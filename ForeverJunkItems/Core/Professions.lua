-- The character's professions (read from the skill list) and the set of
-- materials they use or gather (Data/Materials.lua).
local _, ns = ...

local Professions = {}
ns.Professions = Professions

Professions.known = {}   -- { [key] = true }
Professions.own = {}     -- { [itemID] = true }

local CRAFTING_ORDER = {
    "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring",
    "mining", "herbalism", "skinning", "cooking", "firstaid", "fishing",
}

Professions.LABELS = {
    alchemy = "Alchemy", blacksmithing = "Blacksmithing", enchanting = "Enchanting",
    engineering = "Engineering", leatherworking = "Leatherworking", tailoring = "Tailoring",
    mining = "Mining", herbalism = "Herbalism", skinning = "Skinning", cooking = "Cooking",
    firstaid = "First Aid", fishing = "Fishing",
}

local byName
local function nameIndex()
    if byName then return byName end
    byName = {}
    for key, names in pairs(ns.Materials.NAMES) do
        for _, name in ipairs(names) do byName[name] = key end
    end
    return byName
end

local function addIDs(set, list)
    if type(list) ~= "string" then return end
    for id in list:gmatch("%d+") do set[tonumber(id)] = true end
end

-- Material set for a list of profession keys.
function Professions.MaterialsFor(keys)
    local set = {}
    for key in pairs(keys) do
        addIDs(set, ns.Materials.USES[key])
        addIDs(set, ns.Materials.GATHERS[key])
    end
    return set
end

-- Reads the skill list. A collapsed header hides its lines, and the add-on
-- never opens or closes headers itself: while any header is collapsed the
-- professions seen earlier on this character are kept (`saved`, the
-- per-character record), so folding the list does not forget them.
function Professions.Scan(saved)
    local known, complete = {}, true
    if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        local index = nameIndex()
        local ok, count = pcall(GetNumSkillLines)
        for i = 1, (ok and tonumber(count) or 0) do
            local okLine, name, isHeader, isExpanded = pcall(GetSkillLineInfo, i)
            if okLine and isHeader and not isExpanded then complete = false end
            if okLine and not isHeader and type(name) == "string" and index[name] then
                known[index[name]] = true
            end
        end
    else
        complete = false
    end
    if type(saved) == "table" then
        if complete then
            for key in pairs(saved) do saved[key] = nil end
        else
            for key in pairs(saved) do if ns.Materials.NAMES[key] then known[key] = true end end
        end
        for key in pairs(known) do saved[key] = true end
    end
    Professions.known = known
    Professions.own = Professions.MaterialsFor(known)
    return known
end

-- "Tailoring, Skinning" (fixed order) or nil.
function Professions.Describe()
    local names = {}
    for _, key in ipairs(CRAFTING_ORDER) do
        if Professions.known[key] then names[#names + 1] = Professions.LABELS[key] end
    end
    return #names > 0 and table.concat(names, ", ") or nil
end
