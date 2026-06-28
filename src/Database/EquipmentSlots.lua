local EquipmentSlots = EredarEngineering:CreateModule()

EquipmentSlots.Names = {
    Head = "Head",
    Neck = "Neck",
    Shoulders = "Shoulders",
    Chest = "Chest",
    Back = "Back",
    Tabard = "Tabard",
    Waist = "Waist",
    Legs = "Legs",
    Feet = "Feet",
    Wrists = "Wrists",
    Hands = "Hands",
    Finger1 = "Finger1",
    Finger2 = "Finger2",
    MainHand = "MainHand",
    OffHand = "Off-hand",
    Trinket1 = "Trinket1",
    Trinket2 = "Trinket2",

}

EquipmentSlots.Data = {
    [EquipmentSlots.Names.Head] = {
        Name = EquipmentSlots.Names.Head,
        Id = 1
    },
    [EquipmentSlots.Names.Neck] = {
        Name = EquipmentSlots.Names.Neck,
        Id = 2
    },
    [EquipmentSlots.Names.Shoulders] = {
        Name = EquipmentSlots.Names.Shoulders,
        Id = 3
    },
    [EquipmentSlots.Names.Chest] = {
        Name = EquipmentSlots.Names.Chest,
        Id = 4
    },
    [EquipmentSlots.Names.Waist] = {
        Name = EquipmentSlots.Names.Waist,
        Id = 5
    },
    [EquipmentSlots.Names.Legs] = {
        Name = EquipmentSlots.Names.Legs,
        Id = 6
    },
    [EquipmentSlots.Names.Feet] = {
        Name = EquipmentSlots.Names.Feet,
        Id = 7
    },
    [EquipmentSlots.Names.Wrists] = {
        Name = EquipmentSlots.Names.Wrists,
        Id = 8
    },
    [EquipmentSlots.Names.Hands] = {
        Name = EquipmentSlots.Names.Hands,
        Id = 10
    },
    [EquipmentSlots.Names.Finger1] = {
        Name = EquipmentSlots.Names.Finger1,
        Id = 11
    },
    [EquipmentSlots.Names.Finger2] = {
        Name = EquipmentSlots.Names.Finger2,
        Id = 12
    },
    [EquipmentSlots.Names.Trinket1] = {
        Name = EquipmentSlots.Names.Trinket1,
        Id = 13
    },
    [EquipmentSlots.Names.Trinket2] = {
        Name = EquipmentSlots.Names.Trinket2,
        Id = 14
    },
    [EquipmentSlots.Names.Back] = {
        Name = EquipmentSlots.Names.Back,
        Id = 15
    },
    [EquipmentSlots.Names.MainHand] = {
        Name = EquipmentSlots.Names.MainHand,
        Id = 16
    },
    [EquipmentSlots.Names.OffHand] = {
        Name = EquipmentSlots.Names.OffHand,
        Id = 17
    },
    [EquipmentSlots.Names.Tabard] = {
        Name = EquipmentSlots.Names.Tabard,
        Id = 18
    }
}


_G.EredarEngineering.Database.EquipmentSlots = EquipmentSlots
