local Controls = {}

local PREFIX = "|cFF00FF00[EredarEngineering]|r "
local ERROR_PREFIX = "|cFFFF0000[EredarEngineering]|r "
local HEADER_PREFIX = "|cFFFFFF00[EredarEngineering]|r "

local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
local setCVar = C_CVar and C_CVar.SetCVar or SetCVar
local getCVarDefault = C_CVar and C_CVar.GetCVarDefault or GetCVarDefault

local SECTIONS = { "Controls", "Camera", "Mouse" }

local CONTROL_SETTINGS = {
    { key = "autoLoot",           cvar = "autoLootDefault",    label = "Auto Loot",                  kind = "boolean", section = "Controls" },
    -- writeProtected = true: confirmed live (2026-07-03) that WoW only accepts a change to this
    -- CVar from a genuine hardware click on its own checkbox. C_CVar.SetCVar("deselectOnClick", ...)
    -- returns true (not the nil the client uses for ordinary secure-CVar rejection) from every
    -- insecure origin tried -- addon code, /console, /run, and even the live Setting object's
    -- :SetValue() -- yet GetCVar never reflects the change. Reads are unaffected and stay accurate.
    { key = "stickyTargeting",    cvar = "deselectOnClick",    label = "Sticky Targeting",           kind = "boolean", section = "Controls", inverted = true, writeProtected = true },
    { key = "lootAtMouse",        cvar = "lootUnderMouse",     label = "Loot at Mouse",              kind = "boolean", section = "Controls" },
    { key = "autoDismountFlying", cvar = "autoDismountFlying", label = "Auto Dismount while Flying", kind = "boolean", section = "Controls" },
    { key = "autoCancelAway",     cvar = "autoClearAFK",       label = "Auto Cancel Away Mode",      kind = "boolean", section = "Controls" },
    { key = "interactOnLeftClick", cvar = "interactOnLeftClick", label = "Interact On Left Click",   kind = "boolean", section = "Controls" },
    { key = "combineBags",        cvar = "combinedBags",       label = "Combine Bags",               kind = "boolean", section = "Controls" },
    { key = "interactKeySound",   cvar = "softTargettingInteractKeySound", label = "Interact Key Sound Cue", kind = "boolean", section = "Controls" },
    -- proxy = true: a Settings.RegisterProxySetting widget with no plain console variable behind
    -- it. Get/Set route through a live Setting object instead of C_CVar -- see readSetting/writeSetting.
    { key = "enableInteractKey",  cvar = "PROXY_ENABLE_INTERACT", label = "Enable Interact Key",     kind = "boolean", section = "Controls", proxy = true },
    -- kind = "enum": closed set of valid raw string values, confirmed live (2026-07-03) that
    -- the live Setting object's :SetValue() takes the same raw string the dropdown stores, no
    -- key-code mapping needed. See normalizeEnumValue.
    { key = "lootKey",            cvar = "AUTOLOOTTOGGLE",     label = "Loot Key",                   kind = "enum",  section = "Controls", proxy = true, values = { "SHIFT", "CTRL", "ALT", "NONE" } },

    { key = "cameraWaterCollision", cvar = "cameraWaterCollision", label = "Water Collision", kind = "boolean", section = "Camera" },
    -- kind = "enum" with numeric values: confirmed live (2026-07-03) via /ee-controls dump that
    -- this row's dropdown options are a closed set of 4 specific integers -- {0, 1, 2, 4}, not
    -- a contiguous slider range -- so it was reclassified out of kind = "number". See
    -- normalizeEnumValue for how numeric enums differ from lootKey's string enum.
    { key = "cameraFollowStyle",    cvar = "cameraSmoothStyle",   label = "Camera Following Style", kind = "enum", section = "Camera", values = { 0, 1, 2, 4 } },
    -- min/max/step confirmed live (2026-07-03) via /ee-controls dump: 90-270 in steps of 10
    -- (steps=18 intervals). Needed by the export/import bit layout (see Controls:Export) to
    -- know how many bits a kind = "number" value packs into.
    { key = "autoFollowSpeed",      cvar = "PROXY_CAMERA_SPEED",  label = "Auto Follow Speed",  kind = "number", section = "Camera", proxy = true, min = 90, max = 270, step = 10 },

    { key = "lockCursor",  cvar = "ClipCursor",     label = "Lock Cursor to Window", kind = "boolean", section = "Mouse" },
    { key = "invertMouse", cvar = "mouseInvertPitch", label = "Invert Mouse",        kind = "boolean", section = "Mouse" },
    -- min/max/step confirmed live (2026-07-03), see autoFollowSpeed comment above.
    { key = "mouseLookSpeed", cvar = "PROXY_MOUSE_LOOK_SPEED", label = "Mouse Look Speed", kind = "number", section = "Mouse", proxy = true, min = 90, max = 270, step = 10 },

    { key = "interactKey",      cvar = "SoftTargetInteract",     label = "Interact Key mode",      kind = "number", section = "Controls", notInUI = true },
    { key = "interactKeyArc",   cvar = "SoftTargetInteractArc",  label = "Interact Key arc",       kind = "number", section = "Controls", notInUI = true },
    { key = "interactIconOnly", cvar = "SoftTargetIconInteract", label = "Interact Key icon only", kind = "number", section = "Controls", notInUI = true },
}

