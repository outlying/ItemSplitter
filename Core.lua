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
    Finds an empty slot in the player's bags.

    Iterates through all the bags (from bag 0 to bag 4) and their slots to find the first empty slot.

    @return bag (number) - The index of the bag containing the empty slot, or nil if no empty slot is found.
    @return slot (number) - The index of the empty slot within the bag, or nil if no empty slot is found. 
]]

local function FindEmptySlot(exclude, sourceBagIndex, sourceSlotIndex)

    local function isExcluded(bag, slot)
        for _, pair in ipairs(exclude) do
            if pair[1] == bag and pair[2] == slot then
                return true
            end
        end
        return false
    end

    -- TODO it should allow to support other containers

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            -- Check if the current bag-slot pair is excluded
            if not isExcluded(bag, slot) then
                local itemInfo = GetContainerItemInfo(bag, slot)
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

local function AutomaticSplit(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    local itemInfo = GetContainerItemInfo(sourceBagIndex, sourceSlotIndex)
    local currentStackSize = itemInfo.stackCount

    ClearCursor() -- Drop any items held by cursor

    local excluded = {} -- We are keeping local exclude list to not duplicate destination locations

    while currentStackSize > targetStacksSize do

        while true do
            local sourceItemInfo = GetContainerItemInfo(sourceBagIndex, sourceSlotIndex)
            if sourceItemInfo.isLocked then
                coroutine.yield()
            else
                break
            end
        end

        local destBag, destSlot = FindEmptySlot(excluded)
        table.insert(excluded, {destBag, destSlot})

        if destBag and destSlot then
            SplitContainerItem(sourceBagIndex, sourceSlotIndex, targetStacksSize)
            PickupContainerItem(destBag, destSlot)
            currentStackSize = currentStackSize - targetStacksSize
        else
            print("No more empty slots found for automatic split")
            break
        end
    end

    ClearDialog()
end

--[[
    We start automatic splitting of stack
]]

local coroutineAutomaticSplit = nil

local function StartAutomaticSplitSession(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    -- TODO guild bank splitting is managed by other event: GUILDBANK_ITEM_LOCK_CHANGED

    coroutineAutomaticSplit = coroutine.create(function ()
        AutomaticSplit(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    end)
end

-- Overrides standard function for split dialog

local function OpenFrame(self, maxStack, parent, anchor, anchorTo, stackCount)
    ClearDialog()
    dialog = CreateItemSplitterDialog(maxStack)
    dialog:ClearAllPoints()
    dialog:SetPoint(anchor, parent, anchorTo, 0, 0)

    local bagIndex = parent:GetParent():GetID()
    local slotIndex = parent:GetID()

    dialog.splitButton:SetScript("OnClick", function()
        parent.SplitStack(parent, dialog:GetValue()) -- original behaviour
        ClearDialog()
    end)

    dialog.autoSplitButton:SetScript("OnClick", function ()
        DisableDialog()
        StartAutomaticSplitSession(bagIndex, slotIndex, dialog:GetValue())
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
            ns.debug("Coroutine finished or error occurred:" .. res)
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