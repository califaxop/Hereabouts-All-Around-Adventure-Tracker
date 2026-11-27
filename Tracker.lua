-- The list, drawn in the quest tracker's style: section headers, yellow titles,
-- "- objective" lines, using the tracker's own fonts where the client has them.
local _, ns = ...

local WIDTH = 235

-- the first of these font objects that exists and is a readable size: another addon can shrink the
-- game's tracker fonts (EllesmereUI's quest tracker sets them to 1 px to hide the game's tracker)
local function FontObj(...)
  for i = 1, select("#", ...) do
    local f = _G[select(i, ...)]
    if f and f.GetFont then
      local ok, path, size = pcall(f.GetFont, f)
      if ok and type(path) == "string" and type(size) == "number" and size >= 8 then return f end
    end
  end
  return _G.GameFontNormal
end
-- the tracker's fonts to copy (looked up each time: another addon may have shrunk them since)
local function Bases()
  return FontObj("ObjectiveTrackerHeaderFont", "GameFontNormalMed2", "GameFontNormal"),
    FontObj("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontNormal"),
    FontObj("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontHighlightSmall")
end
-- our own font objects, copied from the tracker's (or set to EllesmereUI's font in its style), so a
-- style change re-fonts every line at once
local HEADER_FONT = CreateFont("HereaboutsHeaderFont")
local TITLE_FONT  = CreateFont("HereaboutsTitleFont")
local LINE_FONT   = CreateFont("HereaboutsLineFont")
do
  local h, t, l = Bases()
  HEADER_FONT:CopyFontObject(h); TITLE_FONT:CopyFontObject(t); LINE_FONT:CopyFontObject(l)
end

-- EllesmereUI style: EllesmereUI's skinning API (EllesmereUI.RegisterSkin, its SKINNING_API.md) paints
-- the settings windows' shells in the player's theme; the tracker takes its accent, panel colour and font.
if type(EllesmereUI) == "table" and EllesmereUI.RegisterSkin then
  EllesmereUI.RegisterSkin("Hereabouts", function(S)
    ns.euiSkin = S
    local function again() if ns.db then ns.ApplyBackdrop(); if ns.RestyleOptions then ns.RestyleOptions() end; ns.Refresh() end end
    if S.OnLooksChanged then S.OnLooksChanged(again) end
    again()
  end)
end
function ns.UsingEUI()
  local S = ns.euiSkin
  if S and (not S.IsEnabled or S.IsEnabled()) then return S end -- whenever it's installed and skinning us
end
local function EUIAccent(S)
  local ok, r, g, b = pcall(S.GetAccentColor)
  return ok and r and { r, g, b } or { 0.047, 0.824, 0.616 }
end

-- Colours. These tables are filled from one of the two palettes below (ns.ApplyStyle),
-- so switching style recolours everything on the next draw.
local TITLE_COLOR, TITLE_HOVER_COLOR, LINE_COLOR, DONE_COLOR = {}, {}, {}, {}
local FOCUS_COLOR, DIM_TITLE, DIM_LINE, HEADER_COLOR = {}, {}, {}, {}
local COMBAT_COLOR = { 0.45, 0.85, 1 } -- the quest (and objective) of what you're fighting
-- low-level (grey) quests: the game's own colour for them
local GRAY_TITLE = (QuestDifficultyColors and QuestDifficultyColors.trivial
  and { QuestDifficultyColors.trivial.r, QuestDifficultyColors.trivial.g, QuestDifficultyColors.trivial.b }) or { 0.5, 0.5, 0.5 }
local DONE_TITLE = { 0.3, 1, 0.3 } -- ready to turn in: the same green as its "Ready to turn in" line
local BEST_COLOR = { 0.25, 1, 0.25 } -- cheapest city price (green, like What's Training)

local PALETTES = {
  -- Blizzard's quest tracker
  blizzard = {
    title = { 0.75, 0.61, 0 }, hover = { 1, 0.82, 0 }, line = { 0.8, 0.8, 0.8 }, done = { 0.6, 0.6, 0.6 },
    focus = { 1, 0.9, 0.35 }, dimTitle = { 0.5, 0.45, 0.3 }, dimLine = { 0.5, 0.5, 0.5 }, header = { 1, 0.82, 0 },
  },
  -- FlareUI's quest tracker (Modules/ObjectiveTracker.lua): Blizzard gold titles, blue focus,
  -- bronze headings, light-grey objectives, untracked text at 55% brightness
  flare = {
    title = { 1, 0.82, 0 }, hover = { 1, 0.92, 0.55 }, line = { 0.85, 0.85, 0.85 }, done = { 0.55, 0.55, 0.55 },
    focus = { 0.40, 0.80, 1 }, dimTitle = { 0.55, 0.45, 0 }, dimLine = { 0.47, 0.47, 0.47 }, header = { 0.80, 0.60, 0.34 },
  },
}
local FLARE_BRONZE   = { 0.65, 0.49, 0.27 }  -- FlareUI's frame-border bronze (#A67D45)
local FLARE_BOX      = { 0.50, 0.38, 0.21 }  -- FlareUI's darker bronze (buttons, scroll thumb)
local FLARE_DIVIDER  = "Interface\\Common\\UI-TooltipDivider-Transparent"
local DIALOG_BG      = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
-- the plain style's border: the game's own tooltip border, so the tracker looks native
local BLIZZ_EDGE     = "Interface\\Tooltips\\UI-Tooltip-Border"
local BLIZZ_BG       = "Interface\\Tooltips\\UI-Tooltip-Background"
ns.BLIZZ_EDGE, ns.BLIZZ_BG = BLIZZ_EDGE, BLIZZ_BG
ns.BLIZZ_BORDER_COLOR = { 0.86, 0.66, 0.36 } -- bronze, like the default frames' borders (the artwork is light grey, so tinted a bit brighter)

local function Fill(dst, src) dst[1], dst[2], dst[3] = src[1], src[2], src[3] end
do -- start on the Blizzard palette until settings are loaded
  local p = PALETTES.blizzard
  Fill(TITLE_COLOR, p.title); Fill(TITLE_HOVER_COLOR, p.hover); Fill(LINE_COLOR, p.line); Fill(DONE_COLOR, p.done)
  Fill(FOCUS_COLOR, p.focus); Fill(DIM_TITLE, p.dimTitle); Fill(DIM_LINE, p.dimLine); Fill(HEADER_COLOR, p.header)
end

-- FlareUI's own border texture, read from the installed FlareUI (nil if it isn't loaded).
function ns.FlareBorder()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FlareUI"))
    or (IsAddOnLoaded and IsAddOnLoaded("FlareUI"))
  if not loaded then return nil end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local path = LSM and LSM:Fetch("border", "FlareUI Frames", true)
  return path or "Interface/AddOns/FlareUI/Media/Borders/FlareUI-Frames.tga"
end

function ns.UsingFlare() return ns.FlareBorder() ~= nil and not ns.UsingEUI() end

local frame = CreateFrame("Frame", "XPPlannerFrame", UIParent)
ns.TrackerFrame = frame
frame:SetSize(WIDTH, 30)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:SetFrameLevel(5) -- leaves room for the border frame to sit underneath the text
-- Don't let the game remember this frame's position itself: it would restore it after a reload
-- with its own (centre-based) anchor and override our top-left anchor.
if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
ns.Frame = frame

-- Backdrop: a soft dark panel behind the list so text stays readable.
-- Drawn from a small soft-edged texture (media/SoftBackdrop.tga) cut into nine pieces:
-- rounded, feathered corners, fading edges and a solid middle, so it fades naturally
-- into the world instead of ending in a hard box edge.
local TEX = "Interface\\AddOns\\" .. ns.name .. "\\media\\SoftBackdrop"
local FEATHER = 22                   -- px of soft fade around the edges
-- Solid area around the list. Left/top are wider so the section-header art
-- (which reaches 15px left and 4px up past the list) sits fully on the backdrop.
local PAD_LEFT, PAD_RIGHT, PAD_TOP, PAD_BOTTOM = 18, 6, 7, 4
local MID = { 31.5 / 64, 32.5 / 64 } -- the texture's solid centre column/row
local pieces = {}

