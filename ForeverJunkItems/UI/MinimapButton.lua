-- Round button on the minimap edge, as in Forever One Button.
--
-- Left-click opens or closes the options, right-click turns the filter on or
-- off, dragging moves the button around the minimap. Shown state and angle
-- are saved in ForeverJunkItemsDB.minimap; "Show minimap button" in the
-- options hides it. A plain button: nothing protected, usable in combat.
local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\ForeverJunkItems\\Media\\icon"
-- The bag inside the logo's gold frame.
MinimapButton.ICON_CROP = { 0.1, 0.9, 0.06, 0.86 }
local SIZE = 31
local button

-- Offset from the minimap centre for an angle in degrees, just outside the
-- round edge.
function MinimapButton.Offset(angle, minimapWidth)
    local radius = (minimapWidth or 140) / 2 + 10
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

-- Angle in degrees (0-359) of a point relative to the minimap centre.
function MinimapButton.AngleOf(dx, dy)
    local angle = math.deg(math.atan2(dy, dx))
    if angle < 0 then angle = angle + 360 end
    return math.floor(angle + 0.5) % 360
end

local function place()
    local x, y = MinimapButton.Offset(ns.db.minimap.angle, Minimap:GetWidth())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function dragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and cx and scale and scale > 0) then return end
    ns.db.minimap.angle = MinimapButton.AngleOf(cx / scale - mx, cy / scale - my)
    place()
end

local function showTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.TITLE, 1, 0.82, 0)
    local on = ns.db.enabled
    GameTooltip:AddLine(on and "Filter: on" or "Filter: off", on and 0.2 or 1, on and 1 or 0.3, on and 0.2 or 0.3)
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    GameTooltip:AddLine(on and "Right-click: turn the filter off" or "Right-click: turn the filter on", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- What a click does; split out so it can be tested without a client.
function MinimapButton.Click(mouseButton)
    if mouseButton == "RightButton" then
        ns.Control.SetEnabled(not ns.db.enabled)
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    elseif ns.UI.IsShown() then
        ns.UI.Close()
    else
        ns.UI.Open()
    end
end

local function build()
    button = CreateFrame("Button", "ForeverJunkItemsMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ICON)
    button.icon:SetTexCoord(unpack(MinimapButton.ICON_CROP))
    button.icon:SetSize(19, 19)
    button.icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    end

    button:SetScript("OnClick", function(self, mouseButton)
        MinimapButton.Click(mouseButton)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then showTooltip(self) end
    end)
    button:SetScript("OnDragStart", function(self)
        if GameTooltip then GameTooltip:Hide() end
        self:SetScript("OnUpdate", dragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- Creates the button on first use, then shows it in place or hides it.
function MinimapButton.Apply()
    if not Minimap or not ns.db then return end
    if not ns.db.minimap.shown then
        if button then button:Hide() end
        return
    end
    if not button then build() end
    place()
    button:Show()
end

function MinimapButton.SetShown(shown)
    ns.db.minimap.shown = shown and true or false
    MinimapButton.Apply()
end

function MinimapButton.IsShown()
    return button ~= nil and button:IsShown()
end
