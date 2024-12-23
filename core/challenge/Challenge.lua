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
        NM:Debug("Challenge: Cannot send invites - challenge already in progress (state: %s)", self.state)
        return 
    end
    
    self.state = "inviting"
    self.leader = UnitName("player")
    self.participants = {}
    self.pendingInvites = {}
    
    NM:Debug("Challenge: Sending invites as leader: %s", self.leader)
    
    local invitedCount = 0
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and 
           accountInfo.gameAccountInfo.isOnline and 
           accountInfo.gameAccountInfo.clientProgram == "WoW" then
            
            local playerName = accountInfo.gameAccountInfo.characterName
            self.pendingInvites[playerName] = true
            self.participants[playerName] = {accepted = false, online = true}
            
            self:BroadcastMessage("INVITE", {
                leader = self.leader,
                participants = self.participants
            }, i)
            
            invitedCount = invitedCount + 1
            NM:Debug("Challenge: Invited %s (Friend Index: %d)", playerName, i)
        end
    end
    
    if invitedCount > 0 then
        NM:Print(string.format(L["Challenge invitations sent to %d players"], invitedCount))
    else
        NM:Print(L["No online WoW friends found to invite"])
        self:Reset()
    end
    
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
    NM:Debug("Challenge: Accepting challenge (State: %s)", self.state or "none")
    
    -- Sende Accept-Nachricht an den Leader
    self:BroadcastMessage("ACCEPT", {
        player = UnitName("player")
    })
    
    -- Aktualisiere lokalen Status
    if not self.participants[UnitName("player")] then
        self.participants[UnitName("player")] = {accepted = false, online = true}
    end
    self.participants[UnitName("player")].accepted = true
    
    -- UI Update
    if NM.ui and NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
    end
    
    NM:Print(L["You accepted the challenge"])
end

function Challenge:Decline()
    NM:Debug("Challenge: Declining challenge (State: %s)", self.state or "none")
    
    -- Sende Decline-Nachricht an den Leader
    self:BroadcastMessage("DECLINE", {
        player = UnitName("player")
    })
    
    -- Reset local state
    self:Reset()
    
    NM:Print(L["You declined the challenge"])
end

function Challenge:Start(duration)
    if not duration or duration <= 0 then
        duration = 3600  -- Standard: 1 Stunde
        NM:Debug("Challenge: No duration specified, using default: %d seconds", duration)
    end
    
    if self.state ~= "inviting" or UnitName("player") ~= self.leader then 
        NM:Debug("Challenge: Cannot start - invalid state or not leader (state: %s, leader: %s)", 
                 self.state, self.leader)
        return 
    end
    
    local acceptedCount = 0
    for name, data in pairs(self.participants) do
        if data.accepted then
            acceptedCount = acceptedCount + 1
            NM:Debug("Challenge: Participant ready: %s", name)
        end
    end
    
    if acceptedCount == 0 then
        NM:Print(L["No participants have accepted the challenge"])
        return
    end
    
    NM:Debug("Challenge: Starting with %d participants", acceptedCount)
    
    self.state = "running"
    self.startTime = time()
    self.duration = duration
    self.endTime = self.startTime + duration
    self.results = {}
    
    -- Initialisiere LIV-Werte für alle Teilnehmer
    for name, data in pairs(self.participants) do
        if data.accepted then
            data.liv = 0
        end
    end
    
    -- Starte Live-Updates
    self:StartLiveUpdates()
    
    -- Broadcast start message to all participants
    self:BroadcastMessage("START", {
        duration = duration,
        startTime = self.startTime,
        leader = self.leader,
        participants = self.participants
    })
    
    NM.session:start()
    
    -- Set timer for challenge end
    C_Timer.After(duration, function()
        if self.state == "running" then
            self:Stop()
        end
    end)
end

