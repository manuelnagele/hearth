-- Hearth core: the everyday numbers, no WoW calls (tests/run.lua under LuaJIT).
local _, ns = ...
ns = ns or {}
local Core = {}
ns.Core = Core

-- World buffs worth a glance (classic spell ids); short names for the tooltip.
Core.WORLD = {
    [22888] = "Onyxia / Nefarian", [16609] = "Warchief's Blessing", [24425] = "Spirit of Zandalar",
    [15366] = "Songflower", [22817] = "Fengus' Ferocity", [22818] = "Mol'dar's Moxie", [22820] = "Slip'kik's Savvy",
    [23768] = "Darkmoon: damage", [23736] = "Darkmoon: agility", [23766] = "Darkmoon: intelligence",
    [23738] = "Darkmoon: spirit", [23737] = "Darkmoon: stamina", [23735] = "Darkmoon: strength",
    [23767] = "Darkmoon: armor", [23769] = "Darkmoon: resistance",
}
-- Flasks and elixirs (either counts) and food buffs; "Well Fed" by name as well.
Core.FLASK = {
    [17628] = true, [17626] = true, [17627] = true, [17629] = true, [17624] = true,             -- flasks
    [17539] = true, [11474] = true, [26276] = true, [21920] = true, [17538] = true, [11405] = true,
    [11334] = true, [17537] = true, [16323] = true, [16329] = true, [11348] = true, [24363] = true,
    [3593] = true, [11371] = true, [17535] = true, [24361] = true, [11390] = true, [11396] = true,
}
Core.FOOD = {
    [19705] = true, [19706] = true, [19708] = true, [19709] = true, [19710] = true, [19711] = true,
    [24799] = true, [18192] = true, [18194] = true, [22730] = true, [25661] = true, [18125] = true,
    [18141] = true, [24870] = true, [18191] = true, [18193] = true,
}

-- auras: { {id, name, icon, left}, ... } -> world buffs sorted by time left, flask?, food?
function Core.scan(auras)
    local world, flask, food = {}, false, false
    for _, a in ipairs(auras) do
        if Core.WORLD[a.id] then world[#world + 1] = a end
        if Core.FLASK[a.id] then flask = true end
        if Core.FOOD[a.id] or a.name == "Well Fed" then food = true end
    end
    table.sort(world, function(x, y) return (x.left or 0) < (y.left or 0) end)
    return world, flask, food
end

-- What's missing for a raid: a list of words ({} when all is there).
function Core.missing(flask, food)
    local out = {}
    if not flask then out[#out + 1] = "flask" end
    if not food then out[#out + 1] = "food" end
    return out
end

-- durability: { {slot, cur, max, link}, ... } -> lowest share (0..1, nil without durable items), worst 3 items
function Core.durability(items)
    local worst = {}
    for _, it in ipairs(items) do
        if it.max and it.max > 0 then worst[#worst + 1] = { link = it.link, share = it.cur / it.max } end
    end
    table.sort(worst, function(a, b) return a.share < b.share end)
    while #worst > 3 do table.remove(worst) end
    return worst[1] and worst[1].share, worst
end

-- Today's gold: the day's start per character (date key "2026-11-22"); returns the new day table and the change.
function Core.today(days, key, money)
    days = days or {}
    if not days[key] then
        for k in pairs(days) do days[k] = nil end           -- keep only today
        days[key] = money
    end
    return days, money - days[key]
end

-- "1:12" for minutes and seconds under an hour, "2h" above
function Core.short(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 3600 then return ("%dh"):format(math.floor(seconds / 3600)) end
    if seconds >= 60 then return ("%dm"):format(math.floor(seconds / 60)) end
    return ("%ds"):format(seconds)
end

-- "2d 4h", "5h 12m", "12m"
function Core.until_(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(m)
end

-- a colour level: "ok", "low", "bad"
function Core.level(value, low, bad)
    if value == nil then return "ok" end
    if value <= bad then return "bad" end
    if value <= low then return "low" end
    return "ok"
end

return Core
