local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    exports['pulsar-mdt']:TriggerPDAlert(
        src,
        coords,
        data.code,
        data.title,
        {
            icon     = blip.sprite,
            size     = blip.scale,
            color    = blip.colour,
            duration = (data.length or blip.length or 5) * 60,
        },
        {
            icon    = 'shield-halved',
            details = data.description or data.title,
        }
    )
end

return dispatch