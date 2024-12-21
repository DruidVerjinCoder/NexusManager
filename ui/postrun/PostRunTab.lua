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
    if not NM.ui.postrun or not NM.ui.postrun.output then return end
    
    local annotations = {}
    local outputText = text or ""
    
    NM:Log("=== UpdateOutput Start ===")
    
    -- Check if we have looted items in the session
    if NM.session and NM.session.itemsLooted then
        NM:Log("Found itemsLooted in session")
        NM:Log("Items in session: " .. NM.Utils.tableToString(NM.session.itemsLooted))
        
        -- Group items by type for better organization
        local itemsByType = {
            General = {},      -- For rarity-based items
            TradeGoods = {},   -- For tradeskill items
            Miscellaneous = {},-- For misc items
            Recipes = {}       -- For recipe items
        }
        
        -- Process each looted item
        for itemID, count in pairs(NM.session.itemsLooted) do
            NM:Log("Processing item: " .. itemID .. " (Count: " .. count .. ")")
            local itemName, _, itemRarity, _, _, itemType, itemSubType = C_Item.GetItemInfo(itemID)
            
            if itemName then
                NM:Log("Item info - Name: " .. itemName .. ", Rarity: " .. itemRarity .. ", Type: " .. itemType)
                if NM.DB:ShouldTrackItem(itemID) then
                    NM:Log("Item should be tracked")
                    local _, _, _, hexColor = C_Item.GetItemQualityColor(itemRarity)
                    local itemText = string.format("|c%s%s|r x%d", hexColor, itemName, count)
                    
                    -- Categorize the item
                    if itemType == ITEM_QUALITY_COLORS[1] then -- Trade Goods
                        table.insert(itemsByType.TradeGoods, {text = itemText, subType = itemSubType})
                        NM:Log("Added to Trade Goods")
                    elseif itemType == ITEM_QUALITY_COLORS[0] then -- Miscellaneous
                        table.insert(itemsByType.Miscellaneous, {text = itemText, subType = itemSubType})
                        NM:Log("Added to Miscellaneous")
                    elseif itemType == L["Recipe"] then
                        table.insert(itemsByType.Recipes, {text = itemText, subType = itemSubType})
                        NM:Log("Added to Recipes")
                    else
                        table.insert(itemsByType.General, {text = itemText, rarity = itemRarity})
                        NM:Log("Added to General")
                    end
                else
                    NM:Log("Item should not be tracked")
                end
            else
                NM:Log("Could not get item info for ID: " .. itemID)
            end
        end
        
        -- Add annotations if we found any tracked items
        local hasAnnotations = false
        
        -- Add header if we have any annotations
        if next(itemsByType.General) or next(itemsByType.TradeGoods) or 
           next(itemsByType.Miscellaneous) or next(itemsByType.Recipes) then
            table.insert(annotations, "\n\nTracked Items:")
            hasAnnotations = true
        end
        
        -- Add items by rarity
        if next(itemsByType.General) then
            table.insert(annotations, "\nBy Rarity:")
            table.sort(itemsByType.General, function(a, b) return a.rarity > b.rarity end)
            for _, item in ipairs(itemsByType.General) do
                table.insert(annotations, "  " .. item.text)
            end
        end
        
        -- Add trade goods
        if next(itemsByType.TradeGoods) then
            table.insert(annotations, "\nTrade Goods:")
            table.sort(itemsByType.TradeGoods, function(a, b) return a.subType < b.subType end)
            for _, item in ipairs(itemsByType.TradeGoods) do
                table.insert(annotations, "  " .. item.text .. " (" .. item.subType .. ")")
            end
        end
        
        -- Add miscellaneous items
        if next(itemsByType.Miscellaneous) then
            table.insert(annotations, "\nMiscellaneous:")
            table.sort(itemsByType.Miscellaneous, function(a, b) return a.subType < b.subType end)
            for _, item in ipairs(itemsByType.Miscellaneous) do
                table.insert(annotations, "  " .. item.text .. " (" .. item.subType .. ")")
            end
        end
        
        -- Add recipes
        if next(itemsByType.Recipes) then
            table.insert(annotations, "\nRecipes:")
            table.sort(itemsByType.Recipes, function(a, b) return a.subType < b.subType end)
            for _, item in ipairs(itemsByType.Recipes) do
                table.insert(annotations, "  " .. item.text .. " (" .. item.subType .. ")")
            end
        end
    else
        NM:Log("No itemsLooted found in session")
    end
    
    NM:Log("=== UpdateOutput End ===")
    
    -- Combine original text with annotations
    if #annotations > 0 then
        outputText = outputText .. table.concat(annotations, "\n")
    end
    
    NM.ui.postrun.output:SetText(outputText)
end

NM.postrun = PostRunTab
