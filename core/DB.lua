local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale

-- Database module
local DB = NM:NewModule("DB")
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

-- Aktuelle Version der DB-Struktur
local CURRENT_DB_VERSION = 1

-- Vollständige Standardwerte für neue Profile
local defaults = {
    profile = {
        dbVersion = 0,  -- Startet bei 0 für neue Profile
        minimap = {
            hide = false,
        },
        debug = false,
        general = {
            poor = false,
            common = false,
            uncommon = false,
            rare = false,
            epic = false,
            legendary = false
        },
        tradegoods = {
            parts = false,
            explosives = false,
            devices = false,
            jewelcrafting = false,
            cloth = false,
            leather = false,
            metal_stone = false,
            cooking = false,
            herb = false,
            enchanting = false,
            inscription = false,
            other = false
        },
        recipe = {
            book = false,
            leatherworking = false,
            tailoring = false,
            engineering = false,
            blacksmithing = false,
            cooking = false,
            alchemy = false,
            firstaid = false,
            enchanting = false,
            fishing = false,
            jewelcrafting = false,
            inscription = false
        },
        battlePets = {
            humanoid = false,
            dragonkin = false,
            flying = false,
            undead = false,
            critter = false,
            magic = false,
            elemental = false,
            beast = false,
            aquatic = false,
            mechanical = false
        },
        miscellaneous = {
            junk = false,
            reagent = false,
            companionPet = false,
            holiday = false,
            other = false,
            mount = false,
            mountEquipment = false
        }
    }
}

function DB:OnInitialize()
    NM:Log("Initializing DB")
    -- Initialisiere die Datenbank
    NM.db = LibStub("AceDB-3.0"):New("NexusManagerDB", defaults, true)
    
    -- Führe Migration durch
    self:MigrateProfile()
end

function DB:MigrateProfile()
    if not NM.db or not NM.db.profile then return end
    
    local currentVersion = NM.db.profile.dbVersion or 0
    NM:Log(string.format("Current DB version: %d, Latest version: %d", currentVersion, CURRENT_DB_VERSION))

    -- Migration für jede Version durchführen
    while currentVersion < CURRENT_DB_VERSION do
        currentVersion = currentVersion + 1
        NM:Log("Migrating to version " .. currentVersion)

        -- Version 1: Grundstruktur und tradeskill -> tradegoods Migration
        if currentVersion == 1 then
            -- Migriere tradeskill zu tradegoods
            if NM.db.profile.tradeskill then
                NM:Log("Migrating tradeskill to tradegoods...")
                if not NM.db.profile.tradegoods then
                    NM.db.profile.tradegoods = {}
                end
                for k, v in pairs(NM.db.profile.tradeskill) do
                    NM.db.profile.tradegoods[k] = v
                end
                NM.db.profile.tradeskill = nil
            end

            -- Stelle sicher, dass alle Kategorien existieren
            for category, defaults in pairs(defaults.profile) do
                if type(defaults) == "table" and category ~= "minimap" then
                    if not NM.db.profile[category] then
                        NM:Log("Creating missing category: " .. category)
                        NM.db.profile[category] = {}
                    end
                    -- Füge fehlende Keys hinzu
                    for k, v in pairs(defaults) do
                        if NM.db.profile[category][k] == nil then
                            NM:Log(string.format("Adding missing key: %s.%s", category, k))
                            NM.db.profile[category][k] = v
                        end
                    end
                end
            end
        end

        -- Hier können weitere Versionen hinzugefügt werden
        -- if currentVersion == 2 then
        --     -- Migration für Version 2
        -- end

        -- Aktualisiere die Versionnummer
        NM.db.profile.dbVersion = currentVersion
        NM:Log("Migration to version " .. currentVersion .. " complete")
    end

end

function DB:MigrateDB(oldVersion)
    -- Add migration logic here
    NM.db.global.version = SAVED_VARIABLES_SCHEMA.global.version
end

-- Character Data Management
function DB:GetCurrentCharacter()
    if not NM.db or not NM.db.global or not NM.db.global.characters then
        return nil
    end
    
    local char = NM.db.global.characters[NM.guid]
    if char then
        -- Ensure character data structure is initialized
        self:InitializeCharacterData(char)
    end
    
    return char
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

end

