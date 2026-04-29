local medical = {}

---@param serverId number
---@return boolean
function medical.isPlayerDead(serverId)
    return Player(serverId).state?.isDead or false
end

---@param value number
function medical.overrideMaxHealth(value)
    -- Integrations with other resources
end

if bridge.name == bridge.currentResource then
    AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_bagName, _key, value)
        if not value then
            TriggerServerEvent("prp-bridge:server:revived")
            TriggerEvent("prp-bridge:client:revived")
            return
        end

        TriggerServerEvent("prp-bridge:server:died")
        TriggerEvent("prp-bridge:client:died")
    end)
end

return medical