local function ExecuteSQL(query, params, cb)
    cb = cb or function() end
    if GetResourceState("oxmysql") == "started" or GetResourceState("oxmysql") == "starting" then
        -- oxmysql
        local ok, res = pcall(function()
            exports.oxmysql:insert(query, params, function(insertId)
                cb(insertId)
            end)
        end)
        if not ok then
            print("[CAD/SQL] oxmysql execute failed:", res)
            cb(nil)
        end
        return
    end

    if GetResourceState("mysql-async") == "started" or GetResourceState("mysql-async") == "starting" or GetResourceState("mysql_async") == "started" then
        -- mysql-async / MySQL.Async
        if MySQL and MySQL.Async and MySQL.Async.execute then
            MySQL.Async.execute(query, params, function(affected)
                cb(affected)
            end)
            return
        end
    end

    -- fallback: we don't have a supported SQL resource available
    print("[CAD/SQL] No supported MySQL resource (oxmysql/mysql-async) available to execute query.")
    cb(nil)
end

-- Helper to test whether CAD resource is running
local function IsCADStarted()
    local res = Config.CAD.resourceName
    if res and GetResourceState(res) == "started" then
        return true
    end
    return false
end

-- Helper: insert a record into testersz.mdt_id_records
-- fields: target_type, target_value, rtype, title, description, creator_identifier, creator_discord, creator_source
local function InsertIntoCAD(opts)
    -- opts table should contain keys: target_type, target_value, rtype, title, description, creator_identifier, creator_discord, creator_source
    if not Config.CAD.enabled or not IsCADStarted() then
        print("[CAD] CAD not started or integration disabled — skipping DB insert.")
        return
    end

    local tbl = Config.CAD.tableName
    local db = Config.CAD.dbName

    -- Use full table name to ensure target DB (as your dump used 'testersz')
    local fullTable = ("`%s`.`%s`"):format(db, tbl)

    local q = ("INSERT INTO %s (target_type, target_value, rtype, title, description, creator_identifier, creator_discord, creator_source) VALUES (@type, @value, @rtype, @title, @description, @creator_identifier, @creator_discord, @creator_source)"):format(fullTable)
    local params = {
        ["@type"] = opts.target_type or "name",
        ["@value"] = opts.target_value or tostring(opts.target_value or ""),
        ["@rtype"] = opts.rtype or "ticket",
        ["@title"] = opts.title or "",
        ["@description"] = opts.description or "",
        ["@creator_identifier"] = opts.creator_identifier or "",
        ["@creator_discord"] = opts.creator_discord or "",
        ["@creator_source"] = tonumber(opts.creator_source) or -1
    }

    ExecuteSQL(q, params, function(res)
        if res then
            print(("[CAD] Inserted record into %s (target=%s rtype=%s creator_cid=%s)"):format(fullTable, params["@value"], params["@rtype"], params["@creator_identifier"]))
        else
            print("[CAD] Failed to insert record into CAD DB.")
        end
    end)
end

-- Helper: fetch target & creator character ids / names using Az-Framework exports
-- callback(targetCid, targetName, creatorCid, creatorName)
local function FetchCharacterInfo(targetServerId, creatorServerId, cb)
    cb = cb or function() end
    -- Attempt to get CIDs via Az-Framework synchronous export (per your docs)
    local ok, targetCid = pcall(function() return exports['Az-Framework']:GetPlayerCharacter(targetServerId) end)
    if not ok then targetCid = nil end

    local ok2, creatorCid = pcall(function() return exports['Az-Framework']:GetPlayerCharacter(creatorServerId) end)
    if not ok2 then creatorCid = nil end

    -- Start by getting names (Az returns via callback for name)
    local targetName = GetPlayerName(targetServerId) or ("Player " .. tostring(targetServerId))
    local creatorName = GetPlayerName(creatorServerId) or ("Player " .. tostring(creatorServerId))

    -- If Az-Framework export exists for GetPlayerCharacterName, call it (async)
    if exports['Az-Framework'] and exports['Az-Framework'].GetPlayerCharacterName then
        local gotTargetName = false
        local gotCreatorName = false

        pcall(function()
            exports['Az-Framework']:GetPlayerCharacterName(targetServerId, function(err, name)
                if not err and name then
                    targetName = name
                end
                gotTargetName = true
                if gotTargetName and gotCreatorName then
                    cb(targetCid, targetName, creatorCid, creatorName)
                end
            end)
        end)

        pcall(function()
            exports['Az-Framework']:GetPlayerCharacterName(creatorServerId, function(err, name)
                if not err and name then
                    creatorName = name
                end
                gotCreatorName = true
                if gotTargetName and gotCreatorName then
                    cb(targetCid, targetName, creatorCid, creatorName)
                end
            end)
        end)

        -- safety timeout in case callbacks never fire
        Citizen.SetTimeout(1500, function()
            if not (gotTargetName and gotCreatorName) then
                cb(targetCid, targetName, creatorCid, creatorName)
            end
        end)
    else
        -- No Az name export, return what we have
        cb(targetCid, targetName, creatorCid, creatorName)
    end
end

