local CrestPlanner = _G.CrestPlanner

local TooltipHooks = {}
CrestPlanner.TooltipHooks = TooltipHooks

local PLANNED_TRACK = "Hero"

local HEADING_COLOR = "|cFF8B5CF6"
local GOOD_COLOR = "|cFF40BF40"
local WARN_COLOR = "|cFFF29E33"
local MUTED_COLOR = "|cFF909090"
local COLOR_END = "|r"

local function ownerSlotIdentifier(tooltip)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not owner then return nil end

    if owner.GetID and owner:GetID() and owner:GetID() > 0 then
        local ownerName = owner.GetName and owner:GetName()
        if ownerName and string.find(ownerName, "^Character.*Slot$") then
            return owner:GetID()
        end
    end

    return nil
end

local STATUS_LINES = {
    done = function(slotPlan)
        return GOOD_COLOR .. "Already at " .. slotPlan.targetItemLevel .. COLOR_END
            .. MUTED_COLOR .. " -- no " .. slotPlan.crestName .. " needed here" .. COLOR_END
    end,

    upgradeable = function(slotPlan)
        local estimateMark = slotPlan.costIsObserved and "" or MUTED_COLOR .. " (estimated)" .. COLOR_END
        local rankWord = slotPlan.ranksRemaining == 1 and "rank" or "ranks"

        return string.format(
            "%s%d %s%s to reach %d, costing %s%d %s%s%s",
            WARN_COLOR, slotPlan.ranksRemaining, rankWord, COLOR_END,
            slotPlan.targetItemLevel,
            WARN_COLOR, slotPlan.crestsForThisSlot, slotPlan.crestName, COLOR_END,
            estimateMark
        )
    end,

    needsBetterItem = function(slotPlan)
        return WARN_COLOR .. "Crests cannot get this slot to " .. slotPlan.targetItemLevel .. COLOR_END
            .. MUTED_COLOR .. " -- its track tops out at " .. tostring(slotPlan.ceiling)
            .. ", so this needs a better drop" .. COLOR_END
    end,

    notUpgradeable = function()
        return MUTED_COLOR .. "No upgrade track on this item -- crests do not apply" .. COLOR_END
    end,

    unknown = function()
        return MUTED_COLOR .. "Item level unavailable" .. COLOR_END
    end,
}

function TooltipHooks:AddEquipmentLines(tooltip, slotIdentifier)
    if not CrestPlanner.enabled then return end
    local slotPlan = CrestPlanner.Plan:PlanForSlot(slotIdentifier, PLANNED_TRACK)
    if not slotPlan then return end

    local lineBuilder = STATUS_LINES[slotPlan.status]
    if not lineBuilder then return end

    tooltip:AddLine(" ")
    tooltip:AddLine(HEADING_COLOR .. "Crest Planner" .. COLOR_END)
    tooltip:AddLine(lineBuilder(slotPlan), 1, 1, 1, true)
end

local COMPARISON_COLORS = {
    good = GOOD_COLOR,
    bad = WARN_COLOR,
    neutral = MUTED_COLOR,
}

function TooltipHooks:AddComparisonLines(tooltip, tooltipData)
    if not CrestPlanner.enabled then return end
    local itemLink = tooltipData and tooltipData.hyperlink
    if not itemLink then return end

    local comparison = CrestPlanner.Comparison:ForCandidate(itemLink, tooltipData.lines, PLANNED_TRACK)
    if not comparison then return end

    local text, verdict = CrestPlanner.Comparison:Describe(comparison)
    if not text then return end

    local estimateMark = comparison.costIsObserved and ""
        or MUTED_COLOR .. " (cost estimated)" .. COLOR_END

    tooltip:AddLine(" ")
    tooltip:AddLine(HEADING_COLOR .. "Crest Planner" .. COLOR_END)
    tooltip:AddLine(COMPARISON_COLORS[verdict] .. text .. COLOR_END .. estimateMark, 1, 1, 1, true)
end

