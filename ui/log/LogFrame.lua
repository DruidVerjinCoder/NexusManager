local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local LogFrame = {}
NM.LogFrame = LogFrame

-- Initialisiere die Logs-Tabelle
NM.logs = NM.logs or {}

-- Log Kategorien und Window Config
LogFrame.CATEGORIES = {
    CHALLENGE = "CHALLENGE",
    SESSION = "SESSION",
    SYSTEM = "SYSTEM",
    ERROR = "ERROR",
    DEBUG = "DEBUG",
    ITEM = "ITEM"
}

LogFrame.WINDOW_CONFIG = {
    CONTAINER_WIDTH = 1100,
    CONTAINER_HEIGHT = 450,
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

-- Am Anfang der Datei nach den Imports:
LogFrame.currentFilter = {
    category = nil, -- nil bedeutet "Alle"
    searchText = ""
}

local function FormatMetadata(metadata)
    if not metadata then
        return ""
    end

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

local function SerializeValue(val)
    if val == nil then
        return "null"
    elseif type(val) == "string" then
        return string.format("%q", val)
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "table" then
        local parts = {}
        -- Prüfe ob es ein Array ist
        local isArray = true
        local maxIndex = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 then
                isArray = false
                break
            end
            maxIndex = max(maxIndex, k)
        end

        if isArray then
            for i = 1, maxIndex do
                table.insert(parts, SerializeValue(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, string.format("%q:%s", k, SerializeValue(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function LogFrame:ExportLogsAsJSON()
    local logsToExport = {}

    for _, log in ipairs(NM.logs) do
        -- Erstelle eine kopie des logs mit formatierter Zeit
        table.insert(logsToExport, {
            timestamp = date("%Y-%m-%d %H:%M:%S", log.timestamp),
            category = log.category,
            message = log.message,
            metadata = log.metadata
        })
    end

    -- Konvertiere zu JSON mit unserer eigenen Funktion
    local json = SerializeValue(logsToExport)

    -- Erstelle ein neues Fenster für den Export
    local exportFrame = AceGUI:Create("Frame")
    exportFrame:SetTitle(L["Export Logs"])
    exportFrame:SetLayout("Fill")
    exportFrame:SetWidth(600)
    exportFrame:SetHeight(400)

    -- Erstelle ein Editbox für den JSON-Text
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel(L["Copy the following text:"])
    editBox:SetFullWidth(true)
    editBox:SetFullHeight(true)
    editBox:SetText(json)
    editBox:HighlightText()
    editBox:SetFocus()
    exportFrame:AddChild(editBox)
end

function LogFrame:Show()
    if self.frame then
        self.frame:Show()
        NM:Log("DEBUG", "LogFrame: Showing existing frame")
        self:UpdateLogDisplay()
        return
    end

    NM:Log("DEBUG", "LogFrame: Creating new frame")
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["Log Viewer"])
    frame:SetLayout("Flow")
    frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH)
    frame:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT)

    -- Verstecke die Resize-Elemente
    if frame.sizer_se then
        frame.sizer_se:Hide()
    end
    if frame.sizer_s then
        frame.sizer_s:Hide()
    end
    if frame.sizer_e then
        frame.sizer_e:Hide()
    end

    self.frame = frame

    -- Filter Container
    local filterContainer = AceGUI:Create("SimpleGroup")
    filterContainer:SetLayout("Flow")
    filterContainer:SetFullWidth(true)
    filterContainer:SetHeight(30)

    -- Kategorie Filter Dropdown
    local categoryFilter = AceGUI:Create("Dropdown")
    categoryFilter:SetLabel(L["Category"])
    categoryFilter:SetWidth(200)
    categoryFilter:SetRelativeWidth(0.2)

    -- Erstelle Liste aller Kategorien
    local categories = {
        [""] = L["All Categories"]
    }
    for _, category in pairs(self.CATEGORIES) do
        local displayName = category:sub(1, 1) .. category:sub(2):lower()
        categories[category] = displayName
    end
    categoryFilter:SetList(categories)
    categoryFilter:SetValue(self.currentFilter.category or "")
    categoryFilter:SetCallback("OnValueChanged", function(_, _, value)
        self.currentFilter.category = value ~= "" and value or nil
        self:UpdateLogDisplay()
    end)
    filterContainer:AddChild(categoryFilter)

    -- Spacer zwischen Dropdown und Suchfeld
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetWidth(20)
    filterContainer:AddChild(spacer1)

    -- Suchfeld
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(L["Search"])
    searchBox:SetWidth(300)
    searchBox:SetRelativeWidth(0.3)  -- 30% der verfügbaren Breite
    searchBox:SetCallback("OnTextChanged", function(_, _, text)
        self.currentFilter.searchText = text:lower()
        self:UpdateLogDisplay()
    end)
    filterContainer:AddChild(searchBox)

    -- Spacer zwischen Suchfeld und Eintragsanzahl
    local spacer2 = AceGUI:Create("Label")
    spacer2:SetWidth(20)
    filterContainer:AddChild(spacer2)

    -- Anzeige der Eintragsanzahl
    self.filterInfo = AceGUI:Create("Label")
    self.filterInfo:SetWidth(150)
    self.filterInfo:SetRelativeWidth(0.15)  -- 15% der verfügbaren Breite
    filterContainer:AddChild(self.filterInfo)

    -- Spacer zwischen filterInfo und Clear-Button
    local spacer3 = AceGUI:Create("Label")
    spacer3:SetWidth(20)
    filterContainer:AddChild(spacer3)

    -- Clear Button
    local clearButton = NM.UIFunctions:createButton(L["Clear"], 100, function()
        NM.logs = {}
        self:UpdateLogDisplay()
    end)
    clearButton:SetRelativeWidth(0.1)
    filterContainer:AddChild(clearButton)

    -- Spacer zwischen Clear-Button und Export-Button
    local spacer4 = AceGUI:Create("Label")
    spacer4:SetWidth(20)
    filterContainer:AddChild(spacer4)

    -- Export Button
    local exportButton = NM.UIFunctions:createButton(L["Export"], 100, function()
        self:ExportLogsAsJSON()
    end)
    exportButton:SetRelativeWidth(0.1)
    filterContainer:AddChild(exportButton)

    frame:AddChild(filterContainer)

    -- Spacer zwischen Filter-Container und Header
    local spacerBeforeHeader = AceGUI:Create("SimpleGroup")
    spacerBeforeHeader:SetFullWidth(true)
    spacerBeforeHeader:SetHeight(10)
    frame:AddChild(spacerBeforeHeader)

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
    self.timeHeader:SetCallback("OnClick", function()
        self:SortBy("TIME")
    end)
    headerContainer:AddChild(self.timeHeader)

    -- Kategorie Header
    self.categoryHeader = AceGUI:Create("InteractiveLabel")
    self.categoryHeader:SetText(self.WINDOW_CONFIG.COLUMNS.CATEGORY.name)
    self.categoryHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.CATEGORY.width)
    self.categoryHeader:SetCallback("OnClick", function()
        self:SortBy("CATEGORY")
    end)
    headerContainer:AddChild(self.categoryHeader)

    -- Message Header
    self.messageHeader = AceGUI:Create("InteractiveLabel")
    self.messageHeader:SetText(self.WINDOW_CONFIG.COLUMNS.MESSAGE.name)
    self.messageHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.MESSAGE.width)
    self.messageHeader:SetCallback("OnClick", function()
        self:SortBy("MESSAGE")
    end)
    headerContainer:AddChild(self.messageHeader)

    -- Data Header
    self.dataHeader = AceGUI:Create("InteractiveLabel")
    self.dataHeader:SetText(self.WINDOW_CONFIG.COLUMNS.DATA.name)
    self.dataHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.DATA.width)
    self.dataHeader:SetCallback("OnClick", function()
        self:SortBy("DATA")
    end)
    headerContainer:AddChild(self.dataHeader)

    frame:AddChild(headerContainer)

    -- Scrollframe für Logs
    self.scrollframe = AceGUI:Create("ScrollFrame")
    self.scrollframe:SetLayout("List")
    self.scrollframe:SetFullWidth(true)
    self.scrollframe:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT - self.WINDOW_CONFIG.HEADER_HEIGHT - 120)
    self.scrollframe.frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH - 20)
    frame:AddChild(self.scrollframe)

    -- Nur EINMAL beim ersten Öffnen die Logs laden
    self:UpdateLogDisplay()
