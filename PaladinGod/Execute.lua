local _, ns = ...
local L = ns.L

-- Three icons above your character when a spell has its moment:
-- - Hammer of Wrath (from level 44): only usable on an enemy at 20% health or less. In combat
--   Forever hides your target's health, but lets the addon hand the game a curve: the icon's
--   opacity is 1 under the line and 0 above it, and the game works it out itself (as HunterGod's
--   pet health warning does)
-- - Exorcism (from level 20): only works on undead and demons
-- - Hammer of Justice while your target casts: a paladin has no interrupt in Classic, but the stun
--   stops the cast. Forever hides what a target casts in combat, but not that it casts: of what
--   UnitCastingInfo and UnitChannelInfo give, isTradeskill is never hidden and only comes while it
--   casts. Within the hammer's 10 yards, when the game says
-- None shows while its spell is cooling down. Each has its own place: Exorcism on the left, Hammer
-- of Justice in the middle, Hammer of Wrath on the right
local HAMMER = { 24275, 24274, 24239 }
local EXORCISM = { 879, 5614, 5615, 10312, 10313, 10314 }
local JUSTICE = { 853, 5588, 5589, 10308 }
local LINE = 0.2 -- Hammer of Wrath's 20%
local GAP = 12
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 150 }
local POLL = 0.1
-- The kinds of creature Exorcism works on, as the game names them (the English and the Spanish client)
local EXORCISABLE = { Undead = true, Demon = true, ["No-muerto"] = true, Demonio = true }
-- For telling its own cooldown from the global one (Hammer of Justice: a minute, 45 sec with its talent)
local COOLDOWN = { hammer = 6, exorcism = 15, justice = 45 }
local PLACE = { exorcism = -1, justice = 0, hammer = 1 }

local db
local holder
local icons = {} -- hammer, exorcism, justice
local known = {}
local castAt = {} -- by key: when you cast it last
local creature -- your target's kind: true for undead or demon, false otherwise, nil unknown
local curve
local testUntil = 0

local function Learn()
	known.hammer = ns.Knows(HAMMER)
	known.exorcism = ns.Knows(EXORCISM)
	known.justice = ns.Knows(JUSTICE)
end

-- A curve for the game: 1 at or under 20%, 0 above
local function Curve()
	if curve == nil then
		curve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve then
			curve = C_CurveUtil.CreateCurve()
			if Enum and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Linear) end
			curve:AddPoint(0, 1)
			curve:AddPoint(LINE, 1)
			curve:AddPoint(LINE + 0.0005, 0)
			curve:AddPoint(1, 0)
		end
	end
	return curve or nil
end

-- Its opacity for your target's health: a number, or a hidden one only the game can use. nil when
-- nothing says
local function UnderLine()
	local health, most = UnitHealth("target"), UnitHealthMax("target")
	if not ns.IsSecret(health) and not ns.IsSecret(most) and type(health) == "number" and type(most) == "number" and most > 0 then
		return health / most <= LINE and 1 or 0
	end
	if UnitHealthPercent and Curve() then return UnitHealthPercent("target", false, Curve()) end
end

-- The highest rank you know
local function Rank(ids)
	local id = ids[1]
	for _, rank in ipairs(ids) do
		local k = IsPlayerSpell and IsPlayerSpell(rank)
		if not ns.IsSecret(k) and k then id = rank end
	end
	return id
end

-- The game says you can't cast it now (not enough mana, or a target over 20% for the hammer). Its
-- documentation doesn't mark this one as hidden in combat; when it is, or says nothing, it doesn't count
local function Unusable(ids)
	if not (C_Spell and C_Spell.IsSpellUsable) then return false end
	local ok, usable = pcall(C_Spell.IsSpellUsable, Rank(ids))
	if not ok or ns.IsSecret(usable) or usable == nil then return false end
	return not usable
end

