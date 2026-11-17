-- The list, drawn in the quest tracker's style: section headers, yellow titles,
-- "- objective" lines, using the tracker's own fonts where the client has them.
local _, ns = ...

local WIDTH = 235

local function FontObj(...)
  for i = 1, select("#", ...) do
    local f = _G[select(i, ...)]
    if f then return f end
  end
end
local HEADER_FONT = FontObj("ObjectiveTrackerHeaderFont", "GameFontNormalMed2", "GameFontNormal")
local TITLE_FONT  = FontObj("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontNormal")
local LINE_FONT   = FontObj("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontHighlightSmall")

-- Colours. These tables are filled from one of the two palettes below (ns.ApplyStyle),
-- so switching style recolours everything on the next draw.
local TITLE_COLOR, TITLE_HOVER_COLOR, LINE_COLOR, DONE_COLOR = {}, {}, {}, {}
local FOCUS_COLOR, DIM_TITLE, DIM_LINE, HEADER_COLOR = {}, {}, {}, {}

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

function ns.UsingFlare() return ns.db and ns.db.useFlareStyle and ns.FlareBorder() ~= nil end

local frame = CreateFrame("Frame", "XPPlannerFrame", UIParent)
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
  Fill(TITLE_COLOR, p.title); Fill(TITLE_HOVER_COLOR, p.hover); Fill(LINE_COLOR, p.line); Fill(DONE_COLOR, p.done)
  Fill(FOCUS_COLOR, p.focus); Fill(DIM_TITLE, p.dimTitle); Fill(DIM_LINE, p.dimLine); Fill(HEADER_COLOR, p.header)
end

function ns.ApplyBackdrop()
  ApplyStyle()
  local a = ns.db.bgAlpha or 0
  local border = ns.db.showBorder
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
  boxed:SetPoint("TOPLEFT", inner, "TOPLEFT", -1, 1)
  boxed:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 1, -1)
  boxed:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  -- soft fade only when there's no border
  for _, t in ipairs(pieces) do
    t:SetVertexColor(0, 0, 0, a)
    t:SetShown(a > 0 and not border)
  end
  boxed:SetShown(border)
  if border then
    boxed:SetBackdropColor(0, 0, 0, a)
    local c = ns.db.borderColor
    boxed:SetBackdropBorderColor(c[1], c[2], c[3], 1)
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
scroll:SetScript("OnMouseWheel", function(self, delta) ScrollTo(self:GetVerticalScroll() - delta * 40) end)

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
local headers, titles, lines = {}, {}, {}
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
    end)
    headers[used.h] = h
  end
  local flare = ns.UsingFlare()
  h.bg:SetShown(not flare)
  h.divider:SetShown(flare)
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
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFontObject(TITLE_FONT)
    b.text:SetPoint("LEFT"); b.text:SetPoint("RIGHT")
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
  b.text:SetTextColor(unpack(TITLE_COLOR))
  b:Show()
  return b
end

local function GetLine()
  used.l = used.l + 1
  local l = lines[used.l]
  if not l then
    l = content:CreateFontString(nil, "OVERLAY")
    l:SetFontObject(LINE_FONT)
    l:SetWidth(WIDTH - 20); l:SetJustifyH("LEFT")
    lines[used.l] = l
  end
  l:Show()
  return l
end

-- Focus mark: a gold bar down the left of the focused quest, with a soft gold glow behind it.
local marks, usedMarks = {}, 0
local function GetMark()
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
  m.bar:SetVertexColor(FOCUS_COLOR[1], FOCUS_COLOR[2], FOCUS_COLOR[3], 0.9)
  m.bg:SetGradient("HORIZONTAL", CreateColor(FOCUS_COLOR[1], FOCUS_COLOR[2], FOCUS_COLOR[3], 0.18),
    CreateColor(FOCUS_COLOR[1], FOCUS_COLOR[2], FOCUS_COLOR[3], 0))
  m.bg:Show(); m.bar:Show()
  return m
end

local function ResetPools()
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
  if TomTom and TomTom.AddWaypoint then
    if pcall(TomTom.AddWaypoint, TomTom, loc.map, loc.x, loc.y, { title = title, from = "XP Planner" }) then
      placed = true
    end
  end
  if OpenWorldMap then pcall(OpenWorldMap, loc.map)
  elseif WorldMapFrame and WorldMapFrame.SetMapID then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then pcall(ToggleWorldMap) end
    pcall(WorldMapFrame.SetMapID, WorldMapFrame, loc.map)
  end
  return placed
end

