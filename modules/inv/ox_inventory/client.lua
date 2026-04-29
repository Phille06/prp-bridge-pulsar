local inv = {}

---@param item string
---@param count number
---@return boolean
function inv.hasItem(item, count)
    local c = exports.ox_inventory:Search('count', item) or 0
    return c >= (count or 1)
end

---@param itemName string
---@param minDurabilityAmount number | nil
---@return number | nil
function inv.findItemSlot(itemName, minDurabilityAmount)
    local items = exports.ox_inventory:Search('slots', itemName)
    for i=1, #items do
        local item = items[i]
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
    return exports.ox_inventory:GetSlotWithItem(itemName, metadata)
end

---@param data table<string, string>
function inv.registerDisplayMetaData(data)
    exports.ox_inventory:displayMetadata(data)
end

---@param name string
function inv.openShop(name)
    exports.ox_inventory:openInventory('shop', { type = name })
end

---@return table<{ name: string, count: number, metadata: table?, slot: number }>
function inv.getAllItems()
    return exports.ox_inventory:GetPlayerItems()
end

---@param itemName string
---@return number
function inv.getItemCount(itemName)
    return exports.ox_inventory:Search('count', itemName) or 0
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-ox_inventory/web/images/%s.png"):format(itemName)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:inv:forceClose", function()
        exports.ox_inventory:closeInventory()
    end)
end

return inv
