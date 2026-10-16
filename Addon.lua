--[[--------------------------------------------------------------------
  Broker_PlayedTime
  DataBroker plugin to track played time across all your characters.
  Copyright (c) 2010-2016 Phanx
  Copyright (c) 2020-2026 Ludius Maximus
  Licensed under the MIT License (see LICENSE.txt for details).
  https://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
  https://www.curseforge.com/wow/addons/broker-playedtime
  https://github.com/LudiusMaximus/Broker_PlayedTime
----------------------------------------------------------------------]]

local ADDON, L = ...

local floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe = floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe

local db, myDB
local timePlayed, timePlayedLevel, timeUpdated = 0, 0, 0
local sortedFactions, sortedPlayers, sortedPlayersNoFactions, sortedRealms = { "Horde", "Alliance", "Neutral" }, {}, {}, {}

-- Only filled in at PLAYER_LOGIN, see InitCurrentCharacter().
local currentFaction, currentPlayer, currentRealm

local interfaceVersion = select(4, GetBuildInfo())

-- WoW Forever has no realms. See InitCurrentCharacter().
-- WOW_PROJECT_CAMELOT is only defined in Forever.
local isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- The realm keys we store for the Forever rulesets are the same in every locale, so the
-- saved variables do not depend on the client language. This is what we show instead,
-- using the names Blizzard gives the rulesets.
local rulesetNames = {
  PvE = L["Normal"],
  PvP = L["PvP"],
  RP = L["Roleplaying"],
  Hardcore = L["Hardcore"],
}

local function GetRealmDisplayName(realm)
  return isForever and rulesetNames[realm] or realm
end

-- Not before PLAYER_LOGIN, because the character is not reliably known before that.
-- WoW Forever for example returns "Unknown" for UnitName("player") at load time.
local function InitCurrentCharacter()

  currentFaction = UnitFactionGroup("player")
  currentPlayer = UnitName("player")
  currentRealm = GetRealmName()

  -- WoW Forever has no realms. All characters of an account share one world and
  -- GetRealmName() only returns the leftover name of whatever shard a character was
  -- migrated from. What actually keeps characters apart there is the game ruleset,
  -- so we use that as the realm key, just like AceDB-3.0 does.
  if isForever then
    if C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
      currentRealm = "Hardcore"
    elseif C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) then
      currentRealm = "RP"
    elseif C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) then
      currentRealm = "PvP"
    else
      currentRealm = "PvE"
    end

    -- Without realms, first names are no longer unique on WoW Forever, only first name
    -- and surname together are. UnitName() returns the surname where other clients
    -- return the realm. We join them the same way AceDB-3.0 does.
    local name, surname = UnitNameUnmodified("player")
    if surname and surname ~= "" then
      currentPlayer = name .. " " .. surname
    end
  end

  -- Must never be nil or empty, because it is used as a table key.
  if not currentRealm or currentRealm == "" then currentRealm = UNKNOWN end

end

-- An inline icon that is taller than a line of text makes its line taller than a blank
-- line, and then every height estimate comes out too low. How big an icon still fits
-- depends on the tooltip font, which other addons are free to replace, so the size is
-- measured rather than assumed; see MeasureMaxIconSize().
local textIconSize

local factionIcons = {}
local classIcons = {}

local function BuildIconStrings(iconSize)

  textIconSize = iconSize

  factionIcons[false] = {
    Alliance = "",
    Horde = "",
    Neutral = ""
  }
  factionIcons[true] = {
    Alliance = "|TInterface\\BattlefieldFrame\\Battleground-Alliance:" .. textIconSize .. ":" .. textIconSize .. ":0:0:32:32:4:26:4:27|t ",
    Horde = "|TInterface\\BattlefieldFrame\\Battleground-Horde:" .. textIconSize .. ":" .. textIconSize .. ":0:0:32:32:5:25:5:26|t ",
    Neutral = "",
  }
  factionIcons["set4"] = {
    Alliance = "|A:honorsystem-portrait-alliance:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
    Horde = "|A:honorsystem-portrait-horde:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
    Neutral = "|A:honorsystem-portrait-neutral:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
  }

  -- These atlases are in retail and WoW Forever, but not in the Classic clients.
  -- So we ask for them instead of deciding by the client.
  if C_Texture.GetAtlasInfo("AllianceSymbol") then
    factionIcons["set1"] = {
      Alliance = "|A:AllianceSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
      Horde = "|A:HordeSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
      Neutral = "|A:CrossedFlags:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    }
  end
  if C_Texture.GetAtlasInfo("nameplates-icon-flag-alliance") then
    factionIcons["set2"] = {
      Alliance = "|A:nameplates-icon-flag-alliance:" .. textIconSize .. ":" .. textIconSize .. "|a ",
      Horde = "|A:nameplates-icon-flag-horde:" .. textIconSize .. ":" .. textIconSize .. "|a ",
      Neutral = "|A:nameplates-icon-flag-neutral:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    }
  end
  if C_Texture.GetAtlasInfo("Warfronts-BaseMapIcons-Alliance-Armory") then
    factionIcons["set3"] = {
      Alliance = "|A:Warfronts-BaseMapIcons-Alliance-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
      Horde = "|A:Warfronts-BaseMapIcons-Horde-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
      Neutral = "|A:Warfronts-BaseMapIcons-Empty-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
    }
  end

  wipe(classIcons)
  for class, t in pairs(CLASS_ICON_TCOORDS) do
    local offset, left, right, bottom, top = 0.025, unpack(t)
    classIcons[class] = format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:" .. textIconSize .. ":" .. textIconSize .. ":0:0:256:256:%s:%s:%s:%s|t ", (left + offset) * 256, (right - offset) * 256, (bottom + offset) * 256, (top - offset) * 256)
  end

end

-- 13 fits Blizzard's default font. Only used until the first measurement has happened.
BuildIconStrings(13)

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
    if not t then return "|cffa8a8a8?|r" end

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


-- Earlier versions stored WoW Forever characters by first name only, so characters
-- with the same first name overwrote each other's entry. Whichever of them logs in
-- first takes the entry over. Its class, level and played time are replaced with the
-- real ones right away anyway.
local function MigrateForeverFirstNameOnly(savedVariables)
  if not isForever then return end

  local firstName = UnitNameUnmodified("player")
  if firstName == currentPlayer then return end

  local names = savedVariables[currentRealm] and savedVariables[currentRealm][currentFaction]
  if names and names[firstName] and not names[currentPlayer] then
    names[currentPlayer] = names[firstName]
    names[firstName] = nil
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

    if db.currentPlayerOnTop and currentlySortingRealm == currentRealm then
      if a == currentPlayer then
        return true
      elseif b == currentPlayer then
        return false
      end
    end

    -- Sort characters by played time.
    if db.sortByPlayedTime then
      local timePlayedA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].timePlayed
      local timePlayedB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].timePlayed
      return timePlayedA > timePlayedB
    -- Sort characters by level.
    elseif db.sortByLevel then
      local levelA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].level
      local levelB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].level
      -- If characters have the same level.
      if levelA == levelB then
        -- Sort characters by played time.
        if db.equalLevelSortByPlayedTime then
          local timePlayedA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].timePlayed
          local timePlayedB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].timePlayed
          return timePlayedA > timePlayedB
        -- Sort characters by played time level (if any).
        elseif db.equalLevelSortByPlayedTimeLevel then
          local timePlayedA = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][a]][a].timePlayedLevel or 0
          local timePlayedB = db[currentlySortingRealm][mapPlayerToFaction[currentlySortingRealm][b]][b].timePlayedLevel or 0
          return timePlayedA > timePlayedB
        -- Otherwise by name.
        else
          return a < b
        end
      else
        return levelA > levelB
      end
    -- Sort characters by name.
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
  if db.performedLevelSquish or interfaceVersion < 90000 then return end

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


