local CrestPlanner = _G.CrestPlanner

local EquipmentProbe = {}
CrestPlanner.EquipmentProbe = EquipmentProbe

local FIRST_INVENTORY_SLOT = 1
local LAST_INVENTORY_SLOT = 17

local SLOT_NAMES = {
    "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet",
    "Wrist", "Hands", "Finger1", "Finger2", "Trinket1", "Trinket2", "Back",
    "MainHand", "OffHand",
}

local function tooltipLinesForSlot(slotIdentifier)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
        return nil, "C_TooltipInfo.GetInventoryItem is unavailable"
    end

    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotIdentifier)
    if not tooltipData or not tooltipData.lines then
        return nil, "no tooltip data for this slot"
    end

    local lines = {}
    for index, line in ipairs(tooltipData.lines) do
        lines[index] = line.leftText
    end

    return lines, nil
end

local function findUpgradeLine(lines)
    if not lines then return nil end

    for _, lineText in ipairs(lines) do
        if lineText and string.find(lineText, "Upgrade Level") then
            return lineText
        end
    end

    return nil
end

function EquipmentProbe:Run()
    local slots = {}

    for slotIdentifier = FIRST_INVENTORY_SLOT, LAST_INVENTORY_SLOT do
        local itemLink = GetInventoryItemLink("player", slotIdentifier)

        if itemLink then
            local lines, tooltipProblem = tooltipLinesForSlot(slotIdentifier)

            slots[#slots + 1] = {
                slotIdentifier = slotIdentifier,
                slotName = SLOT_NAMES[slotIdentifier],
                itemLink = itemLink,
                itemLevel = C_Item and C_Item.GetDetailedItemLevelInfo
                    and C_Item.GetDetailedItemLevelInfo(itemLink) or nil,
                upgradeLine = findUpgradeLine(lines),
                tooltipProblem = tooltipProblem,
                tooltipLines = lines,
            }
        end
    end

    CrestPlanner:RecordProbe("equipment", {
        averageItemLevel = select(2, GetAverageItemLevel()),
        averageItemLevelTotal = (GetAverageItemLevel()),
        slots = slots,
    })

    return slots
end

function EquipmentProbe:PrintSummary(slots)
    for _, slot in ipairs(slots) do
        CrestPlanner:Print(string.format(
            "|cFF909090%-10s|r %s  %s",
            tostring(slot.slotName),
            tostring(slot.itemLevel),
            tostring(slot.upgradeLine or "|cFF707070no upgrade line|r")
        ))
    end

    CrestPlanner:Print(string.format("Captured %d equipped slots.", #slots))
end
