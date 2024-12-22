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
    if not self.pendingInvites[UnitName("player")] then 
        NM:Debug("Challenge: Cannot accept - no pending invite found")
        return 
    end
    
    NM:Debug("Challenge: Accepting challenge from %s", self.leader)
    self.state = "pending"
    self.participants[UnitName("player")] = {accepted = true, online = true}
    
    -- Finde den Leader in der BattleNet-Freundesliste
    for i = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo then
            local playerName = accountInfo.gameAccountInfo.characterName
            if playerName == self.leader then
                -- Sende Accept-Nachricht direkt an den Leader
                local presenceID = accountInfo.gameAccountInfo.gameAccountID
                if presenceID then
                    NM:Debug("Challenge: Found leader %s with presenceID %s", playerName, presenceID)
                    BNSendGameData(presenceID, "NM_CHALLENGE", AceSerializer:Serialize({
                        type = "ACCEPT",
                        data = {
                            player = UnitName("player")
                        },
                        sender = UnitName("player"),
                        addon = "NexusManager",
                        challenge = true
                    }))
                    NM:Debug("Challenge: Sent accept message to leader")
                    break
                end
            end
        end
    end
    
    -- Aktualisiere die UI für den Empfänger
    if NM.ui.challenge then
        NM.ui.challenge:UpdateParticipants(self.participants)
        NM.ui.challenge:SetStartButtonEnabled(false)
    end
    
    NM:Print(L["Challenge accepted"])
end

function Challenge:Decline()
    if not self.pendingInvites[UnitName("player")] then 
        NM:Debug("Challenge: Cannot decline - no pending invite found")
        return 
    end
    
    NM:Debug("Challenge: Declining challenge from %s", self.leader)
    
    self:BroadcastMessage("DECLINE", {
        player = UnitName("player")
    })
    
    self:Reset()
    NM:Print(L["Challenge declined"])
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
    NM:Debug("Challenge: Broadcasting message type: %s", type)
    local message = {
        type = type,
        data = data,
        sender = UnitName("player"),
        addon = "NexusManager",
        challenge = true
    }
    
    local serialized = AceSerializer:Serialize(message)
    
    if specificID then
        local accountInfo = C_BattleNet.GetFriendAccountInfo(specificID)
        if accountInfo and accountInfo.gameAccountInfo then
            local presenceID = accountInfo.gameAccountInfo.gameAccountID
            if presenceID then
                BNSendGameData(presenceID, "NM_CHALLENGE", serialized)
                NM:Debug("Challenge: Sent message to %s", accountInfo.gameAccountInfo.characterName)
            end
        end
    else
        for i = 1, BNGetNumFriends() do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and 
               accountInfo.gameAccountInfo.isOnline and 
               accountInfo.gameAccountInfo.clientProgram == "WoW" then
                
                local presenceID = accountInfo.gameAccountInfo.gameAccountID
                if presenceID then
                    BNSendGameData(presenceID, "NM_CHALLENGE", serialized)
                    NM:Debug("Challenge: Sent message to %s", accountInfo.gameAccountInfo.characterName)
                end
            end
        end
    end
end

