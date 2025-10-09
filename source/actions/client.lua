local player, access = nil, false
local cuffed, dragged, isdragging, plhplayer = false, false, false, 0

-- CONTEXT MENU: policeactions (replace your existing policeactions lib.registerContext block)
lib.registerContext({
    id = "policeactions",
    title = "Police Actions",
    canClose = true,
    options = {
        {
            title = "Cuff Suspect",
            onSelect = function() ToggleCuffs() end
        },
        {
            title = "Drag Suspect",
            onSelect = function()
                local source = GetPlayerPed(-1)
                ToggleDrag(source)
            end
        },
        {
            title = "Place in Vehicle",
            onSelect = function()
                local source = GetPlayerPed(-1)
                PutInVehicle(source)
            end
        },
        {
            title = "Remove From Vehicle",
            onSelect = function() UnseatVehicle() end
        },
        {
            title = "Remove Weapons",
            onSelect = function() RemoveWeapons() end
        },

        -- NEW: Breathalyze
        {
            title = "Breathalyze",
            onSelect = function()
                local closeplayer, distance = GetClosestPlayer()
                if (distance ~= -1 and distance < 3) then
                    local targetServerId = GetPlayerServerId(closeplayer)
                    -- Request BAC from server (server should respond with tests:result or similar)
                    TriggerServerEvent('tests:request', targetServerId, 'bac')
                else
                    ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                end
            end,
            enabled = config.search_player
        },

        -- NEW: Test GSR
        {
            title = "Test for GSR",
            onSelect = function()
                local closeplayer, distance = GetClosestPlayer()
                if (distance ~= -1 and distance < 3) then
                    local targetServerId = GetPlayerServerId(closeplayer)
                    -- Keep compatibility with existing server-side GSR handler
                    TriggerServerEvent("GSR:TestPlayer", targetServerId)
                    if Config and Config.NotifySubject then
                        -- optional: notify target they are being tested (server may already do this)
                        TriggerServerEvent("GSR:NotifySubject", targetServerId) -- harmless if not implemented server-side
                    end
                else
                    ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                end
            end,
            enabled = config.search_player
        },

        -- NEW: Drug Test
        {
            title = "Drug Test",
            onSelect = function()
                local closeplayer, distance = GetClosestPlayer()
                if (distance ~= -1 and distance < 3) then
                    local targetServerId = GetPlayerServerId(closeplayer)
                    TriggerServerEvent('tests:request', targetServerId, 'drugs')
                else
                    ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                end
            end,
            enabled = config.search_player
        },

        {
            title = "Search Nearest Player",
            event = "search_player",
            enabled = config.search_player
        },
        {
            title = "Back",
            onSelect = function()
                lib.showContext("police_menu")
            end,
            icon = "arrow-left",
            description = "Go back to Police menu"
        }
    }
})

if Config.UseThirdEye then
    -- RADIAL MENU: policeactions (replace your existing lib.registerRadial for policeactions)
    lib.registerRadial({
        id = "policeactions",
        items = {
            {
                id = "cuff_suspect",
                icon = "cuff",
                label = "Cuff\nSuspect",
                onSelect = function() ToggleCuffs() end
            },
            {
                id = "drag_suspect",
                icon = "drag",
                label = "Drag\nSuspect",
                onSelect = function() ToggleDrag() end
            },
            {
                id = "place_in_vehicle",
                icon = "place_vehicle",
                label = "Place in\nVehicle",
                onSelect = function() PutInVehicle() end
            },
            {
                id = "remove_from_vehicle",
                icon = "remove_vehicle",
                label = "Remove From\nVehicle",
                onSelect = function() UnseatVehicle() end
            },
            {
                id = "remove_weapons",
                icon = "remove_weapons",
                label = "Remove\nWeapons",
                onSelect = function() RemoveWeapons() end
            },

            -- NEW radial item: Breathalyze
            {
                id = "breathalyze",
                icon = "breathalyze",
                label = "Breathalyze",
                onSelect = function()
                    local closeplayer, distance = GetClosestPlayer()
                    if (distance ~= -1 and distance < 3) then
                        TriggerServerEvent('tests:request', GetPlayerServerId(closeplayer), 'bac')
                    else
                        ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                    end
                end,
                enabled = config.search_player
            },

            -- NEW radial item: Test GSR
            {
                id = "test_gsr",
                icon = "gsr",
                label = "Test for\nGSR",
                onSelect = function()
                    local closeplayer, distance = GetClosestPlayer()
                    if (distance ~= -1 and distance < 3) then
                        TriggerServerEvent("GSR:TestPlayer", GetPlayerServerId(closeplayer))
                    else
                        ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                    end
                end,
                enabled = config.search_player
            },

            -- NEW radial item: Drug Test
            {
                id = "drug_test",
                icon = "drug-test",
                label = "Drug\nTest",
                onSelect = function()
                    local closeplayer, distance = GetClosestPlayer()
                    if (distance ~= -1 and distance < 3) then
                        TriggerServerEvent('tests:request', GetPlayerServerId(closeplayer), 'drugs')
                    else
                        ShowNotification({ title = "Error", description = "No player nearby", type = "error" })
                    end
                end,
                enabled = config.search_player
            },

            {
                id = "search_nearest_player",
                icon = "search",
                label = "Search\nNearest Player",
                onSelect = function() TriggerEvent("search_player") end,
                enabled = config.search_player
            },
            {
                id = "back_to_police_menu",
                icon = "arrow-left",
                label = "Back",
                onSelect = function() lib.showContext("police_menu") end,
                description = "Go back to Police menu"
            }
        }
    })

