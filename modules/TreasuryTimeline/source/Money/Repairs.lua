local TreasuryTimeline = _G.TreasuryTimeline

local Repairs = {}
TreasuryTimeline.Repairs = Repairs

local REPAIR_HOOK_WINDOW_SECONDS = 2

function Repairs:Initialize()
    assert(
        type(_G.RepairAllItems) == "function",
        "RepairAllItems is not a global function on this client -- repair attribution has no reliable"
            .. " source and every repair would be filed as an uncategorized purchase"
    )
    assert(
        REPAIR_HOOK_WINDOW_SECONDS >= 1,
        "lazy-mode: a repair is attributed exactly when RepairAllItems fires within "
            .. REPAIR_HOOK_WINDOW_SECONDS .. "s of the money change; outside that window the fallback"
            .. " reads the GetRepairAllCost drop, which cannot tell a single-item repair from a"
            .. " purchase made at the same vendor in the same second"
    )

    self.expectedRepairCopper = 0
    self.expectedAt = 0
    self.lastKnownRepairCost = 0
    self.merchantIsOpen = false

    hooksecurefunc("RepairAllItems", function(usedGuildBank)
        self:OnRepairAllItems(usedGuildBank)
    end)
end

function Repairs:OnRepairAllItems(usedGuildBank)
    if usedGuildBank then return end

    self.expectedRepairCopper = self.lastKnownRepairCost
    self.expectedAt = GetTime()
    self.lastKnownRepairCost = 0
end

function Repairs:RefreshPendingCost()
    if not self.merchantIsOpen or not CanMerchantRepair() then
        self.lastKnownRepairCost = 0
        return
    end

    local currentCost = GetRepairAllCost() or 0

    -- MERCHANT_SHOW can arrive before the vendor's data does, reporting zero for
    -- a repair that is about to be paid. While the vendor stays open the cached
    -- figure only ever rises: a real drop means the repair went through, and
    -- that is claimed from the money change instead of from here.
    if currentCost > self.lastKnownRepairCost then
        self.lastKnownRepairCost = currentCost
    end
end

function Repairs:OnMerchantShow()
    self.merchantIsOpen = true
    self:RefreshPendingCost()
end

function Repairs:OnMerchantClosed()
    self.merchantIsOpen = false
    self.lastKnownRepairCost = 0
end

local function claimFromHook(self, spentCopper)
    if self.expectedRepairCopper <= 0 then return 0 end
    if GetTime() - self.expectedAt > REPAIR_HOOK_WINDOW_SECONDS then
        self.expectedRepairCopper = 0
        return 0
    end

    local claimedCopper = math.min(self.expectedRepairCopper, spentCopper)
    self.expectedRepairCopper = self.expectedRepairCopper - claimedCopper

    return claimedCopper
end

local function claimFromCostDrop(self, spentCopper)
    if not self.merchantIsOpen or not CanMerchantRepair() then return 0 end

    local currentCost = GetRepairAllCost() or 0
    local costDrop = self.lastKnownRepairCost - currentCost
    self.lastKnownRepairCost = currentCost

    if costDrop <= 0 then return 0 end

    return math.min(costDrop, spentCopper)
end

function Repairs:ClaimRepairPortion(spentCopper)
    local claimedCopper = claimFromHook(self, spentCopper)
    if claimedCopper > 0 then return claimedCopper end

    return claimFromCostDrop(self, spentCopper)
end
