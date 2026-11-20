-- Namespace, saved settings and chat output.
local ADDON, ns = ...

ns.NAME = "ForeverJunkItems"
ns.TITLE = "Forever Junk Items"
ns.VERSION = "1.2.0"

-- Account-wide settings. Money values are in copper.
ns.DEFAULTS = {
    enabled = true,       -- filter loot from enemy corpses
    greyMinValue = 500,   -- grey items worth less than this (whole stack) stay on the corpse
    reserveSlots = 4,     -- with this many free bag slots or fewer, only the essentials are looted
    gatherCorpses = true, -- empty corpses you can skin, mine or gather from
    report = true,        -- list what was left behind in chat
    rareSound = true,     -- a sound when a rare (blue) or better item drops
}

ns.DEFAULT_MINIMAP_ANGLE = 225

function ns.CopyDefaults(db)
    for key, value in pairs(ns.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    if type(db.always) ~= "table" then db.always = {} end
    if type(db.never) ~= "table" then db.never = {} end
    if type(db.stats) ~= "table" then db.stats = { left = 0, value = 0 } end
    -- Minimap button: shown by default, lower left of the minimap edge.
    local minimap = type(db.minimap) == "table" and db.minimap or {}
    local angle = tonumber(minimap.angle)
    db.minimap = { shown = minimap.shown ~= false,
        angle = (angle and angle == angle) and math.floor(angle) % 360 or ns.DEFAULT_MINIMAP_ANGLE }
    return db
end

-- Settings, lists and totals are shared by the account's characters; each
-- character keeps its own professions and its own game Auto Loot value.
function ns.LoadSettings()
    if type(ForeverJunkItemsDB) ~= "table" then ForeverJunkItemsDB = {} end
    ns.db = ns.CopyDefaults(ForeverJunkItemsDB)
    if type(ForeverJunkItemsCharDB) ~= "table" then ForeverJunkItemsCharDB = {} end
    if type(ForeverJunkItemsCharDB.professions) ~= "table" then ForeverJunkItemsCharDB.professions = {} end
    ns.char = ForeverJunkItemsCharDB
    return ns.db
end

ns.session = { left = 0, value = 0 }

local PREFIX = "|cff33cc99Forever Junk Items|r: "

function ns.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message) end
end

-- "1g 2s 3c" from copper.
function ns.Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
    return table.concat(parts, " ")
end

-- Item ID from a number, an "item:123" string or a full item link.
function ns.ItemID(value)
    if type(value) == "number" then return value > 0 and math.floor(value) or nil end
    if type(value) ~= "string" then return nil end
    local id = value:match("item:(%d+)") or value:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end
