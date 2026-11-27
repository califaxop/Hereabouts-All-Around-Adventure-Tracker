-- Leveling session: XP per hour, time to level, XP and quests this session, rested XP.
-- Everything comes from your own XP, which the game always lets addons read.
local _, ns = ...
local S = {}
ns.Session = S

local start, gained, quests, questXP, earned = nil, 0, 0, 0, 0
-- approx: the XP total is short by some amount: you went up more than one level between two XP
-- readings (the levels in between can't be read afterwards), see S.OnXP
local approx = false
local startLevel -- your level when the session began (for "levels this session" and the history)
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

-- Past sessions (1.11.0): HereaboutsCharDB.history, newest first, at most HISTORY_MAX. A session
-- goes there when it ends: at your next real login (not a /reload or a loading screen), or when
-- you reset it. Only sessions of a minute or more with something gained are kept.
S.HISTORY_MAX = 20
-- a session's summary, from its numbers (pure)
function S.Summary(t)
  return { at = t.at, dur = math.floor(t.elapsed or 0), xp = t.gained or 0, quests = t.quests or 0,
    questXP = t.questXP or 0, gold = t.earned or 0, from = t.startLevel, to = t.lastLevel, approx = t.approx or nil }
end
local function Worth(t) return (t.elapsed or 0) >= 60 and ((t.gained or 0) > 0 or (t.quests or 0) > 0 or (t.earned or 0) > 0) end
function S.Archive(t)
  if not Worth(t) then return false end
  HereaboutsCharDB = HereaboutsCharDB or {}
  local h = HereaboutsCharDB.history
  if type(h) ~= "table" then h = {}; HereaboutsCharDB.history = h end
  table.insert(h, 1, S.Summary(t))
  while #h > S.HISTORY_MAX do table.remove(h) end
  return true
end
function S.History()
  local h = HereaboutsCharDB and HereaboutsCharDB.history
  return type(h) == "table" and h or {}
end
-- the session saved at your last logout, at a real login: into the history
function S.ArchiveSaved()
  local s = HereaboutsCharDB and HereaboutsCharDB.session
  if S.Check(s) then
    s.at = s.savedAt
    S.Archive(s)
  end
  if HereaboutsCharDB then HereaboutsCharDB.session = nil end
end

function S.Reset()
  -- (the session so far goes into the history first, when it's worth keeping)
  if start then
    S.Archive({ at = time and time() or 0, elapsed = Now() - start, gained = gained, quests = quests, questXP = questXP,
      earned = earned, startLevel = startLevel, lastLevel = lastLevel, approx = approx })
  end
  start, gained, quests, questXP, earned, approx = Now(), 0, 0, 0, 0, false
  lastXP, lastMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  startLevel = lastLevel
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
    gained = gained, quests = quests, questXP = questXP, earned = earned, approx = approx or nil,
    lastXP = lastXP, lastMax = lastMax, lastLevel = lastLevel, lastMoney = lastMoney, startLevel = startLevel,
  }
end

-- a saved session that can be trusted (1.7.0): every number a real, non-negative number of a
-- sensible size; else why not (it's then started afresh, never half-restored)
local function Count(v, max) return type(v) == "number" and v == v and v >= 0 and v <= max end
function S.Check(s)
  if type(s) ~= "table" then return false, "none saved" end
  if not Count(s.elapsed, 30 * 86400) then return false, "its length" end
  for _, k in ipairs({ "gained", "quests", "questXP", "earned", "lastXP", "lastMax", "lastMoney" }) do
    if s[k] ~= nil and not Count(s[k], 1e12) then return false, k end
  end
  for _, k in ipairs({ "lastLevel", "startLevel" }) do
    if s[k] ~= nil and not (Count(s[k], 1000) and s[k] == math.floor(s[k])) then return false, k end
  end
  if s.savedAt ~= nil and not Count(s.savedAt, 1e11) then return false, "savedAt" end
  return true
end

-- after a /reload: carry on from the saved session (true), or false if there's none to carry on
function S.Restore()
  local s = HereaboutsCharDB and HereaboutsCharDB.session
  local ok, why = S.Check(s)
  S.restoreNote = (not ok and type(s) == "table") and ("saved session not used: bad " .. why) or nil
  if not ok then return false end
  local now = time and time() or 0
  local gap = math.max(0, now - (s.savedAt or now)) -- the loading screen's few seconds count too
  if gap > 15 * 60 then return false end -- not a reload: something left it behind long ago
  start = Now() - s.elapsed - gap
  gained, quests, questXP, earned = s.gained or 0, s.quests or 0, s.questXP or 0, s.earned or 0
  approx = s.approx and true or false
  lastXP, lastMax, lastLevel, lastMoney = s.lastXP, s.lastMax, s.lastLevel, s.lastMoney
  startLevel = s.startLevel or s.lastLevel
  S.OnXP(); S.OnMoney() -- anything gained while the UI reloaded
  if S.Paint then S.Paint() end
  return true
end

-- money changed: only what came in counts (loot, quest rewards, sales, mail, trades), not what
-- you spent: "gold gained", not your balance
function S.OnMoney()
  if not start then S.Reset(); return end
  local m = GetMoney and GetMoney() or 0
  if lastMoney and m > lastMoney then earned = earned + (m - lastMoney) end
  lastMoney = m
end

-- XP changed: count what was gained, including across a level-up.
-- One level up: the rest of the old level, then the new one so far (exact). More than one level
-- between two readings (a big turn-in, the XP of a /reload's loading screen): the levels in between
-- can't be read afterwards, so the total is short by them: counted as approximate (shown "~").
-- the XP gained between two readings, and whether it's short (more than one level up). Pure.
function S.Gain(fromXP, fromMax, fromLevel, xp, level)
  if level > fromLevel then return (fromMax - fromXP) + xp, level - fromLevel > 1 end
  if level < fromLevel then return 0, false end -- (can't happen: start again from here)
  return math.max(0, xp - fromXP), false
end
function S.OnXP()
  if not start then S.Reset(); return end
  local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
  if not (xp and lastXP and level and lastLevel) then lastXP, lastMax, lastLevel = xp, max, level; return end
  local d, short = S.Gain(lastXP, lastMax or 0, lastLevel, xp, level)
  if d > 0 then gained = gained + d end
  if short then approx = true end
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

S.Short, S.Duration, S.Money = Short, Duration, Money -- (for /hab progress)

-- the stats the bar can show, in order: key, settings label, short text (or nil when not
-- meaningful right now), and the tooltip line
S.STATS = {
  { "xph",    "XP per hour" },
  { "ttl",    "Time to level" },
  { "gph",    "Gold gained per hour" },
  { "xp",     "XP this session" },
  { "quests", "Quests this session" },
  { "rested", "Rested XP" },
  { "gold",   "Gold gained this session" },
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
    v.xp = (approx and "~" or "") .. N(Short(gained)) .. " XP"
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
  v.approx = approx
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
  local key = tostring(th.flare) .. tostring(th.eui) .. a .. th.accent[1]
  if bar.skinKey ~= key then
    bar.skinKey = key
    if th.eui then -- EllesmereUI: its flat panel, a thin grey border
      bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
      local okP, r, g, b = pcall(ns.euiSkin.GetPanelColor)
      if not (okP and r) then r, g, b = 0.07, 0.07, 0.08 end
      bar:SetBackdropColor(r, g, b, a)
      bar:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
    elseif th.flare then
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
  -- what the numbers mean (1.7.0)
  GameTooltip:AddLine("Time to level: at this session's XP rate. Quests to level: at this session's average quest XP.", 0.6, 0.6, 0.6, true)
  GameTooltip:AddLine("Gold gained: money in (loot, sales, quest rewards, mail), spending not taken off.", 0.6, 0.6, 0.6, true)
  if v.approx then
    GameTooltip:AddLine("~ XP: you went up more than one level at once; the levels in between aren't counted.", 1, 0.82, 0, true)
  end
  -- the last session in the history (1.11.0; /hab progress has more)
  local last = S.History()[1]
  if last then
    GameTooltip:AddDoubleLine("Last session", format("%s, %s XP, %d quest%s", Duration(last.dur), Short(last.xp), last.quests,
      last.quests == 1 and "" or "s"), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
  end
  GameTooltip:AddLine("Right-click to reset (it goes into the history). Pick what shows in /hab, Session. /hab progress: your progress.", 0.6, 0.6, 0.6, true)
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
