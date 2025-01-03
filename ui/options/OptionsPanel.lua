local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceDB = LibStub("AceDB-3.0")
local OptionsPanel = NM:NewModule("OptionsPanel", "AceEvent-3.0")
local LibStub = LibStub
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local L = NM.Locale

NM.OptionsPanel = OptionsPanel

local defaults = {
    profile = {
        general = {},
        tradeskill = {},
        miscellaneous = {},
        tradegoods = {},
        battlePets = {},
        recipe = {},
        backup = {}
    }
}

StaticPopupDialogs["URL_DIALOG"] = {
    text = "Copy the URL below:",
    button1 = "Close",
    hasEditBox = true,
    maxLetters = 255,
    editBoxWidth = 350,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        self.editBox:SetText(data)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end
}

local generalOptionList = {
    poor = { name = L["|cff9d9d9dPoor|r"], },
    common = { name = L["|cffffffffCommon|r"], },
    uncommon = { name = L["|cff1eff00Uncommon|r"], },
    rare = { name = L["|cff0070ddRare|r"], },
    epic = { name = L["|cffa335eeEpic|r"], },
    legendary = { name = L["|cffff8000Legendary|r"], },
}

local tradeGoodsOptionsList = {
    cloth = { name = L["Cloth"], icon = NM.Images.CLOTH.path },
    leather = { name = L["Leather"], desc = L["Track Leather - Tradeskill"], icon = NM.Images.LEATHER.path },
    metalStone = { name = L["Metal & Stone"], desc = L["Track Metal & Stone - Tradeskill"], icon = NM.Images.METAL_STONE.path },
    cooking = { name = L["Cooking"], desc = L["Track Cooking - Tradeskill"], icon = NM.Images.COOKING.path },
    herb = { name = L["Herb"], desc = L["Track Herb - Tradeskill"], icon = NM.Images.HERB.path },
    enchanting = { name = L["Enchanting"], desc = L["Track Enchanting - Tradeskill"], icon = NM.Images.ENCHANTING.path },
    inscription = { name = L["Inscription"], desc = L["Track Inscription - Tradeskill"], icon = NM.Images.INSCRIPTION.path },
    jewelcrafting = { name = L["Jewelcrafting"], desc = L["Track Jewelcrafting - Tradeskill"], icon = NM.Images.JEWELCRAFTING.path },
    parts = { name = L["Parts"], desc = L["Track Parts - Tradeskill"], icon = NM.Images.PARTS.path },
    elemental = { name = L["Elemental"], desc = L["Track Elemental - Tradeskill"], icon = NM.Images.ELEMENTAL.path },
    other = { name = L["Other"], desc = L["Track Other - Tradeskill"], icon = NM.Images.OTHER.path },
}

local miscellaneousOptionsList = {
    junk = { name = L["Junk"], desc = L["Track Parts - Tradeskill"], icon = NM.Images.JUNK.path },
    reagent = { name = L["Reagent"], desc = L["Mainly spell reagents"], icon = NM.Images.REAGENT.path },
    companionPet = { name = L["CompanionPet"], icon = NM.Images.COMPANION_PET.path },
    holiday = { name = L["Holiday"], icon = NM.Images.HOLIDAY.path },
    other = { name = L["Other"], icon = NM.Images.OTHER.path },
    mount = { name = L["Mount"], icon = NM.Images.MOUNT.path },
    mountEquipment = { name = L["MountEquipment"], icon = NM.Images.MOUNT_EQUIPMENT.path },
}

local battlePetOptionsList = {
    { name = L["Humanoid"], desc = L["Track Humanoid - BattlePets"], icon = NM.Images.HUMANOID_PET.path },
    { name = L["Dragonkin"], desc = L["Track Dragonkin - BattlePets"], icon = NM.Images.DRAGONKIN_PET.path },
    { name = L["Flying"], desc = L["Track Flying - BattlePets"], icon = NM.Images.FLYING_PET.path },
    { name = L["Undead"], desc = L["Track Undead - BattlePets"], icon = NM.Images.UNDEAD_PET.path },
    { name = L["Critter"], desc = L["Track Critter - BattlePets"], icon = NM.Images.CRITTER_PET.path },
    { name = L["Magic"], desc = L["Track Magic - BattlePets"], icon = NM.Images.MAGIC_PET.path },
    { name = L["Elemental"], desc = L["Track Elemental - BattlePets"], icon = NM.Images.ELEMENTAL_PET.path },
    { name = L["Beast"], desc = L["Track Beast - BattlePets"], icon = NM.Images.BEAST_PET.path },
    { name = L["Aquatic"], desc = L["Track Aquatic - BattlePets"], icon = NM.Images.AQUATIC_PET.path },
    { name = L["Mechanical"], desc = L["Track Mechanical - BattlePets"], icon = NM.Images.MECHANICAL_PET.path },
}

