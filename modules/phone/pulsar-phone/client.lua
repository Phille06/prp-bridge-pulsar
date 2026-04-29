---@type table<string, vector3>
local locationsCache = {}

local function generateId()
    local id = tostring(math.random(100000000, 999999999))
    if locationsCache[id] then
        return generateId()
    end
    return id
end

local function markLocation(id)
    local coords = locationsCache[id]
    if not coords then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
end

local function sendCoordsMail(coords)
    local id = generateId()
    locationsCache[id] = coords

    SendNUIMessage({
        type = "ADD_DATA",
        data = {
            type = "messages",
            data = {
                number = "SYSTEM",
                message = string.format("Location shared: %.4f, %.4f — tap to mark on GPS.", coords.x, coords.y),
                time = os.time(),
                unread = true,
                _coordId = id,
            },
        },
    })
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:phone:sendCoordsMail", sendCoordsMail)
    AddEventHandler("prp-bridge:phone:markLocation", markLocation)
end

return {}