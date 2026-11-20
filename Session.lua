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
function S.Values()
  if not start then S.Reset() end
  local v = {}
  local elapsed = math.max(1, Now() - start)
  local warm = elapsed >= 60 -- the first minute says little about a rate
  local maxed = AtMax()
  local left = math.max(0, (UnitXPMax("player") or 0) - (UnitXP("player") or 0))
  local rate = gained / elapsed * 3600
  if not maxed then
    v.xph = (warm and gained > 0) and (Short(rate) .. " XP/h") or "-- XP/h"
    v.ttl = (warm and gained > 0) and ("Level in " .. Duration(left / (rate / 3600))) or "Level in --"
    v.xp = Short(gained) .. " XP"
    if quests > 0 then
      v.quests = format("%d quest%s", quests, quests == 1 and "" or "s")
      if questXP > 0 then v.quests = v.quests .. format(" (~%d to level)", math.ceil(left / (questXP / quests))) end
    else
      v.quests = "0 quests"
    end
    local rested = GetXPExhaustion and GetXPExhaustion()
    v.rested = (type(rested) == "number" and rested > 0) and ("Rested " .. Short(rested)) or nil
  end
  v.gph = warm and (Money(earned / elapsed * 3600) .. "/h") or "--/h"
  v.gold = "+" .. Money(earned)
  v.elapsed = Duration(elapsed)
  return v
end

---------------------------------------------------------------------------
-- The bar under the tracker
---------------------------------------------------------------------------
local bar
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local function Skin()
  local th = ns.Theme()
  local a = math.max(ns.db.bgAlpha or 0, 0.55)
  if th.flare then
    bar:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = ns.FlareBorder(), edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bar:SetBackdropColor(1, 1, 1, a)
  else
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    bar:SetBackdropColor(0.03, 0.03, 0.03, a)
  end
  bar:SetBackdropBorderColor(th.accent[1], th.accent[2], th.accent[3], 1)
  bar.text:SetFontObject(th.lineFont)
  bar.text:SetTextColor(th.line[1], th.line[2], th.line[3])
end

local function Build()
  bar = CreateFrame("Frame", "XPPlannerSessionBar", ns.TrackerFrame, "BackdropTemplate")
  S.bar = bar
  bar:SetHeight(22)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("LEFT", 8, 0); bar.text:SetPoint("RIGHT", -8, 0)
  bar.text:SetJustifyH("CENTER"); bar.text:SetWordWrap(false)
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function(self)
    local v = S.Values()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Session (" .. v.elapsed .. ")", 1, 0.82, 0)
    for _, st in ipairs(S.STATS) do
      if v[st[1]] then GameTooltip:AddDoubleLine(st[2], v[st[1]], 0.8, 0.8, 0.8, 1, 1, 1) end
    end
    GameTooltip:AddLine("Right-click to reset. Pick what shows in /xpp, Session.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then S.Reset(); ns.Print("session stats reset.") end
  end)
end

function S.Paint()
  if not (ns.db and ns.TrackerFrame) then return end
  if not bar then Build() end
  if not ns.db.showSession then bar:Hide(); return end
  local box = ns.TrackerBox or ns.TrackerFrame
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -3)
  bar:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -3)
  Skin()
  local v, parts, on = S.Values(), {}, ns.db.sessionStats or {}
  for _, st in ipairs(S.STATS) do
    if on[st[1]] and v[st[1]] then parts[#parts + 1] = v[st[1]] end
  end
  bar.text:SetText(#parts > 0 and table.concat(parts, "  \194\183  ") or "Session: pick what to show in /xpp")
  bar:Show()
end

-- keep the numbers moving
C_Timer.NewTicker(2, function() if bar and bar:IsVisible() then S.Paint() end end)
