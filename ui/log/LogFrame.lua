local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local LogFrame = {}
NM.LogFrame = LogFrame

-- Initialisiere die Logs-Tabelle
NM.logs = NM.logs or {}

-- Log Kategorien und Window Config
LogFrame.CATEGORIES = {
    CHALLENGE = "Challenge",
    SESSION = "Session",
    SYSTEM = "System",
    ERROR = "Error",
    DEBUG = "Debug"
}

LogFrame.WINDOW_CONFIG = {
    CONTAINER_WIDTH = 1000,
    CONTAINER_HEIGHT = 600,
    HEADER_HEIGHT = 25,
    ROW_HEIGHT = 25,
    COLUMNS = {
        TIME = {
            width = 60,
            name = L["Time"]
        },
        CATEGORY = {
            width = 100,
            name = L["Category"]
        },
        MESSAGE = {
            width = 300,
            name = L["Message"]
        },
        DATA = {
            width = 500,
            name = L["Data"]
        }
    }
}

-- Sortierlogik
function LogFrame:SortBy(columnKey)
    if not self.currentSort then
        self.currentSort = {
            column = columnKey,
            ascending = true
        }
    elseif self.currentSort.column == columnKey then
        self.currentSort.ascending = not self.currentSort.ascending
    else
        self.currentSort.column = columnKey
        self.currentSort.ascending = true
    end
    
    self:UpdateLogDisplay()
    self:UpdateSortIndicators()
end

function LogFrame:Show()
    if self.frame then
        self.frame:Show()
        return
    end
    
    -- Erstelle das Hauptfenster
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["Log Viewer"])
    frame:SetLayout("Flow")
    frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH)
    frame:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT)
    self.frame = frame
    
    -- Header Container
    local headerContainer = AceGUI:Create("SimpleGroup")
    headerContainer:SetLayout("Flow")
    headerContainer:SetFullWidth(true)
    headerContainer:SetHeight(self.WINDOW_CONFIG.HEADER_HEIGHT)
    headerContainer.frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH - 20)
    
    -- Zeit Header
    self.timeHeader = AceGUI:Create("InteractiveLabel")
    self.timeHeader:SetText(self.WINDOW_CONFIG.COLUMNS.TIME.name)
    self.timeHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.TIME.width)
    self.timeHeader:SetCallback("OnClick", function() self:SortBy("TIME") end)
    headerContainer:AddChild(self.timeHeader)
    
    -- Kategorie Header
    self.categoryHeader = AceGUI:Create("InteractiveLabel")
    self.categoryHeader:SetText(self.WINDOW_CONFIG.COLUMNS.CATEGORY.name)
    self.categoryHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.CATEGORY.width)
    self.categoryHeader:SetCallback("OnClick", function() self:SortBy("CATEGORY") end)
    headerContainer:AddChild(self.categoryHeader)
    
    -- Message Header
    self.messageHeader = AceGUI:Create("InteractiveLabel")
    self.messageHeader:SetText(self.WINDOW_CONFIG.COLUMNS.MESSAGE.name)
    self.messageHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.MESSAGE.width)
    self.messageHeader:SetCallback("OnClick", function() self:SortBy("MESSAGE") end)
    headerContainer:AddChild(self.messageHeader)
    
    -- Data Header
    self.dataHeader = AceGUI:Create("InteractiveLabel")
    self.dataHeader:SetText(self.WINDOW_CONFIG.COLUMNS.DATA.name)
    self.dataHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.DATA.width)
    self.dataHeader:SetCallback("OnClick", function() self:SortBy("DATA") end)
    headerContainer:AddChild(self.dataHeader)
    
    frame:AddChild(headerContainer)
    
    -- Scrollframe für Logs
    self.scrollframe = AceGUI:Create("ScrollFrame")
    self.scrollframe:SetLayout("List")
    self.scrollframe:SetFullWidth(true)
    self.scrollframe:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT - self.WINDOW_CONFIG.HEADER_HEIGHT - 80)
    self.scrollframe.frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH - 20)
    frame:AddChild(self.scrollframe)
    
    -- Clear Button
    local clearButton = AceGUI:Create("Button")
    clearButton:SetText(L["Clear"])
    clearButton:SetWidth(100)
    clearButton:SetCallback("OnClick", function()
        NM.logs = {}
        self:UpdateLogDisplay()
    end)
    frame:AddChild(clearButton)
    
    self:UpdateLogDisplay()
end

