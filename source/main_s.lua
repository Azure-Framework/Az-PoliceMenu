-- build lookup for quick checks
local allowedJobs = {}
for _, id in ipairs(Config.jobIdentifiers) do
    allowedJobs[id] = true
end

-- helper to notify via ox_lib
local function notify(src, title, msg, typ)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = title,
        description = msg,
        type        = typ
    })
end

-- when a client asks “am I cop?”
RegisterNetEvent('police:checkJob', function()
    local src = source

    print(("[Police][DEBUG] Received checkJob from %d"):format(src))

    -- call the new export
    exports['Az-Framework']:getPlayerJob(src, function(jobId)
        print(("[Police][DEBUG] getPlayerJob → %d has job '%s'"):format(src, tostring(jobId)))

        local isCop = allowedJobs[jobId] == true

        print(("[Police][DEBUG] isCop = %s"):format(tostring(isCop)))
        TriggerClientEvent('police:checkJobResponse', src, isCop)
    end)
end)

-- (rest of your server logic remains exactly the same)
LEO = { GSRList = {}, DutyPlayers = {} }

RegisterNetEvent("stoicpm:shotspotter", function(location, streetName)
    local src = source
    LEO.GSRList[src] = os.time()
    TriggerClientEvent("stoicpm:shotspotter", -1, location, streetName)
end)

local function ConvertToTime(value)
    local h = math.floor(value / 3600)
    local m = math.floor((value % 3600) / 60)
    local s = value % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end
