local CharacterClasses = EredarEngineering:CreateModule()

CharacterClasses.Names = {
    Warrior = "WARRIOR",
    Hunter = "HUNTER",
    Mage = "MAGE",
    Rogue = "ROGUE",
    Priest = "PRIEST",
    Warlock = "WARLOCK",
    Paladin = "PALADIN",
    Druid = "DRUID",
    Shaman = "SHAMAN",
    Monk = "MONK",
    DemonHunter = "DEMONHUNTER",
    DeathKnight = "DEATHKNIGHT",
    Evoker = "EVOKER"
}

if not CharacterClasses.Names then
    print("|cFFFF0000[EredarEngineering]|r CharacterClasses.Names not found.")
    return
end

local classNames = CharacterClasses.Names

CharacterClasses.Data = {
    [classNames.Warrior] = {
        Name = "Warrior",
        Id = 1
    },
    [classNames.Hunter] = {
        Name = "Hunter",
        Id = 3
    },
    [classNames.Mage] = {
        Name = "Mage",
        Id = 8
    },
    [classNames.Rogue] = {
        Name = "Rogue",
        Id = 4
    },
    [classNames.Priest] = {
        Name = "Priest",
        Id = 5
    },
    [classNames.Warlock] = {
        Name = "Warlock",
        Id = 9
    },
    [classNames.Paladin] = {
        Name = "Paladin",
        Id = 2
    },
    [classNames.Druid] = {
        Name = "Druid",
        Id = 11
    },
    [classNames.Shaman] = {
        Name = "Shaman",
        Id = 7
    },
    [classNames.Monk] = {
        Name = "Monk",
        Id = 10
    },
    [classNames.DemonHunter] = {
        Name = "Demon Hunter",
        Id = 12
    },
    [classNames.DeathKnight] = {
        Name = "Death Knight",
        Id = 6
    },
    [classNames.Evoker] = {
        Name = "Evoker",
        Id = 13
    }
}


function CharacterClasses:GetPlayerClassFilename()
    local localizedClassName, classFilename, classId = UnitClass("player")
    return classFilename
end

_G.EredarEngineering.Database.CharacterClasses = CharacterClasses
