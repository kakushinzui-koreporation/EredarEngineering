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

    if racing then
        self.RaceProbe:Capture("raceStarted")
        self.RaceDisplay:Show()
    else
        self.RaceProbe:Capture("raceEnded")
        self.RaceDisplay:Hide()
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

    self.enabled = false
    self.wasRacing = false
end

EredarEngineering.Modules:Register("dragonRacing", DragonRacing)
