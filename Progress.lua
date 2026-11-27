-- Character progression (1.11.0): professions and weapon skills, and /hab progress, a summary of
-- your level, this session and the ones before.
-- Skills come from C_SkillInfo.GetSkillLineInfoByID(skillLine) (Verified in WoW Forever for weapon
-- skills, by Equip This!: "Two-Handed Maces 209/210"); a skill line it doesn't answer for, or one
-- you don't have (rank 0), isn't shown. Skill line IDs: Blizzard's paper doll for weapons
-- (PaperDollFrameStats.lua), the game's skill lines for professions (Classic IDs, not each checked
-- on Forever: one the game doesn't know simply doesn't show).
local _, ns = ...
local P = {}
ns.Progress = P

P.PROFESSIONS = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356 } -- Alchemy ... Fishing
P.WEAPONS = { 43, 44, 45, 46, 54, 55, 136, 160, 162, 172, 173, 176, 226, 228, 229, 95 } -- swords ... Defense

-- a skill line: { name, rank, max } or nil (not answered, or you don't have it)
local function Line(id)
  local f = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
  if type(f) ~= "function" then return nil end
  local ok, info = pcall(f, id)
  if not (ok and type(info) == "table") then return nil end
  local rank, max, name = info.rank, info.maxRank, info.name
  if not (ns.Readable(rank) and type(rank) == "number" and rank > 0 and ns.Readable(name) and type(name) == "string") then return nil end
  local mod = ns.Readable(info.modifier) and type(info.modifier) == "number" and info.modifier or 0
  return { name = name, rank = rank, mod = mod, max = ns.Readable(max) and type(max) == "number" and max or nil }
end

-- { professions = { line... }, weapons = { line... } }, each sorted by name
function P.Skills()
  local out = { professions = {}, weapons = {} }
  for key, ids in pairs({ professions = P.PROFESSIONS, weapons = P.WEAPONS }) do
    for _, id in ipairs(ids) do
      local l = Line(id)
      if l then out[key][#out[key] + 1] = l end
    end
    table.sort(out[key], function(a, b) return a.name < b.name end)
  end
  return out
end

-- a weapon skill below the most your level allows (5 a level): how far, else nil. Pure.
function P.WeaponGap(line, level)
  local cap = (level or 0) * 5
  if line.rank < cap then return cap - line.rank end
end

-- the history's totals: sessions, time, XP, quests, gold, levels, and XP an hour; pure
function P.Totals(history)
  local t = { sessions = #history, dur = 0, xp = 0, quests = 0, gold = 0, levels = 0 }
  for _, h in ipairs(history) do
    t.dur, t.xp, t.quests, t.gold = t.dur + (h.dur or 0), t.xp + (h.xp or 0), t.quests + (h.quests or 0), t.gold + (h.gold or 0)
    if h.from and h.to and h.to > h.from then t.levels = t.levels + (h.to - h.from) end
  end
  t.xph = t.dur >= 60 and t.xp / t.dur * 3600 or nil
  return t
end

-- /hab progress
function P.Report()
  local S = ns.Session
  local L = {}
  local level, xp, max = UnitLevel("player"), UnitXP("player") or 0, UnitXPMax("player") or 0
  local rested = GetXPExhaustion and GetXPExhaustion()
  L[#L + 1] = format("level %d%s%s", level, max > 0 and format(", %d%% of the way to %d", math.floor(xp / max * 100), level + 1) or "",
    (type(rested) == "number" and rested > 0) and (", rested " .. S.Short(rested)) or "")
  local v = S.Values()
  L[#L + 1] = format("this session (%s): %s, %s, gold gained %s", v.elapsed, v.xp or "max level", v.quests or "", v.gold)
  local h = S.History()
  if #h > 0 then
    local t = P.Totals(h)
    L[#L + 1] = format("last %d session%s: %s, %s XP%s, %d quests, %d level%s, gold gained %s", t.sessions, t.sessions == 1 and "" or "s",
      S.Duration(t.dur), S.Short(t.xp), t.xph and (" (" .. S.Short(t.xph) .. "/h)") or "", t.quests, t.levels, t.levels == 1 and "" or "s", S.Money(t.gold))
    for i = 1, math.min(3, #h) do
      local s = h[i]
      L[#L + 1] = format("  %s: %s, %s%s XP, %d quests%s", s.at and s.at > 0 and date("%d %b %H:%M", s.at) or "?", S.Duration(s.dur),
        s.approx and "~" or "", S.Short(s.xp), s.quests, (s.from and s.to and s.to > s.from) and format(", level %d to %d", s.from, s.to) or "")
    end
  else
    L[#L + 1] = "no past sessions yet (they're kept from your next login, or when you reset the session)."
  end
  local sk = P.Skills()
  local parts = {}
  for _, l in ipairs(sk.professions) do parts[#parts + 1] = format("%s %d/%s", l.name, l.rank, l.max or "?") end
  L[#L + 1] = "professions: " .. (#parts > 0 and table.concat(parts, ", ") or "none the game reports")
  parts = {}
  for _, l in ipairs(sk.weapons) do
    local gap = P.WeaponGap(l, level)
    parts[#parts + 1] = format("%s %d%s%s", l.name, l.rank, l.mod ~= 0 and format("%+d", l.mod) or "", gap and format(" (%d to go)", gap) or "")
  end
  L[#L + 1] = "weapon skills: " .. (#parts > 0 and table.concat(parts, ", ") or "none the game reports")
  return L
end
