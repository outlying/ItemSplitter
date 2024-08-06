local addonName, ns = ...
local f = CreateFrame("Frame") -- Main event frame

-------------------------
-- Event functions

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
	print(event, addOnName)
end

-------------------------

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)