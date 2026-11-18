-- Builds the suggestion lists: quests in your log, quests available nearby, and dungeons.
local _, ns = ...
local Readable = ns.Readable

local function Safe(fn, ...)
  if not fn then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

local function QuestXP(questID)
  local xp = Safe(GetQuestLogRewardXP, questID)
  return Readable(xp) and xp or 0
end

local function Objectives(questID)
  local out = {}
  local list = C_QuestLog and Safe(C_QuestLog.GetQuestObjectives, questID)
  if type(list) == "table" then
    for _, o in ipairs(list) do
      if Readable(o.text) and o.text ~= "" then out[#out + 1] = { text = o.text, done = o.finished } end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Quests in your log
---------------------------------------------------------------------------
local function LogQuests()
  local out = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return out end
  local header -- the quest log's zone header the following quests sit under
  for i = 1, (Safe(C_QuestLog.GetNumQuestLogEntries) or 0) do
    local info = Safe(C_QuestLog.GetInfo, i)
    if info and info.isHeader then header = info.title end
    if info and not info.isHeader and not info.isHidden and info.questID then
      local id = info.questID
      local level = info.difficultyLevel and info.difficultyLevel > 0 and info.difficultyLevel or info.level
      out[#out + 1] = {
        kind = "quest", questID = id, title = info.title, level = level,
        xp = QuestXP(id),
        complete = Safe(C_QuestLog.IsComplete, id) and true or false,
        -- tracked? (if the client can't tell us, treat it as tracked rather than dimming everything)
        tracked = (not C_QuestLog.GetQuestWatchType) or Safe(C_QuestLog.GetQuestWatchType, id) ~= nil,
        focused = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
          and Safe(C_SuperTrack.GetSuperTrackedQuestID) == id or false,
        objectives = Objectives(id),
        zone = header,
      }
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Quests the map shows as available near you
---------------------------------------------------------------------------
local function NearbyQuests()
  local out = {}
  if not (C_QuestLine and C_QuestLine.GetAvailableQuestLines and C_Map) then return out end
  local mapID = Safe(C_Map.GetBestMapForUnit, "player")
  if not mapID then return out end
  Safe(C_QuestLine.RequestQuestLinesForMap, mapID)
  local lines = Safe(C_QuestLine.GetAvailableQuestLines, mapID)
  if type(lines) ~= "table" then return out end
  local seen = {}
  for _, q in ipairs(lines) do
    local id = q.questID
    local inLog = id and C_QuestLog.GetLogIndexForQuestID and Safe(C_QuestLog.GetLogIndexForQuestID, id)
    if id and not seen[id] and not inLog and not q.isHidden and Readable(q.questName) then
      seen[id] = true
      local level = Safe(C_QuestLog.GetQuestDifficultyLevel, id)
      out[#out + 1] = { kind = "nearby", questID = id, title = q.questName,
        level = (Readable(level) and level > 0) and level or nil }
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Ranking
---------------------------------------------------------------------------
-- Is an active quest in the zone you're in? Its quest log zone header matches, or the map
-- shows it on your current map (quests filed under another header with objectives here).
local zoneName, onMap
local function RefreshZone()
  zoneName = GetRealZoneText and GetRealZoneText() or nil
  onMap = {}
  local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit, "player")
  local list = mapID and C_QuestLog.GetQuestsOnMap and Safe(C_QuestLog.GetQuestsOnMap, mapID)
  if type(list) == "table" then
    for _, q in ipairs(list) do if q.questID then onMap[q.questID] = true end end
  end
end
-- In your zone? Questie knows where a quest is done (its turn-in once it's ready, otherwise its
-- zone and objectives); without Questie, the quest log's zone heading or the game's map decide.
-- Returns true/false and why (for /xpp zone).
local function InZone(q)
  -- in a dungeon: its quests are here. The game files them under the dungeon's name in the quest
  -- log ("Scarlet Monastery"), and may place them on the dungeon's own map rather than a zone.
  -- (not `a and f()`: that keeps only f's first value)
  local inInstance = false
  if IsInInstance then inInstance = IsInInstance() end
  local gz, graw
  if ns.Questie.GameQuestZone then gz, graw = ns.Questie.GameQuestZone(q.questID) end
  if inInstance then
    local instName = GetInstanceInfo and GetInstanceInfo()
    local hereRaw = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if graw and hereRaw and graw == hereRaw then return true, "the game's map places it in this dungeon" end
    local h = q.zone and q.zone:lower()
    local n = type(instName) == "string" and instName:lower() or nil
    if h and n and h ~= "" and (n:find(h, 1, true) or h:find(n, 1, true)) then
      return true, "quest log heading matches this dungeon (" .. q.zone .. ")"
    end
  end
  -- first: the game's own map for the quest (its built-in objective areas / turn-in), which also
  -- knows quests Questie's data doesn't
  if gz then
    local here = ns.Questie.CurrentZoneMap()
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(gz)
    local where = info and info.name or ("map " .. gz)
    if here and gz == here then return true, "the game's map places it here (" .. where .. ")" end
    return false, "the game's map places it in " .. where
  end
  local maps = ns.Questie.ActiveQuestMaps and ns.Questie.ActiveQuestMaps(q.questID, q.complete, q.objectives)
  if maps then
    local here = ns.Questie.CurrentZoneMap()
    local why = here and maps[here]
    if why then return true, (type(why) == "string" and why or "Questie") end
    if not next(maps) then
      return false, q.complete and "turn-in place unknown (Questie)" or "what's left has no known place (Questie)"
    end
    return false, q.complete and "turn-in elsewhere (Questie)" or "what's left is elsewhere (Questie)"
  end
  if zoneName and q.zone == zoneName then return true, "quest log heading" end
  if onMap and onMap[q.questID] then return true, "on the game's map" end
  return false, "no match"
end
ns.QuestInZone = function(q) RefreshZone(); return InZone(q) end
ns.LogQuests = function() return LogQuests() end

function ns.BuildSuggestions()
  local db = ns.db
  local me = UnitLevel("player")
  local result = { quests = {}, nearby = {}, pickup = {}, dungeons = {}, training = {} }

  -- Log quests: ready-to-turn-in first, then most XP. Gray quests are dropped.
  local quests = LogQuests()
  if db.activeZoneOnly then RefreshZone() end
  local keep = {}
  for _, q in ipairs(quests) do
    q.trivial = ns.IsTrivial(q.level)
    -- When replacing Blizzard's tracker, keep gray quests too (listed last) so none go missing.
    local hiddenUntracked = db.hideUntracked and not q.tracked and not q.focused
    local otherZone = db.activeZoneOnly and not q.focused and not InZone(q)
    local wanted = not hiddenUntracked and (q.complete or not q.trivial or db.replaceTracker or q.focused)
    if wanted and not otherZone then keep[#keep + 1] = q
    elseif wanted then result.questsElsewhere = (result.questsElsewhere or 0) + 1 end
  end
  table.sort(keep, function(a, b)
    if a.focused ~= b.focused then return a.focused end   -- focused quest pinned on top
    if db.sortByLevel then                                 -- highest level first
      if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
      return a.xp > b.xp
    end
    if a.complete ~= b.complete then return a.complete end
    if a.tracked ~= b.tracked then return a.tracked end   -- untracked ones sink below
    if a.trivial ~= b.trivial then return not a.trivial end
    if a.xp ~= b.xp then return a.xp > b.xp end
    return (a.level or 0) < (b.level or 0)
  end)
  if db.showActive then
    for i = 1, math.min(db.maxQuests, #keep) do result.quests[i] = keep[i] end
  end

  -- Quests to pick up: from Questie when installed, otherwise the map's nearby quests.
  if ns.Questie.Available() then
    if db.showPickup then
      -- which quests: the best XP (as before); in what order: highest level first
      result.pickup, result.pickupTotal, result.pickupElsewhere = ns.Questie.Ranked(db.maxPickup)
      if db.sortByLevel then
        table.sort(result.pickup, function(a, b)
          if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
          return a.xp > b.xp
        end)
      end
    end
  elseif db.showNearby then
    local near = {}
    for _, q in ipairs(NearbyQuests()) do
      if not ns.IsTrivial(q.level) then near[#near + 1] = q end
    end
    table.sort(near, function(a, b)
      if db.sortByLevel then return (a.level or 0) > (b.level or 0) end
      return math.abs((a.level or me) - me) < math.abs((b.level or me) - me)
    end)
    for i = 1, math.min(db.maxQuests, #near) do result.nearby[i] = near[i] end
  end

  -- Dungeons whose level range you're in (at least its minimum, not past its top).
  if db.showDungeons then
    local d = {}
    -- your zone: by name, as the dungeon list names each entrance's zone
    local here = GetRealZoneText and GetRealZoneText() or nil
    local hereMap = ns.Questie.CurrentZoneMap and ns.Questie.CurrentZoneMap()
    local mapInfo = hereMap and C_Map.GetMapInfo and C_Map.GetMapInfo(hereMap)
    local hereZone = mapInfo and mapInfo.name or here
    for _, dg in ipairs(ns.DUNGEONS) do
      if me >= dg.min and me <= dg.max then -- from its minimum level to the top of its range
        local inZone = dg.zone == hereZone or dg.zone == here
        if inZone or not db.dungeonZoneOnly then d[#d + 1] = dg
        else result.dungeonsElsewhere = (result.dungeonsElsewhere or 0) + 1 end
      end
    end
    table.sort(d, function(a, b)
      if db.sortByLevel then -- highest level range first
        if a.min ~= b.min then return a.min > b.min end
        return a.max > b.max
      end
      return math.abs((a.min + a.max) / 2 - me) < math.abs((b.min + b.max) / 2 - me)
    end)
    for i = 1, math.min(db.maxDungeons, #d) do result.dungeons[i] = d[i] end
  end

  -- Spells to train (from What's Training)
  if db.showTraining then
    result.training, result.trainCount, result.trainCost = ns.Training.List(db.maxTraining, db.showNextLevel)
  end

  return result
end
