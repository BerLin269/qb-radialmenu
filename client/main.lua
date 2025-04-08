QBCore = exports['qb-core']:GetCoreObject()
PlayerData = QBCore.Functions.GetPlayerData()
local inRadialMenu = false

local jobIndex = nil
local vehicleIndex = nil

local DynamicMenuItems = {}
local FinalMenuItems = {}
local controlsToToggle = { 24, 0, 1, 2, 142, 257, 346 } -- if not using toggle

local showMenu = false
local shape = 'hex'
local animation = Config.Ui.Animation


local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if not orig.canOpen or orig.canOpen() then
            local toRemove = {}
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                if type(orig_value) == 'table' then
                    if not orig_value.canOpen or orig_value.canOpen() then
                        copy[deepcopy(orig_key)] = deepcopy(orig_value)
                    else
                        toRemove[orig_key] = true
                    end
                else
                    copy[deepcopy(orig_key)] = deepcopy(orig_value)
                end
            end
            for i = 1, #toRemove do table.remove(copy, i) end
            if copy and next(copy) then setmetatable(copy, deepcopy(getmetatable(orig))) end
        end
    elseif orig_type ~= 'function' then
        copy = orig
    end
    return copy
end

local function getNearestVeh()
    local pos = GetEntityCoords(PlayerPedId())
    local entityWorld = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 20.0, 0.0)
    local rayHandle = CastRayPointToPoint(pos.x, pos.y, pos.z, entityWorld.x, entityWorld.y, entityWorld.z, 10, PlayerPedId(), 0)
    local _, _, _, _, vehicleHandle = GetRaycastResult(rayHandle)
    return vehicleHandle
end

