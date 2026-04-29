local inv = {}

local playerInventories = {} ---@type table<string, table<{ name: string, count: number, metaData: table?, slot: number }>>

local origen_inventory = exports.origen_inventory
local items = origen_inventory:Items()

-- Source: https://docs.origennetwork.store/origen_inventory/exports/server

---@return string, any
local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

---@param src? number
---@return table<string, table> --Returns a table of all registered items, where the key is the item name and the value is the item data table.
function inv.getRegisteredItems(src)
    return items
end

---@param inventoryId string|number
---@return table<{ name: string, count: number, metaData: table?, slot: number }>
function inv.getInventoryItems(inventoryId)
    local items = origen_inventory:getItems(inventoryId)
    if not items then
        return {}
    end

    local formattedItems = {}

    for _, item in pairs(items) do
        formattedItems[#formattedItems + 1] = {
            name = item.name,
            count = item.amount,
            metadata = item.metadata,
            slot = item.slot
        }
    end

    return formattedItems
end

---@param inventoryId string | number
---@return table | nil
function inv.getInventory(inventoryId)
    local items = origen_inventory:getItems(inventoryId)
    local formattedItems = {}

    for _, item in pairs(items) do
        formattedItems[#formattedItems + 1] = {
            name = item.name,
            count = item.amount,
            metadata = item.metadata,
            slot = item.slot
        }
    end

    return {
        items = formattedItems,
    }
end

---@param data InvTempStashProps
---@return string inventoryId
function inv.createTemporaryStash(data)
    local inventoryId = ("TEMP_%s"):format(generateUUID())

    origen_inventory:registerStash(inventoryId, {
        label = data.label,
        slots = data.slots or 100,
        weight = data.maxWeight * 1000
    })

    for _, item in pairs(data.items) do
        origen_inventory:addItem(inventoryId, item.name, item.count, item.metaData or {})
    end

    return inventoryId
end

---@param data InvStashProps
function inv.createStash(data)
    origen_inventory:RegisterStash(data.id, data.label, data.slots, data.maxWeight, data.owner, data.groups or nil, data.coords or nil)
end

---@param cb fun(payload: InvSwapHookPayload):boolean Return `false` to cancel the item swap.
---@param options? InvHookOptions
---@return number hookId
function inv.registerSwapItemsHook(cb, options)
    return origen_inventory:registerHook("swapItems", cb, options)
end

---@param hookId number
function inv.removeHooks(hookId)
    return origen_inventory:removeHooks(hookId)
end

---@param cb fun(payload: InvCreateItemHookPayload):boolean
---@param options? table
---@return number hookId
function inv.registerCreateItemHook(cb, options)
    return origen_inventory:registerHook("createItem", cb, options or nil)
end

