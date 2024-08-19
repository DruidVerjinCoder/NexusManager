-- LootAppraiser_TSM.lua --
local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

local TSM = {}
NM.TSM = TSM

function TSM.IsItemInGroup(itemID, group)
    if _G.TSM_API and _G.TSM_API.GetGroupPathByItem then
        local path = _G.TSM_API.GetGroupPathByItem("i:" .. tostring(itemID))
        NM.Debug.Log("    path = \"" .. tostring(path) .. "\"")
        return path == group
    end
    return false
end

function TSM.GetItemValue(itemID, priceSource)
    if priceSource == "Custom" then
        NM.Debug.Log("    price source (custom): " .. NM.db.profile.pricesource.customPriceSource)
        return _G.TSM_API and _G.TSM_API.GetCustomPriceValue(NM.db.profile.pricesource.customPriceSource, "i:" .. tostring(itemID)) or 0
    end

    if _G.TSM_API and _G.TSM_API.GetCustomPriceValue then
        local itemLink
        local newItemID = NM.PetData.ItemID2Species(itemID) -- battle pet handling
        if newItemID == itemID then
            itemLink = "i:" .. tostring(itemID)
        else
            itemLink = newItemID
        end
        return _G.TSM_API.GetCustomPriceValue(priceSource, itemLink) -- "i:" .. tostring(itemID)
    end

    return 0
end

function TSM.ParseCustomPrice(value)
    NM.Debug.Log("ParseCustomPrice(value=" .. tostring(value) .. ")")
    return _G.TSM_API and _G.TSM_API.IsCustomPriceValid(value) or false
end

function TSM.IsTSMLoaded()
    return _G.TSM_API ~= nil
end

function TSM.GetAvailablePriceSources()
    NM.Debug.Log("TSM.GetAvailablePriceSources")

    if not TSM.IsTSMLoaded() then
        NM.Debug.Log("TSM.GetAvailablePriceSources: TSM not loaded")
        return
    end

    local priceSources = {}
    local keys = {}

    if _G.TSM_API and _G.TSM_API.GetPriceSourceKeys then
        local tempPriceSources = {}
        _G.TSM_API.GetPriceSourceKeys(tempPriceSources)
        for k, v in pairs(tempPriceSources) do
            if NM.CONST.PRICE_SOURCE[k] then
                table.insert(keys, k)
            elseif NM.CONST.PRICE_SOURCE[v] then
                table.insert(keys, v)
            end
        end
    end

    table.insert(keys, "Custom")
    sort(keys)

    for _, v in ipairs(keys) do
        priceSources[v] = NM.CONST.PRICE_SOURCE[v]
    end

    return priceSources
end

function TSM.GetGroupPath(itemString)
    return _G.TSM_API and _G.TSM_API.GetGroupPathByItem(itemString)
end

function TSM.ToItemString(value)
    return _G.TSM_API and _G.TSM_API.ToItemString(value)
end

function TSM.FormatGroupPath(path)
    return _G.TSM_API and _G.TSM_API.FormatGroupPath(path)
end