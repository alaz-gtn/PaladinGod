local _, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\PaladinGod\\media\\icon"
-- The paladin's reagents: for the Greater Blessings and for Divine Intervention
local REAGENTS = { 21177, 17033 } -- Symbol of Kings, Symbol of Divinity

local db
local button = CreateFrame("Button", "PaladinGodMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetTexture(ICON)
icon:SetPoint("TOPLEFT", 7, -5)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT")

local function Place()
	local angle = math.rad(db.angle)
	local radius = Minimap:GetWidth() / 2 + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Dragging moves the button around the edge of the minimap
local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	db.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
	Place()
end

button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

button:SetScript("OnClick", function(_, mouse)
	if mouse == "RightButton" then
		ns.SetUnlocked(not ns.unlocked)
	elseif ns.ToggleOptions then
		ns.ToggleOptions()
	end
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("PaladinGod")
	-- The reagents you carry
	if ns.IsPaladin() then
		local count = C_Item and C_Item.GetItemCount or GetItemCount
		for _, item in ipairs(REAGENTS) do
			local have = count and count(item) or 0
			if not ns.IsSecret(have) and have > 0 then
				local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item) or "?"
				GameTooltip:AddLine(format(L.TIP_REAGENT, name, have), 1, 1, 1)
			end
		end
	end
	GameTooltip:AddLine(L.TIP_LEFT, 0.4, 0.7, 1)
	GameTooltip:AddLine(ns.unlocked and L.TIP_RIGHT_LOCK or L.TIP_RIGHT_UNLOCK, 0.4, 0.7, 1)
	GameTooltip:AddLine(L.TIP_DRAG, 0.6, 0.6, 0.6)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.UpdateMinimapButton()
	button:SetShown(not db.hide)
	Place()
end

local function ToggleButton()
	db.hide = not db.hide
	ns.UpdateMinimapButton()
end
ns.commands.button = ToggleButton
ns.commands.boton = ToggleButton
ns.commands["botón"] = ToggleButton

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	db = ns.db.minimapButton
	ns.UpdateMinimapButton()
end)
