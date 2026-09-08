local CrestPlanner = _G.CrestPlanner

local Commitments = {}
CrestPlanner.Commitments = Commitments

function Commitments:All()
    local store = CrestPlanner:GetStore()
    store.commitments = store.commitments or {}

    return store.commitments
end

function Commitments:Add(trackName, amount, label)
    assert(
        amount > 0,
        "A commitment reserves crests you have not spent yet, so it must be positive; a zero or"
            .. " negative reservation would silently inflate what the planner thinks is free"
    )

    local entries = self:All()

    entries[#entries + 1] = {
        track = trackName,
        amount = amount,
        label = label,
        recordedAt = date("%Y-%m-%d %H:%M:%S"),
    }

    return entries[#entries]
end

function Commitments:Clear()
    local store = CrestPlanner:GetStore()
    local removed = #self:All()
    store.commitments = {}

    return removed
end

function Commitments:ReservedFor(trackName)
    local reserved = 0

    for _, entry in ipairs(self:All()) do
        if entry.track == trackName then
            reserved = reserved + entry.amount
        end
    end

    return reserved
end

function Commitments:FreeQuantity(trackName)
    local crest = CrestPlanner.Crests:Get(trackName)
    local held = crest and crest.quantity or 0

    return math.max(0, held - self:ReservedFor(trackName)), held, self:ReservedFor(trackName)
end

function Commitments:Print()
    local entries = self:All()

    if #entries == 0 then
        CrestPlanner:Print(
            "Nothing reserved. Use |cFFFFFFFF/crestplanner commit <track> <amount> <what for>|r"
                .. " to hold crests back for a pending crafting order."
        )
        return
    end

    for _, entry in ipairs(entries) do
        local crest = CrestPlanner.Crests:Get(entry.track)

        CrestPlanner:Print(string.format(
            "|cFFF29E33%d|r %s reserved for |cFFFFFFFF%s|r |cFF909090(%s)|r",
            entry.amount,
            crest and crest.name or entry.track,
            entry.label or "unnamed",
            entry.recordedAt
        ))
    end
end
