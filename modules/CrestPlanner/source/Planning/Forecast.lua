local CrestPlanner = _G.CrestPlanner

local Forecast = {}
CrestPlanner.Forecast = Forecast

local function weeklyRewardsAvailable()
    return C_WeeklyRewards ~= nil and C_WeeklyRewards.GetActivities ~= nil
end

function Forecast:GreatVaultRewards()
    if not weeklyRewardsAvailable() then
        return nil, "C_WeeklyRewards.GetActivities is unavailable on this client"
    end

    local rewards = {}

    for _, activity in ipairs(C_WeeklyRewards.GetActivities()) do
        local isUnlocked = activity.progress and activity.threshold
            and activity.progress >= activity.threshold

        if isUnlocked then
            local itemLevel = nil
            if C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                local hyperlink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
                if hyperlink then
                    itemLevel = C_Item.GetDetailedItemLevelInfo(hyperlink)
                end
            end

            rewards[#rewards + 1] = {
                activityIdentifier = activity.id,
                activityType = activity.type,
                level = activity.level,
                itemLevel = itemLevel,
            }
        end
    end

    return rewards, nil
end

function Forecast:SlotsClosedByRewards(rewards, trackName)
    local crest = CrestPlanner.Crests:Get(trackName)
    if not crest or not crest.ceilingItemLevel then return 0 end

    local closed = 0

    for _, reward in ipairs(rewards or {}) do
        if reward.itemLevel and reward.itemLevel >= crest.ceilingItemLevel then
            closed = closed + 1
        end
    end

    return closed
end

function Forecast:Build(trackName)
    local plan = CrestPlanner.Plan:BuildForTrack(trackName)
    if not plan then return nil end

    local rewards, rewardProblem = self:GreatVaultRewards()
    local costPerRank = plan.costPerRank

    local forecast = {
        plan = plan,
        rewards = rewards,
        rewardProblem = rewardProblem,
        slotsClosedByVault = self:SlotsClosedByRewards(rewards, trackName),
    }

    local crestsAvoided = 0
    if forecast.slotsClosedByVault > 0 and #plan.upgradeableSlots > 0 then
        local averageRanksPerSlot = plan.ranksRemaining / #plan.upgradeableSlots
        local slotsActuallyClosed = math.min(forecast.slotsClosedByVault, #plan.upgradeableSlots)
        crestsAvoided = math.floor(slotsActuallyClosed * averageRanksPerSlot * costPerRank + 0.5)
    end

    forecast.crestsAvoidedByVault = crestsAvoided
    forecast.crestsShortAfterVault = math.max(0, plan.crestsShort - crestsAvoided)

    local weeks, increasePerWeek = CrestPlanner.Plan:WeeksOfCapToClose(
        trackName,
        forecast.crestsShortAfterVault
    )

    forecast.weeksRemaining = weeks
    forecast.capIncreasePerWeek = increasePerWeek

    return forecast
end

function Forecast:Print(trackName)
    local forecast = self:Build(trackName)
    if not forecast then
        CrestPlanner:Print("|cFFE05050Could not build a forecast for " .. trackName .. ".|r")
        return
    end

    local plan = forecast.plan

    if forecast.rewardProblem then
        CrestPlanner:Print("|cFF909090Great Vault: " .. forecast.rewardProblem .. "|r")
    elseif not forecast.rewards or #forecast.rewards == 0 then
        CrestPlanner:Print("|cFF909090Great Vault: nothing unlocked yet this week.|r")
    else
        CrestPlanner:Print(string.format(
            "Great Vault has |cFFFFFFFF%d|r rewards unlocked, |cFF40BF40%d|r of them at or above %d.",
            #forecast.rewards,
            forecast.slotsClosedByVault,
            plan.targetItemLevel
        ))
    end

    if forecast.crestsAvoidedByVault > 0 then
        CrestPlanner:Print(string.format(
            "Taking those would avoid roughly |cFF40BF40%d|r %s, leaving you |cFFF29E33%d|r short instead of %d.",
            forecast.crestsAvoidedByVault,
            plan.crest.name,
            forecast.crestsShortAfterVault,
            plan.crestsShort
        ))
    end

    if forecast.weeksRemaining then
        CrestPlanner:Print(string.format(
            "At |cFFFFFFFF%d|r of cap per week, that is |cFFF29E33%d weeks|r to outgrow %s.",
            forecast.capIncreasePerWeek,
            forecast.weeksRemaining,
            plan.crest.name
        ))
    end

    CrestPlanner:Print(
        "|cFF909090A pending crafting order is not counted -- the client exposes no reliable way to"
            .. " read what it will produce before it lands.|r"
    )
end
