local CrestPlanner = _G.CrestPlanner

local SpendLog = {}
CrestPlanner.SpendLog = SpendLog

local MAXIMUM_ENTRIES = 200

local CAUSE_DETECTORS = {
    {
        cause = "upgrade",
        isActive = function()
            return _G.ItemUpgradeFrame ~= nil and _G.ItemUpgradeFrame:IsShown()
        end,
    },
    {
        cause = "crafting",
        isActive = function()
            return _G.ProfessionsFrame ~= nil and _G.ProfessionsFrame:IsShown()
        end,
    },
    {
        cause = "crestTrade",
        isActive = function()
            return _G.MerchantFrame ~= nil and _G.MerchantFrame:IsShown()
        end,
    },
}

local function detectCause()
    for _, detector in ipairs(CAUSE_DETECTORS) do
        if detector.isActive() then
            return detector.cause
        end
    end

    return "unknown"
end

function SpendLog:Entries()
    local store = CrestPlanner:GetStore()
    store.spendLog = store.spendLog or {}

    return store.spendLog
end

function SpendLog:Record(trackName, amount, cause)
    local entries = self:Entries()

    entries[#entries + 1] = {
        recordedAt = date("%Y-%m-%d %H:%M:%S"),
        dayKey = date("%Y-%m-%d"),
        track = trackName,
        amount = amount,
        cause = cause or detectCause(),
    }

    while #entries > MAXIMUM_ENTRIES do
        table.remove(entries, 1)
    end
end

function SpendLog:NoteChange(trackName, delta, earnedDelta)
    if delta == 0 then return end

    if delta < 0 then
        self:Record(trackName, -delta, detectCause())
        return
    end

    local countedAgainstCap = earnedDelta ~= nil and earnedDelta > 0
    local cause = countedAgainstCap and "gainCounted" or "gainOverCap"

    self:Record(trackName, delta, cause)

    if not countedAgainstCap then
        CrestPlanner:Print(string.format(
            "|cFF40BF40%d %s arrived without touching the season cap.|r |cFF909090Total earned stayed"
                .. " put, so this came from an uncapped source.|r",
            delta,
            trackName
        ))
    end
end

function SpendLog:TotalsByCause(trackName)
    local totals = {}

    for _, entry in ipairs(self:Entries()) do
        if not trackName or entry.track == trackName then
            totals[entry.cause] = (totals[entry.cause] or 0) + entry.amount
        end
    end

    return totals
end

function SpendLog:Print(trackName)
    local totals = self:TotalsByCause(trackName)
    local causes = {}

    for cause in pairs(totals) do
        causes[#causes + 1] = cause
    end
    table.sort(causes)

    if #causes == 0 then
        CrestPlanner:Print(
            "Nothing recorded yet. The log starts from the moment this build loaded, so it cannot"
                .. " explain crests spent before today."
        )
        return
    end

    for _, cause in ipairs(causes) do
        CrestPlanner:Print(string.format(
            "|cFF909090%-12s|r %d",
            cause,
            totals[cause]
        ))
    end
end
