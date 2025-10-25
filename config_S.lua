Config = {}

Config.jobIdentifiers = { "MOLICE", "sheriff", "state" }-- Job identifiers (consistent casing — change to match your framework)
Config.toggle_duty = true                     -- enable/disable the toggle items in your menu
Config.duty_table_name = "duty_records"       -- DB table name
Config.clock_webhook_url = "https://discord.com/api/webhooks/YOUR_DISCORD_WEBHOOK"  -- <- PUT YOUR WEBHOOK HERE
Config.webhook_username = "Duty Logger"
Config.embed_color_on  = 0x00FF00  -- green
Config.embed_color_off = 0xFF0000  -- red
Config.CAD = {
    enabled = true,                       -- toggle CAD import on/off
    resourceName = "Az-5PD",    -- resource name to check (adjust if different)
    dbName = "testersz",                  -- the DB/schema from your SQL dump
    tableName = "mdt_id_records"          -- table name
}
