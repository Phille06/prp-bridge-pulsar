local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local phoneNumber = exports.yphone:GetPhoneNumberBySourceId(src)
    if not phoneNumber then
        return false
    end

    local result = exports.yphone:SendMessageTo(
        tostring(from),
        phoneNumber,
        message
    )

    return result
end

---@param src number | string
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local phoneNumber = exports.yphone:GetPhoneNumberBySourceId(src)
    if not phoneNumber then
        return false
    end

    local result = exports.yphone:SendMessageTo(
        tostring(from),
        phoneNumber,
        message,
        {
            location = {
                x = coords.x,
                y = coords.y
            }
        }
    )

    return result
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    exports.yphone:SendNotification({
            app = 'messages',
            title = title,
            text = content,
        },
        'source',
        src
    )
end

return phone
