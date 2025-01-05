local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Minimap = NM:NewModule("Minimap")

local defaults = {
    profile = {
        minimap = {
            hide = false,
            minimapPos = 220,
            radius = 80,
        }
    }
}

function Minimap:OnInitialize()
    -- Warte auf DB-Initialisierung
    if not NM.db then
        NM.db = LibStub("AceDB-3.0"):New("NexusManagerDB", defaults, true)
    end

    -- Stelle sicher, dass die minimap-Einstellungen existieren
    if not NM.db.profile.minimap then
        NM.db.profile.minimap = defaults.profile.minimap
    end

    local brokerObject = LDB:NewDataObject("NexusManager", {
        type = "launcher",
        icon = "Interface\\Icons\\inv_misc_bag_10",
        OnClick = function(_, button)
            if button == "LeftButton" then
                -- Toggle main window
                if IsControlKeyDown() then
                    NM.LogFrame:Show()
                else
                    NM:OpenNexusManager(nil)
                end
            elseif button == "RightButton" then
                -- Open options
                Settings.OpenToCategory("NexusManager")
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("NexusManager")
            tooltip:AddLine(L["Left Click: Toggle Window"])
            tooltip:AddLine(L["Right Click: Open Options"])
        end,
    })

    if brokerObject then
        LDBIcon:Register("NexusManager", brokerObject, NM.db.profile.minimap)
    end
end

function Minimap:OnEnable()
    if not NM.db.profile.minimap.hide then
        LDBIcon:Show("NexusManager")
    else
        LDBIcon:Hide("NexusManager")
    end
end

function Minimap:Toggle()
    NM.db.profile.minimap.hide = not NM.db.profile.minimap.hide
    if NM.db.profile.minimap.hide then
        LDBIcon:Hide("NexusManager")
    else
        LDBIcon:Show("NexusManager")
    end
end

NM.Minimap = Minimap