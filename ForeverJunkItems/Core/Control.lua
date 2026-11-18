-- Turning the add-on on and off, and the game's Auto Loot option with it.
local _, ns = ...

local Control = {}
ns.Control = Control

local CVAR = "autoLootDefault"

local function cvar()
    return GetCVar and GetCVar(CVAR) or nil
end

-- On: the game's Auto Loot is switched off (the add-on loots instead) and
-- its old value is remembered for this character. Off: it is put back.
function Control.Apply()
    local db, char = ns.db, ns.char
    if not db or not char or not SetCVar then return end
    if db.enabled then
        if cvar() == "1" then
            char.gameAutoLoot = "1"
            pcall(SetCVar, CVAR, "0")
        end
        if not db.introduced then
            db.introduced = true
            ns.Print("now loots for you and leaves junk on enemy corpses. Hold Shift while looting to take "
                .. "everything. Type /fji for the options.")
        end
    elseif char.gameAutoLoot then
        pcall(SetCVar, CVAR, char.gameAutoLoot)
        char.gameAutoLoot = nil
    end
end

-- Logging out: the game's own value goes back into its settings file, so a
-- player who removes the add-on gets their Auto Loot back. The next login
-- switches it off again (Apply).
function Control.OnLogout()
    local db, char = ns.db, ns.char
    if db and char and db.enabled and char.gameAutoLoot and SetCVar then
        pcall(SetCVar, CVAR, char.gameAutoLoot)
    end
end

function Control.SetEnabled(on)
    ns.db.enabled = on and true or false
    Control.Apply()
    ns.Print(ns.db.enabled and "on." or "off. The game's Auto Loot is back as it was.")
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

-- Someone turned the game's Auto Loot back on while the add-on is on: it
-- would take everything, so say once per session how to fix it.
local warned = false
function Control.CheckGameOption()
    if warned or not ns.db or not ns.db.enabled then return end
    if cvar() == "1" then
        warned = true
        ns.Print("the game's Auto Loot option is on, so everything is looted. Type /fji on to let "
            .. "Forever Junk Items filter again.")
    end
end