local recipeOptionsList = {
    { name = L["Book"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_BOOK.path },
    { name = L["Leatherworking"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_LEATHERWORKING.path },
    { name = L["Tailoring"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_TAILORING.path },
    { name = L["Engineering"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_ENGINEERING.path },
    { name = L["Blacksmithing"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_BLACKSMITHING.path },
    { name = L["Cooking"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_COOKING.path },
    { name = L["Alchemy"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_ALCHEMY.path },
    { name = L["Firstaid"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_FIRSTAID.path },
    { name = L["Enchanting"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_ENCHANTING.path },
    { name = L["Fishing"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_FISHING.path },
    { name = L["Jewelcrafting"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_JEWELCRAFTING.path },
    { name = L["Inscription"], desc = L["Track Other - Tradeskill"], icon = NM.Images.RECIPE_INSCRIPTION.path },
}

function OptionsPanel:OnInitialize()
    -- Warte auf DB-Initialisierung
    if not NM.db or not NM.db.profile then
        return
    end

    local options = {
        type = "group",
        name = "NexusManager",
        args = {
            general = self:createOptionsTables(L["Armor/Weapons"], generalOptionList, NM.db.profile.general, L["Track specific rarities of armor and weapon items based on your preferences."]),
            miscellaneous = self:createOptionsTables(L["Miscellaneous"], miscellaneousOptionsList, NM.db.profile.miscellaneous, L["Track various types of miscellaneous items according to your preferences, including junk, reagents, companion pets, holiday items, mounts, and mount equipment"]),
            tradeskill = self:createOptionsTables(L["Tradegoods"], tradeGoodsOptionsList, NM.db.profile.tradeskill, L["Track tradeskill items based on their specific types, such as cloth, leather, metal, stones, cooking ingredients, herbs, elemental items, enchanting materials, and more."]),
            battlePets = self:createOptionsTables(L["Battle-Pets"], battlePetOptionsList, NM.db.profile.battlePets, L["Track battle pets based on their rarity or specific types, such as humanoid, dragonkin, flying, undead, critter, magic, elemental, beast, aquatic, and mechanical."]),
            recipes = self:createOptionsTables(L["Recipes"], recipeOptionsList, NM.db.profile.recipe, L["Track recipes based on the associated profession, such as leatherworking, tailoring, engineering, blacksmithing, cooking, first aid, enchanting, fishing, jewelcrafting, and inscriptions."])
        },
    }

    -- Registriere die Optionen
    AceConfigRegistry:RegisterOptionsTable("NexusManager", options)
    
    -- Erstelle die Optionspanels
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("NexusManager", "NexusManager")
    
    -- Debug-Ausgabe
end

function OptionsPanel:createOptionsTables(name, optionsList, profilePath, descriptionText)
    -- Stelle sicher, dass der Pfad existiert
    if not profilePath then
        profilePath = {}
    end

    local options = {
        type = "group",
        name = name,
        order = 1,
        get = function(info)
            -- Sicherheitscheck
            if not NM.db or not NM.db.profile then
                return nil
            end
            local key = info[#info]
            local section = info[2] -- z.B. "general", "battlePets", etc.
            return NM.db.profile[section] and NM.db.profile[section][key]
        end,
        set = function(info, value)
            -- Sicherheitscheck
            if not NM.db or not NM.db.profile then
                return
            end
            local key = info[#info]
            local section = info[2] -- z.B. "general", "battlePets", etc.
            if not NM.db.profile[section] then
                NM.db.profile[section] = {}
            end
            NM.db.profile[section][key] = value
        end,
        args = {
            description = {
                type = "description",
                name = descriptionText,
                order = 1,
                fontSize = "medium",
            },
            scrollFrame = {
                type = "group",
                name = "",
                order = 2,
                inline = true,
                args = {}
            }
        }
    }

    local index = 1
    for key, data in pairs(optionsList) do
        local optionsName = data.name

        if data.icon ~= nil then
            optionsName = "|T" .. data.icon .. ":24:24|t " .. data.name
        end

        options.args.scrollFrame.args[tostring(key)] = {
            type = "toggle",
            name = optionsName,
            desc = data.desc or "",
            order = index,
        }
        index = index + 1
    end

    return options
end

function OptionsPanel:OpenConfig()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("NexusManager")
    end
end