-- Quests you can pick up, read from your installed Questie's database.
-- Uses Questie's own rules (QuestieDB.IsDoable: level, race, class, prerequisites,
-- already completed) and Questie's XP data (QuestXP), so it matches what Questie shows.
local _, ns = ...
local Q = {}
ns.Questie = Q

local Readable = ns.Readable
local candidates = {}   -- questID -> { id, name, level, xp, zoneID, zone, starter, starterZone }
local scanning, ready = false, false
Q.onUpdate = nil        -- called when a scan finishes

local QDB, QXP, TU, ZDB
local function Bind()
  if not (QuestieLoader and Questie and Questie.API) then return false end
  local ok1, a = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
  local ok2, b = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestXP")
  local ok3, c = pcall(QuestieLoader.ImportModule, QuestieLoader, "TrackerUtils")
  if not (ok1 and ok2 and a and b and a.IsDoable and a.GetQuest and b.GetQuestLogRewardXP) then return false end
  QDB, QXP, TU = a, b, ok3 and c or nil
  local ok4, z = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
  ZDB = ok4 and z or nil
  return true
end

function Q.Available() return ready end
function Q.Count()
  local n, ignored = 0, ns.db.ignoredQuests or {}
  for id in pairs(candidates) do if not ignored[id] then n = n + 1 end end
  return n
end
function Q.IsScanning() return scanning end
function Q.Installed() return (Questie and Questie.API) and true or false end

-- Rescan shortly after settings change (coalesces slider drags).
local rescanToken = 0
function Q.RescanSoon()
  rescanToken = rescanToken + 1
  local mine = rescanToken
  C_Timer.After(0.6, function()
    if mine ~= rescanToken then return end
    if scanning then Q.RescanSoon() else Q.Scan() end
  end)
end

local function ZoneName(id)
  if not id or id <= 0 then return nil end
  if TU and TU.GetZoneNameByID then
    local ok, n = pcall(TU.GetZoneNameByID, TU, id)
    if ok and n then return n end
  end
  local ok, n = pcall(C_Map.GetAreaInfo, id)
  return ok and n or nil
end

local function StarterInfo(quest)
  local npcs = quest.Starts and quest.Starts.NPC
  if type(npcs) == "table" and npcs[1] and QDB.QueryNPCSingle then
    local okN, name = pcall(QDB.QueryNPCSingle, npcs[1], "name")
    local okZ, zone = pcall(QDB.QueryNPCSingle, npcs[1], "zoneID")
    return okN and name or nil, okZ and ZoneName(zone) or nil
  end
  if quest.Starts and quest.Starts.Item and quest.Starts.Item[1] then return "Starts from an item", nil end
  if quest.Starts and quest.Starts.GameObject and quest.Starts.GameObject[1] then return "Starts from an object", nil end
end

local function InLogOrDone(id)
  if C_QuestLog.GetLogIndexForQuestID then
    local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, id)
    if ok and idx then return true end
  end
  if C_QuestLog.IsQuestFlaggedCompleted then
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
    if ok and done then return true end
  end
  return false
end

-- Area ID (Questie) -> the game's map ID for that zone.
local function UiMapFor(areaId)
  if not (ZDB and ZDB.GetUiMapIdByAreaId and areaId) then return nil end
  local ok, m = pcall(ZDB.GetUiMapIdByAreaId, ZDB, areaId)
  return ok and type(m) == "number" and m or nil
end

local function Spawns(c)
  if c.starterNpc and QDB.QueryNPCSingle then
    local ok, sp = pcall(QDB.QueryNPCSingle, c.starterNpc, "spawns")
    if ok and type(sp) == "table" then return sp end
  end
  if c.starterObj and QDB.QueryObjectSingle then
    local ok, sp = pcall(QDB.QueryObjectSingle, c.starterObj, "spawns")
    if ok and type(sp) == "table" then return sp end
  end
end

-- The zones (map IDs) where you can pick a quest up: wherever its quest giver stands. Quests
-- that start from an item use the quest's own zone.
local function StartMaps(c, zoneOrSort)
  local maps = {}
  local spawns = Spawns(c)
  if spawns then
    for areaId in pairs(spawns) do
      local m = UiMapFor(areaId)
      if m then maps[m] = true end
    end
  end
  if not next(maps) and zoneOrSort and zoneOrSort > 0 then
    local m = UiMapFor(zoneOrSort)
    if m then maps[m] = true end
  end
  return maps
end

-- The zone you're in, as a map ID (sub-maps like caves and city districts count as their zone).
local function CurrentZoneMap()
  local id = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
  local guard = 0
  while id and guard < 6 do
    local info = C_Map.GetMapInfo(id)
    if not info or not info.mapType or info.mapType <= zoneType or not info.parentMapID or info.parentMapID == 0 then break end
    id, guard = info.parentMapID, guard + 1
  end
  return id
end
Q.CurrentZoneMap = CurrentZoneMap

