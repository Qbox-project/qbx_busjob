-- Locale lib
lib.locale()

-- Variables

local PlayerData = QBX.Functions.GetPlayerData()
local route = 1
local max = #Config.NPCLocations.Locations
local busBlip = nil
local VehicleZone
local DeliverZone
local PickupZone

local NpcData = {
    Active = false,
    LastNpc = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local BusData = {
    Active = false,
}

-- Functions
local function resetNpcTask()
    NpcData = {
        Active = false,
        LastNpc = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false,
    }
end

local function removeBusBlip()
    if not busBlip then return end
    RemoveBlip(busBlip)
    busBlip = nil
end

local function removeNPCBlip()
    if NpcData.DeliveryBlip then
        RemoveBlip(NpcData.DeliveryBlip)
        NpcData.DeliveryBlip = nil
    end

    if NpcData.NpcBlip then
        RemoveBlip(NpcData.NpcBlip)
        NpcData.NpcBlip = nil
    end
end

local function updateBlip()
    if table.type(PlayerData) == 'empty' or (PlayerData.job.name ~= "bus" and busBlip) then
        removeBusBlip()
        return
    elseif (PlayerData.job.name == "bus" and not busBlip) then
        local coords = Config.Location
        busBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(busBlip, 513)
        SetBlipDisplay(busBlip, 4)
        SetBlipScale(busBlip, 0.6)
        SetBlipAsShortRange(busBlip, true)
        SetBlipColour(busBlip, 49)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(locale('bus_depot'))
        EndTextCommandSetBlipName(busBlip)
        return
    end
end

local function isPlayerVehicleABus()
    if not cache.vehicle then return false end
    local veh = GetEntityModel(cache.vehicle)

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == Config.AllowedVehicles[i].model then
            return true
        end
    end

    if veh == `dynasty` then
        return true
    end

    return false
end

local function nextStop()
    route = route <= (max - 1) and route + 1 or 1
end

local function removePed(ped)
    SetTimeout(60000, function()
        DeletePed(ped)
    end)
end

local function GetDeliveryLocation()
    nextStop()
    removeNPCBlip()
    NpcData.DeliveryBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)
    NpcData.LastDeliver = route
    local inRange = false
    local shownTextUI = false
    DeliverZone = lib.zones.sphere({
        name = "qb_busjob_bus_deliver",
        coords = vec3(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
        radius = 5,
        debug = Config.Debug,
        onEnter = function()
            inRange = true
            if not shownTextUI then
                lib.showTextUI(locale('busstop_text'))
                shownTextUI = true
            end
            CreateThread(function()
                repeat
                    Wait(0)
                    if IsControlJustPressed(0, 38) then
                        TaskLeaveVehicle(NpcData.Npc, cache.vehicle, 0)
                        SetEntityAsMissionEntity(NpcData.Npc, false, true)
                        SetEntityAsNoLongerNeeded(NpcData.Npc)
                        local targetCoords = Config.NPCLocations.Locations[NpcData.LastNpc]
                        TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
                        lib.notify({
                            title = locale('bus_job'),
                            description = locale('dropped_off'),
                            type = 'success'
                        })
                        removeNPCBlip()
                        removePed(NpcData.Npc)
                        resetNpcTask()
                        nextStop()
                        TriggerEvent('qb-busjob:client:DoBusNpc')
                        lib.hideTextUI()
                        shownTextUI = false
                        DeliverZone:remove()
                        DeliverZone = nil
                        break
                    end
                until not inRange
            end)
        end,
        onExit = function()
            lib.hideTextUI()
            shownTextUI = false
            inRange = false
        end
    })
end

local function busGarage()
    local vehicleMenu = {}
    for _, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            title = locale('bus'),
            event = "qb-busjob:client:TakeVehicle",
            args = v
        }
    end
    lib.registerContext({
        id = 'qb_busjob_open_garage_context_menu',
        title = locale('bus_header'),
        options = vehicleMenu
    })
    lib.showContext('qb_busjob_open_garage_context_menu')
end

local function updateZone()
    if VehicleZone then
        VehicleZone:remove()
        VehicleZone = nil
    end

    if table.type(PlayerData) == 'empty' or QBX.PlayerData.job.name ~= 'bus' then return end

    local inRange = false
    local shownTextUI = false
    VehicleZone = lib.zones.sphere({
        name = "qb_busjob_bus_main",
        coords = Config.Location.xyz,
        radius = 5,
        debug = Config.Debug,
        onEnter = function()
            inRange = true
            CreateThread(function()
                repeat
                    Wait(0)
                    if not isPlayerVehicleABus() then
                        if not shownTextUI then
                            lib.showTextUI(locale('bus_job_vehicles'))
                            shownTextUI = true
                        end
                        if IsControlJustReleased(0, 38) then
                            busGarage()
                            lib.hideTextUI()
                            shownTextUI = false
                            break
                        end
                    else
                        if not shownTextUI then
                            lib.showTextUI(locale('bus_stop_work'))
                            shownTextUI = true
                        end
                        if IsControlJustReleased(0, 38) then
                            if not NpcData.Active or NpcData.Active and not NpcData.NpcTaken then
                                if cache.vehicle then
                                    BusData.Active = false
                                    DeleteVehicle(cache.vehicle)
                                    removeNPCBlip()
                                    lib.hideTextUI()
                                    shownTextUI = false
                                    resetNpcTask()
                                    break
                                end
                            else
                                lib.notify({
                                    title = locale('bus_job'),
                                    description = locale('drop_off_passengers'),
                                    type = 'error'
                                })
                            end
                        end
                    end
                until not inRange
            end)
        end,
        onExit = function()
            shownTextUI = false
            inRange = false
            Wait(1000)
            lib.hideTextUI()
        end
    })
