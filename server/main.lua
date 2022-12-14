local QBCore = exports['qb-core']:GetCoreObject()

local function NearBus(src)
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

RegisterNetEvent('qb-busjob:server:NpcPay', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.name ~= "bus" or not NearBus(src) then return DropPlayer(src, 'Attempting to exploit') end

    local payment = math.random(15, 25)
    local randomAmount = math.random(1, 5)
    local r1, r2 = math.random(1, 5), math.random(1, 5)
    if randomAmount == r1 or randomAmount == r2 then
        payment += math.random(10, 20)
    end
    Player.Functions.AddMoney('cash', payment)
end)
