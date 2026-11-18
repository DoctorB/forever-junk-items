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

local function keyFor(line, name)
    line = tonumber(line)
    if line and ns.Materials.LINES[line] then return ns.Materials.LINES[line] end
    return type(name) == "string" and nameIndex()[name] or nil
end

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- WoW Forever: GetProfessions() gives the indexes of the professions
-- (two main ones, then First Aid, Fishing and Cooking) and
-- GetProfessionInfo(index) their name and skill line (7th value).
-- Returns known, complete; complete is false when the list came back empty
-- (it can, right after login).
local function fromProfessions()
    local results = { call(GetProfessions) }
    if not results[1] then return nil end
    local known, any = {}, false
    for i = 2, 8 do
        local index = results[i]
        if type(index) == "number" then
            local ok, name, _, _, _, _, _, line = call(GetProfessionInfo, index)
            local key = ok and keyFor(line, name)
            if key then
                known[key] = true
                any = true
            end
        end
    end
    return known, any
end

-- The skill list: C_SkillInfo (tables) or the classic globals. A collapsed
-- header hides its lines, so the list is then incomplete.
local function fromSkillList()
    local count, read
    if C_SkillInfo and type(C_SkillInfo.GetNumSkillLines) == "function" and type(C_SkillInfo.GetSkillLineInfo) == "function" then
        count = C_SkillInfo.GetNumSkillLines
        read = function(i)
            local ok, info = call(C_SkillInfo.GetSkillLineInfo, i)
            if not ok or type(info) ~= "table" then return nil end
            return info.skillName or info.name, info.isHeader, not info.isCollapsed, info.skillID or info.skillLineID
        end
    elseif type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        count = GetNumSkillLines
        read = function(i)
            local ok, name, isHeader, isExpanded = call(GetSkillLineInfo, i)
            if not ok then return nil end
            return name, isHeader, isExpanded, nil
        end
    else
        return nil
    end
    local known, complete = {}, true
    local ok, total = call(count)
    for i = 1, (ok and tonumber(total) or 0) do
        local name, isHeader, isExpanded, line = read(i)
        if isHeader and not isExpanded then complete = false end
        local key = not isHeader and keyFor(line, name)
        if key then known[key] = true end
    end
    return known, complete
end

-- Reads the character's professions. The add-on never opens or closes
-- skill headers itself: when the list is incomplete the professions seen
-- earlier on this character are kept (`saved`, the per-character record).
function Professions.Scan(saved)
    local known, complete = fromProfessions()
    if not complete then
        -- No GetProfessions, or it listed nothing yet: try the skill list.
        local listed, listComplete = fromSkillList()
        if listed and (next(listed) ~= nil or not known) then known, complete = listed, listComplete end
    end
    if not known then known, complete = {}, false end
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
