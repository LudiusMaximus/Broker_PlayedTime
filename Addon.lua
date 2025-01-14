--[[--------------------------------------------------------------------
	Broker_PlayedTime
	DataBroker plugin to track played time across all your characters.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	Copyright (c) 2020-2025 Ludius <ludiusmaximus@gmail.com>. All rights reserved.
	https://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
	https://www.curseforge.com/wow/addons/broker-playedtime
	https://github.com/LudiusMaximus/Broker_PlayedTime
----------------------------------------------------------------------]]

local ADDON, L = ...

local floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe = floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe

local db, myDB
local timePlayed, timeUpdated = 0, 0
local sortedFactions, sortedPlayers, sortedPlayersNoFactions, sortedRealms = { "Horde", "Alliance", "Neutral" }, {}, {}, {}

local currentFaction = UnitFactionGroup("player")
local currentPlayer = UnitName("player")
local currentRealm = GetRealmName()

-- With 14 the lines get bigger than blank lines.
local textIconSize = 13

local factionIcons = {
	[false] = {
		Alliance = "",
		Horde = "",
		Neutral = ""
	},
	[true] = {
		Alliance = "|TInterface\\BattlefieldFrame\\Battleground-Alliance:" .. textIconSize .. ":" .. textIconSize .. ":0:0:32:32:4:26:4:27|t ",
		Horde = "|TInterface\\BattlefieldFrame\\Battleground-Horde:" .. textIconSize .. ":" .. textIconSize .. ":0:0:32:32:5:25:5:26|t ",
		Neutral = "",
	},
	["set1"] = {
		Alliance = "|A:AllianceSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
		Horde = "|A:HordeSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
		Neutral = "|A:CrossedFlags:" .. textIconSize .. ":" .. textIconSize .. "|a ",
	},
	["set2"] = {
		Alliance = "|A:nameplates-icon-flag-alliance:" .. textIconSize .. ":" .. textIconSize .. "|a ",
		Horde = "|A:nameplates-icon-flag-horde:" .. textIconSize .. ":" .. textIconSize .. "|a ",
		Neutral = "|A:nameplates-icon-flag-neutral:" .. textIconSize .. ":" .. textIconSize .. "|a ",
	},
	["set3"] = {
		Alliance = "|A:Warfronts-BaseMapIcons-Alliance-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
		Horde = "|A:Warfronts-BaseMapIcons-Horde-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
		Neutral = "|A:Warfronts-BaseMapIcons-Empty-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
	},
	["set4"] = {
		Alliance = "|A:honorsystem-portrait-alliance:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
		Horde = "|A:honorsystem-portrait-horde:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
		Neutral = "|A:honorsystem-portrait-neutral:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
	},

}

local classIcons = {}
for class, t in pairs(CLASS_ICON_TCOORDS) do
	local offset, left, right, bottom, top = 0.025, unpack(t)
	classIcons[class] = format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:" .. textIconSize .. ":" .. textIconSize .. ":0:0:256:256:%s:%s:%s:%s|t ", (left + offset) * 256, (right - offset) * 256, (bottom + offset) * 256, (top - offset) * 256)
end

local CLASS_COLORS = { UNKNOWN = "|cffcccccc" }
for k, v in pairs(RAID_CLASS_COLORS) do
	CLASS_COLORS[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
end

------------------------------------------------------------------------

local FormatTime
do
	local DAY_ABBR, HOUR_ABBR, MIN_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", ""), gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", "")
	local DHM = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR)
	local  DH = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR)
	local  HM = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR)
	local   H = format("|cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR)
	local   M = format("|cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR)

	function FormatTime(t, noMinutes)
		if not t then return end

		local d, h, m

		if db.onlyHours then
			d, h, m = 0, floor(t / 3600), floor((t % 3600) / 60)
		else
			d, h, m = floor(t / 86400), floor((t % 86400) / 3600), floor((t % 3600) / 60)
		end

		if d > 0 then
			return noMinutes and format(DH, d, h) or format(DHM, d, h, m)
		elseif h > 0 then
			return noMinutes and format(H, h) or format(HM, h, m)
		else
			return format(M, m)
		end
	end
end


------------------------------------------------------------------------

-- Remove duplicates of this player name for different factions on the same realm.
-- (Can happen for Pandaren, Dracthyr or Faction Change in general.)
local function RemoveDuplicates()
	for faction, names in pairs(db[currentRealm]) do
		if faction ~= currentFaction then
			for name in pairs(names) do
				if name == currentPlayer then
					names[name] = nil
				end
			end
		end
	end
end


------------------------------------------------------------------------

-- Dirty way to pass currently sorting realm to the SortPlayers function.
local currentlySortingRealm = nil


local mapPlayerToFaction = {}
local function BuildMapPlayerToFaction()
	wipe(mapPlayerToFaction)
	for realm in pairs(db) do
		if type(db[realm]) == "table" then
			mapPlayerToFaction[realm] = {}
			for faction in pairs(db[realm]) do
				for name in pairs(db[realm][faction]) do
					mapPlayerToFaction[realm][name] = faction
				end
			end
		end
	end
end


local BuildSortedLists
do
	local function SortPlayers(a, b)

		if db.currentPlayerOnTop then
			if a == currentPlayer then
				return true
			elseif b == currentPlayer then
				return false
			end
		end

		if db.sortByPlayedTime then
			local timePlayedA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].timePlayed
			local timePlayedB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].timePlayed
			return timePlayedA > timePlayedB
		elseif db.sortByLevel then
			local levelA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].level
			local levelB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].level
			return levelA > levelB
		else
			return a < b
		end
	end

	local function SortRealms(a, b)
		if a == currentRealm then
			return true
		elseif b == currentRealm then
			return false
		end
		return a < b
	end

	function BuildSortedLists()
		wipe(sortedRealms)
		for realm in pairs(db) do
			if type(db[realm]) == "table" and (realm == currentRealm or not db.onlyCurrentRealm) then
				tinsert(sortedRealms, realm)
				sortedPlayers[realm] = wipe(sortedPlayers[realm] or {})
				sortedPlayersNoFactions[realm] = wipe(sortedPlayersNoFactions[realm] or {})

				currentlySortingRealm = realm

				for faction in pairs(db[realm]) do

					sortedPlayers[realm][faction] = wipe(sortedPlayers[realm][faction] or {})
					for name in pairs(db[realm][faction]) do
						tinsert(sortedPlayers[realm][faction], name)
						tinsert(sortedPlayersNoFactions[realm], name)
					end
					sort(sortedPlayers[realm][faction], SortPlayers)

				end
				sort(sortedPlayersNoFactions[realm], SortPlayers)

			end
		end
		sort(sortedRealms, SortRealms)
	end
