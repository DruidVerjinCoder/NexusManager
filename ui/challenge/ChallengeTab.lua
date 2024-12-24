local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local ChallengeTab = {
    WINDOW_CONFIG = {
        DURATION_OPTIONS = {
            [300] = "5 " .. L["Minutes"],
            [600] = "10 " .. L["Minutes"],
            [1800] = "30 " .. L["Minutes"],
            [3600] = "1 " .. L["Hour"]
        },
        BUTTON_WIDTH = 150
    },
    
    ICONS = {
        PENDING = "Interface\\COMMON\\Indicator-Yellow",
        ACCEPTED = "Interface\\RAIDFRAME\\ReadyCheck-Ready",
        DECLINED = "Interface\\RAIDFRAME\\ReadyCheck-NotReady",
        OFFLINE = "Interface\\COMMON\\Indicator-Gray"
    }
}

function ChallengeTab:Create()
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Flow")
    container:SetFullWidth(true)
    container:SetHeight(400)
    
    -- Scroll Container für alles
    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Flow")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(400)
    container:AddChild(scrollContainer)
    
    -- Duration Dropdown
    local durationDropdown = AceGUI:Create("Dropdown")
    durationDropdown:SetLabel(L["Duration"])
    durationDropdown:SetList(self.WINDOW_CONFIG.DURATION_OPTIONS)
    durationDropdown:SetWidth(200)
    scrollContainer:AddChild(durationDropdown)
    
    -- Button Container
    local buttonContainer = AceGUI:Create("SimpleGroup")
    buttonContainer:SetLayout("Flow")
    buttonContainer:SetFullWidth(true)
    scrollContainer:AddChild(buttonContainer)
    
    -- Participants List with Rankings (initial versteckt)
    local participantsContainer = AceGUI:Create("InlineGroup")
    participantsContainer:SetTitle(L["Participants"])
    participantsContainer:SetLayout("List")
    participantsContainer:SetFullWidth(true)
    participantsContainer.frame:Hide()
    
    -- Scroll Frame für die Teilnehmerliste
    local participantsScroll = AceGUI:Create("ScrollFrame")
    participantsScroll:SetLayout("List")
    participantsScroll:SetFullWidth(true)
    participantsScroll:SetHeight(200)
    participantsContainer:AddChild(participantsScroll)
    
    -- Challenge Control Buttons nebeneinander
    -- Start Button zuerst erstellen
    local startButton = AceGUI:Create("Button")
    startButton:SetText(L["Start Challenge"])
    startButton:SetWidth(self.WINDOW_CONFIG.BUTTON_WIDTH)
    startButton:SetDisabled(true)  -- Initial deaktiviert
    startButton:SetCallback("OnClick", function()

        -- Starte Session des Leaders/Hosts
        if NM.session then
            NM.session:reset()
            NM.session.state = "running"
        end

        NM.Challenge:Start(NM.Challenge.participants)
    end)
    buttonContainer:AddChild(startButton)
    
    -- Dann den Invite Button
    local inviteButton = AceGUI:Create("Button")
    inviteButton:SetText(L["Send Invites"])
    inviteButton:SetWidth(self.WINDOW_CONFIG.BUTTON_WIDTH)
    inviteButton:SetCallback("OnClick", function()
        local duration = durationDropdown:GetValue()
        if duration then
            NM.Challenge:SendInvites(duration)
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()
            
            -- Host wird sofort als Teilnehmer hinzugefügt
            local playerName = UnitName("player")
            if not NM.Challenge.participants[playerName] then
                NM.Challenge.participants[playerName] = {
                    accepted = true,
                    isHost = true,
                    online = true
                }
                container:UpdateParticipants(NM.Challenge.participants, NM.Challenge.results)
            end
            
            -- Start Button sofort aktivieren
            startButton:SetDisabled(false)
        else
            NM:Print(L["Please select a duration first"])
        end
    end)
    buttonContainer:AddChild(inviteButton)
    
    -- Update Functions
    function container:UpdateParticipants(participants, results)
        participantsScroll:ReleaseChildren()
        
        -- Sortiere Teilnehmer nach LIV
        local sortedParticipants = {}
        for name, data in pairs(participants) do
            table.insert(sortedParticipants, {
                name = name,
                data = data,
                liv = results and results[name] and results[name].liv or 0
            })
        end
        table.sort(sortedParticipants, function(a, b) return a.liv > b.liv end)
        
        -- Erstelle Einträge
        for rank, participant in ipairs(sortedParticipants) do
            local playerRow = AceGUI:Create("SimpleGroup")
            playerRow:SetLayout("Flow")
            playerRow:SetFullWidth(true)
            
            -- Rang
            local rankLabel = AceGUI:Create("Label")
            rankLabel:SetText(rank .. ".")
            rankLabel:SetWidth(30)
            playerRow:AddChild(rankLabel)
            
            -- Status Icon nur anzeigen, wenn Challenge noch nicht gestartet ist
            if NM.Challenge.state ~= "running" then
                local statusIcon = AceGUI:Create("Icon")
                statusIcon:SetWidth(12)
                statusIcon:SetHeight(12)
                statusIcon:SetImageSize(12, 12)
                
                local iconPath
                if not participant.data.online then
                    iconPath = ChallengeTab.ICONS.OFFLINE
                elseif participant.data.declined then
                    iconPath = ChallengeTab.ICONS.DECLINED
                elseif participant.data.accepted then
                    iconPath = ChallengeTab.ICONS.ACCEPTED
                else
                    iconPath = ChallengeTab.ICONS.PENDING
                end
                
                statusIcon:SetImage(iconPath)
                playerRow:AddChild(statusIcon)
            end
            
            -- Spielername (mit Host-Markierung)
            local nameLabel = AceGUI:Create("Label")
            local displayName = participant.name
            if participant.data.isHost then
                displayName = displayName .. " |cffFFD700(Host)|r"
            end
            nameLabel:SetText(displayName)
            nameLabel:SetWidth(150)
            playerRow:AddChild(nameLabel)
            
            -- LIV (vereinfacht)
            local livLabel = AceGUI:Create("Label")
            livLabel:SetText(NM.UIFunctions:FormatGold(participant.liv))
            livLabel:SetWidth(100)
            playerRow:AddChild(livLabel)

            if NM.Challenge.state == "running" then
                local detailIcon = AceGUI:Create("Icon")
                detailIcon:SetWidth(16)
                detailIcon:SetHeight(16)
                detailIcon:SetImageSize(16, 16)
                detailIcon:SetImage("Interface\\Buttons\\UI-GuildButton-PublicNote-Up") -- Ein "i" Icon für Details
                detailIcon:SetCallback("OnClick", function()
                    print("Show details for ", participant.name)
                    NM.ChallengeTab:ShowItemDetails(participant.name)
                end)
                playerRow:AddChild(detailIcon)
            end
            
            participantsScroll:AddChild(playerRow)
        end

        if participants == nil then
            NM.Challenge:BroadcastMessage("UPDATE_PARTICIPANTS", participants)
        end

    end
    
    -- Neue UpdateResults Funktion
    function container:UpdateResults(sortedResults)
        if not sortedResults then return end
        
        -- Aktualisiere die Anzeige der Ergebnisse
        -- Zeige Platzierung, Name, LIV und optional Items/Gold
        for i, result in ipairs(sortedResults) do
            -- Hier die UI-Logik für die Anzeige der sortierten Ergebnisse
            -- z.B. mit einer ScrollList oder ähnlichem
            -- Platz #i: result.player - LIV: result.liv
        end
    end
    
    -- UI State Updates
    function container:UpdateUIState(state, isLeader)
        
        -- Zeige/Verstecke UI Elemente basierend auf dem Status
        if state == "inviting" then
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()
            
            -- Response Buttons werden nicht mehr benötigt
            -- responseContainer.frame:SetShown(not isLeader)
            
            -- UI Status
            durationDropdown:SetDisabled(true)
            inviteButton:SetDisabled(true)
            
            -- Start Button ist aktiv für Leader
            if isLeader then
                startButton:SetDisabled(false)
                -- Host wird automatisch als Teilnehmer hinzugefügt
                if not NM.Challenge.participants[UnitName("player")] then
                    NM.Challenge:Accept()
                end
            else
                startButton:SetDisabled(true)
            end
            
        elseif state == "running" then
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()
            durationDropdown:SetDisabled(true)
            inviteButton:SetDisabled(true)
            startButton:SetDisabled(true)
            
        else
            -- Kein aktiver Challenge-Status
            if participantsContainer.parent then
                participantsContainer.parent:Release(participantsContainer)
            end
            participantsContainer.frame:Hide()
            durationDropdown:SetDisabled(false)
            inviteButton:SetDisabled(false)
            startButton:SetDisabled(true)
        end
    end
    
    -- Initial UI State
    container:UpdateUIState(nil, false)
    
    NM.ui.challenge = container
    return container
