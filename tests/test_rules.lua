-- What stays on the corpse and what is taken (Core/Rules.lua).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot()
local Decide = ns.Rules.Decide

local settings = ns.CopyDefaults({})
local function ctx(extra)
    local c = { settings = settings, own = {}, tight = false, stacksOnto = function() return false end }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

local function decide(item, extra)
    local take, reason = Decide(item, ctx(extra))
    return take, reason
end

H.Equal(select(2, decide({ money = true })), "money", "money is always taken")
H.Equal(decide({ money = true }, { tight = true }), true, "money is taken with full bags too")

-- Quality.
H.Equal(select(2, decide({ itemID = 1, quality = 2 })), "quality", "green is taken")
H.Equal(select(2, decide({ itemID = 1, quality = 4 }, { tight = true })), "quality", "epic is taken with few slots")
H.Equal(select(2, decide({ itemID = 1, quality = 1, sellPrice = 0 })), "common", "white is taken")

-- Quest items, by flag or item class.
H.Equal(select(2, decide({ itemID = 1, quality = 0, quest = true, sellPrice = 0 })), "quest", "quest flag")
H.Equal(select(2, decide({ itemID = 1, quality = 1, classID = 12 }, { tight = true })), "quest", "quest class with few slots")

-- Grey value threshold (default 5 silver, whole stack).
H.Equal(settings.greyMinValue, 500, "default grey threshold is 5 silver")
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 499, quantity = 1 })), "junk", "grey under the threshold stays")
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 500, quantity = 1 })), "value", "grey at the threshold is taken")
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 250, quantity = 2 })), "value", "the whole stack counts")
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 0 })), "junk", "grey with no price stays")
settings.greyMinValue = 0
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 1 })), "value", "threshold 0 keeps any grey that sells")
H.Equal(select(2, decide({ itemID = 1, quality = 0, sellPrice = 0 })), "junk", "threshold 0 still leaves worthless greys")
settings.greyMinValue = 500

-- Unknown data: always taken.
H.Equal(select(2, decide({ itemID = 1, quality = 0 })), "unknown", "grey with an unknown price is taken")
H.Equal(select(2, decide({ itemID = 1 })), "unknown", "unknown quality is taken")

-- Profession materials.
H.Equal(select(2, decide({ itemID = 7, quality = 1 }, { own = { [7] = true }, tight = true })), "profession",
    "own material is taken with few slots")
H.Equal(select(2, decide({ itemID = 7, quality = 0, sellPrice = 1 }, { own = { [7] = true } })), "profession",
    "a grey own material is taken")

-- Few free slots.
H.Equal(select(2, decide({ itemID = 8, quality = 1 }, { tight = true })), "space", "white non-material stays with few slots")
H.Equal(select(2, decide({ itemID = 8, quality = 0, sellPrice = 9999 }, { tight = true })), "space", "valuable grey stays with few slots")
H.Equal(select(2, decide({ itemID = 4496, quality = 1, classID = 1 }, { tight = true })), "bag", "a white bag is taken with few slots")
H.Equal(select(2, decide({ itemID = 4496, quality = 0, classID = 1, sellPrice = 1 }, { tight = true })), "bag", "even a grey bag")
settings.never[4496] = true
H.Equal(select(2, decide({ itemID = 4496, quality = 1, classID = 1 }, { tight = true })), "never", "never list still wins over a bag")
settings.never[4496] = nil
H.Equal(select(2, decide({ itemID = 8, quality = 1, quantity = 2 }, { tight = true, stacksOnto = function(id, q)
    return id == 8 and q == 2 end })), "stack", "an item that joins a carried stack is taken")

-- Player lists win over everything but money.
settings.never[9] = true
H.Equal(select(2, decide({ itemID = 9, quality = 3 })), "never", "never list beats quality")
settings.never[9] = nil
settings.always[9] = true
H.Equal(select(2, decide({ itemID = 9, quality = 0, sellPrice = 0 }, { tight = true })), "always", "always list beats junk and space")

H.Done("test_rules")
