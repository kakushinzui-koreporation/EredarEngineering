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
    { key = "autoFollowSpeed",      cvar = "PROXY_CAMERA_SPEED",  label = "Auto Follow Speed",  kind = "number", section = "Camera", proxy = true },

    { key = "lockCursor",  cvar = "ClipCursor",     label = "Lock Cursor to Window", kind = "boolean", section = "Mouse" },
    { key = "invertMouse", cvar = "mouseInvertPitch", label = "Invert Mouse",        kind = "boolean", section = "Mouse" },
    { key = "mouseLookSpeed", cvar = "PROXY_MOUSE_LOOK_SPEED", label = "Mouse Look Speed", kind = "number", section = "Mouse", proxy = true },

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
    print(HEADER_PREFIX .. "Usage: /ee-controls [list | validate | test | dump | get <key> | set <key> <value>]")
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

local function handleSlash(message)
    local command, argument = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "list" then
        Controls:List()
    elseif command == "validate" then
        Controls:Validate()
    elseif command == "test" then
        Controls:SelfTest()
    elseif command == "dump" then
        Controls:Dump()
    elseif command == "get" then
        printGet(argument)
    elseif command == "set" then
        local key, value = argument:match("^(%S+)%s+(%S+)$")
        if key then
            printSet(key, value)
        else
            printUsage()
        end
    else
        printUsage()
    end
end

SLASH_EREDARCONTROLS1 = "/ee-controls"
SLASH_EREDARCONTROLS2 = "/eec"
SlashCmdList["EREDARCONTROLS"] = handleSlash

_G.EredarEngineering.Controls = Controls
