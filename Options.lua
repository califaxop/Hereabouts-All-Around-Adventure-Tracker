-- XP Planner: settings window (/xpp, or Esc > Options > AddOns > XP Planner), drawn in the
-- tracker's own style: its border, background, fonts and colours (FlareUI's when that style is on).
local _, ns = ...

local W = "Interface\\Buttons\\WHITE8X8"

local function Changed() ns.Refresh() end

---------------------------------------------------------------------------
-- Styling: every widget registers a paint function, re-run when the tracker's style changes
---------------------------------------------------------------------------
local skins = {}
local function Skin(fn) skins[#skins + 1] = fn; fn(ns.Theme()) end
function ns.RestyleOptions()
  local th = ns.Theme()
  for _, fn in ipairs(skins) do fn(th) end
end
local function RGB(c, a) return c[1], c[2], c[3], a or 1 end

-- text in one of the tracker's roles: "title", "header", "line", "value", "note"
local function Text(parent, role, str)
  -- created with a font, and the text set only after the theme's font is applied:
  -- WoW refuses SetText on a font string that has no font yet
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  Skin(function(th)
    if role == "header" then fs:SetFontObject(th.headerFont); fs:SetTextColor(RGB(th.header))
    elseif role == "title" then fs:SetFontObject(th.headerFont); fs:SetTextColor(RGB(th.title))
    elseif role == "value" then fs:SetFontObject(th.lineFont); fs:SetTextColor(RGB(th.title))
    elseif role == "note" then fs:SetFontObject("GameFontHighlightSmall"); fs:SetTextColor(RGB(th.dim))
    else fs:SetFontObject(th.lineFont); fs:SetTextColor(RGB(th.line)) end
  end)
  fs:SetText(str or "")
  return fs
end

-- a section heading with the tracker's divider under it; returns the y below it
local function Section(parent, str, x, y, width)
  Text(parent, "header", str):SetPoint("TOPLEFT", x, y)
  local div = parent:CreateTexture(nil, "ARTWORK")
  div:SetPoint("TOPLEFT", x, y - 18)
  div:SetWidth(width)
  Skin(function(th)
    if th.flare then
      div:SetTexture(th.divider); div:SetVertexColor(1, 1, 1, 1); div:SetHeight(8)
    else
      div:SetColorTexture(RGB(th.accent, 0.7)); div:SetHeight(1)
    end
  end)
  return y - 30
end

local function Note(parent, str, x, y, width)
  local n = Text(parent, "note", str)
  n:SetPoint("TOPLEFT", x, y); n:SetWidth(width or 220)
  return n
end

-- a setting in ns.db; onSet runs after it changes
-- returned as a { get, set } pair (Lua drops a second return value mid-argument-list)
local function Setting(key, onSet)
  return { function() return ns.db[key] end,
    function(v) ns.db[key] = v; if onSet then onSet(v) end end }
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
-- checkbox: a small bordered square with a gold tick, label in the tracker's line font
local function Check(parent, label, x, y, opt, width)
  local get, set = opt[1], opt[2]
  local b = CreateFrame("Button", nil, parent)
  b:SetPoint("TOPLEFT", x, y); b:SetSize(width or 220, 20)
  local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
  box:SetSize(14, 14); box:SetPoint("LEFT", 0, 0)
  box:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  mark:SetSize(20, 20); mark:SetPoint("CENTER", 1, 1)
  local text = Text(b, "line", label)
  text:SetPoint("LEFT", box, "RIGHT", 7, 0); text:SetPoint("RIGHT", 0, 0)
  local active, hover = true, false
  local function paint(th)
    th = th or ns.Theme()
    box:SetBackdropColor(0, 0, 0, 0.55)
    box:SetBackdropBorderColor(RGB(th.accent, hover and active and 1 or 0.8))
    mark:SetVertexColor(RGB(th.title))
    text:SetTextColor(RGB((hover and active) and th.hover or th.line))
  end
  Skin(paint)
  b:SetScript("OnEnter", function() hover = true; paint() end)
  b:SetScript("OnLeave", function() hover = false; paint() end)
  b:SetScript("OnClick", function()
    if not active then return end
    set(not get()); b.Refresh(); Changed()
  end)
  b.Refresh = function() mark:SetShown(get() and true or false); paint() end
  b.SetActive = function(on) active = on; b:SetAlpha(on and 1 or 0.4); paint() end
  return b
end

-- slider: name on the left, value on the right, a thin bronze track with a gold handle
local function Slider(parent, label, x, y, width, minV, maxV, step, opt, fmt)
  local get, set = opt[1], opt[2]
  -- label nil = inline: the slider sits on the line at y, its value to its right
  local name = label and Text(parent, "line", label)
  local value = Text(parent, "value", "")
  local s = CreateFrame("Slider", nil, parent)
  s:SetSize(width, 14)
  if label then
    name:SetPoint("TOPLEFT", x, y)
    value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y); value:SetJustifyH("RIGHT")
    s:SetPoint("TOPLEFT", x, y - 18)
  else
    s:SetPoint("TOPLEFT", x, y - 3)
    value:SetPoint("LEFT", s, "RIGHT", 10, 0)
  end
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
  local trackBg = s:CreateTexture(nil, "BACKGROUND")
  trackBg:SetTexture(W); trackBg:SetHeight(4)
  trackBg:SetPoint("LEFT"); trackBg:SetPoint("RIGHT")
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(W); fill:SetHeight(4); fill:SetPoint("LEFT")
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(W); thumb:SetSize(7, 14)
  s:SetThumbTexture(thumb)
  local function paintFill(v)
    local f = (maxV > minV) and (v - minV) / (maxV - minV) or 0
    fill:SetWidth(math.max(1, f * width))
  end
  Skin(function(th)
    trackBg:SetVertexColor(RGB(th.box, 0.35))
    fill:SetVertexColor(RGB(th.accent, 0.9))
    thumb:SetVertexColor(RGB(th.title))
  end)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
  local refreshing = false
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    value:SetText(fmt(v)); paintFill(v)
    if refreshing or get() == v then return end
    set(v); Changed()
  end)
  s.Refresh = function()
    refreshing = true
    s:SetValue(get()); value:SetText(fmt(get())); paintFill(get())
    refreshing = false
  end
  s.SetActive = function(on)
    s:SetEnabled(on)
    for _, r in ipairs({ s, name or s, value }) do r:SetAlpha(on and 1 or 0.4) end
  end
  return s
