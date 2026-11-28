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
  -- solid underneath (the styles' backgrounds are see-through: with several addons' windows open,
  -- one showed through another)
  local solid = win:CreateTexture(nil, "BACKGROUND", nil, -8)
  solid:SetColorTexture(0.04, 0.035, 0.03, 1)
  solid:SetPoint("TOPLEFT", 3, -3); solid:SetPoint("BOTTOMRIGHT", -3, 3)
  -- the one opened or clicked last comes to the front, whole (never interleaved with another)
  win:SetToplevel(true)
  win:HookScript("OnShow", function(self) self:Raise() end)
  CloseButton(win)
  return win
end

-- The bug report window (2.0.0; like Questie's trace export and Equip This!'s fight records): the
-- form's link to copy at the top, what to do, the report line to copy, what's in it. Opened by
-- the settings window's "Bugs & Feedback" (top right, by the ×) and /hab report. Addons can't open a browser: both are text
-- boxes, selected and ready for Ctrl+C.
local REPO = "https://github.com/califaxop/Hereabouts-All-Around-Adventure-Tracker/issues/new"
local function FormURL(kind)
  if kind == "idea" then return REPO .. "?template=feature_request.yml" end
  local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local ok, v = pcall(get, ns.name, "Version")
  return REPO .. "?template=bug_report.yml" .. ((ok and type(v) == "string") and ("&version=" .. v) or "")
end
local NOTE = {
  bug = "Found a bug? Open the link above in your browser (needs a GitHub account), say what happened and paste the line below into \"Debug output\" "
    .. "(open this window again for each report). Feedback or a feature request? Click \"Feedback / feature request\" below.",
  idea = "Feedback, an idea or a feature you'd like? Open the link above in your browser (needs a GitHub account) and tell us. The line below isn't needed for this.",
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
  local w = Window("XPPlannerReportWindow", 600, 342)
  -- a pop-up: solid, held over the settings window (dimmed and unclickable behind it)
  w:SetFrameStrata("FULLSCREEN_DIALOG")
  w:SetMovable(false); w:SetScript("OnDragStart", nil); w:SetScript("OnDragStop", nil)
  w.shade = CreateFrame("Frame", nil, w)
  w.shade:EnableMouse(true)
  local dim = w.shade:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.55)
  w:Hide()
  local title = Text(w, "title", "Hereabouts Bugs & Feedback")
  title:SetPoint("TOP", 0, -16)
  w.urlBox = CopyBox(w, 540, function() return w.url end)
  w.urlBox:SetPoint("TOP", 0, -42)
  w.note = Text(w, "note", "")
  w.note:SetPoint("TOP", 0, -74); w.note:SetWidth(540); w.note:SetJustifyH("CENTER")
  w.line = CopyBox(w, 540, function() return w.text end)
  w.line:SetPoint("TOP", 0, -134)
  -- what's in it, two columns
  w.stats = {}
  local ICONS = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Misc_PocketWatch_01",
    "Interface\\Icons\\INV_Misc_Note_01", "Interface\\Icons\\Spell_Nature_LightningShield" }
  for i = 1, 4 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local icon = w:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICONS[i]); icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 40 + col * 290, -174 - row * 26)
    local t = Text(w, "line", "")
    t:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    t:SetWidth(255); t:SetJustifyH("LEFT"); t:SetWordWrap(false) -- (cut short, never into the next column)
    w.stats[i] = t
  end
  local inc = Text(w, "note", INCLUDED)
  inc:SetPoint("TOP", 0, -234); inc:SetWidth(540); inc:SetJustifyH("CENTER")
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
  w.kindBtn.label:SetText(w.kind == "bug" and "Feedback / feature request" or "Report a bug instead")
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
-- The settings window (2.1.0): Blizzard's own Settings window design, built from its parts.
-- - Frame: Blizzard's settings frame (SettingsFrameTemplate) with its inner frame.
-- - Categories down the left: the Options list's headers and highlights.
-- - Each page: its title with the divider, and rows with gold labels on the left and Blizzard's
--   controls on the right (the minimal checkbox, the slider with steppers, red buttons), under
--   white section headings, in Blizzard's scroll frame.
-- - A search box finds any setting and jumps to it.
-- Every part is checked for first (Classic Era 1.15.9's interface has them all: Blizzard_SharedXML,
-- Blizzard_Settings_Shared); any that's missing falls back to Hereabouts' own drawing.
---------------------------------------------------------------------------
local window, refreshers, statusUpdate, ignUpdate = nil, {}, nil, nil
local WIN_W, WIN_H = 920, 724        -- the size of Blizzard's settings window (its inner frame's art)
local LIST_X, LIST_W = 18, 186       -- the categories: up to the inner frame's divider (x 212, measured in game)
local CONT_X = 230                   -- the page: right of that divider
local CHILD_W = WIN_W - CONT_X - 22 - 30
local LABEL_X, CTRL_X = 37, 250      -- a row's label, and its control (Blizzard: the row's middle less 80)
local ROW = 30
local LOGO = "Interface\\AddOns\\Hereabouts\\media\\Logo"

