local FRAME_MIN_WIDTH = 280
local FRAME_MIN_HEIGHT = 300
local WARBAND_MAP_SPELL_ID = 431280

local EngineeringToolsFrame = {}

local function buildFrame()
    local frame = CreateFrame("Frame", "EredarEngineeringToolsFrame", UIParent, "BasicFrameTemplateWithInset") ---@diagnostic disable-line: undefined-global
    frame:SetSize(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame.TitleText:SetText("Eredar Engineering Tools") ---@diagnostic disable-line: undefined-field

    -- A SecureActionButton taints unless it lives under a secure parent, so it goes in a
    -- SecureFrameTemplate container anchored to the frame instead of being parented to it directly.
    local secureContainer = CreateFrame("Frame", "EredarSecureContainer", UIParent, "SecureFrameTemplate") ---@diagnostic disable-line: undefined-global
    secureContainer:SetSize(FRAME_MIN_WIDTH - 40, 36)
    secureContainer:SetPoint("TOP", frame, "TOP", 0, -40)

    local warbandButton = CreateFrame("Button", "EredarWarbandMapButton", secureContainer, "SecureActionButtonTemplate,UIPanelButtonTemplate") ---@diagnostic disable-line: undefined-global
    warbandButton:SetAllPoints(secureContainer)
    warbandButton:SetText("Cast Warband Map")
    warbandButton:RegisterForClicks("AnyDown", "AnyUp")
    warbandButton:SetAttribute("type", "spell")
    warbandButton:SetAttribute("spell", WARBAND_MAP_SPELL_ID)

    local reloadButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") ---@diagnostic disable-line: undefined-global
    reloadButton:SetSize(FRAME_MIN_WIDTH - 40, 36)
    reloadButton:SetPoint("TOP", frame, "TOP", 0, -84)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI() ---@diagnostic disable-line: undefined-global
    end)

    local clearBarsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") ---@diagnostic disable-line: undefined-global
    clearBarsButton:SetSize(FRAME_MIN_WIDTH - 40, 36)
    clearBarsButton:SetPoint("TOP", frame, "TOP", 0, -132)
    clearBarsButton:SetText("Clear All Action Bars")
    clearBarsButton:SetScript("OnClick", function()
        EredarEngineering.Warband:ClearAllActionBars()
    end)

    frame:SetScript("OnShow", function() secureContainer:Show() end)
    frame:SetScript("OnHide", function() secureContainer:Hide() end)

    secureContainer:Hide()
    frame:Hide()
    return frame
end

function EngineeringToolsFrame:Toggle()
    if not self.frame then
        self.frame = buildFrame()
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

_G.EredarEngineering.EngineeringToolsFrame = EngineeringToolsFrame
