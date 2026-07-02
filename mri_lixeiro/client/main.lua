local isMenuOpen    = false
local dispatchPeds  = {}
local dispatchBlips = {}
local rentBlip      = nil

-- Variáveis globais para o client/garbage.lua acessar
activeJob        = nil
rentedTruck      = nil
rentedTruckPlate = nil
rentTimerLeft    = 0
local rentTimerActive = false

-- ─── Utilitários ──────────────────────────────────────────────────────────────

local function getClosestStand()
    local pcoords = GetEntityCoords(PlayerPedId())
    local closest = nil
    local minDist = 99999.0
    for _, stand in ipairs(Config.GarbageStands) do
        local dist = #(pcoords - vector3(stand.coords.x, stand.coords.y, stand.coords.z))
        if dist < minDist then
            minDist = dist
            closest = stand
        end
    end
    return closest, minDist
end

-- ─── NUI ──────────────────────────────────────────────────────────────────────

function openMenu(isItem)
    if isMenuOpen then return end
    local playerData = lib.callback.await('mri_Qgarbage:getPlayerData', false)
    local routes     = lib.callback.await('mri_Qgarbage:getRoutes', false)
    if not playerData then return end

    if isItem then
        local pcoords = GetEntityCoords(PlayerPedId())
        local filteredRoutes = {}
        local minDistance = Config.MinimumRouteDistance or 300.0

        for _, route in ipairs(routes) do
            local tooClose = false
            local firstStop = route.stops and route.stops[1]
            local wp = firstStop and Config.Waypoints[firstStop]
            if wp then
                local dist = #(pcoords - vector3(wp.x, wp.y, wp.z))
                if dist < minDistance then tooClose = true end
            end
            if not tooClose then
                table.insert(filteredRoutes, route)
            end
        end
        routes = filteredRoutes
    end

    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type        = 'show',
        isItem      = isItem,
        playerData  = playerData,
        calls       = routes,
        genInterval = Config.RouteGenerateInterval or 30,
        zones       = Config.Zones,
        levels      = Config.Levels,
        accentColor = GetConvar('mri:color', '#22c55e'),
        rentOptions    = Config.TruckRentOptions,
        buyOptions     = Config.TruckBuyOptions,
        ownedTaxis     = playerData.owned_trucks,
        hasRentedTruck = rentedTruck ~= nil and DoesEntityExist(rentedTruck),
        activeJob   = activeJob and {
            callId  = activeJob.routeId,
        } or nil,
    })

    CreateThread(function()
        while isMenuOpen do
            Wait(5000)
            if isMenuOpen then
                local currentRoutes = lib.callback.await('mri_Qgarbage:getRoutes', false)

                if isItem then
                    local pcoords = GetEntityCoords(PlayerPedId())
                    local filteredRoutes = {}
                    local minDistance = Config.MinimumRouteDistance or 300.0
                    for _, route in ipairs(currentRoutes) do
                        local tooClose = false
                        local firstStop = route.stops and route.stops[1]
                        local wp = firstStop and Config.Waypoints[firstStop]
                        if wp then
                            local dist = #(pcoords - vector3(wp.x, wp.y, wp.z))
                            if dist < minDistance then tooClose = true end
                        end
                        if not tooClose then
                            table.insert(filteredRoutes, route)
                        end
                    end
                    currentRoutes = filteredRoutes
                end

                SendNUIMessage({
                    type = 'updateCalls',
                    calls = currentRoutes
                })
            end
        end
    end)
end

function closeMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
end

-- ─── HUD Global ────────────────────────────────────────────────────────────────

function updateHUD()
    if not activeJob and not rentTimerActive then
        SendNUIMessage({ type = 'hideHUD' })
        return
    end

    local data = {}
    if activeJob then
        local elapsed = GetGameTimer() / 1000 - activeJob.startTime
        local capacity = Config.TruckCapacity or 8
        data.condition = math.floor((activeJob.collected / capacity) * 100)
        data.elapsed   = elapsed
        data.route     = activeJob.label
        data.timeLeft  = '--:--'
        data.cargo     = string.format('Sacos: %d/%d', activeJob.collected, activeJob.stopsTotal)
    end

    if rentTimerActive then
        local rmins = math.floor(rentTimerLeft / 60)
        local rsecs = math.floor(rentTimerLeft % 60)
        data.rentalTimeLeft = string.format('%02d:%02d', rmins, rsecs)
        if not activeJob then data.cargo = 'Nenhum' end
    end

    SendNUIMessage({
        type      = 'updateHUD',
        condition = data.condition,
        timeLeft  = data.timeLeft,
        rentalTimeLeft = data.rentalTimeLeft,
        cargo     = data.cargo,
    })
