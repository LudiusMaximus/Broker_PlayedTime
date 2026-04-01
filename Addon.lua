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

local currentFaction = UnitFactionGroup("player")
local currentPlayer = UnitName("player")
local currentRealm = GetRealmName()

-- With 14 the lines get bigger than blank lines.
-- TODO: Make it math.floor(tooltipLineHeight)
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
  ["set4"] = {
    Alliance = "|A:honorsystem-portrait-alliance:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
    Horde = "|A:honorsystem-portrait-horde:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
    Neutral = "|A:honorsystem-portrait-neutral:" .. textIconSize .. ":" .. textIconSize * (50/52) .. "|a ",
  },
}

-- These icons are only available in retail.
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
  factionIcons["set1"] = {
    Alliance = "|A:AllianceSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    Horde = "|A:HordeSymbol:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    Neutral = "|A:CrossedFlags:" .. textIconSize .. ":" .. textIconSize .. "|a ",
  }
  factionIcons["set2"] = {
    Alliance = "|A:nameplates-icon-flag-alliance:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    Horde = "|A:nameplates-icon-flag-horde:" .. textIconSize .. ":" .. textIconSize .. "|a ",
    Neutral = "|A:nameplates-icon-flag-neutral:" .. textIconSize .. ":" .. textIconSize .. "|a ",
  }
  factionIcons["set3"] = {
    Alliance = "|A:Warfronts-BaseMapIcons-Alliance-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
    Horde = "|A:Warfronts-BaseMapIcons-Horde-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
    Neutral = "|A:Warfronts-BaseMapIcons-Empty-Armory:" .. textIconSize .. ":" .. textIconSize * (37/35) .. "|a ",
  }
end


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


