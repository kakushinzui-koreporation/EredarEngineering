local Warband = {}

local TOTAL_ACTION_SLOTS = 120

function Warband:ClearAllActionBars()
    for slot = 1, TOTAL_ACTION_SLOTS do
        local actionType = GetActionInfo(slot) ---@diagnostic disable-line: undefined-global
        if actionType then
            PickupAction(slot) ---@diagnostic disable-line: undefined-global
            ClearCursor() ---@diagnostic disable-line: undefined-global
        end
    end
    print("|cFF00FF00[ArtificerEngineering]|r All action bars cleared.")
end

_G.EredarEngineering.Warband = Warband