end

------------------------------------------------------------------------

-- https://www.wowhead.com/guide/shadowlands-leveling-changes-level-squish
local squishTable = {
	 1, --   1

	 2, --   2
	 2, --   3
	 2, --   4

	 3, --   5
	 3, --   6
	 3, --   7

	 4, --   8
	 4, --   9

	 5, --  10
	 5, --  11

	 6, --  12
	 6, --  13

	 7, --  14
	 7, --  15

	 8, --  16
	 8, --  17

	 9, --  18
	 9, --  19

	10, --  20
	10, --  21
	10, --  22

	11, --  23
	11, --  24
	11, --  25

	12, --  26
	12, --  27
	12, --  28

	13, --  29
	13, --  30
	13, --  31

	14, --  32
	14, --  33
	14, --  34

	15, --  35
	15, --  36

	16, --  37
	16, --  38

	17, --  39
	17, --  40

	18, --  41
	18, --  42

	19, --  43
	19, --  44

	20, --  45
	20, --  46
	20, --  47

	21, --  48
	21, --  49
	21, --  50

	22, --  51
	22, --  52
	22, --  53

	23, --  54
	23, --  55
	23, --  56

	24, --  57
	24, --  58
	24, --  59

	25, --  60
	25, --  61
	25, --  62
	25, --  63

	26, --  64
	26, --  65
	26, --  66
	26, --  67

	27, --  68
	27, --  69
	27, --  70
	27, --  71

	28, --  72
	28, --  73
	28, --  74
	28, --  75

	29, --  76
	29, --  77
	29, --  78
	29, --  79

	30, --  80
	30, --  81

	31, --  82
	31, --  83

	32, --  84
	32, --  85

	33, --  86
	33, --  87

	34, --  88
	34, --  89

	35, --  90
	35, --  91

	36, --  92
	36, --  93

	37, --  94
	37, --  95

	38, --  96
	38, --  97

	39, --  98
	39, --  99

	40, -- 100
	40, -- 101

	41, -- 102
	41, -- 103

	42, -- 104
	42, -- 105

	43, -- 106
	43, -- 107

	44, -- 108
	44, -- 109

	45, -- 110
	45, -- 111

	46, -- 112
	46, -- 113

	47, -- 114
	47, -- 115

	48, -- 116
	48, -- 117

	49, -- 118
	49, -- 119

	50, -- 120
}



local function PerformLevelSquish()

	-- Only once for game clients after Shadowlands.
	if db.performedLevelSquish or select(4, GetBuildInfo()) < 90000 then return end

	for realm in pairs(db) do
		if type(db[realm]) == "table" then
			for faction in pairs(db[realm]) do
				for name in pairs(db[realm][faction]) do
					db[realm][faction][name].level = squishTable[db[realm][faction][name].level]
				end
			end
		end
	end

	db.performedLevelSquish = true

end


-- If players do not fit into one tooltip, we have to start additional ones.
local additionalTooltips = {}


