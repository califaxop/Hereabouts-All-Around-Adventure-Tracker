-- XP Planner: shared namespace, settings and helpers.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end
function ns.Print(...) print("|cffffd200XP Planner:|r", ...) end

ns.DEFAULTS = {
  maxQuests   = 8,      -- quest-log suggestions shown
  maxPickup   = 6,      -- "quests to pick up" shown (needs Questie)
  pickupAllLevels = false, -- Quests to Pick Up: ignore the level range below (find quests you missed)
  levelMin    = -5,     -- Quests to Pick Up: lowest quest level, relative to yours (-8..+8)
  levelMax    = 3,      -- Quests to Pick Up: highest quest level, relative to yours (-8..+8)
  pickupZoneOnly = true,-- Quests to Pick Up: only quests whose quest giver is in your current zone
  zoneBonus   = 1.5,    -- quests in your current zone count as this much more XP (less travel)
  maxDungeons = 3,      -- dungeon suggestions shown
  dungeonZoneOnly = false, -- Dungeons: only those whose entrance is in your current zone
  -- sections to hide in dungeons / in combat (by section: quests, pickup, nearby, training, dungeons)
  hideInInstance = {},
  hideInCombat = {},
  sortByLevel = true,   -- list every section by level, highest first (off: XP / best-fit order)
  showNearby  = true,   -- include quests the map shows as available near you
  showDungeons = true,
  showTraining = true,  -- "Training" section (needs What's Training)
  maxTraining = 10,     -- spells shown in it
  showCityPrices = true, -- training: base cost plus each city's price with your reputation
  showNextLevel = true, -- also list spells coming at your next level (dimmed)
  collapsed   = false,
  locked      = true,   -- can't be dragged until unlocked
  replaceTracker = false, -- hide Blizzard's quest tracker and take its place
  scale       = 1.0,
  bgAlpha     = 0.5,    -- backdrop opacity behind the list (0 = none)
  showBorder  = true,   -- tooltip-style border; off = soft faded edges instead
  useFlareStyle = true, -- match FlareUI's look when FlareUI is installed
  borderColor = { 0.40, 0.33, 0.22 },  -- brown, FlareUI-style
  maxHeight   = 400,    -- px; taller content scrolls
  showActive  = true,   -- "Active Quests" section
  activeZoneOnly = false, -- Active Quests: only quests in the zone you're in (focused quest always shown)
  showPickup  = true,   -- "Quests to Pick Up" section (Questie)
  showObjectives = true,-- objective lines under active quests
  hideDoneObjectives = true, -- ...only the ones still to do
  showXP      = true,   -- XP line under quests
  showStarter = true,   -- quest giver + zone line under quests to pick up
  showTurnIn = true,     -- Quests to Turn In: finished quests get their own section (and leave Active Quests)
  maxTurnIn = 20,
  turninZoneOnly = false, -- ...only the ones turned in where you are
  pos         = nil,    -- nil = sit under the quest tracker
}

function ns.ResetDB()
  -- "Reset to defaults" keeps where the list is and the quests you've ignored
  local pos, ignored = XPPlannerDB.pos, XPPlannerDB.ignoredQuests
  wipe(XPPlannerDB)
  ns.LoadDB()
  XPPlannerDB.pos = pos
  XPPlannerDB.ignoredQuests = ignored or {}
end

-- Ignore list for "Quests to Pick Up": questID -> { name, level }
function ns.IgnoreQuest(id, name, level)
  ns.db.ignoredQuests[id] = { name = name, level = level }
  ns.Refresh()
  if ns.RefreshIgnored then ns.RefreshIgnored() end
end
function ns.UnignoreQuest(id)
  ns.db.ignoredQuests[id] = nil -- back in the list straight away if it still qualifies
  ns.Refresh()
  if ns.RefreshIgnored then ns.RefreshIgnored() end
end

function ns.LoadDB()
  XPPlannerDB = XPPlannerDB or {}
  for k, v in pairs(ns.DEFAULTS) do
    if XPPlannerDB[k] == nil then XPPlannerDB[k] = v end
  end
  -- one-time: switch the old gray border to the new brown default
  if (XPPlannerDB.borderVersion or 1) < 2 then
    XPPlannerDB.borderColor = { 0.40, 0.33, 0.22 }
    XPPlannerDB.borderVersion = 2
  end
  XPPlannerDB.ignoredQuests = XPPlannerDB.ignoredQuests or {}
  ns.db = XPPlannerDB
end

-- Quest difficulty color for a level, the same colors the quest log uses.
function ns.LevelColor(level)
  if GetQuestDifficultyColor and level and level > 0 then
    local ok, c = pcall(GetQuestDifficultyColor, level)
    if ok and c then return c.r, c.g, c.b end
  end
  return 1, 0.82, 0
end

-- Gray ("trivial") for you = little or no XP.
function ns.IsTrivial(level)
  if not level or level <= 0 then return false end
  local me = UnitLevel("player")
  if UnitQuestTrivialLevelRange then
    local ok, range = pcall(UnitQuestTrivialLevelRange, "player")
    if ok and type(range) == "number" then return level < me - range end
  end
  if GetQuestGreenRange then
    local ok, range = pcall(GetQuestGreenRange)
    if ok and type(range) == "number" then return level < me - range end
  end
  return level < me - 8
end
