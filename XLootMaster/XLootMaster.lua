local L = AceLibrary("AceLocale-2.2"):new("XLootMaster")

XLootMaster = XLoot:NewModule("XLootMaster") 

XLootMaster.dewdrop = AceLibrary("Dewdrop-2.0")

local deformat = AceLibrary("Deformat-2.0")

XLootMaster.revision  = tonumber((string.gsub("$Revision: 18448 $", "^%$Revision: (%d+) %$$", "%1")))

----- Module setup -----
function XLootMaster:OnInitialize()
	self.db = XLoot:AcquireDBNamespace("XLootMasterDB")
	self.defaults = {
		mlthreshold = 3,
		mldkpthreshold = 2,
		mldkp = false,
		mlitemtip = true,
		mlplayertip = true,
		mlrandom = true,
		mlrolls = false,
		mlallrolls = true,
		rollrange = 100,
		rolltimeout = 30,
		rollmsg = "Attention! /roll [range] for [item]. Ends in [time] seconds.",
		announcemsg = "[name] awarded [item][method]",
		announce = { group = 1, guild = 1 , rw = 1 },
	}
	XLoot:RegisterDefaults("XLootMasterDB", "profile", self.defaults)
	self.playerlist = {}
	self.prioritylist = {}
	self.rolls = {}
	
	self:DoOptions()
end

function XLootMaster:OnEnable()
	self:Hook("LootFrame_OnEvent","OnEvent", true)
	self:RollHook()
end

function XLootMaster:OnDisable()
end

function XLootMaster:OnEvent(event)
	local method, id = GetLootMethod()
	if method ~= 'master' or id ~= 0 then
		return self.hooks.LootFrame_OnEvent(event)
	end
	if event == "OPEN_MASTER_LOOT_LIST" then
		return self:ShowMenu()
	elseif event == "UPDATE_MASTER_LOOT_LIST" then
		return self.dewdrop:Refresh(1)
	end
	return self.hooks.LootFrame_OnEvent(event)
end

function XLootMaster:RollHook()
	if self.db.profile.mlrolls and not self:IsEventRegistered("CHAT_MSG_SYSTEM") then
		return self:RegisterEvent("CHAT_MSG_SYSTEM", "ChatHandler")
	elseif not self.db.profile.mlrolls and self:IsEventRegistered("CHAT_MSG_SYSTEM") then
		return self:UnregisterEvent("CHAT_MSG_SYSTEM")
	end
end

function XLootMaster:ChatHandler(message)
	if not self.rollactive then return end
	local playername, roll, min, max = deformat(message, RANDOM_ROLL_RESULT)
	if playername then
		local key = min.."-"..max
		if not self.rolls[key] then 
			self.rolls[key] = {}
		end
		if not self.rolls[key][playername] then
			self.rolls[key][playername] = { roll = roll } 
		end
	end
end

function XLootMaster:StartRoll()
	nilTable(self.rolls)
	self.rollactive = true
	self.rollstamp = time()
	if self.rollfinishevent then self:CancelScheduledEvent(self.rollfinishevent) end
	if not self.rollupdateevent then 
		self.rollupdateevent = self:ScheduleRepeatingEvent(function() self.dewdrop:Refresh(2) end, 1) 
	end
	self.rollfinishevent = self:ScheduleEvent(function() 
																		self.rollactive = false
																		self.rollfinishevent = nil
																		if self.rollupdateevent then 
																			self:CancelScheduledEvent(self.rollupdateevent)
																			self.rollupdateevent = nil
																		end 
																	end, self.db.profile.rolltimeout)
end

function XLootMaster:ClearRolls()
	nilTable(self.rolls)
	if self.rollfinishevent then self:CancelScheduledEvent(self.rollfinishevent) end
	if self.rollupdateevent then self:CancelScheduledEvent(self.rollupdateevent) end
end

