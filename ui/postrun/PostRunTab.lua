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
            INSTANCE = 150,
            COPY = 25
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
    NM.ui.postrun:SetLayout("Flow")
    
    -- Add top padding container
    local paddingContainer = AceGUI:Create("SimpleGroup")
    paddingContainer:SetLayout("Flow")
    paddingContainer:SetFullWidth(true)
    paddingContainer:SetHeight(10) -- Padding von 10 Pixeln
    NM.ui.postrun:AddChild(paddingContainer)
    
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
        local isSessionRunning = NM.session and NM.session.state == "running"
        local isSessionPaused = NM.session and NM.session.state == "paused"

        if isSessionPaused then
            -- Fortsetzen einer pausierten Session
            NM.session:continue()
            self:SetImage(PostRunTab.ICONS.PAUSE)
        elseif isSessionRunning then
            -- Pausieren einer laufenden Session
            NM.session:pause()
            self:SetImage(PostRunTab.ICONS.PLAY)
        else
            -- Starten einer neuen Session
            if type(NM.session.start) == "number" then
                -- Wenn start eine Zahl ist, initialisiere die Session neu
                NM.session:init()
                NM.session.state = "running"
            else
                -- Normale Startmethode aufrufen
                NM.session:start()
            end
            self:SetImage(PostRunTab.ICONS.PAUSE)
        end
    end)
    
    button:SetCallback("OnEnter", function(self)
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(self.frame, "ANCHOR_CURSOR")

        local isSessionRunning = NM.session and NM.session.state == "running"
        local isSessionPaused = NM.session and NM.session.state == "paused"

        if isSessionPaused then
            GameTooltip:AddLine(L["Continue the current farm session"])
        elseif isSessionRunning then
            GameTooltip:AddLine(L["Pause the current farm session"])
        else
            GameTooltip:AddLine(L["Start the farm session"])
        end
        GameTooltip:Show()
    end)
end

function PostRunTab:UpdateOutput(text)
    if not NM.ui.postrun or not NM.ui.postrun.output then return end
    
    local annotations = {}
    local outputText = text or ""
    local itemTexts = {}
    
    -- Check if we have looted items in the session
    if NM.session and NM.session.itemsLooted then
        -- Process each looted item
        for itemID, count in pairs(NM.session.itemsLooted) do
            -- Prüfe ob das Item getrackt werden soll basierend auf den Optionen
            if NM.DB:ShouldTrackItem(itemID, true) then
                local itemName, _, itemRarity = C_Item.GetItemInfo(itemID)
                if itemName then
                    local _, _, _, hexColor = C_Item.GetItemQualityColor(itemRarity)
                    table.insert(itemTexts, string.format("%dx %s%s|r", count, hexColor, itemName))
                end
            end
        end
        
        -- Füge Items nur hinzu wenn welche getrackt wurden
        if #itemTexts > 0 then
            table.insert(annotations, "\n\nTracked Items:")
            table.insert(annotations, table.concat(itemTexts, ", "))
        end
    end
    
    -- Combine original text with annotations
    if #annotations > 0 then
        outputText = outputText .. table.concat(annotations, "\n")
    end
    
    NM.ui.postrun.output:SetText(outputText)
end

NM.postrun = PostRunTab
