local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
local AceSerializer = LibStub("AceSerializer-3.0")

local Challenge = {
    state = nil,
    participants = {},
    pendingInvites = {},
    leader = nil,
    duration = 0,
    startTime = nil,
    endTime = nil,
    results = {}
}


function Challenge:GenerateKey()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local length = 8
    local key = ""
    
    for i = 1, length do
        local rand = random(1, strlen(chars))
        key = key .. strsub(chars, rand, rand)
    end
    
    return key
end

-- Optional: Füge eine Debug-Funktion hinzu
function Challenge:PrintDebugInfo()
    print("Challenge Debug Info:")
    print("Key:", self.key or "kein Key")
    print("State:", self.state or "kein State")
    print("Leader:", self.leader or "kein Leader")
end

function Challenge:SendInvites()
    if self.state then 
        return 
    end
    
    self.state = "inviting"
    self.leader = UnitName("player")
    self.participants = {}
    self.pendingInvites = {}
    
    -- Generiere den Challenge Key beim Senden der Einladungen
    self.key = self:GenerateKey()
    print("Challenge Key generiert:", self.key) -- Debug print
    
    -- Aktualisiere das UI mit dem neuen Key
    if NM.ChallengeTab then
        NM.ChallengeTab:UpdateKeyDisplay(self.key)
    end
    
    -- Host als ersten Teilnehmer hinzufügen
    self.participants[self.leader] = {
        accepted = true,
        declined = false,
        online = true,
        isHost = true,
        liv = NM.session and NM.session.liv or 0
    }
    
    local invitedCount = 0
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and 
           accountInfo.gameAccountInfo.isOnline and 
           accountInfo.gameAccountInfo.clientProgram == "WoW" and
           accountInfo.gameAccountInfo.characterName ~= self.leader then
            
            local playerName = accountInfo.gameAccountInfo.characterName
            self.pendingInvites[playerName] = true
            self.participants[playerName] = {
                accepted = false,
                declined = false,
                online = true
            }
            
            self:BroadcastMessage("INVITE", {
                leader = self.leader,
                participants = self.participants
            }, i)
            
            invitedCount = invitedCount + 1
        end
    end
    
    if invitedCount > 0 then
        NM:Print(string.format(L["Challenge invitations sent to %d players"], invitedCount))
    else
        NM:Print(L["No online WoW friends found to invite"])
        self:Reset()
    end
    
    -- UI Update für den Host
    if NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
        NM.ui.challenge:UpdateUIState("inviting", true)
    end
    
    -- Debug print
    self:PrintDebugInfo()
end

function Challenge:Reset()
    self.state = nil
    self.participants = {}
    self.pendingInvites = {}
    self.leader = nil
    self.duration = 0
    self.startTime = nil
    self.endTime = nil
    self.results = {}
    
    if NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
        NM.ui.challenge:UpdateResults(self.results)
    end
end

function Challenge:Accept()
    -- Sende Accept-Nachricht an den Leader
    self:BroadcastMessage("ACCEPT", {
        player = UnitName("player")
    })
    
    -- Aktualisiere lokalen Status
    if not self.participants[UnitName("player")] then
        self.participants[UnitName("player")] = {
            accepted = false, 
            online = true,
            isHost = (UnitName("player") == self.leader)
        }
    end
    self.participants[UnitName("player")].accepted = true
    
    -- UI Update
    NM:OpenNexusManager()
    
    -- Wechsle zum Challenge-Tab (4 ist der Index für den Challenge-Tab)
    if NM.mainFrame then
        NM.mainFrame:SelectTab(4)
        
        -- Warte kurz, bis der Tab gewechselt wurde
        C_Timer.After(0.1, function()
            if NM.ui.challenge then
                -- Aktualisiere die Teilnehmerliste
                NM.ui.challenge:UpdateParticipants(self.participants)
                -- Aktualisiere den UI-Status für einen Teilnehmer
                NM.ui.challenge:UpdateUIState("inviting", UnitName("player") == self.leader)
            end
        end)
    end
    
    NM:Print(L["You accepted the challenge"])
end

function Challenge:Decline()
    -- Sende Decline-Nachricht an den Leader
    self:BroadcastMessage("DECLINE", {
        player = UnitName("player")
    })
    
    -- Markiere lokal als abgelehnt
    if self.participants[UnitName("player")] then
        self.participants[UnitName("player")].declined = true
        self.participants[UnitName("player")].accepted = false
    end
    
    -- UI Update
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
    end
    
    NM:Print(L["You declined the challenge"])