-- Using first tooltip of additionalTooltips to calcualte line height.
local tooltipLineHeight = nil
-- https://warcraft.wiki.gg/wiki/API_GameTooltip_GetPadding only returned 0,0,0,0 for me, so I am getting the "padding" manually.
-- (The "padding" is the actual padding plus the difference between a normal tooltip line and the slightly greater title line.)
local tooltipTopBottomPadding = nil
function GetTooltipLineHeight()

	local testTooltip = additionalTooltips[1]

	if not testTooltip then
		testTooltip = CreateFrame("GameTooltip", ADDON .. "_AdditionalTooltip" .. "1", UIParent, "SharedTooltipTemplate")
		tinsert(additionalTooltips, testTooltip)
	else
		testTooltip:ClearLines()
	end

	testTooltip:SetOwner(UIParent, "ANCHOR_TOPLEFT")

	testTooltip:AddLine("Title")
	testTooltip:Show()
	local tooltipHeight1 = testTooltip:GetHeight()
	testTooltip:AddLine("Line 1")
	testTooltip:Show()
	local tooltipHeight2 = testTooltip:GetHeight()
	local lineHeight = tooltipHeight2 - tooltipHeight1

	-- Check to be on the safe side.
	testTooltip:AddLine("Line 2")
	testTooltip:Show()
	local tooltipHeight3 = testTooltip:GetHeight()
	testTooltip:Hide()

	-- print(math.floor((tooltipHeight2 + lineHeight) * 10000), "should equal", math.floor(tooltipHeight3 * 10000))

	if math.floor((tooltipHeight2 + lineHeight - tooltipHeight3) * 10000) == 0 then
		tooltipLineHeight = lineHeight
		tooltipTopBottomPadding = tooltipHeight1 - lineHeight
	else
		tooltipLineHeight = nil
		tooltipTopBottomPadding = nil
	end

end

------------------------------------------------------------------------

local BrokerPlayedTime = CreateFrame("Frame")
BrokerPlayedTime:SetScript("OnEvent", function(self, event, ...) return self[event] and self[event](self, ...) or self:SaveTimePlayed() end)
BrokerPlayedTime:RegisterEvent("PLAYER_LOGIN")

