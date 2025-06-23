-- azframework_native_support.lua
-- Adaptation of player list and jail logic to use FiveM natives (GetPlayerName) instead of Az-Framework playerData

-- Callback: Return nearby players with native names
lib.callback.register("getPlayerList", function(source)
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local nearby = lib.getNearbyPlayers(playerCoords, 30.0, false)
    local playerData = {}

    for _, ply in ipairs(nearby) do
        local sid = ply.id
        -- Use native GetPlayerName for display
        local name = GetPlayerName(sid) or ("Player " .. sid)
        playerData[#playerData + 1] = {
            name = name,
            id   = sid
        }
    end

    return playerData
end)

-- Jail Player Event: use native naming
RegisterServerEvent('jailPlayer')
AddEventHandler('jailPlayer', function(selectedPlayerId, jailTime, jailReason, fineAmount)
    print("[Jail] PlayerID:", selectedPlayerId, "Time:", jailTime, "Reason:", jailReason, "Fine:", fineAmount)

    -- Deduct fine via Az-Framework (serverId-based)
    local ok, err = exports['Az-Framework']:deductMoney(selectedPlayerId, fineAmount, "Jail Fine")
    if not ok then
        print(("Failed to deduct $%s from %s: %s"):format(fineAmount, selectedPlayerId, tostring(err)))
        return
    end

    -- Teleport and status
    local jailCoords = vector3(1680.23, 2513.08, 45.56)
    TriggerClientEvent('teleportToJail', selectedPlayerId, jailCoords)
    TriggerClientEvent('setJailedStatus', selectedPlayerId, true, jailTime)

    -- Notify jailed player
    local playerName = GetPlayerName(selectedPlayerId) or ("Player " .. selectedPlayerId)
    TriggerClientEvent('chat:addMessage', selectedPlayerId, {
        color = {255, 0, 0},
        multiline = true,
        args = {"Jail System", 
                ("You have been jailed for %s seconds. Reason: %s. Fine: $%s"):format(jailTime, jailReason, fineAmount)}
    })

    -- Notify officer
    TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 0},
        multiline = true,
        args = {"Jail System", 
                ("Jailed %s (ID: %s) for %s seconds. Reason: %s"):format(playerName, selectedPlayerId, jailTime, jailReason)}
    })
end)

-- Unjail Player Event: teleport back
RegisterServerEvent('unjailPlayer')
AddEventHandler('unjailPlayer', function()
    local src = source
    local unjailCoords = vector3(1848.86, 2602.36, 45.60)
    TriggerClientEvent('teleportFromJail', src, unjailCoords)
    TriggerClientEvent('setJailedStatus', src, false, 0)
end)
