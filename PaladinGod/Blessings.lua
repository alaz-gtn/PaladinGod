local _, ns = ...
local L = ns.L

-- Who in your group lacks your blessing, out of combat: a row each, missing ones first, then the
-- ones running out. A click on a row blesses that player with the blessing for their class (one
-- per paladin on each player; in Forever they last an hour). Another paladin's blessing of the
-- same kind counts: yours wouldn't go on top of it. Out of combat only: the game hides everyone's
-- buffs in a fight, and doesn't let addons change these buttons then
local ROW, ROW_GAP = 22, 2
local DEFAULT_POINT = { "CENTER", "CENTER", -330, 80 }
local TICK = 1

local db
local holder
local rows = {}
local inCombat = false
local byName = {} -- blessing name (normal or greater) -> key
local known = {}
local cache = {} -- by unit: { mine = { key, ends } or nil, others = { [key] = true } }
ns.CLASS_ORDER = { "WARRIOR", "ROGUE", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "PRIEST", "MAGE", "WARLOCK" }

local function Learn()
	wipe(byName)
	for key, ids in pairs(ns.BLESSING_SPELLS) do
		local name = ns.SpellName(ids[1])
		if name then byName[name] = key end
		known[key] = ns.Knows(ids)
	end
	for key, ids in pairs(ns.GREATER_BLESSINGS) do
		local name = ns.SpellName(ids[1])
		if name then byName[name] = key end
	end
end

-- The blessing a class gets: the one set for it, or, when that one isn't learned yet, the first you
-- know of what suits it: Might for those who fight with their weapons, Wisdom for the rest
local MELEE = { WARRIOR = true, ROGUE = true }
local function ForClass(class)
	local want = db.classes[class] or "wisdom"
	if want == "none" then return end
	if known[want] then return want end
	for _, key in ipairs(MELEE[class] and { "might", "wisdom", "kings" } or { "wisdom", "might", "kings" }) do
		if known[key] then return key end
	end
end

-- The players in your group, without you
local function Members()
	local list = {}
	if IsInRaid and IsInRaid() then
		for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
			local unit = "raid" .. i
			if not UnitIsUnit(unit, "player") then list[#list + 1] = unit end
		end
	elseif IsInGroup() then
		for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 4) do
			list[#list + 1] = "party" .. i
		end
	end
	return list
end

-- One player's blessings: yours (and until when), and the kinds others put on them
local function Read(unit)
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local entry = { others = {} }
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) or ns.IsSecret(aura.expirationTime) then return end
		local key = byName[aura.name]
		if key then
			local expires = aura.expirationTime
			entry.mine = { key = key, ends = type(expires) == "number" and expires > 0 and expires or math.huge }
			break
		end
	end
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) then return end
		local key = byName[aura.name]
		if key then entry.others[key] = true end
	end
	cache[unit] = entry
	return entry
end

local function Answer(v)
	if ns.IsSecret(v) then return nil end
	if v == true or v == 1 then return true end
	if v == false or v == 0 then return false end
end

-- What to show: { unit, name, class, key, left (0 when missing), far }
local function Missing()
	local list = {}
	local now, warnAt = GetTime(), ns.db.buffs.warnMinutes * 60
	for _, unit in ipairs(Members()) do
		local dead = UnitIsDeadOrGhost(unit)
		if ns.IsSecret(dead) then dead = false end
		local online = not UnitIsConnected or UnitIsConnected(unit)
		if ns.IsSecret(online) then online = true end
		if UnitExists(unit) and online and not dead then
			local _, class = UnitClass(unit)
			local want = class and ForClass(class)
			local entry = cache[unit] or Read(unit)
			if want and entry then
				local left
				if entry.mine then
					left = max(entry.mine.ends - now, 0)
					if left > warnAt then left = nil end
				elseif not entry.others[want] then
					left = 0
				end
				if left then
					local key = entry.mine and entry.mine.key or want
					local spell = ns.SpellName(ns.BLESSING_SPELLS[key][1])
					local reach = C_Spell and C_Spell.IsSpellInRange and Answer(C_Spell.IsSpellInRange(spell, unit))
					list[#list + 1] = { unit = unit, name = UnitName(unit) or unit, class = class, key = key, left = left,
						spell = spell, far = reach == false }
				end
			end
		end
	end
	-- Missing first, then the ones running out soonest, then by name
	table.sort(list, function(a, b)
		if (a.left == 0) ~= (b.left == 0) then return a.left == 0 end
		if a.left ~= b.left then return a.left < b.left end
		return a.name < b.name
	end)
	return list
end

local function Row_OnEnter(self)
	if not self.spell then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.who or "?", 1, 1, 1)
	GameTooltip:AddLine(format(L.CLICK_CAST, self.spell), 0.4, 0.7, 1)
	if self.far then GameTooltip:AddLine(L.GROUP_FAR, 1, 0.5, 0.4) end
	GameTooltip:Show()
end

