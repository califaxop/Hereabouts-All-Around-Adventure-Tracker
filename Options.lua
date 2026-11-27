-- XP Planner: settings window (/hab, or Esc > Options > AddOns > XP Planner), drawn in the
-- tracker's own style: its border, background, fonts and colours (EllesmereUI's or FlareUI's when installed).
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
    elseif th.eui then
      div:SetColorTexture(RGB(th.edge, 1)); div:SetHeight(1)
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
    box:SetBackdropBorderColor(RGB((hover and active) and th.accent or th.edge, hover and active and 1 or 0.8))
    mark:SetVertexColor(RGB(th.mark))
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
  b.label = fs
  local hover = false
  local function paint(th)
    th = th or ns.Theme()
    if th.eui then
      b:SetBackdropColor(RGB(th.box, hover and 1 or 0.85))
      b:SetBackdropBorderColor(RGB(hover and th.accent or th.edge, 1))
    else
      b:SetBackdropColor(RGB(th.box, hover and 0.55 or 0.3))
      b:SetBackdropBorderColor(RGB(th.accent, hover and 1 or 0.8))
    end
    fs:SetTextColor(RGB(hover and th.hover or th.title))
  end
  Skin(paint)
  b:SetScript("OnEnter", function() hover = true; paint() end)
  b:SetScript("OnLeave", function() hover = false; paint() end)
  b:SetScript("OnClick", onClick)
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

-- The bug report window (2.0.0; like Questie's trace export and Equip This!'s fight records): the
-- form's link to copy at the top, what to do, the report line to copy, what's in it. Opened by
-- Status > "Report a bug / suggest" and /hab report. Addons can't open a browser: both are text
-- boxes, selected and ready for Ctrl+C.
local REPO = "https://github.com/califaxop/Hereabouts-All-Around-Adventure-Tracker/issues/new"
local function FormURL(kind)
  if kind == "idea" then return REPO .. "?template=feature_request.yml" end
  local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local ok, v = pcall(get, ns.name, "Version")
  return REPO .. "?template=bug_report.yml" .. ((ok and type(v) == "string") and ("&version=" .. v) or "")
