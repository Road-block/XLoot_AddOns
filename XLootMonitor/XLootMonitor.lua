local L = AceLibrary("AceLocale-2.2"):new("XLootMonitor")

XLootMonitor = XLoot:NewModule("XLootMonitor")

XLootMonitor.dewdrop = AceLibrary("Dewdrop-2.0")
local deformat = AceLibrary("Deformat-2.0")
local AA = AceLibrary("AnchorsAway-1.0")
XLootMonitor.AA = AA
XLoot.deformat = deformat

local _G = getfenv(0)

XLootMonitor.revision  = tonumber((string.gsub("$Revision: 18448 $", "^%$Revision: (%d+) %$$", "%1")))

function XLootMonitor:OnInitialize()
	self.db = XLoot:AcquireDBNamespace("XLootMonitorDB")
	self.defaults = {
		lock = false,
		qualitythreshold = 2,
		selfqualitythreshold = 1,
		historylinktrunc = 20,
		monitorlinktrunc = 20,
		historyactive = true,
		money = true,
		texcolor = true,
		strata = "LOW",
		layout = 1,
		anchors = { },
		pos = { },
		stacks = { },
	}
	XLoot:RegisterDefaults("XLootMonitorDB", "profile", self.defaults)
	self:DoOptions()	

	self.exports = { }
	self.stacks = { }
	self.cache = { time = { }, player = { }, total = { } }
	self.matchcache = { }
	self.filters = { loot = self:LocalizeLootHandlers() }
	self.uid = 0

	self:AddTestItem("money1", function() self:LootHandler(string.format(LOOT_MONEY_SPLIT, "70 Gold, 2 Silver, 3 Copper")) end)
	self:AddTestItem("money2", function() self:LootHandler(string.format(LOOT_MONEY_SPLIT, "1 Gold, 3 Copper")) end)
	self:AddTestItem("money3", function() self:LootHandler(string.format(LOOT_MONEY_SPLIT, "99 Silver, 3 Copper")) end)
	self:AddTestItem("selflootcommon", function() self:LootHandler("You receive loot: |cffffffff|Hitem:4338:0:0:0|h[Mageweave Cloth]|h|r.") end)
	self:AddTestItem("selflootuncommon", function() self:LootHandler("You receive loot: |cff1eff00|Hitem:10373:0:0:0|h[Imbued Plate Leggings]|h|r.") end)
	self:AddTestItem("selflootrare", function() self:LootHandler("You receive loot: |cff007099|Hitem:12602:0:0:0|h[Draconian Deflector]|h|r.") end)
	self:AddTestItem("selfstackloot1", function() self:LootHandler("You receive loot: |cffffffff|Hitem:8948:0:0:0|h[Dried King Bolete]|h|rx3.") end)
end

function XLootMonitor:OpenMenu(frame)
	self.dewdrop:Open(frame,
		'children', function(level, value)
				self.dewdrop:FeedAceOptionsTable(self.fullopts)
			end,
		'cursorX', true,
		'cursorY', true
	)
end

function XLootMonitor:OnEnable()
	self:RegisterEvent("XLoot_Item_Recieved", "ItemRecieved")
	self:RegisterEvent("CHAT_MSG_LOOT", "LootHandler")
	self:RegisterEvent("CHAT_MSG_MONEY", "LootHandler")
	if not AA.stacks.loot then
		local stackname, anchorname, icon = "loot", L["Loot Monitor"], "Interface\\GossipFrame\\TrainerGossipIcon"
		stack = AA:NewAnchor(stackname, anchorname, icon, self.db.profile.stacks, self.dewdrop)
		XLoot:Skin(stack.frame)
		stack.SizeRow = XLoot.SizeRow
		stack.BuildRow = self.BuildRow
		stack.clear = function(row)
			row.recipient = nil
			row.item = nil
			row.count = nil
			row.link = nil
			row.itemid = nil
		end
		stack.opts.trunc = {
			type = "range",
			name = L["Trim item names to..."],
			desc = L["Length in characters to trim item names to"],
			get = function() return self.db.profile.monitorlinktrunc end,
			set = function(v) self.db.profile.monitorlinktrunc = v end,
			min = 4,
			max = 100,
			step = 2,
			order = 16
		}
		stack.opts.monitor =  {
			type = "execute",
			name = "|cFF44EE66"..L["optMonitor"],
			desc = L["descMonitor"],
			icon = "Interface\\GossipFrame\\BinderGossipIcon",
			order = 86,
			func = function() self:OpenMenu(UIParent) end,
		}
		self.opts.monitor.args = stack.opts
	end