function BrokerPlayedTime:PLAYER_LOGIN()
	local function copyTable(src, dst)
		if type(src) ~= "table" then return {} end
		if type(dst) ~= "table" then dst = {} end
		for k, v in pairs(src) do
			if type(v) == "table" then
				dst[k] = copyTable(v, dst[k])
			elseif type(v) ~= type(dst[k]) then
				dst[k] = v
			end
		end
		return dst
	end

	local defaults = {
		sortByPlayedTime = false,
		sortByLevel = false,

		levels = false,
		classIcons = false,
		factionIcons = false,

		groupByFactions = true,
		onlyCurrentRealm = false,
		currentPlayerOnTop = true,
		highlightCurrentPlayer = false,

		onlyHours = false,

		brokerTextCurrentChar = true,

		[currentRealm] = {
			[currentFaction] = {
				[currentPlayer] = {
					class = (select(2, UnitClass("player"))),
					level = UnitLevel("player"),
					timePlayed = 0,
					timeUpdated = 0,
				},
			}
		}
	}

	BrokerPlayedTimeDB = BrokerPlayedTimeDB or {}
	db = copyTable(defaults, BrokerPlayedTimeDB)

	RemoveDuplicates()

	myDB = db[currentRealm][currentFaction][currentPlayer]

	PerformLevelSquish()

	BuildMapPlayerToFaction()

	BuildSortedLists()


	if CUSTOM_CLASS_COLORS then
		local function UpdateClassColors()
			for k, v in pairs(CUSTOM_CLASS_COLORS) do
				CLASS_COLORS[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
			end
		end
		UpdateClassColors()
		CUSTOM_CLASS_COLORS:RegisterCallback(UpdateClassColors)
	end

	self:UnregisterEvent("PLAYER_LOGIN")

	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")

	-- Needed for level boost (no PLAYER_LEVEL_UP event).
	myDB.level = UnitLevel("player")

	self:UpdateTimePlayed()

	GetTooltipLineHeight()

end

local requesting

local o = ChatFrame_DisplayTimePlayed
ChatFrame_DisplayTimePlayed = function(...)
	if requesting then
		requesting = false
		return
	end
	return o(...)
end

function BrokerPlayedTime:UpdateTimePlayed()
	requesting = true
	RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
	local now = time()
	myDB.timePlayed = timePlayed + now - timeUpdated
	myDB.timeUpdated = now

	self:UpdateText()
	self:SetUpdateInterval(timePlayed < 3600)
end

function BrokerPlayedTime:PLAYER_LEVEL_UP(level)
	myDB.level = level or UnitLevel("player")
	self:SaveTimePlayed()
end

function BrokerPlayedTime:TIME_PLAYED_MSG(t)
	timePlayed = t
	timeUpdated = time()
	self:SaveTimePlayed()
end

------------------------------------------------------------------------

local BrokerPlayedTimeMenu = CreateFrame("Frame", "BrokerPlayedTimeMenu", nil, "UIDropDownMenuTemplate")
BrokerPlayedTimeMenu.displayMode = "MENU"
BrokerPlayedTimeMenu.info = {}

BrokerPlayedTimeMenu.GetClassIcons = function() return db.classIcons end
BrokerPlayedTimeMenu.SetClassIcons = function() db.classIcons = not db.classIcons end

BrokerPlayedTimeMenu.GetFactionIcons = function() return db.factionIcons end
BrokerPlayedTimeMenu.SetFactionIcons = function() db.factionIcons = not db.factionIcons end

BrokerPlayedTimeMenu.GetLevels = function() return db.levels end
BrokerPlayedTimeMenu.SetLevels = function() db.levels = not db.levels end


BrokerPlayedTimeMenu.GetSortAlphabetically = function() return not db.sortByPlayedTime and not db.sortByLevel end
BrokerPlayedTimeMenu.SetSortAlphabetically = function()
	db.sortByPlayedTime = false
	db.sortByLevel = false
	UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
	BuildSortedLists()
end

BrokerPlayedTimeMenu.GetSortByPlayedTime = function() return db.sortByPlayedTime end
BrokerPlayedTimeMenu.SetSortByPlayedTime = function()
	db.sortByPlayedTime = true
	db.sortByLevel = false
	UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
	BuildSortedLists()
end

BrokerPlayedTimeMenu.GetSortByLevel = function() return db.sortByLevel end
BrokerPlayedTimeMenu.SetSortByLevel = function()
	db.sortByPlayedTime = false
	db.sortByLevel = true
	UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
	BuildSortedLists()
end

BrokerPlayedTimeMenu.GetGroupByFactions = function() return db.groupByFactions end
BrokerPlayedTimeMenu.SetGroupByFactions = function() db.groupByFactions = not db.groupByFactions end

BrokerPlayedTimeMenu.GetCurrentPlayerOnTop = function() return db.currentPlayerOnTop end
BrokerPlayedTimeMenu.SetCurrentPlayerOnTop = function()
	db.currentPlayerOnTop = not db.currentPlayerOnTop
	BuildSortedLists()
end

BrokerPlayedTimeMenu.GetHighlightCurrentPlayer = function() return db.highlightCurrentPlayer end
BrokerPlayedTimeMenu.SetHighlightCurrentPlayer = function() db.highlightCurrentPlayer = not db.highlightCurrentPlayer end

BrokerPlayedTimeMenu.GetOnlyHours = function() return db.onlyHours end
BrokerPlayedTimeMenu.SetOnlyHours = function()
	db.onlyHours = not db.onlyHours
	BrokerPlayedTime:UpdateText()
end

BrokerPlayedTimeMenu.GetHideOtherRealms = function() return db.onlyCurrentRealm end
BrokerPlayedTimeMenu.SetHideOtherRealms = function()
	db.onlyCurrentRealm = not db.onlyCurrentRealm
	BuildSortedLists()
	BrokerPlayedTime:UpdateText()
end

BrokerPlayedTimeMenu.CloseDropDownMenus = function() CloseDropDownMenus() end

BrokerPlayedTimeMenu.RemoveCharacter = function(button)
	local value = button and button.value or UIDROPDOWNMENU_MENU_VALUE
	local realm, faction, name = string.split("#", value)
	if realm and faction and name and db[realm] and db[realm][faction] and db[realm][faction][name] then
		db[realm][faction][name] = nil

		local nf = 0
		for k in pairs(db[realm][faction]) do
			nf = nf + 1
		end
		if nf == 0 then
			db[realm][faction] = nil
		end

		local nr = 0
		for k in pairs(db[realm]) do
			nr = nr + 1
		end
		if nr == 0 then
			db[realm] = nil
			sortedRealms[realm] = nil
		end

		BuildMapPlayerToFaction()
		BuildSortedLists()
		CloseDropDownMenus()
	end
end

BrokerPlayedTimeMenu.initialize = function(self, level, menuList)
	if not level then return end
	local info = wipe(self.info)
	if level == 1 then
		info.text = L["Played Time"]
		info.isTitle = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Sorting"]
		info.hasArrow = 1
		info.keepShownOnClick = 1
		info.notCheckable = 1
		info.menuList = "Sorting"
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Character levels"]
		info.isNotRadio = 1
		info.checked = self.GetLevels
		info.func = self.SetLevels
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Class icons"]
		info.isNotRadio = 1
		info.checked = self.GetClassIcons
		info.func = self.SetClassIcons
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Faction icons"]
		info.hasArrow = 1
		info.keepShownOnClick = 1
		info.notCheckable = 1
		info.menuList = "Faction icons"
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Group by factions"]
		info.isNotRadio = 1
		info.checked = self.GetGroupByFactions
		info.func = self.SetGroupByFactions
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Current realm only"]
		info.isNotRadio = 1
		info.keepShownOnClick = 1
		info.checked = self.GetHideOtherRealms
		info.func = self.SetHideOtherRealms
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Current character on top"]
		info.isNotRadio = 1
		info.checked = self.GetCurrentPlayerOnTop
		info.func = self.SetCurrentPlayerOnTop
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Current character highlighted"]
		info.isNotRadio = 1
		info.checked = self.GetHighlightCurrentPlayer
		info.func = self.SetHighlightCurrentPlayer
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Time in hours (not days)"]
		info.isNotRadio = 1
		info.checked = self.GetOnlyHours
		info.func = self.SetOnlyHours
		info.keepShownOnClick = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = L["Remove character"]
		info.hasArrow = 1
		info.keepShownOnClick = 1
		info.notCheckable = 1
		info.menuList = "Remove character"
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

		-- Do not show this option for users of PlayedTimeMinimapClock.
		if not TimeManagerClockButton:IsMouseOver() then
			info.text = L["Broker icon text"]
			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.notCheckable = 1
			info.menuList = "Broker icon text"
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)
		end

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)



		info.text = CLOSE
		info.func = self.CloseDropDownMenus
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
		wipe(self.info)

	elseif level == 2 then

		if menuList == "Sorting" then

			info.text = L["By played time"]
			info.checked = self.GetSortByPlayedTime
			info.func = self.SetSortByPlayedTime
			info.keepShownOnClick = 1
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)

			info.text = L["By character name"]
			info.checked = self.GetSortAlphabetically
			info.func = self.SetSortAlphabetically
			info.keepShownOnClick = 1
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)

			info.text = L["By character level"]
			info.checked = self.GetSortByLevel
			info.func = self.SetSortByLevel
			info.keepShownOnClick = 1
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)

		elseif menuList == "Faction icons" then

			for k, v in pairs(factionIcons) do
				if k == false then
					info.text = L["None"]
				else
					info.text = v["Alliance"] .. " " .. v["Horde"] .. " " .. v["Neutral"]
				end
				info.checked = function() return db.factionIcons == k end
				info.func =
					function()
						db.factionIcons = k
						UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
					end
				info.keepShownOnClick = 1
				UIDropDownMenu_AddButton(info, level)
				wipe(self.info)
			end

		elseif menuList == "Broker icon text" then

			info.text = L["Current character time"]
			info.checked = function() return db.brokerTextCurrentChar end
			info.func =
				function()
					db.brokerTextCurrentChar = not db.brokerTextCurrentChar
					UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
					BrokerPlayedTime:UpdateText()
				end
			info.keepShownOnClick = 1
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)

			info.text = L["Total time"]
			info.checked = function() return not db.brokerTextCurrentChar end
			info.func =
				function()
					db.brokerTextCurrentChar = not db.brokerTextCurrentChar
					UIDropDownMenu_Refresh(BrokerPlayedTimeMenu)
					BrokerPlayedTime:UpdateText()
				end
			info.keepShownOnClick = 1
			UIDropDownMenu_AddButton(info, level)
			wipe(self.info)

		elseif menuList == "Remove character" then
			for _, realm in ipairs(sortedRealms) do
				info.text = realm
				info.value = realm
				info.hasArrow = 1
				info.keepShownOnClick = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
				wipe(self.info)
			end
		end

	elseif level == 3 then
		local factions = 0
		for i, faction in ipairs(sortedFactions) do
			info.value = nil
			info.colorCode = nil
			info.func = nil
			info.keepShownOnClick = nil

			local realm = UIDROPDOWNMENU_MENU_VALUE
			local rfp = sortedPlayers[realm][faction]

			if rfp then
				factions = factions + 1

				-- Insert a blank line.
				if factions > 1 then
					info.text = " "
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)
					wipe(self.info)
				end

				info.disabled = nil

				info.text = faction
				info.isTitle = 1
				UIDropDownMenu_AddButton(info, level)
				wipe(self.info)

				for j, name in ipairs(rfp) do
					local cdata = db[realm][faction][name]

					info.text = name
					info.value = format("%s#%s#%s", realm, faction, name)
					info.colorCode = CLASS_COLORS[cdata and cdata.class or "UNKNOWN"]
					info.disabled = (name == currentPlayer and realm == currentRealm)
					info.func = self.RemoveCharacter
					UIDropDownMenu_AddButton(info, level)
					wipe(self.info)
				end
			end
		end
	end
