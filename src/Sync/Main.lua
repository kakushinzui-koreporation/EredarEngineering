local Sync = EredarEngineering:CreateModule()

-- No allow-list here: EredarEngineering.Controls:SetFromString(key, value) already funnels
-- through Controls:Set, which is the single validated write path (settingByKey rejects
-- unknown keys, and writeProtected/proxy/enum handling all live there). Keeping a second,
-- separate allow-list here is exactly what went stale before -- it named CVars from an old
-- prototype and never got updated when the real Controls registry grew.
local function consumePendingCVars(db, applied, rejected)
    db.pendingCVars = nil
    db.lastSync = { applied = applied, rejected = rejected, at = time() }
end

local function reportApplied(applied, rejected)
    if applied == 0 then
        return
    end

    local rejectionNote = rejected > 0
        and string.format(" Rejected %d (unknown key or write-protected).", rejected)
        or ""

    print(string.format(
        "|cFF00FF00[EredarEngineering]|r Applied %d setting(s) from companion app.%s",
        applied,
        rejectionNote
    ))
end

-- db.pendingCVars is keyed by the setting's registry `key` (e.g. "autoDismountFlying",
-- "lootKey"), not the raw CVar name -- see the companion app's setting definitions.
function Sync:ApplyPendingCVars()
    local db = _G.EredarEngineeringDB
    if type(db) ~= "table" or type(db.pendingCVars) ~= "table" then
        return
    end

    local applied, rejected = 0, 0
    for key, rawValue in pairs(db.pendingCVars) do
        local ok = EredarEngineering.Controls:SetFromString(key, rawValue)
        if ok then
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
