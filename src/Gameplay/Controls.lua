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
    { key = "stickyTargeting",    cvar = "deselectOnClick",    label = "Sticky Targeting",           kind = "boolean", section = "Controls", inverted = true },
    { key = "lootAtMouse",        cvar = "lootUnderMouse",     label = "Loot at Mouse",              kind = "boolean", section = "Controls" },
    { key = "autoDismountFlying", cvar = "autoDismountFlying", label = "Auto Dismount while Flying", kind = "boolean", section = "Controls" },
    { key = "autoCancelAway",     cvar = "autoClearAFK",       label = "Auto Cancel Away Mode",      kind = "boolean", section = "Controls" },
    { key = "interactOnLeftClick", cvar = "interactOnLeftClick", label = "Interact On Left Click",   kind = "boolean", section = "Controls" },
    { key = "combineBags",        cvar = "combinedBags",       label = "Combine Bags",               kind = "boolean", section = "Controls" },
    { key = "interactKeySound",   cvar = "softTargettingInteractKeySound", label = "Interact Key Sound Cue", kind = "boolean", section = "Controls" },
    -- proxy = true: a Settings.RegisterProxySetting widget with no plain console variable behind
    -- it. Get/Set route through a live Setting object instead of C_CVar -- see readSetting/writeSetting.
    { key = "enableInteractKey",  cvar = "PROXY_ENABLE_INTERACT", label = "Enable Interact Key",     kind = "boolean", section = "Controls", proxy = true },
    { key = "lootKey",            cvar = "AUTOLOOTTOGGLE",     label = "Loot Key",                   kind = "string",  section = "Controls", proxy = true },

    { key = "cameraWaterCollision", cvar = "cameraWaterCollision", label = "Water Collision", kind = "boolean", section = "Camera" },

    { key = "lockCursor",  cvar = "ClipCursor",     label = "Lock Cursor to Window", kind = "boolean", section = "Mouse" },
    { key = "invertMouse", cvar = "mouseInvertPitch", label = "Invert Mouse",        kind = "boolean", section = "Mouse" },
    { key = "mouseLookSpeed", cvar = "PROXY_MOUSE_LOOK_SPEED", label = "Mouse Look Speed", kind = "number", section = "Mouse", proxy = true },

    { key = "interactKey",      cvar = "SoftTargetInteract",     label = "Interact Key mode",      kind = "number", section = "Controls", notInUI = true },
    { key = "interactKeyArc",   cvar = "SoftTargetInteractArc",  label = "Interact Key arc",       kind = "number", section = "Controls", notInUI = true },
    { key = "interactIconOnly", cvar = "SoftTargetIconInteract", label = "Interact Key icon only", kind = "number", section = "Controls", notInUI = true },
}

local settingByKey = {}
for _, setting in ipairs(CONTROL_SETTINGS) do
    settingByKey[setting.key] = setting
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
    if not setting.proxy and not cvarExists(setting.cvar) then
        return false, "CVar not present on this client: " .. setting.cvar
    end
    if setting.kind == "boolean" then
        return writeBoolean(setting, value == true)
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
    local setting = settingByKey[key]
    if setting == nil then
        print(ERROR_PREFIX .. "Unknown key: " .. tostring(key))
        return
    end

    local desired = value
    if setting.kind == "boolean" then
        if value == "on" or value == "true" or value == "1" then
            desired = true
        elseif value == "off" or value == "false" or value == "0" then
            desired = false
        else
            print(ERROR_PREFIX .. "Boolean setting expects on/off: " .. key)
            return
        end
    end

    local ok, err = Controls:Set(key, desired)
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
