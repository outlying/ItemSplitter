local addonName, ns = ...

-- WoW functions alliases

local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local SplitContainerItem = C_Container and C_Container.SplitContainerItem or SplitContainerItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

-- Addon variables

local f = CreateFrame("Frame") -- Main event frame

local BAG_BACKPACK = (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) or BACKPACK_CONTAINER or 0
local BAG_REAGENT = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or _G.REAGENTBAG_CONTAINER
local BAG_BANK = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
local BAG_REAGENT_BANK = (Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank) or _G.REAGENTBANK_CONTAINER
local NUM_PERSONAL_BAGS = NUM_BAG_SLOTS or 4
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 7

local function BuildPersonalBags()
    local bags = {}
    if BAG_BACKPACK ~= nil then
        table.insert(bags, BAG_BACKPACK)
    end
    for i = 1, NUM_PERSONAL_BAGS do
        table.insert(bags, i)
    end
    return bags
end

local function BuildBankBags()
    local bags = {}
    if BAG_BANK ~= nil then
        table.insert(bags, BAG_BANK)
    end
    for i = 1, NUM_BANK_BAGS do
        table.insert(bags, NUM_PERSONAL_BAGS + i)
    end
    return bags
end

local function BuildSingleBag(bagIndex)
    if bagIndex ~= nil then
        return { bagIndex }
    end
    return {}
end

local function BuildWarbandBank()
    if Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 then
        return {
            Enum.BagIndex.AccountBankTab_1,
            Enum.BagIndex.AccountBankTab_2,
            Enum.BagIndex.AccountBankTab_3,
            Enum.BagIndex.AccountBankTab_4,
            Enum.BagIndex.AccountBankTab_5,
        }
    end
    return {}
end

local ContainerScope = {}
ContainerScope.PERSONAL = BuildPersonalBags()
ContainerScope.PERSONAL_REGENTS = BuildSingleBag(BAG_REAGENT)
ContainerScope.PERSONAL_WITH_REGENTS = ns.mergeTables(ContainerScope.PERSONAL_REGENTS, ContainerScope.PERSONAL)
ContainerScope.BANK = BuildBankBags()
ContainerScope.BANK_REGENTS_WITH_BANK = ns.mergeTables(BuildSingleBag(BAG_REAGENT_BANK), ContainerScope.BANK)
ContainerScope.WARBAND_BANK = BuildWarbandBank()

local dialog = nil

--[[
    Hide, unparent and dereference current instance of dialog
]]

local function ClearDialog()
    if dialog then -- Remove old dialog, we start fresh
        dialog:Hide()
        dialog:SetParent(nil)
    end
    dialog = nil
end

local function DisableDialog()
    if dialog then
        dialog.autoSplitButton:Disable()
        dialog.splitButton:Disable()
        dialog.editBox:Disable()
        dialog.decrementButton:Disable()
        dialog.incrementButton:Disable()
    end
end

--[[
    Get item information
]]
local function CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)
    if isGuildBank then
        local texture, itemCount, locked, isFiltered, quality = GetGuildBankItemInfo(sourceBagIndex, sourceSlotIndex)
        if not texture then
            return nil
        end
        local itemInfo = {} -- We try to replcate of a return structure of GetContainerItemInfo
        itemInfo.stackCount = itemCount
        itemInfo.isLocked = locked
        return itemInfo
    else
        local texture, itemCount, locked = GetContainerItemInfo(sourceBagIndex, sourceSlotIndex)
        if type(texture) == "table" then
            return texture
        end
        if not texture then
            return nil
        end
        return {
            stackCount = itemCount,
            isLocked = locked
        }
    end
end

--[[
    Finds an empty slot in the player's bags.

    Iterates through all the bags (from bag 0 to bag 4) and their slots to find the first empty slot.

    @return bag (number) - The index of the bag containing the empty slot, or nil if no empty slot is found.
    @return slot (number) - The index of the empty slot within the bag, or nil if no empty slot is found. 

    TODO since we look for slipts in diffetent types of spaces that are not available everywhere we need
    a second argument to be replaced with something better
]]

