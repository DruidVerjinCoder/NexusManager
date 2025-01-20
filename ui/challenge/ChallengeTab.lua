local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local AceGUI = LibStub("AceGUI-3.0")
local L = NM.Locale

local ChallengeTab = {
    WINDOW_CONFIG = {
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
    container:SetHeight(350)

    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Flow")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(350)
    container:AddChild(scrollContainer)

    local timerContainer = AceGUI:Create("SimpleGroup")
    timerContainer:SetLayout("Flow")
    timerContainer:SetFullWidth(true)
    timerContainer:SetHeight(40)

    local leftSpacer = AceGUI:Create("Label")
    leftSpacer:SetText("")
    leftSpacer:SetWidth(350)
    timerContainer:AddChild(leftSpacer)

    local timerLabel = AceGUI:Create("Label")
    timerLabel:SetText("00:00:00")
    timerLabel:SetWidth(200)
    timerLabel:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    timerLabel:SetJustifyH("CENTER")
    timerContainer:AddChild(timerLabel)

    self.timerLabel = timerLabel

    local rightSpacer = AceGUI:Create("Label")
    rightSpacer:SetText("")
    rightSpacer:SetWidth(350)
    timerContainer:AddChild(rightSpacer)

    scrollContainer:AddChild(timerContainer)

    local inputGroup = AceGUI:Create("SimpleGroup")
    inputGroup:SetLayout("Flow")
    inputGroup:SetFullWidth(true)
    inputGroup:SetHeight(30)

    local durationInput = AceGUI:Create("EditBox")
    durationInput:SetLabel(L["Duration (minutes)"])
    durationInput:SetWidth(80)
    durationInput:SetText("30")
    durationInput:SetMaxLetters(4)
    inputGroup:AddChild(durationInput)

    local resetButton = AceGUI:Create("Icon")
    resetButton:SetImage("Interface\\Buttons\\UI-RefreshButton")
    resetButton:SetImageSize(20, 20)
    resetButton:SetWidth(26)
    resetButton:SetHeight(26)
    resetButton:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(resetButton.frame, "ANCHOR_TOP")
        GameTooltip:SetText(L["Reset"])
        GameTooltip:Show()
    end)
    resetButton:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    resetButton:SetCallback("OnClick", function()
        if NM.Challenge and NM.Challenge.participants and next(NM.Challenge.participants) then
            NM.Challenge:BroadcastMessage("CHALLENGE_END", {
                message = L["Host has cancelled the challenge"],
                key = NM.Challenge.key
            })
        end
        if NM.Challenge then
            NM.Challenge:Reset()
        end
        container:UpdateUIState("initial", false)
    end)
    inputGroup:AddChild(resetButton)

    local buttonSpacer2 = AceGUI:Create("Label")
    buttonSpacer2:SetText("")
    buttonSpacer2:SetWidth(10)
    inputGroup:AddChild(buttonSpacer2)

    local participantsContainer = AceGUI:Create("InlineGroup")
    participantsContainer:SetTitle(L["Participants"])
    participantsContainer:SetLayout("List")
    participantsContainer:SetWidth(600)
    participantsContainer:SetHeight(100)
    participantsContainer.frame:Hide()

    local participantsScroll = AceGUI:Create("ScrollFrame")
    participantsScroll:SetLayout("List")
    participantsScroll:SetFullWidth(true)
    participantsScroll:SetHeight(150)
    participantsContainer:AddChild(participantsScroll)

    local buttonSpacer3 = AceGUI:Create("Label")
    buttonSpacer3:SetText("")
    buttonSpacer3:SetWidth(10)  -- Abstand zwischen Buttons
    inputGroup:AddChild(buttonSpacer3)

    local inviteButton = AceGUI:Create("Icon")
    inviteButton:SetImage("Interface\\Icons\\INV_Letter_15")
    inviteButton:SetImageSize(20, 20)
    inviteButton:SetWidth(26)
    inviteButton:SetHeight(26)
    inviteButton:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(inviteButton.frame, "ANCHOR_TOP")
        GameTooltip:SetText(L["Send Invites"])
        GameTooltip:Show()
    end)
    inviteButton:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    inviteButton:SetCallback("OnClick", function()
        local duration = NM.Challenge.duration
        if duration then
            NM.Challenge:SendInvites(duration)
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()

            local playerName = UnitName("player")
            if not NM.Challenge.participants[playerName] then
                NM.Challenge.participants[playerName] = {
                    accepted = true,
                    isHost = true,
                    isLeader = true,
                    online = true
                }

                container:UpdateUIState("inviting", true)
                container:UpdateParticipants(NM.Challenge.participants, NM.Challenge.results)

            end
        else
            NM:Print(L["Please select a duration first"])
        end
    end)
    inputGroup:AddChild(inviteButton)

    self.participantsContainer = participantsContainer
    self.participantsScroll = participantsScroll
    container.participantsContainer = participantsContainer

    scrollContainer:AddChild(inputGroup)

    startButton = AceGUI:Create("Icon")
    startButton:SetImage("Interface\\Icons\\INV_Letter_15")
    startButton:SetImageSize(20, 20)
    startButton:SetWidth(26)
    startButton:SetHeight(26)
    startButton:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(startButton.frame, "ANCHOR_TOP")
        GameTooltip:SetText(L["Start Challenge"])
        GameTooltip:Show()
    end)
    resetButton:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)

    startButton:SetCallback("OnClick", function()
        -- Starte Session des Leaders/Hosts
        if NM.session then
            NM.session:reset()
            NM.session.state = "running"
        end

        NM.Challenge.state = "running"

        local playerName = UnitName("player")
        if not NM.Challenge.results then
            NM.Challenge.results = {}
        end
        NM.Challenge.results[playerName] = {
            liv = 0,
            items = {},
            totalGold = 0,
            lootedGold = 0
        }

        if not NM.Challenge.duration or NM.Challenge.duration <= 0 then
            local minutes = tonumber(durationInput:GetText()) or 30
            NM.Challenge.duration = minutes * 60 -- Konvertiere zu Sekunden
        end

        NM.Challenge:Start(NM.Challenge.participants, {
            duration = NM.Challenge.duration,
            startTime = GetTime()
        })

        container:UpdateUIState("running", true)
        container:UpdateParticipants(NM.Challenge.participants, NM.Challenge.results)
        ChallengeTab:StartTimer(NM.Challenge.duration)

        if NM.Challenge then
            NM.Challenge:BroadcastMessage("CHALLENGE_TIMER_START", {
                duration = NM.Challenge.duration,
                startTime = GetTime()
            })
        end

        NM.Challenge:StartLiveUpdates()

    end)
    timerContainer:AddChild(startButton)

    -- Update Functions
    function container:UpdateParticipants(participants, results)
        participantsScroll:ReleaseChildren()

        results = results or {}

        local sortedParticipants = {}
        for name, data in pairs(participants) do
            if not results[name] then
                results[name] = {
                    liv = 0,
                    items = {},
                    totalGold = 0,
                    lootedGold = 0
                }
            end

            table.insert(sortedParticipants, {
                name = name,
                data = data,
                liv = results[name].liv or 0
            })
        end
        table.sort(sortedParticipants, function(a, b)
            return a.liv > b.liv
        end)

        for rank, participant in ipairs(sortedParticipants) do
            local playerRow = AceGUI:Create("SimpleGroup")
            playerRow:SetLayout("Flow")
            playerRow:SetFullWidth(true)

            local rankLabel = AceGUI:Create("Label")
            rankLabel:SetText(rank .. ".")
            rankLabel:SetWidth(30)
            playerRow:AddChild(rankLabel)

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

            local nameLabel = AceGUI:Create("Label")
            local displayName = participant.name
            if participant.data.isHost then
                displayName = displayName .. " |cffFFD700(Host)|r"
            end
            nameLabel:SetText(displayName)
            nameLabel:SetWidth(150)
            playerRow:AddChild(nameLabel)

            local livLabel = AceGUI:Create("Label")
            livLabel:SetText(NM.UIFunctions:FormatGold(participant.liv))
            livLabel:SetWidth(100)
            playerRow:AddChild(livLabel)

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

    local divider = AceGUI:Create("Heading")
    divider:SetFullWidth(true)
    scrollContainer:AddChild(divider)

    local keyBox = AceGUI:Create("EditBox")
    keyBox:SetLabel(L["Challenge Key"])
    keyBox:SetWidth(120)

    local keyButton = AceGUI:Create("Button")
    keyButton:SetText(L["Join"])
    keyButton:SetWidth(60)
    keyButton:SetCallback("OnClick", function()
        local key = keyBox:GetText()
        if key and key ~= "" then
            NM.Challenge:JoinChallenge(key)
        end
    end)

    -- Key Container
    local keyContainer = AceGUI:Create("SimpleGroup")
    keyContainer:SetLayout("Flow")
    keyContainer:SetFullWidth(true)
    keyContainer:SetHeight(40)
    keyContainer:AddChild(keyBox)
    keyContainer:AddChild(keyButton)
    scrollContainer:AddChild(keyContainer)

    -- Speichere Referenzen auf die Key-UI-Elemente
    self.keyBox = keyBox
    self.keyButton = keyButton

    -- Wenn bereits ein Key existiert, zeige ihn an
    if NM.Challenge and NM.Challenge.key then
        self:UpdateKeyDisplay(NM.Challenge.key)
    end

    -- UI State Updates
    function container:UpdateUIState(state, isHost)
        if state then
            NM:Print("State: " .. state)
        else
            NM:Print("Init State")
        end
        -- Zeige/Verstecke UI Elemente basierend auf dem Status
        if state == "initial" then
            -- Verstecke Teilnehmerliste
            if participantsContainer then
                participantsContainer.frame:Hide()
            end

            -- Reset UI Elements
            durationInput:SetDisabled(false)
            durationInput:SetText("30")

            -- Reset Icon Buttons
            startButton:SetDisabled(true)
            inviteButton:SetDisabled(false)
            resetButton:SetDisabled(false)

            -- Reset Key und Join Button
            if self.keyBox then
                self.keyBox:SetText("")
                self.keyBox:SetDisabled(false)
            end
            if self.keyButton then
                self.keyButton:SetDisabled(false)
            end

        elseif state == "inviting" then
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()

            -- UI Status
            durationInput:SetDisabled(true)

            -- Start Button für Host aktivieren
            if isHost then
                print("Enable Start Button for Host")  -- Debug
                startButton:SetDisabled(false)
            else
                startButton:SetDisabled(true)
            end

            -- Deaktiviere Key Input und Join Button während einer Challenge
            if self.keyBox then
                self.keyBox:SetDisabled(true)
            end
            if self.keyButton then
                self.keyButton:SetDisabled(true)
            end

        elseif state == "running" then
            if not participantsContainer.parent then
                scrollContainer:AddChild(participantsContainer)
            end
            participantsContainer.frame:Show()

            -- Alle Buttons deaktivieren im "running" Status
            durationInput:SetDisabled(true)
            inviteButton:SetDisabled(true)
            startButton:SetDisabled(true)

            -- Aktualisiere auch den Challenge-Status
            if NM.Challenge then
                NM.Challenge.state = "running"
            end

            -- Deaktiviere Key Input und Join Button während einer Challenge
            if self.keyBox then
                self.keyBox:SetDisabled(true)
            end
            if self.keyButton then
                self.keyButton:SetDisabled(true)
            end

        else
            -- Kein aktiver Challenge-Status
            if participantsContainer.parent then
                participantsContainer.parent:Release(participantsContainer)
            end
            participantsContainer.frame:Hide()
            durationInput:SetDisabled(false)
            inviteButton:SetDisabled(false)
            startButton:SetDisabled(true)
        end
    end

    container:UpdateUIState(nil, isHost)

    self.inviteButton = inviteButton
    self.resetButton = resetButton
    self.durationInput = durationInput

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
    if not self.participantsContainer then
        return
    end
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(participants, results)
    end
