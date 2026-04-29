---@class SpawnTemporaryVehiclePayload
---@field model  string | number
---@field coords vector3
---@field heading number
---@field plate? string
---@field source? number Player server id (used by pulsar-vehicles to associate spawn)

local ispulsarVehicles = BridgeConfig.VehicleKeys == "pulsar-vehicles"

local function getVehicleModelType(model)
    local tempVehicle = CreateVehicle(model, 0, 0, -200, 0, true, true)
    local spawned = lib.waitFor(function()
        if DoesEntityExist(tempVehicle) then return true end
    end, 'Temp vehicle for type detection failed to spawn', 5000)
    local vehicleType = (spawned and DoesEntityExist(tempVehicle)) and GetVehicleType(tempVehicle) or "automobile"
    if DoesEntityExist(tempVehicle) then DeleteEntity(tempVehicle) end
    return vehicleType
end

---@param payload SpawnTemporaryVehiclePayload
---@return nil | number, string | nil
local function spawnTemporaryVehicle(payload)
    local model = type(payload.model) == 'string' and joaat(payload.model) or payload.model

    local success, response = pcall(function()
        if ispulsarVehicles then
            -- SpawnTemp requires a valid player source for CreateAutomobile.
            -- When no source is available we spawn via CreateVehicleServerSetter and
            -- wire up the pulsar entity state manually so the key system can find a VIN.
            local vehicleType = getVehicleModelType(model)

            local vehicle = CreateVehicleServerSetter(
                model,
                vehicleType,
                payload.coords.x,
                payload.coords.y,
                payload.coords.z,
                payload.heading
            )

            local vehicleSpawned = lib.waitFor(function()
                if DoesEntityExist(vehicle) then return true end
            end, 'Vehicle (pulsar) failed to spawn', 5000)

            if not vehicleSpawned then
                lib.print.error("SpawnTemporaryVehicle: vehicle did not spawn for model:", model)
                return nil
            end

            local plate = payload.plate or exports['pulsar-vehicles']:PlateGenerate(true)
            local VIN = exports['pulsar-vehicles']:VINGenerateLocal()

            SetVehicleNumberPlateText(vehicle, plate)

            local vehState = Entity(vehicle).state
            vehState.VIN          = VIN
            vehState.Owned        = false
            vehState.Locked       = false
            vehState.PlayerDriven = true
            vehState.Fuel         = math.random(50, 100)
            vehState.Plate        = plate
            vehState.Trailer      = GetVehicleType(vehicle) == 'trailer'
            vehState.VEH_IGNITION = false

            return { vehicle = vehicle, plate = plate }
        end

        -- Default spawn path
        local tempVehicle = CreateVehicle(model, 0, 0, -200, 0, true, true)

        local spawned = lib.waitFor(function()
            if DoesEntityExist(tempVehicle) then return true end
        end, 'Vehicle failed to spawn', 5 * 1000)

        if not spawned then
            lib.print.error("Failed to spawn temporary vehicle for model:", model)
            return nil
        end

        local vehicleType = GetVehicleType(tempVehicle)
        DeleteEntity(tempVehicle)

        local vehicle = CreateVehicleServerSetter(
            model,
            vehicleType,
            payload.coords.x,
            payload.coords.y,
            payload.coords.z,
            payload.heading
        )

        local vehicleSpawned = lib.waitFor(function()
            if DoesEntityExist(vehicle) then return true end
        end, 'Vehicle failed to spawn', 5 * 1000)

        if not vehicleSpawned then
            lib.print.error("Failed to spawn vehicle for model:", model)
            return nil
        end

        if payload.plate then
            SetVehicleNumberPlateText(vehicle, payload.plate)
        end

        local plateAvailable = lib.waitFor(function()
            local plate = GetVehicleNumberPlateText(vehicle)
            if plate and plate ~= '' then return true end
        end, 'Vehicle plate failed to set', 5000)

        if not plateAvailable then
            lib.print.error("Failed to set plate for vehicle:", model)
            DeleteEntity(vehicle)
            return nil
        end

        return {
            vehicle = vehicle,
            plate = GetVehicleNumberPlateText(vehicle),
        }
    end)

    if not success then
        lib.print.error("Error spawning temporary vehicle:", response)
        return nil, nil
    end

    if not response then return nil, nil end

    return response.vehicle, response.plate
end
exports('SpawnTemporaryVehicle', spawnTemporaryVehicle)

---@param vehicle number Vehicle entity
local function deleteTemporaryVehicle(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if ispulsarVehicles then
        local vehState = Entity(vehicle).state
        if vehState and vehState.VIN then
            exports['pulsar-vehicles']:Delete(vehicle, function() end)
            return
        end
    end

    DeleteEntity(vehicle)
end
exports('DeleteTemporaryVehicle', deleteTemporaryVehicle)