-- Reusable notification function (keeps your previous ox_lib style)
local function SendCitationHandler(playerId, title, message, cost)
    local data = {
        id = playerId,
        title = title,
        description = message,
        duration = 5000,
        position = 'bottom',
        type = 'inform',
        style = {},
        icon = 'fas fa-info-circle',
        iconColor = '#ffffff',
        iconAnimation = 'fade',
        alignIcon = 'center'
    }
    TriggerClientEvent('ox_lib:notify', playerId, data)
end


local function DeductFine(targetPlayerId, amount, reason)
    local src = source
    print("[CITATION] DeductFine called (this should be invoked from the proper server event handler).")
end

RegisterServerEvent('process_fine')
AddEventHandler('process_fine', function(targetPlayerId, amount, reason)
    local creator = source
    pcall(function()
        if exports['Az-Framework'] and exports['Az-Framework'].deductMoney then
            exports['Az-Framework']:deductMoney(targetPlayerId, amount)
        else
            print("[Az-Framework] deductMoney export not found. Skipping deduct.")
        end
    end)

    -- Notify target player
    local message = 'You have been fined: $' .. tostring(amount) .. ' for: ' .. tostring(reason)
    SendCitationHandler(targetPlayerId, "Fine:", message, amount)

    -- Fetch char info and insert into CAD if available
    FetchCharacterInfo(targetPlayerId, creator, function(targetCid, targetName, creatorCid, creatorName)
        local title = ("Fine: $%s"):format(tostring(amount))
        local description = ("%s — %s"):format(tostring(reason), message)
        InsertIntoCAD({
            target_type = "name",
            target_value = targetName,
            rtype = "fine",
            title = title,
            description = description,
            creator_identifier = tostring(creatorCid or ""),
            creator_discord = "", -- leave blank or fill if you capture discord
            creator_source = tonumber(creator)
        })
        print(("[CITATION] Fined %s (serverID=%s) $%s for '%s'"):format(targetName, tostring(targetPlayerId), tostring(amount), tostring(reason)))
    end)
end)

RegisterServerEvent('process_ticket')
AddEventHandler('process_ticket', function(targetPlayerId, amount, reason)
    local creator = source
    pcall(function()
        if exports['Az-Framework'] and exports['Az-Framework'].deductMoney then
            exports['Az-Framework']:deductMoney(targetPlayerId, amount)
        end
    end)

    local message = 'You have been issued a ticket: $' .. tostring(amount) .. ' for: ' .. tostring(reason)
    SendCitationHandler(targetPlayerId, "Ticket:", message, amount)

    FetchCharacterInfo(targetPlayerId, creator, function(targetCid, targetName, creatorCid, creatorName)
        local title = ("Ticket: $%s"):format(tostring(amount))
        local description = ("%s — %s"):format(tostring(reason), message)
        InsertIntoCAD({
            target_type = "name",
            target_value = targetName,
            rtype = "ticket",
            title = title,
            description = description,
            creator_identifier = tostring(creatorCid or ""),
            creator_discord = "",
            creator_source = tonumber(creator)
        })
        print(("[CITATION] Ticketed %s (serverID=%s) $%s for '%s'"):format(targetName, tostring(targetPlayerId), tostring(amount), tostring(reason)))
    end)
end)

RegisterServerEvent('process_parking_citation')
AddEventHandler('process_parking_citation', function(targetPlayerId, amount, reason)
    local creator = source
    pcall(function()
        if exports['Az-Framework'] and exports['Az-Framework'].deductMoney then
            exports['Az-Framework']:deductMoney(targetPlayerId, amount)
        end
    end)

    local message = 'You have been issued a parking citation: $' .. tostring(amount) .. ' for: ' .. tostring(reason)
    SendCitationHandler(targetPlayerId, "Parking Citation:", message, amount)

    FetchCharacterInfo(targetPlayerId, creator, function(targetCid, targetName, creatorCid, creatorName)
        local title = ("Parking Citation: $%s"):format(tostring(amount))
        local description = ("%s — %s"):format(tostring(reason), message)
        InsertIntoCAD({
            target_type = "name",
            target_value = targetName,
            rtype = "parking",
            title = title,
            description = description,
            creator_identifier = tostring(creatorCid or ""),
            creator_discord = "",
            creator_source = tonumber(creator)
        })
        print(("[CITATION] Parking citation for %s (serverID=%s) $%s for '%s'"):format(targetName, tostring(targetPlayerId), tostring(amount), tostring(reason)))
    end)
end)

RegisterServerEvent('process_impound_vehicle')
AddEventHandler('process_impound_vehicle', function(targetPlayerId)
    local creator = source
    local message = "Your vehicle has been impounded."
    SendCitationHandler(targetPlayerId, "Impound:", message, 0)

    FetchCharacterInfo(targetPlayerId, creator, function(targetCid, targetName, creatorCid, creatorName)
        InsertIntoCAD({
            target_type = "name",
            target_value = targetName,
            rtype = "impound",
            title = "Vehicle Impounded",
            description = message,
            creator_identifier = tostring(creatorCid or ""),
            creator_discord = "",
            creator_source = tonumber(creator)
        })
        print(("[CITATION] Impounded vehicle for %s (serverID=%s)"):format(targetName, tostring(targetPlayerId)))
    end)
end)