local TreasuryTimeline = _G.TreasuryTimeline

local ChartFrame = {}
TreasuryTimeline.ChartFrame = ChartFrame

local FRAME_WIDTH = 620
local FRAME_HEIGHT = 420
local PLOT_INSET_LEFT = 20
local PLOT_INSET_RIGHT = 20
local PLOT_HEIGHT = 210
local PLOT_TOP_OFFSET = -104
local COLUMN_GAP = 4
local MINIMUM_BAR_WIDTH = 2
local MINIMUM_VISIBLE_BAR_HEIGHT = 1
local DAY_LABEL_MINIMUM_COLUMN_WIDTH = 22

local NET_GAIN_COLOR = { 0.25, 0.75, 0.25 }
local NET_LOSS_COLOR = { 0.85, 0.30, 0.30 }
local REPAIR_COLOR = { 0.95, 0.62, 0.20 }
local ZERO_LINE_COLOR = { 0.6, 0.6, 0.6, 0.7 }
local WEEK_BOUNDARY_COLOR = { 0.45, 0.65, 0.95, 0.55 }

local function colorCode(colorParts)
    return string.format(
        "|cFF%02X%02X%02X",
        math.floor(colorParts[1] * 255 + 0.5),
        math.floor(colorParts[2] * 255 + 0.5),
        math.floor(colorParts[3] * 255 + 0.5)
    )
end

local function applyTitle(frame, titleValue)
    local titleText = frame.TitleText
        or (frame.TitleContainer and frame.TitleContainer.TitleText)
    if titleText then
        titleText:SetText(titleValue)
    end
end

local function createHeaderLine(frame, anchorTo, verticalOffset)
    local headerLine = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerLine:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", 0, verticalOffset)
    headerLine:SetJustifyH("LEFT")
    return headerLine
end

local function buildColumn(plotArea)
    local column = CreateFrame("Frame", nil, plotArea)
    column:SetHeight(PLOT_HEIGHT)
    column:EnableMouse(true)

    column.netBar = column:CreateTexture(nil, "ARTWORK")
    column.repairBar = column:CreateTexture(nil, "ARTWORK")

    column.weekBoundary = column:CreateTexture(nil, "BACKGROUND")
    column.weekBoundary:SetColorTexture(unpack(WEEK_BOUNDARY_COLOR))
    column.weekBoundary:SetWidth(1)
    column.weekBoundary:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
    column.weekBoundary:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 0)

    column.dayLabel = column:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    column.dayLabel:SetPoint("TOP", column, "BOTTOM", 0, -2)

    column:SetScript("OnEnter", function(self)
        if not self.dayTotals then return end
        ChartFrame:ShowDayTooltip(self, self.dayTotals)
    end)
    column:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return column
end

local function anchorFromStore()
    return TreasuryTimeline.Database:GetStore().chartAnchor
end

function ChartFrame:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "TreasuryTimelineChartFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(movedFrame)
        movedFrame:StopMovingOrSizing()
        local point, _, relativePoint, offsetX, offsetY = movedFrame:GetPoint()
        local storedAnchor = anchorFromStore()
        storedAnchor.point = point
        storedAnchor.relativePoint = relativePoint
        storedAnchor.offsetX = offsetX
        storedAnchor.offsetY = offsetY
    end)

    applyTitle(frame, "Treasury Timeline")

    local storedAnchor = anchorFromStore()
    frame:SetPoint(storedAnchor.point, UIParent, storedAnchor.relativePoint, storedAnchor.offsetX, storedAnchor.offsetY)

    local headerAnchor = CreateFrame("Frame", nil, frame)
    headerAnchor:SetPoint("TOPLEFT", frame, "TOPLEFT", PLOT_INSET_LEFT, -32)
    headerAnchor:SetSize(1, 1)

    frame.balanceLine = createHeaderLine(frame, headerAnchor, 0)
    frame.netLine = createHeaderLine(frame, headerAnchor, -18)
    frame.repairLine = createHeaderLine(frame, headerAnchor, -36)

    local plotArea = CreateFrame("Frame", nil, frame)
    plotArea:SetPoint("TOPLEFT", frame, "TOPLEFT", PLOT_INSET_LEFT, PLOT_TOP_OFFSET)
    plotArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PLOT_INSET_RIGHT, PLOT_TOP_OFFSET)
    plotArea:SetHeight(PLOT_HEIGHT)
    frame.plotArea = plotArea

    local zeroLine = plotArea:CreateTexture(nil, "BACKGROUND")
    zeroLine:SetColorTexture(unpack(ZERO_LINE_COLOR))
    zeroLine:SetHeight(1)
    frame.zeroLine = zeroLine

    local legend = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    legend:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PLOT_INSET_LEFT, 16)
    legend:SetJustifyH("LEFT")
    legend:SetText(
        "daily net "
            .. colorCode(NET_GAIN_COLOR) .. "gain|r / " .. colorCode(NET_LOSS_COLOR) .. "loss|r"
            .. "      " .. colorCode(REPAIR_COLOR) .. "repairs|r"
            .. "      " .. colorCode(WEEK_BOUNDARY_COLOR) .. "the line before a Tuesday is the weekly reset|r"
            .. "      |cFF909090hover a column for the full day|r"
    )

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
    end)

    tinsert(UISpecialFrames, "TreasuryTimelineChartFrame")

    self.frame = frame
    self.columns = {}

    return frame