function Challenge:HandleMessage(sender, message)
    NM:Debug("Challenge: Received message from %s", sender)
    
    local success, data = AceSerializer:Deserialize(message)
    if not success then 
        NM:Debug("Challenge: Failed to deserialize message")
        return 
    end
    
    NM:Debug("Challenge: Message type: %s", data.type)
    
    if data.type == "INVITE" then
        NM:Debug("Challenge: Received invite from %s", data.data.leader)
        
        -- Speichere die Challenge-Informationen
        self.state = "pending"
        self.leader = data.data.leader
        self.pendingInvites[UnitName("player")] = true
        
        -- Dialog-Optionen erstellen
        local dialog = {
            text = string.format(L["Challenge invitation from %s"], data.data.leader),
            button1 = L["Accept"],
            button2 = L["Decline"],
            timeout = 60,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            
            OnAccept = function()
                self:Accept()
            end,
            
            OnCancel = function()
                self:Decline()
            end,
            
            OnShow = function(self)
                self.text:SetText(string.format(L["Challenge invitation from %s"], data.data.leader))
            end,
        }
        
        StaticPopupDialogs["NEXUSMANAGER_CHALLENGE_INVITE"] = dialog
        StaticPopup_Show("NEXUSMANAGER_CHALLENGE_INVITE")
        
        if NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants)
            NM.ui.challenge:SetStartButtonEnabled(false)
        end
        
    elseif data.type == "ACCEPT" then
        NM:Debug("Challenge: Received accept from %s", data.data.player)
        if self.leader == UnitName("player") then
            if not self.participants[data.data.player] then
                self.participants[data.data.player] = {accepted = false, online = true}
            end
            self.participants[data.data.player].accepted = true
            
            -- Broadcast updated participants list to all
            self:BroadcastMessage("UPDATE_PARTICIPANTS", {
                participants = self.participants
            })
            
            NM:Print(string.format(L["%s accepted the challenge"], data.data.player))
            
            if NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants)
            end
        end
        
    elseif data.type == "DECLINE" then
        if self.leader == UnitName("player") then
            self.participants[data.data.player] = nil
            self.pendingInvites[data.data.player] = nil
            NM:Print(data.data.player .. " " .. L["declined the challenge"])
            if NM.ui.challenge then
                NM.ui.challenge:UpdateParticipants(self.participants)
            end
        end
        
    elseif data.type == "START" then
        NM:Debug("Challenge: Received start message")
        if self.state == "pending" and self.participants[UnitName("player")] and 
           self.participants[UnitName("player")].accepted then
            
            self.state = "running"
            self.startTime = data.data.startTime
            self.duration = data.data.duration
            self.endTime = self.startTime + self.duration
            self.leader = data.data.leader
            self.participants = data.data.participants
            self.results = {}
            
            NM.session:start()
            
            -- Set timer for challenge end
            C_Timer.After(self.duration, function()
                if self.state == "running" then
                    self:Stop()
                end
            end)
            
            NM:Debug("Challenge: Started with duration %d seconds", self.duration)
            
            -- Starte Live-Updates auch für Teilnehmer
            self:StartLiveUpdates()
        end
        
    elseif data.type == "RESULT" then
        NM:Debug("Challenge: Received results from %s", data.data.player)
        self:AddResult(data.data.player, data.data)
        
        -- Prüfe ob alle Ergebnisse da sind
        local allResultsReceived = true
        for name, participant in pairs(self.participants) do
            if participant.accepted and not self.results[name] then
                allResultsReceived = false
                break
            end
        end
        
        -- Wenn alle Ergebnisse da sind, zeige eine Zusammenfassung
        if allResultsReceived then
            self:ShowFinalResults()
        end
    elseif data.type == "UPDATE_PARTICIPANTS" then
        NM:Debug("Challenge: Received participants update")
        self.participants = data.data.participants
        if NM.ui.challenge then
            NM.ui.challenge:UpdateParticipants(self.participants)
        end
    elseif data.type == "LIVE_UPDATE" then
        if self.state == "running" then
            NM:Debug("Challenge: Received live update from %s", data.data.player)
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
        totalLiv = totalLiv + (result.liv or 0)
        if result.liv > maxLiv then
            maxLiv = result.liv
            winner = player
        end
    end
    
    -- Zeige Zusammenfassung
    NM:Print("Challenge beendet!")
    NM:Print(string.format(L["Total LIV: %d"], totalLiv))
    if winner then
        NM:Print(string.format(L["Winner: %s with %d LIV"], winner, maxLiv))
    end
end

NM.Challenge = Challenge 

function NM:ShowChallengeInvite(sender, data)
    local dialog = {
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
    
    StaticPopup_Show("NEXUSMANAGER_CHALLENGE_INVITE", data.leader)
    
    StaticPopupDialogs["NEXUSMANAGER_CHALLENGE_INVITE"] = dialog
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
    
    self.results[player] = {
        liv = data.liv or 0,
        items = data.items or {},
        totalGold = data.totalGold or 0,
        lootedGold = data.lootedGold or 0
    }
    
    if NM.ui.challenge then
        NM.ui.challenge:UpdateResults(self.results)
    end
    
    NM:Debug("Challenge: Live update from %s - LIV: %d", player, data.liv or 0)
end 