local function Piece(l, r, t, b)
  local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  tex:SetTexture(TEX)
  tex:SetTexCoord(l, r, t, b)
  pieces[#pieces + 1] = tex
  return tex
end

-- inner area = the list plus a little padding; everything else hangs off it
local inner = CreateFrame("Frame", nil, frame)
inner:SetPoint("TOPLEFT", -PAD_LEFT, PAD_TOP)
inner:SetPoint("BOTTOMRIGHT", PAD_RIGHT, -PAD_BOTTOM)

local tl = Piece(0, 0.5, 0, 0.5);         tl:SetSize(FEATHER, FEATHER); tl:SetPoint("BOTTOMRIGHT", inner, "TOPLEFT")
local tr = Piece(0.5, 1, 0, 0.5);         tr:SetSize(FEATHER, FEATHER); tr:SetPoint("BOTTOMLEFT", inner, "TOPRIGHT")
local bl = Piece(0, 0.5, 0.5, 1);         bl:SetSize(FEATHER, FEATHER); bl:SetPoint("TOPRIGHT", inner, "BOTTOMLEFT")
local br = Piece(0.5, 1, 0.5, 1);         br:SetSize(FEATHER, FEATHER); br:SetPoint("TOPLEFT", inner, "BOTTOMRIGHT")
local top = Piece(MID[1], MID[2], 0, 0.5);    top:SetPoint("BOTTOMLEFT", inner, "TOPLEFT");    top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
local bottom = Piece(MID[1], MID[2], 0.5, 1); bottom:SetPoint("TOPLEFT", inner, "BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
local left = Piece(0, 0.5, MID[1], MID[2]);   left:SetPoint("TOPRIGHT", inner, "TOPLEFT");     left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
local right = Piece(0.5, 1, MID[1], MID[2]);  right:SetPoint("TOPLEFT", inner, "TOPRIGHT");    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
local center = Piece(MID[1], MID[2], MID[1], MID[2]); center:SetAllPoints(inner)

-- Bordered style: a thin brown border around the whole list (FlareUI-style), with the
-- dark background filling it right up to the border, so nothing bleeds past the edge.
local boxed = CreateFrame("Frame", nil, frame, "BackdropTemplate")
ns.TrackerBox = boxed -- the session bar hangs under it
boxed:SetFrameLevel(frame:GetFrameLevel() - 1)
boxed:SetPoint("TOPLEFT", inner, "TOPLEFT", -1, 1)
boxed:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 1, -1)
boxed:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
})

local function ApplyStyle()
  local p = ns.UsingFlare() and PALETTES.flare or PALETTES.blizzard
  local S = ns.UsingEUI()
  if S then -- EllesmereUI: white titles, its accent for headings, focus and hover
    local acc = EUIAccent(S)
    p = { title = { 0.95, 0.95, 0.95 }, hover = acc, line = { 0.80, 0.80, 0.80 }, done = { 0.55, 0.55, 0.55 },
      focus = acc, dimTitle = { 0.6, 0.6, 0.6 }, dimLine = { 0.5, 0.5, 0.5 }, header = acc }
  end
  -- fonts: EllesmereUI's in its style (at the tracker's sizes), else the tracker's own
  local ok, path, flag = false
  if S then ok, path, flag = pcall(S.GetFont) end
  local hb, tb, lb = Bases()
  for _, pair in ipairs({ { HEADER_FONT, hb }, { TITLE_FONT, tb }, { LINE_FONT, lb } }) do
    if ok and type(path) == "string" then
      local _, size = pair[2]:GetFont()
      pair[1]:SetFont(path, size or 12, flag or "")
    else
      pair[1]:CopyFontObject(pair[2])
    end
  end
  Fill(TITLE_COLOR, p.title); Fill(TITLE_HOVER_COLOR, p.hover); Fill(LINE_COLOR, p.line); Fill(DONE_COLOR, p.done)
  Fill(FOCUS_COLOR, p.focus); Fill(DIM_TITLE, p.dimTitle); Fill(DIM_LINE, p.dimLine); Fill(HEADER_COLOR, p.header)
end

function ns.ApplyBackdrop()
  ApplyStyle()
  local a = ns.db.bgAlpha or 0
  local border = ns.db.showBorder
  local S = ns.UsingEUI()
  if S then
    -- EllesmereUI: its flat panel colour, a thin grey border
    for _, t in ipairs(pieces) do t:Hide() end
    boxed:ClearAllPoints()
    boxed:SetPoint("TOPLEFT", inner, "TOPLEFT", -1, 1)
    boxed:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 1, -1)
    boxed:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    local okP, r, g, b = pcall(S.GetPanelColor)
    if not (okP and r) then r, g, b = 0.07, 0.07, 0.08 end
    boxed:SetBackdropColor(r, g, b, a)
    boxed:SetBackdropBorderColor(0.28, 0.28, 0.28, border and 1 or 0)
    boxed:Show()
    return
  end
  if ns.UsingFlare() then
    -- FlareUI's window: dark dialog background, FlareUI Frames border tinted bronze (16 px edge, 3 px inset)
    for _, t in ipairs(pieces) do t:Hide() end
    local edge = ns.FlareBorder()
    boxed:ClearAllPoints()
    boxed:SetPoint("TOPLEFT", inner, "TOPLEFT", -3, 3)
    boxed:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 3, -3)
    boxed:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = edge, tile = false, tileSize = 0, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    boxed:SetBackdropColor(1, 1, 1, a)
    boxed:SetBackdropBorderColor(FLARE_BRONZE[1], FLARE_BRONZE[2], FLARE_BRONZE[3], 1)
    boxed:Show()
    return
  end
  boxed:ClearAllPoints()
  boxed:SetPoint("TOPLEFT", inner, "TOPLEFT", -3, 3)
  boxed:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 3, -3)
  boxed:SetBackdrop({ bgFile = BLIZZ_BG, edgeFile = BLIZZ_EDGE, tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  -- soft fade only when there's no border
  for _, t in ipairs(pieces) do
    t:SetVertexColor(0, 0, 0, a)
    t:SetShown(a > 0 and not border)
  end
  boxed:SetShown(border)
  if border then
    boxed:SetBackdropColor(0, 0, 0, a)
    local c = ns.BLIZZ_BORDER_COLOR
    boxed:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  end
end

-- The tracker's look, for the settings windows: same palette, fonts and border.
function ns.Theme()
  ApplyStyle()
  local flare = ns.UsingFlare()
  local S = ns.UsingEUI()
  local accent = flare and FLARE_BRONZE or (ns.db.borderColor or { 0.40, 0.33, 0.22 })
  local th = {
    flare = flare, header = HEADER_COLOR, title = TITLE_COLOR, hover = TITLE_HOVER_COLOR,
    line = LINE_COLOR, dim = DIM_LINE, focus = FOCUS_COLOR, accent = accent,
    box = flare and FLARE_BOX or accent, divider = FLARE_DIVIDER,
    headerFont = HEADER_FONT, titleFont = TITLE_FONT, lineFont = LINE_FONT,
  }
  if S then -- EllesmereUI: flat dark controls, thin grey borders, its accent for what's selected
    th.eui = true; th.accent = EUIAccent(S); th.box = { 0.16, 0.16, 0.16 }; th.edge = { 0.28, 0.28, 0.28 }
    th.mark = th.accent; th.title = { 1, 1, 1 }; th.header = { 1, 1, 1 }
  end
  th.edge = th.edge or th.accent
  th.mark = th.mark or th.title
  return th
end

-- A window drawn like the tracker's box: FlareUI's dialog background and bronze border,
-- or the dark panel with the thin brown border.
local shelled = setmetatable({}, { __mode = "k" }) -- windows EllesmereUI has painted
function ns.SkinWindow(f, alpha)
  local th = ns.Theme()
  if th.eui then
    -- EllesmereUI paints the shell itself (once; it keeps it in step with the player's theme)
    if not shelled[f] then
      f:SetBackdrop(nil)
      shelled[f] = pcall(ns.euiSkin.Shell, f)
      if not shelled[f] then f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); f:SetBackdropColor(0.06, 0.06, 0.06, alpha) end
    end
    return
  end
  if th.flare then
    f:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = ns.FlareBorder(), tile = false, tileSize = 0, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(1, 1, 1, alpha)
    f:SetBackdropBorderColor(th.accent[1], th.accent[2], th.accent[3], 1)
  else
    f:SetBackdrop({ bgFile = BLIZZ_BG, edgeFile = BLIZZ_EDGE, tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0.03, 0.03, 0.03, alpha)
    local c = ns.BLIZZ_BORDER_COLOR
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  end
end

---------------------------------------------------------------------------
-- Scrolling viewport: the list never grows past the max height; extra content scrolls.
-- The viewport reaches a little left/up past the list so the header art isn't clipped.
---------------------------------------------------------------------------
local VIEW_L, VIEW_T = 16, 6
local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", -VIEW_L, VIEW_T)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(WIDTH + VIEW_L, 1)
scroll:SetScrollChild(content)

-- thin scroll indicator on the right edge (only when there's more to see)
local track = frame:CreateTexture(nil, "ARTWORK")
track:SetTexture("Interface\\Buttons\\WHITE8X8")
track:SetWidth(1)
track:Hide()
local thumb = frame:CreateTexture(nil, "OVERLAY")
thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
thumb:Hide()

local maxScroll = 0
local function UpdateThumb()
  if maxScroll <= 0 then thumb:Hide(); track:Hide(); return end
  local viewH = frame:GetHeight()
  if ns.UsingFlare() then
    -- FlareUI's scroll bar: a faint bronze track and a 3 px bronze thumb
    thumb:SetVertexColor(FLARE_BOX[1], FLARE_BOX[2], FLARE_BOX[3], 1); thumb:SetWidth(3)
    track:SetVertexColor(FLARE_BOX[1], FLARE_BOX[2], FLARE_BOX[3], 0.25)
    track:ClearAllPoints(); track:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 0); track:SetHeight(viewH)
    track:Show()
  else
    thumb:SetVertexColor(0.55, 0.45, 0.3, 0.8); thumb:SetWidth(2)
    track:Hide()
  end
  local h = math.max(12, viewH * viewH / (viewH + maxScroll))
  thumb:SetHeight(h)
  thumb:ClearAllPoints()
  thumb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, -(scroll:GetVerticalScroll() / maxScroll) * (viewH - h))
  thumb:Show()
end

local function ScrollTo(v)
  scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, v)))
  UpdateThumb()