end

-- flat button in the tracker's bronze
local function Button(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 22)
  b:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  local fs = Text(b, "line", label)
  fs:SetPoint("CENTER"); fs:SetJustifyH("CENTER")
  local hover = false
  local function paint(th)
    th = th or ns.Theme()
    b:SetBackdropColor(RGB(th.box, hover and 0.55 or 0.3))
    b:SetBackdropBorderColor(RGB(th.accent, hover and 1 or 0.8))
    fs:SetTextColor(RGB(hover and th.hover or th.title))
  end
  Skin(paint)
  b:SetScript("OnEnter", function() hover = true; paint() end)
  b:SetScript("OnLeave", function() hover = false; paint() end)
  b:SetScript("OnClick", onClick)
  b.SetLabel = function(t) fs:SetText(t) end
  return b
end

-- "×" close button in the corner
local function CloseButton(win)
  local b = CreateFrame("Button", nil, win)
  b:SetSize(22, 22); b:SetPoint("TOPRIGHT", -8, -8)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  fs:SetPoint("CENTER"); fs:SetText("\195\151")
  local hover = false
  local function paint(th) th = th or ns.Theme(); fs:SetTextColor(RGB(hover and th.hover or th.header)) end
  Skin(paint)
  b:SetScript("OnEnter", function() hover = true; paint() end)
  b:SetScript("OnLeave", function() hover = false; paint() end)
  b:SetScript("OnClick", function() win:Hide() end)
  return b
end

local function Window(name, width, height)
  local win = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  win:SetSize(width, height)
  win:SetFrameStrata("DIALOG")
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetClampedToScreen(true)
  tinsert(UISpecialFrames, name) -- Esc closes it
  Skin(function() ns.SkinWindow(win, 0.96) end)
  CloseButton(win)
  return win
end

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

---------------------------------------------------------------------------
-- The settings window: a tab per topic
---------------------------------------------------------------------------
local window, refreshers, statusUpdate, ignUpdate = nil, {}, nil, nil
local PAGE_W, COL2 = 468, 244

