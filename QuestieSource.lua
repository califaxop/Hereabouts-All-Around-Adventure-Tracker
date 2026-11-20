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

local QDB, QXP, TU, ZDB, QP, QM, QL, QA
local function Bind()
  if not (QuestieLoader and QuestieLoader.ImportModule) then return false end
  local ok1, a = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
  local ok2, b = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestXP")
  local ok3, c = pcall(QuestieLoader.ImportModule, QuestieLoader, "TrackerUtils")
  if not (ok1 and ok2 and a and b and a.IsDoable and a.GetQuest and b.GetQuestLogRewardXP) then return false end
  QDB, QXP, TU = a, b, ok3 and c or nil
  local ok4, z = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
  ZDB = ok4 and z or nil
  local ok5, qp = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestiePlayer")
  QP = ok5 and qp or nil
  local ok6, qm = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieMap")
  QM = ok6 and qm or nil
  local ok7, ql = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieLib")
  QL = (ok7 and ql and ql.GetEffectiveQuestLevel) and ql or nil
  -- Questie's own "available quests" set (what it draws on the map, by its settings)
  local ok8, qa = pcall(QuestieLoader.ImportModule, QuestieLoader, "AvailableQuests")
  QA = (ok8 and qa) or nil
  if QA and type(QA.CalculateAndDrawAll) == "function" and not QA.xppHooked then
    QA.xppHooked = true
    -- Questie recalculates (level up, settings, quest turned in...): follow it shortly after
    hooksecurefunc(QA, "CalculateAndDrawAll", function() C_Timer.After(2, function() Q.RescanSoon() end) end)
  end
  return true
end

function Q.Available() return ready end
function Q.Count()
  local n, ignored = 0, ns.db.ignoredQuests or {}
  for id in pairs(candidates) do if not ignored[id] then n = n + 1 end end
  return n
end
function Q.IsScanning() return scanning end
local function AddonLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) and true or false end
  return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
end
-- Installed: Questie's addon is loaded or its loader exists. Doesn't rely on Questie.API.
function Q.Installed()
  return (AddonLoaded("Questie") or (QuestieLoader ~= nil and type(Questie) == "table")) and true or false
end

-- /xpp questie: what XPP sees of Questie, to tell apart "not loaded" from "loaded but broken".
function Q.Diagnose(print)
  local api = type(Questie) == "table" and Questie.API
  local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Questie", "Version")
  print(format("Questie addon loaded: %s, version: %s", tostring(AddonLoaded("Questie")), tostring(ver)))
  print(format("Questie global: %s, QuestieLoader: %s, API: %s, isReady: %s",
    type(Questie), type(QuestieLoader), tostring(api and true or false), tostring(api and api.isReady)))
  if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
    for i = 1, C_AddOns.GetNumAddOns() do
      local name, title = C_AddOns.GetAddOnInfo(i)
      if name and name ~= "Questie" and (name:lower():find("questie", 1, true)) then
        print(format("Other Questie-named addon: %s (loaded: %s)", name, tostring(AddonLoaded(name))))
      end
    end
  end
  print(format("XPP bound to Questie database: %s, quests found: %d", tostring(ready), Q.Count()))
end

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

-- A map ID raised to its zone (sub-maps like caves and city districts count as their zone).
local function ZoneLevel(id)
  local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
  local guard = 0
  while id and guard < 6 do
    local info = C_Map.GetMapInfo(id)
    if not info or not info.mapType or info.mapType <= zoneType or not info.parentMapID or info.parentMapID == 0 then break end
    id, guard = info.parentMapID, guard + 1
  end
  return id
end
Q.ZoneLevel = ZoneLevel

