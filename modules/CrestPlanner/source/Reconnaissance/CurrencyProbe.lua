local CrestPlanner = _G.CrestPlanner

local CurrencyProbe = {}
CrestPlanner.CurrencyProbe = CurrencyProbe

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

local function expandEveryHeader()
    local expandedAny = false

    for index = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(index)
        if listInfo and listInfo.isHeader and not listInfo.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(index, true)
            expandedAny = true
        end
    end

    return expandedAny
end

local function currencyIdentifierAt(index)
    local currencyLink = C_CurrencyInfo.GetCurrencyListLink(index)
    if not currencyLink then return nil end

    return tonumber(string.match(currencyLink, "currency:(%d+)"))
end

function CurrencyProbe:Run()
    assert(
        C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize,
        "C_CurrencyInfo.GetCurrencyListSize is missing on this client -- the currency probe has no"
            .. " way to enumerate crests and every later calculation would be guesswork"
    )

    expandEveryHeader()

    local entries = {}
    local currentHeader = nil

    for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local listInfo = C_CurrencyInfo.GetCurrencyListInfo(index)

        if listInfo and listInfo.isHeader then
            currentHeader = listInfo.name
        elseif listInfo then
            local currencyIdentifier = currencyIdentifierAt(index)
            local detailedInfo = currencyIdentifier and C_CurrencyInfo.GetCurrencyInfo(currencyIdentifier)

            entries[#entries + 1] = {
                header = currentHeader,
                listIndex = index,
                currencyIdentifier = currencyIdentifier,
                listInfo = copyPlainFields(listInfo),
                currencyInfo = detailedInfo and copyPlainFields(detailedInfo) or "GetCurrencyInfo returned nil",
                description = currencyIdentifier and C_CurrencyInfo.GetCurrencyDescription
                    and C_CurrencyInfo.GetCurrencyDescription(currencyIdentifier) or nil,
            }
        end
    end

    CrestPlanner:RecordProbe("currencies", entries)

    return entries
end

function CurrencyProbe:PrintSummary(entries)
    local crestCount = 0

    for _, entry in ipairs(entries) do
        local info = entry.currencyInfo
        if type(info) == "table" and entry.header then
            local looksLikeCrest = string.find(string.lower(entry.header), "crest")
                or string.find(string.lower(tostring(info.name)), "crest")

            if looksLikeCrest then
                crestCount = crestCount + 1
                CrestPlanner:Print(string.format(
                    "%s |cFF909090id|r %s  |cFF909090have|r %s  |cFF909090earned|r %s  |cFF909090max|r %s",
                    tostring(info.name),
                    tostring(entry.currencyIdentifier),
                    tostring(info.quantity),
                    tostring(info.totalEarned),
                    tostring(info.maxQuantity)
                ))
            end
        end
    end

    CrestPlanner:Print(string.format(
        "Captured %d currency rows, %d of them crests.",
        #entries,
        crestCount
    ))
end
