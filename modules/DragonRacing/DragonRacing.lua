_G.DragonRacing = _G.DragonRacing or {}

local DragonRacing = _G.DragonRacing

DragonRacing.Name = "DragonRacing"
DragonRacing.ChatPrefix = "|cFF63C5DA[Race]|r "

-- Matched against the aura name until the probe learns the identifier. The
-- Paladin's client is English; the learned identifier is what makes this
-- survive a client in any other language.
local RACING_AURA_NAME_PATTERN = "^Racing$"
local COUNTDOWN_AURA_NAME_PATTERN = "^Race Starting$"

local WATCHED_EVENTS = {
    "UNIT_AURA",
    "PLAYER_ENTERING_WORLD",
}

function DragonRacing:Print(message)
    print(self.ChatPrefix .. message)
end

function DragonRacing:Store()
    local database = _G.EredarEngineeringDB
    database.dragonRacing = database.dragonRacing or {}

    return database.dragonRacing
end

local function auraMatching(namePattern)
    for index = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not aura then break end

        if aura.name and string.match(aura.name, namePattern) then
            return aura
        end
    end

    for index = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")
        if not aura then break end

        if aura.name and string.match(aura.name, namePattern) then
            return aura
        end
    end

    return nil
end

function DragonRacing:FindRacingAura()
    local store = self:Store()

    if store.racingAuraIdentifier then
        local byIdentifier = C_UnitAuras.GetPlayerAuraBySpellID(store.racingAuraIdentifier)
        if byIdentifier then return byIdentifier end
    end

    local byName = auraMatching(RACING_AURA_NAME_PATTERN)

    if byName and byName.spellId and store.racingAuraIdentifier ~= byName.spellId then
        store.racingAuraIdentifier = byName.spellId
        self:Print(string.format(
            "Learned the racing aura: |cFFFFFFFF%s|r is spell %d. Name matching is no longer needed.",
            tostring(byName.name),
            byName.spellId
        ))
    end

    return byName
end

function DragonRacing:FindCountdownAura()
    return auraMatching(COUNTDOWN_AURA_NAME_PATTERN)
end

function DragonRacing:IsRacing()
    return self:FindRacingAura() ~= nil
end

function DragonRacing:OnAuraChanged()
    local racing = self:IsRacing()

    if racing == self.wasRacing then return end

    self.wasRacing = racing

    -- The display is the point of the module and the probe is a passenger, so a
    -- failing probe must never keep the display from appearing mid-race.
    local function captureQuietly(reason)
        local succeeded, failure = pcall(function()
            DragonRacing.RaceProbe:Capture(reason)
        end)

        if not succeeded then
            DragonRacing:Print("|cFFE05050The probe failed but the display is unaffected:|r " .. tostring(failure))
        end
    end

    if racing then
        self.RaceProbe:StartMidRaceSampling()
        self.InterfaceBlackout:Hide()
        self.RaceDisplay:Show()
        captureQuietly("raceStarted")
    else
        self.RaceProbe:StopMidRaceSampling()
        self.InterfaceBlackout:Restore()
        self.RaceDisplay:Hide()
        captureQuietly("raceEnded")
    end
end

local COMMAND_HANDLERS = {
    show = function()
        DragonRacing.RaceDisplay:Show()
        DragonRacing:Print("Display forced on. Use |cFFFFFFFF/dragonracing hide|r to put it away.")
    end,

    hide = function()
        DragonRacing.RaceDisplay:Hide()
        DragonRacing.InterfaceBlackout:Restore()
    end,

    -- Rehearses both halves of a real race. Testing the blackout without the
    -- panel proves nothing, because whether the panel survives the blackout is
    -- the entire question.
    blackout = function()
        if DragonRacing.InterfaceBlackout.hidden then
            DragonRacing.InterfaceBlackout:Restore()
            DragonRacing.RaceDisplay:Hide()
            return
        end

        DragonRacing.RaceDisplay:Show()
        DragonRacing.InterfaceBlackout:Hide()
        DragonRacing:Print("Rehearsing race mode. |cFFFFFFFFAlt+Z|r brings the interface back.")
    end,

    keep = function()
        DragonRacing.InterfaceBlackout:SetWanted(not DragonRacing.InterfaceBlackout:IsWanted())
        DragonRacing:Print(string.format(
            "Clearing the interface during a race: |cFFFFFFFF%s|r",
            tostring(DragonRacing.InterfaceBlackout:IsWanted())
        ))
    end,

    status = function()
        local racingAura = DragonRacing:FindRacingAura()
        local store = DragonRacing:Store()

        DragonRacing:Print(string.format(
            "racing now: |cFFFFFFFF%s|r   learned racing aura: |cFFFFFFFF%s|r   learned Whirling Surge: |cFFFFFFFF%s|r",
            tostring(racingAura ~= nil),
            tostring(store.racingAuraIdentifier),
            tostring(store.whirlingSurgeIdentifier)
        ))
        DragonRacing:Print(string.format(
            "captures recorded: |cFFFFFFFF%d|r   vigor power type: |cFFFFFFFF%s|r",
            store.captures and #store.captures or 0,
            tostring(store.vigorPowerType)
        ))
    end,

    probe = function()
        DragonRacing.InterfaceBlackout:Restore()
        DragonRacing.RaceProbe:Capture("manual")
        DragonRacing:Print("Captured. Run |cFFFFFFFF/reload|r so it lands on disk.")
    end,
}

function DragonRacing:InitializeSlashCommands()
    SLASH_DRAGON_RACING1 = "/dragonracing"

    SlashCmdList["DRAGON_RACING"] = function(message)
        local keyword = string.lower(string.match(message or "", "^%s*(%S*)") or "")
        local handler = COMMAND_HANDLERS[keyword] or COMMAND_HANDLERS.status

        handler()
    end
end

function DragonRacing:Enable()
    if self.enabled then return end

    assert(
        C_UnitAuras and C_UnitAuras.GetAuraDataByIndex,
        "C_UnitAuras.GetAuraDataByIndex is missing on this client, so the module cannot tell whether"
            .. " a race is running and would either never show or never hide"
    )

    local watcher = CreateFrame("Frame")
    for _, eventName in ipairs(WATCHED_EVENTS) do
        watcher:RegisterEvent(eventName)
    end

    watcher:SetScript("OnEvent", function(_, event, unitTarget)
        if event == "UNIT_AURA" and unitTarget ~= "player" then return end
        DragonRacing:OnAuraChanged()
    end)

    self:InitializeSlashCommands()

    self.watcherFrame = watcher
    self.wasRacing = false
    self.enabled = true

    self:OnAuraChanged()
end

function DragonRacing:Disable()
    if not self.enabled then return end

    if self.watcherFrame then
        self.watcherFrame:UnregisterAllEvents()
        self.watcherFrame:SetScript("OnEvent", nil)
        self.watcherFrame = nil
    end

    self.RaceDisplay:Hide()
    self.InterfaceBlackout:Restore()

    self.enabled = false
    self.wasRacing = false
end

EredarEngineering.Modules:Register("dragonRacing", DragonRacing)
