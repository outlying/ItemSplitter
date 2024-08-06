local addonName, ns = ...

-- WoW functions alliases

local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local SplitContainerItem = C_Container and C_Container.SplitContainerItem or SplitContainerItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

-- Addon variables

local f = CreateFrame("Frame") -- Main event frame

local dialog = nil
local stacksValue = nil

-- Update value from dialog

local function OnStackValueChanged(value)
    stacksValue = value
end

-- Hide, unparentm and dereference current instance of dialog

local function ClearDialog()
    if dialog then -- Remove old dialog, we start fresh
        dialog:Hide()
        dialog:SetParent(nil)
        -- dialog.splitButton:SetScript("OnClick", nil)
    end
    dialog = nil
end

-- Overrides standard function for split dialog

local function OpenFrame(self, maxStack, parent, anchor, anchorTo, stackCount)
    ClearDialog()
    dialog = CreateItemSplitterDialog(maxStack, OnStackValueChanged)

    dialog:SetPoint(anchor, parent, anchorTo, 0, 0)

    local bagIndex = parent:GetParent():GetID()
    local slotIndex = parent:GetID()

    dialog.splitButton:SetScript("OnClick", function()
        parent.SplitStack(parent, stacksValue) -- original behaviour
        ClearDialog()
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

-- In-game event register

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)