end
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
  ScrollTo(self:GetVerticalScroll() - delta * 40)
  if ns.QuestItems and ns.lastItems then ns.QuestItems.Update(ns.lastItems) end -- (the buttons follow their rows)
end)

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
local headers, titles, lines = {}, {}, {}
ns._headers = headers -- (for checks)
local used = { h = 0, t = 0, l = 0 }

local function GetHeader()
  used.h = used.h + 1
  local h = headers[used.h]
  if not h then
    h = CreateFrame("Button", nil, content)
    h:SetSize(WIDTH, 25)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetPoint("TOPLEFT", -15, 4); h.bg:SetPoint("BOTTOMRIGHT", 0, -4)
    -- Use the tracker's header art if the client has it; otherwise a soft gradient bar.
    local hasArt = false
    for _, atlas in ipairs({ "UI-QuestTracker-Primary-Objective-Header", "Objective-Header" }) do
      if pcall(h.bg.SetAtlas, h.bg, atlas, false) and h.bg:GetAtlas() then hasArt = true; break end
    end
    if not hasArt then
      h.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      h.bg:SetGradient("HORIZONTAL", CreateColor(0.2, 0.15, 0, 0.8), CreateColor(0.2, 0.15, 0, 0))
      h.bg:ClearAllPoints(); h.bg:SetPoint("TOPLEFT", -4, 2); h.bg:SetPoint("BOTTOMRIGHT", 0, -2)
    end
    h.text = h:CreateFontString(nil, "OVERLAY")
    h.text:SetFontObject(HEADER_FONT)
    h.text:SetPoint("LEFT", 4, 0)
    h.text:SetTextColor(1, 0.82, 0)
    h.toggle = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.toggle:SetPoint("RIGHT", -4, 0)
    -- "Zone" / "All": the section's current-zone filter, one click away
    h.zone = CreateFrame("Button", nil, h, "BackdropTemplate")
    h.zone:SetSize(34, 14); h.zone:SetPoint("RIGHT", h.toggle, "LEFT", -8, 0)
    h.zone:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    h.zone.text = h.zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.zone.text:SetPoint("CENTER", 0, 0)
    h.zone:SetScript("OnClick", function(self)
      ns.db[self.key] = not ns.db[self.key]
      if ns.RefreshOptions then ns.RefreshOptions() end
      ns.Refresh()
      if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    h.zone:SetScript("OnEnter", function(self)
      self.hover = true; self.Paint()
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      local what = self.key == "dungeonZoneOnly" and "dungeons" or "quests"
      GameTooltip:SetText(ns.db[self.key] and ("Showing " .. what .. " in your zone") or ("Showing " .. what .. " in all zones"), 1, 1, 1)
      GameTooltip:AddLine(ns.db[self.key] and "Click to show all zones." or "Click to show only your current zone.", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    h.zone:SetScript("OnLeave", function(self) self.hover = false; self.Paint(); GameTooltip:Hide() end)
    h.zone.Paint = function()
      local z = h.zone
      local on = z.key and ns.db[z.key]
      local accent = ns.UsingFlare() and FLARE_BRONZE or (ns.db.borderColor or { 0.4, 0.33, 0.22 })
      local box = ns.UsingFlare() and FLARE_BOX or accent
      z.text:SetText(on and "Zone" or "All")
      z:SetBackdropColor(box[1], box[2], box[3], on and (z.hover and 0.75 or 0.55) or (z.hover and 0.35 or 0.15))
      z:SetBackdropBorderColor(accent[1], accent[2], accent[3], z.hover and 1 or 0.7)
      if on then z.text:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
      else z.text:SetTextColor(LINE_COLOR[1], LINE_COLOR[2], LINE_COLOR[3]) end
    end
    -- the clean look (default): one bronze line under the heading, fading out to the right
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 2, 0); h.line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
    if h.line.SetGradient and CreateColor then
      h.line:SetGradient("HORIZONTAL", CreateColor(0.86, 0.66, 0.36, 0.9), CreateColor(0.86, 0.66, 0.36, 0))
    else
      h.line:SetVertexColor(0.86, 0.66, 0.36, 0.6)
    end
    -- ...the game's own round +/- for collapsing (lit while the heading is hovered)
    h.plus = h:CreateTexture(nil, "OVERLAY")
    h.plus:SetSize(14, 14); h.plus:SetPoint("RIGHT", -2, 0)
    h.plusHi = h:CreateTexture(nil, "HIGHLIGHT")
    h.plusHi:SetAllPoints(h.plus); h.plusHi:SetBlendMode("ADD")
    -- ...and the game's standard red button for Zone / All, so it reads as a button
    h.zoneBtn = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    h.zoneBtn:SetSize(42, 18); h.zoneBtn:SetPoint("RIGHT", h.plus, "LEFT", -6, 0)
    if h.zoneBtn.SetNormalFontObject then
      h.zoneBtn:SetNormalFontObject("GameFontNormalSmall"); h.zoneBtn:SetHighlightFontObject("GameFontHighlightSmall")
    end
    for _, s in ipairs({ "OnClick", "OnEnter", "OnLeave" }) do h.zoneBtn:SetScript(s, h.zone:GetScript(s)) end
    h.zoneBtn.Paint = function()
      local z = h.zoneBtn
      z:SetText((z.key and ns.db[z.key]) and "Zone" or "All")
    end
    -- FlareUI style: a divider line under the heading instead of Blizzard's header art
    h.divider = h:CreateTexture(nil, "ARTWORK")
    h.divider:SetTexture(FLARE_DIVIDER)
    h.divider:SetHeight(8)
    h.divider:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, -4)
    h.divider:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, -4)
    h:SetScript("OnEnter", function(self)
      if ns.UsingFlare() then self.toggle:SetTextColor(FLARE_BRONZE[1], FLARE_BRONZE[2], FLARE_BRONZE[3]) end
    end)
    h:SetScript("OnLeave", function(self)
      if ns.UsingFlare() then self.toggle:SetTextColor(FLARE_BOX[1], FLARE_BOX[2], FLARE_BOX[3]) end
    end)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function()
      if ns.db.locked then return end -- locked: no accidental moves
      frame:StartMoving()
    end)
    h:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      ns.LockTopLeft()
      ns.Refresh() -- the quest item buttons follow (they're placed by screen position)
    end)
    headers[used.h] = h
  end
  local flare = ns.UsingFlare()
  local clean = not flare and not ns.db.classicHeaders
  h.clean = clean
  h.bg:SetShown(not flare and not clean)
  h.divider:SetShown(flare)
  h.line:SetShown(clean)
  h.plus:SetShown(clean); h.plusHi:SetShown(clean)
  h.toggle:SetShown(not clean)
  h.text:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
  if flare then h.toggle:SetTextColor(FLARE_BOX[1], FLARE_BOX[2], FLARE_BOX[3])
  else h.toggle:SetTextColor(1, 0.82, 0) end
  h:Show()
  return h
end

local function GetTitle()
  used.t = used.t + 1
  local b = titles[used.t]
  if not b then
    b = CreateFrame("Button", nil, content)
    b:SetSize(WIDTH - 10, 16)
    -- right end: a dimmed tag (Quests Nearby's distance), the name shortened to make room
    b.dist = b:CreateFontString(nil, "OVERLAY")
    b.dist:SetFontObject(LINE_FONT)
    b.dist:SetPoint("RIGHT", -2, 0); b.dist:SetJustifyH("RIGHT")
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFontObject(TITLE_FONT)
    b.text:SetPoint("LEFT"); b.text:SetPoint("RIGHT", b.dist, "LEFT", -6, 0)
    b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(false)
    b:SetScript("OnEnter", function(self)
      self.text:SetTextColor(unpack(TITLE_HOVER_COLOR))
      if self.spellID and GameTooltip then -- spell tooltip, like What's Training
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function(self)
      self.text:SetTextColor(unpack(self.baseColor))
      if self.spellID and GameTooltip then GameTooltip:Hide() end
    end)
    titles[used.t] = b
  end
  b.baseColor = TITLE_COLOR
  b.spellID = nil
  b.dist:SetText("")
  b.dist:SetFontObject(LINE_FONT); b.dist:SetTextColor(unpack(DIM_LINE))
  b.text:SetTextColor(unpack(TITLE_COLOR))
  b:Show()
  return b
end

local lineGlow = {} -- line -> its flash glow (see Soft animations)
local function GetLine()
  used.l = used.l + 1
  local l = lines[used.l]
  if not l then
    l = content:CreateFontString(nil, "OVERLAY")
    l:SetFontObject(LINE_FONT)
    l:SetJustifyH("LEFT")
    lines[used.l] = l
  end
  l:SetWidth(WIDTH - 20) -- (every time: a quest line can be narrower, see AddEntry)
  if lineGlow[l] then lineGlow[l]:Hide() end
  l:Show()
  return l
end

-- Focus mark: a gold bar down the left of the focused quest, with a soft gold glow behind it
-- (light blue for the quest of what you're fighting, in combat).
local marks, usedMarks = {}, 0
local function GetMark(color)
  usedMarks = usedMarks + 1
  local m = marks[usedMarks]
  if not m then
    m = {}
    m.bg = content:CreateTexture(nil, "BACKGROUND", nil, 1)
    m.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    m.bg:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, 0.18), CreateColor(1, 0.82, 0, 0))
    m.bar = content:CreateTexture(nil, "ARTWORK")
    m.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    m.bar:SetVertexColor(1, 0.82, 0, 0.9)
    m.bar:SetWidth(2)
    marks[usedMarks] = m
  end
  local c = color or FOCUS_COLOR
  m.bar:SetVertexColor(c[1], c[2], c[3], 0.9)
  m.bg:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.2), CreateColor(c[1], c[2], c[3], 0))
  m.bg:SetAlpha(1); m.bar:SetAlpha(1); m.bar:SetWidth(2); m.bg:SetBlendMode("BLEND")
  m.bg:Show(); m.bar:Show()
  return m
