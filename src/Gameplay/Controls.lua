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

    { key = "cameraWaterCollision", cvar = "cameraWaterCollision", label = "Water Collision", kind = "boolean", section = "Camera" },

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

local function readBoolean(setting)
    local enabled = rawIsOne(getCVar(setting.cvar))
    if setting.inverted then
        return not enabled
    end
    return enabled
end

local function writeBoolean(setting, enabled)
    local storeOne = enabled
    if setting.inverted then
        storeOne = not enabled
    end
    return pcall(setCVar, setting.cvar, storeOne and "1" or "0")
end

function Controls:Get(key)
    local setting = settingByKey[key]
    if not setting then
        return nil
    end
    if setting.kind == "boolean" then
        return readBoolean(setting)
    end
    return getCVar(setting.cvar)
end

function Controls:Set(key, value)
    local setting = settingByKey[key]
    if not setting then
        return false, "unknown setting key: " .. tostring(key)
    end
    if not cvarExists(setting.cvar) then
        return false, "CVar not present on this client: " .. setting.cvar
    end
    if setting.kind == "boolean" then
        local ok = writeBoolean(setting, value == true)
        return ok
    end
    return pcall(setCVar, setting.cvar, tostring(value))
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
            local raw = getCVar(setting.cvar)
            if raw == nil then
                print(ERROR_PREFIX .. setting.label .. " (" .. setting.cvar .. "): MISSING")
            else
                local value = setting.kind == "boolean" and tostring(readBoolean(setting)) or tostring(raw)
                print(PREFIX .. setting.label .. " [" .. setting.key .. "] = " .. value)
            end
        end
    end)
end

function Controls:Validate()
    print(HEADER_PREFIX .. "=== Validating Controls CVars against this client ===")
    local present, missing = 0, 0
    forEachGroup(function(groupName, settings)
        if #settings == 0 then
            return
        end
        print(HEADER_PREFIX .. "-- " .. groupName .. " --")
        for _, setting in ipairs(settings) do
            local raw = getCVar(setting.cvar)
            if raw == nil then
                missing = missing + 1
                print(ERROR_PREFIX .. "MISSING  " .. setting.cvar .. " (" .. setting.label .. ")")
            else
                present = present + 1
                print(PREFIX .. "PRESENT  " .. setting.cvar ..
                    " = " .. tostring(raw) .. " (default " .. tostring(getCVarDefault(setting.cvar)) .. ")")
            end
        end
    end)
    print(HEADER_PREFIX .. string.format("Present: %d  Missing: %d", present, missing))
end

function Controls:SelfTest()
    print(HEADER_PREFIX .. "=== Controls self-test (flips booleans and restores) ===")
    forEachGroup(function(groupName, settings)
        if #settings == 0 then
            return
        end
        print(HEADER_PREFIX .. "-- " .. groupName .. " --")
        for _, setting in ipairs(settings) do
            if not cvarExists(setting.cvar) then
                print(ERROR_PREFIX .. "SKIP  " .. setting.label .. ": CVar missing")
            elseif setting.kind ~= "boolean" then
                print(HEADER_PREFIX .. "SKIP  " .. setting.label .. " = " ..
                    tostring(getCVar(setting.cvar)) .. " (non-boolean, not flipped)")
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

local function printUsage()
    print(HEADER_PREFIX .. "Usage: /ee-controls [list | validate | test | get <key> | set <key> <value>]")
end

local function printGet(key)
    if settingByKey[key] == nil then
        print(ERROR_PREFIX .. "Unknown key: " .. tostring(key))
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
