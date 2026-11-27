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

local pending = false
local hooked = {}
-- each tracker as it was before Hereabouts took its place (1.9.0: its alpha too; before, turning
-- replacing off set it to fully shown, whatever it had)
local originalParent, originalAlpha = {}, {}

-- FlareUI's and EllesmereUI's own trackers, through their own switches: FlareUI's tracker module
-- (FlareUI.ObjectiveTracker:SetNever, what its Visibility "Never" uses) and EllesmereUI's cross-addon
-- suppression (_EQT_SetSuppressed, which covers its custom Forever tracker too).
local flareNever, flareHooked = false, false
local function FlareTracker()
  local OT = type(FlareUI) == "table" and FlareUI.ObjectiveTracker
  if type(OT) == "table" and OT.SetNever then return OT end
end
function ns.FlareTrackerOn()
  local p = type(FlareUI) == "table" and FlareUI.db and FlareUI.db.profile
  return FlareTracker() ~= nil and p and p.objectivetracker and p.objectivetracker.enabled and true or false
end
-- EllesmereUI's tracker: true (on), false (off or not there), or nil: there, but its setting can't
-- be read (1.9.0: before, that counted as on, and could switch replacing on by itself)
function ns.EUITrackerOn()
  local EQT = _G.EllesmereUIQuestTracker
  if type(EQT) ~= "table" or not _G._EQT_SetSuppressed then return false end
  local ok, on = pcall(function() return type(EQT.Cfg) == "function" and EQT.Cfg("enabled") end)
  if ok and type(on) == "boolean" then return on end
  return nil
end
local function OtherTrackers(replace)
  local OT = FlareTracker()
  if OT then
    if not flareHooked then
      flareHooked = true
      -- FlareUI's visibility settings can show it again: while we replace it, it stays hidden
      hooksecurefunc(OT, "SetNever", function(self, on)
        if ns.db and ns.db.replaceTracker and not on then self:SetNever(true) end
      end)
    end
    if replace then OT:SetNever(true); flareNever = true
    elseif flareNever then flareNever = false; OT:SetNever(false) end
  end
  if _G._EQT_SetSuppressed then pcall(_G._EQT_SetSuppressed, "Hereabouts", replace and true or false) end
end

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
      if f:GetParent() ~= hider then
        if originalAlpha[f] == nil then originalAlpha[f] = f:GetAlpha() end
        pcall(f.SetParent, f, hider)
      end
      f:SetAlpha(0)
    elseif f:GetParent() == hider then
      pcall(f.SetParent, f, originalParent[f] or UIParent)
      f:SetAlpha(originalAlpha[f] or 1)
      originalAlpha[f] = nil
    end
  end
  OtherTrackers(ns.db.replaceTracker)
end
ns.ApplyReplace = function() Apply(); ns.PlaceFrame() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and not pending then return end
  if not ns.db then return end
  if event == "PLAYER_ENTERING_WORLD" and not ns.db.trackerOffered then
    -- FlareUI's or EllesmereUI's quest tracker in use: Hereabouts takes its place (once; the
    -- player can turn it back in /hab)
    -- (only when their setting says so: an EllesmereUI setting that can't be read doesn't count)
    if ns.FlareTrackerOn() or ns.EUITrackerOn() == true then
      ns.db.trackerOffered = true
      if not ns.db.replaceTracker then
        ns.db.replaceTracker = true
        ns.Print(format("replacing %s's quest tracker. /hab to change.", ns.FlareTrackerOn() and "FlareUI" or "EllesmereUI"))
      end
    end
  end
  Apply()
  -- (FlareUI and EllesmereUI set up their trackers around login: once more a moment later)
  if event == "PLAYER_ENTERING_WORLD" then C_Timer.After(2, function() if ns.db then Apply() end end) end
end)
