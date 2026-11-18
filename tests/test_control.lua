-- The game's Auto Loot option and the commands (Core/Control.lua, Core/Commands.lua).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot() -- client starts with Auto Loot on
H.Equal(H.cvars.autoLootDefault, "0", "game Auto Loot switched off at login")
H.Equal(ns.db.gameAutoLoot, "1", "old value remembered")
H.Check(H.chat[1] and H.chat[1]:find("Hold Shift"), "first login explains Shift")
local lines = #H.chat
H.Fire("PLAYER_LOGIN")
H.Equal(#H.chat, lines, "introduction shown only once")

SlashCmdList.FOREVERJUNKITEMS("off")
H.Equal(ns.db.enabled, false, "/fji off")
H.Equal(H.cvars.autoLootDefault, "1", "game Auto Loot put back")
SlashCmdList.FOREVERJUNKITEMS("on")
H.Equal(H.cvars.autoLootDefault, "0", "/fji on switches it off again")

-- Logout puts the game's value back (for a player who removes the add-on);
-- the next login switches it off again.
H.Fire("PLAYER_LOGOUT")
H.Equal(H.cvars.autoLootDefault, "1", "logout restores the game's Auto Loot")
H.Fire("PLAYER_LOGIN")
H.Equal(H.cvars.autoLootDefault, "0", "login switches it off again")
H.Equal(ns.db.gameAutoLoot, "1", "still remembered")

-- A player who looted by hand gets their setting back unchanged.
ns = H.Boot(function() H.cvars.autoLootDefault = "0" end)
SlashCmdList.FOREVERJUNKITEMS("off")
H.Equal(H.cvars.autoLootDefault, "0", "manual looting stays manual after /fji off")

-- Someone turns the game option back on: one warning per session.
ns = H.Boot()
H.cvars.autoLootDefault = "1"
local before = #H.chat
H.OpenLoot({ [1] = { money = true } }, true)
H.Fire("LOOT_CLOSED")
H.OpenLoot({ [1] = { money = true } }, true)
H.Fire("LOOT_CLOSED")
local warnings = 0
for i = before + 1, #H.chat do if H.chat[i]:find("Auto Loot option is on") then warnings = warnings + 1 end end
H.Equal(warnings, 1, "warned once")

-- Lists.
local link = H.Item(500, { name = "Broken Fang", quality = 0 })
SlashCmdList.FOREVERJUNKITEMS("always " .. link)
H.Check(ns.db.always[500], "/fji always <link>")
SlashCmdList.FOREVERJUNKITEMS("never 500")
H.Check(ns.db.never[500] and not ns.db.always[500], "/fji never moves the item between lists")
SlashCmdList.FOREVERJUNKITEMS("remove " .. link)
H.Check(not ns.db.never[500] and not ns.db.always[500], "/fji remove")
SlashCmdList.FOREVERJUNKITEMS("always nothing")
H.Check(H.LastChat():find("item link"), "bad item refused with a hint")
SlashCmdList.FOREVERJUNKITEMS("status")
H.Check(H.LastChat():find("left behind this session"), "/fji status")
SlashCmdList.FOREVERJUNKITEMS("help")
H.Check(H.LastChat():find("/fji remove"), "help lists the commands")

-- Settings survive a reload and gain new defaults.
ForeverJunkItemsDB = { greyMinValue = 2000 }
ns.LoadSettings()
H.Equal(ns.db.greyMinValue, 2000, "saved value kept")
H.Equal(ns.db.reserveSlots, 4, "missing value gets its default")

-- Helpers.
H.Equal(ns.Money(0), "0c", "money 0")
H.Equal(ns.Money(10203), "1g 2s 3c", "money format")
H.Equal(ns.Money(500), "5s", "silver only")
H.Equal(ns.ItemID("|Hitem:2589::|h"), 2589, "id from link")
H.Equal(ns.ItemID(" 42 "), 42, "id from number text")
H.Equal(ns.ItemID("abc"), nil, "no id")
H.Done("test_control")
