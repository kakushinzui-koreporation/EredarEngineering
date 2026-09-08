local _, Addon = ...

_G.EredarEngineering = _G.EredarEngineering or {}

local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("PLAYER_LOGIN")

local BOOTSTRAP_HANDLERS = {}

addonFrame:SetScript("OnEvent", function(self, event, ...)
    BOOTSTRAP_HANDLERS[event](self, ...)
end)

BOOTSTRAP_HANDLERS.PLAYER_LOGIN = function(self)
    EredarEngineering.Modules:StartEnabledModules()
    self:UnregisterEvent("PLAYER_LOGIN")
end

BOOTSTRAP_HANDLERS.ADDON_LOADED = function(self, addonName)
    if addonName ~= "EredarEngineering" then return end

    if type(_G.EredarEngineeringDB) ~= "table" then
        _G.EredarEngineeringDB = {}
    end

    local WoWSettings = Settings

    local settingsCategory = WoWSettings.RegisterVerticalLayoutCategory("Eredar Engineering")
    WoWSettings.RegisterAddOnCategory(settingsCategory)

    local actionBarsButtonInitializer = CreateSettingsButtonInitializer(
        "Action Bars Quickstart",
        "Enable",
        function()
            EredarEngineering.ActionBars:EnableQuickstartBars()
        end,
        "Enables action bars 1-4 and turns on cooldown numbers.",
        true
    )

    local openToolsButtonInitializer = CreateSettingsButtonInitializer(
        "Eredar Engineering Tools",
        "Open",
        function()
            EredarEngineering.EngineeringToolsFrame:Toggle()
        end,
        "Opens the Eredar Engineering Tools panel.",
        true
    )

    local addonLayout = SettingsPanel:GetLayout(settingsCategory) ---@diagnostic disable-line: undefined-global
    addonLayout:AddInitializer(actionBarsButtonInitializer)
    addonLayout:AddInitializer(openToolsButtonInitializer)

    EredarEngineering.ModuleSettingsPanel:Build(settingsCategory)

    self:UnregisterEvent("ADDON_LOADED")
end

function EredarEngineering:CreateModule()
    local module = {}
    module.Meta = {}
    return module
end

-- Deliberate shorthand, not an oversight: the tools panel is opened often
-- enough that two keystrokes earn their obscurity.
SLASH_DEV_COMMAND1 = "/zz"

local function devCommandHandler(msg, editBox)
    EredarEngineering.EngineeringToolsFrame:Toggle()
end

SlashCmdList["DEV_COMMAND"] = devCommandHandler