local function AddOption(data, id)
    local menuID = id ~= nil and id or (#DynamicMenuItems + 1)
    DynamicMenuItems[menuID] = deepcopy(data)
    DynamicMenuItems[menuID].res = GetInvokingResource()
    return menuID
end

local function RemoveOption(id)
    DynamicMenuItems[id] = nil
end

local function SetupJobMenu()
    local JobInteractionCheck = PlayerData.job.name
    if PlayerData.job.type == 'leo' then JobInteractionCheck = 'police' end
    local JobMenu = {
        id = 'jobinteractions',
        title = 'Work',
        icon = 'briefcase',
        items = {}
    }
    if Config.JobInteractions[JobInteractionCheck] and next(Config.JobInteractions[JobInteractionCheck]) and PlayerData.job.onduty then
        JobMenu.items = Config.JobInteractions[JobInteractionCheck]
    end

    if #JobMenu.items == 0 then
        if jobIndex then
            RemoveOption(jobIndex)
            jobIndex = nil
        end
    else
        jobIndex = AddOption(JobMenu, jobIndex)
    end
end

local function SetupVehicleMenu()
    local VehicleMenu = {
        id = 'vehicle',
        title = 'Vehicle',
        icon = 'car',
        items = {}
    }

    local ped = PlayerPedId()
    local Vehicle = GetVehiclePedIsIn(ped) ~= 0 and GetVehiclePedIsIn(ped) or getNearestVeh()
    if Vehicle ~= 0 then
        VehicleMenu.items[#VehicleMenu.items + 1] = Config.VehicleDoors
        if Config.EnableExtraMenu then VehicleMenu.items[#VehicleMenu.items + 1] = Config.VehicleExtras end

        if not IsVehicleOnAllWheels(Vehicle) then
            VehicleMenu.items[#VehicleMenu.items + 1] = {
                id = 'vehicle-flip',
                title = 'Flip Vehicle',
                icon = 'car-burst',
                type = 'client',
                event = 'qb-radialmenu:flipVehicle',
                shouldClose = true
            }
        end

        if IsPedInAnyVehicle(ped) then
            local seatIndex = #VehicleMenu.items + 1
            VehicleMenu.items[seatIndex] = deepcopy(Config.VehicleSeats)

            local seatTable = {
                [1] = Lang:t('options.driver_seat'),
                [2] = Lang:t('options.passenger_seat'),
                [3] = Lang:t('options.rear_left_seat'),
                [4] = Lang:t('options.rear_right_seat'),
            }

            local AmountOfSeats = GetVehicleModelNumberOfSeats(GetEntityModel(Vehicle))
            for i = 1, AmountOfSeats do
                local newIndex = #VehicleMenu.items[seatIndex].items + 1
                VehicleMenu.items[seatIndex].items[newIndex] = {
                    id = i - 2,
                    title = seatTable[i] or Lang:t('options.other_seats'),
                    icon = 'caret-up',
                    type = 'client',
                    event = 'qb-radialmenu:client:ChangeSeat',
                    shouldClose = false,
                }
            end
        end
    end

    if #VehicleMenu.items == 0 then
        if vehicleIndex then
            RemoveOption(vehicleIndex)
            vehicleIndex = nil
        end
    else
        vehicleIndex = AddOption(VehicleMenu, vehicleIndex)
    end
end

local function SetupSubItems()
    SetupJobMenu()
    SetupVehicleMenu()
end

local function selectOption(t, t2)
    for _, v in pairs(t) do
        if v.items then
            local found, hasAction, val = selectOption(v.items, t2)
            if found then return true, hasAction, val end
        else
            if v.id == t2.id and ((v.event and v.event == t2.event) or v.action) and (not v.canOpen or v.canOpen()) then
                return true, v.action, v
            end
        end
    end
    return false
end

local function IsPoliceOrEMS()
    return (PlayerData.job.name == 'police' or PlayerData.job.type == 'leo' or PlayerData.job.name == 'ambulance')
end

local function IsDowned()
    return (PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand'])
end

local function SetupRadialMenu()
    FinalMenuItems = {}
    if (IsDowned() and IsPoliceOrEMS()) then
        FinalMenuItems = {
            [1] = {
                id = 'emergencybutton2',
                title = Lang:t('options.emergency_button'),
                icon = 'fa-light fa-circle-exclamation',
                type = 'client',
                event = 'police:client:SendPoliceEmergencyAlert',
                shouldClose = true,
            },
        }
    else
        SetupSubItems()
        FinalMenuItems = deepcopy(Config.MenuItems)
        local function processMenuItems(items)
            for i, item in ipairs(items) do
                if item.icon and not item.icon:find('fa%-') then
                    item.icon = 'fa-light fa-' .. item.icon
                end
                if item.items then
                    processMenuItems(item.items)
                end
                if not item.type then
                    item.type = 'client'
                end
            end
        end
        
        processMenuItems(FinalMenuItems)
        
        for _, v in pairs(DynamicMenuItems) do
            FinalMenuItems[#FinalMenuItems + 1] = v
        end
    end
end

local function controlToggle(bool)
    for i = 1, #controlsToToggle do
        DisableControlAction(0, controlsToToggle[i], bool)
    end
end

local function setRadialState(bool, sendMessage, delay)
    if bool then
        TriggerEvent('qb-radialmenu:client:onRadialmenuOpen')
        SetupRadialMenu()
        PlaySoundFrontend(-1, 'NAV', 'HUD_AMMO_SHOP_SOUNDSET', 1)
    else
        TriggerEvent('qb-radialmenu:client:onRadialmenuClose')
    end
    
    SetNuiFocus(bool, bool)
    if Config.UseWhilstWalking then
        SetNuiFocusKeepInput(bool, true)
    end
    
    if sendMessage then
        SendNUIMessage({
            action = bool and 'ui' or 'close',
            radial = bool,
            items = FinalMenuItems
        })
    end
    
    controlToggle(bool)
    if delay then Wait(500) end
    inRadialMenu = bool
end

local function OpenRadialMenu()
    if showMenu then return end
    showMenu = true

    SetupRadialMenu()
    SendNUIMessage({
        action = 'opening',
        items = FinalMenuItems
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true, false)
    controlToggle(true)
    DisablePlayerFiring(PlayerId(), true)
end

local function CloseRadialMenu()
    if not showMenu then return end
    showMenu = false

    SendNUIMessage({
        action = 'close'
    })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false, false)
    controlToggle(false)
    DisablePlayerFiring(PlayerId(), false)
end

CreateThread(function()
    while true do
        Wait(0)
        if showMenu then
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            DisableControlAction(0, 37, true) -- SelectWeapon
            DisableControlAction(0, 45, true) -- Reload
            DisableControlAction(0, 80, true) -- Move Camera Up/Down
            DisableControlAction(0, 140, true) -- Melee Attack Light
            DisableControlAction(0, 141, true) -- Melee Attack Heavy
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 264, true) -- Melee Attack 2
        else
            Wait(100)
        end
    end
end)

RegisterCommand('radialmenu', function()
    if not IsPauseMenuActive() and not IsNuiFocused() then
        OpenRadialMenu()
    end
end)

RegisterKeyMapping('radialmenu', 'Open Radial Menu', 'keyboard', 'F1')

RegisterNUICallback('closeRadial', function(data, cb)
    CloseRadialMenu()
    cb('ok')
end)

RegisterCommand('+radialmenu', function()
    if not IsPauseMenuActive() and not IsNuiFocused() then
        OpenRadialMenu()
    end
end)

RegisterCommand('-radialmenu', function()
    if showMenu then
        CloseRadialMenu()
    end
end)

RegisterKeyMapping('+radialmenu', 'Open Radial Menu', 'keyboard', 'F1')

RegisterNUICallback('selectItem', function(data, cb)
    if data.event then
        if data.type == 'command' then
            ExecuteCommand(data.event)
        else
            TriggerEvent(data.event)
        end
    end
    cb('ok')
end)

RegisterNetEvent('qb-radialmenu:client:onToggle', function()
    if showMenu then
        CloseRadialMenu()
    else
        OpenRadialMenu()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CloseRadialMenu()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterNetEvent('qb-radialmenu:client:noPlayers', function()
    QBCore.Functions.Notify(Lang:t('error.no_people_nearby'), 'error', 2500)
end)

RegisterNetEvent('qb-radialmenu:client:openDoor', function(data)
    local string = data.id
    local replace = string:gsub('door', '')
    local door = tonumber(replace)
    local ped = PlayerPedId()
    local closestVehicle = GetVehiclePedIsIn(ped) ~= 0 and GetVehiclePedIsIn(ped) or getNearestVeh()
    if closestVehicle ~= 0 then
        if closestVehicle ~= GetVehiclePedIsIn(ped) then
            local plate = QBCore.Functions.GetPlate(closestVehicle)
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', false, plate, door)
                else
                    SetVehicleDoorShut(closestVehicle, door, false)
                end
            else
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', true, plate, door)
                else
                    SetVehicleDoorOpen(closestVehicle, door, false, false)
                end
            end
        else
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                SetVehicleDoorShut(closestVehicle, door, false)
            else
                SetVehicleDoorOpen(closestVehicle, door, false, false)
            end
        end
    else
        QBCore.Functions.Notify(Lang:t('error.no_vehicle_found'), 'error', 2500)
    end
end)

RegisterNetEvent('qb-radialmenu:client:setExtra', function(data)
    local string = data.id
    local replace = string:gsub('extra', '')
    local extra = tonumber(replace)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh ~= nil then
        if GetPedInVehicleSeat(veh, -1) == ped then
            SetVehicleAutoRepairDisabled(veh, true)
            if DoesExtraExist(veh, extra) then
                if IsVehicleExtraTurnedOn(veh, extra) then
                    SetVehicleExtra(veh, extra, 1)
                    QBCore.Functions.Notify(Lang:t('error.extra_deactivated', { extra = extra }), 'error', 2500)
                else
                    SetVehicleExtra(veh, extra, 0)
                    QBCore.Functions.Notify(Lang:t('success.extra_activated', { extra = extra }), 'success', 2500)
                end
            else
                QBCore.Functions.Notify(Lang:t('error.extra_not_present', { extra = extra }), 'error', 2500)
            end
        else
            QBCore.Functions.Notify(Lang:t('error.not_driver'), 'error', 2500)
        end
    end
end)

RegisterNetEvent('qb-radialmenu:trunk:client:Door', function(plate, door, open)
    local veh = GetVehiclePedIsIn(PlayerPedId())
    if veh ~= 0 then
        local pl = QBCore.Functions.GetPlate(veh)
        if pl == plate then
            if open then
                SetVehicleDoorOpen(veh, door, false, false)
            else
                SetVehicleDoorShut(veh, door, false)
            end
        end
    end
end)

RegisterNetEvent('qb-radialmenu:client:ChangeSeat', function(data)
    local Veh = GetVehiclePedIsIn(PlayerPedId())
    local IsSeatFree = IsVehicleSeatFree(Veh, data.id)
    local speed = GetEntitySpeed(Veh)
    local HasHarnass = exports['qb-smallresources']:HasHarness()
    if not HasHarnass then
        local kmh = speed * 3.6
        if IsSeatFree then
            if kmh <= 100.0 then
                SetPedIntoVehicle(PlayerPedId(), Veh, data.id)
                QBCore.Functions.Notify(Lang:t('info.switched_seats', { seat = data.title }))
            else
                QBCore.Functions.Notify(Lang:t('error.vehicle_driving_fast'), 'error')
            end
        else
            QBCore.Functions.Notify(Lang:t('error.seat_occupied'), 'error')
        end
    else
        QBCore.Functions.Notify(Lang:t('error.race_harness_on'), 'error')
    end
end)

RegisterNetEvent('qb-radialmenu:flipVehicle', function()
    QBCore.Functions.Progressbar('pick_grape', Lang:t('progress.flipping_car'), Config.Fliptime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_ped',
        flags = 1,
    }, {}, {}, function() -- Done
        local vehicle = getNearestVeh()
        SetVehicleOnGroundProperly(vehicle)
        StopAnimTask(PlayerPedId(), 'mini@repair', 'fixing_a_ped', 1.0)
    end, function() -- Cancel
        QBCore.Functions.Notify(Lang:t('task.cancel_task'), 'error')
        StopAnimTask(PlayerPedId(), 'mini@repair', 'fixing_a_ped', 1.0)
    end)
end)

AddEventHandler('onClientResourceStop', function(resource)
    for k, v in pairs(DynamicMenuItems) do
        if v.res == resource then
            DynamicMenuItems[k] = nil
        end
    end
end)

exports('AddOption', AddOption)
exports('RemoveOption', RemoveOption)
