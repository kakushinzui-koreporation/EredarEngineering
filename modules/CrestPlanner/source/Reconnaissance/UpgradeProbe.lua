local CrestPlanner = _G.CrestPlanner

local UpgradeProbe = {}
CrestPlanner.UpgradeProbe = UpgradeProbe

local FIRST_INVENTORY_SLOT = 1
local LAST_INVENTORY_SLOT = 17

local function copyPlainFields(sourceTable)
    local copied = {}

    for key, value in pairs(sourceTable) do
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copied[tostring(key)] = value
        else
            copied[tostring(key)] = valueType
        end
    end

    return copied
end

local function upgradeCostForSlot(slotIdentifier)
    if not C_ItemUpgrade then
        return nil, "C_ItemUpgrade is unavailable on this client"
    end

    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotIdentifier)
    if not itemLocation or not itemLocation:IsValid() then
        return nil, "no item in this slot"
    end

    local costs = {}

    if C_ItemUpgrade.GetItemUpgradeCurrentLevel then
        costs.currentLevel = C_ItemUpgrade.GetItemUpgradeCurrentLevel(itemLocation)
    end

    if C_ItemUpgrade.GetItemUpgradeItemInfo then
        costs.itemInfo = { C_ItemUpgrade.GetItemUpgradeItemInfo(itemLocation) }
    end

    if C_ItemUpgrade.GetNumUpgradeCosts then
        costs.numberOfCostEntries = C_ItemUpgrade.GetNumUpgradeCosts()
    end

    return costs, nil
end

local function argumentShapesForSlot(slotIdentifier)
    local itemLink = GetInventoryItemLink("player", slotIdentifier)
    if not itemLink then return nil end

    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotIdentifier)
    local itemIdentifier = C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemLink) or nil

    return {
        { label = "itemLink", value = itemLink },
        { label = "itemIdentifier", value = itemIdentifier },
        { label = "itemLocation", value = itemLocation },
        { label = "table{itemID}", value = { itemID = itemIdentifier } },
    }
end

local function callWithEveryArgumentShape(functionName, slotIdentifier)
    local apiFunction = C_ItemUpgrade and C_ItemUpgrade[functionName]
    if not apiFunction then
        return nil, functionName .. " is unavailable"
    end

    local shapes = argumentShapesForSlot(slotIdentifier)
    if not shapes then
        return nil, "no item in this slot"
    end

    local attempts = {}

    for _, shape in ipairs(shapes) do
        if shape.value ~= nil then
            local returned = { pcall(apiFunction, shape.value) }

            if returned[1] then
                local values = {}
                for index = 2, #returned do
                    values[index - 1] = returned[index]
                end

                attempts[#attempts + 1] = {
                    shape = shape.label,
                    accepted = true,
                    values = values,
                }
            else
                attempts[#attempts + 1] = {
                    shape = shape.label,
                    accepted = false,
                    errorText = tostring(returned[2]),
                }
            end
        end
    end

    return attempts, nil
end

local function highWatermarkForSlot(slotIdentifier)
    if not C_ItemUpgrade or not C_ItemUpgrade.GetHighWatermarkForSlot then
        return nil, "GetHighWatermarkForSlot is unavailable"
    end

    local returned = { pcall(C_ItemUpgrade.GetHighWatermarkForSlot, slotIdentifier) }
    if not returned[1] then
        return nil, tostring(returned[2])
    end

    local values = {}
    for index = 2, #returned do
        values[index - 1] = returned[index]
    end

    return values, nil
end