end

-- Register the main police actions radial menu
if Config.UseRadialMenu then
    lib.registerRadial(
        {
            id = "policeactions",
            items = {
                {
                    id = "cuff_suspect",
                    icon = "cuff",
                    label = "Cuff\nSuspect",
                    onSelect = function()
                        ToggleCuffs()
                    end
                },
                {
                    id = "drag_suspect",
                    icon = "drag",
                    label = "Drag\nSuspect",
                    onSelect = function()
                        ToggleDrag()
                    end
                },
                {
                    id = "place_in_vehicle",
                    icon = "place_vehicle",
                    label = "Place in\nVehicle",
                    onSelect = function()
                        PutInVehicle()
                    end
                },
                {
                    id = "remove_from_vehicle",
                    icon = "remove_vehicle",
                    label = "Remove From\nVehicle",
                    onSelect = function()
                        UnseatVehicle()
                    end
                },
                {
                    id = "remove_weapons",
                    icon = "remove_weapons",
                    label = "Remove\nWeapons",
                    onSelect = function()
                        RemoveWeapons()
                    end
                },
                {
                    id = "test_gsr",
                    icon = "gsr",
                    label = "Test for\nGSR",
                    onSelect = function()
                        TriggerEvent("gsr")
                    end,
                    enabled = config.search_player
                },
                {
                    id = "search_nearest_player",
                    icon = "search",
                    label = "Search\nNearest Player",
                    onSelect = function()
                        TriggerEvent("search_player")
                    end,
                    enabled = config.search_player
                },
                {
                    id = "back_to_police_menu",
                    icon = "arrow-left",
                    label = "Back",
                    onSelect = function()
                        lib.showContext("police_menu")
                    end,
                    description = "Go back to Police menu"
                }
            }
        }
    )
end

RegisterNetEvent("accessresponse")
AddEventHandler(
    "accessresponse",
    function(toggle)
        access = toggle
    end
)

Citizen.CreateThread(
    function()
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(0)
        end
        RefreshPerms()

        while true do
            AllMenu()
            Wait(0)
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(0)
            player = PlayerPedId()
            HandleDrag()
        end
    end
)

function AllMenu()
    if access then
        if lib.showContext("policemenu") then
            if lib.showContext("policeloadouts") then
                HandleLoadouts()
            elseif lib.showContext("policeactions") then
                HandleActions()
            end
        end
    end
end

function RefreshPerms()
    if NetworkIsPlayerActive(PlayerId()) then
        TriggerServerEvent("refreshscriptperms")
    end
end
-- Actions Menu Function
RegisterNetEvent("policemenu")
AddEventHandler(
    "policemenu",
    function()
        lib.showContext("policeactions")
    end
)

RegisterCommand(
    "openpm",
    function()
        lib.showContext("policemenu")
    end
)

--Actions
function PlayerCuffed()
    if not cuffed then
                ShowNotification({
            title = "Player Cuffed",
            type = "success" 
        })
        TaskPlayAnim(player, "mp_arrest_paired", "crook_p2_back_right", 8.0, -8, 3750, 2, 0, 0, 0, 0)
        Citizen.Wait(4000)
        cuffed = true
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"  
        })
        dragged = false
        cuffed = false
        Citizen.Wait(100)
        ClearPedTasksImmediately(player)
    end
end

RegisterNetEvent("dragplayer")
AddEventHandler(
    "dragplayer",
    function(otherplayer)
        if cuffed then
            isdragging = not isdragging
            plhplayer = tonumber(otherplayer)
            if isdragging then
                ShowNotification({
                    title = "Player Dragged",
                    type = "success"
                })
            else
                -- Stop dragging, clear tasks and animations for the source ped
                ClearPedTasksImmediately(PlayerPedId())
                
                ShowNotification({
                    title = "Player Dragging Stopped",
                    type = "error"
                })
            end
        else
            ShowNotification({
                title = "Error",
                description = "Player is not cuffed",
                type = "error"
            })
        end
    end
)


