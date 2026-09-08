local addonRoot = (arg and arg[0] or ""):match("^(.*)verification[/\\][^/\\]*$") or "./"

_G.TreasuryTimeline = {}

local printedMessages = {}

function TreasuryTimeline:Print(message)
    printedMessages[#printedMessages + 1] = message
end

local STUBBED_CHARACTER_NAME = "Verifier"
local STUBBED_REALM_NAME = "TestRealm"

local frozenNow = nil

function _G.time(dateParts)
    if dateParts then return os.time(dateParts) end
    return frozenNow or os.time()
end

function _G.date(format, atTime)
    return os.date(format, atTime or frozenNow or os.time())
end

local function freezeClockAt(dateParts)
    frozenNow = os.time(dateParts)
end

local function thawClock()
    frozenNow = nil
    _G.C_DateAndTime = nil
end

local function stubSecondsUntilWeeklyReset(secondsUntilReset)
    _G.C_DateAndTime = {
        GetSecondsUntilWeeklyReset = function()
            return secondsUntilReset
        end,
    }
end

function _G.UnitFullName()
    return STUBBED_CHARACTER_NAME, STUBBED_REALM_NAME
end

function _G.GetNormalizedRealmName()
    return STUBBED_REALM_NAME
end

function _G.UnitClass()
    return "Paladin", "PALADIN"
end

dofile(addonRoot .. "source/Database/Main.lua")
dofile(addonRoot .. "source/Reporting/DailySeries.lua")

local Database = TreasuryTimeline.Database
local DailySeries = TreasuryTimeline.DailySeries

local checksRun = 0

local function check(condition, description)
    checksRun = checksRun + 1
    if not condition then
        error("FAILED: " .. description, 2)
    end
end

DailySeries:RunSelfCheck()
checksRun = checksRun + 9

_G.TreasuryTimelineDB = nil
Database:Initialize()

local STARTING_COPPER = 500000

check(Database.isFirstSightOfCharacter == true, "a character with no record is flagged as first sight")
check(Database:Reconcile(STARTING_COPPER) == 0, "the first sight of a character records no gain")

local todayRecord = Database:GetTodayRecord()
check(todayRecord.earnedCopper == 0, "seeding a starting balance earns nothing")
check(todayRecord.openingCopper == STARTING_COPPER, "the first day opens at the balance already carried")
check(todayRecord.closingCopper == STARTING_COPPER, "the first day closes at the balance already carried")

Database:RecordGain(1000, STARTING_COPPER + 1000)
Database:RecordSpend(300, 200, STARTING_COPPER + 700)

todayRecord = Database:GetTodayRecord()
check(todayRecord.earnedCopper == 1000, "a gain lands in the day earned total")
check(todayRecord.spentCopper == 300, "a spend lands in the day spent total")
check(todayRecord.repairCopper == 200, "the repair share of a spend is filed separately")
check(todayRecord.closingCopper == STARTING_COPPER + 700, "the day closes at the live balance")
check(
    todayRecord.closingCopper == todayRecord.openingCopper + todayRecord.earnedCopper - todayRecord.spentCopper,
    "closing balance equals opening plus earned minus spent"
)

local gapsBefore = Database:FindContinuityGaps()
check(#gapsBefore == 0, "a single unbroken day reports no continuity gap")

Database:GetCharacterRecord().days["2026-01-01"] = {
    openingCopper = 1000, closingCopper = 900, earnedCopper = 0, spentCopper = 100, repairCopper = 0,
}
Database:GetCharacterRecord().days["2026-01-02"] = {
    openingCopper = 800, closingCopper = 800, earnedCopper = 0, spentCopper = 0, repairCopper = 0,
}
local function gapAfter(dayKey)
    for _, candidate in ipairs(Database:FindContinuityGaps()) do
        if candidate.afterDayKey == dayKey then return candidate end
    end
    return nil
end

local syntheticGap = gapAfter("2026-01-01")
check(syntheticGap ~= nil, "a step between one day closing and the next opening is found")
check(syntheticGap.copper == -100, "the gap reports the size and direction of the step")
check(syntheticGap.beforeDayKey == "2026-01-02", "the gap names the day it lands on")

Database:AbsorbGap(syntheticGap)
local absorbed = Database:GetCharacterRecord().days["2026-01-02"]
check(absorbed.spentCopper == 100, "a negative gap is folded in as spending")
check(absorbed.openingCopper == 900, "absorbing lines the opening up with the previous close")
check(gapAfter("2026-01-01") == nil, "no gap survives being absorbed")

Database:GetCharacterRecord().days["2026-01-01"] = nil
Database:GetCharacterRecord().days["2026-01-02"] = nil

local reconciledDifference = Database:Reconcile(STARTING_COPPER + 700 - 5000)
check(reconciledDifference == -5000, "a balance drop that happened while logged out reconciles as a spend")
check(Database:GetTodayRecord().spentCopper == 5300, "the unobserved drop joins the day spent total")
check(Database:GetTodayRecord().repairCopper == 200, "an unobserved drop is never attributed to repairs")

local series = DailySeries:BuildRecentDays(Database:GetStore(), 3)
check(#series == 3, "BuildRecentDays returns one entry per requested day")
check(series[3].dayKey == Database:TodayKey(), "the last entry of the series is today")
check(series[3].netCopper == 1000 - 5300, "today nets earned minus spent")
check(series[1].closingCopper == 0, "a day before this character existed carries no balance")

check(Database:WeekdayOfDayKey("2026-09-01") == 2, "2026-09-01 is a Tuesday")
check(Database:DaysBetween("2026-09-01", "2026-09-08") == 7, "DaysBetween counts a whole week")
check(Database:DaysBetween("2026-09-08", "2026-09-01") == -7, "DaysBetween is signed")

local ONE_HOUR = 60 * 60
local SECONDS_PER_WEEK = 7 * 24 * ONE_HOUR

freezeClockAt({ year = 2026, month = 9, day = 8, hour = 3, min = 0, sec = 0 })
stubSecondsUntilWeeklyReset(5 * ONE_HOUR)
check(
    Database:WeekStartDayKey() == "2026-09-01",
    "a Tuesday before the realm reset still belongs to the week that opened the previous Tuesday"
)
check(Database:DaysSinceWeeklyReset() == 7, "that pre-reset Tuesday sits seven days past its week start")

local weekBeforeReset = DailySeries:BuildCurrentResetWeek(Database:GetStore())
check(weekBeforeReset[1].dayKey == "2026-09-01", "the pre-reset week opens on the previous Tuesday")
check(weekBeforeReset[7].dayKey == "2026-09-07", "the pre-reset week closes on Monday, not on today")

freezeClockAt({ year = 2026, month = 9, day = 8, hour = 10, min = 0, sec = 0 })
stubSecondsUntilWeeklyReset(SECONDS_PER_WEEK - 2 * ONE_HOUR)
check(
    Database:WeekStartDayKey() == "2026-09-08",
    "the same Tuesday after the realm reset opens the new week"
)
check(Database:DaysSinceWeeklyReset() == 0, "the reset day sits at day zero of its own week")

local weekAfterReset = DailySeries:BuildCurrentResetWeek(Database:GetStore())
check(weekAfterReset[1].dayKey == "2026-09-08", "the post-reset week opens on today")
check(weekAfterReset[7].dayKey == "2026-09-14", "the post-reset week runs through the following Monday")
check(Database:IsWeekStartDay("2026-09-08") == true, "the reset day is a week start")
check(Database:IsWeekStartDay("2026-09-15") == true, "a week start repeats every seven days forward")
check(Database:IsWeekStartDay("2026-09-01") == true, "a week start repeats every seven days backward")
check(Database:IsWeekStartDay("2026-09-09") == false, "the day after the reset is not a week start")

_G.C_DateAndTime = nil
check(
    Database:WeekStartDayKey() == "2026-09-08",
    "without the realm clock the week falls back to local midnight on Tuesday"
)

printedMessages = {}
Database:WarnIfResetClockIsUnavailable()
check(#printedMessages == 1, "a missing realm clock is announced instead of silently downgraded")

printedMessages = {}
stubSecondsUntilWeeklyReset(ONE_HOUR)
Database:WarnIfResetClockIsUnavailable()
check(#printedMessages == 0, "a working realm clock says nothing")

thawClock()

local resetWeek = DailySeries:BuildCurrentResetWeek(Database:GetStore())
check(#resetWeek == 7, "the reset week always spans seven columns")
check(
    DailySeries:FindDay(resetWeek, Database:TodayKey()).dayKey == Database:TodayKey(),
    "FindDay locates today inside a week that also holds days still to come"
)
check(
    DailySeries:FindDay(resetWeek, "1999-01-01").netCopper == 0,
    "FindDay returns an empty day rather than nil when the key is outside the range"
)

function _G.UnitFullName()
    return STUBBED_CHARACTER_NAME, nil
end

_G.TreasuryTimelineDB = nil
Database:Initialize()
check(
    Database.characterKey == STUBBED_CHARACTER_NAME .. "-" .. STUBBED_REALM_NAME,
    "a nil realm from UnitFullName falls back to GetNormalizedRealmName"
)

function _G.GetNormalizedRealmName()
    return nil
end

_G.TreasuryTimelineDB = nil
local initializeSucceeded = pcall(function()
    Database:Initialize()
end)
check(
    initializeSucceeded == false,
    "initializing before the character resolves fails loudly instead of building a key from nil"
)

print(string.format("TreasuryTimeline verification passed: %d checks", checksRun))