end

------------------------------------------------------------------------


local function AddPlayerLines(tooltip, realm, names, firstIndex, lastIndex)
	if not realm or not names or #names == 0 then return 0 end
	if firstIndex and lastIndex and firstIndex > lastIndex then return 0 end

	local totalTime = 0
	local indexCounter = 0

	for _, name in ipairs(names) do
		local data = db[realm][mapPlayerToFaction[realm][name]][name]
		if data then

			local charTime = nil

			if realm == currentRealm and name == currentPlayer then
				charTime = data.timePlayed + time() - data.timeUpdated
			else
				charTime = data.timePlayed
			end

			if charTime and charTime > 0 then
				indexCounter = indexCounter + 1

				if not firstIndex or indexCounter >= firstIndex then
					tooltip:AddDoubleLine(
						format("%s%s%s%s%s%s|r",
							factionIcons[db.factionIcons][mapPlayerToFaction[realm][name]],
							db.classIcons and classIcons[data.class] or "",
							CLASS_COLORS[data.class] or GRAY,
							(db.highlightCurrentPlayer and realm == currentRealm and name == currentPlayer) and "|TInterface\\CHATFRAME\\ChatFrameExpandArrow:" .. math.floor(tooltipLineHeight) .. "|t" or "",
							name,
							db.levels and " ("..data.level..")" or ""
						),
						FormatTime(charTime)
					)

					totalTime = totalTime + charTime
				end

				if lastIndex and indexCounter >= lastIndex then return totalTime end
			end

		end
	end



	return totalTime
end