-- Todo Management with Error Handling
function DB:AddTodo(todo)
    if not todo or not todo.type or not todo.assignment then
        return false
    end

    -- Normalize profession name if it's a profession todo
    if todo.type == "profession" then
        todo.assignment = self:NormalizeProfessionName(todo.assignment)
    end
    
    -- Generate a unique key for the todo
    todo.key = todo.type .. "_" .. time() .. "_" .. math.random(1000, 9999)

    local success, err = pcall(function()
        if todo.type == "character" then
            local char = self:GetCurrentCharacter()
            if not char then return end
            
            if not char.todos.general then
                char.todos.general = {}
            end
            
            table.insert(char.todos.general, todo)
        
        elseif todo.type == "profession" then
            -- Add to global profession list
            if not NM.db.global.profession[todo.assignment] then
                NM.db.global.profession[todo.assignment] = {}
            end
            table.insert(NM.db.global.profession[todo.assignment], todo)

            -- Add individual copies to all characters with this profession
            for _, char in pairs(NM.db.global.characters) do
                if self:HasProfession(char, todo.assignment) then
                    if not char.todos.professions[todo.assignment] then
                        char.todos.professions[todo.assignment] = {}
                    end
                    
                    -- Create individual copy for this character
                    local todoCopy = {
                        key = todo.key .. "_" .. char.id,
                        title = todo.title,
                        description = todo.description,
                        frequency = todo.frequency,
                        type = "profession",
                        assignment = todo.assignment,
                        complete = false,
                        completedAt = nil
                    }
                    table.insert(char.todos.professions[todo.assignment], todoCopy)
                end
            end
            
        end
    end)

    if not success then
        return false
    end

    return true
end

-- Reset Functions with Timestamp Handling
function DB:GetResetTimestamp(now, resetType)
    now = now or time()
    
    if resetType == "daily" then
        -- GetQuestResetTime() gibt die Anzahl der Sekunden bis zum nächsten Daily Reset zurück
        local secondsUntilDailyReset = GetQuestResetTime()
        return now + secondsUntilDailyReset
    elseif resetType == "weekly" then
        -- GetNextWeeklyResetTime() gibt den Timestamp des nächsten Weekly Resets zurück
        return C_DateAndTime.GetNextWeeklyResetTime()
    end
    
    return nil
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
   return todos
end

function DB:GetTodos()
    local todos = {}
    local char = self:GetCurrentCharacter()
    
    if not char then 
        return todos 
    end
    
    
    -- Get current professions first
    local currentProfessions = {}
    local prof1, prof2 = GetProfessions()
    
    if prof1 then
        local name = self:NormalizeProfessionName(GetProfessionInfo(prof1))
        if name then currentProfessions[name] = true end
    end
    if prof2 then
        local name = self:NormalizeProfessionName(GetProfessionInfo(prof2))
        if name then currentProfessions[name] = true end
    end
    
    
    -- Character todos
    if char.todos and char.todos.general then
        for _, todo in ipairs(char.todos.general) do
            table.insert(todos, todo)
        end
    end
    
    -- Profession todos - ONLY for current professions
    if char.todos and char.todos.professions then
        
        for profName, profTodos in pairs(char.todos.professions) do
            local normalizedProf = self:NormalizeProfessionName(profName)
            
            -- Only process if character currently has this profession
            if currentProfessions[normalizedProf] then
                
                -- Check global todos for this profession
                if NM.db.global.profession[normalizedProf] then
                    -- Ensure local copies exist
                    for _, globalTodo in ipairs(NM.db.global.profession[normalizedProf]) do
                        local localKey = globalTodo.key .. "_" .. char.id
                        
                        -- Check if we already have this todo
                        local hasLocalCopy = false
                        for _, localTodo in ipairs(profTodos) do
                            if localTodo.key == localKey then
                                hasLocalCopy = true
                                break
                            end
                        end
                        
                        -- Create local copy if needed
                        if not hasLocalCopy then
                            local todoCopy = {
                                key = localKey,
                                title = globalTodo.title,
                                description = globalTodo.description,
                                frequency = globalTodo.frequency,
                                type = "profession",
                                assignment = normalizedProf,
                                complete = false,
                                completedAt = nil
                            }
                            table.insert(profTodos, todoCopy)
                        end
                    end
                end
                
                -- Add all local todos for this profession
                for _, todo in ipairs(profTodos) do
                    table.insert(todos, todo)
                end
            else
                -- Optionally clean up todos for inactive professions
                char.todos.professions[normalizedProf] = nil
            end
        end
    end
    
    -- Clean up professions structure
    if char.todos and char.todos.professions then
        for profName, _ in pairs(char.todos.professions) do
            if not currentProfessions[profName] then
                char.todos.professions[profName] = nil
            end
        end
    end
    
    return todos
