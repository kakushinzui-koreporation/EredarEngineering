local EditMode = {}

function EditMode:IsEditModeAvailable()
    return C_EditMode ~= nil
end

function EditMode:GetLayoutInfo()
    if not self:IsEditModeAvailable() then
        return nil, "Edit Mode is not available in this version of the game."
    end

    local layoutInfo = C_EditMode.GetLayouts()
    if not layoutInfo or type(layoutInfo) ~= "table" then
        return nil, "Could not retrieve layout information."
    end

    return layoutInfo, nil
end

local PRESET_LAYOUT_COUNT = 2

function EditMode:SetLayoutByName(layoutNameToFind)
    local layoutInfo, error = self:GetLayoutInfo()
    if error then
        print("|cFFFF0000[EredarEngineering]|r " .. error)
        return
    end
    if not layoutInfo or type(layoutInfo) ~= "table" then
        return nil, "Could not retrieve layout information."
    end

    local existingLayouts = layoutInfo.layouts
    print("|cFF00FF00[EredarEngineering]|r Active layout index: " .. layoutInfo.activeLayout)
    for layoutIndex, layout in ipairs(existingLayouts) do
        local currentLayoutName = layout.layoutName
        if currentLayoutName == layoutNameToFind then
            print("|cFF00FF00[EredarEngineering]|r Found layout: " ..
                currentLayoutName .. " at index " .. layoutIndex)
            C_EditMode.SetActiveLayout(layoutIndex + PRESET_LAYOUT_COUNT)
            return true
        end
    end
end

function EditMode:ExploreLayouts()
    local layoutInfo, error = self:GetLayoutInfo()
    if error then
        print("|cFFFF0000[EredarEngineering]|r " .. error)
        return
    end
    if not layoutInfo or type(layoutInfo) ~= "table" then
        return nil, "Could not retrieve layout information."
    end

    print("|cFFFFFF00[EredarEngineering]|r === Exploring layoutInfo structure ===")
    print("|cFFFFFF00[EredarEngineering]|r layoutInfo type: " .. type(layoutInfo))

    print("|cFFFFFF00[EredarEngineering]|r === All fields in layoutInfo ===")
    for fieldName, fieldValue in pairs(layoutInfo) do
        print("|cFFFFFF00[EredarEngineering]|r Field: " .. fieldName .. " (Type: " .. type(fieldValue) .. ")")
        if type(fieldValue) == "table" then
            print("|cFFFFFF00[EredarEngineering]|r   - Table with " .. #fieldValue .. " entries")
        else
            print("|cFFFFFF00[EredarEngineering]|r   - Value: " .. tostring(fieldValue))
        end
    end

    print("|cFFFFFF00[EredarEngineering]|r === Checking for 'layouts' field ===")
    if layoutInfo.layouts then
        print("|cFF00FF00[EredarEngineering]|r Found 'layouts' field!")
        print("|cFFFFFF00[EredarEngineering]|r layouts type: " .. type(layoutInfo.layouts))
        print("|cFFFFFF00[EredarEngineering]|r Number of layouts: " .. #layoutInfo.layouts)

        print("|cFFFFFF00[EredarEngineering]|r === All layouts in layoutInfo.layouts ===")
        for i, layout in ipairs(layoutInfo.layouts) do
            print("|cFFFFFF00[EredarEngineering]|r --- Layout " .. i .. " ---")
            print("|cFFFFFF00[EredarEngineering]|r Type: " .. type(layout))

            if type(layout) == "table" then
                print("|cFFFFFF00[EredarEngineering]|r Available fields:")
                for fieldName, fieldValue in pairs(layout) do
                    print("|cFFFFFF00[EredarEngineering]|r   - " .. fieldName .. ": " .. tostring(fieldValue))
                end
            else
                print("|cFFFFFF00[EredarEngineering]|r Value: " .. tostring(layout))
            end
        end
    else
        print("|cFFFF0000[EredarEngineering]|r 'layouts' field not found in layoutInfo")
    end

    print("|cFFFFFF00[EredarEngineering]|r === End of exploration ===")
end

_G.EredarEngineering.EditMode = EditMode
