local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

function NM:OnEnable()
    print("Inside Minimap")
    NM.icon = LibStub("LibDBIcon-1.0")
    NM.LibDataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(NM.name, {
        type = "launcher",
        text = NM.name,
        icon = "Interface\\Addons\\"..NM.name.."\\assets\\cm_icon",

        OnClick = function(_, button, _)
            if button == "LeftButton" then
                NM:OpenNexusManager(nil)
            elseif button == "RightButton" then
                -- need to open it twice to show the submenu point of plugins
                Settings.OpenToCategory(NM.optionsFrame)
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine(NM.name)
            tooltip:AddLine("|cFFFFFFCCLeft-Click|r to open the main window")
            tooltip:AddLine("|cFFFFFFCCRight-Click|r to open options window")
            tooltip:AddLine("|cFFFFFFCCDrag|r to move this button")
        end
    })
    NM.icon:Register(NM.name, NM.LibDataBroker, NM.db.profile.general.minimap)
    NM.icon:Show(NM.name)
end