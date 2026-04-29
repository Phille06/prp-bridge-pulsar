local inv = {}

--- Source: https://tgiann.gitbook.io/tgiann/scripts/tgiann-inventory/exports/client

---@param item string
---@param count number
---@return boolean
function inv.hasItem(item, count)
    return exports["tgiann-inventory"]:HasItem(item, count)
end

---@param itemName string
---@param minDurabilityAmount number | nil
---@return number | nil
function inv.findItemSlot(itemName, minDurabilityAmount)
    local items = exports["tgiann-inventory"]:Search("slots", itemName)
    for i=1, #items do
        local item = items[i]
        if item.name == itemName then
            return item.slot
        end
    end
    return nil
end

---@param itemName string
---@param metadata table|nil
---@return table | nil
function inv.getSlotWithItem(itemName, metadata)
    local items = exports["tgiann-inventory"]:Search("slots", itemName)
    for i = 1, #items do
        local item = items[i]
        if item.name == itemName then
            if metadata then
                local match = true
                for k, v in pairs(metadata) do
                    if item.metadata and item.metadata[k] ~= v then
                        match = false
                        break
                    end
                end
                if match then return item end
            else
                return item
            end
        end
    end
    return nil
end

---@param data table<string, string>
function inv.registerDisplayMetaData(data)
    exports["tgiann-inventory"]:DisplayMetadata(data)
end

---@param name string
function inv.openShop(name)
    -- this follows the docs but it just doesn't work
    exports["tgiann-inventory"]:OpenInventory("shop", name, name)
end

---@return table<{ name: string, count: number, metadata: table?, slot: number }>
function inv.getAllItems()
    local items = exports["tgiann-inventory"]:GetPlayerItems()
    local formattedItems = {}

    for _, item in pairs(items) do
        formattedItems[#formattedItems+1] = {
            name = item.name,
            count = item.count,
            metadata = item.info or item.metadata or nil,
            slot = item.slot
        }
    end

    return formattedItems
end

---@param itemName string
---@return number
function inv.getItemCount(itemName)
    return exports["tgiann-inventory"]:GetItemCount(itemName) or 0
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-inventory_images/images/%s.webp"):format(itemName)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:inv:forceClose", function()
        exports["tgiann-inventory"]:CloseInventory()
    end)
end

return inv
