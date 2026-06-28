local ActionBars = {}

function ActionBars:EnableQuickstartBars()
    -- SetActionBarToggles takes positional booleans mapped to specific bars (verified in-game),
    -- and MultiActionBar_Update must run afterward or the change is not applied until a reload.
    SetActionBarToggles(true, true, true, false, false, false, false, "")
    MultiActionBar_Update() ---@diagnostic disable-line: undefined-global
    SetCVar("countdownForCooldowns", 1)
    print("|cFF00FF00[ArtificerEngineering]|r Action bars 1-4 enabled. Cooldown numbers on.")
end

_G.EredarEngineering.ActionBars = ActionBars
