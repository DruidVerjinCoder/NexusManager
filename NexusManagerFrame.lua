NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")

function NM:CreateFrame()
    NM:Print("Initialize Frame the first time")
    
    MyAddonMainFrame = CreateFrame("Frame", "NexusManager" , UIParent, "PortraitFrameFlatTemplate")
    MyAddonMainFrame:SetSize(400, 300)
    MyAddonMainFrame:SetPoint("CENTER")
    MyAddonMainFrame:SetFrameStrata("HIGH")
    MyAddonMainFrame:EnableMouse(true)
    MyAddonMainFrame:SetMovable(true)
    MyAddonMainFrame:RegisterForDrag("LeftButton")
    MyAddonMainFrame:SetScript("OnDragStart", MyAddonMainFrame.StartMoving)
    MyAddonMainFrame:SetScript("OnDragStop", MyAddonMainFrame.StopMovingOrSizing)
    
    NM.Frame = MyAddonMainFrame
end