end

function Challenge:Start(participants, timerData)
    -- Prüfe ob es überhaupt akzeptierte Teilnehmer gibt
    local hasAcceptedParticipants = false
    for _, participant in pairs(self.participants) do
        if participant.accepted and not participant.declined then
            hasAcceptedParticipants = true
            break
        end
    end
    
    if not hasAcceptedParticipants then
        print(L["No participants have accepted the challenge"])
        return
    end
    
    -- Bereinige die Teilnehmerliste - behalte NUR akzeptierte und NICHT abgelehnte Teilnehmer
    local acceptedParticipants = {}
    for name, participant in pairs(self.participants) do
        if participant.accepted and not participant.declined then
            acceptedParticipants[name] = participant
        end
    end

    print("acceptedParticipants:")
    for name, participant in pairs(acceptedParticipants) do
        print("- " .. name)
    end
    
    -- Ersetze die alte Teilnehmerliste mit der bereinigten Liste
    self.participants = acceptedParticipants
    
    -- Lösche ausstehende Einladungen
    self.pendingInvites = {}
    
    -- Starte die Challenge
    self.state = "running"
    self.startTime = time()
    self.endTime = self.startTime + self.duration
    
    -- Aktualisiere das UI
    if NM.ChallengeTab then
        NM.ChallengeTab:UpdateParticipants(self.participants)
    end
    
    -- -- Starte nur Sessions für akzeptierte Teilnehmer
    -- if NM.session then
    --     local playerName = UnitName("player")
    --     if self.participants[playerName] then -- Jetzt sind nur noch wirklich aktive Teilnehmer in der Liste
    --         NM.session:reset()
    --     end
    -- end
    
    -- Broadcast den Start
    self:BroadcastMessage("CHALLENGE_START", {
        participants = participants,
        results = self.results,
        duration = timerData.duration,
        startTime = timerData.startTime
    })
    
    -- Debug print
    print("Aktive Teilnehmer nach Start:")
    for name, _ in pairs(self.participants) do
        print("- " .. name)
    end
end

function Challenge:Stop()
    if self.state ~= "running" then return end
    
    self.state = "finished"
    
    -- Stoppe lokale Session
    if NM.session then
        NM.session:Stop()
    end
    
    -- Zeige Endergebnisse
    self:ShowFinalResults()
    
    -- Informiere alle Teilnehmer
    self:BroadcastMessage("STOP", {
        endTime = time()
    })
end

function Challenge:AddResult(player, results)
    self.results[player] = {
        liv = results.liv or 0,
        items = results.items or {},
        totalGold = results.totalGold or 0,
        lootedGold = results.lootedGold or 0
    }
    
    if NM.ui.challenge then
        NM.ui.challenge:UpdateResults(self.results)
    end
    
end

function Challenge:BroadcastMessage(type, data, specificID)
    -- Füge den Key zu den Daten hinzu
    if type ~= "INVITE" then -- Bei Einladungen noch keinen Key mitschicken
        data.key = self.key
    end
    
    local message = {
        type = type,
        data = data,
        sender = UnitName("player"),
        addon = "NexusManager",
        challenge = true
    }
    
    local serialized = AceSerializer:Serialize(message)
    
    -- Wenn ein spezifischer Spieler angegeben ist
    if specificID then
        local accountInfo = C_BattleNet.GetFriendAccountInfo(specificID)
        if accountInfo and accountInfo.gameAccountInfo then
            local presenceID = accountInfo.gameAccountInfo.gameAccountID
            if presenceID then
                BNSendGameData(presenceID, "NM_CHALLENGE", serialized)
            end
        end
        return
    end
    
    -- Sende an alle Teilnehmer
    local sentCount = 0
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and 
           accountInfo.gameAccountInfo.isOnline and 
           accountInfo.gameAccountInfo.clientProgram == "WoW" then
            
            local playerName = accountInfo.gameAccountInfo.characterName
            -- Sende nur an Teilnehmer der Challenge
            if self.participants[playerName] then
                local presenceID = accountInfo.gameAccountInfo.gameAccountID
                if presenceID then
                    BNSendGameData(presenceID, "NM_CHALLENGE", serialized)
                    sentCount = sentCount + 1
                end
            end
        end
    end
    
end