local function FindEmptySlot(exclude, isGuildBank, sourceBagIndex, sourceSlotIndex, forceBankScope)

    local function isExcluded(bag, slot)
        for _, pair in ipairs(exclude) do
            if pair[1] == bag and pair[2] == slot then
                return true
            end
        end
        return false
    end

    local bags = ContainerScope.PERSONAL

    if BAG_REAGENT and sourceBagIndex == BAG_REAGENT then
        bags = ContainerScope.PERSONAL_WITH_REGENTS
    end

    if BAG_REAGENT_BANK and sourceBagIndex == BAG_REAGENT_BANK then
        bags = ContainerScope.BANK_REGENTS_WITH_BANK
    end
        
    if ns.containsValue(ContainerScope.BANK, sourceBagIndex) then
        bags = ContainerScope.BANK
    end

    if ns.containsValue(ContainerScope.WARBAND_BANK, sourceBagIndex) then
        bags = { sourceBagIndex }
    end

    if isGuildBank then
        bags = { sourceBagIndex }
    end

    if forceBankScope then
        if ns.containsValue(ContainerScope.BANK, sourceBagIndex) or sourceBagIndex == BAG_REAGENT_BANK then
            bags = ContainerScope.BANK
        else
            bags = { sourceBagIndex }
        end
    end

    for _, bag in ipairs(bags) do
        local maxSlots = nil
        local startSlot = 1
        
        if isGuildBank then
            startSlot = sourceSlotIndex + 1
            maxSlots = 98
        elseif BAG_REAGENT_BANK and bag == BAG_REAGENT_BANK then
            maxSlots = 98
        elseif bag == BAG_BANK then
            maxSlots = 28
        else
            maxSlots = GetContainerNumSlots(bag)
        end

        for slot = startSlot, maxSlots do
            -- Check if the current bag-slot pair is excluded
            if not isExcluded(bag, slot) then
                local itemInfo = CollectItemInfo(isGuildBank, bag, slot)
                if not itemInfo then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

--[[
    This function takes stack of items and creates small stack automatically, new stack will land in
    the first free spot in same container group

    @return done (bool) - true if all is split, false in case of potential more items to split
]]

local function AutomaticSplit(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize, forceBankScope)
    ns.Log.debug("Splitting " .. ns.location_string(isGuildBank, sourceBagIndex, sourceSlotIndex))
    local itemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)

    if not itemInfo then
        ns.Log.debug("Unable to get item info for given input")
        return
    end

    local currentStackSize = itemInfo.stackCount
    ClearCursor() -- Drop any items held by cursor
    local excluded = {} -- We are keeping local exclude list to not duplicate destination locations

    while currentStackSize > targetStacksSize do

        for attempt = 1, ns.Constant.MAX_SAFE_LOOP do
            local sourceItemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)
            
            if sourceItemInfo and not sourceItemInfo.isLocked then
                break
            end
            
            coroutine.yield()
        
            if attempt == ns.Constant.MAX_SAFE_LOOP then
                ns.Log.error("Waiting for non-nil and non-locked source item failed")
                return
            end
        end

        local destBag, destSlot = FindEmptySlot(excluded, isGuildBank, sourceBagIndex, sourceSlotIndex, forceBankScope)

        if destBag and destSlot then
            table.insert(excluded, {destBag, destSlot})
            ns.Log.debug("Moving " .. targetStacksSize .. " items, from " .. ns.location_string(isGuildBank, sourceBagIndex, sourceSlotIndex) .. " to " .. ns.location_string(isGuildBank, destBag, destSlot))

            -- This is special guild bank handling
            if isGuildBank then
                SplitGuildBankItem(sourceBagIndex, sourceSlotIndex, targetStacksSize)
                PickupGuildBankItem(destBag, destSlot)

            -- Other bags / banks handling
            else
                SplitContainerItem(sourceBagIndex, sourceSlotIndex, targetStacksSize)
                PickupContainerItem(destBag, destSlot)
            end

            -- Wait on an actual change
            local expectedStackSize = currentStackSize - targetStacksSize
            for attempt = 1, ns.Constant.MAX_SAFE_LOOP do
                local inprogressItemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)

                if inprogressItemInfo and inprogressItemInfo.stackCount == expectedStackSize then
                    currentStackSize = expectedStackSize
                    ns.Log.debug("Current stack size: " .. currentStackSize)
                    break
                end
                coroutine.yield()

                if attempt >= ns.Constant.MAX_SAFE_LOOP then
                    ns.Log.error("Waiting for source item (" .. ns.location_string(isGuildBank, sourceBagIndex, sourceSlotIndex) .. ") stack change failed")
                    return
                end
            end
        else
            ns.Log.warn("No more empty slots found for automatic split")
            break
        end
    end
