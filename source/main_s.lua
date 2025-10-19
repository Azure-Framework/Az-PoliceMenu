---@diagnostic disable: undefined-global

Config = Config or {}
Config.Debug = Config.Debug or false

local function dprint(...)
    if Config.Debug then
        print("[Az-PoliceMenu]", ...)
    end
end

local allowedJobs = {}

local function rebuildAllowedJobs()
    allowedJobs = {}

    if Config.jobIdentifiers == nil then
        if Config.PoliceJobs and #Config.PoliceJobs > 0 then
            Config.jobIdentifiers = Config.PoliceJobs
            dprint("Config.jobIdentifiers was nil; using Config.PoliceJobs")
        else
            Config.jobIdentifiers = { "Police", "sheriff", "state" }
            dprint("Config.jobIdentifiers was nil; using built-in default list")
        end
    end


    for _, id in ipairs(Config.jobIdentifiers or {}) do
        if id ~= nil then
            allowedJobs[tostring(id)] = true
            if type(id) == "string" then
                allowedJobs[string.lower(id)] = true
            end
        end
    end
end

rebuildAllowedJobs()

local function printAllowedJobs()
    local exact, lower = {}, {}
    for _, id in ipairs(Config.jobIdentifiers or {}) do
        table.insert(exact, tostring(id))
        if type(id) == "string" then table.insert(lower, string.lower(id)) end
    end
    print("[Az-PoliceMenu] Config.jobIdentifiers (exact): " .. table.concat(exact, ", "))
    print("[Az-PoliceMenu] Internal allowedJobs lowerkeys: " .. table.concat(lower, ", "))
end

local function notify(src, title, msg, typ)
    if TriggerClientEvent and exports and exports.ox_lib then
        TriggerClientEvent('ox_lib:notify', src, {
            title = title,
            description = msg,
            type = typ
        })
    else
        dprint(("notify -> %s: %s"):format(tostring(title), tostring(msg)))
    end
end

local function extractJobString(job)
    if job == nil then return nil end

    if type(job) == "string" then
        return job
    elseif type(job) == "table" then
        if job.name then return tostring(job.name) end
        if job.job  then return tostring(job.job) end
        if job.label then return tostring(job.label) end
        return tostring(job)
    else
        return tostring(job)
    end
end

local function safeGetPlayerJob(src, cb)
    assert(type(cb) == "function", "safeGetPlayerJob requires a callback")

    local triedResources = {
        "Az-Framework", "az-framework", "Az_Framework", "az_framework",
        "qb-core", "QBCore",
        "es_extended", "esx_society"
    }

    local function trySync(resName)
        if exports and exports[resName] and type(exports[resName].getPlayerJob) == "function" then
            local ok, res = pcall(function() return exports[resName]:getPlayerJob(src) end)
            if ok then
                dprint(("safeGetPlayerJob (sync) via %s -> %s"):format(resName, tostring(res)))
                return true, res
            else
                dprint(("safeGetPlayerJob (sync) via %s errored: %s"):format(resName, tostring(res)))
                return false, nil
            end
        end
        return false, nil
    end

    local function tryAsync(resName)
        if exports and exports[resName] and type(exports[resName].getPlayerJob) == "function" then
            local ok, err = pcall(function()
                exports[resName]:getPlayerJob(src, function(job)
                    dprint(("safeGetPlayerJob (async) via %s -> %s"):format(resName, tostring(job)))
                    cb(job)
                end)
            end)
            if not ok then
                dprint(("safeGetPlayerJob: async call to %s failed: %s"):format(resName, tostring(err)))
                return false
            end
            return true
        end
        return false
    end

    for _, resName in ipairs(triedResources) do
        local okSync, res = trySync(resName)
        if okSync then
            cb(res)
            return
        end

        local okAsync = tryAsync(resName)
        if okAsync then
            return
        end
    end

    if _G["ESX"] and type(_G["ESX"].GetPlayerFromId) == "function" then
        local ok, player = pcall(function() return ESX.GetPlayerFromId(src) end)
        if ok and player then
            dprint("safeGetPlayerJob via ESX global")
            cb(player.job)
            return
        end
    end

    if _G["QBCore"] and type(_G["QBCore"].GetPlayer) == "function" then
        local ok, ply = pcall(function() return QBCore.GetPlayer(src) end)
        if ok and ply then
            dprint("safeGetPlayerJob via QBCore global")
            cb(ply.PlayerData and ply.PlayerData.job or nil)
            return
        end
    end

    dprint("safeGetPlayerJob: No getPlayerJob export found; returning nil")
    cb(nil)
end

-- Replace existing 'police:checkJob' handler with this code.
RegisterNetEvent('police:checkJob', function()
    local src = source

    if next(allowedJobs) == nil then
        rebuildAllowedJobs()
        dprint("Allowed jobs was empty; rebuilt from Config.jobIdentifiers")
    end

    dprint(("Received checkJob from %d (Az-Framework only)"):format(src))

    -- Attempt to get job solely via Az-Framework export
    local jobRaw = nil
    if exports and exports["Az-Framework"] and type(exports["Az-Framework"].getPlayerJob) == "function" then
        local ok, res = pcall(function()
            return exports["Az-Framework"]:getPlayerJob(src)
        end)
        if ok then
            jobRaw = res
            dprint(("Az-Framework getPlayerJob returned: %s"):format(tostring(res)))
        else
            dprint(("Az-Framework getPlayerJob errored for %d: %s"):format(src, tostring(res)))
        end
    else
        dprint("Az-Framework export getPlayerJob NOT found.")
    end

    local jobStr = extractJobString(jobRaw)
    dprint(("extracted job string -> %s (preserved case)"):format(tostring(jobStr)))

    rebuildAllowedJobs()

    local isCop = false
    if jobStr ~= nil then
        if allowedJobs[jobStr] then
            isCop = true
            dprint(("police check: exact match passed for '%s'"):format(tostring(jobStr)))
        else
            local lower = string.lower(tostring(jobStr))
            if allowedJobs[lower] then
                isCop = true
                dprint(("police check: lowercase fallback matched '%s' -> '%s'"):format(tostring(jobStr), lower))
            end
        end
    else
        dprint(("Could not determine job for player %d via Az-Framework; treating as not a cop."):format(src))
    end

    dprint(("isCop = %s"):format(tostring(isCop)))
    TriggerClientEvent('police:checkJobResponse', src, isCop)
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

AddEventHandler('onResourceStart', function(resName)
    if GetCurrentResourceName() ~= resName then return end
    rebuildAllowedJobs()
    dprint('Az-PoliceMenu server.lua started; allowed jobs rebuilt')
    if Config.Debug then printAllowedJobs() end
end)

RegisterCommand("azfw_debug_jobs", function(src)
    if src == 0 then
        printAllowedJobs()
    else
        local allowed = table.concat((function()
            local t = {}
            for _, id in ipairs(Config.jobIdentifiers or {}) do table.insert(t, tostring(id)) end
            return t
        end)(), ", ")
        notify(src, "Az-PoliceMenu", "Allowed jobs (exact as-config): " .. allowed, "success")
    end
end, true)
