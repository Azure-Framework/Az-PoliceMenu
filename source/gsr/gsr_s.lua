-- server.lua
-- Server-side for CIV self-tests + GSR
-- Returns nil for unset BAC/Drugs so clients can display "Nothing"

-- PlayerTests: keyed by serverId -> { gsr=false, gsrTimer=0, bac=nil, bacSet=false, drugs=nil, drugsSet=false, hasData=false }
local PlayerTests = {}

local function ensurePlayerEntry(id)
    if not PlayerTests[id] then
        PlayerTests[id] = { gsr = false, gsrTimer = 0, bac = nil, bacSet = false, drugs = nil, drugsSet = false, hasData = false }
    end
    return PlayerTests[id]
end

-- ===== Safe Text / Config fallbacks =====
local DefaultText = {
    TestedPositive    = "Tested: Positive",
    TestedNegative    = "Tested: Negative",
    GettingTestedMsg  = "You are being tested by "
}

local Text = {}
do
    local cfgText = (Config and Config.Text) or {}
    for k, v in pairs(DefaultText) do Text[k] = v end
    for k, v in pairs(cfgText) do
        if type(v) == "string" and v ~= "" then
            Text[k] = v
        end
    end
end

local function getAutoCleanSeconds()
    return (Config and Config.GSRAutoClean) or 120
end

-- ===== CIV: Save self-tests from clients =====
RegisterNetEvent('CIV:SetSelfTests')
AddEventHandler('CIV:SetSelfTests', function(data)
    local src = source
    if not src then return end

    local entry = ensurePlayerEntry(src)

    if data.bac ~= nil then
        entry.bac = tonumber(data.bac) or 0.0
        entry.bacSet = true
    end
    if data.drugs ~= nil then
        entry.drugs = (data.drugs == true)
        entry.drugsSet = true
    end

    -- mark hasData if any of the fields set or gsr occurred
    entry.hasData = entry.hasData or entry.bacSet or entry.drugsSet or entry.gsr

    -- notify client with authoritative state (includes bacSet/drugsSet)
    TriggerClientEvent('GSR:SelfUpdate', src, entry)
    TriggerClientEvent('GSR:TestNotify', src, "Your self-test values have been saved.")
end)

-- ===== GSR: client reported firing -> server authoritative set =====
RegisterNetEvent('GSR:ReportFired')
AddEventHandler('GSR:ReportFired', function()
    local src = source
    if not src then return end

    local entry = ensurePlayerEntry(src)
    entry.gsr = true
    entry.gsrTimer = getAutoCleanSeconds()
    entry.hasData = true

    -- -- notify the client of the authoritative update
    -- TriggerClientEvent('GSR:SelfUpdate', src, entry)
end)

-- ===== GSR Countdown (server-side) =====
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        for serverId, entry in pairs(PlayerTests) do
            if entry and entry.gsr and entry.gsrTimer and entry.gsrTimer > 0 then
                entry.gsrTimer = entry.gsrTimer - 1
                if entry.gsrTimer <= 0 then
                    entry.gsr = false
                    entry.gsrTimer = 0
                    local sid = tonumber(serverId)
                    if sid then
                        TriggerClientEvent('GSR:SelfUpdate', sid, entry)
                    end
                end
            end
        end
    end
end)

