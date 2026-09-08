-- Loads every file the toc lists, in the order the toc lists them, exactly as
-- WoW would. Its whole purpose is to fail when a file reaches for a namespace
-- that a later file creates -- the one class of mistake that is invisible to a
-- syntax check and only surfaces on the loading screen.

local addonRoot = (arg and arg[0] or ""):match("^(.*)verification[/\\][^/\\]*$") or "./"

-- Anything the addon itself defines must behave for real, so that asking for it
-- too early fails here instead of in game. Everything else is a WoW API and is
-- answered permissively, because this harness tests load order, not behaviour.
local OUR_OWN_GLOBALS = {
    EredarEngineering = true,
    EredarEngineeringDB = true,
    TreasuryTimeline = true,
    TreasuryTimelineDB = true,
    CrestPlanner = true,
    CrestPlannerDB = true,
    DragonRacing = true,
}

local function makePermissive()
    return setmetatable({}, {
        __index = function() return makePermissive() end,
        __call = function() return makePermissive() end,
        __newindex = function(tbl, key, value) rawset(tbl, key, value) end,
        __concat = function() return "" end,
        __tostring = function() return "stub" end,
    })
end

setmetatable(_G, {
    __index = function(_, key)
        if OUR_OWN_GLOBALS[key] then return nil end
        return makePermissive()
    end,
})

local tocPath = addonRoot .. "EredarEngineering.toc"
local tocFile = assert(io.open(tocPath, "r"), "cannot open " .. tocPath)

local orderedFiles = {}
for line in tocFile:lines() do
    local trimmed = line:gsub("%s+$", "")
    if trimmed:match("%.lua$") and not trimmed:match("^#") then
        orderedFiles[#orderedFiles + 1] = trimmed:gsub("\\", "/")
    end
end
tocFile:close()

assert(#orderedFiles > 0, "the toc listed no Lua files, so this check would pass vacuously")

local loaded = 0

for _, relativePath in ipairs(orderedFiles) do
    local fullPath = addonRoot .. relativePath
    local chunk, loadError = loadfile(fullPath)

    if not chunk then
        error(string.format("cannot load %s\n  %s", relativePath, tostring(loadError)), 0)
    end

    local succeeded, runtimeError = pcall(chunk)

    if not succeeded then
        error(string.format(
            "%s failed while loading, at toc position %d.\n  %s\n"
                .. "  A file that reaches for a namespace a later file creates belongs after it in the toc.",
            relativePath,
            loaded + 1,
            tostring(runtimeError)
        ), 0)
    end

    loaded = loaded + 1
end

local function assertRegistered(namespaceName, pieceNames)
    local namespace = rawget(_G, namespaceName)
    assert(namespace, namespaceName .. " never came into existence during load")

    for _, pieceName in ipairs(pieceNames) do
        assert(
            rawget(namespace, pieceName) ~= nil,
            namespaceName .. "." .. pieceName .. " is missing after loading every toc file"
        )
    end
end

assertRegistered("TreasuryTimeline", {
    "Formatting", "Database", "DailySeries", "Repairs", "Tracker", "ChartFrame", "SlashCommands",
    "Enable", "Disable",
})

assertRegistered("CrestPlanner", {
    "Crests", "Equipment", "UpgradeCost", "SpendLog", "Commitments",
    "Plan", "Comparison", "Forecast",
    "TooltipHooks", "UpgradeWindowWarning",
    "CurrencyProbe", "AchievementProbe", "EquipmentProbe", "UpgradeProbe", "CraftingOrderProbe",
    "SlashCommands", "Enable", "Disable",
})

assertRegistered("DragonRacing", { "RaceProbe", "RaceDisplay", "Enable", "Disable" })

print(string.format("Load order check passed: %d files loaded in toc order", loaded))