end

--[[
    We start automatic splitting of stack
]]

local coroutineAutomaticSplit = nil

local function StartAutomaticSplitSession(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize, forceBankScope)
    coroutineAutomaticSplit = coroutine.create(function ()
        AutomaticSplit(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize, forceBankScope)
        ClearDialog()
    end)
end

--[[
    Detector function to figure out clicked bag-slot combination based on parent UI element
    
    The guild bank is a bit tricky since tabs IDs are overlapping with usual bag numeration
    so tab 1 in bank is 1, the same as bag 1 player is carrying.
]]

local function SourceLocation(parent)
    local parentName = parent and parent.GetName and parent:GetName() or nil
    local parentParent = parent and parent.GetParent and parent:GetParent() or nil
    local parentParentName = parentParent and parentParent.GetName and parentParent:GetName() or nil
    local parentParentParent = parentParent and parentParent.GetParent and parentParent:GetParent() or nil
    local parentParentParentName = parentParentParent and parentParentParent.GetName and parentParentParent:GetName() or nil

    local isGuildBank = false
    local bagIndex = parentParent and parentParent.GetID and parentParent:GetID() or nil
    local slotIndex = parent and parent.GetID and parent:GetID() or nil
    local forceBankScope = false
    local hasItemLocation = false

    local locationBagIndex, locationSlotIndex = nil, nil
    if parent and parent.GetItemLocation and parent:GetItemLocation() and parent:GetItemLocation().GetBagAndSlot and parent:GetItemLocation():GetBagAndSlot() then
        locationBagIndex, locationSlotIndex = parent:GetItemLocation():GetBagAndSlot()
        hasItemLocation = locationBagIndex ~= nil and locationSlotIndex ~= nil
    end

    ns.printParentNames(parent)

    if GetCurrentGuildBankTab then
        ns.Log.debug("Current guild bank tab opened:", GetCurrentGuildBankTab())
    end

    -- This should work everywhere except guild bank as it's container numeration is not shared with other spaces
    if locationBagIndex and locationSlotIndex then
        ns.Log.debug("BI", locationBagIndex, "SI", locationSlotIndex, "GBankTab", GetCurrentGuildBankTab())
        bagIndex = locationBagIndex
        slotIndex = locationSlotIndex
    end

    -- Baganator guild bank --
    if ns.isParentNameInHierarchy(parent, "Baganator_SingleViewGuildViewFrameblizzard") then
        isGuildBank = true
        if GetCurrentGuildBankTab then
            bagIndex = GetCurrentGuildBankTab()
        end
    end

    -- Baganator personal bank
    if ns.isParentNameInHierarchy(parent, "Baganator_CategoryViewBankViewFrameblizzard") then
        forceBankScope = true
    end

    -- Bagnon guild bank
    if parentName and string.sub(parentName, 1, 15) == "BagnonGuildItem" and locationSlotIndex then
        isGuildBank = true
        if GetCurrentGuildBankTab then
            bagIndex = GetCurrentGuildBankTab()
        end
        slotIndex = locationSlotIndex
    end

    -- Blizzard Guild Bank Frame
    if parentParentParentName == "GuildBankFrame" then
        isGuildBank = true
        if GetCurrentGuildBankTab then
            bagIndex = GetCurrentGuildBankTab()
        end
    end

    -- Blizzard combined bags mode
    if parentParentName == "ContainerFrameCombinedBags" and parent.GetItemLocation and parent:GetItemLocation() and parent:GetItemLocation().GetBagAndSlot then
        bagIndex, slotIndex = parent:GetItemLocation():GetBagAndSlot()
    end

    -- Blizzard personal bank (ensure auto-split stays in bank slots)
    if BankFrame
        and BankFrame.IsVisible
        and BankFrame:IsVisible()
        and BankFrame.GetActiveBankType
        and Enum
        and Enum.BankType
        and BankFrame:GetActiveBankType() == Enum.BankType.Character
        and ns.isParentNameInHierarchy(parent, "BankFrame") then
        forceBankScope = true
        local bankBagId = parent.GetBagID and parent:GetBagID()
        local bankSlotId = parent.GetSlotID and parent:GetSlotID()
        if bankBagId and bankSlotId then
            bagIndex = bankBagId
            slotIndex = bankSlotId
        elseif locationBagIndex and locationSlotIndex then
            bagIndex = locationBagIndex
            slotIndex = locationSlotIndex
        else
            bagIndex = BAG_BANK
            slotIndex = parent:GetID()
        end
    end

    -- Blizzard Warband bank
    if BankFrame
        and BankFrame.IsVisible
        and BankFrame:IsVisible()
        and BankFrame.GetActiveBankType
        and Enum
        and Enum.BankType
        and BankFrame:GetActiveBankType() == Enum.BankType.Account then
        if parent.GetBankTabID and parent.GetContainerSlotID then
            bagIndex = parent:GetBankTabID()
            slotIndex = parent:GetContainerSlotID()
        end
    end

    return isGuildBank, bagIndex, slotIndex, forceBankScope, hasItemLocation