local function OnTooltipShow(tooltip)

	-- Estimate how many tooltips we need.
	local tooltipInitialHeight = 0
	local initialNumLines = tooltip:NumLines()
	if initialNumLines > 0 then
		tooltip:Show()
		tooltipInitialHeight = tooltip:GetHeight()
	else
		tooltipInitialHeight = tooltipTopBottomPadding
	end
	-- print("tooltipInitialHeight", tooltipInitialHeight)
	-- print("initialNumLines", initialNumLines)


	local lineCounter = 0
	lineCounter = lineCounter + 1	 					-- tooltip:AddLine(L["Played Time"])

	for _, realm in ipairs(sortedRealms) do
		lineCounter = lineCounter + 1					-- tooltip:AddLine(" ")
		if #sortedRealms > 1 then
			lineCounter = lineCounter + 1	 			-- tooltip:AddLine(realm)
		end

		if db.groupByFactions then
			for _, faction in ipairs(sortedFactions) do
				-- Not every realm has every faction.
				if sortedPlayers[realm][faction] then
					lineCounter = lineCounter + #sortedPlayers[realm][faction]			-- AddPlayerLines(tooltip, realm, sortedPlayers[realm][faction])
				end
			end
		else
			lineCounter = lineCounter + #sortedPlayersNoFactions[realm]				-- AddPlayerLines(tooltip, realm, sortedPlayersNoFactions[realm])
		end

	end

	lineCounter = lineCounter + 1	 			-- tooltip:AddLine(" ")
	lineCounter = lineCounter + 1	 			-- tooltip:AddDoubleLine(L["Total"], FormatTime(total))


	local estimatedHeight = tooltipInitialHeight + lineCounter*tooltipLineHeight
	-- print("estimatedHeight", estimatedHeight)

	local allowedHeight = 0.7 * UIParent:GetHeight()
	-- print("allowedHeight", allowedHeight)


	-- One tooltip is enough.
	if estimatedHeight <= allowedHeight then
		local totalTime = 0
		tooltip:AddLine(L["Played Time"])
		for _, realm in ipairs(sortedRealms) do
			tooltip:AddLine(" ")
			if #sortedRealms > 1 then
				tooltip:AddLine(realm)
			end

			if db.groupByFactions then
				for _, faction in ipairs(sortedFactions) do
					totalTime = totalTime + AddPlayerLines(tooltip, realm, sortedPlayers[realm][faction])
				end
			else
				totalTime = totalTime + AddPlayerLines(tooltip, realm, sortedPlayersNoFactions[realm])
			end
		end

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["Total"], FormatTime(totalTime))

		tooltip:Show()
		-- print("real height", tooltip:GetHeight(), tooltip:NumLines())


	-- #########################################################################
	-- We need several tooltips.
	else

		-- Create the additional tooltips.
		local numNeededTooltips = ceil(estimatedHeight / allowedHeight)
		-- print("numNeededTooltips", numNeededTooltips)

		-- Make all tooltips equally long.
		-- Each of the numNeededTooltips - 1 additional tooltips adds tooltipTopBottomPadding plus one tooltipLineHeight (blank title line) to the estimated height.
		-- If there is a new realm at the beginning of an additional tooltip, the extra tooltipLineHeight corresponds to the blank line preceding the realm name.
		-- Hence, allowedHeight is slightly too great. But this is OK, as we are fine with the last additinal tooltip not being fully filled.
		allowedHeight = (estimatedHeight + (numNeededTooltips - 1)*(tooltipTopBottomPadding + tooltipLineHeight)) / numNeededTooltips
		-- print("distributed allowedHeight", allowedHeight)


		-- Store the maximum tooltip height to make them all equally high.
		local maxTooltipHeight = 0

		for i = 1, numNeededTooltips-1 do
			if not additionalTooltips[i] then
				additionalTooltips[i] = CreateFrame("GameTooltip", ADDON .. "_AdditionalTooltip" .. i .. "asdas", UIParent, "SharedTooltipTemplate")
			end
		end

		-- To hide additional tootips with original tooltip.
		if not tooltip.BrokerPlayedTime_hooked then
			tooltip:HookScript("OnHide", function()
				for _, v in pairs(additionalTooltips) do
					if v:IsShown() then
						v:Hide()
					end
				end
			end)
			tooltip.BrokerPlayedTime_hooked = true
		end


		-- The tootips in the order we will use them!
		local tooltipsInOrder = {}

		-- #########################################################################
		-- Decide whether to append additional tooltips left or right.
		if UIParent:GetWidth() * UIParent:GetEffectiveScale() / GetCursorPosition() > 2 then
			-- print("Cursor is in LEFT side of screen")
			-- Original tooltip stays leftmost.
			tooltipsInOrder[1] = tooltip

			-- Additional tooltips get appended right.
			for i = 1, numNeededTooltips-1 do

				local tooltipOwner = i == 1 and tooltip or additionalTooltips[i-1]
				if tooltipOwner ~= additionalTooltips[i]:GetOwner() then
					-- SetOwner() performs ClearAllPoints() and ClearLines() as well.
					additionalTooltips[i]:SetOwner(tooltipOwner, "ANCHOR_NONE")
					additionalTooltips[i]:SetPoint("TOPLEFT", tooltipOwner, "TOPRIGHT", -3, 0)
				else
					additionalTooltips[i]:ClearLines()
				end

				tooltipsInOrder[i+1] = additionalTooltips[i]
			end

		-- #########################################################################
		else
			-- print("Cursor is in RIGHT side of screen")
			-- Original tooltip becomes rightmost.
			-- (Changing the anchor points did not work, clearing and reusing original tooltip worked.)
			tooltipsInOrder[numNeededTooltips] = tooltip

			-- Additional tooltips get appended left.
			for i = numNeededTooltips-1, 1, -1  do

				local tooltipOwner = i == numNeededTooltips-1 and tooltip or additionalTooltips[i+1]
				if tooltipOwner ~= additionalTooltips[i]:GetOwner() then
					-- SetOwner() performs ClearAllPoints() and ClearLines() as well.
					additionalTooltips[i]:SetOwner(tooltipOwner, "ANCHOR_NONE")
					additionalTooltips[i]:SetPoint("TOPRIGHT", tooltipOwner, "TOPLEFT", 3, 0)
				else
					additionalTooltips[i]:ClearLines()
				end

				tooltipsInOrder[i] = additionalTooltips[i]
			end


			-- Copy content (if any) of original tooltip to the leftmost additional tooltip.
			if initialNumLines > 0 then

				local leftText,  leftTextR,  leftTextG,  leftTextB  = {}, {}, {}, {}
				local rightText, rightTextR, rightTextG, rightTextB = {}, {}, {}, {}

				for i = 1, initialNumLines do
					leftText[i] = _G[tooltip:GetName().."TextLeft"..i]:GetText()
					leftTextR[i], leftTextG[i], leftTextB[i] = _G[tooltip:GetName().."TextLeft"..i]:GetTextColor()
					rightText[i] = _G[tooltip:GetName().."TextRight"..i]:GetText()
					rightTextR[i], rightTextG[i], rightTextB[i] = _G[tooltip:GetName().."TextRight"..i]:GetTextColor()
					-- print(i, leftText[i], rightText[i], leftTextR[i], leftTextG[i], leftTextB[i], rightTextR[i], rightTextG[i], rightTextB[i])
				end

				for i = 1, initialNumLines do
					-- print(i, leftText[i], rightText[i], leftTextR[i], leftTextG[i], leftTextB[i], rightTextR[i], rightTextG[i], rightTextB[i])
					if rightText then
						tooltipsInOrder[1]:AddDoubleLine(leftText[i], rightText[i], leftTextR[i], leftTextG[i], leftTextB[i], rightTextR[i], rightTextG[i], rightTextB[i])
					else
						tooltipsInOrder[1]:AddLine(leftText[i], leftTextR[i], leftTextG[i], leftTextB[i], true)
					end
				end

				-- Clear original tooltip.
				tooltip:ClearLines()

			end

		end



		-- #########################################################################
		-- Start filling the tooltips.



		local lineCounter = 0
		local currentTooltipIndex = 1
		local currentTooltip = tooltipsInOrder[currentTooltipIndex]
		-- currentTooltip:AddLine("This is tooltip" .. currentTooltipIndex .. " " .. (currentTooltip:GetName() and currentTooltip:GetName() or "no name"))

		local tooltipLinesLeft = nil

		-- Function to skip to the next tooltip. Resetting all values accordingly.
		local function NextTooltip()
			-- If we unexpectedly hit the end of the last tooltip, we continue!
			if currentTooltipIndex == numNeededTooltips then return end

			currentTooltip:Show()
			local currentTooltipHeight = currentTooltip:GetHeight()
			if currentTooltipHeight > maxTooltipHeight then
				maxTooltipHeight = currentTooltipHeight
			end

			-- print("------------- change from tooltip", currentTooltipIndex, "to", currentTooltipIndex + 1)
			currentTooltipIndex = currentTooltipIndex + 1
			currentTooltip = tooltipsInOrder[currentTooltipIndex]
			-- currentTooltip:AddLine("This is tooltip" .. currentTooltipIndex .. " " .. (currentTooltip:GetName() and currentTooltip:GetName() or "no name"))

			tooltipInitialHeight = tooltipTopBottomPadding

			-- Add a blank line to skip title of additional tooltips.
			currentTooltip:AddLine(" ")
			lineCounter = 1
			tooltipLinesLeft = floor((allowedHeight - (tooltipInitialHeight + tooltipLineHeight)) / tooltipLineHeight)
		end


		currentTooltip:AddLine(L["Played Time"])
		currentTooltip:AddLine(" ")
		lineCounter = lineCounter + 2

		local totalTime = 0
		for _, realm in ipairs(sortedRealms) do

			-- Starting character list of a new realm.

			-- How many lines do still fit on the current tooltip?
			tooltipLinesLeft = floor((allowedHeight - (tooltipInitialHeight + lineCounter*tooltipLineHeight)) / tooltipLineHeight)
			-- print("++", realm, "tooltipLinesLeft", tooltipLinesLeft)

			-- Only start a new realm at the end of a tooltip, if we have at least space for 4 lines: blank, realm name, 2 characters
			-- Otherwise, continue with next tooltip.
			if tooltipLinesLeft < 4 then
				NextTooltip()
			end

			-- Only add realm name, if there are more than one.
			if #sortedRealms > 1 then
				-- Add a blank line before starting a new realm, unless this is the first line of a tooltip.
				if (currentTooltipIndex == 1 and lineCounter > 2) or (currentTooltipIndex > 1 and lineCounter > 1) then
					currentTooltip:AddLine(" ")
					lineCounter = lineCounter + 1
				end
				currentTooltip:AddLine(realm)
				lineCounter = lineCounter + 1
			end


			local function TooltipSkippingCharacterPrint(listOfCharacterNames, minRest)

				if not minRest then minRest = 2 end

				local charactersToPrint = #listOfCharacterNames
				-- print("---", realm, "charactersToPrint", charactersToPrint)

				local firstIndex = 1
				local lastIndex = #listOfCharacterNames

				while charactersToPrint > 0 do

					-- print("in loop charactersToPrint", charactersToPrint)
					-- print("in loop tooltipLinesLeft", tooltipLinesLeft)

					tooltipLinesLeft = floor((allowedHeight - (tooltipInitialHeight + lineCounter*tooltipLineHeight)) / tooltipLineHeight)
					-- Only print as many characters as there are lines left.
					-- But only if there are more than minRest characters left to be printed on the next tooltip.
					if tooltipLinesLeft > 0 and tooltipLinesLeft < charactersToPrint and (charactersToPrint - tooltipLinesLeft > minRest) then
						-- print(charactersToPrint, "characters", "are too many for", tooltipLinesLeft)
						lastIndex = tooltipLinesLeft
					end

					-- print("printing", firstIndex, "to", lastIndex, "on", currentTooltip:GetName())
					totalTime = totalTime + AddPlayerLines(currentTooltip, realm, listOfCharacterNames, firstIndex, lastIndex)
					lineCounter = lineCounter + (lastIndex - firstIndex + 1)

					-- Are we skipping a tooltip?
					if lastIndex == tooltipLinesLeft then
						NextTooltip()
					end

					charactersToPrint = charactersToPrint - lastIndex
					-- Prepare indexes for next iteration, if there is one.
					if charactersToPrint > 0 then
						firstIndex = lastIndex + 1
						lastIndex = #listOfCharacterNames
					end

				end

			end



			if db.groupByFactions then
				for i, faction in ipairs(sortedFactions) do
					-- Not every realm has every faction.
					if sortedPlayers[realm][faction] then
						if i < #sortedFactions then
							TooltipSkippingCharacterPrint(sortedPlayers[realm][faction], 0)
						else
						  TooltipSkippingCharacterPrint(sortedPlayers[realm][faction], 2)
						end
					end
				end
			else
				TooltipSkippingCharacterPrint(sortedPlayersNoFactions[realm], 2)
			end

		end


		currentTooltip:AddLine(" ")
		currentTooltip:AddDoubleLine(L["Total"], FormatTime(totalTime))


		currentTooltip:Show()
		local currentTooltipHeight = currentTooltip:GetHeight()
		if currentTooltipHeight > maxTooltipHeight then
			maxTooltipHeight = currentTooltipHeight
		end


		-- Make all tooltips equally high.
		-- GameTooltip gets automatically reset. So we have to increase its size by blank lines.
		while GameTooltip:GetHeight() < maxTooltipHeight do
			GameTooltip:AddLine(" ")
			GameTooltip:Show()
		end
		maxTooltipHeight = GameTooltip:GetHeight()
		for _, k in pairs(tooltipsInOrder) do
			k:SetHeight(maxTooltipHeight)
		end

	end

