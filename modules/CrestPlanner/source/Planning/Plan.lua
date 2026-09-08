local CrestPlanner = _G.CrestPlanner

local Plan = {}
CrestPlanner.Plan = Plan

local function trackCeilingFor(trackName)
    local crest = CrestPlanner.Crests:Get(trackName)

    return crest and crest.ceilingItemLevel or nil
end

function Plan:ClassifySlot(slot, targetItemLevel)
    if not slot.itemLevel then
        return { status = "unknown", slot = slot }
    end

    local reach = math.max(slot.itemLevel, slot.watermark or 0)

    if reach >= targetItemLevel then
        return { status = "done", slot = slot }
    end

    if not slot.upgrade then
        return { status = "notUpgradeable", slot = slot }
    end

    local ceiling = trackCeilingFor(slot.upgrade.track)
    local ranksRemaining = slot.upgrade.maximumRank - slot.upgrade.currentRank

    if ceiling and ceiling < targetItemLevel then
        return { status = "needsBetterItem", slot = slot, ceiling = ceiling, ranksRemaining = ranksRemaining }
    end

    local itemLevelPerRank = ranksRemaining > 0 and ceiling
        and ((ceiling - slot.itemLevel) / ranksRemaining) or nil

    local ranksToTarget = ranksRemaining
    if itemLevelPerRank and itemLevelPerRank > 0 then
        ranksToTarget = math.min(
            ranksRemaining,
            math.ceil((targetItemLevel - slot.itemLevel) / itemLevelPerRank)
        )
    end

    local spendTrack = slot.upgrade.track
    local spendCrest = CrestPlanner.Crests:Get(spendTrack)
    local costPerRank, costIsObserved = CrestPlanner.UpgradeCost:ForTrack(spendTrack)

    return {
        status = "upgradeable",
        slot = slot,
        ceiling = ceiling,
        ranksRemaining = ranksToTarget,
        ranksToTrackCeiling = ranksRemaining,
        itemLevelPerRank = itemLevelPerRank,
        spendTrack = spendTrack,
        spendCrestName = spendCrest and spendCrest.name or spendTrack,
        costPerRank = costPerRank,
        costIsObserved = costIsObserved,
        crestsForThisSlot = ranksToTarget * costPerRank,
    }
end

function Plan:BuildForTrack(trackName)
    local crest = CrestPlanner.Crests:Get(trackName)
    if not crest or not crest.ceilingItemLevel then return nil end

    local targetItemLevel = crest.ceilingItemLevel
    local costPerRank, costIsObserved = CrestPlanner.UpgradeCost:ForTrack(trackName)

    local plan = {
        track = trackName,
        crest = crest,
        targetItemLevel = targetItemLevel,
        costPerRank = costPerRank,
        costIsObserved = costIsObserved,
        slotsDone = 0,
        ranksRemaining = 0,
        blockedSlots = {},
        upgradeableSlots = {},
        requiredByTrack = {},
    }

    for _, slot in pairs(CrestPlanner.Equipment:SlotsByRedundancy()) do
        local classification = self:ClassifySlot(slot, targetItemLevel)

        if classification.status == "done" then
            plan.slotsDone = plan.slotsDone + 1
        elseif classification.status == "upgradeable" then
            plan.upgradeableSlots[#plan.upgradeableSlots + 1] = classification
            plan.ranksRemaining = plan.ranksRemaining + classification.ranksRemaining

            local spendTrack = classification.spendTrack
            plan.requiredByTrack[spendTrack] =
                (plan.requiredByTrack[spendTrack] or 0) + classification.crestsForThisSlot
        elseif classification.status ~= "unknown" then
            plan.blockedSlots[#plan.blockedSlots + 1] = classification
        end
    end

    plan.shortfallByTrack = {}
    plan.crestsRequired = 0

    for spendTrack, required in pairs(plan.requiredByTrack) do
        local spendCrest = CrestPlanner.Crests:Get(spendTrack)
        local free, held, reserved = CrestPlanner.Commitments:FreeQuantity(spendTrack)

        plan.shortfallByTrack[spendTrack] = {
            crestName = spendCrest and spendCrest.name or spendTrack,
            required = required,
            held = held,
            reserved = reserved,
            free = free,
            short = math.max(0, required - free),
        }

        plan.crestsRequired = plan.crestsRequired + required
    end

    plan.crestsHeld = crest.quantity
    plan.crestsShort = math.max(0, (plan.requiredByTrack[trackName] or 0) - plan.crestsHeld)
    plan.stillEarnableThisSeason = CrestPlanner.Crests:RemainingEarnableThisSeason(trackName)
    plan.outlook = Plan:Outlook(plan)

    return plan
end

function Plan:Outlook(plan)
    if #plan.upgradeableSlots > 0 then
        return "actionable"
    end

    if #plan.blockedSlots > 0 then
        return "blocked"
    end

    return "complete"
end

function Plan:PlanForSlot(slotIdentifier, trackName)
    local slot = CrestPlanner.Equipment:SlotAt(slotIdentifier)
    if not slot then return nil end

    local crest = CrestPlanner.Crests:Get(trackName)
    if not crest or not crest.ceilingItemLevel then return nil end

    local classification = self:ClassifySlot(slot, crest.ceilingItemLevel)

    classification.targetItemLevel = crest.ceilingItemLevel
    classification.targetCrestName = crest.name
    classification.crestName = classification.spendCrestName or crest.name

    return classification
end

function Plan:AverageItemLevelGap(targetAverage)
    local currentAverage = CrestPlanner.Equipment:AverageItemLevel()

    return currentAverage, math.max(0, targetAverage - currentAverage)
end

function Plan:TradeableFromLowerTracks(targetTrackName)
    local TRADE_RATIO = 3
    local order = { "Adventurer", "Veteran", "Champion", "Hero", "Myth" }

    local targetIndex = nil
    for index, trackName in ipairs(order) do
        if trackName == targetTrackName then
            targetIndex = index
        end
    end

    if not targetIndex or targetIndex == 1 then return nil end

    local carried = 0
    local steps = {}

    for index = 1, targetIndex - 1 do
        local crest = CrestPlanner.Crests:Get(order[index])
        local available = (crest and crest.quantity or 0) + carried
        local promoted = math.floor(available / TRADE_RATIO)

        steps[#steps + 1] = {
            fromTrack = order[index],
            toTrack = order[index + 1],
            available = available,
            promoted = promoted,
        }

        carried = promoted
    end

    local remainingEarnable = CrestPlanner.Crests:RemainingEarnableThisSeason(targetTrackName)

    return {
        ratio = TRADE_RATIO,
        steps = steps,
        totalPromoted = carried,
        remainingEarnable = remainingEarnable,
        usableNow = remainingEarnable and math.min(carried, remainingEarnable) or carried,
        blockedByCap = remainingEarnable == 0,
        ratioIsVerified = false,
    }
end

function Plan:WeeksOfCapToClose(trackName, crestsShort)
    local increasePerWeek = CrestPlanner.Crests:WeeklyCapIncrease(trackName)
    if not increasePerWeek or increasePerWeek <= 0 then return nil end

    return math.ceil(crestsShort / increasePerWeek), increasePerWeek
end