local function FormatMetadata(metadata)
    if not metadata then return "" end
    
    local parts = {}
    for key, value in pairs(metadata) do
        if type(value) == "table" then
            -- Für verschachtelte Tabellen
            local subParts = {}
            for k, v in pairs(value) do
                table.insert(subParts, k .. "=" .. tostring(v))
            end
            table.insert(parts, key .. "={" .. table.concat(subParts, ",") .. "}")
        else
            table.insert(parts, key .. "=" .. tostring(value))
        end
    end
    
    return table.concat(parts, " | ")
end

function LogFrame:UpdateLogDisplay()
    if not self.scrollframe then return end
    self.scrollframe:ReleaseChildren()
    
    -- Kopiere Logs in eine sortierbare Liste
    local logsList = {}
    for _, log in ipairs(NM.logs) do
        table.insert(logsList, log)
    end
    
    -- Sortiere die Liste
    if self.currentSort then
        table.sort(logsList, function(a, b)
            local aValue, bValue
            
            if self.currentSort.column == "TIME" then
                aValue = a.timestamp
                bValue = b.timestamp
            elseif self.currentSort.column == "CATEGORY" then
                aValue = a.category
                bValue = b.category
            elseif self.currentSort.column == "MESSAGE" then
                aValue = a.message
                bValue = b.message
            elseif self.currentSort.column == "DATA" then
                aValue = NM.Utils:TableToString(a.metadata)
                bValue = NM.Utils:TableToString(b.metadata)
            end
            
            if self.currentSort.ascending then
                return aValue < bValue
            else
                return aValue > bValue
            end
        end)
    end
    
    -- Zeige sortierte Logs an
    for index, log in ipairs(logsList) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        row:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)
        row.frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH - 20)
        
        -- Alternierender Hintergrund
        if index % 2 == 0 then
            local bg = row.frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        -- Zeit
        local time = AceGUI:Create("Label")
        time:SetText(date("%H:%M:%S", log.timestamp))
        time:SetWidth(self.WINDOW_CONFIG.COLUMNS.TIME.width)
        time.label:SetJustifyH("LEFT")
        row:AddChild(time)
        
        -- Kategorie
        local category = AceGUI:Create("Label")
        category:SetText(log.category)
        category:SetWidth(self.WINDOW_CONFIG.COLUMNS.CATEGORY.width)
        category.label:SetJustifyH("LEFT")
        row:AddChild(category)
        
        -- Message
        local message = AceGUI:Create("Label")
        message:SetText(log.message)
        message:SetWidth(self.WINDOW_CONFIG.COLUMNS.MESSAGE.width)
        message.label:SetJustifyH("LEFT")
        row:AddChild(message)
        
        -- Data
        local data = AceGUI:Create("Label")
        data:SetText(FormatMetadata(log.metadata))
        data:SetWidth(self.WINDOW_CONFIG.COLUMNS.DATA.width)
        data.label:SetJustifyH("LEFT")
        data.label:SetWordWrap(false)
        row:AddChild(data)
        
        self.scrollframe:AddChild(row)
    end
end

function LogFrame:UpdateSortIndicators()
    -- Setze Basis-Texte
    local timeText = self.WINDOW_CONFIG.COLUMNS.TIME.name
    local categoryText = self.WINDOW_CONFIG.COLUMNS.CATEGORY.name
    local messageText = self.WINDOW_CONFIG.COLUMNS.MESSAGE.name
    local dataText = self.WINDOW_CONFIG.COLUMNS.DATA.name
    
    if self.currentSort then
        local arrow = self.currentSort.ascending and 
            "|TInterface/BUTTONS/Arrow-Up-Up:12:12:0:0:1:1|t" or
            "|TInterface/BUTTONS/Arrow-Down-Up:12:12:0:0:1:1|t"
        
        if self.currentSort.column == "TIME" then
            timeText = timeText .. "  " .. arrow
        elseif self.currentSort.column == "CATEGORY" then
            categoryText = categoryText .. "  " .. arrow
        elseif self.currentSort.column == "MESSAGE" then
            messageText = messageText .. "  " .. arrow
        elseif self.currentSort.column == "DATA" then
            dataText = dataText .. "  " .. arrow
        end
    end
    
    self.timeHeader:SetText(timeText)
    self.categoryHeader:SetText(categoryText)
    self.messageHeader:SetText(messageText)
    self.dataHeader:SetText(dataText)
end

function LogFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function LogFrame:AddLog(category, message, metadata)
    if not message then return end
    
    local logEntry = {
        timestamp = time(),
        category = category or self.CATEGORIES.SYSTEM,
        message = message,
        metadata = metadata or {}
    }
    
    table.insert(NM.logs, logEntry)
    
    if self.frame and self.scrollframe then
        self:UpdateLogDisplay()
    end
end

NM.LogFrame = LogFrame