end

-- onExit()

RegisterNetEvent("qb-busjob:client:TakeVehicle", function(data)
    if BusData.Active then
        lib.notify({
            title = locale('bus_job'),
            description = locale('one_bus_active'),
            type = 'error'
        })
        return
    end

    local netId = lib.callback.await('qb-busjob:server:spawnBus', false, data.model)
    Wait(300)
    if not netId or netId == 0 or not NetworkDoesEntityExistWithNetworkId(netId) then
        lib.notify({
            title = locale('bus_job'),
            description = locale('failed_to_spawn'),
            type = 'error'
        })
        return
    end

    local veh = NetToVeh(netId)
    if veh == 0 then
        lib.notify({
            title = locale('bus_job'),
            description = locale('failed_to_spawn'),
            type = 'error'
        })
        return
    end

    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleEngineOn(veh, true, true, false)
    lib.hideContext()
    TriggerEvent('qb-busjob:client:DoBusNpc')
end)

-- Events
AddEventHandler('onResourceStart', function(resourceName)
    -- handles script restarts
    if GetCurrentResourceName() ~= resourceName then return end

    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBX.Functions.GetPlayerData()
    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    updateBlip()
    updateZone()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    updateBlip()
    updateZone()
end)

RegisterNetEvent('qb-busjob:client:DoBusNpc', function()
    if not isPlayerVehicleABus() then
        lib.notify({
            title = locale('bus_job'),
            description = locale('not_in_bus'),
            type = 'error'
        })
        return
    end

    if not NpcData.Active then
        local Gender = math.random(1, #Config.NpcSkins)
        local PedSkin = math.random(1, #Config.NpcSkins[Gender])
        local model = joaat(Config.NpcSkins[Gender][PedSkin])
        lib.requestModel(model)
        NpcData.Npc = CreatePed(3, model, Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z - 0.98, Config.NPCLocations.Locations[route].w, false, true)
        PlaceObjectOnGroundProperly(NpcData.Npc)
        FreezeEntityPosition(NpcData.Npc, true)
        removeNPCBlip()
        NpcData.NpcBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
        SetBlipColour(NpcData.NpcBlip, 3)
        SetBlipRoute(NpcData.NpcBlip, true)
        SetBlipRouteColour(NpcData.NpcBlip, 3)
        NpcData.LastNpc = route
        NpcData.Active = true
        local inRange = false
        local shownTextUI = false
        PickupZone = lib.zones.sphere({
            name = "qb_busjob_bus_pickup",
            coords = vec3(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
            radius = 5,
            debug = Config.Debug,
            onEnter = function()
                inRange = true
                if not shownTextUI then
                    lib.showTextUI(locale('busstop_text'))
                    shownTextUI = true
                end
                CreateThread(function()
                    repeat
                        Wait(0)
                        if IsControlJustPressed(0, 38) then
                            local maxSeats, freeSeat = GetVehicleModelNumberOfSeats(GetEntityModel(cache.vehicle))

                            for i = maxSeats - 1, 0, -1 do
                                if IsVehicleSeatFree(cache.vehicle, i) then
                                    freeSeat = i
                                    break
                                end
                            end

                            if not freeSeat then return end

                            ClearPedTasksImmediately(NpcData.Npc)
                            FreezeEntityPosition(NpcData.Npc, false)
                            TaskEnterVehicle(NpcData.Npc, cache.vehicle, -1, freeSeat, 1.0, 0)
                            Wait(3000)
                            lib.notify({
                                title = locale('bus_job'),
                                description = locale('goto_busstop'),
                                type = 'info'
                            })
                            removeNPCBlip()
                            GetDeliveryLocation()
                            NpcData.NpcTaken = true
                            TriggerServerEvent('qb-busjob:server:NpcPay')
                            lib.hideTextUI()
                            shownTextUI = false
                            PickupZone:remove()
                            PickupZone = nil
                            break
                        end
                    until not inRange
                end)
            end,
            onExit = function()
                lib.hideTextUI()
                shownTextUI = false
                inRange = false
            end
        })
    else
        lib.notify({
            title = locale('bus_job'),
            description = locale('already_driving_bus'),
            type = 'info'
        })
    end
end)
