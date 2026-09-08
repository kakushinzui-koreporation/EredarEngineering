local DragonRacing = _G.DragonRacing

local RaceProbe = {}
DragonRacing.RaceProbe = RaceProbe

local MAXIMUM_CAPTURES = 24
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

-- WoW hands addon code "secret values" for some powers. They read back fine but
-- comparing one throws, so every reading is isolated: a probe exists to survey
-- unknown ground and must record what it cannot touch instead of dying on it.
local function readPower(powerType)
    local succeeded, current = pcall(UnitPower, "player", powerType)
    if not succeeded then
        return nil, nil, "UnitPower threw: " .. tostring(current)
    end

    local maximumSucceeded, maximum = pcall(UnitPowerMax, "player", powerType)
    if not maximumSucceeded then
        return nil, nil, "UnitPowerMax threw: " .. tostring(maximum)
    end

    local comparable, isWorthKeeping = pcall(function()
        return (current and current > 0) or (maximum and maximum > 0)
    end)

    if not comparable then
        return current, maximum, "secret value, readable but not comparable"
    end

    if not isWorthKeeping then
        return nil, nil, nil
    end

    return current, maximum, nil
end

local function everyPowerType()
    local powers = {}

    for powerName, powerValue in pairs(Enum.PowerType) do
        if type(powerValue) == "number" and powerValue >= 0 then
            local current, maximum, note = readPower(powerValue)

            if current ~= nil or note then
                powers[powerName] = {
                    powerType = powerValue,
                    current = tostring(current),
                    maximum = tostring(maximum),
                    note = note,
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

    local succeeded, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
    if not succeeded then
        return "GetGlidingInfo threw: " .. tostring(isGliding)
    end

    return {
        isGliding = tostring(isGliding),
        canGlide = tostring(canGlide),
        forwardSpeed = tostring(forwardSpeed),
    }
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

-- Power values come back secret and may not track a live value, so the charges
-- of the skyriding spells are the alternative reading: charges are plain
-- numbers. This records every action bar spell that has any, so the one
-- carrying vigor can be identified instead of guessed.
local function everySpellWithCharges()
    local found = {}

    for actionSlot = 1, 180 do
        local actionType, identifier = GetActionInfo(actionSlot)

        if actionType == "spell" and identifier then
            local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(identifier)

            if charges and charges.maxCharges and charges.maxCharges > 0 then
                local spellInfo = C_Spell.GetSpellInfo(identifier)

                found[#found + 1] = {
                    actionSlot = actionSlot,
                    spellIdentifier = identifier,
                    name = spellInfo and spellInfo.name or "unknown",
                    currentCharges = charges.currentCharges,
                    maxCharges = charges.maxCharges,
                    cooldownDuration = charges.cooldownDuration,
                }
            end
        end
    end

    if #found == 0 then
        return "no action bar spell reported charges"
    end

    return found
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

local function guarded(label, reader)
    local succeeded, result = pcall(reader)
    if succeeded then return result end

    return label .. " threw: " .. tostring(result)
end

function RaceProbe:Capture(reason)
    local store = DragonRacing:Store()
    store.captures = store.captures or {}

    store.captures[#store.captures + 1] = {
        reason = reason,
        capturedAt = date("%Y-%m-%d %H:%M:%S"),
        auras = guarded("auras", everyPlayerAura),
        powers = guarded("powers", everyPowerType),
        gliding = guarded("gliding", glidingState),
        whirlingSurge = guarded("whirlingSurge", whirlingSurgeState),
        spellsWithCharges = guarded("spellsWithCharges", everySpellWithCharges),
        frames = guarded("frames", visibleRaceFrames),
    }

    while #store.captures > MAXIMUM_CAPTURES do
        table.remove(store.captures, 1)
    end
end

local MID_RACE_SAMPLE_SECONDS = 3

function RaceProbe:StartMidRaceSampling()
    if self.sampler then return end

    self.sampler = C_Timer.NewTicker(MID_RACE_SAMPLE_SECONDS, function()
        RaceProbe:Capture("midRace")
    end)
end

function RaceProbe:StopMidRaceSampling()
    if not self.sampler then return end

    self.sampler:Cancel()
    self.sampler = nil
end