function TooltipHooks:AddCrestLines(tooltip, currencyIdentifier)
    if not CrestPlanner.enabled then return end
    local crest = nil
    for _, candidate in ipairs(CrestPlanner.Crests:Ordered()) do
        if candidate.identifier == currencyIdentifier then
            crest = candidate
        end
    end

    if not crest then return end

    local plan = CrestPlanner.Plan:BuildForTrack(crest.track)

    tooltip:AddLine(" ")
    tooltip:AddLine(HEADING_COLOR .. "Crest Planner" .. COLOR_END)

    if crest.capMeasuresEarned then
        local remaining = CrestPlanner.Crests:RemainingEarnableThisSeason(crest.track)
        if remaining == 0 then
            tooltip:AddLine(
                WARN_COLOR .. "Capped this season at " .. crest.seasonMaximum .. COLOR_END
                    .. MUTED_COLOR .. " -- the cap counts what you earned, not what you hold,"
                    .. " so spending frees nothing" .. COLOR_END,
                1, 1, 1, true
            )
        elseif remaining then
            tooltip:AddLine(
                GOOD_COLOR .. remaining .. " more earnable" .. COLOR_END
                    .. MUTED_COLOR .. " before the season cap" .. COLOR_END,
                1, 1, 1, true
            )
        end
    end

    if not plan then return end

    if plan.outlook == "complete" then
        tooltip:AddLine(
            GOOD_COLOR .. "Every slot already sits at " .. plan.targetItemLevel .. COLOR_END,
            1, 1, 1, true
        )
        return
    end

    if plan.outlook == "blocked" then
        tooltip:AddLine(
            MUTED_COLOR .. #plan.blockedSlots .. " slots are below " .. plan.targetItemLevel
                .. ", but their gear tops out lower, so this crest cannot touch them yet."
                .. " Better drops first." .. COLOR_END,
            1, 1, 1, true
        )
        return
    end

    local estimateMark = plan.costIsObserved and "" or MUTED_COLOR .. " (cost estimated)" .. COLOR_END

    tooltip:AddLine(string.format(
        "%s%d %s%s across %d %s to put everything at %d: %s%d%s%s",
        WARN_COLOR, plan.ranksRemaining, plan.ranksRemaining == 1 and "rank" or "ranks", COLOR_END,
        #plan.upgradeableSlots,
        #plan.upgradeableSlots == 1 and "slot" or "slots",
        plan.targetItemLevel,
        WARN_COLOR, plan.crestsRequired, COLOR_END,
        estimateMark
    ), 1, 1, 1, true)

    if plan.crestsShort > 0 then
        tooltip:AddLine(
            MUTED_COLOR .. "You hold " .. plan.crestsHeld .. ", so you are short "
                .. plan.crestsShort .. COLOR_END,
            1, 1, 1, true
        )

        local trade = CrestPlanner.Plan:TradeableFromLowerTracks(crest.track)
        if trade and trade.totalPromoted > 0 then
            if trade.blockedByCap then
                tooltip:AddLine(
                    MUTED_COLOR .. "Trading up is worth about " .. trade.totalPromoted
                        .. " here, but it respects the cap, so none of it lands until the cap rises."
                        .. COLOR_END,
                    1, 1, 1, true
                )
            else
                tooltip:AddLine(
                    GOOD_COLOR .. "Trading lower crests up can fill " .. trade.usableNow
                        .. " of what is left under the cap" .. COLOR_END
                        .. MUTED_COLOR .. " (assumes " .. trade.ratio .. ":1)" .. COLOR_END,
                    1, 1, 1, true
                )
            end
        end

        local weeks, increasePerWeek = CrestPlanner.Plan:WeeksOfCapToClose(crest.track, plan.crestsShort)
        if weeks then
            local _, increaseIsObserved = CrestPlanner.Crests:WeeklyCapIncrease(crest.track)
            tooltip:AddLine(
                MUTED_COLOR .. "At " .. increasePerWeek .. " of cap per week"
                    .. (increaseIsObserved and "" or " (estimated)")
                    .. ", that is " .. weeks .. (weeks == 1 and " more week." or " more weeks.") .. COLOR_END,
                1, 1, 1, true
            )
        end
    end
end

local function installModernHooks()
    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then
        return false
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end

        local slotIdentifier = ownerSlotIdentifier(tooltip)
        if slotIdentifier then
            TooltipHooks:AddEquipmentLines(tooltip, slotIdentifier)
            return
        end

        TooltipHooks:AddComparisonLines(tooltip, tooltipData)
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, tooltipData)
        local currencyIdentifier = tooltipData and tooltipData.id
        if currencyIdentifier then
            TooltipHooks:AddCrestLines(tooltip, currencyIdentifier)
        end
    end)

    return true
end

function TooltipHooks:Initialize()
    if installModernHooks() then
        self.installed = true
        return
    end

    self.installed = false

    CrestPlanner:Print(
        "|cFFE05050TooltipDataProcessor is unavailable on this client, so the tooltip lines are off."
            .. " The slash commands still work.|r"
    )
end
