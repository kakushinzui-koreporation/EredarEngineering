local Registry = EredarEngineering:CreateModule()

_G.EredarEngineering.Modules = Registry

local MODULE_ORDER = {
    {
        key = "treasuryTimeline",
        title = "Treasury Timeline",
        description = "Records how much gold each character gains or loses per day and separates"
            .. " what repairs cost you. The week starts at the realm reset. Type /treasury.",
    },
    {
        key = "crestPlanner",
        title = "Crest Planner",
        description = "Works out how many Mistcrests separate you from the of-the-Mist"
            .. " achievements, reading every threshold from the client. Adds lines to gear and"
            .. " crest tooltips. Type /crestplanner.",
    },
}

Registry.Order = MODULE_ORDER

local implementations = {}

function Registry:Definition(moduleKey)
    for _, definition in ipairs(MODULE_ORDER) do
        if definition.key == moduleKey then
            return definition
        end
    end

    return nil
end

function Registry:Register(moduleKey, implementation)
    assert(
        self:Definition(moduleKey),
        "Module '" .. tostring(moduleKey) .. "' registered itself but has no entry in MODULE_ORDER,"
            .. " so no settings checkbox would ever appear for it"
    )
    assert(
        type(implementation.Enable) == "function" and type(implementation.Disable) == "function",
        "Module '" .. tostring(moduleKey) .. "' must expose both Enable and Disable; a module that"
            .. " cannot be switched off does not belong in a registry built to switch modules off"
    )

    implementations[moduleKey] = implementation
end

function Registry:Store()
    local database = _G.EredarEngineeringDB
    database.modules = database.modules or {}

    return database.modules
end

function Registry:IsEnabled(moduleKey)
    return self:Store()[moduleKey] == true
end

function Registry:SetEnabled(moduleKey, shouldEnable)
    local implementation = implementations[moduleKey]
    if not implementation then return false end

    self:Store()[moduleKey] = shouldEnable and true or false

    if shouldEnable then
        implementation:Enable()
    else
        implementation:Disable()
    end

    return true
end

function Registry:StartEnabledModules()
    for _, definition in ipairs(MODULE_ORDER) do
        local implementation = implementations[definition.key]

        if implementation and self:IsEnabled(definition.key) then
            implementation:Enable()
        end
    end
end

function Registry:IsRegistered(moduleKey)
    return implementations[moduleKey] ~= nil
end
