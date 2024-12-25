local NM = LibStub("AceAddon-3.0"):GetAddon("NexusManager")
local L = NM.Locale
-- Pattern für Loot-Nachrichten
local PATTERN_LOOT_ITEM_SELF = LOOT_ITEM_SELF:gsub("%%s", "(.+)")
local PATTERN_LOOT_ITEM_SELF_MULTIPLE = LOOT_ITEM_SELF_MULTIPLE:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
local session = {
   start = time(),
   currentGold = GetMoney(),
   totalGold = 0,
   lootedGold = 0,
   class = L[select(1, UnitClass("player"))],
   state = nil,
   liv = 0,
   uncommon = 0,
   rare = 0,
   epic = 0,
   items = {},
   itemsLooted = {},
   pauseTime = nil,
   totalPauseTime = 0
}

-- Core Session Functions
function session:init()
   self:reset()
end

function session:reset()
   self.start = time()
   self.currentGold = GetMoney()
   self.totalGold = 0
   self.lootedGold = 0
   self.uncommon = 0
   self.rare = 0
   self.epic = 0
   self.items = {}
   self.itemsLooted = {}
   self.state = nil
   self.pauseTime = nil
   self.totalPauseTime = 0
   
   -- Instance handling
   if IsInInstance() then
      local name, type, difficulty = GetInstanceInfo()
      self.instance = {
         name = name,
         type = type,
         difficulty = difficulty
      }
      self.instanceRuns = 1
      self.farmName = name
   else
      self.instance = nil
      self.instanceRuns = 0
      self.farmName = nil
   end
end

function session:continue()
   if self.state ~= "paused" then return end
   
   -- Berechne die Pausenzeit und addiere sie zur Gesamtpausenzeit
   if self.pauseTime then
      self.totalPauseTime = self.totalPauseTime + (time() - self.pauseTime)
   end
   
   self.pauseTime = nil
   self.state = "running"
   NM:Print(L["Session was continued"])
end

function session:GetDurationString()
   local offset = time()
   local duration = offset - self.start - self.totalPauseTime
   local hours = math.floor(duration / 3600) % 24
   local minutes = math.floor(duration / 60) % 60
   local seconds = duration % 60
   return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function session:pause()
   if self.state ~= "running" then return end
   
   self.pauseTime = time()
   self.state = "paused"
   NM:Print(L["Session was paused"])
end

-- Item Handling
function session:itemLooted(event, message)
   local itemLink, quantity = self:parseItemLoot(message)
   if not itemLink then return end
   
   local itemID = self:ToItemID(itemLink)
   if not itemID then return end
   
   self:addItem(itemID, quantity)
   self.itemsLooted[itemID] = (self.itemsLooted[itemID] or 0) + quantity
   
   -- Trigger Challenge Update when items are looted
   self:SendChallengeUpdate()
   
   if NM.ItemsContainer then
      NM.ItemsContainer:Update()
   end
end

function session:parseItemLoot(message)
   -- Check for multiple items
   local item, count = message:match(PATTERN_LOOT_ITEM_SELF_MULTIPLE)
   if item and count then
      return item, tonumber(count)
   end
   
   -- Check for single item
   local item = message:match(PATTERN_LOOT_ITEM_SELF)
   if item then
      return item, 1
   end
   
   return nil, nil
end

function session:addItem(itemID, quantity)
   if not self.items[itemID] then
      self.items[itemID] = {
         quantity = 0,
         value = NM.TSM.GetItemValue(itemID, "DBRegionSaleAvg") or 0
      }
   end
   
   self.items[itemID].quantity = self.items[itemID].quantity + quantity
   self.liv = self.liv + (self.items[itemID].value * quantity)
   
   local _, _, quality, _, _, itemType = C_Item.GetItemInfo(itemID)
   if quality and (itemType == "Armor" or itemType == "Weapon") then
      if quality == 2 then self.uncommon = self.uncommon + quantity
      elseif quality == 3 then self.rare = self.rare + quantity
      elseif quality == 4 then self.epic = self.epic + quantity end
   end
   
   -- Challenge Update
   self:SendChallengeUpdate()
