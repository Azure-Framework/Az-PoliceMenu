-- In-memory cache of player duty state: DutyState[src] = true/false
local DutyState = {}

-- Helper: extract Discord ID from identifiers (robust)
local function getDiscordFromIdentifiers(src)
  local ids = GetPlayerIdentifiers(src) or {}
  for _, id in ipairs(ids) do
    if type(id) == "string" then
      local d = id:match("^discord:(%d+)$")
      if d and #d >= 17 then
        return d
      end
      d = id:match("(%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d?)")
      if d and #d >= 17 then
        return d
      end
    end
  end
  return ""
end

-- Helper: attempt to get character ID from Az-Framework exports (if present)
local function getCharIdFromExports(src)
  if exports and exports['Az-Framework'] then
    local ok, res = pcall(function() return exports['Az-Framework']:GetPlayerCharacter(src) end)
    if ok and res and res ~= "" then
      return tostring(res)
    end
  end
  return ""
end

-- Check for MySQL.Async availability
local hasMySQLAsync = (MySQL and MySQL.Async and type(MySQL.Async.execute) == "function")

-- ensure table using OxMySQL await
local function ensureDutyTable()
  local tname = tostring(Config.duty_table_name or "duty_records")
  local create_sql = ([[CREATE TABLE IF NOT EXISTS `%s` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `serverid` INT NOT NULL,
    `discordid` VARCHAR(64) DEFAULT '',
    `charid` VARCHAR(64) DEFAULT '',
    `action` VARCHAR(16) NOT NULL,
    `timestamp` BIGINT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]]):format(tname)

  local ok, err = pcall(function()
    -- uses OxMySQL await API
    MySQL.query.await(create_sql, {})
    print(("[duty] ensured table exists (oxmysql): %s"):format(tname))
  end)
  if not ok then
    print(("[duty] Could not create table via oxmysql: %s"):format(tostring(err)))
  end
end

-- insert history using oxmysql await insert (returns insert id)
local function insertDutyHistory(serverid, discordid, charid, action)
  local tname = tostring(Config.duty_table_name or "duty_records")
  local sql = ([[INSERT INTO `%s` (serverid,discordid,charid,action,timestamp)
    VALUES (?, ?, ?, ?, ?)]]):format(tname)
  local ts = os.time()
  local ok, err = pcall(function()
    local insertedId = MySQL.insert.await(sql, { serverid, discordid, charid, action, ts })
    -- optionally log insertedId
  end)
  if not ok then
    print(("[duty] insertDutyHistory failed (oxmysql): %s"):format(tostring(err)))
  end
end


-- Send Discord webhook embed (if configured)
local function sendDiscordWebhook(title, action, src, discordid, charid)
  local url = Config.clock_webhook_url or ""
  if not url or url == "" or url == "https://discord.com/api/webhooks/..." then
    print("[duty] webhook URL not configured; skipping Discord embed.")
    return
  end

  local playerName = GetPlayerName(src) or ("ID "..tostring(src))
  local serverId = tonumber(src) or 0
  local ts_iso = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()) -- UTC ISO format

  local color = (action == "in") and (Config.embed_color_on or 0x00FF00) or (Config.embed_color_off or 0xFF0000)

  local embed = {
    title = title,
    color = color,
    fields = {
      { name = "Player", value = playerName, inline = true },
      { name = "Server ID", value = tostring(serverId), inline = true },
      { name = "Discord ID", value = (discordid ~= "" and discordid or "Unknown"), inline = true },
      { name = "Character ID", value = (charid ~= "" and charid or "Unknown"), inline = true },
      { name = "Action", value = (action == "in" and "Clock In" or "Clock Out"), inline = true },
      { name = "Timestamp (UTC)", value = ts_iso, inline = true }
    },
    timestamp = ts_iso
  }

  local body = {
    username = Config.webhook_username or "Duty Logger",
    embeds = { embed }
  }

  local headers = { ["Content-Type"] = "application/json" }
  local okBody = json and json.encode or function(t) return tostring(t) end
  local payload = okBody(body)

  PerformHttpRequest(url, function(statusCode, responseText, responseHeaders)
    if statusCode ~= 204 and statusCode ~= 200 then
      print(("[duty] webhook send responded: %s   body: %s"):format(tostring(statusCode), tostring(responseText)))
    end
  end, "POST", payload, headers)
end

-- Toggle ON duty handler (client -> server)
RegisterNetEvent('toggle_onduty')
AddEventHandler('toggle_onduty', function()
  local src = source
  -- update in-memory
  DutyState[src] = true

  local discordid = getDiscordFromIdentifiers(src) or ""
  local charid = getCharIdFromExports(src) or ""

  -- persist (async)
  insertDutyHistory(src, discordid, charid, "in")

  -- notify console and client
  print(("[duty] Player %s (src=%d) clocked IN. discord=%s char=%s"):format(GetPlayerName(src) or "unknown", src, discordid, charid))
  TriggerClientEvent('chat:addMessage', src, { args = { "^2Duty", "You are now ON duty." } })

  -- send webhook embed (non-blocking)
  sendDiscordWebhook("Clock In", "in", src, discordid, charid)
end)

-- Toggle OFF duty handler (client -> server)
RegisterNetEvent('toggle_offDuty')
AddEventHandler('toggle_offDuty', function()
  local src = source
  -- update in-memory
  DutyState[src] = false

  local discordid = getDiscordFromIdentifiers(src) or ""
  local charid = getCharIdFromExports(src) or ""

  -- persist (async)
  insertDutyHistory(src, discordid, charid, "out")

  -- notify
  print(("[duty] Player %s (src=%d) clocked OUT. discord=%s char=%s"):format(GetPlayerName(src) or "unknown", src, discordid, charid))
  TriggerClientEvent('chat:addMessage', src, { args = { "^2Duty", "You are now OFF duty." } })

  -- send webhook embed (non-blocking)
  sendDiscordWebhook("Clock Out", "out", src, discordid, charid)
end)

exports('IsPlayerOnDuty', function(src)
  src = tonumber(src) or source
  return DutyState[src] == true
end)

AddEventHandler("playerDropped", function()
  local src = source
  DutyState[src] = nil
end)

-- Ensure DB table on resource start
AddEventHandler('onResourceStart', function(resourceName)
  if resourceName == GetCurrentResourceName() then
    ensureDutyTable()
  end
end)

-- Also ensure when script loads (in case onResourceStart fired earlier)
Citizen.CreateThread(function()
  Wait(1000)
  ensureDutyTable()
end)
