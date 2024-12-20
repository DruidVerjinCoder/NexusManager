local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale

function NM:CreateInterfaceOptions()
    -- Registriere die Addon-Kategorie in der Interface-Options
    local category, layout = Settings.RegisterCanvasLayoutCategory(
        NM.mainFrame, 
        "NexusManager",
        "NexusManager"
    )
    category.ID = "NexusManager" -- Unique identifier
    
    -- Erstelle die Einstellungsseite
    local options = {
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                minimap = {
                    type = "toggle",
                    name = L["Show Minimap Button"],
                    desc = L["Toggle the minimap button"],
                    get = function() return not NM.db.profile.minimap.hide end,
                    set = function(_, val) 
                        NM.db.profile.minimap.hide = not val
                        if val then
                            NM.minimapIcon:Show("NexusManager")
                        else
                            NM.minimapIcon:Hide("NexusManager")
                        end
                    end,
                    order = 1,
                }
                -- Weitere Einstellungen hier
            }
        }
    }

    -- Erstelle die Einstellungskategorie
    Settings.RegisterAddOnCategory(category)

    -- Erstelle die einzelnen Einstellungen
    local container = category:AddChild(CreateFrame("Frame"))
    container.layoutIndex = 1  -- Wichtig für die Reihenfolge
    
    -- Minimap Button Toggle
    local minimapCheck = Settings.CreateCheckBox(
        container, 
        "NexusManager_MinimapButton",
        L["Show Minimap Button"],
        L["Toggle the minimap button"],
        function(self, value)
            NM.db.profile.minimap.hide = not value
            if value then
                NM.minimapIcon:Show("NexusManager")
            else
                NM.minimapIcon:Hide("NexusManager")
            end
        end
    )
    minimapCheck:SetPoint("TOPLEFT", 10, -10)
    minimapCheck.layoutIndex = 2

    -- Weitere UI-Elemente hier...

    -- Initialisiere die Werte
    minimapCheck:SetValue(not NM.db.profile.minimap.hide)

    -- Registriere die Einstellungen
    Settings.LoadAddOnCategory(category)
end 