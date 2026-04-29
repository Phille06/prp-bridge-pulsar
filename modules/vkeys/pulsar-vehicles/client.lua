local vkeys = {}

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(vehicle, plate)
    local vehEnt = Entity(vehicle)
    if not vehEnt or not vehEnt.state or not vehEnt.state.VIN then return end

    TriggerServerEvent('pulsar-vehicles:prp-bridge:giveKey', NetworkGetNetworkIdFromEntity(vehicle))
end

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(vehicle, plate)
    local vehEnt = Entity(vehicle)
    if not vehEnt or not vehEnt.state or not vehEnt.state.VIN then return end

    TriggerServerEvent('pulsar-vehicles:prp-bridge:removeKey', NetworkGetNetworkIdFromEntity(vehicle))
end

return vkeys