end

-- ─── Timer do Aluguel ─────────────────────────────────────────────────────────

local function startRentTimer(minutes)
    if rentTimerActive then return end
    rentTimerLeft = minutes * 60
    rentTimerActive = true

    CreateThread(function()
        while rentTimerActive and rentTimerLeft > 0 do
            Wait(1000)

            if rentedTruck and not DoesEntityExist(rentedTruck) then
                ReturnTruck()
                break
            end

            rentTimerLeft = rentTimerLeft - 1
            if rentTimerLeft <= 0 then
                lib.notify({ title = 'Aluguel Expirado', description = 'Seu tempo de aluguel acabou. O caminhão foi devolvido.', type = 'error' })
                if activeJob then CancelJob() end
                ReturnTruck()
                break
            end
        end
    end)

    CreateThread(function()
        while rentTimerActive do
            if not activeJob then
                SendNUIMessage({
                    type = 'showHUD',
                    route = 'Livre',
                    cargo = 'Nenhum',
                    condition = 100,
                    timeLeft = '--:--',
                    rentalTimeLeft = string.format('%02d:%02d', math.floor(rentTimerLeft/60), math.floor(rentTimerLeft%60))
                })
            end
            Wait(1000)
        end
        if not activeJob then SendNUIMessage({ type = 'hideHUD' }) end
    end)
end

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────

RegisterNUICallback('closeMenu', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    lib.notify({ title = data.title, description = data.description, type = data.type or 'info' })
    cb('ok')
end)

RegisterNUICallback('waypointCentral', function(_, cb)
    local closest, _ = getClosestStand()
    if closest then
        SetNewWaypoint(closest.coords.x, closest.coords.y)
        lib.notify({ title = 'GPS Atualizado', description = 'A garagem de coleta mais próxima foi marcada no seu mapa.', type = 'success' })
    else
        lib.notify({ title = 'Erro', description = 'Nenhuma garagem encontrada.', type = 'error' })
    end
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    if not rentedTruck or not DoesEntityExist(rentedTruck) then
        rentedTruck = nil
        lib.notify({ title = 'Sem Caminhão', description = 'Alugue ou retire seu caminhão antes de aceitar rotas.', type = 'warning' })
        cb('err'); return
    end

    local ok, routeData = lib.callback.await('mri_Qgarbage:acceptRoute', false, data.callId)
    if not ok then
        lib.notify({ title = 'Indisponível', description = 'Alguém já aceitou essa rota ou ela expirou.', type = 'error' })
        openMenu()
        cb('err'); return
    end

    closeMenu()
    Wait(300)
    StartJob(routeData)
    cb('ok')
end)

RegisterNUICallback('cancelJob', function(_, cb)
    closeMenu()
    CancelJob()
    cb('ok')
end)

local function clearRentBlip()
    if rentBlip and DoesBlipExist(rentBlip) then
        SetBlipRoute(rentBlip, false)
        RemoveBlip(rentBlip)
    end
    rentBlip = nil
end

local function SpawnTruckVehicle(model, isRental, durationMins)
    local stand, dist = getClosestStand()
    if dist > 30.0 then
        lib.notify({ title = 'Erro', description = 'Você não está perto do Chefe do Lixo.', type = 'error' })
        return false
    end

    local spawnRadius = stand.spawnRadius or 6.0
    local chosenSpawn = nil

    -- Tenta cada ponto de spawn configurado até achar um livre (mesma ideia do Randomizer original)
    local order = {}
    for i = 1, #stand.spawnPoints do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    for _, idx in ipairs(order) do
        local sp = stand.spawnPoints[idx]
        local nearVeh = GetClosestVehicle(sp.coords.x, sp.coords.y, sp.coords.z, spawnRadius, 0, 70)
        if not DoesEntityExist(nearVeh) then
            chosenSpawn = sp
            break
        end
    end

    if not chosenSpawn then
        lib.notify({ title = 'Vaga ocupada', description = 'Todas as vagas do terminal estão ocupadas no momento.', type = 'warning' })
        return false
    end

    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        lib.notify({ title = 'Erro', description = 'Modelo de caminhão inválido.', type = 'error' })
        return false
    end

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) do
        Wait(100); t = t + 100
        if t > 10000 then return false end
    end

    local truck = CreateVehicle(hash, chosenSpawn.coords.x, chosenSpawn.coords.y, chosenSpawn.coords.z, chosenSpawn.heading, true, false)
    SetVehicleNumberPlateText(truck, ('LIXO%04d'):format(math.random(1, 9999)))
    SetEntityAsMissionEntity(truck, true, true)
    SetModelAsNoLongerNeeded(hash)

    local plate = GetVehicleNumberPlateText(truck)
    SetVehicleDoorsLocked(truck, 1)
    exports['mri_Qcarkeys']:GiveTempKeys(plate)

    rentedTruck      = truck
    rentedTruckPlate = plate

    clearRentBlip()
    rentBlip = AddBlipForEntity(truck)
    SetBlipSprite(rentBlip, 318)
    SetBlipColour(rentBlip, 43)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Seu Caminhão')
    EndTextCommandSetBlipName(rentBlip)

    CreateThread(function()
        while DoesEntityExist(truck) and GetVehiclePedIsIn(PlayerPedId(), false) ~= truck do
            Wait(500)
        end
        clearRentBlip()
    end)

    if isRental and durationMins then
        startRentTimer(durationMins)
    else
        rentTimerActive = false
        rentTimerLeft = 0
    end

    SendNUIMessage({ type = 'updateRentState', hasRentedTruck = true })
    return true, plate
