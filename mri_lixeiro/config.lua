Config = {}

Config.Debug = false

-- ─── Geração de Rotas ──────────────────────────────────────────────────────────
Config.RouteGenerateInterval = 30   -- Tempo em segundos para gerar uma nova rota
Config.MaxActiveRoutes       = 15   -- Limite máximo de rotas ativas no servidor simultaneamente
Config.TabletItem            = 'tablet_garbage' -- Nome do item usável no inventário
Config.MinimumRouteDistance  = 300.0 -- Distância mínima do jogador à primeira parada para a rota aparecer no tablet

-- ─── Aluguel de Caminhão (Por Tempo) ────────────────────────────────────────────
Config.RentVehicleModel = 'trash' -- Veículo spawnado no aluguel

Config.TruckRentOptions = {
    { id = 'rent_30', label = 'Aluguel Rápido', price = 400, duration = 30, image = 'https://docs.fivem.net/vehicles/trash.webp', desc = 'Aluguel por 30 Minutos' },
    { id = 'rent_60', label = 'Aluguel Padrão', price = 650, duration = 60, image = 'https://docs.fivem.net/vehicles/trash.webp', desc = 'Aluguel por 1 Hora' },
    { id = 'rent_120',label = 'Aluguel Diário', price = 1100, duration = 120, image = 'https://docs.fivem.net/vehicles/trash.webp', desc = 'Aluguel por 2 Horas' },
}

-- ─── Caminhões Disponíveis para Compra ────────────────────────────────────────
Config.TruckBuyOptions = {
    { model = 'trash',  label = 'Caminhão de Lixo Padrão',  price = 4500, image = 'https://docs.fivem.net/vehicles/trash.webp', desc = 'Caminhão compactador clássico' },
    { model = 'trash2', label = 'Caminhão de Lixo Reforçado', price = 9500, image = 'https://docs.fivem.net/vehicles/trash2.webp', desc = 'Maior capacidade de carga' },
}

-- ─── Parâmetros da Rota ────────────────────────────────────────────────────────
Config.TruckCapacity        = 8     -- Quantidade máxima de sacos que o caminhão aguenta por viagem
Config.MaxSafeSpeed         = 90    -- km/h máximo sem risco de derrubar carga
Config.SpillChancePerImpact = 0.35  -- Chance de perder 1 saco de lixo ao bater forte com carga no caminhão
Config.TimeBonusPercent     = 0.15  -- bônus de pagamento de 15% (agilidade na rota)
Config.SearchGarbage        = true  -- Permite vasculhar lixeiras espalhadas pelo mapa em busca de material extra
Config.SearchObjects = {            -- Hashes de props de lixo "soltos" pelo mapa (vasculháveis, fora da rota)
    -1096777189, 666561306, 1437508529, -1426008804,
    -228596739, 651101403, -58485588, 218085040,
}
Config.SearchItemList = { -- Itens que podem ser encontrados ao vasculhar (Config.SearchGarbage) - igual ao itemList original
    { name = 'rubber',     min = 1, max = 2 },
    { name = 'metalscrap', min = 1, max = 2 },
}
Config.PaymentMaterialGain = true -- Se true, dá um pouco de cada item de Config.PaymentMaterialList ao concluir a rota
Config.PaymentMaterialList = { -- igual ao materialList original
    { name = 'rubber',     min = 1, max = 2 },
    { name = 'plastic',    min = 1, max = 2 },
    { name = 'metalscrap', min = 1, max = 2 },
    { name = 'copper',     min = 1, max = 2 },
    { name = 'iron',       min = 1, max = 2 },
    { name = 'steel',      min = 1, max = 2 },
}

-- ─── Níveis e Títulos ─────────────────────────────────────────────────────────
Config.Levels = {
    [1]  = { xp = 0,      label = "Iniciante",          multiplier = 1.00, color = "#9ca3af" },
    [2]  = { xp = 500,    label = "Coletor",            multiplier = 1.10, color = "#60a5fa" },
    [3]  = { xp = 1500,   label = "Coletor Ágil",       multiplier = 1.25, color = "#34d399" },
    [4]  = { xp = 3000,   label = "Lixeiro",            multiplier = 1.40, color = "#a78bfa" },
    [5]  = { xp = 5500,   label = "Lixeiro Noturno",    multiplier = 1.60, color = "#f472b6" },
    [6]  = { xp = 9000,   label = "Lixeiro Sênior",     multiplier = 1.85, color = "#fb923c" },
    [7]  = { xp = 14000,  label = "Operador de Frota",  multiplier = 2.10, color = "#fbbf24" },
    [8]  = { xp = 20000,  label = "Supervisor de Rota", multiplier = 2.40, color = "#f87171" },
    [9]  = { xp = 28000,  label = "Chefe de Equipe",    multiplier = 2.80, color = "#c084fc" },
    [10] = { xp = 38000,  label = "Rei do Lixo",        multiplier = 3.50, color = "#f59e0b" },
}

