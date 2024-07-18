NM = LibStub("AceAddon-3.0"):NewAddon("NexusManager", "AceConsole-3.0")
local AceDB = LibStub("AceDB-3.0")
local log = true;

local Locale = {}
NM.Locale = Locale

--lua
local rawset = rawset

-- save
local localeSave = {}

function NM.GetLocales(locale)
    return GetLocale() == locale and Locale or nil
end

setmetatable(Locale, {
    __index = function(self, key)
        --self[key] = key or ""
        return localeSave[key] or key --error(format("'%s' LOCALE NOT FOUND", key or "nil"))
    end,
    __newindex = function(self, key, value)
        rawset(localeSave, key, value == true and key or value)
    end,
}
)

local L = NM.GetLocales("deDE")

function NM:Log(msg)
    if log then
        NM:Print(msg);
    end
end

function NM:LogTable(tbl, indent)
    if log then
        indent = indent or ""
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                NM:LogTable(v, indent .. "  ")
            else
                print(indent .. tostring(k) .. " = " .. tostring(v))
            end
        end
    end
end

function NM:OnInitialize()
    self.db = AceDB:New("NexusManagerDB")
end

function NM:OnEnable()
    NM:UpdateDB();
    NM:RegisterChatCommand("nm", "OpenNexusManager")
    NM:ResetCompletedTodos()
    NM:LoadMissingProfessionTodoToCharacter();
end

function NM:OpenNexusManager(input)
    if (input == "h" or input == "help") then
        local help_text = [[ Verwende /nm <Befehl>.
        Verfügbare Befehle:
            - status: Zeigt den aktuellen Status des Addons an
            - config: Öffnet das Konfigurationsfenster
        ]]
        NM:Print(help_text)
    else
        if not NM.Frame then
            NM:CreateMainFrame()
        end
    end
end

function NM:UpdateDB()
    local unit = "player"
    local guid = UnitGUID(unit)
    self.guid = guid

    if not self.db.global.characters then
        self.db.global.characters = {}
    end

    if not self.db.global.characters[guid] then
        self.db.global.characters[guid] = {
            id = guid,
            class = GetPlayerInfoByGUID(guid),
            name = UnitName(unit),
            realm = GetRealmName(),
            todos = {
                general = {},
                professions = self:GetProfessionTable()
            }
        }
    end

    if not self.db.global.profession then
        print("Initialize professional table")
        self.db.global.profession = self:GetProfessionTable()
    end
end

function NM:CreateUniqueKeyForTodo(title)
    local titleWithId = title .. self.guid
    local hash = 0
    for i = 1, #titleWithId do
        hash = (hash * 31 + string.byte(titleWithId, i)) % 2 ^ 32
    end

    return string.format("%08x", hash)
end

function NM:GetProfessionTable()
    local professions = {}
    for _, profession in ipairs({
        "alchemy",
        "inscription",
        "enchanting",
        "mining",
        "skinning",
        "blacksmithing",
        "tailoring",
        "jewelcrafting",
        "fishing",
        "archeology",
        "herbalism",
        "engineering",
        "leatherworking",
        "cooking"
    }) do
        professions[profession] = {}
    end
    return professions
end