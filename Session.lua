-- Leveling session: XP per hour, time to level, XP and quests this session, rested XP.
-- Everything comes from your own XP, which the game always lets addons read.
local _, ns = ...
local S = {}
ns.Session = S

local start, gained, quests, questXP, earned = nil, 0, 0, 0, 0
local lastMoney
local lastXP, lastMax, lastLevel

local function Now() return GetTime and GetTime() or 0 end
local function AtMax()
  if IsPlayerAtEffectiveMaxLevel then
    local ok, v = pcall(IsPlayerAtEffectiveMaxLevel)
    if ok and v ~= nil then return v and true or false end
  end
  local max = UnitXPMax("player")
  return not max or max == 0
end

function S.Reset()
  start, gained, quests, questXP, earned = Now(), 0, 0, 0, 0
  lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  lastMoney = GetMoney and GetMoney() or 0
  if S.Paint then S.Paint() end
end

-- A /reload keeps the session going: it's saved just before (PLAYER_LOGOUT fires on a reload too)
-- and restored after, when the game says the load is a UI reload. A real login starts afresh.
-- Saved per character (HereaboutsCharDB), so alts keep their own.
function S.Save()
  if not start then return end
  HereaboutsCharDB = HereaboutsCharDB or {}
  HereaboutsCharDB.session = {
    elapsed = Now() - start, savedAt = time and time() or 0,
    gained = gained, quests = quests, questXP = questXP, earned = earned,
    lastXP = lastXP, lastMax = lastMax, lastLevel = lastLevel, lastMoney = lastMoney,
  }
end

-- after a /reload: carry on from the saved session (true), or false if there's none to carry on
function S.Restore()
  local s = HereaboutsCharDB and HereaboutsCharDB.session
  if type(s) ~= "table" or type(s.elapsed) ~= "number" then return false end
  local now = time and time() or 0
  local gap = math.max(0, now - (s.savedAt or now)) -- the loading screen's few seconds count too
  if gap > 15 * 60 then return false end -- not a reload: something left it behind long ago
  start = Now() - s.elapsed - gap
  gained, quests, questXP, earned = s.gained or 0, s.quests or 0, s.questXP or 0, s.earned or 0
  lastXP, lastMax, lastLevel, lastMoney = s.lastXP, s.lastMax, s.lastLevel, s.lastMoney
  S.OnXP(); S.OnMoney() -- anything gained while the UI reloaded
  if S.Paint then S.Paint() end
  return true
end

-- money changed: only what came in counts (loot, quest rewards, sales), not what you spent
function S.OnMoney()
  if not start then S.Reset(); return end
  local m = GetMoney and GetMoney() or 0
  if lastMoney and m > lastMoney then earned = earned + (m - lastMoney) end
  lastMoney = m
end

-- XP changed: count what was gained, including across a level-up
function S.OnXP()
  if not start then S.Reset(); return end
  local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  if not (xp and lastXP) then lastXP, lastMax, lastLevel = xp, max, level; return end
  local d
  if level > (lastLevel or level) then
    d = ((lastMax or 0) - lastXP) + xp -- the rest of the old level, then the new one so far
  else
    d = xp - lastXP
  end
  if d > 0 then gained = gained + d end
  lastXP, lastMax, lastLevel = xp, max, level
end

-- a quest was turned in, for "quests this session" and "about N quests to level"
function S.OnQuest(xpReward)
  if not start then S.Reset() end
  quests = quests + 1
  if type(xpReward) == "number" and xpReward > 0 then questXP = questXP + xpReward end
end

local function Short(n)
  if n >= 1e6 then return format("%.1fm", n / 1e6) end
  if n >= 1e4 then return format("%.1fk", n / 1e3) end
  return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n))
end
local function Duration(sec)
  if sec >= 3600 * 99 then return "a long while" end
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h > 0 then return format("%dh %02dm", h, m) end
  return format("%dm", math.max(1, m))
end

local function Money(c)
  c = math.floor(c)
  local g, si, co = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  if g > 0 then return format("%dg %ds", g, si) end
  if si > 0 then return format("%ds %dc", si, co) end
  return format("%dc", co)
end

