local function ShowNotification(text)
  -- try native if not using lib.notify
  if lib and lib.notify then
    lib.notify({ title = "Duty", description = text, type = "success" })
  else
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
  end
end

-- Command: /onduty
RegisterCommand("onduty", function()
  TriggerServerEvent('toggle_onduty')
  ShowNotification("Clocking in...")
end, false)

-- Command: /offduty
RegisterCommand("offduty", function()
  TriggerServerEvent('toggle_offDuty')
  ShowNotification("Clocking out...")
end, false)

-- Exported functions so your menu can call these events directly
exports('ClockIn', function()
  TriggerServerEvent('toggle_onduty')
end)

exports('ClockOut', function()
  TriggerServerEvent('toggle_offDuty')
end)

-- Optional: show small hint on resource start
AddEventHandler('onClientResourceStart', function(res)
  if GetCurrentResourceName() == res then
    ShowNotification("Duty system ready. Use /onduty and /offduty or your menu items.")
  end
end)
