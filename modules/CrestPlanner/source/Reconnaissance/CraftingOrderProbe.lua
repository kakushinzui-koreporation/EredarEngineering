local CrestPlanner = _G.CrestPlanner

local CraftingOrderProbe = {}
CrestPlanner.CraftingOrderProbe = CraftingOrderProbe

local NAMESPACES_TO_MAP = {
    "C_CraftingOrders",
    "C_TradeSkillUI",
    "C_Mail",
}

local CANDIDATE_EVENTS = {
    "CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE",
    "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED",
    "CRAFTINGORDERS_CLAIMED_ORDER_ADDED",
    "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED",
    "CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS",
    "CRAFTINGORDERS_UPDATE_CUSTOMER_NAME",
    "MAIL_INBOX_UPDATE",
    "MAIL_SUCCESS",
}

local function mapNamespace(namespaceName)
    local namespace = _G[namespaceName]
    if type(namespace) ~= "table" then
        return namespaceName .. " does not exist on this client"
    end

    local members = {}
    for key, value in pairs(namespace) do
        members[tostring(key)] = type(value)
    end

    return members
end

local MAXIMUM_DUMP_DEPTH = 5

local function deepCopyForDump(value, depth)
    local valueType = type(value)

    if valueType ~= "table" then
        return valueType == "function" and "function" or value
    end

    if depth >= MAXIMUM_DUMP_DEPTH then
        return "table (depth limit reached)"
    end

    local copied = {}
    for key, inner in pairs(value) do
        copied[tostring(key)] = deepCopyForDump(inner, depth + 1)
    end

    return copied
end

local function readMyOrders()
    if not C_CraftingOrders then
        return "C_CraftingOrders is unavailable"
    end

    local readers = { "GetMyOrders", "GetCrafterOrders", "GetPersonalOrdersInfo" }
    local results = {}

    for _, readerName in ipairs(readers) do
        local reader = C_CraftingOrders[readerName]

        if type(reader) == "function" then
            local returned = { pcall(reader) }

            if returned[1] then
                local payload = returned[2]
                if type(payload) == "table" then
                    results[readerName] = {
                        entryCount = #payload,
                        entries = deepCopyForDump(payload, 0),
                    }
                else
                    results[readerName] = tostring(payload)
                end
            else
                results[readerName] = "error: " .. tostring(returned[2])
            end
        else
            results[readerName] = "not a function on this client"
        end
    end

    return results
end

local function eventsThatExist()
    local probeFrame = CreateFrame("Frame")
    local existing = {}

    for _, eventName in ipairs(CANDIDATE_EVENTS) do
        local registered = pcall(probeFrame.RegisterEvent, probeFrame, eventName)
        existing[eventName] = registered and "registers" or "rejected"

        if registered then
            probeFrame:UnregisterEvent(eventName)
        end
    end

    return existing
end

function CraftingOrderProbe:Run()
    local namespaces = {}
    for _, namespaceName in ipairs(NAMESPACES_TO_MAP) do
        namespaces[namespaceName] = mapNamespace(namespaceName)
    end

    local findings = {
        question = "does placing a crafting order deduct crests immediately, or only on delivery",
        namespaces = namespaces,
        myOrders = readMyOrders(),
        events = eventsThatExist(),
        crestQuantitiesAtCapture = {},
    }

    for _, crest in ipairs(CrestPlanner.Crests:Refresh() and CrestPlanner.Crests:Ordered()) do
        findings.crestQuantitiesAtCapture[crest.track] = crest.quantity
    end

    CrestPlanner:RecordProbe("craftingOrders", findings)

    return findings
end

function CraftingOrderProbe:PrintSummary(findings)
    for namespaceName, members in pairs(findings.namespaces) do
        if type(members) == "table" then
            local functionCount = 0
            for _, memberType in pairs(members) do
                if memberType == "function" then
                    functionCount = functionCount + 1
                end
            end
            CrestPlanner:Print(string.format("%s exposes %d functions", namespaceName, functionCount))
        else
            CrestPlanner:Print(string.format("|cFFE05050%s|r", tostring(members)))
        end
    end

    for readerName, result in pairs(findings.myOrders) do
        if type(result) == "table" then
            CrestPlanner:Print(string.format(
                "|cFF909090%s|r returned %d entries",
                readerName,
                result.entryCount
            ))
        else
            CrestPlanner:Print(string.format("|cFF909090%s|r %s", readerName, tostring(result)))
        end
    end

    CrestPlanner:Print("Everything else went to SavedVariables.")
end
