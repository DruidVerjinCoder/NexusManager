local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local ItemsContainer = {
    WINDOW_CONFIG = {
        CONTAINER_WIDTH = 200,
        CONTAINER_HEIGHT = 300,
        HEADER_HEIGHT = 25,
        FOOTER_HEIGHT = 25,
        ROW_HEIGHT = 25,
        SORT_BUTTON_HEIGHT = 20,
        COLUMNS = {
            ICON = {
                width = 25,
                name = ""
            },
            NAME = {
                width = 125,
                name = L["Name"]
            },
            QUANTITY = {
                width = 50,
                name = L["Qty"]
            },
            VALUE = {
                width = 110,
                name = L["Value"]
            }
        }
    },
    container = nil
}

-- Sortierlogik
function ItemsContainer:SortBy(columnKey)
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

    -- Sammle und sortiere Items direkt
    local itemsList = {}
    local totalValue = 0
    
    -- Sammle NUR Items aus der eigenen Session
    if NM.session and NM.session.items then
        for itemID, quantity in pairs(NM.session.items) do
            local actualQuantity = type(quantity) == "table" and (quantity.quantity or 0) or quantity
            local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
            if itemName then
                local itemValue = select(11, C_Item.GetItemInfo(itemID)) or 0
                table.insert(itemsList, {
                    id = itemID,
                    name = itemName,
                    link = itemLink,
                    icon = itemIcon,
                    quantity = actualQuantity,
                    value = itemValue
                })
                totalValue = totalValue + (itemValue * actualQuantity)
            end
        end
    end
    
    -- Sortiere die Liste
    table.sort(itemsList, function(a, b)
        if self.currentSort.column == "NAME" then
            if self.currentSort.ascending then
                return a.name < b.name
            else
                return a.name > b.name
            end
        elseif self.currentSort.column == "QUANTITY" then
            if self.currentSort.ascending then
                return a.quantity < b.quantity
            else
                return a.quantity > b.quantity
            end
        elseif self.currentSort.column == "VALUE" then
            local aTotal = a.value * a.quantity
            local bTotal = b.value * b.quantity
            if self.currentSort.ascending then
                return aTotal < bTotal
            else
                return aTotal > bTotal
            end
        end
    end)
    
    -- Update die Sortier-Icons
    self:UpdateSortIndicators()
    
    -- Update die Anzeige mit der sortierten Liste
    self:UpdateDisplay(itemsList, totalValue)
end

-- Neue Funktion für die Anzeige
function ItemsContainer:UpdateDisplay(itemsList, totalValue)
    if not self.scrollframe then return end
    self.scrollframe:ReleaseChildren()
    
    -- Zeige sortierte Items an
    for index, item in ipairs(itemsList) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        row:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)
        
        -- Alternierender Hintergrund
        if index % 2 == 0 then
            local bg = row.frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        -- Icon
        local icon = AceGUI:Create("Icon")
        icon:SetImage(item.icon)
        icon:SetImageSize(self.WINDOW_CONFIG.ROW_HEIGHT - 5, self.WINDOW_CONFIG.ROW_HEIGHT - 5)
        icon:SetWidth(self.WINDOW_CONFIG.COLUMNS.ICON.width)
        row:AddChild(icon)
        
        -- Name
        local name = AceGUI:Create("InteractiveLabel")
        name:SetText(item.link)
        name:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width)
        row:AddChild(name)
        
        -- Quantity
        local qty = AceGUI:Create("Label")
        qty:SetText(item.quantity)
        qty:SetWidth(self.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
        row:AddChild(qty)
        
        -- Value
        local value = AceGUI:Create("Label")
        value:SetText(NM.UIFunctions:FormatGold(item.value * item.quantity))
        value:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
        row:AddChild(value)
        
        self.scrollframe:AddChild(row)
    end
    
    -- Update Total Row
    self.totalRow:ReleaseChildren()
    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText("Total:")
    totalLabel:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width + self.WINDOW_CONFIG.COLUMNS.ICON.width)
    self.totalRow:AddChild(totalLabel)
    
    local value = AceGUI:Create("Label")
    value:SetText(NM.UIFunctions:FormatGold(totalValue))
    value:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
    self.totalRow:AddChild(value)
end

-- Public methods
function ItemsContainer:Create()
    if not self.container then
        -- Hauptcontainer als SimpleGroup
        self.container = AceGUI:Create("SimpleGroup")
        self.container:SetLayout("List")
        self.container:SetFullWidth(true)
        self.container:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT)
        
        -- Header Container
        local headerContainer = AceGUI:Create("SimpleGroup")
        headerContainer:SetLayout("Flow")
        headerContainer:SetFullWidth(true)
        headerContainer:SetHeight(self.WINDOW_CONFIG.HEADER_HEIGHT)
        
        -- Icon Spalte (leer für Ausrichtung)
        local iconHeader = AceGUI:Create("Label")
        iconHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.ICON.width)
        headerContainer:AddChild(iconHeader)
        
        -- Name Header mit Sortierung
        self.nameHeader = AceGUI:Create("InteractiveLabel")
        self.nameHeader:SetText("Item")
        self.nameHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width)
        self.nameHeader:SetCallback("OnClick", function() self:SortBy("NAME") end)
        headerContainer:AddChild(self.nameHeader)
        
        -- Quantity Header mit Sortierung
        self.qtyHeader = AceGUI:Create("InteractiveLabel")
        self.qtyHeader:SetText("Qty")
        self.qtyHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
        self.qtyHeader:SetCallback("OnClick", function() self:SortBy("QUANTITY") end)
        headerContainer:AddChild(self.qtyHeader)
        
        -- Value Header mit Sortierung
        self.valueHeader = AceGUI:Create("InteractiveLabel")
        self.valueHeader:SetText("LIV")
        self.valueHeader:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
        self.valueHeader:SetCallback("OnClick", function() self:SortBy("VALUE") end)
        headerContainer:AddChild(self.valueHeader)
        
        self.container:AddChild(headerContainer)
        
        -- Scrollframe für Items
        self.scrollframe = AceGUI:Create("ScrollFrame")
        self.scrollframe:SetLayout("List")
        self.scrollframe:SetFullWidth(true)
        local scrollHeight = self.WINDOW_CONFIG.CONTAINER_HEIGHT - 
                           self.WINDOW_CONFIG.HEADER_HEIGHT - 
                           self.WINDOW_CONFIG.FOOTER_HEIGHT
        self.scrollframe:SetHeight(scrollHeight)
        self.container:AddChild(self.scrollframe)
        
        -- Total Row
        self.totalRow = AceGUI:Create("SimpleGroup")
        self.totalRow:SetLayout("Flow")
        self.totalRow:SetFullWidth(true)
        self.totalRow:SetHeight(self.WINDOW_CONFIG.FOOTER_HEIGHT)
        self.container:AddChild(self.totalRow)
    end
    
    self:Update()
    return self.container
