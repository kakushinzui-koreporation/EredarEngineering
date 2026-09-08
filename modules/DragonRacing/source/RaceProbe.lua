local DragonRacing = _G.DragonRacing

local RaceProbe = {}
DragonRacing.RaceProbe = RaceProbe

local MAXIMUM_CAPTURES = 6
local WHIRLING_SURGE_NAME = "Whirling Surge"

local function everyPlayerAura()
    local auras = {}

    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, filter)
            if not aura then break end

            auras[#auras + 1] = {
                filter = filter,
                name = aura.name,
                spellIdentifier = aura.spellId,
                applications = aura.applications,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
                icon = aura.icon,
            }
        end
    end

    return auras
end

local function everyPowerType()
    local powers = {}

    for powerName, powerValue in pairs(Enum.PowerType) do
        if type(powerValue) == "number" and powerValue >= 0 then
            local current = UnitPower("player", powerValue)
            local maximum = UnitPowerMax("player", powerValue)

            if (current and current > 0) or (maximum and maximum > 0) then
                powers[powerName] = {
                    powerType = powerValue,
                    current = current,
                    maximum = maximum,
                }
            end
        end
    end

    return powers
end

local function glidingState()
    if not C_PlayerInfo or not C_PlayerInfo.GetGlidingInfo then
        return "C_PlayerInfo.GetGlidingInfo is unavailable"
    end

    local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()

    return { isGliding = isGliding, canGlide = canGlide, forwardSpeed = forwardSpeed }
end

local function whirlingSurgeState()
    local findings = {}

    for actionSlot = 1, 180 do
        local actionType, identifier = GetActionInfo(actionSlot)

        if actionType == "spell" and identifier then
            local spellInfo = C_Spell.GetSpellInfo(identifier)

            if spellInfo and spellInfo.name == WHIRLING_SURGE_NAME then
                local cooldown = C_Spell.GetSpellCooldown(identifier)
                local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(identifier)

                findings[#findings + 1] = {
                    actionSlot = actionSlot,
                    spellIdentifier = identifier,
                    cooldown = cooldown and {
                        startTime = cooldown.startTime,
                        duration = cooldown.duration,
                        isEnabled = cooldown.isEnabled,
                    } or "no cooldown table",
                    charges = charges and {
                        currentCharges = charges.currentCharges,
                        maxCharges = charges.maxCharges,
                        cooldownDuration = charges.cooldownDuration,
                    } or "no charges table",
                }
            end
        end
    end

    if #findings == 0 then
        return "Whirling Surge was not found on any action bar slot"
    end

    return findings
end

local function visibleRaceFrames()
    local candidates = {
        "UIWidgetTopCenterContainerFrame",
        "UIWidgetBelowMinimapContainerFrame",
        "UIWidgetPowerBarContainerFrame",
        "ObjectiveTrackerFrame",
        "VehicleSeatIndicator",
    }

    local states = {}

    for _, frameName in ipairs(candidates) do
        local frame = _G[frameName]
        states[frameName] = frame and (frame:IsShown() and "shown" or "hidden") or "does not exist"
    end

    return states
end

function RaceProbe:Capture(reason)
    local store = DragonRacing:Store()
    store.captures = store.captures or {}

    store.captures[#store.captures + 1] = {
        reason = reason,
        capturedAt = date("%Y-%m-%d %H:%M:%S"),
        auras = everyPlayerAura(),
        powers = everyPowerType(),
        gliding = glidingState(),
        whirlingSurge = whirlingSurgeState(),
        frames = visibleRaceFrames(),
    }

    while #store.captures > MAXIMUM_CAPTURES do
        table.remove(store.captures, 1)
    end
end
