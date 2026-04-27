fx_version 'cerulean'
game 'gta5'

author 'Mcdikmen'
description 'mcLaw - A simple law system for FiveM'
version '1.0.0'

dependencies {
    'ox_lib'
}

client_scripts {
    '@ox_lib/init.lua',
    'client/*.lua'
}

server_scripts {
    '@ox_lib/init.lua',
    'server/*.lua'
}

shared_scripts {
    'modules/utils_lib.js',
    'shared/*.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}