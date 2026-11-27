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
  sessionStats = { xph = true, gph = true }, -- the bars it shows (Session.lua's STATS)
  showQuestItems = true, -- a small button for a quest's usable item, left of its [level] in the list
  showTurnIn = true,     -- Quests to Turn In: finished quests get their own section (and leave Active Quests)
  maxTurnIn = 20,
  turninZoneOnly = false, -- ...only the ones turned in where you are
  pos         = nil,    -- nil = sit under the quest tracker
  sectionOrder = { "quests", "turnin", "pickup", "training", "dungeons" }, -- top to bottom (1.12.0)
}

-- The tracker's sections as modules (1.12.0): each with its own settings (shown, how many, only
-- this zone), drawn in the order of `sectionOrder`. `ns.MODULES` is the list of them.
ns.MODULES = {
  { key = "quests", name = "Active Quests", show = "showActive", max = "maxQuests", zone = "activeZoneOnly" },
  { key = "turnin", name = "Quests to Turn In", show = "showTurnIn", max = "maxTurnIn", zone = "turninZoneOnly" },
  { key = "pickup", name = "Quests Nearby", show = "showPickup", max = "maxPickup", zone = "pickupZoneOnly" },
  { key = "training", name = "Training", show = "showTraining", max = "maxTraining" },
  { key = "dungeons", name = "Dungeons", show = "showDungeons", max = "maxDungeons", zone = "dungeonZoneOnly" },
}

-- The sections' order: the saved one, with any section it lacks added at the end and anything
-- unknown or doubled dropped (an order saved by an older version, or a damaged one, still works)
function ns.SectionOrder()
  local known, out, seen = {}, {}, {}
  for _, m in ipairs(ns.MODULES) do known[m.key] = true end
  for _, k in ipairs(type(ns.db.sectionOrder) == "table" and ns.db.sectionOrder or {}) do
    if known[k] and not seen[k] then seen[k] = true; out[#out + 1] = k end
  end
  for _, m in ipairs(ns.MODULES) do if not seen[m.key] then out[#out + 1] = m.key end end
  return out
end
-- a section one place up (by = -1) or down (1)
function ns.MoveSection(key, by)
  local order = ns.SectionOrder()
  for i, k in ipairs(order) do
    if k == key and order[i + by] then
      order[i], order[i + by] = order[i + by], order[i]
      break
    end
  end
  ns.db.sectionOrder = order
end

-- Layouts (1.12.0): what the tracker shows and how, without its look (position, scale, colours,
-- border stay as they are). Saved into one of three slots (HereaboutsDB.layouts, kept by "Reset to
-- defaults"), or set from a preset.
ns.LAYOUT_KEYS = { "sectionOrder", "hideInInstance", "hideInCombat", "showSession", "sessionStats",
  "showObjectives", "hideDoneObjectives", "showXP", "showStarter", "showNextLevel", "showCityPrices" }
for _, m in ipairs(ns.MODULES) do
  for _, f in ipairs({ "show", "max", "zone" }) do if m[f] then table.insert(ns.LAYOUT_KEYS, m[f]) end end
end
ns.LAYOUT_SLOTS = 3
-- built-in layouts: { key, name, what it's for, settings (the rest: the defaults) }
ns.PRESETS = {
  { "questing", "Questing", "Everything, as it comes (the defaults).", {} },
  { "zone", "This zone", "Only what's here: active quests, turn-ins and quests to pick up in your zone; no training or dungeons.",
    { activeZoneOnly = true, turninZoneOnly = true, pickupZoneOnly = true, showTraining = false, showDungeons = false } },
  { "dungeon", "Dungeons", "Dungeons and your quests first; nothing to pick up; turn-ins and training hidden inside dungeons.",
    { sectionOrder = { "dungeons", "quests", "turnin", "pickup", "training" }, showPickup = false,
      hideInInstance = { turnin = true, training = true, dungeons = true } } },
  { "minimal", "Minimal", "Active quests only (5), what's left to do, no XP lines, no session bar.",
    { showTurnIn = false, showPickup = false, showTraining = false, showDungeons = false, maxQuests = 5,
      showXP = false, showSession = false, hideDoneObjectives = true } },
  { "leveling", "Leveling", "Quests first, XP lines and the session's XP rate; training at your next level too.",
    { showXP = true, showNextLevel = true, sessionStats = { xph = true, xp = true, rested = true } } },
}

local function Layout(src)
  local t = {}
  for _, k in ipairs(ns.LAYOUT_KEYS) do t[k] = ns.Copy(src[k]) end
  return t
end
local function ApplyLayout(t)
  for _, k in ipairs(ns.LAYOUT_KEYS) do
    if t[k] ~= nil then ns.db[k] = ns.Copy(t[k]) else ns.db[k] = ns.Copy(ns.DEFAULTS[k]) end
  end
end
function ns.SaveLayout(slot)
  ns.db.layouts = type(ns.db.layouts) == "table" and ns.db.layouts or {}
  ns.db.layouts[slot] = { savedAt = time and time() or 0, values = Layout(ns.db) }
end
function ns.LoadLayout(slot)
  local l = type(ns.db.layouts) == "table" and ns.db.layouts[slot]
  if type(l) ~= "table" or type(l.values) ~= "table" then return false end
  ApplyLayout(l.values)
  return true
end
function ns.ApplyPreset(key)
  for _, p in ipairs(ns.PRESETS) do
    if p[1] == key then
      local t = Layout(ns.DEFAULTS)
      for k, v in pairs(p[4]) do t[k] = v end
      ApplyLayout(t)
      return true
    end
  end
  return false
end

-- A deep copy (settings tables never share a table with ns.DEFAULTS: 1.7.0)
local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
ns.Copy = Copy

function ns.ResetDB()
  -- "Reset to defaults" keeps where the list is, the quests you've ignored and your saved layouts
  local pos, ignored, layouts = HereaboutsDB.pos, HereaboutsDB.ignoredQuests, HereaboutsDB.layouts
  wipe(HereaboutsDB)
  ns.LoadDB()
  HereaboutsDB.pos = pos
  HereaboutsDB.ignoredQuests = ignored or {}
  HereaboutsDB.layouts = layouts
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
  -- 2.0.0: the session's separate stats folded into its XP and gold bars (here and in saved layouts)
  ns.Session.FoldStats(HereaboutsDB.sessionStats)
  for _, l in pairs(type(HereaboutsDB.layouts) == "table" and HereaboutsDB.layouts or {}) do
    if type(l) == "table" and type(l.values) == "table" then ns.Session.FoldStats(l.values.sessionStats) end
  end
  ns.db = HereaboutsDB
end

-- How long things take (2.0.0, /hab perf): ms, precise where the game offers it
function ns.Clock() return debugprofilestop and debugprofilestop() or (GetTime() * 1000) end
-- each kind: { n, ms, max }; since: when counting began (GetTime)
ns.perf = { since = 0 }
function ns.Measure(kind, ms)
  local p = ns.perf[kind] or { n = 0, ms = 0, max = 0 }
  ns.perf[kind] = p
  p.n, p.ms, p.max = p.n + 1, p.ms + ms, math.max(p.max, ms)
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
