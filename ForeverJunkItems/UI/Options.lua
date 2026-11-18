-- Options window (/fji). Uses only templates already verified on Forever
-- 1.60.1 by Forever One Button: BasicFrameTemplateWithInset,
-- UIPanelButtonTemplate, UICheckButtonTemplate.
local _, ns = ...

local UI = {}
ns.UI = UI

-- Grey value steps, in copper.
UI.GREY_STEPS = { 0, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000 }
UI.RESERVE_MIN, UI.RESERVE_MAX = 0, 16
UI.LIST_ROWS = 6

local WIDTH, HEIGHT = 470, 600
local frame
local refreshers = {}

local function tooltip(widget, title, text)
    widget:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function text(parent, template, x, y, width)
    local s = parent:CreateFontString(nil, "OVERLAY", template)
    s:SetPoint("TOPLEFT", x, y)
    if width then s:SetWidth(width) end
    s:SetJustifyH("LEFT")
    return s
end

local function section(parent, title, y)
    text(parent, "GameFontNormal", 16, y):SetText(title)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.25)
    rule:SetPoint("TOPLEFT", 16, y - 16)
    rule:SetSize(WIDTH - 32, 1)
    return y - 24
end

local function check(parent, y, label, tip, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", 14, y)
    local s = text(parent, "GameFontHighlight", 0, 0)
    s:ClearAllPoints()
    s:SetPoint("LEFT", c, "RIGHT", 4, 0)
    s:SetText(label)
    if c.SetHitRectInsets then c:SetHitRectInsets(0, -300, 0, 0) end
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    tooltip(c, label, tip)
    refreshers[#refreshers + 1] = function() c:SetChecked(get()) end
    return c
end

-- "-  value  +" row.
local function stepper(parent, y, label, tip, show, change)
    local s = text(parent, "GameFontHighlight", 20, y - 4)
    s:SetText(label)
    local value = text(parent, "GameFontHighlight", 0, 0, 70)
    value:ClearAllPoints()
    value:SetPoint("TOPLEFT", 318, y - 4)
    value:SetJustifyH("CENTER")
    local minus = button(parent, "-", 26, function() change(-1) end)
    minus:SetPoint("TOPLEFT", 290, y)
    local plus = button(parent, "+", 26, function() change(1) end)
    plus:SetPoint("TOPLEFT", 390, y)
    tooltip(minus, label, tip)
    tooltip(plus, label, tip)
    refreshers[#refreshers + 1] = function() value:SetText(show()) end
end

function UI.StepGrey(current, direction)
    local steps, index = UI.GREY_STEPS, 1
    for i, v in ipairs(steps) do
        if v <= current then index = i end
    end
    index = math.max(1, math.min(#steps, index + direction))
    return steps[index]
end

local function itemLabel(id)
    local name, _, quality = nil, nil, nil
    if GetItemInfo then name, _, quality = GetItemInfo(id) end
    if not name then return "Item " .. id end
    local color = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    return color and color.hex and (color.hex .. name .. "|r") or name
end

-- Sorted item IDs of a list.
function UI.Sorted(list)
    local ids = {}
    for id in pairs(list) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- A drop box ("Drag an item here") and the list under it.
local function listColumn(parent, x, y, title, listName, tip)
    text(parent, "GameFontNormalSmall", x, y):SetText(title)
    local drop = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    drop:SetSize(200, 26)
    drop:SetPoint("TOPLEFT", x, y - 16)
    drop:SetText("Drop an item here")
    local function take()
        local kind, id = GetCursorInfo()
        if kind == "item" and id then
            ns.Commands.SetList(listName, id)
            ClearCursor()
        end
    end
    drop:SetScript("OnReceiveDrag", take)
    drop:SetScript("OnClick", take)
    tooltip(drop, title, tip)
    local rows = {}
    for i = 1, UI.LIST_ROWS do
        local row = CreateFrame("Button", nil, parent)
        row:SetSize(200, 16)
        row:SetPoint("TOPLEFT", x + 4, y - 46 - (i - 1) * 17)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetAllPoints()
        label:SetJustifyH("LEFT")
        row.label = label
        row:SetScript("OnClick", function(self) if self.itemID then ns.Commands.Remove(self.itemID) end end)
        tooltip(row, "Click to remove", "The item follows the normal rules again.")
        rows[i] = row
    end
    local more = text(parent, "GameFontDisableSmall", x + 4, y - 46 - UI.LIST_ROWS * 17)
    refreshers[#refreshers + 1] = function()
        local ids = UI.Sorted(ns.db[listName])
        for i, row in ipairs(rows) do
            local id = ids[i]
            row.itemID = id
            if id then
                row.label:SetText(itemLabel(id))
                row:Show()
            else
                row:Hide()
            end
        end
        if #ids == 0 then
            more:SetText("Empty")
        elseif #ids > UI.LIST_ROWS then
            more:SetText("and " .. (#ids - UI.LIST_ROWS) .. " more (/fji remove <item>)")
        else
            more:SetText("")
        end
    end
end

local function build()
    frame = CreateFrame("Frame", "ForeverJunkItemsOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverJunkItemsOptions") end
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(ns.TITLE .. " " .. ns.VERSION)

    local db = function() return ns.db end
    local y = -34
    local intro = text(frame, "GameFontHighlightSmall", 16, y, WIDTH - 32)
    intro:SetText("Loots for you and leaves worthless items on enemy corpses, so your bags last longer. "
        .. "Hold Shift while looting to take everything.")
    y = y - 34

    y = section(frame, "Looting", y)
    check(frame, y, "Filter loot from enemies",
        "On: Forever Junk Items loots for you and leaves junk behind. The game's own Auto Loot is switched "
        .. "off while this is on, and put back when you turn it off.",
        function() return db().enabled end, function(v) ns.Control.SetEnabled(v) end)
    y = y - 30
    stepper(frame, y, "Leave grey items worth less than",
        "Grey items whose whole stack sells for less than this stay on the corpse. Set it to 0 to keep "
        .. "every grey item that sells for something.",
        function() return ns.Money(db().greyMinValue) end,
        function(d) db().greyMinValue = UI.StepGrey(db().greyMinValue, d); UI.Refresh() end)
    y = y - 28
    stepper(frame, y, "Free bag slots to keep",
        "When only this many free slots are left, just quest items, green or better items and your "
        .. "profession materials are looted. Items that join a stack you already carry are always looted.",
        function() return tostring(db().reserveSlots) end,
        function(d)
            db().reserveSlots = math.max(UI.RESERVE_MIN, math.min(UI.RESERVE_MAX, db().reserveSlots + d))
            UI.Refresh()
        end)
    y = y - 30
    check(frame, y, "Empty corpses I can skin, mine or gather from",
        "A corpse can only be skinned once it is empty. With this on, such corpses are looted completely "
        .. "when you have the profession.",
        function() return db().gatherCorpses end, function(v) db().gatherCorpses = v end)
    y = y - 28
    check(frame, y, "List what is left behind in chat",
        "One chat line per corpse with the items left behind and what they are worth.",
        function() return db().report end, function(v) db().report = v end)
    y = y - 38

    y = section(frame, "Your professions", y)
    local professions = text(frame, "GameFontHighlight", 20, y, WIDTH - 40)
    local professionsHint = text(frame, "GameFontDisableSmall", 20, y - 18, WIDTH - 40)
    refreshers[#refreshers + 1] = function()
        local list = ns.Professions.Describe()
        professions:SetText(list or "None found yet")
        professionsHint:SetText(list and "Materials for these professions are always looted, even when your bags are almost full."
            or "Open your skills (K) once if the Professions header is folded.")
    end
    y = y - 50

    y = section(frame, "Your lists", y)
    listColumn(frame, 18, y, "Always loot", "always", "Drag an item from your bags here: it will always be looted.")
    listColumn(frame, 248, y, "Never loot", "never", "Drag an item from your bags here: it will stay on corpses.")
    y = y - 70 - UI.LIST_ROWS * 17

    local stats = text(frame, "GameFontHighlightSmall", 16, -HEIGHT + 30, WIDTH - 32)
    refreshers[#refreshers + 1] = function()
        stats:SetText("Left behind this session: " .. ns.session.left .. " items worth "
            .. ns.Money(ns.session.value) .. ".  All time: " .. db().stats.left .. " items.")
    end
end

function UI.Create()
    -- Built on first open; nothing to do at login.
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    for _, refresh in ipairs(refreshers) do refresh() end
end

function UI.Open()
    if not ns.db then return end
    if not frame then build() end
    frame:Show()
    UI.Refresh()
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end
