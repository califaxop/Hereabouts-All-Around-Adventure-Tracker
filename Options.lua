-- XP Planner: settings window (/xpp, or Esc > Options > AddOns > XP Planner)
local _, ns = ...

local function Changed() ns.Refresh() end

local function Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  fs:SetText(text)
  return fs
end

local function Header(parent, text, anchor, x, y)
  local h = Label(parent, text)
  if anchor then h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -18)
  else h:SetPoint("TOPLEFT", x, y) end
  return h
end

local function Slider(parent, label, minV, maxV, step, key, fmt, anchor, onSet)
  local text = Label(parent, "", "GameFontHighlight")
  text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -6)
  s:SetSize(200, 16)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
  s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
  local refreshing = false
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    text:SetText(label .. ": " .. fmt(v))
    if refreshing or ns.db[key] == v then return end
    ns.db[key] = v
    if onSet then onSet(v) end
    Changed()
  end)
  s.Refresh = function()
    refreshing = true
    s:SetValue(ns.db[key]); text:SetText(label .. ": " .. fmt(ns.db[key]))
    refreshing = false
  end
  return s
end

local function Check(parent, label, key, anchor, onSet, invert)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  local l = Label(parent, label, "GameFontHighlight")
  l:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if invert then v = not v end
    ns.db[key] = v
    if onSet then onSet(v) end
    Changed()
  end)
  cb.Refresh = function()
    local v = ns.db[key] and true or false
    if invert then v = not v end
    cb:SetChecked(v)
  end
  return cb
end

local function Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local panels = {}

