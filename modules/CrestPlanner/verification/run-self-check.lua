local addonRoot = (arg and arg[0] or ""):match("^(.*)verification[/\\][^/\\]*$") or "./"
local probeFile = arg and arg[1]

_G.date = os.date
_G.time = os.time

_G.CrestPlanner = {}

local printedMessages = {}

function CrestPlanner:Print(message)
    printedMessages[#printedMessages + 1] = message
end

function CrestPlanner:GetStore()
    return self.store
end

CrestPlanner.store = { observedCostPerRank = {} }

local checksRun = 0

local function check(condition, description)
    checksRun = checksRun + 1
    if not condition then
        error("FAILED: " .. description, 2)
    end
end

dofile(addonRoot .. "source/Model/Crests.lua")
dofile(addonRoot .. "source/Model/Equipment.lua")
dofile(addonRoot .. "source/Model/UpgradeCost.lua")
dofile(addonRoot .. "source/Model/Commitments.lua")
dofile(addonRoot .. "source/Planning/Plan.lua")

local Equipment = CrestPlanner.Equipment
local Crests = CrestPlanner.Crests
local Plan = CrestPlanner.Plan
local UpgradeCost = CrestPlanner.UpgradeCost

local parsed = Equipment:ParseUpgradeLine("Upgrade Level: Hero 3/6")
check(parsed ~= nil, "an upgrade line parses at all")
check(parsed.track == "Hero", "the track name comes out of the upgrade line")
check(parsed.currentRank == 3, "the current rank comes out of the upgrade line")
check(parsed.maximumRank == 6, "the maximum rank comes out of the upgrade line")
check(Equipment:ParseUpgradeLine("Myth 6/6") == nil, "a line without the label is rejected")
check(Equipment:ParseUpgradeLine(nil) == nil, "a nil line is rejected rather than crashing")
check(Equipment:ParseUpgradeLine("Soulbound") == nil, "an unrelated tooltip line is rejected")

check(UpgradeCost:ForTrack("Hero") == 20, "an unmeasured track falls back to the estimate")
check(select(2, UpgradeCost:ForTrack("Hero")) == false, "the estimate reports itself as unobserved")
UpgradeCost:Record("Hero", 15, "Hero Mistcrest")
check(UpgradeCost:ForTrack("Hero") == 15, "a measured cost replaces the estimate")
check(select(2, UpgradeCost:ForTrack("Hero")) == true, "a measured cost reports itself as observed")
CrestPlanner.store.observedCostPerRank = {}

if not probeFile then
    print(string.format("CrestPlanner verification passed: %d checks (pure logic only)", checksRun))
    return
end

assert(loadfile(probeFile))()
local probes = CrestPlannerDB.probes

local currencyById = {}
for _, entry in ipairs(probes.currencies.payload) do
    if entry.currencyIdentifier and type(entry.currencyInfo) == "table" then
        currencyById[entry.currencyIdentifier] = entry
    end
end

_G.C_CurrencyInfo = {
    GetCurrencyInfo = function(identifier)
        local entry = currencyById[identifier]
        return entry and entry.currencyInfo or nil
    end,
    GetCurrencyDescription = function(identifier)
        local entry = currencyById[identifier]
        return entry and entry.currencyInfo and entry.currencyInfo.description or nil
    end,
}

local equipmentBySlot = {}
for _, slot in ipairs(probes.equipment.payload.slots) do
    equipmentBySlot[slot.slotIdentifier] = slot
end

_G.GetInventoryItemLink = function(_, slotIdentifier)
    local slot = equipmentBySlot[slotIdentifier]
    return slot and slot.itemLink or nil
end

_G.C_Item = {
    GetDetailedItemLevelInfo = function(itemLink)
        for _, slot in pairs(equipmentBySlot) do
            if slot.itemLink == itemLink then return slot.itemLevel end
        end
        return nil
    end,
}

_G.C_TooltipInfo = {
    GetInventoryItem = function(_, slotIdentifier)
        local slot = equipmentBySlot[slotIdentifier]
        if not slot or not slot.tooltipLines then return nil end

        local lines = {}
        for index, leftText in ipairs(slot.tooltipLines) do
            lines[index] = { leftText = leftText }
        end
        return { lines = lines }
    end,
}

_G.GetAverageItemLevel = function()
    return probes.equipment.payload.averageItemLevel
end

-- Mapping read from the live client on 2026-09-08: itemRedundancySlot is zero-based and both
-- rings share slot 9, both trinkets share slot 10.
local REDUNDANCY_BY_EQUIPMENT_SLOT = {
    [1] = 0, [2] = 1, [3] = 2, [5] = 3, [6] = 4, [7] = 5, [8] = 6, [9] = 7,
    [10] = 8, [11] = 9, [12] = 9, [13] = 10, [14] = 10, [15] = 11, [16] = 12,
}
local slotOfLink = {}
for identifier, slot in pairs(equipmentBySlot) do
    slotOfLink[slot.itemLink] = identifier
end
_G.C_ItemUpgrade = {
    GetHighWatermarkForItem = function(itemLink)
        local identifier = slotOfLink[itemLink]
        local slot = identifier and equipmentBySlot[identifier]
        return slot and slot.itemLevel or nil
    end,
    GetHighWatermarkSlotForItem = function(itemLink)
        local identifier = slotOfLink[itemLink]
        return identifier and REDUNDANCY_BY_EQUIPMENT_SLOT[identifier] or nil
    end,
}

Crests:Refresh()

check(#Crests.mismatchedNames == 0, "every seeded crest identifier still matches its name")
check(Crests:Get("Hero").ceilingItemLevel == 321, "the Hero ceiling is read from the crest description")
check(Crests:Get("Hero").floorItemLevel == 308, "the Hero floor is read from the crest description")
check(Crests:Get("Myth").ceilingItemLevel == 334, "the Myth ceiling is read from the crest description")
check(Crests:Get("Champion").ceilingItemLevel == 308, "the Champion ceiling equals the Hero floor")
check(Crests:Get("Hero").capMeasuresEarned == true, "the Hero cap is measured against total earned")
check(Crests:IsCapped("Hero") == true, "the captured snapshot had Hero capped")
check(Crests:RemainingEarnableThisSeason("Hero") == 0, "a capped crest reports zero left to earn")

local plan = Plan:BuildForTrack("Hero")

check(plan ~= nil, "a Hero plan builds from the captured client state")
check(plan.targetItemLevel == 321, "the plan targets the Hero ceiling")
check(#plan.upgradeableSlots == 10, "the two rings collapse into one redundancy category, so ten remain")
check(plan.ranksRemaining == 30, "ten categories at three ranks each")
check(plan.requiredByTrack.Hero == 600, "600 Hero crests once the ring pair counts once")
check(plan.slotsDone == 3, "legs, the trinket pair and the weapon already clear 321")
check(plan.crestsRequired == 600, "the whole bill at the estimated twenty crests per rank")
check(plan.crestsHeld == 260, "the plan reads the held quantity from the client snapshot")
check(plan.crestsShort == 340, "600 required against 260 held leaves 340 short")
check(plan.costIsObserved == false, "the cost is still flagged as an estimate")

local headPlan = Plan:PlanForSlot(1, "Hero")
check(headPlan.status == "upgradeable", "the head slot is closable with crests")
check(headPlan.ranksRemaining == 3, "the head slot needs three ranks")
check(headPlan.crestsForThisSlot == 60, "the head slot costs sixty crests at the estimate")
check(headPlan.spendTrack == "Hero", "a Hero piece is paid for with Hero crests")
check(headPlan.crestName == "Hero Mistcrest", "the tooltip names the crest the piece actually consumes")

local mythCloakSlot = {
    slotIdentifier = 15,
    label = "Back",
    itemLevel = 318,
    upgrade = { track = "Myth", currentRank = 1, maximumRank = 6 },
}
local cloakPlan = Plan:ClassifySlot(mythCloakSlot, 321)
check(cloakPlan.status == "upgradeable", "a Myth 1/6 cloak at 318 can still be upgraded toward 321")
check(cloakPlan.spendTrack == "Myth", "a Myth piece is paid for with Myth crests, never Hero")
check(cloakPlan.spendCrestName == "Myth Mistcrest", "the Myth piece names the Myth crest")
check(cloakPlan.ranksRemaining == 1, "318 needs one rank to cross 321, not five to reach 334")
check(cloakPlan.crestsForThisSlot == 20, "one rank of a Myth piece costs twenty Myth crests")

local legsPlan = Plan:PlanForSlot(7, "Hero")
check(legsPlan.status == "done", "the Myth 6/6 legs already clear the Hero target")

local mythPlan = Plan:BuildForTrack("Myth")
check(mythPlan.targetItemLevel == 334, "the Myth plan targets 334")
check(mythPlan.ranksRemaining == 0, "no slot can advance toward 334 with Myth crests today")
check(#mythPlan.blockedSlots == 12, "against 334 every category except the legs is blocked")
check(mythPlan.slotsDone == 1, "only the Myth 6/6 legs already sit at 334")
check(mythPlan.outlook == "blocked", "zero advanceable ranks plus blocked slots reads as blocked, never as complete")
check(Plan:BuildForTrack("Hero").outlook == "actionable", "the Hero plan still reads as actionable")

local trade = Plan:TradeableFromLowerTracks("Hero")
check(trade ~= nil, "the trade chain computes for Hero")
check(trade.ratioIsVerified == false, "the trade ratio is flagged as unverified")
check(trade.blockedByCap == true, "a capped target track blocks the trade chain from landing")
check(trade.usableNow == 0, "nothing from the chain is usable while the target sits at its ceiling")
check(Crests:WeeklyCapIncrease("Hero") == 100, "a single cap observation falls back to the estimate")
check(select(2, Crests:WeeklyCapIncrease("Hero")) == false, "that fallback reports itself as unobserved")
CrestPlanner.store.seasonMaximumHistory = { Hero = { ["2026-08-24"] = 100, ["2026-09-07"] = 300 } }
check(Crests:WeeklyCapIncrease("Hero") == 100, "two observations two weeks apart derive 100 per week")
check(select(2, Crests:WeeklyCapIncrease("Hero")) == true, "a derived increase reports itself as observed")
CrestPlanner.store.seasonMaximumHistory = nil
check(Plan:WeeksOfCapToClose("Hero", 400) == 4, "400 short at 100 of cap per week is four weeks")
check(#trade.steps == 3, "the chain runs Adventurer to Veteran to Champion to Hero")
check(trade.totalPromoted > 0, "the captured crest piles do promote into something")

_G.C_Item.GetItemInfo = function(itemLink)
    local byLink = {
        ["myth-head"] = "INVTYPE_HEAD",
        ["hero-head"] = "INVTYPE_HEAD",
        ["junk-head"] = "INVTYPE_HEAD",
    }
    return nil, nil, nil, nil, nil, nil, nil, nil, byLink[itemLink]
end

local originalDetailed = _G.C_Item.GetDetailedItemLevelInfo
_G.C_Item.GetDetailedItemLevelInfo = function(itemLink)
    local synthetic = { ["myth-head"] = 318, ["hero-head"] = 314, ["junk-head"] = 290 }
    if synthetic[itemLink] then return synthetic[itemLink] end
    return originalDetailed(itemLink)
end

local function lines(text) return { { leftText = text } } end

local mythCandidate = CrestPlanner.Comparison and nil
dofile(addonRoot .. "source/Planning/Comparison.lua")
local Comparison = CrestPlanner.Comparison

local mythDrop = Comparison:ForCandidate("myth-head", lines("Upgrade Level: Myth 1/6"), "Hero")
check(mythDrop ~= nil, "a Myth candidate compares against the equipped head")
check(mythDrop.slotIdentifier == 1, "an INVTYPE_HEAD candidate lands on the head slot")
check(mythDrop.currentCost == 60, "the equipped Hero 3/6 head costs 60 to reach 321")
check(mythDrop.candidateCost == 20, "a Myth 1/6 at 318 needs a single rank to cross 321, not five")
check(mythDrop.crestsSaved == 40, "swapping in the Myth piece saves 40 crests")
check(select(2, Comparison:Describe(mythDrop)) == "good", "a saving reads as a good verdict")

local sameTrack = Comparison:ForCandidate("hero-head", lines("Upgrade Level: Hero 4/6"), "Hero")
check(sameTrack.candidateCost == 40, "a Hero 4/6 at 314 needs two ranks to reach 321")
check(sameTrack.crestsSaved == 20, "the higher Hero rank saves twenty crests")

local worseItem = Comparison:ForCandidate("junk-head", lines("Upgrade Level: Champion 6/6"), "Hero")
check(worseItem.candidateCost == nil, "a Champion piece cannot reach 321 at all")
check(worseItem.crestsSaved == nil, "an unreachable candidate reports no saving rather than a fake one")
check(select(2, Comparison:Describe(worseItem)) == "bad", "an unreachable candidate reads as a bad verdict")

local Commitments = CrestPlanner.Commitments
check(Commitments:ReservedFor("Myth") == 0, "nothing is reserved before anything is committed")
check(Commitments:FreeQuantity("Myth") == 90, "every held crest is free when nothing is reserved")

Commitments:Add("Myth", 80, "Loa Worshiper's Band")
check(Commitments:ReservedFor("Myth") == 80, "a pending crafting order reserves its crests")
local freeMyth, heldMyth, reservedMyth = Commitments:FreeQuantity("Myth")
check(heldMyth == 90, "the held count still reports the full pile")
check(reservedMyth == 80, "the reserved count reports the order")
check(freeMyth == 10, "only ten Myth crests are actually free to spend")

local mythPlanWithOrder = Plan:BuildForTrack("Myth")
check(
    mythPlanWithOrder.shortfallByTrack.Myth == nil or mythPlanWithOrder.shortfallByTrack.Myth.free == 10,
    "the plan spends what is free, not what is held"
)

Commitments:Clear()
check(Commitments:ReservedFor("Myth") == 0, "clearing releases every reservation")

local currentAverage, averageGap = Plan:AverageItemLevelGap(331)
check(math.abs(currentAverage - 316.1875) < 0.001, "the average item level matches what the client reported")
check(math.abs(averageGap - 14.8125) < 0.001, "the gap to the Myth average target is computed")

print(string.format("CrestPlanner verification passed: %d checks against the real client capture", checksRun))
print(string.format(
    "  plan: %d ranks across %d slots, %d crests required, %d held, %d short",
    plan.ranksRemaining, #plan.upgradeableSlots, plan.crestsRequired, plan.crestsHeld, plan.crestsShort
))
print(string.format(
    "  trade chain is worth %d Hero but %s",
    trade.totalPromoted,
    trade.blockedByCap and "lands nothing while the cap is full" or ("can fill " .. trade.usableNow .. " under the cap")
))