end

function XLootMonitor:OnDisable()
	self:UnregisterAllEvents()
end
function XLootMonitor:ItemRecieved(item, recipient, count, class, classname, icon)
	if not self.db.profile.historyactive then return end
	if item == "coin" then recipient = "_coin" end

	-- Insert into time cache
	table.insert(self.cache.time, {item = item, player = recipient, count = count, time = time(), class = class, icon = icon})

	-- Insert into player cache
	if not self.cache.player[recipient] then 
		self.cache.player[recipient] = { class = class, classname = classname }
	end
	table.insert(self.cache.player[recipient], { item = item, player = recipient, count = count, time = time(), icon = icon })

	--Add to total cache
	if not self.cache.total[item] then
		self.cache.total[item] = {item = item, player = recipient, count = count, time = time(), class = class, icon = icon}
	else
		self.cache.total[item].count = self.cache.total[item].count + count
	end
end

function XLootMonitor:BuildHistory(level, value)
	local db = self.db.profile
	local string_format = string.format
	if level == 1 then
		self.dewdrop:AddLine(
			'text', "|cFF77BBFF"..L["moduleHistory"],
			'icon', "Interface\\GossipFrame\\TrainerGossipIcon",
			'iconWidth', 24,
			'iconHeight', 24,
			'isTitle', true)		
		self.dewdrop:AddLine(
			'text', L["historyTime"],
			'hasArrow' , true,
			'value', "time")
		self.dewdrop:AddLine(
			'text', L["historyPlayer"],
			'hasArrow', true,
			'value', "player")
		self.dewdrop:AddLine(
			'text', L["View by item"],
			'hasArrow', true,
			'value', "total")
		self.dewdrop:AddLine()
		self.dewdrop:AddLine(
			'text', L["Export history"],
			'hasArrow', true,
			'value', 'historyexport')
		self.dewdrop:AddLine(
			'text', "|cFFFF3311"..L["historyClear"],
			'icon', "Interface\\Glues\\Login\\Glues-CheckBox-Check",
			'func', function() self.cache.time = nilTable(self.cache.time); self.cache.player = nilTable(self.cache.player); self.cache.total = nilTable(self.cache.total) end)
		self.dewdrop:AddLine()
		self.dewdrop:AddLine(
			'text', L["historyTrunc"],
			'hasArrow', true,
			'hasSlider', true,
			'sliderMin', 5,
			'sliderMax', 100,
			'sliderValue', db.historylinktrunc,
			'sliderStep', 5,
			'sliderFunc', function(v) db.historylinktrunc = v end)
		self.dewdrop:AddLine(
			'text', L["moduleActive"],
			'checked', db.historyactive,
			'func', function(v) db.historyactive = not db.historyactive end)
		self.dewdrop:AddLine()
		self.dewdrop:AddLine(
			'text', "|cFF44EE66"..L["optMonitor"],
			'icon', "Interface\\GossipFrame\\BinderGossipIcon",
			'func', function() self:OpenMenu(UIParent) end)
	elseif level == 2 then
		-- View history by time
		if value == "time" then
			if not next(self.cache.time) then
				self:HistoryEmptyLine()
			else
				for k,v in ipairs(self.cache.time) do
					if v.item == "coin" then
						self.dewdrop:AddLine(
							'text', string_format("|cFFEEEEEE%s|r   %s", date("%H:%M", v.time), XLoot:ParseMoney(v.count)),
							'icon', GetCoinIcon(v.count),
							'tooltipFunc', function() end,
							'notClickable', true)
					else
						local link = self:HistoryTrimLink(v.item)
						self.dewdrop:AddLine(
							'text', string_format("|cFFEEEEEE%s|r   |cFF%s%s|r %s%s", date("%H:%M", v.time), XLoot:ClassHex(v.class), v.player, tonumber(v.count) > 1 and tostring(v.count).."x" or "", link),
						    'icon', v.icon,
						    'tooltipFunc', GameTooltip.SetHyperlink,
						    'tooltipArg1', GameTooltip,
						    'tooltipArg2', XLoot:LinkToID(v.item),
						    'func', function(arg1) self:LinkHistoryItem(arg1) end,
						    'arg1', v)
					end
				end
			end
		-- View history by player
		elseif value == "player" then
			if not next(self.cache.player) then
				self:HistoryEmptyLine()
			else
				for k, v in iteratetable(self.cache.player) do
					if k ~= "_coin" then
						self.dewdrop:AddLine(
							'text', string_format("|cFF%s%s|r", XLoot:ClassHex(v.class), k),
							'hasArrow', true,
							'value', "player "..k)
					else
						self.dewdrop:AddLine(
							'text', L["historyMoney"],
							'hasArrow', true,
							'value', "player _coin")
					end
				end
			end
		-- View history by item
		elseif value == "total" then
			if not next(self.cache.total) then
				self:HistoryEmptyLine()
			else
				if self.cache.total["coin"] then
					local coins = self.cache.total["coin"].count
					self.dewdrop:AddLine(
						'text', XLoot:ParseMoney(coins),
						'icon', GetCoinIcon(coins),
						'tooltipFunc', function() end,
						'notClickable', true)
				end
				for k, v in iteratetable(self.cache.total) do
					if k ~= "coin" then
						self.dewdrop:AddLine(
							'text', v.count.." "..v.item,
						    'icon', v.icon,
						    'arg1', v,
						    'hasArrow', true,
						    'value', "total "..k)
					end
				end
			end
		-- Export history
		elseif value == "historyexport" then
			if table.getn(self.exports) > 0 then
				for k, v in pairs(self.exports) do
					self.dewdrop:AddLine(
						'text', v.title,
						'icon', v.icon,
						'iconWidth', v.iconWidth,
						'iconHeight', v.iconHeight,
						'tooltipTitle', v.title,
						'tooltipText', v.tooltip,
						'func', v.func)
				end
			else
				self.dewdrop:AddLine(
					'text', L["No export handlers found"],
					'isTitle', true)
			end				
		end
	elseif level == 3 then
		if string.sub(value, 1, 6) == "player" then
			local player = string.sub(value, 8)
			for k, v in pairs(self.cache.player[player]) do
				if type(k) == "number" then
					if v.item == "coin" then
						self.dewdrop:AddLine(
							'text', string_format("|cFFEEEEEE%s|r   %s", date("%H:%M", v.time), XLoot:ParseMoney(v.count)),
							'icon', GetCoinIcon(v.count),
							'tooltipFunc', function() end,
							'notClickable', true)
					else
						self.dewdrop:AddLine(
							'text', string_format("|cFFEEEEEE%s|r   %s%s", date("%H:%M", v.time), tonumber(v.count) > 1 and tostring(v.count).."x" or "", v.item),
						    'icon', v.icon,
						    'tooltipFunc', GameTooltip.SetHyperlink,
						    'tooltipArg1', GameTooltip,
						    'tooltipArg2', XLoot:LinkToID(v.item),
						    'func', function(arg1) self:LinkHistoryItem(arg1) end,
						    'arg1', v)
					end
				end
			end
		elseif string.sub(value, 1, 5) == "total" then
			local item = string.sub(value, 7)
			for k, v in iteratetable(self.cache.time) do
				if v.item == item then
					local link = self:HistoryTrimLink(v.item)
					self.dewdrop:AddLine(
						'text', string_format("|cFFEEEEEE%s|r   |cFF%s%s|r %s%s", date("%H:%M", v.time), XLoot:ClassHex(v.class), v.player, tonumber(v.count) > 1 and tostring(v.count).."x" or "", link),
					    'icon', v.icon,
					    'tooltipFunc', GameTooltip.SetHyperlink,
					    'tooltipArg1', GameTooltip,
					    'tooltipArg2', XLoot:LinkToID(v.item),
					    'func', function(arg1) self:LinkHistoryItem(arg1) end,
					    'arg1', v)
				end
			end
		end
	end
