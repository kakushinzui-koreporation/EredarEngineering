local SpecialVariables = {}


function SpecialVariables:SetEnableFloatingCombatText(booleanEnabledValue)
    SetCVar("enableFloatingCombatText", booleanEnabledValue)
end

function SpecialVariables:DisableFloatingCombatText()
    SetCVar("enableFloatingCombatText", false)
end

_G.EredarEngineering.SpecialVariables = SpecialVariables