end

function ChallengeTab:UpdateUIState(state, isHost)
    if not self.participantContainer then
        self.participantContainer = AceGUI:Create("InlineGroup")
        self.participantContainer:SetTitle(L["Participants"])
        self.participantContainer:SetLayout("List")
        self.participantContainer:SetFullWidth(true)
        self:AddChild(self.participantContainer)
    end

    self.participantContainer.frame:Show()

    if state == "inviting" then
        self.participantContainer:SetTitle(L["Waiting for participants..."])
    elseif state == "running" then
        self.participantContainer:SetTitle(L["Challenge in progress"])
    end
end

function ChallengeTab:UpdateParticipants(participants)
    if not self.participantContainer then
        return
    end

    self.participantContainer:ReleaseChildren()

    for name, data in pairs(participants) do
        local participantRow = AceGUI:Create("SimpleGroup")
        participantRow:SetLayout("Flow")
        participantRow:SetFullWidth(true)

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

    self.participantContainer:DoLayout()

    self:UpdateNavigation()
end

function ChallengeTab:ShowItemDetails(playerName)
    if not playerName then
        return
    end

    local frame = CreateFrame("Frame", "NMItemDetailsFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(400, 550)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.portrait = frame.PortraitContainer.portrait

    SetPortraitTexture(frame.portrait, playerName)

    if not frame.portrait:GetTexture() then
        local name, realm = strsplit("-", playerName)
        if not realm then
            realm = GetRealmName()
        end
        frame.portrait:SetTexture("Interface\\CharacterFrame\\TEMPORARYPORTRAIT-FEMALE-BLOODELF")
    end

    frame.TitleContainer.TitleText:SetText(string.format(L["Items for %s"], playerName))

    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("List")
    container:SetFullWidth(true)
    container:SetFullHeight(true)
    container.frame:SetParent(frame)
    container.frame:SetPoint("TOPLEFT", 10, -25)
    container.frame:SetPoint("BOTTOMRIGHT", -10, 10)

    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)
    headerGroup:SetHeight(25)

    headerGroup.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 85, -25)
    headerGroup.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -25)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(50)
    headerGroup:AddChild(spacer)

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

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetHeight(350)
    container:AddChild(scroll)

    local statsContainer = AceGUI:Create("InlineGroup")
    statsContainer:SetLayout("Flow")
    statsContainer:SetFullWidth(true)
    statsContainer:SetHeight(80)
    statsContainer:SetTitle(L["Statistics"])
    container:AddChild(statsContainer)

    frame.container = container
    frame.scroll = scroll
    frame.statsContainer = statsContainer
    self.itemDetailsFrame = frame

    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
        self.itemDetailsFrame = nil
        self.currentDetailPlayer = nil
    end)

    frame:Show()

    self.currentDetailPlayer = playerName

    self:UpdateStats({
        totalLIV = 0,
        lootedGold = 0,
        totalGold = 0
    })

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
    if not self.itemDetailsFrame then
        return
    end

    local scroll = self.itemDetailsFrame.scroll
    scroll:ReleaseChildren()

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

    if not self.currentSort then
        self.currentSort = {
            column = "totalValue",
            ascending = false
        }
    end

    table.sort(items, function(a, b)
        local aValue = a[self.currentSort.column]
        local bValue = b[self.currentSort.column]

        if self.currentSort.ascending then
            return aValue < bValue
        else
            return aValue > bValue
        end
    end)

    for index, item in ipairs(items) do
        local itemRow = AceGUI:Create("SimpleGroup")
        itemRow:SetLayout("Flow")
        itemRow:SetFullWidth(true)
        itemRow:SetHeight(30)

        if index % 2 == 0 then
            local bg = itemRow.frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end

        itemRow.frame:SetScript("OnEnter", function()
            local highlight = itemRow.frame:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)  -- Hellerer Hintergrund beim Hover
        end)

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

        local itemLabel = AceGUI:Create("InteractiveLabel")
        local displayText = string.format("%s |cFF888888x%d|r", item.name, item.count)
        itemLabel:SetText(displayText)
        itemLabel:SetWidth(200)

        local r, g, b = GetItemQualityColor(item.rarity)
        itemLabel:SetColor(r, g, b)

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

        local valueLabel = AceGUI:Create("Label")
        valueLabel:SetText(string.format("%s\n|cFF888888%s|r",
                NM.UIFunctions:FormatGold(item.totalValue),
                NM.UIFunctions:FormatGold(item.value)))
        valueLabel:SetWidth(120)
        itemRow:AddChild(valueLabel)

        scroll:AddChild(itemRow)
    end

    self:UpdateStats(stats)
