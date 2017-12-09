local L = AceLibrary("AceLocale-2.2"):new("XLootMonitor")

L:RegisterTranslations("enUS", function()
	return {
		catGrowth = "Row growth",
		catLoot = "Loot",
		catPosSelf = "Anchor point...",
		catPosTarget = "To...",
		catPosOffset = "Offset frame...",
		catModules = "Modules",
		
		moduleHistory = "Loot History",
		moduleActive = "Active",
		
		historyTime = "View by time",
		historyPlayer = "View by player",
		["View by item"] = true,
		historyClear = "Clear current history",
		historyEmpty = "No history to display",
		historyTrunc = "Maximum item width",
		historyMoney = "Money looted",
		["Export history"] = true,
		["No export handlers found"] = true,
		
		["Loot Monitor"] = true,
		
		optStacks = "Stacks/Anchors",
		optLockAll = "Lock all frames",
		optPositioning = "Positioning",
		optMonitor = "XLoot Monitor",
		optAnchor = "Show Anchor",
		optPosVert = "Vertically",
		optPosHoriz = "Horizontally",
		optTimeout = "Timeout",
		optDirection = "Direction",
		optThreshold = "Stack Threshold",
		optQualThreshold = "Quality threshold",
		optSelfQualThreshold = "Own quality threshold",
		optUp = "Up",
		optDown = "Down",
		optMoney = "Show coins looted",
		["Show countdown text"] = true,
		["Show small text beside the item indicating how much time remains"] = true,
		["Trim item names to..."] = true,
		["Length in characters to trim item names to"] = true,
		
		descStacks = "Set options for each individual stack, such as anchor visibility or timeout.",
		descPositioning = "Position and attachment of rows in the stack",
		descMonitor = "XLootMonitor plugin configuration",
		descAnchor = "Show anchor for this stack",
		descPosVert = "Offset the row vertically from the point you choose to anchor it to by a specific amount",
		descPosHoriz = "Offset the row horizontally from the point you choose to anchor it to by a specific amount",
		descTimeout = "Time before each row fades. |cFFFF5522Setting this to 0 disables timed fading entirely",
		descDirection = "Direction stacks grow",
		descThreshold = "Maximum number of rows displayed at any given time",
		descQualThreshold = "The lowest quality of everyone else's that will be shown by the monitor",
		descSelfQualThreshold = "The lowest quality of your own loot that will be shown by the monitor",
		descMoney = "Show share of coins looted while in a group |cFFFF0000Does NOT include solo coins yet.|r",
		
		optPos = {
			TOPLEFT = "Top left corner",
			TOP = "Top edge",
			TOPRIGHT = "Top right corner",
			RIGHT = "Right edge",
			BOTTOMRIGHT = "Bottom right corner",
			BOTTOM = "Bottom edge",
			BOTTOMLEFT = "Bottom left corner",
			LEFT = "Left edge",
			TOPLEFT = "Top left corner",
		},
		
		linkErrorLength = "Linking would make the message too long. Send or clear the current message and try again.",
		
		playerself = "You", 
	}
end)

