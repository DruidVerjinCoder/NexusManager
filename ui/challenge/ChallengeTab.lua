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

        -- Setze Challenge-Status auf "running"
        NM.Challenge.state = "running"

        -- Starte die Challenge
        NM.Challenge:Start(NM.Challenge.participants)
        
        -- Update UI Status auf "running"
        container:UpdateUIState("running", true)
        
        -- Aktualisiere die Teilnehmerliste
        container:UpdateParticipants(NM.Challenge.participants, NM.Challenge.results)
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
            
            -- Host wird sofort als Teilnehmer hinzugefügt und als Leader markiert
            local playerName = UnitName("player")
            if not NM.Challenge.participants[playerName] then
                NM.Challenge.participants[playerName] = {
                    accepted = true,
                    isHost = true,
                    isLeader = true,  -- Explizit als Leader markieren
                    online = true
                }
                -- UI sofort aktualisieren mit Leader-Status
                container:UpdateUIState("inviting", true)
                container:UpdateParticipants(NM.Challenge.participants, NM.Challenge.results)
            end
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
            
            -- Details Icon (immer anzeigen)
            local detailIcon = AceGUI:Create("Icon")
            detailIcon:SetWidth(16)
            detailIcon:SetHeight(16)
            detailIcon:SetImageSize(16, 16)
            detailIcon:SetImage("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            detailIcon:SetCallback("OnClick", function()
                NM.ChallengeTab:ShowItemDetails(participant.name)
            end)
            playerRow:AddChild(detailIcon)
            
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
            
            -- UI Status
            durationDropdown:SetDisabled(true)
            inviteButton:SetDisabled(true)
            
            -- Prüfe explizit ob wir der Host sind
            local playerName = UnitName("player")
            local isHost = NM.Challenge.participants[playerName] and NM.Challenge.participants[playerName].isHost
            
            -- Start Button ist aktiv für Leader/Host
            if isHost then
                startButton:SetDisabled(false)
            else
                startButton:SetDisabled(true)
            end
            
        elseif state == "running" then
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()
            
            -- Alle Buttons deaktivieren im "running" Status
            durationDropdown:SetDisabled(true)
            inviteButton:SetDisabled(true)
            startButton:SetDisabled(true)
            
            -- Aktualisiere auch den Challenge-Status
            if NM.Challenge then
                NM.Challenge.state = "running"
            end
            
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
    
    -- Aktualisiere auch die Navigation, wenn ein Details-Frame offen ist
    self:UpdateNavigation()
end

