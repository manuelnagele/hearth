-- Hearth: everyday items on Deadbeat's bar. Gold and today's change, bags, durability, the raid you're in, flask and
-- food; on the shelf world buffs, mail, latency and time in a dungeon. Each where it fits (Deadbeat's contexts),
-- details in its tooltip. A Deadbeat module (spec 2.0).
local ADDON, ns = ...
local Core = ns.Core
local VERSION = "1.0.0"

local db, char
local m, K, P
local entered = {}                   -- instance name -> when you came in (this session)

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- --- reading the game -------------------------------------------------------------------------

local function auras()
    local list, now = {}, GetTime()
    for i = 1, 40 do
        local name, icon, id, expires
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            name, icon, id, expires = a.name, a.icon, a.spellId, a.expirationTime
        elseif UnitBuff then
            local n, ic, _, _, _, exp, _, _, _, sid = UnitBuff("player", i)
            if not n then break end
            name, icon, id, expires = n, ic, sid, exp
        else
            break
        end
        if not (secret(id) or secret(name) or secret(expires)) then
            list[#list + 1] = { id = id, name = name, icon = icon, left = (expires and expires > 0) and (expires - now) or nil }
        end
    end
    return list
end

local function freeSlots()
    local C = C_Container
    local free, total = 0, 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n = C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag) or 0
        local f, kind = 0, 0
        if C and C.GetContainerNumFreeSlots then f, kind = C.GetContainerNumFreeSlots(bag) end
        if (kind or 0) == 0 then free, total = free + (f or 0), total + n end   -- normal bags only
    end
    return free, total
end

local function gear()
    local items = {}
    if not GetInventoryItemDurability then return items end
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and not secret(cur) then
            items[#items + 1] = { slot = slot, cur = cur, max = max, link = GetInventoryItemLink("player", slot) }
        end
    end
    return items
end

local function instance()
    local name, kind = GetInstanceInfo()
    if kind ~= "raid" and kind ~= "party" then return nil end
    return name, kind
end

-- this lockout's progress for the raid you're in: killed, total (from the saved instances)
local function progress(name)
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    for i = 1, GetNumSavedInstances() do
        local n, _, _, _, locked, _, _, _, _, _, total, killed = GetSavedInstanceInfo(i)
        if n == name and locked then return killed, total end
    end
end

-- --- the items (spec 2.0): at most three showing in any place ---------------------------------------------
--   world / city: gold, bags, durability (world) · raid: raid, consumables, bags · dungeon: bags, durability
--   on the shelf: world buffs, mail, latency, time in a dungeon

local items = {}
local ALL = { farm = true, raid = true, dungeon = true, city = true, world = true }
local LEVEL = { ok = "normal", low = "warn", bad = "bad" }

local function buildItems()
    local I = "Interface\\Icons\\"
    items.gold = m:Item("gold", { name = "Gold", icon = I .. "INV_Misc_Coin_01", contexts = { city = true, world = true } })
    items.bags = m:Item("bags", { name = "Bags", icon = I .. "INV_Misc_Bag_08", contexts = ALL })
    items.durability = m:Item("durability", { name = "Durability", icon = I .. "Trade_BlackSmithing",
        contexts = { dungeon = true, world = true, farm = true } })
    items.raid = m:Item("raid", { name = "Raid", icon = I .. "INV_Misc_Head_Dragon_01", contexts = { raid = true } })
    items.consumables = m:Item("consumables", { name = "Flask and food", icon = I .. "INV_Potion_41",
        contexts = { raid = true } })
    items.dungeon = m:Item("dungeon", { name = "Time inside", icon = I .. "INV_Misc_PocketWatch_02",
        default = false, contexts = { dungeon = true } })
    items.mail = m:Item("mail", { name = "Mail", icon = I .. "INV_Letter_15", default = false,
        contexts = { city = true, world = true } })
    -- world buffs: a widget of up to five small icons with minutes left
    local canvas, item = m:Widget("buffs", { name = "World buffs", width = 20, default = false,
        contexts = { raid = true, city = true, world = true } })
    items.buffs, items.buffsCanvas = item, canvas
    canvas.slots = {}
    for i = 1, 5 do
        local sl = CreateFrame("Frame", nil, canvas)
        sl:SetSize(36, 14)
        sl.icon = sl:CreateTexture(nil, "ARTWORK")
        sl.icon:SetSize(13, 13)
        sl.icon:SetPoint("LEFT")
        sl.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        sl.text = sl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sl.text:SetPoint("LEFT", 15, 0)
        canvas.slots[i] = sl
    end
    -- latency: a widget with one dot
    local lc, li = m:Widget("latency", { name = "Latency", width = 8, default = false, contexts = ALL })
    items.latency = li
    lc.pip = lc:CreateTexture(nil, "ARTWORK")
    lc.pip:SetSize(6, 6)
    lc.pip:SetTexture("Interface\\Buttons\\WHITE8x8")
    lc.pip:SetPoint("LEFT", 1, 0)
    items.latencyCanvas = lc
end

-- --- drawing ---------------------------------------------------------------------------------------

local state = {}

local function draw()
    if not m then return end
    -- latency
    local _, _, home, world = GetNetStats()
    local lat = math.max(home or 0, world or 0)
    items.latencyCanvas.pip:SetVertexColor(unpack(lat < 120 and K.GREEN or (lat < 300 and P.goldOn or K.RED)))
    state.latency, state.home, state.world = lat, home, world
    -- mail
    if HasNewMail and HasNewMail() then items.mail:Set("new") items.mail:Show() else items.mail:Hide() end
    -- bags
    local free, total = freeSlots()
    state.free, state.total = free, total
    items.bags:Set(tostring(free), LEVEL[Core.level(free, 8, 3)])
    -- durability
    local low, worst = Core.durability(gear())
    state.worst = worst
    if low then
        items.durability:Set(("%d%%"):format(low * 100 + 0.5), LEVEL[Core.level(low * 100, 50, 25)])
        items.durability:Show()
    else
        items.durability:Hide()
    end
    -- world buffs + consumables
    local wb, flask, food = Core.scan(auras())
    state.wb, state.flask, state.food = wb, flask, food
    local canvas = items.buffsCanvas
    local x = 0
    for i, sl in ipairs(canvas.slots) do
        local a = wb[i]
        if a then
            sl.icon:SetTexture(a.icon)
            sl.text:SetText(a.left and Core.short(a.left) or "")
            sl.text:SetTextColor(unpack((a.left or 9999) < 600 and P.goldOn or P.warmGrey))
            sl:SetWidth(15 + (sl.text:GetStringWidth() or 18))
            sl:ClearAllPoints()
            sl:SetPoint("LEFT", canvas, "LEFT", x, 0)
            x = x + sl:GetWidth() + 6
            sl:Show()
        else
            sl:Hide()
        end
    end
    canvas:SetWidth(math.max(1, x - 6))
    canvas:SetShown(#wb > 0)
    local miss = Core.missing(flask, food)
    if #miss > 0 then items.consumables:Set("no " .. table.concat(miss, " · "), "bad")
    else items.consumables:Set("ready", "good") end
    -- the instance you're in
    local name, kind = instance()
    if name then entered[name] = entered[name] or time() end
    for k in pairs(entered) do if k ~= name then entered[k] = nil end end
    if kind == "raid" then
        local killed, all = progress(name)
        items.raid:Set((killed and all) and ("%d/%d · %s"):format(killed, all, K.clock(time() - entered[name]))
            or K.clock(time() - entered[name]))
        items.raid:Show()
    else
        items.raid:Hide()
    end
    if kind == "party" then items.dungeon:Set(K.clock(time() - entered[name])) items.dungeon:Show()
    else items.dungeon:Hide() end
    -- gold and today's change
    local money = GetMoney()
    local change
    char.days, change = Core.today(char.days, date("%Y-%m-%d"), money)
    state.change, state.start = change, money - change
    items.gold:Set(K.coins(money, 11, true), change > 0 and "good" or "normal")
    Deadbeat.Refresh()
end

-- --- tooltips: one per item --------------------------------------------------------------------------------

local function line(tip, left, right)
    local g = P.warmGrey
    tip:AddDoubleLine("  " .. left, right, g[1], g[2], g[3], 1, 1, 1)
end

local TIPS = {}

function TIPS.gold(tip)
    if not state.start then return end
    line(tip, "Start of today", K.coins(state.start, 11, true))
    line(tip, "Now", K.coins(GetMoney(), 11, true))
    local sign = state.change >= 0 and ("|cff" .. K.hex(K.GREEN) .. "+") or ("|cff" .. K.hex(K.RED) .. "−")
    line(tip, "Today", sign .. "|r" .. K.coins(math.abs(state.change), 11, true))
end

function TIPS.bags(tip) line(tip, "Free", ("%d of %d"):format(state.free or 0, state.total or 0)) end

function TIPS.durability(tip)
    for _, it in ipairs(state.worst or {}) do line(tip, it.link or "?", ("%d%%"):format(it.share * 100 + 0.5)) end
end

function TIPS.raid(tip)
    if not (GetNumSavedInstances and GetNumSavedInstances() > 0) then return end
    for i = 1, GetNumSavedInstances() do
        local n, _, reset, _, locked, _, _, isRaid, _, _, total, killed = GetSavedInstanceInfo(i)
        if locked and isRaid then line(tip, ("%s %d/%d"):format(n, killed or 0, total or 0), "resets in " .. Core.until_(reset)) end
    end
end

function TIPS.consumables(tip)
    line(tip, "Flask or elixir", state.flask and "yes" or ("|cff" .. K.hex(K.RED) .. "missing|r"))
    line(tip, "Food buff", state.food and "yes" or ("|cff" .. K.hex(K.RED) .. "missing|r"))
end

function TIPS.buffs(tip)
    for _, a in ipairs(state.wb or {}) do line(tip, Core.WORLD[a.id] or a.name, a.left and K.clock(a.left) or "") end
end

function TIPS.mail(tip)
    if GetLatestThreeSenders then
        local a, b, c = GetLatestThreeSenders()
        local who = table.concat({ a, b, c }, ", ")
        if who ~= "" then line(tip, "From", who) end
    end
end

function TIPS.latency(tip, shift)
    line(tip, "Home · world", ("%d · %d ms"):format(state.home or 0, state.world or 0))
    line(tip, "Frame rate", ("%d fps"):format(GetFramerate and GetFramerate() or 0))
end

TIPS.dungeon = function(tip) line(tip, "Time inside", items.dungeon.value) end

-- --- events ----------------------------------------------------------------------------------------------

local f = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    HearthDB = HearthDB or {}
    db = HearthDB
    db.version, db.chars = VERSION, db.chars or {}
end

function handlers.PLAYER_LOGIN()
    if not (Deadbeat and Deadbeat.SPEC and Deadbeat.SPEC >= "2.0") then return end
    local guid = UnitGUID("player")
    db.chars[guid] = db.chars[guid] or {}
    char = db.chars[guid]
    K, P = Deadbeat.kit, Deadbeat.kit.P
    m = Deadbeat.Register("Hearth", { icon = "Interface\\Icons\\INV_Misc_Rune_01", spec = "2.0" })
    buildItems()
    m:Tooltip(function(tip, item, shift) local t = TIPS[item.id] if t then t(tip, shift) end end)
    m:Click(function(item)
        if item.id == "bags" and ToggleAllBags then ToggleAllBags() end
    end, function(item) return item.id == "bags" and "open your bags" or nil end)
    m:OnContext(draw)
    m:Options({ title = "Hearth", icon = "Interface\\Icons\\INV_Misc_Rune_01", rows = {
        { kind = "header", label = "Everyday" },
        { kind = "note", label = "Hearth's items: gold, bags, durability, the raid you're in, flask and food; on the shelf: world buffs, mail, latency, time in a dungeon. Arrange them in edit mode (right-click the gear); which places each shows in: the Bar page." },
    } })
    if RequestRaidInfo then RequestRaidInfo() end
    C_Timer.NewTicker(1, draw)
    draw()
end

for _, e in ipairs({ "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "UPDATE_PENDING_MAIL",
                     "UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    handlers[e] = function() if m then draw() end end
end
handlers.UNIT_AURA = function(unit) if unit == "player" and m then draw() end end

f:SetScript("OnEvent", function(_, event, ...) local h = handlers[event] if h then h(...) end end)
for event in pairs(handlers) do pcall(f.RegisterEvent, f, event) end

SLASH_HEARTH1 = "/hearth"
SlashCmdList.HEARTH = function()
    if Deadbeat and Deadbeat.OpenSettings then Deadbeat.OpenSettings("Hearth") end
end
