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

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("PLAYER_LOGIN")

bootstrapFrame:SetScript("OnEvent", function(frame)
    assertEveryModuleLoaded()

    TreasuryTimeline.DailySeries:RunSelfCheck()
    TreasuryTimeline.Database:Initialize()
    TreasuryTimeline.Tracker:Initialize()
    TreasuryTimeline.SlashCommands:Initialize()

    frame:UnregisterEvent("PLAYER_LOGIN")
end)
