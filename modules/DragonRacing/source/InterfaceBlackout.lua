local DragonRacing = _G.DragonRacing

local InterfaceBlackout = {}
DragonRacing.InterfaceBlackout = InterfaceBlackout

local SAFETY_CHECK_SECONDS = 2

-- Blizzard's own race widgets are the one part of the interface the Paladin
-- wants left on screen. Hiding UIParent takes them with it, so they are lifted
-- out to WorldFrame for the duration and put back exactly where they were.
-- Confirmed visible mid-race by the probe on 2026-09-08.
local RACE_WIDGET_FRAMES = {
    "UIWidgetTopCenterContainerFrame",
    "UIWidgetBelowMinimapContainerFrame",
    "UIWidgetPowerBarContainerFrame",
}

local function liftRaceWidgets(self)
    self.liftedWidgets = {}

    for _, frameName in ipairs(RACE_WIDGET_FRAMES) do
        local frame = _G[frameName]

        if frame and frame:IsShown() then
            local lifted = pcall(function()
                local point, _, relativePoint, offsetX, offsetY = frame:GetPoint()

                self.liftedWidgets[frameName] = {
                    parent = frame:GetParent(),
                    point = point,
                    relativePoint = relativePoint,
                    offsetX = offsetX,
                    offsetY = offsetY,
                }

                frame:SetParent(WorldFrame)

                if point then
                    frame:ClearAllPoints()
                    frame:SetPoint(point, WorldFrame, relativePoint, offsetX, offsetY)
                end
            end)

            if not lifted then
                self.liftedWidgets[frameName] = nil
            end
        end
    end
end

local function lowerRaceWidgets(self)
    for frameName, saved in pairs(self.liftedWidgets or {}) do
        local frame = _G[frameName]

        if frame and saved.parent then
            pcall(function()
                frame:SetParent(saved.parent)

                if saved.point then
                    frame:ClearAllPoints()
                    frame:SetPoint(saved.point, saved.parent, saved.relativePoint, saved.offsetX, saved.offsetY)
                end
            end)
        end
    end

    self.liftedWidgets = nil
end

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
