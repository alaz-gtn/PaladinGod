local _, ns = ...
local L = ns.L

-- When one of your big cooldowns is back: its icon big in the middle of the screen, popping in and
-- fading fast, as MageGod's pulse for Blink. In combat Forever hides how long a cooldown has left,
-- but not whether it is running: the pulse comes when a spell goes from cooling down to ready.
-- A wait shorter than any global cooldown wasn't the spell's own, so it doesn't count. Only the
-- spells you know, each with its own switch. Two back at once come one after the other
-- gcd: it waits for the global cooldown (Wowhead's Forever data). Divine Favor, Templar's Bulwark and
-- Voice of Truth don't
local SPELLS = {
	{ key = "divineShield", ids = { 642, 1020 }, gcd = true }, -- Divine Shield
	{ key = "divineProtection", ids = { 498, 5573 }, gcd = true }, -- Divine Protection
	{ key = "layOnHands", ids = { 633, 2800, 10310 }, gcd = true }, -- Lay on Hands
	{ key = "protection", ids = { 1022, 5599, 10278 }, gcd = true }, -- Blessing of Protection
	{ key = "bulwark", ids = { 1311015 } }, -- Templar's Bulwark (Protection)
	{ key = "divineFavor", ids = { 20216 } }, -- Divine Favor (Holy)
	{ key = "repentance", ids = { 20066 }, gcd = true }, -- Repentance (Retribution)
	{ key = "justice", ids = { 853, 5588, 5589, 10308 }, gcd = true }, -- Hammer of Justice
	{ key = "voice", ids = { 1310897 } }, -- Voice of Truth (Forever's)
	{ key = "intervention", ids = { 19752 }, gcd = true }, -- Divine Intervention
}
ns.COOLDOWN_SPELLS = SPELLS
-- Spells with no cooldown of their own that wait for the global one, known from the first levels:
-- cooling down, it can only be the global cooldown or a silence
local REFERENCES = {
	{ key = "holyLight", ids = { 635 } }, -- Holy Light
	{ key = "righteousness", ids = { 21084, 20154 } }, -- Seal of Righteousness
}
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 80 }
local GCD_MAX = 2.5 -- no global cooldown lasts this long: a longer wait was the spell's own
local POLL = 0.1
-- The pulse: it pops in, holds, and fades while it grows
local POP, HOLD, FADE = 0.12, 0.3, 0.55
local SHINE = 0.5
local STAR = "Interface\\Cooldown\\star4"

local db
local place, art
local playing -- when the pulse on screen started
local queue = {} -- spells back while another pulse was on screen
local testing -- the spell the options' button shows

local function Resolve(entry)
	for _, id in ipairs(entry.ids) do
		local known = IsPlayerSpell and IsPlayerSpell(id)
		if not ns.IsSecret(known) and known then return id end
	end
	-- Forever may give it another number: the spellbook answers for its name
	local name = ns.SpellName(entry.ids[1])
	local info = name and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
	if not ns.IsSecret(info) and type(info) == "table" then
		local id = info.spellID
		if not ns.IsSecret(id) and id then return id end
		return entry.ids[1]
	end
end

-- Is it cooling down? nil when the game won't say
local function Cooling(spell)
	local info = C_Spell.GetSpellCooldown(spell)
	if ns.IsSecret(info) or type(info) ~= "table" then return nil end
	local active = info.isActive
	if ns.IsSecret(active) or active == nil then
		local duration = info.duration
		if ns.IsSecret(duration) or duration == nil then return nil end
		active = duration > 0
	end
	return active and true or false, info
end

-- Is the global cooldown running? nil when the game won't say. While it runs, any spell shows as
-- cooling down: that alone says nothing about its own cooldown
local GCD_SPELL = 61304
local function GlobalRunning()
	local info = C_Spell.GetSpellCooldown(GCD_SPELL)
	if ns.IsSecret(info) or type(info) ~= "table" then return nil end
	local active = info.isActive
	if ns.IsSecret(active) or active == nil then
		local duration = info.duration
		if ns.IsSecret(duration) or duration == nil then return nil end
		active = duration > 0
	end
	return active and true or false
end

-- Silenced, stunned, or your school locked out: the game shows every spell cooling down until it
-- ends, and that says nothing about their own cooldowns. nil when the game won't say
local function Locked(spell)
	if C_Spell.GetSpellLossOfControlCooldown then
		local _, duration = C_Spell.GetSpellLossOfControlCooldown(spell)
		if not ns.IsSecret(duration) and type(duration) == "number" and duration > 0 then return true end
	end
	if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount then
		local count = C_LossOfControl.GetActiveLossOfControlDataCount()
		if not ns.IsSecret(count) and type(count) == "number" then return count > 0 end
	end
end

-- In a fight the game may not say a thing about the global cooldown (61304 unread, or always "not
-- running"), and spells cast one after another chain it for longer than any one. While it runs, every
-- spell that waits for it shows cooling down at once; one of them ready says it isn't running, so
-- another one still cooling down is on its own cooldown. Read once per look, for all of them
local coolingNow = {}

-- Is it cooling down on its own? true: another one that waits for the global cooldown is ready.
-- false: all of them are cooling down, none on a cooldown of its own that we know of. nil when it
-- can't tell (it skips the global cooldown, or nothing else to compare with)
local function Alone(entry)
	if not entry.gcd then return nil end
	local any = false
	for _, other in ipairs(SPELLS) do
		if other ~= entry and other.gcd then
			local c = coolingNow[other.key]
			if c == false then return true end
			if c == true and not (other.real or other.own) then any = true end
		end
	end
	for _, other in ipairs(REFERENCES) do
		local c = coolingNow[other.key]
		if c == false then return true end
		if c == true then any = true end
	end
	if any then return false end
end

-- Is that its own cooldown and not the global one? nil when the game won't say
local function Own(spell, info)
	local duration = info.duration
	if not ns.IsSecret(duration) and duration ~= nil then return duration > 1.6 end
	local gcd = info.isOnGCD
	if not ns.IsSecret(gcd) and gcd ~= nil then return not gcd end
	if C_Spell.GetSpellCooldownDuration then
		local timer = C_Spell.GetSpellCooldownDuration(spell, true)
		local zero = timer and timer.IsZero and timer:IsZero()
		-- While the global one runs this may count it too: it can't tell then
		if not ns.IsSecret(zero) and zero ~= nil then
			if not zero and GlobalRunning() ~= false then return nil end
			return not zero
		end
	end
end

local function Draw(parent)
	local a = {}
	a.shine = parent:CreateTexture(nil, "BACKGROUND")
	a.shine:SetPoint("CENTER")
	a.shine:SetTexture(STAR)
	a.shine:SetBlendMode("ADD")
	a.shine:SetAlpha(0)
	a.box = CreateFrame("Frame", nil, parent)
	a.box:SetPoint("CENTER")
	a.edge = a.box:CreateTexture(nil, "BACKGROUND")
	a.edge:SetColorTexture(0, 0, 0, 1)
	a.icon = a.box:CreateTexture(nil, "ARTWORK")
	a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	a.edge:SetAllPoints(a.box)
	return a
end

-- How it looks t seconds in: its alpha, its size, and the shine's
local function Frame(t)
	local alpha, scale
	if t < POP then
		alpha, scale = t / POP, 0.6 + 0.4 * t / POP
	elseif t < POP + HOLD then
		alpha, scale = 1, 1
	else
		local f = min((t - POP - HOLD) / FADE, 1)
		alpha, scale = 1 - f, 1 + 0.3 * f
	end
	local shine = t < SHINE and (1 - t / SHINE) * 0.9 or 0
	return alpha, scale, shine, 0.8 + 1.2 * min(t / SHINE, 1)
end

local function Paint(alpha, scale, shine, shineScale)
	local size = db.size
	art.box:SetAlpha(alpha * db.alpha / 100)
	art.box:SetSize(size * scale, size * scale)
	local px = ns.OnePixel(place)
	art.icon:ClearAllPoints()
	art.icon:SetPoint("TOPLEFT", art.box, "TOPLEFT", px, -px)
	art.icon:SetPoint("BOTTOMRIGHT", art.box, "BOTTOMRIGHT", -px, px)
	art.shine:SetAlpha(shine * db.alpha / 100)
	art.shine:SetSize(size * 1.6 * shineScale, size * 1.6 * shineScale)
end

-- While unlocked it stays up to be dragged
local function Rest()
	if playing then return end
	place:SetSize(db.size, db.size)
	if ns.unlocked and db.enabled and ns.IsPaladin() then
		art.icon:SetTexture(ns.SpellIcon(SPELLS[1].ids[1]))
		place:Show()
		Paint(1, 1, 0, 1)
	else
		place:Hide()
	end
end

-- Its icon pops up now, or after the one on screen
function ns.PulseCooldown(spell)
	if not ns.IsPaladin() then return end
	if playing then
		queue[#queue + 1] = spell
		return
	end
	art.icon:SetTexture(ns.SpellIcon(spell))
	art.shine:SetVertexColor(db.color.r, db.color.g, db.color.b)
	playing = GetTime()
	place:SetSize(db.size, db.size)
	place:Show()
	Paint(Frame(0))
end

local function Animate()
	local t = GetTime() - playing
	if t >= POP + HOLD + FADE then
		playing = nil
		local nextSpell = table.remove(queue, 1)
		if nextSpell then
			ns.PulseCooldown(nextSpell)
			return
		end
		Rest()
		return
	end
	Paint(Frame(t))
end

function ns.StyleCooldowns()
	if not place then return end
	art.shine:SetVertexColor(db.color.r, db.color.g, db.color.b)
	Rest()
end

local function Wanted(entry)
	return db.enabled and db.spells[entry.key] and ns.IsPaladin()
end

-- Checks whether a spell is back
local function Check(entry)
	local spell = entry.spell
	if not spell then return end
	local now = GetTime()
	local cooling, info = Cooling(spell)
	if cooling == nil then
		entry.blind = entry.blind or now
		return
	end
	-- After a stretch where the game wouldn't say, what it says now may be old news
	local stale = entry.blind and now - entry.blind > 1
	entry.blind = nil
	-- Half a second more: the game may say the silence is over a moment before the spells
	if cooling and not entry.real and Locked(spell) then entry.lockedAt = now end
	local alone
	if cooling and not entry.real and not entry.own then alone = Alone(entry) end
	if cooling and not entry.real and entry.lockedAt and now - entry.lockedAt < 0.5 then
		-- What it shows now may be the silence's: its wait starts again when that is over
		entry.own, entry.since = false, now
	elseif alone == false then
		entry.since = now -- all of them at once: the global cooldown or a silence. Its wait starts afresh
	elseif cooling then
		if alone then entry.own, entry.real = true, true end
		local own = not entry.own and Own(spell, info)
		if own then entry.own, entry.real = true, true end
		-- Only the global cooldown, as the game says: its time doesn't count. Spells cast one after
		-- another chain them for longer than any one, and that isn't the spell's own coming back.
		-- In combat it may not say whose it is: while the global one runs, the wait doesn't start
		local global = not entry.own and own == nil and GlobalRunning()
		if entry.own then
			entry.since = entry.since or now
			entry.real = true
		elseif own == false or global and not entry.real then
			entry.since = now -- the global one, or maybe: its wait starts afresh
		else
			entry.since = entry.since or now
			if global == false then entry.real = true end -- the global one is over and it still cools down
		end
	elseif entry.since then
		if not stale and (entry.own or now - entry.since > GCD_MAX) and Wanted(entry) and not ns.Away() then
			ns.PulseCooldown(spell)
		end
		entry.since, entry.own, entry.real, entry.lockedAt = nil, false, nil, nil
	elseif entry.own and entry.castAt and now - entry.castAt > 1 then
		entry.own, entry.real = false, nil -- the cast never showed a cooldown
	end
end

-- One look at all of them: is any still to watch?
local function Look()
	for _, list in ipairs({ SPELLS, REFERENCES }) do
		for _, entry in ipairs(list) do
			local c
			if entry.spell and (entry.gcd or list == REFERENCES) then c = Cooling(entry.spell) end
			coolingNow[entry.key] = c
		end
	end
	local busy = false
	for _, entry in ipairs(SPELLS) do
		Check(entry)
		busy = busy or entry.since or entry.own
	end
	return busy
end

-- Watched often only while one is cooling down, or just cast
local poller = CreateFrame("Frame")
poller:Hide()
local waited = 0
poller:SetScript("OnUpdate", function(self, elapsed)
	waited = waited + elapsed
	if waited < POLL then return end
	waited = 0
	if not Look() then self:Hide() end
end)

local function Watch()
	if Look() then poller:Show() end
end

local function Learn()
	for _, entry in ipairs(SPELLS) do entry.spell = Resolve(entry) end
	for _, entry in ipairs(REFERENCES) do entry.spell = Resolve(entry) end
end

-- The options' button: one of them, or the first you know
function ns.TestCooldowns(key)
	local pick
	for _, entry in ipairs(SPELLS) do
		if (key and entry.key == key) or (not key and not pick and entry.spell) then pick = entry end
	end
	pick = pick or SPELLS[1]
	ns.PulseCooldown(pick.spell or pick.ids[1])
end
local function Test()
	if ns.IsPaladin() then ns.TestCooldowns() end
end
ns.commands.cooldowns = Test
ns.commands.cds = Test
ns.commands.reutilizacion = Test
ns.commands["reutilización"] = Test

-- For the tests
function ns.CooldownsState()
	local byKey = {}
	for _, entry in ipairs(SPELLS) do byKey[entry.key] = entry end
	return { place = place, art = art, poller = poller, spells = byKey, queue = queue }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN") -- built once
		db = ns.db.cooldowns
		place = CreateFrame("Frame", "PaladinGodCooldowns", UIParent)
		place:SetFrameStrata("HIGH")
		place:SetSize(db.size, db.size)
		place:Hide()
		art = Draw(place)
		place:SetScript("OnUpdate", function()
			if playing then Animate() end
		end)
		ns.Movable(place, "cooldowns", DEFAULT_POINT, L.COOLDOWNS_NAME)
		table.insert(ns.refreshers, ns.StyleCooldowns)
		Learn()
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		ns.StyleCooldowns()
		Watch()
	elseif event == "SPELLS_CHANGED" then
		Learn()
		Watch()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		local name = ns.SpellName(spellID)
		for _, entry in ipairs(SPELLS) do
			-- The spell under any of its numbers
			if entry.spell and (spellID == entry.spell or (name and not ns.IsSecret(name) and name == ns.SpellName(entry.spell))) then
				entry.own, entry.castAt = true, GetTime()
			end
		end
		Watch()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		Watch()
	end
end)