end

function ChallengeTab:SetStartButtonEnabled(enabled)
    if self.startButton then
        self.startButton:SetEnabled(enabled)
    end
end

function ChallengeTab:OnStartButtonClick()
    if NM.Challenge then
        local duration = 3600  -- Standard: 1 Stunde
        NM.Challenge:Start(duration)
    end
end

function ChallengeTab:UpdateParticipants(participants, results)
    if not self.participantsContainer then return end
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(participants, results)
    end
end

-- Neue Funktion für Details-Ansicht
function ChallengeTab:ShowParticipantDetails(playerName, data)
    -- TODO: Implementiere Details-Fenster
    -- Hier können wir später ein Popup oder eine neue Ansicht erstellen,
    -- die detaillierte Informationen über den Teilnehmer anzeigt:
    -- - Gesammelte Items
    -- - Gelootetes Gold
    -- - LIV Entwicklung
    -- - etc.
    NM:Debug("Showing details for participant: %s", playerName)
end

function ChallengeTab:UpdateUIState(state, isHost)
    if not self.participantContainer then
        -- Container erstellen, falls er noch nicht existiert
        self.participantContainer = AceGUI:Create("InlineGroup")
        self.participantContainer:SetTitle(L["Participants"])
        self.participantContainer:SetLayout("List")
        self.participantContainer:SetFullWidth(true)
        self.participantContainer:SetHeight(200)
        self:AddChild(self.participantContainer)
    end
    
    -- Container sichtbar machen
    self.participantContainer.frame:Show()
    
    -- UI-Elemente basierend auf Status aktualisieren
    if state == "inviting" then
        -- Zeige Teilnehmerliste
        self.participantContainer:SetTitle(L["Waiting for participants..."])
    elseif state == "running" then
        self.participantContainer:SetTitle(L["Challenge in progress"])
    end