end

function XLootMonitor:HistoryExportCopier(text)
	local frame = XLootHistoryEditFrame
	local edit = XLootHistoryEdit
	if not frame then
		frame = CreateFrame("Frame", "XLootHistoryEditFrame", UIParent)
		frame:SetHeight(28)
		frame:SetWidth(200)
		XLoot:BackdropFrame(frame, { .2, .2, .2, 8 }, { .8, .8, .8, 8 })
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, UIParent:GetWidth()/4)
		
		edit = CreateFrame("EditBox", "XLootHistoryEdit", frame)
		edit:SetScript("OnEscapePressed", function() frame:Hide(); edit:Hide() end)
		edit:SetAutoFocus(true)
		edit:SetMultiLine(true)
		edit:EnableMouse(true)
		edit:SetFontObject(GameFontNormalSmall)
		edit:SetTextColor(1, 1, 1)
		edit:SetJustifyV("TOP")
		edit:SetJustifyH("LEFT")
	--	edit:SetPoint("LEFT", frame, "LEFT", 3, 0)
		edit:SetPoint("TOP", frame, "TOP", 0, 0)
	--	edit:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
		edit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)

		local close = CreateFrame("Button", "XLootHistoryEditClose", edit)
		close:SetScript("OnClick", function() frame:Hide(); edit:Hide() end)
		close:SetFrameLevel(8)
		close:SetWidth(32)
		close:SetHeight(32)
		close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
		close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 3)
		close:SetHitRectInsets(5, 5, 5, 5)
		return close:Show()
	end
	-- /script XLootMonitor:HistoryExportCopier()
	edit:SetText("")
	frame:Show()
	edit:Show()
	edit:SetMaxLetters(1000)--string.len(text))
	edit:SetText("WEORIUQLJLAJDOFJWOENRQ\nSDFOUHWEORHJQLJ\n\n\nasdlkjasdf")
	edit:HighlightText()