-- The zone you're in, as a map ID.
local function CurrentZoneMap()
  return ZoneLevel(C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
end
Q.CurrentZoneMap = CurrentZoneMap

-- The game's own quest map data (its built-in objective areas and turn-in markers): the zone
-- where it places a quest in your log right now. nil if the game gives no map for it.
function Q.GameQuestZone(id)
  local f = _G.GetQuestUiMapID or (C_QuestLog and C_QuestLog.GetQuestUiMapID)
  if not f then return nil end
  local ok, m = pcall(f, id)
  if not ok or type(m) ~= "number" or m <= 0 then return nil end
  return ZoneLevel(m), m
end

-- Where an active quest is done, from Questie's database, as a set of map IDs (nil if Questie
-- can't say). Ready to turn in: wherever its turn-in NPC or object stands. Still in progress:
-- wherever its objectives are (mobs and objects to kill or use, and the mobs and objects that
-- drop its items); the quest's own zone only when those places aren't known.
local activeMaps = {}
-- each map remembers why it counts (for /xpp zone): e.g. "objective: Twisted Elemental (mob)"
local function AddSpawns(maps, kind, id, why)
  local query = (kind == "npc") and QDB.QueryNPCSingle or QDB.QueryObjectSingle
  if not (query and id) then return end
  local ok, sp = pcall(query, id, "spawns")
  if ok and type(sp) == "table" then
    local okN, name = pcall(query, id, "name")
    local label = (why or "") .. ((okN and name) or ("#" .. tostring(id))) .. (kind == "npc" and " (mob/NPC)" or " (object)")
    for areaId in pairs(sp) do
      local m = UiMapFor(areaId)
      if m and not maps[m] then maps[m] = label end
    end
  end
end
local function Field(id, key)
  if not (QDB and QDB.QueryQuestSingle) then return nil end
  local ok, v = pcall(QDB.QueryQuestSingle, id, key)
  return ok and v or nil
end
-- logObjectives: the quest log's objective lines ({ text, done }). An objective already done
-- (its name appears in a finished line, e.g. "Twisted Air Totem: 5/5") doesn't count.
-- Questie's own quest log: each objective, whether it's done, and where it spawns (what its map
-- markers come from, including special objectives like "find the crown in the Badlands crypt").
-- Returns a set of map IDs ({} = nothing left with a known place), or nil if Questie has no entry.
local function FromQuestieLog(id)
  local log = QP and QP.currentQuestlog
  local q = type(log) == "table" and log[id]
  if type(q) ~= "table" then return nil end
  local maps, sawObjective = {}, false
  local function scan(list)
    if type(list) ~= "table" then return end
    for _, o in pairs(list) do
      if type(o) == "table" then
        sawObjective = true
        if not o.Completed and type(o.spawnList) == "table" then
          for _, sp in pairs(o.spawnList) do
            if type(sp) == "table" and type(sp.Spawns) == "table" then
              for areaId in pairs(sp.Spawns) do
                local m = UiMapFor(areaId)
                if m and not maps[m] then
                  maps[m] = "objective: " .. tostring(sp.Name or o.Description or "?") .. " (Questie's map)"
                end
              end
            end
          end
        end
      end
    end
  end
  local ok = pcall(function() scan(q.Objectives); scan(q.SpecialObjectives) end)
  if not ok or not sawObjective then return nil end
  return maps
end

-- The map markers Questie has drawn for a quest (its objectives while in progress, its turn-in
-- once complete): the maps they sit on. nil if Questie has drawn none for it.
local function FromQuestieMarkers(id)
  local byQuest = QM and type(QM.questIdFrames) == "table" and QM.questIdFrames[id]
  if type(byQuest) ~= "table" then return nil end
  local maps, any = {}, false
  pcall(function()
    for k, v in pairs(byQuest) do
      local f = (type(v) == "table" and v) or (type(v) == "string" and _G[v]) or (type(k) == "string" and _G[k]) or nil
      if type(f) == "table" then
        local data = f.data
        local typ = type(data) == "table" and data.Type or nil
        if typ ~= "available" then
          local m = f.UiMapID or f.uiMapId or (type(data) == "table" and (data.UiMapID or data.uiMapId))
          if type(m) == "number" then
            any = true
            if not maps[m] then
              local what = type(data) == "table" and (data.Name or (type(data.ObjectiveData) == "table" and data.ObjectiveData.Description)) or nil
              maps[m] = "Questie's map marker" .. (what and (": " .. tostring(what)) or "")
            end
          end
        end
      end
    end
  end)
  if not any then return nil end
  return maps
end
Q.FromQuestieMarkers = FromQuestieMarkers

function Q.ActiveQuestMaps(id, complete, logObjectives)
  if not (ready and QDB and id) then return nil end
  -- first choice: where Questie has drawn the quest's markers (not cached: it follows progress)
  local mk = FromQuestieMarkers(id)
  if mk then return mk end
  if not complete then
    -- next: Questie's own quest log (objectives, done or not, and where they spawn)
    local m = FromQuestieLog(id)
    if m then return m end
  end
  -- what's still to do, by name, so finished objectives drop out (and the cache follows progress)
  local doneText, todoKey = {}, {}
  for _, o in ipairs(logObjectives or {}) do
    if type(o.text) == "string" then
      if o.done then doneText[#doneText + 1] = o.text:lower() else todoKey[#todoKey + 1] = o.text end
    end
  end
  local key = id .. (complete and ":done" or (":todo:" .. table.concat(todoKey, "|")))
  if activeMaps[key] ~= nil then return activeMaps[key] or nil end
  local function finished(name)
    if type(name) ~= "string" or name == "" then return false end
    local n = name:lower()
    for _, t in ipairs(doneText) do if t:find(n, 1, true) then return true end end
    return false
  end
  local function nameOf(query, oid)
    local ok, n = pcall(query, oid, "name")
    return ok and n or nil
  end
  local maps = {}
  local remaining = 0
  if complete then
    local fb = Field(id, "finishedBy") -- { npc IDs, object IDs }
    if type(fb) == "table" then
      for _, n in ipairs(type(fb[1]) == "table" and fb[1] or {}) do AddSpawns(maps, "npc", n, "turn-in: ") end
      for _, o in ipairs(type(fb[2]) == "table" and fb[2] or {}) do AddSpawns(maps, "object", o, "turn-in: ") end
    end
  else
    local obj = Field(id, "objectives") -- { creatures, objects, items, reputation, ... }
    local hasAny = false
    if type(obj) == "table" then
      for _, c in ipairs(type(obj[1]) == "table" and obj[1] or {}) do
        local nid = type(c) == "table" and c[1] or c
        hasAny = true
        if not finished(QDB.QueryNPCSingle and nameOf(QDB.QueryNPCSingle, nid)) then
          remaining = remaining + 1
          AddSpawns(maps, "npc", nid, "objective: ")
        end
      end
      for _, o in ipairs(type(obj[2]) == "table" and obj[2] or {}) do
        local oid = type(o) == "table" and o[1] or o
        hasAny = true
        if not finished(QDB.QueryObjectSingle and nameOf(QDB.QueryObjectSingle, oid)) then
          remaining = remaining + 1
          AddSpawns(maps, "object", oid, "objective: ")
        end
      end
      for _, it in ipairs(type(obj[3]) == "table" and obj[3] or {}) do
        local itemId = type(it) == "table" and it[1] or it
        hasAny = true
        local iname = QDB.QueryItemSingle and nameOf(QDB.QueryItemSingle, itemId)
        if itemId and not finished(iname) then
          remaining = remaining + 1
          if QDB.QueryItemSingle then
            local drop = "drops " .. (iname or "item") .. ": "
            local ok1, npcs = pcall(QDB.QueryItemSingle, itemId, "npcDrops")
            if ok1 and type(npcs) == "table" then for _, n in ipairs(npcs) do AddSpawns(maps, "npc", n, drop) end end
            local ok2, objs = pcall(QDB.QueryItemSingle, itemId, "objectDrops")
            if ok2 and type(objs) == "table" then for _, o in ipairs(objs) do AddSpawns(maps, "object", o, drop) end end
          end
        end
      end
      for _, r in ipairs(type(obj[4]) == "table" and obj[4] or {}) do hasAny = true end
    end
    -- the quest's own zone only for quests with no listed objectives at all (e.g. "talk to...");
    -- objectives still to do whose places Questie doesn't know don't make it count as here
    if not hasAny and not next(maps) then
      local zone = Field(id, "zoneOrSort")
      if type(zone) == "number" and zone > 0 then
        local m = UiMapFor(zone); if m then maps[m] = "the quest's zone (it lists no objectives)" end
      end
    end
  end
  if not next(maps) then
    -- Questie knows the quest but nothing left to do is placed anywhere: say "not here" (an empty
    -- set), rather than "can't say", which would fall back to the quest log's zone heading
    local known = complete and Field(id, "finishedBy") or (not complete and Field(id, "objectives"))
    maps = known and {} or false
  end
  activeMaps[key] = maps
  return maps or nil
end

-- /xpp qinfo <questID>: what each source holds, as short lines
function Q.Inspect(id)
  local out = {}
  local function keys(t, n)
    local k = {}
    if type(t) ~= "table" then return tostring(t) end
    for key in pairs(t) do k[#k + 1] = tostring(key); if #k >= (n or 12) then break end end
    return "{" .. table.concat(k, ", ") .. "}"
  end
  local function maps(m) if not m then return "nothing" end local t = {} for k, v in pairs(m) do t[#t + 1] = k .. " " .. tostring(v) end return #t > 0 and table.concat(t, "; ") or "no places" end
  out[#out + 1] = "here = map " .. tostring(CurrentZoneMap())
  local gz, graw = Q.GameQuestZone(id)
  out[#out + 1] = "game's quest map: " .. (gz and ("map " .. graw .. " (zone " .. gz .. ")") or "none")
  local okW, wm = pcall(function() return C_QuestLog.GetNextWaypoint and C_QuestLog.GetNextWaypoint(id) end)
  out[#out + 1] = "game's next waypoint map: " .. tostring(okW and wm or "none")
  out[#out + 1] = "markers: " .. (QM and ("questIdFrames " .. keys(QM.questIdFrames and QM.questIdFrames[id], 6)) or "QuestieMap not found")
  out[#out + 1] = "  -> " .. maps(FromQuestieMarkers(id))
  local log = QP and QP.currentQuestlog
  out[#out + 1] = "log: " .. (QP and (type(log) == "table" and ("entry " .. keys(log[id], 14)) or "no currentQuestlog") or "QuestiePlayer not found")
  local e = type(log) == "table" and log[id]
  if type(e) == "table" then
    out[#out + 1] = "  Objectives " .. keys(e.Objectives, 6) .. "  SpecialObjectives " .. keys(e.SpecialObjectives, 6)
    local o = type(e.Objectives) == "table" and select(2, next(e.Objectives))
    if type(o) == "table" then out[#out + 1] = "  first objective " .. keys(o, 14) end
  end
  out[#out + 1] = "  -> " .. maps(FromQuestieLog(id))
  out[#out + 1] = "database objectives: " .. keys(Field(id, "objectives"), 8) .. "  zoneOrSort " .. tostring(Field(id, "zoneOrSort"))
  return out
end

-- The quests Questie lists as available right now (nil if this Questie doesn't expose them)
local function QuestieSet()
  local set = QA and QA.__availableQuests
  if type(set) == "table" then return set end
end

-- a cheap fingerprint of Questie's available set: count and id sum
function Q.SetStamp(set)
  local n, sum = 0, 0
  for id in pairs(set) do n = n + 1; sum = sum + (tonumber(id) or 0) end
  return n .. ":" .. sum
end

-- Questie fills and updates its available set in the background, over several seconds:
-- check it every few seconds and rescan whenever it has changed since the last scan.
local watcher
local function WatchQuestieSet()
  if watcher or not C_Timer.NewTicker then return end
  watcher = C_Timer.NewTicker(3, function()
    if not ready or scanning then return end
    local set = QuestieSet()
    if set and Q.SetStamp(set) ~= Q.setStamp then Q.Scan() end
  end)
end

local function Consider(id, fromQuestie)
  if InLogOrDone(id) then return end
  if not fromQuestie then -- Questie's set is already filtered by its own rules and settings
    local okD, doable = pcall(QDB.IsDoable, id)
    if not (okD and doable) then return end
  end
  local okQ, quest = pcall(QDB.GetQuest, id)
  if not (okQ and quest) or quest.isHidden then return end
  -- keep every level (Questie already drops what you can't take yet); the level range, or
  -- "Show all levels", is applied when listing, so changing it needs no rescan
  -- level to accept: Questie's "can take" check leaves that to its own level filter
  local me = UnitLevel("player")
  local reqLvl, reqMax
  if QL then
    local okL, lvl, rl, rm = pcall(QL.GetEffectiveQuestLevel, id, me)
    if okL then reqLvl = (type(rl) == "number" and rl > 0) and rl or lvl; reqMax = rm end
  else
    reqLvl = Field(id, "requiredLevel")
  end
  if not fromQuestie then
    if type(reqLvl) == "number" and reqLvl > me then return end              -- too low to take it yet
    if type(reqMax) == "number" and reqMax > 0 and me > reqMax then return end -- too high for it
  end
  local okX, xp = pcall(QXP.GetQuestLogRewardXP, QXP, id, false)
  xp = (okX and Readable(xp) and type(xp) == "number") and xp or 0
  -- (repeatable and no-XP quests: listed when Questie lists them, i.e. by Questie's settings)
  local starter, starterZone = StarterInfo(quest)
  local zoneID = quest.zoneOrSort
  candidates[id] = {
    id = id, name = quest.name, level = quest.level, xp = xp,
    repeatable = quest.IsRepeatable and true or nil,
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
  local set = QuestieSet()
  Q.setStamp = set and Q.SetStamp(set) or nil -- what this scan saw (see the watcher below)
  -- Questie's available quests when it exposes them; otherwise its whole database, checked here
  for id in pairs(set or QDB.QuestPointers or {}) do ids[#ids + 1] = id end
  local fromQuestie = set ~= nil
  local fresh, i = {}, 1
  local old = candidates
  candidates = fresh
  local function step()
    local stop = math.min(i + 250, #ids)
    for n = i, stop do Consider(ids[n], fromQuestie) end
    i = stop + 1
    if i <= #ids then
      C_Timer.After(0, step)
    else
      scanning = false
      if Q.onUpdate then Q.onUpdate() end
    end
  end
  if #ids == 0 then
    candidates = fromQuestie and fresh or old; scanning = false
    if fromQuestie and Q.onUpdate then Q.onUpdate() end
    return
  end
  step()
end

-- Drop a quest right away when you accept or finish it (no full rescan needed).
function Q.Remove(id) if id then candidates[id] = nil end end

-- Ranked list. Score = XP, with a bonus for quests in the zone you're in (less travel).
-- Ranked list: quests you can pick up (optionally only in your zone, always within your level
-- range), best XP first. Quests in your zone get the zone bonus when the zone filter is off.
function Q.Ranked(limit)
  local db = ns.db
  local hereMap = CurrentZoneMap()
  local ignored = db.ignoredQuests or {}
  local list, elsewhere = {}, 0
  for _, c in pairs(candidates) do
    c.here = (hereMap and c.maps and c.maps[hereMap]) or false
    if not ignored[c.id] then -- which quests at all: Questie's settings decide
      if c.here or not db.pickupZoneOnly then
        c.score = c.xp * (c.here and db.zoneBonus or 1)
        list[#list + 1] = c
      else
        elsewhere = elsewhere + 1 -- hidden by the current-zone filter
      end
    end
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return (a.level or 0) < (b.level or 0)
  end)
  local out = {}
  for n = 1, math.min(limit, #list) do out[n] = list[n] end
  return out, #list, elsewhere
end

local function OnReady()
  if ready then return end
  if Bind() then
    ready = true
    Q.Scan()
    WatchQuestieSet()
  else
    ns.Print("Questie found, but its database couldn't be read. Using the map instead.")
  end
end

-- Ready once Questie says so; without its API, once its quest list exists. Gives up after ~2 min.
local function PollReady(tries)
  if ready then return end
  local api = type(Questie) == "table" and Questie.API
  local qdbOk, qdb = false, nil
  if QuestieLoader and QuestieLoader.ImportModule then
    qdbOk, qdb = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
  end
  if (api and api.isReady) or (not api and qdbOk and type(qdb) == "table" and qdb.QuestPointers) then
    return OnReady()
  end
  if tries > 0 and C_Timer then C_Timer.After(2, function() PollReady(tries - 1) end) end
end

function Q.Init()
  if not Q.Installed() then return false end
  local api = type(Questie) == "table" and Questie.API
  if api and type(api.RegisterOnReady) == "function" then
    local ok = pcall(api.RegisterOnReady, OnReady)
    if not ok then PollReady(60) end
  else
    PollReady(60)
  end
  return true
end

-- Items Questie's database ties to a quest: the item it starts you with, items it gives you to
-- use, and its item objectives. (The quest item button keeps only the usable ones you carry.)
function Q.QuestItemIds(id)
  if not (ready and QDB and QDB.GetQuest) then return nil end
  local ok, quest = pcall(QDB.GetQuest, id)
  if not (ok and type(quest) == "table") then return nil end
  local out = {}
  if type(quest.sourceItemId) == "number" and quest.sourceItemId > 0 then out[#out + 1] = quest.sourceItemId end
  for _, item in pairs(type(quest.requiredSourceItems) == "table" and quest.requiredSourceItems or {}) do
    if type(item) == "number" then out[#out + 1] = item end
  end
  for _, o in pairs(type(quest.ObjectiveData) == "table" and quest.ObjectiveData or {}) do
    if type(o) == "table" and o.Type == "item" and type(o.Id) == "number" then out[#out + 1] = o.Id end
  end
  return out
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