end

function ChallengeTab:UpdateStats(stats)
    if not self.itemDetailsFrame then
        return
    end

    local statsContainer = self.itemDetailsFrame.container.children[3]
    statsContainer:ReleaseChildren()

    local leftStats = AceGUI:Create("SimpleGroup")
    leftStats:SetLayout("Flow")
    leftStats:SetWidth(190)
    leftStats:SetHeight(80)

    local rightStats = AceGUI:Create("SimpleGroup")
    rightStats:SetLayout("Flow")
    rightStats:SetWidth(190)
    rightStats:SetHeight(80)

    local livGroup = AceGUI:Create("SimpleGroup")
    livGroup:SetLayout("Flow")
    livGroup:SetFullWidth(true)
    livGroup:SetHeight(25)

    local livLabel = AceGUI:Create("Label")
    livLabel:SetText(L["Items LIV"] .. ":")
    livLabel:SetWidth(100)
    livGroup:AddChild(livLabel)

    local livValue = AceGUI:Create("Label")
    livValue:SetText(NM.UIFunctions:FormatGold(stats.totalLIV))
    livValue:SetWidth(80)
    livGroup:AddChild(livValue)

    leftStats:AddChild(livGroup)

    local lootedGroup = AceGUI:Create("SimpleGroup")
    lootedGroup:SetLayout("Flow")
    lootedGroup:SetFullWidth(true)
    lootedGroup:SetHeight(25)

    local lootedLabel = AceGUI:Create("Label")
    lootedLabel:SetText(L["Looted Gold"] .. ":")
    lootedLabel:SetWidth(100)
    lootedGroup:AddChild(lootedLabel)

    local lootedValue = AceGUI:Create("Label")
    lootedValue:SetText(NM.UIFunctions:FormatGold(stats.lootedGold))
    lootedValue:SetWidth(80)
    lootedGroup:AddChild(lootedValue)

    rightStats:AddChild(lootedGroup)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetFullWidth(true)
    spacer:SetHeight(5)
    rightStats:AddChild(spacer)

    local totalGroup = AceGUI:Create("SimpleGroup")
    totalGroup:SetLayout("Flow")
    totalGroup:SetFullWidth(true)
    totalGroup:SetHeight(25)

    local totalLabel = AceGUI:Create("Label")
    totalLabel:SetText(L["Total Gold"] .. ":")
    totalLabel:SetWidth(100)
    totalGroup:AddChild(totalLabel)

    local totalValue = AceGUI:Create("Label")
    totalValue:SetText(NM.UIFunctions:FormatGold(stats.totalGold))
    totalValue:SetWidth(80)
    totalGroup:AddChild(totalValue)

    rightStats:AddChild(totalGroup)

    statsContainer:AddChild(leftStats)
    statsContainer:AddChild(rightStats)
