-- Spells you can train, read from your installed What's Training (its public WT_API).
-- Uses What's Training's own categories, costs (with faction discounts) and ignore list,
-- so this section always agrees with What's Training's window.
local _, ns = ...
local T = {}
ns.Training = T

local registered = false

function T.Installed() return WT_API ~= nil end
function T.Ready() return WT_API ~= nil and WT_API.IsReady and WT_API.IsReady() end

-- Spells for the section: available now first (cheapest level first), then next level.
-- Each: { id, name, rank, level, cost, link, nextLevel }
function T.List(limit, includeNext)
  local out, avail, nextLvl = {}, {}, {}
  if not T.Ready() then return out, 0, 0 end
  local S = WT_API.Status
  local ok, spells = pcall(WT_API.GetSpells)
  if not ok or type(spells) ~= "table" then return out, 0, 0 end
  for _, s in ipairs(spells) do
    local entry = { id = s.id, name = s.name, rank = s.subText, level = s.level, cost = s.cost or 0, link = s.link }
    if s.status == S.AVAILABLE or s.status == S.WEAPON_AVAILABLE then
      avail[#avail + 1] = entry
    elseif includeNext and (s.status == S.NEXTLEVEL or s.status == S.WEAPON_NEXTLEVEL) then
      entry.nextLevel = true
      nextLvl[#nextLvl + 1] = entry
    end
  end
  local desc = ns.db.sortByLevel
  local function byLevel(a, b)
    if (a.level or 0) ~= (b.level or 0) then
      if desc then return (a.level or 0) > (b.level or 0) end -- highest level first
      return (a.level or 0) < (b.level or 0)
    end
    return (a.name or "") < (b.name or "")
  end
  table.sort(avail, byLevel); table.sort(nextLvl, byLevel)

  local total = 0
  for _, e in ipairs(avail) do total = total + e.cost end
  for _, e in ipairs(avail) do if #out < limit then out[#out + 1] = e end end
  for _, e in ipairs(nextLvl) do if #out < limit then out[#out + 1] = e end end
  return out, #avail, total
end

function T.Init()
  if registered or not (WT_API and WT_API.RegisterCallback) then return false end
  registered = true
  local E = WT_API.Event
  for _, ev in ipairs({ E.READY, E.SPELLS_CHANGED, E.LEVEL_CHANGED, E.IGNORED_CHANGED }) do
    if ev then pcall(WT_API.RegisterCallback, "XPPlanner", ev, function() ns.Refresh() end) end
  end
  return true
end
