local CharacterEquipment = EredarEngineering:CreateModule()

function CharacterEquipment:GetPlayerEquipment()
    local playerEquipment = {}
    for slotName, slotData in pairs(EredarEngineering.Database.EquipmentSlots.Data) do
        local slotId = slotData.Id
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            playerEquipment[slotName] = itemLink
        end
    end
    return playerEquipment
end

_G.EredarEngineering.Database.CharacterEquipment = CharacterEquipment
