-- Looting flow against the fake client (Core/Looter.lua, Core/Events.lua).
local H = dofile("tests/harness/wow.lua")

local function boot(setup)
    local ns = H.Boot(setup)
    H.cvars.autoLootDefault = "0" -- the add-on switched it off at login
    return ns
end

-- 1. Corpse: junk stays, the rest is taken, the window never opens.
local ns = boot()
local grey = H.Item(100, { quality = 0, sellPrice = 3 })
local white = H.Item(101, { quality = 1, sellPrice = 10, stack = 20 })
local green = H.Item(102, { quality = 2, sellPrice = 900 })
H.OpenLoot({
    [1] = { money = true },
    [2] = { link = grey, quality = 0 },
    [3] = { link = white, quality = 1 },
    [4] = { link = green, quality = 2 },
})
H.Check(H.Taken(1) and H.Taken(3) and H.Taken(4), "money, white and green taken")
H.Check(not H.Taken(2), "worthless grey left on the corpse")
H.Equal(H.lootCalls[1], 1, "money requested first")
H.Equal(H.lootFrameOpened, 0, "Blizzard's loot window not opened")
H.Equal(H.closed, 1, "loot closed once the wanted slots were cleared")
H.Check(LootFrame:IsEventRegistered("LOOT_OPENED"), "window handed back its LOOT_OPENED")
H.Check(H.LastChat():find("left behind") and H.LastChat():find("Item100"), "chat lists what was left")
H.Equal(ns.session.left, 1, "session counter")
H.Equal(ns.db.stats.left, 1, "all-time counter")

