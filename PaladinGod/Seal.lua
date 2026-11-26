local _, ns = ...
local L = ns.L

-- Your seal. In Forever a Judgement no longer uses the seal up, so a seal lasts its 30 seconds.
-- - Fighting without one (or about to, with an enemy targeted): a grey reminder in the row above
--   your character, like the others; a click casts your seal, out of combat. In combat Forever hides
--   your buffs, so the addon follows the seals you cast, and reads your buffs out of combat
-- - While one is on: its icon with the seconds it has left, on a spot of its own. Forever hides those
--   in combat, so the game draws it itself: an aura container watching your seals, its button with
--   the seal's icon and the seconds the game writes. Only if the game won't build it does the addon
--   draw it from what you cast
local SEALS = {
	righteousness = { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293 },
	crusader = { 21082, 20162, 20305, 20306, 20307, 20308 },
	command = { 20375, 20915, 20918, 20919, 20920 }, -- a talent
	justice = { 20164 },
	light = { 20165, 20347, 20348, 20349 },
	wisdom = { 20166, 20356, 20357 },
	fury = { 1311649, 1311656, 20163, 20419, 20421, 20422, 20423 }, -- Forever's, for shields
}
local SEAL_ORDER = { "righteousness", "crusader", "command", "justice", "light", "wisdom", "fury" }
ns.SEAL_SPELLS, ns.SEAL_ORDER = SEALS, SEAL_ORDER
local SEAL_TIME = 30
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -55 }

local db
local reminder -- the grey icon in the reminders' row
local place -- the spot you drag for the seconds: the game's drawing hangs from it
local base -- the addon's own drawing of them, when the game won't
local holder, container, watching, dressed -- the game's drawing of your real seal
local byName = {} -- seal name -> key
local known = {}
local sealEnds -- GetTime() when the seal the addon knows of runs out; false for none, nil while unknown
local sealKey
local lasts = SEAL_TIME
local inCombat = false
local pending -- something to build or fit once the fight is over

local function Learn()
	wipe(byName)
	for key, ids in pairs(SEALS) do
		local name = ns.SpellName(ids[1])
		if name then byName[name] = key end
		known[key] = ns.Knows(ids)
	end
end

local function KnowsAny()
	for _, key in ipairs(SEAL_ORDER) do
		if known[key] then return true end
	end
	return false
end

-- The seal a click casts: the one you chose, or the last you cast, or the first you know
local function Wanted()
	local pick = db.choice == "auto" and ns.db.lastSeal or db.choice
	if pick and known[pick] then return pick end
	for _, key in ipairs(SEAL_ORDER) do
		if known[key] then return key end
	end
end

-- Out of combat your buffs say which seal is on, and until when
local function Scan()
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
	local found
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) then return false end
		local key = byName[aura.name]
		if key then
			local expires, duration = aura.expirationTime, aura.duration
			if ns.IsSecret(expires) then return false end
			if not ns.IsSecret(duration) and type(duration) == "number" and duration > 0 then lasts = duration end
			found = { key = key, ends = type(expires) == "number" and expires > 0 and expires or math.huge }
			-- A seal with a number the addon doesn't watch yet: the game's drawing learns it
			local id = aura.spellId
			if not ns.IsSecret(id) and not ns.IsSecret(duration) and type(id) == "number" and type(duration) == "number"
				and duration > 0 then
				local listed = false
				for _, sid in ipairs(SEALS[key]) do
					if sid == id then listed = true end
				end
				if not listed and not db.learned[id] then
					db.learned[id] = key
					pending = true
				end
			end
			break
		end
	end
	sealEnds = found and found.ends or false
	sealKey = found and found.key
	return true
end

local function ShowReminder(key)
	local id = SEALS[key][1]
	reminder.icon:SetTexture(ns.SpellIcon(id))
	reminder.icon:SetDesaturated(true)
	reminder.text:SetText("")
	reminder.spellName = ns.SpellName(id)
	if not reminder:IsShown() then reminder:Show() end
	ns.SyncReminders()
