local CrestPlanner = _G.CrestPlanner

local Comparison = {}
CrestPlanner.Comparison = Comparison

local INVENTORY_TYPE_TO_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}

local function candidateSlotsFor(itemLink)
    local equipLocation = select(9, C_Item.GetItemInfo(itemLink))
    if not equipLocation then return nil end

    return INVENTORY_TYPE_TO_SLOTS[equipLocation], equipLocation
end

local function upgradeFromTooltipLines(tooltipLines)
    if not tooltipLines then return nil end

    for _, line in ipairs(tooltipLines) do
        local parsed = CrestPlanner.Equipment:ParseUpgradeLine(line.leftText)
        if parsed then return parsed end
    end

    return nil
end

local function crestsToClose(classification, costPerRank)
    if classification.status == "done" then return 0 end
    if classification.status == "upgradeable" then
        return classification.ranksRemaining * costPerRank
    end

    return nil
end

function Comparison:ForCandidate(itemLink, tooltipLines, trackName)
    local crest = CrestPlanner.Crests:Get(trackName)
    if not crest or not crest.ceilingItemLevel then return nil end

    local candidateSlots, equipLocation = candidateSlotsFor(itemLink)
    if not candidateSlots then return nil end

    local candidateItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    if not candidateItemLevel then return nil end

    local costPerRank, costIsObserved = CrestPlanner.UpgradeCost:ForTrack(trackName)

    local candidate = {
        itemLevel = candidateItemLevel,
        upgrade = upgradeFromTooltipLines(tooltipLines),
        label = "candidate",
    }

    local candidateClassification = CrestPlanner.Plan:ClassifySlot(candidate, crest.ceilingItemLevel)
    local candidateCost = crestsToClose(candidateClassification, costPerRank)

    local worstSlot, worstCost, worstClassification = nil, -1, nil

    for _, slotIdentifier in ipairs(candidateSlots) do
        local equipped = CrestPlanner.Equipment:SlotAt(slotIdentifier)

        if not equipped then
            return {
                trackName = trackName,
                crestName = crest.name,
                targetItemLevel = crest.ceilingItemLevel,
                candidateItemLevel = candidateItemLevel,
                candidateCost = candidateCost,
                equipLocation = equipLocation,
                fillsEmptySlot = true,
                slotIdentifier = slotIdentifier,
                slotLabel = CrestPlanner.Equipment.SlotLabels[slotIdentifier],
                costIsObserved = costIsObserved,
            }
        end

        local classification = CrestPlanner.Plan:ClassifySlot(equipped, crest.ceilingItemLevel)
        local cost = crestsToClose(classification, costPerRank)
        local comparableCost = cost or math.huge

        if comparableCost > worstCost then
            worstCost = comparableCost
            worstSlot = equipped
            worstClassification = classification
        end
    end

    if not worstSlot then return nil end

    local currentCost = crestsToClose(worstClassification, costPerRank)

    return {
        trackName = trackName,
        crestName = crest.name,
        targetItemLevel = crest.ceilingItemLevel,
        candidateItemLevel = candidateItemLevel,
        candidateCost = candidateCost,
        candidateStatus = candidateClassification.status,
        currentItemLevel = worstSlot.itemLevel,
        currentCost = currentCost,
        currentStatus = worstClassification.status,
        slotIdentifier = worstSlot.slotIdentifier,
        slotLabel = worstSlot.label,
        equipLocation = equipLocation,
        itemLevelChange = candidateItemLevel - worstSlot.itemLevel,
        crestsSaved = (currentCost and candidateCost) and (currentCost - candidateCost) or nil,
        costIsObserved = costIsObserved,
    }
end

function Comparison:Describe(comparison)
    if not comparison then return nil end

    if comparison.fillsEmptySlot then
        return string.format("Fills your empty %s.", tostring(comparison.slotLabel)), "good"
    end

    local levelChange = comparison.itemLevelChange
    local levelText

    if levelChange > 0 then
        levelText = string.format("+%d over your %s", levelChange, comparison.slotLabel)
    elseif levelChange < 0 then
        levelText = string.format("%d against your %s", levelChange, comparison.slotLabel)
    else
        levelText = string.format("same level as your %s", comparison.slotLabel)
    end

    if comparison.crestsSaved == nil then
        if comparison.candidateStatus == "needsBetterItem" and comparison.currentStatus ~= "needsBetterItem" then
            return string.format(
                "%s, but its track tops out below %d, so it cannot reach the target the way your current piece can.",
                levelText,
                comparison.targetItemLevel
            ), "bad"
        end

        return string.format("%s.", levelText), "neutral"
    end

    if comparison.crestsSaved > 0 then
        return string.format(
            "%s, and saves %d %s on the way to %d.",
            levelText,
            comparison.crestsSaved,
            comparison.crestName,
            comparison.targetItemLevel
        ), "good"
    end

    if comparison.crestsSaved < 0 then
        return string.format(
            "%s, but would cost %d more %s to reach %d.",
            levelText,
            -comparison.crestsSaved,
            comparison.crestName,
            comparison.targetItemLevel
        ), "bad"
    end

    return string.format("%s, same crest cost to reach %d.", levelText, comparison.targetItemLevel), "neutral"
end
