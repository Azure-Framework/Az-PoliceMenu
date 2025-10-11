-- client.lua
-- Client-side for CIV self-tests + GSR + police test compatibility
-- Shows "Nothing" when BAC or Drugs are not set.

-- Local state
local plyPed = PlayerPedId()
local gsrPositive = false
local gsrTimer = 0
local gsrTestDistance = 5.0

-- for notification debouncing
local prevGsrPositive = nil
local prevBac = nil
local prevDrugs = nil
local lastNotify = 0
local notifyCooldown = 10000 -- ms

-- guard for local timer thread so we don't spawn multiple ones
local gsrLocalTimerRunning = false

-- Local authoritative-ish state stored by server updates
LocalPlayerState = LocalPlayerState or { bac = nil, bacSet = false, drugs = nil, drugsSet = false }

-- ----- HELPERS -----
local function fmt(n)
    return string.format("%.2f", tonumber(n) or 0.0)
end

local function presentOrNothing(value, isSet, asNumber)
    if not isSet then
        return "Nothing"
    end
    if asNumber then
        return fmt(value)
    end
    return value and "Positive" or "Negative"
end

local function GetPlayersActive()
    local players = {}
    for _, id in ipairs(GetActivePlayers()) do
        table.insert(players, id)
    end
    return players
end

local function GetClosestPlayer()
    local players = GetPlayersActive()
    local pCoords = GetEntityCoords(PlayerPedId())
    local closestPlayer = -1
    local closestDistance = 9999.0
    for _, player in ipairs(players) do
        local ped = GetPlayerPed(player)
        if ped ~= PlayerPedId() then
            local dstvec = pCoords - GetEntityCoords(ped)
            local dst = #(dstvec)
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

-- ----- SERVER -> CLIENT: authoritative self update -----
RegisterNetEvent('GSR:SelfUpdate')
AddEventHandler('GSR:SelfUpdate', function(entry)
    if not entry then return end

    -- new values from server
    local newGsr = entry.gsr or false
    local newTimer = entry.gsrTimer or 0
    local newBac = entry.bac -- may be nil
    local newBacSet = entry.bacSet == true
    local newDrugs = entry.drugs -- may be nil or boolean
    local newDrugsSet = entry.drugsSet == true

    -- update local authoritative state
    gsrPositive = newGsr
    gsrTimer = newTimer
    LocalPlayerState = LocalPlayerState or {}
    LocalPlayerState.bac = newBac
    LocalPlayerState.bacSet = newBacSet
    LocalPlayerState.drugs = newDrugs
    LocalPlayerState.drugsSet = newDrugsSet

    -- decide whether to notify:
    local now = GetGameTimer() -- ms
    local changed = false
    if prevGsrPositive == nil or prevGsrPositive ~= newGsr then
        changed = true
    elseif prevBac == nil or ( (prevBac or 0) ~= (newBac or prevBac) ) or (prevBac and newBac == nil) then
        changed = true
    elseif prevDrugs == nil or prevDrugs ~= newDrugs then
        changed = true
    end

    if changed or (now - lastNotify) > notifyCooldown then
        lib.notify({
            title = 'GSR',
            description = ('Saved: BAC=%s Drugs=%s GSR=%s'):format(
                presentOrNothing(LocalPlayerState.bac, LocalPlayerState.bacSet, true),
                (LocalPlayerState.drugsSet and (LocalPlayerState.drugs and "Positive" or "Negative")) or "Nothing",
                gsrPositive and 'Positive' or 'Negative'
            ),
            type = 'inform'
        })
        lastNotify = now
    end

    -- persist previous values for next comparison
    prevGsrPositive = newGsr
    prevBac = newBac
    prevDrugs = newDrugs
end)

-- ----- When player shoots, report to server (server will set authoritative GSR) -----
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
        plyPed = PlayerPedId()
        if IsPedShooting(plyPed) then
            -- quick local set so client feels immediate, server will confirm
            gsrPositive = true
            gsrTimer = (Config and Config.GSRAutoClean) or 120

            -- start a small local timer thread (only one at a time)
            if not gsrLocalTimerRunning then
                gsrLocalTimerRunning = true
                Citizen.CreateThread(function()
                    while gsrPositive and gsrTimer > 0 do
                        Citizen.Wait(1000)
                        gsrTimer = gsrTimer - 1
                        if gsrTimer <= 0 then
                            gsrPositive = false
                        end
                    end
                    gsrLocalTimerRunning = false
                end)
            end

            -- inform server (server will set its authoritative state and timer)
            TriggerServerEvent('GSR:ReportFired')
            -- small cooldown to avoid spamming the server for every single shot frame
            Citizen.Wait(1000)
        end
    end