local function ShowPickupMenu(owner, q)
  local function showOnMap()
    local loc = ns.Questie.Location(q.id)
    local who = q.starter or q.name
    if not loc then ns.Print("no location known for " .. (q.name or "this quest") .. ".")
    elseif ns.SetWaypoint(loc, who) then ns.Print(format("waypoint set: %s (%.1f, %.1f)", who, loc.x * 100, loc.y * 100))
    else ns.Print("couldn't place a waypoint on that map.") end
  end
  local function ignore()
    ns.IgnoreQuest(q.id, q.name, q.level)
    ns.Print((q.name or "Quest") .. " ignored. Manage ignored quests in /xpp.")
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
local function AddEntry(title, level, sub, onClick, style)
  local startY = y
  local t = GetTitle()
  local lvl = level and format("[%d] ", level) or ""
  t.text:SetText(lvl .. (title or "?"))
  t.spellID = style and style.spellID or nil
  if style and style.focused then t.baseColor = FOCUS_COLOR
  elseif style and style.dim then t.baseColor = DIM_TITLE end
  t.text:SetTextColor(unpack(t.baseColor))
  t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  t:SetScript("OnClick", onClick)
  Place(t, 10, 0)
  for _, s in ipairs(sub) do
    local l = GetLine()
    l:SetText("- " .. s.text)
    local c = s.done and DONE_COLOR or (s.color or LINE_COLOR)
    if style and style.dim and not s.color then c = DIM_LINE end
    l:SetTextColor(unpack(c))
    l:SetHeight(l:GetStringHeight())
    Place(l, 20, 1)
  end
  if style and style.focused then
    local m = GetMark()
    local top, h = startY + VIEW_T - 2, (y - startY) + 4
    m.bar:ClearAllPoints(); m.bar:SetPoint("TOPLEFT", content, "TOPLEFT", VIEW_L + 4, -top); m.bar:SetHeight(h)
    m.bg:ClearAllPoints(); m.bg:SetPoint("TOPLEFT", content, "TOPLEFT", VIEW_L + 4, -top)
    m.bg:SetSize(WIDTH - 8, h)
  end
  y = y + 6
end