end

---------------------------------------------------------------------------
-- Distance to a quest giver, in yards (the game's distance unit)
---------------------------------------------------------------------------
-- yards from you to a location (Locations.lua), or nil
local Yards = ns.Locations.Yards
local function YardsText(yd)
  if not yd then return nil end
  if yd >= 1000 then return format("%.1fk yd", yd / 1000) end
  return format("%d yd", math.floor(yd / 5 + 0.5) * 5) -- to the nearest 5 yards
end

-- lines showing a distance: refreshed every second while shown, without rebuilding the list
local distLines = {}
local function DistText(d) local t = YardsText(Yards(d.loc)); return d.base .. (t and (" - " .. t) or "") end
local function PaintDist(d)
  if d.tag then d.line:SetText(YardsText(Yards(d.loc)) or "")
  else d.line:SetText("- " .. DistText(d)) end
end
C_Timer.NewTicker(1, function()
  for _, d in ipairs(distLines) do
    if d.line:IsShown() then PaintDist(d) end
  end
end)

local function ResetPools()
  wipe(distLines)
  for _, m in ipairs(marks) do m.bg:Hide(); m.bar:Hide() end
  usedMarks = 0
  for _, h in ipairs(headers) do h:Hide() end
  for _, t in ipairs(titles) do t:Hide() end
  for _, l in ipairs(lines) do l:Hide() end
  used.h, used.t, used.l = 0, 0, 0
end

---------------------------------------------------------------------------
-- Click actions
---------------------------------------------------------------------------
local function OpenQuest(questID)
  if QuestMapFrame_OpenToQuestDetails and pcall(QuestMapFrame_OpenToQuestDetails, questID) then return end
  local idx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
  if idx and ShowQuestLog then pcall(ShowQuestLog); if QuestLog_SetSelection then pcall(QuestLog_SetSelection, idx) end end
end

local function Call(fn, ...) if fn then pcall(fn, ...) end end
local function S(name, fallback) return _G[name] or fallback end -- Blizzard's own (localized) menu text

-- Right-click menu: the same entries, text and actions as Blizzard's quest tracker
-- (QuestObjectiveTrackerMixin:OnBlockHeaderClick). Because this list can also show quests
-- you aren't tracking, "Stop Tracking" becomes "Track Quest" for those.
local function ShowQuestMenu(owner, questID)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    OpenQuest(questID); return
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or "")

    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
      if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
        root:CreateButton(S("SUPER_TRACK_QUEST", "Focus Quest"), function() C_SuperTrack.SetSuperTrackedQuestID(questID) end)
      else
        root:CreateButton(S("STOP_SUPER_TRACK_QUEST", "Stop Focusing"), function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
      end
    end

    if QuestUtil and QuestUtil.OpenQuestDetails then
      local showing = QuestUtil.IsShowingQuestDetails and QuestUtil.IsShowingQuestDetails(questID)
      root:CreateButton(showing and S("OBJECTIVES_HIDE_VIEW_IN_QUESTLOG", "Hide Quest Details")
        or S("OBJECTIVES_VIEW_IN_QUESTLOG", "View in Quest Log"), function() QuestUtil.OpenQuestDetails(questID) end)
    end

    root:CreateButton(S("OBJECTIVES_SHOW_QUEST_MAP", "Open Quest Map"), function() OpenQuest(questID) end)
    -- (with Questie: a waypoint to the nearest place left to do, or the turn-in once it's done)
    if ns.Questie.Available() then
      local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
      root:CreateButton(done and "Waypoint to the turn-in" or "Waypoint to the nearest objective", function() ns.QuestWaypoint(questID) end)
    end

    local watched = C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questID) ~= nil
    if watched then
      if not QuestUtil or not QuestUtil.CanRemoveQuestWatch or QuestUtil.CanRemoveQuestWatch() then
        root:CreateButton(S("OBJECTIVES_STOP_TRACKING", "Stop Tracking"), function() C_QuestLog.RemoveQuestWatch(questID) end)
      end
    elseif C_QuestLog.AddQuestWatch then
      root:CreateButton(S("TRACK_QUEST", "Track Quest"), function() C_QuestLog.AddQuestWatch(questID) end)
    end

    if C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
      root:CreateButton(S("SHARE_QUEST", "Share Quest"), function()
        if QuestUtil and QuestUtil.ShareQuest then QuestUtil.ShareQuest(questID)
        else Call(C_QuestLog.SetSelectedQuest, questID); Call(QuestLogPushQuest) end
      end)
    end

    root:CreateButton(S("ABANDON_QUEST_ABBREV", "Abandon"), function()
      if QuestMapQuestOptions_AbandonQuest then QuestMapQuestOptions_AbandonQuest(questID)
      else
        Call(C_QuestLog.SetSelectedQuest, questID); Call(C_QuestLog.SetAbandonQuest)
        Call(StaticPopup_Show, "ABANDON_QUEST", C_QuestLog.GetTitleForQuestID(questID))
      end
    end)
  end)
end

-- An active quest's places still to visit (1.10.0): its objectives not yet done (by name, against
-- the quest log's finished lines), or its turn-in once it's complete; as locations
function ns.QuestPlaces(questID)
  local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
  local list = ns.Locations.Filter(ns.Questie.QuestLocations(questID), done and { turnin = true } or { objective = true })
  if done then return list, true end
  local finished = {}
  local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
  for _, o in ipairs(type(objs) == "table" and objs or {}) do
    if o.finished and type(o.text) == "string" then finished[ns.ObjectiveKey(o.text)] = true end
  end
  local todo = {}
  for _, l in ipairs(list) do if not ns.ObjectiveMatches(l.name, finished) then todo[#todo + 1] = l end end
  return todo, false
end
function ns.QuestWaypoint(questID)
  local list, done = ns.QuestPlaces(questID)
  local loc = ns.Locations.Nearest(list, nil, C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
  if not loc then ns.Print(done and "the turn-in's place isn't known." or "no place known for what's left to do."); return end
  if ns.SetWaypoint(loc, loc.label) then ns.Print(format("waypoint set: %s (%.1f, %.1f)", loc.label, loc.x * 100, loc.y * 100)) end
end

-- Left/right click on an active quest, like Blizzard's tracker:
-- shift-click links it in chat, left-click opens it, right-click shows the menu.
---------------------------------------------------------------------------
-- Quests to Pick Up: right-click menu (Show on Map / Ignore Quest)
---------------------------------------------------------------------------
-- Put a waypoint on the quest giver: the game's own map pin (and TomTom's arrow if installed),
-- then open the world map there.
function ns.SetWaypoint(loc, title)
  if not loc then return false end
  local placed = false
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local can = not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(loc.map)
    if can and pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(loc.map, loc.x, loc.y)) then
      placed = true
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      end
    end
  end
  -- TomTom: one arrow at a time from Hereabouts (1.9.0: the previous one is taken off first; before,
  -- every Show on Map added another)
  if type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function" then
    if ns.tomtomWaypoint and type(TomTom.RemoveWaypoint) == "function" then pcall(TomTom.RemoveWaypoint, TomTom, ns.tomtomWaypoint) end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, loc.map, loc.x, loc.y, { title = title, from = "Hereabouts" })
    if ok then placed = true; ns.tomtomWaypoint = uid end
  end
  if OpenWorldMap then pcall(OpenWorldMap, loc.map)
  elseif WorldMapFrame and WorldMapFrame.SetMapID then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then pcall(ToggleWorldMap) end
    pcall(WorldMapFrame.SetMapID, WorldMapFrame, loc.map)
  end
  return placed
end

-- open the map on a quest giver and put a waypoint there (and TomTom's arrow if installed)
-- low level (grey) for you? the game's own flag for the quest when it has one, else its level rule
local function IsLowLevel(q)
  local id = q.id or q.questID
  if C_QuestLog and C_QuestLog.IsQuestTrivial and id then
    local ok, v = pcall(C_QuestLog.IsQuestTrivial, id)
    if ok and type(v) == "boolean" then return v end
  end
  return ns.IsTrivial(q.level)
end

local function ShowPickupOnMap(q)
  local loc = q.loc or ns.Questie.Location(q.id)
  local who = q.starter or q.name
  if not loc then ns.Print("no location known for " .. (q.name or "this quest") .. ".")
  elseif ns.SetWaypoint(loc, who) then ns.Print(format("waypoint set: %s (%.1f, %.1f)", who, loc.x * 100, loc.y * 100))
  else ns.Print("couldn't place a waypoint on that map.") end
end

local function ShowPickupMenu(owner, q)
  local function showOnMap() ShowPickupOnMap(q) end
  local function ignore()
    ns.IgnoreQuest(q.id, q.name, q.level)
    ns.Print((q.name or "Quest") .. " ignored. Manage ignored quests in /hab.")
  end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then showOnMap(); return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(q.name or "")
    root:CreateButton("Show on Map", showOnMap)
    root:CreateButton("Ignore Quest", ignore)
  end)