-- Dedicated tooltip for measuring line height.
local measureTooltip = nil
local tooltipLineHeight = nil
-- https://warcraft.wiki.gg/wiki/API_GameTooltip_GetPadding only returned 0,0,0,0 for me, so I am getting the "padding" manually.
-- (The "padding" is the actual padding plus the difference between a normal tooltip line and the slightly greater title line.)
local tooltipTopBottomPadding = nil
function GetTooltipLineHeight()

  if not measureTooltip then
    measureTooltip = CreateFrame("GameTooltip", ADDON .. "_MeasureTooltip", UIParent, "SharedTooltipTemplate")
  else
    measureTooltip:ClearLines()
  end

  measureTooltip:SetOwner(UIParent, "ANCHOR_TOPLEFT")

  measureTooltip:AddLine("Title")
  measureTooltip:Show()
  local tooltipHeight1 = measureTooltip:GetHeight()
  measureTooltip:AddLine("Line 1")
  measureTooltip:Show()
  local tooltipHeight2 = measureTooltip:GetHeight()
  local lineHeight = tooltipHeight2 - tooltipHeight1

  -- Check to be on the safe side.
  measureTooltip:AddLine("Line 2")
  measureTooltip:Show()
  local tooltipHeight3 = measureTooltip:GetHeight()
  measureTooltip:Hide()

  if math.floor((tooltipHeight2 + lineHeight) * 1000) - math.floor(tooltipHeight3 * 1000) == 0 then
    tooltipLineHeight = lineHeight
    tooltipTopBottomPadding = tooltipHeight1 - lineHeight
  else
    tooltipLineHeight = nil
    tooltipTopBottomPadding = nil
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
-- group of character lines. Every DoubleLine added while it is set inherits the realm
-- name as a `realm` field on its entry. ShowMultiColumnFrame reads those fields to
-- identify contiguous realm blocks and uses them for the column-balancing algorithm
-- (avoiding orphan groups at column boundaries).
local function CreateLineCollector()
  return {
    lines = {},
    currentRealm = nil,
    AddLine = function(self, text, r, g, b, kind)
      tinsert(self.lines, { leftText = text, leftR = r, leftG = g, leftB = b, kind = kind })
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
        currentBlock = { startIdx = i, endIdx = i, count = 0, realm = line.leftText }
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
  db = copyTable(defaults, BrokerPlayedTimeDB)

  RemoveDuplicates()

  myDB = db[currentRealm][currentFaction][currentPlayer]
  
  -- Needed if you deleted and recreated a character with the same name but different class.  
  myDB.class = (select(2, UnitClass("player")))
  -- Needed for deletion/recreation and for level boost (no PLAYER_LEVEL_UP event).
  myDB.level = UnitLevel("player")


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

  self:UpdateTimePlayed()

  GetTooltipLineHeight()

end

local requesting

-- Hook the appropriate display function based on WoW version
if ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed then
  -- Retail: Hook ChatFrameUtil.DisplayTimePlayed
  local originalDisplayTimePlayed = ChatFrameUtil.DisplayTimePlayed
  function ChatFrameUtil.DisplayTimePlayed(chatFrame, totalTime, levelTime)
    if requesting then
      requesting = false
      return  -- Suppress the message display
    end
    return originalDisplayTimePlayed(chatFrame, totalTime, levelTime)
  end
else
  -- Classic: Hook ChatFrame_DisplayTimePlayed
  local o = ChatFrame_DisplayTimePlayed
  ChatFrame_DisplayTimePlayed = function(...)
    if requesting then
      requesting = false
      return
    end
    return o(...)
  end
end

function BrokerPlayedTime:UpdateTimePlayed()
  requesting = true
  RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
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

    mainMenu:CreateCheckbox(L["Current realm only"],
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
      end)

    mainMenu:CreateDivider()

    -- ===== REMOVE CHARACTER =====
    local removeCharSubmenu = mainMenu:CreateButton(L["Remove character"])
    removeCharSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

    for _, realm in ipairs(sortedRealms) do
      local realmSubmenu = removeCharSubmenu:CreateButton(realm)
      realmSubmenu:SetOnEnter(function(_, desc) desc:ForceOpenSubmenu() end)

      for i, faction in ipairs(sortedFactions) do
        -- Only show factions that have characters on this realm
        if sortedPlayers[realm] and sortedPlayers[realm][faction] and #sortedPlayers[realm][faction] > 0 then
          -- Faction title
          realmSubmenu:CreateTitle(faction)

          -- Character list (indented with radio buttons)
          for j, name in ipairs(sortedPlayers[realm][faction]) do
            local cdata = db[realm][faction][name]
            local disableRemove = (name == currentPlayer and realm == currentRealm)

            realmSubmenu:CreateRadio(
              format("%s%s",
                CLASS_COLORS[cdata and cdata.class or "UNKNOWN"],
                name),
              function() return false end, -- Never selected
              function()
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
              end
            ):SetEnabled(not disableRemove)
          end
        end
      end
    end


    -- ===== BROKER TEXT OPTIONS =====
    if not TimeManagerClockButton:IsMouseOver() then
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




local function AddPlayerLines(tooltip, realm, names, firstIndex, lastIndex)
  if not realm or not names or #names == 0 then return 0 end
  if firstIndex and lastIndex and firstIndex > lastIndex then return 0 end

  local totalTime = 0
  local indexCounter = 0

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
        indexCounter = indexCounter + 1

        if not firstIndex or indexCounter >= firstIndex then
          tooltip:AddDoubleLine(
            format("%s%s%s%s%s%s|r",
              factionIcons[db.factionIcons][mapPlayerToFaction[realm][name]],
              db.classIcons and classIcons[data.class] or "",
              CLASS_COLORS[data.class] or CLASS_COLORS["UNKNOWN"],
              (db.highlightCurrentPlayer and realm == currentRealm and name == currentPlayer) and "|TInterface\\CHATFRAME\\ChatFrameExpandArrow:" .. (tooltipLineHeight and math.floor(tooltipLineHeight) or "13") .. "|t" or "",
              name,
              db.levels and (" (" .. data.level .. (db.showPlayedTimeLevel and (": " .. FormatTime(charTimeLevel, not db.alwaysShowMinutes)) or "") .. ")") or ""
            ),
            FormatTime(charTime, not db.alwaysShowMinutes)
          )

          totalTime = totalTime + charTime
        end

        if lastIndex and indexCounter >= lastIndex then return totalTime end
      end

    end
  end



  return totalTime
end




local fallBackWarningGiven = false

local function OnTooltipShow(tooltip)

  if not tooltipLineHeight then
    GetTooltipLineHeight()
  end

  -- Estimate how many tooltips we need.
  -- NOTE: Do NOT call tooltip:Show() / tooltip:GetHeight() here. When this hook fires
  -- inside TimeManagerClockButton_UpdateTooltip (a C-level secure call), GetHeight()
  -- returns a tainted "secret" number that cannot be used in arithmetic.
  -- Instead, compute the initial height from our own measurements.
  local initialNumLines = tooltip:NumLines()
  local tooltipInitialHeight = tooltipTopBottomPadding or 0
  if tooltipLineHeight and initialNumLines > 0 then
    tooltipInitialHeight = tooltipTopBottomPadding + (initialNumLines * tooltipLineHeight)
  end
  -- print("tooltipInitialHeight", tooltipInitialHeight)
  -- print("initialNumLines", initialNumLines)


  local lineCounter = 0
  lineCounter = lineCounter + 1             -- tooltip:AddLine(L["Played Time"])
  lineCounter = lineCounter + 1             -- tooltip:AddLine(L["Right click for settings"])

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



  -- If we were not able to determine tooltipLineHeight, there is something messed up with this user's tooltip.
  -- No better solution yet than to not use multiple tooltips.
  local estimatedHeight = 0
  if tooltipLineHeight then
    estimatedHeight = tooltipInitialHeight + lineCounter*tooltipLineHeight
  elseif not fallBackWarningGiven then
    print(ADDON, "could not determine your tooltip line height. Falling back to single column tooltip.")
    fallBackWarningGiven = true
  end

  -- print("estimatedHeight", estimatedHeight)

  local allowedHeight = 0.7 * UIParent:GetHeight()
  -- print("allowedHeight", allowedHeight)


  -- One tooltip is enough.
  if estimatedHeight <= allowedHeight then
    local totalTime = 0
    tooltip:AddLine(L["Played Time"])
    tooltip:AddLine("|cffa8a8a8(" .. L["Right click for options"] .. ")|r")
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
    tooltip:AddDoubleLine(L["Total"], FormatTime(totalTime, not db.alwaysShowMinutes))

    tooltip:Show()
    -- print("real height", tooltip:GetHeight(), tooltip:NumLines())


  -- #########################################################################
  -- We need several columns. Use custom multi-column frame.
  else

    local numColumns = ceil(estimatedHeight / allowedHeight)

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
      if #sortedRealms > 1 then
        collector:AddLine(realm, nil, nil, nil, "realm")
      end
      collector.currentRealm = realm

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

BrokerPlayedTime.dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(L["Time Played"], {
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