local function track(x) refreshers[#refreshers + 1] = x; return x end

function ns.RefreshOptions()
  if not (window and window:IsShown()) then return end
  for _, x in ipairs(refreshers) do x.Refresh() end
  if statusUpdate then statusUpdate() end
  if ignUpdate then ignUpdate() end
end

local function Restyle() ns.ApplyBackdrop(); ns.RestyleOptions(); ns.RefreshOptions() end

-- a Blizzard template or atlas, if this client has it
local function Make(kind, parent, template, name)
  local ok, f = pcall(CreateFrame, kind, name, parent, template)
  if ok and f then return f end
end
local function HasAtlas(a)
  if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
  local ok, info = pcall(C_Texture.GetAtlasInfo, a)
  return ok and info ~= nil
end
local function Font(fs, obj) if _G[obj] then fs:SetFontObject(obj) end end
-- a template's child frame or region, only if it's really there
local function Part(f, key) local v = f and rawget(f, key); if type(v) == "table" or type(v) == "userdata" then return v end end

-- Search: every setting, its page and where it is on it
local index, building = {}, nil
local function Index(label, frame, y)
  if type(label) == "string" and label ~= "" and building then
    index[#index + 1] = { label = label, page = building, frame = frame, y = y }
  end
  return frame
end

---------------------------------------------------------------------------
-- Blizzard's controls (with Hereabouts' own as the fallback)
---------------------------------------------------------------------------
local function BCheck(parent, opt)
  local get, set = opt[1], opt[2]
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(30, 29)
  if HasAtlas("checkbox-minimal") and HasAtlas("checkmark-minimal") then
    local function tex(a) local t = b:CreateTexture(); t:SetAtlas(a, true); t:SetPoint("CENTER"); return t end
    b:SetNormalTexture(tex("checkbox-minimal")); b:SetPushedTexture(tex("checkbox-minimal"))
    b:SetCheckedTexture(tex("checkmark-minimal"))
    if HasAtlas("checkmark-minimal-disabled") then b:SetDisabledCheckedTexture(tex("checkmark-minimal-disabled")) end
  else
    b:SetSize(26, 26)
    b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up"); b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  end
  b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Changed() end)
  b.Refresh = function() b:SetChecked(get() and true or false) end
  b.SetActive = function(on) b:SetEnabled(on); b:SetAlpha(on and 1 or 0.5) end
  return b
end

local function BSlider(parent, minV, maxV, step, opt, fmt, width)
  local get, set = opt[1], opt[2]
  local M = MinimalSliderWithSteppersMixin
  local s = M and Make("Frame", parent, "MinimalSliderWithSteppersTemplate")
  if not (s and s.Init and s.RegisterCallback and M.Label and M.Event) then
    if s then s:Hide() end
    local fb = Slider(parent, nil, 0, 0, (width or 250) - 60, minV, maxV, step, opt, fmt) -- (placed by the row)
    return fb
  end
  s:SetWidth(width or 250)
  local refreshing = false
  local function snap(v) return math.floor(v / step + 0.5) * step end
  s:Init(get() or minV, minV, maxV, math.max(1, math.floor((maxV - minV) / step + 0.5)), { [M.Label.Right] = function(v) return fmt(snap(v)) end })
  s:RegisterCallback(M.Event.OnValueChanged, function(_, v)
    v = snap(v)
    if refreshing or get() == v then return end
    set(v); Changed()
  end, s)
  s.Refresh = function()
    refreshing = true
    s:SetValue(get()); if s.FormatValue then s:FormatValue(get()) end
    refreshing = false
  end
  s.SetActive = function(on) s:SetEnabled(on) end
  return s
end

local function BButton(parent, text, width, onClick)
  local b = Make("Button", parent, "UIPanelButtonTemplate")
  if not b then return Button(parent, text, width, onClick) end
  b:SetSize(width, 22); b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

