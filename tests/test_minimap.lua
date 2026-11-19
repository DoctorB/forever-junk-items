-- Minimap button (UI/MinimapButton.lua).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot()
local M = ns.MinimapButton
H.Check(H.createdNames.ForeverJunkItemsMinimapButton, "button created at login")
H.Check(M.IsShown(), "shown by default")
H.Equal(ns.db.minimap.angle, 225, "default angle: lower left")

-- Geometry.
local x, y = M.Offset(0, 140)
H.Equal(x, 80, "angle 0 sits on the right edge")
H.Check(math.abs(y) < 1e-9, "angle 0 has no vertical offset")
H.Equal(M.AngleOf(0, 10), 90, "straight up is 90")
H.Equal(M.AngleOf(-10, 0), 180, "left is 180")
H.Equal(M.AngleOf(0, -10), 270, "down is 270")

-- Clicks.
local button = ForeverJunkItemsMinimapButton
button.scripts.OnClick(button, "LeftButton")
H.Check(ns.UI.IsShown(), "left-click opens the options")
button.scripts.OnClick(button, "LeftButton")
H.Check(not ns.UI.IsShown(), "second left-click closes them")
button.scripts.OnClick(button, "RightButton")
H.Equal(ns.db.enabled, false, "right-click turns the filter off")
H.Equal(H.cvars.autoLootDefault, "1", "game Auto Loot put back")
button.scripts.OnClick(button, "RightButton")
H.Equal(ns.db.enabled, true, "right-click turns it on again")

-- Dragging saves the angle.
H.cursorPosition = { 1000, 700 }
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnDragStop(button)
H.Equal(ns.db.minimap.angle, 90, "drag above the minimap saves 90")
H.Equal(button.scripts.OnUpdate, nil, "drag stops following the cursor")

-- Hide and show.
SlashCmdList.FOREVERJUNKITEMS("minimap")
H.Check(not M.IsShown(), "/fji minimap hides it")
H.Equal(ns.db.minimap.shown, false, "hidden state saved")
SlashCmdList.FOREVERJUNKITEMS("minimap")
H.Check(M.IsShown(), "/fji minimap shows it again")

-- Saved values are cleaned up.
H.Equal(ns.CopyDefaults({ minimap = { shown = false, angle = 400.7 } }).minimap.angle, 40, "angle wrapped")
H.Equal(ns.CopyDefaults({ minimap = { angle = 0 / 0 } }).minimap.angle, 225, "NaN angle reset")
H.Equal(ns.CopyDefaults({ minimap = "bad" }).minimap.shown, true, "broken value reset")

-- A hidden button stays hidden after the next login.
local ns2 = H.Boot(function() _G.ForeverJunkItemsDB = { minimap = { shown = false, angle = 10 } } end)
H.Check(not ns2.MinimapButton.IsShown(), "hidden button not created at login")
H.Done("test_minimap")
