-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local route = 1
local max = #Config.NPCLocations.Locations
local busBlip = nil
local NpcData = {
    Active = false,
    CurrentNpc = nil,
    LastNpc = nil,
    CurrentDeliver = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}
local BusData = {
    Active = false
}
local VehicleZone = nil
local PickupZone = nil

-- Functions
local function resetNpcTask()
    NpcData = {
        Active = false,
        CurrentNpc = nil,
        LastNpc = nil,
        CurrentDeliver = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false
    }
end

local function updateBlip()
    if PlayerData.job.name == "bus" then
        local coords = Config.Location

        busBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

        SetBlipSprite(busBlip, 513)
        SetBlipDisplay(busBlip, 4)
        SetBlipScale(busBlip, 0.6)
        SetBlipAsShortRange(busBlip, true)
        SetBlipColour(busBlip, 49)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Lang:t('info.bus_depot'))
        EndTextCommandSetBlipName(busBlip)
    elseif busBlip then
        RemoveBlip(busBlip)
    end
end

local function whitelistedVehicle()
    local veh = GetEntityModel(cache.vehicle)
    local retval = false

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == Config.AllowedVehicles[i].model then
            retval = true
        end
    end

    return retval
end

local function nextStop()
    if route <= (max - 1) then
        route = route + 1
    else
        route = 1
    end
end

local function GetDeliveryLocation()
    nextStop()

    if NpcData.DeliveryBlip then
        RemoveBlip(NpcData.DeliveryBlip)
    end

    NpcData.DeliveryBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)

    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)

    NpcData.LastDeliver = route

    local inRange = false

    DeliverZone = lib.zones.sphere({
        name = "busjobdeliver",
        coords = vec3(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
        radius = 5,
        debug = false,
        onEnter = function()
            inRange = true

            lib.showTextUI(Lang:t('info.busstop_text'))

            CreateThread(function()
                repeat
                    Wait(0)

                    if IsControlJustPressed(0, 38) then
                        TaskLeaveVehicle(NpcData.Npc, cache.vehicle, 0)
                        SetEntityAsMissionEntity(NpcData.Npc, false, true)
                        SetEntityAsNoLongerNeeded(NpcData.Npc)

                        local targetCoords = Config.NPCLocations.Locations[NpcData.LastNpc]

                        TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)

                        QBCore.Functions.Notify(Lang:t('success.dropped_off'), 'success')

                        if NpcData.DeliveryBlip then
                            RemoveBlip(NpcData.DeliveryBlip)
                        end

                        local RemovePed = function(pped)
                            SetTimeout(60000, function()
                                DeletePed(pped)
                            end)
                        end

                        RemovePed(NpcData.Npc)

                        resetNpcTask()
                        nextStop()

                        TriggerEvent('qb-busjob:client:DoBusNpc')

                        lib.hideTextUI()

                        DeliverZone:remove()
                        break
                    end
                until not inRange
            end)
        end,
        onExit = function()
            lib.hideTextUI()

            inRange = false
        end
    })
end

local function busGarage()
    local vehicleMenu = {}

    for _, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            title = Lang:t('info.bus'),
            event = "qb-busjob:client:TakeVehicle",
            args = {
                model = v.model
            }
        }
    end

    lib.registerContext({
        id = 'open_busGarage_context_menu',
        title = Lang:t('menu.bus_header'),
        options = vehicleMenu
    })
    lib.showContext('open_busGarage_context_menu')
end

local function busMain()
    if PlayerData.job.name == "bus" then
        if not VehicleZone then
            local inRange = false

            VehicleZone = lib.zones.sphere({
                name = "busMain",
                coords = vec3(Config.Location.x, Config.Location.y, Config.Location.z),
                radius = 5,
                debug = false,
                onEnter = function()
                    inRange = true

                    CreateThread(function()
                        repeat
                            Wait(0)

                            local inVeh = whitelistedVehicle()

                            if not inVeh then
                                lib.showTextUI(Lang:t('info.busstop_text'))

                                if IsControlJustReleased(0, 38) then
                                    busGarage()

                                    lib.hideTextUI()
                                    break
                                end
                            else
                                lib.showTextUI(Lang:t('info.bus_stop_work'))

                                if IsControlJustReleased(0, 38) then
                                    if not NpcData.Active or NpcData.Active and not NpcData.NpcTaken then
                                        if IsPedInAnyVehicle(cache.ped, false) then
                                            BusData.Active = false

                                            DeleteVehicle(cache.vehicle)
                                            RemoveBlip(NpcData.NpcBlip)

                                            lib.hideTextUI()

                                            resetNpcTask()
                                            break
                                        end
                                    else
                                        QBCore.Functions.Notify(Lang:t('error.drop_off_passengers'), 'error')
                                    end
                                end
                            end
                        until not inRange
                    end)
                end,
                onExit = function()
                    lib.hideTextUI()

                    inRange = false
                end
            })
        end
    else
        if VehicleZone then
            VehicleZone:remove()
        end
    end
