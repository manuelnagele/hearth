-- luajit tests/smoke.lua: Hearth on Deadbeat (sibling repo) on the shared harness (deadbeat-spec).
local W = dofile(os.getenv("HARNESS") or "../deadbeat-spec/harness/wowstub.lua")   -- the shared harness
W.loadDeadbeat(os.getenv("DEADBEAT") or "../deadbeat")

function GetNetStats() return 0, 0, 80, 140 end
function GetFramerate() return 90 end
function HasNewMail() return true end
function GetLatestThreeSenders() return "A Friend", nil, nil end
function GetInventoryItemDurability(slot) if slot == 5 then return 20, 100 end if slot == 1 then return 90, 100 end end
function GetInventoryItemLink(_, slot) return "[item " .. slot .. "]" end
local raid = false
function GetInstanceInfo() if raid then return "Blackwing Lair", "raid" end return "Orgrimmar", "none" end
function IsInInstance() return raid, raid and "raid" or "none" end
function IsResting() return not raid end
function GetZoneText() return raid and "Blackwing Lair" or "Orgrimmar" end
function GetNumSavedInstances() return 1 end
function GetSavedInstanceInfo() return "Blackwing Lair", 1, 300000, 9, true, false, 0, true, 40, "40", 8, 5 end
C_UnitAuras = { GetAuraDataByIndex = function(_, i)
    local list = { { name = "Rallying Cry", icon = 1, spellId = 22888, expirationTime = GetTime() + 4000 },
                   { name = "Well Fed", icon = 2, spellId = 1, expirationTime = GetTime() + 900 } }
    return list[i]
end }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
                GetContainerNumFreeSlots = function(bag) return bag == 0 and 2 or 0, 0 end }

local ns = {}
for _, f in ipairs({ "Hearth/Core.lua", "Hearth/Hearth.lua" }) do assert(loadfile(f))("Hearth", ns) end
for _, fr in ipairs(W.frames) do fr:_fire("ADDON_LOADED", "Hearth") end
for _, fr in ipairs(W.frames) do fr:_fire("PLAYER_LOGIN") end
for _, fr in ipairs(W.frames) do fr:_fire("PLAYER_ENTERING_WORLD") end
assert(Deadbeat.Context() == "city", "city: " .. Deadbeat.Context())
local labels = {}
rawset(DeadbeatBar.label, "SetText", function(_, t) labels[#labels + 1] = t end)
for _, t in ipairs(W.tickers) do t() end
assert(labels[#labels] == "Orgrimmar", "zone on the bar in a city: " .. tostring(labels[#labels]))
raid = true
for _, fr in ipairs(W.frames) do fr:_fire("PLAYER_ENTERING_WORLD") end
for _, t in ipairs(W.tickers) do t() end
assert(Deadbeat.Context() == "raid" and labels[#labels] == "Blackwing Lair", "raid label")
DeadbeatBar:_script("OnEnter")
local tip = table.concat(W.tipLines, "\n")
assert(tip:find("Everyday") and tip:find("Consumables"), "tooltip section: " .. tip)
Deadbeat.OpenSettings("Hearth")
Deadbeat.OpenSettings("Bar")
SlashCmdList.HEARTH("")
print("hearth smoke ok")