function UpgradeProbe:Run()
    local slots = {}

    local watermarks = {}
    for slotIdentifier = FIRST_INVENTORY_SLOT, LAST_INVENTORY_SLOT do
        local byIndexValues, byIndexProblem = highWatermarkForSlot(slotIdentifier)
        local forItemAttempts, forItemProblem =
            callWithEveryArgumentShape("GetHighWatermarkForItem", slotIdentifier)
        local watermarkSlotAttempts, watermarkSlotProblem =
            callWithEveryArgumentShape("GetHighWatermarkSlotForItem", slotIdentifier)

        watermarks[slotIdentifier] = {
            values = byIndexValues,
            problem = byIndexProblem,
            itemLink = GetInventoryItemLink("player", slotIdentifier),
            forItemAttempts = forItemAttempts,
            forItemProblem = forItemProblem,
            watermarkSlotAttempts = watermarkSlotAttempts,
            watermarkSlotProblem = watermarkSlotProblem,
        }
    end

    self.lastWatermarks = watermarks

    for slotIdentifier = FIRST_INVENTORY_SLOT, LAST_INVENTORY_SLOT do
        local itemLink = GetInventoryItemLink("player", slotIdentifier)

        if itemLink then
            local costs, problem = upgradeCostForSlot(slotIdentifier)

            slots[#slots + 1] = {
                slotIdentifier = slotIdentifier,
                itemLink = itemLink,
                costs = costs,
                problem = problem,
            }
        end
    end

    local upgradeApiSurface = {}
    if C_ItemUpgrade then
        for key, value in pairs(C_ItemUpgrade) do
            upgradeApiSurface[tostring(key)] = type(value)
        end
    end

    local currencyInfoBySlot = {}
    if C_ItemUpgrade and C_ItemUpgrade.GetNumUpgradeCosts then
        local costEntryCount = C_ItemUpgrade.GetNumUpgradeCosts() or 0
        for index = 1, costEntryCount do
            currencyInfoBySlot[index] = { C_ItemUpgrade.GetUpgradeCostInfo(index) }
        end
    end

    CrestPlanner:RecordProbe("upgrade", {
        note = "run this with the item upgrade window open on a Hero 3/6 piece",
        upgradeApiSurface = upgradeApiSurface,
        openWindowCosts = currencyInfoBySlot,
        highWatermarks = watermarks,
        slots = slots,
    })

    return slots, upgradeApiSurface
end

function UpgradeProbe:PrintSummary(slots, upgradeApiSurface)
    local functionNames = {}
    for name, valueType in pairs(upgradeApiSurface or {}) do
        if valueType == "function" then
            functionNames[#functionNames + 1] = name
        end
    end
    table.sort(functionNames)

    CrestPlanner:Print("C_ItemUpgrade exposes: " .. table.concat(functionNames, ", "))

    local function renderValues(values)
        if not values then return "-" end

        local rendered = {}
        for index = 1, #values do
            rendered[index] = tostring(values[index])
        end
        return table.concat(rendered, " | ")
    end

    local function firstAccepted(attempts)
        for _, attempt in ipairs(attempts or {}) do
            if attempt.accepted then
                return attempt.shape .. " -> " .. renderValues(attempt.values)
            end
        end
        return "every argument shape rejected"
    end

    for slotIdentifier = 1, 17 do
        local record = (self.lastWatermarks or {})[slotIdentifier]

        if record and record.itemLink then
            CrestPlanner:Print(string.format(
                "|cFF909090slot %2d|r byIndex %s | forItem %s | wmSlot %s",
                slotIdentifier,
                renderValues(record.values),
                firstAccepted(record.forItemAttempts),
                firstAccepted(record.watermarkSlotAttempts)
            ))
        end
    end

    for _, slot in ipairs(slots) do
        local itemName = string.match(slot.itemLink, "%[(.-)%]") or "?"
        local currentLevel = slot.costs and slot.costs.currentLevel

        CrestPlanner:Print(string.format(
            "|cFF909090slot %2d|r %-34s level %s %s",
            slot.slotIdentifier,
            itemName,
            tostring(currentLevel),
            slot.problem and ("|cFFE05050" .. slot.problem .. "|r") or ""
        ))
    end

    CrestPlanner:Print(string.format("Captured %d slots. Everything went to SavedVariables.", #slots))
end
