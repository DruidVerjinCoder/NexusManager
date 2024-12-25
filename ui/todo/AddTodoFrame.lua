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
        PROFESSIONS = NM.DB.PROFESSION_TYPES
    },
    
    -- State management
    state = {
        isValid = false,
        currentType = nil,
        formData = {},
        editMode = false,
        editKey = nil
    }
}

-- Private helper functions
local function validateTodoName(name)
    return name and name:len() >= AddTodoFrame.FORM_CONFIG.MIN_NAME_LENGTH
end

local function clearFormData()
    local editMode = AddTodoFrame.state.editMode
    local editKey = AddTodoFrame.state.editKey
    
    AddTodoFrame.state = {
        isValid = false,
        currentType = nil,
        formData = {
            title = "",
            description = "",
            frequency = "once",
            type = "character",
            assignment = ""
        },
        editMode = editMode,
        editKey = editKey
    }
    
end

-- Public methods
function AddTodoFrame:Create(todoToEdit)
    if self.window then
        self.window:Release()
    end
    
    -- Reset state and set edit mode if needed
    clearFormData()
    self.state.editMode = todoToEdit ~= nil
    self.state.editKey = todoToEdit and todoToEdit.key or nil
    
    -- Pre-fill form data if editing
    if todoToEdit then
        self.state.formData = {
            key = todoToEdit.key,  -- Explicitly set the key in formData
            title = todoToEdit.title or "",
            description = todoToEdit.description or "",
            frequency = todoToEdit.frequency or "once",
            type = todoToEdit.type or "character",
            assignment = todoToEdit.assignment or ""
        }
        self.state.currentType = todoToEdit.type
    end
    
    self.window = self:CreateWindow()
    self:CreateFormElements()
    self:SetupCallbacks()
    
    -- Update window title based on mode
    self.window:SetTitle(self.state.editMode and L["Edit Todo"] or L["Add Todo"])
    
    -- Pre-fill form elements if editing
    if todoToEdit then
        self.nameBox:SetText(todoToEdit.title)
        self.descBox:SetText(todoToEdit.description)
        self.freqDropdown:SetValue(todoToEdit.frequency)
        self.typeDropdown:SetValue(todoToEdit.type)
        
        -- Use C_Timer.After to ensure the type dropdown callback has completed
        C_Timer.After(0.1, function()
            if self.targetDropdown then
                self:UpdateTargetDropdown(todoToEdit.type)
                self.targetDropdown:SetValue(todoToEdit.assignment)
            end
        end)
    end
    
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

function AddTodoFrame:UpdateTargetDropdown(selectedType)
    local options = {}
    
    if selectedType == "profession" then
        options = self.DROPDOWN_OPTIONS.PROFESSIONS
    elseif selectedType == "character" then
        -- Get all characters from DB
        if NM.db and NM.db.global and NM.db.global.characters then
            for guid, charData in pairs(NM.db.global.characters) do
                options[guid] = charData.name
            end
        end
        
        -- If no characters found, at least add current character
        if not next(options) then
            local currentChar = NM.DB:GetCurrentCharacter()
            if currentChar then
                options[currentChar.guid] = currentChar.name
            end
        end
    end
    
    self.targetDropdown:SetList(options)
    
    -- If we're in edit mode and have an assignment, try to select it
    if self.state.editMode and self.state.formData.assignment then
        self.targetDropdown:SetValue(self.state.formData.assignment)
    else
        -- Default selection for new todos
        local firstKey = next(options)
        if firstKey then
            self.targetDropdown:SetValue(firstKey)
            self.state.formData.assignment = firstKey
        end
    end
    
    -- Force layout update
    self.targetDropdown:SetLabel(selectedType == "profession" and L["Profession"] or L["Character"])
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
    if not self.state.isValid then 
        return 
    end
    
    self.saveButton:SetText(L["Saving..."])
    self.saveButton:SetDisabled(true)
    
    local success
    if self.state.editMode and self.state.editKey then
        -- Create a complete new todo object
        local updatedTodo = {
            key = self.state.editKey,
            title = self.nameBox:GetText(),
            description = self.descBox:GetText(),
            frequency = self.freqDropdown:GetValue(),
            type = self.typeDropdown:GetValue(),
            assignment = self.targetDropdown:GetValue()
        }
        
        -- Ensure we have all required fields
        if not updatedTodo.title or not updatedTodo.type or not updatedTodo.assignment then
            return false
        end
        
        success = NM.DB:UpdateTodo(self.state.editKey, updatedTodo)
    else
        success = NM.DB:AddTodo(self.state.formData)
    end
    
    if success then
        NM:reloadScrollFrameTable()
        self:OnClose()
    else
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

-- Hilfsfunktion für Debug-Ausgaben (fügen Sie diese am Anfang der Datei hinzu)
if not NM.Utils then
    NM.Utils = {}
end

NM.Utils.tableToString = function(tbl)
    if type(tbl) ~= "table" then return tostring(tbl) end
    local result = "{"
    for k, v in pairs(tbl) do
        result = result .. "[" .. tostring(k) .. "] = " .. tostring(v) .. ", "
    end
    return result .. "}"
end