-- ===== TEST: server bridge for BAC/Drugs =====
RegisterNetEvent('tests:request')
AddEventHandler('tests:request', function(targetServerId, testType)
    local requester = source
    if not requester or not targetServerId or not testType then return end
    targetServerId = tonumber(targetServerId)

    local entry = PlayerTests[targetServerId]
    if entry and entry.hasData then
        -- Only send value if explicitly set; otherwise send nil (client will show "Nothing")
        if testType == 'bac' then
            if entry.bacSet then
                local bacVal = tonumber(entry.bac) or 0.0
                TriggerClientEvent('tests:response', requester, 'bac', bacVal, targetServerId)
            else
                TriggerClientEvent('tests:response', requester, 'bac', nil, targetServerId)
            end
        elseif testType == 'drugs' then
            if entry.drugsSet then
                local drugsVal = (entry.drugs == true)
                TriggerClientEvent('tests:response', requester, 'drugs', drugsVal, targetServerId)
            else
                TriggerClientEvent('tests:response', requester, 'drugs', nil, targetServerId)
            end
        end

        -- optionally notify subject
        if Config and Config.NotifySubject then
            TriggerClientEvent('GSR:TestNotify', targetServerId, (Text.GettingTestedMsg or "") .. tostring(GetPlayerName(requester) or "a tester"))
        end
    else
        -- ask the target to reply (client will call tests:callback). Client may reply nil if not set.
        TriggerClientEvent('tests:ask_target', targetServerId, requester, testType)
        if Config and Config.NotifySubject then
            TriggerClientEvent('GSR:TestNotify', targetServerId, (Text.GettingTestedMsg or "") .. tostring(GetPlayerName(requester) or "a tester"))
        end
    end
end)

-- Called by target client when asked to run a test locally
RegisterNetEvent('tests:callback')
AddEventHandler('tests:callback', function(requesterServerId, testType, result)
    local tested = source
    if not requesterServerId or not testType then return end
    requesterServerId = tonumber(requesterServerId)
    TriggerClientEvent('tests:response', requesterServerId, testType, result, tested)
end)

-- ===== GSR test path (police -> server) =====
RegisterNetEvent("GSR:TestPlayer")
AddEventHandler("GSR:TestPlayer", function(tested)
    local tester = source
    if not tester or not tested then return end

    local entry = PlayerTests[tested]
    if entry and entry.hasData then
        if entry.gsr then
            TriggerClientEvent("GSR:TestNotify", tester, Text.TestedPositive)
        else
            TriggerClientEvent("GSR:TestNotify", tester, Text.TestedNegative)
        end

        if Config and Config.NotifySubject then
            TriggerClientEvent("GSR:TestNotify", tested, (Text.GettingTestedMsg or "") .. tostring(GetPlayerName(tester) or "a tester"))
        end
    else
        -- fallback: ask tested client to run original handler
        TriggerClientEvent("GSR:TestHandler", tested, tester)
        if Config and Config.NotifySubject then
            TriggerClientEvent("GSR:TestNotify", tested, (Text.GettingTestedMsg or "") .. tostring(GetPlayerName(tester) or "a tester"))
        end
    end
end)

-- Legacy callback handler for clients that call back results to server
RegisterNetEvent("GSR:TestCallback")
AddEventHandler("GSR:TestCallback", function(tester, result)
    if not tester then return end
    if result then
        TriggerClientEvent("GSR:TestNotify", tester, Text.TestedPositive)
    else
        TriggerClientEvent("GSR:TestNotify", tester, Text.TestedNegative)
    end
end)

-- Optional export
exports('GetPlayerTests', function(serverId)
    return PlayerTests[serverId]
end)

-- Cleanup when players leave
AddEventHandler('playerDropped', function(reason)
    local sid = tostring(source)
    if PlayerTests[sid] then PlayerTests[sid] = nil end
end)

-- Debug command to dump PlayerTests to server console (console-only)
RegisterCommand('debug_gsr_dump', function(source, args, raw)
    if source ~= 0 then
        print("debug_gsr_dump: console only")
        return
    end
    print("=== GSR PlayerTests dump ===")
    for k, v in pairs(PlayerTests) do
        print(("%s -> gsr=%s gsrTimer=%s bac=%s bacSet=%s drugs=%s drugsSet=%s hasData=%s"):format(
            tostring(k),
            tostring(v.gsr),
            tostring(v.gsrTimer),
            tostring(v.bac),
            tostring(v.bacSet),
            tostring(v.drugs),
            tostring(v.drugsSet),
            tostring(v.hasData)
        ))
    end
    print("=== end dump ===")
end, false)

-- End of server.lua
