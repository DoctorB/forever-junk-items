-- Offline stand-in for the WoW Forever client: just enough API to load the
-- add-on in TOC order and drive it with events. Lua 5.1.
local H = { failures = 0, checks = 0 }

-- ------------------------------------------------------------- assertions

function H.Check(condition, message)
    H.checks = H.checks + 1
    if not condition then
        H.failures = H.failures + 1
        io.stderr:write("FAIL: " .. tostring(message) .. "\n")
    end
end

function H.Equal(actual, expected, message)
    H.Check(actual == expected, string.format("%s (expected %s, got %s)", tostring(message), tostring(expected), tostring(actual)))
end

function H.Done(name)
    if H.failures > 0 then
        io.stderr:write(string.format("%s: %d of %d checks failed\n", name, H.failures, H.checks))
        os.exit(1)
    end
    print(string.format("%s: %d checks passed", name, H.checks))
end

-- ------------------------------------------------------------------- TOC

function H.ReadToc(path)
    local files, fields = {}, {}
    for line in io.lines(path) do
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then
            fields[key] = value
        elseif line:match("%S") and not line:match("^#") then
            files[#files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
        end
    end
    return files, fields
end

-- ---------------------------------------------------------------- client

-- Generic widget: records scripts, events and shown state; any other
-- method is a no-op returning nil.
local function newObject(kind, name)
    local o = { kind = kind, name = name, scripts = {}, events = {}, shown = true, children = {} }
    local methods = {}
    function methods:SetScript(script, fn) self.scripts[script] = fn end
    function methods:GetScript(script) return self.scripts[script] end
    function methods:RegisterEvent(event)
        if H.unknownEvents[event] then error("unknown event " .. event) end
        self.events[event] = true
        H.frames[self] = true
    end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:IsEventRegistered(event) return self.events[event] == true end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetChecked(v) self.checked = v end
    function methods:GetChecked() return self.checked end
    function methods:SetText(v) self.text = v end
    function methods:GetText() return self.text end
    function methods:CreateFontString() local f = newObject("FontString"); self.children[#self.children + 1] = f; return f end
    function methods:CreateTexture() return newObject("Texture") end
    function methods:NumLines() return #(self.lines or {}) end
    setmetatable(o, { __index = function(_, key)
        return methods[key] or function() return nil end
    end })
    return o
end
H.NewObject = newObject

function H.Reset()
    H.failuresAtReset = H.failures
    H.frames = {}
    H.unknownEvents = {}
    H.timers = {}
    H.now = 0
    H.chat = {}
    H.cvars = { autoLootDefault = "1" }
    H.modifier = false
    H.loot = {}          -- slot -> { link, quantity, quality, locked, quest, money, source }
    H.lootCalls = {}
    H.closed = 0
    H.items = {}         -- itemID -> { name, quality, sellPrice, stack, classID, bind, family, uncached }
    H.bagCount = {}      -- itemID -> count in bags
    H.bags = { [0] = { free = 10, family = 0 } }
    H.skills = {}        -- { { name, header, expanded } }
    H.units = {}         -- unit -> { guid, dead, lines }
    H.lootMethod = { "freeforall" }
    H.fishing = false
    H.createdNames = {}

    _G.ForeverJunkItemsDB = nil
    _G.ForeverJunkItemsCharDB = nil
    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) H.chat[#H.chat + 1] = message end }
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.unpack = unpack
    _G.bit = { band = function(a, b)
        local result, bitValue = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then result = result + bitValue end
            a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
        end
        return result
    end }

    _G.CreateFrame = function(kind, name)
        local o = newObject(kind, name)
        if name then _G[name] = o; H.createdNames[name] = true end
        return o
    end
    _G.UIParent = newObject("Frame", "UIParent")
    _G.WorldFrame = newObject("Frame", "WorldFrame")
    _G.GameTooltip = newObject("GameTooltip", "GameTooltip")
    _G.Minimap = newObject("Frame", "Minimap")
    Minimap.GetWidth = function() return 140 end
    Minimap.GetCenter = function() return 1000, 600 end
    Minimap.GetEffectiveScale = function() return 1 end
    H.cursorPosition = { 1000, 600 }
    _G.GetCursorPosition = function() return H.cursorPosition[1], H.cursorPosition[2] end
    -- Blizzard's loot window, registered for LOOT_OPENED as in the client.
    H.lootFrameOpened = 0
    _G.LootFrame = newObject("Frame", "LootFrame")
    LootFrame.shown = false
    LootFrame:RegisterEvent("LOOT_OPENED")
    LootFrame:RegisterEvent("LOOT_CLOSED")
    LootFrame:SetScript("OnEvent", function(self, event)
        if event == "LOOT_OPENED" then H.lootFrameOpened = H.lootFrameOpened + 1; self.shown = true end
        if event == "LOOT_CLOSED" then self.shown = false end
    end)

    _G.C_Timer = { After = function(delay, fn) H.timers[#H.timers + 1] = { at = H.now + delay, fn = fn } end }
    _G.GetCVar = function(name) return H.cvars[name] end
    _G.GetCVarBool = function(name) return H.cvars[name] == "1" end
    _G.SetCVar = function(name, value) H.cvars[name] = tostring(value) end
    _G.IsModifiedClick = function(name) return name == "AUTOLOOTTOGGLE" and H.modifier end

    _G.GetNumLootItems = function()
        local n = 0
        for slot in pairs(H.loot) do if slot > n then n = slot end end
        return n
    end
    _G.LootSlotHasItem = function(slot) return H.loot[slot] ~= nil and not H.loot[slot].gone end
    _G.GetLootSlotType = function(slot)
        local s = H.loot[slot]
        if not s then return 0 end
        return s.money and 2 or 1
    end
    _G.GetLootSlotLink = function(slot)
        local s = H.loot[slot]
        return s and not s.money and s.link or nil
    end
    _G.GetLootSlotInfo = function(slot)
        local s = H.loot[slot]
        if not s then return nil end
        return "icon", "name", s.quantity or 1, nil, s.quality, s.locked, s.quest, s.questID, true
    end
    _G.GetLootSourceInfo = function(slot)
        local s = H.loot[slot]
        return s and (s.source or "Creature-0-1-2-3-4-5") or nil, 1
    end
    _G.IsFishingLoot = function() return H.fishing end
    _G.LootSlot = function(slot)
        H.lootCalls[#H.lootCalls + 1] = slot
        local s = H.loot[slot]
        if s and not s.gone and not s.stuck then
            if s.bind == 1 and not s.confirmed then
                H.Fire("LOOT_BIND_CONFIRM", slot) -- waits for the player's answer
                return
            end
            s.gone = true
            H.Fire("LOOT_SLOT_CLEARED", slot)
        end
    end
    _G.CloseLoot = function()
        H.closed = H.closed + 1
        H.Fire("LOOT_CLOSED")
    end
    _G.GetLootMethod = function() return unpack(H.lootMethod) end
    _G.GetLootThreshold = function() return 2 end
    _G.UnitIsUnit = function(a, b) return a == b end

    _G.GetItemInfo = function(id)
        id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
        local i = H.items[id]
        if not i or i.uncached then return nil end
        return i.name, "|Hitem:" .. id .. "|h[" .. i.name .. "]|h", i.quality, 1, 1, "Type", "Sub", i.stack or 1, "",
            "icon", i.sellPrice or 0, i.classID or 15, 0, i.bind or 0
    end
    _G.GetItemInfoInstant = function(id)
        local i = H.items[tonumber(id)]
        if not i then return nil end
        return id, "Type", "Sub", "", "icon", i.classID or 15, 0
    end
    _G.GetItemCount = function(id) return H.bagCount[tonumber(id)] or 0 end
    _G.GetItemFamily = function(id) local i = H.items[tonumber(id)]; return i and i.family or 0 end
    _G.GetContainerNumFreeSlots = function(bag)
        local b = H.bags[bag]
        if not b then return 0, 0 end
        return b.free, b.family
    end
    _G.C_Container = nil
    _G.C_Item = nil

    -- WoW Forever: profession indexes, then name ... skill line (7th value).
    H.professions = {}   -- { { name, line } } in GetProfessions order
    _G.GetProfessions = function()
        local indexes = {}
        for i = 1, #H.professions do indexes[i] = i end
        return unpack(indexes)
    end
    _G.GetProfessionInfo = function(index)
        local p = H.professions[index]
        if not p then return nil end
        return p.name, "icon", 1, 75, 2, 0, p.line
    end
    _G.C_SkillInfo = nil
    _G.GetNumSkillLines = function() return #H.skills end
    _G.GetSkillLineInfo = function(i)
        local s = H.skills[i]
        return s.name, s.header or false, s.expanded ~= false
    end

    _G.UNIT_SKINNABLE_LEATHER = "Skinnable"
    _G.UNIT_SKINNABLE_HERB = "Requires Herbalism"
    _G.UNIT_SKINNABLE_ROCK = "Requires Mining"
    _G.UNIT_SKINNABLE_BOLTS = "Requires Engineering"
    _G.UnitExists = function(unit) return H.units[unit] ~= nil end
    _G.UnitIsDead = function(unit) return H.units[unit] and H.units[unit].dead end
    _G.UnitGUID = function(unit) return H.units[unit] and H.units[unit].guid end
    _G.C_TooltipInfo = { GetUnit = function(unit)
        local u = H.units[unit]
        local lines = {}
        for _, t in ipairs(u and u.lines or {}) do lines[#lines + 1] = { leftText = t } end
        return { lines = lines }
    end }

    _G.GetCursorInfo = function() return H.cursor and "item" or nil, H.cursor end
    _G.ClearCursor = function() H.cursor = nil end
    _G.ITEM_QUALITY_COLORS = { [0] = { hex = "|cff9d9d9d" }, [1] = { hex = "|cffffffff" }, [2] = { hex = "|cff1eff00" } }
end

function H.Fire(event, ...)
    local list = {}
    for frame in pairs(H.frames) do list[#list + 1] = frame end
    for _, frame in ipairs(list) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end

-- Runs every timer due within `seconds`.
function H.Advance(seconds)
    local target = H.now + seconds
    while true do
        table.sort(H.timers, function(a, b) return a.at < b.at end)
        local nextTimer = H.timers[1]
        if not nextTimer or nextTimer.at > target then break end
        table.remove(H.timers, 1)
        H.now = nextTimer.at
        nextTimer.fn()
    end
    H.now = target
end

-- Loads the add-on files in TOC order with a shared namespace, then fires
-- ADDON_LOADED and PLAYER_LOGIN.
function H.Boot(setup)
    H.Reset()
    if setup then setup() end
    local files = H.ReadToc("ForeverJunkItems/ForeverJunkItems.toc")
    local ns = {}
    for _, file in ipairs(files) do
        local chunk = assert(loadfile("ForeverJunkItems/" .. file))
        chunk("ForeverJunkItems", ns)
    end
    H.ns = ns
    H.Fire("ADDON_LOADED", "ForeverJunkItems")
    H.Fire("PLAYER_LOGIN")
    return ns
end

-- Helpers to describe loot.
function H.Item(id, fields)
    fields.name = fields.name or ("Item" .. id)
    H.items[id] = fields
    return "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. fields.name .. "]|h|r"
end

-- Opens loot: fires LOOT_READY then LOOT_OPENED, as the client does.
function H.OpenLoot(slots, autoLoot)
    H.loot = slots
    H.lootCalls = {}
    H.Fire("LOOT_READY", autoLoot)
    H.Fire("LOOT_OPENED", autoLoot)
end

function H.Taken(slot)
    for _, s in ipairs(H.lootCalls) do if s == slot then return true end end
    return false
end

function H.LastChat()
    return H.chat[#H.chat] or ""
end

return H