-- Dedicated tooltip for measuring line height and icon size.
local measureTooltip = nil
local tooltipLineHeight = nil
-- https://warcraft.wiki.gg/wiki/API_GameTooltip_GetPadding only returned 0,0,0,0 for me, so I am getting the "padding" manually.
-- (The "padding" is the actual padding plus the difference between a normal tooltip line and the slightly greater title line.)
local tooltipTopBottomPadding = nil

-- Font size the current measurement was taken with, so we notice when another addon
-- swaps the tooltip font after we have already measured.
local measuredWithFontSize = nil

-- Turned on with "/brokerplayedtime debug". Only needed to diagnose user reports.
local debugLineHeight = false

local function DebugPrint(...)
  if debugLineHeight then print(ADDON, ...) end
end

local function GetTooltipFontSize()
  local _, fontSize = GameTooltipText:GetFont()
  return fontSize
end

-- Last resort if measuring a real tooltip does not give a plausible result.
-- A rough estimate still yields a usable multi-column layout, whereas giving up
-- forces a single column that runs off the screen.
local function EstimateTooltipMetricsFromFont()
  local fontSize = GetTooltipFontSize() or 12
  local _, headerFontSize = GameTooltipHeaderText:GetFont()
  headerFontSize = headerFontSize or 14
  -- A tooltip line is the font size plus roughly two pixels of line spacing.
  -- Blizzard's tooltips inset their text by roughly ten pixels at the top and at the bottom.
  return fontSize + 2, 20 + headerFontSize - fontSize
end

-- Number of normal lines in the small measuring tooltip, and how many more lines the
-- big one gets on top of that.
local MEASURE_BASE_LINES = 4
local MEASURE_SPAN = 20

-- Rebuild the measuring tooltip with a title line plus numLines normal lines and return
-- its height. linePrefix is put in front of every normal line.
local function MeasureTooltipHeight(numLines, linePrefix)

  if not measureTooltip then
    measureTooltip = CreateFrame("GameTooltip", ADDON .. "_MeasureTooltip", UIParent, "SharedTooltipTemplate")
  else
    measureTooltip:ClearLines()
  end

  measureTooltip:SetOwner(UIParent, "ANCHOR_TOPLEFT")

  -- The first line uses the slightly greater title font, all others are normal lines.
  measureTooltip:AddLine("Title")
  for _ = 1, numLines do
    measureTooltip:AddLine((linePrefix or "") .. "Line")
  end
  measureTooltip:Show()
  local height = measureTooltip:GetHeight()
  measureTooltip:Hide()

  return height
end

-- Biggest inline icon that still leaves its line as tall as a plain line of text.
-- A line can only grow with the icon in it, never shrink, so this is monotonic and we
-- can binary search it. plainHeight is MeasureTooltipHeight(MEASURE_BASE_LINES) without
-- a prefix. If not even MIN_ICON_SIZE fits, that is what we return and live with.
local MIN_ICON_SIZE, MAX_ICON_SIZE = 6, 32

local function MeasureMaxIconSize(plainHeight)

  local low, high = MIN_ICON_SIZE, MAX_ICON_SIZE

  while low < high do
    local size = ceil((low + high) / 2)
    local probe = format("|TInterface\\CHATFRAME\\ChatFrameExpandArrow:%d:%d|t ", size, size)
    -- Tolerance, because GetHeight() comes back through float32.
    if MeasureTooltipHeight(MEASURE_BASE_LINES, probe) - plainHeight < 0.5 then
      low = size
    else
      high = size - 1
    end
  end

  return low
end

-- How far our estimate for the real tooltip was off last time. See VerifyHeightEstimate().
local estimateCorrection = 1

-- An addon that swaps the tooltip font back and forth would otherwise have us measuring
-- again on every single hover.
local MIN_REMEASURE_INTERVAL = 5
local lastMeasureTime = 0

