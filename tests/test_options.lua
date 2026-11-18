-- Options window (UI/Options.lua).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot()
local UI = ns.UI
SlashCmdList.FOREVERJUNKITEMS("")
H.Check(UI.IsShown(), "/fji opens the options")
H.Check(H.createdNames.ForeverJunkItemsOptions, "named window for Esc to close")
H.Equal(UISpecialFrames[1], "ForeverJunkItemsOptions", "closes with Esc")

-- Grey value steps.
H.Equal(UI.StepGrey(500, 1), 1000, "5s -> 10s")
H.Equal(UI.StepGrey(500, -1), 200, "5s -> 2s")
H.Equal(UI.StepGrey(0, -1), 0, "floor at 0")
H.Equal(UI.StepGrey(50000, 1), 50000, "ceiling at 5g")
H.Equal(UI.StepGrey(750, 1), 1000, "an odd saved value moves to the next step")

-- Drag an item onto the Always box.
H.Item(600, { name = "Wool Cloth", quality = 1 })
H.cursor = 600
ns.Commands.SetList("always", select(2, GetCursorInfo()))
H.Check(ns.db.always[600], "dropped item added")
local ids = UI.Sorted({ [3] = true, [1] = true, [2] = true })
H.Equal(table.concat(ids, ","), "1,2,3", "lists sorted by item number")
UI.Refresh()
H.Done("test_options")
