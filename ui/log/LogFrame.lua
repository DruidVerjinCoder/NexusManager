local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale
local AceSerializer = LibStub("AceSerializer-3.0")

local LogFrame = {}
NM.LogFrame = LogFrame

-- Log Kategorien
LogFrame.CATEGORIES = {
    CHALLENGE = "Challenge",
    SESSION = "Session",
    SYSTEM = "System",
    ERROR = "Error",
    DEBUG = "Debug"
}

-- Log Typen für Challenge
LogFrame.CHALLENGE_TYPES = {
    SEND = "Send",
    RECEIVE = "Receive",
    JOIN = "Join",
    LEAVE = "Leave",
    START = "Start",
    END = "End",
    CANCEL = "Cancel"
}

-- Initialisiere die Logs als persistente Tabelle
NM.logs = NM.logs or {}

function LogFrame:AddLog(category, message, metadata)
    -- Überprüfe ob eine Nachricht vorhanden ist
    if not message then return end
    
    -- Erstelle den Log-Eintrag
    local logEntry = {
        timestamp = time(),
        category = category or self.CATEGORIES.SYSTEM,
        message = message,
        metadata = metadata or {}
    }
    
    table.insert(NM.logs, logEntry)
    
    -- Aktualisiere das Fenster wenn es offen ist
    if self.frame and self.editBox then
        self:UpdateLogDisplay()
    end
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
    frame:SetWidth(800)
    frame:SetHeight(600)
    self.frame = frame
    
    -- Filter Dropdown für Kategorien
    local categoryFilter = AceGUI:Create("Dropdown")
    categoryFilter:SetLabel(L["Category"])
    categoryFilter:SetWidth(200)
    local categories = {[""] = L["All"]}
    for _, category in pairs(self.CATEGORIES) do
        categories[category] = category
    end
    categoryFilter:SetList(categories)
    categoryFilter:SetCallback("OnValueChanged", function(_, _, value)
        self.currentFilter = value
        self:UpdateLogDisplay()
    end)
    frame:AddChild(categoryFilter)
    
    -- Erstelle die Editbox für die Logs
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetFullWidth(true)
    editBox:SetHeight(500)
    editBox:DisableButton(true)
    editBox:SetLabel("")
    editBox:SetMaxLetters(0) -- Unbegrenzte Textlänge
    editBox:SetNumLines(0)   -- Automatische Zeilenzahl
    self.editBox = editBox
    
    -- Aktiviere Scrolling
    editBox.editBox:SetMultiLine(true)
    editBox.editBox:SetAutoFocus(false)
    editBox.scrollFrame:SetPoint("BOTTOMRIGHT", -23, 0)
    
    frame:AddChild(editBox)
    
    -- Button Container
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetHeight(30)
    
    -- Clear Button
    local clearButton = AceGUI:Create("Button")
    clearButton:SetText(L["Clear"])
    clearButton:SetWidth(100)
    clearButton:SetCallback("OnClick", function()
        NM.logs = {}
        self:UpdateLogDisplay()
    end)
    
    buttonGroup:AddChild(clearButton)
    frame:AddChild(buttonGroup)
    
    -- Zeige aktuelle Logs an
    self:UpdateLogDisplay()
end

function LogFrame:UpdateLogDisplay()
    if not self.editBox then return end
    
    local displayLogs = {}
    for _, log in ipairs(NM.logs) do
        -- Filtere nach Kategorie wenn ein Filter gesetzt ist
        if not self.currentFilter or self.currentFilter == "" or log.category == self.currentFilter then
            local timeString = date("%H:%M:%S", log.timestamp)
            local metadataStr = ""
            
            -- Formatiere Metadata
            if next(log.metadata) then
                local metaParts = {}
                for key, value in pairs(log.metadata) do
                    table.insert(metaParts, key .. ": " .. tostring(value))
                end
                metadataStr = " [" .. table.concat(metaParts, ", ") .. "]"
            end
            
            -- Stelle sicher, dass message nicht nil ist
            local message = log.message or "No message"
            
            table.insert(displayLogs, string.format("[%s] [%s]%s %s", 
                timeString, 
                log.category,
                metadataStr,
                message
            ))
        end
    end
    
    self.editBox:SetText(table.concat(displayLogs, "\n"))
end

function LogFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function LogFrame:FormatChallengeData(data)
    if type(data) ~= "table" then return tostring(data) end
    
    local parts = {}
    
    -- Versuche alle Felder der Table zu formatieren
    for key, value in pairs(data) do
        if type(value) == "table" then
            table.insert(parts, key .. ": " .. NM.Utils:TableToString(value))
        else
            table.insert(parts, key .. ": " .. tostring(value))
        end
    end
    
    return table.concat(parts, " | ")
end