end

function ChartFrame:ShowDayTooltip(column, dayTotals)
    local Formatting = TreasuryTimeline.Formatting

    GameTooltip:SetOwner(column, "ANCHOR_CURSOR")
    GameTooltip:AddLine(dayTotals.dayKey, 1, 1, 1)
    GameTooltip:AddDoubleLine("Earned", Formatting:FormatCopper(dayTotals.earnedCopper), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Spent", Formatting:FormatCopper(dayTotals.spentCopper), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Repairs", Formatting:FormatCopper(dayTotals.repairCopper), 0.95, 0.62, 0.2, 1, 1, 1)
    GameTooltip:AddDoubleLine("Net", Formatting:FormatSignedCopper(dayTotals.netCopper), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Balance at close", Formatting:FormatCopper(dayTotals.closingCopper), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:Show()
end

local function plotBounds(series)
    local largestGain = 0
    local largestDrop = 0

    for _, dayTotals in ipairs(series) do
        if dayTotals.netCopper > largestGain then
            largestGain = dayTotals.netCopper
        end
        if -dayTotals.netCopper > largestDrop then
            largestDrop = -dayTotals.netCopper
        end
        if dayTotals.repairCopper > largestDrop then
            largestDrop = dayTotals.repairCopper
        end
    end

    local span = largestGain + largestDrop
    if span == 0 then
        return 0, 0, PLOT_HEIGHT / 2
    end

    return largestGain, largestDrop, PLOT_HEIGHT * (largestDrop / span)
end

local function scaledHeight(amountCopper, referenceCopper, availablePixels)
    if amountCopper <= 0 or referenceCopper <= 0 or availablePixels <= 0 then return 0 end
    return math.max(MINIMUM_VISIBLE_BAR_HEIGHT, (amountCopper / referenceCopper) * availablePixels)
end

function ChartFrame:LayoutColumns(series)
    local frame = self.frame
    local plotArea = frame.plotArea
    local plotWidth = plotArea:GetWidth()
    local dayCount = #series
    local Database = TreasuryTimeline.Database
    local todayKey = Database:TodayKey()

    local largestGain, largestDrop, zeroOffsetFromBottom = plotBounds(series)
    frame.zeroLine:ClearAllPoints()
    frame.zeroLine:SetPoint("BOTTOMLEFT", plotArea, "BOTTOMLEFT", 0, zeroOffsetFromBottom)
    frame.zeroLine:SetPoint("BOTTOMRIGHT", plotArea, "BOTTOMRIGHT", 0, zeroOffsetFromBottom)

    local columnWidth = plotWidth / dayCount
    local barWidth = math.max(MINIMUM_BAR_WIDTH, math.floor((columnWidth - COLUMN_GAP) / 2))
    local upwardPixels = PLOT_HEIGHT - zeroOffsetFromBottom
    local downwardPixels = zeroOffsetFromBottom
    local showEveryDayLabel = columnWidth >= DAY_LABEL_MINIMUM_COLUMN_WIDTH

    for index = 1, dayCount do
        local column = self.columns[index]
        if not column then
            column = buildColumn(plotArea)
            self.columns[index] = column
        end

        local dayTotals = series[index]
        column.dayTotals = dayTotals
        column:SetWidth(columnWidth)
        column:ClearAllPoints()
        column:SetPoint("BOTTOMLEFT", plotArea, "BOTTOMLEFT", (index - 1) * columnWidth, 0)
        column:Show()

        local netBar = column.netBar
        netBar:ClearAllPoints()
        netBar:SetWidth(barWidth)

        if dayTotals.netCopper >= 0 then
            netBar:SetColorTexture(unpack(NET_GAIN_COLOR))
            netBar:SetHeight(scaledHeight(dayTotals.netCopper, largestGain, upwardPixels))
            netBar:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", COLUMN_GAP / 2, zeroOffsetFromBottom)
        else
            netBar:SetColorTexture(unpack(NET_LOSS_COLOR))
            netBar:SetHeight(scaledHeight(-dayTotals.netCopper, largestDrop, downwardPixels))
            netBar:SetPoint("TOPLEFT", column, "BOTTOMLEFT", COLUMN_GAP / 2, zeroOffsetFromBottom)
        end
        netBar:SetShown(dayTotals.netCopper ~= 0)

        local repairBar = column.repairBar
        repairBar:ClearAllPoints()
        repairBar:SetWidth(barWidth)
        repairBar:SetColorTexture(unpack(REPAIR_COLOR))
        repairBar:SetHeight(scaledHeight(dayTotals.repairCopper, largestDrop, downwardPixels))
        repairBar:SetPoint("TOPLEFT", column, "BOTTOMLEFT", COLUMN_GAP / 2 + barWidth, zeroOffsetFromBottom)
        repairBar:SetShown(dayTotals.repairCopper > 0)

        column.weekBoundary:SetShown(index > 1 and Database:IsWeekStartDay(dayTotals.dayKey))

        local wantsLabel = showEveryDayLabel or index == 1 or index == dayCount
        column.dayLabel:SetShown(wantsLabel)
        if wantsLabel then
            local dayNumber = string.sub(dayTotals.dayKey, 9)
            local isStillToCome = dayTotals.dayKey > todayKey
            column.dayLabel:SetText(isStillToCome and ("|cFF505050" .. dayNumber .. "|r") or dayNumber)
        end
    end

    for index = dayCount + 1, #self.columns do
        self.columns[index]:Hide()
    end
end

local RANGE_STRATEGIES = {
    rolling = {
        buildSeries = function(store)
            return TreasuryTimeline.DailySeries:BuildRecentDays(store, store.chartDayCount)
        end,
        describe = function(store)
            return string.format("Last %d days", store.chartDayCount)
        end,
    },

    resetWeek = {
        buildSeries = function(store)
            return TreasuryTimeline.DailySeries:BuildCurrentResetWeek(store)
        end,
        describe = function()
            return "This reset week"
        end,
    },
}

function ChartFrame:Refresh()
    local frame = self:Build()
    local Formatting = TreasuryTimeline.Formatting
    local DailySeries = TreasuryTimeline.DailySeries
    local store = TreasuryTimeline.Database:GetStore()

    local rangeStrategy = RANGE_STRATEGIES[store.chartRangeMode]
    local series = rangeStrategy.buildSeries(store)
    local summary = DailySeries:Summarize(series)
    local todayTotals = DailySeries:FindDay(series, TreasuryTimeline.Database:TodayKey())
    local characterRecord = TreasuryTimeline.Database:GetCharacterRecord()

    frame.balanceLine:SetText(string.format(
        "Account |cFFFFFFFF%s|r        %s |cFFFFFFFF%s|r",
        Formatting:FormatCopper(DailySeries:TotalCopper(store)),
        characterRecord.name,
        Formatting:FormatCopper(characterRecord.currentCopper)
    ))

    frame.netLine:SetText(string.format(
        "Today %s        %s %s",
        Formatting:FormatSignedCopper(todayTotals.netCopper),
        rangeStrategy.describe(store),
        Formatting:FormatSignedCopper(summary.netCopper)
    ))

    local repairShare = summary.spentCopper > 0
        and (summary.repairCopper / summary.spentCopper) * 100
        or 0

    frame.repairLine:SetText(string.format(
        "Repairs %s |cFF909090of|r %s |cFF909090spent, %.0f%% of everything that left|r",
        Formatting:FormatCopper(summary.repairCopper),
        Formatting:FormatCopper(summary.spentCopper),
        repairShare
    ))

    self:LayoutColumns(series)
end

function ChartFrame:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function ChartFrame:Show()
    self:Refresh()
    self.frame:Show()
end

function ChartFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ChartFrame:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