local settingByKey = {}
local settingByVariable = {}
for _, setting in ipairs(CONTROL_SETTINGS) do
    settingByKey[setting.key] = setting
    settingByVariable[setting.cvar] = setting
end

local function settingsInSection(section)
    local matches = {}
    for _, setting in ipairs(CONTROL_SETTINGS) do
        if setting.section == section and not setting.notInUI then
            table.insert(matches, setting)
        end
    end
    return matches
end

local function settingsNotInUI()
    local matches = {}
    for _, setting in ipairs(CONTROL_SETTINGS) do
        if setting.notInUI then
            table.insert(matches, setting)
        end
    end
    return matches
end

local function forEachGroup(callback)
    for _, section in ipairs(SECTIONS) do
        callback(section, settingsInSection(section))
    end
    callback("Not in UI", settingsNotInUI())
end

local function cvarExists(cvar)
    return getCVar(cvar) ~= nil
end

local function rawIsOne(rawValue)
    return rawValue == "1" or rawValue == 1 or rawValue == true
end

-- Proxy-backed settings (see CONTROL_SETTINGS `proxy = true`) have no plain console variable:
-- their value only lives on a live Setting object, handed to us either by Settings.GetSetting
-- (if this client exposes it) or by /ee-controls dump caching it while the row was on screen.
local proxySettingCache = {}

local function cacheLiveSetting(variable, settingObj)
    if variable and settingObj then
        proxySettingCache[variable] = settingObj
    end
end

local function findLiveSetting(variable)
    if Settings and Settings.GetSetting then
        local ok, found = pcall(Settings.GetSetting, variable)
        if ok and found then
            cacheLiveSetting(variable, found)
            return found
        end
    end
    return proxySettingCache[variable]
end

-- Reads a setting's raw value. Returns (value, state) where state is one of:
--   "present" - value read successfully
--   "missing" - confirmed absent on this client (plain CVar) or GetValue() itself errored
--   "unseen"  - proxy setting with no live Setting reference yet this session
local function readSetting(setting)
    if not setting.proxy then
        local raw = getCVar(setting.cvar)
        if raw == nil then
            return nil, "missing"
        end
        return raw, "present"
    end

    local liveSetting = findLiveSetting(setting.cvar)
    if not liveSetting then
        return nil, "unseen"
    end
    local ok, value = pcall(function() return liveSetting:GetValue() end)
    if not ok then
        return nil, "missing"
    end
    return value, "present"
end

local function writeSetting(setting, value)
    if not setting.proxy then
        local raw = value
        if type(raw) == "boolean" then
            raw = raw and "1" or "0"
        end
        return pcall(setCVar, setting.cvar, tostring(raw))
    end

    local liveSetting = findLiveSetting(setting.cvar)
    if not liveSetting then
        return false, "no live Setting reference for " .. setting.cvar ..
            " yet -- open its Options page (or run /ee-controls dump) this session, then retry"
    end
    local ok = pcall(function() liveSetting:SetValue(value) end)
    if not ok then
        return false, "SetValue failed on live Setting object for " .. setting.cvar
    end
    return true
end