end)

-- ----- CIV MENU (set BAC / drugs / view saved) -----
lib.registerContext({
    id = "civ_self_menu",
    title = "Community Wellness Kiosk",
    canClose = true,
    options = {
        {
            title = "Set my BAC",
            onSelect = function()
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

                if not dialog then return end
                local bacVal = tonumber(dialog.bac) or tonumber(dialog[1]) or 0.0
                if bacVal < 0 then bacVal = 0.0 end
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
                local bacDisplay = LocalPlayerState.bacSet and tostring(fmt(LocalPlayerState.bac)) or "Nothing"
                local drugsDisplay = LocalPlayerState.drugsSet and (LocalPlayerState.drugs and "Positive" or "Negative") or "Nothing"
                local gsr = gsrPositive and 'Positive' or 'Negative'
                lib.notify({
                    title = 'Self Tests',
                    description = ("BAC: %s\nDrugs: %s\nGSR: %s"):format(bacDisplay, drugsDisplay, gsr),
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

-- ----- SERVER -> CLIENT: Tester notifications & responses -----

-- Test notification (textual)
RegisterNetEvent('GSR:TestNotify')
AddEventHandler('GSR:TestNotify', function(msg)
    if not msg then return end
    lib.notify({ title = 'GSR', description = tostring(msg), type = 'inform' })
end)

-- Tester receives a result from server (or forwarded from tested client)
RegisterNetEvent('tests:response')
AddEventHandler('tests:response', function(testType, result, testedServerId)
    testedServerId = testedServerId or 'unknown'
    if testType == 'bac' then
        if result == nil then
            lib.notify({
                title = 'Breathalyzer Result',
                description = ('Player %s — BAC: Nothing (not set)'):format(tostring(testedServerId)),
                type = 'inform'
            })
        else
            local bac = tonumber(result) or 0.0
            lib.notify({
                title = 'Breathalyzer Result',
                description = ('Player %s — BAC: %.3f'):format(tostring(testedServerId), bac),
                type = 'inform'
            })
        end
    elseif testType == 'drugs' then
        if result == nil then
            lib.notify({
                title = 'Drug Test Result',
                description = ('Player %s — Drugs: Nothing (not set)'):format(tostring(testedServerId)),
                type = 'inform'
            })
        else
            local positive = (result == true or tostring(result) == 'true')
            lib.notify({
                title = 'Drug Test Result',
                description = ('Player %s — Drugs: %s'):format(tostring(testedServerId), positive and 'Positive' or 'Negative'),
                type = positive and 'error' or 'inform'
            })
        end
    else
        lib.notify({ title = 'Test', description = 'Unknown test result', type = 'inform' })
    end
end)

-- Server asks target to run the test locally (no server-side saved data). We reply via tests:callback.
RegisterNetEvent('tests:ask_target')
AddEventHandler('tests:ask_target', function(requesterServerId, maybeRequesterServerId, testType)
    local testerServerId = tonumber(requesterServerId) or tonumber(maybeRequesterServerId)
    if not testerServerId then
        if requesterServerId then
            TriggerServerEvent('tests:callback', requesterServerId, testType, nil)
        end
        return
    end

    LocalPlayerState = LocalPlayerState or {}
    if testType == 'bac' then
        if LocalPlayerState.bacSet then
            local bac = tonumber(LocalPlayerState.bac) or 0.0
            TriggerServerEvent('tests:callback', testerServerId, 'bac', bac)
        else
            TriggerServerEvent('tests:callback', testerServerId, 'bac', nil) -- not set
        end
    elseif testType == 'drugs' then
        if LocalPlayerState.drugsSet then
            local drugs = (LocalPlayerState.drugs == true)
            TriggerServerEvent('tests:callback', testerServerId, 'drugs', drugs)
        else
            TriggerServerEvent('tests:callback', testerServerId, 'drugs', nil) -- not set
        end
    else
        TriggerServerEvent('tests:callback', testerServerId, testType, nil)
    end
end)

-- Compatibility: older scripts expect the target client to implement "GSR:TestHandler"
RegisterNetEvent('GSR:TestHandler')
AddEventHandler('GSR:TestHandler', function(testerServerId)
    LocalPlayerState = LocalPlayerState or {}
    local gsr = gsrPositive or false
    TriggerServerEvent('GSR:TestCallback', testerServerId, gsr)
end)

-- End of client.lua