-- We take the slope over a wide span of lines instead of comparing two adjacent heights.
-- That divides the rounding error of every individual GetHeight() by the number of lines
-- and it stays correct even if something clamps the minimum height of a short tooltip.
local function GetTooltipLineHeight()

  -- tooltipHeightA == padding + titleLine + MEASURE_BASE_LINES * lineHeight
  local tooltipHeightA = MeasureTooltipHeight(MEASURE_BASE_LINES)
  -- tooltipHeightB == the same plus MEASURE_SPAN more lines
  local tooltipHeightB = MeasureTooltipHeight(MEASURE_BASE_LINES + MEASURE_SPAN)

  local lineHeight = (tooltipHeightB - tooltipHeightA) / MEASURE_SPAN

  -- Plausibility check instead of an exact comparison. GetHeight() comes back through
  -- float32, so any height that is not exactly representable is off by a few millionths.
  -- Anything stricter than this rejects perfectly good measurements for everybody whose
  -- tooltip font is not a whole number of pixels high.
  if lineHeight > 5 and lineHeight < 60 then
    tooltipLineHeight = lineHeight
    tooltipTopBottomPadding = tooltipHeightA - (MEASURE_BASE_LINES + 1) * lineHeight
  else
    tooltipLineHeight, tooltipTopBottomPadding = EstimateTooltipMetricsFromFont()
    DebugPrint("implausible measurement", tooltipHeightA, tooltipHeightB, lineHeight, "- estimating instead")
  end

  measuredWithFontSize = GetTooltipFontSize()
  lastMeasureTime = GetTime()

  -- Whatever we learned about the real tooltip was learned for the old metrics.
  estimateCorrection = 1

  BuildIconStrings(MeasureMaxIconSize(tooltipHeightA))

  DebugPrint("line height", tooltipLineHeight, "padding", tooltipTopBottomPadding, "icon size", textIconSize)

end

-- Measure on demand instead of once at login: the layout is not necessarily settled at
-- PLAYER_LOGIN, and other addons may only install their tooltip font after we have loaded.
local function EnsureTooltipLineHeight()
  if not tooltipLineHeight then
    GetTooltipLineHeight()
  elseif measuredWithFontSize ~= GetTooltipFontSize()
     and GetTime() - lastMeasureTime > MIN_REMEASURE_INTERVAL then
    GetTooltipLineHeight()
  end
end

-- We measure a tooltip of our own, but we draw into whichever tooltip the display addon
-- hands us. A skin that only styles the tooltips it knows by name makes the two disagree,
-- and if the real one has taller lines than ours, we underestimate and the single column
-- runs off the screen. So one frame after a single column tooltip, look at what its height
-- really turned out to be and carry the correction into the next estimate.
local function VerifyHeightEstimate(tooltip, shownNumLines)

  C_Timer.After(0, function()

    if not tooltip:IsShown() then return DebugPrint("no correction: tooltip already gone") end

    local numLines = tooltip:NumLines()
    local realHeight = tooltip:GetHeight()

    -- GetHeight() is a secret value while the tooltip belongs to a secure call. That
    -- should not be the case a frame later, but doing arithmetic on one would throw.
    if issecretvalue and (issecretvalue(numLines) or issecretvalue(realHeight)) then
      return DebugPrint("no correction: tooltip height is a secret value")
    end

    -- Another addon may have added lines after us. Then the height says nothing about
    -- our own error, so there is nothing to be learned from it.
    if numLines ~= shownNumLines then
      return DebugPrint(format("no correction: tooltip has %d lines instead of %d", numLines, shownNumLines))
    end
    if not realHeight or realHeight <= 0 then
      return DebugPrint("no correction: tooltip has no height")
    end

    local predictedHeight = tooltipTopBottomPadding + shownNumLines * tooltipLineHeight
    if predictedHeight <= 0 then return DebugPrint("no correction: nothing predicted") end

    local correction = realHeight / predictedHeight

    -- Only believe plausible corrections. Anything beyond this is not a line height
    -- mismatch but something else going on that we should not bake in.
    if correction > 0.5 and correction < 2 then
      estimateCorrection = correction
      DebugPrint(format("%d lines predicted %.1f, really %.1f, correction %.4f", numLines, predictedHeight, realHeight, correction))
    else
      DebugPrint(format("no correction: %d lines predicted %.1f but really %.1f", numLines, predictedHeight, realHeight))
    end

  end)
end

------------------------------------------------------------------------
-- Slash command. Only there to diagnose tooltip layout problems.

SLASH_BROKERPLAYEDTIME1 = "/brokerplayedtime"
SLASH_BROKERPLAYEDTIME2 = "/bpt"
SlashCmdList["BROKERPLAYEDTIME"] = function(msg)

  msg = string.lower(msg or "")
  msg = string.match(msg, "^%s*(.-)%s*$")

  if msg == "debug" or msg == "debug on" then
    debugLineHeight = true
    print(ADDON, "debug output on. Now open the Played Time tooltip to see how it is laid out.")
    GetTooltipLineHeight()
  elseif msg == "debug off" then
    debugLineHeight = false
    print(ADDON, "debug output off.")
  else
    print(ADDON, "usage: /brokerplayedtime debug [on|off]")
  end

end


------------------------------------------------------------------------
-- Multi-column tooltip using a persistent frame with font string pooling.
------------------------------------------------------------------------

-- The custom frame for multi-column display.
local multiColumnFrame = nil

-- Font string pool: array of { left = FontString, right = FontString }.
local fontStringPool = {}
local fontStringPoolSize = 0
local fontStringPoolActive = 0

local function InitMultiColumnFrame()
  if multiColumnFrame then return end
  multiColumnFrame = CreateFrame("Frame", ADDON .. "_MultiColumnFrame", UIParent, "TooltipBackdropTemplate")
  multiColumnFrame:SetFrameStrata("TOOLTIP")
  multiColumnFrame:SetClampedToScreen(true)
  multiColumnFrame:Hide()

  -- If ElvUI is loaded and its tooltip skin is enabled, match the ElvUI tooltip style.
  if C_AddOns.IsAddOnLoaded("ElvUI") then
    local E = unpack(ElvUI or {})
    if E and E.private and E.private.skins
        and E.private.skins.blizzard
        and E.private.skins.blizzard.enable
        and E.private.skins.blizzard.tooltip
        and multiColumnFrame.SetTemplate then
      if multiColumnFrame.NineSlice then
        multiColumnFrame.NineSlice:SetAlpha(0)
      end
      local TT = E:GetModule("Tooltip", true)
      if TT and TT.db then
        multiColumnFrame.customBackdropAlpha = TT.db.colorAlpha
      end
      multiColumnFrame:SetTemplate("Transparent")
    end
  end
end

local titleFont = nil
local function GetTitleFont()
  if not titleFont then
    titleFont = CreateFont(ADDON .. "_TitleFont")
    titleFont:CopyFontObject(GameTooltipHeaderText)
    local path, size, flags = titleFont:GetFont()
    titleFont:SetFont(path, size + 2, flags)
  end
  return titleFont
end

