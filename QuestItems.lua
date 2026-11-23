-- Quest item buttons: a small button left of a quest's [level] in the list, for the usable item
-- of that quest (click to use it). They're Blizzard's secure item buttons, which the game only lets
-- addons set up, move or hide out of combat: so they're placed by screen position (NOT anchored to
-- the rows: anchoring secure buttons would lock the tracker's rows in combat), placed again after
-- every redraw and scroll out of combat, and in combat they stay where they are until it ends.
-- Combat focus only highlights quests (nothing moves), so they stay beside their quests in a fight.
local _, ns = ...
local Q = {}
ns.QuestItems = Q

-- The button sits in a column of its own just left of the [level]: when any quest in the list has an
-- item, every quest row moves right by Q.INDENT (the tracker does it), so titles stay aligned.
local MAX, SIZE, GAP = 12, 14, 3
Q.INDENT = SIZE + GAP + 1
local buttons = {}
Q.buttons = buttons
local pending -- the list to show once combat ends

-- keybinding labels (Key Bindings > AddOns > Hereabouts): the first three buttons, top to bottom
_G.BINDING_HEADER_XPPLANNER = "Hereabouts"
_G["BINDING_NAME_CLICK XPPlannerQuestItem1:LeftButton"] = "Use quest item"
_G["BINDING_NAME_CLICK XPPlannerQuestItem2:LeftButton"] = "Use second quest item"
_G["BINDING_NAME_CLICK XPPlannerQuestItem3:LeftButton"] = "Use third quest item"

local function Count(itemID)
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, itemID)
    if ok then return n end
  end
  return GetItemCount and GetItemCount(itemID) or 0
end

local function MakeButton(i)
  local b = CreateFrame("Button", "XPPlannerQuestItem" .. i, UIParent, "SecureActionButtonTemplate, BackdropTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "item")
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropColor(0, 0, 0, 0.6)
  b:SetBackdropBorderColor(0, 0, 0, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", 2, -2)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
    if self.quest then GameTooltip:AddLine("For: " .. self.quest, 0.6, 0.8, 1) end
    local key = GetBindingKey and GetBindingKey("CLICK " .. self:GetName() .. ":LeftButton")
    if key then GameTooltip:AddLine("Key: " .. (GetBindingText and GetBindingText(key, true) or key), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function Paint(b)
  if not b.itemID then return end
  local n = Count(b.itemID)
  b.count:SetText((n and n > 1) and n or "")
  b.icon:SetDesaturated(not n or n == 0)
  if C_Container and C_Container.GetItemCooldown then
    local ok, s, d = pcall(C_Container.GetItemCooldown, b.itemID)
    if ok and type(s) == "number" and type(d) == "number" then b.cd:SetCooldown(s, d) end
  end
end

-- where a row's left edge and middle are on screen, in UIParent's units; nil if the row is scrolled
-- out of the list's visible area
local function Spot(row)
  if not (row and row:IsVisible()) then return nil end
  local left, top, bottom = row:GetLeft(), row:GetTop(), row:GetBottom()
  if not (left and top and bottom) then return nil end
  local vTop, vBottom = ns.TrackerView and ns.TrackerView()
  local mid = (top + bottom) / 2
  if vTop and vBottom and (mid > vTop or mid < vBottom) then return nil end
  local k = row:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return left * k, mid * k, k
end

local function Apply(list)
  local strata = ns.TrackerFrame and ns.TrackerFrame:GetFrameStrata() or "MEDIUM"
  local level = (ns.TrackerFrame and ns.TrackerFrame:GetFrameLevel() or 5) + 20

  for i = 1, MAX do
    local it = list[i]
    local b = buttons[i]
    local x, y, k
    if it then x, y, k = Spot(it.row) end
    if x and not b then b = MakeButton(i); buttons[i] = b end
    if b then
      if x then
        b.itemID, b.quest = it.itemID, it.title
        b:SetAttribute("item", "item:" .. it.itemID)
        b.icon:SetTexture(it.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.itemID)))
        b:SetFrameStrata(strata); b:SetFrameLevel(level)
        b:SetScale(math.max(0.5, k or 1)) -- (the list's scale)
        b:ClearAllPoints()
        b:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", (x - GAP) / b:GetScale(), y / b:GetScale())
        b:Show()
        Paint(b)

      else
        b.itemID, b.quest = nil, nil
        b:SetAttribute("item", nil)
        b:Hide()
      end
    end
  end
end

-- list: { { itemID, icon, title, row }, ... } in list order, or {} to hide them
function Q.Update(list)
  list = (ns.db and ns.db.showQuestItems and not ns.db.hidden) and (list or {}) or {}
  if InCombatLockdown and InCombatLockdown() then pending = list; return end
  pending = nil
  Apply(list)
end

-- counts and cooldowns can change any time (not protected); the buttons themselves wait for combat to end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and pending then
    local l = pending; pending = nil; Apply(l)
  end
  for _, b in ipairs(buttons) do if b:IsShown() then Paint(b) end end
end)
