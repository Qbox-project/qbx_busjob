local config = require 'config.server'
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'
local activeBuses = {}
local busesSpawning = {}

local function isAllowedModel(model)
    if type(model) ~= 'number' then return false end

    for i = 1, #clientConfig.allowedVehicles do
        if clientConfig.allowedVehicles[i].model == model then return true end
    end

    return false
end

local function isWorkBus(model)
    return isAllowedModel(model) or model == joaat('dynasty')
end

local function getNearbyStop(coords)
    for i = 1, #sharedConfig.npcLocations.locations do
        if #(coords - sharedConfig.npcLocations.locations[i].xyz) <= 20.0 then return i end
    end
end

lib.callback.register('qbx_busjob:server:spawnBus', function(source, model)
    local player = exports.qbx_core:GetPlayer(source)
    local ped = GetPlayerPed(source)
    if not player or player.PlayerData.job.name ~= 'bus' or ped == 0 or not isAllowedModel(model) then return end
    if #(GetEntityCoords(ped) - sharedConfig.location.xyz) > 7.5 then return end

    local activeBus = activeBuses[source]
    if busesSpawning[source] or activeBus and DoesEntityExist(activeBus.entity) then return end

    busesSpawning[source] = true
    local netId = qbx.spawnVehicle({ model = model, spawnSource = sharedConfig.location, warp = ped })
    busesSpawning[source] = nil
    if not netId or netId == 0 then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    if not exports.qbx_core:GetPlayer(source) then
        DeleteEntity(veh)
        return
    end

    activeBuses[source] = {
        entity = veh,
        routeIndex = 1,
        nextPayment = 0
    }

    local plate = locale('info.bus_plate') .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId
end)

RegisterNetEvent('qbx_busjob:server:NpcPay', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    if not player or player.PlayerData.job.name ~= 'bus' or ped == 0 then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    local bus = activeBuses[src]
    if not bus or not DoesEntityExist(bus.entity) then
        local stopIndex = getNearbyStop(GetEntityCoords(ped))
        if not stopIndex or not isWorkBus(GetEntityModel(vehicle)) then return end

        bus = { entity = vehicle, routeIndex = stopIndex, nextPayment = 0 }
        activeBuses[src] = bus
    end
    if bus.entity ~= vehicle or os.time() < bus.nextPayment then return end

    local stop = sharedConfig.npcLocations.locations[bus.routeIndex]
    if not stop or #(GetEntityCoords(ped) - stop.xyz) > 20.0 then return end

    bus.nextPayment = os.time() + 15
    bus.routeIndex = (bus.routeIndex + 1) % #sharedConfig.npcLocations.locations + 1

    local payment = math.random(15, 25)
    if math.random(1, 100) < config.bonusChance then
        payment = payment + math.random(10, 20)
    end
    player.Functions.AddMoney('cash', payment)
end)

AddEventHandler('playerDropped', function()
    local bus = activeBuses[source]
    if bus and DoesEntityExist(bus.entity) then DeleteEntity(bus.entity) end
    activeBuses[source] = nil
    busesSpawning[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, bus in pairs(activeBuses) do
        if DoesEntityExist(bus.entity) then DeleteEntity(bus.entity) end
    end
end)
