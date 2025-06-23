-- Example: replace NDCore.getPlayer + ox_inventory:AddItem
-- with Az-Framework equivalents. Adjust export names as needed.

-- Utility to fetch player data via Az-Framework.
-- You need an export or callback from Az-Framework that, given a discord ID or source, returns job info.
-- I'll assume something like exports['Az-Framework']:getPlayerData(discordId, callback),
-- where callback receives a table with at least .job.
-- If Az-Framework uses a synchronous return, adapt accordingly.

-- Example for police check:
function HandlePoliceRoleCheck(source)
    -- get Discord ID from source
    local discordId = exports['Az-Framework']:getDiscordId(source)
    if not discordId then
        print("Could not retrieve Discord ID for source " .. tostring(source))
        return
    end

    -- fetch player data via Az-Framework (replace with actual API)
    exports['Az-Framework']:getPlayerData(discordId, function(playerData)
        if not playerData or not playerData.job then
            print(("No job data for Discord ID %s"):format(discordId))
            return
        end

        local pdJob = playerData.job
        -- Check if the player has a police job
        for _, jobName in ipairs(Config.PoliceJobs) do
            if pdJob == jobName then
                -- The player is in a police job.
                -- Instead of giving items via ox_inventory, call the Az-Framework inventory method,
                -- or send a notification, or whatever is appropriate in your framework.
                -- Example placeholder:
                -- exports['Az-Framework']:giveItem(discordId, itemName, amount)
                -- For now, just log:
                print(("Discord ID %s has police job '%s'"):format(discordId, pdJob))

                -- If Az-Framework has an “addInventoryItem” export, use it:
                -- for _, item in ipairs(Config.PoliceItems) do
                --     local ok, err = exports['Az-Framework']:addInventoryItem(discordId, item, 1)
                --     if not ok then
                --         print(("Failed to give item '%s' to %s: %s"):format(item, discordId, tostring(err)))
                --     end
                -- end

                return
            end
        end

        print(("Discord ID %s is not in a police job (found '%s')"):format(discordId, pdJob))
    end)
end

-- Example for EMS check:
function HandleEMSRoleCheck(source)
    local discordId = exports['Az-Framework']:getDiscordId(source)
    if not discordId then
        print("Could not retrieve Discord ID for source " .. tostring(source))
        return
    end

    exports['Az-Framework']:getPlayerData(discordId, function(playerData)
        if not playerData or not playerData.job then
            print(("No job data for Discord ID %s"):format(discordId))
            return
        end

        local emsJob = playerData.job
        -- Check if the player has an EMS job
        for _, jobName in ipairs(Config.EMSJobs) do
            if emsJob == jobName then
                -- The player is in an EMS job.
                print(("Discord ID %s has EMS job '%s'"):format(discordId, emsJob))

                -- Placeholder for giving items via Az-Framework:
                -- for _, item in ipairs(Config.EMSItems) do
                --     local ok, err = exports['Az-Framework']:addInventoryItem(discordId, item, 1)
                --     if not ok then
                --         print(("Failed to give EMS item '%s' to %s: %s"):format(item, discordId, tostring(err)))
                --     end
                -- end

                return
            end
        end

        print(("Discord ID %s is not in an EMS job (found '%s')"):format(discordId, emsJob))
    end)
end

-- If Az-Framework’s getPlayerData is synchronous, e.g.:
-- local playerData = exports['Az-Framework']:getPlayerData(discordId)
-- then adapt accordingly:
-- function HandlePoliceRoleCheck(source)
--     local discordId = exports['Az-Framework']:getDiscordId(source)
--     if not discordId then return end
--     local playerData = exports['Az-Framework']:getPlayerData(discordId)
--     if not playerData or not playerData.job then
--         print("No job data for " .. discordId)
--         return
--     end
--     local pdJob = playerData.job
--     ...
-- end

-- Example usage: hook into an event when you want to check/give items:
RegisterCommand("checkPoliceRole", function(source, args, rawCommand)
    HandlePoliceRoleCheck(source)
end, false)

RegisterCommand("checkEMSRole", function(source, args, rawCommand)
    HandleEMSRoleCheck(source)
end, false)

-- If you also want to fetch departments as in your snippet:
-- Example: print available departments on resource start or via a command:
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        exports['Az-Framework']:getDepartments(function(depts)
            for _, dept in ipairs(depts) do
                print("Department:", dept.name)
            end
        end)
    end
end)

-- Or via command:
RegisterCommand("listDepartments", function(source, args)
    exports['Az-Framework']:getDepartments(function(depts)
        for _, dept in ipairs(depts) do
            print("Department:", dept.name)
        end
    end)
end, false)
