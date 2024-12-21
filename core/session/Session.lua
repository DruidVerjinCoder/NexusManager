local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
local LibStub = LibStub
LibStub("AceSerializer-3.0"):Embed(NM)

-- Global Messages From WoW - API
local INSTANCE_RESET_SUCCESS, OKAY, LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, AMOUNT_RECEIVED_COLON =
    INSTANCE_RESET_SUCCESS
    , OKAY,
    LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, AMOUNT_RECEIVED_COLON

local PATTERN_LOOT_ITEM_SELF = LOOT_ITEM_SELF:gsub("%%s", "(.+)")
local PATTERN_LOOT_ITEM_SELF_MULTIPLE = LOOT_ITEM_SELF_MULTIPLE:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")


local session = {
    start = time(),
    currentGold = GetMoney(),
    totalGold = 0,
    lootedGold = 0,
    location = nil,
    class = L[select(1, UnitClass("player"))],
    state = nil,
    pauseStart = nil,
    sessionPause = nil,
    liv = 0,
    uncommon = 0,
    rare = 0,
    epic = 0,
    items = {}
}

function session:init()
    self:reset()
end

function session:reset()
    session.start = time()
    session.currentGold = GetMoney()
    session.totalGold = 0
    session.lootedGold = 0
    session.uncommon = 0
    session.rare = 0
    session.epic = 0
    session.instance = nil
    session.items = {}

    if IsInInstance then
        local instanceInfo = GetInstanceInfo()
        session.instance = {}
        session.instance.name = select(1, instanceInfo)
        session.instance.type = select(2, instanceInfo)
        session.instance.difficulty = select(3, instanceInfo)
        session.instanceRuns = 1
        session.farmName = session.instance.name
    else
        session.instance = nil
        session.instanceRuns = 0
        session.farmName = nil
    end

    session.lootedItems = {}
    session.state = nil
end

function session:itemLooted(event, message)
    if self.state ~= "running" then return end
    
    local itemLink, quantity
    
    -- Prüfe auf Mehrfach-Drops
    local item, count = message:match(PATTERN_LOOT_ITEM_SELF_MULTIPLE)
    if item and count then
        itemLink = item
        quantity = tonumber(count)
    else
        -- Prüfe auf Einzel-Drops
        itemLink = message:match(PATTERN_LOOT_ITEM_SELF)
        quantity = 1
    end
    
    -- Wenn kein Item gefunden wurde, beende
    if not itemLink then return end
    
    -- Hole ItemID und füge es hinzu
    local itemID = self:ToItemID(itemLink)
    if not itemID then return end
    
    -- Füge Item zur Session hinzu
    self:addItem(itemID, quantity)
    NM:Log(string.format("Looted: %s x%d", itemLink, quantity))
    
    -- Aktualisiere UI
    if NM.ItemsContainer then
        NM.ItemsContainer:Update()
    end
end

function session:moneyLooted(event, msg)
end

function session:moneyChanged()
end

function session:zoneSwitched(self, event)
end

function session:addItem(itemID, quantity)
    -- Initialisiere Item-Eintrag falls nicht vorhanden
    if not self.items[itemID] then
        self.items[itemID] = {
            quantity = 0,
            value = NM.TSM.GetItemValue(itemID, "DBRegionSaleAvg") or 0
        }
    end
    
    -- Aktualisiere Quantity
    self.items[itemID].quantity = self.items[itemID].quantity + quantity
    
    -- Aktualisiere LIV
    self.liv = self.liv + (self.items[itemID].value * quantity)
    
    -- Aktualisiere Qualitäts-Counter
    local _, _, quality =  C_Item.GetItemInfo(itemID)
    if quality then
        if quality == 2 then
            self.uncommon = self.uncommon + quantity
        elseif quality == 3 then
            self.rare = self.rare + quantity
        elseif quality == 4 then
            self.epic = self.epic + quantity
        end
    end
end

function session:GetPostrunMsg()
    if session.state then
        local msg = "!postrun " .. session.farmName .. "\n" ..
            L["Class: "] .. L[session.class] .. "\n" ..
            L["Duration: "] .. session:GetDurationString(session.start) .. "\n" ..
            L["LIV: "] .. session:FormatGold(session.liv) .. "\n" ..
            L["Uncommon: "] .. self:GetUncommonCount() .. "\n" ..
            L["Rare: "] .. self:GetRareCount() .. "\n" ..
            L["Epic: "] .. self:GetEpicCount() .. "\n" ..
            L["Gold looted: "] .. session:FormatGold(session.lootedGold) .. "\n" ..
            L["Gold total: "] .. session:FormatGold(session.totalGold) .. "\n" ..
            L["Annotation: "] .. "-"
        ;

        if self.itemsLooted and next(self.itemsLooted) then
            NM:Log("ItemsLooted: " .. NM.Utils.tableToString(self.itemsLooted))
            for itemID, count in pairs(self.itemsLooted) do
                if NM.DB:ShouldTrackItem(itemID) then
                    local itemName, _, itemRarity = C_Item.GetItemInfo(itemID)
                    if itemName then
                        local _, _, _, hexColor =  C_Item.GetItemQualityColor(itemRarity)
                        msg = msg .. "\n- " .. string.format("|c%s%s|r x%d", hexColor, itemName, count)
                    end
                end
            end
        end 
        return msg;
    end

    return L["LA not running or paused. Please start or resume the session."]
