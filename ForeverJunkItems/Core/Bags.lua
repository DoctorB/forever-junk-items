-- Free bag space and stacking, read from the client.
local _, ns = ...

local Bags = {}
ns.Bags = Bags

local function api(name)
    return (C_Container and C_Container[name]) or _G[name]
end

local function itemAPI(name)
    return (C_Item and C_Item[name]) or _G[name]
end

local LAST_BAG = 4 -- backpack (0) and the four bag slots

-- general: free slots in bags that take any item.
-- special: list of { family, free } for profession bags, quivers, ammo pouches.
function Bags.Space()
    local space = { general = 0, special = {} }
    local freeSlots = api("GetContainerNumFreeSlots")
    if not freeSlots then return nil end
    for bag = 0, LAST_BAG do
        local ok, free, family = pcall(freeSlots, bag)
        if ok and type(free) == "number" and free > 0 then
            if not family or family == 0 then
                space.general = space.general + free
            else
                space.special[#space.special + 1] = { family = family, free = free }
            end
        end
    end
    return space
end

local function maxStack(itemID)
    local getInfo = itemAPI("GetItemInfo")
    if not getInfo then return nil end
    local ok, name, _, _, _, _, _, _, stack = pcall(getInfo, itemID)
    if ok and name and type(stack) == "number" then return stack end
    return nil
end

-- True when `quantity` more of the item fits on a stack already in the bags.
function Bags.StacksOnto(itemID, quantity)
    local count = itemAPI("GetItemCount")
    local stack = maxStack(itemID)
    if not count or not stack or stack <= 1 then return false end
    local ok, have = pcall(count, itemID)
    if not ok or type(have) ~= "number" or have <= 0 then return false end
    local room = (stack - have % stack) % stack
    return room >= (quantity or 1)
end

local function familyMatch(bagFamily, itemFamily)
    if not bagFamily or not itemFamily or itemFamily == 0 then return false end
    if bit and bit.band then return bit.band(bagFamily, itemFamily) ~= 0 end
    return bagFamily == itemFamily
end

-- Reserves room for an item in `space` and returns true when it fits.
function Bags.Reserve(space, itemID, quantity)
    if not space then return true end -- unknown: let the client decide
    if itemID and Bags.StacksOnto(itemID, quantity) then return true end
    local getFamily = itemAPI("GetItemFamily")
    local family = itemID and getFamily and select(2, pcall(getFamily, itemID))
    if type(family) == "number" and family ~= 0 then
        for _, bag in ipairs(space.special) do
            if bag.free > 0 and familyMatch(bag.family, family) then
                bag.free = bag.free - 1
                return true
            end
        end
    end
    if space.general > 0 then
        space.general = space.general - 1
        return true
    end
    return false
end
