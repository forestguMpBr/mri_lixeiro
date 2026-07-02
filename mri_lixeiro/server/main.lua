local function dbGetPlayer(citizenid)
    return MySQL.single.await('SELECT * FROM mri_qgarbage_players WHERE citizenid = ?', { citizenid })
end

local function dbCreatePlayer(citizenid)
    MySQL.insert.await('INSERT INTO mri_qgarbage_players (citizenid) VALUES (?)', { citizenid })
    return { citizenid = citizenid, xp = 0, level = 1, total_routes = 0, total_earned = 0, history = '[]', owned_trucks = '[]' }
end

local function loadPlayer(citizenid)
    local data = dbGetPlayer(citizenid)
    if not data then data = dbCreatePlayer(citizenid) end
    data.history      = json.decode(data.history or '[]')
    data.owned_trucks = json.decode(data.owned_trucks or '[]')
    return data
end

local function savePlayer(data)
    MySQL.update.await(
        'UPDATE mri_qgarbage_players SET xp=?, level=?, total_routes=?, total_earned=?, history=?, owned_trucks=? WHERE citizenid=?',
        { data.xp, data.level, data.total_routes, data.total_earned, json.encode(data.history), json.encode(data.owned_trucks), data.citizenid }
    )
end

lib.callback.register('mri_Qgarbage:getPlayerData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local data  = loadPlayer(player.PlayerData.citizenid)
    local level = GetPlayerLevel(data.xp)
    data.level  = level
    data.xpProgress    = GetXPProgress(data.xp)
    data.xpToNextLevel = GetXPToNextLevel(data.xp)
    data.levelData     = Config.Levels[level]

    local rank = MySQL.scalar.await('SELECT COUNT(*) FROM mri_qgarbage_players WHERE xp > ?', { data.xp }) + 1
    data.rank = rank
    data.rankBuff = Config.TopRankingBuffs and Config.TopRankingBuffs[rank] or nil

    return data
end)

-- ─── Geração de Rotas ──────────────────────────────────────────────────────────

local ActiveRoutes = {}

