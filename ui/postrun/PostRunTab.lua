local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local PostRunTab = {
    WINDOW_CONFIG = {
        OUTPUT_WIDTH = 325,
        OUTPUT_LINES = 14,
        BUTTON_SIZES = {
            SESSION = 60,
            RESET = 30,
            INSTANCE = 150
        }
    },
    
    ICONS = {
        PLAY = "Interface\\AddOns\\NexusManager\\assets\\icons\\play",
        PAUSE = "Interface\\AddOns\\NexusManager\\assets\\icons\\pause",
        RESET = "Interface\\AddOns\\NexusManager\\assets\\icons\\reset1"
    },
    
    state = {
        isRunning = false,
        isPaused = false
    }
}

-- Private helper functions
local function createFarmNameInput()
    return NM.UIFunctions:createEditBox(L["Farm-Name"], 0, function(widget, event, text)
        NM.session.farmName = text
        NM:Log("Farm-Name set to " .. text)
    end)
end

local function createOutputBox()
    local output = AceGUI:Create("MultiLineEditBox")
    output:SetLabel("")
    output:SetFocus()
    output:SetWidth(PostRunTab.WINDOW_CONFIG.OUTPUT_WIDTH)
    output:DisableButton(true)
    output:SetNumLines(PostRunTab.WINDOW_CONFIG.OUTPUT_LINES)
    return output
end

local function createSessionActions()
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    return container
end

-- Public methods
function PostRunTab:Create()
    NM.ui.postrun = AceGUI:Create("SimpleGroup")
    
    -- Farm Name Input
    local farmName = createFarmNameInput()
    NM.ui.postrun:AddChild(farmName)
    
    -- Output Box
    local outputBox = createOutputBox()
    NM.ui.postrun:SetUserData("postrunBox", outputBox)
    NM.ui.postrun:AddChild(outputBox)
    NM.ui.postrun.output = outputBox
    
    -- Session Actions
    local sessionActions = createSessionActions()
    self:CreateSessionControls(sessionActions)
    NM.ui.postrun:AddChild(sessionActions)
    
    NM:Log("PostRun Tab initialized")
end

function PostRunTab:CreateSessionControls(container)
    -- Session Start/Pause Button
    local sessionButton = self:CreateSessionButton()
    container:AddChild(sessionButton)
    
    -- Reset Button
    local resetButton = self:CreateResetButton()
    container:AddChild(resetButton)
    
    -- Reset Instance Button
    local resetInstanceButton = self:CreateResetInstanceButton()
    container:AddChild(resetInstanceButton)
end

function PostRunTab:CreateSessionButton()
    local button = NM.UIFunctions:createInteractiveImage(
        self.ICONS.PLAY,
        25,
        L["Start the farm session"]
    )
    button:SetWidth(self.WINDOW_CONFIG.BUTTON_SIZES.SESSION)
    
    self:SetupSessionButtonCallbacks(button)
    return button
end

function PostRunTab:CreateResetButton()
    local button = NM.UIFunctions:createInteractiveImage(
        self.ICONS.RESET,
        25,
        L["Reset the current farm session"]
    )
    button:SetWidth(self.WINDOW_CONFIG.BUTTON_SIZES.RESET)
    
    button:SetCallback("OnClick", function()
        NM.session:restart()
    end)
    
    return button
end

function PostRunTab:CreateResetInstanceButton()
    return NM.UIFunctions:createButton(
        L["Reset instance"],
        self.WINDOW_CONFIG.BUTTON_SIZES.INSTANCE,
        function() 
            print("Reset Instance")
        end
    )
end

function PostRunTab:SetupSessionButtonCallbacks(button)
    button:SetCallback("OnClick", function(self)
        local isSessionRunning = NM.session.state == "running"
        local isSessionPaused = NM.session.state == "paused"

        if not isSessionRunning then
            NM.session:start()
            self:SetImage(PostRunTab.ICONS.PAUSE)
        elseif isSessionPaused and isSessionRunning then
            NM.session:continue()
            self:SetImage(PostRunTab.ICONS.PAUSE)
        else
            NM.session:pause()
            self:SetImage(PostRunTab.ICONS.PLAY)
        end
    end)
    
    button:SetCallback("OnEnter", function(self)
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(self.frame, "ANCHOR_CURSOR")

        local isSessionRunning = NM.session.state == "running"
        local isSessionPaused = NM.session.state == "paused"

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

function PostRunTab:UpdateOutput(text)
    if NM.ui.postrun and NM.ui.postrun.output then
        NM.ui.postrun.output:SetText(text)
    end
end

NM.postrun = PostRunTab