local function AcquireFontStringPair()
  fontStringPoolActive = fontStringPoolActive + 1
  if fontStringPoolActive > fontStringPoolSize then
    fontStringPoolSize = fontStringPoolActive
    local left = multiColumnFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    local right = multiColumnFrame:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    left:SetJustifyH("LEFT")
    right:SetJustifyH("RIGHT")
    fontStringPool[fontStringPoolSize] = { left = left, right = right }
  end
  local pair = fontStringPool[fontStringPoolActive]
  pair.left:Show()
  pair.right:Show()
  return pair.left, pair.right
end

local function ReleaseAllFontStrings()
  for i = 1, fontStringPoolActive do
    fontStringPool[i].left:Hide()
    fontStringPool[i].left:ClearAllPoints()
    fontStringPool[i].right:Hide()
    fontStringPool[i].right:ClearAllPoints()
  end
  fontStringPoolActive = 0
end

local function HideMultiColumnFrame()
  if multiColumnFrame and multiColumnFrame:IsShown() then
    ReleaseAllFontStrings()
    multiColumnFrame:Hide()
  end
end

-- Line collector: a "virtual tooltip" that captures AddLine/AddDoubleLine calls.
-- The optional `kind` parameter tags special lines: "title", "realm", "total".
-- `currentRealm` is a mutable field the caller sets (and later clears) around each
-- group of character lines, before adding the realm title. The realm title and every
-- DoubleLine added while it is set inherit the realm key as a `realm` field on their
-- entry. ShowMultiColumnFrame reads those fields to identify contiguous realm blocks
-- and uses them for the column-balancing algorithm (avoiding orphan groups at column
-- boundaries).
local function CreateLineCollector()
  return {
    lines = {},
    currentRealm = nil,
    AddLine = function(self, text, r, g, b, kind)
      tinsert(self.lines, { leftText = text, leftR = r, leftG = g, leftB = b, kind = kind, realm = (kind == "realm") and self.currentRealm or nil })
    end,
    AddDoubleLine = function(self, lText, rText, lr, lg, lb, rr, rg, rb, kind)
      tinsert(self.lines, { leftText = lText, rightText = rText, leftR = lr, leftG = lg, leftB = lb, rightR = rr, rightG = rg, rightB = rb, kind = kind, realm = (not kind) and self.currentRealm or nil })
    end,
  }
end

