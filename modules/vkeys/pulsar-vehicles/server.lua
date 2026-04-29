local vkeys = {}

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local VIN = Entity(vehicle).state.VIN
    if not VIN then return end

    exports['pulsar-vehicles']:KeysAdd(src, VIN)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local VIN = Entity(vehicle).state.VIN
    if not VIN then return end

    exports['pulsar-vehicles']:KeysRemove(src, VIN)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent('pulsar-vehicles:prp-bridge:giveKey', function(netId)
        local src = source
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and DoesEntityExist(vehicle) then
            vkeys.give(src, vehicle)
        end
    end)

    RegisterNetEvent('pulsar-vehicles:prp-bridge:removeKey', function(netId)
        local src = source
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and DoesEntityExist(vehicle) then
            vkeys.remove(src, vehicle)
        end
    end)
end

return vkeys