local function pickRandomStops(pool, count)
    local copy = {}
    for i = 1, #pool do copy[i] = pool[i] end

    -- Embaralha (Fisher-Yates)
    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end

    local stops = {}
    for i = 1, math.min(count, #copy) do
        stops[i] = copy[i]
    end
    return stops
end

local function GenerateRoute()
    local routeTemplate = Config.Routes[math.random(#Config.Routes)]
    local id = tostring(math.random(100000, 999999))

    ActiveRoutes[id] = {
        id         = id,
        templateId = routeTemplate.id,
        label      = routeTemplate.label,
        zone       = routeTemplate.zone,
        distance   = routeTemplate.distance,
        basePay    = routeTemplate.basePay,
        baseXP     = routeTemplate.baseXP,
        minLevel   = routeTemplate.minLevel,
        stops      = pickRandomStops(routeTemplate.stopsPool, routeTemplate.stopsCount or 3),
    }
end

CreateThread(function()
    local maxRoutes = Config.MaxActiveRoutes or 15
    for i = 1, maxRoutes do
        GenerateRoute()
    end

    while true do
        Wait((Config.RouteGenerateInterval or 30) * 1000)

        local count = 0
        local keys = {}
        for k, _ in pairs(ActiveRoutes) do
            count = count + 1
            table.insert(keys, k)
        end

        if count >= maxRoutes then
            local keyToRemove = keys[math.random(#keys)]
            ActiveRoutes[keyToRemove] = nil
        end

        GenerateRoute()
    end
end)

lib.callback.register('mri_Qgarbage:getRoutes', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local data  = loadPlayer(player.PlayerData.citizenid)
    local xp    = data and data.xp or 0
    local level = GetPlayerLevel(xp)

    local available = {}
    for _, route in pairs(ActiveRoutes) do
        if level >= route.minLevel then
            table.insert(available, route)
        end
    end
    return available
end)

lib.callback.register('mri_Qgarbage:acceptRoute', function(source, routeId)
    if ActiveRoutes[routeId] then
        local route = ActiveRoutes[routeId]
        ActiveRoutes[routeId] = nil
        return true, route
    end
    return false, nil
end)

-- ─── Aluguel / Compra de Caminhão ──────────────────────────────────────────────

lib.callback.register('mri_Qgarbage:rentTruck', function(source, id)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Jogador não encontrado' end

    local option = nil
    for _, opt in ipairs(Config.TruckRentOptions) do
        if opt.id == id then option = opt break end
    end
    if not option then return false, 'Opção inválida' end

    local price = option.price
    local cash  = player.PlayerData.money['cash']
    local bank  = player.PlayerData.money['bank']

    if cash >= price then
        player.Functions.RemoveMoney('cash', price, 'mri_qgarbage-rent')
        return true, option.duration
    elseif bank >= price then
        player.Functions.RemoveMoney('bank', price, 'mri_qgarbage-rent')
        return true, option.duration
    end

    return false, 'Dinheiro insuficiente'
end)

lib.callback.register('mri_Qgarbage:buyTruck', function(source, model)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Jogador não encontrado' end

    local option = nil
    for _, opt in ipairs(Config.TruckBuyOptions) do
        if opt.model == model then option = opt break end
    end
    if not option then return false, 'Opção inválida' end

    local price = option.price
    local cash  = player.PlayerData.money['cash']
    local bank  = player.PlayerData.money['bank']

    local data = loadPlayer(player.PlayerData.citizenid)
    for _, v in ipairs(data.owned_trucks) do
        if v == model then return false, 'Você já possui este veículo' end
    end

    if cash >= price then
        player.Functions.RemoveMoney('cash', price, 'mri_qgarbage-buy')
    elseif bank >= price then
        player.Functions.RemoveMoney('bank', price, 'mri_qgarbage-buy')
    else
        return false, 'Dinheiro insuficiente'
    end

    table.insert(data.owned_trucks, model)
    savePlayer(data)
    return true
end)

-- ─── Ranking ────────────────────────────────────────────────────────────────────

lib.callback.register('mri_Qgarbage:getRanking', function(source, category)
    local orderCol = 'xp'
    if category == 'level' then orderCol = 'level'
    elseif category == 'routes' then orderCol = 'total_routes'
    end

    local query = string.format('SELECT citizenid, xp, level, total_routes FROM mri_qgarbage_players ORDER BY %s DESC LIMIT 50', orderCol)
    local playersData = MySQL.query.await(query)

    local ranking = {}
    if not playersData then return ranking end

    for _, v in ipairs(playersData) do
        local name = 'Desconhecido'
        local pData = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { v.citizenid })

        if pData and pData.charinfo then
            local charinfo = pData.charinfo
            if type(charinfo) == 'string' then
                local success, result = pcall(json.decode, charinfo)
                if success then charinfo = result else charinfo = nil end
            end

            if type(charinfo) == 'table' and charinfo.firstname and charinfo.lastname then
                name = charinfo.firstname .. ' ' .. charinfo.lastname
            end
        end
        table.insert(ranking, {
            citizenid    = v.citizenid,
            name         = name,
            xp           = v.xp,
            level        = v.level,
            total_routes = v.total_routes,
        })
    end
    return ranking
end)

-- ─── Conclusão da Rota ──────────────────────────────────────────────────────────

RegisterNetEvent('mri_Qgarbage:completeRoute', function(payload)
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local templateId      = payload.templateId
    local stopsCollected  = tonumber(payload.stopsCollected) or 0
    local stopsTotal      = tonumber(payload.stopsTotal) or 1
    local elapsed         = payload.elapsed or 0

    local route = nil
    for _, r in ipairs(Config.Routes) do
        if r.id == templateId then route = r break end
    end
    if not route then return end

    local efficiency = math.floor(math.max(0, math.min(100, (stopsCollected / stopsTotal) * 100)))

    local data  = loadPlayer(player.PlayerData.citizenid)
    local level = GetPlayerLevel(data.xp)
    local mult  = Config.Levels[level].multiplier

    local basePay = math.floor(route.basePay * mult)
    basePay = math.floor(basePay * (efficiency / 100))

    local timeBonus = 0
    local expectedTime = stopsTotal * 90 -- referência: ~1m30 por parada
    if elapsed <= expectedTime then
        timeBonus = math.floor(basePay * Config.TimeBonusPercent)
    end

    local rank = MySQL.scalar.await('SELECT COUNT(*) FROM mri_qgarbage_players WHERE xp > ?', { data.xp }) + 1
    local rankBuff = Config.TopRankingBuffs and Config.TopRankingBuffs[rank] or 1.0

    local totalPay = math.floor((basePay + timeBonus) * rankBuff)

    local xpGained = math.floor(route.baseXP * (efficiency / 100))
    if elapsed <= expectedTime then
        xpGained = math.floor(xpGained * 1.25)
    end
    if efficiency >= 100 then
        xpGained = math.floor(xpGained * 1.10)
    end

    local oldLevel = level
    data.xp           = data.xp + xpGained
    data.total_routes = data.total_routes + 1
    data.total_earned = data.total_earned + totalPay
    data.level        = GetPlayerLevel(data.xp)

    local entry = {
        call      = route.label,
        pay       = totalPay,
        xp        = xpGained,
        condition = efficiency,
        bonus     = timeBonus,
        date      = os.date('%d/%m %H:%M'),
    }
    table.insert(data.history, 1, entry)
    if #data.history > 20 then table.remove(data.history) end

    savePlayer(data)
    player.Functions.AddMoney('cash', totalPay, 'garbage-route')

    TriggerClientEvent('mri_Qgarbage:routeResult', src, {
        pay           = totalPay,
        timeBonus     = timeBonus,
        xp            = xpGained,
        condition     = efficiency,
        leveledUp     = data.level > oldLevel,
        newLevel      = data.level,
        newLevelLabel = Config.Levels[data.level] and Config.Levels[data.level].label or '',
        totalXP       = data.xp,
    })
end)

-- ─── Busca em Lixeiras Soltas (Bônus de Material) ──────────────────────────────

RegisterNetEvent('mri_Qgarbage:searchGarbage', function()
    local src    = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not Config.SearchGarbage then return end

    local roll = math.random(1, 3) -- 33% de achar item
    if roll == 1 then
        local item = Config.SearchItemList[math.random(#Config.SearchItemList)]
        local amount = math.random(item.min, item.max)
        local added = exports.ox_inventory and exports.ox_inventory:CanCarryItem(src, item.name, amount)
        if added == nil or added then
            player.Functions.AddItem(item.name, amount)
        end
        TriggerClientEvent('mri_Qgarbage:searchResult', src, true, item.name, amount)
    else
        TriggerClientEvent('mri_Qgarbage:searchResult', src, false)
    end
end)

-- ─── Inicialização ──────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mri_qgarbage_players` (
            `citizenid`         VARCHAR(50) NOT NULL,
            `xp`                INT NOT NULL DEFAULT 0,
            `level`             INT NOT NULL DEFAULT 1,
            `total_routes`      INT NOT NULL DEFAULT 0,
            `total_earned`      BIGINT NOT NULL DEFAULT 0,
            `owned_trucks`      LONGTEXT DEFAULT '[]',
            `history`           LONGTEXT,
            `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

if Config.TabletItem then
    exports.qbx_core:CreateUseableItem(Config.TabletItem, function(source, item)
        TriggerClientEvent('mri_Qgarbage:client:useTablet', source)
    end)
end