end

function XLootMonitor:HistoryEmptyLine()
	self.dewdrop:AddLine(
		'text', L["historyEmpty"],
		'isTitle', true)
end

function XLootMonitor:HistoryTrimLink(link)
	local length = self.db.profile.historylinktrunc
	local name = XLoot:LinkToName(link)
	if string.len(name) > length then
		link = string.gsub(link, name, string.sub(name, 1, length).."..")
	end
	return link
end

function XLootMonitor:LinkHistoryItem(item)
	if not IsControlKeyDown() then
		if not ChatFrameEditBox:IsVisible() then
			ChatFrameEditBox:Show()
		end
		local outstring = string.format("%s %s: %s ", date("%H:%M", item.time), item.player, item.item)
		if strlen(ChatFrameEditBox:GetText()..outstring) > 255 then
			self:Print(L["linkErrorLength"])
		else
			ChatFrameEditBox:Insert(outstring)
		end
	else
		DressUpItemLink(item.item)
	end
end

----- I'm lazy, can't you tell?

function XLootMonitor:BuildHandler(solosort, groupsort, pat, targ, thing, num)
	return { solo = solosort, group = groupsort, pattern = pat, recipient = targ, item = thing, count = num }
end

function XLootMonitor:LocalizeLootHandlers()
	local s = "self"
	return {
				 self:BuildHandler(8, 1, LOOT_MONEY_SPLIT, s, "coin", 1),
				 self:BuildHandler(5, 2, LOOT_ITEM_MULTIPLE, 1, 2, 3),
				 self:BuildHandler(6, 3, LOOT_ITEM, 1, 2),
				 self:BuildHandler(1, 4, LOOT_ITEM_SELF_MULTIPLE, s, 1, 2),
				 self:BuildHandler(2, 5, LOOT_ITEM_SELF, s, 1),
				 self:BuildHandler(3, 6, LOOT_ITEM_PUSHED_SELF_MULTIPLE, s, 1, 2),
				 self:BuildHandler(4, 6, LOOT_ITEM_PUSHED_SELF, s, 1),
				}
end