-- Is it cooling down (its own cooldown, not the global one)?
local function Cooling(ids, key)
	local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(Rank(ids))
	if ns.IsSecret(info) or type(info) ~= "table" then return false end
	local active = info.isActive
	if ns.IsSecret(active) or active == nil then
		local d = info.duration
		if ns.IsSecret(d) or d == nil then return false end
		active = d > 0
	end
	if not active then return false end
	local d = info.duration
	if not ns.IsSecret(d) and d ~= nil then return d > 1.6 end
	local gcd = info.isOnGCD
	if not ns.IsSecret(gcd) and gcd ~= nil then return not gcd end
	-- The game won't say whose cooldown it is: by when you cast it
	return castAt[key] ~= nil and GetTime() - castAt[key] < COOLDOWN[key]
end

local function Enemy()
	return ns.EnemyTarget()
end

-- Your target casting or channelling something: isTradeskill comes, never hidden, only while it does
local function Casting()
	local tradeskill = UnitCastingInfo and select(6, UnitCastingInfo("target"))
	if tradeskill == nil and UnitChannelInfo then tradeskill = select(6, UnitChannelInfo("target")) end
	if ns.IsSecret(tradeskill) then return true end
	return tradeskill == false
end

-- Within the spell's reach, unless the game says it isn't
local function InReach(ids)
	if not (C_Spell and C_Spell.IsSpellInRange) then return true end
	local within = C_Spell.IsSpellInRange(ns.SpellName(ids[1]), "target")
	if ns.IsSecret(within) or within == nil then return true end
	return within == true or within == 1
end

-- Your target's kind, read as you target it: the game may hide it in combat
local function ReadCreature()
	local kind = UnitCreatureType and UnitCreatureType("target")
	if ns.IsSecret(kind) or kind == nil then
		creature = nil
	else
		creature = EXORCISABLE[kind] or false
	end
end

local function Set(icon, show, alpha)
	icon:SetShown(show)
	if show then
		icon:SetAlpha(alpha)
		if not icon.glowing:IsPlaying() then icon.glowing:Play() end
	else
		icon.glowing:Stop()
	end
end

function ns.UpdateExecute()
	if not holder then return end
	local sample = ns.unlocked or GetTime() < testUntil
	local on = ns.IsPaladin() and not ns.Away()
	local enemy = on and Enemy()
	-- Exorcism: an undead or a demon targeted, and Exorcism ready
	local exo = sample and db.exorcism
		or (enemy and db.exorcism and known.exorcism and creature == true and not Cooling(EXORCISM, "exorcism")
			and not Unusable(EXORCISM))
	Set(icons.exorcism, exo and true or false, 1)
	-- Hammer of Justice: your target casting, the hammer ready and within reach
	local stop = sample and db.interrupt
		or (enemy and db.interrupt and known.justice and Casting() and not Cooling(JUSTICE, "justice")
			and not Unusable(JUSTICE) and InReach(JUSTICE))
	Set(icons.justice, stop and true or false, 1)
	-- Hammer of Wrath: your target at 20% or under, and the hammer ready. The game says when
	if sample and db.hammer then
		Set(icons.hammer, true, 1)
	elseif enemy and db.hammer and known.hammer and not Cooling(HAMMER, "hammer") and not Unusable(HAMMER) then
		-- A hidden value can't even be compared with nil: ask first. One the addon can read says it all
		local alpha = UnderLine()
		if ns.IsSecret(alpha) then
			Set(icons.hammer, true, alpha)
		else
			Set(icons.hammer, alpha == 1, 1)
		end
	else
		Set(icons.hammer, false)
	end
	holder:SetShown(icons.exorcism:IsShown() or icons.hammer:IsShown() or icons.justice:IsShown())
end

function ns.StyleExecute()
	if not holder then return end
	local size = db.size
	holder:SetSize(size * 3 + GAP * 2, size)
	for key, icon in pairs(icons) do
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", holder, "CENTER", PLACE[key] * (size + GAP), 0)
		icon.box:SetSize(size, size)
		icon.shine:SetSize(size * 2.2, size * 2.2)
		ns.ReEdge(icon.box)
		ns.UseFont(icon.box.text, ns.FONTS[ns.db.range.font], max(floor(size * 0.3), 10), "THICKOUTLINE")
	end
	ns.UpdateExecute()
