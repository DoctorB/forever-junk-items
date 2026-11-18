-- What to take from a corpse. Pure: no client calls.
--
-- Rules.Decide(item, ctx) -> take (boolean), reason (string)
--   item: { money, itemID, quality, quantity, quest, classID, sellPrice }
--   ctx:  { settings, own = { [itemID] = true }, tight = boolean,
--           stacksOnto = function(itemID, quantity) -> boolean }
--
-- When something is unknown the item is taken: the add-on never leaves
-- behind an item it could not judge.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local QUEST_CLASS = 12
Rules.POOR, Rules.COMMON, Rules.UNCOMMON = 0, 1, 2

function Rules.Decide(item, ctx)
    if item.money then return true, "money" end
    local settings = ctx.settings
    local id = item.itemID
    if id and settings.never[id] then return false, "never" end
    if id and settings.always[id] then return true, "always" end
    if item.quest or item.classID == QUEST_CLASS then return true, "quest" end
    local quality = item.quality
    if type(quality) ~= "number" then return true, "unknown" end
    if quality >= Rules.UNCOMMON then return true, "quality" end
    if id and ctx.own and ctx.own[id] then return true, "profession" end
    if ctx.tight then
        -- Few free slots left: only what costs no new slot.
        if id and ctx.stacksOnto and ctx.stacksOnto(id, item.quantity or 1) then return true, "stack" end
        return false, "space"
    end
    if quality >= Rules.COMMON then return true, "common" end
    if type(item.sellPrice) ~= "number" then return true, "unknown" end
    local value = item.sellPrice * math.max(1, item.quantity or 1)
    if value > 0 and value >= (settings.greyMinValue or 0) then return true, "value" end
    return false, "junk"
end
