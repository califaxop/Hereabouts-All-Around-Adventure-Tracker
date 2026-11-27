-- Hereabouts: shared namespace, settings and helpers.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end
function ns.Print(...) print("|cffffd200Hereabouts:|r", ...) end

ns.DEFAULTS = {
  maxQuests   = 8,      -- quest-log suggestions shown
  maxPickup   = 6,      -- "quests to pick up" shown (needs Questie)
  pickupZoneOnly = true,-- Quests to Pick Up: only quests whose quest giver is in your current zone
  zoneBonus   = 1.5,    -- quests in your current zone count as this much more XP (less travel)
  maxDungeons = 3,      -- dungeon suggestions shown
  dungeonZoneOnly = false, -- Dungeons: only those whose entrance is in your current zone
  -- sections to hide in dungeons / in combat (by section: quests, pickup, nearby, training, dungeons)
  hideInInstance = {},
  hideInCombat = {},
  sortByLevel = true,   -- list every section by level, highest first (off: XP / best-fit order)
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
  classicHeaders = false, -- section headings: the quest tracker's header art (the earlier look) instead of the clean line
  borderColor = { 0.40, 0.33, 0.22 },  -- brown, FlareUI-style
  maxHeight   = 400,    -- px; taller content scrolls
  showActive  = true,   -- "Active Quests" section
  activeZoneOnly = false, -- Active Quests: only quests in the zone you're in (focused quest always shown)
  animations = true,     -- soft animations: a progressed objective flashes, the combat mark fades in and out
  combatFocus = true,     -- in combat with a quest's creature: its quests highlighted light blue (in place)
  showPickup  = true,   -- "Quests to Pick Up" section (Questie)
  showObjectives = true,-- objective lines under active quests
  hideDoneObjectives = true, -- ...only the ones still to do
  showXP      = true,   -- XP line under quests
  showStarter = true,   -- quest giver + zone line under quests to pick up
  showSession = true,    -- the session bar under the tracker
  sessionStats = { xph = true, ttl = true, gph = true }, -- what it shows (see Session.lua's STATS)
  showQuestItems = true, -- a small button for a quest's usable item, left of its [level] in the list
  showTurnIn = true,     -- Quests to Turn In: finished quests get their own section (and leave Active Quests)
  maxTurnIn = 20,
  turninZoneOnly = false, -- ...only the ones turned in where you are
  pos         = nil,    -- nil = sit under the quest tracker
}

-- A deep copy (settings tables never share a table with ns.DEFAULTS: 1.7.0)
local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
ns.Copy = Copy

function ns.ResetDB()
  -- "Reset to defaults" keeps where the list is and the quests you've ignored
  local pos, ignored = HereaboutsDB.pos, HereaboutsDB.ignoredQuests
  wipe(HereaboutsDB)
  ns.LoadDB()
  HereaboutsDB.pos = pos
  HereaboutsDB.ignoredQuests = ignored or {}
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
  HereaboutsDB = HereaboutsDB or {}
  -- a setting that's missing gets a copy of its default. A table setting that's there is the
  -- player's as it is (in sessionStats, hideInCombat... a missing key means "off").
  -- (Before 1.7.0 the default tables themselves were handed out: changing a setting changed the
  -- default too, so "Reset to defaults" brought back your own choices, not the defaults.)
  for k, v in pairs(ns.DEFAULTS) do
    if HereaboutsDB[k] == nil then HereaboutsDB[k] = Copy(v) end
  end
  -- one-time: switch the old gray border to the new brown default
  if (HereaboutsDB.borderVersion or 1) < 2 then
    HereaboutsDB.borderColor = { 0.40, 0.33, 0.22 }
    HereaboutsDB.borderVersion = 2
  end
  HereaboutsDB.ignoredQuests = HereaboutsDB.ignoredQuests or {}
  ns.db = HereaboutsDB
end

-- Errors caught while building or drawing the list (1.7.0): each one printed the first time only
-- (before, every rebuild printed it again), all kept for /hab errors and /hab status: the last 10,
-- the same one again counted.
ns.errors = {}
function ns.NoteError(where, msg)
  msg = tostring(msg)
  for _, e in ipairs(ns.errors) do
    if e.where == where and e.msg == msg then e.n = e.n + 1; return end
  end
  if #ns.errors >= 10 then table.remove(ns.errors, 1) end
  ns.errors[#ns.errors + 1] = { where = where, msg = msg, n = 1 }
  ns.Print("error (" .. where .. "): " .. msg .. "  (/hab errors lists them)")
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