-- Display collected lines in a multi-column frame anchored to the given tooltip.
local function ShowMultiColumnFrame(tooltip, collectedLines, numColumns)
  InitMultiColumnFrame()
  ReleaseAllFontStrings()

  local numLines = #collectedLines
  local linesPerColumn = ceil(numLines / numColumns)

  -- Spacing constants.
  local LINE_SPACING = 1        -- extra pixels between every line
  local REALM_EXTRA_SPACING = 3 -- additional pixels after a realm or total header

  -- Compute column ranges, balancing realm character blocks.
  -- Rule: if a column boundary splits a realm with >6 chars such that
  -- either side has <3 chars, move those chars to the other column.
  -- If the result would exceed 90% screen height, revert to even distribution.
  local columnRanges = {}
  do
    -- Identify contiguous realm blocks (realm title + character lines).
    local realmBlocks = {}
    local lineToBlock = {}
    local currentBlock = nil
    for i, line in ipairs(collectedLines) do
      if line.kind == "realm" then
        -- Start a new block with the realm title line.
        -- count only tracks character lines (not the title itself).
        currentBlock = { startIdx = i, endIdx = i, count = 0, realm = line.realm }
        tinsert(realmBlocks, currentBlock)
        lineToBlock[i] = #realmBlocks
      elseif line.realm then
        if currentBlock and currentBlock.realm == line.realm then
          currentBlock.endIdx = i
          currentBlock.count = currentBlock.count + 1
        else
          currentBlock = { startIdx = i, endIdx = i, count = 1, realm = line.realm }
          tinsert(realmBlocks, currentBlock)
        end
        lineToBlock[i] = #realmBlocks
      else
        currentBlock = nil
      end
    end

    -- Initial split points (last line index of each column, except the last).
    local splits = {}
    for col = 1, numColumns - 1 do
      splits[col] = min(col * linesPerColumn, numLines)
    end

    -- Adjust splits to avoid orphan groups (<3 chars at a column boundary).
    for s = 1, #splits do
      local splitIdx = splits[s]
      local blockIdx = lineToBlock[splitIdx]
      if blockIdx then
        local block = realmBlocks[blockIdx]
        if block.count > 6 then
          local beforeCount = splitIdx - block.startIdx + 1
          local afterCount = block.endIdx - splitIdx
          if beforeCount < 3 and block.startIdx > 1 then
            splits[s] = block.startIdx - 1
          elseif afterCount > 0 and afterCount < 3 then
            splits[s] = block.endIdx
          end
        end
      end
    end

    -- Ensure splits remain sorted and within bounds.
    for s = 1, #splits do
      if splits[s] < 1 then splits[s] = 1 end
      if splits[s] >= numLines then splits[s] = numLines - 1 end
      if s > 1 and splits[s] <= splits[s-1] then splits[s] = splits[s-1] + 1 end
    end

    -- Build column ranges.
    local prevEnd = 0
    for s = 1, #splits do
      tinsert(columnRanges, { startIdx = prevEnd + 1, endIdx = splits[s] })
      prevEnd = splits[s]
    end
    tinsert(columnRanges, { startIdx = prevEnd + 1, endIdx = numLines })

    -- If the tallest column would exceed 90% screen height, revert to even distribution.
    local maxLines = 0
    for _, r in ipairs(columnRanges) do
      local count = r.endIdx - r.startIdx + 1
      if count > maxLines then maxLines = count end
    end
    if maxLines * tooltipLineHeight > 0.9 * UIParent:GetHeight() then
      columnRanges = {}
      for col = 1, numColumns do
        local s = (col - 1) * linesPerColumn + 1
        local e = min(col * linesPerColumn, numLines)
        tinsert(columnRanges, { startIdx = s, endIdx = e })
      end
    end
  end

  -- Phase 1: Create font strings, set text, measure widths.
  -- Only "content" lines (those with right-side text) are measured for column sizing;
  -- this excludes the title, subtitle, spacers, and realm/total headers.
  local columns = {}
  for col = 1, numColumns do
    columns[col] = { pairs = {}, maxLeftWidth = 0, maxRightWidth = 0 }

    for idx = columnRanges[col].startIdx, columnRanges[col].endIdx do
      local lineData = collectedLines[idx]
      local leftFS, rightFS = AcquireFontStringPair()

      -- Title uses an extra-large font. Realm/total use header font. All get NORMAL_FONT_COLOR.
      if lineData.kind == "title" then
        leftFS:SetFontObject(GetTitleFont())
        rightFS:SetFontObject(GetTitleFont())
        leftFS:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        rightFS:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
      elseif lineData.kind == "realm" or lineData.kind == "total" then
        leftFS:SetFontObject(GameTooltipHeaderText)
        rightFS:SetFontObject(GameTooltipHeaderText)
        leftFS:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        rightFS:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
      else
        leftFS:SetFontObject(GameTooltipText)
        rightFS:SetFontObject(GameTooltipText)
      end

      leftFS:SetText(lineData.leftText or "")
      rightFS:SetText(lineData.rightText or "")

      -- Override colors when explicit values were provided by the caller.
      if lineData.leftR then
        leftFS:SetTextColor(lineData.leftR, lineData.leftG, lineData.leftB)
      end
      if lineData.rightR then
        rightFS:SetTextColor(lineData.rightR, lineData.rightG, lineData.rightB)
      end

      -- Only content lines (with right-side text, but not the "total" header)
      -- contribute to column width, since they represent the actual data rows.
      if lineData.rightText and lineData.kind ~= "total" then
        local lw = leftFS:GetUnboundedStringWidth()
        local rw = rightFS:GetUnboundedStringWidth()
        if lw > columns[col].maxLeftWidth then columns[col].maxLeftWidth = lw end
        if rw > columns[col].maxRightWidth then columns[col].maxRightWidth = rw end
      end

      tinsert(columns[col].pairs, { left = leftFS, right = rightFS, kind = lineData.kind })
    end
  end

  -- Phase 2: Calculate frame dimensions using global max left/right widths.
  local PADDING_H = 14
  local PADDING_V = tooltipTopBottomPadding or 14
  local COLUMN_GAP = 34
  local TEXT_GAP = 12   -- gap between left and right text within a column

  local globalMaxLeftWidth = 0
  local globalMaxRightWidth = 0
  for col = 1, numColumns do
    if columns[col].maxLeftWidth > globalMaxLeftWidth then globalMaxLeftWidth = columns[col].maxLeftWidth end
    if columns[col].maxRightWidth > globalMaxRightWidth then globalMaxRightWidth = columns[col].maxRightWidth end
  end
  local colWidth = globalMaxLeftWidth + TEXT_GAP + globalMaxRightWidth
  local totalWidth = PADDING_H * 2 + colWidth * numColumns + COLUMN_GAP * (numColumns - 1)

  -- Compute tallest column height, accounting for per-line and post-realm spacing.
  local maxColHeight = 0
  for col = 1, numColumns do
    local h = 0
    for _, pair in ipairs(columns[col].pairs) do
      h = h + tooltipLineHeight + LINE_SPACING
      if pair.kind == "realm" or pair.kind == "title" then h = h + REALM_EXTRA_SPACING end
    end
    if h > maxColHeight then maxColHeight = h end
  end
  local totalHeight = PADDING_V + maxColHeight

  -- Phase 3: Position all font strings using accumulated y-offsets.
  local x = PADDING_H
  for col = 1, numColumns do
    local yOffset = -(PADDING_V / 2)
    for _, pair in ipairs(columns[col].pairs) do
      pair.left:SetPoint("TOPLEFT", multiColumnFrame, "TOPLEFT", x, yOffset)
      pair.right:SetPoint("TOPRIGHT", multiColumnFrame, "TOPLEFT", x + colWidth, yOffset)
      yOffset = yOffset - (tooltipLineHeight + LINE_SPACING)
      if pair.kind == "realm" or pair.kind == "title" then yOffset = yOffset - REALM_EXTRA_SPACING end
    end
    x = x + colWidth + COLUMN_GAP
  end

  -- Phase 4: Size and anchor the frame.
  multiColumnFrame:SetSize(totalWidth, totalHeight)
  multiColumnFrame:ClearAllPoints()

  -- Anchor based on cursor position (left half → extend right, right half → extend left).
  if UIParent:GetWidth() * UIParent:GetEffectiveScale() / GetCursorPosition() > 2 then
    multiColumnFrame:SetPoint("TOPLEFT", tooltip, "TOPLEFT")
  else
    multiColumnFrame:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT")
  end

  multiColumnFrame:SetFrameLevel(tooltip:GetFrameLevel() + 10)

  -- If ElvUI-skinned, update backdrop alpha to match the current tooltip opacity setting.
  if multiColumnFrame.template == "Transparent" and ElvUI then
    local E = unpack(ElvUI)
    if E then
      local TT = E:GetModule("Tooltip", true)
      if TT and TT.db then
        local r, g, b = multiColumnFrame:GetBackdropColor()
        multiColumnFrame:SetBackdropColor(r, g, b, TT.db.colorAlpha)
      end
    end
  end

  multiColumnFrame:Show()

  -- Hook tooltip OnHide to hide our frame.
  if not tooltip.BrokerPlayedTime_hooked then
    tooltip:HookScript("OnHide", HideMultiColumnFrame)
    tooltip.BrokerPlayedTime_hooked = true
  end

  -- Keep the original tooltip minimal (one blank line so it stays shown by the host).
  tooltip:AddLine(" ")
end

------------------------------------------------------------------------

local BrokerPlayedTime = CreateFrame("Frame")
BrokerPlayedTime:SetScript("OnEvent", function(self, event, ...)
  if self[event] then
    self[event](self, ...)
  else
    self:SaveTimePlayed()
  end
end)
BrokerPlayedTime:RegisterEvent("PLAYER_LOGIN")

