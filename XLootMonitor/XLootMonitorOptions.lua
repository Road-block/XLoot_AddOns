local L = AceLibrary("AceLocale-2.2"):new("XLootMonitor")
local XL = AceLibrary("AceLocale-2.2"):new("XLoot")

local _G = getfenv(0)

local hcolor = "|cFF77BBFF"
local specialmenu = "|cFF44EE66"

function XLootMonitor:DoOptions()
	local db = self.db.profile

	self.opts = {
		header = {
			type = "header",
			icon = "Interface\\GossipFrame\\VendorGossipIcon",
			iconWidth = 24,
			iconHeight = 24,
			name = hcolor..L["optMonitor"].."  |c88888888"..self.revision,
			order = 1
		},
		lock = {
			type = "toggle",
			name = L["optLockAll"],
			desc = L["optLockAll"],
			get = function()
				return db.lock
				end,
			set = function(v)
				db.lock = v
				end,
			order = 2
		},
		options = {
			type = "execute",
			name = XL["optOptions"],
			desc = XL["descOptions"],
			func = function() self:OpenMenu(UIParent) end,
			order = 100,
			guiHidden = true
		},
		mspacer = {
			type = "header",
			order = 3
		},
		monitor = {
			type = "group",
			icon = "Interface\\GossipFrame\\TrainerGossipIcon",
			iconWidth = 16,
			iconHeight = 16,
			name = "|cFF44EE66"..L["Loot Monitor"],
			desc = "|cFF44EE66"..L["Loot Monitor"],
			args = { },
			order = 10
		},
		qualitythreshold = {
			type = "text",
			name = L["optQualThreshold"],
			desc = L["descQualThreshold"],
			get = function() return XLoot.opts_qualitykeys[db.qualitythreshold+1] end,
			set = function(v) db.qualitythreshold = XLoot:optGetKey(XLoot.opts_qualitykeys, v) - 1 end,
			validate = XLoot.opts_qualitykeys,
			order = 15
		},
		selfqualitythreshold = {
			type = "text",
			name = L["optSelfQualThreshold"],
			desc = L["descSelfQualThreshold"],
			get = function() return XLoot.opts_qualitykeys[db.selfqualitythreshold+1] end,
			set = function(v) db.selfqualitythreshold = XLoot:optGetKey(XLoot.opts_qualitykeys, v) - 1 end,
			validate = XLoot.opts_qualitykeys,
			order = 16
		},
		money = {
			type = "toggle",
			name = L["optMoney"],
			desc = L["descMoney"],
			set = function(v) db.money = v end,
			get = function() return db.money end,
			order = 17,
		},
		modulespacer = {
			type = "header",
			order = 70,
		},
		moduleheader = {
			type = "header",
			name = hcolor..L["catModules"],
			icon = "Interface\\GossipFrame\\TaxiGossipIcon",
			order = 71,
		},
		history = {
			type = "execute",
			name = specialmenu..L["moduleHistory"],
			desc = specialmenu..L["moduleHistory"],
			icon = "Interface\\GossipFrame\\TrainerGossipIcon",
			func = function() 
							self.dewdrop:Open(UIParent,
							'children', function(level, value, valueN_1, valueN_2, valueN_3, valueN_4) self:BuildHistory(level, value) end,
							'cursorX', true,
							'cursorY', true
						)
			end,
			order = 75,
		},
		xlootspacer = {
			type = "header",
			order = 85
		},
		xlootoptions =  {
			name = specialmenu..XL["guiTitle"],
			desc = specialmenu..XL["guiTitle"],
			icon = "Interface\\GossipFrame\\BinderGossipIcon",
			desc = XL["guiTitle"],
			type = "execute",
			order = 86,
			func = function() XLoot:OpenMenu(UIParent) end
		},
	}

	if not XLoot.opts.args.pluginspacer then
		XLoot.opts.args.pluginspacer = {
			type = "header",
			order = 85
		}
	end
	
	XLoot.opts.args.monitor =  {
		name = specialmenu..L["optMonitor"],
		desc = L["descMonitor"],
		icon = "Interface\\GossipFrame\\BinderGossipIcon",
		type = "group",
		order = 86,
		args = self.opts
	}

	XLoot.opts.args.history = {
		type = "execute",
		name = specialmenu..L["moduleHistory"],
		desc = specialmenu..L["moduleHistory"],
		icon = "Interface\\GossipFrame\\TrainerGossipIcon",
		func = function() 
						self.dewdrop:Open(UIParent,
						'children', function(level, value, valueN_1, valueN_2, valueN_3, valueN_4) self:BuildHistory(level, value) end,
						'cursorX', true,
						'cursorY', true
					)
		end,
		order = 87,
	}

	self.fullopts = { type = "group", args = self.opts }
	self:RegisterChatCommand({ "/xlm", "/xlootmonitor" }, self.fullopts)
end