end

local function ActiveQuestClick(self, button, questID)
  if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID
    and ChatFrameUtil.TryInsertQuestLinkForQuestID(questID) then return end
  if button == "RightButton" then ShowQuestMenu(self, questID) else OpenQuest(questID) end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local y
local function Place(region, x, gap)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", content, "TOPLEFT", x + VIEW_L, -(y + VIEW_T))
  y = y + region:GetHeight() + (gap or 0)
end


-- style: nil, or { focused = true } / { dim = true }
---------------------------------------------------------------------------
-- Soft animations: an objective that progressed flashes (its count lights up, a soft gold glow behind
-- it), and a quest that becomes your combat quest fades its light blue mark in (and out after).
-- Keyed by quest, not by line: lines are pooled and re-dealt on every render, so each render tells
-- the running animations which line or mark is theirs now.
---------------------------------------------------------------------------
local FLASH_TIME, FADE_TIME, ALERT_TIME = 0.9, 0.35, 1.4 -- (alert: the combat mark arriving, made to be noticed)
local ALERT_COLOR = { 0.8, 0.97, 1 }
local FLASH_COLOR = { 1, 0.95, 0.55 }
local anims = {}      -- key -> start time (flash: "f:quest:objective", fade in: "c:quest", fade out: "u:quest")
local targets = {}    -- key -> what this render drew for it
local prevObj, prevCombat = {}, {}
local animDriver = CreateFrame("Frame")
animDriver:Hide()

local function Mix(a, b, t) return a + (b - a) * t end
local function Hex(c) return format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

-- the soft glow behind a line (gold for progress, light blue for combat)
local function Glow(l, r, g, b)
  local t = lineGlow[l]
  if not t then
    t = content:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineGlow[l] = t
  end
  t:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", l, "TOPLEFT", -6, 1)
  t:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, -1)
  return t
end

local function Paint(key, p)
  local tg = targets[key]
  if not tg then return end
  if tg.line then -- objective flash: up quickly, then eases back
    local k = p < 0.15 and p / 0.15 or (1 - (p - 0.15) / 0.85) ^ 2
    if p >= 1 then k = 0 end
    local b, c = tg.base, {}
    for i = 1, 3 do c[i] = Mix(b[i], FLASH_COLOR[i], k) end
    if tg.num then -- just the count lights up
      tg.line:SetText(k > 0 and ("- " .. tg.pre .. "|cff" .. Hex(c) .. tg.num .. "|r" .. tg.post) or ("- " .. tg.text))
    else
      tg.line:SetTextColor(c[1], c[2], c[3])
    end
    local g = Glow(tg.line, 1, 0.85, 0.3)
    g:SetBlendMode("BLEND")
    if k > 0 then g:SetAlpha(0.35 * k); g:Show() else g:Hide() end
  elseif tg.mark then -- combat mark: arrives with a bright pulse (twice, settling), fades out after
    p = math.min(p, 1)
    local m, k = tg.mark, 0
    local e
    if tg.out then
      e = (1 - p) ^ 2
    else
      e = 1 - (1 - math.min(p / 0.15, 1)) ^ 2 -- (in quickly)
      local q
      -- (flare, held a moment at full, then a second pulse and settle)
      if p < 0.06 then k = p / 0.06
      elseif p < 0.2 then k = 1
      else q = (p - 0.2) / 0.8; k = (1 - q) ^ 1.5 * (0.55 + 0.45 * math.cos(q * 4 * math.pi)) end
      if p >= 1 then k = 0 end
    end
    local c = {}
    for i = 1, 3 do c[i] = Mix(tg.from and tg.from[i] or COMBAT_COLOR[i], COMBAT_COLOR[i], tg.from and e or 1) end
    m.bar:SetVertexColor(Mix(c[1], 1, k), Mix(c[2], 1, k), Mix(c[3], 1, k), Mix(0.9, 1, k)) -- (white at the peak)
    m.bar:SetWidth(2 + 4 * k)
    m.bg:SetBlendMode(k > 0 and "ADD" or "BLEND") -- (added light: it glows, rather than tints)
    m.bg:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.2 + 0.8 * k), CreateColor(c[1], c[2], c[3], 0.35 * k))
    if not tg.from then -- (the focused quest: gold to light blue and back, rather than a fade)
      m.bar:SetAlpha(e); m.bg:SetAlpha(e)
      if tg.out and p >= 1 then m.bar:Hide(); m.bg:Hide() end
    end
    for _, l in ipairs(tg.lines or {}) do -- the lit objective lights up bright, then settles to its light blue
      local lc = {}
      for i = 1, 3 do lc[i] = Mix(Mix(LINE_COLOR[i], COMBAT_COLOR[i], e), ALERT_COLOR[i], k * 0.6) end -- (softer than the mark)
      l:SetTextColor(lc[1], lc[2], lc[3])
      local g = Glow(l, COMBAT_COLOR[1], COMBAT_COLOR[2], COMBAT_COLOR[3])
      g:SetBlendMode(k > 0 and "ADD" or "BLEND")
      if k > 0 then g:SetAlpha(0.5 * k); g:Show() else g:Hide() end
    end
    if tg.title then -- the quest's name flashes too
      local b = tg.title.baseColor
      tg.title.text:SetTextColor(Mix(b[1], ALERT_COLOR[1], k), Mix(b[2], ALERT_COLOR[2], k), Mix(b[3], ALERT_COLOR[3], k))
    end
  end
end

animDriver:SetScript("OnUpdate", function(self)
  local now, any = GetTime(), false
  for key, start in pairs(anims) do
    local kind = key:sub(1, 1)
    local p = (now - start) / (kind == "f" and FLASH_TIME or kind == "c" and ALERT_TIME or FADE_TIME)
    Paint(key, math.min(p, 1))
    if p >= 1 then anims[key] = nil; targets[key] = nil else any = true end
  end
  if not any then self:Hide() end
end)

local function Animate(key)
  if not ns.db.animations then return end
  anims[key] = GetTime()
  animDriver:Show()
end

-- Before a render: what changed since the last one starts its animation.
local function DiffQuests(quests)
  wipe(targets)
  local combat = {}
  for _, q in ipairs(quests or {}) do
    local id = q.questID
    for i, o in ipairs(q.objectives or {}) do
      local k = id .. ":" .. i
      if prevObj[k] and o.text and prevObj[k] ~= o.text then Animate("f:" .. k) end
      prevObj[k] = o.text
    end
    local done = q.complete and true or false
    if prevObj[id .. ":c"] == false and done then Animate("f:" .. id .. ":c") end
    prevObj[id .. ":c"] = done
    if q.combat then
      combat[id] = true
      if not prevCombat[id] then anims["u:" .. id] = nil; Animate("c:" .. id) end
    end
  end
  for id in pairs(prevCombat) do
    if not combat[id] then anims["c:" .. id] = nil; Animate("u:" .. id) end
  end
  prevCombat = combat
end

-- During a render: this line is the objective `key`; if it's flashing, take the line over.
local function FlashLine(key, l, text, base)
  if not anims[key] then return end
  local pre, num, post = text:match("^(.-)(%d+%s*/%s*%d+)(.*)$")
  if not num then pre, num, post = text:match("^(.-)(%d+%%)(.*)$") end
  targets[key] = { line = l, text = text, base = base, pre = pre, num = num, post = post }
  Paint(key, (GetTime() - anims[key]) / FLASH_TIME)
end