end

RegisterNetEvent("qb-busjob:client:TakeVehicle", function(data)
    local coords = Config.Location

    if BusData.Active then
        QBCore.Functions.Notify(Lang:t('error.one_bus_active'), 'error')
        return
    else
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)

            SetVehicleNumberPlateText(veh, Lang:t('info.bus_plate') .. tostring(math.random(1000, 9999)))
            SetVehicleFuelLevel(veh, 100.0)

            lib.hideContext()

            TaskWarpPedIntoVehicle(cache.ped, veh, -1)

            TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))

            SetVehicleEngineOn(veh, true, true, false)
        end, data.model, coords, true)

        Wait(1000)

        TriggerEvent('qb-busjob:client:DoBusNpc')
    end
end)

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()

    busMain()
    updateBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo

    busMain()
    updateBlip()
end)

RegisterNetEvent('qb-busjob:client:DoBusNpc', function()
    if whitelistedVehicle() then
        if not NpcData.Active then
            local Gender = math.random(1, #Config.NpcSkins)
            local PedSkin = math.random(1, #Config.NpcSkins[Gender])
            local model = joaat(Config.NpcSkins[Gender][PedSkin])

            lib.requestModel(model)

            NpcData.Npc = CreatePed(3, model, Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z - 0.98, Config.NPCLocations.Locations[route].w, false, true)

            PlaceObjectOnGroundProperly(NpcData.Npc)
            FreezeEntityPosition(NpcData.Npc, true)

            if NpcData.NpcBlip then
                RemoveBlip(NpcData.NpcBlip)
            end

            QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')

            NpcData.NpcBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)

            SetBlipColour(NpcData.NpcBlip, 3)
            SetBlipRoute(NpcData.NpcBlip, true)
            SetBlipRouteColour(NpcData.NpcBlip, 3)

            NpcData.LastNpc = route
            NpcData.Active = true

            local inRange = false

            PickupZone = lib.zones.sphere({
                name = "busjobdeliver",
                coords = vec3(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z),
                radius = 5,
                debug = false,
                onEnter = function()
                    inRange = true

                    lib.showTextUI(Lang:t('info.busstop_text'))

                    CreateThread(function()
                        repeat
                            Wait(0)

                            if IsControlJustPressed(0, 38) then
                                local maxSeats, freeSeat = GetVehicleModelNumberOfSeats(cache.vehicle)

                                for i = maxSeats - 1, 0, -1 do
                                    if IsVehicleSeatFree(cache.vehicle, i) then
                                        freeSeat = i
                                        break
                                    end
                                end

                                ClearPedTasksImmediately(NpcData.Npc)
                                FreezeEntityPosition(NpcData.Npc, false)
                                TaskEnterVehicle(NpcData.Npc, cache.vehicle, -1, freeSeat, 1.0, 0)

                                QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')

                                if NpcData.NpcBlip then
                                    RemoveBlip(NpcData.NpcBlip)
                                end

                                GetDeliveryLocation()

                                NpcData.NpcTaken = true

                                TriggerServerEvent('qb-busjob:server:NpcPay')

                                lib.hideTextUI()

                                PickupZone:remove()
                                break
                            end
                        until not inRange
                    end)
                end,
                onExit = function()
                    lib.hideTextUI()

                    inRange = false
                end
            })
        else
            QBCore.Functions.Notify(Lang:t('error.already_driving_bus'), 'error')
        end
    else
        QBCore.Functions.Notify(Lang:t('error.not_in_bus'), 'error')
    end
end)