local ox_target = exports.ox_target
local pendingPoliceCheck = nil

RegisterNetEvent('police:checkJobResponse')
AddEventHandler('police:checkJobResponse', function(isCop)
    print(('[Client][DEBUG] Received checkJobResponse: %s'):format(tostring(isCop)))
    if pendingPoliceCheck then
        pendingPoliceCheck(isCop)
        pendingPoliceCheck = nil
    else
        print("[Client][DEBUG] WARNING: no pending callback!")
    end
end)

local function IsPoliceJob(cb)
    print("[Client][DEBUG] IsPoliceJob() → sending request")
    pendingPoliceCheck = cb
    TriggerServerEvent('police:checkJob')
    SetTimeout(5000, function()
        if pendingPoliceCheck then
            print("[Client][DEBUG] No response within 5s, defaulting to false")
            pendingPoliceCheck(false)
            pendingPoliceCheck = nil
        end
    end)
end

local actionMenuOptions = {{
    name      = "openActionMenu",
    icon      = Config.ThirdEyeIcon,
    label     = Config.ThirdEyeMenuName,
    iconColor = Config.ThirdEyeIconColor,
    distance  = Config.ThirdEyeDistance,
    onSelect  = function(data)
        IsPoliceJob(function(ok)
            if not ok then
                print("No permission to access police menu.")
                return
            end

            local tgtServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TriggerEvent("openActionMenu", tgtServerId)
            lib.showContext('policeactions')
        end)
    end
}}

CreateThread(function()
    ox_target:addGlobalPlayer(actionMenuOptions)
    while true do
        Wait(0)
        if IsControlJustReleased(0, 168) then
            IsPoliceJob(function(ok)
                if ok then
                    DisplayPoliceMenu()
                else
                    print("You do not have permission to access the police menu.")
                end
            end)
        end
    end
end)

RegisterCommand('policeMenu', function()
    IsPoliceJob(function(ok)
        if ok then
            DisplayPoliceMenu()
        else
            print("You do not have permission to access the police menu.")
        end
    end)
end, false)

function DisplayPoliceMenu()
    local policeMenu = {
        id      = 'police_menu',
        title   = 'Police Menu',
        options = {
            { 
                title = 'Clock In',  
                onSelect = function()
                    TriggerServerEvent('toggle_onduty')
                end,
                enabled = Config.toggle_duty
            },
            { 
                title = 'Clock Out', 
                onSelect = function()
                    TriggerServerEvent('toggle_offDuty')
                end,
                enabled = Config.toggle_duty
            },
            { 
                title = 'Actions',   
                onSelect = function()
                    TriggerEvent('policemenu')
                end,
                enabled = Config.action_menu
            },
            { 
                title = 'Citations', 
                onSelect = function()
                    TriggerEvent('citations_menu')
                end,
                enabled = Config.citations_menu
            },
            { 
                title = 'Traffic Control', 
                onSelect = function()
                    lib.showContext('menu:main')
                end
            }
        }
    }
    lib.registerContext(policeMenu)
    lib.showContext('police_menu')
end