local function BuildPanel(panel)
  local w = {}
  local function track(x) w[#w + 1] = x; return x end

  local title = Label(panel, "XP Planner", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)

  -- Left column ------------------------------------------------------------
  local hPos = Header(panel, "Position", nil, 16, -46)
  local lock = track(Check(panel, "Lock in place", "locked", hPos))
  local repl = track(Check(panel, "Replace Blizzard's quest tracker", "replaceTracker", lock,
    function() ns.ApplyReplace() end))
  local hide = track(Check(panel, "Hide the list", "hidden", repl))
  local scale = track(Slider(panel, "Scale", 0.6, 1.5, 0.05, "scale",
    function(v) return math.floor(v * 100 + 0.5) .. "%" end, hide, function() ns.PlaceFrame() end))
  local bgA = track(Slider(panel, "Background opacity", 0, 1, 0.05, "bgAlpha",
    function(v) return math.floor(v * 100 + 0.5) .. "%" end, scale, function() ns.ApplyBackdrop() end))
  local flare = track(Check(panel, "FlareUI style (needs FlareUI)", "useFlareStyle", bgA,
    function() ns.ApplyBackdrop() end))
  flare:ClearAllPoints(); flare:SetPoint("TOPLEFT", bgA, "BOTTOMLEFT", 0, -12)
  local border = track(Check(panel, "Border (when not using FlareUI style)", "showBorder", flare,
    function() ns.ApplyBackdrop() end))
  local resetPos = Button(panel, "Move under quest tracker", 200, function()
    ns.db.pos = nil; ns.PlaceFrame(); Changed()
  end)
  resetPos:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -10)

  local hSec = Header(panel, "Sections", resetPos, nil, -16)
  local sA0 = track(Check(panel, "Active Quests", "showActive", hSec))
  local sA = track(Check(panel, "  ...only quests in my current zone", "activeZoneOnly", sA0))
  local sP = track(Check(panel, "Quests to Pick Up (Questie)", "showPickup", sA))
  local sD = track(Check(panel, "Dungeons", "showDungeons", sP))
  local sT = track(Check(panel, "Training (What's Training)", "showTraining", sD))
  local sL = track(Check(panel, "Sort by level (highest first)", "sortByLevel", sT))
  local sNL = track(Check(panel, "  ...and spells at your next level", "showNextLevel", sL))
  local sN = track(Check(panel, "Map's nearby quests (if no Questie)", "showNearby", sNL))

  local hDet = Header(panel, "Details", sN, nil, -16)
  local dO = track(Check(panel, "Objectives under active quests", "showObjectives", hDet))
  local dX = track(Check(panel, "XP reward", "showXP", dO))
  local dG = track(Check(panel, "Quest giver and zone", "showStarter", dX))
  local dU = track(Check(panel, "Hide quests you aren't tracking", "hideUntracked", dG))

  -- Right column -----------------------------------------------------------
  local hAmt = Header(panel, "How many to show", nil, 270, -46)
  local mA = track(Slider(panel, "Active quests", 1, 20, 1, "maxQuests", tostring, hAmt))
  local mP = track(Slider(panel, "Quests to pick up", 1, 20, 1, "maxPickup", tostring, mA))
  local mD = track(Slider(panel, "Dungeons", 1, 6, 1, "maxDungeons", tostring, mP))
  local mT = track(Slider(panel, "Spells to train", 1, 30, 1, "maxTraining", tostring, mD))
  local mH = track(Slider(panel, "Max height (then scrolls)", 120, 900, 10, "maxHeight",
    function(v) return v .. " px" end, mT))

  local hPick = Header(panel, "Picking quests", mH, nil, -22)
  local zoneOnly = track(Check(panel, "Only quests from my current zone", "pickupZoneOnly", hPick))
  local signed = function(v) return (v > 0 and "+" or "") .. v .. (v == 0 and " (your level)" or "") end
  local lowest = track(Slider(panel, "Lowest quest level: you", -8, 8, 1, "levelMin", signed, zoneOnly,
    function(v) if v > ns.db.levelMax then ns.db.levelMax = v; ns.RefreshOptions() end end))
  local above = track(Slider(panel, "Highest quest level: you", -8, 8, 1, "levelMax", signed, lowest,
    function(v) if v < ns.db.levelMin then ns.db.levelMin = v; ns.RefreshOptions() end end))
  local bonus = track(Slider(panel, "Current-zone bonus", 1, 3, 0.1, "zoneBonus",
    function(v) return format("x%.1f", v) end, above))
  local note = Label(panel, "Ranks quests in your zone higher (less travel).", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", bonus, "BOTTOMLEFT", 0, -8)

  -- Info + actions ---------------------------------------------------------
  local hInfo = Header(panel, "Status", note, nil, -22)
  local info = Label(panel, "", "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", hInfo, "BOTTOMLEFT", 0, -6)
  info:SetWidth(220); info:SetJustifyH("LEFT")
  local function UpdateInfo()
    local q = ns.Questie
    local text
    if not q.Installed() then
      text = "|cffff6060Questie not found.|r Using the map's nearby quests."
    elseif not q.Available() then
      text = "|cffffd200Questie found, still loading...|r"
    elseif q.IsScanning() then
      text = "|cffffd200Questie: scanning quests...|r"
    else
      text = format("|cff60ff60Questie connected.|r %d quests you can pick up.", q.Count())
    end
    local tr = ns.Training
    if not tr.Installed() then
      text = text .. "\n|cffff6060What's Training not found.|r"
    elseif not tr.Ready() then
      text = text .. "\n|cffffd200What's Training loading...|r"
    else
      text = text .. "\n|cff60ff60What's Training connected.|r"
    end
    info:SetText(text .. format("\nLevel %d", UnitLevel("player")))
  end

  local rescan = Button(panel, "Rescan Questie", 120, function() ns.Questie.Scan(); UpdateInfo() end)
  rescan:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -10)
  local reset = Button(panel, "Reset to defaults", 120, function()
    ns.ResetDB(); ns.PlaceFrame()
    for _, x in ipairs(w) do x.Refresh() end
    ns.Questie.RescanSoon(); Changed()
  end)
  reset:SetPoint("LEFT", rescan, "RIGHT", 8, 0)

  local ign = Button(panel, "Ignored quests", 248, function() ns.OpenIgnored() end)
  ign:SetPoint("TOPLEFT", rescan, "BOTTOMLEFT", 0, -8)
  local function UpdateIgnButton()
    local n = 0
    for _ in pairs(ns.db.ignoredQuests or {}) do n = n + 1 end
    ign:SetText(format("Ignored quests (%d)...", n))
  end

  panel.RefreshAll = function()
    for _, x in ipairs(w) do x.Refresh() end
    UpdateInfo(); UpdateIgnButton()
  end
  panel.UpdateIgnButton = UpdateIgnButton
  panel:HookScript("OnShow", panel.RefreshAll)
  local t = 0
  panel:HookScript("OnUpdate", function(_, dt)
    t = t + dt
    if t > 1 then t = 0; UpdateInfo() end
  end)
  panels[#panels + 1] = panel
  return panel
end

function ns.RefreshOptions()
  for _, p in ipairs(panels) do if p:IsVisible() then p.RefreshAll() end end
end

---------------------------------------------------------------------------
-- Esc > Options > AddOns entry, and the /xpp window
---------------------------------------------------------------------------
local settingsPanel, window

function ns.CreateOptions()
  if settingsPanel then return end
  settingsPanel = CreateFrame("Frame")
  settingsPanel.name = "XP Planner"
  local ok, e = pcall(BuildPanel, settingsPanel)
  if not ok then ns.Print("settings panel failed: " .. tostring(e)); return end
  pcall(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
      local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
      Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(settingsPanel)
    end
  end)
end

function ns.OpenOptions()
  if not window then
    window = CreateFrame("Frame", "XPPlannerOptionsWindow", UIParent, "BackdropTemplate")
    window:SetSize(560, 930)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    window:SetMovable(true); window:EnableMouse(true); window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "XPPlannerOptionsWindow") -- Esc closes it
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    local inner = CreateFrame("Frame", nil, window)
    inner:SetPoint("TOPLEFT", 8, -8); inner:SetPoint("BOTTOMRIGHT", -8, 8)
    local ok, e = pcall(BuildPanel, inner)
    if not ok then window:Hide(); window = nil; ns.Print("settings failed: " .. tostring(e)); return end
    window:Hide()
  end
  -- shrink to fit smaller screens (the window is tall)
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end

