local phone = {}

---@param src number
---@return string | nil
local function getPhoneNumber(src)
    local player = exports['pulsar-characters']:FetchCharacterSource(src)
    if not player then return nil end
    return player:GetData("Phone")
end

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local targetNumber = getPhoneNumber(src)
    if not targetNumber then return false end

    local msgData = {
        owner = targetNumber,
        number = tostring(from),
        message = message,
        time = os.time(),
        method = 0,
        unread = true,
    }

    TriggerClientEvent("Phone:Client:Messages:Notify", src, msgData, false)
    return true
end

---@param src number | string
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local targetNumber = getPhoneNumber(src)
    if not targetNumber then return false end

    TriggerClientEvent("prp-bridge:phone:sendCoordsMail", src, coords)
    return true
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    TriggerClientEvent(
        "Phone:Client:Notifications:Add",
        src,
        title,
        content or "",
        os.time(),
        6000,
        "messages",
        nil,
        nil
    )
end

return phone