---------------------------------------------------------------------------
-- A page's rows: section headings, then a gold label on the left and a control on the right
---------------------------------------------------------------------------
local function Rows(p)
  local R = { y = 0, n = 0 }
  local function Hover(row, label, tip)
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints(); hover:SetColorTexture(1, 1, 1, 0.05); hover:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      hover:Show()
      if tip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tip, nil, nil, nil, true); GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
  end
  -- a white heading
  function R.Section(_, title)
    R.y = R.y - (R.n > 0 and 8 or 0)
    local t = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t:SetPoint("TOPLEFT", 7, R.y - 10); t:SetText(title)
    Index(title, t, R.y)
    R.y = R.y - 36
  end
  -- a row with its label; returns the row frame and its control's x
  function R.Row(_, label, tip, indent)
    local row = CreateFrame("Frame", nil, p)
    row:SetPoint("TOPLEFT", 0, R.y); row:SetSize(CHILD_W, ROW)
    local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l:SetPoint("LEFT", LABEL_X + (indent and 20 or 0), 0); l:SetPoint("RIGHT", row, "LEFT", CTRL_X - 10, 0)
    l:SetJustifyH("LEFT"); l:SetWordWrap(true); l:SetMaxLines(2); l:SetText(label)
    row.label = l
    Hover(row, label, tip)
    Index(label, row, R.y)
    R.y, R.n = R.y - ROW, R.n + 1
    return row
  end
  function R.Check(_, label, opt, tip, indent)
    local row = R:Row(label, tip, indent)
    local c = track(BCheck(row, opt))
    c:SetPoint("LEFT", CTRL_X, 0)
    local sa = c.SetActive
    c.SetActive = function(on) sa(on); Font(row.label, on and "GameFontNormal" or "GameFontDisable") end
    return c, row
  end
  function R.Slider(_, label, minV, maxV, step, opt, fmt, tip, x)
    local row = R:Row(label, tip)
    local s = track(BSlider(row, minV, maxV, step, opt, fmt))
    s:ClearAllPoints(); s:SetPoint("LEFT", x or CTRL_X, 0)
    return s, row
  end
  function R.Button(_, label, text, width, onClick, tip)
    local row = R:Row(label, tip)
    local b = BButton(row, text, width, onClick)
    b:SetPoint("LEFT", CTRL_X, 0)
    return b, row
  end
  -- a short grey note under the rows above (no control)
  function R.Note(_, text)
    local n = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    n:SetPoint("TOPLEFT", LABEL_X, R.y + 4); n:SetWidth(CHILD_W - LABEL_X - 30); n:SetJustifyH("LEFT")
    n:SetTextColor(0.7, 0.7, 0.7); n:SetText(text)
    R.y = R.y - math.max(16, (n:GetStringHeight() or 12) + 10)
    return n
  end
  function R.Height(_) return -R.y + 20 end
  return R
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
local function PageTracker(p)
  local R = Rows(p)
  R:Section("Position")
  R:Check("Lock in place", Setting("locked"), "Unlock to drag the list by a section heading.")
  R:Check("Replace the quest tracker", Setting("replaceTracker", function() ns.ApplyReplace() end),
    "Hide the game's quest tracker (or FlareUI's / EllesmereUI's) and take its place.")
  R:Check("Hide the list", Setting("hidden"))
  R:Button("Position", "Move under quest tracker", 200, function() ns.db.pos = nil; ns.PlaceFrame(); Changed() end,
    "Put the list back under the game's quest tracker.")

  R:Section("Look")
  -- (the look follows EllesmereUI / FlareUI on its own when they're installed)
  local border = R:Check("Border", Setting("showBorder", Restyle), "A border around the list. FlareUI and EllesmereUI draw their own.")
  local r = border.Refresh
  border.Refresh = function() r(); border.SetActive(not ns.UsingFlare() and not ns.UsingEUI()) end
  -- the earlier section headings (the quest tracker's header art), for those who prefer them
  local classic = R:Check("Classic section headings", Setting("classicHeaders", function() ns.Refresh() end),
    "The quest tracker's own heading art for each section (without FlareUI).")
  local rc = classic.Refresh
  classic.Refresh = function() rc(); classic.SetActive(not ns.UsingFlare()) end
  R:Slider("Scale", 0.6, 1.5, 0.05, Setting("scale", function() ns.PlaceFrame() end), pct)
  R:Slider("Background opacity", 0, 1, 0.05, Setting("bgAlpha", function() ns.ApplyBackdrop() end), pct)
  R:Slider("Max height", 120, 900, 10, Setting("maxHeight"), function(v) return v .. " px" end, "Taller than this, the list scrolls.")

  -- which sections show in dungeons and in combat (ticked = shown)
  R:Section("Show in dungeons and in combat")
  local heads = {}
  for i, t in ipairs({ "In dungeons", "In combat" }) do
    heads[i] = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); heads[i]:SetText(t)
  end
  R.y = R.y - 8
  local function Shown(tbl, key)
    return { function() return not (ns.db[tbl] and ns.db[tbl][key]) end,
      function(v) ns.db[tbl] = ns.db[tbl] or {}; ns.db[tbl][key] = (not v) or nil end }
  end
  for _, sec in ipairs({ { "quests", "Active Quests" }, { "turnin", "Quests to Turn In" }, { "pickup", "Quests Nearby" },
      { "training", "Training" }, { "dungeons", "Dungeons" } }) do
    local row = R:Row(sec[2], "Ticked: this section shows in dungeons / in combat.")
    local a = track(BCheck(row, Shown("hideInInstance", sec[1]))); a:SetPoint("LEFT", CTRL_X, 0)
    local b = track(BCheck(row, Shown("hideInCombat", sec[1]))); b:SetPoint("LEFT", CTRL_X + 110, 0)
    if sec[1] == "quests" then
      heads[1]:SetPoint("BOTTOM", a, "TOP", 0, 0); heads[2]:SetPoint("BOTTOM", b, "TOP", 0, 0)
    end
  end
  return R:Height()
end

local function PageLists(p)
  local R = Rows(p)
  local count = function(v) return "up to " .. v end
  R:Section("What to list")
  -- one row per section: on/off and how many; its options indented under it
  local function Row(label, key, maxKey, maxV)
    local c, row = R:Check(label, { function() return ns.db[key] end, function(v)
      ns.db[key] = v; ns.RefreshOptions() -- greys out its slider and options
    end })
    local s = track(BSlider(row, 1, maxV, 1, Setting(maxKey), count, 230))
    s:ClearAllPoints(); s:SetPoint("LEFT", CTRL_X + 44, 0)
    local r = c.Refresh
    c.Refresh = function() r(); s.SetActive(ns.db[key] and true or false) end
  end
  local function Sub(label, key, parentKey)
    local c = R:Check(label, Setting(key), nil, true)
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db[parentKey] and true or false) end
  end
  Row("Active Quests", "showActive", "maxQuests", 20)
  Sub("Only quests in my current zone", "activeZoneOnly", "showActive")
  Row("Quests to Turn In", "showTurnIn", "maxTurnIn", 20)
  Row("Quests Nearby (Questie)", "showPickup", "maxPickup", 20)
  Row("Dungeons", "showDungeons", "maxDungeons", 6)
  Sub("Only dungeons in my current zone", "dungeonZoneOnly", "showDungeons")
  Row("Training (What's Training)", "showTraining", "maxTraining", 30)
  Sub("Also spells at my next level", "showNextLevel", "showTraining")

  R:Section("Details")
  R:Check("Sort by level (highest first)", Setting("sortByLevel"))
  R:Check("Objectives under active quests", Setting("showObjectives", function() ns.RefreshOptions() end))
  local hide = R:Check("Hide finished objectives", Setting("hideDoneObjectives"), nil, true)
  local hr = hide.Refresh
  hide.Refresh = function() hr(); hide.SetActive(ns.db.showObjectives and true or false) end
  R:Check("XP reward", Setting("showXP"))
  R:Check("Quest giver and zone", Setting("showStarter"))
  R:Check("Training prices by city", Setting("showCityPrices"))
  R:Check("Quest item buttons (beside the quest)", Setting("showQuestItems", function() ns.Refresh() end))
  R:Check("In combat: mark my enemy's quests", Setting("combatFocus", function() ns.Refresh() end),
    "While you fight something a quest of yours needs (to kill it, or for what it drops), that quest is highlighted light blue where it is in Active Quests (nothing moves), with the objective it counts for lit up. Your target first; with no quest target, the enemies fighting you (needs enemy nameplates on). Back to normal when combat ends.")
  R:Check("Soft animations", Setting("animations"), "Objectives flash when they progress; the combat mark fades in and out.")
  return R:Height()
