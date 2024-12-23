local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local ItemsContainer = {
    WINDOW_CONFIG = {
        CONTAINER_WIDTH = 200,
        CONTAINER_HEIGHT = 450,
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
                width = 95,
                name = L["Name"]
            },
            QUANTITY = {
                width = 30,
                name = L["Qty"]
            },
            VALUE = {
                width = 160,
                name = L["Value"]
            }
        }
    },
    container = nil
}

local function createItemRow(item)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(ItemsContainer.WINDOW_CONFIG.ROW_HEIGHT)

    -- Icon mit Tooltip
    local icon = AceGUI:Create("Icon")
    icon:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.ICON.width)
    icon:SetHeight(ItemsContainer.WINDOW_CONFIG.ROW_HEIGHT)
    icon:SetImage(item.icon)
    icon:SetImageSize(ItemsContainer.WINDOW_CONFIG.ROW_HEIGHT - 5, ItemsContainer.WINDOW_CONFIG.ROW_HEIGHT - 5)
    
    -- Tooltip für Icon
    icon:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(icon.frame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(item.link)
        GameTooltip:Show()
    end)
    icon:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:AddChild(icon)

    -- Name mit Tooltip (kompakter)
    local name = AceGUI:Create("InteractiveLabel")
    name:SetText(item.link or item.name)
    name:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.NAME.width)
    name:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(name.frame, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(item.link)
        GameTooltip:Show()
    end)
    name:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:AddChild(name)

    -- Quantity (kompakter)
    local quantity = AceGUI:Create("Label")
    quantity:SetText(item.quantity)
    quantity:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
    row:AddChild(quantity)

    -- Value (kompakter)
    local value = AceGUI:Create("Label")
    value:SetText(NM.UIFunctions:FormatGold(item.value * item.quantity))
    value:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.VALUE.width)
    row:AddChild(value)

    return row
end

local function createTotalRow(totalValue)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(ItemsContainer.WINDOW_CONFIG.FOOTER_HEIGHT)

    -- Leere Zelle für Icon
    local emptyIcon = AceGUI:Create("Label")
    emptyIcon:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.ICON.width)
    row:AddChild(emptyIcon)

    -- "Total" Label
    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText("Total:")
    totalLabel:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.NAME.width)
    row:AddChild(totalLabel)

    -- Leere Zelle für Quantity
    local emptyQty = AceGUI:Create("Label")
    emptyQty:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
    row:AddChild(emptyQty)

    -- Total Value
    local value = AceGUI:Create("Label")
    value:SetText(NM.UIFunctions:FormatGold(totalValue))
    value:SetWidth(ItemsContainer.WINDOW_CONFIG.COLUMNS.VALUE.width)
    row:AddChild(value)

    return row
end

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

    self:Update()
end

-- Public methods
function ItemsContainer:Create()
    if not self.container then
        -- Hauptcontainer als SimpleGroup
        self.container = AceGUI:Create("SimpleGroup")
        self.container:SetLayout("List")
        self.container:SetFullWidth(true)
        self.container:SetHeight(self.WINDOW_CONFIG.CONTAINER_HEIGHT)
        
        -- Sortierbuttons Container
        local sortContainer = AceGUI:Create("SimpleGroup")
        sortContainer:SetLayout("Flow")
        sortContainer:SetFullWidth(true)
        sortContainer:SetHeight(self.WINDOW_CONFIG.SORT_BUTTON_HEIGHT)
        
        -- Kompakte Sortierbuttons
        local nameSort = AceGUI:Create("Button")
        nameSort:SetText("Name")
        nameSort:SetWidth(100)
        nameSort:SetCallback("OnClick", function() self:SortBy("NAME") end)
        sortContainer:AddChild(nameSort)
        
        local qtySort = AceGUI:Create("Button")
        qtySort:SetText("Qty")
        qtySort:SetWidth(70)
        qtySort:SetCallback("OnClick", function() self:SortBy("QUANTITY") end)
        sortContainer:AddChild(qtySort)
        
        local valueSort = AceGUI:Create("Button")
        valueSort:SetText("Value")
        valueSort:SetWidth(150)
        valueSort:SetCallback("OnClick", function() self:SortBy("VALUE") end)
        sortContainer:AddChild(valueSort)
        
        self.container:AddChild(sortContainer)
        
        -- Scrollframe für Items
        self.scrollframe = AceGUI:Create("ScrollFrame")
        self.scrollframe:SetLayout("List")
        self.scrollframe:SetFullWidth(true)
        -- Neue Höhenberechnung: Container - Sortierbuttons - Footer
        local scrollHeight = self.WINDOW_CONFIG.CONTAINER_HEIGHT - 
                           (self.WINDOW_CONFIG.SORT_BUTTON_HEIGHT + 100) - 
                           (self.WINDOW_CONFIG.FOOTER_HEIGHT + 15)
        self.scrollframe:SetHeight(scrollHeight)
        self.container:AddChild(self.scrollframe)
        
        -- Total Row (fixiert am unteren Rand)
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
    
    -- Sammle NUR Items aus der eigenen Session
    if NM.session and NM.session.items then
        for itemID, quantity in pairs(NM.session.items) do
            -- Prüfe ob quantity eine Zahl oder eine Tabelle ist
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
    
    -- Debug Ausgabe
    for itemID, data in pairs(sessionItems) do
        NM:Debug("ItemsContainer: Own Item %d has quantity %d", itemID, data.quantity)
    end
    
    -- Konvertiere in Array für Sortierung
    local itemsList = {}
    local totalValue = 0
    
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
    for _, item in ipairs(itemsList) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        
        -- Icon
        local icon = AceGUI:Create("Icon")
        icon:SetImage(item.icon)
        icon:SetImageSize(self.WINDOW_CONFIG.COLUMNS.ICON.width, self.WINDOW_CONFIG.COLUMNS.ICON.width)
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
    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText("Total:")
    totalLabel:SetWidth(self.WINDOW_CONFIG.COLUMNS.NAME.width)
    self.totalRow:AddChild(totalLabel)
    
    local emptyQty = AceGUI:Create("Label")
    emptyQty:SetWidth(self.WINDOW_CONFIG.COLUMNS.QUANTITY.width)
    self.totalRow:AddChild(emptyQty)
    
    local value = AceGUI:Create("Label")
    value:SetText(NM.UIFunctions:FormatGold(totalValue))
    value:SetWidth(self.WINDOW_CONFIG.COLUMNS.VALUE.width)
    self.totalRow:AddChild(value)
end

NM.ItemsContainer = ItemsContainer