RegisterNetEvent("removeplayerweapons")
AddEventHandler(
    "removeplayerweapons",
    function()
        RemoveAllPedWeapons(player, true)
    end
)

RegisterNetEvent("forceplayerintovehicle")
AddEventHandler(
    "forceplayerintovehicle",
    function()
        if cuffed then
            local pos = GetEntityCoords(player)
            local playercoords = GetOffsetFromEntityInWorldCoords(player, 0.0, 20.0, 0.0)

            local rayHandle =
                CastRayPointToPoint(
                pos.x,
                pos.y,
                pos.z,
                playercoords.x,
                playercoords.y,
                playercoords.z,
                10,
                GetPlayerPed(-1),
                0
            )
            local _, _, _, _, vehicleHandle = GetRaycastResult(rayHandle)

            if vehicleHandle ~= nil then
                SetPedIntoVehicle(player, vehicleHandle, 2)
            end
        end
    end
)

RegisterNetEvent("removeplayerfromvehicle")
AddEventHandler(
    "removeplayerfromvehicle",
    function(otherplayer)
        local ped = GetPlayerPed(otherplayer)
        ClearPedTasksImmediately(ped)
        playercoords = GetEntityCoords(player, true)
        local xnew = playercoords.x + 2
        local ynew = playercoords.y + 2

        SetEntityCoords(player, xnew, ynew, playercoords.z)
    end
)

RegisterNetEvent("cuffplayer")
AddEventHandler("cuffplayer", PlayerCuffed)

function DisableControls()
    DisableControlAction(1, 140, true)
    DisableControlAction(1, 141, true)
    DisableControlAction(1, 142, true)
    --SetPedPathCanUseLadders(player, false)
end

function PlayerUncuffing()
    ExecuteCommand("e uncuff")
end

function PlayerCancelEmote()
    ExecuteCommand("e c")
end

function HandleDrag(source)
    while cuffed or dragged or isdragging do
        Citizen.Wait(0)

        if cuffed then
            RequestAnimDict("mp_arresting")
            while not HasAnimDictLoaded("mp_arresting") do
                Citizen.Wait(0)
            end

            while IsPedBeingStunned(player, false) do
                ClearPedTasksImmediately(player)
            end
            TaskPlayAnim(player, "mp_arresting", "idle", 8.0, -8, -1, 16, 0, 0, 0, 0)
            DisableControls()
        end

        if IsPlayerDead(PlayerPedId()) then
            cuffed = false
            isdragging = false
            dragged = false
        end

        if isdragging then
            local draggedPlayerPed = GetPlayerPed(GetPlayerFromServerId(plhplayer))
            local draggingPlayerPed = PlayerPedId()

            -- Attach the dragging player's ped to the dragged player's ped
            AttachEntityToEntity(
                draggingPlayerPed,
                draggedPlayerPed,
                4103,
                11816,
                0.48,
                0.00,
                0.0,
                0.0,
                0.0,
                0.0,
                false,
                false,
                false,
                false,
                2,
                true
            )
            dragged = true
        else
            if not IsPedInParachuteFreeFall(player) and dragged then
                dragged = false
                DetachEntity(PlayerPedId(), true, false)
                ClearPedTasks(PlayerPedId())
                ClearPedTasksImmediately(PlayerPedId())
            end
        end

    end
end

function GetPlayers()
    local players = {}
    for i, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        table.insert(players, player)
    end
    return players
end

function GetClosestPlayer()
    local players = GetPlayers()
    local closestDistance, closestPlayer = -1, -1
    local playercoords = GetEntityCoords(player, 0)

    for i, value in ipairs(players) do
        local target = GetPlayerPed(value)
        if (target ~= player) then
            local targetCoords = GetEntityCoords(GetPlayerPed(value), 0)
            local distance =
                Vdist(
                targetCoords["x"],
                targetCoords["y"],
                targetCoords["z"],
                playercoords.x,
                playercoords.y,
                playercoords.z
            )
            if (closestDistance == -1 or closestDistance > distance) then
                closestPlayer = value
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

function RemoveWeapons()
    local closeplayer, distance = GetClosestPlayer()
    if (distance ~= -1 and distance < 3) then
        TriggerServerEvent("removeplayerweapons", GetPlayerServerId(closeplayer))
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"})
    end
end