end

function NM:GetUnitIDFromName(fullName)
    local name, realm = strsplit("-", fullName)
    if not realm then
        realm = GetRealmName()
    end

    realm = realm:gsub("%s+", "")

    for i = 1, GetNumSubgroupMembers() do
        local unitName, unitRealm = UnitName("party" .. i)
        if not unitRealm then
            unitRealm = GetRealmName()
        end
        unitRealm = unitRealm:gsub("%s+", "")

        if name == unitName and realm == unitRealm then
            return "party" .. i
        end
    end

    for i = 1, GetNumGroupMembers() do
        local unitName, unitRealm = UnitName("raid" .. i)
        if not unitRealm then
            unitRealm = GetRealmName()
        end
        unitRealm = unitRealm:gsub("%s+", "")

        if name == unitName and realm == unitRealm then
            return "raid" .. i
        end
    end

    local playerName, playerRealm = UnitName("player")
    if not playerRealm then
        playerRealm = GetRealmName()
    end
    playerRealm = playerRealm:gsub("%s+", "")

    if name == playerName and realm == playerRealm then
        return "player"
    end

    local loadAvatarButton = AceGUI:Create("Button")
    loadAvatarButton:SetText(L["Load Avatar"])
    loadAvatarButton:SetWidth(100)
    loadAvatarButton:SetCallback("OnClick", function()
        C_FriendList.SendWho(fullName)
        C_Timer.After(1, function()
            if self.itemDetailsFrame and self.itemDetailsFrame.portrait then
                SetPortraitTexture(self.itemDetailsFrame.portrait, fullName)
            end
        end)
    end)

    return nil, loadAvatarButton
