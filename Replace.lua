-- Optional: replace Blizzard's quest tracker with XP Planner.
--
-- Blizzard's tracker can hold secure quest-item buttons, so the game won't let addons hide it
-- during combat, and Blizzard re-shows it on quest updates (including mid-fight). So instead of
-- hiding it, we move it (outside combat) into an invisible container: Blizzard can call Show() as
-- often as it likes, it stays invisible because its parent is hidden. As a backup, if it does
-- appear during combat it's made fully transparent. Turning the option off moves it back.
local _, ns = ...

local hider = CreateFrame("Frame", nil, UIParent)
hider:Hide()

local function Trackers()
  local list = {}
  for _, name in ipairs({ "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
    local f = _G[name]
    if f and f.SetParent then list[#list + 1] = f end
  end
  return list
end
ns.BlizzardTracker = function() return Trackers()[1] end

local pending = false
local hooked = {}
local originalParent = {}

local function Apply()
  if InCombatLockdown() then pending = true; return end
  pending = false
  for _, f in ipairs(Trackers()) do
    if not hooked[f] then
      hooked[f] = true
      originalParent[f] = f:GetParent() or UIParent
      -- backup: if it ever shows while replacing (e.g. mid-combat), keep it invisible
      f:HookScript("OnShow", function(self)
        if ns.db and ns.db.replaceTracker then
          self:SetAlpha(0)
          if InCombatLockdown() then pending = true end
        end
      end)
    end
    if ns.db.replaceTracker then
      if f:GetParent() ~= hider then pcall(f.SetParent, f, hider) end
      f:SetAlpha(0)
    else
      if f:GetParent() == hider then pcall(f.SetParent, f, originalParent[f] or UIParent) end
      f:SetAlpha(1)
    end
  end
end
ns.ApplyReplace = function() Apply(); ns.PlaceFrame() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and not pending then return end
  if ns.db then Apply() end
end)