function BrokerPlayedTime:PLAYER_LOGIN()

  InitCurrentCharacter()

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

    equalLevelSortByPlayedTime = false,
    equalLevelSortByPlayedTimeLevel = true,

    levels = false,
    showPlayedTimeLevel = false,
    classIcons = false,
    factionIcons = false,

    groupByFactions = true,
    onlyCurrentRealm = false,
    currentPlayerOnTop = true,
    highlightCurrentPlayer = false,

    onlyHours = false,
    alwaysShowMinutes = true,

    brokerTextCurrentChar = true,

    [currentRealm] = {
      [currentFaction] = {
        [currentPlayer] = {
          class = (select(2, UnitClass("player"))),
          level = UnitLevel("player"),
          timePlayed = 0,
          timePlayedLevel = 0,
          timeUpdated = 0,
        },
      }
    }
  }

  BrokerPlayedTimeDB = BrokerPlayedTimeDB or {}
  -- Before copyTable() creates an empty entry for the full name.
  MigrateForeverFirstNameOnly(BrokerPlayedTimeDB)
  db = copyTable(defaults, BrokerPlayedTimeDB)

  -- Sets 1 to 3 of the faction icons are only built where their atlases exist (see
  -- BuildIconStrings()), which the Classic clients do not have. So if the saved
  -- variables were copied over from another client's WTF folder, the chosen set might
  -- not exist here, and the tooltip would raise a Lua error when indexing it. In that
  -- case, fall back to the Battleground icons, which every client has. "None" is the
  -- key false, which does exist, hence comparing with nil.
  if factionIcons[db.factionIcons] == nil then
    db.factionIcons = true
  end

  RemoveDuplicates()

  -- Before we store the current level below, which is already a squished one.
  PerformLevelSquish()

  myDB = db[currentRealm][currentFaction][currentPlayer]

  -- Needed if you deleted and recreated a character with the same name but different class.
  myDB.class = (select(2, UnitClass("player")))
  -- Needed for deletion/recreation and for level boost (no PLAYER_LEVEL_UP event).
  myDB.level = UnitLevel("player")

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

  self:UpdateTimePlayed()

end

local requesting

-- Suppress the chat message for the played time we request ourselves.
-- (Every game version we support has ChatFrameUtil.DisplayTimePlayed now.)
local originalDisplayTimePlayed = ChatFrameUtil.DisplayTimePlayed
function ChatFrameUtil.DisplayTimePlayed(chatFrame, totalTime, levelTime)
  if requesting then
    requesting = false
    return
  end
  return originalDisplayTimePlayed(chatFrame, totalTime, levelTime)
end

function BrokerPlayedTime:UpdateTimePlayed()
  requesting = true
  RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
  -- Before the first TIME_PLAYED_MSG we do not know the played time yet, and saving
  -- would store the seconds since 1970 instead.
  if timeUpdated == 0 then return end

  local now = time()
  myDB.timePlayed = timePlayed + now - timeUpdated
  myDB.timePlayedLevel = timePlayedLevel + now - timeUpdated
  myDB.timeUpdated = now

  BuildSortedLists()
  self:UpdateText()
  self:SetUpdateInterval(timePlayed < 3600)
end

function BrokerPlayedTime:PLAYER_LEVEL_UP(level)
  myDB.level = level or UnitLevel("player")
  self:SaveTimePlayed()
  -- The time on this level starts over now, but we only learn that when we ask.
  self:UpdateTimePlayed()
end

function BrokerPlayedTime:TIME_PLAYED_MSG(t, l)
  timePlayed, timePlayedLevel = t, l
  timeUpdated = time()
  self:SaveTimePlayed()
end

------------------------------------------------------------------------

