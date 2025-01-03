local NM = LibStub("AceAddon-3.0"):NewAddon("NexusManager", "AceConsole-3.0", "AceEvent-3.0")
local AceDB = LibStub("AceDB-3.0")
local L = {}

-- Constants
local PROFESSIONS = {
    "alchemy", "inscription", "enchanting", "mining", "skinning",
    "blacksmithing", "tailoring", "jewelcrafting", "fishing",
    "archeology", "herbalism", "engineering", "leatherworking", "cooking"
}

local DEBUG = true

-- Initialize localization system
NM.Locale = L
local localeSave = {}

setmetatable(L, {
    __index = function(_, key)
        return localeSave[key] or key
    end,
    __newindex = function(_, key, value)
        rawset(localeSave, key, value == true and key or value)
    end
})

function NM:GetLocales(locale)
    return GetLocale() == locale and L or nil
end

-- Logging functions
function NM:Log(category, msg, metadata)
    -- Prüfe ob die Kategorie gültig ist
    if not self.LogFrame.CATEGORIES[category] then
        category = self.LogFrame.CATEGORIES.SYSTEM  -- Nutze die tatsächliche Kategorie-Konstante
    end
    
    -- Füge Log zum LogFrame hinzu
    self.LogFrame:AddLog(category, msg, metadata)
end

function NM:InitializeCharacter()
    local guid = UnitGUID("player")
    if not guid then
        self:Log("Error: Could not get player GUID")
        return nil
    end
    
    if not self.db.global.characters[guid] then
        local className = select(2, GetPlayerInfoByGUID(guid))
        self.db.global.characters[guid] = {
            id = guid,
            class = className,
            name = UnitName("player") or "Unknown",
            realm = GetRealmName() or "Unknown",
            todos = {
                general = {},
                professions = self:GetProfessionTable()
            },
            lastUpdate = time()
        }
        self:Log("New character initialized: " .. (UnitName("player") or "Unknown"))
    end
    
    return guid
end

function NM:InitializeDB()
    if not self.db.global.characters then
        self.db.global.characters = {}
    end
    
    if not self.db.global.profession then
        self:Log("Initializing profession table")
        self.db.global.profession = self:GetProfessionTable()
    end
    
    if not self.db.profile then
        self.db.profile = {
            general = {
                minimap = {}
            }
        }
    end
end

function NM:Debug(...)
    if not self.db.profile.debug then return end
    
    local message = string.format(...)
    local timestamp = date("%H:%M:%S")
    print(string.format("|cFF69CCF0[NM Debug %s]|r %s", timestamp, message))
end

function NM:OnInitialize()
    self.db = AceDB:New("NexusManagerDB")
    self:InitializeDB()
    self.guid = self:InitializeCharacter()
    
    self:RegisterChatCommand("nm", "OpenNexusManager")
    
    -- Register events mit korrekter Methodenbindung
    self:RegisterEvent("CHAT_MSG_LOOT", function(...)
        if NM.session then
            NM.session:itemLooted(...)
        end
    end)
    self:RegisterEvent("CHAT_MSG_MONEY", function(event, msg)
        if NM.session then
            NM.session:moneyLooted(event, msg)
        end
    end)
    self:RegisterEvent("UPDATE_INSTANCE_INFO", function(...)
        if NM.session then
            NM.session:zoneSwitched(...)
        end
    end)
    self:RegisterEvent("PLAYER_MONEY", function(...)
        if NM.session then
            NM.session:moneyChanged(...)
        end
    end)
    
    -- Registriere Challenge Kommunikation
    self:RegisterEvent("BN_CHAT_MSG_ADDON")
    
    -- Registriere den Addon-Präfix für Battle.net-Kommunikation
    C_ChatInfo.RegisterAddonMessagePrefix("NM_CHALLENGE")
    
    -- Default Einstellungen
    local defaults = {
        profile = {
            debug = true,  -- Debug-Modus standardmäßig aus
            -- ... andere defaults ...
        }
    }
    
    self.db = LibStub("AceDB-3.0"):New("NexusManagerDB", defaults, true)
end

function NM:OnEnable()
    -- Existierender Code...
end

function NM:BN_CHAT_MSG_ADDON(event, prefix, message, channel, sender)
    if prefix ~= "NM_CHALLENGE" then return end
    
    NM.Challenge:HandleMessage(sender, message)
end

function NM:OpenNexusManager(input)
    if input == "h" or input == "help" then
        local help_text = [[ Verwende /nm <Befehl>.
        Verfügbare Befehle:
            - status: Zeigt den aktuellen Status des Addons an
            - config: Öffnet das Konfigurationsfenster
        ]]
        self:Print(help_text)
        return
    end
    
    if not self.Frame then
        self:CreateMainFrame()
    end
end

function NM:CreateUniqueKeyForTodo(title)
    local titleWithId = title .. self.guid
    local hash = 0
    
    for i = 1, #titleWithId do
        hash = (hash * 31 + string.byte(titleWithId, i)) % 2^32
    end
    
    return string.format("%08x", hash)
end

function NM:GetProfessionTable()
    local professions = {}
    for _, profession in ipairs(PROFESSIONS) do
        professions[profession] = {}
    end
    return professions
end
