local Sync = EredarEngineering:CreateModule()

local ALLOWED_CVARS = {
    deselectOnClick      = true,
    autoLootDefault      = true,
    graphicsOutlineMode  = true,
    graphicsViewDistance = true,
}

local function consumePendingCVars(db, applied, rejected)
    db.pendingCVars = nil
    db.lastSync = { applied = applied, rejected = rejected, at = time() }
end

local function reportApplied(applied, rejected)
    if applied == 0 then
        return
    end

    local rejectionNote = rejected > 0
        and string.format(" Rejected %d (not allow-listed).", rejected)
        or ""

    print(string.format(
        "|cFF00FF00[EredarEngineering]|r Applied %d CVar(s) from companion app.%s",
        applied,
        rejectionNote
    ))
end

function Sync:ApplyPendingCVars()
    local db = _G.EredarEngineeringDB
    if type(db) ~= "table" or type(db.pendingCVars) ~= "table" then
        return
    end

    local applied, rejected = 0, 0
    for cvar, value in pairs(db.pendingCVars) do
        if ALLOWED_CVARS[cvar] then
            SetCVar(cvar, tostring(value))
            applied = applied + 1
        else
            rejected = rejected + 1
        end
    end

    consumePendingCVars(db, applied, rejected)
    reportApplied(applied, rejected)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    Sync:ApplyPendingCVars()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

_G.EredarEngineering.Sync = Sync
