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
    else
        -- Stelle sicher, dass alle Profilsektionen existieren
        for section, defaults in pairs(SAVED_VARIABLES_SCHEMA.profile) do
            if not NM.db.profile[section] then
                NM.db.profile[section] = defaults
            end
        end
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

    NM:Log(string.format("Initialized character: %s-%s (%s)", name, realm, class))
end

-- Todo Management with Error Handling
function DB:AddTodo(todo)
    if not todo or not todo.type or not todo.assignment then
        NM:Log("Error: Invalid todo data")
        return false
    end

    -- Normalize profession name if it's a profession todo
    if todo.type == "profession" then
        todo.assignment = self:NormalizeProfessionName(todo.assignment)
    end
    
    -- Generate a unique key for the todo
    todo.key = todo.type .. "_" .. time() .. "_" .. math.random(1000, 9999)
    NM:Log("Generated new todo key: " .. todo.key)

    local success, err = pcall(function()
        if todo.type == "character" then
            local char = self:GetCurrentCharacter()
            if not char then return end
            
            if not char.todos.general then
                char.todos.general = {}
            end
            
            table.insert(char.todos.general, todo)
            NM:Log("Added character todo: " .. todo.title)
        
        elseif todo.type == "profession" then
            -- Add to global profession list
            if not NM.db.global.profession[todo.assignment] then
                NM.db.global.profession[todo.assignment] = {}
            end
            table.insert(NM.db.global.profession[todo.assignment], todo)

            -- Add individual copies to all characters with this profession
            for _, char in pairs(NM.db.global.characters) do
                if self:HasProfession(char, todo.assignment) then
                    NM:Log("Adding profession todo to character: " .. char.name)
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
        NM:Log("UpdateTodo: Invalid input - key or updatedTodo missing")
        return false 
    end
    
    NM:Log("=== UpdateTodo Debug Start ===")
    NM:Log("Key: " .. tostring(key))
    NM:Log("Type: " .. tostring(updatedTodo.type))
    
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
            NM:Log("Could not find original todo")
            return false
        end
        
        NM:Log("Old type: " .. oldType)
        NM:Log("New type: " .. updatedTodo.type)
        
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
        NM:Log("Error in UpdateTodo: " .. tostring(err))
        return false
    end
    
    NM:Log("=== UpdateTodo Debug End ===")
    return true
end

function DB:DeleteTodo(key, todoType, assignment)
    if not key then 
        NM:Log("DeleteTodo: No key provided")
        return false 
    end
    
    NM:Log("=== DeleteTodo Debug Start ===")
    NM:Log("Deleting todo - Key: " .. key .. ", Type: " .. todoType .. ", Assignment: " .. (assignment or "none"))
    
    local success, err = pcall(function()
        if todoType == "character" then
            local char = self:GetCurrentCharacter()
            if not char then return end
            
            -- Find and remove from character todos
            for i, todo in ipairs(char.todos.general) do
                if todo.key == key then
                    table.remove(char.todos.general, i)
                    NM:Log("Deleted character todo: " .. key)
                    break
                end
            end
            
        elseif todoType == "profession" then
            -- Get the base key without character ID
            local baseKey = key:gsub("_Player%-[^_]+$", "")
            NM:Log("Base key for deletion: " .. baseKey)
            
            -- Remove from global profession list
            if NM.db.global.profession[assignment] then
                for i, todo in ipairs(NM.db.global.profession[assignment]) do
                    if todo.key == baseKey then
                        table.remove(NM.db.global.profession[assignment], i)
                        NM:Log("Removed from global profession list")
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
                            NM:Log("Removed todo from character: " .. char.name)
                        end
                    end
                end
            end
            
            -- Clean up empty profession lists
            for _, char in pairs(NM.db.global.characters) do
                if char.todos and char.todos.professions and char.todos.professions[assignment] then
                    if #char.todos.professions[assignment] == 0 then
                        char.todos.professions[assignment] = nil
                        NM:Log("Cleaned up empty profession list for character: " .. char.name)
                    end
                end
            end
            
            -- Clean up global profession list if empty
            if NM.db.global.profession[assignment] and #NM.db.global.profession[assignment] == 0 then
                NM.db.global.profession[assignment] = nil
                NM:Log("Cleaned up empty global profession list")
            end
        end
    end)
    
    if not success then
        NM:Log("Error deleting todo: " .. (err or "unknown error"))
        NM:Log("=== DeleteTodo Debug End (Error) ===")
        return false
    end
    
    NM:Log("=== DeleteTodo Debug End (Success) ===")
    return true
end

-- Helper function to sync profession todos when professions change
function DB:SyncProfessionTodos(charData, profession, isLearning)
    profession = self:NormalizeProfessionName(profession)
    if not charData or not profession then return end
    
    NM:Log("Syncing profession todos for " .. charData.name .. " - " .. profession .. " (Learning: " .. tostring(isLearning) .. ")")
    
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
    NM:Log("=== Profession Update Event Start ===")
    NM:Log("Event: " .. event)
    
    local char = self.DB:GetCurrentCharacter()
    if not char then 
        NM:Log("No character found")
        return 
    end
    
    -- Get current professions
    local currentProfessions = {}
    local prof1, prof2 = GetProfessions()
    
    if prof1 then
        local name = self.DB:NormalizeProfessionName(GetProfessionInfo(prof1))
        if name then 
            currentProfessions[name] = true
            NM:Log("Found profession 1: " .. name)
        end
    end
    if prof2 then
        local name = self.DB:NormalizeProfessionName(GetProfessionInfo(prof2))
        if name then 
            currentProfessions[name] = true
            NM:Log("Found profession 2: " .. name)
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
            NM:Log("Removing unlearned profession: " .. profession)
            char.todos.professions[profession] = nil
            professionsChanged = true
        end
    end
    
    -- Add new professions and sync todos
    for profession, _ in pairs(currentProfessions) do
        if not char.todos.professions[profession] then
            NM:Log("Adding new profession: " .. profession)
            char.todos.professions[profession] = {}
            self.DB:SyncProfessionTodos(char, profession, true)
            professionsChanged = true
        end
    end
    
    -- Force UI update if professions changed
    if professionsChanged then
        NM:Log("Professions changed - Updating UI")
        C_Timer.After(0.1, function()
            self:reloadScrollFrameTable()
            -- Double-check update after a short delay
            C_Timer.After(0.5, function()
                self:reloadScrollFrameTable()
            end)
        end)
    end
    
    NM:Log("=== Profession Update Event End ===")
end

-- Helper function to sync profession todos
function DB:SyncProfessionTodos(char, profession, isLearning)
    if not char or not profession then return end
    
    NM:Log("=== Syncing Profession Todos ===")
    NM:Log("Character: " .. char.name)
    NM:Log("Profession: " .. profession)
    NM:Log("Is Learning: " .. tostring(isLearning))
    
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
            NM:Log("Added " .. added .. " todos for " .. profession)
        end
    end
    
    NM:Log("=== Sync Complete ===")
end

-- Helper function to clean up profession todos
function DB:CleanupProfessionTodos(char, profession)
    if not char or not profession then return end
    
    NM:Log("Cleaning up todos for profession: " .. profession)
    
    -- Remove profession todos for this character
    if char.todos and char.todos.professions then
        char.todos.professions[profession] = nil
        NM:Log("Removed profession todos for: " .. profession)
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

function DB:OnInitialize()
    self:InitializeProfessionTracking()
    
end

-- Helper function to initialize character data structure
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
    
    NM:Log("=== Loading Missing Profession Todos ===")
    
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
        NM:Log("Checking profession: " .. profession)
        
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
                    NM:Log("Adding new todo for " .. profession .. ": " .. globalTodo.title)
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
            NM:Log("Removing todos for unlearned profession: " .. profession)
            char.todos.professions[profession] = nil
        end
    end
    
    NM:Log("=== Profession Todos Loading Complete ===")
end

NM.LoadMissingProfessionTodoToCharacter = function()
    return NM.DB:LoadMissingProfessionTodoToCharacter()
end

-- Helper function to check if an item matches the enabled options
function DB:ShouldTrackItem(itemID)
    print("Should Track Item")
    if not itemID then 
        NM:Log("ShouldTrackItem: No itemID provided")
        return false 
    end
    
    local itemName, _, itemRarity, _, _, itemType, itemSubType = C_Item.GetItemInfo(itemID)
    if not itemName then 
        NM:Log("ShouldTrackItem: Could not get item info for ID " .. itemID)
        return false 
    end
    
    NM:Log("Checking item: " .. itemName .. " (Rarity: " .. itemRarity .. ")")
    
    -- Check general options (item rarity)
    local rarityMap = {
        [0] = "poor",
        [1] = "common",
        [2] = "uncommon",
        [3] = "rare",
        [4] = "epic",
        [5] = "legendary"
    }
    
    local rarityOption = rarityMap[itemRarity]
    if rarityOption then
        NM:Log("Checking rarity option: " .. rarityOption .. " = " .. tostring(NM.db.profile.general[rarityOption]))
        if NM.db.profile.general[rarityOption] then
            NM:Log("Item should be tracked due to rarity setting")
            return true
        end
    end
    
    -- Check trade goods
    if itemType == ITEM_QUALITY_COLORS[1] then -- "Trade Goods"
        local tradeMap = {
            [L["Cloth"]] = "cloth",
            [L["Leather"]] = "leather",
            [L["Metal & Stone"]] = "metalStone",
            [L["Cooking"]] = "cooking",
            [L["Herb"]] = "herb",
            [L["Enchanting"]] = "enchanting",
            [L["Inscription"]] = "inscription",
            [L["Jewelcrafting"]] = "jewelcrafting",
            [L["Parts"]] = "parts",
            [L["Elemental"]] = "elemental",
        }
        
        if tradeMap[itemSubType] and NM.db.profile.tradeskill[tradeMap[itemSubType]] then
            return true
        end
    end
    
    -- Check miscellaneous items
    if itemType == ITEM_QUALITY_COLORS[0] then -- "Miscellaneous"
        local miscMap = {
            [L["Junk"]] = "junk",
            [L["Reagent"]] = "reagent",
            [L["CompanionPet"]] = "companionPet",
            [L["Holiday"]] = "holiday",
            [L["Mount"]] = "mount",
            [L["MountEquipment"]] = "mountEquipment",
        }
        
        if miscMap[itemSubType] and NM.db.profile.miscellaneous[miscMap[itemSubType]] then
            return true
        end
    end
    
    -- Check recipes
    if itemType == L["Recipe"] then
        local recipeMap = {
            [L["Leatherworking"]] = "Leatherworking",
            [L["Tailoring"]] = "Tailoring",
            [L["Engineering"]] = "Engineering",
            [L["Blacksmithing"]] = "Blacksmithing",
            [L["Cooking"]] = "Cooking",
            [L["Alchemy"]] = "Alchemy",
            [L["Firstaid"]] = "Firstaid",
            [L["Enchanting"]] = "Enchanting",
            [L["Fishing"]] = "Fishing",
            [L["Jewelcrafting"]] = "Jewelcrafting",
            [L["Inscription"]] = "Inscription",
        }
        
        if recipeMap[itemSubType] and NM.db.profile.recipe[recipeMap[itemSubType]] then
            return true
        end
    end
    
    return false
end

function DB:CheckTodo(todo)
    if not todo then 
        NM:Log("CheckTodo: No todo provided")
        return false 
    end
    
    -- Get current character
    local char = self:GetCurrentCharacter()
    if not char then 
        NM:Log("CheckTodo: No character found")
        return false 
    end
    
    NM:Log("=== CheckTodo Debug ===")
    NM:Log("Todo Key: " .. (todo.key or "nil"))
    NM:Log("Todo Type: " .. (todo.type or "nil"))
    if todo.type == "profession" then
        NM:Log("Profession: " .. (todo.assignment or "nil"))
    end
    
    -- Initialize todos structure if needed
    if not char.todos then 
        NM:Log("Initializing todos structure")
        char.todos = {} 
    end
    
    -- Check and update todo status
    local isComplete = false
    if todo.type == "profession" then
        if not char.todos.professions then char.todos.professions = {} end
        if not char.todos.professions[todo.assignment] then char.todos.professions[todo.assignment] = {} end
        
        -- Find existing todo
        local found = false
        for _, profTodo in ipairs(char.todos.professions[todo.assignment]) do
            if profTodo.key == todo.key then
                found = true
                isComplete = not profTodo.complete  -- Toggle status
                profTodo.complete = isComplete
                profTodo.completedAt = isComplete and time() or nil
                NM:Log("Found existing todo - New status: " .. tostring(isComplete))
                break
            end
        end
        
        -- If not found, create new todo
        if not found then
            NM:Log("Creating new profession todo")
            local newTodo = {
                key = todo.key,
                title = todo.title,
                description = todo.description,
                frequency = todo.frequency,
                type = "profession",
                assignment = todo.assignment,
                complete = true,
                completedAt = time()
            }
            table.insert(char.todos.professions[todo.assignment], newTodo)
            isComplete = true
        end
        
    elseif todo.type == "instance" then
        if not char.todos.instances then char.todos.instances = {} end
        
        -- Similar logic for instance todos
        local found = false
        for _, instTodo in ipairs(char.todos.instances) do
            if instTodo.key == todo.key then
                found = true
                isComplete = not instTodo.complete  -- Toggle status
                instTodo.complete = isComplete
                instTodo.completedAt = isComplete and time() or nil
                NM:Log("Found existing instance todo - New status: " .. tostring(isComplete))
                break
            end
        end
        
        if not found then
            NM:Log("Creating new instance todo")
            local newTodo = {
                key = todo.key,
                title = todo.title,
                description = todo.description,
                frequency = todo.frequency,
                type = "instance",
                complete = true,
                completedAt = time()
            }
            table.insert(char.todos.instances, newTodo)
            isComplete = true
        end
    end
    
    NM:Log("Final status: " .. tostring(isComplete))
    NM:Log("=== CheckTodo End ===")
    
    return isComplete
end