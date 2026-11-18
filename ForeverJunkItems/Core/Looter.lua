-- The looting itself.
--
-- The game's own Auto Loot takes every slot by itself, so a filter cannot
-- work on top of it: while the add-on is on, the game option stays off and
-- the add-on loots instead. Holding the auto loot key (Shift by default)
-- turns the game's Auto Loot back on for that corpse, so everything is
-- taken and the add-on stays out of the way.
--
-- Corpse loot: on LOOT_READY each slot is judged (Core/Rules.lua) and only
-- the wanted ones are requested with LootSlot. When nothing needs a choice,
-- Blizzard's loot window is not opened for that corpse (its LOOT_OPENED is
-- unregistered and handed back at LOOT_CLOSED; nothing of Blizzard's is
-- replaced or called) and the loot closes once the wanted slots are gone,
-- leaving the rest on the corpse.
--
-- Anything that is not an enemy corpse (chests, herbs, ore, fishing,
-- containers opened in the bags) is taken whole.
local _, ns = ...

local Looter = {}
ns.Looter = Looter

local RETRY_DELAY = 0.4  -- one more request for slots the server has not cleared
local GIVE_UP = 1.5      -- then the loot closes and the leftovers are reported

local SLOT_ITEM = 1
local BIND_ON_PICKUP = 1

local L = { open = false, id = 0, requested = {}, pending = 0, left = {}, missed = {}, hid = false, ours = false }
Looter.state = L

local function itemAPI(name)
    return (C_Item and C_Item[name]) or _G[name]
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    return unpack(results, 2)
end

local function isItemSlot(slot)
    if type(GetLootSlotType) == "function" then return call(GetLootSlotType, slot) == SLOT_ITEM end
    return call(GetLootSlotLink, slot) ~= nil
end

local function hasItem(slot)
    if type(LootSlotHasItem) == "function" then return call(LootSlotHasItem, slot) and true or false end
    return call(GetLootSlotInfo, slot) ~= nil
end

-- The game is taking everything itself (its Auto Loot, or the key held).
function Looter.GameAutoLoots(autoLoot)
    if autoLoot ~= nil then return autoLoot and true or false end
    local on = GetCVarBool and GetCVarBool("autoLootDefault") or false
    local key = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") or false
    return on ~= key
end

local function masterLootThreshold()
    if type(GetLootMethod) ~= "function" then return nil end
    local method, partyMaster, raidMaster = call(GetLootMethod)
    if method ~= "master" then return nil end
    local mine = partyMaster == 0 or (raidMaster and UnitIsUnit("raid" .. raidMaster, "player"))
    if not mine then return nil end
    return call(GetLootThreshold) or 2
end

-- What the rules need to know about one slot.
function Looter.ReadSlot(slot)
    local _, _, quantity, _, quality, locked, isQuest, questID = call(GetLootSlotInfo, slot)
    local item = { slot = slot, quantity = quantity or 1, quality = quality, locked = locked,
                   quest = (isQuest or (questID and questID > 0)) and true or false }
    if not isItemSlot(slot) then
        item.money = true
        return item
    end
    item.link = call(GetLootSlotLink, slot)
    item.itemID = ns.ItemID(item.link)
    if item.itemID then
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            pcall(C_Item.RequestLoadItemDataByID, item.itemID)
        end
        local instant = itemAPI("GetItemInfoInstant")
        if instant then
            local _, _, _, _, _, classID = call(instant, item.itemID)
            item.classID = classID
        end
        local info = itemAPI("GetItemInfo")
        if info then
            local name, _, _, _, _, _, _, _, _, _, sellPrice, _, _, bindType = call(info, item.itemID)
            if name then
                item.cached = true
                item.sellPrice = sellPrice
                item.bind = bindType
            end
        end
    end
    return item
end