end

-- Layout (1.12.0): the sections' order and whether each shows, presets, and three saved layouts
-- (what shows, not the look: Core.lua LAYOUT_KEYS)
local function PageLayout(p)
  local function applied(what)
    ns.Refresh(); ns.RefreshOptions()
    if ns.Session then ns.Session.Paint() end
    ns.Print(what)
  end
  local R = Rows(p)
  R:Section("Sections, top to bottom")
  local first = R.y -- (the rows are placed on every refresh, in the order)
  local rows = {}
  for _, m in ipairs(ns.MODULES) do
    local _, row = R:Check(m.name, Setting(m.show, function() ns.RefreshOptions() end))
    local up = BButton(row, "Up", 60, function() ns.MoveSection(m.key, -1); Changed(); ns.RefreshOptions() end)
    up:SetPoint("LEFT", CTRL_X + 44, 0)
    local down = BButton(row, "Down", 60, function() ns.MoveSection(m.key, 1); Changed(); ns.RefreshOptions() end)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    rows[m.key] = { row = row, up = up, down = down }
  end
  track({ Refresh = function()
    for i, key in ipairs(ns.SectionOrder()) do
      local r = rows[key]
      r.row:ClearAllPoints(); r.row:SetPoint("TOPLEFT", 0, first - (i - 1) * ROW)
      r.up:SetEnabled(i > 1); r.down:SetEnabled(i < #ns.MODULES)
    end
  end })

  R:Section("Presets")
  for _, pr in ipairs(ns.PRESETS) do
    R:Button(pr[2], "Use", 96, function() ns.ApplyPreset(pr[1]); applied(format("layout: %s.", pr[2])) end, pr[3])
  end
  R:Note("A preset sets what shows and where, not the look. Save your layout below first to come back to it.")

  R:Section("Your layouts")
  for slot = 1, ns.LAYOUT_SLOTS do
    local row = R:Row("Layout " .. slot)
    local save = BButton(row, "Save", 80, function() ns.SaveLayout(slot); applied(format("layout %d saved.", slot)) end)
    save:SetPoint("LEFT", CTRL_X, 0)
    local load = BButton(row, "Load", 80, function()
      if ns.LoadLayout(slot) then applied(format("layout %d loaded.", slot)) end
    end)
    load:SetPoint("LEFT", save, "RIGHT", 4, 0)
    local when = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    when:SetPoint("LEFT", load, "RIGHT", 12, 0)
    track({ Refresh = function()
      local l = type(ns.db.layouts) == "table" and ns.db.layouts[slot]
      local saved = l and l.savedAt and l.savedAt > 0
      when:SetText(saved and ("saved " .. date("%d %b %H:%M", l.savedAt)) or "empty")
      load:SetEnabled(l and true or false)
    end })
  end
  return R:Height()
end

local function PagePicking(p)
  local R = Rows(p)
  R:Section("Which quests to suggest")
  R:Check("Only quests from my current zone", Setting("pickupZoneOnly"))
  R:Slider("Current-zone bonus", 1, 3, 0.1, Setting("zoneBonus"), function(v) return format("x%.1f", v) end,
    "With All zones, quests in your zone rank higher, since there's less travel.")
  R:Note("Quests Nearby needs Questie. Which quests show (levels, low-level, repeatable, dungeon and PvP quests) follows Questie's own settings: Questie options, Quest Level Options.")

  R:Section("Ignored quests")
  local _, row = R:Button("Ignored quests", "Manage...", 120, function() ns.OpenIgnored() end)
  local count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  count:SetPoint("LEFT", CTRL_X + 132, 0)
  R:Note("Right-click a quest under Quests Nearby to ignore it.")
  ignUpdate = function()
    local n = 0
    for _ in pairs(ns.db.ignoredQuests or {}) do n = n + 1 end
    count:SetText(n == 0 and "none" or format(n == 1 and "%d quest" or "%d quests", n))
  end
  return R:Height()
end

local function PageSession(p)
  local function repaint() if ns.Session then ns.Session.Paint() end end
  local R = Rows(p)
  R:Section("Session bar")
  R:Check("Show the session bar", Setting("showSession", repaint),
    "A small bar under Hereabouts with this session's numbers. Hover it for all of them, right-click it to reset.")
  R:Section("What it shows")
  for _, st in ipairs(ns.Session.STATS) do
    local key = st[1]
    local c = R:Check(st[2], {
      function() return (ns.db.sessionStats or {})[key] and true or false end,
      function(v) ns.db.sessionStats = ns.db.sessionStats or {}; ns.db.sessionStats[key] = v or nil; repaint() end })
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db.showSession and true or false) end
  end
  R:Note("Hover the XP bar for everything on XP (per hour, time to level, this session, quests, rested), the gold bar for everything on gold (per hour, gained, what training costs now). Gold counts what comes in, not what you spend.")
  R:Button("Reset the session", "Reset", 96, function() ns.Session.Reset(); ns.Print("session stats reset.") end,
    "Start the session's numbers again (this one goes into your history).")
  return R:Height()