---------------------------------------------------------------------------
-- Ignored Quests window: every quest you ignored from "Quests to Pick Up".
-- Remove one and it returns to the list right away if it still qualifies.
---------------------------------------------------------------------------
local ignWin, ignRows = nil, {}
local ROW_H = 22

local function BuildIgnored()
  ignWin = CreateFrame("Frame", "XPPlannerIgnoredWindow", UIParent, "BackdropTemplate")
  ignWin:SetSize(340, 360)
  ignWin:SetPoint("CENTER", 300, 0)
  ignWin:SetFrameStrata("DIALOG")
  ignWin:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 } })
  ignWin:SetMovable(true); ignWin:EnableMouse(true); ignWin:RegisterForDrag("LeftButton")
  ignWin:SetScript("OnDragStart", ignWin.StartMoving)
  ignWin:SetScript("OnDragStop", ignWin.StopMovingOrSizing)
  ignWin:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "XPPlannerIgnoredWindow")
  local close = CreateFrame("Button", nil, ignWin, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local title = Label(ignWin, "Ignored Quests", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -20)
  local hint = Label(ignWin, "Removed quests come back to Quests to Pick Up if they still qualify.", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); hint:SetWidth(300); hint:SetJustifyH("LEFT")

  local scroll = CreateFrame("ScrollFrame", nil, ignWin)
  scroll:SetPoint("TOPLEFT", 20, -64)
  scroll:SetPoint("BOTTOMRIGHT", -20, 50)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 1)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * ROW_H * 2)))
  end)
  ignWin.content, ignWin.scroll = content, scroll

  ignWin.empty = Label(content, "No ignored quests.", "GameFontDisable")
  ignWin.empty:SetPoint("TOPLEFT", 0, -4)

  local clear = Button(ignWin, "Clear all", 100, function()
    wipe(ns.db.ignoredQuests); ns.Refresh(); ns.RefreshIgnored()
  end)
  clear:SetPoint("BOTTOMLEFT", 20, 18)
end

function ns.RefreshIgnored()
  for _, p in ipairs(panels) do if p.UpdateIgnButton then p.UpdateIgnButton() end end
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
      r:SetSize(300, ROW_H)
      r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      r.text:SetPoint("LEFT"); r.text:SetPoint("RIGHT", -80, 0)
      r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
      r.remove = Button(r, "Remove", 72, nil)
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
  ignWin:Show()
  ns.RefreshIgnored()
end
