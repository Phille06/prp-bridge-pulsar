local shops = {}

bridge.inv.registerSwapItemsHook(function(payload)
    local src = payload.source
    local item = payload.fromSlot.name:lower()
    local inventory = payload.toInventory == src and payload.fromInventory or payload.toInventory

    if payload.toInventory == payload.fromInventory then
        return false
    end

    if payload.action ~= 'move' then
        return false
    end

    if payload.toInventory == src then
        return true
    end

    if not inventory:match('^sell_shop_[%w]+') then
        return false
    end

    local shop = shops[inventory]
    if not shop then
        return false
    end

    local shopItem = shop.items[item]
    if not shopItem then
        bridge.fw.notify(src, 'error', locale('SUCH_ITEM_CANNOT_BE_SOLD'))
        return false
    end

    local amount = shopItem.price * payload.count

    local added = bridge.fw.addMoney(src, "cash", amount, shop.reason)
    if not added then
        return false
    end

    SetTimeout(0, function()
        bridge.inv.clearInventory(inventory)
    end)

    bridge.fw.notify(src, 'success', locale('SOLD_ITEM', payload.count, shopItem.label))

    return true
end, {
    inventoryFilter = {
        '^sell_shop_[%w]+'
    }
})

local function registerShop(id, payload)
    local shopId = ("sell_shop_%s"):format(id)

    if shops[shopId] then
        return
    end

    shops[shopId] = payload

    bridge.inv.createStash({
        id = shopId,
        label = payload.label,
        slots = 1,
        maxWeight = 9000000,
        coords = payload.coords,
    })

    bridge.inv.clearInventory(shopId)
end
exports("RegisterSellShop", registerShop)

local function openShop(src, id)
    local shopId = ("sell_shop_%s"):format(id)

    local shop = shops[shopId]

    if not shop then
        lib.print.error(("No shop found with id %s"):format(shopId))
        return
    end

    bridge.inv.openStash(src, shopId)
end
exports("OpenSellShop", openShop)
