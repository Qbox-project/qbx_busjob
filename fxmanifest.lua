fx_version 'cerulean'
game 'gta5'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    '@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_script 'server/main.lua'

dependency 'ox_lib'

lua54 'yes'