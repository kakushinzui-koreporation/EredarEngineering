local CrestPlanner = _G.CrestPlanner

local AchievementProbe = {}
CrestPlanner.AchievementProbe = AchievementProbe

local KNOWN_MIST_ACHIEVEMENTS = {
    [62410] = "Adventurer of the Mist",
    [62411] = "Veteran of the Mist",
    [62412] = "Champion of the Mist",
    [62414] = "Hero of the Mist",
}

local SEARCH_RANGE_START = 62405
local SEARCH_RANGE_END = 62425

local function describeCriteria(achievementIdentifier)
    local criteriaCount = GetAchievementNumCriteria(achievementIdentifier) or 0
    local criteria = {}

    for index = 1, criteriaCount do
        local description, criteriaType, completed, quantity, requiredQuantity,
            characterName, flags, assetIdentifier, quantityString, criteriaIdentifier =
                GetAchievementCriteriaInfo(achievementIdentifier, index)

        criteria[index] = {
            description = description,
            criteriaType = criteriaType,
            completed = completed,
            quantity = quantity,
            requiredQuantity = requiredQuantity,
            characterName = characterName,
            flags = flags,
            assetIdentifier = assetIdentifier,
            quantityString = quantityString,
            criteriaIdentifier = criteriaIdentifier,
        }
    end

    return criteriaCount, criteria
end

local function describeAchievement(achievementIdentifier)
    local identifier, name, points, completed, month, day, year, description,
        flags, icon, rewardText, isGuild, workingOnIt, earnedBy =
            GetAchievementInfo(achievementIdentifier)

    if not identifier then return nil end

    local criteriaCount, criteria = describeCriteria(achievementIdentifier)

    return {
        achievementIdentifier = identifier,
        name = name,
        points = points,
        completed = completed,
        completedOn = completed and string.format("%s/%s/%s", tostring(month), tostring(day), tostring(year)) or nil,
        description = description,
        flags = flags,
        rewardText = rewardText,
        isGuild = isGuild,
        workingOnIt = workingOnIt,
        earnedBy = earnedBy,
        criteriaCount = criteriaCount,
        criteria = criteria,
    }
end

function AchievementProbe:Run()
    assert(
        type(GetAchievementCriteriaInfo) == "function",
        "GetAchievementCriteriaInfo is missing on this client -- there is no way to read whether the"
            .. " of-the-Mist achievements track one average or one criterion per equipment slot, which"
            .. " is the single question this probe exists to answer"
    )

    local found = {}

    for achievementIdentifier = SEARCH_RANGE_START, SEARCH_RANGE_END do
        local details = describeAchievement(achievementIdentifier)

        if details then
            local expectedName = KNOWN_MIST_ACHIEVEMENTS[achievementIdentifier]
            details.expectedName = expectedName
            details.nameMatchesExpectation = expectedName == nil or expectedName == details.name

            found[#found + 1] = details
        end
    end

    CrestPlanner:RecordProbe("achievements", {
        searchRangeStart = SEARCH_RANGE_START,
        searchRangeEnd = SEARCH_RANGE_END,
        results = found,
    })

    return found
end

function AchievementProbe:PrintSummary(found)
    for _, details in ipairs(found) do
        local isOfTheMist = details.name and string.find(details.name, "of the Mist")

        if isOfTheMist then
            CrestPlanner:Print(string.format(
                "|cFFFFFFFF%d|r %s  |cFF909090criteria|r %d  |cFF909090done|r %s",
                details.achievementIdentifier,
                tostring(details.name),
                details.criteriaCount,
                tostring(details.completed)
            ))

            for index = 1, math.min(details.criteriaCount, 3) do
                local criterion = details.criteria[index]
                CrestPlanner:Print(string.format(
                    "    |cFF909090%d.|r %s  |cFF909090%s/%s|r  type %s",
                    index,
                    tostring(criterion.description),
                    tostring(criterion.quantity),
                    tostring(criterion.requiredQuantity),
                    tostring(criterion.criteriaType)
                ))
            end

            if details.criteriaCount > 3 then
                CrestPlanner:Print(string.format(
                    "    |cFF909090... %d more criteria, all captured to SavedVariables|r",
                    details.criteriaCount - 3
                ))
            end
        end
    end

    CrestPlanner:Print(string.format("Captured %d achievements in the search range.", #found))
end