---@param inventoryId string
---@param keep? string | table<string> The keep argument is either a string or an array of strings containing the name(s) of the item(s) to keep in the inventory after clearing.
function inv.clearInventory(inventoryId, keep)
    local _keep = {}
    if type(keep) == "string" then
        _keep[keep] = true
    elseif type(keep) == "table" then
        for i=1, #keep do
            _keep[keep[i]] = true
        end
    end

    local toRemove = {}
    -- Here using getInventoryItems directly from origen is on purpose.
    local inventoryItems = origen_inventory:getInventoryItems(inventoryId)

    for i=1, #inventoryItems do
        local item = inventoryItems[i]
        if not _keep[item.name] then
            toRemove[#toRemove + 1] = item
        end
    end

    return origen_inventory:removeItems(inventoryId, toRemove)
end

---@param src number | string
---@param inventoryId string
function inv.openStash(src, inventoryId)
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerClientEvent("prp-bridge:origen_inv:openStash", src, inventoryId)
end

---@param src number | string
---@param inventoryId string
function inv.forceOpenStash(src, inventoryId)
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerClientEvent("prp-bridge:origen_inv:openStash", src, inventoryId)
end

---@param inventoryId string|number
---@param itemName string
---@param count number
---@param metadata table|nil
---@return boolean, InvGiveItemResp
function inv.giveItem(inventoryId, itemName, count, metadata)
    return origen_inventory:addItem(inventoryId, itemName, count, metadata)
end

---@param inventoryId string|number
---@param itemName string
---@param count number
---@param metadata table|nil
---@param slot number|nil
---@return boolean, InvRemoveItemResp
function inv.removeItem(inventoryId, itemName, count, metadata, slot)
    return origen_inventory:removeItem(inventoryId, itemName, count, metadata, slot)
end

---@param itemName string
---@return string|nil -- Returns the label of the item, or `nil` if not found.
function inv.getItemLabel(itemName)
    local item = items[itemName]
    if not item then
        return nil
    end

    return item.label
end

---@param itemName string
---@return table|nil -- Returns the item data table, or `nil` if not found.
function inv.getItemData(itemName)
    return items[itemName]
end

---@param prefix string
---@param items table<{ name: string, count: number, metaData: table? }>
---@param coords vector3
---@param slots number?
---@param maxWeight number?
---@param instance string|number|nil
---@param model number?
function inv.createCustomDrop(prefix, items, coords, slots, maxWeight, instance, model)
    error("origen_inventory does not support custom drops")
end

---@param src number | string
---@param loadout table<{ name: string, count: number, metaData: table? }>
---@param excludedItems table<string, boolean>
function inv.giveLoadoutItems(src, loadout, excludedItems)
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then return end

    local playerItems = inv.getInventoryItems(src)
    --lib.print.debug('Current inventory items for source:', src, 'identifier:', identifier, 'items:', playerItems)

    local currentLoadout = {}

    for _, item in pairs(playerItems) do
        if not excludedItems[item.name] then
            origen_inventory:removeItem(src, item.name, item.count, item.metadata, item.slot)

            currentLoadout[#currentLoadout + 1] = item
        end
    end

    for _, item in pairs(loadout) do
        origen_inventory:addItem(src, item.name, item.count, item.metaData)
    end

    playerInventories[identifier] = currentLoadout
end

---@param src number | string
---@param loadout table<{ name: string, count: number, metaData: table? }>
function inv.returnItems(src, loadout)
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then return lib.print.debug('No identifier for source:', src) end

    local storedItems = playerInventories[identifier]
    if not storedItems then return lib.print.debug('No stored items for identifier:', identifier) end

    for _, item in pairs(loadout) do
        lib.print.debug('Removing loadout item from source:', src, 'item:', item)
        origen_inventory:removeItem(src, item.name, item.count)
    end

    Wait(0)

    for _, item in pairs(storedItems) do
        lib.print.debug('Restoring item to source:', src, 'item:', item)
        origen_inventory:addItem(src, item.name, item.count, item.metaData or {})
    end

    playerInventories[identifier] = nil
end

---@param inventoryId string|number
---@param lookFor string[] | string
---@return number | table<string, number>
function inv.count(inventoryId, lookFor)
    local count = origen_inventory:Search(inventoryId, 'count', lookFor)
    return count
end

---@param inventoryId string|number
---@param item string
---@param amount number
---@return boolean
function inv.hasItem(inventoryId, item, amount)
    local count = inv.count(inventoryId, item)
    if type(count) == "table" then
        return (count[item:upper()] or count[item:lower()]) >= (amount or 1)
    end

    return count >= (amount or 1)
end

---@param inventoryId string|number
---@param slot number
---@return { weight: number, name: string, metadata: table?, count: number, slot: number } | nil
function inv.getSlot(inventoryId, slot)
    local playerItems = inv.getInventoryItems(inventoryId)
    for k,v in pairs(playerItems) do
        if v.slot == slot then
            return {
                name = v.name,
                count = v.count or v.amount,
                metadata = v.metaData,
                slot = v.slot,
                weight = v.weight
            }
        end
    end
    return nil
end

---@param inventoryId string|number
---@param slot number
---@return number | nil
function inv.getItemDurability(inventoryId, slot)
    local item = origen_inventory:GetSlot(inventoryId, slot)
    if not item then
        return nil
    end

    if not item.metadata or not item.metadata.durability then
        return nil
    end

    return item.metadata.durability
end

---@param inventoryId string|number
---@param slot number
---@return table | nil
function inv.getItemMetaData(inventoryId, slot)
    local slotItem = inv.getSlot(inventoryId, slot)
    if not slotItem then return nil end
    return slotItem.metadata
end

---@param inventoryId string|number
---@param slot number
---@param metaData table
---@return boolean
function inv.setItemMetaData(inventoryId, slot, metaData)
    local item = origen_inventory:GetSlot(inventoryId, slot)
    if not item then
        return false
    end

    return origen_inventory:setMetadata(inventoryId, slot, metaData)
end

---@param inventoryId string|number
---@param slot number
---@param key string
---@param value any
---@return boolean
function inv.setItemMetaDataKey(inventoryId, slot, key, value)
    local item = origen_inventory:GetSlot(inventoryId, slot)
    if not item then
        return false
    end

    local newMeta = lib.table.deepclone(item.metadata or {})
    newMeta[key] = value
    return origen_inventory:setMetadata(inventoryId, slot, newMeta)
end

---@param inventoryId string|number
---@param slot number
---@param metaData table<string, any>
---@return boolean
function inv.setItemMetaDatasByKey(inventoryId, slot, metaData)
    local item = origen_inventory:GetSlot(inventoryId, slot)
    if not item then
        return false
    end

    local newMeta = lib.table.deepclone(item.metadata or {})
    for k, v in pairs(metaData) do
        newMeta[k] = v
    end

    return origen_inventory:SetMetadata(inventoryId, slot, newMeta)
end

---@param inventoryId string|number
---@param lookFor string[] | string
---@return InvSearchItem[] | nil
function inv.searchInventory(inventoryId, lookFor)
    local found = {}

    local inventoryItems = inv.getInventoryItems(inventoryId)
    if not inventoryItems or #inventoryItems == 0 then
        return
    end

    for i = 1, #inventoryItems do
        local item = inventoryItems[i]
        if type(lookFor) == "table" then
            if lib.table.contains(lookFor, item.name) then
                found[#found + 1] = item
            end
        elseif type(lookFor) == "string" then
            if item.name == lookFor then
                found[#found + 1] = item
            end
        end
    end

    return found
end

---@param shopId string
---@param shopData InvShopData
function inv.registerShop(shopId, shopData)
    origen_inventory:createShop(shopId, {
        label = shopData.name,
        slots = #shopData.items,
        items = shopData.items
    })
end

---@param inventoryId string | number
---@param item string
---@param count number
---@param metaData table?
---@return boolean
function inv.canCarryItem(inventoryId, item, count, metaData)
    return origen_inventory:CanCarryItem(inventoryId, item, count, metaData)
end

---@param type InvVehStashType
---@param plate string
---@return boolean
function inv.vehInvHasItems(type, plate)
    local inventoryId = ("%s_%s"):format(type, plate)
    local inventoryItems = origen_inventory:getInventoryItems(inventoryId) or {}
    return #inventoryItems > 0
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-origen_inventory/html/images/%s.png"):format(itemName)
end

return inv
