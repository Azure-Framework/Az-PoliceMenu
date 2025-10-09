-- Client: request server-side permission to search nearest player
RegisterNetEvent('search_player')
AddEventHandler('search_player', function()
    local nearestPlayer = GetNearestPlayer() -- keep your existing helper
    if nearestPlayer ~= -1 then
        -- send the server the target server ID; server will validate and return search:performClient if allowed
        TriggerServerEvent('search:request', tonumber(nearestPlayer))
    else
        lib.notify({
            title = 'No Players Nearby',
            description = 'No players are nearby to search.',
            type = 'info'
        })
    end
end)

-- Client: server allowed the search — actually open the inventory via ox_inventory
RegisterNetEvent('search:performClient')
AddEventHandler('search:performClient', function(targetServerId)
    if not targetServerId then return end
    -- defensive: check resource available client-side too
    if GetResourceState and GetResourceState("Az-Inventory") == "started" and exports.ox_inventory then
        -- ox_inventory expects a server id for openNearbyInventory in many setups; adapt if your ox_inventory expects a ped or player id differently
        exports.ox_inventory:openNearbyInventory(tonumber(targetServerId))
    else
        -- fallback if resource not available on client for some reason
        lib.notify({
            title = 'Search Failed',
            description = 'Inventory resource not available.',
            type = 'error'
        })
    end
end)
