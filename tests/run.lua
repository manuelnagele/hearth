-- luajit tests/run.lua  (from the repo root)
local ns = {}
assert(loadfile("Hearth/Core.lua"))("Hearth", ns)
local Core = ns.Core
local failures = 0
local function check(name, cond)
    if not cond then failures = failures + 1 print("FAIL " .. name) else print("ok   " .. name) end
end

local world, flask, food = Core.scan({
    { id = 22888, name = "Rallying Cry", left = 4000 }, { id = 15366, name = "Songflower", left = 900 },
    { id = 17628, name = "Supreme Power", left = 3000 }, { id = 1, name = "Well Fed", left = 100 },
    { id = 2, name = "Arcane Intellect", left = 1000 },
})
check("world buffs, shortest first", #world == 2 and world[1].id == 15366)
check("flask and food seen", flask and food)
check("nothing missing", #Core.missing(true, true) == 0)
local miss = Core.missing(false, false)
check("missing flask and food", miss[1] == "flask" and miss[2] == "food")
local _, f2, fo2 = Core.scan({ { id = 19709, name = "Increased Stamina" } })
check("food by id", fo2 and not f2)

local low, worst = Core.durability({ { cur = 50, max = 100, link = "a" }, { cur = 10, max = 100, link = "b" },
    { cur = 100, max = 100, link = "c" }, { cur = 70, max = 100, link = "d" }, { cur = 0, max = 0 } })
check("lowest durability", low == 0.1 and worst[1].link == "b" and #worst == 3)
check("no durable items", Core.durability({}) == nil)

local days, change = Core.today(nil, "2026-11-22", 50000)
check("first look today: no change", change == 0 and days["2026-11-22"] == 50000)
days, change = Core.today(days, "2026-11-22", 68000)
check("gold up today", change == 18000)
days, change = Core.today(days, "2026-11-23", 60000)
check("a new day starts over", change == 0 and days["2026-11-22"] == nil)

check("short times", Core.short(4000) == "1h" and Core.short(900) == "15m" and Core.short(42) == "42s")
check("until", Core.until_(2 * 86400 + 4 * 3600 + 5) == "2d 4h" and Core.until_(5 * 3600 + 720) == "5h 12m")
check("levels", Core.level(2, 8, 3) == "bad" and Core.level(6, 8, 3) == "low" and Core.level(20, 8, 3) == "ok")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
