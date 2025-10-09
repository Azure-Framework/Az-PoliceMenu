-- Server-side: guarded search request (add to server.lua)

-- Ensure Config exists; you probably already have Config. This provides a safe default.
Config = Config or {}
Config.AllowedDepts = Config.AllowedDepts or {} -- e.g. {"police","sheriff"}

-- Helper: try to resolve player's department/job using Az-Framework exports (robust to different API shapes)
local function resolvePlayerDepartment(src)
  if not exports['Az-Framework'] then return nil end

  -- Try a few common export names / shapes
  local ok, res

  -- 1) GetPlayerDepartment(src) -> string or table
  ok, res = pcall(function() return exports['Az-Framework']:GetPlayerDepartment(src) end)
  if ok and res and res ~= "" then
    if type(res) == "table" then
      -- attempt to transform table into a string (common shapes)
      return tostring(res.department or res.name or res.job or next(res) and tostring(res[next(res)]) or nil)
    end
    return tostring(res)
  end

  -- 2) GetPlayerJob(src) -> table or string (common in some frameworks)
  ok, res = pcall(function() return exports['Az-Framework']:GetPlayerJob(src) end)
  if ok and res and res ~= "" then
    if type(res) == "table" then
      return tostring(res.department or res.name or res.label or res.job or res.id or nil)
    end
    return tostring(res)
  end

  -- 3) GetPlayerData / GetCharacter / GetPlayerInfo - attempt generic getters that may contain job/department
  ok, res = pcall(function() return exports['Az-Framework']:GetPlayerCharacter(src) end)
  if ok and res and type(res) == "table" then
    -- If Az-Framework returns a character table with a job/department field
    return tostring(res.department or res.job or res.jobname or res.job.label or nil)
  end

  -- not found
  return nil
end

-- Utility: case-insensitive membership test
local function isInAllowedDepts(dept)
  if not dept or type(dept) ~= "string" then return false end
  for _, allowed in ipairs(Config.AllowedDepts or {}) do
    if tostring(allowed):lower() == dept:lower() then
      return true
    end
  end
  return false
end

-- Main server event: client requests to search a nearby player (server enforces permission if Az-Inventory running)
RegisterNetEvent('search:request')
AddEventHandler('search:request', function(targetServerId)
  local src = source
  targetServerId = tonumber(targetServerId) or 0
  if targetServerId <= 0 then
    -- invalid target
    TriggerClientEvent('chat:addMessage', src, { args = { "^1Search", "Invalid target ID." } })
    return
  end

  -- If Az-Inventory is started, enforce department whitelist (if configured)
  local azInvState = GetResourceState("Az-Inventory") -- returns "started", "stopped", "missing", etc.
  if azInvState == "started" then
    -- If no AllowedDepts configured, treat as open (no restriction)
    if Config.AllowedDepts and #Config.AllowedDepts > 0 then
      local dept = resolvePlayerDepartment(src)
      if not dept then
        -- Could not resolve department -> deny (safe default)
        TriggerClientEvent('chat:addMessage', src, { args = { "^1Search", "You are not allowed to search players (department not found)." } })
        print(("[search] Denied search for src=%d: department could not be resolved"):format(src))
        return
      end

      if not isInAllowedDepts(dept) then
        TriggerClientEvent('chat:addMessage', src, { args = { "^1Search", "You do not have permission to search players." } })
        print(("[search] Denied search for src=%d: department '%s' not allowed"):format(src, tostring(dept)))
        return
      end
      -- allowed; continue below
    end
  end

  -- At this point: Az-Inventory not started OR no AllowedDepts configured OR department matched → allow the search
  -- Tell the requesting client to perform the inventory open (client will call the export)
  TriggerClientEvent('search:performClient', src, targetServerId)
  print(("[search] Allowed search: src=%d -> target=%d (Az-Inventory state=%s)"):format(src, targetServerId, tostring(azInvState)))
end)
