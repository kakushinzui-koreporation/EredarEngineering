local TreasuryTimeline = _G.TreasuryTimeline

local Tracker = {}
TreasuryTimeline.Tracker = Tracker

local TRACKED_EVENTS = {
    "PLAYER_MONEY",
    "MERCHANT_SHOW",
    "MERCHANT_CLOSED",
    "UPDATE_INVENTORY_DURABILITY",
}

local EVENT_HANDLERS = {
    PLAYER_MONEY = function(tracker)
        tracker:OnMoneyChanged()
    end,

    MERCHANT_SHOW = function()
        TreasuryTimeline.Repairs:OnMerchantShow()
    end,

    MERCHANT_CLOSED = function()
        TreasuryTimeline.Repairs:OnMerchantClosed()
    end,

    UPDATE_INVENTORY_DURABILITY = function()
        TreasuryTimeline.Repairs:RefreshPendingCost()
    end,
}

function Tracker:Initialize()
    assert(
        self.frame == nil,
        "Tracker:Initialize ran twice -- a second event frame and a second RepairAllItems hook would"
            .. " count every money change twice; call Tracker:Resynchronize to rebase the balance instead"
    )

    TreasuryTimeline.Repairs:Initialize()

    local trackerFrame = CreateFrame("Frame")
    for _, eventName in ipairs(TRACKED_EVENTS) do
        trackerFrame:RegisterEvent(eventName)
    end

    trackerFrame:SetScript("OnEvent", function(_, event)
        EVENT_HANDLERS[event](self)
    end)

    self.frame = trackerFrame

    self:Resynchronize()
end

function Tracker:Resynchronize()
    self.lastKnownCopper = GetMoney()
    TreasuryTimeline.Database:Reconcile(self.lastKnownCopper)
end

function Tracker:OnMoneyChanged()
    local currentCopper = GetMoney()
    local deltaCopper = currentCopper - self.lastKnownCopper
    self.lastKnownCopper = currentCopper

    if deltaCopper == 0 then return end

    if deltaCopper > 0 then
        TreasuryTimeline.Database:RecordGain(deltaCopper, currentCopper)
    else
        local spentCopper = -deltaCopper
        local repairCopper = TreasuryTimeline.Repairs:ClaimRepairPortion(spentCopper)
        TreasuryTimeline.Database:RecordSpend(spentCopper, repairCopper, currentCopper)
    end

    if TreasuryTimeline.ChartFrame:IsShown() then
        TreasuryTimeline.ChartFrame:Refresh()
    end
end
