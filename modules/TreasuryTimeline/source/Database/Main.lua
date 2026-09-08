local TreasuryTimeline = _G.TreasuryTimeline

local Database = {}
TreasuryTimeline.Database = Database

local SCHEMA_VERSION = 1
local DEFAULT_RETENTION_IN_DAYS = 365
local DEFAULT_CHART_DAY_COUNT = 14
local DEFAULT_CHART_RANGE_MODE = "resetWeek"
local SECONDS_PER_DAY = 24 * 60 * 60
local NOON_HOUR = 12
local DAYS_PER_WEEK = 7
local FALLBACK_RESET_WEEKDAY = 2

Database.DaysPerWeek = DAYS_PER_WEEK

function Database:NoonTimeOfDayKey(dayKey)
    local year, month, day = string.match(dayKey, "(%d+)-(%d+)-(%d+)")

    return time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = NOON_HOUR,
        min = 0,
        sec = 0,
    })
end

function Database:TodayKey()
    return date("%Y-%m-%d")
end

function Database:DayKeyOffsetFromToday(offsetInDays)
    return date("%Y-%m-%d", self:NoonTimeOfDayKey(self:TodayKey()) - offsetInDays * SECONDS_PER_DAY)
end

function Database:DaysBetween(fromDayKey, toDayKey)
    local elapsedSeconds = self:NoonTimeOfDayKey(toDayKey) - self:NoonTimeOfDayKey(fromDayKey)

    return math.floor(elapsedSeconds / SECONDS_PER_DAY + 0.5)
end

function Database:WeekdayOfDayKey(dayKey)
    return tonumber(date("%w", self:NoonTimeOfDayKey(dayKey)))
end

function Database:SecondsUntilWeeklyReset()
    if not C_DateAndTime or not C_DateAndTime.GetSecondsUntilWeeklyReset then
        return nil
    end

    return C_DateAndTime.GetSecondsUntilWeeklyReset()
end

function Database:WeekStartDayKey()
    local secondsUntilReset = self:SecondsUntilWeeklyReset()

    if secondsUntilReset == nil then
        local todayWeekday = self:WeekdayOfDayKey(self:TodayKey())
        local daysSince = (todayWeekday - FALLBACK_RESET_WEEKDAY + DAYS_PER_WEEK) % DAYS_PER_WEEK

        return self:DayKeyOffsetFromToday(daysSince)
    end

    local lastResetTime = time() + secondsUntilReset - DAYS_PER_WEEK * SECONDS_PER_DAY
    local weekStartDayKey = date("%Y-%m-%d", lastResetTime)

    assert(
        weekStartDayKey <= self:TodayKey(),
        "lazy-mode: the week opens at the realm reset instant, while the columns stay calendar days"
            .. " cut at local midnight, so the reset-day column mixes the hours before the reset with"
            .. " the hours after it; a start later than today would mean the realm clock and the local"
            .. " clock drifted more than a full day apart"
    )

    return weekStartDayKey
end

function Database:IsWeekStartDay(dayKey)
    return self:DaysBetween(self:WeekStartDayKey(), dayKey) % DAYS_PER_WEEK == 0
end

function Database:DaysSinceWeeklyReset()
    return self:DaysBetween(self:WeekStartDayKey(), self:TodayKey())
end

local function buildCharacterKey()
    local characterName, realmName = UnitFullName("player")
    if not realmName or realmName == "" then
        realmName = GetNormalizedRealmName()
    end

    assert(
        characterName and realmName,
        "Neither UnitFullName nor GetNormalizedRealmName has resolved this character yet"
            .. " -- Database:Initialize must run at PLAYER_LOGIN or later, never at ADDON_LOADED"
    )

    return characterName .. "-" .. realmName, characterName, realmName
end

local function emptyDayRecord(openingCopper)
    return {
        openingCopper = openingCopper,
        closingCopper = openingCopper,
        earnedCopper = 0,
        spentCopper = 0,
        repairCopper = 0,
    }
end

function Database:Initialize()
    if type(_G.TreasuryTimelineDB) ~= "table" then
        _G.TreasuryTimelineDB = {}
    end

    local store = _G.TreasuryTimelineDB
    store.schemaVersion = store.schemaVersion or SCHEMA_VERSION
    store.characters = store.characters or {}
    store.retentionInDays = store.retentionInDays or DEFAULT_RETENTION_IN_DAYS
    store.chartDayCount = store.chartDayCount or DEFAULT_CHART_DAY_COUNT
    store.chartRangeMode = store.chartRangeMode or DEFAULT_CHART_RANGE_MODE
    store.chartAnchor = store.chartAnchor or { point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = 0 }

    assert(
        store.schemaVersion == SCHEMA_VERSION,
        "TreasuryTimelineDB was written by schema version " .. tostring(store.schemaVersion)
            .. " and this build reads version " .. SCHEMA_VERSION
            .. " -- no migration exists yet, so refusing to load rather than corrupt the history"
    )

    self.store = store

    local characterKey, characterName, realmName = buildCharacterKey()
    self.characterKey = characterKey

    local characterRecord = store.characters[characterKey]
    if not characterRecord then
        characterRecord = { days = {} }
        store.characters[characterKey] = characterRecord
    end

    self.isFirstSightOfCharacter = characterRecord.currentCopper == nil

    characterRecord.name = characterName
    characterRecord.realm = realmName
    characterRecord.classFile = select(2, UnitClass("player"))
    characterRecord.currentCopper = characterRecord.currentCopper or 0
    characterRecord.days = characterRecord.days or {}

    self.characterRecord = characterRecord

    self:PruneBeyondRetention()
    self:WarnIfResetClockIsUnavailable()
