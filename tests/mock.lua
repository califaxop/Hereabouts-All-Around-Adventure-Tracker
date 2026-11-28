-- A mock of the game client, just enough for Hereabouts' files to load and run (tests/run_tests.py).
-- Frames answer any method: CamelCase methods do nothing, Get* return nil, unless listed below.
MOCK = { now = 1000, clock = 1700000000, level = 20, xp = 100, xpMax = 1000, money = 5000, rested = 0,
  combat = false, events = {}, timers = {}, quests = {} }

issecretvalue = function() return false end

local function obj(name)
  local o = { _scripts = {}, _shown = true, _alpha = 1, _attr = {}, _points = {}, _name = name }
  if name then _G[name] = o end
  return setmetatable(o, { __index = function(_, k)
    local m = MOCK.methods[k]
    if m then return m end
    if type(k) ~= "string" or not k:find("^%u") or k:find("_") then return nil end
    if k:find("^Create") then return function() return obj() end end
    if k:find("^Get") or k:find("^Is") then return function() return nil end end
    return function() end
  end })
end
MOCK.obj = obj
MOCK.methods = {
  Show = function(s) s._shown = true end, Hide = function(s) s._shown = false end,
  SetShown = function(s, v) s._shown = v and true or false end,
  IsShown = function(s) return s._shown end, IsVisible = function(s) return s._shown end,
  SetAlpha = function(s, a) s._alpha = a end, GetAlpha = function(s) return s._alpha end,
  SetScript = function(s, n, f) s._scripts[n] = f end, HookScript = function(s, n, f) s._scripts[n] = f end,
  GetScript = function(s, n) return s._scripts[n] end,
  RegisterEvent = function(s, e) MOCK.events[e] = MOCK.events[e] or {}; table.insert(MOCK.events[e], s) end,
  RegisterUnitEvent = function(s, e) MOCK.events[e] = MOCK.events[e] or {}; table.insert(MOCK.events[e], s) end,
  SetAttribute = function(s, k, v)
    if MOCK.combat and s._protected then error("ADDON_ACTION_BLOCKED: SetAttribute in combat") end
    s._attr[k] = v
  end,
  GetAttribute = function(s, k) return s._attr[k] end,
  ClearAllPoints = function(s)
    if MOCK.combat and s._protected then error("ADDON_ACTION_BLOCKED: ClearAllPoints in combat") end
    s._points = {}
  end,
  SetPoint = function(s, ...)
    if MOCK.combat and s._protected then error("ADDON_ACTION_BLOCKED: SetPoint in combat") end
    s._points = { ... }
  end,
  GetName = function(s) return s._name end,
  SetText = function(s, t) s._text = t end, GetText = function(s) return s._text end,
  SetFormattedText = function(s, f, ...) s._text = string.format(f, ...) end,
  GetStringWidth = function() return 50 end, GetStringHeight = function() return 12 end,
  GetWidth = function() return 250 end, GetHeight = function() return 20 end,
  GetEffectiveScale = function() return 1 end, GetScale = function() return 1 end,
  GetFrameStrata = function() return "MEDIUM" end, GetFrameLevel = function() return 5 end,
  GetVerticalScroll = function() return 0 end,
  GetLeft = function(s) return s._left end, GetTop = function(s) return s._top end,
  GetBottom = function(s) return s._top and (s._top - 16) end,
  GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
  SetDesaturated = function(s, v) s._desat = v end,
}
CreateFrame = function(kind, name, parent, template)
  local o = obj(name)
  o._parent = parent
  if template and tostring(template):find("Secure") then o._protected = true end
  return o
end
UIParent = obj("UIParent"); GameTooltip = obj("GameTooltip"); WorldFrame = obj("WorldFrame")
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormalSmall",
  "ObjectiveTrackerFont12", "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont", "NumberFontNormalSmall",
  "GameFontNormalLarge", "GameFontDisable", "GameFontDisableSmall" }) do obj(n) end

-- player -------------------------------------------------------------------------------------
UnitLevel = function() return MOCK.level end
UnitXP = function() return MOCK.xp end
UnitXPMax = function() return MOCK.xpMax end
GetXPExhaustion = function() return MOCK.rested > 0 and MOCK.rested or nil end
GetMoney = function() return MOCK.money end
UnitAffectingCombat = function() return MOCK.combat end
InCombatLockdown = function() return MOCK.combat end
UnitName = function() return "Tester" end
UnitClass = function() return "Warrior", "WARRIOR" end
GetBuildInfo = function() return "1.60.1", "12345", "Nov 1 2026", 16001 end
UnitExists = function() return false end
IsInInstance = function() return false end
GetRealZoneText = function() return "Elwynn Forest" end
GetTime = function() return MOCK.now end
time = function() return MOCK.clock end
date = os.date

-- quest log (MOCK.quests: list of { questID, title, level, complete, item })
C_QuestLog = {
  GetNumQuestLogEntries = function() return #MOCK.quests end,
  GetLogIndexForQuestID = function(id) for i, q in ipairs(MOCK.quests) do if q.questID == id then return i end end end,
  IsQuestFlaggedCompleted = function() return false end,
  GetInfo = function(i) local q = MOCK.quests[i]; if q then return { title = q.title, questID = q.questID, level = q.level, isHeader = false } end end,
  IsComplete = function(id) for _, q in ipairs(MOCK.quests) do if q.questID == id then return q.complete end end return false end,
  GetQuestObjectives = function() return {} end,
}
C_Map = { GetBestMapForUnit = function() return 1429 end, GetMapInfo = function() return { name = "Elwynn Forest", mapType = 3 } end,
  GetAreaInfo = function() return nil end }
C_Item = { GetItemCount = function(id) return (MOCK.items or {})[id] or 1 end, GetItemIconByID = function() return 134400 end }
C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "test" end }

-- timers and events ---------------------------------------------------------------------------
C_Timer = {
  After = function(_, fn) MOCK.timers[#MOCK.timers + 1] = fn end,
  NewTicker = function(_, fn) return { Cancel = function() end } end,
}
function MOCK.RunTimers()
  for _ = 1, 20 do
    local t = MOCK.timers; MOCK.timers = {}
    if #t == 0 then return end
    for _, fn in ipairs(t) do fn() end
  end
end
function MOCK.Fire(event, ...)
  for _, f in ipairs(MOCK.events[event] or {}) do
    if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

-- the rest -------------------------------------------------------------------------------------
format = string.format; tinsert = table.insert; strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
hooksecurefunc = function(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  local old = t[name]
  t[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
BreakUpLargeNumbers = function(n) return tostring(n) end
SlashCmdList = {}; UISpecialFrames = {}
-- Blizzard's slider with steppers (Blizzard_SharedXML): the keys its Init and callbacks take
MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end PRINTS[#PRINTS + 1] = table.concat(t, " ") end
CreateFont = function(name) return obj(name) end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGBA = function(s) return s.r, s.g, s.b, s.a end } end