-- Membership check against a `kind = "enum"` setting's closed `values` list -- the Lua
-- equivalent of a TypeScript `type X = "A" | "B" | "C"` union, enforced at the one point every
-- write path (addon code and /ee-controls set) funnels through. `values` holds either all
-- strings (case-insensitive match, e.g. lootKey's SHIFT/CTRL/ALT/NONE) or all numbers
-- (cameraFollowStyle's closed {0, 1, 2, 4}, confirmed live 2026-07-03 to not be a contiguous
-- range) -- never a mix, so the first entry's type decides which comparison to use.
local function normalizeEnumValue(setting, value)
    if type(setting.values[1]) == "number" then
        local numeric = tonumber(value)
        if numeric == nil then
            return nil
        end
        for _, allowed in ipairs(setting.values) do
            if allowed == numeric then
                return allowed
            end
        end
        return nil
    end

    if type(value) ~= "string" then
        return nil
    end
    local upper = value:upper()
    for _, allowed in ipairs(setting.values) do
        if allowed == upper then
            return allowed
        end
    end
    return nil
end

local function boolFromRaw(setting, raw)
    local enabled = rawIsOne(raw)
    if setting.inverted then
        enabled = not enabled
    end
    return enabled
end

local function writeBoolean(setting, enabled)
    local storeOne = enabled
    if setting.inverted then
        storeOne = not enabled
    end
    return writeSetting(setting, storeOne)
end

function Controls:Get(key)
    local setting = settingByKey[key]
    if not setting then
        return nil
    end
    local raw, state = readSetting(setting)
    if state ~= "present" then
        return nil
    end
    if setting.kind == "boolean" then
        return boolFromRaw(setting, raw)
    end
    return raw
end

function Controls:Set(key, value)
    local setting = settingByKey[key]
    if not setting then
        return false, "unknown setting key: " .. tostring(key)
    end
    if setting.writeProtected then
        return false, setting.cvar .. " is write-protected -- WoW only accepts a change to it " ..
            "from a real click on its own checkbox, not from addon or slash-command code"
    end
    if not setting.proxy and not cvarExists(setting.cvar) then
        return false, "CVar not present on this client: " .. setting.cvar
    end
    if setting.kind == "boolean" then
        return writeBoolean(setting, value == true)
    end
    if setting.kind == "enum" then
        local normalized = normalizeEnumValue(setting, value)
        if not normalized then
            return false, "invalid value " .. tostring(value) .. " for " .. setting.key ..
                " -- expected one of: " .. table.concat(setting.values, ", ")
        end
        return writeSetting(setting, normalized)
    end
    return writeSetting(setting, value)
end

function Controls:Toggle(key)
    local setting = settingByKey[key]
    if not setting or setting.kind ~= "boolean" then
        return false
    end
    return self:Set(key, not self:Get(key))
end

-- Coerces a raw string value (from a slash command argument, or a SavedVariables entry
-- written by the companion app) into the type Set expects, then funnels it through Set --
-- the same single validated write path everything else uses. Only
-- `kind = "boolean"` needs coercion (on/true/1 -> true, off/false/0 -> false); enum and number
-- kinds pass the raw string straight through unchanged.
function Controls:SetFromString(key, rawValue)
    local setting = settingByKey[key]
    if setting == nil then
        return false, "unknown setting key: " .. tostring(key)
    end

    local desired = rawValue
    if setting.kind == "boolean" then
        if rawValue == "on" or rawValue == "true" or rawValue == "1" or rawValue == true then
            desired = true
        elseif rawValue == "off" or rawValue == "false" or rawValue == "0" or rawValue == false then
            desired = false
        else
            return false, "boolean setting expects on/off: " .. key
        end
    end

    return self:Set(key, desired)
end

-- Export/import: a copy-paste string alternative to the SavedVariables sync channel with the
-- companion app. Only settings with a live Options row or a confirmed value range are
-- encodable -- the notInUI SoftTarget* fields have neither yet, so they're excluded from the
-- payload until their ranges are confirmed (see pending.md decision, 2026-07-03).
-- Bump this whenever the exportable field set's shape changes (add/remove/reorder/resize a
-- field) -- Import already refuses to apply a string whose version doesn't match this one.
local EXPORT_VERSION = 1

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_INDEX = {}
for characterIndex = 1, #BASE64_CHARS do
    BASE64_INDEX[BASE64_CHARS:sub(characterIndex, characterIndex)] = characterIndex - 1
end

local function exportableSettings()
    local list = {}
    for _, setting in ipairs(CONTROL_SETTINGS) do
        if not setting.notInUI then
            table.insert(list, setting)
        end
    end
    return list
end

local function bitsForCount(count)
    local bits = 0
    while (2 ^ bits) < count do
        bits = bits + 1
    end
    return bits
end

local function numberIndexRange(setting)
    return math.floor((setting.max - setting.min) / setting.step + 0.5)
end