local function track(x) refreshers[#refreshers + 1] = x; return x end

function ns.RefreshOptions()
  if not (window and window:IsShown()) then return end
  for _, x in ipairs(refreshers) do x.Refresh() end
  if statusUpdate then statusUpdate() end
  if ignUpdate then ignUpdate() end
end

local function Restyle() ns.ApplyBackdrop(); ns.RestyleOptions(); ns.RefreshOptions() end

local function PageTracker(p)
  local y = Section(p, "Position", 0, 0, 220)
  track(Check(p, "Lock in place", 0, y, Setting("locked")))
  track(Check(p, "Replace Blizzard's quest tracker", 0, y - 24, Setting("replaceTracker", function() ns.ApplyReplace() end)))
  track(Check(p, "Hide the list", 0, y - 48, Setting("hidden")))
  local under = Button(p, "Move under quest tracker", 200, function() ns.db.pos = nil; ns.PlaceFrame(); Changed() end)
  under:SetPoint("TOPLEFT", 0, y - 80)
  Note(p, "Unlock, then drag a section heading to move the list.", 0, y - 110, 220)

  y = Section(p, "Look", COL2, 0, 224)
  track(Check(p, "FlareUI style (needs FlareUI)", COL2, y, Setting("useFlareStyle", Restyle), 224))
  local border = track(Check(p, "Border (without FlareUI style)", COL2, y - 24, Setting("showBorder", Restyle), 224))
  local r = border.Refresh
  border.Refresh = function() r(); border.SetActive(not ns.UsingFlare()) end
  track(Slider(p, "Scale", COL2, y - 58, 224, 0.6, 1.5, 0.05, Setting("scale", function() ns.PlaceFrame() end), pct))
  track(Slider(p, "Background opacity", COL2, y - 100, 224, 0, 1, 0.05, Setting("bgAlpha", function() ns.ApplyBackdrop() end), pct))
  track(Slider(p, "Max height (then scrolls)", COL2, y - 142, 224, 120, 900, 10, Setting("maxHeight"),
    function(v) return v .. " px" end))

  -- which sections show in dungeons and in combat (ticked = shown)
  y = Section(p, "Show in dungeons and in combat", 0, -224, PAGE_W)
  local C1, C2 = 300, 390
  Text(p, "note", "In dungeons"):SetPoint("TOPLEFT", C1 - 22, y)
  Text(p, "note", "In combat"):SetPoint("TOPLEFT", C2 - 18, y)
  y = y - 18
  local function Shown(tbl, key)
    return { function() return not (ns.db[tbl] and ns.db[tbl][key]) end,
      function(v) ns.db[tbl] = ns.db[tbl] or {}; ns.db[tbl][key] = (not v) or nil end }
  end
  for i, sec in ipairs({ { "quests", "Active Quests" }, { "pickup", "Quests to Pick Up" }, { "training", "Training" },
      { "dungeons", "Dungeons" }, { "nearby", "Available Nearby (without Questie)" } }) do
    local ry = y - (i - 1) * 22
    Text(p, "line", sec[2]):SetPoint("TOPLEFT", 0, ry - 2)
    track(Check(p, nil, C1, ry, Shown("hideInInstance", sec[1]), 24))
    track(Check(p, nil, C2, ry, Shown("hideInCombat", sec[1]), 24))
  end
end

local function PageLists(p)
  local y = Section(p, "What to list", 0, 0, PAGE_W)
  local count = function(v) return "up to " .. v end
  -- one row per section: on/off on the left, how many on the right; options indented under it
  local function Row(label, key, maxKey, maxV, ry)
    local s = maxKey and Slider(p, nil, COL2, ry, 150, 1, maxV, 1, Setting(maxKey), count)
    local c = Check(p, label, 0, ry, { function() return ns.db[key] end, function(v)
      ns.db[key] = v; ns.RefreshOptions() -- greys out its slider and options
    end }, 230)
    track(c)
    if s then
      track(s)
      local r = c.Refresh
      c.Refresh = function() r(); s.SetActive(ns.db[key] and true or false) end
    end
    return c
  end
  local function Sub(label, key, parentKey, ry)
    local c = Check(p, label, 22, ry, Setting(key), 208)
    track(c)
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db[parentKey] and true or false) end
    return c
  end
  Row("Active Quests", "showActive", "maxQuests", 20, y)
  Sub("Only quests in my current zone", "activeZoneOnly", "showActive", y - 24)
  Sub("Hide quests I'm not tracking", "hideUntracked", "showActive", y - 46)
  local ready = track(Check(p, "Always show ready to turn in", COL2, y - 24, Setting("showAllReady"), 224))
  local rr = ready.Refresh
  ready.Refresh = function() rr(); ready.SetActive(ns.db.showActive and true or false) end
  Row("Quests to Pick Up (Questie)", "showPickup", "maxPickup", 20, y - 76)
  Row("Dungeons", "showDungeons", "maxDungeons", 6, y - 106)
  Sub("Only dungeons in my current zone", "dungeonZoneOnly", "showDungeons", y - 130)
  Row("Training (What's Training)", "showTraining", "maxTraining", 30, y - 160)
  Sub("Also spells at my next level", "showNextLevel", "showTraining", y - 184)
  Row("Map's nearby quests (without Questie)", "showNearby", nil, nil, y - 214)

  y = Section(p, "Details", 0, y - 252, PAGE_W)
  track(Check(p, "Sort by level (highest first)", 0, y, Setting("sortByLevel")))
  local objectives = track(Check(p, "Objectives under active quests", 0, y - 24, Setting("showObjectives", function() ns.RefreshOptions() end)))
  local hideDone = track(Check(p, "Hide finished objectives", 22, y - 48, Setting("hideDoneObjectives"), 208))
  local hr = hideDone.Refresh
  hideDone.Refresh = function() hr(); hideDone.SetActive(ns.db.showObjectives and true or false) end
  track(Check(p, "XP reward", COL2, y, Setting("showXP"), 224))
  track(Check(p, "Quest giver and zone", COL2, y - 24, Setting("showStarter"), 224))
  track(Check(p, "Training prices by city", COL2, y - 48, Setting("showCityPrices"), 224))