end

local function PageStatus(p)
  local R = Rows(p)
  R:Section("Connected addons")
  local rows = {}
  for _, n in ipairs({ "Questie", "What's Training", "FlareUI", "EllesmereUI", "TomTom" }) do -- (ns.Integrations' order)
    local row = R:Row(n)
    local dot = row:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(W); dot:SetSize(8, 8); dot:SetPoint("LEFT", CTRL_X, 0)
    local state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("LEFT", dot, "RIGHT", 8, 0); state:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    state:SetJustifyH("LEFT"); state:SetWordWrap(true)
    rows[n] = { dot = dot, state = state }
  end
  local COLORS = { on = { 0.35, 0.9, 0.35 }, partial = { 1, 0.82, 0.2 }, loading = { 1, 0.82, 0.2 }, off = { 0.45, 0.45, 0.45 } }
  local rescan, rrow = R:Button("Your level", "Rescan Questie", 130, function() ns.Questie.Scan(); if statusUpdate then statusUpdate() end end)
  Index("Rescan Questie", rescan, R.y)
  statusUpdate = function()
    for _, it in ipairs(ns.Integrations()) do
      local r, c = rows[it[1]], COLORS[it[2]]
      if r then r.dot:SetVertexColor(c[1], c[2], c[3]); r.state:SetText(it[3]) end
    end
    rrow.label:SetText(format("Your level: %d", UnitLevel("player")))
  end
  R:Section("Reset")
  R:Button("Reset to defaults", "Defaults", 96, function() ns.ConfirmDefaults() end,
    "Every setting back to its default. Keeps where the list is, the quests you've ignored and your saved layouts.")
  return R:Height()
end

-- name, icon, what it's for, builder; under a category heading
local PAGES = {
  { "Tracker", "Interface\\Icons\\INV_Misc_Map_01", "Where the list sits, how it looks, and what shows in dungeons and in combat.", PageTracker },
  { "Lists", "Interface\\Icons\\INV_Scroll_03", "Which sections list what, and the details under each quest.", PageLists },
  { "Layout", "Interface\\Icons\\INV_Misc_Gear_01", "The sections' order, presets, and your saved layouts.", PageLayout },
  { "Picking Quests", "Interface\\Icons\\INV_Misc_Spyglass_02", "Which quests Quests Nearby suggests.", PagePicking },
  { "Session", "Interface\\Icons\\INV_Misc_PocketWatch_01", "The session bars under the tracker.", PageSession },
  { "Status", "Interface\\Icons\\INV_Misc_Note_01", "The addons Hereabouts works with, and starting afresh.", PageStatus },
}
ns.OPTION_PAGES = PAGES
local CATEGORIES = { { "Hereabouts", { 1, 2, 3, 4, 5 } }, { "Help", { 6 } } }

-- "Defaults": every setting back to its default, after asking (the game's own dialog)
function ns.ConfirmDefaults()
  local function reset()
    ns.ResetDB(); ns.PlaceFrame(); ns.Questie.RescanSoon(); Restyle(); Changed(); ns.RefreshOptions()
    ns.Print("settings back to their defaults.")
  end
  if not (StaticPopupDialogs and StaticPopup_Show) then reset(); return end
  StaticPopupDialogs.HEREABOUTS_DEFAULTS = StaticPopupDialogs.HEREABOUTS_DEFAULTS or {
    text = "Put every Hereabouts setting back to its default?\n\nWhere the list is, the quests you've ignored and your saved layouts are kept.",
    button1 = OKAY or "Okay", button2 = CANCEL or "Cancel",
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopupDialogs.HEREABOUTS_DEFAULTS.OnAccept = reset
  StaticPopup_Show("HEREABOUTS_DEFAULTS")
end

-- the window: Blizzard's settings frame, else Hereabouts' own
local function Frame()
  local f = Make("Frame", UIParent, "SettingsFrameTemplate", "XPPlannerOptionsWindow")
  if not f then
    local w = Window("XPPlannerOptionsWindow", WIN_W, WIN_H)
    Text(w, "title", "Hereabouts"):SetPoint("TOP", 0, -12)
    return w
  end
  f:SetSize(WIN_W, WIN_H)
  f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:HookScript("OnShow", function(self) self:Raise() end)
  tinsert(UISpecialFrames, "XPPlannerOptionsWindow") -- Esc closes it
  local text = Part(Part(f, "NineSlice"), "Text")
  if text then text:SetText("Hereabouts") end
  if HasAtlas("Options_InnerFrame") then
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetAtlas("Options_InnerFrame", true); inner:SetPoint("TOPLEFT", 17, -64)
  end
  return f
end

local function BuildWindow()
  wipe(index)
  window = Frame()
  window:SetPoint("CENTER")
  reportHost = window
  window:HookScript("OnHide", function() if reportWin then reportWin:Hide() end end)

  -- top left: the logo and what Hereabouts is
  local logo = window:CreateTexture(nil, "ARTWORK")
  logo:SetSize(28, 28); logo:SetPoint("TOPLEFT", 30, -30); logo:SetTexture(LOGO)
  local tagline = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  tagline:SetPoint("LEFT", logo, "RIGHT", 8, 0); tagline:SetText("Your quests, filtered to where you are.")

  -- the page
  local container = CreateFrame("Frame", nil, window)
  container:SetPoint("TOPLEFT", CONT_X, -76); container:SetPoint("BOTTOMRIGHT", -22, 46)
  local title = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  if HasAtlas("Options_HorizontalDivider") then
    local div = container:CreateTexture(nil, "ARTWORK")
    div:SetAtlas("Options_HorizontalDivider"); div:SetHeight(2)
    div:SetPoint("TOPLEFT", 7, -50); div:SetPoint("TOPRIGHT", -26, -50)
  end
  local bug = BButton(container, "Bugs & Feedback", 140, function() ns.ShowReport() end)
  bug:SetPoint("TOPRIGHT", -26, -16)

  -- the buttons at the bottom
  local close = BButton(window, CLOSE or "Close", 96, function() window:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -16, 16)

  -- the categories
  local pages, items, current = {}, {}, 1
  local function paintItems()
    for i, it in ipairs(items) do
      local on, over = i == current, it.over
      Font(it.label, on and "GameFontHighlight" or "GameFontNormal")
      if on and HasAtlas("Options_List_Active") then it.tex:SetAtlas("Options_List_Active"); it.tex:SetAllPoints(); it.tex:Show()
      elseif over and HasAtlas("Options_List_Hover") then it.tex:SetAtlas("Options_List_Hover"); it.tex:SetAllPoints(); it.tex:Show()
      elseif on or over then it.tex:SetColorTexture(1, 1, 1, on and 0.12 or 0.06); it.tex:SetAllPoints(); it.tex:Show()
      else it.tex:Hide() end
    end
  end
  local function Select(i)
    current = i
    for k, pg in ipairs(pages) do pg.scroll:SetShown(k == i) end
    title:SetText(PAGES[i][1])
    paintItems()
  end
  local y = -76
  for h, cat in ipairs(CATEGORIES) do
    local head = CreateFrame("Frame", nil, window)
    head:SetSize(LIST_W, 30); head:SetPoint("TOPLEFT", LIST_X, y)
    -- the header band: its art is taller than the band, which is at its top (seen in game), so it's
    -- placed by its top at its own height, as wide as the list
    local bg = head:CreateTexture(nil, "ARTWORK")
    if HasAtlas("Options_CategoryHeader_" .. h) then
      bg:SetAtlas("Options_CategoryHeader_" .. h, true); bg:SetWidth(LIST_W); bg:SetPoint("TOPLEFT")
    end
    local hl = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    if not _G.GameFontHighlightMedium then hl:SetFontObject("GameFontHighlightLarge") end
    hl:SetPoint("LEFT", 20, -1); hl:SetText(cat[1])
    y = y - 32
    for _, i in ipairs(cat[2]) do
      local b = CreateFrame("Button", nil, window)
      b:SetSize(LIST_W, 20); b:SetPoint("TOPLEFT", LIST_X, y)
      b.tex = b:CreateTexture(nil, "BACKGROUND")
      b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      b.label:SetPoint("TOPLEFT", 36, 1); b.label:SetPoint("BOTTOMRIGHT"); b.label:SetJustifyH("LEFT")
      b.label:SetText(PAGES[i][1])
      b:SetScript("OnClick", function() Select(i) end)
      b:SetScript("OnEnter", function(self)
        self.over = true; paintItems()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(PAGES[i][1], 1, 1, 1)
        GameTooltip:AddLine(PAGES[i][3], nil, nil, nil, true); GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function(self) self.over = false; paintItems(); GameTooltip:Hide() end)
      items[i] = b
      y = y - 22
    end
    y = y - 18
  end

  -- each page in Blizzard's scroll frame (its minimal scroll bar), else a plain one with the wheel
  for i, def in ipairs(PAGES) do
    local scroll = Make("ScrollFrame", container, "ScrollFrameTemplate") or CreateFrame("ScrollFrame", nil, container)
    scroll:SetPoint("TOPLEFT", 0, -56); scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(CHILD_W)
    scroll:SetScrollChild(child)
    building = i
    child:SetHeight(math.max(1, def[4](child)))
    building = nil
    if not Part(scroll, "ScrollBar") then
      scroll:EnableMouseWheel(true)
      scroll:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 48)))
      end)
    end
    function scroll.ScrollTo(v)
      local max = math.max(0, child:GetHeight() - scroll:GetHeight())
      scroll:SetVerticalScroll(math.max(0, math.min(max, v)))
    end
    scroll:Hide()
    pages[i] = { scroll = scroll, child = child }
  end

  -- search (Blizzard's search box): any setting by name; pick one to go to it and see it flash
  local search = Make("EditBox", window, "SearchBoxTemplate") or CreateFrame("EditBox", nil, window, "BackdropTemplate")
  search:SetSize(260, 20); search:SetAutoFocus(false)
  search:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 4, 20)
  if not Part(search, "Instructions") then
    search:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 }); search:SetBackdropColor(0, 0, 0, 0.6)
    search:SetBackdropBorderColor(0.5, 0.5, 0.5, 1); search:SetFontObject("GameFontHighlight"); search:SetTextInsets(6, 6, 0, 0)
  end
  local results = CreateFrame("Frame", nil, window, "BackdropTemplate")
  results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -2); results:SetWidth(320)
  results:SetFrameLevel(window:GetFrameLevel() + 40)
  results:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  results:SetBackdropColor(0.05, 0.05, 0.05, 0.97); results:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  results:Hide()
  local lines = {}
  local function Flash(f)
    local t = 0
    local holder = CreateFrame("Frame")
    holder:SetScript("OnUpdate", function(self, dt)
      t = t + dt
      f:SetAlpha(0.35 + 0.65 * math.abs(math.cos(t * 6)))
      if t > 1.6 then f:SetAlpha(1); self:SetScript("OnUpdate", nil) end
    end)
  end
  local function Go(e)
    results:Hide(); search:SetText(""); search:ClearFocus()
    Select(e.page)
    pages[e.page].scroll.ScrollTo(-e.y - 40)
    Flash(e.frame)
  end
  local function Find(text)
    local q, found = (text or ""):lower(), {}
    if #q < 2 then return found end
    for _, e in ipairs(index) do
      if e.label:lower():find(q, 1, true) then found[#found + 1] = e end
      if #found >= 10 then break end
    end
    return found
  end
  search:HookScript("OnTextChanged", function(self)
    local found = Find(self:GetText())
    for i = 1, math.max(#found, #lines) do
      local e, b = found[i], lines[i]
      if e and not b then
        b = CreateFrame("Button", nil, results)
        b:SetSize(308, 20); b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("LEFT", 4, 0); b.text:SetPoint("RIGHT", -4, 0); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(false)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        lines[i] = b
      end
      if b then
        b:SetShown(e ~= nil)
        if e then
          b.text:SetText(e.label .. "  |cff9d9d9d" .. PAGES[e.page][1] .. "|r")
          b:SetScript("OnClick", function() Go(e) end)
        end
      end
    end
    results:SetHeight(#found * 20 + 12)
    results:SetShown(#found > 0)
  end)
  search:HookScript("OnEnterPressed", function(self)
    local e = Find(self:GetText())[1]
    if e then Go(e) else self:ClearFocus() end
  end)
  window:HookScript("OnHide", function() results:Hide() end)

  Select(1)
  window:SetScript("OnShow", function(self) self:Raise(); ns.RefreshOptions() end)
  local t = 0
  window:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    if t > 1 then t = 0; if statusUpdate then statusUpdate() end end
  end)
  window:Hide()
end
ns.OptionsIndex = function() return index end

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
