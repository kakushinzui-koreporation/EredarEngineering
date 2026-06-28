local Controls = {}

function Controls:GetAutoLootSetting()
    return GetCVar("autoLootDefault")
end

_G.EredarEngineering.Controls = Controls