end

function Database:WarnIfResetClockIsUnavailable()
    if self:SecondsUntilWeeklyReset() ~= nil then return end

    TreasuryTimeline:Print(
        "|cFFF29E33C_DateAndTime.GetSecondsUntilWeeklyReset is missing on this client, so the week"
            .. " opens at local midnight on Tuesday instead of at the realm reset.|r"
    )
end

function Database:GetStore()
    return self.store
end

function Database:GetCharacterRecord()
    return self.characterRecord
end

function Database:LatestDayKeyBefore(characterRecord, boundaryDayKey)
    local latestKey = nil
    for dayKey in pairs(characterRecord.days) do
        if dayKey < boundaryDayKey and (latestKey == nil or dayKey > latestKey) then
            latestKey = dayKey
        end
    end
    return latestKey
end

function Database:GetTodayRecord()
    local characterRecord = self.characterRecord
    local todayKey = self:TodayKey()
    local dayRecord = characterRecord.days[todayKey]

    if not dayRecord then
        local previousKey = self:LatestDayKeyBefore(characterRecord, todayKey)
        local openingCopper = previousKey
            and characterRecord.days[previousKey].closingCopper
            or characterRecord.currentCopper

        dayRecord = emptyDayRecord(openingCopper)
        characterRecord.days[todayKey] = dayRecord
    end

    return dayRecord
end

-- Money that moved while nothing was watching leaves no trace inside any day,
-- only a step between one day's close and the next day's open. A crash, a
-- disabled module or an addon rename all produce it, and none of them announce
-- themselves, so the gap has to be looked for deliberately.
function Database:FindContinuityGaps(characterRecord)
    characterRecord = characterRecord or self.characterRecord

    local dayKeys = {}
    for dayKey in pairs(characterRecord.days) do
        dayKeys[#dayKeys + 1] = dayKey
    end
    table.sort(dayKeys)

    local gaps = {}

    for index = 2, #dayKeys do
        local previousDay = characterRecord.days[dayKeys[index - 1]]
        local currentDay = characterRecord.days[dayKeys[index]]
        local step = currentDay.openingCopper - previousDay.closingCopper

        if step ~= 0 then
            gaps[#gaps + 1] = {
                afterDayKey = dayKeys[index - 1],
                beforeDayKey = dayKeys[index],
                copper = step,
            }
        end
    end

    return gaps
end

-- Folds an unexplained step into the day it lands on, so the ledger reads
-- continuously again. It is filed as earned or spent with no category, since
-- that is precisely the extent of what is known about it.
function Database:AbsorbGap(gap)
    local dayRecord = self.characterRecord.days[gap.beforeDayKey]
    if not dayRecord then return false end

    if gap.copper < 0 then
        dayRecord.spentCopper = dayRecord.spentCopper + (-gap.copper)
    else
        dayRecord.earnedCopper = dayRecord.earnedCopper + gap.copper
    end

    dayRecord.openingCopper = dayRecord.openingCopper - gap.copper

    return true
end

local function applyBalance(self, currentCopper)
    self.characterRecord.currentCopper = currentCopper
    self.characterRecord.lastSeenAt = time()
    self:GetTodayRecord().closingCopper = currentCopper
end

function Database:RecordGain(gainedCopper, currentCopper)
    local dayRecord = self:GetTodayRecord()
    dayRecord.earnedCopper = dayRecord.earnedCopper + gainedCopper
    applyBalance(self, currentCopper)
end

function Database:RecordSpend(spentCopper, repairCopper, currentCopper)
    local dayRecord = self:GetTodayRecord()
    dayRecord.spentCopper = dayRecord.spentCopper + spentCopper
    dayRecord.repairCopper = dayRecord.repairCopper + repairCopper
    applyBalance(self, currentCopper)
end

function Database:SeedBalance(currentCopper)
    self.isFirstSightOfCharacter = false
    self.characterRecord.currentCopper = currentCopper

    local dayRecord = self:GetTodayRecord()
    dayRecord.openingCopper = currentCopper
    dayRecord.closingCopper = currentCopper
    self.characterRecord.lastSeenAt = time()
end

function Database:Reconcile(currentCopper)
    if self.isFirstSightOfCharacter then
        self:SeedBalance(currentCopper)
        return 0
    end

    local difference = currentCopper - self.characterRecord.currentCopper

    if difference == 0 then
        applyBalance(self, currentCopper)
    elseif difference > 0 then
        self:RecordGain(difference, currentCopper)
    else
        self:RecordSpend(-difference, 0, currentCopper)
    end

    return difference
end

function Database:PruneBeyondRetention()
    local oldestKeptKey = self:DayKeyOffsetFromToday(self.store.retentionInDays)

    for _, characterRecord in pairs(self.store.characters) do
        for dayKey in pairs(characterRecord.days) do
            if dayKey < oldestKeptKey then
                characterRecord.days[dayKey] = nil
            end
        end
    end
end

function Database:ForgetEverything()
    self.store.characters = {}
    self.characterRecord = nil
    self:Initialize()
end