end

NM.ChallengeTab = ChallengeTab

function ChallengeTab:UpdateNavigation()
    if self.itemDetailsFrame and self.itemDetailsFrame.UpdateNavigation then
        self.itemDetailsFrame.UpdateNavigation()
    end
end

function ChallengeTab:UpdateKeyDisplay(key)
    if key and self.keyBox then
        self.keyBox:SetText(key)
        if self.copyButton then
            self.copyButton:SetDisabled(false)
        end
    end
end

function ChallengeTab:StartTimer(duration)
    if not duration then
        return
    end
    if self.timerTicker then
        self.timerTicker:Cancel()
    end

    local endTime = GetTime() + duration

    -- Initialer Timer-Update
    local remaining = endTime - GetTime()
    local hours = math.floor(remaining / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = math.floor(remaining % 60)
    self.timerLabel:SetText(string.format("%02d:%02d:%02d", hours, minutes, seconds))

    self.timerTicker = C_Timer.NewTicker(1, function()
        remaining = endTime - GetTime()

        if remaining <= 0 then
            -- Timer ist abgelaufen
            self.timerTicker:Cancel()
            self.timerTicker = nil
            self.timerLabel:SetText("00:00:00")

            -- Sende Broadcast für Challenge Ende mit leeren Daten
            if NM.Challenge then
                NM.Challenge:BroadcastMessage("CHALLENGE_END", {})
            end
        else
            -- Aktualisiere Timer-Anzeige
            hours = math.floor(remaining / 3600)
            minutes = math.floor((remaining % 3600) / 60)
            seconds = math.floor(remaining % 60)

            self.timerLabel:SetText(string.format("%02d:%02d:%02d", hours, minutes, seconds))
        end
    end)
end

function ChallengeTab:StopTimer()
    if self.timerTicker then
        self.timerTicker:Cancel()
        self.timerTicker = nil
    end
    self.timerLabel:SetText("00:00:00")
end

function ChallengeTab:SyncTimer(remainingTime)
    if remainingTime and remainingTime > 0 then
        self:StartTimer(remainingTime)
    else
        self:StopTimer()
    end
end

function ChallengeTab:HandleChallengeStart(data)
    if not data or not data.duration then
        return
    end

    -- Berechne die verbleibende Zeit basierend auf der Startzeit
    local elapsed = GetTime() - data.startTime
    local remainingTime = data.duration - elapsed


    -- Starte den Timer nur, wenn noch Zeit übrig ist
    if remainingTime > 0 then
        self:StartTimer(remainingTime)
    else
        self:StopTimer()
    end
end

