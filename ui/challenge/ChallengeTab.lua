NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale
ChallengeTab = {}

function ChallengeTab:Create()
    NM.ui.challenge = AceGUI:Create("SimpleGroup")
    NM.ui.challenge:SetLayout("List")

    local challengeDescription = AceGUI:Create("MultiLineEditBox")
    challengeDescription:SetLabel(L["Description"]);
    challengeDescription:SetNumLines(2);
    challengeDescription:DisableButton(true);
    challengeDescription:SetWidth(325);

    local settingGroup = AceGUI:Create("SimpleGroup")
    settingGroup:SetLayout("Flow")

    local durationField = AceGUI:Create("EditBox")
    durationField:SetLabel(L["Duration"])
    durationField:SetWidth(100)

    local minLabel = AceGUI:Create("Label")
    minLabel:SetText(L["min"])
    minLabel:SetWidth(25)

    local priceSource = AceGUI:Create("Dropdown")
    priceSource:SetLabel(L["Price Source"])
    priceSource:SetWidth(150)

    settingGroup:AddChild(durationField)
    settingGroup:AddChild(minLabel)
    settingGroup:AddChild(priceSource)

    NM.ui.challenge:AddChild(challengeDescription)
    NM.ui.challenge:AddChild(settingGroup)


    local btnGroup = AceGUI:Create("SimpleGroup")
    btnGroup:SetLayout("Flow")
    local inviteBtn = AceGUI:Create("Button")
    inviteBtn:SetText(L["Send invites"])
    inviteBtn:SetWidth(250)
    btnGroup:AddChild(inviteBtn);
    
    local inviteBtn = AceGUI:Create("InteractiveLabel")
    inviteBtn:SetImage("Interface\\AddOns\\NexusManager\\assets\\icons\\setting", 20, 20)
    inviteBtn:SetWidth(50)
    btnGroup:AddChild(inviteBtn);

    NM.ui.challenge:AddChild(btnGroup)
    print("After Creation of ChallengeTab")
end

NM.ChallengeTab = ChallengeTab
