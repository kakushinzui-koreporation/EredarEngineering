if not EredarEngineering then
    print("|cFFFF0000[EredarEngineering]|r  module not found.")
    return
end

if not EredarEngineering.Commands then
    print("|cFFFF0000[EredarEngineering]|r Commands module not found. Slash commands will not work")
    return
end

local SlashCommands = {}
SlashCommands.Meta = {}
SlashCommands.Meta.Names = {
    RELOAD_UI = "RELOAD_UI",
    ACTION_BARS_SETUP = "ACTION_BARS_SETUP"
}

local slashCommandNames = SlashCommands.Meta.Names


SlashCommands.Meta.CommandList = {
    [slashCommandNames.RELOAD_UI] = {
        aliases = { "rr", "aa", "ww", "ss", "dd" },
        name = EredarEngineering.Commands.Meta.Names.reloadUI,
        slashCommandName = slashCommandNames.RELOAD_UI
    },
    [slashCommandNames.ACTION_BARS_SETUP] = {
        aliases = { "action-bars-setup" },
        slashCommandName = slashCommandNames.ACTION_BARS_SETUP
    }
}

function SlashCommands:RegisterSlashCommand(commandName, commandAliases)
    for i, commandAlias in ipairs(commandAliases) do
        _G["SLASH_" .. commandName .. i] = "/" .. commandAlias
    end
end

local reloadUIData = SlashCommands.Meta.CommandList[slashCommandNames.RELOAD_UI]

for i, commandAliasData in ipairs(reloadUIData.aliases) do
    SlashCommands:RegisterSlashCommand(slashCommandNames.RELOAD_UI, reloadUIData.aliases)
end

function SlashCommands:ReloadUI()
    EredarEngineering.Commands:ReloadUI()
end


SlashCmdList[SlashCommands.Meta.Names.RELOAD_UI] = function(msg, editBox)
    SlashCommands:ReloadUI()
end


local actionBarsSetupData = SlashCommands.Meta.CommandList[slashCommandNames.ACTION_BARS_SETUP]
SlashCommands:RegisterSlashCommand(slashCommandNames.ACTION_BARS_SETUP, actionBarsSetupData.aliases)

SlashCmdList[slashCommandNames.ACTION_BARS_SETUP] = function()
    EredarEngineering.ActionBars:EnableQuickstartBars()
end

_G.EredarEngineering.SlashCommands = SlashCommands