local function OpenMenu()
  MenuUtil.CreateContextMenu(UIParent, function(button, mainMenu)
    mainMenu:CreateTitle(L["Played Time"])
    mainMenu:CreateDivider()

    -- ===== SORTING =====
    local sortingSubmenu = mainMenu:CreateButton(L["Sorting"])
    sortingSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

    sortingSubmenu:CreateRadio(L["By played time"],
      function() return db.sortByPlayedTime end,
      function()
        db.sortByPlayedTime = true
        db.sortByLevel = false
        BuildSortedLists()
        return MenuResponse.Refresh
      end)

    sortingSubmenu:CreateRadio(L["By character name"],
      function() return not db.sortByPlayedTime and not db.sortByLevel end,
      function()
        db.sortByPlayedTime = false
        db.sortByLevel = false
        BuildSortedLists()
        return MenuResponse.Refresh
      end)

    sortingSubmenu:CreateRadio(L["By character level"],
      function() return db.sortByLevel end,
      function()
        db.sortByPlayedTime = false
        db.sortByLevel = true
        BuildSortedLists()
        return MenuResponse.Refresh
      end)

    -- Nested: Sorting of equal levels
    if db.sortByLevel then
      local equalLevelSubmenu = sortingSubmenu:CreateButton(L["Sorting of equal levels"])
      equalLevelSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

      equalLevelSubmenu:CreateRadio(L["By played time this level"],
        function() return db.equalLevelSortByPlayedTimeLevel end,
        function()
          db.equalLevelSortByPlayedTime = false
          db.equalLevelSortByPlayedTimeLevel = true
          BuildSortedLists()
          return MenuResponse.Refresh
        end)

      equalLevelSubmenu:CreateRadio(L["By played time"],
        function() return db.equalLevelSortByPlayedTime end,
        function()
          db.equalLevelSortByPlayedTime = true
          db.equalLevelSortByPlayedTimeLevel = false
          BuildSortedLists()
          return MenuResponse.Refresh
        end)

      equalLevelSubmenu:CreateRadio(L["By character name"],
        function() return not db.equalLevelSortByPlayedTime and not db.equalLevelSortByPlayedTimeLevel end,
        function()
          db.equalLevelSortByPlayedTime = false
          db.equalLevelSortByPlayedTimeLevel = false
          BuildSortedLists()
          return MenuResponse.Refresh
        end)
    end

    mainMenu:CreateDivider()

    -- ===== DISPLAY OPTIONS =====
    mainMenu:CreateCheckbox(L["Show character levels"],
      function() return db.levels end,
      function()
        db.levels = not db.levels
      end)

    mainMenu:CreateCheckbox(L["Show played time this level"],
      function() return db.showPlayedTimeLevel end,
      function()
        db.showPlayedTimeLevel = not db.showPlayedTimeLevel
      end,
      function() return not db.levels end)

    mainMenu:CreateCheckbox(L["Show class icons"],
      function() return db.classIcons end,
      function()
        db.classIcons = not db.classIcons
      end)

    -- ===== FACTION ICONS =====
    local factionIconsSubmenu = mainMenu:CreateButton(L["Show faction icons"])
    factionIconsSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

    for k, v in pairs(factionIcons) do
      local iconLabel
      if k == false then
        iconLabel = L["None"]
      else
        iconLabel = v["Alliance"] .. " " .. v["Horde"] .. " " .. v["Neutral"]
      end

      factionIconsSubmenu:CreateRadio(iconLabel,
        function() return db.factionIcons == k end,
        function()
          db.factionIcons = k
          return MenuResponse.Refresh
        end)
    end

    mainMenu:CreateDivider()

    -- ===== GROUP & FILTER OPTIONS =====
    mainMenu:CreateCheckbox(L["Group by factions"],
      function() return db.groupByFactions end,
      function()
        db.groupByFactions = not db.groupByFactions
      end)

    mainMenu:CreateCheckbox(isForever and L["Current ruleset only"] or L["Current realm only"],
      function() return db.onlyCurrentRealm end,
      function()
        db.onlyCurrentRealm = not db.onlyCurrentRealm
        BuildSortedLists()
        BrokerPlayedTime:UpdateText()
      end)

    mainMenu:CreateCheckbox(L["Current character on top"],
      function() return db.currentPlayerOnTop end,
      function()
        db.currentPlayerOnTop = not db.currentPlayerOnTop
        BuildSortedLists()
      end)

    mainMenu:CreateCheckbox(L["Current character highlighted"],
      function() return db.highlightCurrentPlayer end,
      function()
        db.highlightCurrentPlayer = not db.highlightCurrentPlayer
      end)

    mainMenu:CreateDivider()

    -- ===== TIME FORMAT OPTIONS =====
    mainMenu:CreateCheckbox(L["Time in hours (not days)"],
      function() return db.onlyHours end,
      function()
        db.onlyHours = not db.onlyHours
        BrokerPlayedTime:UpdateText()
      end)

    mainMenu:CreateCheckbox(L["Always show minutes also"],
      function() return db.alwaysShowMinutes end,
      function()
        db.alwaysShowMinutes = not db.alwaysShowMinutes
        BrokerPlayedTime:UpdateText()
        BrokerPlayedTime:SetUpdateInterval(timePlayed < 3600)
      end)

    mainMenu:CreateDivider()

    -- ===== REMOVE CHARACTER =====
    local removeCharSubmenu = mainMenu:CreateButton(L["Remove character"])
    removeCharSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

    for _, realm in ipairs(sortedRealms) do
      local realmSubmenu = removeCharSubmenu:CreateButton(GetRealmDisplayName(realm))
      realmSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

      for _, faction in ipairs(sortedFactions) do
        -- Only show factions that have characters on this realm
        if sortedPlayers[realm] and sortedPlayers[realm][faction] and #sortedPlayers[realm][faction] > 0 then
          -- Faction title
          realmSubmenu:CreateTitle(faction)

          -- Character list (indented with radio buttons)
          for _, name in ipairs(sortedPlayers[realm][faction]) do
            local cdata = db[realm][faction][name]
            local disableRemove = (name == currentPlayer and realm == currentRealm)

            realmSubmenu:CreateRadio(
              format("%s%s",
                CLASS_COLORS[cdata and cdata.class or "UNKNOWN"],
                name),
              function() return false end, -- Never selected
              function()
                db[realm][faction][name] = nil
                if not next(db[realm][faction]) then
                  db[realm][faction] = nil
                end
                if not next(db[realm]) then
                  db[realm] = nil
                end

                BuildMapPlayerToFaction()
                BuildSortedLists()
                BrokerPlayedTime:UpdateText()
              end
            ):SetEnabled(not disableRemove)
          end
        end
      end
    end


    -- ===== BROKER TEXT OPTIONS =====
    if not (TimeManagerClockButton and TimeManagerClockButton:IsMouseOver()) then
      mainMenu:CreateDivider()

      local brokerTextSubmenu = mainMenu:CreateButton(L["Broker icon text"])
      brokerTextSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

      brokerTextSubmenu:CreateRadio(L["Current character time"],
        function() return db.brokerTextCurrentChar end,
        function()
          db.brokerTextCurrentChar = true
          BrokerPlayedTime:UpdateText()
          return MenuResponse.Refresh
        end)

      brokerTextSubmenu:CreateRadio(L["Total time"],
        function() return not db.brokerTextCurrentChar end,
        function()
          db.brokerTextCurrentChar = false
          BrokerPlayedTime:UpdateText()
          return MenuResponse.Refresh
        end)

    end

  end)
end




local function AddPlayerLines(tooltip, realm, names)
  if not names then return 0 end

  local totalTime = 0

  for _, name in ipairs(names) do
    local data = db[realm][mapPlayerToFaction[realm][name]][name]
    if data then

      local charTime, charTimeLevel = nil, nil

      if realm == currentRealm and name == currentPlayer then
        local now = time()
        charTime = data.timePlayed + now - data.timeUpdated
        charTimeLevel = data.timePlayedLevel + now - data.timeUpdated
      else
        charTime, charTimeLevel = data.timePlayed, data.timePlayedLevel
      end

      if charTime and charTime > 0 then
        tooltip:AddDoubleLine(
          format("%s%s%s%s%s%s|r",
            factionIcons[db.factionIcons][mapPlayerToFaction[realm][name]],
            db.classIcons and classIcons[data.class] or "",
            CLASS_COLORS[data.class] or CLASS_COLORS["UNKNOWN"],
            (db.highlightCurrentPlayer and realm == currentRealm and name == currentPlayer) and "|TInterface\\CHATFRAME\\ChatFrameExpandArrow:" .. textIconSize .. "|t" or "",
            name,
            db.levels and (" (" .. data.level .. (db.showPlayedTimeLevel and (": " .. FormatTime(charTimeLevel, not db.alwaysShowMinutes)) or "") .. ")") or ""
          ),
          FormatTime(charTime, not db.alwaysShowMinutes)
        )

        totalTime = totalTime + charTime
      end

    end
  end

  return totalTime
end




