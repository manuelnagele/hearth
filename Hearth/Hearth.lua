-- Hearth: the bar in everyday play. Gold and today's change, bags, durability, world buffs, raid consumables, raid
-- progress, mail, the clock and latency, each where it fits (Deadbeat's contexts), details in the tooltip.
-- A Deadbeat module (spec 0.1).
local ADDON, ns = ...
local Core = ns.Core
local VERSION = "0.2.0"

local db, char
local m, K, P
local badges = {}
local entered = {}                   -- instance name -> when you came in (this session)

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function colour(level)
    if level == "bad" then return K.RED end
    if level == "low" then return P.goldOn end
    return { 0.92, 0.88, 0.80 }
end

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

-- --- the badges -----------------------------------------------------------------------------------

-- a badge: an icon and a text; the width follows the text
local function badge(id, label, contexts, iconPath)
    local b = m:Badge(40, { id = id, label = label, contexts = contexts })
    if iconPath then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(13, 13)
        b.icon:SetPoint("LEFT")
        b.icon:SetTexture(iconPath)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", iconPath and 16 or 0, 0)
    function b.set(text, c)
        b.text:SetText(text)
        if c then b.text:SetTextColor(c[1], c[2], c[3]) end
        b:SetWidth((iconPath and 16 or 0) + (b.text:GetStringWidth() or 20))
    end
    badges[id] = b
    return b
end

local ALL = { farm = true, raid = true, dungeon = true, city = true, world = true }

local function buildBadges()
    -- created right to left: the latency pip sits next to the gear. No clock: the minimap has one (user, 2026-11-22).
    local clock = badge("hearth.clock", "Latency", ALL)
    clock.pip = clock:CreateTexture(nil, "ARTWORK")
    clock.pip:SetSize(6, 6)
    clock.pip:SetTexture("Interface\\Buttons\\WHITE8x8")
    clock.pip:SetPoint("LEFT", 1, 0)
    function clock.set() clock:SetWidth(8) end
    badge("hearth.mail", "New mail", { city = true, world = true }, "Interface\\Icons\\INV_Letter_15")
    badge("hearth.durability", "Durability", { raid = true, dungeon = true, world = true, farm = true },
        "Interface\\Icons\\Trade_BlackSmithing")
    badge("hearth.bags", "Free bag slots", ALL, "Interface\\Icons\\INV_Misc_Bag_08")
    badge("hearth.consumables", "Raid consumables", { raid = true })
    local buffs = m:Badge(20, { id = "hearth.buffs", label = "World buffs", contexts = { raid = true, city = true, world = true } })
    buffs.slots = {}
    for i = 1, 5 do
        local s = CreateFrame("Frame", nil, buffs)
        s:SetSize(36, 14)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(13, 13)
        s.icon:SetPoint("LEFT")
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.text = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.text:SetPoint("LEFT", 15, 0)
        buffs.slots[i] = s
    end
    badges["hearth.buffs"] = buffs
end

-- --- drawing ---------------------------------------------------------------------------------------

local state = {}

local function draw()
    if not m then return end
    local ctx = Deadbeat.Context and Deadbeat.Context() or "world"
    -- clock + latency
    local _, _, home, world = GetNetStats()
    local lat = math.max(home or 0, world or 0)
    local c = badges["hearth.clock"]
    c.pip:SetVertexColor(unpack(lat < 120 and K.GREEN or (lat < 300 and P.goldOn or K.RED)))
    c.set()
    state.latency, state.home, state.world = lat, home, world
    -- mail
    local mail = badges["hearth.mail"]
    if HasNewMail and HasNewMail() then mail.set("", nil) mail:SetWidth(14) mail:Show() else mail:Hide() end
    -- bags
    local free, total = freeSlots()
    state.free, state.total = free, total
    badges["hearth.bags"].set(tostring(free), colour(Core.level(free, 8, 3)))
    -- durability
    local low, worst = Core.durability(gear())
    state.worst = worst
    local d = badges["hearth.durability"]
    if low then
        d.set(("%d%%"):format(low * 100 + 0.5), colour(Core.level(low * 100, 50, 25)))
        d:Show()
    else
        d:Hide()
    end
    -- world buffs + consumables
    local list = auras()
    local wb, flask, food = Core.scan(list)
    state.wb, state.flask, state.food = wb, flask, food
    local buffs = badges["hearth.buffs"]
    local x = 0
    for i, s in ipairs(buffs.slots) do
        local a = wb[i]
        if a then
            s.icon:SetTexture(a.icon)
            s.text:SetText(a.left and Core.short(a.left) or "")
            s.text:SetTextColor(unpack((a.left or 9999) < 600 and P.goldOn or P.warmGrey))
            s:SetWidth(15 + (s.text:GetStringWidth() or 18))
            s:ClearAllPoints()
            s:SetPoint("LEFT", buffs, "LEFT", x, 0)
            x = x + s:GetWidth() + 6
            s:Show()
        else
            s:Hide()
        end
    end
    buffs:SetWidth(math.max(1, x - 6))
    buffs:SetShown(#wb > 0)
    local miss = Core.missing(flask, food)
    local cons = badges["hearth.consumables"]
    if #miss > 0 then cons.set("no " .. table.concat(miss, " · no "), K.RED) cons:Show() else cons:Hide() end
    -- the label and numbers
    local name, kind = instance()
    if name then entered[name] = entered[name] or time() end
    for k in pairs(entered) do if k ~= name then entered[k] = nil end end
    if kind == "raid" and db.raidLine ~= false then
        local killed, all = progress(name)
        m:Set("label", name, 25)
        m:Set("clock", K.clock(time() - entered[name]), 25)
        if killed and all then m:Set("primary", ("%d/%d"):format(killed, all), 25) else m:Clear("primary") end
        m:Set("secondary", "", 25)
    elseif kind == "party" then
        m:Set("label", name, 15)
        m:Set("clock", K.clock(time() - entered[name]), 15)
        m:Clear("primary") m:Clear("secondary")
    elseif db.goldLine ~= false and (ctx == "city" or ctx == "world") then
        local money = GetMoney()
        local change
        char.days, change = Core.today(char.days, date("%Y-%m-%d"), money)
        state.change, state.start = change, money - change
        m:Set("label", GetZoneText() or "", 12)
        m:Set("clock", "", 12)                           -- over Haul's session clock
        m:Set("primary", K.coins(money, 12, true), 12)
        local sign = change >= 0 and ("|cff" .. K.hex(K.GREEN) .. "+") or ("|cff" .. K.hex(K.RED) .. "−")
        m:Set("secondary", change ~= 0 and (sign .. "|r" .. K.coins(math.abs(change), 10, true) .. " today") or "", 12)
    else
        for _, f in ipairs({ "label", "clock", "primary", "secondary" }) do m:Clear(f) end
    end
    Deadbeat.Refresh()
end

-- --- tooltip ---------------------------------------------------------------------------------------------

local function section(tip)
    local g, w = P.warmGrey, { 1, 1, 1 }
    tip:AddLine("Everyday", P.bronze4[1], P.bronze4[2], P.bronze4[3])
    if state.start then
        tip:AddDoubleLine("  Gold today", ("%s → %s"):format(K.coins(state.start, 11, true), K.coins(GetMoney(), 11, true)),
            g[1], g[2], g[3], 1, 1, 1)
    end
    tip:AddDoubleLine("  Bags", ("%d free of %d"):format(state.free or 0, state.total or 0), g[1], g[2], g[3], 1, 1, 1)
    for i, it in ipairs(state.worst or {}) do
        tip:AddDoubleLine(i == 1 and "  Durability" or " ", ("%s  %d%%"):format(it.link or "?", it.share * 100 + 0.5),
            g[1], g[2], g[3], 1, 1, 1)
    end
    for i, a in ipairs(state.wb or {}) do
        tip:AddDoubleLine(i == 1 and "  World buffs" or " ", ("%s  %s"):format(Core.WORLD[a.id] or a.name,
            a.left and K.clock(a.left) or ""), g[1], g[2], g[3], 1, 1, 1)
    end
    if select(2, instance()) == "raid" then
        local miss = Core.missing(state.flask, state.food)
        tip:AddDoubleLine("  Consumables", #miss == 0 and "flask and food" or ("|cff" .. K.hex(K.RED) .. "no " ..
            table.concat(miss, ", no ") .. "|r"), g[1], g[2], g[3], 1, 1, 1)
    end
    if GetNumSavedInstances and GetNumSavedInstances() > 0 then
        for i = 1, GetNumSavedInstances() do
            local n, _, reset, _, locked, _, _, isRaid, _, _, total, killed = GetSavedInstanceInfo(i)
            if locked and isRaid then
                tip:AddDoubleLine(("  %s %d/%d"):format(n, killed or 0, total or 0), "resets in " .. Core.until_(reset),
                    g[1], g[2], g[3], w[1], w[2], w[3])
            end
        end
    end
    if HasNewMail and HasNewMail() and GetLatestThreeSenders then
        local a, b, c = GetLatestThreeSenders()
        local who = table.concat({ a, b, c }, ", ")
        tip:AddDoubleLine("  Mail", who ~= "" and who or "new mail", g[1], g[2], g[3], 1, 1, 1)
    end
    tip:AddDoubleLine("  Latency · FPS", ("%d / %d ms  ·  %d fps"):format(state.home or 0, state.world or 0,
        GetFramerate and GetFramerate() or 0), g[1], g[2], g[3], 1, 1, 1)
end

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
    if not Deadbeat then return end
    local guid = UnitGUID("player")
    db.chars[guid] = db.chars[guid] or {}
    char = db.chars[guid]
    K, P = Deadbeat.kit, Deadbeat.kit.P
    m = Deadbeat.Register("Hearth", 60, { spec = "0.1" })
    buildBadges()
    m:Section(section)
    m:OnContext(draw)
    if m.Options then
        m:Options({ title = "Hearth", icon = "Interface\\Icons\\INV_Misc_Rune_01", rows = {
            { kind = "header", label = "Everyday" },
            { kind = "toggle", label = "Zone, gold and today's change in the open world and in cities",
              get = function() return db.goldLine ~= false end, set = function(on) db.goldLine = on draw() end },
            { kind = "toggle", label = "In a raid: raid, time inside, bosses killed",
              get = function() return db.raidLine ~= false end, set = function(on) db.raidLine = on draw() end },
            { kind = "note", label = "Which badges show where (bags, durability, world buffs, consumables, mail, clock): the Bar page." },
        } })
    end
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