-- Dispatch table (see [[dispatch-table-pattern]] in Cognitio): one entry per `kind`, each
-- bundling the three behaviors that kind needs for export/import. Replaces what used to be
-- the same if/elseif chain on setting.kind repeated three times over -- adding a new kind is
-- a new table entry here, not a new branch in three separate functions.
local KIND_STRATEGIES = {
    boolean = {
        width = function(setting)
            return 1
        end,
        encode = function(setting, value)
            return value and 1 or 0
        end,
        decode = function(setting, index)
            return index ~= 0
        end,
    },
    enum = {
        width = function(setting)
            return bitsForCount(#setting.values)
        end,
        -- Routes through normalizeEnumValue first (same gate Controls:Set uses) instead of
        -- comparing `value` against setting.values directly: a plain (non-proxy) CVar's raw
        -- value is always a string ("1"), even for a numeric enum like cameraFollowStyle whose
        -- values are Lua numbers -- a bare `==` would never match without this coercion.
        encode = function(setting, value)
            local normalized = normalizeEnumValue(setting, value)
            if normalized == nil then
                return nil
            end
            for valueIndex, allowedValue in ipairs(setting.values) do
                if allowedValue == normalized then
                    return valueIndex - 1
                end
            end
            return nil
        end,
        decode = function(setting, index)
            local clampedIndex = math.max(0, math.min(index, #setting.values - 1))
            return setting.values[clampedIndex + 1]
        end,
    },
    number = {
        width = function(setting)
            return bitsForCount(numberIndexRange(setting) + 1)
        end,
        encode = function(setting, value)
            local numericValue = tonumber(value)
            if numericValue == nil then
                return nil
            end
            local maxIndex = numberIndexRange(setting)
            local index = math.floor((numericValue - setting.min) / setting.step + 0.5)
            if index < 0 then index = 0 end
            if index > maxIndex then index = maxIndex end
            return index
        end,
        decode = function(setting, index)
            local clampedIndex = math.max(0, math.min(index, numberIndexRange(setting)))
            return setting.min + clampedIndex * setting.step
        end,
    },
}

local function kindStrategy(setting)
    local strategy = KIND_STRATEGIES[setting.kind]
    if not strategy then
        error("no KIND_STRATEGIES entry for kind " .. tostring(setting.kind))
    end
    return strategy
end

local function fieldBitWidth(setting)
    return kindStrategy(setting).width(setting)
end

local function encodeFieldValue(setting, value)
    return kindStrategy(setting).encode(setting, value)
end

local function decodeFieldValue(setting, index)
    return kindStrategy(setting).decode(setting, index)
end

-- Packs {width, value} fields into a byte array, MSB-first, zero-padding the final byte to a
-- full byte. Pure arithmetic, no bit library -- Lua 5.1 (WoW's runtime) has no bitwise
-- operators, and this avoids depending on one existing on the client.
local function packFields(fieldList)
    local bytes = {}
    local accumulator, accumulatedBitCount = 0, 0
    for _, field in ipairs(fieldList) do
        for bitPosition = field.width - 1, 0, -1 do
            local bitValue = math.floor(field.value / (2 ^ bitPosition)) % 2
            accumulator = accumulator * 2 + bitValue
            accumulatedBitCount = accumulatedBitCount + 1
            if accumulatedBitCount == 8 then
                table.insert(bytes, accumulator)
                accumulator, accumulatedBitCount = 0, 0
            end
        end
    end
    if accumulatedBitCount > 0 then
        table.insert(bytes, accumulator * (2 ^ (8 - accumulatedBitCount)))
    end
    return bytes
end

-- Inverse of packFields: reads `widths`, in the same order used to pack them, from a byte array.
local function unpackFields(bytes, widths)
    local byteIndex, bitIndex = 1, 7
    local function nextBit()
        local byte = bytes[byteIndex] or 0
        local bitValue = math.floor(byte / (2 ^ bitIndex)) % 2
        bitIndex = bitIndex - 1
        if bitIndex < 0 then
            bitIndex, byteIndex = 7, byteIndex + 1
        end
        return bitValue
    end
    local values = {}
    for _, width in ipairs(widths) do
        local value = 0
        for _ = 1, width do
            value = value * 2 + nextBit()
        end
        table.insert(values, value)
    end
    return values
end

local function checksumOf(bytes)
    local sum = 0
    for _, byteValue in ipairs(bytes) do
        sum = (sum + byteValue) % 256
    end
    return sum
end

-- Standard base64: every 3 input bytes become 4 output characters, each character indexing 6
-- bits of the 24-bit group formed by those 3 bytes. See base64Decode for the inverse.
local function base64Encode(bytes)
    local characters = {}
    local groupStart = 1
    while groupStart <= #bytes do
        local byte1, byte2, byte3 = bytes[groupStart], bytes[groupStart + 1], bytes[groupStart + 2]
        local charIndex1 = math.floor(byte1 / 4)
        local charIndex2 = (byte1 % 4) * 16 + (byte2 and math.floor(byte2 / 16) or 0)
        local charIndex3 = byte2 and ((byte2 % 16) * 4 + (byte3 and math.floor(byte3 / 64) or 0)) or nil
        local charIndex4 = byte3 and (byte3 % 64) or nil

        table.insert(characters, BASE64_CHARS:sub(charIndex1 + 1, charIndex1 + 1))
        table.insert(characters, BASE64_CHARS:sub(charIndex2 + 1, charIndex2 + 1))
        table.insert(characters, charIndex3 and BASE64_CHARS:sub(charIndex3 + 1, charIndex3 + 1) or "=")
        table.insert(characters, charIndex4 and BASE64_CHARS:sub(charIndex4 + 1, charIndex4 + 1) or "=")

        groupStart = groupStart + 3
    end
    return table.concat(characters)
end

local function base64Decode(exportString)
    exportString = exportString:gsub("%s", "")
    if #exportString == 0 or #exportString % 4 ~= 0 then
        return nil, "invalid length"
    end

    local bytes = {}
    local groupStart = 1
    while groupStart <= #exportString do
        local char1 = exportString:sub(groupStart, groupStart)
        local char2 = exportString:sub(groupStart + 1, groupStart + 1)
        local char3 = exportString:sub(groupStart + 2, groupStart + 2)
        local char4 = exportString:sub(groupStart + 3, groupStart + 3)
        local charIndex1, charIndex2 = BASE64_INDEX[char1], BASE64_INDEX[char2]
        if charIndex1 == nil or charIndex2 == nil then
            return nil, "invalid character"
        end
        table.insert(bytes, charIndex1 * 4 + math.floor(charIndex2 / 16))

        if char3 ~= "=" then
            local charIndex3 = BASE64_INDEX[char3]
            if charIndex3 == nil then
                return nil, "invalid character"
            end
            table.insert(bytes, (charIndex2 % 16) * 16 + math.floor(charIndex3 / 4))

            if char4 ~= "=" then
                local charIndex4 = BASE64_INDEX[char4]
                if charIndex4 == nil then
                    return nil, "invalid character"
                end
                table.insert(bytes, (charIndex3 % 4) * 64 + charIndex4)
            end
        end

        groupStart = groupStart + 4
    end
    return bytes
end

-- Snapshots every exportable setting's current value into a version-prefixed, checksummed
-- byte string, base64-encoded for pasting into chat. Fails closed if any setting's value
-- isn't known yet (UNSEEN proxy, or a plain CVar reporting MISSING) instead of silently
-- exporting a guessed default.
function Controls:Export()
    local fields = exportableSettings()
    local missingLabels = {}
    local encodedFields = {}

    for _, setting in ipairs(fields) do
        local value = Controls:Get(setting.key)
        if value == nil then
            table.insert(missingLabels, setting.label)
        else
            local encoded = encodeFieldValue(setting, value)
            if encoded == nil then
                table.insert(missingLabels, setting.label)
            else
                table.insert(encodedFields, { width = fieldBitWidth(setting), value = encoded })
            end
        end
    end

    if #missingLabels > 0 then
        return nil, "cannot export -- value unknown for: " .. table.concat(missingLabels, ", ") ..
            " -- open their Options page (or run /ee-controls dump) first"
    end

    local payload = { EXPORT_VERSION }
    for _, byteValue in ipairs(packFields(encodedFields)) do
        table.insert(payload, byteValue)
    end
    table.insert(payload, checksumOf(payload))

    return base64Encode(payload)
end

-- Decodes an export string and applies every field through Controls:Set -- the same gate
-- /ee-controls set and the companion app sync already use, so writeProtected/proxy/enum
-- validation still apply per field. Returns (true, results) for a structurally valid string
-- (results is a per-field {setting, value, ok, err} list -- individual fields can still fail
-- to apply) or (false, reason) if the string itself can't be trusted.
function Controls:Import(exportString)
    local bytes, decodeErr = base64Decode(exportString)
    if not bytes then
        return false, "could not decode export string: " .. tostring(decodeErr)
    end
    if #bytes < 3 then
        return false, "export string too short"
    end

    local version = bytes[1]
    local receivedChecksum = bytes[#bytes]
    local payload = {}
    for byteIndex = 1, #bytes - 1 do
        table.insert(payload, bytes[byteIndex])
    end

    if checksumOf(payload) ~= receivedChecksum then
        return false, "checksum mismatch -- the string may be truncated or corrupted"
    end
    if version ~= EXPORT_VERSION then
        return false, "unsupported export version " .. tostring(version) ..
            " (this client expects " .. EXPORT_VERSION .. ")"
    end

    local dataBytes = {}
    for payloadIndex = 2, #payload do
        table.insert(dataBytes, payload[payloadIndex])
    end

    local fields = exportableSettings()
    local widths = {}
    for _, setting in ipairs(fields) do
        table.insert(widths, fieldBitWidth(setting))
    end
    local rawValues = unpackFields(dataBytes, widths)

    local results = {}
    for fieldIndex, setting in ipairs(fields) do
        local decoded = decodeFieldValue(setting, rawValues[fieldIndex])
        local ok, applyErr = Controls:Set(setting.key, decoded)
        table.insert(results, { setting = setting, value = decoded, ok = ok, err = applyErr })
    end
    return true, results
end

function Controls:List()
    print(HEADER_PREFIX .. "=== Controls settings ===")
    forEachGroup(function(groupName, settings)
        if #settings == 0 then
            return
        end
        print(HEADER_PREFIX .. "-- " .. groupName .. " --")
        for _, setting in ipairs(settings) do
            local raw, state = readSetting(setting)
            if state == "missing" then
                print(ERROR_PREFIX .. setting.label .. " (" .. setting.cvar .. "): MISSING")
            elseif state == "unseen" then
                print(ERROR_PREFIX .. setting.label .. " (" .. setting.cvar ..
                    "): UNSEEN -- open its Options page once, or run /ee-controls dump")
            else
                local value = setting.kind == "boolean" and tostring(boolFromRaw(setting, raw)) or tostring(raw)
                print(PREFIX .. setting.label .. " [" .. setting.key .. "] = " .. value)
            end
        end
    end)
end

function Controls:Validate()
    print(HEADER_PREFIX .. "=== Validating Controls CVars against this client ===")
    local present, missing, unseen = 0, 0, 0
    forEachGroup(function(groupName, settings)
        if #settings == 0 then
            return
        end
        print(HEADER_PREFIX .. "-- " .. groupName .. " --")
        for _, setting in ipairs(settings) do
            local raw, state = readSetting(setting)
            if state == "present" then
                present = present + 1
                local defaultLabel = setting.proxy and "n/a (proxy setting)" or tostring(getCVarDefault(setting.cvar))
                print(PREFIX .. "PRESENT  " .. setting.cvar ..
                    " = " .. tostring(raw) .. " (default " .. defaultLabel .. ")")
            elseif state == "unseen" then
                unseen = unseen + 1
                print(HEADER_PREFIX .. "UNSEEN   " .. setting.cvar .. " (" .. setting.label ..
                    ") -- open its Options page once this session, or run /ee-controls dump, then re-validate")
            else
                missing = missing + 1
                print(ERROR_PREFIX .. "MISSING  " .. setting.cvar .. " (" .. setting.label .. ")")
            end
        end
    end)
    print(HEADER_PREFIX .. string.format("Present: %d  Missing: %d  Unseen: %d", present, missing, unseen))
end

function Controls:SelfTest()
    print(HEADER_PREFIX .. "=== Controls self-test (flips booleans and restores) ===")
    forEachGroup(function(groupName, settings)
        if #settings == 0 then
            return
        end
        print(HEADER_PREFIX .. "-- " .. groupName .. " --")
        for _, setting in ipairs(settings) do
            local _, state = readSetting(setting)
            if state ~= "present" then
                print(ERROR_PREFIX .. "SKIP  " .. setting.label .. ": " .. state)
            elseif setting.writeProtected then
                print(HEADER_PREFIX .. "SKIP  " .. setting.label ..
                    " (write-protected -- requires a real UI click, confirmed live)")
            elseif setting.kind ~= "boolean" then
                print(HEADER_PREFIX .. "SKIP  " .. setting.label .. " = " ..
                    tostring(Controls:Get(setting.key)) .. " (non-boolean, not flipped)")
            else
                local before = Controls:Get(setting.key)
                Controls:Set(setting.key, not before)
                local flipped = Controls:Get(setting.key)
                Controls:Set(setting.key, before)
                local restored = Controls:Get(setting.key)
                if flipped == (not before) and restored == before then
                    print(PREFIX .. "PASS  " .. setting.label)
                else
                    print(ERROR_PREFIX .. "FAIL  " .. setting.label ..
                        " (before=" .. tostring(before) .. " flipped=" .. tostring(flipped) ..
                        " restored=" .. tostring(restored) .. ")")
                end
            end
        end
    end)
end

local function settingVariable(setting)
    if type(setting) ~= "table" then
        return nil
    end
    local ok, variable = pcall(function() return setting:GetVariable() end)
    if ok and variable ~= nil then
        return variable
    end
    return rawget(setting, "variable")
end

local function settingName(setting, data)
    local ok, name = pcall(function() return setting:GetName() end)
    if ok and name ~= nil then
        return name
    end
    return data and data.name
end

local function settingValue(setting)
    local ok, value = pcall(function() return setting:GetValue() end)
    if ok then
        return value
    end
    return nil
end

-- kind = "number" rows in CONTROL_SETTINGS have no confirmed value range yet -- this is the
-- blocking step for the export/import bit layout (binary+base64, see pending.md). Sliders
-- expose their range through data.options, either a pre-built table or a factory function
-- returning one (Settings.CreateSliderOptions); the exact accessor names are a best-effort
-- guess same as findScrollBox, so unknown shapes fall back to a raw key dump instead of
-- failing silently.
local function dumpOptionsRange(data)
    local optionsSource = data.options
    local options

    if type(optionsSource) == "function" then
        local ok, called = pcall(optionsSource)
        if not ok or type(called) ~= "table" then
            print(ERROR_PREFIX .. string.format("    data.options() did not return a table (ok=%s, value=%s)",
                tostring(ok), tostring(called)))
            return
        end
        options = called
    elseif type(optionsSource) == "table" then
        options = optionsSource
    else
        local keys = {}
        for k in pairs(data) do table.insert(keys, tostring(k)) end
        print(ERROR_PREFIX .. "    data.options is neither a function nor a table (" ..
            tostring(optionsSource) .. "). data keys: " .. table.concat(keys, ", "))
        return
    end

    -- Confirmed live (2026-07-03) on PROXY_MOUSE_LOOK_SPEED's options table: plain fields
    -- (minValue/maxValue/steps), not getter methods. Try the field first, then fall back to a
    -- same-named method in case another slider's options table is shaped differently.
    local function readField(fieldName, methodName)
        local field = options[fieldName]
        if field ~= nil and type(field) ~= "function" then
            return field
        end
        local method = options[methodName]
        if type(method) ~= "function" then
            return nil
        end
        local callOk, value = pcall(method, options)
        if callOk then
            return value
        end
        return nil
    end

    local minValue = readField("minValue", "GetMinValue")
    local maxValue = readField("maxValue", "GetMaxValue")
    local steps = readField("steps", "GetSteps") or readField("stepValue", "GetStepValue")

    if minValue ~= nil or maxValue ~= nil or steps ~= nil then
        print(PREFIX .. string.format("    range: min=%s max=%s steps=%s",
            tostring(minValue), tostring(maxValue), tostring(steps)))
        return
    end

    -- No slider range found -- confirmed live (2026-07-03) on cameraSmoothStyle that a
    -- `kind = "number"` row can still be dropdown-backed: its options table is a plain array
    -- of entries (options[1], options[2], ...) instead of a min/max/steps record. That's a
    -- signal the registry entry likely belongs to `kind = "enum"`, not `kind = "number"`.
    if options[1] ~= nil then
        print(PREFIX .. string.format("    dropdown-style options (%d entries):", #options))
        for i, entry in ipairs(options) do
            if type(entry) == "table" then
                local parts = {}
                for k, v in pairs(entry) do
                    if type(v) ~= "function" then
                        table.insert(parts, tostring(k) .. "=" .. tostring(v))
                    end
                end
                print(PREFIX .. "      [" .. i .. "] " .. table.concat(parts, ", "))
            else
                print(PREFIX .. "      [" .. i .. "] " .. tostring(entry))
            end
        end
        return
    end

    local keys = {}
    for k in pairs(options) do table.insert(keys, tostring(k)) end
    print(ERROR_PREFIX .. "    options table found but no known min/max/steps accessor. Keys: " ..
        table.concat(keys, ", "))
end

local function dumpRow(frame, index)
    local data = frame and frame.data
    if data == nil then
        print(ERROR_PREFIX .. string.format("  [row %d] frame has no .data field", index))
        return
    end

    local variable = settingVariable(data.setting)
    if variable then
        cacheLiveSetting(variable, data.setting)
        print(PREFIX .. string.format("  %s -> %s = %s",
            tostring(settingName(data.setting, data) or "?"),
            tostring(variable),
            tostring(settingValue(data.setting))))
        local known = settingByVariable[variable]
        if known and known.kind == "number" then
            dumpOptionsRange(data)
        end
    else
        print(ERROR_PREFIX .. string.format("  %s -> not CVar-backed (no data.setting:GetVariable())",
            tostring(data.name or "?")))
    end
end

-- Blizzard's live Settings UI is the only source of real CVar names -- there is no
-- GetAllCVars() API. The exact frame/method names below are best-effort guesses from
-- known Settings API conventions; each lookup degrades to a raw key dump on failure so a
-- single live run tells us what actually exists on this client instead of guessing blind.
local function findScrollBox()
    if SettingsPanel == nil then
        return nil, "SettingsPanel is not loaded yet. Open the Options panel once, then retry."
    end
    if not SettingsPanel:IsShown() then
        return nil, "Open Options and navigate to the target page (e.g. Gameplay > Controls > Mouse) before running dump."
    end

    local container = SettingsPanel.Container
    if container == nil then
        local keys = {}
        for k in pairs(SettingsPanel) do table.insert(keys, tostring(k)) end
        return nil, "SettingsPanel.Container not found. SettingsPanel keys: " .. table.concat(keys, ", ")
    end

    local list = container.SettingsList
    if list == nil then
        local keys = {}
        for k in pairs(container) do table.insert(keys, tostring(k)) end
        return nil, "SettingsPanel.Container.SettingsList not found. Container keys: " .. table.concat(keys, ", ")
    end

    local scrollBox = list.ScrollBox
    if scrollBox == nil then
        local keys = {}
        for k in pairs(list) do table.insert(keys, tostring(k)) end
        return nil, "SettingsList.ScrollBox not found. SettingsList keys: " .. table.concat(keys, ", ")
    end

    return scrollBox
end

local function collectRows(scrollBox)
    local rows = {}

    local ok = pcall(function()
        scrollBox:ForEachFrame(function(frame) table.insert(rows, frame) end)
    end)
    if ok and #rows > 0 then
        return rows
    end

    rows = {}
    ok = pcall(function()
        for _, frame in ipairs(scrollBox:GetFrames() or {}) do
            table.insert(rows, frame)
        end
    end)
    if ok and #rows > 0 then
        return rows
    end

    return {}
end

function Controls:Dump()
    print(HEADER_PREFIX .. "=== Dumping visible rows in the open Settings page ===")

    local scrollBox, err = findScrollBox()
    if scrollBox == nil then
        print(ERROR_PREFIX .. err)
        return
    end

    local rows = collectRows(scrollBox)
    if #rows == 0 then
        print(ERROR_PREFIX .. "No known ScrollBox enumeration method worked (tried ForEachFrame, GetFrames).")
        print(ERROR_PREFIX .. "Function-like keys on the ScrollBox, for manual inspection:")
        for k, v in pairs(scrollBox) do
            if type(v) == "function" then
                print(ERROR_PREFIX .. "  ." .. tostring(k))
            end
        end
        return
    end

    for index, frame in ipairs(rows) do
        dumpRow(frame, index)
    end
    print(HEADER_PREFIX .. string.format("Dumped %d visible row(s). Scroll the panel and re-run to see more.", #rows))
end

local function printUsage()
    print(HEADER_PREFIX .. "Usage: /ee-controls [list | validate | test | dump | get <key> | " ..
        "set <key> <value> | export | import <string>]")
end

local function printGet(key)
    local setting = settingByKey[key]
    if setting == nil then
        print(ERROR_PREFIX .. "Unknown key: " .. tostring(key))
        return
    end
    local _, state = readSetting(setting)
    if state == "unseen" then
        print(ERROR_PREFIX .. key .. ": UNSEEN -- open its Options page once, or run /ee-controls dump")
        return
    end
    if state == "missing" then
        print(ERROR_PREFIX .. key .. ": MISSING")
        return
    end
    print(PREFIX .. key .. " = " .. tostring(Controls:Get(key)))
end

local function printSet(key, value)
    local ok, err = Controls:SetFromString(key, value)
    if ok then
        print(PREFIX .. "Set " .. key .. " -> " .. tostring(Controls:Get(key)))
    else
        print(ERROR_PREFIX .. "Could not set " .. tostring(key) .. ": " .. tostring(err))
    end
end

local function printExport()
    local exportString, err = Controls:Export()
    if not exportString then
        print(ERROR_PREFIX .. err)
        return
    end
    print(HEADER_PREFIX .. "Export string (select and copy):")
    print(PREFIX .. exportString)
end

local function printImport(exportString)
    if exportString == "" then
        print(ERROR_PREFIX .. "Usage: /ee-controls import <string>")
        return
    end
    local ok, resultsOrErr = Controls:Import(exportString)
    if not ok then
        print(ERROR_PREFIX .. "Import failed: " .. tostring(resultsOrErr))
        return
    end
    print(HEADER_PREFIX .. "=== Import results ===")
    for _, result in ipairs(resultsOrErr) do
        if result.ok then
            print(PREFIX .. "OK    " .. result.setting.label .. " -> " .. tostring(result.value))
        else
            print(ERROR_PREFIX .. "SKIP  " .. result.setting.label .. ": " .. tostring(result.err))
        end
    end
end

-- Dispatch table (see [[dispatch-table-pattern]] in Cognitio): maps each slash command name
-- directly to the function that handles it, instead of an if/elseif chain that grows one
-- branch per command. Adding a command is adding an entry here.
local COMMAND_HANDLERS = {
    list = function()
        Controls:List()
    end,
    validate = function()
        Controls:Validate()
    end,
    test = function()
        Controls:SelfTest()
    end,
    dump = function()
        Controls:Dump()
    end,
    export = function()
        printExport()
    end,
    import = function(argument)
        printImport(argument)
    end,
    get = function(argument)
        printGet(argument)
    end,
    set = function(argument)
        local key, value = argument:match("^(%S+)%s+(%S+)$")
        if key then
            printSet(key, value)
        else
            printUsage()
        end
    end,
}

local function handleSlash(message)
    local command, argument = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        command = "list"
    end
    local handler = COMMAND_HANDLERS[command]
    if handler then
        handler(argument)
    else
        printUsage()
    end
end

SLASH_EREDARCONTROLS1 = "/ee-controls"
SLASH_EREDARCONTROLS2 = "/eec"
SlashCmdList["EREDARCONTROLS"] = handleSlash

_G.EredarEngineering.Controls = Controls