function Challenge:HandleMessage(sender, message)
    local success, data = AceSerializer:Deserialize(message)
    if not success then return end
    
    if data.type == "CHALLENGE_START" then
        -- Behalte die existierende Teilnehmerliste
        local currentParticipants = self.participants
        
        -- Setze Challenge-Status
        self.state = "running"
        self.startTime = data.data.startTime
        self.duration = data.data.duration
        self.endTime = data.data.endTime
        
        -- Verwende die übergebenen Teilnehmer, falls vorhanden, sonst behalte die aktuellen
        if data.data.participants then
            self.participants = data.data.participants
        end
        
        -- Starte lokale Session
        if NM.session then
            NM.session:reset()
            NM.session.state = "running"
        end
        
        -- Starte Live-Updates
        self:StartLiveUpdates()
        
        -- UI Update
        if NM.ui and NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants)
            NM.ui.challenge:UpdateUIState("running", UnitName("player") == self.leader)
            NM.ChallengeTab:StartTimer(self.duration)
        end
        
        NM:Print(L["Challenge started!"])
    elseif data.type == "CHALLENGE_END" then
        -- Stoppe die Session zum exakt gleichen Zeitpunkt
        if NM.session then
            NM.session:pause()
        end
        
        -- Stoppe den Timer
        if NM.ChallengeTab then
            NM.ChallengeTab:StopTimer()
        end
        
        -- Sende ein finales LIVE_UPDATE
        if NM.session then
            local finalData = {
                player = UnitName("player"),
                liv = NM.session.liv or 0,
                items = NM.session.itemsLooted,
                totalGold = NM.session.totalGold,
                lootedGold = NM.session.lootedGold
            }
            self:BroadcastMessage("LIVE_UPDATE", finalData)
        end
        
        -- Stoppe Live-Updates
        if self.updateTimer then
            self.updateTimer:Cancel()
            self.updateTimer = nil
        end
        
        self.state = "finished"

        -- Zeige schwebenden Text an
        self:ShowFloatingText(L["Challenge Complete!"])

    elseif data.type == "CANCEL_CHALLENGE" then
            if data.message then
                NM:Print(data.message)
            end
            self:Reset()
    elseif data.type == "LIVE_UPDATE" then
        -- Verarbeite LIVE_UPDATE nur wenn Challenge aktiv ist oder gerade beendet wurde
        if self.state == "running" then
            local player = data.data.player
            local liv = data.data.liv or 0
            
            -- Aktualisiere direkt die Teilnehmerdaten und Ergebnisse
            if self.participants[player] then
                self.participants[player].liv = liv
                self.results[player] = {
                    liv = liv,
                    items = data.data.items or {},
                    totalGold = data.data.totalGold or 0,
                    lootedGold = data.data.lootedGold or 0,
                    originalLiv = liv
                }
                
                -- UI nur einmal aktualisieren
                if NM.ui and NM.ui.challenge then
                    NM.ui.challenge:UpdateParticipants(self.participants, self.results)
                end
            end
        end
    elseif data.type == "INVITE" then
        self.state = "pending"
        self.leader = data.data.leader
        self.participants = data.data.participants
        NM:ShowChallengeInvite(sender, data.data)
        
    elseif data.type == "ACCEPT" then
        -- Aktualisiere die Teilnehmerliste
        if self.participants[data.data.player] then
            self.participants[data.data.player].accepted = true
            self.participants[data.data.player].liv = 0
            
            -- Broadcast den neuen Status an alle
            self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                participants = self.participants,
                state = self.state
            })
            
            -- UI Update
            if NM.ui and NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants, self.results)
                NM.ui.challenge:UpdateUIState("inviting", UnitName("player") == self.leader)
            end
        end
        
    elseif data.type == "DECLINE" then
        if self.participants[data.data.player] then
            -- Markiere den Spieler als abgelehnt, anstatt ihn zu entfernen
            self.participants[data.data.player] = {
                accepted = false,
                declined = true,
                online = true
            }
            
            -- Broadcast den neuen Status an alle
            self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                participants = self.participants
            })
            
            -- UI Update
            if NM.ui and NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants, self.results)
            end
            
            if self.leader == UnitName("player") then
                NM:Print(string.format(L["%s declined the challenge"], data.data.player))
            end
        end
        return
    elseif data.type == "PAUSE" then
        
    elseif data.type == "UPDATE_PARTICIPANTS" then
        -- Alle Teilnehmer aktualisieren ihre Liste
        self.participants = data.data.participants
        self.state = data.data.state or self.state
        
        -- UI Update für alle Teilnehmer
        if NM.ui and NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants, self.results)
            NM.ui.challenge:UpdateUIState(self.state, UnitName("player") == self.leader)
        end
        
    elseif data.type == "LIVE_UPDATE" then
        if self.state == "running" then
            self:UpdateLiveResult(data.data.player, data.data)
        end
    elseif data.type == "CHALLENGE_DATA" then
        -- Nur verarbeiten, wenn wir noch keine laufende Session haben
        if self.state ~= "running" then
            -- Übernehme die Challenge-Daten
            self.key = data.data.key
            self.state = data.data.state
            self.participants = data.data.participants
            self.duration = data.data.duration
            self.startTime = data.data.startTime
            self.endTime = data.data.endTime
            self.results = data.data.results
            
            -- Starte die Session, wenn die Challenge läuft
            if self.state == "running" and NM.session then
                NM.session:reset()
                NM.session.state = "running"
                -- Starte Live-Updates
                self:StartLiveUpdates()
            end
            
            -- UI aktualisieren
            if NM.ui and NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants, self.results)
                NM.ui.challenge:UpdateUIState(self.state, UnitName("player") == self.leader)
            end
            
            NM:Print(L["Joined ongoing challenge"])
        else
            NM:Print(L["Already in a running challenge"])
        end
    end
    
    if data.type == "JOIN_REQUEST" then
        -- Wenn wir der Host sind und der Key stimmt
        -- NM:Print("JOIN_REQUEST started with key " .. data.data.key)
        -- NM:Print("Compare key " .. data.data.key .. " with " .. self.key)
        if self.participants[UnitName("player")].isHost and data.data.ckey == self.key then
            -- Füge den Spieler hinzu
            self.participants[data.data.player] = {
                accepted = true,
                declined = false,
                online = true,
                isHost = false,
                liv = 0
            }
            
            -- Sende aktuelle Challenge-Daten an den neuen Teilnehmer
            self:SendChallengeDataTo(data.data.player)
        end
    end
