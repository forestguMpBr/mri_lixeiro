function GetPlayerLevel(xp)
    local level = 1
    for l = #Config.Levels, 1, -1 do
        if xp >= Config.Levels[l].xp then
            level = l
            break
        end
    end
    return level
end

function GetXPProgress(xp)
    local level = GetPlayerLevel(xp)
    if level >= #Config.Levels then return 100 end
    local cur  = Config.Levels[level].xp
    local next = Config.Levels[level + 1].xp
    return math.floor(((xp - cur) / (next - cur)) * 100)
end

function GetXPToNextLevel(xp)
    local level = GetPlayerLevel(xp)
    if level >= #Config.Levels then return 0 end
    return Config.Levels[level + 1].xp - xp
end

function GetAvailableRoutes(playerLevel)
    local routes = {}
    for _, route in ipairs(Config.Routes) do
        if playerLevel >= route.minLevel then
            routes[#routes + 1] = route
        end
    end
    return routes
end


function FormatMoney(amount)
    return string.format("R$ %s", tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end