local shownSomething = false
local function Section(name, count, key)
  local h = GetHeader()
  h.text:SetText(name)
  local collapsed = ns.db.collapsedSections and ns.db.collapsedSections[key]
  h.toggle:SetText(collapsed and "+" or "-")
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

  if #s.quests > 0 and Section("Active Quests", #s.quests, "quests") then
    for _, q in ipairs(s.quests) do
      local sub = {}
      if q.complete then
        sub[#sub + 1] = { text = "Ready to turn in", color = { 0.3, 1, 0.3 } }
      else
        if ns.db.showObjectives then
          for i, o in ipairs(q.objectives) do if i <= 3 then sub[#sub + 1] = o end end
        end
      end
      if ns.db.showXP and q.xp > 0 then sub[#sub + 1] = { text = BreakUpLargeNumbers and (BreakUpLargeNumbers(q.xp) .. " XP") or (q.xp .. " XP") } end
      AddEntry(q.title, q.level, sub, function(self, button) ActiveQuestClick(self, button, q.questID) end,
        { focused = q.focused, dim = not q.tracked and not q.focused })
    end
  end

  if #s.pickup > 0 and Section("Quests to Pick Up", #s.pickup, "pickup") then
    for _, q in ipairs(s.pickup) do
      local sub = {}
      if ns.db.showXP then sub[1] = { text = (BreakUpLargeNumbers and BreakUpLargeNumbers(q.xp) or q.xp) .. " XP" } end
      if not ns.db.showStarter then
        -- no giver line
      elseif q.starter then
        sub[#sub + 1] = { text = q.starter .. (q.zone and (" - " .. q.zone) or ""),
          color = q.here and { 0.3, 1, 0.3 } or nil }
      elseif q.zone then
        sub[#sub + 1] = { text = q.zone, color = q.here and { 0.3, 1, 0.3 } or nil }
      end
      AddEntry(q.name, q.level, sub, function(self, button)
        if button == "RightButton" then ShowPickupMenu(self, q); return end
        ns.Print(format("[%d] %s - %s XP - %s", q.level or 0, q.name or "?", q.xp,
          (q.starter or "?") .. (q.zone and (", " .. q.zone) or "")))
      end)
    end
  end

  if #s.nearby > 0 and Section("Available Nearby", #s.nearby, "nearby") then
    for _, q in ipairs(s.nearby) do
      AddEntry(q.title, q.level, { { text = "Not picked up yet (see map)" } }, function()
        if ToggleWorldMap then pcall(ToggleWorldMap) end
      end)
    end
  end

  if s.training and #s.training > 0 and Section("Training", #s.training, "training") then
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
      local sub = { { text = sp.cost > 0 and money(sp.cost) or "Free" } }
      if sp.nextLevel then sub[#sub + 1] = { text = "Next level" } end
      AddEntry(name, sp.level, sub, function()
        -- shift-click links the spell in chat, like everywhere else
        if IsModifiedClick and IsModifiedClick("CHATLINK") and sp.link and ChatEdit_InsertLink then
          ChatEdit_InsertLink(sp.link)
        end
      end, { spellID = type(sp.id) == "number" and sp.id or nil, dim = sp.nextLevel })
    end
  end

  if #s.dungeons > 0 and Section("Dungeons", #s.dungeons, "dungeons") then
    for _, d in ipairs(s.dungeons) do
      AddEntry(d.name, nil, { { text = format("Levels %d-%d", d.min, d.max) }, { text = d.zone } }, function()
        ns.Print(d.name .. ": " .. d.zone .. format(" (levels %d-%d)", d.min, d.max))
      end)
    end
  end

  -- Size: grow with the content up to the max height, then scroll.
  local viewH = math.min(y, ns.db.maxHeight or 400)
  frame:SetHeight(math.max(viewH, 1))
  content:SetHeight(y + VIEW_T)
  maxScroll = math.max(0, y - viewH)
  ScrollTo(scroll:GetVerticalScroll()) -- keep your place, clamped to the new size
  if ns.db.pos and ns.db.pos[1] ~= "TOPLEFT" then ns.LockTopLeft() end
  frame:SetShown(shownSomething and not ns.db.hidden)
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
local pending = false
function ns.Refresh()
  if pending then return end
  pending = true
  C_Timer.After(0.2, function()
    pending = false
    local ok, s = pcall(ns.BuildSuggestions)
    if ok then ns.Render(s) else ns.Print("error: " .. tostring(s)) end
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, arg1, ...)
  if event == "ADDON_LOADED" then
    if arg1 ~= ns.name then return end
    ns.LoadDB(); ns.PlaceFrame(); ns.CreateOptions()
    ns.Questie.onUpdate = ns.Refresh
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
      "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "QUESTLINE_UPDATE", "PLAYER_LOGIN",
      "SUPER_TRACKING_CHANGED", "QUEST_WATCH_LIST_CHANGED", "QUEST_REMOVED" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    -- re-apply our top-left anchor after the game has finished placing frames
    ns.PlaceFrame()
  end
  if event == "PLAYER_LOGIN" then
    ns.ApplyBackdrop() -- FlareUI's media is registered by now
    if ns.Questie.Init() then ns.Print("using Questie's quest database.") end
    if ns.Training.Init() then ns.Print("using What's Training for spells to train.") end
  elseif event == "QUEST_ACCEPTED" then
    ns.Questie.Remove((...) or arg1) -- modern: (questID); older clients: (logIndex, questID)
  elseif event == "QUEST_REMOVED" then
    -- e.g. abandoned: it can be picked up again, so let Questie list it again.
    ns.Questie.RescanSoon()
  elseif event == "QUEST_TURNED_IN" or event == "PLAYER_LEVEL_UP" then
    -- New quests may have unlocked (follow-ups, level requirements).
    C_Timer.After(1, ns.Questie.Scan)
  end
  ns.Refresh()
end)

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
SLASH_XPPLANNER1 = "/xpp"
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
    ns.Print(db.replaceTracker and "replacing Blizzard's quest tracker." or "Blizzard's quest tracker is back.")
    if InCombatLockdown() then ns.Print("(takes effect when you leave combat)") end
    if ns.RefreshOptions then ns.RefreshOptions() end
  elseif cmd == "toggle" or cmd == "hide" or cmd == "show" then
    db.hidden = (cmd == "hide") or (cmd == "toggle" and not db.hidden)
  elseif cmd == "reset" then
    db.pos = nil; ns.PlaceFrame(); ns.Print("moved back under the quest tracker.")
  elseif cmd == "quests" and tonumber(arg) then
    db.maxQuests = math.max(1, math.min(20, tonumber(arg)))
  elseif cmd == "nearby" then
    db.showNearby = not db.showNearby; ns.Print("nearby quests " .. (db.showNearby and "on" or "off"))
  elseif cmd == "dungeons" then
    db.showDungeons = not db.showDungeons; ns.Print("dungeons " .. (db.showDungeons and "on" or "off"))
  else
    ns.Print("/xpp (settings)  -  /xpp lock | unlock  -  /xpp replace  -  /xpp toggle  -  /xpp reset (position)  -  /xpp quests <n>  -  /xpp nearby  -  /xpp dungeons")
    return
  end
  ns.Refresh()
end
