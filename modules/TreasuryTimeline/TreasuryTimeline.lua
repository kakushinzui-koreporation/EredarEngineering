local ADDON_NAME = "TreasuryTimeline"

_G.TreasuryTimeline = _G.TreasuryTimeline or {}

local TreasuryTimeline = _G.TreasuryTimeline

TreasuryTimeline.Name = ADDON_NAME
TreasuryTimeline.ChatPrefix = "|cFFFFD100[Treasury]|r "

function TreasuryTimeline:Print(message)
    print(self.ChatPrefix .. message)
end

local REQUIRED_MODULES = {
    "Formatting",
    "Database",
    "DailySeries",
    "Repairs",
    "Tracker",
    "ChartFrame",
    "SlashCommands",
}

local function assertEveryModuleLoaded()
    for _, moduleName in ipairs(REQUIRED_MODULES) do
        assert(
            TreasuryTimeline[moduleName],
            ADDON_NAME .. " module missing: " .. moduleName
                .. " -- check its entry and load order in TreasuryTimeline.toc"
        )
    end
end

function TreasuryTimeline:Enable()
    if self.enabled then return end

    assertEveryModuleLoaded()

    self.DailySeries:RunSelfCheck()
    self.Database:Initialize()
    self.Tracker:Initialize()
    self.SlashCommands:Initialize()

    self.enabled = true
end

function TreasuryTimeline:Disable()
    if not self.enabled then return end

    self.Tracker:Stop()
    self.ChartFrame:Hide()

    self.enabled = false
end

EredarEngineering.Modules:Register("treasuryTimeline", TreasuryTimeline)
