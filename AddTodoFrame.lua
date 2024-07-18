local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")

NM.createTodo = {}

function NM.createTodo:Create()
    -- Erstelle ein Fenster
    local window = NM.UIFunctions:createWindow("Todo Liste", "Flow", 280, 350, false, NM.mainFrame)

    -- Erstelle das Eingabefeld für den Todo-Namen
    local nameBox = NM.UIFunctions:createEditBox("Todo-Name", 260);
    window:AddChild(nameBox)

    -- Erstelle das Eingabefeld für die Todo-Beschreibung
    local descBox = NM.UIFunctions:createMultiLineEditBox("Todo-Beschreibung (optional)", 260, 5)
    window:AddChild(descBox)

    -- Erstelle das Dropdown-Menü für die Frequenz
    local dropdownFreq = NM.UIFunctions:createDropdown("Frequenz", 260, {
        ["weekly"] = "Wöchentlich",
        ["daily"] = "Täglich",
        ["once"] = "Einmalig"
    })

    local assignTodoDropdown = NM.UIFunctions:createDropdown("Typ", 260, {
        ["profession"] = "Beruf",
        ["character"] = "Charakter",
    });

    local selectionDropdown = NM.UIFunctions:createDropdown(" ", 260, {})

    assignTodoDropdown:SetCallback("OnValueChanged", function(self, event)
        local value = assignTodoDropdown:GetValue(NM.guid, nil)
        if (value == "profession") then
            NM.UIFunctions:refreshDropdownOptions(selectionDropdown, "Professions", {
                ["alchemy"] = "Alchemie",
                ["inscription"] = "Inschriftenkunde",
                ["enchanting"] = "Verzauberungskunst",
                ["mining"] = "Bergbau",
                ["skinning"] = "Kürschnerei",
                ["blacksmithing"] = "Schmiedekunst",
                ["tailoring"] = "Schneideri",
                ["jewelcrafting"] = "Juwelierkunst",
                ["fishing"] = "Angeln",
                ["archeology"] = "Archiologie",
                ["herbalism"] = "Kräuterkunde",
                ["engineering"] = "Ingenieuskunst",
                ["cooking"] = "Kochen",
                ["leatherworking"] = "Lederverarbeitung"
            });
        end
        if value == "character" then
            NM.UIFunctions:refreshDropdownOptions(selectionDropdown, "Character", NM:LoadCharacterNames());
        end
    end)

    window:AddChild(dropdownFreq)
    window:AddChild(assignTodoDropdown)
    window:AddChild(selectionDropdown)

    local saveButton = NM.UIFunctions:createButton("Save", 260, function()
        local todoName = nameBox:GetText()
        local todoDesc = descBox:GetText()
        local todoFreq = dropdownFreq:GetValue()
        local todoType = assignTodoDropdown:GetValue();

        -- here is the character or the profession stuff
        local assignGoal = selectionDropdown:GetValue();
        NM:AddTodo(todoType, assignGoal, todoName, todoDesc, false, todoFreq)
        NM:Print("Added a new todo")
        NM:reloadScrollFrameTable()
        NM:Log("Reloaded Todo")
        window:Release()
    end);
    saveButton:SetDisabled(true)
    -- Erstelle den Speichern-Button
    window:AddChild(saveButton)

    -- Validierungsfunktion
    local function ValidateInput()
        local todoName = nameBox:GetText()
        local todoFreq = dropdownFreq:GetValue()
        local type = assignTodoDropdown:GetValue()
        local target = selectionDropdown:GetValue()

        if todoName ~= "" and todoFreq ~= nil and type ~= "" and target ~= "" then
            saveButton:SetDisabled(false)
        else
            saveButton:SetDisabled(true)
        end
    end

    -- Event-Listener hinzufügen
    nameBox:SetCallback("OnTextChanged", ValidateInput)
    selectionDropdown:SetCallback("OnValueChanged", ValidateInput)

    NM.ui.todo.add = window;
end
