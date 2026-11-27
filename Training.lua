-- Spells you can train, read from your installed What's Training (its public WT_API).
-- Uses What's Training's own categories, costs (with faction discounts) and ignore list,
-- so this section always agrees with What's Training's window.
local _, ns = ...
local T = {}
ns.Training = T

local registered = false

-- What's Training's public API, checked part by part (1.9.0): a part that's missing or changed
-- empties only what it's for (the Training section, city prices), never the rest of the list.
local function Fn(k) return type(WT_API) == "table" and type(WT_API[k]) == "function" end
function T.Installed() return type(WT_API) == "table" end
function T.Ready()
  if not Fn("IsReady") then return false end
  local ok, r = pcall(WT_API.IsReady)
  return ok and r and true or false
end
-- { name, available, what it's for }
function T.Capabilities()
  return {
    { "spells", Fn("GetSpells") and type(WT_API.Status) == "table", "the Training section" },
    { "trainers", Fn("GetSource"), "weapon masters' cities" },
    { "pet abilities", Fn("GetCatalog"), "pet trainer prices" },
    { "updates", Fn("RegisterCallback") and type(WT_API.Event) == "table", "the section following What's Training" },
  }
end

-- Spells for the section: available now first (cheapest level first), then next level.
-- Each: { id, name, rank, level, cost, link, nextLevel }
function T.List(limit, includeNext)
  local out, avail, nextLvl = {}, {}, {}
  if not T.Ready() then return out, 0, 0 end
  local S = WT_API.Status
  if type(S) ~= "table" or not Fn("GetSpells") then return out, 0, 0 end
  local ok, spells = pcall(WT_API.GetSpells)
  if not ok or type(spells) ~= "table" then return out, 0, 0 end
  for _, s in ipairs(spells) do
    local entry = { id = s.id, name = s.name, rank = s.subText, level = s.level, cost = s.cost or 0, link = s.link,
      baseCost = s.baseCost or s.cost or 0, isItem = s.isItem, quest = s.quest }
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

---------------------------------------------------------------------------
-- Price by city. What's Training's public API gives one chosen price, so the per-city
-- rows are worked out here the way What's Training does on Forever: each capital city that
-- trains your class charges 10% less once you're Honored (or better) with it.
-- City lists from What's Training's Forever data (MIT license, github.com/fusionpit/WhatsTraining).
---------------------------------------------------------------------------
local CITIES = {
  -- [factionID] = name if the game can't tell us
  [47] = "Ironforge", [54] = "Gnomeregan", [69] = "Darnassus", [72] = "Stormwind",
  [68] = "Undercity", [76] = "Orgrimmar", [81] = "Thunder Bluff", [530] = "Darkspear Trolls",
}
local ROLES = {
  DRUID   = { Alliance = { 69, 72 },          Horde = { 81 } },
  HUNTER  = { Alliance = { 47, 69, 72 },      Horde = { 76, 81, 530 } },
  MAGE    = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 530 } },
  PALADIN = { Alliance = { 47, 72 },          Horde = { 68 } },
  PET     = { Alliance = { 47, 69, 72 },      Horde = { 76, 81 } },
  PRIEST  = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 530 } },
  ROGUE   = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 81, 530 } },
  SHAMAN  = { Alliance = { 47 },              Horde = { 76, 81 } },
  WARLOCK = { Alliance = { 47, 54, 72 },      Horde = { 68, 76 } },
  WARRIOR = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 81 } },
}
-- weapon masters -> their city
local WEAPON_NPCS = { [2704] = 530, [11865] = 47, [11866] = 69, [11867] = 72, [11868] = 76, [11869] = 81, [11870] = 68, [13084] = 47 }

local petIds -- spell id -> true for hunter pet abilities (from What's Training's catalog)
local function IsPetAbility(id)
  if petIds == nil then
    petIds = false
    if Fn("GetCatalog") then
      local _, token = UnitClass("player")
      local ok, cat = pcall(WT_API.GetCatalog, token)
      if ok and type(cat) == "table" and #cat > 0 then
        petIds = {}
        for _, e in ipairs(cat) do if e.petAbility then petIds[e.id] = true end end
      else
        petIds = nil -- not loaded yet: try again next time
      end
    end
  end
  return petIds and petIds[id] or false
end

local function CityRow(key)
  local name, standing
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, key)
    if ok and d then name, standing = d.name, d.reaction end
  elseif GetFactionInfoByID then
    local n, _, st = GetFactionInfoByID(key); name, standing = n, st
  end
  return { name = (name and name ~= "") and name or CITIES[key] or ("Faction " .. key), pct = (standing or 4) >= 6 and 10 or 0 }
end

-- Cities that train this spell for you, as { name, price, best }, cheapest first. Empty when the
-- price is the same everywhere (quests, tomes) or What's Training's data doesn't cover it.
function T.CityPrices(e)
  local base = e.baseCost or e.cost or 0
  if base <= 0 or e.quest or e.isItem then return {}, base end
  local keys
  local faction = UnitFactionGroup("player")
  if Fn("GetSource") and type(e.id) == "number" then
    local ok, src = pcall(WT_API.GetSource, e.id)
    if ok and type(src) == "table" and src.kind == "weaponMaster" then
      keys = {}
      for _, t in ipairs(src.trainers or {}) do
        local k = WEAPON_NPCS[t.npc]
        if k then keys[#keys + 1] = k end
      end
    end
  end
  if not keys then
    local _, token = UnitClass("player")
    local role = ROLES[IsPetAbility(e.id) and "PET" or token]
    keys = role and role[faction] or {}
  end
  local rows, seen = {}, {}
  for _, k in ipairs(keys) do
    if not seen[k] then
      seen[k] = true
      local r = CityRow(k)
      r.price = math.floor((base * (100 - r.pct) + 50) / 100)
      rows[#rows + 1] = r
    end
  end
  table.sort(rows, function(a, b)
    if a.price ~= b.price then return a.price < b.price end
    return a.name < b.name
  end)
  if rows[1] and rows[1].price < base then
    for _, r in ipairs(rows) do r.best = r.price == rows[1].price end
  end
  return rows, base
end

function T.Init()
  if registered or not (Fn("RegisterCallback") and type(WT_API.Event) == "table") then return false end
  registered = true
  local E = WT_API.Event
  for _, ev in ipairs({ E.READY, E.SPELLS_CHANGED, E.LEVEL_CHANGED, E.IGNORED_CHANGED }) do
    if ev then pcall(WT_API.RegisterCallback, "XPPlanner", ev, function() ns.Refresh() end) end
  end
  return true
end
