NM = LibStub("AceAddon-3.0"):NewAddon("NexusManager","AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function NM:OnEnable()
    NM:RegisterChatCommand("nm","OpenNexusManager")
end

function NM:OpenNexusManager(input)
    if (input == "h" or input == "help") then
        local help_text = [[ Verwende /nm <Befehl>.
        Verfügbare Befehle:
            - status: Zeigt den aktuellen Status des Addons an
            - config: Öffnet das Konfigurationsfenster
        ]]
        NM:Print(help_text)
    elseif (input == "item") then
        local sName,sLink,iRarity,iLevel,iMinLevel,sType,sSubType,iStackCount = C_Item.GetItemInfo(35)
        NM:Print(sName)
    else
        if not NM.Frame then
            NM:CreateFrame()
        end
    end
end