end

-- Session State Management
function session:start()
   self:init()
   self.state = 'running'
   NM:Print(L["Session was started"])
end

function session:restart()
   self:init()
   self.state = 'running'
   NM:Print(L["Session was restarted"])
end

-- Utility Functions
function session:FormatGold(value)
   if not value then return "0,0000" end
   local goldValue = tostring(value)
   local pos = #goldValue - 4
   if pos < 0 then
      return "0," .. string.rep("0", -pos) .. goldValue
   end
   local gold = goldValue:sub(1, pos)
   return (gold == "" and "0" or gold) .. "," .. goldValue:sub(pos + 1)
end

function session:ToItemID(itemString)
   if not itemString then return nil end
   local _, _, _, _, Id = string.find(itemString, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+)")
   return tonumber(Id)
end

function session:GetPostrunMsg()
   if not self.state then
      return L["LA not running or paused. Please start or resume the session."]
   end
   
   local msg = string.format("!postrun %s\n%s%s\n%s%s\n%s%s\n%s%d\n%s%d\n%s%d\n%s%s\n%s%s\n%s",
      self.farmName or "",
      L["Class: "], L[self.class],
      L["Duration: "], self:GetDurationString(),
      L["LIV: "], self:FormatGold(self.liv),
      L["Uncommon: "], self.uncommon,
      L["Rare: "], self.rare,
      L["Epic: "], self.epic,
      L["Gold looted: "], self:FormatGold(self.lootedGold),
      L["Gold total: "], self:FormatGold(self.totalGold),
      L["Annotations: "], NM.DB:UpdateOutput()
   )
   return msg .. NM.DB:UpdateOutput()
end

function session:zoneSwitched()
   if IsInInstance() then
      local name, type, difficulty = GetInstanceInfo()
      self.instance = {
         name = name,
         type = type,
         difficulty = difficulty
      }
      if not self.farmName then
         self.farmName = name
      end
      self.instanceRuns = (self.instanceRuns or 0) + 1
   else
      self.instance = nil
   end
end

function session:moneyLooted(event, msg)
   if self.state ~= "running" then return end
   
   local copper = 0
   local gold = tonumber(msg:match("(%d+) Gold") or 0)
   local silver = tonumber(msg:match("(%d+) Silver") or 0)
   local copperMatch = tonumber(msg:match("(%d+) Copper") or 0)
   
   -- Korrigierte Berechnung: 1 Gold = 10000 Kupfer, 1 Silber = 100 Kupfer
   copper = (gold * 10000) + (silver * 100) + copperMatch
   
   if copper > 0 then
      self.lootedGold = self.lootedGold + copper
   end
end

function session:moneyChanged()
   if self.state ~= "running" then 
      return 
   end
   
   local newMoney = GetMoney()
   local moneyDiff = newMoney - self.currentGold
   
   if moneyDiff > 0 then
      self.totalGold = self.totalGold + moneyDiff
      -- Challenge Update
      self:SendChallengeUpdate()
   end
   
   self.currentGold = newMoney
end

-- Neue Funktion für Challenge Updates
function session:SendChallengeUpdate()
   if not self.state == "running" then
      return
   end
   
   if not NM.Challenge then
      return
   end
   
   if not NM.Challenge.state == "running" then
      return
   end

   local currentData = {
      player = UnitName("player"),
      liv = self.liv,
      items = self.itemsLooted,
      totalGold = self.totalGold,
      lootedGold = self.lootedGold
   }
   
   if NM.Challenge.BroadcastMessage then
      NM.Challenge:BroadcastMessage("LIVE_UPDATE", currentData)
   end
end

NM.session = session