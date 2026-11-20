-- Quest Item Button: one-click buttons for the usable items of your quests in this zone
-- (your focused quest's item first). They're Blizzard's secure item buttons, which can only be
-- set up or changed out of combat: changes during combat wait for it to end.
local _, ns = ...
local Q = {}
ns.QuestItems = Q

local MAX, SIZE, GAP = 3, 36, 6
local buttons, holder = {}, nil
Q.buttons = buttons
local pending -- the list to show once combat ends

-- keybinding labels (Key Bindings > AddOns > XP Planner)
_G.BINDING_HEADER_XPPLANNER = "XP Planner"
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
  local b = CreateFrame("Button", "XPPlannerQuestItem" .. i, holder, "SecureActionButtonTemplate, BackdropTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "item")
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropColor(0, 0, 0, 0.6)
  b:SetBackdropBorderColor(0.65, 0.49, 0.27, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b.hotkey = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
  b.hotkey:SetPoint("TOPRIGHT", -2, -2)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
    if self.quest then GameTooltip:AddLine("For: " .. self.quest, 0.6, 0.8, 1) end
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
    local ok, s, d, e = pcall(C_Container.GetItemCooldown, b.itemID)
    if ok and type(s) == "number" and type(d) == "number" then b.cd:SetCooldown(s, d) end
  end
  local key = GetBindingKey and GetBindingKey("CLICK " .. b:GetName() .. ":LeftButton")
  b.hotkey:SetText(key and (GetBindingText and GetBindingText(key, true) or key) or "")
end

local function Apply(list)
  if not holder then
    holder = CreateFrame("Frame", "XPPlannerQuestItems", UIParent)
    holder:SetSize(SIZE, SIZE)
  end
  holder:ClearAllPoints()
  -- beside the tracker, on its left, at the top
  holder:SetPoint("TOPRIGHT", ns.TrackerBox or ns.TrackerFrame or UIParent, "TOPLEFT", -6, 0)
  for i = 1, MAX do
    local it = list[i]
    local b = buttons[i]
    if it and not b then b = MakeButton(i); buttons[i] = b end
    if b then
      if it then
        b.itemID, b.quest = it.itemID, it.title
        b:SetAttribute("item", "item:" .. it.itemID)
        b.icon:SetTexture(it.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.itemID)))
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(i - 1) * (SIZE + GAP))
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

-- list: { { itemID, icon, title }, ... } (focused quest's first), or {} to hide them
function Q.Update(list)
  list = (ns.db and ns.db.showQuestItems and not ns.db.hidden) and (list or {}) or {}
  if InCombatLockdown and InCombatLockdown() then pending = list; return end
  pending = nil
  Apply(list)
end

-- counts and cooldowns can change any time (not protected); the buttons themselves wait for combat to end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "UPDATE_BINDINGS" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and pending then
    local l = pending; pending = nil; Apply(l)
  end
  for _, b in ipairs(buttons) do if b:IsShown() then Paint(b) end end
end)
