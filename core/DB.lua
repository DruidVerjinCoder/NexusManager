local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

local L = NM.Locale

NM.professionalTypes = {
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

function NM:LoadCharacterNames()
    local pair = {}
    NM:Log("Load Character Names")
    --NM:LogTable(self.db.global.characters)
    for key, char in pairs(self.db.global.characters) do
        pair[key] = char.name .. " - " .. char.realm .. " (" .. char.class .. ")"
    end
    NM:Log("Loaded list: ")
    NM:LogTable(pair)
    return pair;
end

function NM:DeleteTodo(todoKey)
    local guid = self.guid
    local characterTodos = self.db.global.characters[guid].todos

    -- Delete general todo
    for i, todo in ipairs(characterTodos.general) do
        if todo.key == todoKey then
            table.remove(characterTodos.general, i)
            return
        end
    end

    -- Delete profession todo
    for _, todoList in pairs(characterTodos.professions) do
        for i, todo in ipairs(todoList) do
            if todo.key == todoKey then
                table.remove(todoList, i)
                return
            end
        end
    end
    NM:reloadScrollFrameTable()
end

function NM:LoadMissingProfessionTodoToCharacter()
    local categories = NM:LoadCharacterCategories()

    -- for _, category in pairs(categories) do
    --     local profType = NM.professionalTypes[category]
    --     for _, globalTodo in ipairs(NM.db.global.profession[profType]) do
    --         local currentProfessionalTodos = NM.db.global.characters[NM.guid].todos.professions[profType]
    --         local duplicate = false;
    --         for _, playerProfTodo in ipairs(currentProfessionalTodos) do
    --             if (playerProfTodo.key == globalTodo.key) then
    --                 duplicate = true
    --                 break
    --             end
    --         end

    --         if not duplicate then
    --             table.insert(NM.db.global.characters[NM.guid].todos.professions[profType], globalTodo)
    --         end
    --     end
    -- end
end

function NM:LoadCharacterCategories()
    local categories = {}

    local prof1, prof2, archeology, fishing, cooking = GetProfessions()

    local function addProfession(professionIndex)
        local professionName = GetProfessionInfo(professionIndex)
        local key = L[professionName]
        if key then
            table.insert(categories, key)
        end
    end

    if prof1 ~= nil then
        addProfession(prof1)
    end

    if prof2 ~= nil then
        addProfession(prof2)
    end

    if archeology then table.insert(categories, L["Archeology"]) end
    if fishing then table.insert(categories, L["Fishing"]) end
    if cooking then table.insert(categories, L["Cooking"]) end

    return categories;
end

function NM:GetPersonalTodos()
    local todos = {}
    if NM.db.global.characters[NM.guid] and NM.db.global.characters[NM.guid].todos then
        for _, todo in ipairs(NM.db.global.characters[NM.guid].todos.general) do
            table.insert(todos, todo)
        end
    end

    for _, profession in ipairs(NM:LoadCharacterCategories()) do
        local professionTodoList = NM.db.global.characters[NM.guid].todos.professions[NM.professionalTypes[profession]]
        -- for _, profTodo in ipairs(professionTodoList) do
        --     table.insert(todos, profTodo)
        -- end
    end

    NM:Print("Found " .. #todos .. " for the current character")
    return todos;
end

function NM:ResetCompletedTodos()
    local characterTodos = NM.db.global.characters[NM.guid].todos
    local now = time()
    local dailyResetTimestamp = NM:GetDailyResetTimestamp(now)
    local weeklyResetTimestamp = NM:GetWeeklyResetTimestamp(now)

    NM:Print("Daily reset timestamp: " .. date("%Y-%m-%d %H:%M:%S", dailyResetTimestamp))
    NM:Print("Weekly reset timestamp: " .. date("%Y-%m-%d %H:%M:%S", weeklyResetTimestamp))

    local resetCount = 0

    -- Reset todos
    for _, todo in ipairs(characterTodos.general) do
        NM:ResetTodo(todo, dailyResetTimestamp, weeklyResetTimestamp, resetCount)
    end

    for profession, todoList in pairs(characterTodos.professions) do
        for _, todo in pairs(todoList) do
            NM:ResetTodo(todo, dailyResetTimestamp, weeklyResetTimestamp, resetCount, profession)
        end
    end

    if resetCount > 0 then
        NM:Log("Reset " .. resetCount .. " completed todos.")
    end
end

function NM:GetDailyResetTimestamp(now)
    return now - tonumber(date("%H", now)) * 3600 - tonumber(date("%M", now)) * 60
end

function NM:GetWeeklyResetTimestamp(now)
    local currentWeekday = tonumber(date("%w", now)) -- 0 = Sunday, 1 = Monday,..., 6 = Saturday
    if currentWeekday == 3 then -- Wednesday
        return now - tonumber(date("%H", now)) * 3600 - tonumber(date("%M", now)) * 60
    else
        local wednesdayThisWeek = now - (currentWeekday - 3) * 86400
        return wednesdayThisWeek - tonumber(date("%H", wednesdayThisWeek)) * 3600 - tonumber(date("%M", wednesdayThisWeek)) * 60
    end
end

function NM:ResetTodo(todo, dailyResetTimestamp, weeklyResetTimestamp, resetCount, profession)
    if todo.complete then
        local resetTimestamp
        if todo.frequency == 'daily' then
            resetTimestamp = dailyResetTimestamp
        elseif todo.frequency == 'weekly' then
            resetTimestamp = weeklyResetTimestamp
        end

        NM:Log("Todo '" .. todo.title .. "' was completed on " .. date("%Y-%m-%d %H:%M:%S", todo.completedAt) .. " and today is " .. date("%Y-%m-%d %H:%M:%S", time()) .. ". Checking if it needs to be reset...")

        if todo.completedAt < resetTimestamp then
            NM:Log("Todo '" .. todo.title .. "' needs to be reset.")
            todo.completedAt = nil
            todo.complete = false
            resetCount = resetCount + 1
            if profession then
                NM:Log("Reset profession todo: " .. todo.title .. " (" .. profession .. ")")
            else
                NM:Log("Reset todo: " .. todo.title)
            end
        else
            NM:Log("Todo '" .. todo.title .. "' does not need to be reset.")
        end
    end
end

function NM:AddTodo(type, assign, title, description, complete, frequency)
    local todo = {
        key = NM:CreateUniqueKeyForTodo(title),
        type = type,
        assignment = assign,
        title = title,
        description = description,
        complete = complete,
        frequency = frequency,
    }

    if type == "character" then
        table.insert(self.db.global.characters[assign].todos.general, todo)
    elseif type == "profession" then
        -- Add to Global alchemy
        table.insert(self.db.global.profession[assign], todo)
        -- Add to every character the todo of the profession
        for guid, _ in pairs(self.db.global.characters) do
            table.insert(self.db.global.characters[guid].todos.professions[assign], todo);
        end
    end
end

function NM:CheckTodo(todoKey, todoType, checked)
    if (todoType == "character") then
        for _, todo in pairs(self.db.global.characters[NM.guid].todos.general) do
            if todo ~= nil and todo.key == todoKey then
                todo.complete = checked
                if checked then
                    todo.completedAt = time()
                else
                    todo.completedAt = nil
                end
                NM:Log("Updated general todo: " .. todoKey)
                return;
            end
        end
    end

    for _, profession in ipairs(NM:LoadCharacterCategories()) do
        local professionKey = NM.professionalTypes[profession]
        local professionTodoList = NM.db.global.characters[NM.guid].todos.professions[professionKey]
        if professionTodoList then
            for _, todo in ipairs(professionTodoList) do
                if todo.key == todoKey then
                    todo.complete = checked
                    if checked then
                        todo.completedAt = time()
                    else
                        todo.completedAt = nil
                    end
                    NM:Log("Updated profession todo: " .. todoKey .. " (" .. profession .. ")")
                    return
                end
            end
        else
            NM:Log("No todo list found for profession: " .. profession)
        end
    end
    NM:Log("Todo not found: " .. todoKey)
end