end

local function PagePicking(p)
  local y = Section(p, "Which quests to suggest", 0, 0, PAGE_W)
  track(Check(p, "Only quests from my current zone", 0, y, Setting("pickupZoneOnly"), 300))
  local signed = function(v) return v == 0 and "your level" or ((v > 0 and "+" or "") .. v) end
  track(Slider(p, "Lowest quest level", 0, y - 34, 220, -8, 8, 1,
    Setting("levelMin", function(v) if v > ns.db.levelMax then ns.db.levelMax = v; ns.RefreshOptions() end end), signed))
  track(Slider(p, "Highest quest level", COL2, y - 34, 224, -8, 8, 1,
    Setting("levelMax", function(v) if v < ns.db.levelMin then ns.db.levelMin = v; ns.RefreshOptions() end end), signed))
  track(Slider(p, "Current-zone bonus", 0, y - 80, 220, 1, 3, 0.1, Setting("zoneBonus"),
    function(v) return format("x%.1f", v) end))
  Note(p, "Quests in your zone rank higher, since there's less travel.", COL2, y - 84, 224)

  y = Section(p, "Ignored quests", 0, y - 132, PAGE_W)
  local count = Text(p, "line", "")
  count:SetPoint("TOPLEFT", 0, y - 4)
  local manage = Button(p, "Manage...", 120, function() ns.OpenIgnored() end)
  manage:SetPoint("TOPLEFT", COL2, y)
  Note(p, "Right-click a quest under Quests to Pick Up to ignore it.", 0, y - 30, PAGE_W)
  ignUpdate = function()
    local n = 0
    for _ in pairs(ns.db.ignoredQuests or {}) do n = n + 1 end
    count:SetText(n == 0 and "No quests ignored." or format(n == 1 and "%d quest ignored." or "%d quests ignored.", n))
  end
end

