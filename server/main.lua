
lib.locale()

local function isPlayerNearBus(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    for _, v in pairs(Config.NPCLocations.Locations) do
        local dist = #(coords - vec3(v.x, v.y, v.z))
        if dist < 20 then
            return true
        end
    end
    return false
end

lib.callback.register('qb-busjob:server:spawnBus', function(source, model)
    local netId = SpawnVehicle(source, model, Config.Location, true)
    if not netId or netId == 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local plate = locale('bus_plate') .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId
end)

RegisterNetEvent('qb-busjob:server:NpcPay', function()
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= "bus" or not isPlayerNearBus(src) then return DropPlayer(src, locale('exploit_attempt')) end

    local payment = math.random(15, 25)
    if math.random(1, 100) < Config.BonusChance then
        payment = payment + math.random(10, 20)
    end
    Player.Functions.AddMoney('cash', payment)
end)