----- Menu exhibition -----
function XLootMaster:ShowMenu()
	self.dewdrop:Open(UIParent,
		'children', function(level, value)
				if GetNumRaidMembers() > 0 then
					self:BuildRaidMenu(level, value)
				else
					self:BuildPartyMenu(level, value)
				end
			end,
		'cursorX', true,
		'cursorY', true
	)
end

function XLootMaster:ShowPriorityMenu()
	self.dewdrop:Open(UIParent,
		'children', function(level, value)
				self:BuildPriorityMenu(level, value)
			end,
		'cursorX', true,
		'cursorY', true
	)
end

----- Menu constructors -----
function XLootMaster:BuildPartyMenu(level, value)
	if level == 1 then
		self:InjectLootLine()
		self.dewdrop:AddLine()
		self:BuildPlayerList()
		for k, v in iteratetable(self.playerlist) do
			for k2, v2 in iteratetable(v) do
				if k2 ~= "classname" and k2 ~= "class" then
					self:InjectPlayer(k2, v2)
				end				
			end
		end
	end
	self:InjectRandomMenu(level, value)
	self:InjectFooter(level, value)
end

function XLootMaster:BuildRaidMenu(level, value)
	if level == 1 then
		self:InjectLootLine()
		self:BuildPlayerList()
		self:InjectPriorityList()
		self:InjectClasses()
		self.dewdrop:AddLine()
		local ownname = UnitName("player")
		self.dewdrop:AddLine(
			'text', "|cFFBBBBBB"..L["Self loot"],
			'icon', "Interface\\GossipFrame\\VendorGossipIcon",
			'iconWidth', 20,
			'iconHeight', 20,
			'closeWhenClicked', true,
			'func', function() self:GiveLoot(ownname, self:GetMLID(ownname), ownname) end)
	elseif level == 2 then
		if self.playerlist[value] then
			for k, v in iteratetable(self.playerlist[value]) do
				if k ~= "classname" and k ~= "class" then
					self:InjectPlayer(k, v)
				end
			end
		end
	end
	self:InjectRandomMenu(level, value)
	self:InjectFooter(level, value)
end

function XLootMaster:BuildPriorityMenu(level, value)
	if level == 1 then
		self.dewdrop:AddLine(
			'text', "|cFF44FF44"..L["Priority Looters"],
			'icon', "Interface\\TargetingFrame\\UI-PVP-FFA",
			'iconWidth', 84,
			'iconHeight', 84,
			'isTitle', true)
		self:BuildPlayerList()
		if self.prioritylist then
			for k, v in iteratetable(self.prioritylist, "key") do
					self.dewdrop:AddLine(
						'text', string.format("|cFF%s%s|r", XLoot:ClassHex(v.class), v.name),
						'hasArrow', true,
						'value', v.name)
				end
		else
			self.dewdrop:AddLine(
					'text', "No priority players",
					'isTitle', true)
		end
		self.dewdrop:AddLine()
		self.dewdrop:AddLine(
			'text', "|cFF44FF44"..L["Possible victims"],
			'icon', "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
			'iconWidth', 24,
			'iconHeight', 24,
			'isTitle', true)
		self:InjectClasses()
	elseif level == 2 then
		if self.prioritylist[value] then
			local player = self.prioritylist[value]
			if player.key ~= 1 then
				self.dewdrop:AddLine(
					'text', L["Move up"],
					'icon', "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Down",
					'iconWidth', 24,
					'iconHeight', 24,
					'arg1', value,
					'func', function(val) self:PriorityShift(val, -1) end)
			end
			if player.key ~= self.prioritykeys then
				self.dewdrop:AddLine(
					'text', L["Move Down"],
					'icon', "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Down",
					'iconWidth', 24,
					'iconHeight', 24,
					'arg1', value,
					'func', function(val) self:PriorityShift(val, 1) end)
			end
			self.dewdrop:AddLine(
				'text', "|cFFFF3311"..L["Remove"],
				'icon', "Interface\\Glues\\Login\\Glues-CheckBox-Check",
				'arg1', value,
				'func', function(val) self:PriorityRemove(val) end)
				
		elseif self.playerlist[value] then
	local tip = self.db.profile.mlplayertip
			for k, v in iteratetable(self.playerlist[value]) do 
				if k ~= "classname" and k ~= "class" then
					self.dewdrop:AddLine(
						'text', string.format("|cFF%s%s|r", XLoot:ClassHex(v.class), k),
						'checked', self.prioritylist[k] and true or false,
						'arg1', v,
						'func', function(player) if self.prioritylist[player.name] then self:PriorityRemove(player.name) else self:PriorityAdd(player) end end)
				end
			end
		end
	end
	self:InjectFooter(level, value)		
