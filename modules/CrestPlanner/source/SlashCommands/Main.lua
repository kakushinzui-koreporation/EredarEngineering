local CrestPlanner = _G.CrestPlanner

local SlashCommands = {}
CrestPlanner.SlashCommands = SlashCommands

local PLANNED_TRACK = "Hero"
local MYTH_AVERAGE_TARGET = 331

local PROBES = {
    currencies = function()
        return CrestPlanner.CurrencyProbe, CrestPlanner.CurrencyProbe:Run()
    end,

    achievements = function()
        return CrestPlanner.AchievementProbe, CrestPlanner.AchievementProbe:Run()
    end,

    equipment = function()
        return CrestPlanner.EquipmentProbe, CrestPlanner.EquipmentProbe:Run()
    end,

    upgrade = function()
        return CrestPlanner.UpgradeProbe, CrestPlanner.UpgradeProbe:Run()
    end,

    craftingorders = function()
        return CrestPlanner.CraftingOrderProbe, CrestPlanner.CraftingOrderProbe:Run()
    end,
}

local PROBE_ORDER = { "currencies", "achievements", "equipment", "upgrade", "craftingorders" }

local function splitArguments(message)
    local arguments = {}
    for word in string.gmatch(message or "", "%S+") do
        arguments[#arguments + 1] = string.lower(word)
    end
    return arguments
end

local function runProbe(probeName)
    local probeRunner = PROBES[probeName]
    if not probeRunner then
        CrestPlanner:Print("Unknown probe: " .. tostring(probeName))
        return
    end

    CrestPlanner:Print("|cFFFFFFFF--- " .. probeName .. " ---|r")

    local probeModule, firstResult, secondResult = probeRunner()
    probeModule:PrintSummary(firstResult, secondResult)
end

local function printPlan()
    CrestPlanner.Crests:Refresh()
    CrestPlanner.Equipment:Read()

    local plan = CrestPlanner.Plan:BuildForTrack(PLANNED_TRACK)
    if not plan then
        CrestPlanner:Print("|cFFE05050Could not read the " .. PLANNED_TRACK .. " crest on this client.|r")
        return
    end

    CrestPlanner:Print(string.format(
        "Outgrowing |cFFFFFFFF%s|r means %d in every slot. |cFF40BF40%d done|r, |cFFF29E33%d to go|r.",
        plan.crest.name,
        plan.targetItemLevel,
        plan.slotsDone,
        #plan.upgradeableSlots
    ))

    for spendTrack, shortfall in pairs(plan.shortfallByTrack) do
        CrestPlanner:Print(string.format(
            "%-22s need |cFFFFFFFF%d|r, hold |cFFFFFFFF%d|r, short |cFFF29E33%d|r |cFF909090(%s)|r",
            shortfall.crestName,
            shortfall.required,
            shortfall.held,
            shortfall.short,
            CrestPlanner.UpgradeCost:Describe(spendTrack)
        ))
    end

    for _, entry in ipairs(plan.upgradeableSlots) do
        CrestPlanner:Print(string.format(
            "    |cFF909090%-10s|r %s  |cFFF29E33%d %s|r  %d %s",
            entry.slot.label,
            tostring(entry.slot.itemLevel),
            entry.ranksRemaining,
            entry.ranksRemaining == 1 and "rank" or "ranks",
            entry.crestsForThisSlot,
            entry.spendCrestName
        ))
    end

    for _, entry in ipairs(plan.blockedSlots) do
        CrestPlanner:Print(string.format(
            "    |cFF909090%-10s|r %s  |cFFE05050crests cannot close this slot|r",
            entry.slot.label,
            tostring(entry.slot.itemLevel)
        ))
    end

    local trade = CrestPlanner.Plan:TradeableFromLowerTracks(PLANNED_TRACK)
    if trade and trade.totalPromoted > 0 then
        if trade.blockedByCap then
            CrestPlanner:Print(string.format(
                "|cFF909090Your lower crests are worth about %d here, but trading respects the cap, so none of it lands while you sit at the ceiling.|r",
                trade.totalPromoted
            ))
        else
            CrestPlanner:Print(string.format(
                "Trading lower crests up can fill |cFF40BF40%d|r of the %d still under the cap. |cFF909090Assumes %d:1.|r",
                trade.usableNow,
                trade.remainingEarnable or 0,
                trade.ratio
            ))
        end
    end

    local weeks, increasePerWeek = CrestPlanner.Plan:WeeksOfCapToClose(PLANNED_TRACK, plan.crestsShort)
    if weeks and plan.crestsShort > 0 then
        local _, increaseIsObserved = CrestPlanner.Crests:WeeklyCapIncrease(PLANNED_TRACK)
        CrestPlanner:Print(string.format(
            "At |cFFFFFFFF%d|r of cap per week%s, closing the gap takes |cFFF29E33%d more weeks|r.",
            increasePerWeek,
            increaseIsObserved and "" or " |cFF909090(estimated)|r",
            weeks
        ))
    end

    local currentAverage, averageGap = CrestPlanner.Plan:AverageItemLevelGap(MYTH_AVERAGE_TARGET)
    CrestPlanner:Print(string.format(
        "|cFF909090Average item level %.2f. Myth of the Mist wants %d on average, %.2f short.|r",
        currentAverage,
        MYTH_AVERAGE_TARGET,
        averageGap
    ))
end

local COMMAND_HANDLERS = {}

COMMAND_HANDLERS[""] = printPlan

COMMAND_HANDLERS["probe"] = function(arguments)
    if arguments[2] then
        runProbe(arguments[2])
    else
        for _, probeName in ipairs(PROBE_ORDER) do
            runProbe(probeName)
        end
    end

    CrestPlanner:Print("Run |cFFFFFFFF/reload|r so SavedVariables lands on disk.")
end

COMMAND_HANDLERS["crests"] = function()
    for _, crest in ipairs(CrestPlanner.Crests:Refresh() and CrestPlanner.Crests:Ordered()) do
        local remaining = CrestPlanner.Crests:RemainingEarnableThisSeason(crest.track)

        CrestPlanner:Print(string.format(
            "%-22s |cFFFFFFFF%5d|r held  |cFF909090earned|r %d/%d  %s",
            crest.name,
            crest.quantity,
            crest.totalEarned,
            crest.seasonMaximum,
            remaining == 0 and "|cFFF29E33capped|r" or ("|cFF40BF40" .. tostring(remaining) .. " to go|r")
        ))
    end
end

COMMAND_HANDLERS["commit"] = function(arguments)
    if arguments[2] == "clear" then
        CrestPlanner:Print(string.format("Released %d reservations.", CrestPlanner.Commitments:Clear()))
        return
    end

    local trackName = arguments[2]
    local amount = tonumber(arguments[3])

    if not trackName or not amount then
        CrestPlanner.Commitments:Print()
        return
    end

    local matched = nil
    for _, crest in ipairs(CrestPlanner.Crests:Ordered()) do
        if string.lower(crest.track) == trackName then
            matched = crest.track
        end
    end

    if not matched then
        CrestPlanner:Print("Unknown crest track: " .. tostring(trackName))
        return
    end

    local label = table.concat(arguments, " ", 4)
    CrestPlanner.Commitments:Add(matched, amount, label ~= "" and label or nil)
    CrestPlanner.Commitments:Print()
end

COMMAND_HANDLERS["forecast"] = function()
    CrestPlanner.Crests:Refresh()
    CrestPlanner.Equipment:Read()
    CrestPlanner.Forecast:Print(PLANNED_TRACK)
end

COMMAND_HANDLERS["spent"] = function()
    CrestPlanner.SpendLog:Print(nil)
end

COMMAND_HANDLERS["help"] = function()
    CrestPlanner:Print("|cFFFFFFFF/crestplanner|r prints the plan toward outgrowing " .. PLANNED_TRACK .. " crests.")
    CrestPlanner:Print("|cFFFFFFFF/crestplanner crests|r prints what you hold and what the season cap allows.")
    CrestPlanner:Print("|cFFFFFFFF/crestplanner probe|r re-reads the client and writes it to SavedVariables.")
    CrestPlanner:Print("|cFFFFFFFF/crestplanner forecast|r folds in the Great Vault and projects the weeks left.")
    CrestPlanner:Print("|cFFFFFFFF/crestplanner spent|r shows where your crests went since this build loaded.")
    CrestPlanner:Print("|cFFFFFFFF/crestplanner commit myth 80 ring order|r holds crests back for a pending order.")
    CrestPlanner:Print("Hover any gear, equipped or not, and the tooltip says what it saves you.")
end

function SlashCommands:Initialize()
    SLASH_CREST_PLANNER1 = "/crestplanner"

    SlashCmdList["CREST_PLANNER"] = function(message)
        local arguments = splitArguments(message)
        local handler = COMMAND_HANDLERS[arguments[1] or ""] or COMMAND_HANDLERS["help"]
        handler(arguments)
    end
end
