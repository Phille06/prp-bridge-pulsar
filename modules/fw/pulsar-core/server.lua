local fw = {}

if bridge.name == bridge.currentResource then
    exports['pulsar-core']:MiddlewareAdd('Characters:Spawning', function(source)
        local stateId = fw.getIdentifier(source)
        if not stateId then return end
        TriggerEvent('prp-bridge:server:playerLoad', source)
    end, 1)
    exports['pulsar-core']:MiddlewareAdd('playerDropped', function(source)
        TriggerEvent('prp-bridge:server:playerUnload', source)
    end, 1)
end

---@param src number | string
---@return string?
function fw.getIdentifier(src)
    local char = exports['pulsar-characters']:FetchCharacterSource(src)
    if not char then return nil end
    local sid = tostring(char:GetData('SID'))
    return sid
    -- return char:GetData('SID')
end

---@param identifier string
---@return number?
function fw.getSrcFromIdentifier(identifier)
    local player = exports['pulsar-characters']:FetchBySID(tonumber(identifier))
    if not player then return nil end
    return player:GetData('Source')
end

---@param identifier string
---@return string?
function fw.getCharacterName(identifier)
    local player = exports['pulsar-characters']:FetchBySID(tonumber(identifier))
    if not player then return nil end
    local first = player:GetData('First')
    local last = player:GetData('Last')
    if not first or not last then return nil end
    return string.format('%s %s', first, last)
end

---@param src number | string
---@param type 'inform' | 'error' | 'success' | 'warning'
---@param message string
---@param title? string
---@param duration? number
function fw.notify(src, type, message, title, duration)
    local method = 'Info'
    if type == 'error'   then method = 'Error'
    elseif type == 'success' then method = 'Success'
    elseif type == 'warning' then method = 'Warn'
    end
    exports['pulsar-hud']:Notification(src, type, message)
end

---@param commandName string
---@param helpText string
---@param params table<{ name: string, type: string, help: string }>?
---@param restrictedGroup string?
---@param callback fun(src: number, args: table, rawCommand: string)
function fw.registerCommand(commandName, helpText, params, restrictedGroup, callback) -- this works... but its not great, should prob refactor
    local wrappedCallback = function(source, args, rawCommand)
        local namedArgs = {}
        if params then
            for i, param in ipairs(params) do
                local converter = ({
                    playerId = function(val) return fw.getSrcFromIdentifier(val) end,
                    number   = function(val) return tonumber(val) end,
                })[param.type]
                namedArgs[param.name] = converter and converter(args[i]) or args[i]
            end
        end
        callback(source, namedArgs, rawCommand)
    end

    local suggestion = { help = helpText, params = params or {} }

    if restrictedGroup == 'group.admin' then
        exports["pulsar-chat"]:RegisterAdminCommand(commandName, wrappedCallback, suggestion, -1)
    elseif restrictedGroup == 'group.staff' then 
        exports["pulsar-chat"]:RegisterStaffCommand(commandName, wrappedCallback, suggestion, -1)
    else
        exports["pulsar-chat"]:RegisterCommand(commandName, wrappedCallback, suggestion, -1)
    end
end

---@param src string | number
---@return boolean
function fw.isAdmin(src)
    local player = exports['pulsar-core']:FetchSource(src)
    if not player then return false end
    return player.Permissions:IsAdmin()
end

---@param src number | string
---@param payload table<string, { type: "set" | "add" | "remove", value: any }>
function fw.setMetadata(src, payload)
    local player = exports['pulsar-characters']:FetchBySID(tonumber(src))
    if not player then return end

    for key, data in pairs(payload) do
        if data.type == 'add' or data.type == 'remove' then
            local current = player:GetData(key) or 0
            local new = data.type == 'add' and (current + data.value) or (current - data.value)
            if new > 100 then new = 100 elseif new < 0 then new = 0 end
            player:SetData(key, new)
        else
            player:SetData(key, data.value)
        end
    end
end

---@param src number | string
---@param rep string
---@param amount number
---@param reason string
function fw.addRep(src, rep, amount, reason)
    exports['pulsar-characters']:RepAdd(src, rep, amount)
end

---@param src number | string
---@param rep string
---@param amount number
---@param reason string
function fw.removeRep(src, rep, amount, reason)
    exports['pulsar-characters']:RepRemove(src, rep, amount)
end

---@param identifier string
---@param coords vector3
function fw.updateDisconnectLocation(identifier, coords)
    TriggerEvent('Characters:Server:LastLocation', coords)
end

---@param explosionType number
function fw.isExplosionAllowed(explosionType)
    -- Use your anticheat for checking
    return true
end

---@param explosionType number
---@param time number
function fw.allowExplosion(explosionType, time)
    -- Use your anticheat for allowing
end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@param moneyAmount number
---@param reason string | nil
---@return boolean
function fw.addMoney(src, moneyType, moneyAmount, reason)
    return exports['pulsar-finance']:WalletModify(src, moneyAmount) or false
end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@param moneyAmount number
---@param reason string | nil
---@return boolean
function fw.removeMoney(src, moneyType, moneyAmount, reason)
    return exports['pulsar-finance']:WalletModify(src, -moneyAmount) or false
end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@return number
function fw.getMoney(src, moneyType)
    local player = exports['pulsar-characters']:FetchBySID(tonumber(src))
    if not player then return 0 end
    return player:GetData(moneyType) or 0
end

