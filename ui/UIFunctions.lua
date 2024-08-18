local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")

NM.UIFunctions = {}

function NM.UIFunctions:createWindow(title, layout, width, height, resize, parent)
    local window = AceGUI:Create("Window")
    window:SetTitle(title)
    window:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    window:SetLayout(layout)
    window:SetWidth(width)
    window:SetHeight(height)
    window:EnableResize(resize);
    window.frame:SetParent(parent)
    return window;
end

function NM.UIFunctions:createLabel(text, width)
    local lbl = AceGUI:Create("Label")
    lbl:SetWidth(width)
    lbl:SetText(text)
    return lbl;
end

function NM.UIFunctions:createButton(label, width, OnClick)
    local button = AceGUI:Create("Button")
    button:SetText(label)
    button:SetWidth(width)
    button:SetCallback("OnClick", OnClick)
    return button;
end

function NM.UIFunctions:createCheckBox(label, value, OnValueChanged)
    local chkBox = AceGUI:Create("CheckBox")
    chkBox:SetType("checkbox")
    chkBox:SetLabel(label)
    chkBox:SetValue(value)
    chkBox:SetCallback("OnValueChanged", OnValueChanged)
    return chkBox;
end

function NM.UIFunctions:createEditBox(label,width,onEnterPressedCallBack)
    local editBox = AceGUI:Create("EditBox")
    editBox:SetLabel(label)
    editBox:SetCallback("OnEnterPressed",onEnterPressedCallBack)
    return editBox
end

function NM.UIFunctions:createMultiLineEditBox(label, width, numLines)
    local multiLineEditBox = AceGUI:Create("MultiLineEditBox")
    multiLineEditBox:SetLabel(label);
    multiLineEditBox:SetWidth(width)
    multiLineEditBox:SetNumLines(numLines)
    multiLineEditBox:DisableButton(true)
    return multiLineEditBox;
end

function NM.UIFunctions:createDropdown(label, width, items)
    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel(label)
    dropdown:SetWidth(width)
    dropdown:SetList(items)
    return dropdown;
end

function NM.UIFunctions:refreshDropdownOptions(dropdown, label, list)
    dropdown:SetValue("")
    dropdown:SetLabel(label)
    dropdown:SetList(list)
end

function NM.UIFunctions:createInteractiveImage(icon, size, tooltipText)
    local imgLabel = AceGUI:Create("InteractiveLabel")
    imgLabel:SetImage(icon)
    imgLabel:SetImageSize(size, size);
    imgLabel:SetCallback("OnEnter", function(self)
        GameTooltip:SetOwner(imgLabel.frame, "ANCHOR_CURSOR")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    imgLabel:SetCallback("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    return imgLabel;
end

function NM.UIFunctions:createButtonGroup(tableConfig)
    local buttonGroup = AceGUI:Create("SimpleGroup")
    -- check if there is a backdrop (elvui has a backdrop, default ui not)
    local hasButtonGroupBackdrop = buttonGroup.frame.GetBackdrop or false;
    if hasButtonGroupBackdrop then
        buttonGroup.frame:SetBackdrop(nil);
    end

    buttonGroup:SetLayout("Fill")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetHeight(60)

    return buttonGroup
end