local function Row(i)
	local b = rows[i]
	if b then return b end
	b = CreateFrame("Button", "PaladinGodGroup" .. i, holder, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	ns.DarkRow(b)
	b.time = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.time:SetPoint("RIGHT", -6, 0)
	b.time:SetShadowOffset(1, -1)
	b.time:SetShadowColor(0, 0, 0, 1)
	b.time:SetTextColor(1, 0.85, 0.4)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	b:SetScript("OnEnter", Row_OnEnter)
	b:SetScript("OnLeave", GameTooltip_Hide)
	rows[i] = b
	return b
end

local function ClassColor(class)
	local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function SetAction(b, r)
	local spell, unit = r and r.spell, r and r.unit
	local kind = spell and "spell" or nil
	if b:GetAttribute("type") ~= kind then b:SetAttribute("type", kind) end
	if b:GetAttribute("spell") ~= spell then b:SetAttribute("spell", spell) end
	if b:GetAttribute("unit") ~= unit then b:SetAttribute("unit", unit) end
end

local function Samples()
	local now = { { name = "Arthas", class = "WARRIOR", key = "might", left = 0 },
		{ name = "Jaina", class = "MAGE", key = "wisdom", left = 0 },
		{ name = "Uther", class = "PALADIN", key = "wisdom", left = 75 } }
	for _, r in ipairs(now) do r.spell = ns.SpellName(ns.BLESSING_SPELLS[r.key][1]) end
	return now
end

function ns.UpdateGroup()
	if not holder or InCombatLockdown() then return end
	local list
	if ns.unlocked then
		list = db.enabled and ns.IsPaladin() and Samples() or {}
	elseif db.enabled and ns.IsPaladin() and not inCombat and not ns.Away() then
		list = Missing()
	else
		list = {}
	end
	local more = #list - db.maxRows
	local width, y = 140, 0
	local shown = min(#list, db.maxRows)
	for i = 1, shown do
		local r = list[i]
		local b = Row(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -y)
		b:SetHeight(ROW)
		y = y + ROW + ROW_GAP
		b.icon:SetTexture(ns.SpellIcon(ns.BLESSING_SPELLS[r.key][1]))
		b.icon:SetDesaturated(r.left == 0)
		ns.ThinFont(b.text, 13)
		ns.ThinFont(b.time, 12)
		b.text:SetText(r.name)
		b.text:SetTextColor(ClassColor(r.class))
		b.stripe:SetColorTexture(ClassColor(r.class))
		b.time:SetText(r.left > 0 and ns.Clock(r.left) or "")
		b:SetAlpha(r.far and 0.5 or 1)
		b.spell, b.who, b.far = r.spell, r.name, r.far
		SetAction(b, not ns.unlocked and r or nil)
		width = max(width, b.text:GetStringWidth() + b.time:GetStringWidth() + ROW + 34)
		b:Show()
	end
	-- Too many for the list: how many more
	local last = shown
	if more > 0 then
		last = shown + 1
		local b = Row(last)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -y)
		b:SetHeight(ROW)
		y = y + ROW + ROW_GAP
		b.icon:SetTexture(nil)
		ns.ThinFont(b.text, 13)
		b.text:SetText(format(L.GROUP_MORE, more))
		b.text:SetTextColor(0.7, 0.7, 0.7)
		b.time:SetText("")
		b:SetAlpha(1)
		b.spell, b.who, b.far = nil, nil, nil
		SetAction(b, nil)
		b:Show()
	end
	for i = 1, last do rows[i]:SetWidth(width) end
	for i = last + 1, #rows do
		SetAction(rows[i], nil)
		rows[i]:Hide()
	end
	holder:SetSize(width, max(y - ROW_GAP, ROW))
	holder:SetShown(last > 0)
end

-- For the tests
function ns.GroupState()
	return { holder = holder, rows = rows, cache = cache }
end

local function IsGroupUnit(unit)
	return type(unit) == "string" and (unit:match("^party%d+$") or unit:match("^raid%d+$")) and true or false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.group
		holder = CreateFrame("Frame", "PaladinGodGroup", UIParent)
		holder:SetSize(140, ROW)
		holder:Hide()
		ns.Movable(holder, "group", DEFAULT_POINT, L.GROUP_NAME)
		Learn()
		table.insert(ns.refreshers, function()
			wipe(cache)
			ns.UpdateGroup()
		end)
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		pcall(self.RegisterEvent, self, "UNIT_CONNECTION")
		pcall(self.RegisterEvent, self, "PLAYER_DEAD")
		pcall(self.RegisterEvent, self, "PLAYER_UNGHOST")
		-- The times left and who's in reach, now and then
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < TICK then return end
			since = 0
			if not inCombat then ns.UpdateGroup() end
		end)
	elseif event == "UNIT_AURA" then
		if not IsGroupUnit(unit) or inCombat then return end
		Read(unit)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
		-- The numbers point at other players now
		wipe(cache)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		-- The last moment the game lets the list go
		holder:Hide()
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		wipe(cache)
	elseif event == "SPELLS_CHANGED" then
		Learn()
	end
	ns.UpdateGroup()
end)