local function Consider(id)
  if InLogOrDone(id) then return end
  local okD, doable = pcall(QDB.IsDoable, id)
  if not (okD and doable) then return end
  local okQ, quest = pcall(QDB.GetQuest, id)
  if not (okQ and quest) or quest.isHidden or quest.IsRepeatable then return end
  -- keep anything within the widest level range the settings allow (-8..+8); the exact range
  -- you chose is applied when listing, so changing it needs no rescan
  local me = UnitLevel("player")
  if quest.level and quest.level > 0 and (quest.level > me + 8 or quest.level < me - 8) then return end
  local okX, xp = pcall(QXP.GetQuestLogRewardXP, QXP, id, false)
  if not (okX and Readable(xp) and xp > 0) then return end
  local starter, starterZone = StarterInfo(quest)
  local zoneID = quest.zoneOrSort
  candidates[id] = {
    id = id, name = quest.name, level = quest.level, xp = xp,
    zoneID = (zoneID and zoneID > 0) and zoneID or nil,
    zone = starterZone or ZoneName(zoneID),
    starter = starter,
    starterNpc = quest.Starts and type(quest.Starts.NPC) == "table" and quest.Starts.NPC[1] or nil,
    starterObj = quest.Starts and type(quest.Starts.GameObject) == "table" and quest.Starts.GameObject[1] or nil,
  }
  candidates[id].maps = StartMaps(candidates[id], zoneID)
end

-- Scan every quest in Questie's database, a slice per frame so the game never stutters.
function Q.Scan()
  if not ready or scanning then return end
  scanning = true
  local ids = {}
  for id in pairs(QDB.QuestPointers or {}) do ids[#ids + 1] = id end
  local fresh, i = {}, 1
  local old = candidates
  candidates = fresh
  local function step()
    local stop = math.min(i + 250, #ids)
    for n = i, stop do Consider(ids[n]) end
    i = stop + 1
    if i <= #ids then
      C_Timer.After(0, step)
    else
      scanning = false
      if Q.onUpdate then Q.onUpdate() end
    end
  end
  if #ids == 0 then candidates = old; scanning = false; return end
  step()
end

-- Drop a quest right away when you accept or finish it (no full rescan needed).
function Q.Remove(id) if id then candidates[id] = nil end end

-- Ranked list. Score = XP, with a bonus for quests in the zone you're in (less travel).
-- Ranked list: quests you can pick up (optionally only in your zone, always within your level
-- range), best XP first. Quests in your zone get the zone bonus when the zone filter is off.
function Q.Ranked(limit)
  local db = ns.db
  local me = UnitLevel("player")
  local lo, hi = me + (db.levelMin or -5), me + (db.levelMax or 3)
  local hereMap = CurrentZoneMap()
  local ignored = db.ignoredQuests or {}
  local list = {}
  for _, c in pairs(candidates) do
    local lvl = c.level
    local inRange = not lvl or lvl <= 0 or (lvl >= lo and lvl <= hi) -- unknown/scaling levels: kept
    c.here = (hereMap and c.maps and c.maps[hereMap]) or false
    if not ignored[c.id] and inRange and (c.here or not db.pickupZoneOnly) then
      c.score = c.xp * (c.here and db.zoneBonus or 1)
      list[#list + 1] = c
    end
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return (a.level or 0) < (b.level or 0)
  end)
  local out = {}
  for n = 1, math.min(limit, #list) do out[n] = list[n] end
  return out, #list
end

function Q.Init()
  if not (Questie and Questie.API and Questie.API.RegisterOnReady) then return false end
  Questie.API.RegisterOnReady(function()
    if Bind() then
      ready = true
      Q.Scan()
    else
      ns.Print("Questie found, but its database couldn't be read. Using the map instead.")
    end
  end)
  return true
end

---------------------------------------------------------------------------
-- Where to pick a quest up: the quest giver's spawn (map ID, x, y in 0-1).
-- With several spawns, the one in the zone you're in wins.
---------------------------------------------------------------------------
function Q.Location(id)
  local c = candidates[id]
  if not (c and QDB) then return nil end
  local spawns
  if c.starterNpc and QDB.QueryNPCSingle then
    local ok, sp = pcall(QDB.QueryNPCSingle, c.starterNpc, "spawns"); spawns = ok and sp or nil
  end
  if not spawns and c.starterObj and QDB.QueryObjectSingle then
    local ok, sp = pcall(QDB.QueryObjectSingle, c.starterObj, "spawns"); spawns = ok and sp or nil
  end
  if type(spawns) ~= "table" then return nil end
  local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local best
  for areaId, points in pairs(spawns) do
    local uiMapId = ZDB and ZDB.GetUiMapIdByAreaId and select(2, pcall(ZDB.GetUiMapIdByAreaId, ZDB, areaId))
    local p = type(points) == "table" and points[1]
    if type(uiMapId) == "number" and type(p) == "table" and p[1] and p[2] and p[1] > 0 then
      local loc = { map = uiMapId, x = p[1] / 100, y = p[2] / 100 }
      if uiMapId == here then return loc end
      best = best or loc
    end
  end
  return best
end