end

-- Overrides standard function for split dialog

local function OpenFrame(self, maxStack, parent, anchor, anchorTo, stackCount)
    if type(self) == "number" then
        stackCount = anchorTo
        anchorTo = anchor
        anchor = parent
        parent = maxStack
        maxStack = self
        self = StackSplitFrame
    end

    if not parent then
        parent = UIParent
        anchor = "CENTER"
        anchorTo = "CENTER"
    end

    ClearDialog()
    dialog = CreateItemSplitterDialog(maxStack)
    dialog:ClearAllPoints()
    dialog:SetPoint(anchor, parent, anchorTo, 0, 0)
    dialog.editBox:SetScript("OnEditFocusGained", function(self)
        C_Timer.After(0.1, function()
            self:HighlightText()
        end)
    end)
    dialog.editBox:SetFocus()

    local isGuildBank, bagIndex, slotIndex, forceBankScope, hasItemLocation = SourceLocation(parent)
    local isMerchant = MerchantFrame and MerchantFrame:IsVisible()

    if isMerchant then
        dialog.autoSplitButton:Hide()
        dialog.splitButton:ClearAllPoints()
        dialog.splitButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 10)
        if hasItemLocation then
            dialog.splitButton:SetText("Sell")
        else
            dialog.splitButton:SetText("Buy")
        end
    end

    dialog.splitButton:SetScript("OnClick", function()
        local splitValue = dialog:GetValue()
        if self and type(self.split) == "function" then
            self.split(splitValue)
        elseif StackSplitFrame and type(StackSplitFrame.SplitStack) == "function" then
            StackSplitFrame:SplitStack(splitValue)
        else
            parent.SplitStack(parent, splitValue) -- original behaviour
        end
        ClearDialog()
    end)

    dialog.autoSplitButton:SetScript("OnClick", function ()
        DisableDialog()
        StartAutomaticSplitSession(isGuildBank, bagIndex, slotIndex, dialog:GetValue(), forceBankScope)
    end)
end

-- Init block

local function Init()
    if StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
        StackSplitFrame.OpenStackSplitFrame = OpenFrame
    elseif type(OpenStackSplitFrame) == "function" then
        OpenStackSplitFrame = OpenFrame
    else
        ns.Log.warn("Stack split override not available")
    end
end

-- Frame update

function f:OnUpdate(elapsed)
    if coroutineAutomaticSplit then
        local status, res = coroutine.resume(coroutineAutomaticSplit)
        if not status then
            ns.Log.debug("Coroutine finished or error occurred:" .. res)
            coroutineAutomaticSplit = nil  -- Clear the coroutine once it's done or if an error occurred
        end
    end
end

-- Event functions

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, loadedAddonName)
	if addonName == loadedAddonName then
		Init()
	end
end

function f:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(event, type)
    if type == 10 then
        contextGuildBank = true
    end
end

function f:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(event, type)
    if type == 10 then
        contextGuildBank = false
        ClearDialog() -- for guild bank it is possible to close dialog this way
    end
end

-- In-game event register

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
f:SetScript("OnEvent", f.OnEvent)
f:SetScript("OnUpdate", f.OnUpdate)
