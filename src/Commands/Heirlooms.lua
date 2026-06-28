local Heirlooms = EredarEngineering:CreateModule()

function Heirlooms:CreateForClass(classStringId)
    print("Creating heirlooms for class: " .. classStringId)
end

function Heirlooms:Create(itemId)
    print("Creating heirloom for item: " .. itemId)
    local foo = C_Heirloom.CreateHeirloomByItemID(itemId)
end

_G.EredarEngineering.Commands.Heirlooms = Heirlooms
