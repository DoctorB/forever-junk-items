-- Professions from the skill list and their materials (Core/Professions.lua, Data/Materials.lua).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(function()
    H.skills = {
        { name = "Professions", header = true },
        { name = "Tailoring" }, { name = "Skinning" },
        { name = "Secondary Skills", header = true },
        { name = "First Aid" }, { name = "Defense" },
    }
end)
local P = ns.Professions
H.Check(P.known.tailoring and P.known.skinning and P.known.firstaid, "professions read at login")
H.Check(not P.known.defense, "weapon and other skills ignored")
H.Equal(P.Describe(), "Tailoring, Skinning, First Aid", "readable list in a fixed order")
H.Check(P.own[2589], "Linen Cloth is a tailoring material")
H.Check(P.own[2318], "Light Leather is gathered by skinning")
H.Check(not P.own[2770], "Copper Ore is not a material of these professions")
H.Check(ForeverJunkItemsCharDB.professions.tailoring, "saved per character")

-- A folded header hides its lines: the saved professions are kept.
H.skills = { { name = "Professions", header = true, expanded = false }, { name = "Secondary Skills", header = true } }
H.Fire("SKILL_LINES_CHANGED")
H.Check(P.known.tailoring and P.known.skinning, "folded header keeps the known professions")
-- Everything open and a profession dropped: it is forgotten.
H.skills = { { name = "Professions", header = true }, { name = "Skinning" } }
H.Fire("SKILL_LINES_CHANGED")
H.Check(not P.known.tailoring and P.known.skinning, "unlearned profession forgotten when the list is complete")
H.Check(not ForeverJunkItemsCharDB.professions.tailoring, "and removed from the saved record")

-- Other client languages.
H.skills = { { name = "Schneiderei" }, { name = "Minage" } }
H.Fire("SKILL_LINES_CHANGED")
H.Check(P.known.tailoring and P.known.mining, "German and French names recognised")
H.Check(P.own[2770], "a miner keeps Copper Ore")

-- Generated data sanity.
local M = ns.Materials
H.Check(type(M.BUILD) == "string" and M.BUILD:match("^1%.60%.1%.%d+$"), "data built from a Forever 1.60.1 build")
for _, key in ipairs({ "alchemy", "blacksmithing", "cooking", "enchanting", "engineering", "firstaid",
    "leatherworking", "mining", "tailoring" }) do
    H.Check(type(M.USES[key]) == "string" and #M.USES[key] > 20, "materials listed for " .. key)
end
for _, key in ipairs({ "herbalism", "mining", "skinning" }) do
    H.Check(type(M.GATHERS[key]) == "string" and #M.GATHERS[key] > 20, "gathered items listed for " .. key)
end
local mats = P.MaterialsFor({ cooking = true })
H.Check(mats[2672], "Stringy Wolf Meat is a cooking material")
H.Check(P.MaterialsFor({ herbalism = true })[2447], "Peacebloom is gathered by herbalism")
H.Done("test_professions")