end

function ChallengeTab:UpdateParticipants(participants)
    if not self.participantContainer then return end
    
    -- Lösche bestehende Einträge
    self.participantContainer:ReleaseChildren()
    
    -- Füge Teilnehmer hinzu
    for name, data in pairs(participants) do
        local participantRow = AceGUI:Create("SimpleGroup")
        participantRow:SetLayout("Flow")
        participantRow:SetFullWidth(true)
        
        -- Name des Teilnehmers
        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText(name)
        nameLabel:SetWidth(150)
        
        -- Status des Teilnehmers
        local statusLabel = AceGUI:Create("Label")
        if data.accepted then
            statusLabel:SetText(L["Accepted"])
            statusLabel:SetColor(0, 1, 0) -- Grün
        elseif data.declined then
            statusLabel:SetText(L["Declined"])
            statusLabel:SetColor(1, 0, 0) -- Rot
        else
            statusLabel:SetText(L["Pending"])
            statusLabel:SetColor(1, 1, 0) -- Gelb
        end
        statusLabel:SetWidth(100)
        
        participantRow:AddChild(nameLabel)
        participantRow:AddChild(statusLabel)
        
        self.participantContainer:AddChild(participantRow)
    end
    
    -- Aktualisiere das Layout
    self.participantContainer:DoLayout()
end

