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
-- The settings window (2.1.0): laid out like Questie's options, in Hereabouts' own look. The logo
-- sits in a round frame at the top left. Each page has its title and what it's for, and holds
-- framed groups of settings in two columns (scrolling when long). The pages are tabs down the right
-- edge, one icon each, and the search box finds any setting and jumps to it.
---------------------------------------------------------------------------
local window, refreshers, statusUpdate, ignUpdate = nil, {}, nil, nil
local WIN_W, WIN_H = 640, 600
local CHILD_W = 582                  -- a page's scrolling area
local BOX_X, BOX_W = 8, 566          -- the framed groups
local COL1, COL2 = 22, 302           -- the two columns inside a group
local COL_W = 260
local PAGE_W = BOX_W - 28            -- a full-width row inside a group
local LOGO = "Interface\\AddOns\\Hereabouts\\media\\Logo"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function track(x) refreshers[#refreshers + 1] = x; return x end

function ns.RefreshOptions()
  if not (window and window:IsShown()) then return end
  for _, x in ipairs(refreshers) do x.Refresh() end
  if statusUpdate then statusUpdate() end
  if ignUpdate then ignUpdate() end
end

local function Restyle() ns.ApplyBackdrop(); ns.RestyleOptions(); ns.RefreshOptions() end

-- Search: every labelled setting, its page and where it is on it
local index, building = {}, nil
local function Index(label, frame, y)
  if type(label) == "string" and label ~= "" and building then
    index[#index + 1] = { label = label, page = building, frame = frame, y = y }
  end
  return frame
end

-- A framed group: its title above, a box under it. `top` is the title's y; the rows go at g.y
-- (moving down with g:Next), and g:Close() sizes the box and gives the next group's top.
local function Group(p, title, top)
  local hdr = Text(p, "header", title)
  hdr:SetPoint("TOPLEFT", BOX_X + 4, top)
  Index(title, hdr, top)
  local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
  box:SetPoint("TOPLEFT", BOX_X, top - 22); box:SetWidth(BOX_W)
  box:SetFrameLevel(math.max(0, p:GetFrameLevel()))
  box:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  Skin(function(th)
    box:SetBackdropColor(0, 0, 0, th.eui and 0.35 or 0.28)
    box:SetBackdropBorderColor(RGB(th.eui and th.edge or th.accent, th.eui and 1 or 0.55))
  end)
  local g = { y = top - 34 }
  function g.Next(_, h) g.y = g.y - (h or 26) end
  function g.Close(_)
    local h = (top - 22) - g.y + 4
    box:SetHeight(h)
    return top - 22 - h - 18
  end
  return g
end

-- the page builders: each gets its scrolling area `p` and returns how tall it is
local function PageTracker(p)
  local g = Group(p, "Position", 0)
  Index("Lock in place", track(Check(p, "Lock in place", COL1, g.y, Setting("locked"), COL_W)), g.y)
  Index("Replace the quest tracker", track(Check(p, "Replace the quest tracker", COL2, g.y,
    Setting("replaceTracker", function() ns.ApplyReplace() end), COL_W)), g.y)
  g:Next()
  Index("Hide the list", track(Check(p, "Hide the list", COL1, g.y, Setting("hidden"), COL_W)), g.y)
  local under = Button(p, "Move under quest tracker", 200, function() ns.db.pos = nil; ns.PlaceFrame(); Changed() end)
  under:SetPoint("TOPLEFT", COL2, g.y)
  Index("Move under quest tracker", under, g.y)
  g:Next(28)
  Note(p, "Unlock, then drag a section heading to move the list.", COL1, g.y, PAGE_W)
  g:Next(18)
  local top = g:Close()

  g = Group(p, "Look", top)
  -- (the look follows EllesmereUI / FlareUI on its own when they're installed)
  local border = track(Check(p, "Border (without FlareUI / EllesmereUI)", COL1, g.y, Setting("showBorder", Restyle), COL_W))
  local r = border.Refresh
  border.Refresh = function() r(); border.SetActive(not ns.UsingFlare() and not ns.UsingEUI()) end
  Index("Border", border, g.y)
  -- the earlier section headings (the quest tracker's header art), for those who prefer them
  local classic = track(Check(p, "Classic section headings", COL2, g.y, Setting("classicHeaders", function() ns.Refresh() end), COL_W))
  local rc = classic.Refresh
  classic.Refresh = function() rc(); classic.SetActive(not ns.UsingFlare()) end
  Index("Classic section headings", classic, g.y)
  g:Next(32)
  Index("Scale", track(Slider(p, "Scale", COL1, g.y, 240, 0.6, 1.5, 0.05, Setting("scale", function() ns.PlaceFrame() end), pct)), g.y)
  Index("Background opacity", track(Slider(p, "Background opacity", COL2, g.y, 240, 0, 1, 0.05,
    Setting("bgAlpha", function() ns.ApplyBackdrop() end), pct)), g.y)
  g:Next(42)
  Index("Max height", track(Slider(p, "Max height (then scrolls)", COL1, g.y, 240, 120, 900, 10, Setting("maxHeight"),
    function(v) return v .. " px" end)), g.y)
  g:Next(38)
  top = g:Close()

  -- which sections show in dungeons and in combat (ticked = shown)
  g = Group(p, "Show in dungeons and in combat", top)
  local C1, C2 = 330, 440
  Text(p, "note", "In dungeons"):SetPoint("TOPLEFT", C1 - 22, g.y)
  Text(p, "note", "In combat"):SetPoint("TOPLEFT", C2 - 18, g.y)
  g:Next(20)
  local function Shown(tbl, key)
    return { function() return not (ns.db[tbl] and ns.db[tbl][key]) end,
      function(v) ns.db[tbl] = ns.db[tbl] or {}; ns.db[tbl][key] = (not v) or nil end }
  end
  for _, sec in ipairs({ { "quests", "Active Quests" }, { "turnin", "Quests to Turn In" }, { "pickup", "Quests Nearby" },
      { "training", "Training" }, { "dungeons", "Dungeons" } }) do
    local name = Text(p, "line", sec[2]); name:SetPoint("TOPLEFT", COL1, g.y - 2)
    Index(sec[2] .. " in dungeons and combat", name, g.y)
    track(Check(p, nil, C1, g.y, Shown("hideInInstance", sec[1]), 24))
    track(Check(p, nil, C2, g.y, Shown("hideInCombat", sec[1]), 24))
    g:Next(22)
  end
  return -g:Close()
end

local function PageLists(p)
  local g = Group(p, "What to list", 0)
  local count = function(v) return "up to " .. v end
  -- one row per section: on/off on the left, how many on the right; options indented under it
  local function Row(label, key, maxKey, maxV)
    local s = maxKey and Slider(p, nil, COL2, g.y, 170, 1, maxV, 1, Setting(maxKey), count)
    local c = Check(p, label, COL1, g.y, { function() return ns.db[key] end, function(v)
      ns.db[key] = v; ns.RefreshOptions() -- greys out its slider and options
    end }, COL_W)
    track(c); Index(label, c, g.y)
    if s then
      track(s)
      local r = c.Refresh
      c.Refresh = function() r(); s.SetActive(ns.db[key] and true or false) end
    end
    g:Next(24)
  end
  local function Sub(label, key, parentKey)
    local c = Check(p, label, COL1 + 22, g.y, Setting(key), COL_W - 22)
    track(c); Index(label, c, g.y)
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db[parentKey] and true or false) end
    g:Next(30)
  end
  Row("Active Quests", "showActive", "maxQuests", 20)
  Sub("Only quests in my current zone", "activeZoneOnly", "showActive")
  Row("Quests to Turn In", "showTurnIn", "maxTurnIn", 20); g:Next(6)
  Row("Quests Nearby (Questie)", "showPickup", "maxPickup", 20); g:Next(6)
  Row("Dungeons", "showDungeons", "maxDungeons", 6)
  Sub("Only dungeons in my current zone", "dungeonZoneOnly", "showDungeons")
  Row("Training (What's Training)", "showTraining", "maxTraining", 30)
  Sub("Also spells at my next level", "showNextLevel", "showTraining")
  local top = g:Close()

  g = Group(p, "Details", top)
  local function C(label, key, col, onSet, indentOf)
    local c = track(Check(p, label, (col == 2 and COL2 or COL1) + (indentOf and 22 or 0), g.y, Setting(key, onSet), COL_W - (indentOf and 22 or 0)))
    Index(label, c, g.y)
    if indentOf then
      local r = c.Refresh
      c.Refresh = function() r(); c.SetActive(ns.db[indentOf] and true or false) end
    end
    return c
  end
  C("Sort by level (highest first)", "sortByLevel", 1); C("XP reward", "showXP", 2); g:Next()
  C("Objectives under active quests", "showObjectives", 1, function() ns.RefreshOptions() end); C("Quest giver and zone", "showStarter", 2); g:Next()
  C("Hide finished objectives", "hideDoneObjectives", 1, nil, "showObjectives"); C("Training prices by city", "showCityPrices", 2); g:Next()
  C("Quest item buttons (beside the quest)", "showQuestItems", 1, function() ns.Refresh() end)
  local cf = C("In combat: mark my enemy's quests", "combatFocus", 2, function() ns.Refresh() end)
  cf:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("In combat: mark my enemy's quests", 1, 1, 1)
    GameTooltip:AddLine("While you fight something a quest of yours needs (to kill it, or for what it drops), that quest is highlighted light blue where it is in Active Quests (nothing moves), with the objective it counts for lit up. Your target first; with no quest target, the enemies fighting you (needs enemy nameplates on). Back to normal when combat ends.", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
  end)
  cf:HookScript("OnLeave", function() GameTooltip:Hide() end)
  g:Next()
  C("Soft animations (objective progress, combat mark)", "animations", 1)
  g:Next()
  return -g:Close()
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
  local g = Group(p, "Sections, top to bottom", 0)
  local first = g.y -- (the rows are placed on every refresh, from here)
  local rows = {}
  for _, m in ipairs(ns.MODULES) do
    local r = {}
    r.check = track(Check(p, m.name, COL1, first, Setting(m.show, function() ns.RefreshOptions() end), 240))
    Index(m.name, r.check, first)
    r.up = Button(p, "Up", 56, function() ns.MoveSection(m.key, -1); Changed(); ns.RefreshOptions() end)
    r.down = Button(p, "Down", 56, function() ns.MoveSection(m.key, 1); Changed(); ns.RefreshOptions() end)
    rows[m.key] = r
  end
  track({ Refresh = function()
    for i, key in ipairs(ns.SectionOrder()) do
      local r, ry = rows[key], first - (i - 1) * 26
      r.check:ClearAllPoints(); r.check:SetPoint("TOPLEFT", COL1, ry)
      r.up:ClearAllPoints(); r.up:SetPoint("TOPLEFT", COL2, ry)
      r.down:ClearAllPoints(); r.down:SetPoint("TOPLEFT", COL2 + 62, ry)
      r.up:SetAlpha(i > 1 and 1 or 0.35); r.down:SetAlpha(i < #ns.MODULES and 1 or 0.35)
    end
  end })
  g:Next(#ns.MODULES * 26)
  local top = g:Close()

  g = Group(p, "Presets", top)
  for i, pr in ipairs(ns.PRESETS) do
    local b = Button(p, pr[2], 100, function()
      ns.ApplyPreset(pr[1]); applied(format("layout: %s.", pr[2]))
    end)
    b:SetPoint("TOPLEFT", COL1 + (i - 1) * 106, g.y)
    Tip(b, pr[2], pr[3])
    Index("Preset: " .. pr[2], b, g.y)
  end
  g:Next(30)
  Note(p, "A preset sets what shows and where, not the look. Save your layout below first to come back to it.", COL1, g.y, PAGE_W)
  g:Next(20)
  top = g:Close()

  g = Group(p, "Your layouts", top)
  for slot = 1, ns.LAYOUT_SLOTS do
    local label = Text(p, "line", "")
    label:SetPoint("TOPLEFT", COL1, g.y - 4)
    local save = Button(p, "Save", 64, function() ns.SaveLayout(slot); applied(format("layout %d saved.", slot)) end)
    save:SetPoint("TOPLEFT", COL2, g.y)
    local load = Button(p, "Load", 64, function()
      if ns.LoadLayout(slot) then applied(format("layout %d loaded.", slot)) end
    end)
    load:SetPoint("TOPLEFT", COL2 + 70, g.y)
    Index("Layout " .. slot, label, g.y)
    track({ Refresh = function()
      local l = type(ns.db.layouts) == "table" and ns.db.layouts[slot]
      label:SetText(format("Layout %d: %s", slot, (l and l.savedAt and l.savedAt > 0) and ("saved " .. date("%d %b %H:%M", l.savedAt)) or "empty"))
      load:SetAlpha(l and 1 or 0.35)
    end })
    g:Next(26)
  end
  return -g:Close()
end

local function PagePicking(p)
  local g = Group(p, "Which quests to suggest", 0)
  Index("Only quests from my current zone", track(Check(p, "Only quests from my current zone", COL1, g.y, Setting("pickupZoneOnly"), COL_W)), g.y)
  g:Next(28)
  Note(p, "Quests Nearby needs Questie. Which quests show (levels, low-level, repeatable, dungeon and PvP quests) follows Questie's own settings: Questie options, Quest Level Options.", COL1, g.y, PAGE_W)
  g:Next(40)
  Index("Current-zone bonus", track(Slider(p, "Current-zone bonus", COL1, g.y, 240, 1, 3, 0.1, Setting("zoneBonus"),
    function(v) return format("x%.1f", v) end)), g.y)
  Note(p, "With All zones, quests in your zone rank higher, since there's less travel.", COL2, g.y - 4, COL_W)
  g:Next(42)
  local top = g:Close()

  g = Group(p, "Ignored quests", top)
  local count = Text(p, "line", "")
  count:SetPoint("TOPLEFT", COL1, g.y - 4)
  local manage = Button(p, "Manage...", 120, function() ns.OpenIgnored() end)
  manage:SetPoint("TOPLEFT", COL2, g.y)
  Index("Ignored quests: manage", manage, g.y)
  g:Next(30)
  Note(p, "Right-click a quest under Quests Nearby to ignore it.", COL1, g.y, PAGE_W)
  g:Next(18)
  ignUpdate = function()
    local n = 0
    for _ in pairs(ns.db.ignoredQuests or {}) do n = n + 1 end
    count:SetText(n == 0 and "No quests ignored." or format(n == 1 and "%d quest ignored." or "%d quests ignored.", n))
  end
  return -g:Close()
end

local function PageSession(p)
  local function repaint() if ns.Session then ns.Session.Paint() end end
  local g = Group(p, "Session bar", 0)
  Index("Show the session bar", track(Check(p, "Show the session bar under the tracker", COL1, g.y, Setting("showSession", repaint), 340)), g.y)
  g:Next(28)
  Note(p, "A small bar under Hereabouts with this session's numbers. Hover it for all of them, right-click it to reset.", COL1, g.y, PAGE_W)
  g:Next(20)
  local top = g:Close()

  g = Group(p, "What it shows", top)
  for i, st in ipairs(ns.Session.STATS) do
    local key = st[1]
    local col = (i - 1) % 2
    local c = track(Check(p, st[2], col == 0 and COL1 or COL2, g.y, {
      function() return (ns.db.sessionStats or {})[key] and true or false end,
      function(v) ns.db.sessionStats = ns.db.sessionStats or {}; ns.db.sessionStats[key] = v or nil; repaint() end }, COL_W))
    Index(st[2], c, g.y)
    local r = c.Refresh
    c.Refresh = function() r(); c.SetActive(ns.db.showSession and true or false) end
    if col == 1 or i == #ns.Session.STATS then g:Next() end
  end
  g:Next(4)
  Note(p, "Hover the XP bar for everything on XP (per hour, time to level, this session, quests, rested), the gold bar for everything on gold (per hour, gained, what training costs now). Gold counts what comes in, not what you spend.",
    COL1, g.y, PAGE_W)
  g:Next(42)
  local reset = Button(p, "Reset session", 130, function() ns.Session.Reset(); ns.Print("session stats reset.") end)
  reset:SetPoint("TOPLEFT", COL1, g.y)
  Index("Reset session", reset, g.y)
  g:Next(28)
  return -g:Close()
end

local function PageStatus(p)
  local g = Group(p, "Connected addons", 0)
  local rows = {}
  local NAMES = { "Questie", "What's Training", "FlareUI", "EllesmereUI", "TomTom" } -- (ns.Integrations' order)
  for _, n in ipairs(NAMES) do
    local dot = p:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(W); dot:SetSize(8, 8); dot:SetPoint("TOPLEFT", COL1 + 2, g.y - 5)
    local name = Text(p, "line", n); name:SetPoint("TOPLEFT", COL1 + 18, g.y)
    Index(n, name, g.y)
    local state = Text(p, "note", ""); state:SetPoint("TOPLEFT", COL1 + 160, g.y - 1); state:SetWidth(PAGE_W - 160)
    rows[n] = { dot = dot, state = state }
    g:Next(30)
  end
  local COLORS = { on = { 0.35, 0.9, 0.35 }, partial = { 1, 0.82, 0.2 }, loading = { 1, 0.82, 0.2 }, off = { 0.45, 0.45, 0.45 } }
  local level = Text(p, "line", "")
  level:SetPoint("TOPLEFT", COL1, g.y)
  local rescan = Button(p, "Rescan Questie", 130, function() ns.Questie.Scan(); if statusUpdate then statusUpdate() end end)
  rescan:SetPoint("TOPLEFT", COL2, g.y + 4)
  Index("Rescan Questie", rescan, g.y)
  g:Next(28)
  statusUpdate = function()
    for _, it in ipairs(ns.Integrations()) do
      local r, c = rows[it[1]], COLORS[it[2]]
      if r then r.dot:SetVertexColor(c[1], c[2], c[3]); r.state:SetText(it[3]) end
    end
    level:SetText(format("Your level: %d", UnitLevel("player")))
  end
  local top = g:Close()

  g = Group(p, "Reset", top)
  local reset = Button(p, "Reset to defaults", 140, function()
    ns.ResetDB(); ns.PlaceFrame(); ns.Questie.RescanSoon(); Restyle(); Changed(); ns.RefreshOptions()
  end)
  reset:SetPoint("TOPLEFT", COL1, g.y)
  Index("Reset to defaults", reset, g.y)
  Note(p, "Keeps where the list is, the quests you've ignored and your saved layouts.", COL1 + 152, g.y - 5, PAGE_W - 152)
  g:Next(30)
  return -g:Close()
end

-- name, icon, what it's for, builder
local PAGES = {
  { "Tracker", "Interface\\Icons\\INV_Misc_Map_01", "Where the list sits, how it looks, and what shows in dungeons and in combat.", PageTracker },
  { "Lists", "Interface\\Icons\\INV_Scroll_03", "Which sections list what, and the details under each quest.", PageLists },
  { "Layout", "Interface\\Icons\\INV_Misc_Gear_01", "The sections' order, presets, and your saved layouts.", PageLayout },
  { "Picking Quests", "Interface\\Icons\\INV_Misc_Spyglass_02", "Which quests Quests Nearby suggests.", PagePicking },
  { "Session", "Interface\\Icons\\INV_Misc_PocketWatch_01", "The session bars under the tracker.", PageSession },
  { "Status", "Interface\\Icons\\INV_Misc_Note_01", "The addons Hereabouts works with, and starting afresh.", PageStatus },
}
ns.OPTION_PAGES = PAGES

-- a thin scrollbar in the window's colours: wheel or drag
local function Scroller(scroll, child)
  local bar = CreateFrame("Frame", nil, scroll:GetParent())
  bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 12, 0); bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 12, 0)
  bar:SetWidth(6)
  local trackTex = bar:CreateTexture(nil, "BACKGROUND")
  trackTex:SetAllPoints()
  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(6)
  local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
  thumbTex:SetAllPoints()
  Skin(function(th)
    trackTex:SetColorTexture(RGB(th.eui and th.edge or th.accent, 0.25))
    thumbTex:SetColorTexture(RGB(th.eui and th.accent or th.title, 0.8))
  end)
  local function Max() return math.max(0, child:GetHeight() - scroll:GetHeight()) end
  local function Place()
    local max, h = Max(), scroll:GetHeight()
    bar:SetShown(max > 0)
    if max <= 0 then return end
    local th = math.max(24, h * h / child:GetHeight())
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * scroll:GetVerticalScroll() / max)
  end
  function scroll.ScrollTo(v)
    scroll:SetVerticalScroll(math.max(0, math.min(Max(), v)))
    Place()
  end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, d) scroll.ScrollTo(scroll:GetVerticalScroll() - d * 48) end)
  scroll:SetScript("OnSizeChanged", Place)
  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function()
    local _, y0 = GetCursorPosition()
    local s0, k = scroll:GetVerticalScroll(), thumb:GetEffectiveScale()
    thumb:SetScript("OnUpdate", function()
      local _, y = GetCursorPosition()
      local free = scroll:GetHeight() - thumb:GetHeight()
      if free > 0 then scroll.ScrollTo(s0 + (y0 - y) / k * Max() / free) end
    end)
  end)
  thumb:SetScript("OnMouseUp", function() thumb:SetScript("OnUpdate", nil) end)
  scroll.PlaceBar = Place
