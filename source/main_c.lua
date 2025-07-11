-- client.lua

local ox_target = exports.ox_target
local pendingPoliceCheck = nil



-- register the response handler once
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

-- ask server “am I cop?”
local function IsPoliceJob(cb)
    print("[Client][DEBUG] IsPoliceJob() → sending request")
    pendingPoliceCheck = cb
    TriggerServerEvent('police:checkJob')
    -- timeout guard
    SetTimeout(5000, function()
        if pendingPoliceCheck then
            print("[Client][DEBUG] No response within 5s, defaulting to false")
            pendingPoliceCheck(false)
            pendingPoliceCheck = nil
        end
    end)
end

-- ox_target menu entry
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

-- register ox_target + F7 key
CreateThread(function()
    ox_target:addGlobalPlayer(actionMenuOptions)
    while true do
        Wait(0)
        if IsControlJustReleased(0, 168) then -- F7
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

-- fallback command
RegisterCommand('policeMenu', function()
    IsPoliceJob(function(ok)
        if ok then
            DisplayPoliceMenu()
        else
            print("You do not have permission to access the police menu.")
        end
    end)
end, false)

-- build & show the menu
function DisplayPoliceMenu()
    local policeMenu = {
        id      = 'police_menu',
        title   = 'Police Menu',
        options = {
            { title = 'Clock In',  event = 'toggle_onduty',  enabled = Config.toggle_duty    },
            { title = 'Clock Out', event = 'toggle_offDuty', enabled = Config.toggle_duty    },
            { title = 'Actions',   event = 'policemenu',     enabled = Config.action_menu    },
            { title = 'Citations', event = 'citations_menu', enabled = Config.citations_menu },
            { title = 'Jailer',    event = 'jail_menu',      enabled = Config.jail_player    },
            { title = 'Traffic Control', onSelect = function()
                lib.showContext('menu:main')
            end }
        }
    }
    lib.registerContext(policeMenu)
    lib.showContext('police_menu')
end