-- Neue Funktion für den Item-Details Frame
function ChallengeTab:ShowItemDetails(playerName)
    if not playerName then return end

    -- Erstelle neuen Frame mit Blizzard Template
    local frame = CreateFrame("Frame", "NMItemDetailsFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(400, 550)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Setze Portrait
    frame.portrait = frame.PortraitContainer.portrait
    
    -- Versuche zuerst das direkte Portrait
    SetPortraitTexture(frame.portrait, playerName)
    
    -- Wenn kein direktes Portrait, versuche Battle.net Avatar
    if not frame.portrait:GetTexture() then
        -- Name und Realm trennen
        local name, realm = strsplit("-", playerName)
        if not realm then
            realm = GetRealmName()
        end
        
        -- Setze Standard-Avatar
        frame.portrait:SetTexture("Interface\\CharacterFrame\\TEMPORARYPORTRAIT-FEMALE-BLOODELF")
        -- oder alternativ:
        -- frame.portrait:SetTexture("Interface\\CharacterFrame\\TEMPORARYPORTRAIT-MALE-BLOODELF")
    end
    
    -- Setze Titel
    frame.TitleContainer.TitleText:SetText(string.format(L["Items for %s"], playerName))
    
    -- Erstelle AceGUI Container
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("List")
    container:SetFullWidth(true)
    container:SetFullHeight(true)
    container.frame:SetParent(frame)
    container.frame:SetPoint("TOPLEFT", 10, -25)
    container.frame:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Header mit Sortierbuttons und Refresh
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)
    headerGroup:SetHeight(25)
    
    -- Container nach rechts verschieben
    headerGroup.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 85, -25)
    headerGroup.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -25)

    -- Spacer für Rechtsausrichtung
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(50)
    headerGroup:AddChild(spacer)

    -- Sortierbuttons
    local nameSort = AceGUI:Create("Button")
    nameSort:SetText(L["Name"])
    nameSort:SetWidth(150)
    nameSort:SetCallback("OnClick", function() 
        self:SortItems(playerName, "name") 
    end)
    headerGroup:AddChild(nameSort)

    local valueSort = AceGUI:Create("Button")
    valueSort:SetText(L["Value"])
    valueSort:SetWidth(100)
    valueSort:SetCallback("OnClick", function() 
        self:SortItems(playerName, "totalValue") 
    end)
    headerGroup:AddChild(valueSort)

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

    container:AddChild(headerGroup)
    
    -- Scrollframe für Items
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetHeight(350)
    container:AddChild(scroll)
    
    -- Stats Container
    local statsContainer = AceGUI:Create("InlineGroup")
    statsContainer:SetLayout("Flow")
    statsContainer:SetFullWidth(true)
    statsContainer:SetHeight(80)
    statsContainer:SetTitle(L["Statistics"])
    container:AddChild(statsContainer)
    
    -- Speichere Referenzen
    frame.container = container
    frame.scroll = scroll
    frame.statsContainer = statsContainer
    self.itemDetailsFrame = frame
    
    -- Close Button Event
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
        self.itemDetailsFrame = nil
        self.currentDetailPlayer = nil
    end)
    
    frame:Show()
    
    -- Speichere aktuellen Spieler
    self.currentDetailPlayer = playerName
    
    -- Initial Update mit leeren Stats
    self:UpdateStats({
        totalLIV = 0,
        lootedGold = 0,
        totalGold = 0
    })
    
    -- Dann Update der Items und Stats mit echten Daten
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
    if not self.itemDetailsFrame then return end
    
    local scroll = self.itemDetailsFrame.scroll
    scroll:ReleaseChildren()  -- Wichtig: Alle Kinder freigeben vor dem Neuaufbau
    
    -- Items sammeln und sortieren
    local items = {}
    local stats = {
        totalLIV = 0,
        lootedGold = 0,
        totalGold = 0
    }
    
    if NM.Challenge.results[playerName] then
        local result = NM.Challenge.results[playerName]
        stats.lootedGold = result.lootedGold or 0
        stats.totalGold = result.totalGold or 0
        
        if result.items then
            for itemID, count in pairs(result.items) do
                local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
                if itemName then
                    local itemValue = NM.TSM.GetItemValue(itemID, "DBRegionSaleAvg") or 0
                    local totalValue = itemValue * count
                    stats.totalLIV = stats.totalLIV + totalValue
                    
                    table.insert(items, {
                        id = itemID,
                        name = itemName,
                        link = itemLink,
                        count = count,
                        rarity = itemRarity,
                        texture = itemTexture,
                        value = itemValue,
                        totalValue = totalValue
                    })
                end
            end
        end
    end
    
    -- Stelle sicher, dass currentSort initialisiert ist
    if not self.currentSort then
        self.currentSort = {
            column = "totalValue",
            ascending = false
        }
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
    
    -- Items anzeigen mit Index-basiertem Highlighting
    for index, item in ipairs(items) do
        local itemRow = AceGUI:Create("SimpleGroup")
        itemRow:SetLayout("Flow")
        itemRow:SetFullWidth(true)
        itemRow:SetHeight(30)
        
        -- Alternierender Hintergrund basierend auf aktuellem Index
        if index % 2 == 0 then
            local bg = itemRow.frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        -- Hover Effekt
        itemRow.frame:SetScript("OnEnter", function()
            local highlight = itemRow.frame:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)  -- Hellerer Hintergrund beim Hover
        end)
        
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
        
        -- Item Name mit Count
        local itemLabel = AceGUI:Create("InteractiveLabel")
        local displayText = string.format("%s |cFF888888x%d|r", item.name, item.count)
        itemLabel:SetText(displayText)
        itemLabel:SetWidth(200)
        
        -- Farbe basierend auf Seltenheit
        local r, g, b = GetItemQualityColor(item.rarity)
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
        
        -- TSM Wert (Einzeln und Gesamt)
        local valueLabel = AceGUI:Create("Label")
        valueLabel:SetText(string.format("%s\n|cFF888888%s|r", 
            NM.UIFunctions:FormatGold(item.totalValue),
            NM.UIFunctions:FormatGold(item.value)))
        valueLabel:SetWidth(120)
        itemRow:AddChild(valueLabel)
        
        scroll:AddChild(itemRow)
    end
    
    -- Update Stats
    self:UpdateStats(stats)
end

