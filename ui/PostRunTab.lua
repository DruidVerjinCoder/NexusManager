NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
local AceGUI = LibStub("AceGUI-3.0")

local postrun = {}

function postrun:Create()
    NM.ui.postrun = AceGUI:Create("SimpleGroup")

    local farmName = NM.UIFunctions:createEditBox("Farm-Name", 0, function(widget, event, text)
        NM.session.farmName = text
        NM:Log("Farm-Name set to " .. text)
    end)

    NM.ui.postrun:AddChild(farmName)

    local multiLineEditBox = AceGUI:Create("MultiLineEditBox")
    multiLineEditBox:SetLabel("")
    multiLineEditBox:SetFocus()
    multiLineEditBox:SetWidth(325)
    multiLineEditBox:DisableButton(true)
    multiLineEditBox:SetNumLines(14)

    NM.ui.postrun:SetUserData("postrunBox", multiLineEditBox)
    
    NM.ui.postrun:AddChild(multiLineEditBox)
    NM.ui.postrun.output = multiLineEditBox;

    ---- Aktionen
    local sessionActions = AceGUI:Create("ScrollFrame")
    sessionActions:SetLayout("Table")
    sessionActions:SetUserData("table", {
        columns = { 75, 75, 150 },
        align = "CENTER"
    })
    sessionActions:SetFullWidth(true)
    sessionActions:SetHeight(60)
    if sessionActions.frame.GetBackdrop then
        sessionActions.frame:SetBackdrop(nil);
    end

    -- Aktionen
    local sessionInteractionIcon = NM.UIFunctions:createInteractiveImage(
        "Interface\\AddOns\\NexusManager\\Media\\icons\\play", 25,
        L["Start the farm session"])
    postrun:acceptSessionButtonClick(sessionInteractionIcon)
    postrun:updateGameTooltipByState(sessionInteractionIcon)
    sessionActions:AddChild(sessionInteractionIcon)

    local reload = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\icons\\reset1", 25,
        L["Reset the current farm session"])
    reload:SetCallback("OnClick", function()
        NM.session:restart()
    end);
    sessionActions:AddChild(reload)

    NM.ui.postrun:AddChild(sessionActions)

    NM:Log("After initializing postrunContainer")
end

function postrun:updateGameTooltipByState(interactionLabel, notStartedState, continueState, runningState)
    interactionLabel:SetCallback("OnEnter", function(self)
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(self.frame, "ANCHOR_CURSOR")

        local isSessionRunning = NM.LA.Session.IsRunning()
        local isSessionPaused = NM.LA.Session.IsPaused();

        if not isSessionRunning then
            GameTooltip:AddLine(L["Start the farm session"])
        elseif isSessionPaused and isSessionRunning then
            GameTooltip:AddLine(L["Continue the current farm session"])
        else
            GameTooltip:AddLine(L["Pause the current farm session"])
        end
        GameTooltip:Show()
    end)
end

function postrun:acceptSessionButtonClick(button)
    button:SetCallback("OnClick", function(self)
        local isSessionRunning = NM.LA.Session.IsRunning()
        local isSessionPaused = NM.LA.Session.IsPaused();

        if not isSessionRunning then
            NM.session:start()
            self:SetImage("Interface\\AddOns\\NexusManager\\Media\\icons\\pause")
        elseif isSessionPaused and isSessionRunning then
            NM.session:continue()
            self:SetImage("Interface\\AddOns\\NexusManager\\Media\\icons\\pause")
        else
            NM.session:pause()
            self:SetImage("Interface\\AddOns\\NexusManager\\Media\\icons\\play")
        end

    end)
end

NM.postrun = postrun
