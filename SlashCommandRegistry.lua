local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")

function NM:CreateMainFrame()
    MyAddonMainFrame = CreateFrame("Frame", nil , UIParent, "PortraitFrameFlatTemplate")
    MyAddonMainFrame:SetSize(400, 300)
    MyAddonMainFrame:SetPoint("CENTER")
    MyAddonMainFrame:SetFrameStrata("HIGH")
    MyAddonMainFrame:EnableMouse(true)
    MyAddonMainFrame:SetMovable(true)
    MyAddonMainFrame:RegisterForDrag("LeftButton")
    MyAddonMainFrame:SetScript("OnDragStart", MyAddonMainFrame.StartMoving)
    MyAddonMainFrame:SetScript("OnDragStop", MyAddonMainFrame.StopMovingOrSizing)

    -- Create Tab1 Frame
    MyAddonMainFrame.tab1 = CreateFrame("Frame", "MyAddonTab1Frame", MyAddonMainFrame)
    MyAddonMainFrame.tab1:SetSize(400, 270)
    MyAddonMainFrame.tab1:SetPoint("TOP", 0, -30)
    MyAddonMainFrame.tab1:Hide()

    -- Create Tab2 Frame
    MyAddonMainFrame.tab2 = CreateFrame("Frame", "MyAddonTab2Frame", MyAddonMainFrame)
    MyAddonMainFrame.tab2:SetSize(400, 270)
    MyAddonMainFrame.tab2:SetPoint("TOP", 0, -30)
    MyAddonMainFrame.tab2:Hide()

    -- Tab-Wechsel Logik
    MyAddonMainFrame.selectedTab = 1
    PanelTemplates_SetNumTabs(MyAddonMainFrame, 2)
    PanelTemplates_SetTab(MyAddonMainFrame, 1)

    -- XML-Elemente für Tabs setzen
    for i = 1, 2 do
        local tab = CreateFrame("Button", "$parentTab"..i, MyAddonMainFrame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText("Tab "..i)
        tab:SetScript("OnClick", function(self)
            MyAddon_SelectTab(self:GetID())
        end)
        tab:SetPoint("TOPLEFT", MyAddonMainFrame, "BOTTOMLEFT", (i - 1) * 100, 7)
    end

    -- Select the initial tab
    MyAddon_SelectTab(1) 
end