local function OnTooltipShow(tooltip)

  EnsureTooltipLineHeight()

  -- Estimate how many columns we need.
  -- NOTE: Do NOT call tooltip:Show() / tooltip:GetHeight() here. When this hook fires
  -- inside TimeManagerClockButton_UpdateTooltip (a C-level secure call), GetHeight()
  -- returns a tainted "secret" number that cannot be used in arithmetic.
  -- Instead, compute the initial height from our own measurements.
  -- (VerifyHeightEstimate() does read the real height, but a frame later and outside
  -- of the secure call, where it is an ordinary number again.)
  local initialNumLines = tooltip:NumLines()
  local tooltipInitialHeight = tooltipTopBottomPadding + initialNumLines * tooltipLineHeight


  local lineCounter = 0
  lineCounter = lineCounter + 1             -- tooltip:AddLine(L["Played Time"])
  lineCounter = lineCounter + 1             -- tooltip:AddLine(L["Right click for options"])

  for _, realm in ipairs(sortedRealms) do
    lineCounter = lineCounter + 1          -- tooltip:AddLine(" ")
    if #sortedRealms > 1 then
      lineCounter = lineCounter + 1         -- tooltip:AddLine(realm)
    end

    if db.groupByFactions then
      for _, faction in ipairs(sortedFactions) do
        -- Not every realm has every faction.
        if sortedPlayers[realm][faction] then
          lineCounter = lineCounter + #sortedPlayers[realm][faction]      -- AddPlayerLines(tooltip, realm, sortedPlayers[realm][faction])
        end
      end
    else
      lineCounter = lineCounter + #sortedPlayersNoFactions[realm]        -- AddPlayerLines(tooltip, realm, sortedPlayersNoFactions[realm])
    end

  end

  lineCounter = lineCounter + 1         -- tooltip:AddLine(" ")
  lineCounter = lineCounter + 1         -- tooltip:AddDoubleLine(L["Total"], FormatTime(total))



  local estimatedHeight = (tooltipInitialHeight + lineCounter*tooltipLineHeight) * estimateCorrection
  local allowedHeight = 0.7 * UIParent:GetHeight()

  local numColumns = 1
  if estimatedHeight > allowedHeight then
    numColumns = ceil(estimatedHeight / allowedHeight)
  end

  DebugPrint(format("%d lines (%d already there) estimated at %.1f, allowed %.1f, using %d column(s)",
                    initialNumLines + lineCounter, initialNumLines, estimatedHeight, allowedHeight, numColumns))


  -- One tooltip is enough.
  if numColumns == 1 then
    local totalTime = 0
    tooltip:AddLine(L["Played Time"])
    tooltip:AddLine("|cffa8a8a8(" .. L["Right click for options"] .. ")|r")
    for _, realm in ipairs(sortedRealms) do
      tooltip:AddLine(" ")
      if #sortedRealms > 1 then
        tooltip:AddLine(GetRealmDisplayName(realm))
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
    tooltip:AddDoubleLine(L["Total"], FormatTime(totalTime, not db.alwaysShowMinutes))

    tooltip:Show()

    -- AddPlayerLines() skips characters without played time, so the number of lines we
    -- counted for the estimate is an upper bound. Learn from what is actually there.
    VerifyHeightEstimate(tooltip, tooltip:NumLines())


  -- #########################################################################
  -- We need several columns. Use custom multi-column frame.
  else

    -- Collect all lines into a virtual tooltip.
    local collector = CreateLineCollector()

    -- If the host tooltip already had content (e.g. minimap clock), copy it first
    -- so it stays at the top, before our title and character data.
    -- The first line gets GameTooltipHeaderText font, matching its role as a header.
    if initialNumLines > 0 then
      local tooltipName = tooltip:GetName()
      for i = 1, initialNumLines do
        local lText = _G[tooltipName .. "TextLeft" .. i]:GetText()
        local lR, lG, lB = _G[tooltipName .. "TextLeft" .. i]:GetTextColor()
        local rText = _G[tooltipName .. "TextRight" .. i]:GetText()
        local rR, rG, rB = _G[tooltipName .. "TextRight" .. i]:GetTextColor()
        if rText and rText ~= "" then
          collector:AddDoubleLine(lText, rText, lR, lG, lB, rR, rG, rB, i == 1 and "total" or nil)
        else
          collector:AddLine(lText, lR, lG, lB, i == 1 and "total" or nil)
        end
      end
    end

    collector:AddLine(L["Played Time"], nil, nil, nil, "title")
    collector:AddLine("|cffa8a8a8(" .. L["Right click for options"] .. ")|r")

    local totalTime = 0
    for _, realm in ipairs(sortedRealms) do
      collector:AddLine(" ")
      collector.currentRealm = realm
      if #sortedRealms > 1 then
        collector:AddLine(GetRealmDisplayName(realm), nil, nil, nil, "realm")
      end

      if db.groupByFactions then
        for _, faction in ipairs(sortedFactions) do
          totalTime = totalTime + AddPlayerLines(collector, realm, sortedPlayers[realm][faction])
        end
      else
        totalTime = totalTime + AddPlayerLines(collector, realm, sortedPlayersNoFactions[realm])
      end
    end
    collector.currentRealm = nil

    collector:AddLine(" ")
    collector:AddDoubleLine(L["Total"], FormatTime(totalTime, not db.alwaysShowMinutes), nil, nil, nil, nil, nil, nil, "total")

    ShowMultiColumnFrame(tooltip, collector.lines, numColumns)

  end

end



------------------------------------------------------------------------

-- Not localized on purpose: other addons (e.g. PlayedTimeMinimapClock) look the data
-- object up by this name, and display addons store their settings under it.
BrokerPlayedTime.dataObject = LibStub("LibDataBroker-1.1"):NewDataObject("Time Played", {
  type = "data source",
  icon = [[Interface\Icons\Spell_Nature_TimeStop]],
  text = UNKNOWN,
  OnTooltipShow = OnTooltipShow,
  OnClick = function(self, button)
    if button == "RightButton" then
      GameTooltip:Hide()
      OpenMenu()
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
  self.dataObject.text = FormatTime(timeToPrint, (not db.alwaysShowMinutes) and (timeToPrint > 3600) )
end

do
  local updateDelay
  local function UpdateText()
    BrokerPlayedTime:UpdateText()
    C_Timer.After(updateDelay, UpdateText)
  end
  function BrokerPlayedTime:SetUpdateInterval(fast)
    local alreadyRunning = updateDelay
    updateDelay = (db.alwaysShowMinutes or fast) and 10 or 60
    if not alreadyRunning then
      C_Timer.After(updateDelay, UpdateText)
    end
  end
end