function ChallengeTab:UpdateStats(stats)
    if not self.itemDetailsFrame then return end
    
    local statsContainer = self.itemDetailsFrame.container.children[3]
    statsContainer:ReleaseChildren()
    
    -- Erstelle zwei Spalten für Stats mit mehr Abstand
    local leftStats = AceGUI:Create("SimpleGroup")
    leftStats:SetLayout("Flow")
    leftStats:SetWidth(190)
    leftStats:SetHeight(80)  -- Erhöhte Höhe für mehr Abstand
    
    local rightStats = AceGUI:Create("SimpleGroup")
    rightStats:SetLayout("Flow")
    rightStats:SetWidth(190)
    rightStats:SetHeight(80)  -- Erhöhte Höhe für mehr Abstand
    
    -- Linke Spalte: Items LIV
    local livGroup = AceGUI:Create("SimpleGroup")
    livGroup:SetLayout("Flow")
    livGroup:SetFullWidth(true)
    livGroup:SetHeight(25)  -- Höhe für eine Zeile
    
    local livLabel = AceGUI:Create("Label")
    livLabel:SetText(L["Items LIV"] .. ":")
    livLabel:SetWidth(100)
    livGroup:AddChild(livLabel)
    
    local livValue = AceGUI:Create("Label")
    livValue:SetText(NM.UIFunctions:FormatGold(stats.totalLIV))
    livValue:SetWidth(80)
    livGroup:AddChild(livValue)
    
    leftStats:AddChild(livGroup)
    
    -- Rechte Spalte: Looted Gold
    local lootedGroup = AceGUI:Create("SimpleGroup")
    lootedGroup:SetLayout("Flow")
    lootedGroup:SetFullWidth(true)
    lootedGroup:SetHeight(25)  -- Höhe für eine Zeile
    
    local lootedLabel = AceGUI:Create("Label")
    lootedLabel:SetText(L["Looted Gold"] .. ":")
    lootedLabel:SetWidth(100)
    lootedGroup:AddChild(lootedLabel)
    
    local lootedValue = AceGUI:Create("Label")
    lootedValue:SetText(NM.UIFunctions:FormatGold(stats.lootedGold))
    lootedValue:SetWidth(80)
    lootedGroup:AddChild(lootedValue)
    
    rightStats:AddChild(lootedGroup)
    
    -- Abstand zwischen den Zeilen
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetFullWidth(true)
    spacer:SetHeight(5)
    rightStats:AddChild(spacer)
    
    -- Total Gold
    local totalGroup = AceGUI:Create("SimpleGroup")
    totalGroup:SetLayout("Flow")
    totalGroup:SetFullWidth(true)
    totalGroup:SetHeight(25)  -- Höhe für eine Zeile
    
    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText(L["Total Gold"] .. ":")
    totalLabel:SetWidth(100)
    totalGroup:AddChild(totalLabel)
    
    local totalValue = AceGUI:Create("Label")
    totalValue:SetText(NM.UIFunctions:FormatGold(stats.totalGold))
    totalValue:SetWidth(80)
    totalGroup:AddChild(totalValue)
    
    rightStats:AddChild(totalGroup)
    
    -- Füge beide Spalten zum Container hinzu
    statsContainer:AddChild(leftStats)
    statsContainer:AddChild(rightStats)
end

-- Hilfsfunktion zum Finden der UnitID
function NM:GetUnitIDFromName(fullName)
    -- Trenne Name und Realm
    local name, realm = strsplit("-", fullName)
    if not realm then
        realm = GetRealmName() -- Aktueller Realm wenn keiner angegeben
    end
    
    -- Normalisiere Realmnamen (entferne Leerzeichen etc.)
    realm = realm:gsub("%s+", "")
    
    -- Prüfe Party
    for i = 1, GetNumSubgroupMembers() do
        local unitName, unitRealm = UnitName("party" .. i)
        if not unitRealm then unitRealm = GetRealmName() end
        unitRealm = unitRealm:gsub("%s+", "")
        
        if name == unitName and realm == unitRealm then
            return "party" .. i
        end
    end
    
    -- Prüfe Raid
    for i = 1, GetNumGroupMembers() do
        local unitName, unitRealm = UnitName("raid" .. i)
        if not unitRealm then unitRealm = GetRealmName() end
        unitRealm = unitRealm:gsub("%s+", "")
        
        if name == unitName and realm == unitRealm then
            return "raid" .. i
        end
    end
    
    -- Prüfe ob es der Spieler selbst ist
    local playerName, playerRealm = UnitName("player")
    if not playerRealm then playerRealm = GetRealmName() end
    playerRealm = playerRealm:gsub("%s+", "")
    
    if name == playerName and realm == playerRealm then
        return "player"
    end
    
    -- Wenn keine Unit gefunden, versuche einen alternativen Weg
    -- Erstelle einen Button zum Laden des Avatars
    local loadAvatarButton = AceGUI:Create("Button")
    loadAvatarButton:SetText(L["Load Avatar"])
    loadAvatarButton:SetWidth(100)
    loadAvatarButton:SetCallback("OnClick", function()
        -- Öffne Freundesliste und suche nach dem Spieler
        C_FriendList.SendWho(fullName)
        -- Nach kurzer Verzögerung sollte das Avatar verfügbar sein
        C_Timer.After(1, function()
            -- Versuche das Portrait neu zu laden
            if self.itemDetailsFrame and self.itemDetailsFrame.portrait then
                SetPortraitTexture(self.itemDetailsFrame.portrait, fullName)
            end
        end)
    end)
    
    return nil, loadAvatarButton
end

NM.ChallengeTab = ChallengeTab

-- Füge diese neue Funktion hinzu
function ChallengeTab:UpdateNavigation()
    if self.itemDetailsFrame and self.itemDetailsFrame.UpdateNavigation then
        self.itemDetailsFrame.UpdateNavigation()
    end
end

-- Aktualisiere die bestehende UpdateResults Funktion
function ChallengeTab:UpdateResults(results)
    -- ... (bestehender Code) ...
    
    -- Aktualisiere auch die Navigation
    self:UpdateNavigation()
end