local function PageStatus(p)
  local y = Section(p, "Connected addons", 0, 0, PAGE_W)
  local rows = {}
  local NAMES = { "Questie", "What's Training", "FlareUI", "TomTom" }
  for i, n in ipairs(NAMES) do
    local ry = y - (i - 1) * 26
    local dot = p:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(W); dot:SetSize(8, 8); dot:SetPoint("TOPLEFT", 2, ry - 5)
    local name = Text(p, "line", n); name:SetPoint("TOPLEFT", 18, ry)
    local state = Text(p, "note", ""); state:SetPoint("TOPLEFT", 150, ry - 1); state:SetWidth(318)
    rows[n] = { dot = dot, state = state }
  end
  local function set(n, color, str)
    local r = rows[n]
    r.dot:SetVertexColor(color[1], color[2], color[3])
    r.state:SetText(str)
  end
  local GREEN, YELLOW, GREY = { 0.35, 0.9, 0.35 }, { 1, 0.82, 0.2 }, { 0.45, 0.45, 0.45 }
  local function loaded(a) return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(a))
    or (IsAddOnLoaded and IsAddOnLoaded(a)) end

  local level = Text(p, "line", "")
  level:SetPoint("TOPLEFT", 0, y - 112)

  statusUpdate = function()
    local q = ns.Questie
    if not q.Installed() then set("Questie", GREY, "Not installed: Quests to Pick Up uses the map's nearby quests.")
    elseif not q.Available() then set("Questie", YELLOW, "Loading...")
    elseif q.IsScanning() then set("Questie", YELLOW, "Scanning quests...")
    else set("Questie", GREEN, format("Connected: %d quests you can pick up.", q.Count())) end
    local tr = ns.Training
    if not tr.Installed() then set("What's Training", GREY, "Not installed: no Training section.")
    elseif not tr.Ready() then set("What's Training", YELLOW, "Loading...")
    else set("What's Training", GREEN, "Connected.") end
    if ns.FlareBorder() then set("FlareUI", GREEN, ns.UsingFlare() and "Connected: its style is on." or "Installed: its style is off (Tracker tab).")
    else set("FlareUI", GREY, "Not installed: the plain style is used.") end
    if loaded("TomTom") then set("TomTom", GREEN, "Connected: Show on Map also sets its arrow.")
    else set("TomTom", GREY, "Not installed: Show on Map uses the game's map pin.") end
    level:SetText(format("Your level: %d", UnitLevel("player")))
  end

  local rescan = Button(p, "Rescan Questie", 130, function() ns.Questie.Scan(); statusUpdate() end)
  rescan:SetPoint("TOPLEFT", 0, y - 140)

  y = Section(p, "Reset", 0, y - 190, PAGE_W)
  local reset = Button(p, "Reset to defaults", 130, function()
    ns.ResetDB(); ns.PlaceFrame(); ns.Questie.RescanSoon(); Restyle(); Changed(); ns.RefreshOptions()
  end)
  reset:SetPoint("TOPLEFT", 0, y)
  Note(p, "Keeps where the list is and the quests you've ignored.", 140, y - 5, 320)
end

local TABS = {
  { "Tracker", PageTracker },
  { "Lists", PageLists },
  { "Picking Quests", PagePicking },
  { "Status", PageStatus },
}

local function BuildWindow()
  window = Window("XPPlannerOptionsWindow", 520, 500)
  window:SetPoint("CENTER")
  local title = Text(window, "title", "XP Planner")
  title:SetPoint("TOPLEFT", 26, -20)
  local sub = Text(window, "note", "Where your next XP is: quests, dungeons and training.")
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)

  -- tabs: text in the heading font, the active one underlined in bronze
  local tabs, pages = {}, {}
  local current = 1
  local x = 26
  local line = window:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 26, -72); line:SetPoint("TOPRIGHT", -26, -72); line:SetHeight(1)
  local function paintTabs(th)
    th = th or ns.Theme()
    line:SetColorTexture(RGB(th.accent, 0.5))
    for i, t in ipairs(tabs) do
      local on = (i == current)
      t.text:SetTextColor(RGB(on and th.title or (t.hover and th.hover or th.dim)))
      t.bar:SetColorTexture(RGB(th.accent)); t.bar:SetShown(on)
    end
  end
  local function Select(i)
    current = i
    for k, pg in ipairs(pages) do pg:SetShown(k == i) end
    paintTabs()
  end
  for i, def in ipairs(TABS) do
    local t = CreateFrame("Button", nil, window)
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.text:SetFontObject(ns.Theme().headerFont); t.text:SetText(def[1])
    t.text:SetPoint("BOTTOM", 0, 6)
    local w = math.max(60, math.floor((t.text:GetStringWidth() or 0) + 0.5) + 20)
    t:SetSize(w, 26); t:SetPoint("BOTTOMLEFT", window, "TOPLEFT", x, -72)
    t.bar = t:CreateTexture(nil, "OVERLAY")
    t.bar:SetHeight(2); t.bar:SetPoint("BOTTOMLEFT", 6, 0); t.bar:SetPoint("BOTTOMRIGHT", -6, 0)
    t:SetScript("OnClick", function() Select(i) end)
    t:SetScript("OnEnter", function() t.hover = true; paintTabs() end)
    t:SetScript("OnLeave", function() t.hover = false; paintTabs() end)
    tabs[i] = t
    x = x + w + 4

    local pg = CreateFrame("Frame", nil, window)
    pg:SetPoint("TOPLEFT", 26, -88); pg:SetSize(PAGE_W, 390)
    def[2](pg)
    pg:Hide()
    pages[i] = pg
  end
  Skin(function(th)
    for _, t in ipairs(tabs) do t.text:SetFontObject(th.headerFont) end
    paintTabs(th)
  end)
  Select(1)

  window:SetScript("OnShow", function() ns.RefreshOptions() end)
  local t = 0
  window:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    if t > 1 then t = 0; if statusUpdate then statusUpdate() end end
  end)
  window:Hide()
