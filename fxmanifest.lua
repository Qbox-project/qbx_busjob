fx_version 'cerulean'
game 'gta5'

version '1.0.0'
repository 'https://github.com/Qbox-project/qb-busjob'

shared_scripts {
    'config.lua',
    '@qbx-core/import.lua',
    '@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_script 'server/main.lua'

files {
    'locales/*.json'
}

dependencies {
    'qb-core',
    'ox_lib'
}


modules {
    'qbx_core:core',
	'qbx_core:playerdata',
	'qbx_core:utils'
}



lua54 'yes'
use_experimental_fxv2_oal 'yes'