function Challenge:Stop()
    if self.state ~= "running" then return end
    
    self.state = "finished"
    
    -- Stoppe Live-Updates
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
    
    -- Sammle die Ergebnisse vom Session
    local results = {
        player = UnitName("player"),
        liv = NM.session.liv,
        items = NM.session.itemsLooted,
        totalGold = NM.session.totalGold,
        lootedGold = NM.session.lootedGold
    }
    
    -- Sende die Ergebnisse an alle
    self:BroadcastMessage("RESULT", results)
    
    -- Füge eigene Ergebnisse hinzu
    self:AddResult(UnitName("player"), results)
    
    NM:Debug("Challenge: Stopped and sent results - LIV: %d, Items: %d", 
        results.liv or 0, #(results.items or {}))
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
                    NM:Debug("Challenge: [SENT] Message to participant %s (ID: %s)", 
                        playerName,
                        tostring(presenceID)
                    )
                end
            end
        end
    end
    
    NM:Debug("Challenge: [BROADCAST] Completed - Sent to %d participants", sentCount)
end

function Challenge:HandleMessage(sender, message)
    local success, data = AceSerializer:Deserialize(message)
    if not success then 
        NM:Debug("Challenge: Failed to deserialize message from %s", sender)
        return 
    end
    
    NM:Debug("Challenge: [EVENT] Received %s from %s (My Role: %s, State: %s)", 
        data.type, 
        sender, 
        self.leader == UnitName("player") and "Leader" or "Participant",
        self.state or "none"
    )
    
    if data.type == "INVITE" then
        NM:Debug("Challenge: Received invite from %s", sender)
        self.state = "pending"
        self.leader = data.data.leader
        self.participants = data.data.participants
        NM:ShowChallengeInvite(sender, data.data)
        
    elseif data.type == "ACCEPT" then
        if self.leader == UnitName("player") then
            -- Leader aktualisiert die Teilnehmerliste
            if self.participants[data.data.player] then
                self.participants[data.data.player].accepted = true
                -- Broadcast den neuen Status an alle
                self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                    participants = self.participants
                })
            end
        end
        
    elseif data.type == "DECLINE" then
        if self.leader == UnitName("player") then
            -- Leader entfernt den Spieler
            self.participants[data.data.player] = nil
            -- Broadcast den neuen Status an alle
            self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                participants = self.participants
            })
        end
        
    elseif data.type == "UPDATE_PARTICIPANTS" then
        -- Alle Teilnehmer aktualisieren ihre Liste
        self.participants = data.data.participants
        if NM.ui and NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants)
        end
        
    elseif data.type == "START" then
        self.state = "running"
        self.startTime = time()
        self:StartLiveUpdates()
        NM:Print(L["Challenge started!"])
        
    elseif data.type == "LIVE_UPDATE" then
        if self.state == "running" then
            NM:Debug("Challenge: [LIVE_UPDATE] From: %s, LIV: %s", 
                data.data.player, 
                tostring(data.data.liv)
            )
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
    
    NM:Debug("Challenge: Showing invite popup from %s", data.leader)
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
                liv = NM.session.liv,
                items = NM.session.itemsLooted,
                totalGold = NM.session.totalGold,
                lootedGold = NM.session.lootedGold
            }
            
            -- Sende Live-Update an alle Teilnehmer
            self:BroadcastMessage("LIVE_UPDATE", currentData)
            
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
    
    -- Speichere Original und formatierte Werte
    local formattedLiv = NM.session:FormatGold(data.liv or 0)
    
    self.results[player] = {
        liv = formattedLiv,
        originalLiv = data.liv or 0,
        items = data.items or {},
        totalGold = data.totalGold or 0,
        lootedGold = data.lootedGold or 0
    }
    
    -- Aktualisiere auch die Teilnehmerliste
    if self.participants[player] then
        self.participants[player].liv = data.liv
    end
    
    -- UI Update
    if NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
        NM.ui.challenge:UpdateResults(self.results)
    end
    
    NM:Debug("Challenge: Updated result for %s - LIV: %s (Original: %d)", 
        player, formattedLiv, data.liv or 0)
end 

function Challenge:SendLiveUpdate(player, livData)
    NM:Debug("Challenge: Sending live update for player: %s, LIV: %s", 
        player, tostring(livData.liv))
    
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
                    NM:Debug("Challenge: Sent live update to: %s", playerName)
                end
            end
        end
    end
end 