-- Bônus de multiplicador no pagamento para os Top 3 do Ranking
Config.TopRankingBuffs = {
    [1] = 1.5, -- Top 1: +50% de lucro
    [2] = 1.3, -- Top 2: +30% de lucro
    [3] = 1.1, -- Top 3: +10% de lucro
}

-- ─── Zonas de Coleta ───────────────────────────────────────────────────────────
Config.Zones = {
    geral = {
        label    = "Coleta da Cidade",
        desc     = "Lixo residencial e comercial pela cidade",
        minLevel = 1,
        color    = "#60a5fa",
        icon     = "🗑️",
    },
}

-- ─── Pontos de Lixo (Paradas das Rotas) ────────────────────────────────────────
-- Mesmos 20 pontos de coleta do script original (garbagejobOptions.Location).
Config.Waypoints = {
    [1]  = vector3(114.83, -1462.31, 29.29508),
    [2]  = vector3(-6.04, -1566.23, 29.209197),
    [3]  = vector3(-1.88, -1729.55, 29.300233),
    [4]  = vector3(159.09, -1816.69, 27.91234),
    [5]  = vector3(358.94, -1805.07, 28.96659),
    [6]  = vector3(481.36, -1274.82, 29.64475),
    [7]  = vector3(127.9472, -1057.73, 29.19237),
    [8]  = vector3(-1613.123, -509.06, 34.99874),
    [9]  = vector3(342.78, -1036.47, 29.19420),
    [10] = vector3(383.03, -903.60, 29.15601),
    [11] = vector3(165.44, -1074.68, 28.90792),
    [12] = vector3(50.42, -1047.98, 29.31497),
    [13] = vector3(-1463.92, -623.96, 30.20619),
    [14] = vector3(443.96, -574.33, 28.49450),
    [15] = vector3(-1255.41, -1286.82, 3.58411),
    [16] = vector3(-1229.35, -1221.41, 6.44954),
    [17] = vector3(-31.94, -93.43, 57.24907),
    [18] = vector3(274.31, -164.43, 60.35734),
    [19] = vector3(-364.33, -1864.71, 20.24249),
    [20] = vector3(-1239.42, -1401.13, 3.75217),
}

-- ─── Pontos de Descarte (Terminal do Lixo) ─────────────────────────────────────
-- Mesmos pontos de spawn do caminhão no script original (Garbage_Options.Truck.Spawn).
-- O jogador retorna a um destes pontos para descartar o lixo e finalizar a rota.
Config.DisposalPoints = {
    vector4(-319.49, -1520.59, 27.55, 180.76),
    vector4(-325.97, -1520.99, 27.54, 179.45),
    vector4(-332.25, -1520.61, 27.54, 183.55),
}

-- ─── Tipos de Rotas ────────────────────────────────────────────────────────────
-- stopsPool: lista de índices de Config.Waypoints elegíveis para esta rota (todos os 20 pontos originais).
-- stopsCount: quantas paradas (sorteadas dentro do stopsPool) compõem a rota.
Config.Routes = {
    {
        id          = 1,
        label       = "Rota Curta",
        zone        = "geral",
        stopsPool   = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20},
        stopsCount  = 4,
        distance    = "Curta",
        basePay     = 900,
        baseXP      = 100,
        minLevel    = 1,
    },
    {
        id          = 2,
        label       = "Rota Média",
        zone        = "geral",
        stopsPool   = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20},
        stopsCount  = 7,
        distance    = "Média",
        basePay     = 1600,
        baseXP      = 180,
        minLevel    = 2,
    },
    {
        id          = 3,
        label       = "Rota Longa",
        zone        = "geral",
        stopsPool   = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20},
        stopsCount  = 10,
        distance    = "Longa",
        basePay     = 2400,
        baseXP      = 280,
        minLevel    = 4,
    },
    {
        id          = 4,
        label       = "Rota Completa",
        zone        = "geral",
        stopsPool   = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20},
        stopsCount  = 14,
        distance    = "Muito Longa",
        basePay     = 3500,
        baseXP      = 420,
        minLevel    = 6,
    },
}

-- ─── Pontos de Lixeiro (Despachante / Menu) ────────────────────────────────────
-- Mesmo ponto do "Chefe do Lixo" (Garbage_Options.Boss) do script original.
Config.GarbageStands = {
    {
        id          = 1,
        label       = "Chefe do Lixo",
        coords      = vector4(-319.23, -1545.41, 27.8, 327.55),
        ped         = 's_m_y_garbage',
        blip        = { sprite = 318, color = 43, label = "Trabalho - Lixeiro" },
        -- Vários pontos de spawn (igual ao Garbage_Options.Truck.Spawn original); o sistema
        -- tenta cada um até achar uma vaga livre.
        spawnPoints = {
            { coords = vector3(-319.49, -1520.59, 27.55), heading = 180.76 },
            { coords = vector3(-325.97, -1520.99, 27.54), heading = 179.45 },
            { coords = vector3(-332.25, -1520.61, 27.54), heading = 183.55 },
        },
        spawnRadius = 6.0,
    },
}
