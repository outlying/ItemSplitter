local addonName, ns = ...

-- WoW functions alliases

local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local SplitContainerItem = C_Container and C_Container.SplitContainerItem or SplitContainerItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

--[[
    AutoSplittingSession representation of ongoing stack splitting process
]]

AutoSplittingSession = {}
AutoSplittingSession.__index = AutoSplittingSession

function AutoSplittingSession:new(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    local instance = setmetatable({}, AutoSplittingSession)
    instance.sourceBagIndex = sourceBagIndex
    instance.sourceSlotIndex = sourceSlotIndex
    instance.targetStacksSize = targetStacksSize
    return instance
end

-- Addon variables

local f = CreateFrame("Frame") -- Main event frame

local dialog = nil
local autoSplittingSession = nil

--[[
    Finds an empty slot in the player's bags.

    Iterates through all the bags (from bag 0 to bag 4) and their slots to find the first empty slot.

    @return bag (number) - The index of the bag containing the empty slot, or nil if no empty slot is found.
    @return slot (number) - The index of the empty slot within the bag, or nil if no empty slot is found. 
]]

local function FindEmptySlot()

    -- TODO it should allow to support other containers

    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemInfo = GetContainerItemInfo(bag, slot)
            if not itemInfo then
                return bag, slot
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

local function AutomaticSplit(bagIndex, slotIndex, targetStacksSize)
    local itemInfo = GetContainerItemInfo(bagIndex, slotIndex)
    local currentStackSize = itemInfo.stackCount

    local function SplitItem(sourceBag, sourceSlot, size)
        local destBag, destSlot = FindEmptySlot()
        if destBag and destSlot then
            SplitContainerItem(sourceBag, sourceSlot, size)
            PickupContainerItem(destBag, destSlot)
        else
            print("No empty slot found for split")
            return false
        end
        return true
    end

    if currentStackSize > targetStacksSize then
        SplitItem(bagIndex, slotIndex, targetStacksSize)
        return false
    end

    return true
end

--[[
    We start automatic splitting of stack
]]

local function StartAutomaticSplitSession(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    f:RegisterEvent("ITEM_LOCK_CHANGED")
    -- TODO guild bank splitting is managed by other event: GUILDBANK_ITEM_LOCK_CHANGED

    autoSplittingSession = AutoSplittingSession:new(sourceBagIndex, sourceSlotIndex, targetStacksSize)
    
    AutomaticSplit(
        autoSplittingSession.sourceBagIndex, 
        autoSplittingSession.sourceSlotIndex, 
        autoSplittingSession.targetStacksSize)
end

--[[
    After item lock is changed we try to continue and split item stack further
]]

local function ContinueAutomaticSplitSession()
    if not autoSplittingSession then
        print("Error, no automatic splitting session in progress")
        return
    end

    AutomaticSplit(autoSplittingSession.sourceBagIndex, autoSplittingSession.sourceSlotIndex, autoSplittingSession.targetStacksSize)

    local autoSplitResult = AutomaticSplit(
        autoSplittingSession.sourceBagIndex, 
        autoSplittingSession.sourceSlotIndex, 
        autoSplittingSession.targetStacksSize)

    if autoSplitResult then
        autoSplittingSession = nil
        f:UnregisterEvent("ITEM_LOCK_CHANGED")
    end
end 

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
        StartAutomaticSplitSession(bagIndex, slotIndex, dialog:GetValue())
    end)
end

-- Init block

local function Init()
	StackSplitFrame.OpenStackSplitFrame = OpenFrame
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

function f:ITEM_LOCK_CHANGED(event, bagOfUpdatedItem, slotOfUpdatedItem)
    if bagOfUpdatedItem and slotOfUpdatedItem then
        local itemInfo = GetContainerItemInfo(bagOfUpdatedItem, slotOfUpdatedItem)
        if itemInfo and not itemInfo.isLocked then
            ContinueAutomaticSplitSession()
        end
    end
end

-- In-game event register

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)