-- the stats the bar can show, in order: key, settings label, short text (or nil when not
-- meaningful right now), and the tooltip line
S.STATS = {
  { "xph",    "XP per hour" },
  { "ttl",    "Time to level" },
  { "gph",    "Gold per hour" },
  { "xp",     "XP this session" },
  { "quests", "Quests this session" },
  { "rested", "Rested XP" },
  { "gold",   "Gold this session" },
}
-- Each stat's text, with its number(s) wrapped in `hl` ... "|r" (the bars show numbers in the
-- quest-title gold; the tooltip passes no colour). The labels keep the line colour.
function S.Values(hl)
  if not start then S.Reset() end
  local v = {}
  local function N(s) return hl and (hl .. s .. "|r") or s end
  local elapsed = math.max(1, Now() - start)
  local warm = elapsed >= 60 -- the first minute says little about a rate
  local maxed = AtMax()
  local left = math.max(0, (UnitXPMax("player") or 0) - (UnitXP("player") or 0))
  local rate = gained / elapsed * 3600
  if not maxed then
    v.xph = ((warm and gained > 0) and N(Short(rate)) or N("--")) .. " XP/h"
    v.ttl = "Level in " .. ((warm and gained > 0) and N(Duration(left / (rate / 3600))) or N("--"))
    v.xp = N(Short(gained)) .. " XP"
    if quests > 0 then
      v.quests = format("%s quest%s", N(quests), quests == 1 and "" or "s")
      if questXP > 0 then v.quests = v.quests .. format(" (~%s to level)", N(math.ceil(left / (questXP / quests)))) end
    else
      v.quests = N("0") .. " quests"
    end
    local rested = GetXPExhaustion and GetXPExhaustion()
    v.rested = (type(rested) == "number" and rested > 0) and ("Rested " .. N(Short(rested))) or nil
  end
  v.gph = (warm and N(Money(earned / elapsed * 3600)) or N("--")) .. "/h"
  v.gold = N("+" .. Money(earned))
  v.elapsed = Duration(elapsed)
  return v
end

---------------------------------------------------------------------------
-- The bars under the tracker: one slim bar per row of stats that pair up, stacked, so
-- nothing gets cut off. A row shows when any of its stats is turned on.
---------------------------------------------------------------------------
S.ROWS = {
  { "xph", "ttl" },     -- 13.2k XP/h  ·  Level in 5h 32m
  { "gph", "gold" },    -- 1g 20s/h  ·  +3g 40s
  { "xp", "quests" },   -- 8,500 XP  ·  4 quests (~12 to level)
  { "rested" },         -- Rested 4,500
}
local bars = {}
S.bars = bars
local BAR_H, GAP = 22, 2
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"

local function Skin(bar)
  local th = ns.Theme()
  local a = math.max(ns.db.bgAlpha or 0, 0.55)
  local key = tostring(th.flare) .. a .. th.accent[1]
  if bar.skinKey ~= key then
    bar.skinKey = key
    if th.flare then
      bar:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = ns.FlareBorder(), edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
      bar:SetBackdropColor(1, 1, 1, a)
      bar:SetBackdropBorderColor(th.accent[1], th.accent[2], th.accent[3], 1)
    else -- the game's tooltip border, like the tracker
      bar:SetBackdrop({ bgFile = ns.BLIZZ_BG, edgeFile = ns.BLIZZ_EDGE, tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      bar:SetBackdropColor(0.03, 0.03, 0.03, a)
      local c = ns.BLIZZ_BORDER_COLOR
      bar:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    end
  end
  bar.text:SetFontObject(th.lineFont)
  bar.text:SetTextColor(th.line[1], th.line[2], th.line[3])
end

local function Tooltip(self)
  local v = S.Values()
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText("Session (" .. v.elapsed .. ")", 1, 0.82, 0)
  for _, st in ipairs(S.STATS) do
    if v[st[1]] then GameTooltip:AddDoubleLine(st[2], v[st[1]], 0.8, 0.8, 0.8, 1, 1, 1) end
  end
  GameTooltip:AddLine("Right-click to reset. Pick what shows in /hab, Session.", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Bar(i)
  if bars[i] then return bars[i] end
  local bar = CreateFrame("Frame", "XPPlannerSessionBar" .. i, ns.TrackerFrame, "BackdropTemplate")
  bar:SetHeight(BAR_H)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("LEFT", 8, 0); bar.text:SetPoint("RIGHT", -8, 0)
  bar.text:SetJustifyH("CENTER"); bar.text:SetWordWrap(false)
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", Tooltip)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then S.Reset(); ns.Print("session stats reset.") end
  end)
  bars[i] = bar
  if i == 1 then S.bar = bar end
  return bar
end

function S.Paint()
  if not (ns.db and ns.TrackerFrame) then return end
  local used = 0
  if ns.db.showSession then
    local t = ns.Theme().title -- the quest names' gold, for the numbers
    local v, on = S.Values(format("|cff%02x%02x%02x", math.floor(t[1] * 255 + 0.5), math.floor(t[2] * 255 + 0.5), math.floor(t[3] * 255 + 0.5))), ns.db.sessionStats or {}
    local lines = {}
    for _, row in ipairs(S.ROWS) do
      local parts = {}
      for _, key in ipairs(row) do
        if on[key] and v[key] then parts[#parts + 1] = v[key] end
      end
      if #parts > 0 then lines[#lines + 1] = table.concat(parts, "  \194\183  ") end
    end
    if #lines == 0 then lines[1] = "Session: pick what to show in /hab" end
    local anchor = ns.TrackerBox or ns.TrackerFrame
    for i, line in ipairs(lines) do
      local bar = Bar(i)
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -3 or -GAP)
      bar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, i == 1 and -3 or -GAP)
      Skin(bar)
      bar.text:SetText(line)
      bar:Show()
      anchor, used = bar, i
    end
  end
  for i = used + 1, #bars do bars[i]:Hide() end
end

-- keep the numbers moving
C_Timer.NewTicker(2, function() if bars[1] and bars[1]:IsVisible() then S.Paint() end end)
