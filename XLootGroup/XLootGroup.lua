local L = AceLibrary("AceLocale-2.2"):new("XLootGroup")

XLootGroup = XLoot:NewModule("XLootGroup")

XLootGroup.dewdrop = AceLibrary("Dewdrop-2.0")

local AA = AceLibrary("AnchorsAway-1.0")
XLootGroup.AA = AA

local _G = getfenv(0)

XLootGroup.revision  = tonumber((string.gsub("$Revision: 18496 $", "^%$Revision: (%d+) %$$", "%1")))

function XLootGroup:OnInitialize()
	self.db = XLoot:AcquireDBNamespace("XLootGroupDB")
	self.defaults = {
		extra = true,
		buttonscale = 24,
		nametrunc = 15,
	}
	XLoot:RegisterDefaults("XLootGroupDB", "profile", self.defaults)
end

function XLootGroup:OpenMenu(frame)
	self.dewdrop:Open(frame,
		'children', function(level, value)
				self.dewdrop:FeedAceOptionsTable(self.fullopts)
			end,
		'cursorX', true,
		'cursorY', true
	)
end

function XLootGroup:OnEnable()
	local db = self.db.profile
	UIParent:UnregisterEvent("START_LOOT_ROLL")
	UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
	self:RegisterEvent("START_LOOT_ROLL", "AddGroupLoot")
	self:RegisterEvent("CANCEL_LOOT_ROLL", "CancelGroupLoot")
	
	if not AA.stacks.roll then
		local stack = AA:NewAnchor("roll", "Loot Rolls", "Interface\\Buttons\\UI-GroupLoot-Dice-Up", db, self.dewdrop, nil, 'add')
		XLoot:Skin(stack.frame)
		stack.SizeRow = XLoot.SizeRow
		stack.BuildRow = self.GroupBuildRow
		stack.opts.threshold = nil
		stack.opts.timeout = nil
		stack.opts.extra = { 
			type = "toggle", 
			name = L["Show countdown text"], 
			desc = L["Show small text beside the item indicating how much time remains"], 
			get = function() if db.extra == nil then db.extra = true end return db.extra end,
			set = function(v) db.extra = v end,
			order = 15 }
		stack.opts.buttonsize = {
			type = "range",
			name = L["Roll button size"],
			desc = L["Size of the Need, Greed, and Pass buttons"],
			get = function() return db.buttonscale end,
			set = function(v) db.buttonscale = v; XLootGroup:ResizeButtons() end,
			min = 10,
			max = 36,
			step = 1,
			order = 16
		}
		stack.opts.trunc = {
			type = "range",
			name = L["Trim item names to..."],
			desc = L["Length in characters to trim item names to"],
			get = function() return db.nametrunc end,
			set = function(v) db.nametrunc = v end,
			min = 4,
			max = 100,
			step = 2,
			order = 17
		}
		local stackdb = AA.stacks.roll.db
		stackdb.timeout = 10000
		stackdb.threshold = 10000
		stack.clear = function(row)
			row.rollID = nil
			row.rollTime = nil
			row.timeout = nil
			row.link = nil
			row.itemid = nil
			row.clicked = nil
		end
		
		if not XLoot.opts.args.pluginspacer then
			XLoot.opts.args.pluginspacer = {
				type = "header",
				order = 85
			}
		end
		
		XLoot.opts.args.group =  {
			name = "|cFF44EE66"..L["XLoot Group"],
			desc = L["A stack of frames for showing group loot information"],
			icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
			type = "group",
			order = 87,
			args = stack.opts
		}
	end
end

function XLootGroup:OnDisable()
	self:UnregisterAllEvents()
	UIParent:RegisterEvent("START_LOOT_ROLL")
	UIParent:RegisterEvent("CANCEL_LOOT_ROLL")
end

function XLootGroup:ResizeButtons()
	local size = self.db.profile.buttonscale
	for _, row in pairs(AA.stacks.roll.rows) do
		row.bgreed:SetWidth(size)
		row.bgreed:SetHeight(size)
		row.bneed:SetWidth(size)
		row.bneed:SetHeight(size)
		row.bpass:SetWidth(size)
		row.bpass:SetHeight(size)
		XLoot:SizeRow(nil, row)
	end
end

XLootGroup.rollbuttons = { 'bneed', 'bgreed', 'bpass' }
function XLootGroup:AddGroupLoot(item, time)
	local stack = AA.stacks.roll
	local row = AA:AddRow(stack)
	row.rollID = item
	row.rollTime = time
	row.timeout = time
	row.link = GetLootRollItemLink(item)
	row.itemid = XLoot:LinkToID(row.link)
	row.status:SetMinMaxValues(0, time)
	local texture, name, count, quality, bop = GetLootRollItemInfo(item)
	local length = self.db.profile.nametrunc
	if string.len(name) > length then
		name = string.sub(name, 1, length)..".."
	end
	SetItemButtonTexture(row.button, texture)
	row.fsloot:SetText((count>1 and count.."x " or "")..name)
	row.fsloot:SetVertexColor(GetItemQualityColor(quality))
	row:SetScript("OnUpdate", self:RollUpdateClosure(item, time, row, stack, id))
	for k, v in pairs(XLootGroup.rollbuttons) do
		row[v]:Show()
		row[v]:Enable()
	end
	XLoot:QualityColorRow(row, quality)
	XLoot:SizeRow(stack, row)
