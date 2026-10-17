fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Mcdikmen'
description 'mcLaw - A simple law system for FiveM (County RP / QBCore build)'
version '1.1.0'

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
    'qb-target',
    'qb-menu',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.secret.lua', -- server only, gitignored (webhook URL)
    'server/*.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}