end

function ItemsContainer:Update()
    if not self.container then return end
    
    -- Nur Items im Scrollframe aktualisieren
    self.scrollframe:ReleaseChildren()
    
    local sessionItems = {}
    local totalValue = 0
    
    -- Sammle NUR Items aus der eigenen Session
    if NM.session and NM.session.items then
        for itemID, quantity in pairs(NM.session.items) do
            local actualQuantity = type(quantity) == "table" and (quantity.quantity or 0) or quantity
            
            if not sessionItems[itemID] then
                sessionItems[itemID] = {
                    quantity = 0,
                    id = itemID
                }
            end
            sessionItems[itemID].quantity = sessionItems[itemID].quantity + actualQuantity
        end
    end
    
    -- Konvertiere in Array für Sortierung
    local itemsList = {}
    
    for itemID, itemData in pairs(sessionItems) do
        local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        if itemName then
            local itemValue = select(11, C_Item.GetItemInfo(itemID)) or 0
            table.insert(itemsList, {
                id = itemID,
                name = itemName,
                link = itemLink,
                icon = itemIcon,
                quantity = itemData.quantity,
                value = itemValue
            })
            totalValue = totalValue + (itemValue * itemData.quantity)
        end
    end
    
    -- Sortiere Items
    table.sort(itemsList, function(a, b)
        if a.value == b.value then
            return a.name < b.name
        end
        return a.value > b.value
    end)
    
    -- Zeige Items an
    for index, item in ipairs(itemsList) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        row:SetHeight(self.WINDOW_CONFIG.ROW_HEIGHT)
        
        -- Alternierender Hintergrund
        if index % 2 == 0 then
            local bg = row.frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        -- Icon
        local icon = AceGUI:Create("Icon")
        icon:SetImage(item.icon)
        icon:SetImageSize(self.WINDOW_CONFIG.ROW_HEIGHT - 5, self.WINDOW_CONFIG.ROW_HEIGHT - 5)
        icon:SetWidth(self.WINDOW_CONFIG.COLUMNS.ICON.width)
        row:AddChild(icon)
        
        -- Name
        local name = AceGUI:Create("InteractiveLabel")
        name:SetText(item.link)
        name:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width)
        row:AddChild(name)
        
        -- Quantity
        local qty = AceGUI:Create("Label")
        qty:SetText(item.quantity)
        qty:SetWidth(self.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
        row:AddChild(qty)
        
        -- Value
        local value = AceGUI:Create("Label")
        value:SetText(NM.UIFunctions:FormatGold(item.value * item.quantity))
        value:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
        row:AddChild(value)
        
        self.scrollframe:AddChild(row)
    end
    
    -- Update Total Row
    self.totalRow:ReleaseChildren()
    
    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText("Total:")
    totalLabel:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width + self.WINDOW_CONFIG.COLUMNS.ICON.width)
    self.totalRow:AddChild(totalLabel)
    
    local value = AceGUI:Create("Label")
    value:SetText(NM.UIFunctions:FormatGold(totalValue))
    value:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
    self.totalRow:AddChild(value)
end

function ItemsContainer:UpdateSortIndicators()
    -- Setze Basis-Texte
    local nameText = "Item"
    local qtyText = "Qty"
    local valueText = "LIV"
    
    -- Füge Sortier-Indikatoren hinzu
    if self.currentSort then
        -- Größere Icons (12x12) und besseres Spacing
        local arrow = self.currentSort.ascending and 
            "|TInterface/BUTTONS/Arrow-Up-Up:12:12:0:0:1:1|t" or  -- Format: path:height:width:xOffset:yOffset
            "|TInterface/BUTTONS/Arrow-Down-Up:12:12:0:0:1:1|t"
        
        if self.currentSort.column == "NAME" then
            nameText = nameText .. "  " .. arrow  -- Doppeltes Leerzeichen für besseren Abstand
        elseif self.currentSort.column == "QUANTITY" then
            qtyText = qtyText .. "  " .. arrow
        elseif self.currentSort.column == "VALUE" then
            valueText = valueText .. "  " .. arrow
        end
    end
    
    -- Update Header-Texte
    self.nameHeader:SetText(nameText)
    self.qtyHeader:SetText(qtyText)
    self.valueHeader:SetText(valueText)
end

NM.ItemsContainer = ItemsContainer