function ToggleCuffs()
    local closeplayer, distance = GetClosestPlayer()
    if (distance ~= -1 and distance < 3) then
        RequestAnimDict("mp_arrest_paired")
        while not HasAnimDictLoaded("mp_arrest_paired") do
            Wait(0)
        end
        TaskPlayAnim(player, "mp_arrest_paired", "crook_p2_back_right", 8.0, -8, 3750, 2, 0, 0, 0, 0)
        TriggerServerEvent("cuffplayer", GetPlayerServerId(closeplayer))
        ShowNotification({
            title = "Player Cuffed",
            type = "success"
        })
        RequestAnimDict("mp_arrest_paired")
        while not HasAnimDictLoaded("mp_arrest_paired") do
            Wait(0)
        end
        TaskPlayAnim(GetPlayerPed(-1), "mp_arrest_paired", "cop_p2_back_right", 8.0, -8, 3750, 2, 0, 0, 0, 0)
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"
        })
    end
end

function ToggleDrag(source)
    local closeplayer, distance = GetClosestPlayer()
    if distance ~= -1 and distance < 3 then
        TriggerServerEvent("dragplayer", GetPlayerServerId(closeplayer))
        
        if not animPlaying then
            -- Request and play animation for the source player
            RequestAnimDict("switch@trevor@escorted_out")
            while not HasAnimDictLoaded("switch@trevor@escorted_out") do
                Citizen.Wait(0)
            end
            TaskPlayAnim(
                source, -- Source player Ped
                "switch@trevor@escorted_out",
                "001215_02_trvs_12_escorted_out_idle_guard2",
                8.0,
                1.0,
                -1,
                49,
                0,
                0,
                0,
                0
            )
            animPlaying = true
        else
            -- If animation is already playing, stop it
            ClearPedTasksImmediately(source)
            animPlaying = false
        end
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"
        })
    end
end


function PutInVehicle(source)
    local closeplayer, distance = GetClosestPlayer()
    if (distance ~= -1 and distance < 3) then
        TriggerServerEvent("forceplayerintovehicle", GetPlayerServerId(closeplayer))
        ClearPedTasksImmediately(source)
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"
        })
    end
end

function UnseatVehicle()
    local closeplayer, distance = GetClosestPlayer()
    if (distance ~= -1 and distance < 3) then
        TriggerServerEvent("removeplayerfromvehicle", GetPlayerServerId(closeplayer))
    else
        ShowNotification({
            title = "Error",
            description = "No player nearby",
            type = "error"
        })
    end
end

RegisterCommand(
    "traffic",
    function()
        lib.showContext("menu:main")
    end
)

function ShowNotification(data)
    -- Trigger notification
    lib.notify(data)
end

local sz = nil

lib.registerContext(
    {
        id = "menu:main",
        title = "Traffic Menu",
        canClose = true,
        options = {
            {
                title = "Slow Traffic",
                onSelect = function()
                    if sz ~= nil then
                        RemoveSpeedZone(sz)
                        ShowNotification(
                            {
                                title = "Traffic Resumed",
                                type = "success"
                            }
                        )
                        sz = nil
                        RemoveBlip(tcblip)
                    else
                        ShowNotification(
                            {
                                title = "Traffic Slowed",
                                type = "warning"
                            }
                        )
                        tcblip = AddBlipForRadius(GetEntityCoords(GetPlayerPed(-1)), 40.0)
                        SetBlipAlpha(tcblip, 80)
                        SetBlipColour(tcblip, 5)
                        sz = AddSpeedZoneForCoord(GetEntityCoords(GetPlayerPed(-1)), 40.0, 5.0, false)
                    end
                end,
                icon = "car",
                description = "Slow down traffic in the area."
            },
            {
                title = "Resume Traffic",
                onSelect = function()
                    if sz ~= nil then
                        RemoveSpeedZone(sz)
                        ShowNotification(
                            {
                                title = "Traffic Resumed",
                                type = "success"
                            }
                        )
                        sz = nil
                        RemoveBlip(tcblip)
                    end
                end,
                icon = "play",
                description = "Resume normal traffic flow."
            },
            {
                title = "Stop Traffic",
                onSelect = function()
                    if sz ~= nil then
                        RemoveSpeedZone(sz)
                        ShowNotification(
                            {
                                title = "Traffic Resumed",
                                type = "success"
                            }
                        )
                        sz = nil
                        RemoveBlip(tcblip)
                    else
                        ShowNotification(
                            {
                                title = "Traffic Stopped",
                                type = "error"
                            }
                        )
                        tcblip = AddBlipForRadius(GetEntityCoords(GetPlayerPed(-1)), 50.0)
                        sz = AddSpeedZoneForCoord(GetEntityCoords(GetPlayerPed(-1)), 50.0, 0.0, false)
                        SetBlipAlpha(tcblip, 80)
                        SetBlipColour(tcblip, 1)
                    end
                end,
                icon = "stop",
                description = "Completely stop traffic in the area."
            },
            {
                title = 'Back',
                onSelect = function()
                    lib.showContext('police_menu') -- Assuming you have an 'mdt_menu' context
                end,
                icon = 'arrow-left',
                description = 'Go back to Police Menu',
            },
        }
    }
)
