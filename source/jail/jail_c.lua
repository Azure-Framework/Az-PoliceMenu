local kioskPed = nil
local kioskNetId = nil
local pedSpawned = false
local playerPed = PlayerPedId()

-- helper: load model
local function LoadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Citizen.Wait(1)
        if (GetGameTimer() - t) > 5000 then
            break
        end
    end
    return HasModelLoaded(hash)
end

-- helper: show help text (top-left contextual)
local function ShowHelpNotification(msg)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, 0, 1, -1)
end

-- spawn kiosk ped if enabled
local function SpawnKioskPed()
    if not Config.Jailer.usePeds then return end
    local coords = Config.Jailer.coords
    local model = GetHashKey(Config.Jailer.pedModel or "s_m_m_prisguard_01")
    if not LoadModel(model) then
        print("Jailer: failed to load ped model:", tostring(Config.Jailer.pedModel))
        return
    end

    if kioskPed and DoesEntityExist(kioskPed) then
        DeleteEntity(kioskPed)
        kioskPed = nil
    end

    kioskPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
    SetEntityHeading(kioskPed, coords.w or 0.0)
    FreezeEntityPosition(kioskPed, true)
    SetEntityInvincible(kioskPed, true)
    SetBlockingOfNonTemporaryEvents(kioskPed, true)
    pedSpawned = true
end

local function DeleteKioskPed()
    if kioskPed and DoesEntityExist(kioskPed) then
        SetEntityAsNoLongerNeeded(kioskPed)
        DeleteEntity(kioskPed)
        kioskPed = nil
    end
    pedSpawned = false
end

-- initialize on resource start
Citizen.CreateThread(function()
    -- spawn ped if enabled
    if Config.Jailer.usePeds then
        SpawnKioskPed()
    end
end)

-- cleanup on stop/restart
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        DeleteKioskPed()
    end
end)

-- draw marker & handle interaction
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        playerPed = PlayerPedId()
        local pcoords = GetEntityCoords(playerPed)
        local kiosk = Config.Jailer.coords
        local dist = #(pcoords - vector3(kiosk.x, kiosk.y, kiosk.z))
        -- draw marker if within drawDist and enabled
        if Config.Jailer.drawMarker and dist < Config.Jailer.drawDist then
            DrawMarker(
                Config.Jailer.markerType,
                kiosk.x,
                kiosk.y,
                kiosk.z - 0.98,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                Config.Jailer.markerScale.x,
                Config.Jailer.markerScale.y,
                Config.Jailer.markerScale.z,
                255, 120, 0, 180,
                false,
                true,
                2,
                nil,
                nil,
                false
            )
        end

        -- show help & listen for E press when close enough
        if dist <= Config.Jailer.interactDist then
            ShowHelpNotification(Config.Jailer.helpText)
            if IsControlJustReleased(0, 38) then -- E key
                -- execute the command just as requested
                ExecuteCommand("Jailer")
            end
        end
    end
end)



-- register the jailer context menu (simple lib menu for now)
lib.registerContext({
    id = "jailer_menu",
    title = "Jailer Kiosk",
    canClose = true,
    options = {
        {
            title = "Jail Player by ID",
            onSelect = function()
                local dialog = lib.inputDialog("Jail Player", {
                    { type = 'number', label = 'Target Server ID', name = 'target', required = true },
                    { type = 'number', label = 'Time (minutes)', name = 'time', required = true, min = 1, default = 5 },
                    { type = 'select', label = 'Cell', name = 'cell', options = (function()
                        local opts = {}
                        for i = 1, #Config.Jailer.cellPositions do
                            table.insert(opts, { value = tostring(i), label = "Cell " .. tostring(i) })
                        end
                        if #opts == 0 then table.insert(opts, { value = "1", label = "Cell 1" }) end
                        return opts
                    end)(), required = true}
                }, { allowCancel = true, size = 'md' })

                if not dialog then return end
                local target = tonumber(dialog.target)
                local time = tonumber(dialog.time)
                local cellIndex = tonumber(dialog.cell) or 1

                if not target or not time then
                    lib.notify({ title = "Jailer", description = "Invalid input.", type = "error" })
                    return
                end

                -- send to server to process jailing (server must implement jail logic)
                TriggerServerEvent("jailer:jailPlayer", target, time, cellIndex)
                lib.notify({ title = "Jailer", description = "Jail request sent.", type = "inform" })
            end
        },
        {
            title = "Unjail Player by ID",
            onSelect = function()
                local dialog = lib.inputDialog("Unjail Player", {
                    { type = 'number', label = 'Target Server ID', name = 'target', required = true }
                }, { allowCancel = true, size = 'sm' })

                if not dialog then return end
                local target = tonumber(dialog.target)
                if not target then
                    lib.notify({ title = "Jailer", description = "Invalid ID.", type = "error" })
                    return
                end
                TriggerServerEvent("jailer:unJailPlayer", target)
                lib.notify({ title = "Jailer", description = "Unjail request sent.", type = "inform" })
            end
        },
        {
            title = "Teleport to Cell (client)",
            onSelect = function()
                local opts = {}
                for i = 1, #Config.Jailer.cellPositions do
                    local c = Config.Jailer.cellPositions[i]
                    table.insert(opts, { value = tostring(i), label = "Cell " .. tostring(i) })
                end
                if #opts == 0 then
                    lib.notify({ title = "Jailer", description = "No cells configured.", type = "error" })
                    return
                end

                local dialog = lib.inputDialog("Teleport to Cell", {
                    { type = 'select', label = 'Select Cell', name = 'cell', options = opts, required = true }
                }, { allowCancel = true, size = 'sm' })

                if not dialog then return end
                local idx = tonumber(dialog.cell) or 1
                local pos = Config.Jailer.cellPositions[idx] or Config.Jailer.coords
                SetEntityCoords(PlayerPedId(), pos.x, pos.y, pos.z)
                SetEntityHeading(PlayerPedId(), pos.w or 0.0)
                lib.notify({ title = "Jailer", description = "Teleported to cell " .. tostring(idx), type = "success" })
            end
        },
        {
            title = "Open Config (show coords)",
            onSelect = function()
                local c = Config.Jailer.coords
                lib.notify({
                    title = "Jailer Config",
                    description = ("XYZH: %.3f, %.3f, %.3f, %.1f"):format(c.x, c.y, c.z, c.w or 0.0),
                    type = "inform"
                })
            end
        },
        {
            title = "Close",
            onSelect = function() lib.hideContext(true) end
        }
    }
})

-- Server event example handlers (clients listen for confirmations)
RegisterNetEvent("jailer:notify")
AddEventHandler("jailer:notify", function(data)
    -- data = { title = "...", description = "...", type = "inform" }
    lib.notify(data)
end)