end


----- Priority management -----
function XLootMaster:PriorityAdd(player)
	self.prioritylist[player.name] = player
	if not self.prioritykeys then
		self.prioritykeys = 1
	else self.prioritykeys = self.prioritykeys + 1 end
	self.prioritylist[player.name].key = self.prioritykeys
end

function XLootMaster:PriorityRemove(name)
	local tempkey = self.prioritylist[name].key
	nilTable(self.prioritylist[name])
	self.prioritylist[name] = nil
	self.prioritykeys = self.prioritykeys - 1
	for k, v in pairs(self.prioritylist) do
		if v.key > tempkey then
			v.key = v.key-1
		end
	end
	if table.getn(self.prioritylist) == 0 then
		self.dewdrop:Close(2)
	end
	self.dewdrop:Refresh(1)
end

function XLootMaster:PriorityShift(name, mod)
	local key = self.prioritylist[name].key
	for k, v in pairs(self.prioritylist) do
		if v.key == key + mod then
			v.key = key
			break
		end
	end
	self.prioritylist[name].key = key + mod
end

----- Menu components -----
function XLootMaster:InjectPlayer(name, object)
	local mlid = self:GetMLID(name)
	local tip = self.db.profile.mlplayertip
	local cname = name
	if mlid then 
		local name = string.format("|cFF%s%s|r", XLoot:ClassHex(object.class), name)
		self.dewdrop:AddLine(
			'text', name,
			'closeWhenClicked', true, 
			'tooltipFunc', tip and GameTooltip.SetUnit or function() end,
			'tooltipArg1', tip and GameTooltip or nil,
			'tooltipArg2', tip and object.unit or nil,
			'func', function() self:GiveLoot(name, mlid, cname) end)
	else
		self.dewdrop:AddLine(
			'text', name,
			'closeWhenClicked', true,
			'tooltipFunc', function() end,
			'disabled', true)
	end
end

function XLootMaster:InjectClasses()
	for k, v in iteratetable(self.playerlist) do
		self.dewdrop:AddLine(
			'text', string.format("|cFF%s%s|r", XLoot:ClassHex(k), v.classname),
			'hasArrow', true,
			'value', k)
	end
end

function XLootMaster:InjectLootLine()
	local icon, name, quantity, quality = GetLootSlotInfo(LootFrame.selectedSlot)
	local tip = self.db.profile.mlitemtip
	local link = XLoot:LinkToID(GetLootSlotLink(LootFrame.selectedSlot))
	if not link then return nil end
	self.dewdrop:AddLine(
		'text', string.format("%s%s%s|r", tonumber(quantity) > 1 and tostring(quantity).."x" or "", ITEM_QUALITY_COLORS[quality].hex, name),
		 'icon', icon,
		 'iconWidth', 20,
		 'iconHeight', 20,
		 'tooltipFunc', tip and GameTooltip.SetHyperlink or function() end,
		 'tooltipArg1', tip and GameTooltip or nil,
		 'tooltipArg2', tip and link or nil)
end

