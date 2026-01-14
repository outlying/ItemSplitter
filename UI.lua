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

    -- Info window
    local infoFrame = CreateFrame("Frame", nil, frame, "BasicFrameTemplateWithInset")
    infoFrame:SetSize(260, 140)
    infoFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
    infoFrame:SetFrameStrata("DIALOG")
    infoFrame:Hide()

    infoFrame.title = infoFrame:CreateFontString(nil, "OVERLAY")
    infoFrame.title:SetFontObject("GameFontHighlight")
    infoFrame.title:SetPoint("CENTER", infoFrame.TitleBg, "CENTER", 5, 0)
    infoFrame.title:SetText("Info")

    infoFrame.text = infoFrame:CreateFontString(nil, "OVERLAY")
    infoFrame.text:SetFontObject("GameFontHighlightSmall")
    infoFrame.text:SetPoint("TOPLEFT", infoFrame, "TOPLEFT", 12, -30)
    infoFrame.text:SetPoint("BOTTOMRIGHT", infoFrame, "BOTTOMRIGHT", -12, 12)
    infoFrame.text:SetJustifyH("LEFT")
    infoFrame.text:SetJustifyV("TOP")
    infoFrame.text:SetText("Item Splitter is maintained by Mermido-Silvermoon and built after hours.\nDonations in the form of in-game gold are always appreciated.\n\nFor technical issues or bug reports, please use:\ngithub.com/outlying/ItemSplitter\n\nVersion: @project-version@")

    infoFrame.CloseButton:SetScript("OnClick", function()
        infoFrame:Hide()
    end)

    -- Info button on the title bar
    local infoButton = CreateFrame("Button", nil, frame)
    infoButton:SetSize(32, 32)
    infoButton:SetPoint("LEFT", frame.TitleBg, "LEFT", 0, -2)
    infoButton:SetNormalTexture("Interface\\Common\\help-i")
    infoButton:SetHighlightTexture("Interface\\Common\\help-i", "ADD")
    infoButton:SetPushedTexture("Interface\\Common\\help-i")
    infoButton:SetScript("OnClick", function()
        if infoFrame:IsShown() then
            infoFrame:Hide()
        else
            infoFrame:Show()
        end
    end)

    frame.infoFrame = infoFrame
    frame.infoButton = infoButton

    -- Edit box for number input
    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(40, 20)
    editBox:SetPoint("CENTER", frame, "CENTER", -15, 10)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetNumber(1)
    editBox:SetJustifyH("RIGHT")
    editBox:SetTextInsets(0, 5, 0, 0)
    editBox:SetScript("OnTextChanged", function(self)
        local currentNumber = editBox:GetNumber()
        editBox:SetNumber(ns.math_min(ns.math_max(currentNumber, 1), maximumValue))
    end)

    -- Support for Enter and Alt+Enter key press
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "ENTER" then
            if IsAltKeyDown() then
                frame.autoSplitButton:Click()
            else
                frame.splitButton:Click()
            end
        end
    end)

    local incrementValue = function ()
        local currentNumber = editBox:GetNumber()
        editBox:SetNumber(ns.math_min(currentNumber + 1, maximumValue))
    end

    local decrementValue = function ()
        local currentNumber = editBox:GetNumber()
        editBox:SetNumber(ns.math_max(currentNumber - 1, 1))
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

    frame.decrementButton = decrementButton

    -- Increment button
    local incrementButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    incrementButton:SetSize(20, 20)
    incrementButton:SetPoint("LEFT", decrementButton, "RIGHT", 5, 0)
    incrementButton:SetText("+")
    incrementButton:SetScript("OnClick", function()
        incrementValue()
    end)

    frame.incrementButton = incrementButton

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

    function frame:SetInfoText(text)
        if text and text ~= "" then
            frame.infoFrame.text:SetText(text)
        end
    end

    frame:HookScript("OnHide", function()
        frame.infoFrame:Hide()
    end)

    return frame
end