end
local NOTE = {
  bug = "Open the link above in your browser (needs a GitHub account), say what happened, and paste the line below into \"Debug output\". "
    .. "Please open this window again for each report: the line holds things as they are right now.",
  idea = "Open the link above in your browser (needs a GitHub account) and tell us your idea. The line below isn't needed for an idea.",
}
local INCLUDED = "Included: Hereabouts' version, the game client, your class and level, your add-ons, how your quests are placed, the session, your sections and any errors caught. Never: your name, realm, guild or other players."
local reportWin, reportHost -- reportHost: the settings window, once built
-- a one-line box that keeps its text (typing in it puts it back), selected when clicked
local function CopyBox(parent, width, get)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(width, 22); e:SetAutoFocus(false); e:SetTextInsets(6, 6, 0, 0); e:SetMaxLetters(0)
  e:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  Skin(function(th)
    e:SetFontObject(th.lineFont); e:SetTextColor(RGB(th.title))
    e:SetBackdropColor(0, 0, 0, 0.55); e:SetBackdropBorderColor(RGB(th.eui and th.edge or th.title, 0.7))
  end)
  e:SetScript("OnTextChanged", function(self, user) if user and self:GetText() ~= get() then self:SetText(get()); self:HighlightText() end end)
  e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  e:SetScript("OnEscapePressed", function() parent:Hide() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end
local function BuildReport()
  local w = Window("XPPlannerReportWindow", 600, 330)
  -- a pop-up: solid, held over the settings window (dimmed and unclickable behind it)
  w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetToplevel(true)
  w:SetMovable(false); w:SetScript("OnDragStart", nil); w:SetScript("OnDragStop", nil)
  local solid = w:CreateTexture(nil, "BACKGROUND", nil, -8)
  solid:SetColorTexture(0.04, 0.035, 0.03, 1)
  solid:SetPoint("TOPLEFT", 3, -3); solid:SetPoint("BOTTOMRIGHT", -3, 3)
  w.shade = CreateFrame("Frame", nil, w)
  w.shade:EnableMouse(true)
  local dim = w.shade:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.55)
  w:Hide()
  local title = Text(w, "title", "Hereabouts Bug Report")
  title:SetPoint("TOP", 0, -16)
  w.urlBox = CopyBox(w, 540, function() return w.url end)
  w.urlBox:SetPoint("TOP", 0, -42)
  w.note = Text(w, "note", "")
  w.note:SetPoint("TOP", 0, -74); w.note:SetWidth(540); w.note:SetJustifyH("CENTER")
  w.line = CopyBox(w, 540, function() return w.text end)
  w.line:SetPoint("TOP", 0, -122)
  -- what's in it, two columns
  w.stats = {}
  local ICONS = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Misc_PocketWatch_01",
    "Interface\\Icons\\INV_Misc_Note_01", "Interface\\Icons\\Spell_Nature_LightningShield" }
  for i = 1, 4 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local icon = w:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICONS[i]); icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 40 + col * 290, -162 - row * 26)
    local t = Text(w, "line", "")
    t:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    t:SetWidth(255); t:SetJustifyH("LEFT"); t:SetWordWrap(false) -- (cut short, never into the next column)
    w.stats[i] = t
  end
  local inc = Text(w, "note", INCLUDED)
  inc:SetPoint("TOP", 0, -222); inc:SetWidth(540); inc:SetJustifyH("CENTER")
  w.kindBtn = Button(w, "", 180, function() ns.ShowReport(w.kind == "bug" and "idea" or "bug") end)
  w.kindBtn:SetPoint("BOTTOMLEFT", 20, 16)
  local close = Button(w, "Close", 110, function() w:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -20, 16)
  return w
end