end

local function HideReminder()
	reminder.spellName = nil
	if reminder:IsShown() then reminder:Hide() end
end

-- The addon's own drawing of your seal and its seconds
local function Paint(key, left)
	base.icon:SetTexture(ns.SpellIcon(SEALS[key][1]))
	base.text:SetText(format("%d", ceil(left)))
end

function ns.UpdateSeal()
	if not db then return end
	if ns.unlocked then
		-- Samples to drag: the reminder with the others, the seconds on their own spot
		local key = Wanted() or "righteousness"
		if db.enabled then
			ShowReminder(key)
			Paint(key, 18)
			base:Show()
		else
			HideReminder()
			base:Hide()
		end
		return
	end
	local on = db.enabled and ns.IsPaladin() and KnowsAny() and not ns.Away()
	local left = sealEnds and sealEnds ~= math.huge and max(sealEnds - GetTime(), 0) or 0
	local want = on and Wanted()
	-- Fighting, or about to, without a seal
	if want and left == 0 and (inCombat or (db.target and ns.EnemyTarget())) then
		ShowReminder(want)
	else
		HideReminder()
	end
	-- Its seconds: the game draws them; the addon only when the game won't
	if on and left > 0 and sealKey and not container then
		Paint(sealKey, left)
		base:Show()
	else
		base:Hide()
	end
end

-- /paladingod bufos tells which seal the addon knows of
function ns.SealReport()
	if sealEnds == nil then return L.BUFF_UNKNOWN end
	if not sealEnds or sealEnds <= GetTime() then return L.BUFF_NONE end
	return format(L.BUFF_LEFT, ns.SpellName(SEALS[sealKey][1]) or "?", ns.Clock(max(sealEnds - GetTime(), 0)))
end

-- Sizes and places what the addon can touch now; the game's drawing waits for the end of a fight
local function Fit()
	local size = db.size
	base:SetSize(size, size)
	ns.ReEdge(base)
	ns.UseFont(base.text, ns.FONTS[ns.db.range.font], max(floor(size * 0.42), 10), "THICKOUTLINE")
	-- The game's drawing hangs from the place: neither can be touched in a fight
	if InCombatLockdown() then
		pending = true
		ns.UpdateSeal()
		return
	end
	place:SetSize(size, size)
	if holder then
		holder:SetSize(size, size)
		holder:SetShown(db.enabled and true or false)
		if dressed then
			ns.ReEdge(dressed)
			pcall(ns.UseFont, dressed.text, ns.FONTS[ns.db.range.font], max(floor(size * 0.42), 10), "THICKOUTLINE")
		end
	end
	ns.UpdateSeal()
end
ns.StyleSeal = Fit

-- The container's button: the seal's icon in the reminders' thin black edge, and the seconds the
-- game writes
local function Dress(button)
	button:SetAllPoints(holder)
	button:EnableMouse(false)
	local d = button
	d.lines = {}
	for i = 1, 4 do
		d.lines[i] = button:CreateTexture(nil, "BORDER")
		d.lines[i]:SetColorTexture(0, 0, 0, 1)
	end
	ns.ReEdge(d)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pcall(button.SetIcon, button, icon)
	d.text = button:CreateFontString(nil, "OVERLAY")
	d.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	d.text:SetTextColor(1, 1, 1)
	ns.UseFont(d.text, ns.FONTS[ns.db.range.font], max(floor(db.size * 0.42), 10), "THICKOUTLINE")
	d.timed = ns.GameWritesSeconds(button, d.text)
	dressed = d
end