end

function Challenge:ShowFinalResults()
    local totalLiv = 0
    local winner = nil
    local maxLiv = 0
    
    -- Berechne Gesamtwerte und finde den Gewinner
    for player, result in pairs(self.results) do
        totalLiv = totalLiv + (result.originalLiv or 0)
        if result.originalLiv > maxLiv then
            maxLiv = result.originalLiv
            winner = player
        end
    end
    
    -- Zeige Zusammenfassung
    NM:Print("Challenge beendet!")
    NM:Print(string.format(L["Total LIV: %s"], NM.session:FormatGold(totalLiv)))
    if winner then
        NM:Print(string.format(L["Winner: %s with %s LIV"], winner, NM.session:FormatGold(maxLiv)))
    end
end

NM.Challenge = Challenge 

function NM:ShowChallengeInvite(sender, data)
    -- Erstelle den Dialog VOR dem Anzeigen
    StaticPopupDialogs["NEXUSMANAGER_CHALLENGE_INVITE"] = {
        text = string.format(L["Challenge invitation from %s"], data.leader),
        button1 = L["Accept"],
        button2 = L["Decline"],
        timeout = 60,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        
        OnAccept = function()
            if self.Challenge then
                self.Challenge:Accept()
            end
        end,
        
        OnCancel = function()
            if self.Challenge then
                self.Challenge:Decline()
            end
        end,
        
        OnShow = function(self)
            self.text:SetText(string.format(L["Challenge invitation from %s"], data.leader))
        end,
    }
    
    -- Dann zeige den Dialog an
    StaticPopup_Show("NEXUSMANAGER_CHALLENGE_INVITE")
end

-- Neue Funktion für regelmäßige Updates
function Challenge:StartLiveUpdates()
    if self.updateTimer then return end
    
    self.updateTimer = C_Timer.NewTicker(5, function()  -- Alle 5 Sekunden
        if self.state == "running" then
            -- Sammle aktuelle Session-Daten
            local currentData = {
                player = UnitName("player"),
                liv = NM.session.liv or 0,
                items = NM.session.itemsLooted,
                totalGold = NM.session.totalGold,
                lootedGold = NM.session.lootedGold
            }
            
            -- Aktualisiere eigene Teilnehmerdaten
            if self.participants[UnitName("player")] then
                self.participants[UnitName("player")].liv = currentData.liv
            end
            
            -- Sende Live-Update
            self:BroadcastMessage("LIVE_UPDATE", currentData)
        else
            -- Stoppe Timer wenn Challenge nicht mehr läuft
            self.updateTimer:Cancel()
            self.updateTimer = nil
        end
    end)
