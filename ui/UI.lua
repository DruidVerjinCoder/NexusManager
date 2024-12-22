local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")

local mainFrameName = "NexusManagerFrame"
local L = NM.Locale
NM.mainFrame = nil

local mainUiTotal = 0

NM.ui = {
    todo = {
        add = {
        },
        delete = {
        },
        update = {
        }
    }
}

function NM:DeleteTodo(todoKey)
    if not todoKey then
        NM:Log("Error: No todo key provided for deletion")
        return false
    end

    local success = NM.DB:DeleteTodo(todoKey)
    
    if success then
        NM:Print(L["Todo deleted"])
        self:reloadScrollFrameTable()
    else
        NM:Print(L["Failed to delete todo"])
    end
    
    return success
end

function NM:reloadScrollFrameTable()
    if not NM.ui.todo.container then return end
    
    -- Clear existing content
    NM.ui.todo.container:ReleaseChildren()
    
    -- Get all todos
    local todos = NM.DB:GetTodos()
    
    -- Sort todos (optional)
    table.sort(todos, function(a, b)
        if a.frequency ~= b.frequency then
            -- Sortiere nach Frequenz: daily > weekly > once
            local order = {daily = 1, weekly = 2, once = 3}
            return order[a.frequency] < order[b.frequency]
        end
        return a.title < b.title
    end)
    
    -- Add todos to container
    for _, todo in ipairs(todos) do
        local chkBox = NM.UIFunctions:createCheckBox(todo.title, todo.complete,
            function(self) 
                NM:Log("Checking todo: " .. todo.title)
                NM:Log("Key: " .. (todo.key or "nil"))
                NM:Log("Type: " .. (todo.type or "nil"))
                NM.DB:CheckTodo(todo) -- Übergebe das gesamte todo-Objekt
            end)
        chkBox:SetWidth(250)

        if todo.type == "profession" then
            chkBox:SetImage("Interface\\AddOns\\NexusManager\\assets\\profession\\" .. todo.assignment)
        end

        chkBox:SetDescription(todo.description)
        
        -- Add reset time tooltip
        chkBox:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(chkBox.frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(todo.title)
            
            if todo.description and todo.description ~= "" then
                GameTooltip:AddLine(todo.description, 1, 1, 1, true)
            end
            
            -- Add reset time
            if todo.frequency == "daily" then
                local resetIn = GetQuestResetTime()
                local hours = math.floor(resetIn / 3600)
                local minutes = math.floor((resetIn % 3600) / 60)
                GameTooltip:AddLine(string.format(L["Resets in: %d hours and %d minutes"], hours, minutes), 0.8, 0.8, 0.8)
            elseif todo.frequency == "weekly" then
                local resetIn
                -- Versuche verschiedene Methoden für den Weekly Reset
                if C_WeeklyRewards and C_WeeklyRewards.GetNextWeeklyRewardReset then
                    resetIn = C_WeeklyRewards.GetNextWeeklyRewardReset() - time()
                elseif C_DateAndTime and C_DateAndTime.GetNextWeeklyResetTime then
                    resetIn = C_DateAndTime.GetNextWeeklyResetTime() - time()
                else
                    local questReset = GetQuestResetTime()
                    if questReset < (3 * 86400) then
                        resetIn = questReset + (4 * 86400)
                    else
                        resetIn = questReset
                    end
                end
                
                local days = math.floor(resetIn / 86400)
                local hours = math.floor((resetIn % 86400) / 3600)
                GameTooltip:AddLine(string.format(L["Resets in: %d days and %d hours"], days, hours), 0.8, 0.8, 0.8)
            end
            
            -- Add key in gray (for debugging/admin purposes)
            if todo.key then
                GameTooltip:AddLine(" ")  -- Empty line as separator
                GameTooltip:AddLine("ID: " .. todo.key, 0.7, 0.7, 0.7)
            end
            
            GameTooltip:Show()
        end)
        
        chkBox:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        NM.ui.todo.container:AddChild(chkBox)

        local edit = NM.UIFunctions:createInteractiveImage(
            "Interface\\AddOns\\NexusManager\\assets\\icons\\setting",
            20,
            L["Edit Todo"]
        )
        edit:SetCallback("OnClick", function()
            -- Debug output for todo being edited
            NM:Log("=== Starting Todo Edit ===")
            NM:Log("Todo being edited:")
            for k, v in pairs(todo) do
                NM:Log("  " .. k .. ": " .. tostring(v))
            end
            
            NM.AddTodoFrame:Create(todo)
        end)

        local delete = NM.UIFunctions:createInteractiveImage(
            "Interface\\AddOns\\NexusManager\\assets\\icons\\trash",
            20,
            L["Delete Todo"]
        )
        delete:SetCallback("OnClick", function()
            if todo.type == "profession" then
                -- Show confirmation dialog for profession todos
                StaticPopupDialogs["NEXUSMANAGER_CONFIRM_DELETE"] = {
                    text = L["This will delete the todo for all characters with this profession. Are you sure?"],
                    button1 = L["Yes"],
                    button2 = L["No"],
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                    OnAccept = function()
                        if NM.DB:DeleteTodo(todo.key, todo.type, todo.assignment) then
                            NM:Print(L["Todo deleted"])
                            NM:reloadScrollFrameTable()
                        else
                            NM:Print(L["Failed to delete todo"])
                        end
                    end,
                }
                StaticPopup_Show("NEXUSMANAGER_CONFIRM_DELETE")
            else
                -- Direct deletion for character todos
                if NM.DB:DeleteTodo(todo.key, todo.type, todo.assignment) then
                    NM:Print(L["Todo deleted"])
                    NM:reloadScrollFrameTable()
                else
                    NM:Print(L["Failed to delete todo"])
                end
            end
        end)

        NM.ui.todo.container:AddChild(edit)
        NM.ui.todo.container:AddChild(delete)
    end
    
    -- Force UI update
    NM.ui.todo.container:DoLayout()
