local ADDON_NAME = "CrestPlanner"

_G.CrestPlanner = _G.CrestPlanner or {}

local CrestPlanner = _G.CrestPlanner

CrestPlanner.Name = ADDON_NAME
CrestPlanner.ChatPrefix = "|cFF8B5CF6[CrestPlanner]|r "

function CrestPlanner:Print(message)
    print(self.ChatPrefix .. message)
end

local REQUIRED_MODULES = {
    "Crests",
    "Equipment",
    "UpgradeCost",
    "Plan",
    "Comparison",
    "Forecast",
    "SpendLog",
    "Commitments",
    "TooltipHooks",
    "UpgradeWindowWarning",
    "CurrencyProbe",
    "AchievementProbe",
    "EquipmentProbe",
    "UpgradeProbe",
    "CraftingOrderProbe",
    "SlashCommands",
}

local function assertEveryModuleLoaded()
    for _, moduleName in ipairs(REQUIRED_MODULES) do
        assert(
            CrestPlanner[moduleName],
            ADDON_NAME .. " module missing: " .. moduleName
                .. " -- check its entry and load order in CrestPlanner.toc"
        )
    end
end

function CrestPlanner:InitializeStore()
    if type(_G.CrestPlannerDB) ~= "table" then
        _G.CrestPlannerDB = {}
    end

    local store = _G.CrestPlannerDB
    store.probes = store.probes or {}
    store.observedCostPerRank = store.observedCostPerRank or {}

    self.store = store
end

function CrestPlanner:GetStore()
    return self.store
end

function CrestPlanner:RecordProbe(probeName, payload)
    local characterName, realmName = UnitFullName("player")
    if not realmName or realmName == "" then
        realmName = GetNormalizedRealmName()
    end

    self.store.probes[probeName] = {
        capturedAt = date("%Y-%m-%d %H:%M:%S"),
        character = tostring(characterName) .. "-" .. tostring(realmName),
        clientBuild = select(4, GetBuildInfo()),
        payload = payload,
    }
end

local WATCHED_EVENTS = {
    "CURRENCY_DISPLAY_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED",
}

local function installCostLearner()
    CrestPlanner.UpgradeCost:TakeSnapshot()

    local learnerFrame = CreateFrame("Frame")
    for _, eventName in ipairs(WATCHED_EVENTS) do
        learnerFrame:RegisterEvent(eventName)
    end

    learnerFrame:SetScript("OnEvent", function()
        CrestPlanner.UpgradeCost:ReconcileAgainstSnapshot()
        CrestPlanner.UpgradeWindowWarning:Refresh()
    end)

    CrestPlanner.costLearnerFrame = learnerFrame
end

function CrestPlanner:Enable()
    if self.enabled then return end

    assertEveryModuleLoaded()

    self:InitializeStore()
    self.Crests:Refresh()
    self.Crests:WarnIfSeedsDrifted()
    self.Crests:RecordSeasonMaximums()
    self.Equipment:Read()

    self.TooltipHooks:Initialize()
    self.UpgradeWindowWarning:Initialize()
    self.SlashCommands:Initialize()

    installCostLearner()

    self.enabled = true
end

function CrestPlanner:Disable()
    if not self.enabled then return end

    if self.costLearnerFrame then
        self.costLearnerFrame:UnregisterAllEvents()
        self.costLearnerFrame:SetScript("OnEvent", nil)
        self.costLearnerFrame = nil
    end

    self.enabled = false
end

EredarEngineering.Modules:Register("crestPlanner", CrestPlanner)
