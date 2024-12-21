local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

local Images = {}

-- Funktion zum Erstellen eines Textur-Strings mit optionaler Größe
local function createTextureString(path, defaultSize)
    return function(size)
        local textureSize = size or defaultSize
        return "|T" .. path .. ":" .. textureSize .. ":" .. textureSize .. "|t"
    end
end

-- Funktion zum Erstellen eines Bildpfads
local function createImagePath(path, defaultSize)
    return {
        path = path,
        texture = createTextureString(path, defaultSize)
    }
end

-- Gold, Silber und Bronze Icons
Images.GOLD = createImagePath("Interface\\MoneyFrame\\UI-GoldIcon", 12)
Images.SILVER = createImagePath("Interface\\MoneyFrame\\UI-SilverIcon", 12)
Images.BRONZE = createImagePath("Interface\\MoneyFrame\\UI-CopperIcon", 12)

-- Trade-Goods
Images.CLOTH = createImagePath("Interface\\Icons\\INV_Fabric_Felcloth_Ebon")
Images.LEATHER = createImagePath("Interface\\Icons\\INV_Misc_LeatherScrap_03")
Images.METAL_STONE = createImagePath("Interface\\Icons\\INV_Ore_Thorium_01")
Images.COOKING = createImagePath("Interface\\Icons\\INV_Misc_Food_15")
Images.HERB = createImagePath("Interface\\Icons\\INV_Misc_Herb_19")
Images.ENCHANTING = createImagePath("Interface\\Icons\\Trade_Engraving")
Images.INSCRIPTION = createImagePath("Interface\\Icons\\INV_Inscription_Tradeskill01")
Images.JEWELCRAFTING = createImagePath("Interface\\Icons\\INV_Misc_Gem_01")
Images.PARTS = createImagePath("Interface\\Icons\\INV_Misc_Gear_01")
Images.ELEMENTAL = createImagePath("Interface\\Icons\\Spell_Nature_ElementalPrecision_1")
Images.OTHER = createImagePath("Interface\\Icons\\INV_Misc_QuestionMark")

-- Miscellaneous
Images.JUNK = createImagePath("Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
Images.REAGENT = createImagePath("Interface\\Icons\\inv_alchemy_optionalreagent_01")
Images.COMPANION_PET = createImagePath("Interface\\Icons\\INV_Box_PetCarrier_01")
Images.HOLIDAY = createImagePath("Interface\\Icons\\inv_holiday_christmas_present_01")
Images.MOUNT =  createImagePath("Interface\\Icons\\ability_mount_spectraltiger")
Images.MOUNT_EQUIPMENT = createImagePath("Interface\\Icons\\inv_tailoring_70_saddleblanket")

-- BattlePet Option Icons
Images.HUMANOID_PET = createImagePath("Interface\\Icons\\pet_type_humanoid")
Images.DRAGONKIN_PET = createImagePath("Interface\\Icons\\pet_type_dragon")
Images.FLYING_PET = createImagePath("Interface\\Icons\\pet_type_flying")
Images.UNDEAD_PET = createImagePath("Interface\\Icons\\pet_type_undead")
Images.CRITTER_PET = createImagePath("Interface\\Icons\\pet_type_critter")
Images.MAGIC_PET = createImagePath("Interface\\Icons\\pet_type_magical")
Images.ELEMENTAL_PET = createImagePath("Interface\\Icons\\pet_type_elemental")
Images.BEAST_PET = createImagePath("Interface\\Icons\\pet_type_beast")
Images.AQUATIC_PET = createImagePath("Interface\\Icons\\pet_type_water")
Images.MECHANICAL_PET = createImagePath("Interface\\Icons\\pet_type_mechanical")

-- Recipe Option Icons
Images.RECIPE_BOOK = createImagePath("Interface\\icons\\inv_misc_book_02")
Images.RECIPE_LEATHERWORKING = createImagePath("Interface\\Icons\\INV_Misc_ArmorKit_17")
Images.RECIPE_TAILORING = createImagePath("Interface\\Icons\\Trade_Tailoring")
Images.RECIPE_ENGINEERING = createImagePath("Interface\\Icons\\Trade_Engineering")
Images.RECIPE_BLACKSMITHING = createImagePath("Interface\\Icons\\Trade_BlackSmithing")
Images.RECIPE_COOKING = createImagePath("Interface\\Icons\\INV_Misc_Food_15")
Images.RECIPE_ALCHEMY = createImagePath("Interface\\Icons\\Trade_Alchemy")
Images.RECIPE_FIRSTAID = createImagePath("Interface\\Icons\\Spell_Holy_SealOfSacrifice")
Images.RECIPE_ENCHANTING = createImagePath("Interface\\Icons\\Trade_Engraving")
Images.RECIPE_FISHING = createImagePath("Interface\\Icons\\Trade_Fishing")
Images.RECIPE_JEWELCRAFTING = createImagePath("Interface\\Icons\\INV_Misc_Gem_01")
Images.RECIPE_INSCRIPTION = createImagePath("Interface\\Icons\\INV_Inscription_Tradeskill01")

NM.Images = Images;