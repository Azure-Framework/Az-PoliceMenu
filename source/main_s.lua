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

  if type(exports) ~= "table" then
    cb(nil)
    return
  end

  for resName, _ in pairs(exports) do
    local fn = exports[resName] and exports[resName].getPlayerJob
    if type(fn) == "function" then
      -- Try a synchronous-style call (many frameworks return value directly)
      local ok, res = pcall(function() return exports[resName]:getPlayerJob(src) end)
      if ok and res ~= nil then
        if DEBUG_DISPATCH then
          print(("[dispatch] safeGetPlayerJob sync via %s -> %s"):format(resName, tostring(res)))
        end
        return cb(res)
      end

      -- If sync didn't return anything, try calling it as async (with callback)
      local okAsync, err = pcall(function()
        exports[resName]:getPlayerJob(src, function(job)
          if DEBUG_DISPATCH then
            print(("[dispatch] safeGetPlayerJob async via %s -> %s"):format(resName, tostring(job)))
          end
          cb(job)
        end)
      end)
      if okAsync then
        return
      end
    end
  end

  -- nothing found
  if DEBUG_DISPATCH then
    print("[dispatch] safeGetPlayerJob: no export named getPlayerJob found")
  end
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
