local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local AddTodoFrame = {
    WINDOW_CONFIG = {
        WIDTH = 280,
        HEIGHT = 350,
        ELEMENT_WIDTH = 260,
        TITLE = L["Add Todo"]
    },
    
    FORM_CONFIG = {
        DESCRIPTION_LINES = 5,
        MIN_NAME_LENGTH = 3
    },
    
    DROPDOWN_OPTIONS = {
        FREQUENCY = {
            ["weekly"] = L["Weekly"],
            ["daily"] = L["Daily"],
            ["once"] = L["Once"]
        },
        TYPE = {
            ["profession"] = L["Profession"],
            ["character"] = L["Character"]
        },
        PROFESSIONS = NM.DB.PROFESSION_TYPES -- Nutze die zentrale Definition aus DB
    },
    
    -- State management
    state = {
        isValid = false,
        currentType = nil,
        formData = {}
    }
}

-- Private helper functions
local function validateTodoName(name)
    return name and name:len() >= AddTodoFrame.FORM_CONFIG.MIN_NAME_LENGTH
end

local function clearFormData()
    AddTodoFrame.state.formData = {
        title = "",
        description = "",
        frequency = nil,
        type = nil,
        assignment = nil
    }
end

-- Public methods
function AddTodoFrame:Create()
    if self.window then
        self.window:Release()
    end
    
    clearFormData()
    self.window = self:CreateWindow()
    self:CreateFormElements()
    self:SetupCallbacks()
    
    NM.ui.todo.add = self.window
    return self.window
end

function AddTodoFrame:CreateWindow()
    local window = NM.UIFunctions:createWindow(
        self.WINDOW_CONFIG.TITLE,
        "Flow",
        self.WINDOW_CONFIG.WIDTH,
        self.WINDOW_CONFIG.HEIGHT,
        false,
        NM.mainFrame
    )
    
    window:SetCallback("OnClose", function()
        self:OnClose()
    end)
    
    return window
end

function AddTodoFrame:CreateFormElements()
    -- Name Input with validation feedback
    self.nameBox = NM.UIFunctions:createEditBox(L["Todo Name"], self.WINDOW_CONFIG.ELEMENT_WIDTH)
    self.nameBox:SetCallback("OnTextChanged", function(_, _, text)
        self.state.formData.title = text
        self:UpdateValidation()
    end)
    self.window:AddChild(self.nameBox)
    
    -- Description Input
    self.descBox = NM.UIFunctions:createMultiLineEditBox(
        L["Todo Description (optional)"],
        self.WINDOW_CONFIG.ELEMENT_WIDTH,
        self.FORM_CONFIG.DESCRIPTION_LINES
    )
    self.descBox:SetCallback("OnTextChanged", function(_, _, text)
        self.state.formData.description = text
    end)
    self.window:AddChild(self.descBox)
    
    -- Frequency Dropdown
    self.freqDropdown = self:CreateDropdown(
        L["Frequency"],
        self.DROPDOWN_OPTIONS.FREQUENCY,
        function(value) 
            self.state.formData.frequency = value
            self:UpdateValidation()
        end
    )
    
    -- Type Dropdown
    self.typeDropdown = self:CreateDropdown(
        L["Type"],
        self.DROPDOWN_OPTIONS.TYPE,
        function(value)
            self.state.formData.type = value
            self.state.currentType = value
            self:UpdateTargetDropdown(value)
            self:UpdateValidation()
        end
    )
    
    -- Target Selection Dropdown
    self.targetDropdown = self:CreateDropdown(
        " ",
        {},
        function(value)
            self.state.formData.assignment = value
            self:UpdateValidation()
        end
    )
    
    -- Save Button with loading state
    self.saveButton = NM.UIFunctions:createButton(L["Save"], self.WINDOW_CONFIG.ELEMENT_WIDTH, 
        function() self:SaveTodo() end
    )
    self.saveButton:SetDisabled(true)
    
    -- WICHTIG: Button zum Window hinzufügen
    self.window:AddChild(self.saveButton)
end

function AddTodoFrame:CreateDropdown(label, options, callback)
    local dropdown = NM.UIFunctions:createDropdown(
        label,
        self.WINDOW_CONFIG.ELEMENT_WIDTH,
        options
    )
    
    dropdown:SetCallback("OnValueChanged", function(_, _, value)
        if callback then callback(value) end
    end)
    
    self.window:AddChild(dropdown)
    return dropdown
end

function AddTodoFrame:UpdateTargetDropdown(todoType)
    local options = {}
    local label = " "
    
    if todoType == "profession" then
        options = self.DROPDOWN_OPTIONS.PROFESSIONS
        label = L["Professions"]
    elseif todoType == "character" then
        options = self:LoadCharacterNames()
        label = L["Character"]
    end
    
    NM.UIFunctions:refreshDropdownOptions(
        self.targetDropdown,
        label,
        options
    )
end

function AddTodoFrame:UpdateValidation()
    local isValid = (
        validateTodoName(self.state.formData.title) and
        self.state.formData.frequency and
        self.state.formData.type and
        self.state.formData.assignment
    )
    
    self.state.isValid = isValid
    self.saveButton:SetDisabled(not isValid)
end

function AddTodoFrame:SaveTodo()
    if not self.state.isValid then return end
    
    self.saveButton:SetText(L["Saving..."])
    self.saveButton:SetDisabled(true)
    
    local success = NM.DB:AddTodo(self.state.formData)
    
    if success then
        NM:Print(L["Added a new todo"])
        NM:reloadScrollFrameTable()
        self:OnClose()
    else
        NM:Print(L["Failed to add todo"])
        self.saveButton:SetText(L["Save"])
        self.saveButton:SetDisabled(false)
    end
end

function AddTodoFrame:OnClose()
    clearFormData()
    if self.window then
        self.window:Release()
        self.window = nil
    end
end

function AddTodoFrame:SetupCallbacks()
    -- Window callbacks
    self.window:SetCallback("OnClose", function()
        self:OnClose()
    end)

    -- Form element callbacks
    self.nameBox:SetCallback("OnTextChanged", function(_, _, text)
        self.state.formData.title = text
        self:UpdateValidation()
    end)
    
    self.descBox:SetCallback("OnTextChanged", function(_, _, text)
        self.state.formData.description = text
    end)
    
    self.freqDropdown:SetCallback("OnValueChanged", function(_, _, value)
        self.state.formData.frequency = value
        self:UpdateValidation()
    end)
    
    self.typeDropdown:SetCallback("OnValueChanged", function(_, _, value)
        self.state.formData.type = value
        self.state.currentType = value
        self:UpdateTargetDropdown(value)
        self:UpdateValidation()
    end)
    
    self.targetDropdown:SetCallback("OnValueChanged", function(_, _, value)
        self.state.formData.assignment = value
        self:UpdateValidation()
    end)
end

function AddTodoFrame:LoadCharacterNames()
    local names = {}
    local currentChar = NM.DB:GetCurrentCharacter()
    
    if not currentChar then return names end
    
    -- Add current character
    names[currentChar.id] = string.format("%s-%s", currentChar.name, currentChar.realm)
    
    -- Add other characters from global DB
    if NM.db and NM.db.global and NM.db.global.characters then
        for guid, char in pairs(NM.db.global.characters) do
            if guid ~= currentChar.id then
                names[guid] = string.format("%s-%s", char.name, char.realm)
            end
        end
    end
    
    return names
end

NM.AddTodoFrame = AddTodoFrame
