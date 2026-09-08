local DragonRacing = _G.DragonRacing

local RaceDisplay = {}
DragonRacing.RaceDisplay = RaceDisplay

local WHIRLING_SURGE_NAME = "Whirling Surge"
local UPDATE_INTERVAL_SECONDS = 0.1

local READY_COLOR = { 0.35, 0.85, 0.45 }
local COOLING_COLOR = { 0.95, 0.62, 0.20 }
local CHARGE_COLOR = { 0.85, 0.90, 1.00 }
local EMPTY_COLOR = { 0.90, 0.35, 0.35 }

-- Vigor is the shared charge pool behind the skyriding movement spells, not a
-- unit power. Measured across a live race on 2026-09-08: these drained 6 to 0
-- together while power type 25 sat frozen at its own maximum of 3, which was
-- the number the panel had been showing all along.
local VIGOR_SPELL_NAMES = { "Skyward Ascent", "Surge Forward" }

local function findWhirlingSurge()
    local store = DragonRacing:Store()

    if store.whirlingSurgeIdentifier then
        return store.whirlingSurgeIdentifier
    end

    for actionSlot = 1, 180 do
        local actionType, identifier = GetActionInfo(actionSlot)

        if actionType == "spell" and identifier then
            local spellInfo = C_Spell.GetSpellInfo(identifier)

            if spellInfo and spellInfo.name == WHIRLING_SURGE_NAME then
                store.whirlingSurgeIdentifier = identifier
                DragonRacing:Print(string.format(
                    "Learned %s: spell |cFFFFFFFF%d|r.",
                    WHIRLING_SURGE_NAME,
                    identifier
                ))
                return identifier
            end
        end
    end

    return nil
end

local function findVigorSpell()
    local store = DragonRacing:Store()

    if store.vigorSpellIdentifier then
        return store.vigorSpellIdentifier
    end

    for actionSlot = 1, 180 do
        local actionType, identifier = GetActionInfo(actionSlot)

        if actionType == "spell" and identifier then
            local spellInfo = C_Spell.GetSpellInfo(identifier)

            if spellInfo then
                for _, candidateName in ipairs(VIGOR_SPELL_NAMES) do
                    if spellInfo.name == candidateName then
                        store.vigorSpellIdentifier = identifier
                        DragonRacing:Print(string.format(
                            "Learned vigor from %s: spell |cFFFFFFFF%d|r.",
                            candidateName,
                            identifier
                        ))
                        return identifier
                    end
                end
            end
        end
    end

    return nil
end

local function readVigorCharges()
    local identifier = findVigorSpell()
    if not identifier then return nil end

    local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(identifier)
    if not charges or not charges.maxCharges then return nil end

    return charges.currentCharges, charges.maxCharges
end

function RaceDisplay:Build()
    if self.frame then return self.frame end

    -- Parented to WorldFrame on purpose: hiding UIParent during a race takes
    -- every child with it, and this panel is the one thing that must survive.
    local frame = CreateFrame("Frame", "EredarEngineeringRaceDisplay", WorldFrame)
    frame:SetSize(200, 70)
    frame:SetPoint("CENTER", WorldFrame, "CENTER", 0, -180)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0, 0, 0, 0.55)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame.title:SetText("|cFF63C5DARace|r")

    frame.vigorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.vigorText:SetPoint("TOP", frame, "TOP", 0, 0)

    frame.surgeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.surgeText:SetPoint("TOP", frame.vigorText, "BOTTOM", 0, -6)

    self.frame = frame

    return frame
end

function RaceDisplay:Refresh()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end

    local currentCharges, maximumCharges = readVigorCharges()

    if currentCharges and maximumCharges then
        frame.vigorText:SetFormattedText("%d / %d", currentCharges, maximumCharges)

        local colour = currentCharges == 0 and EMPTY_COLOR or CHARGE_COLOR
        frame.vigorText:SetTextColor(colour[1], colour[2], colour[3])
    else
        frame.vigorText:SetText("vigor unreadable")
        frame.vigorText:SetTextColor(0.6, 0.6, 0.6)
    end

    local surgeIdentifier = findWhirlingSurge()

    if not surgeIdentifier then
        frame.surgeText:SetText("")
        return
    end

    local cooldown = C_Spell.GetSpellCooldown(surgeIdentifier)
    local remaining = 0

    if cooldown and cooldown.startTime and cooldown.startTime > 0 and cooldown.duration > 0 then
        remaining = cooldown.startTime + cooldown.duration - GetTime()
    end

    if remaining > 0 then
        frame.surgeText:SetFormattedText("Surge %.1f", remaining)
        frame.surgeText:SetTextColor(COOLING_COLOR[1], COOLING_COLOR[2], COOLING_COLOR[3])
    else
        frame.surgeText:SetText("Surge ready")
        frame.surgeText:SetTextColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3])
    end
end

function RaceDisplay:Show()
    local frame = self:Build()
    frame:Show()

    self.elapsedSinceUpdate = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsedSinceUpdate = self.elapsedSinceUpdate + elapsed
        if self.elapsedSinceUpdate < UPDATE_INTERVAL_SECONDS then return end

        self.elapsedSinceUpdate = 0
        self:Refresh()
    end)

    self:Refresh()
end

function RaceDisplay:Hide()
    if not self.frame then return end

    self.frame:SetScript("OnUpdate", nil)
    self.frame:Hide()
end
