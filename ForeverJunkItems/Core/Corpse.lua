-- Where the loot comes from: an enemy corpse (filtered) or anything else
-- (chests, herbs, ore, fishing, containers in the bags: taken whole), and
-- whether that corpse can still be skinned, mined or gathered by you.
local _, ns = ...

local Corpse = {}
ns.Corpse = Corpse

-- The tooltip line of a corpse that a gathering profession can still use.
local function gatherLines()
    return {
        { text = UNIT_SKINNABLE_LEATHER, key = "skinning" },
        { text = UNIT_SKINNABLE_HERB, key = "herbalism" },
        { text = UNIT_SKINNABLE_ROCK, key = "mining" },
        { text = UNIT_SKINNABLE_BOLTS, key = "engineering" },
    }
end

-- On Forever some unit and tooltip values are secret (in game 2026-11-21:
-- the corpse GUID and its tooltip lines while looting). Lua may hold them
-- but not compare them or use them as table keys: they count as unknown.
local function plain(value)
    if value == nil then return nil end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    return value
end
Corpse.plain = plain

local function guidKind(guid)
    guid = plain(guid)
    return type(guid) == "string" and guid:match("^(%a+)%-") or nil
end

-- { [guid] = true } of every loot slot's source, or nil when the client
-- cannot say.
function Corpse.Sources(slotCount)
    if type(GetLootSourceInfo) ~= "function" then return nil end
    local sources, any = {}, false
    for slot = 1, slotCount do
        local ok, guid = pcall(GetLootSourceInfo, slot)
        guid = ok and plain(guid) or nil
        if type(guid) == "string" then
            sources[guid] = true
            any = true
        end
    end
    return any and sources or nil
end

-- True when every source is a creature. Unknown sources count as a
-- creature unless this is fishing loot.
function Corpse.IsCreatureLoot(sources)
    if type(IsFishingLoot) == "function" then
        local ok, fishing = pcall(IsFishingLoot)
        if ok and fishing then return false end
    end
    if not sources then return true end
    for guid in pairs(sources) do
        local kind = guidKind(guid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return false end
    end
    return true
end

local scanner
local function tooltipLines(unit)
    if C_TooltipInfo and type(C_TooltipInfo.GetUnit) == "function" then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            local lines = {}
            for _, line in ipairs(data.lines) do
                local text = type(line) == "table" and plain(line.leftText) or nil
                if type(text) == "string" then lines[#lines + 1] = text end
            end
            return lines
        end
    end
    if not CreateFrame then return {} end
    if not scanner then
        scanner = CreateFrame("GameTooltip", "ForeverJunkItemsScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    pcall(scanner.SetUnit, scanner, unit)
    local lines = {}
    for i = 1, scanner:NumLines() do
        local region = _G["ForeverJunkItemsScanTooltipTextLeft" .. i]
        local text = region and plain(region:GetText())
        if type(text) == "string" then lines[#lines + 1] = text end
    end
    scanner:Hide()
    return lines
end

-- The gathering profession this corpse still offers ("skinning", ...) or nil.
-- The corpse is the dead unit under the mouse or targeted whose GUID is one
-- of the loot sources (any dead one when the sources are unknown).
function Corpse.GatherProfession(sources)
    for _, unit in ipairs({ "mouseover", "target" }) do
        local guid = plain(UnitGUID(unit))
        if plain(UnitExists(unit)) and plain(UnitIsDead(unit)) and (not sources or (guid and sources[guid])) then
            for _, text in ipairs(tooltipLines(unit)) do
                for _, entry in ipairs(gatherLines()) do
                    if entry.text and text == entry.text then return entry.key end
                end
            end
        end
    end
    return nil
end
