-- Client events. Loaded last.
local ADDON, ns = ...

local frame = CreateFrame("Frame")
ns.EventFrame = frame

local function scanProfessions()
    if not ns.char then return end
    ns.Professions.Scan(ns.char.professions)
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    ns.LoadSettings()
    frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
    ns.Control.Apply()
    scanProfessions()
    if ns.UI and ns.UI.Create then ns.UI.Create() end
end

function handlers.PLAYER_LOGOUT()
    ns.Control.OnLogout()
end

function handlers.SKILL_LINES_CHANGED()
    scanProfessions()
end

-- Learning or unlearning a profession changes the spell book.
function handlers.SPELLS_CHANGED()
    scanProfessions()
end

function handlers.LOOT_READY(autoLoot)
    ns.Looter.readySeen = true
    if next(ns.Professions.known) == nil then scanProfessions() end -- an empty read after login
    ns.Control.CheckGameOption()
    ns.Looter.OnReady(autoLoot)
end

function handlers.LOOT_OPENED(autoLoot)
    ns.Looter.OnOpened(autoLoot)
end

function handlers.LOOT_SLOT_CLEARED(slot)
    ns.Looter.OnSlotCleared(slot)
end

function handlers.LOOT_CLOSED()
    ns.Looter.OnClosed()
end

function handlers.LOOT_BIND_CONFIRM()
    ns.Looter.OnBindConfirm()
end

ns.Handlers = handlers

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)

for event in pairs(handlers) do
    pcall(frame.RegisterEvent, frame, event) -- an event this client lacks is skipped
end
