local plyPed = PlayerPedId()
local gsrPositive = false
local gsrTimer = 0
local gsrTestDistance = 5.0

-- Update local state when server authoritative data arrives
RegisterNetEvent('GSR:SelfUpdate')
AddEventHandler('GSR:SelfUpdate', function(entry)
    if not entry then return end
    gsrPositive = entry.gsr or false
    gsrTimer = entry.gsrTimer or 0
    LocalPlayerState = LocalPlayerState or {}
    LocalPlayerState.bac = entry.bac or 0.0
    LocalPlayerState.drugs = entry.drugs or false

    -- lightweight notification (you can use lib.notify instead)
    lib.notify({
        title = 'GSR',
        description = ('Saved: BAC=%.2f Drugs=%s GSR=%s'):format(LocalPlayerState.bac, tostring(LocalPlayerState.drugs), gsrPositive and 'Positive' or 'Negative'),
        type = 'inform'
    })
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
        plyPed = PlayerPedId()
        if IsPedShooting(plyPed) then
            -- quick local set so client feels immediate, server will confirm
            gsrPositive = true
            gsrTimer = (Config and Config.GSRAutoClean) or 120
            -- start a small local timer thread (optional)
            Citizen.CreateThread(function()
                while gsrPositive and gsrTimer > 0 do
                    Citizen.Wait(1000)
                    gsrTimer = gsrTimer - 1
                    if gsrTimer <= 0 then gsrPositive = false end
                end
            end)

            -- inform server (server will set its authoritative state and timer)
            TriggerServerEvent('GSR:ReportFired')
            -- small cooldown to avoid spamming the server for every single shot frame
            Citizen.Wait(1000)
        end
    end
end)

-- CIV self menu: set your own BAC / drug result
local function GetClosestPlayer()
    local players = GetActivePlayers()
    local pCoords = GetEntityCoords(PlayerPedId())
    local closestPlayer = -1
    local closestDistance = 9999.0
    for _, player in ipairs(players) do
        local ped = GetPlayerPed(player)
        if ped ~= PlayerPedId() then
            local dst = #(pCoords - GetEntityCoords(ped))
            if dst < closestDistance then
                closestPlayer = player
                closestDistance = dst
            end
        end
    end
    if closestPlayer ~= -1 then
        return closestPlayer, closestDistance
    end
    return nil, nil
end
lib.registerContext({
    id = "civ_self_menu",
    title = "Community Wellness Kiosk",
    canClose = true,
    options = {
        {
            title = "Set my BAC",
            onSelect = function()
                -- Slider: min 0.00, max 0.40, step 0.01 (change these values if you prefer)
                local dialog = lib.inputDialog('Set your BAC', {
                    {
                        type = 'slider',
                        label = 'BAC (e.g. 0.00)',
                        name = 'bac',
                        default = 0.00,
                        min = 0.00,
                        max = 0.40,
                        step = 0.01,
                        required = true
                    }
                }, { allowCancel = true, size = 'sm' })

                if not dialog then
                    return -- user cancelled
                end

                -- support both named return (dialog.bac) and array return (dialog[1])
                local bacVal = tonumber(dialog.bac) or tonumber(dialog[1]) or 0.0
                if bacVal < 0 then bacVal = 0.0 end

                -- send server event to save player's self-test BAC
                TriggerServerEvent('CIV:SetSelfTests', { bac = bacVal })
            end
        },
        {
            title = "Set my Drug result (Positive)",
            onSelect = function()
                TriggerServerEvent('CIV:SetSelfTests', { drugs = true })
            end
        },
        {
            title = "Set my Drug result (Negative)",
            onSelect = function()
                TriggerServerEvent('CIV:SetSelfTests', { drugs = false })
            end
        },
        {
            title = "View my current saved values",
            onSelect = function()
                LocalPlayerState = LocalPlayerState or {}
                local bac = LocalPlayerState.bac or 0.0
                local drugs = LocalPlayerState.drugs and 'Positive' or 'Negative'
                local gsr = gsrPositive and 'Positive' or 'Negative'
                lib.notify({
                    title = 'Self Tests',
                    description = ("BAC: %.2f\nDrugs: %s\nGSR: %s"):format(tonumber(bac) or 0.0, drugs, gsr),
                    type = 'inform'
                })
            end
        },
        { title = "Close", onSelect = function() lib.hideContext(true) end }
    }
})

-- Command to open the CIV menu
RegisterCommand('civself', function()
    lib.showContext('civ_self_menu')
end)