end

function XLootGroup:RollUpdateClosure(item, time, row, stack, id)
	local width, lastleft, niltext
	return function()
		if not width then
			width = row.status:GetWidth()
		end
		local left = GetLootRollTimeLeft(item)
		if not lastleft then lastleft = left
		elseif lastleft < left then return nil end
		left = math.max(0, math.min(left, time))
		row.status:SetValue(left)
		if self.db.profile.extra then
			row.fsextra:SetText(string.format("%.f ", left/1000))
			niltext = false
		elseif not niltext then
			row.fsextra:SetText("")
			niltext = true
		end
		local point = width*(left/time)+1
		return row.status.spark:SetPoint("CENTER", row.status, "LEFT", point, 0)
	end
end

function XLootGroup:CancelGroupLoot(id, timeout)
	 for k, row in ipairs(AA.stacks.roll.rowstack) do
	 	if row.rollID == id then
			row:SetScript("OnUpdate", nil)
			row.fsextra:SetText("")
			--local left = GetLootRollTimeLeft(id)
			AA:PopRow(AA.stacks.roll, row.id, nil, nil, 5)
			for i, v in pairs(XLootGroup.rollbuttons) do
				row[v]:Disable()
				if v ~= row.clicked then
					local rowt = row[v]
					UIFrameFadeOut(row[v], 1, 1, 0)
					row[v].fadeInfo.finishedFunc = function() rowt:Hide()  end
					row[v].fadeInfo.fadeHoldTime = 5
				end
			end
	 	end
	 end
end

function XLootGroup:ClickRoll(row, which)
	row.clicked = which
end

function XLootGroup:GroupBuildRow(stack, id)
	local row = XLoot:GenericItemRow(stack, id, AA)

	local rowname = row:GetName()

	local bneed = CreateFrame("Button", rowname.."NeedButton", row)
	bneed:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
	bneed:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")
	bneed:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
	bneed:SetScript("OnClick", function() XLootGroup:ClickRoll(row, 'bneed'); RollOnLoot(row.rollID, 1) end)
	bneed:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText(NEED) end)
	bneed:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local bgreed = CreateFrame("Button", rowname.."GreedButton", row)
	bgreed:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
	bgreed:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")
	bgreed:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Down")
	bgreed:SetScript("OnClick", function() XLootGroup:ClickRoll(row, 'bgreed'); RollOnLoot(row.rollID, 2) end)
	bgreed:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText(GREED) end)
	bgreed:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local bpass = CreateFrame("Button", rowname.."PassButton", row)
	bpass:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	bpass:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
	bpass:SetScript("OnClick", function() XLootGroup:ClickRoll(row, 'bpass'); RollOnLoot(row.rollID, 0) end)
	bpass:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText(PASS) end)
	bpass:SetScript("OnLeave", function() GameTooltip:Hide() end)
	
	local status = CreateFrame("StatusBar", rowname.."StatusBar", row)
	status:SetMinMaxValues(0, 60000)
	status:SetValue(0)
	status:SetStatusBarTexture("Interface\\AddOns\\XLootGroup\\DarkBottom.tga")--"Interface\\AddOns\\ag_UnitFrames\\Images\\AceBarFrames")--"Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
	
	local spark = row:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	status.spark = spark
	
	row:SetScale(1.2)
	
	local size = XLootGroup.db.profile.buttonscale
	bneed:SetWidth(size)
	bneed:SetHeight(size)
	bgreed:SetWidth(size)
	bgreed:SetHeight(size)
	bpass:SetWidth(size)
	bpass:SetHeight(size)
	
	local level = row.overlay:GetFrameLevel()+1
	bneed:SetFrameLevel(level)
	bgreed:SetFrameLevel(level)
	bpass:SetFrameLevel(level)
	
	bneed:SetPoint("LEFT", row.button, "RIGHT", 5, -1)
	bgreed:SetPoint("LEFT", bneed, "RIGHT", 0, -1)
	bpass:SetPoint("LEFT", bgreed, "RIGHT", 0, 2.2)
	row.fsplayer:ClearAllPoints()
	row.fsloot:SetPoint("LEFT", bpass, "RIGHT", 5, 1.2)
	status:SetFrameLevel(status:GetFrameLevel()-1)
	status:SetStatusBarColor(.8, .8, .8, .9)
	status:SetPoint("TOP", row, "TOP", 0, -4)
	status:SetPoint("BOTTOM", row, "BOTTOM", 0, 4)
	status:SetPoint("LEFT", row.button, "RIGHT", -1, 0)
	status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	
	row.fsextra:SetVertexColor(.8, .8, .8, .8)
	
	spark:SetWidth(12)
	spark:SetHeight(status:GetHeight()*2.44)

	XLoot:ItemButtonWrapper(row.button, 8, 8, 20)
	
	row.bneed = bneed
	row.bgreed = bgreed
	row.bpass = bpass
	row.status = status
	row.candismiss = false
	row.sizeoffset = 52
	return row
end