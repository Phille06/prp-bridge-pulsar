local isPlacingProp = false
local placingEntity = nil

---@param model number
---@return boolean
function loadModel(model)
    if HasModelLoaded(model) then
        return true
    end

    local timeout = GetGameTimer() + 5000

    RequestModel(model)
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasModelLoaded(model)
end

---@param model string | number the model name or hash
---@param forceGround boolean? should the prop be forced on the ground
---@param allowedMaterials table<number, boolean>? what materials can the prop be placed on if any
---@param maxDistance number? the max distance from you the prop can be placed
---@return vector4 | nil
local function propPlacer(model, forceGround, allowedMaterials, maxDistance)
    if isPlacingProp then
        bridge.fw.notify("error", locale("ALREADY_PLACING_PROP"))
        return
    end

    local modelHash = joaat(model)
    if not model or not IsModelValid(modelHash) then
        lib.print.debug("No valid model provided to prop placer", model, modelHash)
        return
    end

    local loadedModel = loadModel(modelHash)
    if not loadedModel then
        lib.print.debug("Unable to load prop placer model", model, modelHash)
        return
    end

    local pedCoords = GetEntityCoords(cache.ped, false)
    placingEntity = CreateObject(model, pedCoords.x, pedCoords.y, pedCoords.z, false, true, false)
    SetEntityCollision(placingEntity, false, false)
    SetEntityDrawOutline(placingEntity, true)
    SetEntityDrawOutlineColor(135, 218, 33, 255)
    FreezeEntityPosition(placingEntity, true)

    isPlacingProp = true
    local finalCoords = nil
    local finalRotation = nil
    local hitEntity, entityHit, endCoords, materialHash

    local invalidMaterialText = locale("INVALID_MATERIAL")
    local actionText = ("[Scroll Wheel] - %s  \n[E] - %s  \n[Backspace] - %s"):format(
        locale("ROTATE_PROP"),
        locale("PLACE_PROP"),
        locale("EXIT_PROP_PLACER")
    )

    if BridgeConfig.Debug then
        invalidMaterialText = invalidMaterialText .. ("  \n[H] - %s"):format(locale("PROP_PLACEMENT_DEBUG"))
        actionText = actionText .. ("  \n[H] - %s"):format(locale("PROP_PLACEMENT_DEBUG"))
    end

    bridge.fw.showTextUI(actionText, {
        position = "bottom-center"
    })

    lib.disableControls:Add(177, 200, 201, 322, 24, 23, 75)

    Citizen.CreateThread(function()
        while isPlacingProp do
            lib.disableControls()

            if IsControlJustPressed(0, 194) or IsDisabledControlJustReleased(0, 194) then -- backspace
                isPlacingProp = false
            elseif BridgeConfig.Debug and IsControlJustPressed(0, 74) or IsDisabledControlJustPressed(0, 74) then -- h
                if allowedMaterials and allowedMaterials[materialHash] then
                    lib.print.info("Material hash already being used:", materialHash)
                else
                    allowedMaterials[materialHash] = true
                    lib.print.info("Allowed material hash:", materialHash, " save it to the config")
                end
            end

            if not allowedMaterials or allowedMaterials?[materialHash] then
                local open, text = bridge.fw.isTextUIOpen()
                if open and text ~= actionText then
                    bridge.fw.showTextUI(actionText, {
                        position = "bottom-center",
                    })
                end

                if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then -- e
                    if #(GetEntityCoords(placingEntity, false) - GetEntityCoords(cache.ped, false)) <= maxDistance then
                        -- Make sure its on the ground before we grab its final coords
                        if forceGround then
                            PlaceObjectOnGroundProperly(placingEntity)
                        end
                        
                        finalCoords = GetEntityCoords(placingEntity, false)
                        finalRotation = GetEntityHeading(placingEntity)
                        isPlacingProp = false
                    else
                        bridge.fw.notify("error", locale("PROP_PLACEMENT_TOO_FAR"))
                    end
                elseif IsControlPressed(0, 15) then -- scroll up
                    SetEntityHeading(placingEntity, GetEntityHeading(placingEntity) + 1.5)
                elseif IsControlPressed(0, 14) then -- scroll down
                    SetEntityHeading(placingEntity, GetEntityHeading(placingEntity) - 1.5)
                end
            else
                local open, text = bridge.fw.isTextUIOpen()
                if open and text ~= invalidMaterialText then
                    bridge.fw.showTextUI(invalidMaterialText, {
                        position = "bottom-center"
                    })
                end
            end

            Wait(0)
        end
    end)

    while isPlacingProp do
        hitEntity, entityHit, endCoords, _, materialHash = lib.raycast.fromCamera(1 | 8 | 16, placingEntity)
        if hitEntity and hitEntity > 0 and entityHit ~= cache.ped and not allowedMaterials or allowedMaterials?[materialHash] then
            SetEntityCoordsNoOffset(placingEntity, endCoords.x, endCoords.y, endCoords.z, false, false, false)
            if forceGround then
                PlaceObjectOnGroundProperly(placingEntity)
            end
        end

        Wait(0)
    end

    bridge.fw.hideTextUI()
    SetEntityDrawOutline(placingEntity, false)
    DeleteEntity(placingEntity)
    SetModelAsNoLongerNeeded(modelHash)

    if not finalCoords or not finalRotation then
        return
    end

    return vector4(finalCoords.x, finalCoords.y, finalCoords.z, finalRotation)
end

AddEventHandler("onResourceStop", function(resource)
    if cache.resource ~= resource then return end
    if not isPlacingProp then return end
    if not placingEntity or not DoesEntityExist(placingEntity) then return end
    SetEntityDrawOutline(placingEntity, false)
    SetEntityAsMissionEntity(placingEntity, false, false)
    DeleteEntity(placingEntity)
    placingEntity = nil
    bridge.fw.hideTextUI()
end)

lib.callback.register("prp-bridge:placeProp", propPlacer)
exports("PropPlacer", propPlacer)