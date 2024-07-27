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

function NM:reloadScrollFrameTable()
    NM.ui.todo.container:ReleaseChildren()

    NM.ui.todo.container:AddChild(NM.UIFunctions:createLabel("To-Do", 240))
    NM.ui.todo.container:AddChild(NM.UIFunctions:createLabel("", 30))
    NM.ui.todo.container:AddChild(NM.UIFunctions:createLabel("", 30))

    for _, todo in pairs(NM:GetPersonalTodos()) do
        local chkBox = NM.UIFunctions:createCheckBox(todo.title, todo.complete,
            function(self) NM:CheckTodo(todo.key, todo.type, self:GetValue()) end)
        chkBox:SetWidth(250)

        if todo.type == "profession" then
            chkBox:SetImage("Interface\\AddOns\\NexusManager\\Media\\profession\\" .. todo.assignment)
        end

        chkBox:SetDescription(todo.description)

        NM.ui.todo.container:AddChild(chkBox)

        local edit = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\settings_3", 20,
            "Todo-Bearbeiten")

        local delete = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\cross", 20,
            "Todo Löschen")
        delete:SetCallback("OnClick", function()
            NM:DeleteTodo(todo.key)
            NM:reloadScrollFrameTable()
        end)

        NM.ui.todo.container:AddChild(edit);
        NM.ui.todo.container:AddChild(delete);
    end
end

function NM:InitializePostrunContainer()
    NM.ui.postrun = AceGUI:Create("SimpleGroup")


    local farmName = NM.UIFunctions:createEditBox("Farm-Name", 0, function(widget, event, text)
        NM.session.farmName = text
        NM:Log("Farm-Name set to " .. text)
    end)

    NM.ui.postrun:AddChild(farmName)

    local multiLineEditBox = AceGUI:Create("MultiLineEditBox")
    multiLineEditBox:SetLabel("")
    local initialText = L["LA not running or paused. Please start or resume the session."];
    multiLineEditBox:SetText(initialText)
    multiLineEditBox:SetFocus()
    multiLineEditBox:SetWidth(325)
    multiLineEditBox:DisableButton(true)
    multiLineEditBox:SetNumLines(14)

    NM.ui.postrun:SetUserData("postrunBox", multiLineEditBox)

    NM.ui.postrun:AddChild(multiLineEditBox)

    ---- Aktionen
    local sessionActions = AceGUI:Create("ScrollFrame")
    sessionActions:SetLayout("Table")
    sessionActions:SetUserData("table", {
        columns = { 75, 75, 150 },
        align = "CENTER"
    })
    sessionActions:SetFullWidth(true)
    sessionActions:SetHeight(60)
    if sessionActions.frame.GetBackdrop then
        sessionActions.frame:SetBackdrop(nil);
    end

    -- Aktionen
    local addIcon = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\add", 25,
        "State die session")
    addIcon:SetCallback("OnClick", function()
        local isSessionRunning = NM.LA.Session.IsRunning()
        local isSessionPaused = NM.LA.Session.IsPaused();

        if not isSessionRunning then
            NM.session:start()
        elseif isSessionPaused and isSessionRunning then
            NM.session:restart()
        else
            NM.session:pause()
        end
        NM.LA.UI.ShowMainWindow(true)
    end);

    sessionActions:AddChild(addIcon)

    local reload = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\replay", 25,
        "Lade die Todo's neu")
    reload:SetCallback("OnClick", function()
        NM:LoadMissingProfessionTodoToCharacter();
        NM:reloadScrollFrameTable()
    end);
    sessionActions:AddChild(reload)

    NM.ui.postrun:AddChild(sessionActions)

    NM:Log("After initializing postrunContainer")
    return NM.ui.postrun;
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
    local addIcon = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\add", 25,
        "Neues Todo anlegen")
    addIcon:SetCallback("OnClick", function()
        NM.createTodo:Create();
    end);
    buttonContainer:AddChild(addIcon)

    local reload = NM.UIFunctions:createInteractiveImage("Interface\\AddOns\\NexusManager\\Media\\replay", 25,
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
        columns = { 310, 30, 30 },
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
    if NM.ui.postrun and NM.session.state == 'running' then
        NM.ui.postrun:GetUserData("postrunBox"):SetText(NM.session:GetPostrunMsg())
    end
end

function NM:CreateMainFrame()
    if NM.mainFrame == nil or NM.mainFrame.isInitialized == false then
        local mainFrame = CreateFrame("Frame", mainFrameName, UIParent, "PortraitFrameFlatTemplate")
        mainFrame:SetScript("OnUpdate", function(_, elapsed)
            mainUiTotal = mainUiTotal + elapsed
            if mainUiTotal >= 1 then
                reloadPostrunContainer()
            end

            if elapsed >= 25 then
                NM:Log("Update Backup String")
            end
        end)
        local portraitTexture = mainFrame:CreateTexture(nil, "OVERLAY")
        portraitTexture:SetDrawLayer("ARTWORK", 2)
        portraitTexture:SetTexture("Interface\\AddOns\\NexusManager\\Media\\cm_icon")
        portraitTexture:SetSize(53.1, 53.1)
        portraitTexture:SetPoint("TOPLEFT", mainFrame.PortraitContainer.portrait, "TOPLEFT", 3.5, -3)
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
        local tabNames = { "To-Dos", "Postrun", "Items", "Backup" }
        local tabContainers = {}

        for i = 1, #tabNames do
            local container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container:SetHeight(200);
            container:SetWidth(200);
            container.frame:SetParent(mainFrame)
            container.frame:SetAllPoints(mainFrame)
            container.frame:Hide()
            tabContainers[i] = container
        end

        local todosContainer = tabContainers[1]
        local postrunContainer = tabContainers[2]
        local itemContainer = tabContainers[3]
        local backupContainer = tabContainers[4]

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
                        tabContent.frame:SetPoint("TOPLEFT", mainFrameName, "TOPLEFT", 10, -30)
                        postrunContainer:AddChild(NM:InitializePostrunContainer())
                        NM.currentTab = "postrun"
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
