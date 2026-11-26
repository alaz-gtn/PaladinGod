local _, ns = ...

-- Your effects on your enemies, beside each one's nameplate: small icons with the reminders' thin
-- black edge and the seconds left, which the game writes itself. Forever keeps auras from addons in
-- combat, so the game draws them, as HunterGod's Freezing Trap counter and ForeverAuras do: an aura
-- container on each nameplate token, with one slot for each kind, looking only at yours
-- ("HARMFUL|PLAYER") and only at the spells you know. Left of the health bar, nearest first:
-- - your Judgement (of the Crusader, Light, Wisdom or Justice)
-- - your stuns and the like: Hammer of Justice, Repentance, Turn Undead, Seal of Justice's stun
-- - Vindication (a Retribution talent: less attack power for the target)
local GROUPS = {
	{ key = "judgement", needs = { 20271 }, ids = {
		20188, 20300, 20301, 20302, 20303, 21183, 25942, 25943, 456496, -- of the Crusader
		20185, 20267, 20341, 20342, 20343, 20344, 20345, 20346, 25752, 25753, 28775, -- of Light
		20186, 20268, 20352, 20353, 20354, 20355, 25757, 25758, -- of Wisdom
		20184, 25944, 25945, -- of Justice
	} },
	{ key = "control", parts = {
		{ needs = { 853, 5588, 5589, 10308 }, ids = { 853, 5588, 5589, 10308, 1324513, 1324515, 1324516, 1324517 } }, -- Hammer of Justice
		{ needs = { 20066 }, ids = { 20066, 1324538 } }, -- Repentance
		{ needs = { 2878, 5627, 10326 }, ids = { 2878, 5627, 10326, 1324543, 1324545, 1324546 } }, -- Turn Undead
		{ needs = { 20164 }, ids = { 20170 } }, -- Seal of Justice's stun
	} },
	{ key = "vindication", needs = { 9452 }, ids = { 67, 440667 } },
}
ns.DEBUFF_GROUPS = GROUPS
local PLATES = 40 -- nameplate1 to nameplate40
local GAP = 3
local NONE = { [1] = true } -- a list matching no aura, for a slot with nothing to look for yet

local db
local slots = {} -- by nameplate number: { holder, container, plate, buttons }
local pending -- a change of what you know, waiting for the end of a fight

-- The spells one kind watches: those you know, as the slot's list. nil when none
local function Watched(group)
	local map, any = {}, false
	local parts = group.parts or { group }
	for _, part in ipairs(parts) do
		if ns.Knows(part.needs) then
			for _, id in ipairs(part.ids) do map[id] = true end
			any = true
		end
	end
	return any and map or nil
end

-- Next to the plate's health bar, not its wider click area
local function PlateBar(plate)
	local unitFrame = plate.UnitFrame
	local bar = unitFrame and (unitFrame.healthBar
		or unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
	return bar or plate
end

local function Place(unit)
	local slot = slots[tonumber(unit:match("^nameplate(%d+)$") or "")]
	if not slot then return end
	local holder = slot.holder
	-- A frame the game protects can't be moved in combat: it waits for the end of the fight
	if InCombatLockdown() and holder:IsProtected() then
		slot.pending = true
		return
	end
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
	if not (db.enabled and ns.IsPaladin() and plate) or plate:IsForbidden() then
		holder:Hide()
		return
	end
	if slot.plate ~= plate then
		holder:SetParent(plate)
		holder:ClearAllPoints()
		if pcall(holder.SetPoint, holder, "RIGHT", PlateBar(plate), "LEFT", -6, 0) then slot.plate = plate end
	end
	holder:Show()
	-- The token may name another mob now
	pcall(slot.container.UpdateAllAuras, slot.container)
end

-- A slot's button: the icon in a thin black edge, the seconds the game writes, at the kind's place
local function Dress(button, slot, index)
	local size = db.size
	button:SetSize(size, size)
	button:ClearAllPoints()
	button:SetPoint("RIGHT", slot.holder, "RIGHT", -(index - 1) * (size + GAP), 0)
	button:EnableMouse(false)
	button.lines = {}
	for i = 1, 4 do
		button.lines[i] = button:CreateTexture(nil, "BORDER")
		button.lines[i]:SetColorTexture(0, 0, 0, 1)
	end
	ns.ReEdge(button)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pcall(button.SetIcon, button, icon)
	button.timer = button:CreateFontString(nil, "OVERLAY")
	button.timer:SetPoint("CENTER", button, "CENTER", 0, 0)
	ns.UseFont(button.timer, ns.FONTS[ns.db.range.font], max(floor(size * 0.55), 9), "OUTLINE")
	button.timer:SetTextColor(1, 1, 1)
	button.timed = ns.GameWritesSeconds(button, button.timer)
	slot.buttons[#slot.buttons + 1] = button
end

-- What each slot looks at, out of combat: the spells you know of each kind, if you want that kind
local function Refilter()
	if InCombatLockdown() then
		pending = true
		return
	end
	for _, slot in pairs(slots) do
		for _, group in ipairs(GROUPS) do
			local map = db[group.key] and Watched(group) or NONE
			pcall(slot.container.SetAuraSlotCandidateFilters, slot.container, "PaladinGod" .. group.key, { includeSpellIDs = map })
		end
	end
end

-- Built out of combat, once; a build the game refuses is tried again when the fight ends
local function Build()
	if InCombatLockdown() or not (ns.IsPaladin() and CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return end
	local size = db.size
	for i = #slots + 1, PLATES do
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(#GROUPS * (size + GAP), size)
		holder:Hide()
		local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
		if not ok or not container then return end
		container:SetAllPoints(holder)
		container:SetEnabled(false)
		container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
		local slot = { holder = holder, container = container, buttons = {} }
		for index, group in ipairs(GROUPS) do
			local map = db[group.key] and Watched(group) or NONE
			local options = {
				candidateFilters = { includeSpellIDs = map },
				initializeFrame = function(button) Dress(button, slot, index) end,
			}
			-- Yours only; should the game not take that filter, any paladin's
			if not (pcall(container.AddAuraSlot, container, "PaladinGod" .. group.key, "HARMFUL|PLAYER", options)
				or pcall(container.AddAuraSlot, container, "PaladinGod" .. group.key, "HARMFUL", options)) then
				return
			end
		end
		container:SetUnit("nameplate" .. i)
		container:SetEnabled(true)
		slots[i] = slot
		Place("nameplate" .. i)
	end
end

function ns.UpdateDebuffs()
	if not db then return end
	Build()
	Refilter()
	for i in pairs(slots) do Place("nameplate" .. i) end
end

-- For the tests
function ns.DebuffsState()
	return { slots = slots }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.debuffs
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		table.insert(ns.refreshers, ns.UpdateDebuffs)
		Build()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Build()
		if pending then
			pending = false
			Refilter()
		end
		for i, slot in pairs(slots) do
			if slot.pending then
				slot.pending = nil
				Place("nameplate" .. i)
			end
		end
	elseif event == "SPELLS_CHANGED" then
		Refilter()
	elseif event == "NAME_PLATE_UNIT_ADDED" and not ns.IsSecret(unit) then
		Place(unit)
	end
end)
