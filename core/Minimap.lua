local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

-- Constants
local TOOLTIP_COLOR = "|cFFFFFFCC"
local TOOLTIP_TEXT = {
    TITLE = function(name) return name end,
    LEFT_CLICK = TOOLTIP_COLOR.."Left-Click|r to open the main window",
    RIGHT_CLICK = TOOLTIP_COLOR.."Right-Click|r to open options window",
    DRAG = TOOLTIP_COLOR.."Drag|r to move this button"
}

-- Local helper functions
local function HandleClick(_, button, _)
    if button == "LeftButton" then
        NM:OpenNexusManager(nil)
    elseif button == "RightButton" then
        -- need to open it twice to show the submenu point of plugins
        Settings.OpenToCategory("Interface")
        Settings.OpenToCategory(NM.optionsFrame)
    end
end

local function HandleTooltip(tooltip)
    tooltip:AddLine(TOOLTIP_TEXT.TITLE(NM.name))
    tooltip:AddLine(TOOLTIP_TEXT.LEFT_CLICK)
    tooltip:AddLine(TOOLTIP_TEXT.RIGHT_CLICK)
    tooltip:AddLine(TOOLTIP_TEXT.DRAG)
end

function NM:OnEnable()
    NM.icon = LibStub("LibDBIcon-1.0")
    NM.LibDataBroker = LibStub("LibDataBroker-1.1"):NewDataObject(NM.name, {
        type = "launcher",
        text = NM.name,
        icon = "Interface\\Addons\\"..NM.name.."\\assets\\cm_icon",
        OnClick = HandleClick,
        OnTooltipShow = HandleTooltip
    })
    
    NM.icon:Register(NM.name, NM.LibDataBroker, NM.db.profile.general.minimap)
    NM.icon:Show(NM.name)
end