end

function Challenge:UpdateLiveResult(player, data)
    if not self.results[player] then
        self.results[player] = {}
    end
    
    self.results[player] = {
        liv = data.liv or 0,
        items = data.items or {},
        totalGold = data.totalGold or 0,
        lootedGold = data.lootedGold or 0,
        originalLiv = data.liv or 0  -- Speichere den Original-Wert
    }
    
    -- UI nur einmal aktualisieren
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants, self.results)
    end
end

function Challenge:SendLiveUpdate(player, livData)
    -- Finde den Spieler in der BattleNet-Freundesliste
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo then
            local playerName = accountInfo.gameAccountInfo.characterName
            if self.participants[playerName] then
                local presenceID = accountInfo.gameAccountInfo.gameAccountID
                if presenceID then
                    local message = {
                        type = "LIVE_UPDATE",
                        data = livData,
                        sender = player,
                        addon = "NexusManager",
                        challenge = true
                    }
                    
                    local serialized = AceSerializer:Serialize(message)
                    BNSendGameData(presenceID, "NM_CHALLENGE", serialized)
                end
            end
        end
    end
end

function Challenge:JoinWithKey(inputKey)
    NM:Print("JoinWithKey started with key " .. inputKey)
    
    -- Hole eigene Account Info
    local accountInfo = C_BattleNet.GetAccountInfoByGUID(UnitGUID("player"))
    local gameAccountID = accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.gameAccountID
    
    -- Sende Join-Request mit Account Info
    local message = {
        ckey = inputKey,
        player = UnitName("player"),
        accountID = gameAccountID  -- Füge Game Account ID hinzu
    }
    
    self:BroadcastMessage("JOIN_REQUEST", message)
end

-- Neue Hilfsfunktion
function Challenge:SendChallengeDataTo(player)
    local challengeData = {
        key = self.key,
        state = self.state,
        participants = self.participants,
        duration = self.duration,
        startTime = self.startTime,
        endTime = self.endTime,
        results = self.results
    }
    NM:Print("Sende Challenge-Daten an " .. player)
    self:BroadcastMessage("CHALLENGE_DATA", challengeData)
    
    -- Informiere alle Teilnehmer über den neuen Spieler
    self:BroadcastMessage("UPDATE_PARTICIPANTS", {
        participants = self.participants,
        state = self.state
    })
end

-- Neue Hilfsfunktion um akzeptierte Teilnehmer zu erhalten
function Challenge:GetAcceptedParticipants()
    local accepted = {}
    for name, participant in pairs(self.participants) do
        if participant.accepted then
            accepted[name] = true
        end
    end
    return accepted
end 

function Challenge:ShowFloatingText(text)
    -- Erstelle einen neuen Frame falls er noch nicht existiert
    if not self.floatingFrame then
        self.floatingFrame = CreateFrame("Frame", "NexusManagerFloatingText", UIParent)
        self.floatingFrame:SetSize(400, 50)
        self.floatingFrame:SetPoint("TOP", UIParent, "CENTER", 0, 100)
        
        -- Erstelle das Text Label
        self.floatingFrame.text = self.floatingFrame:CreateFontString(nil, "OVERLAY")
        self.floatingFrame.text:SetPoint("CENTER")
        self.floatingFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    end
    
    -- Setze den Text
    self.floatingFrame.text:SetText(text)
    self.floatingFrame:Show()
    
    -- Animation
    self.floatingFrame:SetAlpha(0)
    self.floatingFrame:Show()
    
    -- Fade In
    UIFrameFadeIn(self.floatingFrame, 0.5, 0, 1)
    
    -- Nach 2 Sekunden Fade Out
    C_Timer.After(2, function()
        UIFrameFadeOut(self.floatingFrame, 0.5, 1, 0)
        -- Verstecke den Frame nach dem Fade Out
        C_Timer.After(0.5, function()
            self.floatingFrame:Hide()
        end)
    end)
    
    -- Spiele einen Sound ab (optional)
    PlaySound(SOUNDKIT.RAID_WARNING)
end