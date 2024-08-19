local addonName, ns = ...

-- WoW functions alliases

local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local SplitContainerItem = C_Container and C_Container.SplitContainerItem or SplitContainerItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

-- Addon variables

local f = CreateFrame("Frame") -- Main event frame

local ContainerScope = {}
ContainerScope.PERSONAL = { 
    Enum.BagIndex.Backpack,
    Enum.BagIndex.Bag_1,
    Enum.BagIndex.Bag_2,
    Enum.BagIndex.Bag_3,
    Enum.BagIndex.Bag_4
 }

 ContainerScope.PERSONAL_REGENTS = {
    Enum.BagIndex.ReagentBag
 }

 ContainerScope.PERSONAL_WITH_REGENTS = ns.mergeTables(ContainerScope.PERSONAL, ContainerScope.PERSONAL_REGENTS)

 ContainerScope.BANK = {
    Enum.BagIndex.Bank,
    Enum.BagIndex.BankBag_1,
    Enum.BagIndex.BankBag_2,
    Enum.BagIndex.BankBag_3,
    Enum.BagIndex.BankBag_4,
    Enum.BagIndex.BankBag_5,
    Enum.BagIndex.BankBag_6,
    Enum.BagIndex.BankBag_7
 }

 ContainerScope.BANK_REGENTS = {
    Enum.BagIndex.Reagentbank
 }

 ContainerScope.BANK_WITH_REGENTS = ns.mergeTables(ContainerScope.BANK, ContainerScope.BANK_REGENTS)

local dialog = nil
local contextGuildBank = false

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
        return GetContainerItemInfo(sourceBagIndex, sourceSlotIndex)
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

local function FindEmptySlot(exclude, isGuildBank, sourceBagIndex, sourceSlotIndex)

    local function isExcluded(bag, slot)
        for _, pair in ipairs(exclude) do
            if pair[1] == bag and pair[2] == slot then
                return true
            end
        end
        return false
    end

    -- TODO it should allow to support other containers

    local startBag = 0
    local endBag = 4

    if isGuildBank then
        startBag = sourceBagIndex
        endBag = sourceBagIndex
    end

    for bag = startBag, endBag do
        local maxSlots = nil
        
        if isGuildBank then
            maxSlots = 98 -- For bank tabs is always the same -- TODO const ?
        else
            maxSlots = GetContainerNumSlots(bag)
        end

        for slot = 1, maxSlots do
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

local function AutomaticSplit(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize)
    local itemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)

    if not itemInfo then
        ns.Log.debug("Unable to get item info for given input")
        return
    end

    local currentStackSize = itemInfo.stackCount
    ClearCursor() -- Drop any items held by cursor
    local excluded = {} -- We are keeping local exclude list to not duplicate destination locations
    local transferBag, transferSlot = nil, nil

    if isGuildBank then
        transferBag, transferSlot = FindEmptySlot(excluded, false, sourceBagIndex, sourceSlotIndex) -- False we look in players bags
        if not transferBag or not transferSlot then
            ns.Log.info("At least one empty slot in your bags is required to do that")
            return
        end
    end

    while currentStackSize > targetStacksSize do

        while true do
            local sourceItemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)
            if sourceItemInfo.isLocked then
                coroutine.yield()
            else
                break
            end
        end

        local destBag, destSlot = FindEmptySlot(excluded, isGuildBank, sourceBagIndex, sourceSlotIndex)

        if destBag and destSlot then
            table.insert(excluded, {destBag, destSlot})

            -- This is special guild bank handling
            if isGuildBank and transferBag and transferSlot then
                
                SplitGuildBankItem(sourceBagIndex, sourceBagIndex, targetStacksSize)
                PickupContainerItem(transferBag, transferSlot)
                PickupContainerItem(transferBag, transferSlot)
                PickupGuildBankItem(destBag, destSlot)

            -- Other bags / banks handling
            else
                SplitContainerItem(sourceBagIndex, sourceSlotIndex, targetStacksSize)
                PickupContainerItem(destBag, destSlot)
            end

            -- Wait on an actual change
            while true do
                local inprogressItemInfo = CollectItemInfo(isGuildBank, sourceBagIndex, sourceSlotIndex)
                if inprogressItemInfo then
                    if inprogressItemInfo.stackCount == currentStackSize - targetStacksSize then
                        currentStackSize = currentStackSize - targetStacksSize
                        ns.Log.debug("Current stack size: " .. currentStackSize)
                        break
                    else
                        coroutine.yield()
                    end
                else
                    coroutine.yield()
                end
            end
        else
            ns.Log.warn("No more empty slots found for automatic split")
            break
        end
    end

    ClearDialog()
end

--[[
    We start automatic splitting of stack
]]

local coroutineAutomaticSplit = nil

local function StartAutomaticSplitSession(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize)
    coroutineAutomaticSplit = coroutine.create(function ()
        AutomaticSplit(isGuildBank, sourceBagIndex, sourceSlotIndex, targetStacksSize)
    end)
end

--[[
    Detector function to figure out clicked bag-slot combination based on parent UI element
    
    The guild bank is a bit tricky since tabs IDs are overlapping with usual bag numeration
    so tab 1 in bank is 1, the same as bag 1 player is carrying.
]]

local function SourceLocation(parent)
    local isGuildBank = false
    local bagIndex = parent:GetParent():GetID()
    local slotIndex = parent:GetID()

    if parent:GetParent():GetParent():GetName() == "GuildBankFrame" then
        isGuildBank = true
        bagIndex = GetCurrentGuildBankTab()
    end

    return isGuildBank, bagIndex, slotIndex
end

-- Overrides standard function for split dialog

local function OpenFrame(self, maxStack, parent, anchor, anchorTo, stackCount)

    ClearDialog()
    dialog = CreateItemSplitterDialog(maxStack)
    dialog:ClearAllPoints()
    dialog:SetPoint(anchor, parent, anchorTo, 0, 0)

    local isGuildBank, bagIndex, slotIndex = SourceLocation(parent)

    dialog.splitButton:SetScript("OnClick", function()
        parent.SplitStack(parent, dialog:GetValue()) -- original behaviour
        ClearDialog()
    end)

    dialog.autoSplitButton:SetScript("OnClick", function ()
        DisableDialog()
        StartAutomaticSplitSession(isGuildBank, bagIndex, slotIndex, dialog:GetValue())
    end)
end

-- Init block

local function Init()
	StackSplitFrame.OpenStackSplitFrame = OpenFrame
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