-- 2. Only junk: closed at once.
H.closed = 0
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Equal(#H.lootCalls, 0, "nothing requested")
H.Equal(H.closed, 1, "closed straight away")
H.Equal(H.lootFrameOpened, 0, "LOOT_OPENED after the close does not open the window")

-- 3. Shift held (the game's Auto Loot takes everything): hands off.
H.closed, H.lootFrameOpened = 0, 0
H.OpenLoot({ [1] = { link = grey, quality = 0 } }, true)
H.Equal(#H.lootCalls, 0, "add-on requests nothing while the game auto loots")
H.Equal(H.closed, 0, "add-on does not close the loot")
H.Equal(H.lootFrameOpened, 1, "window behaves as normal")
H.Fire("LOOT_CLOSED")

-- 4. Turned off: hands off.
ns.Control.SetEnabled(false)
H.lootFrameOpened = 0
H.OpenLoot({ [1] = { link = grey, quality = 0 } }, false)
H.Equal(#H.lootCalls, 0, "off: nothing requested")
H.Equal(H.lootFrameOpened, 1, "off: window as normal")
H.Fire("LOOT_CLOSED")
ns.Control.SetEnabled(true)
H.cvars.autoLootDefault = "0"

-- 5. Not a corpse (chest, herb, ore, container): everything taken.
H.OpenLoot({ [1] = { link = grey, quality = 0, source = "GameObject-0-1-2-3-4-5" } })
H.Check(H.Taken(1), "chest loot taken whole")
H.fishing = true
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(H.Taken(1), "fishing loot taken whole")
H.fishing = false
H.OpenLoot({ [1] = { link = grey, quality = 0, source = "Item-0-1-2-3" } })
H.Check(H.Taken(1), "container opened in the bags taken whole")

-- 6. Few free slots: only essentials, stacks still join.
H.bags[0].free = 3 -- default reserve is 4
local cloth = H.Item(2589, { quality = 1, stack = 20 }) -- Linen Cloth
local meat = H.Item(2672, { quality = 1, stack = 10 })  -- Stringy Wolf Meat
H.skills = { { name = "Professions", header = true }, { name = "Tailoring" } }
H.Fire("SKILL_LINES_CHANGED")
H.bagCount[2672] = 3
H.OpenLoot({
    [1] = { link = cloth, quality = 1 },
    [2] = { link = white, quality = 1 },
    [3] = { link = meat, quality = 1, quantity = 2 },
})
H.Check(H.Taken(1), "tailor keeps Linen Cloth with few slots")
H.Check(not H.Taken(2), "other white items left with few slots")
H.Check(H.Taken(3), "meat joins the stack already carried")
H.bags[0].free = 10
H.bagCount[2672] = nil

-- 7. Bags full: a wanted item is reported, not requested.
H.bags[0].free = 0
ns.db.reserveSlots = 0
H.OpenLoot({ [1] = { link = green, quality = 2 } })
H.Check(not H.Taken(1), "no request without room")
H.Check(H.LastChat():find("no room"), "player told the item stayed for lack of room")
H.bags[0].free = 10
ns.db.reserveSlots = 4

-- Special bags take their own items.
H.bags[0].free = 0
H.bags[1] = { free = 2, family = 32 } -- herb bag
local herb = H.Item(2447, { quality = 1, family = 32 })
H.OpenLoot({ [1] = { link = herb, quality = 1 } })
-- tight (0 general slots) and not a herbalist: left for space.
H.Check(not H.Taken(1), "herb left when not a material of yours and bags are tight")
H.skills = { { name = "Herbalism" } }
H.Fire("SKILL_LINES_CHANGED")
H.OpenLoot({ [1] = { link = herb, quality = 1 } })
H.Check(H.Taken(1), "herbalist: herb goes into the herb bag")
H.bags[0].free, H.bags[1] = 10, nil

-- 8. Group roll / locked item: the window opens for the player.
H.lootFrameOpened, H.closed = 0, 0
H.OpenLoot({ [1] = { link = green, quality = 2, locked = true }, [2] = { link = grey, quality = 0 } })
H.Equal(H.lootFrameOpened, 1, "window shown for a locked item")
H.Equal(H.closed, 0, "loot left open for the player")
H.Fire("LOOT_CLOSED")
H.Check(LootFrame:IsEventRegistered("LOOT_OPENED"), "window events restored after closing")

-- 9. Master looter: items at or above the threshold go to the window.
H.lootMethod = { "master", 0 }
H.lootFrameOpened = 0
H.OpenLoot({ [1] = { link = green, quality = 2 } })
H.Equal(H.lootFrameOpened, 1, "master looter decides in the window")
H.Fire("LOOT_CLOSED")
H.lootMethod = { "freeforall" }

-- 10. Bind on pickup: the window opens so the question can be answered.
local bop = H.Item(103, { quality = 3, bind = 1 })
H.lootFrameOpened = 0
H.OpenLoot({ [1] = { link = bop, quality = 3, bind = 1 } })
H.Equal(H.lootFrameOpened, 1, "window shown for a bind-on-pickup item")
H.Fire("LOOT_CLOSED")
-- Binding not cached: the question itself opens the window.
H.items[104] = nil
local bop2 = "|Hitem:104::|h[Uncached]|h"
H.lootFrameOpened = 0
H.OpenLoot({ [1] = { link = bop2, quality = 3, bind = 1 } })
H.Advance(1)
H.Equal(H.lootFrameOpened, 1, "LOOT_BIND_CONFIRM opens the window")
H.Fire("LOOT_CLOSED")

-- 11. Price not cached yet: wait, then judge.
local slow = H.Item(105, { quality = 0, sellPrice = 1, uncached = true })
H.closed = 0
H.OpenLoot({ [1] = { link = slow, quality = 0 } })
H.Equal(#H.lootCalls, 0, "nothing decided while the price is unknown")
H.items[105].uncached = false
H.Advance(0.2)
H.Check(not H.Taken(1), "junk left once its price arrived")
H.Equal(H.closed, 1, "closed after the delayed decision")
-- Never cached: taken (never leave what cannot be judged).
local never = H.Item(106, { quality = 0, sellPrice = 1, uncached = true })
H.OpenLoot({ [1] = { link = never, quality = 0 } })
H.Advance(1)
H.Check(H.Taken(1), "an item that could not be judged is taken")
H.Fire("LOOT_CLOSED")

-- 12. A lost request is retried, then the loot closes and reports it.
H.closed = 0
H.OpenLoot({ [1] = { link = green, quality = 2, stuck = true } })
H.Equal(#H.lootCalls, 1, "first request")
H.Advance(0.5)
H.Equal(#H.lootCalls, 2, "one retry")
H.Advance(1.5)
H.Equal(H.closed, 1, "gave up and closed")
H.Check(H.LastChat():find("no room") and H.LastChat():find("Item102"), "missed item reported")

-- 13. Skinnable corpse and a skinner: everything taken.
H.skills = { { name = "Skinning" } }
H.Fire("SKILL_LINES_CHANGED")
H.units.mouseover = { guid = "Creature-0-1-2-3-4-5", dead = true, lines = { "Wolf", "Skinnable" } }
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(H.Taken(1), "skinner empties a skinnable corpse")
ns.db.gatherCorpses = false
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(not H.Taken(1), "option off: junk stays even on skinnable corpses")
ns.db.gatherCorpses = true
H.skills = { { name = "Tailoring" } }
H.Fire("SKILL_LINES_CHANGED")
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(not H.Taken(1), "not a skinner: junk stays")
-- A different corpse under the mouse does not count.
H.skills = { { name = "Skinning" } }
H.Fire("SKILL_LINES_CHANGED")
H.units.mouseover.guid = "Creature-9-9-9-9-9-9"
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(not H.Taken(1), "another corpse's tooltip is ignored")
-- Secret GUID or tooltip text (in game 2026-11-21: Lua errors while
-- looting): unknown, never compared or used as a key; the junk stays.
local SECRET = newproxy(true)
getmetatable(SECRET).__index = function() error("secret value indexed") end
_G.issecretvalue = function(value) return value == SECRET end
H.units.mouseover = { guid = SECRET, dead = true, lines = { "Wolf", "Skinnable" } }
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(not H.Taken(1), "secret corpse GUID: no gathering assumed, no error")
H.units.mouseover = { guid = "Creature-0-1-2-3-4-5", dead = true, lines = { "Wolf", SECRET } }
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(not H.Taken(1), "secret tooltip line: skipped, no error")
H.units.mouseover.lines = { SECRET, "Skinnable" }
H.OpenLoot({ [1] = { link = grey, quality = 0 } })
H.Check(H.Taken(1), "a plain line after a secret one still counts")
_G.issecretvalue = nil
H.units.mouseover = nil

-- 14. Without LOOT_READY the add-on starts on LOOT_OPENED.
ns = boot(function() H.unknownEvents.LOOT_READY = true end)
H.cvars.autoLootDefault = "0"
green = H.Item(102, { quality = 2, sellPrice = 900 })
grey = H.Item(100, { quality = 0, sellPrice = 3 })
H.loot = { [1] = { link = green, quality = 2 }, [2] = { link = grey, quality = 0 } }
H.lootCalls = {}
H.Fire("LOOT_OPENED", false)
H.Check(H.Taken(1) and not H.Taken(2), "filter works from LOOT_OPENED")
H.Equal(H.closed, 1, "and closes the loot")
H.Check(LootFrame:IsEventRegistered("LOOT_OPENED"), "window events restored")

-- 15. A rare (blue) or better item: one chime per loot, the game's "epic loot" sound.
H.sounds = {}
local blue = H.Item(200, { quality = 3, sellPrice = 5000 })
local purple = H.Item(201, { quality = 4, sellPrice = 9000 })
H.OpenLoot({ [1] = { link = green, quality = 2 }, [2] = { link = grey, quality = 0 } })
H.Equal(#H.sounds, 0, "no sound for green and grey")
H.OpenLoot({ [1] = { link = blue, quality = 3 }, [2] = { link = purple, quality = 4 } })
H.Equal(#H.sounds, 1, "one sound for two rare items")
H.Equal(H.sounds[1], 31578, "the epic loot sound")
H.Check(H.Taken(1) and H.Taken(2), "and both are taken")
H.Advance(1)
H.OpenLoot({ [1] = { link = blue, quality = 3 } })
H.Equal(#H.sounds, 2, "again on the next loot")
ns.db.rareSound = false
H.OpenLoot({ [1] = { link = blue, quality = 3 } })
H.Equal(#H.sounds, 2, "option off: silent")
ns.db.rareSound = true
ns.db.never[200] = true
H.OpenLoot({ [1] = { link = blue, quality = 3 } })
H.Equal(#H.sounds, 2, "an item on the Never list stays silent")
ns.db.never[200] = nil
H.bags = { [0] = { free = 0, family = 0 } }
H.OpenLoot({ [1] = { link = blue, quality = 3 } })
H.Equal(#H.sounds, 3, "bags full: the sound still points at it")
H.bags = { [0] = { free = 10, family = 0 } }
local fresh = H.Item(202, { quality = 3, sellPrice = 100, uncached = true })
H.OpenLoot({ [1] = { link = fresh, quality = 3 } })
H.Advance(1)
H.Equal(#H.sounds, 4, "an item not cached yet: one sound after the waits")
local before = #H.sounds
ns.Commands.Run("sound")
H.Equal(#H.sounds, before + 1, "/fji sound plays it")
ns.Commands.Run("sound off")
H.Equal(ns.db.rareSound, false, "/fji sound off")
ns.Commands.Run("sound on")
H.Equal(ns.db.rareSound, true, "/fji sound on")

H.Done("test_looter")