end



------------------------------------------------------------------------

BrokerPlayedTime.dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(L["Time Played"], {
	type = "data source",
	icon = [[Interface\Icons\Spell_Nature_TimeStop]],
	text = UNKNOWN,
	OnTooltipShow = OnTooltipShow,
	OnClick = function(self, button)
		if button == "RightButton" then
			GameTooltip:Hide()
			ToggleDropDownMenu(1, nil, BrokerPlayedTimeMenu, self, 0, 0, nil, nil, 15)
			if BrokerPlayedTimeMenu ~= UIDROPDOWNMENU_OPEN_MENU then
				self:GetScript("OnEnter")(self)
			end
		end
	end,
})

function BrokerPlayedTime:UpdateText()

	local timeToPrint = 0

	if db.brokerTextCurrentChar then
		timeToPrint = myDB.timePlayed + time() - myDB.timeUpdated
	else
		for _, realm in pairs(sortedRealms) do
			for _, faction in pairs(db[realm]) do
				for name, data in pairs(faction) do
					if data then

						local charTime = nil
						if realm == currentRealm and name == currentPlayer then
							charTime = data.timePlayed + time() - data.timeUpdated
						else
							charTime = data.timePlayed
						end

						timeToPrint = timeToPrint + charTime
					end
				end
			end
		end
	end
	self.dataObject.text = FormatTime(timeToPrint, timeToPrint > 3600)
end

do
	local updateDelay
	local function UpdateText()
		BrokerPlayedTime:UpdateText()
		C_Timer.After(updateDelay, UpdateText)
	end
	function BrokerPlayedTime:SetUpdateInterval(fast)
		local alreadyRunning = updateDelay
		updateDelay = fast and 30 or 300
		if not alreadyRunning then
			C_Timer.After(updateDelay, UpdateText)
		end
	end
end

------------------------------------------------------------------------
