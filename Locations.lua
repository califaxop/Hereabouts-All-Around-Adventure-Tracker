-- One location model for the whole addon (1.10.0). Every place Hereabouts knows of is a location:
--   { kind, map, x, y, label, source }
--   kind    what it is (L.KINDS): a quest giver, an objective, a turn-in, where a quest's item drops
--   map     the game's map ID (uiMapID); x, y on that map in 0-1, or nil: somewhere on that map
--           (the place isn't known to the point, e.g. an instance spawn)
--   label   what to call it ("Wendel Mathers", "drops Akiris Reed: Naga Explorer")
--   source  where it comes from: "game", "questie", "static" (LOCATION_SOURCES.md)
-- Questie's spawns (area ID -> points in 0-100) are turned into locations here and nowhere else;
-- distances in yards (world positions) are worked out here too. Pure apart from L.WorldPos and
-- L.PlayerPos (the game's maps), which callers can pass in.
local _, ns = ...
local L = {}
ns.Locations = L

-- (trainers and dungeon entrances: Dungeons.lua and Training.lua know them by zone or city name
-- only, without the game's map IDs or points; they join the model when verified places do)
L.KINDS = {
  giver = "quest giver", objective = "objective", turnin = "turn-in", itemsource = "where its item drops",
}
L.MAX_POINTS = 25 -- per area and thing: a mob with hundreds of spawns doesn't need them all

-- a checked location, or nil: a map ID that's a whole positive number, and a point in 0-1 or none
-- (0, 0 and points outside the map are dropped: Questie marks instance spawns with -1, -1)
function L.New(kind, map, x, y, label, source)
  if not L.KINDS[kind] then return nil end
  if type(map) ~= "number" or map <= 0 or map ~= math.floor(map) then return nil end
  if x ~= nil or y ~= nil then
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then
      x, y = nil, nil
    end
  end
  return { kind = kind, map = map, x = x, y = y, label = label, source = source or "questie" }
end

-- Questie spawns { [areaID] = { { x, y }, ... } } (0-100) -> locations; toMap(areaID) -> map ID
-- or nil. An area with no usable point is still a location (somewhere on that map).
function L.FromSpawns(spawns, kind, label, toMap)
  local out = {}
  if type(spawns) ~= "table" then return out end
  for areaId, points in pairs(spawns) do
    local map = toMap(areaId)
    if map then
      local n = 0
      for _, p in ipairs(type(points) == "table" and points or {}) do
        if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
          local loc = L.New(kind, map, p[1] / 100, p[2] / 100, label, "questie")
          if loc and loc.x then
            out[#out + 1] = loc
            n = n + 1
            if n >= L.MAX_POINTS then break end
          end
        end
      end
      if n == 0 then
        local loc = L.New(kind, map, nil, nil, label, "questie")
        if loc then out[#out + 1] = loc end
      end
    end
  end
  return out
end

-- only these kinds (a set: { giver = true, ... }); nil keeps all
function L.Filter(list, kinds)
  if not kinds then return list end
  local out = {}
  for _, loc in ipairs(list) do if kinds[loc.kind] then out[#out + 1] = loc end end
  return out
end

-- the maps a list covers: map -> the first label there (what the zone filter needs)
function L.Maps(list)
  local maps = {}
  for _, loc in ipairs(list) do
    if loc.map and maps[loc.map] == nil then maps[loc.map] = loc.label or L.KINDS[loc.kind] end
  end
  return maps
end

---------------------------------------------------------------------------
-- Distances (yards, on the same continent only)
---------------------------------------------------------------------------
-- a map point's world position: continent, x, y; or nil
function L.WorldPos(map, x, y)
  if not (map and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
  if not (ok and cont and pos) then return end
  local wx, wy
  if pos.GetXY then wx, wy = pos:GetXY() else wx, wy = pos.x, pos.y end
  if type(wx) ~= "number" or type(wy) ~= "number" then return end
  return cont, wx, wy
end
-- your world position: { cont, x, y }, or nil
function L.PlayerPos()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return end
  local ok, p = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not (ok and p and p.GetXY) then return end
  local x, y = p:GetXY()
  if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return end
  local c, wx, wy = L.WorldPos(map, x, y)
  if c then return { c, wx, wy } end
end
-- yards from `from` (a world position, default yours) to a location with a point; nil if unknown
function L.Yards(loc, from)
  if not (loc and loc.x) then return nil end
  from = from or L.PlayerPos()
  if not from then return nil end
  local c, x, y = L.WorldPos(loc.map, loc.x, loc.y)
  if not c or c ~= from[1] then return nil end
  return math.sqrt((x - from[2]) ^ 2 + (y - from[3]) ^ 2)
end

-- The nearest location with a point, and its yards. When none can be measured (another continent,
-- no position): the first with a point on `preferMap`, else the first with a point.
function L.Nearest(list, from, preferMap)
  from = from or L.PlayerPos()
  local best, bestYd, onMap, any
  for _, loc in ipairs(list) do
    if loc.x then
      local yd = from and L.Yards(loc, from)
      if yd and (not bestYd or yd < bestYd) then best, bestYd = loc, yd end
      if not onMap and preferMap and loc.map == preferMap then onMap = loc end
      any = any or loc
    end
  end
  if best then return best, bestYd end
  return onMap or any, nil
end

-- A visiting order for a set of places (the start of route planning): from `from`, always the
-- nearest place not yet visited. Places that can't be measured go last, as they came.
function L.Route(list, from)
  from = from or L.PlayerPos()
  local left, order, cur = {}, {}, from
  for _, loc in ipairs(list) do left[#left + 1] = loc end
  while cur and #left > 0 do
    local bi, byd
    for i, loc in ipairs(left) do
      local yd = L.Yards(loc, cur)
      if yd and (not byd or yd < byd) then bi, byd = i, yd end
    end
    if not bi then break end
    local loc = table.remove(left, bi)
    order[#order + 1] = loc
    local c, x, y = L.WorldPos(loc.map, loc.x, loc.y)
    cur = { c, x, y }
  end
  for _, loc in ipairs(left) do order[#order + 1] = loc end
  return order
end