end

RegisterNUICallback('rentTaxi', function(data, cb)
    if rentedTruck and DoesEntityExist(rentedTruck) then
        lib.notify({ title = 'Já em uso', description = 'Devolva seu caminhão atual primeiro.', type = 'warning' })
        cb('err'); return
    end

    local ok, duration = lib.callback.await('mri_Qgarbage:rentTruck', false, data.id)
    if not ok then
        lib.notify({ title = 'Falha', description = duration or 'Não foi possível alugar.', type = 'error' })
        cb('err'); return
    end

    closeMenu()
    Wait(300)

    local success, plate = SpawnTruckVehicle(Config.RentVehicleModel, true, duration)
    if success then
        lib.notify({ title = 'Caminhão Alugado!', description = 'Veículo liberado na vaga. Placa: '..plate, type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('buyTaxi', function(data, cb)
    local ok, msg = lib.callback.await('mri_Qgarbage:buyTruck', false, data.model)
    if not ok then
        lib.notify({ title = 'Falha', description = msg or 'Não foi possível comprar.', type = 'error' })
        cb('err'); return
    end
    lib.notify({ title = 'Sucesso', description = 'Veículo comprado com sucesso!', type = 'success' })

    local playerData = lib.callback.await('mri_Qgarbage:getPlayerData', false)
    if playerData then
        SendNUIMessage({ type = 'updatePlayer', ownedTaxis = playerData.owned_trucks })
    end
    cb('ok')
end)

RegisterNUICallback('useOwnedTaxi', function(data, cb)
    if rentedTruck and DoesEntityExist(rentedTruck) then
        lib.notify({ title = 'Já em uso', description = 'Devolva seu caminhão atual primeiro.', type = 'warning' })
        cb('err'); return
    end

    closeMenu()
    Wait(300)

    local success, plate = SpawnTruckVehicle(data.model, false, nil)
    if success then
        lib.notify({ title = 'Caminhão Retirado!', description = 'Seu caminhão está na vaga.', type = 'success' })
    end
    cb('ok')
end)

function ReturnTruck()
    if not rentedTruck or not DoesEntityExist(rentedTruck) then
        rentedTruck      = nil
        rentedTruckPlate = nil
        rentTimerActive  = false
        clearRentBlip()
        SendNUIMessage({ type = 'updateRentState', hasRentedTruck = false })
        return
    end

    if GetVehiclePedIsIn(PlayerPedId(), false) == rentedTruck then
        lib.notify({ title = 'Atenção', description = 'Saia do caminhão antes de devolvê-lo.', type = 'warning' })
        return false
    end

    if rentedTruckPlate then
        exports['mri_Qcarkeys']:RemoveTempKeys(rentedTruckPlate)
        TriggerServerEvent('mm_carkeys:server:removevehiclekeys', rentedTruckPlate)
    end

    DeleteEntity(rentedTruck)
    rentedTruck      = nil
    rentedTruckPlate = nil
    rentTimerActive  = false
    clearRentBlip()
    SendNUIMessage({ type = 'updateRentState', hasRentedTruck = false })
    return true
end

RegisterNUICallback('returnTaxi', function(_, cb)
    if ReturnTruck() then
        lib.notify({ title = 'Devolvido', description = 'Caminhão devolvido/guardado.', type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('getRanking', function(data, cb)
    local category = data.category or 'xp'
    local ranking = lib.callback.await('mri_Qgarbage:getRanking', false, category)
    cb(ranking)
end)

-- ─── Resultado da rota (vindo do servidor) ─────────────────────────────────────

RegisterNetEvent('mri_Qgarbage:routeResult', function(result)
    local msg = string.format(
        'Pagamento: R$ %s | XP: +%d | Eficiência: %d%%',
        tostring(result.pay), math.floor(result.xp), math.floor(result.condition)
    )
    if result.timeBonus > 0 then
        msg = msg .. string.format(' | Bônus: +R$ %s', tostring(result.timeBonus))
    end

    lib.notify({ title = '✅ Rota Concluída!', description = msg, type = 'success', duration = 8000 })

    if result.leveledUp then
        Wait(1000)
        lib.notify({
            title       = '🎉 Nível Aumentado!',
            description = string.format('Você é agora %s (Nível %d)!', result.newLevelLabel, result.newLevel),
            type        = 'success',
            duration    = 6000,
        })
    end
end)

RegisterNetEvent('mri_Qgarbage:searchResult', function(found, itemName, amount)
    if found then
        lib.notify({ title = 'Lixeira Vasculhada', description = string.format('Você encontrou %dx %s!', amount, itemName), type = 'success' })
    else
        lib.notify({ title = 'Lixeira Vasculhada', description = 'Não havia nada de útil aqui.', type = 'info' })
    end
end)

-- ─── Despachantes ─────────────────────────────────────────────────────────────

local function spawnDispatcher(dispatcher)
    local hash = GetHashKey(dispatcher.ped)

    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then return end
    end

    local c   = dispatcher.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    PlaceObjectOnGroundProperly(ped)
    SetModelAsNoLongerNeeded(hash)
    dispatchPeds[#dispatchPeds + 1] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            label    = dispatcher.label,
            icon     = 'fas fa-truck',
            distance = 3.0,
            onSelect = function() openMenu() end,
        }
    })

    local c2  = dispatcher.coords
    local blip = AddBlipForCoord(c2.x, c2.y, c2.z)
    SetBlipSprite(blip, dispatcher.blip.sprite)
    SetBlipColour(blip, dispatcher.blip.color)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(dispatcher.blip.label)
    EndTextCommandSetBlipName(blip)
    dispatchBlips[#dispatchBlips + 1] = blip
end

CreateThread(function()
    Wait(2000)
    for _, d in ipairs(Config.GarbageStands) do
        spawnDispatcher(d)
        Wait(200)
    end
end)

-- ─── Busca em Lixeiras Soltas pelo Mapa ────────────────────────────────────────

local searched = {}
local searching = false

if Config.SearchGarbage then
    CreateThread(function()
        if exports.ox_target then
            local ox_options = {
                {
                    name = 'SearchGarbageBin',
                    label = 'Vasculhar Lixeira',
                    icon = 'fas fa-trash',
                    canInteract = function(entity)
                        if searching then return false end
                        return not searched[entity]
                    end,
                    onSelect = function(data)
                        local entity = data.entity
                        if searched[entity] then return end
                        searched[entity] = true
                        searching = true

                        local ped = PlayerPedId()
                        FreezeEntityPosition(ped, true)
                        lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
                        TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0, -1.0, -1, 49, 0, 0, 0, 0)
                        Wait(math.random(1500, 3500))
                        FreezeEntityPosition(ped, false)
                        ClearPedTasks(ped)
                        RemoveAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')

                        TriggerServerEvent('mri_Qgarbage:searchGarbage')
                        Wait(1000)
                        searching = false
                    end,
                },
            }
            exports.ox_target:addModel(Config.SearchObjects, ox_options)
        end
    end)
end

-- ─── Limpeza ──────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(dispatchPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in ipairs(dispatchBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    clearRentBlip()
    if rentedTruck and DoesEntityExist(rentedTruck) then
        if rentedTruckPlate then
            exports['mri_Qcarkeys']:RemoveTempKeys(rentedTruckPlate)
            TriggerServerEvent('mm_carkeys:server:removevehiclekeys', rentedTruckPlate)
        end
        DeleteEntity(rentedTruck)
    end
    rentedTruck = nil
    if activeJob then CancelJob() end
    closeMenu()
end)

RegisterNetEvent('mri_Qgarbage:client:useTablet', function()
    openMenu(true)
end)