-- Every seal the container watches: Forever's ranks and any other the addon saw by those names
local function WatchList()
	local spells, ids = {}, {}
	local function Add(id)
		if spells[id] then return end
		spells[id] = true
		ids[#ids + 1] = id
	end
	for _, key in ipairs(SEAL_ORDER) do
		for _, id in ipairs(SEALS[key]) do Add(id) end
	end
	for id in pairs(db.learned) do Add(id) end
	table.sort(ids)
	return spells, table.concat(ids, ",")
end

-- Built out of combat. A list that changes builds a new one; containers can't be thrown away, so
-- the old one is switched off
local function Build()
	if InCombatLockdown() then
		pending = true
		return
	end
	if not (ns.IsPaladin() and CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return end
	local spells, list = WatchList()
	if list == watching then return end
	if container then
		pcall(container.SetEnabled, container, false)
		holder:Hide()
		holder, container, watching, dressed = nil, nil, nil, nil
	end
	local box = CreateFrame("Frame", nil, UIParent)
	box:SetSize(db.size, db.size)
	box:SetFrameStrata("MEDIUM")
	box:SetFrameLevel(base:GetFrameLevel() + 5)
	box:SetPoint("CENTER", place, "CENTER")
	local ok, aurasBox = pcall(CreateFrame, "AuraContainer", nil, box, "CustomAuraContainerTemplate")
	if not ok or not aurasBox then return end
	aurasBox:SetAllPoints(box)
	aurasBox:SetEnabled(false)
	aurasBox:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
	holder = box
	if not pcall(aurasBox.AddAuraSlot, aurasBox, "PaladinGodSeal", "HELPFUL", {
		candidateFilters = { includeSpellIDs = spells },
		initializeFrame = Dress,
	}) then
		holder = nil
		box:Hide()
		return
	end
	aurasBox:SetUnit("player")
	aurasBox:SetEnabled(true)
	container, watching = aurasBox, list
	Fit()
end

-- A seal you cast: on you for its 30 seconds, whatever was on before
local function Cast(spellID)
	local key = byName[ns.SpellName(spellID) or ""]
	if not key then return end
	ns.db.lastSeal = key
	known[key] = true
	if not Scan() then
		sealEnds, sealKey = GetTime() + lasts, key
	end
end

-- For the tests
function ns.SealState()
	return { place = place, base = base, reminder = reminder, holder = holder, container = container,
		dressed = dressed, ends = sealEnds, key = sealKey }
end

reminder = CreateFrame("Frame", "PaladinGodSealReminder", UIParent)
reminder:Hide()
ns.StyleReminder(reminder)
ns.AddReminder("seal", reminder, function()
	if inCombat then return end
	return reminder.spellName
end, function(tip)
	tip:AddLine(reminder.spellName or "?", 1, 1, 1)
	tip:AddLine(L.SEAL_MISSING, 1, 0.5, 0.4)
end)

place = CreateFrame("Frame", "PaladinGodSealPlace", UIParent)
place:SetSize(40, 40)
base = CreateFrame("Frame", "PaladinGodSeal", place)
base:SetPoint("CENTER")
base:SetFrameStrata("MEDIUM")
base:Hide()
ns.StyleReminder(base)
base.text:ClearAllPoints()
base.text:SetPoint("CENTER", base, "CENTER", 0, 0)
base.text:SetTextColor(1, 1, 1)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.seal
		Learn()
		Scan()
		ns.Movable(place, "seal", DEFAULT_POINT, L.SEAL_NAME)
		Build()
		Fit()
		table.insert(ns.refreshers, Fit)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("SPELLS_CHANGED")
		pcall(self.RegisterEvent, self, "PLAYER_DEAD")
		-- Its count ticks on its own
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < 0.2 then return end
			since = 0
			ns.UpdateSeal()
		end)
	elseif event == "UNIT_AURA" then
		Scan()
		if pending and not InCombatLockdown() then
			pending = false
			Build()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		Cast(spellID)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		Scan()
		if pending then
			pending = false
			Build()
			Fit()
		end
	elseif event == "SPELLS_CHANGED" then
		Learn()
		Build()
	elseif event == "PLAYER_DEAD" then
		sealEnds, sealKey = false, nil
	end
	ns.UpdateSeal()
end)