local function AddEntry(title, level, sub, onClick, style)
  local startY = y
  local lit -- (objectives lit for combat: they ease in with the mark)
  local t = GetTitle()
  local indent = style and style.indent or 0 -- (room for a quest item button, see QuestItems.lua)
  t:SetWidth(WIDTH - 10 - indent) -- (as wide as before less the room, so long titles still end at the edge)
  local lvl = level and format("[%d] ", level) or ""
  t.text:SetText(lvl .. (title or "?"))
  t.spellID = style and style.spellID or nil
  if style and style.loc then -- distance to the quest giver, at the right end of the name row
    local d = { line = t.dist, loc = style.loc, tag = true }
    distLines[#distLines + 1] = d
    PaintDist(d)
  end
  if style and style.focused then t.baseColor = FOCUS_COLOR
  elseif style and style.dim then t.baseColor = DIM_TITLE
  elseif style and style.done then t.baseColor = DONE_TITLE
  elseif style and style.gray then t.baseColor = GRAY_TITLE end
  t.text:SetTextColor(unpack(t.baseColor))
  t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  t:SetScript("OnClick", onClick)
  Place(t, 10 + indent, 0)
  for _, s in ipairs(sub) do
    local l = GetLine()
    l:SetWidth(WIDTH - 20 - indent)
    if s.loc then -- this line also shows how far away the quest giver is
      local d = { line = l, base = s.text, loc = s.loc }
      distLines[#distLines + 1] = d
      l:SetText("- " .. DistText(d))
    else
      l:SetText("- " .. s.text)
    end
    local c = s.done and DONE_COLOR or (s.color or LINE_COLOR)
    if style and style.dim and not s.color then c = DIM_LINE end
    l:SetTextColor(unpack(c))
    l:SetHeight(l:GetStringHeight())
    Place(l, 20 + indent + (s.indent or 0) * 10, 1)
    if s.flashKey and not s.loc then FlashLine(s.flashKey, l, s.text, c) end
    if s.lit then lit = lit or {}; lit[#lit + 1] = l end
  end
  local fadeKey = style and style.fadeKey
  local out = fadeKey and fadeKey:sub(1, 1) == "u"
  if style and (style.focused or style.combat or out) then
    local m = GetMark((style.combat or out) and COMBAT_COLOR or nil) -- (what you're fighting: light blue, over the focus gold)
    local top, h = startY + VIEW_T - 2, (y - startY) + 4
    m.bar:ClearAllPoints(); m.bar:SetPoint("TOPLEFT", content, "TOPLEFT", VIEW_L + 4, -top); m.bar:SetHeight(h)
    m.bg:ClearAllPoints(); m.bg:SetPoint("TOPLEFT", content, "TOPLEFT", VIEW_L + 4, -top)
    m.bg:SetSize(WIDTH - 8, h)
    if fadeKey then
      targets[fadeKey] = { mark = m, out = out, from = style.focused and FOCUS_COLOR or nil, lines = not out and lit or nil,
        title = not out and t or nil }
      Paint(fadeKey, (GetTime() - anims[fadeKey]) / (out and FADE_TIME or ALERT_TIME))
    end
  end
  y = y + 6
  return t
end

local function AddNote(text)
  local l = GetLine()
  l:SetText(text); l:SetTextColor(unpack(DIM_LINE))
  l:SetHeight(l:GetStringHeight())
  Place(l, 10, 6)
end

local shownSomething = false
-- zoneKey: the setting for this section's current-zone filter (adds the Zone / All switch)
-- a section the settings hide right now (in a dungeon / in combat)
local function SectionHidden(key)
  local db = ns.db
  if db.hideInInstance and db.hideInInstance[key] and IsInInstance and IsInInstance() then return true end
  if db.hideInCombat and db.hideInCombat[key] and UnitAffectingCombat and UnitAffectingCombat("player") then return true end
  return false
end
ns.SectionHidden = SectionHidden

local function Section(name, count, key, zoneKey)
  local h = GetHeader()
  h.text:SetText(name)
  -- the Zone / All switch: the red button (clean headings) or the small box (classic / FlareUI)
  local z, other = h.zone, h.zoneBtn
  if h.clean then z, other = h.zoneBtn, h.zone end
  other:Hide()
  z.key = zoneKey
  z:SetShown(zoneKey ~= nil)
  if zoneKey then z.Paint() end
  local collapsed = ns.db.collapsedSections and ns.db.collapsedSections[key]
  h.toggle:SetText(collapsed and "+" or "-")
  local sign = collapsed and "Plus" or "Minus"
  h.plus:SetTexture("Interface\\Buttons\\UI-" .. sign .. "Button-Up")
  h.plusHi:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
  h:SetScript("OnClick", function()
    ns.db.collapsedSections = ns.db.collapsedSections or {}
    ns.db.collapsedSections[key] = not collapsed
    ns.Refresh()
  end)
  Place(h, 0, 4)
  shownSomething = true -- a header alone still counts, so you can always expand it again
  return not collapsed and count > 0
end

function ns.Render(s)
  ResetPools()
  y = 0
  shownSomething = false

  local items = {} -- quests with a usable item: { itemID, icon, title, questID, row } (buttons in the left margin,
  -- beside their titles: the rows themselves never move for them, see QuestItems.lua)
  local qIndent = 0
  if ns.Session then ns.Session.Paint() end

  -- with the zone filter on, the heading stays even when nothing's here, so the switch is reachable
  local qElse = ns.db.activeZoneOnly and (s.questsElsewhere or 0) or 0
  -- in combat with a quest's creature: its quests are marked light blue (and still show when the section
  -- is hidden in combat: then only they do)
  local onlyCombat = s.combatFocus and SectionHidden("quests")
  DiffQuests(s.quests)
  if (s.combatFocus or not SectionHidden("quests")) and (#s.quests > 0 or qElse > 0)
    and Section("Active Quests", #s.quests, "quests", "activeZoneOnly") then
    for _, q in ipairs(s.quests) do
     if q.combat or not onlyCombat then
      local sub = {}
      if q.complete then
        sub[#sub + 1] = { text = "Ready to turn in", color = { 0.3, 1, 0.3 }, flashKey = "f:" .. q.questID .. ":c" }
      else
        if ns.db.showObjectives then
          for i, o in ipairs(q.objectives) do
            if #sub >= 3 then break end
            if not (ns.db.hideDoneObjectives and o.done) then
              local lit = q.combatObjectives and q.combatObjectives[ns.ObjectiveKey(o.text)] and not o.done
              -- (a copy: the objective what you're fighting counts for is lit up, and a progressed one flashes)
              o = { text = o.text, done = o.done, color = lit and COMBAT_COLOR or o.color,
                flashKey = "f:" .. q.questID .. ":" .. i, lit = lit and anims["c:" .. q.questID] and true or nil }
              sub[#sub + 1] = o
            end
          end
        end
      end
      if ns.db.showXP and q.xp > 0 then sub[#sub + 1] = { text = BreakUpLargeNumbers and (BreakUpLargeNumbers(q.xp) .. " XP") or (q.xp .. " XP") } end
      -- gold: worth doing; grey: low level; green: ready to turn in (the focused quest keeps its highlight)
      local row = AddEntry(q.title, q.level, sub, function(self, button) ActiveQuestClick(self, button, q.questID) end,
        { focused = q.focused, done = q.complete, gray = IsLowLevel(q), combat = q.combat, indent = qIndent,
          fadeKey = (anims["c:" .. q.questID] and "c:" .. q.questID) or (anims["u:" .. q.questID] and "u:" .. q.questID) or nil })
      if q.item then items[#items + 1] = { itemID = q.item.itemID, icon = q.item.icon, title = q.title, questID = q.questID, row = row } end
     end
    end
  end

  if not SectionHidden("quests") and #s.quests == 0 and qElse > 0 and not (ns.db.collapsedSections and ns.db.collapsedSections.quests) then
    AddNote(format("None in this zone (%d elsewhere)", qElse))
  end

  local tElse = ns.db.turninZoneOnly and (s.turninElsewhere or 0) or 0
  local turnin = s.turnin or {}
  if not SectionHidden("turnin") and (#turnin > 0 or tElse > 0) and Section("Quests to Turn In", #turnin, "turnin", "turninZoneOnly") then
    for _, q in ipairs(turnin) do
      local sub = {}
      -- with All zones: where to turn it in
      if not ns.db.turninZoneOnly and ns.Questie.TurnInZone then
        local where, here = ns.Questie.TurnInZone(q.questID)
        if where then sub[#sub + 1] = { text = "Turn in: " .. where .. (here and " (here)" or "") } end
      end
      if ns.db.showXP and q.xp > 0 then sub[#sub + 1] = { text = BreakUpLargeNumbers and (BreakUpLargeNumbers(q.xp) .. " XP") or (q.xp .. " XP") } end
      AddEntry(q.title, q.level, sub, function(self, button) ActiveQuestClick(self, button, q.questID) end,
        { focused = q.focused, done = true }) -- green: ready to turn in
    end
  end
  if not SectionHidden("turnin") and #turnin == 0 and tElse > 0 and not (ns.db.collapsedSections and ns.db.collapsedSections.turnin) then
    AddNote(format("None in this zone (%d elsewhere)", tElse))
  end

  local pElse = ns.db.pickupZoneOnly and (s.pickupElsewhere or 0) or 0
  if not SectionHidden("pickup") and (#s.pickup > 0 or pElse > 0) and Section("Quests Nearby", #s.pickup, "pickup", "pickupZoneOnly") then
    for _, q in ipairs(s.pickup) do
      local sub = {}
      if ns.db.showXP then
        local xpText = q.xp > 0 and ((BreakUpLargeNumbers and BreakUpLargeNumbers(q.xp) or q.xp) .. " XP") or "No XP"
        sub[1] = { text = xpText .. (q.repeatable and " - repeatable" or "") }
      elseif q.repeatable then
        sub[1] = { text = "Repeatable" }
      end
      -- distance to the quest giver: shown at the right end of the quest's name row
      local loc = q.loc or (ns.Questie.Location and ns.Questie.Location(q.id))
      if not ns.db.showStarter then
        -- no giver line
      elseif q.starter then
        sub[#sub + 1] = { text = q.starter .. (q.zone and (" - " .. q.zone) or ""),
          color = (not q.here) and DIM_LINE or nil }
      elseif q.zone then
        sub[#sub + 1] = { text = q.zone, color = (not q.here) and DIM_LINE or nil }
      end
      AddEntry(q.name, q.level, sub, function(self, button)
        if button == "RightButton" then ShowPickupMenu(self, q); return end
        -- shift-click: the quest's details in chat; click: map + waypoint on the quest giver
        if IsShiftKeyDown and IsShiftKeyDown() then
          ns.Print(format("[%d] %s - %s XP - %s", q.level or 0, q.name or "?", q.xp,
            (q.starter or "?") .. (q.zone and (", " .. q.zone) or "")))
          return
        end
        ShowPickupOnMap(q)
      end, { gray = IsLowLevel(q), loc = loc }) -- low-level quests in the game's grey
    end
  end

  if not SectionHidden("pickup") and #s.pickup == 0 and pElse > 0 and not (ns.db.collapsedSections and ns.db.collapsedSections.pickup) then
    AddNote(format("None in this zone (%d elsewhere)", pElse))
  end


  if not SectionHidden("training") and s.training and #s.training > 0 and Section("Training", #s.training, "training") then
    local money = function(c)
      return (GetCoinTextureString and GetCoinTextureString(c)) or (GetMoneyString and GetMoneyString(c)) or (c .. "c")
    end
    if (s.trainCount or 0) > 0 then
      local note = GetLine()
      note:SetText(format("%d to train - %s", s.trainCount, money(s.trainCost or 0)))
      note:SetTextColor(unpack(LINE_COLOR))
      note:SetHeight(note:GetStringHeight())
      Place(note, 10, 6)
    end
    for _, sp in ipairs(s.training) do
      local name = (sp.name or "?") .. (sp.rank and sp.rank ~= "" and (" (" .. sp.rank .. ")") or "")
      local sub
      local cities = {}
      if ns.db.showCityPrices then cities = ns.Training.CityPrices(sp) end
      if #cities > 0 then
        -- what each city charges with your reputation (green: the cheapest)
        sub = {}
        for _, c in ipairs(cities) do
          sub[#sub + 1] = { text = money(c.price) .. " in " .. c.name, color = c.best and BEST_COLOR or nil }
        end
      else
        sub = { { text = sp.cost > 0 and money(sp.cost) or "Free" } }
      end
      -- next-level spells: shown dimmed, with their level in the title (no extra line)
      AddEntry(name, sp.level, sub, function()
        -- shift-click links the spell in chat, like everywhere else
        if IsModifiedClick and IsModifiedClick("CHATLINK") and sp.link and ChatEdit_InsertLink then
          ChatEdit_InsertLink(sp.link)
        end
      end, { spellID = type(sp.id) == "number" and sp.id or nil, dim = sp.nextLevel })
    end
  end

  local dElse = ns.db.dungeonZoneOnly and (s.dungeonsElsewhere or 0) or 0
  if not SectionHidden("dungeons") and (#s.dungeons > 0 or dElse > 0) and Section("Dungeons", #s.dungeons, "dungeons", "dungeonZoneOnly") then
    for _, d in ipairs(s.dungeons) do
      AddEntry(d.name, nil, { { text = format("Levels %d-%d", d.min, d.max) }, { text = d.zone } }, function()
        ns.Print(d.name .. ": " .. d.zone .. format(" (levels %d-%d)", d.min, d.max))
      end)
    end
  end
  if not SectionHidden("dungeons") and #s.dungeons == 0 and dElse > 0 and not (ns.db.collapsedSections and ns.db.collapsedSections.dungeons) then
    AddNote(format("None in this zone (%d elsewhere)", dElse))
  end

  -- Size: grow with the content up to the max height, then scroll.
  local viewH = math.min(y, ns.db.maxHeight or 400)
  frame:SetHeight(math.max(viewH, 1))
  content:SetHeight(y + VIEW_T)
  maxScroll = math.max(0, y - viewH)
  ScrollTo(scroll:GetVerticalScroll()) -- keep your place, clamped to the new size
  if ns.db.pos and ns.db.pos[1] ~= "TOPLEFT" then ns.LockTopLeft() end
  frame:SetShown(shownSomething and not ns.db.hidden)
  -- quest item buttons, each left of its quest's [level] (placed now the list is laid out)
  ns.lastItems = items
  if ns.QuestItems then ns.QuestItems.Update(items) end
end

-- where the list's visible area is on screen (for the item buttons: rows scrolled out of view get none)
function ns.TrackerView()
  local top, bottom = scroll:GetTop(), scroll:GetBottom()
  return top, bottom
end

-- Save and anchor by the top-left corner, so the list only ever grows downward.
function ns.LockTopLeft()
  local left, top = frame:GetLeft(), frame:GetTop()
  if not (left and top) then return end
  if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
  -- Saved in screen (UIParent) units so it stays put when the list's scale changes.
  local s = frame:GetScale()
  local x, y = left * s, top * s - UIParent:GetHeight()
  ns.db.pos = { "TOPLEFT", "TOPLEFT", x, y }
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / s, y / s)
end

function ns.PlaceFrame()
  -- clears a position the game may have remembered from older versions (layout cache)
  if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
  frame:SetScale(ns.db.scale or 1)
  ns.ApplyBackdrop()
  frame:ClearAllPoints()
  local p = ns.db.pos
  if p then
    local s = frame:GetScale()
    if p[1] == "TOPLEFT" then frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p[3] / s, p[4] / s)
    else frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
  else
    local tracker = _G.ObjectiveTrackerFrame or _G.QuestWatchFrame or _G.WatchFrame
    if tracker and ns.db.replaceTracker then
      frame:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0) -- take Blizzard's tracker's spot
    elseif tracker then
      frame:SetPoint("TOPLEFT", tracker, "BOTTOMLEFT", 0, -10)
    else
      frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -300)
    end
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Updates are gathered for 0.2 s, then done once, as lightly as they allow:
--   "redraw": only how the list is shown changed (e.g. combat hides sections): draw the last list again
--   "log":    the quest log may have changed: rebuild only if what we show from it really did
--   (none):   anything else: rebuild
local LEVEL = { redraw = 1, log = 2, full = 3 }
local pending, need, lastStamp, lastList = false, 0, nil, nil
local function Run()
  pending = false
  local level = need; need = 0
  if level == LEVEL.redraw and lastList then
    local ok, e = pcall(ns.Render, lastList)
    if not ok then ns.NoteError("drawing the list", e) end
    return
  end
  local ok, stamp, quests = pcall(ns.QuestLogStamp)
  if not ok then ns.NoteError("reading the quest log", stamp); stamp, quests = nil, nil end
  if level == LEVEL.log and stamp and stamp == lastStamp and lastList then return end -- nothing we show changed
  local ok2, s = pcall(ns.BuildSuggestions, quests)
  if not ok2 then ns.NoteError("building the list", s); return end
  lastStamp, lastList = stamp, s
  local ok3, e = pcall(ns.Render, s)
  if not ok3 then ns.NoteError("drawing the list", e) end
end
function ns.Refresh(kind)
  local level = LEVEL[kind or "full"] or LEVEL.full
  if level > need then need = level end
  if pending then return end
  pending = true
  C_Timer.After(0.2, Run)
end

-- Combat focus: what you're fighting changes often (threat events fire a lot), so check at most
-- twice a second, and rebuild the list only when the quests to show change.
local focusKey, focusPending = "", false
function ns.CheckCombatFocus()
  if focusPending then return end
  focusPending = true
  C_Timer.After(0.5, function()
    focusPending = false
    local ok, key = pcall(ns.CombatFocusKey)
    if ok and key ~= focusKey then focusKey = key; ns.Refresh("full") end
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, arg1, ...)
  if event == "ADDON_LOADED" then
    if arg1 ~= ns.name then return end
    ns.LoadDB(); ns.PlaceFrame(); ns.CreateOptions()
    ns.Questie.onUpdate = ns.Refresh
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
      "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "QUESTLINE_UPDATE", "PLAYER_LOGIN",
      "SUPER_TRACKING_CHANGED", "QUEST_WATCH_LIST_CHANGED", "QUEST_REMOVED",
      "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "UNIT_THREAT_LIST_UPDATE",
      "NAME_PLATE_UNIT_ADDED", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_MONEY" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    return
  end
  if event == "PLAYER_LOGOUT" then
    ns.Session.Save(); return -- (also fires on /reload: the session carries over)
  end
  if event == "PLAYER_ENTERING_WORLD" then
    -- re-apply our top-left anchor after the game has finished placing frames
    ns.PlaceFrame()
    -- (isInitialLogin, isReloadingUi): after a /reload, carry the session on
    local isReload = select(1, ...)
    if isReload and not arg1 then ns.Session.Restore() end
  end
  if event == "PLAYER_LOGIN" then
    ns.ApplyBackdrop() -- FlareUI's media is registered by now
    ns.Print("loaded. Type |cffffff00/hab|r to set up Hereabouts.")
    if ns.Questie.Init() then ns.Print("using Questie's quest database.") end
    if ns.Training.Init() then ns.Print("using What's Training for spells to train.") end
    ns.Session.Reset()
  elseif event == "PLAYER_XP_UPDATE" then
    ns.Session.OnXP(); return
  elseif event == "PLAYER_MONEY" then
    ns.Session.OnMoney(); return
  elseif event == "UPDATE_EXHAUSTION" then
    return
  elseif event == "QUEST_ACCEPTED" then
    ns.Questie.Remove((...) or arg1) -- modern: (questID); older clients: (logIndex, questID)
  elseif event == "QUEST_REMOVED" then
    -- e.g. abandoned: it can be picked up again, so let Questie list it again.
    ns.Questie.RescanSoon()
  elseif event == "QUEST_TURNED_IN" or event == "PLAYER_LEVEL_UP" then
    -- QUEST_TURNED_IN: questID (arg1 here), xpReward, moneyReward. (Before 1.7.0 the second of the
    -- rest was taken: the money reward counted as XP, so "~N quests to level" was off.)
    if event == "QUEST_TURNED_IN" then ns.Session.OnQuest((...)) end
    -- New quests may have unlocked (follow-ups, level requirements).
    C_Timer.After(1, ns.Questie.Scan)
  elseif event == "QUEST_LOG_UPDATE" then
    ns.Refresh("log"); return     -- fires often, often for nothing we show
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    -- combat changes which sections show, and (with combat focus) which quests
    if event == "PLAYER_REGEN_ENABLED" then focusKey = "" end
    ns.Refresh(ns.db.combatFocus and "full" or "redraw")
    if event == "PLAYER_REGEN_DISABLED" and ns.db.combatFocus then
      C_Timer.After(1, ns.CheckCombatFocus) -- (a mob that pulled you: its threat line shows a moment later)
    end
    return
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_THREAT_LIST_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
    -- in combat: rebuild only when what you're fighting changes the quests to show
    if ns.db.combatFocus and UnitAffectingCombat("player") then ns.CheckCombatFocus() end
    return
  end
  ns.Refresh()
end)

-- /hab where: a quest's places, from the location model (1.10.0)
function ns.WhereReport(id)
  local L = ns.Locations
  if not ns.Questie.Available() then return { "needs Questie (its database knows where things are)." } end
  local all = ns.Questie.QuestLocations(id)
  local out = { format("quest %d: %d places known", id, #all) }
  local from = L.PlayerPos()
  local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  for _, kind in ipairs({ "giver", "itemsource", "objective", "turnin" }) do
    local list = L.Filter(all, { [kind] = true })
    if #list > 0 then
      local loc, yd = L.Nearest(list, from, here)
      local info = loc and C_Map.GetMapInfo and C_Map.GetMapInfo(loc.map)
      out[#out + 1] = format("  %s: %d; nearest %s%s%s", L.KINDS[kind], #list, loc and loc.label or "?",
        info and info.name and (" in " .. info.name) or "", loc and loc.x and format(" (%.1f, %.1f)", loc.x * 100, loc.y * 100) or "")
        .. (yd and format(", %d yd", yd) or "")
    end
  end
  if C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) then
    local todo, done = ns.QuestPlaces(id)
    -- one point per thing (its nearest), then nearest-next
    local best = {}
    for _, l in ipairs(todo) do
      local k = l.label or "?"
      local yd = L.Yards(l, from)
      if l.x and (not best[k] or (yd and (not best[k].yd or yd < best[k].yd))) then best[k] = { loc = l, yd = yd } end
    end
    local pts = {}
    for _, b in pairs(best) do pts[#pts + 1] = b.loc end
    local names = {}
    for i, l in ipairs(L.Route(pts, from)) do if i <= 6 then names[#names + 1] = l.label end end
    out[#out + 1] = format("  %s: %s", done and "to turn in" or "left to do, nearest first", #names > 0 and table.concat(names, " > ") or "no place known")
  end
  return out
end

-- /hab status (1.7.0): the version, what's bound of Questie and What's Training, the session,
-- the quest item buttons and the errors caught: what a bug report needs
function ns.Status()
  local L = {}
  local get = C_AddOns and C_AddOns.GetAddOnMetadata
  L[#L + 1] = format("version %s; in combat: %s", tostring(get and get(ns.name, "Version") or "?"), InCombatLockdown() and "yes" or "no")
  for _, it in ipairs(ns.Integrations()) do L[#L + 1] = format("%s (%s): %s", it[1], it[2], it[3]) end
  local v = ns.Session.Values()
  L[#L + 1] = format("session: %s, %s%s%s", v.elapsed, v.xp or "max level", v.approx and " (approximate)" or "",
    ns.Session.restoreNote and ("; " .. ns.Session.restoreNote) or "")
  local shown, stale = 0, 0
  for _, b in ipairs(ns.QuestItems.buttons) do
    if b:IsShown() then shown = shown + 1; if b.stale then stale = stale + 1 end end
  end
  L[#L + 1] = format("quest item buttons: %d shown, %d waiting for combat to end", shown, stale)
  L[#L + 1] = format("errors caught: %d", #ns.errors)
  return L
end

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
SLASH_XPPLANNER1 = "/hab"
SLASH_XPPLANNER2 = "/hereabouts"
SLASH_XPPLANNER3 = "/xpp" -- the old command, still works
SlashCmdList.XPPLANNER = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local db = ns.db
  if cmd == "" or cmd == "config" or cmd == "options" then
    local ok, e = pcall(ns.OpenOptions)
    if not ok then ns.Print("settings error: " .. tostring(e)) end
    return
  elseif cmd == "lock" or cmd == "unlock" then
    db.locked = (cmd == "lock")
    ns.Print(db.locked and "locked in place." or "unlocked: drag a section header to move it.")
    if ns.RefreshOptions then ns.RefreshOptions() end
    return
  elseif cmd == "replace" then
    db.replaceTracker = not db.replaceTracker
    ns.ApplyReplace()
    ns.Print(db.replaceTracker and "replacing the quest tracker." or "the quest tracker is back.")
    if InCombatLockdown() then ns.Print("(takes effect when you leave combat)") end
    if ns.RefreshOptions then ns.RefreshOptions() end
  elseif cmd == "toggle" or cmd == "hide" or cmd == "show" then
    db.hidden = (cmd == "hide") or (cmd == "toggle" and not db.hidden)
  elseif cmd == "reset" then
    db.pos = nil; ns.PlaceFrame(); ns.Print("moved back under the quest tracker.")
  elseif cmd == "quests" and tonumber(arg) then
    db.maxQuests = math.max(1, math.min(20, tonumber(arg)))
  elseif cmd == "dungeons" then
    db.showDungeons = not db.showDungeons; ns.Print("dungeons " .. (db.showDungeons and "on" or "off"))
  elseif cmd == "qinfo" and tonumber(arg) then
    -- what each Questie source holds for one quest (to see why the zone filter decided as it did)
    local id = tonumber(arg)
    ns.Print("Questie sources for quest " .. id .. ":")
    for _, l in ipairs(ns.Questie.Inspect(id)) do print("  " .. l) end
    return
  elseif cmd == "session" then
    ns.Session.Reset(); ns.Print("session stats reset.")
  elseif cmd == "status" then
    for _, l in ipairs(ns.Status()) do ns.Print(l) end
    return
  elseif cmd == "errors" then
    if #ns.errors == 0 then ns.Print("no errors caught this session.") end
    for _, e in ipairs(ns.errors) do ns.Print(format("%s (x%d): %s", e.where, e.n, e.msg)) end
    return
  elseif cmd == "questie" then
    ns.Questie.Diagnose(ns.Print)
  elseif cmd == "zone" then
    -- why each active quest counts as in your zone or not (for "only quests in my current zone")
    ns.Print(format("version %s, your zone: %s (map %s)", tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name, "Version") or "?"),
      GetRealZoneText() or "?", tostring(ns.Questie.CurrentZoneMap())))
    -- each: here / elsewhere / can't tell (still listed), why, and which source decided (LOCATION_SOURCES.md)
    for _, q in ipairs(ns.LogQuests()) do
      local inZone, why, source = ns.QuestInZone(q)
      local color, state = "|cff999999", "elsewhere"
      if inZone then color, state = "|cff60ff60", "here" elseif inZone == nil then color, state = "|cffffd200", "can't tell (listed)" end
      print(format("  %s[%s] %s|r - %s: %s [%s] (quest %s)", color, tostring(q.level), q.title,
        state, why, ns.LOCATION_CONFIDENCE[source] or tostring(source), tostring(q.questID)))
    end
    return
  elseif cmd == "where" then
    -- every place known for a quest (Questie's data), by kind, the nearest of each, and a visiting
    -- order of what's left (/hab where <questID>; blank: the focused quest)
    local id = tonumber(arg) or (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID())
    if not id or id == 0 then ns.Print("/hab where <questID> (or focus a quest)"); return end
    for _, l in ipairs(ns.WhereReport(id)) do ns.Print(l) end
    return
  elseif cmd == "focus" then
    -- what combat focus sees right now: who you're fighting, how it was found, and their quests
    for _, l in ipairs(ns.CombatFocusReport()) do ns.Print(l) end
    return
  else
    ns.Print("/hab (settings)  -  /hab lock | unlock  -  /hab replace  -  /hab toggle  -  /hab reset (position)  -  /hab quests <n>  -  /hab session (reset)  -  /hab dungeons  -  /hab zone  -  /hab where <quest>  -  /hab focus  -  /hab questie  -  /hab status  -  /hab errors")
    return
  end
  ns.Refresh()
end
