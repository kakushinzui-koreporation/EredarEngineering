local CrestPlanner = _G.CrestPlanner

local Equipment = {}
CrestPlanner.Equipment = Equipment

local FIRST_INVENTORY_SLOT = 1
local LAST_INVENTORY_SLOT = 17
local SHIRT_SLOT = 4
local TABARD_SLOT = 19

local SLOT_LABELS = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger 1",
    [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
    [16] = "Main Hand", [17] = "Off Hand",
}

Equipment.SlotLabels = SLOT_LABELS

local function isCosmeticSlot(slotIdentifier)
    return slotIdentifier == SHIRT_SLOT or slotIdentifier == TABARD_SLOT
end

function Equipment:ParseUpgradeLine(lineText)
    if not lineText then return nil end

    local trackName, currentRank, maximumRank =
        string.match(lineText, "Upgrade Level:%s*(%a+)%s*(%d+)/(%d+)")

    if not trackName then return nil end

    return {
        track = trackName,
        currentRank = tonumber(currentRank),
        maximumRank = tonumber(maximumRank),
    }
end

local function upgradeStateForSlot(slotIdentifier)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return nil end

    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotIdentifier)
    if not tooltipData or not tooltipData.lines then return nil end

    for _, line in ipairs(tooltipData.lines) do
        local parsed = Equipment:ParseUpgradeLine(line.leftText)
        if parsed then return parsed end
    end

    return nil
end

local function watermarkFor(itemLink)
    if not C_ItemUpgrade or not C_ItemUpgrade.GetHighWatermarkForItem then return nil end

    local succeeded, characterWatermark = pcall(C_ItemUpgrade.GetHighWatermarkForItem, itemLink)
    if not succeeded then return nil end

    return characterWatermark
end

local function redundancySlotFor(itemLink)
    if not C_ItemUpgrade or not C_ItemUpgrade.GetHighWatermarkSlotForItem then return nil end

    local succeeded, redundancySlot = pcall(C_ItemUpgrade.GetHighWatermarkSlotForItem, itemLink)
    if not succeeded then return nil end

    return redundancySlot
end

function Equipment:Read()
    local slots = {}

    for slotIdentifier = FIRST_INVENTORY_SLOT, LAST_INVENTORY_SLOT do
        if not isCosmeticSlot(slotIdentifier) then
            local itemLink = GetInventoryItemLink("player", slotIdentifier)

            if itemLink then
                slots[slotIdentifier] = {
                    slotIdentifier = slotIdentifier,
                    label = SLOT_LABELS[slotIdentifier] or ("Slot " .. slotIdentifier),
                    itemLink = itemLink,
                    itemLevel = C_Item and C_Item.GetDetailedItemLevelInfo
                        and C_Item.GetDetailedItemLevelInfo(itemLink) or nil,
                    upgrade = upgradeStateForSlot(slotIdentifier),
                    watermark = watermarkFor(itemLink),
                    redundancySlot = redundancySlotFor(itemLink),
                }
            end
        end
    end

    self.slots = slots

    return slots
end

function Equipment:SlotsByRedundancy()
    local grouped = {}

    for _, slot in pairs(self:Slots()) do
        local key = slot.redundancySlot or ("slot:" .. slot.slotIdentifier)
        local existing = grouped[key]

        local slotReach = slot.watermark or slot.itemLevel or 0
        local existingReach = existing and (existing.watermark or existing.itemLevel or 0) or -1

        if slotReach > existingReach then
            grouped[key] = slot
        end
    end

    return grouped
end

function Equipment:Slots()
    if not self.slots then
        self:Read()
    end

    return self.slots
end

function Equipment:SlotAt(slotIdentifier)
    return self:Slots()[slotIdentifier]
end

function Equipment:AverageItemLevel()
    return (GetAverageItemLevel())
end

function Equipment:RankSnapshot()
    local snapshot = {}

    for slotIdentifier, slot in pairs(self:Read()) do
        if slot.upgrade then
            snapshot[slotIdentifier] = {
                track = slot.upgrade.track,
                currentRank = slot.upgrade.currentRank,
            }
        end
    end

    return snapshot
end
