fx_version 'adamant'
games { 'gta5' }
dependency 'chat'
lua54 'yes'
version '1.3.0'
author 'TheStoicBear | ValenciaModifcations'
description 'Az-PoliceMenu'

client_scripts {
    'source/search/search_c.lua',
    'source/citation/citation_c.lua',
    'source/jail/jail_c.lua',
    'source/gsr/gsr_c.lua',
    'source/main_c.lua',
    'source/actions/client.lua',
    'source/duty/client.lua'
}

server_scripts {
    'config_S.lua',
    '@oxmysql/lib/MySQL.lua',
    'source/search/search_s.lua',
    'source/citation/citation_s.lua',
    'source/gsr/gsr_s.lua',
    'source/main_s.lua',
    'source/jail/jail_s.lua',
    'source/actions/server.lua',
    'source/duty/server.lua'
} 

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua"
} 