end

-- Helper function to check if character has a profession
function DB:HasProfession(charData, profession)
    return charData and 
           charData.todos and 
           charData.todos.professions and 
           charData.todos.professions[profession]
end

function DB:UpdateTodo(key, updatedTodo)
    if not key or not updatedTodo then 
        return false 
    end
    
    
    local success, err = pcall(function()
        local oldTodo = nil
        local oldType = nil
        local char = self:GetCurrentCharacter()
        
        -- First, find and remember the old todo
        if char then
            -- Check character todos
            for _, todo in ipairs(char.todos.general) do
                if todo.key == key then
                    oldTodo = todo
                    oldType = "character"
                    break
                end
            end
            
            -- Check profession todos if not found in character todos
            if not oldTodo then
                for prof, todos in pairs(char.todos.professions) do
                    for _, todo in ipairs(todos) do
                        if todo.key == key then
                            oldTodo = todo
                            oldType = "profession"
                            break
                        end
                    end
                    if oldTodo then break end
                end
            end
        end
        
        if not oldTodo then
            return false
        end
        
        -- If type changed, we need to remove from old location and add to new
        if oldType ~= updatedTodo.type then
            -- Remove from old location
            if oldType == "character" then
                for i, todo in ipairs(char.todos.general) do
                    if todo.key == key then
                        table.remove(char.todos.general, i)
                        break
                    end
                end
            elseif oldType == "profession" then
                -- Remove from global profession list
                if NM.db.global.profession[oldTodo.assignment] then
                    for i, todo in ipairs(NM.db.global.profession[oldTodo.assignment]) do
                        if todo.key == key then
                            table.remove(NM.db.global.profession[oldTodo.assignment], i)
                            break
                        end
                    end
                end
            end
            
            -- Add to new location
            if updatedTodo.type == "character" then
                if not char.todos.general then
                    char.todos.general = {}
                end
                table.insert(char.todos.general, updatedTodo)
            elseif updatedTodo.type == "profession" then
                if not NM.db.global.profession[updatedTodo.assignment] then
                    NM.db.global.profession[updatedTodo.assignment] = {}
                end
                table.insert(NM.db.global.profession[updatedTodo.assignment], updatedTodo)
                
                -- Add to all characters with this profession
                for _, character in pairs(NM.db.global.characters) do
                    if character.todos.professions[updatedTodo.assignment] then
                        table.insert(character.todos.professions[updatedTodo.assignment], updatedTodo)
                    end
                end
            end
        else
            -- If type hasn't changed, just update in place
            if updatedTodo.type == "character" then
                for i, todo in ipairs(char.todos.general) do
                    if todo.key == key then
                        char.todos.general[i] = updatedTodo
                        break
                    end
                end
            elseif updatedTodo.type == "profession" then
                if NM.db.global.profession[updatedTodo.assignment] then
                    for i, todo in ipairs(NM.db.global.profession[updatedTodo.assignment]) do
                        if todo.key == key then
                            NM.db.global.profession[updatedTodo.assignment][i] = updatedTodo
                            break
                        end
                    end
                end
            end
        end
    end)
    
    if not success then
        return false
    end
    
    return true
end