function XLootMonitor:BuildStackOptions(stack, icon)
	local db = self.db.profile
	local skeleton = {
					header = {
						type = "header",
						icon = icon,
						iconWidth = 24,
						iconHeight = 24,
						name = hcolor..stack.anchorname,
						order = 1					
					},
					anchor = {
						type = "toggle",
						name = L["optAnchor"],
						desc = L["optAnchor"],
						set = function()
							stack.anchor = not stack.anchor
							stack.frame:EnableMouse(stack.anchor)
							db.anchors[stack.name] = stack.anchor
							if stack.anchor then
								if stack.frame:GetAlpha() < 1 then
									UIFrameFadeIn(stack.frame, 0.5, 0, 1)
								end
							elseif stack.frame:GetAlpha() > 0 then
								UIFrameFadeIn(stack.frame, 0.5, 1, 0)
							end
						end,
						get = function() return stack.anchor end,
						order = 2,
					},
					lock = {
						type = "toggle",
						name = XL["optLock"],
						desc = XL["optLock"],
						get = function()
							return db.stacks[stack.name].lock
							end,
						set = function(v)
							db.stacks[stack.name].lock = v
							end,
						order = 4
					},
					spacer = {
						type = "header",
						order = 6
					},
					positioning = {
						type = "group",
						name = L["optPositioning"],
						desc = L["descPositioning"],
						args = {
							offset = {
								type = "header",
								name = hcolor..L["catPosOffset"],
								order = 1
							},
							horiz = {
								type = "range",
								icon = "Interface\\Buttons\\UI-SliderBar-Button-Vertical",
								iconHeight = 24,
								iconWidth = 24,
								name = L["optPosHoriz"],
								desc = L["descPosHoriz"],
								get = function()
									return db.stacks[stack.name].attach.x
									end,
								set = function(v)
									db.stacks[stack.name].attach.x = v
									end,
								min = -20,
								max = 20,
								step = 1,
								order = 2
							},
							vert = {
								type = "range",
								name = L["optPosVert"],
								icon = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
								iconHeight = 24,
								iconWidth = 24,
								desc = L["descPosVert"],
								get = function()
									return db.stacks[stack.name].attach.y
									end,
								set = function(v)
									db.stacks[stack.name].attach.y = v
									end,
								min = -20,
								max = 20,
								step = 1,
								order = 3
							},
							spacer = {
								type = "header",
								order = 5
							},
							self = {
								type = "header",
								name = hcolor..L["catPosSelf"],
								order = 10
							},
							spacer2 = {
								type = "header",
								order = 20
							},
							target = {
								type = "header",
								name = hcolor..L["catPosTarget"],
								order = 30
							},
						},
						order = 8
					},
					timeout = {
						type = "range",
						name = L["optTimeout"],
						desc = L["descTimeout"],
						get = function()
							return db.stacks[stack.name].timeout
							end,
						set = function(v)
							db.stacks[stack.name].timeout = v
							end,
						min = 0,
						max = 200,
						step = 5,
						order = 12
					},
					threshold = {
						type = "range",
						name = L["optThreshold"],
						desc = L["descThreshold"],
						get = function()
							return db.stacks[stack.name].threshold
							end,
						set = function(v)
							db.stacks[stack.name].threshold = v
							end,
						min = 1,
						max = 40,
						step = 1,
						order = 14
					},
					spacer2 = {
						type = "header",
						order = 30
					},
					xlmmenu =  {
						type = "execute",
						icon = "Interface\\GossipFrame\\BinderGossipIcon",
						name = specialmenu..L["optMonitor"],
						desc = L["descMonitor"],
						order = 36,
						func = function()
							self:OpenMenu(UIParent)
							end
					}
				}
		local selfattach = self:AttachMenu(11, stack, "self")
		local targetattach = self:AttachMenu(31, stack, "target")
		for k, v in pairs(selfattach) do
			skeleton.positioning.args["self"..v.point] = v
		end
		for k, v in pairs(targetattach) do
			skeleton.positioning.args["target"..v.point] = v
		end
		return skeleton
end

function XLootMonitor:AttachMenu(offset, stack, point)
	local points = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT" }
	local toggles = { }
	for key, val in pairs(points) do
		local tempval = val
		local tmp = { 
					type = "toggle", 
					name =L["optPos"][tempval], 
					desc = L["optPos"][tempval], 
					isRadio = true,
					checked = variable == tempval,
					set = function(v)
						variable = tempval; 
						stack.setvalue("attach", point, tempval)
						self.dewdrop:Refresh(2)
						end,
					get = function()
							return stack.getvalue("attach", point) == tempval
						end,
					point = tempval,
					order = offset + key - 1,
					}
		table.insert(toggles, tmp)
	end
	return toggles
end

function XLootMonitor:AddTestItem(title, func)
	if not self.testfuncs then self.testfuncs = { func }
	else table.insert(self.testfuncs, func) end
	if not self.opts.advanced then 
		self.opts.advanced = {
			type = "group",
			name = "|c77AAAAAA"..XL["optAdvanced"],
			desc = XL["descAdvanced"],
			args = { },
			order = 20
		}
	end
	if not self.opts.advanced.args.test then 
		self.opts.advanced.args.test = {
			type = "group",
			name = "|cFFFF5522Test handlers",
			desc = "If you're using this, kill yourself now <3.",
			args = { },
			order = 1
		}
	end
	if not self.opts.advanced.args.autotest then
		self.opts.advanced.args.autotest = {
			type = "toggle",
			name = "|cFFFF5522Stress-test handlers",
			desc = "If you're using this, you're most likely profiling. Again, kill yourself now. <3. Also. |cFFFF0000This WILL lag you out for a few moments.|r",
			set = function() 
								for it = 1, 25 do
									for key, func in ipairs(self.testfuncs) do
										func()
									end
								end
							end,
			get = function() end,
		}
	end
	if not self.opts.advanced.args.test.args[title] then
		self.opts.advanced.args.test.args[title] = {
			type = "toggle",
			name = title,
			desc = title,
			set = func,
			get = function() return false end,
		}
	end
end