end

function session:start()
    NM.session:init()
    NM.session.state = 'running'
    NM:Print(L["Session was started"])
end

function session:continue()
    NM.session.state = 'running'
end

function session:restart()
    NM.session:init()
    NM.session.state = 'running'
    NM:Print(L["Session was restarted"])
end

function session:pause()
    NM.session.state = 'paused'
    NM:Print(L["Session was paused"])
end

function session:GetDurationString(deltaTime)
    local offset = NM.session.pauseStart or time()
    local duration = offset - (deltaTime or time()) - (session.sessionPause or 0)
    local hours, minutes, seconds = session:CalculateTime(duration)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

--- Berechnet Stunden, Minuten und Sekunden aus einer Dauer in Sekunden
--- @param duration number Dauer in Sekunden
--- @return number Stunden
--- @return number Minuten
--- @return number Sekunden
function session:CalculateTime(duration)
    local hours = math.floor(duration / 3600) % 24
    local minutes = math.floor(duration / 60) % 60
    local seconds = duration % 60
    return hours, minutes, seconds
end

--- Formatierter Goldwert
--- @param value number Goldwert
--- @return string Formatierter Goldwert (z.B. "1,2345")
function session:FormatGold(value)
    local goldValue = tostring(value)
    if not goldValue or goldValue == "nil" then
        return "0,0000"
    end

    local pos = #goldValue - 4
    if pos < 0 then
        -- Füge führende 0 hinzu, wenn der Wert kleiner als 1 Gold ist
        return "0," .. string.rep("0", -pos) .. goldValue
    else
        -- Füge Komma zwischen Gold und Silber ein
        local gold = goldValue:sub(1, pos)
        if gold == "" then gold = "0" end  -- Wenn kein Gold-Teil, dann "0" verwenden
        return gold .. "," .. goldValue:sub(pos + 1)
    end
end

function session:PrintItem(itemID)
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc,
    itemTexture, sellPrice, classID,
    subclassID, bindType, expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemID)

    NM:Print("Item Info:")
    NM:Print("  Name: " .. itemName)
    NM:Print("  Link: " .. itemLink)
    NM:Print("  Quality: " .. itemQuality)
    NM:Print("  Level: " .. itemLevel)
    NM:Print("  Min Level: " .. itemMinLevel)
    NM:Print("  Type: " .. itemType)
    NM:Print("  SubType: " .. itemSubType)
    NM:Print("  Stack Count: " .. itemStackCount)
    NM:Print("  Equip Loc: " .. itemEquipLoc)
    NM:Print("  Texture: " .. itemTexture)
    NM:Print("  Sell Price: " .. sellPrice)
    NM:Print("  Class ID: " .. classID)
    NM:Print("  Subclass ID: " .. subclassID)
    NM:Print("  Bind Type: " .. bindType)
    NM:Print("  Expansion ID: " .. expacID)
    if setID then
        NM:Print("  Set ID: " .. setID)
    end
    NM:Print("  Crafting Reagent: " .. (isCraftingReagent and "Yes" or "No"))
    NM:Print("======================")
end

function session:ToItemID(itemString)
    if not itemString then
        return
    end

    --local printable = gsub(itemString, "\124", "\124\124");
    --ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");

    --local itemId = LA.TSM.GetItemID(itemString)

    local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, reforging, Name = string
        .find(itemString,
            "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

    --ChatFrame1:AddMessage("Id: " .. Id .. " vs. " .. itemId);
    return tonumber(Id)
end

function session:GetItems()
    print("GetItems for Table")
    local itemsList = {}
    
    -- Konvertiere die Items in das erwartete Format
    for itemID, itemData in pairs(self.items) do
        local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        
        -- Nur hinzufügen wenn Item-Info verfügbar
        if itemName then
            table.insert(itemsList, {
                id = itemID,
                name = itemName,
                link = itemLink,
                icon = itemIcon,
                quality = itemQuality,
                quantity = itemData.quantity or 0,
                value = itemData.value or 0
            })
        end
    end
    return itemsList
end

--- Zählt Items nach Rarität
--- @param rarity number Die Rarität (2=Uncommon, 3=Rare, 4=Epic)
--- @return number Anzahl der Items mit der angegebenen Rarität
function session:GetItemCountByRarity(rarity)
    local count = 0
    for itemID, itemData in pairs(self.items) do
        local _, _, quality = C_Item.GetItemInfo(itemID)
        if quality == rarity then
            count = count + itemData.quantity
        end
    end
    return count
end

--- Gibt die Anzahl aller Uncommon (grünen) Items zurück
--- @return number Anzahl der Uncommon Items
function session:GetUncommonCount()
    return self:GetItemCountByRarity(2)
end

--- Gibt die Anzahl aller Rare (blauen) Items zurück
--- @return number Anzahl der Rare Items
function session:GetRareCount()
    return self:GetItemCountByRarity(3)
end

--- Gibt die Anzahl aller Epic (lila) Items zurück
--- @return number Anzahl der Epic Items
function session:GetEpicCount()
    return self:GetItemCountByRarity(4)
end

NM.session = session;