-- Neue Funktion für den Item-Details Frame
function ChallengeTab:ShowItemDetails(playerName)
    -- Wenn Frame existiert, aktualisiere nur den Inhalt
    if self.itemDetailsFrame then
        if self.currentDetailPlayer == playerName then
            -- Gleicher Spieler - Frame schließen
            self.itemDetailsFrame:Hide()
            self.itemDetailsFrame = nil
            self.currentDetailPlayer = nil
            return
        else
            -- Anderer Spieler - Inhalt aktualisieren
            self.itemDetailsFrame:SetTitle(string.format(L["Items for %s"], playerName))
            self:UpdateItemList(playerName)
        end
    else
        -- Erstelle neuen Frame
        local frame = AceGUI:Create("Frame")
        frame:SetTitle(string.format(L["Items for %s"], playerName))
        frame:SetLayout("List")  -- Geändert zu List für bessere Kontrolle
        frame:SetWidth(300)
        frame:SetHeight(400)

        -- Header mit Sortierbuttons und Refresh
        local headerGroup = AceGUI:Create("SimpleGroup")
        headerGroup:SetLayout("Flow")
        headerGroup:SetFullWidth(true)
        headerGroup:SetHeight(25)

        -- Sortierbuttons
        local nameSort = AceGUI:Create("Button")
        nameSort:SetText(L["Name"])
        nameSort:SetWidth(120)
        nameSort:SetCallback("OnClick", function() 
            self:SortItems(playerName, "name") 
        end)
        headerGroup:AddChild(nameSort)

        local countSort = AceGUI:Create("Button")
        countSort:SetText(L["Count"])
        countSort:SetWidth(80)
        countSort:SetCallback("OnClick", function() 
            self:SortItems(playerName, "count") 
        end)
        headerGroup:AddChild(countSort)

        -- Refresh Button
        local refreshButton = AceGUI:Create("Icon")
        refreshButton:SetImage("Interface\\Buttons\\UI-RefreshButton")
        refreshButton:SetImageSize(16, 16)
        refreshButton:SetWidth(20)
        refreshButton:SetHeight(20)
        refreshButton:SetCallback("OnClick", function()
            self:UpdateItemList(playerName)
        end)
        headerGroup:AddChild(refreshButton)

        frame:AddChild(headerGroup)
        
        -- Scrollframe für Items
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        frame:AddChild(scroll)
        
        -- Speichere Referenzen
        frame.scroll = scroll
        self.itemDetailsFrame = frame
        
        -- Initialisiere Sortierung
        self.currentSort = {
            column = "name",
            ascending = true
        }
    end
    
    -- Speichere aktuellen Spieler
    self.currentDetailPlayer = playerName
    
    -- Initial Update
    self:UpdateItemList(playerName)
end

function ChallengeTab:SortItems(playerName, column)
    if self.currentSort.column == column then
        self.currentSort.ascending = not self.currentSort.ascending
    else
        self.currentSort.column = column
        self.currentSort.ascending = true
    end
    
    self:UpdateItemList(playerName)
end

function ChallengeTab:UpdateItemList(playerName)
    if not self.itemDetailsFrame or not self.itemDetailsFrame.scroll then return end
    
    local scroll = self.itemDetailsFrame.scroll
    scroll:ReleaseChildren()
    
    -- Items sammeln und sortieren
    local items = {}
    if NM.Challenge.results[playerName] and NM.Challenge.results[playerName].items then
        for itemID, count in pairs(NM.Challenge.results[playerName].items) do
            local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
            if itemName then
                table.insert(items, {
                    id = itemID,
                    name = itemName,
                    link = itemLink,
                    count = count,
                    rarity = itemRarity,
                    texture = itemTexture
                })
            end
        end
    end
    
    -- Sortierung anwenden
    table.sort(items, function(a, b)
        local aValue = a[self.currentSort.column]
        local bValue = b[self.currentSort.column]
        
        if self.currentSort.ascending then
            return aValue < bValue
        else
            return aValue > bValue
        end
    end)
    
    -- Items anzeigen
    for _, item in ipairs(items) do
        local itemRow = AceGUI:Create("SimpleGroup")
        itemRow:SetLayout("Flow")
        itemRow:SetFullWidth(true)
        
        -- Item Icon mit Tooltip
        local itemIcon = AceGUI:Create("Icon")
        itemIcon:SetWidth(24)
        itemIcon:SetHeight(24)
        itemIcon:SetImageSize(24, 24)
        itemIcon:SetImage(item.texture)
        itemIcon:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(itemIcon.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end)
        itemIcon:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        itemRow:AddChild(itemIcon)
        
        -- Item Name mit Tooltip
        local itemLabel = AceGUI:Create("InteractiveLabel")
        local displayText = item.name
        if item.count and item.count > 1 then
            displayText = displayText .. " x" .. item.count
        end
        itemLabel:SetText(displayText)
        itemLabel:SetWidth(200)
        
        -- Farbe basierend auf Seltenheit
        local r, g, b = C_Item.GetItemQualityColor(item.rarity)
        itemLabel:SetColor(r, g, b)
        
        -- Tooltip und Chat Link
        itemLabel:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(itemLabel.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end)
        itemLabel:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        itemLabel:SetCallback("OnClick", function()
            if IsShiftKeyDown() then
                ChatEdit_InsertLink(item.link)
            end
        end)
        
        itemRow:AddChild(itemLabel)
        scroll:AddChild(itemRow)
    end
end

NM.ChallengeTab = ChallengeTab
