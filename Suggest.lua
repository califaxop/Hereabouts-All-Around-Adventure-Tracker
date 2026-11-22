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
-- a quest's usable item (the one Blizzard's tracker shows a button for), if it has one
local function QuestItem(logIndex)
  if not GetQuestLogSpecialItemInfo then return nil end
  local link, icon = Safe(GetQuestLogSpecialItemInfo, logIndex)
  if not (Readable(link) and type(link) == "string") then return nil end
  local id = tonumber(link:match("item:(%d+)"))
  if id then return { itemID = id, icon = icon } end
end

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
        item = QuestItem(i),
      }
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

-- The quest log as the tracker sees it, and a fingerprint of everything it shows from it
-- (quests, completion, tracking, focus, objective progress, items, zone headers). When a
-- "quest log changed" event leaves this the same, there's nothing to rebuild.
function ns.QuestLogStamp()
  local quests = LogQuests()
  local parts = {}
  for _, q in ipairs(quests) do
    parts[#parts + 1] = table.concat({ q.questID, q.complete and 1 or 0, q.tracked and 1 or 0, q.focused and 1 or 0,
      q.item and q.item.itemID or 0, tostring(q.zone), q.xp, q.level or 0 }, ",")
    for _, o in ipairs(q.objectives) do parts[#parts + 1] = (o.done and "+" or "-") .. o.text end
  end
  return table.concat(parts, "|"), quests
end

-- an objective's words without its count: "1/8 Tumbled Crystal" and "Tumbled Crystal: 1/8" match
function ns.ObjectiveKey(text)
  return ((text or ""):lower():gsub("[%d%%/:%-%.,%(%)]", " "):gsub("slain", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- In combat: the quests of what you're fighting. A unit's tooltip lists them, readable in combat on
-- Forever: a quest title line, then your progress ("Hostile Takeover", "1/8 Tumbled Crystal").
-- In a group, lines after another member's name are theirs, not yours.
-- Your target first; with no quest target, every enemy nameplate whose tooltip has a threat line
-- ("100% Threat": it's fighting you), so a mob that jumps you counts too.
local function UnitQuests(unit, titles)
  local ok, d = pcall(C_TooltipInfo.GetUnit, unit)
  if not (ok and type(d) == "table" and type(d.lines) == "table") then return false end
  local T = Enum and Enum.TooltipDataLineType or {}
  local TITLE, PLAYER, OBJ = T.QuestTitle or 17, T.QuestPlayer or 18, T.QuestObjective or 8
  local me = UnitName and UnitName("player")
  local mine, name, threat, found, current = true, nil, false, {}, nil
  for i, l in ipairs(d.lines) do
    local text, kind = l.leftText, l.type
    if Readable(text) and Readable(kind) and type(text) == "string" then
      if i == 1 then name = text end
      if kind == PLAYER then
        mine = Readable(me) and (text == me or text:sub(1, #me + 1) == me .. " ") -- ("Name Surname")
      elseif kind == TITLE and mine then
        current = { title = text, objectives = {} }
        found[#found + 1] = current
      elseif kind == OBJ and mine and current then
        current.objectives[ns.ObjectiveKey(text)] = true -- ("1/8 Tumbled Crystal")
      elseif text:find("^%s*%d+%% [Tt]hreat") then
        threat = true
      end
    end
  end
  return threat, name, found
end

-- { [title] = { [objective key] = true } } and who it's for (a name, or "3 enemies"), or nil
function ns.CombatQuests()
  if not (ns.db.combatFocus and UnitAffectingCombat and UnitAffectingCombat("player")) then return nil end
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
  local titles, any = {}, false
  local _, name, found = UnitQuests("target")
  local function merge(list)
    for _, q in ipairs(list) do
      titles[q.title] = titles[q.title] or {}
      for k in pairs(q.objectives) do titles[q.title][k] = true end
    end
  end
  if found and #found > 0 then
    merge(found)
    return titles, name
  end
  -- no quest target: the enemies fighting you
  local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
  local names, n = nil, 0
  for _, plate in ipairs(type(plates) == "table" and plates or {}) do
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(unit) == "string" then
      local threat, nm, q = UnitQuests(unit)
      if threat and q and #q > 0 then
        merge(q)
        any = true
        if nm ~= names then n = n + 1; names = names or nm end
      end
    end
  end
  if any then return titles, (n > 1) and (n .. " enemies") or names end
end

-- what the focus is now, as a string (to tell when it changes)
function ns.CombatFocusKey()
  local titles, name = ns.CombatQuests()
  if not titles then return "" end
  local t = {}
  for k in pairs(titles) do t[#t + 1] = k end
  table.sort(t)
  return (name or "") .. "|" .. table.concat(t, "|")
end

function ns.BuildSuggestions(logQuests)
  local db = ns.db
  local me = UnitLevel("player")
  local result = { quests = {}, turnin = {}, nearby = {}, pickup = {}, dungeons = {}, training = {} }

  -- Log quests: ready-to-turn-in first, then most XP. Gray quests are dropped.
  local quests = logQuests or LogQuests()
  -- in combat with a quest's creature: its quests are marked (and listed first, wherever they are)
  local focus, focusName = ns.CombatQuests()
  for _, q in ipairs(quests) do
    local objs = focus and not q.complete and focus[q.title]
    q.combat = objs and true or nil
    q.combatObjectives = objs or nil
    if objs then result.combatFocus = focusName or "your target" end
  end
  if db.activeZoneOnly then RefreshZone() end
  if db.turninZoneOnly and db.showTurnIn and not db.activeZoneOnly then RefreshZone() end
  local keep, turnin = {}, {}
  for _, q in ipairs(quests) do
    q.trivial = ns.IsTrivial(q.level)
    if q.complete and db.showTurnIn and not q.focused then
      -- Quests to Turn In: every finished quest, with its own zone filter
      -- (InZone goes by where it's turned in). The focused quest stays pinned in Active Quests.
      if db.turninZoneOnly and not InZone(q) then
        result.turninElsewhere = (result.turninElsewhere or 0) + 1
      else
        turnin[#turnin + 1] = q
      end
    else
      -- When replacing Blizzard's tracker, keep gray quests too (listed last) so none go missing.
      local otherZone = db.activeZoneOnly and not q.focused and not InZone(q)
      if q.combat then otherZone = false end -- (what you're fighting: shown wherever it is)
      -- (Blizzard's tracking ticks don't matter here: the Zone / All switch decides what shows)
      local wanted = q.complete or not q.trivial or db.replaceTracker or q.focused
      if wanted and not otherZone then keep[#keep + 1] = q
      elseif wanted then result.questsElsewhere = (result.questsElsewhere or 0) + 1 end
    end
  end
  table.sort(keep, function(a, b)
    if (a.combat or false) ~= (b.combat or false) then return a.combat or false end -- what you're fighting first
    if a.focused ~= b.focused then return a.focused end   -- focused quest pinned on top
    if db.sortByLevel then                                 -- highest level first
      if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
      return a.xp > b.xp
    end
    if a.complete ~= b.complete then return a.complete end
    if a.trivial ~= b.trivial then return not a.trivial end
    if a.xp ~= b.xp then return a.xp > b.xp end
    return (a.level or 0) < (b.level or 0)
  end)
  if db.showActive then
    for i = 1, math.min(db.maxQuests, #keep) do result.quests[i] = keep[i] end
  end
  table.sort(turnin, function(a, b)
    if db.sortByLevel and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    if a.xp ~= b.xp then return a.xp > b.xp end
    return (a.level or 0) < (b.level or 0)
  end)
  result.turnin = {}
  if db.showTurnIn then
    for i = 1, math.min(db.maxTurnIn or 20, #turnin) do result.turnin[i] = turnin[i] end
  end

  -- Quest items: usable items of your quests in this zone, the focused quest's first
  result.questItems = {}
  if db.showQuestItems then
    if not db.activeZoneOnly then RefreshZone() end
    local seen = {}
    local function add(q)
      if q.item and not seen[q.item.itemID] and #result.questItems < 3 then
        seen[q.item.itemID] = true
        result.questItems[#result.questItems + 1] = { itemID = q.item.itemID, icon = q.item.icon, title = q.title }
      end
    end
    for _, q in ipairs(quests) do if q.focused then add(q) end end
    for _, q in ipairs(quests) do if not q.complete and InZone(q) then add(q) end end
  end

  -- Quests Nearby: Questie's available quests (needs Questie; the game has no such list)
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
