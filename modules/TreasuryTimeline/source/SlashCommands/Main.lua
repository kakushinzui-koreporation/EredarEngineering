local TreasuryTimeline = _G.TreasuryTimeline

local SlashCommands = {}
TreasuryTimeline.SlashCommands = SlashCommands

local MINIMUM_DAY_COUNT = 1
local MAXIMUM_DAY_COUNT = 90
local DEFAULT_LISTED_DAY_COUNT = 7

local function splitArguments(message)
    local arguments = {}
    for word in string.gmatch(message or "", "%S+") do
        arguments[#arguments + 1] = string.lower(word)
    end
    return arguments
end

local function clampDayCount(requestedDayCount, fallbackDayCount)
    local dayCount = tonumber(requestedDayCount) or fallbackDayCount
    return math.max(MINIMUM_DAY_COUNT, math.min(MAXIMUM_DAY_COUNT, math.floor(dayCount)))
end

local function printDaySummary(dayTotals)
    local Formatting = TreasuryTimeline.Formatting

    TreasuryTimeline:Print(string.format(
        "%s  net %s  |cFF909090earned|r %s  |cFF909090spent|r %s  |cFFF29E33repairs|r %s",
        dayTotals.dayKey,
        Formatting:FormatSignedCopper(dayTotals.netCopper),
        Formatting:FormatCopper(dayTotals.earnedCopper),
        Formatting:FormatCopper(dayTotals.spentCopper),
        Formatting:FormatCopper(dayTotals.repairCopper)
    ))
end

local COMMAND_HANDLERS = {}

COMMAND_HANDLERS[""] = function()
    TreasuryTimeline.ChartFrame:Toggle()
end

COMMAND_HANDLERS["chart"] = function(arguments)
    local store = TreasuryTimeline.Database:GetStore()
    store.chartDayCount = clampDayCount(arguments[2], store.chartDayCount)
    store.chartRangeMode = "rolling"
    TreasuryTimeline.ChartFrame:Show()
end

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local function describeDuration(totalSeconds)
    local days = math.floor(totalSeconds / SECONDS_PER_DAY)
    local hours = math.floor((totalSeconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
    local minutes = math.floor((totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)

    if days > 0 then
        return string.format("%d days %d hours", days, hours)
    end
    if hours > 0 then
        return string.format("%d hours %d minutes", hours, minutes)
    end
    return string.format("%d minutes", minutes)
end

COMMAND_HANDLERS["week"] = function()
    local Database = TreasuryTimeline.Database
    Database:GetStore().chartRangeMode = "resetWeek"
    TreasuryTimeline.ChartFrame:Show()

    local secondsUntilReset = Database:SecondsUntilWeeklyReset()
    if secondsUntilReset == nil then return end

    TreasuryTimeline:Print(string.format(
        "Week opened |cFFFFFFFF%s|r at the realm reset. Next reset in |cFFFFFFFF%s|r.",
        Database:WeekStartDayKey(),
        describeDuration(secondsUntilReset)
    ))
end

COMMAND_HANDLERS["today"] = function()
    local store = TreasuryTimeline.Database:GetStore()
    local series = TreasuryTimeline.DailySeries:BuildRecentDays(store, 1)
    printDaySummary(series[1])
end

COMMAND_HANDLERS["days"] = function(arguments)
    local store = TreasuryTimeline.Database:GetStore()
    local dayCount = clampDayCount(arguments[2], DEFAULT_LISTED_DAY_COUNT)
    local series = TreasuryTimeline.DailySeries:BuildRecentDays(store, dayCount)
    local summary = TreasuryTimeline.DailySeries:Summarize(series)
    local Formatting = TreasuryTimeline.Formatting

    for _, dayTotals in ipairs(series) do
        printDaySummary(dayTotals)
    end

    TreasuryTimeline:Print(string.format(
        "|cFFFFFFFF%d days|r  net %s  |cFFF29E33repairs|r %s",
        dayCount,
        Formatting:FormatSignedCopper(summary.netCopper),
        Formatting:FormatCopper(summary.repairCopper)
    ))
end

COMMAND_HANDLERS["characters"] = function()
    local store = TreasuryTimeline.Database:GetStore()
    local DailySeries = TreasuryTimeline.DailySeries
    local Formatting = TreasuryTimeline.Formatting

    for _, balance in ipairs(DailySeries:CharacterBalances(store)) do
        local classColor = balance.classFile and RAID_CLASS_COLORS[balance.classFile]
        local coloredName = classColor
            and string.format("|c%s%s|r", classColor.colorStr, balance.name)
            or balance.name

        TreasuryTimeline:Print(string.format(
            "%s |cFF909090%s|r  %s",
            coloredName,
            balance.realm,
            Formatting:FormatCopper(balance.currentCopper)
        ))
    end

    TreasuryTimeline:Print(string.format(
        "|cFFFFFFFFAccount total|r  %s",
        Formatting:FormatCopper(DailySeries:TotalCopper(store))
    ))
end

COMMAND_HANDLERS["reset"] = function(arguments)
    if arguments[2] ~= "confirm" then
        TreasuryTimeline:Print("This erases every day recorded for every character. Run |cFFFFFFFF/treasury reset confirm|r to go through with it.")
        return
    end

    TreasuryTimeline.Database:ForgetEverything()
    TreasuryTimeline.Tracker:Resynchronize()
    TreasuryTimeline.ChartFrame:Hide()
    TreasuryTimeline:Print("History erased. Tracking restarts from the balance you are carrying now.")
end

COMMAND_HANDLERS["help"] = function()
    TreasuryTimeline:Print("|cFFFFFFFF/treasury|r opens or closes the chart.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury week|r shows the reset week, Tuesday through Monday.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury chart <days>|r switches to a rolling range of that many days.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury today|r prints what today earned, spent and repaired.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury days <count>|r prints one line per day plus the range total.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury characters|r prints the gold each character is carrying.")
    TreasuryTimeline:Print("|cFFFFFFFF/treasury reset confirm|r erases the whole history.")
end

function SlashCommands:Initialize()
    SLASH_TREASURY_TIMELINE1 = "/treasury"

    SlashCmdList["TREASURY_TIMELINE"] = function(message)
        local arguments = splitArguments(message)
        local handler = COMMAND_HANDLERS[arguments[1] or ""] or COMMAND_HANDLERS["help"]
        handler(arguments)
    end
end
