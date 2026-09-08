local CrestPlanner = _G.CrestPlanner

local UpgradeCost = {}
CrestPlanner.UpgradeCost = UpgradeCost

local ESTIMATED_COST_PER_RANK = 20

UpgradeCost.EstimatedCostPerRank = ESTIMATED_COST_PER_RANK

function UpgradeCost:Store()
    local store = CrestPlanner:GetStore()
    store.observedCostPerRank = store.observedCostPerRank or {}

    return store.observedCostPerRank
end

function UpgradeCost:ForTrack(trackName)
    local observed = self:Store()[trackName]

    if observed then
        return observed.costPerRank, true
    end

    return ESTIMATED_COST_PER_RANK, false
end

function UpgradeCost:Describe(trackName)
    local costPerRank, isObserved = self:ForTrack(trackName)

    if isObserved then
        return string.format("%d per rank", costPerRank)
    end

    return string.format("%d per rank |cFF909090(estimated, not yet seen)|r", costPerRank)
end

function UpgradeCost:Record(trackName, costPerRank, spentCrestName)
    assert(
        costPerRank > 0,
        "A recorded upgrade cost must be positive; a zero or negative cost would mean the snapshot"
            .. " comparison matched the wrong pair of events"
    )

    self:Store()[trackName] = {
        costPerRank = costPerRank,
        crestName = spentCrestName,
        observedAt = date("%Y-%m-%d %H:%M:%S"),
    }

    CrestPlanner:Print(string.format(
        "Learned the real cost: |cFFFFFFFF%d %s|r per %s rank. Estimates replaced with the measurement.",
        costPerRank,
        tostring(spentCrestName),
        trackName
    ))
end

local function crestQuantitySnapshot()
    local snapshot = {}

    for _, crest in ipairs(CrestPlanner.Crests:Refresh() and CrestPlanner.Crests:Ordered()) do
        snapshot[crest.track] = { quantity = crest.quantity, totalEarned = crest.totalEarned }
    end

    return snapshot
end

local function singleRankGain(previousRanks, currentRanks)
    local gainedSlot, gainedTrack, gainedRanks = nil, nil, 0
    local changeCount = 0

    for slotIdentifier, current in pairs(currentRanks) do
        local previous = previousRanks[slotIdentifier]

        if previous and previous.track == current.track and current.currentRank > previous.currentRank then
            changeCount = changeCount + 1
            gainedSlot = slotIdentifier
            gainedTrack = current.track
            gainedRanks = current.currentRank - previous.currentRank
        elseif previous and previous.currentRank ~= current.currentRank then
            changeCount = changeCount + 1
        end
    end

    if changeCount ~= 1 or not gainedTrack then return nil end

    return gainedTrack, gainedRanks, gainedSlot
end

local function singleCrestDrop(previousQuantities, currentQuantities)
    local droppedTrack, droppedAmount = nil, 0
    local changeCount = 0

    for trackName, current in pairs(currentQuantities) do
        local previous = previousQuantities[trackName]

        if previous and current.quantity < previous.quantity then
            changeCount = changeCount + 1
            droppedTrack = trackName
            droppedAmount = previous.quantity - current.quantity
        end
    end

    if changeCount ~= 1 then return nil end

    return droppedTrack, droppedAmount
end

function UpgradeCost:TakeSnapshot()
    self.previousRanks = CrestPlanner.Equipment:RankSnapshot()
    self.previousQuantities = crestQuantitySnapshot()
end

function UpgradeCost:ReconcileAgainstSnapshot()
    if not self.previousRanks or not self.previousQuantities then
        self:TakeSnapshot()
        return
    end

    local currentRanks = CrestPlanner.Equipment:RankSnapshot()
    local currentQuantities = crestQuantitySnapshot()

    local gainedTrack, gainedRanks = singleRankGain(self.previousRanks, currentRanks)
    local droppedTrack, droppedAmount = singleCrestDrop(self.previousQuantities, currentQuantities)

    for trackName, current in pairs(currentQuantities) do
        local previous = self.previousQuantities[trackName]
        if previous then
            CrestPlanner.SpendLog:NoteChange(
                trackName,
                current.quantity - previous.quantity,
                current.totalEarned - previous.totalEarned
            )
        end
    end

    self.previousRanks = currentRanks
    self.previousQuantities = currentQuantities

    if not gainedTrack or not droppedTrack then return end
    if gainedRanks <= 0 then return end

    local costPerRank = droppedAmount / gainedRanks
    if costPerRank ~= math.floor(costPerRank) then return end

    local spentCrest = CrestPlanner.Crests:Get(droppedTrack)
    self:Record(gainedTrack, costPerRank, spentCrest and spentCrest.name or droppedTrack)
end