function XLootMonitor:LootHandler(text)
	if not self.currentsort or self.currentsort ~= self:GroupStatus() then
		self.currentsort = self:GroupStatus()
		table.sort(self.filters.loot, function(a, b) return a[self.currentsort] > b[self.currentsort] end)
	end
	for i, v in iteratetable(self.filters.loot, self:GroupStatus()) do
		local matches = nilTable(self.matchcache)
		matches = { deformat(text, v.pattern) }
		if matches[1] then
			recipient = v.recipient == "self" and UnitName("player") or matches[v.recipient]
			local item = v.item == "coin" and "coin" or matches[v.item]
			local count = item == "coin" and (XLoot:ParseCoinString(matches[v.count]) or 0) or (v.count ~= nil and matches[v.count] or 1)
			local PlayerClass, EnglishClass = UnitClass(unitFromPlayerName(recipient))
			
			return self:AddLoot(item, recipient, count, EnglishClass, PlayerClass)
		end
	end
end

function XLootMonitor:AddLoot(item, recipient, count, class, classname)
	local  itemName, itemLink, itemQuality, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture
	local itemid
	
 	if item ~= "coin" then
 		itemid = XLoot:LinkToID(item)
		itemName, itemLink, itemQuality, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = XLoot:ItemInfo(itemid)
		if recipient == UnitName("player") then
			if (itemQuality) and (itemQuality < self.db.profile.selfqualitythreshold) then
				return
			end
		else
			if (itemQuality) and (itemQuality < self.db.profile.qualitythreshold) then
				return
			end
		end
	else
		if not self.db.profile.money then
			return
		end
		itemName = "coin"
	end
	self:TriggerEvent("XLoot_Item_Recieved", item, recipient, count, class, classname, itemTexture, itemName, itemLink)
		
	local length = self.db.profile.monitorlinktrunc
	if string.len(itemName) > length then
		itemName = string.sub(itemName, 1, length)..".."
	end
	
	local stack = AA.stacks.loot
	if (stack.rowstack[1] and stack.rowstack[1].item ~= itemName) or not stack.rowstack[1] then 
		
		local loottext = ""
		if item == "coin" then
			loottext = XLoot:ParseMoney(count)
		elseif tonumber(count) > 1 then
			loottext = string.format("%sx [%s]", count, itemName)
		else
			loottext = "["..itemName.."]"
		end
		
		local row = AA:PushRow(stack)
		
		row.recipient = recipient
		row.item = itemName or "coin"
		row.count = count
		row.link = item
		row.itemid = itemid
	
		if item == "coin" then -- Money
			row.fsplayer:SetText(loottext)
			row.fsloot:SetText("")
			SetItemButtonTexture(row.button, GetCoinIcon(count))
			XLoot:QualityColorRow(row, item)
		else -- Item
			row.fsplayer:SetText(recipient)
			row.fsloot:SetText(loottext)
			SetItemButtonTexture(row.button, itemTexture)
			row.fsloot:SetVertexColor(GetItemQualityColor(itemQuality))
			local c = RAID_CLASS_COLORS[class]
			row.fsplayer:SetVertexColor(c.r, c.g, c.b)
			XLoot:QualityColorRow(row, itemQuality)
		end
		row.fsextra:SetText("")
		XLoot:SizeRow(stack, row)
	else -- Add to the last row
		local srow = stack.rowstack[1]
		if item ~= "coin" then
			srow.count = srow.count + count
			srow.additional = (stack.rowstack.additional or 0) + count
			srow.fsextra:SetText("|cAA22FF22+"..srow.additional.." ")
			srow.fsloot:SetText(srow.count.."x ["..itemName.."]")
			srow.fsplayer:SetText(recipient)
			local c = RAID_CLASS_COLORS[class]
			srow.fsplayer:SetVertexColor(c.r, c.g, c.b)
		else
			srow.fsextra:SetText("|cAA22FF22+"..XLoot:ParseMoney(count, true).." ")
			srow.count = count + (srow.count or 0)
			srow.fsplayer:SetText(XLoot:ParseMoney(srow.count))
		end
			XLoot:SizeRow(stack, srow)
	end
end

function XLootMonitor:ThresholdCheck(recipient, quality)
	if recipient == UnitName("player") then
		if itemQuality < self.db.profile.selfqualitythreshold then
			return false
		end
	else
		if itemQuality < self.db.profile.qualitythreshold then
			return false
		end
	end
	return true
end

function XLootMonitor:BuildRow(stack, id)
	return XLoot:GenericItemRow(stack, id, AA)
end

function XLootMonitor:GroupStatus() -- Separate for future tweaking :P
	if GetNumPartyMembers() > 0 then return "group" else return "solo" end
end