end

-- the logo in a round frame, overlapping the window's top left corner (like Questie's emblem)
local function Emblem(win)
  local e = CreateFrame("Frame", nil, win)
  e:SetSize(66, 66); e:SetPoint("TOPLEFT", -18, 18)
  e:SetFrameLevel(win:GetFrameLevel() + 20)
  local ring = e:CreateTexture(nil, "BACKGROUND")
  ring:SetAllPoints()
  local inner = e:CreateTexture(nil, "BORDER")
  inner:SetPoint("TOPLEFT", 4, -4); inner:SetPoint("BOTTOMRIGHT", -4, 4)
  inner:SetColorTexture(0.04, 0.035, 0.03, 1)
  local logo = e:CreateTexture(nil, "ARTWORK")
  logo:SetPoint("TOPLEFT", 7, -7); logo:SetPoint("BOTTOMRIGHT", -7, 7)
  logo:SetTexture(LOGO)
  -- round (the game's portrait mask); a square logo if the client can't
  pcall(function()
    for _, t in ipairs({ ring, inner, logo }) do
      local m = e:CreateMaskTexture()
      m:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      m:SetAllPoints(t)
      t:AddMaskTexture(m)
    end
  end)
  Skin(function(th) ring:SetColorTexture(RGB(th.eui and th.accent or th.accent)) end)
  return e
end

local function BuildWindow()
  wipe(index)
  window = Window("XPPlannerOptionsWindow", WIN_W, WIN_H)
  window:SetPoint("CENTER")
  reportHost = window
  window:HookScript("OnHide", function() if reportWin then reportWin:Hide() end end)
  Emblem(window)

  -- title bar: the name in the middle, Bugs & Feedback and the × on the right
  local band = window:CreateTexture(nil, "BORDER")
  band:SetPoint("TOPLEFT", 4, -4); band:SetPoint("TOPRIGHT", -4, -4); band:SetHeight(30)
  local bandLine = window:CreateTexture(nil, "BORDER")
  bandLine:SetPoint("TOPLEFT", band, "BOTTOMLEFT"); bandLine:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT"); bandLine:SetHeight(1)
  Skin(function(th)
    band:SetColorTexture(0, 0, 0, 0.35)
    bandLine:SetColorTexture(RGB(th.eui and th.edge or th.accent, th.eui and 1 or 0.6))
  end)
  local title = Text(window, "title", "Hereabouts")
  title:SetPoint("TOP", 0, -12)
  local bug = Button(window, "Bugs & Feedback", 130, function() ns.ShowReport() end)
  bug:SetHeight(20); bug:SetPoint("TOPRIGHT", -34, -9)

  -- the page's own title and what it's for
  local pageTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pageTitle:SetPoint("TOPLEFT", 60, -44)
  local pageNote = Text(window, "note", "")
  pageNote:SetPoint("TOPLEFT", 60, -66); pageNote:SetWidth(330)
  Skin(function(th) pageTitle:SetTextColor(RGB(th.title)) end)

  -- the panel the pages scroll in
  local panel = CreateFrame("Frame", nil, window, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", 16, -92); panel:SetPoint("BOTTOMRIGHT", -16, 16)
  panel:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  Skin(function(th)
    panel:SetBackdropColor(0, 0, 0, 0.25)
    panel:SetBackdropBorderColor(RGB(th.eui and th.edge or th.accent, th.eui and 1 or 0.7))
  end)

  -- pages and their tabs (icons down the right edge)
  local pages, tabs, current = {}, {}, 1
  local function paintTabs(th)
    th = th or ns.Theme()
    for i, t in ipairs(tabs) do
      local on = i == current
      t:SetBackdropColor(0.04, 0.035, 0.03, 1)
      t:SetBackdropBorderColor(RGB(on and th.title or (t.hover and th.hover or (th.eui and th.edge or th.accent)), 1))
      t.icon:SetDesaturated(not on and not t.hover)
      t.icon:SetAlpha((on or t.hover) and 1 or 0.75)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", window, "TOPRIGHT", on and 1 or -3, -92 - (i - 1) * 48)
    end
  end
  local function Select(i)
    current = i
    for k, pg in ipairs(pages) do pg.scroll:SetShown(k == i) end
    pageTitle:SetText(PAGES[i][1]); pageNote:SetText(PAGES[i][3])
    paintTabs()
    pages[i].scroll.PlaceBar()
  end
  for i, def in ipairs(PAGES) do
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 4, -10); scroll:SetPoint("BOTTOMRIGHT", -16, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(CHILD_W)
    scroll:SetScrollChild(child)
    building = i
    local h = def[4](child)
    building = nil
    child:SetHeight(math.max(1, h))
    Scroller(scroll, child)
    scroll:Hide()
    pages[i] = { scroll = scroll, child = child }

    local t = CreateFrame("Button", nil, window, "BackdropTemplate")
    t:SetSize(42, 42)
    t:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", 4, -4); t.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    t.icon:SetTexture(def[2]); t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:SetScript("OnClick", function() Select(i) end)
    t:SetScript("OnEnter", function(self)
      self.hover = true; paintTabs()
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(def[1], 1, 1, 1)
      GameTooltip:AddLine(def[3], 0.85, 0.85, 0.85, true); GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self) self.hover = false; paintTabs(); GameTooltip:Hide() end)
    tabs[i] = t
  end
  Skin(paintTabs)

  -- search: any setting by name; pick one to go to its page and see it flash
  local search = CreateFrame("EditBox", nil, window, "BackdropTemplate")
  search:SetSize(190, 20); search:SetPoint("TOPRIGHT", -18, -52)
  search:SetAutoFocus(false); search:SetTextInsets(6, 6, 0, 0)
  search:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  local hint = Text(search, "note", "Search settings")
  hint:SetPoint("LEFT", 7, 0)
  Skin(function(th)
    search:SetFontObject(th.lineFont); search:SetTextColor(RGB(th.title))
    search:SetBackdropColor(0, 0, 0, 0.55); search:SetBackdropBorderColor(RGB(th.eui and th.edge or th.accent, 0.8))
  end)
  local results = CreateFrame("Frame", nil, window, "BackdropTemplate")
  results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -2); results:SetWidth(300)
  results:SetFrameLevel(window:GetFrameLevel() + 30)
  results:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  Skin(function(th)
    results:SetBackdropColor(0.04, 0.035, 0.03, 0.98); results:SetBackdropBorderColor(RGB(th.eui and th.edge or th.accent, 1))
  end)
  results:Hide()
  local lines = {}
  local function Flash(f)
    local t = 0
    f:SetScript("OnUpdate", nil)
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
    pages[e.page].scroll.ScrollTo(-e.y - 30)
    Flash(e.frame)
  end
  local function Find(text)
    local q = (text or ""):lower()
    local found = {}
    if #q < 2 then return found end
    for _, e in ipairs(index) do
      if e.label:lower():find(q, 1, true) then found[#found + 1] = e end
      if #found >= 8 then break end
    end
    return found
  end
  search:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    hint:SetShown(text == "")
    local found = Find(text)
    for i = 1, math.max(#found, #lines) do
      local e = found[i]
      local b = lines[i]
      if e and not b then
        b = CreateFrame("Button", nil, results)
        b:SetSize(292, 20)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
        b.text = Text(b, "line", ""); b.text:SetPoint("LEFT", 4, 0); b.text:SetPoint("RIGHT", -4, 0); b.text:SetWordWrap(false)
        b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.08); b.hl:Hide()
        b:SetScript("OnEnter", function() b.hl:Show() end)
        b:SetScript("OnLeave", function() b.hl:Hide() end)
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
    results:SetHeight(#found * 20 + 8)
    results:SetShown(#found > 0)
  end)
  search:SetScript("OnEnterPressed", function(self)
    local e = Find(self:GetText())[1]
    if e then Go(e) else self:ClearFocus() end
  end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  window:HookScript("OnHide", function() results:Hide() end)

  Select(1)
  window:SetScript("OnShow", function() ns.RefreshOptions(); pages[current].scroll.PlaceBar() end)
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
