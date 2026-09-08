local TreasuryTimeline = _G.TreasuryTimeline

local DailySeries = {}
TreasuryTimeline.DailySeries = DailySeries

local function emptyDayTotals(dayKey)
    return {
        dayKey = dayKey,
        earnedCopper = 0,
        spentCopper = 0,
        repairCopper = 0,
        netCopper = 0,
        closingCopper = 0,
        hasActivity = false,
    }
end

local function carriedClosingBefore(characterRecord, boundaryDayKey)
    local previousKey = TreasuryTimeline.Database:LatestDayKeyBefore(characterRecord, boundaryDayKey)
    if not previousKey then return 0 end
    return characterRecord.days[previousKey].closingCopper
end

function DailySeries:BuildForDays(store, dayKeys)
    local carriedClosing = {}
    for characterKey, characterRecord in pairs(store.characters) do
        carriedClosing[characterKey] = carriedClosingBefore(characterRecord, dayKeys[1])
    end

    local series = {}

    for _, dayKey in ipairs(dayKeys) do
        local dayTotals = emptyDayTotals(dayKey)

        for characterKey, characterRecord in pairs(store.characters) do
            local dayRecord = characterRecord.days[dayKey]

            if dayRecord then
                dayTotals.earnedCopper = dayTotals.earnedCopper + dayRecord.earnedCopper
                dayTotals.spentCopper = dayTotals.spentCopper + dayRecord.spentCopper
                dayTotals.repairCopper = dayTotals.repairCopper + dayRecord.repairCopper
                dayTotals.hasActivity = true
                carriedClosing[characterKey] = dayRecord.closingCopper
            end

            dayTotals.closingCopper = dayTotals.closingCopper + carriedClosing[characterKey]
        end

        dayTotals.netCopper = dayTotals.earnedCopper - dayTotals.spentCopper
        series[#series + 1] = dayTotals
    end

    return series
end

function DailySeries:BuildRecentDays(store, dayCount)
    local dayKeys = {}
    for offsetInDays = dayCount - 1, 0, -1 do
        dayKeys[#dayKeys + 1] = TreasuryTimeline.Database:DayKeyOffsetFromToday(offsetInDays)
    end

    return self:BuildForDays(store, dayKeys)
end

function DailySeries:BuildCurrentResetWeek(store)
    local Database = TreasuryTimeline.Database
    local firstOffset = Database:DaysSinceWeeklyReset()

    local dayKeys = {}
    for offsetInDays = firstOffset, firstOffset - (Database.DaysPerWeek - 1), -1 do
        dayKeys[#dayKeys + 1] = Database:DayKeyOffsetFromToday(offsetInDays)
    end

    return self:BuildForDays(store, dayKeys)
end

function DailySeries:FindDay(series, dayKey)
    for _, dayTotals in ipairs(series) do
        if dayTotals.dayKey == dayKey then
            return dayTotals
        end
    end

    return emptyDayTotals(dayKey)
end

function DailySeries:Summarize(series)
    local summary = {
        earnedCopper = 0,
        spentCopper = 0,
        repairCopper = 0,
        netCopper = 0,
        largestAbsoluteNetCopper = 0,
        largestRepairCopper = 0,
        activeDayCount = 0,
    }

    for _, dayTotals in ipairs(series) do
        summary.earnedCopper = summary.earnedCopper + dayTotals.earnedCopper
        summary.spentCopper = summary.spentCopper + dayTotals.spentCopper
        summary.repairCopper = summary.repairCopper + dayTotals.repairCopper

        local absoluteNet = math.abs(dayTotals.netCopper)
        if absoluteNet > summary.largestAbsoluteNetCopper then
            summary.largestAbsoluteNetCopper = absoluteNet
        end
        if dayTotals.repairCopper > summary.largestRepairCopper then
            summary.largestRepairCopper = dayTotals.repairCopper
        end
        if dayTotals.hasActivity then
            summary.activeDayCount = summary.activeDayCount + 1
        end
    end

    summary.netCopper = summary.earnedCopper - summary.spentCopper

    return summary
end

function DailySeries:CharacterBalances(store)
    local balances = {}

    for characterKey, characterRecord in pairs(store.characters) do
        balances[#balances + 1] = {
            characterKey = characterKey,
            name = characterRecord.name or characterKey,
            realm = characterRecord.realm or "",
            classFile = characterRecord.classFile,
            currentCopper = characterRecord.currentCopper or 0,
        }
    end

    table.sort(balances, function(left, right)
        if left.currentCopper ~= right.currentCopper then
            return left.currentCopper > right.currentCopper
        end
        return left.characterKey < right.characterKey
    end)

    return balances
end

function DailySeries:TotalCopper(store)
    local total = 0
    for _, characterRecord in pairs(store.characters) do
        total = total + (characterRecord.currentCopper or 0)
    end
    return total
end

function DailySeries:RunSelfCheck()
    local syntheticStore = {
        characters = {
            ["Alpha-Realm"] = {
                currentCopper = 500,
                days = {
                    ["2026-01-01"] = {
                        openingCopper = 0,
                        closingCopper = 500,
                        earnedCopper = 700,
                        spentCopper = 200,
                        repairCopper = 150,
                    },
                },
            },
            ["Beta-Realm"] = {
                currentCopper = 300,
                days = {
                    ["2026-01-01"] = {
                        openingCopper = 100,
                        closingCopper = 300,
                        earnedCopper = 200,
                        spentCopper = 0,
                        repairCopper = 0,
                    },
                },
            },
        },
    }

    local series = self:BuildForDays(syntheticStore, { "2026-01-01", "2026-01-02" })

    assert(series[1].netCopper == 700, "DailySeries sums net across characters: expected 700")
    assert(series[1].closingCopper == 800, "DailySeries sums closing balances across characters: expected 800")
    assert(series[1].repairCopper == 150, "DailySeries sums repairs across characters: expected 150")
    assert(series[2].netCopper == 0, "A day nobody played nets zero")
    assert(
        series[2].closingCopper == 800,
        "A day nobody played carries the previous closing balance forward instead of dropping to zero"
    )
    assert(series[2].hasActivity == false, "A day with no character record is not an active day")

    local summary = self:Summarize(series)
    assert(summary.netCopper == 700, "Summarize nets the whole range")
    assert(summary.activeDayCount == 1, "Summarize counts only days with real activity")

    local balances = self:CharacterBalances(syntheticStore)
    assert(balances[1].characterKey == "Alpha-Realm", "CharacterBalances sorts by gold, richest first")
    assert(self:TotalCopper(syntheticStore) == 800, "TotalCopper sums every character")
end
