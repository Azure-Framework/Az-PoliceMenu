
-- Function to send notifications or chat messages
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

-- Helper to get a player’s display name on the server
-- `serverId` is already the server index, so we can call GetPlayerName directly
local function FetchPlayerName(serverId, callback)
    local name = GetPlayerName(serverId) or ("Player " .. serverId)
    callback(name, serverId)
end

-- Function to deduct fines and send a message
local function DeductFine(targetPlayerId, amount, reason)
    FetchPlayerName(targetPlayerId, function(playerName, discordId)
        -- Deduct money via Az-Framework export
        exports['Az-Framework']:deductMoney(targetPlayerId, amount)

        local message = 'You have been fined: $' .. amount .. ' for: ' .. reason
        SendCitationHandler(targetPlayerId, "Fine:", message, amount)

        print(("Fined %s (serverID=%s) $%s for '%s'")
            :format(playerName, tostring(discordId), amount, reason))
    end)
end

-- Function to issue a ticket and send a message
local function IssueTicket(targetPlayerId, amount, reason)
    FetchPlayerName(targetPlayerId, function(playerName, discordId)
        exports['Az-Framework']:deductMoney(targetPlayerId, amount)

        local message = 'You have been issued a ticket: $' .. amount .. ' for: ' .. reason
        SendCitationHandler(targetPlayerId, "Ticket:", message, amount)

        print(("Issued ticket to %s (serverID=%s): $%s for '%s'")
            :format(playerName, tostring(discordId), amount, reason))
    end)
end

-- Function to issue a parking citation and send a message
local function IssueParkingCitation(targetPlayerId, amount, reason)
    FetchPlayerName(targetPlayerId, function(playerName, discordId)
        exports['Az-Framework']:deductMoney(targetPlayerId, amount)

        local message = 'You have been issued a parking citation: $' .. amount .. ' for: ' .. reason
        SendCitationHandler(targetPlayerId, "Parking Citation:", message, amount)

        print(("Issued parking citation to %s (serverID=%s): $%s for '%s'")
            :format(playerName, tostring(discordId), amount, reason))
    end)
end

-- Function to impound a vehicle and send a message
local function ImpoundVehicleHandler(targetPlayerId)
    FetchPlayerName(targetPlayerId, function(playerName, discordId)
        local message = "Your vehicle has been impounded."
        SendCitationHandler(targetPlayerId, "Impound:", message, 0)

        print(("Impounded vehicle for %s (serverID=%s)")
            :format(playerName, tostring(discordId)))
    end)
end

-- Register server events
RegisterServerEvent('process_fine')
AddEventHandler('process_fine', function(targetPlayerId, amount, reason)
    DeductFine(targetPlayerId, amount, reason)
end)

RegisterServerEvent('process_ticket')
AddEventHandler('process_ticket', function(targetPlayerId, amount, reason)
    IssueTicket(targetPlayerId, amount, reason)
end)

RegisterServerEvent('process_parking_citation')
AddEventHandler('process_parking_citation', function(targetPlayerId, amount, reason)
    IssueParkingCitation(targetPlayerId, amount, reason)
end)

RegisterServerEvent('process_impound_vehicle')
AddEventHandler('process_impound_vehicle', function(targetPlayerId)
    ImpoundVehicleHandler(targetPlayerId)
end)
