local TreasuryTimeline = _G.TreasuryTimeline

local Formatting = {}
TreasuryTimeline.Formatting = Formatting

local COPPER_PER_GOLD = 10000

local GAIN_COLOR = "|cFF40C040"
local LOSS_COLOR = "|cFFE05050"
local NEUTRAL_COLOR = "|cFF909090"
local COLOR_END = "|r"

Formatting.GainColor = GAIN_COLOR
Formatting.LossColor = LOSS_COLOR
Formatting.NeutralColor = NEUTRAL_COLOR
Formatting.ColorEnd = COLOR_END

function Formatting:FormatCopper(totalCopper)
    return GetCoinTextureString(math.abs(totalCopper))
end

function Formatting:ColorForAmount(totalCopper)
    if totalCopper > 0 then return GAIN_COLOR end
    if totalCopper < 0 then return LOSS_COLOR end
    return NEUTRAL_COLOR
end

function Formatting:FormatSignedCopper(totalCopper)
    if totalCopper == 0 then
        return NEUTRAL_COLOR .. "0" .. COLOR_END
    end

    local sign = totalCopper > 0 and "+" or "-"
    return self:ColorForAmount(totalCopper) .. sign .. COLOR_END .. self:FormatCopper(totalCopper)
end

function Formatting:FormatCompactGold(totalCopper)
    local goldAmount = math.abs(totalCopper) / COPPER_PER_GOLD
    local sign = totalCopper < 0 and "-" or ""

    if goldAmount >= 1000 then
        return string.format("%s%.1fk", sign, goldAmount / 1000)
    end
    if goldAmount >= 10 then
        return string.format("%s%d", sign, math.floor(goldAmount + 0.5))
    end
    return string.format("%s%.1f", sign, goldAmount)
end
