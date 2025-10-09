Config = Config or {}
Config.Debug = Config.Debug or false
-- Provide a default list; servers should override this in a separate config file
Config.jobIdentifiers = Config.jobIdentifiers or { "Police", "sheriff", "state" }

local debugPrint = function(...) if Config.Debug then print("[Az-PoliceMenu]", ...) end end

-- build lookup for quick checks
local allowedJobs = {}
for _, id in ipairs(Config.jobIdentifiers or {}) do
    allowedJobs[tostring(id)] = true
end

-- helper to notify via ox_lib (keeps your existing helper)
local function notify(src, title, msg, typ)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = title,
        description = msg,
        type        = typ
    })
end

local function safeGetPlayerJob(src, cb)
    assert(type(cb) == "function", "safeGetPlayerJob requires a callback")

    local triedResources = {
        "Az-Framework",
        "az-framework",
        "Az_Framework",
        "az_framework",
        -- add more common names here if needed
    }

    -- helper to attempt sync call
    local function trySync(resName)
        if exports and exports[resName] and type(exports[resName].getPlayerJob) == "function" then
            local ok, res = pcall(function()
                return exports[resName]:getPlayerJob(src)
            end)
            if ok then
                debugPrint(("safeGetPlayerJob (sync) via %s -> %s"):format(resName, tostring(res)))
                return true, res
            else
                debugPrint(("safeGetPlayerJob (sync) via %s errored: %s"):format(resName, tostring(res)))
                return false, nil
            end
        end
        return false, nil
    end

    -- helper to attempt async call (export takes callback)
    local function tryAsync(resName)
        if exports and exports[resName] and type(exports[resName].getPlayerJob) == "function" then
            local ok, err = pcall(function()
                exports[resName]:getPlayerJob(src, function(job)
                    debugPrint(("safeGetPlayerJob (async) via %s -> %s"):format(resName, tostring(job)))
                    cb(job)
                end)
            end)
            if not ok then
                debugPrint(("safeGetPlayerJob: async call to %s failed: %s"):format(resName, tostring(err)))
                return false
            end
            return true
        end
        return false
    end

    -- Try resources in order: sync first, then async
    for _, resName in ipairs(triedResources) do
        local ok, res = trySync(resName)
        if ok then
            -- sync result (may be nil)
            return cb(res)
        end

        local okAsync = tryAsync(resName)
        if okAsync then
            -- we assume async will call cb; return to avoid trying other resources
            return
        end
    end

    -- None found
    debugPrint("safeGetPlayerJob: No getPlayerJob export found in known resource names")
    cb(nil)
end

-- when a client asks “am I cop?”
RegisterNetEvent('police:checkJob', function()
    local src = source

    print(("[Police][DEBUG] Received checkJob from %d"):format(src))

    safeGetPlayerJob(src, function(jobId)
        print(("[Police][DEBUG] safeGetPlayerJob → %d has job '%s'"):format(src, tostring(jobId)))

        local isCop = false
        if jobId ~= nil then
            isCop = allowedJobs[tostring(jobId)] == true
        else
            print(("[Police][DEBUG] Could not determine job for player %d; treating as not a cop."):format(src))
        end

        print(("[Police][DEBUG] isCop = %s"):format(tostring(isCop)))
        TriggerClientEvent('police:checkJobResponse', src, isCop)
    end)
end)

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

-- Optional: helper to print current allowed job list for debugging
local function printAllowedJobs()
    local list = {}
    for k,_ in pairs(allowedJobs) do table.insert(list, tostring(k)) end
    print("[Az-PoliceMenu] Allowed jobs: " .. table.concat(list, ", "))
end

-- Print config on start if debug
AddEventHandler('onResourceStart', function(resName)
    if GetCurrentResourceName() ~= resName then return end
    debugPrint('Az-PoliceMenu server.lua started')
    if Config.Debug then printAllowedJobs() end
end)