end

function LogFrame:UpdateLogDisplay()
    if not self.scrollframe then
        return
    end

    self.scrollframe:ReleaseChildren()

    local logsList = {}

    -- Filtere Logs basierend auf Kategorie und Suchtext
    for _, log in ipairs(NM.logs) do
        local matchesCategory = not self.currentFilter.category or
                log.category:upper() == self.currentFilter.category:upper()
        local matchesSearch = self.currentFilter.searchText == "" or
                log.message:lower():find(self.currentFilter.searchText, 1, true) or
                FormatMetadata(log.metadata):lower():find(self.currentFilter.searchText, 1, true)

        if matchesCategory and matchesSearch then
            table.insert(logsList, log)
        end
    end

    -- Update Anzahl der Einträge im Filter-Info Label
    if self.filterInfo then
        self.filterInfo:SetText(string.format(L["Showing %d entries"], #logsList))
    end

    -- Sortiere gefilterte Liste
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
                aValue = FormatMetadata(a.metadata)
                bValue = FormatMetadata(b.metadata)
            end

            if self.currentSort.ascending then
                return aValue < bValue
            else
                return aValue > bValue
            end
        end)
    end

    -- Zeige gefilterte und sortierte Logs
    for _, log in ipairs(logsList) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        row:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)
        row.frame:SetWidth(self.WINDOW_CONFIG.CONTAINER_WIDTH - 20)

        -- Container für alle Spalten
        local contentGroup = AceGUI:Create("SimpleGroup")
        contentGroup:SetLayout("Flow")
        contentGroup:SetFullWidth(true)
        contentGroup:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)

        -- Zeit
        local time = AceGUI:Create("Label")
        time:SetText(date("%H:%M:%S", log.timestamp))
        time:SetWidth(self.WINDOW_CONFIG.COLUMNS.TIME.width)
        time.label:SetJustifyH("LEFT")
        contentGroup:AddChild(time)

        -- Kategorie
        local category = AceGUI:Create("Label")
        category:SetText(log.category)
        category:SetWidth(self.WINDOW_CONFIG.COLUMNS.CATEGORY.width)
        category.label:SetJustifyH("LEFT")
        contentGroup:AddChild(category)

        -- Message
        local message = AceGUI:Create("Label")
        message:SetText(log.message)
        message:SetWidth(self.WINDOW_CONFIG.COLUMNS.MESSAGE.width)
        message.label:SetJustifyH("LEFT")
        contentGroup:AddChild(message)

        -- Data-Spalte
        local dataContainer = AceGUI:Create("SimpleGroup")
        dataContainer:SetLayout("Fill")
        dataContainer:SetWidth(self.WINDOW_CONFIG.COLUMNS.DATA.width)
        dataContainer:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)

        local dataText = AceGUI:Create("Label")

        -- Formatiere den Text basierend auf der Kategorie
        local displayText = ""
        if log.category == "ITEM" and log.metadata and log.metadata.itemLink then
            local itemData = log.metadata.itemData or {}

            displayText = string.format(
                    "%s | Qty: %d | iLvl: %s | %s | %s | %s",
                    log.metadata.itemLink or "N/A",
                    log.metadata.count or 1,
                    itemData.ilvl or "N/A",
                    itemData.quality or "N/A",
                    itemData.type or "N/A",
                    itemData.subType or "N/A"
            )
        else
            displayText = FormatMetadata(log.metadata)
        end

        dataText:SetText(displayText)
        dataText:SetWidth(self.WINDOW_CONFIG.COLUMNS.DATA.width)
        dataText.label:SetJustifyH("LEFT")
        dataText.label:SetWordWrap(true)

        dataContainer:AddChild(dataText)
        contentGroup:AddChild(dataContainer)
        row:AddChild(contentGroup)
        self.scrollframe:AddChild(row)
    end

    NM:Log("DEBUG", "LogFrame: Display update complete")
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
    if not message then
        return
    end

    local upperCategory = category and category:upper() or self.CATEGORIES.SYSTEM

    -- Wenn es ein Item ist, sammle zusätzliche Item-Daten
    if upperCategory == "ITEM" and metadata and metadata.itemLink then
        metadata.itemData = self:GetItemData(metadata.itemLink)
    end

    local logEntry = {
        timestamp = time(),
        category = upperCategory,
        message = message,
        metadata = metadata or {}
    }

    table.insert(NM.logs, logEntry)
end

-- Optional: Methode zum Zurücksetzen der Filter
function LogFrame:ResetFilters()
    self.currentFilter.category = nil
    self.currentFilter.searchText = ""
    if self.frame then
        self:UpdateLogDisplay()
    end
end

-- Hilfsfunktion zum Sammeln von Item-Informationen (am Anfang der Datei nach den Kategorien)
function LogFrame:GetItemData(itemLink)
    if not itemLink then
        return nil
    end

    local itemID = itemLink:match("item:(%d+)")
    if not itemID then
        return nil
    end

    local itemName, _, itemRarity, itemLevel, itemMinLevel, itemType,
    itemSubType, _, itemEquipLoc, itemTexture = C_Item.GetItemInfo(itemLink)

    return {
        id = itemID,
        name = itemName,
        link = itemLink,
        rarity = itemRarity,
        ilvl = itemLevel,
        minLevel = itemMinLevel,
        type = itemType,
        subType = itemSubType,
        equipSlot = itemEquipLoc,
        texture = itemTexture,
        quality = _G["ITEM_QUALITY" .. (itemRarity or 0) .. "_DESC"]
    }
end

NM.LogFrame = LogFrame
