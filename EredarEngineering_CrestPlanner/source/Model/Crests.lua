local CrestPlanner = _G.CrestPlanner

local Crests = {}
CrestPlanner.Crests = Crests

local SEEDED_CREST_IDENTIFIERS = {
    { identifier = 3442, track = "Adventurer" },
    { identifier = 3443, track = "Veteran" },
    { identifier = 3444, track = "Champion" },
    { identifier = 3445, track = "Hero" },
    { identifier = 3446, track = "Myth" },
}

local function itemLevelRangeFromDescription(description)
    if not description then return nil, nil end

    local floorLevel, ceilingLevel = string.match(description, "item levels (%d+)%-(%d+)")

    return tonumber(floorLevel), tonumber(ceilingLevel)
end

local function readCrest(seed)
    local info = C_CurrencyInfo.GetCurrencyInfo(seed.identifier)
    if not info or not info.name then return nil end

    local description = C_CurrencyInfo.GetCurrencyDescription
        and C_CurrencyInfo.GetCurrencyDescription(seed.identifier)
    local floorLevel, ceilingLevel = itemLevelRangeFromDescription(description)

    return {
        identifier = seed.identifier,
        track = seed.track,
        name = info.name,
        quantity = info.quantity or 0,
        totalEarned = info.totalEarned or 0,
        seasonMaximum = info.maxQuantity or 0,
        capMeasuresEarned = info.useTotalEarnedForMaxQty == true,
        floorItemLevel = floorLevel,
        ceilingItemLevel = ceilingLevel,
        description = description,
    }
end

function Crests:Refresh()
    assert(
        C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,
        "C_CurrencyInfo.GetCurrencyInfo is missing on this client -- CrestPlanner has no way to read"
            .. " a single crest and every number it could show would be invented"
    )

    local byTrack = {}
    local ordered = {}
    local mismatchedNames = {}

    for _, seed in ipairs(SEEDED_CREST_IDENTIFIERS) do
        local crest = readCrest(seed)

        if crest then
            if not string.find(crest.name, seed.track, 1, true) then
                mismatchedNames[#mismatchedNames + 1] = string.format(
                    "%d is named %s but was seeded as %s",
                    seed.identifier, crest.name, seed.track
                )
            end

            byTrack[seed.track] = crest
            ordered[#ordered + 1] = crest
        end
    end

    self.byTrack = byTrack
    self.ordered = ordered
    self.mismatchedNames = mismatchedNames

    return byTrack
end

local ESTIMATED_WEEKLY_CAP_INCREASE = 100
local SECONDS_PER_DAY = 24 * 60 * 60
local DAYS_PER_WEEK = 7

Crests.EstimatedWeeklyCapIncrease = ESTIMATED_WEEKLY_CAP_INCREASE

local function capHistory()
    local store = CrestPlanner:GetStore()
    store.seasonMaximumHistory = store.seasonMaximumHistory or {}

    return store.seasonMaximumHistory
end

function Crests:RecordSeasonMaximums()
    local history = capHistory()
    local today = date("%Y-%m-%d")

    for _, crest in ipairs(self:Ordered()) do
        if crest.seasonMaximum > 0 then
            history[crest.track] = history[crest.track] or {}
            history[crest.track][today] = crest.seasonMaximum
        end
    end
end

local function noonTimeOfDayKey(dayKey)
    local year, month, day = string.match(dayKey, "(%d+)-(%d+)-(%d+)")

    return time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12, min = 0, sec = 0 })
end

function Crests:WeeklyCapIncrease(trackName)
    local trackHistory = capHistory()[trackName]
    if not trackHistory then
        return ESTIMATED_WEEKLY_CAP_INCREASE, false
    end

    local earliestKey, latestKey = nil, nil
    for dayKey in pairs(trackHistory) do
        if not earliestKey or dayKey < earliestKey then earliestKey = dayKey end
        if not latestKey or dayKey > latestKey then latestKey = dayKey end
    end

    if not earliestKey or earliestKey == latestKey then
        return ESTIMATED_WEEKLY_CAP_INCREASE, false
    end

    local elapsedDays = (noonTimeOfDayKey(latestKey) - noonTimeOfDayKey(earliestKey)) / SECONDS_PER_DAY
    if elapsedDays < DAYS_PER_WEEK then
        return ESTIMATED_WEEKLY_CAP_INCREASE, false
    end

    local capGrowth = trackHistory[latestKey] - trackHistory[earliestKey]
    local weeksElapsed = elapsedDays / DAYS_PER_WEEK

    return math.floor(capGrowth / weeksElapsed + 0.5), true
end

function Crests:Get(trackName)
    if not self.byTrack then
        self:Refresh()
    end

    return self.byTrack[trackName]
end

function Crests:Ordered()
    if not self.ordered then
        self:Refresh()
    end

    return self.ordered
end

function Crests:IsCapped(trackName)
    local crest = self:Get(trackName)
    if not crest or crest.seasonMaximum == 0 then return false end

    return crest.totalEarned >= crest.seasonMaximum
end

function Crests:RemainingEarnableThisSeason(trackName)
    local crest = self:Get(trackName)
    if not crest or crest.seasonMaximum == 0 then return nil end

    return math.max(0, crest.seasonMaximum - crest.totalEarned)
end

function Crests:WarnIfSeedsDrifted()
    if not self.mismatchedNames or #self.mismatchedNames == 0 then return end

    CrestPlanner:Print(
        "|cFFE05050The crest identifiers no longer match their names on this client. A new season"
            .. " almost certainly renumbered them. Run /crestplanner probe currencies and send the"
            .. " result.|r"
    )

    for _, mismatch in ipairs(self.mismatchedNames) do
        CrestPlanner:Print("    " .. mismatch)
    end
end