end

function NM:InitializeTodoTabContainer()
    local mainContainer = AceGUI:Create("SimpleGroup")

    ---- Aktionen
    local buttonContainer = AceGUI:Create("ScrollFrame")
    buttonContainer:SetLayout("Table")
    buttonContainer:SetUserData("table", {
        columns = { 150, 150 },
        align = "CENTER"
    })
    buttonContainer:SetFullWidth(true)
    buttonContainer:SetHeight(60)

    local btnContainerBackDrop = buttonContainer.frame.GetBackdrop or false;
    if btnContainerBackDrop then
        buttonContainer.frame:SetBackdrop(nil);
    end

    -- Aktionen
    local addIcon = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\assets\\icons\\plus", 25,
        "Neues Todo anlegen")
    addIcon:SetCallback("OnClick", function()
        NM.AddTodoFrame:Create();
    end);
    buttonContainer:AddChild(addIcon)

    local reload = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\assets\\icons\\recycle", 25,
        "Lade die Todo's neu")
    reload:SetCallback("OnClick", function()
        NM:LoadMissingProfessionTodoToCharacter();
        NM:reloadScrollFrameTable()
    end);
    buttonContainer:AddChild(reload)

    mainContainer:AddChild(buttonContainer)

    local todoContainer = AceGUI:Create("ScrollFrame")
    todoContainer:SetLayout("Table")
    todoContainer:SetUserData("table", {
        columns = { 240, 30, 30 },
        space = 1,
        align = "LEFT"
    })

    local hasItemTableBackdrop = todoContainer.frame.GetBackdrop or false;
    if hasItemTableBackdrop then
        todoContainer.frame:SetBackdrop(nil);
    end

    todoContainer:SetFullWidth(true)
    todoContainer:SetHeight(300)

    NM.ui.todo.container = todoContainer;
    mainContainer:AddChild(todoContainer)

    NM:reloadScrollFrameTable()

    return mainContainer;
end

local function reloadPostrunContainer()
    if NM.ui.postrun then
        -- Prüfe ob die Session pausiert ist
        if not NM.session or NM.session.state == "paused" then
            return
        end
        
        -- Nur aktualisieren wenn die Session läuft
        if NM.session.state == "running" then
            NM.ui.postrun.output:SetText(NM.session:GetPostrunMsg())
        end
    end
end