---@param src number | string
---@param job string
---@param grade number?
---@param duty boolean?
---@return boolean
function fw.hasJob(src, job, grade, duty)
    local jobData = exports['pulsar-jobs']:HasJob(src, job, nil, nil, grade, duty)
    return jobData ~= false
end

---@param jobName string
---@return number
function fw.getDutyCountJob(jobName)
    local dutyData = exports['pulsar-jobs']:DutyGetDutyData(jobName)
    if not dutyData then return 0 end
    return dutyData.Count or 0
end

---@param jobName string
---@return table<number, true>
function fw.getPlayersOnDuty(jobName)
    local dutyData = exports['pulsar-jobs']:DutyGetDutyData(jobName)
    if not dutyData or not dutyData.DutyPlayers then return {} end
    local formatted = {}
    for _, src in ipairs(dutyData.DutyPlayers) do
        formatted[src] = true
    end
    return formatted
end

---@param itemName string
---@param cb fun(src: number, item: { name: string, label: string, metaData: table?, slot: number, count: number })
function fw.registerItemUse(itemName, cb)
    exports.ox_inventory:RegisterUse(itemName, itemName, function(source, item, itemData)
        local meta = item.MetaData or item.metadata or item.Metadata
        cb(source, {
            name     = item.Name,
            label    = itemData and itemData.label or itemName,
            metadata = meta,
            metaData = meta, -- alias for camelCase consumers like prp-notebook (why prodigy why)
            slot     = item.Slot,
            count    = item.Count,
        })
    end)
end

---@param plate string
---@param returnEmpty? boolean
---@return OwnedVehicle | nil
function fw.getOwnedVehicleByPlate(plate, returnEmpty)
    local p = promise.new()

    exports['pulsar-vehicles']:OwnedGetAll(nil, nil, nil, function(vehicles)
        if not vehicles then
            p:resolve(returnEmpty and {
                label   = 'Unknown',
                class   = 'OPEN',
                plate   = plate,
            } or nil)
            return
        end

        for _, vehicle in ipairs(vehicles) do
            if vehicle.RegisteredPlate == plate then
                local vehData = BridgeConfig.VehicleData[vehicle.Vehicle]
                if vehData and vehData.class then
                    p:resolve(lib.table.merge(lib.table.deepclone(vehData), {
                        plate   = vehicle.RegisteredPlate,
                        vehicle = vehicle.Vehicle,
                        VIN     = vehicle.VIN,
                        class   = vehicle.Class or vehData.class,
                        label   = vehicle.Model or vehData.label,
                    }, false))
                    return
                end
            end
        end

        p:resolve(returnEmpty and {
            label   = 'Unknown',
            class   = 'OPEN',
            plate   = plate,
        } or nil)
    end)

    return Citizen.Await(p)
end

---@param identifier string | number
---@param classes? string | table<string>
---@return table<number, OwnedVehicle> | nil
function fw.getAllOwnedVehicles(identifier, classes)
    local p = promise.new()

    exports['pulsar-vehicles']:OwnedGetAll(nil, 0, identifier, function(vehicles)
        if not vehicles then
            p:resolve(nil)
            return
        end

        local filtered = {}
        for _, vehicle in ipairs(vehicles) do
            local vehData = BridgeConfig.VehicleData[vehicle.Vehicle]
            local vehClass = vehicle.Class or (vehData and vehData.class)

            if not classes or (vehClass and (
                type(classes) == 'table' and lib.table.contains(classes, vehClass)
                or vehClass == classes
            )) then
                filtered[#filtered + 1] = {
                    plate   = vehicle.RegisteredPlate,
                    vehicle = vehicle.Vehicle,
                    VIN     = vehicle.VIN,
                    class   = vehClass,
                    label   = vehicle.Model,
                }
            end
        end

        p:resolve(#filtered > 0 and filtered or nil)
    end)

    return Citizen.Await(p)
end

---@param src number
---@param vehicleName string
---@return integer?
---@return string?
function fw.addOwnedVehicle(src, vehicleName)
    local stateId = fw.getIdentifier(src)
    if not stateId then return nil, 'CHARACTER_NOT_LOGGED_IN' end

    local vehicleHash = joaat(vehicleName)
    local vehData = BridgeConfig.VehicleData[vehicleHash]

    local p = promise.new()

    exports['pulsar-vehicles']:OwnedAddToCharacter(stateId, vehicleHash, 0, "automobile", {
        make  = vehData and vehData.manufacturer or 'Unknown',
        model = vehData and vehData.label or vehicleName,
        class = vehData and vehData.class or 'Unknown',
        value = vehData and vehData.value or false, -- for this to work you need to add value to the vehicleConfig.lua
    }, function(success, doc)
        if success and doc then
            p:resolve(doc._id)
        else
            p:resolve(nil)
        end
    end)

    local insertId = Citizen.Await(p)
    if not insertId then return nil, 'INSERT_FAILED' end
    return insertId
end

---@param plate string
---@param identifier string
---@return boolean
---@return string?
function fw.updateVehicleOwner(plate, identifier)
    local vehicle = fw.getOwnedVehicleByPlate(plate)
    if not vehicle then return false, 'VEHICLE_NOT_FOUND' end

    local success = MySQL.update.await(
        "UPDATE vehicles SET OwnerId = ? WHERE RegisteredPlate = ?",
        { identifier, plate }
    )

    if not success or success == 0 then return false, 'OWNER_NOT_UPDATED' end
    return true
end

return fw
