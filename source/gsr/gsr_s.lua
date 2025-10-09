local PlayerTests = {} -- keyed by serverId -> { gsr = false, gsrTimer = 0, bac = 0.0, drugs = false }

local function ensurePlayerEntry(id)
    if not PlayerTests[id] then
        PlayerTests[id] = { gsr = false, gsrTimer = 0, bac = 0.0, drugs = false, hasData = false }
    end
    return PlayerTests[id]
end

-- Civs set their own BAC / drug result
RegisterNetEvent('CIV:SetSelfTests')
AddEventHandler('CIV:SetSelfTests', function(data)
    local src = source
    local entry = ensurePlayerEntry(src)

    if data.bac ~= nil then
        entry.bac = tonumber(data.bac) or 0.0
    end
    if data.drugs ~= nil then
        entry.drugs = (data.drugs == true)
    end

    entry.hasData = true
    -- notify client so they can show UI/state if needed
    TriggerClientEvent('GSR:SelfUpdate', src, entry)
    TriggerClientEvent('GSR:TestNotify', src, "Your self-test values have been saved.")
end)

-- Client reports they fired a gun -> set server-side GSR and start server timer
RegisterNetEvent('GSR:ReportFired')
AddEventHandler('GSR:ReportFired', function()
    local src = source
    local entry = ensurePlayerEntry(src)
    entry.gsr = true
    entry.gsrTimer = (Config and Config.GSRAutoClean) or 120
    entry.hasData = true
    -- optional: notify the player (small msg)
    TriggerClientEvent('GSR:SelfUpdate', src, entry)
end)

-- Maintain GSR countdown server-side
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for serverId, entry in pairs(PlayerTests) do
            if entry.gsr and entry.gsrTimer and entry.gsrTimer > 0 then
                entry.gsrTimer = entry.gsrTimer - 1
                if entry.gsrTimer <= 0 then
                    entry.gsr = false
                    entry.gsrTimer = 0
                    -- notify player that their GSR cleared
                    TriggerClientEvent('GSR:SelfUpdate', tonumber(serverId), entry)
                end
            end
        end
    end
end)

RegisterNetEvent("GSR:TestPlayer")
AddEventHandler("GSR:TestPlayer", function(tested)
    local tester = source

    local entry = PlayerTests[tested]
    if entry and entry.hasData then
        -- we have server-side data -> notify tester directly (same message flow as original)
        if entry.gsr then
            TriggerClientEvent("GSR:TestNotify", tester, Config.Text.TestedPositive)
        else
            TriggerClientEvent("GSR:TestNotify", tester, Config.Text.TestedNegative)
        end

        if Config and Config.NotifySubject then
            TriggerClientEvent("GSR:TestNotify", tested, Config.Text.GettingTestedMsg .. GetPlayerName(tester))
        end
    else
        -- fallback to original behavior: trigger target client to perform test and callback server
        TriggerClientEvent("GSR:TestHandler", tested, tester)
        if Config and Config.NotifySubject then
            TriggerClientEvent("GSR:TestNotify", tested, Config.Text.GettingTestedMsg .. GetPlayerName(tester))
        end
    end
end)

-- Keep original TestCallback handling intact (in case clients still use it)
RegisterNetEvent("GSR:TestCallback")
AddEventHandler("GSR:TestCallback", function(tester, result)
    if result then
        TriggerClientEvent("GSR:TestNotify", tester, Config.Text.TestedPositive)
    else
        TriggerClientEvent("GSR:TestNotify", tester, Config.Text.TestedNegative)
    end
end)