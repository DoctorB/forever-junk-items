-- Manifest, namespace and package identity.
local H = dofile("tests/harness/wow.lua")
local files, fields = H.ReadToc("ForeverJunkItems/ForeverJunkItems.toc")
H.Equal(fields.Interface, "16001", "WoW Forever interface")
H.Equal(fields.Title, "Forever Junk Items", "title")
H.Equal(fields.SavedVariables, "ForeverJunkItemsDB", "account settings")
H.Equal(fields.SavedVariablesPerCharacter, "ForeverJunkItemsCharDB", "per-character professions")
H.Equal(fields.IconTexture, [[Interface\AddOns\ForeverJunkItems\Media\icon]], "add-on list icon")
H.Equal(fields["X-License"], "MIT", "license field")
local icon = io.open("ForeverJunkItems/Media/icon.tga", "rb")
H.Check(icon ~= nil, "icon file exists")
if icon then
    local header = icon:read(18)
    icon:close()
    -- Uncompressed true-colour TGA, 64x64, 32 bits: what the client loads.
    H.Check(header:byte(3) == 2 and header:byte(13) == 64 and header:byte(15) == 64 and header:byte(17) == 32,
        "icon is an uncompressed 64x64 32-bit TGA")
end
H.Equal(fields.Dependencies, nil, "no dependency")
H.Equal(fields.OptionalDeps, nil, "no optional dependency")
H.Check(fields.Version:match("^%d+%.%d+%.%d+$") or fields.Version:match("^%d+%.%d+%.%d+%-alpha%.%d+$")
    or fields.Version:match("^%d+%.%d+%.%d+%-beta%.%d+$"), "semantic version (optional -alpha.N / -beta.N)")

local ns = H.Boot()
H.Equal(ns.VERSION, fields.Version, "runtime version matches TOC")
H.Equal(ns.NAME, "ForeverJunkItems", "technical identifier")
H.Equal(ns.TITLE, fields.Title, "runtime title matches TOC")

-- Every listed file exists; every shipped Lua file is listed.
local listed = {}
for _, file in ipairs(files) do
    listed[file] = true
    H.Check(io.open("ForeverJunkItems/" .. file, "rb") ~= nil, "listed file exists: " .. file)
end
local finder = package.config:sub(1, 1) == "\\" and 'dir /b /s /a-d ForeverJunkItems | findstr /e .lua'
    or 'find ForeverJunkItems -name "*.lua"'
local count = 0
for path in io.popen(finder):lines() do
    path = path:gsub("\\", "/"):match("ForeverJunkItems/(.*)$")
    H.Check(listed[path], "unlisted Lua file shipped: " .. tostring(path))
    count = count + 1
end
H.Equal(count, #files, "no orphan Lua files")

-- Globals the add-on creates: saved variables, slash command and named frames only.
local allowed = { ForeverJunkItemsDB = true, ForeverJunkItemsCharDB = true,
    SLASH_FOREVERJUNKITEMS1 = true, SLASH_FOREVERJUNKITEMS2 = true }
for name in pairs(_G) do
    if type(name) == "string" and (name:find("^ForeverJunkItems") or name:find("^SLASH_FOREVERJUNK")) then
        H.Check(allowed[name] or H.createdNames[name], "unexpected global " .. name)
    end
end

-- Lua 5.1 subset: nothing the client lacks.
for _, file in ipairs(files) do
    local source = assert(io.open("ForeverJunkItems/" .. file, "rb")):read("*a")
    for _, banned in ipairs({ "goto ", "require%(", "io%.", "os%.", "loadstring", "//" }) do
        if file ~= "Data/Materials.lua" or banned ~= "//" then
            H.Check(not source:find(banned), file .. " uses " .. banned)
        end
    end
end
H.Done("test_toc")
