local NM = LibStub("AceAddon-3.0"):NewAddon("NexusManager", "AceConsole-3.0", "AceEvent-3.0")
local AceDB = LibStub("AceDB-3.0")
local L = {}

-- Constants
local PROFESSIONS = {
    "alchemy", "inscription", "enchanting", "mining", "skinning",
    "blacksmithing", "tailoring", "jewelcrafting", "fishing",
    "archeology", "herbalism", "engineering", "leatherworking", "cooking"
}

local DEBUG = false

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
function NM:Log(msg)
    if DEBUG then
        self:Print(msg)
    end
end

function NM:LogTable(tbl, indent)
    if not DEBUG then return end
    
    indent = indent or ""
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            self:Print(indent .. tostring(k) .. ":")
            self:LogTable(v, indent .. "  ")
        else
            self:Print(indent .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

-- Database initialization and management
function NM:InitializeCharacter()
    local guid = UnitGUID("player")
    
    if not self.db.global.characters[guid] then
        self.db.global.characters[guid] = {
            id = guid,
            class = GetPlayerInfoByGUID(guid),
            name = UnitName("player"),
            realm = GetRealmName(),
            todos = {
                general = {},
                professions = self:GetProfessionTable()
            }
        }
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

function NM:OnInitialize()
    self.db = AceDB:New("NexusManagerDB")
end

function NM:OnEnable()
    self:InitializeDB()
    self.guid = self:InitializeCharacter()
    
    self:RegisterChatCommand("nm", "OpenNexusManager")
    self:ResetCompletedTodos()
    self:LoadMissingProfessionTodoToCharacter()
    
    -- Register events
    self:RegisterEvent("CHAT_MSG_LOOT", self.session.itemLooted)
    self:RegisterEvent("CHAT_MSG_MONEY", self.session.moneyLooted)
    self:RegisterEvent("UPDATE_INSTANCE_INFO", self.session.zoneSwitched)
    self:RegisterEvent("PLAYER_MONEY", self.session.moneyChanged)
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
