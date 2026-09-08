local SettingsPanel = EredarEngineering:CreateModule()

_G.EredarEngineering.ModuleSettingsPanel = SettingsPanel

local VARIABLE_PREFIX = "EredarEngineeringModule_"

local function createModuleCheckbox(category, definition)
    local Registry = EredarEngineering.Modules
    local variableName = VARIABLE_PREFIX .. definition.key

    local setting = Settings.RegisterProxySetting(
        category,
        variableName,
        type(false),
        definition.title,
        false,
        function()
            return Registry:IsEnabled(definition.key)
        end,
        function(shouldEnable)
            Registry:SetEnabled(definition.key, shouldEnable)
        end
    )

    local tooltipText = definition.description

    if not Registry:IsRegistered(definition.key) then
        tooltipText = tooltipText .. "\n\n|cFFE05050This module failed to load, so the switch does nothing.|r"
    end

    Settings.CreateCheckbox(category, setting, tooltipText)

    return setting
end

function SettingsPanel:Build(category)
    assert(
        Settings and Settings.RegisterProxySetting and Settings.CreateCheckbox,
        "The Settings API is missing RegisterProxySetting or CreateCheckbox on this client, so the"
            .. " module switches cannot be drawn and every module would be stuck at its saved state"
    )

    for _, definition in ipairs(EredarEngineering.Modules.Order) do
        createModuleCheckbox(category, definition)
    end
end