end

function ns.OpenOptions()
  if not window then
    local ok, e = pcall(BuildWindow)
    if not ok then if window then window:Hide() end; window = nil; ns.Print("settings failed: " .. tostring(e)); return end
  end
  ns.RestyleOptions()
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end

-- Esc > Options > AddOns: a short page with a button that opens the window
local settingsPanel
function ns.CreateOptions()
  if settingsPanel then return end
  settingsPanel = CreateFrame("Frame")
  settingsPanel.name = "XP Planner"
  pcall(function()
    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText("XP Planner")
    local b = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    b:SetSize(200, 24); b:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    b:SetText("Open XP Planner settings")
    b:SetScript("OnClick", function()
      if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
      if not (window and window:IsShown()) then ns.OpenOptions() end
    end)
    local hint = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -8); hint:SetText("Or type /xpp.")
    if Settings and Settings.RegisterCanvasLayoutCategory then
      Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name))
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(settingsPanel)
    end
  end)
end

---------------------------------------------------------------------------
-- Ignored Quests window: every quest you ignored from "Quests to Pick Up".
-- Remove one and it returns to the list right away if it still qualifies.
---------------------------------------------------------------------------
local ignWin, ignRows = nil, {}
local ROW_H = 24

local function BuildIgnored()
  ignWin = Window("XPPlannerIgnoredWindow", 360, 380)
  ignWin:SetPoint("CENTER", 300, 0)
  Text(ignWin, "title", "Ignored Quests"):SetPoint("TOPLEFT", 22, -20)
  Note(ignWin, "Removed quests come back to Quests to Pick Up if they still qualify.", 22, -44, 316)
  local line = ignWin:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 22, -70); line:SetPoint("TOPRIGHT", -22, -70); line:SetHeight(1)
  Skin(function(th) line:SetColorTexture(RGB(th.accent, 0.5)) end)

  local scroll = CreateFrame("ScrollFrame", nil, ignWin)
  scroll:SetPoint("TOPLEFT", 22, -80)
  scroll:SetPoint("BOTTOMRIGHT", -22, 50)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(316, 1)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * ROW_H * 2)))
  end)
  ignWin.content = content

  ignWin.empty = Text(content, "note", "No ignored quests.")
  ignWin.empty:SetPoint("TOPLEFT", 0, -4)

  local clear = Button(ignWin, "Clear all", 100, function()
    wipe(ns.db.ignoredQuests); ns.Refresh(); ns.RefreshIgnored()
  end)
  clear:SetPoint("BOTTOMLEFT", 22, 18)
end

function ns.RefreshIgnored()
  if ignUpdate then ignUpdate() end
  if not (ignWin and ignWin:IsShown()) then return end
  local list = {}
  for id, info in pairs(ns.db.ignoredQuests) do
    list[#list + 1] = { id = id, name = info.name or ("Quest " .. id), level = info.level }
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  for i, q in ipairs(list) do
    local r = ignRows[i]
    if not r then
      r = CreateFrame("Frame", nil, ignWin.content)
      r:SetSize(316, ROW_H)
      r.text = Text(r, "line", "")
      r.text:SetPoint("LEFT"); r.text:SetPoint("RIGHT", -84, 0)
      r.text:SetWordWrap(false)
      r.remove = Button(r, "Remove", 76, nil)
      r.remove:SetPoint("RIGHT")
      ignRows[i] = r
    end
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r.text:SetText((q.level and format("[%d] ", q.level) or "") .. q.name)
    r.remove:SetScript("OnClick", function() ns.UnignoreQuest(q.id) end)
    r:Show()
  end
  for i = #list + 1, #ignRows do ignRows[i]:Hide() end
  ignWin.empty:SetShown(#list == 0)
  ignWin.content:SetHeight(math.max(1, #list * ROW_H))
end

function ns.OpenIgnored()
  if not ignWin then BuildIgnored() end
  ns.RestyleOptions()
  ignWin:Show()
  ns.RefreshIgnored()
end