function DB:DeleteTodo(key, todoType, assignment)
    if not key then 
        return false 
    end
    
    
    local success, err = pcall(function()
        if todoType == "character" then
            local char = self:GetCurrentCharacter()
            if not char then return end
            
            -- Find and remove from character todos
            for i, todo in ipairs(char.todos.general) do
                if todo.key == key then
                    table.remove(char.todos.general, i)
                    break
                end
            end
            
        elseif todoType == "profession" then
            -- Get the base key without character ID
            local baseKey = key:gsub("_Player%-[^_]+$", "")
            
            -- Remove from global profession list
            if NM.db.global.profession[assignment] then
                for i, todo in ipairs(NM.db.global.profession[assignment]) do
                    if todo.key == baseKey then
                        table.remove(NM.db.global.profession[assignment], i)
                        break
                    end
                end
            end
            
            -- Remove from all characters with this profession
            for _, char in pairs(NM.db.global.characters) do
                if char.todos and char.todos.professions and char.todos.professions[assignment] then
                    local charTodos = char.todos.professions[assignment]
                    for i = #charTodos, 1, -1 do  -- Iterate backwards to safely remove
                        local todo = charTodos[i]
                        -- Check if this todo matches our base key
                        if todo.key:find(baseKey) then
                            table.remove(charTodos, i)
                        end
                    end
                end
            end
            
            -- Clean up empty profession lists
            for _, char in pairs(NM.db.global.characters) do
                if char.todos and char.todos.professions and char.todos.professions[assignment] then
                    if #char.todos.professions[assignment] == 0 then
                        char.todos.professions[assignment] = nil
                    end
                end
            end
            
            -- Clean up global profession list if empty
            if NM.db.global.profession[assignment] and #NM.db.global.profession[assignment] == 0 then
                NM.db.global.profession[assignment] = nil
            end
        end
    end)
    
    if not success then
        return false
    end
    
    return true
end

-- Helper function to sync profession todos when professions change
function DB:SyncProfessionTodos(charData, profession, isLearning)
    profession = self:NormalizeProfessionName(profession)
    if not charData or not profession then return end
    
    if isLearning then
        -- Character learned a profession - add todos
        if NM.db.global.profession[profession] then
            if not charData.todos.professions[profession] then
                charData.todos.professions[profession] = {}
            end
            
            -- Copy each global profession todo with individual completion status
            for _, globalTodo in ipairs(NM.db.global.profession[profession]) do
                local todoCopy = {
                    key = globalTodo.key .. "_" .. charData.id,
                    title = globalTodo.title,
                    description = globalTodo.description,
                    frequency = globalTodo.frequency,
                    type = "profession",
                    assignment = profession,
                    complete = false,  -- Reset completion status for new character
                    completedAt = nil
                }
                table.insert(charData.todos.professions[profession], todoCopy)
            end
        end
    else
        -- Character unlearned a profession - remove todos
        if charData.todos.professions[profession] then
            charData.todos.professions[profession] = nil
        end
    end
end

-- In your event handling setup
function NM:OnProfessionUpdate(event, ...)
    
    local char = self.DB:GetCurrentCharacter()
    if not char then 
        return 
    end
    
    -- Get current professions
    local currentProfessions = {}
    local prof1, prof2 = GetProfessions()
    
    if prof1 then
        local name = self.DB:NormalizeProfessionName(GetProfessionInfo(prof1))
        if name then 
            currentProfessions[name] = true
        end
    end
    if prof2 then
        local name = self.DB:NormalizeProfessionName(GetProfessionInfo(prof2))
        if name then 
            currentProfessions[name] = true
        end
    end
    
    -- Initialize profession structure if needed
    if not char.todos then char.todos = {} end
    if not char.todos.professions then char.todos.professions = {} end
    
    -- Check for profession changes
    local professionsChanged = false
    
    -- Remove unlearned professions
    for profession, _ in pairs(char.todos.professions) do
        if not currentProfessions[profession] then
            char.todos.professions[profession] = nil
            professionsChanged = true
        end
    end
    
    -- Add new professions and sync todos
    for profession, _ in pairs(currentProfessions) do
        if not char.todos.professions[profession] then
            char.todos.professions[profession] = {}
            self.DB:SyncProfessionTodos(char, profession, true)
            professionsChanged = true
        end
    end
    
    -- Force UI update if professions changed
    if professionsChanged then
        C_Timer.After(0.1, function()
            self:reloadScrollFrameTable()
            -- Double-check update after a short delay
            C_Timer.After(0.5, function()
                self:reloadScrollFrameTable()
            end)
        end)
    end
    
end

