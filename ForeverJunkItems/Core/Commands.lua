-- Slash commands: /fji and /foreverjunk.
local _, ns = ...

local Commands = {}
ns.Commands = Commands

local HELP = {
    "/fji - options",
    "/fji on | off - turn the filter on or off",
    "/fji status - current settings and professions",
    "/fji always <item> - always loot an item (shift-click it into the command)",
    "/fji never <item> - never loot an item",
    "/fji remove <item> - take an item off both lists",
    "/fji minimap - show or hide the minimap button",
}

local function itemText(id)
    local name = GetItemInfo and select(2, GetItemInfo(id))
    return name or ("item " .. id)
end

function Commands.SetList(list, value)
    local id = ns.ItemID(value)
    if not id then
        ns.Print("give an item link or item number.")
        return false
    end
    local other = list == "always" and "never" or "always"
    ns.db[other][id] = nil
    ns.db[list][id] = true
    ns.Print(itemText(id) .. (list == "always" and " will always be looted." or " will never be looted."))
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    return true
end

function Commands.Remove(value)
    local id = ns.ItemID(value)
    if not id then
        ns.Print("give an item link or item number.")
        return false
    end
    ns.db.always[id], ns.db.never[id] = nil, nil
    ns.Print(itemText(id) .. " follows the normal rules again.")
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    return true
end

function Commands.Status()
    local db = ns.db
    ns.Print(db.enabled and "on" or "off")
    ns.Print("grey items worth less than " .. ns.Money(db.greyMinValue) .. " stay on the corpse")
    ns.Print("with " .. db.reserveSlots .. " free bag slots or fewer, only quest items, green or better "
        .. "and your profession materials are looted")
    ns.Print("professions: " .. (ns.Professions.Describe() or "none found"))
    ns.Print("left behind this session: " .. ns.session.left .. " items (" .. ns.Money(ns.session.value) .. ")")
end

function Commands.Run(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "options" or command == "config" then
        if ns.UI and ns.UI.Open then ns.UI.Open() end
    elseif command == "on" then
        ns.Control.SetEnabled(true)
    elseif command == "off" then
        ns.Control.SetEnabled(false)
    elseif command == "status" then
        Commands.Status()
    elseif command == "always" or command == "never" then
        Commands.SetList(command, rest)
    elseif command == "remove" then
        Commands.Remove(rest)
    elseif command == "minimap" then
        local shown = not ns.db.minimap.shown
        ns.MinimapButton.SetShown(shown)
        ns.Print(shown and "minimap button shown." or "minimap button hidden: /fji minimap shows it again.")
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end

SLASH_FOREVERJUNKITEMS1 = "/fji"
SLASH_FOREVERJUNKITEMS2 = "/foreverjunk"
SlashCmdList.FOREVERJUNKITEMS = Commands.Run