-- kind: "bug" (default) or "idea" (the ideas form's link instead)
function ns.ShowReport(kind)
  reportWin = reportWin or BuildReport()
  local w = reportWin
  w.kind = kind == "idea" and "idea" or "bug"
  local ok, text, info = pcall(ns.Report)
  if not ok then text, info = "(the report failed: " .. tostring(text):gsub("|", "||") .. ")", nil end
  w.url, w.text = FormURL(w.kind), text
  w.urlBox:SetText(w.url); if w.urlBox.SetCursorPosition then w.urlBox:SetCursorPosition(0) end
  w.line:SetText(text)
  w.note:SetText(NOTE[w.kind])
  w.kindBtn.label:SetText(w.kind == "bug" and "Suggest an idea instead" or "Report a bug instead")
  local G = "|cffffd200"
  local q = info and info.quests
  w.stats[1]:SetText("Your quests: " .. G .. (q and (format("%d here, %d elsewhere", q.here, q.elsewhere) .. (q.unknown > 0 and format(", %d can't tell", q.unknown) or "")) or "-") .. "|r")
  w.stats[2]:SetText("Session: " .. G .. (info and (info.session .. ", " .. (info.xp or "max level")) or "-") .. "|r")
  w.stats[3]:SetText("Errors caught: " .. G .. (info and info.errors or "-") .. "|r")
  w.stats[4]:SetText("Add-ons connected: " .. G .. (info and format("%d of %d", info.addons, info.ofAddons) or "-") .. "|r")
  w:ClearAllPoints()
  if reportHost and reportHost:IsShown() then
    w:SetScale(reportHost:GetScale())
    w:SetPoint("CENTER", reportHost, "CENTER", 0, 0)
    w.shade:ClearAllPoints(); w.shade:SetAllPoints(reportHost); w.shade:Show()
  else
    w:SetScale(1)
    w:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    w.shade:Hide()
  end
  w.shade:SetFrameLevel(math.max(0, w:GetFrameLevel() - 1))
  w:Show(); w:Raise()
  -- the line to copy selected for a bug; the link for an idea
  local focus = w.kind == "bug" and w.line or w.urlBox
  focus:SetFocus(); focus:HighlightText()
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
  track(Check(p, "Replace the quest tracker", 0, y - 24, Setting("replaceTracker", function() ns.ApplyReplace() end)))
  track(Check(p, "Hide the list", 0, y - 48, Setting("hidden")))
  local under = Button(p, "Move under quest tracker", 200, function() ns.db.pos = nil; ns.PlaceFrame(); Changed() end)
  under:SetPoint("TOPLEFT", 0, y - 80)
  Note(p, "Unlock, then drag a section heading to move the list.", 0, y - 110, 220)

  y = Section(p, "Look", COL2, 0, 224)
  -- (the look follows EllesmereUI / FlareUI on its own when they're installed)
  local border = track(Check(p, "Border (without FlareUI / EllesmereUI)", COL2, y, Setting("showBorder", Restyle), 224))
  local r = border.Refresh
  border.Refresh = function() r(); border.SetActive(not ns.UsingFlare() and not ns.UsingEUI()) end
  -- the earlier section headings (the quest tracker's header art), for those who prefer them
  local classic = track(Check(p, "Classic section headings", COL2, y - 24, Setting("classicHeaders", function() ns.Refresh() end), 224))
  local rc = classic.Refresh
  classic.Refresh = function() rc(); classic.SetActive(not ns.UsingFlare()) end
  track(Slider(p, "Scale", COL2, y - 64, 224, 0.6, 1.5, 0.05, Setting("scale", function() ns.PlaceFrame() end), pct))
  track(Slider(p, "Background opacity", COL2, y - 100, 224, 0, 1, 0.05, Setting("bgAlpha", function() ns.ApplyBackdrop() end), pct))
  track(Slider(p, "Max height (then scrolls)", COL2, y - 136, 224, 120, 900, 10, Setting("maxHeight"),
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
  for i, sec in ipairs({ { "quests", "Active Quests" }, { "turnin", "Quests to Turn In" }, { "pickup", "Quests Nearby" },
      { "training", "Training" }, { "dungeons", "Dungeons" } }) do
    local ry = y - (i - 1) * 20
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
  Row("Quests to Turn In", "showTurnIn", "maxTurnIn", 20, y - 54)
  Row("Quests Nearby (Questie)", "showPickup", "maxPickup", 20, y - 84)
  Row("Dungeons", "showDungeons", "maxDungeons", 6, y - 114)
  Sub("Only dungeons in my current zone", "dungeonZoneOnly", "showDungeons", y - 138)
  Row("Training (What's Training)", "showTraining", "maxTraining", 30, y - 168)
  Sub("Also spells at my next level", "showNextLevel", "showTraining", y - 192)

  y = Section(p, "Details", 0, y - 230, PAGE_W)
  track(Check(p, "Sort by level (highest first)", 0, y, Setting("sortByLevel")))
  track(Check(p, "Objectives under active quests", 0, y - 24, Setting("showObjectives", function() ns.RefreshOptions() end)))
  local hideDone = track(Check(p, "Hide finished objectives", 22, y - 48, Setting("hideDoneObjectives"), 208))
  local hr = hideDone.Refresh
  hideDone.Refresh = function() hr(); hideDone.SetActive(ns.db.showObjectives and true or false) end
  track(Check(p, "XP reward", COL2, y, Setting("showXP"), 224))
  track(Check(p, "Quest giver and zone", COL2, y - 24, Setting("showStarter"), 224))
  track(Check(p, "Training prices by city", COL2, y - 48, Setting("showCityPrices"), 224))
  track(Check(p, "Quest item buttons (beside the quest)", 0, y - 72, Setting("showQuestItems", function() ns.Refresh() end), 230))
  local cf = track(Check(p, "In combat: mark my enemy's quests", COL2, y - 72, Setting("combatFocus", function() ns.Refresh() end), 224))
  cf:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("In combat: mark my enemy's quests", 1, 1, 1)
    GameTooltip:AddLine("While you fight something a quest of yours needs (to kill it, or for what it drops), that quest is highlighted light blue where it is in Active Quests (nothing moves), with the objective it counts for lit up. Your target first; with no quest target, the enemies fighting you (needs enemy nameplates on). Back to normal when combat ends.", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
  end)
  cf:HookScript("OnLeave", function() GameTooltip:Hide() end)
  track(Check(p, "Soft animations (objective progress, combat mark)", 0, y - 96, Setting("animations"), 300))
end

local function PagePicking(p)
  local y = Section(p, "Which quests to suggest", 0, 0, PAGE_W)
  track(Check(p, "Only quests from my current zone", 0, y, Setting("pickupZoneOnly"), 220))
  Note(p, "Quests Nearby needs Questie. Which quests show (levels, low-level, repeatable, dungeon and PvP quests) follows Questie's own settings: Questie options, Quest Level Options.", 0, y - 28, PAGE_W)
  track(Slider(p, "Current-zone bonus", 0, y - 80, 220, 1, 3, 0.1, Setting("zoneBonus"),
    function(v) return format("x%.1f", v) end))
  Note(p, "With All zones, quests in your zone rank higher, since there's less travel.", COL2, y - 84, 224)

  y = Section(p, "Ignored quests", 0, y - 132, PAGE_W)
  local count = Text(p, "line", "")
  count:SetPoint("TOPLEFT", 0, y - 4)
  local manage = Button(p, "Manage...", 120, function() ns.OpenIgnored() end)
  manage:SetPoint("TOPLEFT", COL2, y)
  Note(p, "Right-click a quest under Quests Nearby to ignore it.", 0, y - 30, PAGE_W)
  ignUpdate = function()
    local n = 0
    for _ in pairs(ns.db.ignoredQuests or {}) do n = n + 1 end
    count:SetText(n == 0 and "No quests ignored." or format(n == 1 and "%d quest ignored." or "%d quests ignored.", n))
  end
end

local function PageStatus(p)
  local y = Section(p, "Connected addons", 0, 0, PAGE_W)
  local rows = {}
  local NAMES = { "Questie", "What's Training", "FlareUI", "EllesmereUI", "TomTom" } -- (ns.Integrations' order)
  for i, n in ipairs(NAMES) do
    local ry = y - (i - 1) * 30
    local dot = p:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(W); dot:SetSize(8, 8); dot:SetPoint("TOPLEFT", 2, ry - 5)
    local name = Text(p, "line", n); name:SetPoint("TOPLEFT", 18, ry)
    local state = Text(p, "note", ""); state:SetPoint("TOPLEFT", 150, ry - 1); state:SetWidth(318)
    rows[n] = { dot = dot, state = state }
  end
  local COLORS = { on = { 0.35, 0.9, 0.35 }, partial = { 1, 0.82, 0.2 }, loading = { 1, 0.82, 0.2 }, off = { 0.45, 0.45, 0.45 } }

  local level = Text(p, "line", "")
  level:SetPoint("TOPLEFT", 0, y - 152)

  statusUpdate = function()
    for _, it in ipairs(ns.Integrations()) do
      local r, c = rows[it[1]], COLORS[it[2]]
      if r then r.dot:SetVertexColor(c[1], c[2], c[3]); r.state:SetText(it[3]) end
    end
    level:SetText(format("Your level: %d", UnitLevel("player")))
  end

  local rescan = Button(p, "Rescan Questie", 130, function() ns.Questie.Scan(); statusUpdate() end)
  rescan:SetPoint("TOPLEFT", 0, y - 176)

  y = Section(p, "Reset", 0, y - 226, PAGE_W)
  local reset = Button(p, "Reset to defaults", 130, function()
    ns.ResetDB(); ns.PlaceFrame(); ns.Questie.RescanSoon(); Restyle(); Changed(); ns.RefreshOptions()
  end)
  reset:SetPoint("TOPLEFT", 0, y)
  Note(p, "Keeps where the list is and the quests you've ignored.", 140, y - 5, 320)

  y = Section(p, "Feedback", 0, y - 44, PAGE_W)
  local fb = Button(p, "Report a bug / suggest", 180, function()
    ns.ShowReport()
  end)
  fb:SetPoint("TOPLEFT", 0, y)
  Note(p, "The form's link and a report to paste into it (or /hab report).", 190, y - 5, 270)
end

local function PageSession(p)
  local y = Section(p, "Session bar", 0, 0, PAGE_W)
  local function repaint() if ns.Session then ns.Session.Paint() end end
  track(Check(p, "Show the session bar under the tracker", 0, y, Setting("showSession", repaint), 320))
  Note(p, "A small bar under Hereabouts with this session's numbers. Hover it for all of them, right-click it to reset.", 0, y - 26, PAGE_W)
  y = Section(p, "What it shows", 0, y - 70, PAGE_W)
  for i, st in ipairs(ns.Session.STATS) do
    local key = st[1]
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local c = track(Check(p, st[2], col == 0 and 0 or COL2, y - row * 24, {
      function() return (ns.db.sessionStats or {})[key] and true or false end,
      function(v) ns.db.sessionStats = ns.db.sessionStats or {}; ns.db.sessionStats[key] = v or nil; repaint() end }, 220))
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db.showSession and true or false) end
  end
  local rows = math.ceil(#ns.Session.STATS / 2)
  Note(p, "Gold counts what comes in (loot, quest rewards, sales), not what you spend. Rates start after the first minute.",
    0, y - rows * 24 - 8, PAGE_W)
  local reset = Button(p, "Reset session", 130, function() ns.Session.Reset(); ns.Print("session stats reset.") end)
  reset:SetPoint("TOPLEFT", 0, y - rows * 24 - 46)
end

-- Layout (1.12.0): the sections' order and whether each shows, presets, and three saved layouts
-- (what shows, not the look: Core.lua LAYOUT_KEYS)
local function PageLayout(p)
  local function applied(what)
    ns.Refresh(); ns.RefreshOptions()
    if ns.Session then ns.Session.Paint() end
    ns.Print(what)
  end
  local function Tip(b, title, text)
    b:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(title, 1, 1, 1)
      GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true); GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local y = Section(p, "Sections, top to bottom", 0, 0, PAGE_W)
  local top = y -- (the rows are placed on every refresh: from here, not from `y`, which moves on)
  local rows = {}
  for _, m in ipairs(ns.MODULES) do
    local r = {}
    r.check = track(Check(p, m.name, 0, y, Setting(m.show, function() ns.RefreshOptions() end), 200))
    r.up = Button(p, "Up", 50, function() ns.MoveSection(m.key, -1); Changed(); ns.RefreshOptions() end)
    r.down = Button(p, "Down", 50, function() ns.MoveSection(m.key, 1); Changed(); ns.RefreshOptions() end)
    rows[m.key] = r
  end
  -- (placed by the order on every refresh)
  track({ Refresh = function()
    for i, key in ipairs(ns.SectionOrder()) do
      local r, ry = rows[key], top - (i - 1) * 26
      r.check:ClearAllPoints(); r.check:SetPoint("TOPLEFT", 0, ry)
      r.up:ClearAllPoints(); r.up:SetPoint("TOPLEFT", 230, ry)
      r.down:ClearAllPoints(); r.down:SetPoint("TOPLEFT", 286, ry)
      r.up:SetAlpha(i > 1 and 1 or 0.35); r.down:SetAlpha(i < #ns.MODULES and 1 or 0.35)
    end
  end })

  y = Section(p, "Presets", 0, y - #ns.MODULES * 26 - 14, PAGE_W)
  for i, pr in ipairs(ns.PRESETS) do
    local b = Button(p, pr[2], 88, function()
      ns.ApplyPreset(pr[1]); applied(format("layout: %s.", pr[2]))
    end)
    b:SetPoint("TOPLEFT", (i - 1) * 94, y)
    Tip(b, pr[2], pr[3])
  end
  Note(p, "A preset sets what shows and where, not the look. Save your layout below first to come back to it.", 0, y - 30, PAGE_W)

  y = Section(p, "Your layouts", 0, y - 70, PAGE_W)
  for slot = 1, ns.LAYOUT_SLOTS do
    local ry = y - (slot - 1) * 26
    local label = Text(p, "line", "")
    label:SetPoint("TOPLEFT", 0, ry - 4)
    local save = Button(p, "Save", 60, function() ns.SaveLayout(slot); applied(format("layout %d saved.", slot)) end)
    save:SetPoint("TOPLEFT", 230, ry)
    local load = Button(p, "Load", 60, function()
      if ns.LoadLayout(slot) then applied(format("layout %d loaded.", slot)) end
    end)
    load:SetPoint("TOPLEFT", 296, ry)
    track({ Refresh = function()
      local l = type(ns.db.layouts) == "table" and ns.db.layouts[slot]
      label:SetText(format("Layout %d: %s", slot, (l and l.savedAt and l.savedAt > 0) and ("saved " .. date("%d %b %H:%M", l.savedAt)) or "empty"))
      load:SetAlpha(l and 1 or 0.35)
    end })
  end
end

local TABS = {
  { "Tracker", PageTracker },
  { "Lists", PageLists },
  { "Layout", PageLayout },
  { "Picking Quests", PagePicking },
  { "Session", PageSession },
  { "Status", PageStatus },
}

local function BuildWindow()
  window = Window("XPPlannerOptionsWindow", 560, 500) -- (six tabs since 1.12.0)
  window:SetPoint("CENTER")
  reportHost = window
  window:HookScript("OnHide", function() if reportWin then reportWin:Hide() end end)
  local title = Text(window, "title", "Hereabouts")
  title:SetPoint("TOPLEFT", 26, -20)
  local sub = Text(window, "note", "Your quests, filtered to where you are.")
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)

  -- tabs: text in the heading font, the active one underlined in bronze
  local tabs, pages = {}, {}
  local current = 1
  local x = 26
  local line = window:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 26, -72); line:SetPoint("TOPRIGHT", -26, -72); line:SetHeight(1)
  local function paintTabs(th)
    th = th or ns.Theme()
    line:SetColorTexture(RGB(th.eui and th.edge or th.accent, th.eui and 1 or 0.5))
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
  settingsPanel.name = "Hereabouts"
  pcall(function()
    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText("Hereabouts")
    local b = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    b:SetSize(200, 24); b:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    b:SetText("Open Hereabouts settings")
    b:SetScript("OnClick", function()
      if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
      if not (window and window:IsShown()) then ns.OpenOptions() end
    end)
    local hint = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -8); hint:SetText("Or type /hab.")
    if Settings and Settings.RegisterCanvasLayoutCategory then
      Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name))
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(settingsPanel)
    end
  end)
end

---------------------------------------------------------------------------
-- Ignored Quests window: every quest you ignored from "Quests Nearby".
-- Remove one and it returns to the list right away if it still qualifies.
---------------------------------------------------------------------------
local ignWin, ignRows = nil, {}
local ROW_H = 24

local function BuildIgnored()
  ignWin = Window("XPPlannerIgnoredWindow", 360, 380)
  ignWin:SetPoint("CENTER", 300, 0)
  Text(ignWin, "title", "Ignored Quests"):SetPoint("TOPLEFT", 22, -20)
  Note(ignWin, "Removed quests come back to Quests Nearby if they still qualify.", 22, -44, 316)
  local line = ignWin:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 22, -70); line:SetPoint("TOPRIGHT", -22, -70); line:SetHeight(1)
  Skin(function(th) line:SetColorTexture(RGB(th.eui and th.edge or th.accent, th.eui and 1 or 0.5)) end)

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