-- Helper function to sync profession todos
function DB:SyncProfessionTodos(char, profession, isLearning)
    if not char or not profession then return end
    
    if isLearning then
        -- Ensure profession structure exists
        if not char.todos.professions[profession] then
            char.todos.professions[profession] = {}
        end
        
        -- Check global todos
        if NM.db.global.profession[profession] then
            local added = 0
            for _, globalTodo in ipairs(NM.db.global.profession[profession]) do
                local localKey = globalTodo.key .. "_" .. char.id
                
                -- Check if we already have this todo
                local hasLocalCopy = false
                for _, localTodo in ipairs(char.todos.professions[profession]) do
                    if localTodo.key == localKey then
                        hasLocalCopy = true
                        break
                    end
                end
                
                -- Create local copy if needed
                if not hasLocalCopy then
                    local todoCopy = {
                        key = localKey,
                        title = globalTodo.title,
                        description = globalTodo.description,
                        frequency = globalTodo.frequency,
                        type = "profession",
                        assignment = profession,
                        complete = false,
                        completedAt = nil
                    }
                    table.insert(char.todos.professions[profession], todoCopy)
                    added = added + 1
                end
            end
        end
    end
end

-- Helper function to clean up profession todos
function DB:CleanupProfessionTodos(char, profession)
    if not char or not profession then return end
    
    
    -- Remove profession todos for this character
    if char.todos and char.todos.professions then
        char.todos.professions[profession] = nil
    end
end

-- Register the correct events
function NM:InitializeProfessionTracking()
    -- Register for profession-related events
    self:RegisterEvent("SKILL_LINES_CHANGED", "OnProfessionUpdate")
    self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnProfessionUpdate")
    
    -- For retail WoW
    if C_TradeSkillUI then
        self:RegisterEvent("TRADE_SKILL_SHOW", "OnProfessionUpdate")
        self:RegisterEvent("NEW_RECIPE_LEARNED", "OnProfessionUpdate")
    end
end

function DB:InitializeCharacterData(char)
    if not char.todos then
        char.todos = {
            general = {},
            professions = {}
        }
    end
    
    if not char.todos.general then
        char.todos.general = {}
    end
    
    if not char.todos.professions then
        char.todos.professions = {}
    end
    
    -- Get current professions and initialize their structures
    local prof1, prof2 = GetProfessions()
    if prof1 then
        local name = GetProfessionInfo(prof1)
        if name and not char.todos.professions[name] then
            char.todos.professions[name] = {}
        end
    end
    if prof2 then
        local name = GetProfessionInfo(prof2)
        if name and not char.todos.professions[name] then
            char.todos.professions[name] = {}
        end
    end
end

-- Helper function to normalize profession names
function DB:NormalizeProfessionName(profName)
    if not profName then return nil end
    -- First character uppercase, rest lowercase
    return profName:gsub("^%l", string.upper)
end

function DB:LoadMissingProfessionTodoToCharacter()
    local char = self:GetCurrentCharacter()
    if not char then return end
    
    -- Initialize profession todos if needed
    if not char.todos then char.todos = {} end
    if not char.todos.professions then char.todos.professions = {} end
    
    -- Get current professions
    local prof1, prof2 = GetProfessions()
    local currentProfessions = {}
    
    if prof1 then
        local name = self:NormalizeProfessionName(GetProfessionInfo(prof1))
        if name then currentProfessions[name] = true end
    end
    if prof2 then
        local name = self:NormalizeProfessionName(GetProfessionInfo(prof2))
        if name then currentProfessions[name] = true end
    end
    
    -- For each current profession
    for profession in pairs(currentProfessions) do
        
        -- Initialize profession table if needed
        if not char.todos.professions[profession] then
            char.todos.professions[profession] = {}
        end
        
        -- Check global todos
        if NM.db.global.profession[profession] then
            for _, globalTodo in ipairs(NM.db.global.profession[profession]) do
                local localKey = globalTodo.key .. "_" .. char.id
                
                -- Check if we already have this todo
                local hasLocalCopy = false
                for _, localTodo in ipairs(char.todos.professions[profession]) do
                    if localTodo.key == localKey then
                        hasLocalCopy = true
                        break
                    end
                end
                
                -- Create local copy if needed
                if not hasLocalCopy then
                    local todoCopy = {
                        key = localKey,
                        title = globalTodo.title,
                        description = globalTodo.description,
                        frequency = globalTodo.frequency,
                        type = "profession",
                        assignment = profession,
                        complete = false,
                        completedAt = nil
                    }
                    table.insert(char.todos.professions[profession], todoCopy)
                end
            end
        end
    end
    
    -- Clean up todos for professions we no longer have
    for profession in pairs(char.todos.professions) do
        if not currentProfessions[profession] then
            char.todos.professions[profession] = nil
        end
    end
    
