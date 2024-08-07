local addonName, ns = ...

function CreateItemSplitterDialog(
    maximumValue
)

    -- Create the main frame
    local frame = CreateFrame("Frame", "ItemSplitterFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(200, 100)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:EnableMouseWheel(true)

    -- Title text
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 5, 0)
    frame.title:SetText("Item Splitter")

    -- Edit box for number input
    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(40, 20)
    editBox:SetPoint("CENTER", frame, "CENTER", -15, 10)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetNumber(1)
    editBox:SetJustifyH("RIGHT")
    editBox:SetTextInsets(0, 5, 0, 0)

    local incrementValue = function ()
        local currentNumber = editBox:GetNumber()
        editBox:SetNumber(ns.math_min(currentNumber + 1, maximumValue))
    end

    local decrementValue = function ()
        local currentNumber = editBox:GetNumber()
        editBox:SetNumber(ns.math_min(currentNumber - 1, maximumValue))
    end
    
    frame.editBox = editBox

    -- Scroll wheel support for frame
    frame:SetScript("OnMouseWheel", function(self, delta)
        local currentNumber = editBox:GetNumber()
        if delta > 0 then
            incrementValue()
        elseif delta < 0 and currentNumber > 1 then
            decrementValue()
        end
    end)

    -- Decrement button
    local decrementButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    decrementButton:SetSize(20, 20)
    decrementButton:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
    decrementButton:SetText("-")
    decrementButton:SetScript("OnClick", function()
        decrementValue()
    end)

    -- Increment button
    local incrementButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    incrementButton:SetSize(20, 20)
    incrementButton:SetPoint("LEFT", decrementButton, "RIGHT", 5, 0)
    incrementButton:SetText("+")
    incrementButton:SetScript("OnClick", function()
        incrementValue()
    end)

    -- Split button
    local splitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    splitButton:SetSize(80, 20)
    splitButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    splitButton:SetText("Split")

    splitButton:SetScript("OnClick", function()
        print("Error, split button script, this should be overridden.")
    end)

    frame.splitButton = splitButton

    -- Auto Split button
    local autoSplitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    autoSplitButton:SetSize(80, 20)
    autoSplitButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    autoSplitButton:SetText("Auto Split")

    autoSplitButton:SetScript("OnClick", function()
        print("Error, auto split button script, this should be overridden.")
    end)

    frame.autoSplitButton = autoSplitButton

    function frame:GetValue()
        return frame.editBox:GetNumber()
    end

    return frame
end
