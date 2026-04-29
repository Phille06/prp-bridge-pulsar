local inv = {}

---@param item string
---@param count number
---@return boolean
function inv.hasItem(item, count)
    local c = exports.ox_inventory:Search('count', item)
    return c[item:upper()] >= (count or 1)
end

---@param itemName string
---@param minDurabilityAmount number | nil
---@return number | nil, table | nil
function inv.findItemSlot(itemName, minDurabilityAmount)
    local items = exports.origen_inventory:Search('slots', itemName)
    for _, item in pairs(items) do
        if item.name == itemName then
            if minDurabilityAmount and item.durability and item.durability >= minDurabilityAmount then
                return item.slot
            else
                return item.slot
            end
        end
    end
    return nil
end

---@param itemName string
---@param metadata table|nil
---@return table | nil
function inv.getSlotWithItem(itemName, metadata)
    return exports.origen_inventory:GetSlotWithItem(itemName, metadata)
end

---@param data table<string, string>
function inv.registerDisplayMetaData(data)
    for k,v in pairs(data) do
        exports.origen_inventory:displayMetadata(k, v)
    end
end

---@param name string
function inv.openShop(name)
    exports.origen_inventory:openInventory('shop', name)
end

---@return table<{ name: string, count: number, metadata: table?, slot: number }>
function inv.getAllItems()
    return exports.origen_inventory:GetPlayerInventory()
end

---@param itemName string
---@return number
function inv.getItemCount(itemName)
    return exports.origen_inventory:Search('count', itemName) or 0
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-origen_inventory/html/images/%s.png"):format(itemName)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:origen_inv:openStash", function(inventoryId)
        exports.origen_inventory:openInventory("stash", inventoryId)
    end)

    RegisterNetEvent("prp-bridge:inv:forceClose", function()
        exports.origen_inventory:CloseInventory()
    end)
end

return inv
