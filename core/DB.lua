local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale

-- Database module
local DB = {}
NM.DB = DB

-- SavedVariables Schema Definition
local SAVED_VARIABLES_SCHEMA = {
    global = {
        characters = {},
        profession = {},
        version = "1.0.0"
    },
    profile = {
        general = {
            minimap = {}
        }
    }
}

-- Constants
DB.PROFESSION_TYPES = {
    [L["Alchemy"]] = "alchemy",
    [L["Inscription"]] = "inscription",
    [L["Enchanting"]] = "enchanting",
    [L["Mining"]] = "mining",
    [L["Skinning"]] = "skinning",
    [L["Blacksmith"]] = "blacksmithing",
    [L["Tailoring"]] = "tailoring",
    [L["Jewelcrafting"]] = "jewelcrafting",
    [L["Fishing"]] = "fishing",
    [L["Archeology"]] = "archeology",
    [L["Herbalism"]] = "herbalism",
    [L["Engineering"]] = "engineering",
    [L["Leatherworking"]] = "leatherworking",
    [L["Cooking"]] = "cooking"
}

-- Database Initialization and Validation
function DB:InitializeDB()
    if not NM.db then
        NM:Log("Error: Database not initialized")
        return
    end

    -- Initialize global settings if needed
    if not NM.db.global then
        NM.db.global = SAVED_VARIABLES_SCHEMA.global
    end

    -- Initialize profile settings if needed
    if not NM.db.profile then
        NM.db.profile = SAVED_VARIABLES_SCHEMA.profile
    end

    -- Version check and migration if needed
    if NM.db.global.version ~= SAVED_VARIABLES_SCHEMA.global.version then
        self:MigrateDB(NM.db.global.version)
    end
end

function DB:MigrateDB(oldVersion)
    NM:Log("Migrating database from version " .. (oldVersion or "unknown"))
    -- Add migration logic here
    NM.db.global.version = SAVED_VARIABLES_SCHEMA.global.version
end

-- Character Data Management
function DB:GetCurrentCharacter()
    local guid = UnitGUID("player")
    if not guid then return nil end

    if not NM.db.global.characters[guid] then
        self:InitializeCharacter(guid)
    end

    return NM.db.global.characters[guid]
end

function DB:InitializeCharacter(guid)
    if not guid then return end

    local name, realm = UnitName("player"), GetRealmName()
    local _, class = UnitClass("player")

    NM.db.global.characters[guid] = {
        id = guid,
        class = class,
        name = name,
        realm = realm,
        lastLogin = time(),
        todos = {
            general = {},
            professions = self:GetProfessionTable()
        }
    }

    NM:Log(string.format("Initialized character: %s-%s (%s)", name, realm, class))
end

-- Todo Management with Error Handling
function DB:AddTodo(todo)
    if not todo or not todo.type or not todo.assignment then
        NM:Log("Error: Invalid todo data")
        return false
    end

    local success, err = pcall(function()
        if todo.type == "character" then
            local char = self:GetCurrentCharacter()
            if not char then return end
            
            table.insert(char.todos.general, todo)
            NM:Log("Added character todo: " .. todo.title)
        
        elseif todo.type == "profession" then
            -- Add to global profession list
            if not NM.db.global.profession[todo.assignment] then
                NM.db.global.profession[todo.assignment] = {}
            end
            table.insert(NM.db.global.profession[todo.assignment], todo)

            -- Add to characters with matching profession
            for _, char in pairs(NM.db.global.characters) do
                if char.todos.professions[todo.assignment] then
                    table.insert(char.todos.professions[todo.assignment], todo)
                end
            end
            
            NM:Log("Added profession todo: " .. todo.title)
        end
    end)

    if not success then
        NM:Log("Error adding todo: " .. (err or "unknown error"))
        return false
    end

    return true
end

-- Reset Functions with Timestamp Handling
function DB:GetResetTimestamp(now, resetType)
    now = now or time()
    
    local function getServerResetTime(timestamp)
        -- WoW server resets happen at specific times
        local serverHour = 3  -- 3 AM server time
        local currentHour = tonumber(date("%H", timestamp))
        local currentMinute = tonumber(date("%M", timestamp))
        
        return timestamp - (currentHour * 3600) - (currentMinute * 60) + (serverHour * 3600)
    end

    if resetType == "daily" then
        return getServerResetTime(now)
    elseif resetType == "weekly" then
        local weekday = tonumber(date("%w", now))
        local daysToWednesday = (weekday >= 3) and (weekday - 3) or (4 + weekday)
        local wednesday = now - (daysToWednesday * 86400)
        return getServerResetTime(wednesday)
    end
end

-- Profession Management
function DB:LoadCharacterProfessions()
    local professions = {}
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()

    local function addProfession(index)
        if index then
            local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
            if name and DB.PROFESSION_TYPES[L[name]] then
                table.insert(professions, {
                    name = L[name],
                    skillLine = skillLine
                })
            end
        end
    end

    addProfession(prof1)
    addProfession(prof2)
    if archaeology then addProfession(archaeology) end
    if fishing then addProfession(fishing) end
    if cooking then addProfession(cooking) end

    return professions
end

function DB:GetPersonalTodos()
   local todos = {}
   local currentChar = self:GetCurrentCharacter()
   
   if not currentChar then
       NM:Log("Warning: Could not get current character data")
       return {}
   end
    -- Add general todos
   if currentChar.todos and currentChar.todos.general then
       for _, todo in ipairs(currentChar.todos.general) do
           table.insert(todos, todo)
       end
   end
    -- Add profession todos
   if currentChar.todos and currentChar.todos.professions then
       local charProfessions = self:LoadCharacterProfessions()
       for _, prof in ipairs(charProfessions) do
           local profKey = self.PROFESSION_TYPES[prof.name]
           if profKey and currentChar.todos.professions[profKey] then
               for _, todo in ipairs(currentChar.todos.professions[profKey]) do
                   -- Add profession information to todo
                   todo.professionName = prof.name
                   todo.type = "profession"
                   table.insert(todos, todo)
               end
           end
       end
   end
    NM:Log(string.format("Found %d todos for character %s", #todos, currentChar.name))
   return todos
end