function NM:CreateMainFrame()
    if NM.mainFrame == nil or NM.mainFrame.isInitialized == false then
        local mainFrame = CreateFrame("Frame", mainFrameName, UIParent, "PortraitFrameFlatTemplate")
        local portraitTexture = mainFrame:CreateTexture(nil, "OVERLAY")
        portraitTexture:SetDrawLayer("ARTWORK", 2)
        portraitTexture:SetTexture("Interface\\AddOns\\NexusManager\\assets\\cm_icon")
        portraitTexture:SetSize(53.1, 53.1)
        portraitTexture:SetPoint("TOPLEFT", mainFrame.PortraitContainer.portrait, "TOPLEFT", 3.5, -3)

        mainFrame:SetScript("OnUpdate", function(_, elapsed)
            mainUiTotal = mainUiTotal + elapsed
            if mainUiTotal >= 1 then
                mainUiTotal = 0  -- Reset the counter
                reloadPostrunContainer()
            end

            if elapsed >= 25 then
                NM:Log("Update Backup String")
            end
        end)
        mainFrame:SetTitle("NexusManager")
        mainFrame:SetWidth(350)
        mainFrame:SetHeight(400)
        mainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -30);
        mainFrame:SetMovable(true)
        mainFrame:EnableMouse(true)
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
        mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
        mainFrame:Hide()

        local tabs = {}
        local tabNames = { "To-Dos", "Postrun", "Items", "Challenge" }
        local tabContainers = {}

        for i = 1, #tabNames do
            print("Create Container for " .. tabNames[i])
            local tabContainer = AceGUI:Create("SimpleGroup")
            tabContainer:SetLayout("Fill")
            tabContainer:SetHeight(200);
            tabContainer:SetWidth(200);
            tabContainer.frame:SetParent(mainFrame)
            tabContainer.frame:SetAllPoints(mainFrame)
            tabContainer.frame:Hide()
            tabContainers[i] = tabContainer
        end

        local todosContainer = tabContainers[1]
        local postrunContainer = tabContainers[2]
        local itemContainer = tabContainers[3]
        local challengeContainer = tabContainers[4]

        -- Funktion zur Aktualisierung der Tabs und Container
        local function UpdateTabs(selectedID)
            for j, tabContent in ipairs(tabContainers) do
                if j == selectedID and tabContent ~= nil then
                    tabContent.frame:Show()
                    if j == 1 then
                        tabContent.frame:SetPoint("TOPLEFT", mainFrameName, "TOPLEFT", 10, -30)
                        todosContainer:AddChild(NM:InitializeTodoTabContainer())
                        NM.currentTab = "todo"
                    elseif j == 2 then
                        tabContent.frame:SetPoint("TOPLEFT", mainFrameName, "TOPLEFT", 15, -50)
                        if not NM.ui.postrun then
                            NM.postrun:Create()
                            postrunContainer:AddChild(NM.ui.postrun)
                        end
                        NM.currentTab = "postrun" 
                    elseif j == 3 then
                        tabContent.frame:SetPoint("TOPLEFT", mainFrameName, "TOPLEFT", 15, -50)
                        if not NM.ui.items then
                            NM.ui.items = NM.ItemsContainer:Create()
                            itemContainer:AddChild(NM.ui.items)
                        end 
                        NM.currentTab = "items"
                    elseif j == 4 then
                        tabContent.frame:SetPoint("TOPLEFT", mainFrameName, "TOPLEFT", 10, -50)
                        if not NM.ui.challenge then
                            NM.ChallengeTab:Create()
                            challengeContainer:AddChild(NM.ui.challenge)
                        end
                        NM.currentTab = "challenge"
                    end
                else
                    tabContent.frame:Hide()
                end
            end
        end

        for i, name in ipairs(tabNames) do
            local tab = CreateFrame("Button", "MyAddonTab" .. i, mainFrame, "PanelTabButtonTemplate")
            tab:SetID(i)
            tab:SetText(name)
            tab:SetScript("OnClick", function(self)
                PanelTemplates_SetTab(mainFrame, self:GetID())
                UpdateTabs(self:GetID())
            end)
            tab:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", (i - 1) * 100 + 18, 2)
            tabs[i] = tab
        end

        PanelTemplates_SetNumTabs(mainFrame, #tabs)
        PanelTemplates_SetTab(mainFrame, 1)

        mainFrame.Tabs = tabs
        mainFrame.TabContainers = { todosContainer, postrunContainer, itemContainer, backupContainer }

        UpdateTabs(1)
        mainFrame.isInitialized = true

        mainFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)

        NM.mainFrame = mainFrame
    end
    NM.mainFrame:Show()
end

local function createProfessionLabel(profession)
    local label = NM.UIFunctions:createInteractiveLabel(profession)
    label:SetCallback("OnClick", function()
        if NM.DB and NM.DB.LoadMissingProfessionTodoToCharacter then
            NM.DB:LoadMissingProfessionTodoToCharacter()
        else
            NM:Log("Error: DB or LoadMissingProfessionTodoToCharacter not available")
        end
        
        -- Rest of your click handler code...
    end)
    return label
end
