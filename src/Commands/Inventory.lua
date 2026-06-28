local Inventory = EredarEngineering:CreateModule()


local function IterateInventory()
    for bagID = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bagID)

        for slotID = 1, 2 do
            local itemID = C_Container.GetContainerItemID(bagID, slotID)

            if itemID then
                local itemName, _, itemQuality, itemLevel = C_Item.GetItemInfo(itemID)

                print(string.format("Objeto: %s | iLvl: %d | Calidad: %d", itemName, itemLevel, itemQuality))
            end
        end
    end
end

local function TraverseReagentBag()
    local reagentBagID = EredarEngineering.Database.Inventory.Bags.ReagentBag
    local numSlots = C_Container.GetContainerNumSlots(reagentBagID)

    for slotID = 1, numSlots do
        local itemID = C_Container.GetContainerItemID(reagentBagID, slotID)
        if itemID then
            local itemName, _, itemQuality, itemLevel = C_Item.GetItemInfo(itemID)
            print(string.format("Objeto: %s | iLvl: %d | Calidad: %d", itemName, itemLevel, itemQuality))
        end
    end
end

function Inventory:Traverse()
    TraverseReagentBag()
end

_G.EredarEngineering.Commands.Inventory = Inventory