end

-- /paladingod martillo: both for a few seconds
function ns.TestExecute()
	testUntil = GetTime() + 4
	ns.UpdateExecute()
	C_Timer.After(4.1, ns.UpdateExecute)
end
ns.commands.hammer = ns.TestExecute
ns.commands.martillo = ns.TestExecute
ns.commands.exorcism = ns.TestExecute
ns.commands.exorcismo = ns.TestExecute

-- For the tests
function ns.ExecuteState()
	return { holder = holder, hammer = icons.hammer, exorcism = icons.exorcism, justice = icons.justice, creature = creature }
end

-- One icon. Its opacity may be the game's own (hidden) number, so what breathes goes in a frame of
-- its own inside it: an animation can't share a frame with a hidden opacity
local function Icon(key, spell)
	local icon = CreateFrame("Frame", nil, holder)
	icon.key = key
	local inner = CreateFrame("Frame", nil, icon)
	inner:SetAllPoints(icon)
	icon.shine = inner:CreateTexture(nil, "BACKGROUND")
	icon.shine:SetPoint("CENTER")
	icon.shine:SetTexture("Interface\\AddOns\\PaladinGod\\media\\proc_spot")
	icon.shine:SetBlendMode("ADD")
	-- Gold, and the hammer that stops a cast in orange
	if key == "justice" then icon.shine:SetVertexColor(1, 0.45, 0.15) else icon.shine:SetVertexColor(1, 0.8, 0.3) end
	icon.box = CreateFrame("Frame", nil, inner)
	icon.box:SetPoint("CENTER")
	ns.StyleReminder(icon.box)
	icon.box.icon:SetTexture(ns.SpellIcon(spell))
	icon.box.text:SetTextColor(1, 0.85, 0.35)
	-- The hammer's moment, under it; Exorcism's icon says it alone
	icon.box.text:SetText(key == "hammer" and L.HAMMER_WORD or key == "justice" and L.INTERRUPT_WORD or "")
	icon.glowing = inner:CreateAnimationGroup()
	icon.glowing:SetLooping("BOUNCE")
	local fade = icon.glowing:CreateAnimation("Alpha")
	fade:SetTarget(icon.shine)
	fade:SetFromAlpha(0.25)
	fade:SetToAlpha(0.8)
	fade:SetDuration(0.5)
	icon:Hide()
	icons[key] = icon
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.execute
		holder = CreateFrame("Frame", "PaladinGodExecute", UIParent)
		holder:SetSize(108, 48)
		holder:Hide()
		Icon("exorcism", EXORCISM[1])
		Icon("hammer", HAMMER[1])
		Icon("justice", JUSTICE[1])
		Learn()
		ReadCreature()
		ns.Movable(holder, "execute", DEFAULT_POINT, L.EXECUTE_NAME)
		table.insert(ns.refreshers, ns.StyleExecute)
		ns.StyleExecute()
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		pcall(self.RegisterUnitEvent, self, "UNIT_HEALTH", "target")
		-- Your target starting or stopping a cast
		for _, name in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
			"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
			pcall(self.RegisterUnitEvent, self, name, "target")
		end
		-- Cooldowns and health move all the time: a quick look while there's an enemy targeted
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < POLL then return end
			since = 0
			if holder:IsShown() or UnitExists("target") or GetTime() < testUntil + 0.5 then ns.UpdateExecute() end
		end)
		return
	elseif event == "PLAYER_TARGET_CHANGED" then
		ReadCreature()
	elseif event == "SPELLS_CHANGED" then
		Learn()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" then
			ns.UpdateExecute()
			return
		end
		if not spellID or ns.IsSecret(spellID) then return end
		local name = ns.SpellName(spellID)
		if name == ns.SpellName(HAMMER[1]) then castAt.hammer = GetTime() end
		if name == ns.SpellName(EXORCISM[1]) then castAt.exorcism = GetTime() end
		if name == ns.SpellName(JUSTICE[1]) then castAt.justice = GetTime() end
	end
	ns.UpdateExecute()
end)
