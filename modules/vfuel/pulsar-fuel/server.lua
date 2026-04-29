local vfuel = {}

---@param source number
---@param vehicle number
---@param amount number
---@return boolean
function vfuel.set(source, vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    local vehState = Entity(vehicle)
    if not vehState or not vehState.state then
        return false
    end

    vehState.state.Fuel = math.min(math.max(amount + 0.0, 0.0), 100.0)
    return true
end

return vfuel