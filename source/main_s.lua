
local function dprint(...)
    if Config and Config.Debug then
        print("[Az-PoliceMenu]", ...)
    end
end

-- simple table->string helper (handles nested tables, avoids cycles)
local function dump(o, seen)
    seen = seen or {}
    if type(o) ~= "table" then return tostring(o) end
    if seen[o] then return "<cycle>" end
    seen[o] = true
    local parts = {}
    for k, v in pairs(o) do
        table.insert(parts, tostring(k) .. " = " .. dump(v, seen))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

-- Allowed jobs map
local allowedJobs = {}

-- Build allowedJobs strictly from Config.jobIdentifiers (safe if nil)
local function rebuildAllowedJobs()
    allowedJobs = {}

    if not Config or not Config.jobIdentifiers then
        print("[Az-PoliceMenu] WARNING: Config.jobIdentifiers is nil; using default { 'police' }")

    end

    if type(Config.jobIdentifiers) ~= "table" then
        print("[Az-PoliceMenu] ERROR: Config.jobIdentifiers must be a table. Coercing to default.")

    end

    print("[Az-PoliceMenu] rebuildAllowedJobs -> using Config.jobIdentifiers:")
    for i, v in ipairs(Config.jobIdentifiers or {}) do
        print(("  [%d] %s"):format(i, tostring(v)))
        if v ~= nil then
            allowedJobs[tostring(v)] = true
            if type(v) == "string" then allowedJobs[string.lower(v)] = true end
        end
    end
end

local function dumpAllowedJobs()
    local keys = {}
    for k, _ in pairs(allowedJobs) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    print("[Az-PoliceMenu] internal allowedJobs keys: " .. (next(keys) and table.concat(keys, ", ") or "<empty>"))
end

-- initial build
rebuildAllowedJobs()
dumpAllowedJobs()

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
        if job.PlayerData and job.PlayerData.job then
            if type(job.PlayerData.job) == "string" then
                return tostring(job.PlayerData.job)
            elseif type(job.PlayerData.job) == "table" and job.PlayerData.job.name then
                return tostring(job.PlayerData.job.name)
            end
        end
        return tostring(job)
    else
        return tostring(job)
    end
end

-- Robust getter (tries multiple exports/globals)
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

    -- ESX global fallback
    if _G["ESX"] and type(_G["ESX"].GetPlayerFromId) == "function" then
        local ok, player = pcall(function() return ESX.GetPlayerFromId(src) end)
        if ok and player then
            dprint("safeGetPlayerJob via ESX global")
            cb(player.job)
            return
        end
    end

    -- QBCore global fallback
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

-- Simple, defensive police check (works even if Config.jobIdentifiers missing)
RegisterNetEvent('police:checkJob', function()
    local src = source

    -- ensure allowedJobs is up-to-date (safe)
    rebuildAllowedJobs()
    dumpAllowedJobs()

    dprint(("Received checkJob from %d"):format(src))

    safeGetPlayerJob(src, function(jobRaw)
        print((" [Az-PoliceMenu] [JOB DEBUG] player %d raw job: %s"):format(src, dump(jobRaw)))
        local jobStr = extractJobString(jobRaw)
        print((" [Az-PoliceMenu] [JOB DEBUG] player %d extracted job string: %s"):format(src, tostring(jobStr)))

        local isCop = false
        if jobStr ~= nil then
            local jobLower = string.lower(tostring(jobStr))
            for _, v in ipairs(Config.jobIdentifiers or {}) do
                if jobLower == string.lower(tostring(v)) then
                    isCop = true
                    break
                end
            end
            if isCop then
                print((" [Az-PoliceMenu] police check: matched '%s'"):format(jobLower))
            else
                print((" [Az-PoliceMenu] police check: no match for '%s'"):format(jobLower))
            end
        else
            print((" [Az-PoliceMenu] Could not determine job for player %d; treating as not a cop."):format(src))
        end

        print((" [Az-PoliceMenu] isCop = %s"):format(tostring(isCop)))
        TriggerClientEvent('police:checkJobResponse', src, isCop)
    end)
end)

-- LEO helpers
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

-- Resource start / debug command
AddEventHandler('onResourceStart', function(resName)
    if GetCurrentResourceName() ~= resName then return end
    rebuildAllowedJobs()
    dprint('Az-PoliceMenu server.lua started; allowed jobs rebuilt')
    printAllowedJobs()
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
