local DragonRacing = _G.DragonRacing

local InterfaceBlackout = {}
DragonRacing.InterfaceBlackout = InterfaceBlackout

local SAFETY_CHECK_SECONDS = 2

-- Hiding UIParent is the only move that clears third-party addons too, which a
-- list of Blizzard frame names never would. It also takes the chat with it, so
-- every path back out of this state has to be automatic.
local RESTORE_EVENTS = {
    "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_DEAD",
    "PLAYER_LEAVING_WORLD",
}

function InterfaceBlackout:IsWanted()
    local store = DragonRacing:Store()

    if store.hideInterfaceDuringRace == nil then
        store.hideInterfaceDuringRace = true
    end

    return store.hideInterfaceDuringRace
end

function InterfaceBlackout:SetWanted(shouldHide)
    DragonRacing:Store().hideInterfaceDuringRace = shouldHide and true or false

    if not shouldHide then
        self:Restore()
    end
end

local function installSafetyNet(self)
    if self.safetyFrame then return end

    local safety = CreateFrame("Frame")
    for _, eventName in ipairs(RESTORE_EVENTS) do
        safety:RegisterEvent(eventName)
    end

    safety:SetScript("OnEvent", function()
        InterfaceBlackout:Restore()
    end)

    self.safetyFrame = safety
end

local function startSafetyTicker(self)
    if self.safetyTicker then return end

    self.safetyTicker = C_Timer.NewTicker(SAFETY_CHECK_SECONDS, function()
        if not DragonRacing:IsRacing() then
            InterfaceBlackout:Restore()
        end
    end)
end

function InterfaceBlackout:Hide()
    if self.hidden then return end
    if not self:IsWanted() then return end

    if InCombatLockdown() then
        DragonRacing:Print("Not clearing the interface while in combat.")
        return
    end

    installSafetyNet(self)

    self.hidden = true
    UIParent:Hide()

    startSafetyTicker(self)
end

function InterfaceBlackout:Restore()
    if self.safetyTicker then
        self.safetyTicker:Cancel()
        self.safetyTicker = nil
    end

    if not self.hidden then return end

    self.hidden = false
    UIParent:Show()
end

function InterfaceBlackout:Toggle()
    if self.hidden then
        self:Restore()
    else
        self:Hide()
    end
end
