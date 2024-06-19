local NM = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), "NexusManager", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function ToItemID(itemString)
    if not itemString then
        return
    end

    --local printable = gsub(itemString, "\124", "\124\124");
    --ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");

    --local itemId = LA.TSM.GetItemID(itemString)

    local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, reforging, Name = string.find(itemString, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

    --ChatFrame1:AddMessage("Id: " .. Id .. " vs. " .. itemId);
    return tonumber(Id)
end


-- Funktion zum Erstellen der Charakterübersicht
local function CreateCharacterList()
    local characters = { "Charakter 1", "Charakter 2", "Charakter 3" }

    print("Create Character List in " .. tostring(container))

    for _, char in ipairs(characters) do
        local charGroup = AceGUI:Create("SimpleGroup")
        charGroup:SetLayout("Flow")
        charGroup:SetFullWidth(true)
        charGroup:SetHeight(200);

        local icon = AceGUI:Create("Icon")
        icon:SetImage("Interface\\ICONS\\INV_Misc_QuestionMark")
        icon:SetImageSize(32, 32)
        icon:SetWidth(50)

        local label = AceGUI:Create("Label")
        label:SetText(char)
        label:SetWidth(200)

        local star = AceGUI:Create("Icon")
        star:SetImage("Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_LADYLUCK")
        star:SetImageSize(32, 32)
        star:SetWidth(50)

        charGroup:AddChild(icon)
        charGroup:AddChild(label)
        charGroup:AddChild(star)

        container:AddChild(charGroup)
        print("Added Character Part")
        container:SetUserData("overViewCharGroup", charGroup)
    end

    return container;
end

-- Funktion zum Erstellen des Copy-Buttons
local function CreateCopyButton(container, text)
    local button = CreateFrame("Button", nil, container.frame, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetText("Copy Text")

    button:SetScript("OnClick", function()
        local secureFunc = [[
            local text = ...;
            CopyToClipboard(text);
        ]]
        RunScript(secureFunc, text)
    end)

    return button
end

-- Hauptfenster erstellen
local function CreateMainFrame()
    -- Anzahl der Taschen (0 bis 4 für normale Taschen)
    local numBags = 4

    -- Schleife durch alle Taschen
    for bag = 0, numBags do
        -- Anzahl der Slots in der aktuellen Tasche
        local numSlots = C_Container.GetContainerNumSlots(bag)

        -- Schleife durch alle Slots in der Tasche
        for slot = 1, numSlots do
            -- Hol den Item-Link aus dem Slot
            local itemID = C_Container.GetContainerItemID(bag, slot)

            -- Überprüfen, ob ein Item-Link vorhanden ist
            if itemID then
                -- Hol die Item-Informationen
                local itemName, itemLink = C_Item.GetItemInfo(itemID)

                -- Ausgabe des Item-Namens und Item-Links
                local itemID = ToItemID(itemLink)
                print("Item ID: " .. itemID .. ": " .. itemLink)
            end
        end
    end

    local mainFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "UIPanelDialogTemplate")
    mainFrame:SetSize(400, 300)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()

    local tabs = {}
    local tabNames = { "Overview", "To-Dos", "Statistiks" }
    local tabContainers = {}

    -- Tab Containers erstellen
    for i = 1, #tabNames do
        local container = AceGUI:Create("SimpleGroup")
        --container:SetAllPoints(mainFrame)
        container.frame:Hide()
        tabContainers[i] = container
    end

    local overviewContainer = tabContainers[1]
    local todosContainer = tabContainers[2]
    local statsContainer = tabContainers[3]

    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", "MyAddonTab" .. i, mainFrame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(name)
        tab:SetScript("OnClick", function(self)
            PanelTemplates_SetTab(mainFrame, self:GetID())
            for j, tabContent in ipairs(tabContainers) do
                if j == self:GetID() and tabContent ~= nil then
                    if j == 1 and not overviewContainer.isInitialized then
                        tab.frame = CreateCharacterList()
                    elseif j == 2 and not todosContainer.isInitialized then
                        --local todoLabel = todosContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        --todoLabel:SetPoint("CENTER")
                        --todoLabel:SetText("To-Dos will be here")
                    elseif j == 3 and not statsContainer.isInitialized then
                        --local statsLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        --statsLabel:SetPoint("CENTER")
                        --statsLabel:SetText("Statistics will be here")
                        --statsContainer.isInitialized = true
                    end
                else
                    print("Hide Container " .. tostring(j))
                end
            end
        end)
        tab:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", (i - 1) * 100 + 15, 7)
        tabs[i] = tab
    end

    PanelTemplates_SetNumTabs(mainFrame, #tabs)
    PanelTemplates_SetTab(mainFrame, 1)

    mainFrame.Tabs = tabs
    mainFrame.TabContainers = { overviewContainer, todosContainer, statsContainer }

    return mainFrame
end

-- Hauptfenster Instanz
local mainFrame = CreateMainFrame()

-- Slash-Befehl registrieren
SLASH_MYADDON1 = "/nm"
SlashCmdList["MYADDON"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

