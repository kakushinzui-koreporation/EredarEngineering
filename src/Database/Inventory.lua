local Inventory = EredarEngineering:CreateModule()
Inventory.Bags = {
    MainBag = 0,
    FirstBag = 1,
    LastBag = 4,
    ReagentBag = 5,
}


_G.EredarEngineering.Database.Inventory = Inventory
