local CrestPlanner = _G.CrestPlanner

local UpgradeWindowWarning = {}
CrestPlanner.UpgradeWindowWarning = UpgradeWindowWarning

local BLIZZARD_UPGRADE_ADDON = "Blizzard_ItemUpgradeUI"
local PLANNED_TRACK = "Hero"

local GOOD_COLOR = { 0.25, 0.75, 0.25 }
local WARN_COLOR = { 0.95, 0.62, 0.20 }
local MUTED_COLOR = { 0.57, 0.57, 0.57 }

local function attachMessageLine(upgradeFrame)
    if upgradeFrame.crestPlannerMessage then
        return upgradeFrame.crestPlannerMessage
    end

    local message = upgradeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    message:SetPoint("BOTTOMLEFT", upgradeFrame, "BOTTOMLEFT", 20, 12)
    message:SetPoint("BOTTOMRIGHT", upgradeFrame, "BOTTOMRIGHT", -20, 12)
    message:SetJustifyH("CENTER")
    message:SetWordWrap(true)
    message:SetMaxLines(3)

    upgradeFrame.crestPlannerMessage = message

    return message
end

local function messageForPlan(plan)
    if not plan then
        return "Crest Planner has no reading for this slot.", MUTED_COLOR
    end

    if plan.status == "done" then
        return string.format(
            "This slot already sits at %d. Spending %s here buys you nothing toward outgrowing them.",
            plan.targetItemLevel,
            plan.crestName
        ), WARN_COLOR
    end

    if plan.status == "needsBetterItem" then
        return string.format(
            "This item tops out at %d, below the %d you need. Crests cannot close this slot -- it needs a better drop.",
            tostring(plan.ceiling),
            plan.targetItemLevel
        ), WARN_COLOR
    end

    if plan.status == "upgradeable" then
        local estimateNote = plan.costIsObserved and "" or " (cost still estimated)"

        return string.format(
            "%d ranks to %d, about %d %s%s.",
            plan.ranksRemaining,
            plan.targetItemLevel,
            plan.crestsForThisSlot,
            plan.crestName,
            estimateNote
        ), GOOD_COLOR
    end

    return "Crests do not apply to this item.", MUTED_COLOR
end

local function wholeCharacterSummary()
    local plan = CrestPlanner.Plan:BuildForTrack(PLANNED_TRACK)
    if not plan then
        return "Crest Planner could not read your crests.", MUTED_COLOR
    end

    if plan.outlook == "complete" then
        return string.format("Every slot already sits at %d.", plan.targetItemLevel), GOOD_COLOR
    end

    if plan.outlook == "blocked" then
        return string.format(
            "%d slots sit below %d, but their gear tops out lower. Crests cannot close them -- better drops first.",
            #plan.blockedSlots,
            plan.targetItemLevel
        ), WARN_COLOR
    end

    local parts = {}
    for _, shortfall in pairs(plan.shortfallByTrack) do
        local shortNote = shortfall.short > 0
            and string.format("short %d", shortfall.short)
            or "covered"

        parts[#parts + 1] = string.format(
            "%d %s, %s",
            shortfall.required,
            string.gsub(shortfall.crestName, " Mistcrest", ""),
            shortNote
        )
    end
    table.sort(parts)

    local estimateNote = plan.costIsObserved and "" or "  (cost estimated)"

    return string.format(
        "%d ranks over %d slots to %d\n%s%s",
        plan.ranksRemaining,
        #plan.upgradeableSlots,
        plan.targetItemLevel,
        table.concat(parts, "   "),
        estimateNote
    ), GOOD_COLOR
end

function UpgradeWindowWarning:Refresh()
    local upgradeFrame = _G.ItemUpgradeFrame
    if not upgradeFrame or not upgradeFrame:IsShown() then return end

    local message = attachMessageLine(upgradeFrame)
    local slotIdentifier = self.watchedSlotIdentifier

    local text, color
    if slotIdentifier then
        text, color = messageForPlan(CrestPlanner.Plan:PlanForSlot(slotIdentifier, PLANNED_TRACK))
    else
        text, color = wholeCharacterSummary()
    end

    message:SetText(text)
    message:SetTextColor(color[1], color[2], color[3])
end

function UpgradeWindowWarning:WatchSlot(slotIdentifier)
    self.watchedSlotIdentifier = slotIdentifier
    self:Refresh()
end

local WATCHED_EVENTS = {
    "ITEM_UPGRADE_MASTER_SET_ITEM",
    "ITEM_UPGRADE_MASTER_UPDATE",
}

local function readCostFromOpenWindow()
    if not C_ItemUpgrade or not C_ItemUpgrade.GetItemUpgradeItemInfo then return end

    local succeeded, itemInfo = pcall(C_ItemUpgrade.GetItemUpgradeItemInfo)
    if not succeeded or type(itemInfo) ~= "table" then return end

    local costAmount = itemInfo.upgradeCost or itemInfo.cost
    local currencyIdentifier = itemInfo.upgradeCostCurrencyID or itemInfo.currencyID

    if not costAmount or costAmount <= 0 or not currencyIdentifier then return end

    for _, crest in ipairs(CrestPlanner.Crests:Ordered()) do
        if crest.identifier == currencyIdentifier then
            local knownCost, isObserved = CrestPlanner.UpgradeCost:ForTrack(crest.track)
            if not isObserved or knownCost ~= costAmount then
                CrestPlanner.UpgradeCost:Record(crest.track, costAmount, crest.name)
            end
            return
        end
    end
end

local function hookUpgradeFrame()
    local upgradeFrame = _G.ItemUpgradeFrame
    if not upgradeFrame then return false end

    upgradeFrame:HookScript("OnShow", function()
        UpgradeWindowWarning:Refresh()
    end)

    local costWatcher = CreateFrame("Frame")
    for _, eventName in ipairs(WATCHED_EVENTS) do
        costWatcher:RegisterEvent(eventName)
    end
    costWatcher:SetScript("OnEvent", function()
        readCostFromOpenWindow()
        UpgradeWindowWarning:Refresh()
    end)

    UpgradeWindowWarning.costWatcher = costWatcher

    return true
end

function UpgradeWindowWarning:Initialize()
    self.watchedSlotIdentifier = nil

    if hookUpgradeFrame() then
        self.installed = true
        return
    end

    local waiterFrame = CreateFrame("Frame")
    waiterFrame:RegisterEvent("ADDON_LOADED")
    waiterFrame:SetScript("OnEvent", function(frame, _, loadedAddonName)
        if loadedAddonName ~= BLIZZARD_UPGRADE_ADDON then return end

        UpgradeWindowWarning.installed = hookUpgradeFrame()
        frame:UnregisterEvent("ADDON_LOADED")
    end)

    self.waiterFrame = waiterFrame
end