function XLootMaster:InjectRandomMenu(level, value)
	local db = self.db.profile
	if not db.mlrandom then return end
	if level == 1 then
		self.dewdrop:AddLine()
		local randplayer, randid = self:GetRandomMLID()
		self.dewdrop:AddLine(
			'text', L["Give to random player"],
			'icon', "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
			'iconWidth', 20,
			'iconHeight', 20, 
			'func', function() self:GiveLoot(randplayer, randid, nil, "Random") end)
		self.dewdrop:AddLine(
			--'text', L["Random"],
			'text', L["Rolls"],
			'icon', "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
			'iconWidth', 20,
			'iconHeight', 20, 
			'hasArrow', true,
			'value', 'random')
	elseif level == 2 and value == 'random' then
		if db.mlrolls then
			self.dewdrop:AddLine(
				'text', L["Clear list and announce new roll"],
				'icon', 'Interface\\Buttons\\UI-GuildButton-MOTD-Up', 
				'iconWidth', 20,
				'iconHeight', 20, 
				'func', function() 
							self:StartRoll()
							local message = tokenizestring(db.rollmsg, { range = db.rollrange, item = GetLootSlotLink(LootFrame.selectedSlot), time = db.rolltimeout })
							self:SendMasterMessage(message)
							end)
			if self.rollactive then
				local remaining = db.rolltimeout-(time()-self.rollstamp)
				self.dewdrop:AddLine(
					'text', remaining > 1 and string.format(L["|cFF2255FFListening... |cFF44FF44%s|cFF2255FF seconds left"], remaining) or L["|CFFBBBBBBRoll finished"],
					'isTitle', true)
			end
			if next(self.rolls) then
				for k, v in iteratetable(self.rolls, nil, true) do
					local min, max = deformat(k, "%d-%d")
					if db.mlallrolls or (min == 1 and max == db.rollrange) then
						self.dewdrop:AddLine()
						self.dewdrop:AddLine(
							'text', "|cFF77BBFF"..k,
							'icon', "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
							'isTitle', true)
						for k2, v2 in iteratetable(self.rolls[k], 'roll', true) do
							local rawname = k2 -- Disconnecting is bad.
							local name = string.format("|cff%s%s|r", XLoot:ClassHex(UnitClass(unitFromPlayerName(k2))), k2)
							self.dewdrop:AddLine(
								'text', string.format("%s - %s", v2.roll, name),
								'closeWhenClicked', true,
								'func', function() self:GiveLoot(name, self:GetMLID(rawname), rawname); self:ClearRolls() end, true, true)
						end
					end
				end
			end
		end
	end
end

function XLootMaster:InjectFooter(level, value)
	if level == 1 then 
		self.dewdrop:AddLine()
		self.dewdrop:AddLine(
			'text', OPTIONS_MENU,
			'hasArrow', true,
			'value', 'options')
		self.dewdrop:AddLine(
			'text', "|cFFFF3311"..CANCEL,
			'icon', "Interface\\Glues\\Login\\Glues-CheckBox-Check",
			'closeWhenClicked', true)
	elseif level == 2 then
		if value == "options" then
			self.dewdrop:AddLine(
				'text', "|cFF44EE66"..L[">> Priority configuration"],
				'icon', "Interface\\TargetingFrame\\UI-PVP-FFA",
				'iconWidth', 64,
				'iconHeight', 64,
				'func', function() self:ShowPriorityMenu() end)
			self.dewdrop:AddLine()
			self.dewdrop:FeedAceOptionsTable( XLoot.opts.args.master, 1)
		end
	elseif level == 3 then
		if XLoot.opts.args.master.args[value] then 
			self.dewdrop:FeedAceOptionsTable(XLoot.opts.args.master.args[value], 2)
		end
	end		
end

function XLootMaster:InjectPriorityList()
	if self.prioritylist then
		for k, v in iteratetable(self.prioritylist, 'key') do
			self:InjectPlayer(k, v)
		end
		self.dewdrop:AddLine()
	end
