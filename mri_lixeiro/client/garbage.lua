local garbageBag      = nil
local jobMonitorRunning = false
local routeBlip       = nil

-- ─── Utilitários ──────────────────────────────────────────────────────────────

local function removeRouteBlip()
    if routeBlip and DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
    routeBlip = nil
end

local function addRouteBlip(coords, label, sprite, color)
    removeRouteBlip()
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(routeBlip, sprite)
    SetBlipColour(routeBlip, color)
    SetBlipScale(routeBlip, 1.0)
    SetBlipAsShortRange(routeBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(routeBlip)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, color)
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

-- ─── Animações de Coleta (baseadas no script original do lixeiro) ─────────────

local function GetGarbageBag()
    local ped = PlayerPedId()
    local bag = GetHashKey('prop_cs_rub_binbag_01')
    FreezeEntityPosition(ped, true)
    loadAnim('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    loadAnim('missfbi4prepp1')
    TaskPlayAnim(ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0, -1.0, -1, 49, 0, 0, 0, 0)
    Wait(math.random(1500, 3500))
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    RemoveAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')

    garbageBag = CreateObject(bag, 0, 0, 0, true, true, true)
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
    AttachEntityToEntity(garbageBag, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)

    CreateThread(function()
        while garbageBag do
            local p = PlayerPedId()
            if IsEntityPlayingAnim(p, 'missfbi4prepp1', '_bag_throw_garbage_man', 3) then
            elseif not IsEntityPlayingAnim(p, 'missfbi4prepp1', '_bag_walk_garbage_man', 3) then
                ClearPedTasks(p)
                TaskPlayAnim(p, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
            end
            Wait(0)
        end
        RemoveAnimDict('missfbi4prepp1')
    end)
end

local function PutGarbageBag(truck)
    local ped = PlayerPedId()
    loadAnim('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    if truck and DoesEntityExist(truck) then
        SetEntityHeading(ped, GetEntityHeading(truck))
    end
    Wait(1250)
    if garbageBag then
        DetachEntity(garbageBag, 1, false)
        DeleteObject(garbageBag)
    end
    TaskPlayAnim(ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
    garbageBag = nil
    FreezeEntityPosition(ped, false)
    RemoveAnimDict('missfbi4prepp1')
end

local function dropGarbageBagOnGround()
    -- Usado quando um saco cai do caminhão por causa de uma batida forte
    local truck = rentedTruck
    if not truck or not DoesEntityExist(truck) then return end
    local coords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -3.0, 0.0)
    local hash = GetHashKey('prop_cs_rub_binbag_01')
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 2000 do Wait(50); t = t + 50 end
    if HasModelLoaded(hash) then
        local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
        PlaceObjectOnGroundProperly(obj)
        SetModelAsNoLongerNeeded(hash)
        SetEntityAsNoLongerNeeded(obj)
        CreateThread(function()
            Wait(60000)
            if DoesEntityExist(obj) then DeleteObject(obj) end
        end)
    end
end

-- ─── Monitor da Rota ────────────────────────────────────────────────────────────

local function startJobMonitor()
    if jobMonitorRunning then return end
    jobMonitorRunning = true

    CreateThread(function()
        local lastHealth = nil

        while activeJob do
            local ped   = PlayerPedId()
            local truck = rentedTruck
            local pcoords = GetEntityCoords(ped)

            -- ── Risco de derrubar carga em colisões fortes ──
            if truck and DoesEntityExist(truck) then
                if not lastHealth then lastHealth = GetVehicleBodyHealth(truck) end
                local health = GetVehicleBodyHealth(truck)
                if health < lastHealth and activeJob.collected > 0 then
                    local diff = lastHealth - health
                    if diff > 15 then
                        if math.random() < (Config.SpillChancePerImpact or 0.35) then
                            activeJob.collected = math.max(0, activeJob.collected - 1)
                            dropGarbageBagOnGround()
                            lib.notify({ title = 'Carga Instável!', description = 'Um saco de lixo caiu do caminhão por causa do impacto!', type = 'error' })
                        end
                    end
                end
                lastHealth = health
            else
                lastHealth = nil
            end

            -- ── Lógica das paradas ──
            if activeJob.currentStopIndex <= activeJob.stopsTotal then
                local stop = activeJob.stops[activeJob.currentStopIndex]
                local dist = #(pcoords - vector3(stop.x, stop.y, stop.z))

                if dist <= 60 and activeJob.lastBlipStop ~= activeJob.currentStopIndex then
                    addRouteBlip(stop, string.format('Parada %d/%d', activeJob.currentStopIndex, activeJob.stopsTotal), 318, 43)
                    activeJob.lastBlipStop = activeJob.currentStopIndex
                end

                if dist <= 60 and activeJob.lastBlipStop ~= activeJob.currentStopIndex then
                    addRouteBlip(stop, string.format('Parada %d/%d', activeJob.currentStopIndex, activeJob.stopsTotal), 318, 43)
                    activeJob.lastBlipStop = activeJob.currentStopIndex
                end

                -- Pegar lixo na parada (só quando NÃO está carregando saco)
                if not garbageBag and dist <= 5 then
                    local inVehicle = IsPedInAnyVehicle(ped, false)
                    if not inVehicle then
                        DrawText3DSmall(stop.x, stop.y, stop.z, '[E] Pegar Lixo')
                        if IsControlJustReleased(0, 38) then
                            GetGarbageBag()
                        end
                    end
                end
            else
                -- ── Todas as paradas concluídas: ir descartar ──
                if activeJob.lastBlipStop ~= 'disposal' then
                    addRouteBlip(activeJob.disposal, 'Descartar Lixo (Terminal)', 605, 1)
                    activeJob.lastBlipStop = 'disposal'
                    lib.notify({ title = '✅ Coleta Concluída!', description = 'Volte ao terminal para descartar o lixo e receber o pagamento.', type = 'success', duration = 8000 })
                end

                local dp = activeJob.disposal
                DrawMarker(1, dp.x, dp.y, dp.z, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.0, 43, 180, 43, 120, false, true, 2, false, nil, nil, false)

                local dDist = #(pcoords - vector3(dp.x, dp.y, dp.z))
                if dDist <= 25 then
                    DrawText3DSmall(dp.x, dp.y, dp.z, '[E] Descartar Lixo e Receber Pagamento')
                    if IsControlJustReleased(0, 38) then
                        CompleteJob()
                    end
                end
            end

            -- ── Colocar saco no caminhão (em qualquer parada, basta estar perto da traseira) ──
            if garbageBag and truck and DoesEntityExist(truck) then
                local truckBack = GetOffsetFromEntityInWorldCoords(truck, 0.0, -4.5, 0.0)
                local vDist = #(pcoords - truckBack)
                if vDist <= 4.0 then
                    DrawText3DSmall(truckBack.x, truckBack.y, truckBack.z, '[E] Colocar no Caminhão')
                    if IsControlJustReleased(0, 38) then
                        PutGarbageBag(truck)
                        activeJob.collected = activeJob.collected + 1
                        activeJob.currentStopIndex = activeJob.currentStopIndex + 1
                        lib.notify({ title = 'Lixo Coletado', description = string.format('Saco %d/%d guardado no caminhão.', activeJob.collected, activeJob.stopsTotal), type = 'success' })

                        -- Atualiza blip imediatamente para a próxima parada (ou descarte)
                        if activeJob.currentStopIndex <= activeJob.stopsTotal then
                            local nextStop = activeJob.stops[activeJob.currentStopIndex]
                            addRouteBlip(nextStop, string.format('Parada %d/%d', activeJob.currentStopIndex, activeJob.stopsTotal), 318, 43)
                            activeJob.lastBlipStop = activeJob.currentStopIndex
                        else
                            addRouteBlip(activeJob.disposal, 'Descartar Lixo (Aterro)', 605, 1)
                            activeJob.lastBlipStop = 'disposal'
                        end
                    end
                end
            end

            updateHUD()
            Wait(0)
        end
        jobMonitorRunning = false
    end)
end

function DrawText3DSmall(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z + 1.0)
    local pCoords = GetGameplayCamCoords()
    local dist = #(pCoords - vector3(x, y, z))
    local scale = (1 / dist) * 2.0
    local fov = (1 / GetGameplayCamFov()) * 100.0
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.35 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(sx, sy)
    end
end

-- ─── Funções Principais ─────────────────────────────────────────────────────────

function StartJob(route)
    if activeJob then
        lib.notify({ title = 'Atenção', description = 'Você já tem uma rota ativa.', type = 'warning' })
        return
    end
    if not route or not route.stops or #route.stops == 0 then return end

    local stopCoords = {}
    for _, idx in ipairs(route.stops) do
        local wp = Config.Waypoints[idx]
        if wp then table.insert(stopCoords, wp) end
    end
    if #stopCoords == 0 then return end

    local disposal = Config.DisposalPoints[math.random(#Config.DisposalPoints)]

    activeJob = {
        routeId          = route.id,
        templateId       = route.templateId,
        label            = route.label,
        stops            = stopCoords,
        stopsTotal       = #stopCoords,
        currentStopIndex = 1,
        collected        = 0,
        disposal         = disposal,
        startTime        = GetGameTimer() / 1000,
        lastBlipStop     = nil,
    }

    addRouteBlip(stopCoords[1], 'Parada 1/' .. #stopCoords, 318, 43)

    SendNUIMessage({
        type      = 'showHUD',
        route     = route.label,
        cargo     = string.format('Sacos: 0/%d', #stopCoords),
        condition = 0,
        timeLeft  = '--:--',
    })

    lib.notify({
        title       = 'Rota Aceita',
        description = 'Siga até a primeira parada indicada no GPS para começar a coleta.',
        type        = 'info',
        duration    = 6000,
    })

    startJobMonitor()
end

function CompleteJob()
    if not activeJob then return end

    local elapsed = GetGameTimer() / 1000 - activeJob.startTime
    local job     = activeJob
    activeJob     = nil

    removeRouteBlip()
    SendNUIMessage({ type = 'hideHUD' })

    if garbageBag then
        DetachEntity(garbageBag, 1, false)
        DeleteObject(garbageBag)
        garbageBag = nil
    end

    TriggerServerEvent('mri_Qgarbage:completeRoute', {
        templateId     = job.templateId,
        stopsCollected = job.collected,
        stopsTotal     = job.stopsTotal,
        elapsed        = elapsed,
    })
end

function CancelJob()
    if not activeJob then return end
    activeJob = nil

    removeRouteBlip()
    SendNUIMessage({ type = 'hideHUD' })

    if garbageBag then
        ClearPedTasks(PlayerPedId())
        DetachEntity(garbageBag, 1, false)
        DeleteObject(garbageBag)
        garbageBag = nil
    end

    lib.notify({ title = 'Rota cancelada', description = 'Você abandonou a coleta.', type = 'error' })
end