-- Decides every slot. Returns take (list of items), leave (list), needWindow,
-- unknown (items whose price or binding the client has not cached yet).
function Looter.Plan(slotCount, ctx)
    local take, leave, needWindow, unknown = {}, {}, false, 0
    local mlThreshold = masterLootThreshold()
    -- Money first: it never needs bag space.
    local items = {}
    for slot = 1, slotCount do
        if hasItem(slot) then
            local item = Looter.ReadSlot(slot)
            table.insert(items, item.money and 1 or #items + 1, item)
        end
    end
    for _, item in ipairs(items) do
        local wanted, reason
        if ctx.takeAll then
            wanted, reason = true, "all"
        else
            wanted, reason = ns.Rules.Decide(item, ctx)
        end
        item.reason = reason
        if not ctx.takeAll and not item.money and not item.cached and type(item.quality) == "number"
            and (item.quality == ns.Rules.POOR or item.quality >= ns.Rules.UNCOMMON) then
            unknown = unknown + 1
        end
        if not wanted then
            leave[#leave + 1] = item
        elseif item.locked or (mlThreshold and not item.money and (item.quality or 0) >= mlThreshold) then
            -- A group roll or a master-loot choice: the player decides in the window.
            needWindow = true
        elseif not item.money and not ns.Bags.Reserve(ctx.space, item.itemID, item.quantity) then
            item.reason = "full"
            leave[#leave + 1] = item
        else
            if item.bind == BIND_ON_PICKUP then needWindow = true end
            take[#take + 1] = item
        end
    end
    return take, leave, needWindow, unknown
end

local function context(settings, gatherKey)
    local space = ns.Bags.Space()
    return {
        settings = settings, own = ns.Professions.own, space = space,
        tight = space ~= nil and space.general <= (settings.reserveSlots or 0),
        stacksOnto = ns.Bags.StacksOnto,
        takeAll = gatherKey ~= nil,
    }
end

local function hideWindow()
    if LootFrame and LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:UnregisterEvent("LOOT_OPENED")
        L.hid = true
    end
end

local function giveBackWindow()
    if L.hid and LootFrame and not LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:RegisterEvent("LOOT_OPENED")
    end
    L.hid = false
end
Looter.GiveBackWindow = giveBackWindow

-- Lets Blizzard's loot window open for this loot. Before LOOT_OPENED,
-- handing its event back is enough; after it, the window's own LOOT_OPENED
-- handler is called (position and paging stay Blizzard's).
local function showWindow()
    L.windowNeeded = true
    giveBackWindow()
    if not L.opened or not LootFrame or LootFrame:IsShown() then return end
    local handler = LootFrame:GetScript("OnEvent")
    if handler then pcall(handler, LootFrame, "LOOT_OPENED", false) end
end
Looter.ShowWindow = showWindow

local function after(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) end
end

-- Closing the loot before LOOT_OPENED has gone by would let that event
-- reach the window after LOOT_CLOSED gave it back, opening it on a loot
-- that no longer exists: the close waits for LOOT_OPENED (or a moment).
local function close()
    if not L.open then return end
    if L.opened then
        CloseLoot()
        return
    end
    L.closeOnOpen = true
    local id = L.id
    after(0.3, function()
        if L.open and L.id == id and L.closeOnOpen then
            L.closeOnOpen = false
            CloseLoot()
        end
    end)
end

local function finish()
    if L.open and L.ours and not L.windowNeeded and L.pending == 0 then close() end
end

local function request(slot)
    if not L.requested[slot] then
        L.requested[slot] = true
        L.pending = L.pending + 1
    end
    LootSlot(slot)
end

local function retry(id)
    if not L.open or L.id ~= id then return end
    for slot in pairs(L.requested) do
        if hasItem(slot) and not select(6, call(GetLootSlotInfo, slot)) then LootSlot(slot) end
    end
end

local function giveUp(id)
    if not L.open or L.id ~= id or L.windowNeeded or L.pending == 0 then return end
    for slot in pairs(L.requested) do
        if hasItem(slot) then L.missed[#L.missed + 1] = call(GetLootSlotLink, slot) end
    end
    L.pending = 0
    close()
end

local MAX_WAITS, WAIT = 3, 0.15 -- item data the client has not cached yet

local function run(id)
    if not L.open or L.id ~= id then return end
    local count = call(GetNumLootItems) or 0
    local ctx = context(ns.db, L.gatherKey)
    if L.notCorpse then ctx.takeAll = true end
    local take, leave, needWindow, unknown = Looter.Plan(count, ctx)
    if unknown > 0 and L.waits < MAX_WAITS then
        -- Price or binding not cached yet: ask for it and judge again shortly.
        L.waits = L.waits + 1
        after(WAIT, function() run(id) end)
        return
    end
    for _, item in ipairs(leave) do L.left[#L.left + 1] = item end
    for _, item in ipairs(take) do request(item.slot) end
    if needWindow then
        showWindow()
        return
    end
    if L.pending == 0 then
        close()
        return
    end
    after(RETRY_DELAY, function() retry(id) end)
    after(GIVE_UP, function() giveUp(id) end)
end

function Looter.OnReady(autoLoot)
    if L.open then return end
    L.open, L.ours, L.windowNeeded, L.opened, L.closeOnOpen = true, false, false, false, false
    L.id = L.id + 1
    L.pending, L.waits = 0, 0
    wipe(L.requested)
    wipe(L.left)
    wipe(L.missed)
    local settings = ns.db
    if not settings or not settings.enabled or Looter.GameAutoLoots(autoLoot) then return end
    local sources = ns.Corpse.Sources(call(GetNumLootItems) or 0)
    L.notCorpse = not ns.Corpse.IsCreatureLoot(sources)
    L.gatherKey = nil
    if not L.notCorpse and settings.gatherCorpses then
        local key = ns.Corpse.GatherProfession(sources)
        if key and ns.Professions.known[key] then L.gatherKey = key end
    end
    L.ours = true
    hideWindow()
    run(L.id)
end

-- LOOT_OPENED: the loot window's moment has passed (clients without
-- LOOT_READY start the loot here).
function Looter.OnOpened(autoLoot)
    if not L.open then
        if Looter.readySeen then return end -- the loot already ended
        Looter.OnReady(autoLoot)
    end
    L.opened = true
    if L.closeOnOpen then
        L.closeOnOpen = false
        CloseLoot()
    end
end

-- A bind-on-pickup question: the player answers it with the window open.
function Looter.OnBindConfirm()
    if L.open and L.ours and not L.windowNeeded then showWindow() end
end

function Looter.OnSlotCleared(slot)
    if not L.open or not L.requested[slot] then return end
    L.requested[slot] = nil
    L.pending = math.max(0, L.pending - 1)
    finish()
end

-- Chat line and totals for what stayed behind.
local function report()
    local settings = ns.db
    local junk, full, value = {}, {}, 0
    for _, item in ipairs(L.left) do
        local text = item.link and ((item.quantity or 1) > 1 and (item.link .. "x" .. item.quantity) or item.link)
        if item.reason == "full" then
            if text then full[#full + 1] = text end
        else
            if text then junk[#junk + 1] = text end
            value = value + (item.sellPrice or 0) * (item.quantity or 1)
        end
    end
    if #junk > 0 then
        ns.session.left = ns.session.left + #junk
        ns.session.value = ns.session.value + value
        if settings then
            settings.stats.left = settings.stats.left + #junk
            settings.stats.value = settings.stats.value + value
        end
        if settings and settings.report then
            ns.Print("left behind " .. table.concat(junk, ", ") .. (value > 0 and (" (" .. ns.Money(value) .. ")") or ""))
        end
    end
    for _, link in ipairs(L.missed) do full[#full + 1] = link end
    if #full > 0 then
        ns.Print("|cffff5555no room in your bags for|r " .. table.concat(full, ", "))
    end
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function Looter.OnClosed()
    giveBackWindow()
    if L.open and L.ours then report() end
    L.open, L.ours, L.windowNeeded, L.closeOnOpen = false, false, false, false
    L.pending = 0
    wipe(L.requested)
end
