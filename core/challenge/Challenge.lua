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

function Challenge:New()
    local challenge = {}
    setmetatable(challenge, self)
    self.__index = self
    return challenge
end

function Challenge:SendInvites()
    if self.state then 
        -- Nur kritische Fehler loggen
        NM:Debug("Challenge: Cannot send invites - already in progress")
        return 
    end
    
    self.state = "inviting"
    self.leader = UnitName("player")
    self.participants = {}
    self.pendingInvites = {}
    
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
    end
end

function Challenge:Reset()
    NM:Debug("Challenge: Resetting challenge state")
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
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
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

function Challenge:Start(duration)
    NM:Debug("Challenge: Attempting to start challenge")
    
    -- Überprüfe, ob wir der Leader sind
    if self.leader ~= UnitName("player") then
        NM:Debug("Challenge: Cannot start - not the leader")
        return
    end
    
    -- Überprüfe, ob die Challenge bereits läuft
    if self.state == "running" then
        NM:Debug("Challenge: Cannot start - already running")
        return
    end
    
    if not duration or duration <= 0 then
        duration = 3600  -- Standard: 1 Stunde
    end
    
    NM:Debug("Challenge: Starting challenge with duration: %d", duration)
    
    -- Setze Challenge-Status
    self.state = "running"
    self.startTime = time()
    self.duration = duration
    self.endTime = self.startTime + duration
    
    -- Starte lokale Session
    if NM.session then
        NM.session:reset()  -- Reset session first
        NM.session.state = "running"  -- Explizit den Status setzen
        NM:Debug("Challenge: Local session started")
    else
        NM:Debug("Challenge: Warning - session module not available")
    end
    
    -- Starte Live-Updates
    self:StartLiveUpdates()
    
    -- Informiere alle Teilnehmer
    self:BroadcastMessage("START", {
        startTime = self.startTime,
        duration = self.duration,
        endTime = self.endTime
    })
    
    NM:Print(L["Challenge started!"])
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
    
    -- Debug Ausgabe
    NM:Debug("Challenge: Added results for %s - LIV: %d", 
        player, self.results[player].liv)
end

function Challenge:BroadcastMessage(type, data, specificID)
    NM:Debug("Challenge: [BROADCAST] Type: %s, Target: %s", 
        type, 
        specificID and "Specific Player" or "All Participants"
    )
    
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
                NM:Debug("Challenge: [SENT] Message to %s (ID: %s)", 
                    accountInfo.gameAccountInfo.characterName,
                    tostring(presenceID)
                )
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
    if not success then 
        NM:Debug("Challenge: Failed to deserialize message")
        return 
    end
    
    if data.type == "LIVE_UPDATE" then
        -- Log nur die deserialisierten Daten
        if self.state == "running" then
            local player = data.data.player
            local liv = data.data.liv or 0
            
            -- Debug nur für wichtige Änderungen
            NM:Debug("Challenge: Received LIVE_UPDATE from %s with LIV: %s", player, tostring(liv))
            
            -- Aktualisiere direkt die Teilnehmerdaten und Ergebnisse
            if self.participants[player] then
                self.participants[player].liv = liv
                self.results[player] = {
                    liv = liv,
                    items = data.data.items or {},
                    totalGold = data.data.totalGold or 0,
                    lootedGold = data.data.lootedGold or 0,
                    originalLiv = liv  -- Speichere den Original-Wert
                }
                
                -- UI nur einmal aktualisieren
                if NM.ui and NM.ui.challenge then
                    NM.ui.challenge:UpdateParticipants(self.participants, self.results)
                end
            end
        end
    end
    
    
    if data.type == "START" then
        StaticPopup_Hide("NEXUSMANAGER_CHALLENGE_INVITE")
        
        -- Entferne alle pending Teilnehmer
        for name, participant in pairs(self.participants) do
            if not participant.accepted then
                self.participants[name] = nil
            end
        end
        
        -- Setze Challenge-Status
        self.state = "running"
        self.startTime = data.data.startTime
        self.duration = data.data.duration
        self.endTime = data.data.endTime
        
        -- Starte lokale Session
        if NM.session then
            NM.session:reset()  -- Reset session first
            NM.session.state = "running"  -- Explizit den Status setzen
        else
        end
        
        -- Starte Live-Updates
        self:StartLiveUpdates()
        
        NM:Print(L["Challenge started!"])
    end
    
    if data.type == "INVITE" then
        self.state = "pending"
        self.leader = data.data.leader
        self.participants = data.data.participants
        NM:ShowChallengeInvite(sender, data.data)
        
    elseif data.type == "ACCEPT" then
        -- Aktualisiere die Teilnehmerliste
        if self.participants[data.data.player] then
            self.participants[data.data.player].accepted = true
            self.participants[data.data.player].liv = 0  -- Initialisiere LIV
            
            -- Broadcast den neuen Status an alle
            self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                participants = self.participants
            })
            
            -- UI Update
            if NM.ui and NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants, self.results)
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
        
    elseif data.type == "UPDATE_PARTICIPANTS" then
        -- Alle Teilnehmer aktualisieren ihre Liste
        self.participants = data.data.participants
        if NM.ui and NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants, self.results)
        end
        
    elseif data.type == "LIVE_UPDATE" then
        if self.state == "running" then
            self:UpdateLiveResult(data.data.player, data.data)
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
            
            -- Aktualisiere eigene Teilnehmerdaten, aber sende sie nicht
            if self.participants[UnitName("player")] then
                self.participants[UnitName("player")].liv = currentData.liv
            end
            
            -- Sende Live-Update an alle Teilnehmer, außer an sich selbst
            for playerName, _ in pairs(self.participants) do
                if playerName ~= UnitName("player") then
                    self:SendLiveUpdate(playerName, currentData)
                end
            end
            
            -- Aktualisiere eigene Ergebnisse
            self:UpdateLiveResult(UnitName("player"), currentData)
            
        else
            -- Stoppe Timer wenn Challenge nicht mehr läuft
            if self.updateTimer then
                self.updateTimer:Cancel()
                self.updateTimer = nil
            end
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