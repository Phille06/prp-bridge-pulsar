local vehiclesToObjects = {} --[[@as table<number, table<number, table>>]]
local entities = {}
local scopedVehicles = {}

---@param model number
local function requestModel(model)
    local timeout = 0
    RequestModel(model)
    while not HasModelLoaded(model) do
        timeout = timeout + 1
        if timeout > 20 then break end
        Wait(0)
    end
end

local function createObject(netId, data)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local timeout = 0
    while not NetworkDoesNetworkIdExist(netId) and timeout < 10 do
        Wait(0)
        entity = NetworkGetEntityFromNetworkId(netId)
        timeout = timeout + 1
    end

    local coords = GetEntityCoords(entity)
    requestModel(data[2])
    local obj = CreateObject(data[2], coords.x, coords.y, coords.z - 1.0, false, true, false)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, data[7][1], data[7][2])
    if data[7][3] or data[7][4] then
        SetEntityCompletelyDisableCollision(obj, data[7][3], data[7][4])
    end

    AttachEntityToEntity(
        obj,
        entity,
        GetEntityBoneIndexByName(entity, data[3]),
        data[4].x, data[4].y, data[4].z,
        data[5].x, data[5].y, data[5].z,
        true,
        true,
        false,
        true,
        data[6],
        true
    )

    entities[obj] = data[1] or {}

    return obj
end

local function deleteEntity(entity)
    entities[entity] = nil
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function reattachObject(netId, objectId, data)
    if not vehiclesToObjects[netId] then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local timeout = 0
    while not NetworkDoesNetworkIdExist(netId) and timeout < 10 do
        Wait(0)
        entity = NetworkGetEntityFromNetworkId(netId)
        timeout = timeout + 1
    end

    if not vehiclesToObjects[netId][objectId] then return end

    local obj = vehiclesToObjects[netId][objectId]?.entity
    if not obj or not DoesEntityExist(obj) then return end

    AttachEntityToEntity(
        obj,
        entity,
        GetEntityBoneIndexByName(entity, data[3]),
        data[4].x, data[4].y, data[4].z,
        data[5].x, data[5].y, data[5].z,
        true,
        true,
        false,
        true,
        data[6],
        true
    )

    entities[obj] = data[1] or {}
end

AddStateBagChangeHandler("VehTempAttachObjects", nil, function(bagName, key, value, reserved, replicated)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    if not NetworkGetEntityIsNetworked(entity) then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    scopedVehicles[entity] = netId
    if not vehiclesToObjects[netId] then vehiclesToObjects[netId] = {} end

    pcall(function()
        if value then
            for objectId, data in pairs(value) do
                if not vehiclesToObjects[netId][objectId] then
                    data.entity = createObject(netId, data)
                    vehiclesToObjects[netId][objectId] = data
                else
                    reattachObject(netId, objectId, data)
                end
            end
        elseif vehiclesToObjects[netId] ~= nil then
            for objectId, data in pairs(vehiclesToObjects[netId]) do
                deleteEntity(data.entity)
                vehiclesToObjects[netId][objectId] = nil
            end
        end
    end)

    pcall(function()
        for objectId, data in pairs(vehiclesToObjects[netId]) do
            if not value[objectId] and data.entity and DoesEntityExist(data.entity) then
                deleteEntity(data.entity)
                vehiclesToObjects[netId][objectId] = nil
            end
        end
    end)
end)

CreateThread(function()
    while true do
        pcall(function()
            for entity, netId in pairs(scopedVehicles) do
                if not DoesEntityExist(entity) then
                    -- vehicle is no longer in scope
                    if vehiclesToObjects[netId] ~= nil then
                        for objectId, data in pairs(vehiclesToObjects[netId]) do
                            if data and data.entity ~= nil and DoesEntityExist(data.entity) then
                                deleteEntity(data.entity)
                                vehiclesToObjects[netId][objectId].entity = nil
                            end
                        end
                        vehiclesToObjects[netId] = nil
                    end

                    scopedVehicles[entity] = nil
                end
            end
        end)
        Wait(500)
    end
end)

exports("GetTempVehObjectId", function(entity)
    return entities[entity]
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for entity, _ in pairs(entities) do
        deleteEntity(entity)
    end
end)