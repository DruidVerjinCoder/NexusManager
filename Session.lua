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
    currentGold = GetMoney(),
    totalGold = 0,
    lootedGold = 0,
    location = nil,
    class = L[select(1, UnitClass("player"))],
    state = nil,
}

function session:init()
    self:reset()
end

function session:reset()
    session.currentGold = GetMoney()
    session.totalGold = 0
    session.lootedGold = 0
    session.instance = nil

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

function session:itemLooted(event, msg)
    if event then
        local itemLink, quantity = 0, 0
        -- local itemLink =
        if event:match(PATTERN_LOOT_ITEM_SELF_MULTIPLE) then
            itemLink, quantity = string.match(event, PATTERN_LOOT_ITEM_SELF_MULTIPLE)
        elseif event:match(PATTERN_LOOT_ITEM_SELF) then
            itemLink = string.match(event, PATTERN_LOOT_ITEM_SELF)
            quantity = 1
        else
            return
        end
        local itemID = NM.LA.Util.ToItemID(itemLink)
        session:addItem(itemID, quantity)
    end
end

function session:moneyLooted(event, msg)
end

function session:moneyChanged()
end

function session:zoneSwitched(self, event)
end

function session:addItem(itemID, quantity)
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc,
    itemTexture, sellPrice, classID,
    subclassID, bindType, expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemID)
    session:PrintItem(itemID);
end

function session:GetPostrunMsg()
    if session.state then
        local liv, lootedCurrency = 0, 0

        if NM.LA.Session.IsRunning() then
            liv = NM.LA.Session.GetCurrentSession("liv")
            lootedCurrency = NM.LA.Session.GetCurrentSession("totalLootedCurrency")
        end

        local msg = "!postrun " .. session.farmName .. "\n" ..
            L["Class: "] .. L[session.class] .. "\n" ..
            L["Duration: "] .. session:GetDurationString(NM.LA.Session.GetCurrentSession("start")) .. "\n" ..
            L["LIV: "] .. session:FormatGold(liv) .. "\n" ..
            L["Uncommon: "] .. "\n" ..
            L["Rare: "] .. "\n" ..
            L["Epic: "] .. "\n" ..
            L["Gold looted: "] .. session:FormatGold(lootedCurrency) .. "\n" ..
            L["Gold total: "] .. "\n" ..
            L["Annotation: "] .. "-"
        ;
        return msg;
    end

    return L["LA not running or paused. Please start or resume the session."]
end

function session:start()
    NM.session:init()
    NM.LA.Session.Start(true);
    NM.session.state = 'running'
    NM:Print(L["Session was started"])
end

function session:continue()
    NM.LA.Session.Restart();
    NM.session.state = 'running'
end

function session:restart()
    NM.LA.Session.New();
    NM.session:init()
    NM.session.state = 'running'
    NM:Print(L["Session was restarted"])
end

function session:pause()
    NM.LA.Session.Pause();
    NM.session.state = 'paused'
    NM:Print(L["Session was paused"])
end

function session:GetDurationString(deltaTime)
    local offset = NM.LA.Session.GetPauseStart() or time()
    local duration = offset - deltaTime - NM.LA.Session.GetSessionPause()
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
        return "0," .. string.rep("0", -pos) .. goldValue
    else
        return goldValue:sub(1, pos) .. "," .. goldValue:sub(pos + 1)
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
    NM:print("======================")
end

NM.session = session;
