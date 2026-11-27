-- Every add-on Hereabouts works with, in one place (1.9.0): its state and what it gives, for the
-- settings window's "Connected addons" and /hab status. Each one is outside code: Hereabouts asks
-- each part it uses whether it's there (QuestieSource.lua, Training.lua, Replace.lua) and does
-- without the parts that aren't.
local _, ns = ...

local function Loaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) and true or false end
  return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
end
-- the parts missing from a capability list, as words ("its map markers, quest XP"), or nil
local function Missing(caps)
  local out = {}
  for _, c in ipairs(caps) do if not c[2] then out[#out + 1] = c[1] end end
  return #out > 0 and table.concat(out, ", ") or nil
end

-- { { name, state, text } }: state "on" (working), "partial" (working without some parts),
-- "loading", "off" (not installed)
function ns.Integrations()
  local L = {}
  local function add(name, state, text) L[#L + 1] = { name, state, text } end

  local q = ns.Questie
  if not q.Installed() then add("Questie", "off", "Not installed: no Quests Nearby section (active quests and turn-ins still work).")
  elseif not q.Available() then add("Questie", "loading", "Loading...")
  elseif q.IsScanning() then add("Questie", "loading", "Scanning quests...")
  else
    local miss = Missing(q.Capabilities())
    add("Questie", miss and "partial" or "on", format("Connected: %d quests you can pick up.", q.Count())
      .. (miss and (" Missing: " .. miss .. ".") or ""))
  end

  local t = ns.Training
  if not t.Installed() then add("What's Training", "off", "Not installed: no Training section.")
  elseif not t.Ready() then add("What's Training", "loading", "Loading...")
  else
    local miss = Missing(t.Capabilities())
    add("What's Training", miss and "partial" or "on", "Connected." .. (miss and (" Missing: " .. miss .. ".") or ""))
  end

  if ns.FlareBorder() then
    add("FlareUI", "on", (ns.UsingFlare() and "Connected: its style is used." or "Installed: EllesmereUI's style is used.")
      .. (ns.FlareTrackerOn() and " Its tracker is on." or ""))
  else add("FlareUI", "off", "Not installed: the plain style is used.") end

  if ns.UsingEUI() then
    local tr = ns.EUITrackerOn()
    add("EllesmereUI", tr == nil and "partial" or "on", "Connected: its style is used."
      .. ((tr == true and " Its tracker is on.") or (tr == nil and " Its tracker setting can't be read.") or ""))
  else add("EllesmereUI", "off", "Not installed.") end

  if type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function" then
    add("TomTom", "on", "Connected: Show on Map also sets its arrow (one at a time).")
  elseif Loaded("TomTom") then add("TomTom", "partial", "Installed, but its waypoints can't be set: Show on Map uses the game's map pin.")
  else add("TomTom", "off", "Not installed: Show on Map uses the game's map pin.") end
  return L
end
