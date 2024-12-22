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
            
            local wowAccountID = accountInfo.gameAccountInfo.wowProjectID
            if wowAccountID then
                self:BroadcastMessage("INVITE", {
                    leader = self.leader
                }, wowAccountID)
                invitedCount = invitedCount + 1
                NM:Debug("Challenge: Invited %s (ID: %s)", playerName, wowAccountID)
            end
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
    self.participants[UnitName("player")] = {accepted = true, online = true}
    
    self:BroadcastMessage("ACCEPT", {
        player = UnitName("player")
    })
    
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
    
    self:BroadcastMessage("START", {
        duration = duration,
        startTime = self.startTime,
        leader = self.leader,
        participants = self.participants
    })
    
    NM.session:start()
    
    C_Timer.After(duration, function()
        if self.state == "running" then
            self:Stop()
        end
    end)
end

function Challenge:Stop()
    if self.state ~= "running" then return end
    
    self.state = "finished"
    
    self:BroadcastMessage("RESULT", {
        player = UnitName("player"),
        liv = NM.session.liv,
        items = NM.session.itemsLooted
    })
    
    self:AddResult(UnitName("player"), NM.session.liv, NM.session.itemsLooted)
end

function Challenge:AddResult(player, liv, items)
    self.results[player] = {
        liv = liv,
        items = items
    }
    
    if NM.ui.challenge then
        NM.ui.challenge:UpdateResults(self.results)
    end
end

function Challenge:BroadcastMessage(type, data, specificID)
    local message = {
        type = type,
        data = data,
        sender = UnitName("player"),
        addon = "NexusManager",
        challenge = true
    }
    
    local serialized = AceSerializer:Serialize(message)
    
    if specificID then
        BNSendGameData(specificID, "NM_CHALLENGE", serialized)
    else
        for i = 1, BNGetNumFriends() do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and 
               accountInfo.gameAccountInfo.isOnline and 
               accountInfo.gameAccountInfo.clientProgram == "WoW" then
                
                local playerName = accountInfo.gameAccountInfo.characterName
                if self.participants[playerName] then
                    local wowAccountID = accountInfo.gameAccountInfo.wowProjectID
                    if wowAccountID then
                        BNSendGameData(wowAccountID, "NM_CHALLENGE", serialized)
                    end
                end
            end
        end
    end
end

function Challenge:HandleMessage(sender, message)
    local success, data = AceSerializer:Deserialize(message)
    
    if not success then return end
    
    if data.type == "INVITE" then
        NM:ShowChallengeInvite(sender, data.data)
        
    elseif data.type == "ACCEPT" then
        if self.leader == UnitName("player") then
            self.participants[data.data.player].accepted = true
            NM:Print(data.data.player .. " " .. L["accepted the challenge"])
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
            
            C_Timer.After(self.duration, function()
                if self.state == "running" then
                    self:Stop()
                end
            end)
        end
        
    elseif data.type == "RESULT" then
        self:AddResult(data.data.player, data.data.liv, data.data.items)
    end
end

NM.Challenge = Challenge 