end


----- Cache management -----
function XLootMaster:BuildPlayerList()
	if table.getn(self.playerlist) > 0 then	for k, v in pairs(self.playerlist) do v = nil; self.playerlist[k] = nil end self.playerlist = { } end
	
	if GetNumRaidMembers() > 0 then
		for i = 1, GetNumRaidMembers() do
			self:PlayerIteration("raid"..i)
		end
		
	elseif GetNumPartyMembers() > 0 then
		for i = 1, GetNumPartyMembers() do
			self:PlayerIteration("party"..i)
		end
		self:PlayerIteration("player")
		
	else
		self:PlayerIteration("player")
	end
end

function XLootMaster:PlayerIteration(unit)
	local classname, class = UnitClass(unit)
	local name = UnitName(unit)
	if not self.playerlist[class] then 
		self.playerlist[class] = { class = class, classname = classname }
	end
	self.playerlist[class][name] = { name = name, class = class, unit = unit }
end


----- Utility functions -----
function XLootMaster:SendMasterMessage(message, skipRw)
	if IsRaidLeader() or IsRaidOfficer() and not skipRw then
		SendChatMessage(message, "RAID_WARNING");
	elseif GetNumRaidMembers() > 0 then
		SendChatMessage(message, "RAID") 
	else 
		SendChatMessage(message, "PARTY")
	end
end

-- Called whenever loot has been distributed, fed the data object.
function XLootMaster:AnnounceDistribution(v)
	local ann = self.db.profile.announce
	local message = tokenizestring(self.db.profile.announcemsg, { name = v.name, item = v.link, method = v.method and " ("..v.method..")" or "" })
	if ann.group ~= 1 and v.quality >= ann.group-2 then
		self:SendMasterMessage(message, true)
	end
	if ann.rw ~= 1 and v.quality >= ann.rw-2 then
		self:SendMasterMessage(message)
	end
	if ann.guild ~= 1 and v.quality >= ann.guild-2 then
		SendChatMessage(message, "GUILD")
	end
end

function XLootMaster:GiveLoot(name, id, plainname, method)
	local link = GetLootSlotLink(LootFrame.selectedSlot)
	local dialog
	local data = { id = id, name = plainname or name, link = link, quality = LootFrame.selectedQuality, method = method }
	
	if LootFrame.selectedQuality >= self.db.profile.mldkpthreshold and self.db.profile.mldkp then
		dialog = StaticPopup_Show("CONFIRM_XLOOT_DKP_DISTRIBUTION", ITEM_QUALITY_COLORS[LootFrame.selectedQuality].hex..LootFrame.selectedItemName..FONT_COLOR_CODE_CLOSE, name)
		if dialog then
			dialog.data = data
		end
		
	elseif LootFrame.selectedQuality >= self.db.profile.mlthreshold then
		dialog = StaticPopup_Show("CONFIRM_XLOOT_DISTRIBUTION", ITEM_QUALITY_COLORS[LootFrame.selectedQuality].hex..LootFrame.selectedItemName..FONT_COLOR_CODE_CLOSE, name)
		if dialog then
			dialog.data = data
		end	
		
	else
		self:AnnounceDistribution(data)
		GiveMasterLoot(LootFrame.selectedSlot, id)
	end
end

function XLootMaster:GetRandomMLID()
	local max = GetNumRaidMembers() > 0 and 40 or 5
	local name, id
	while not name do
		id = math.random(1, max)
		name = GetMasterLootCandidate(id)
	end
	return name, id
end

function XLootMaster:GetMLID(name)
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do
			if GetMasterLootCandidate(i) == name then
				return i
			end
		end
	elseif GetNumPartyMembers() > 0 then
		for i = 1, MAX_PARTY_MEMBERS+1 do
			if GetMasterLootCandidate(i) == name then
				return i
			end
		end
	end
	return nil
end