end

NM.LoadMissingProfessionTodoToCharacter = function()
    return NM.DB:LoadMissingProfessionTodoToCharacter()
end

-- Helper function to check if an item matches the enabled options
function DB:ShouldTrackItem(itemID)
    if not itemID then return false end
    
    -- Get current character's profile name
    local characterName = UnitName("player")
    local realmName = GetRealmName()
    local profileName = characterName .. " - " .. realmName
    
    -- Get item info
    local itemName, _, itemRarity, _, _, itemType, subType, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemID)
    if not itemName then return false end

    -- Debug output
    NM:Log("=== ShouldTrackItem Debug ===")
    NM:Log(string.format("Checking item: %s (ID: %d)", itemName, itemID))
    NM:Log(string.format("Type: %s, Rarity: %d", itemType or "nil", itemRarity or -1))
    
    if not NM.db.profiles[profileName] then
        NM:Log("Profile not found!")
        return false
    end
    
    local settings = NM.db.profiles[profileName].scrollFrame
    if not settings then
        NM:Log("No scrollFrame settings found!")
        return false
    end

    -- Prüfe Rüstung und Waffen basierend auf Rarität
    if itemType == "Armor" or itemType == "Weapon" then
        local rarityMap = {
            [0] = "poor",
            [1] = "common",
            [2] = "uncommon",
            [3] = "rare",
            [4] = "epic",
            [5] = "legendary"
        }
        
        local rarityKey = rarityMap[itemRarity]
        if rarityKey and settings[rarityKey] then
            NM:Log(string.format("Item is %s %s, tracking enabled", rarityKey, itemType))
            return true
        end
    end
    
    -- Handelswaren
    if classID == 7 then
        -- Mapping von SubclassID zu Setting-Namen
        local subclassMap = {
            [1] = "parts",           -- Teile
            [2] = "explosives",      -- Sprengstoff
            [3] = "devices",         -- Geräte
            [4] = "jewelcrafting",   -- Juwelenschleifen
            [5] = "cloth",           -- Stoff
            [6] = "leather",         -- Leder
            [7] = "metalStone",      -- Erze & Steine
            [8] = "cooking",         -- Kochkunst
            [9] = "herb",            -- Kräuter
            [10] = "elemental",      -- Elementar
            [11] = "enchanting",     -- Verzauberkunst
            [12] = "inscription",    -- Inschriftenkunde
            [13] = "other"          -- Sonstiges
        }
        
        local settingName = subclassMap[subclassID]
        if settingName and settings[settingName] then
            NM:Log(string.format("Item is %s, tracking enabled", settingName))
            return true
        end
    end

    NM:Log("Item not tracked")
    return false
end

-- Helper functions to get category keys
function DB:GetRarityKey(itemRarity)
    local rarityMap = {
        [0] = "poor",
        [1] = "common",
        [2] = "uncommon",
        [3] = "rare",
        [4] = "epic",
        [5] = "legendary"
    }
    return rarityMap[itemRarity]
end

-- Weitere Helper-Funktionen für die verschiedenen Kategorien...

function DB:UpdateOutput()
    if not NM.session or not NM.session.itemsLooted then 
        return string.format("\n%s-", L["Annotation: "])
    end
    
    local trackedItems = {}
    
    -- Sammle alle getrackte Items
    for itemID, count in pairs(NM.session.itemsLooted) do
        if self:ShouldTrackItem(itemID) then
            local itemName, _, itemRarity = C_Item.GetItemInfo(itemID)
            if itemName then
                local _, _, _, hexColor = C_Item.GetItemQualityColor(itemRarity)
                local itemText = string.format("%dx |c%s%s|r", count, hexColor, itemName)
                table.insert(trackedItems, itemText)
            end
        end
    end
    
    -- Füge Items zum Output hinzu
    if #trackedItems > 0 then
        return string.format("\n%s%s", L["Annotation: "], table.concat(trackedItems, ", "))
    end
    
    -- Wenn keine Items getrackt wurden
    return string.format("\n%s-", L["Annotation: "])
end