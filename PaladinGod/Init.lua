local addonName, ns = ...
local L = ns.L

-- The paladin's colour, #F48CBA
ns.ACCENT = { 0.96, 0.55, 0.73 }

-- Settings: whatever is missing from the saved ones is filled in from here
local defaults = {
	buffs = {
		enabled = true,
		aura = true,
		auraChoice = "auto", -- auto (the last one you had on) | devotion | retribution | concentration | shadow | frost | fire
		blessing = true,
		blessingChoice = "auto", -- auto (the last of yours seen on you) | might | wisdom | kings
		-- Righteous Fury: warn (you don't tank: a warning when it's on in a group) | tank (remind it) | off
		fury = "warn",
		warnMinutes = 2, -- a blessing or Righteous Fury shows this long before it ends
		click = true, -- clicking a reminder casts it, out of combat
		text = true, -- a word under the icons that need one
	},
	lastAura = nil, -- the aura you had on last
	lastBlessing = nil, -- the last of your blessings seen on you
	lastSeal = nil, -- the seal you cast last
	-- Your seal: its icon with the seconds it has left, grey when you fight without one
	seal = {
		enabled = true,
		choice = "auto", -- auto (the last one you cast) | righteousness | crusader | command | justice | light | wisdom | fury
		target = true, -- also out of combat, with an enemy targeted (about to pull)
		size = 40,
		learned = {}, -- other spells the addon saw by a seal's name
	},
	food = { enabled = true },
	-- Herbalism or Mining: their tracking on, out in the world (last: the one you had on)
	gather = { enabled = true },
	-- Your reagents running low (Symbol of Divinity, Symbol of Kings): Reagents.lua, the family's
	reagents = { enabled = true },
	-- Your class's buffs someone in your group lacks: GroupBuffs.lua, the family's (none for a paladin,
	-- whose blessings go by player in Blessings.lua)
	groupBuffs = { enabled = true },
	-- Your gear under this % and your bags with this many free slots or fewer: Repair.lua, the family's
	repair = { enabled = true, low = 25, bags = 2 },
	-- Who in your group lacks your blessing, and which one each class gets
	group = {
		enabled = true,
		maxRows = 10,
		classes = {
			WARRIOR = "might", ROGUE = "might",
			PALADIN = "wisdom", HUNTER = "wisdom", MAGE = "wisdom", WARLOCK = "wisdom", PRIEST = "wisdom",
			DRUID = "wisdom", SHAMAN = "wisdom",
		},
	},
	-- At the class trainer: when the talent reset price drops. The trainer options seen to lead to the reset
	respec = { enabled = true, options = {} },
	-- Golden light around you while a proc is up
	procs = {
		size = 40, -- %: around your character, not over half the screen
		gap = 150, -- from the middle to each side, for the columns
		alpha = 60, -- the burst as it comes, %
		calm = 20, -- while it lasts, after the burst: faint, %
		timer = true, -- the seconds it has left
		timerSize = 22,
		-- Holy
		infusion = { enabled = true, color = { r = 1, g = 0.82, b = 0.35 } },
		divinefavor = { enabled = true, color = { r = 1, g = 0.95, b = 0.7 } },
		-- Retribution
		vengeance = { enabled = true, color = { r = 1, g = 0.55, b = 0.2 } },
		-- Protection
		redoubt = { enabled = true, color = { r = 0.45, g = 0.7, b = 1 } },
		shieldsworn = { enabled = true, color = { r = 0.85, g = 0.9, b = 1 } },
		reckoning = { enabled = true, color = { r = 0.55, g = 0.78, b = 1 } },
		ironcreed = { enabled = true, color = { r = 0.7, g = 0.76, b = 0.88 } },
		learned = {}, -- other spells the addon saw by a proc's name: id -> proc
		ignored = {}, -- ones it saw always on: a passive, not the proc
	},
	-- What's left of a shield that absorbs: Templar's Bulwark, a priest's Power Word: Shield or a
	-- protection potion, each in its own colour
	barrier = {
		enabled = true,
		potions = true, -- the protection potions too
		width = 160, height = 14, text = true, time = true,
		icon = true, -- the shield's icon on a tag at its left end
		color = { r = 0.96, g = 0.55, b = 0.73 }, -- a shield the addon can't tell
		-- Yours, and every other class's that can be on you, with the same keys and colours as the rest
		-- of the family; the protection potions in their school's
		colors = {
			bulwark = { r = 1, g = 0.82, b = 0.3 }, -- Templar's Bulwark: gold
			powerWord = { r = 1, g = 0.92, b = 0.6 },
			aegis = { r = 1, g = 0.97, b = 0.82 }, -- Divine Aegis: nearly white
			contingency = { r = 0.55, g = 0.9, b = 0.8 }, -- Contingency Plan: a gnome's teal
			barrier = { r = 0.52, g = 0.78, b = 0.92 }, -- Ice Barrier
			manaShield = { r = 0.6, g = 0.5, b = 1 },
			fireWard = { r = 1, g = 0.5, b = 0.15 },
			frostWard = { r = 0.75, g = 0.95, b = 1 },
			ward = { r = 0.62, g = 0.4, b = 1 }, -- Shadow Ward
			sacrifice = { r = 0.42, g = 0.3, b = 0.78 }, -- a Voidwalker's
			fire = { r = 1, g = 0.42, b = 0.1 },
			frost = { r = 0.45, g = 0.75, b = 1 },
			nature = { r = 0.4, g = 0.85, b = 0.3 },
			shadow = { r = 0.62, g = 0.38, b = 0.85 },
			arcane = { r = 0.85, g = 0.55, b = 1 },
			holy = { r = 1, g = 0.85, b = 0.35 },
		},
	},
	-- Your weapon's swing
	swing = {
		enabled = true,
		width = 200,
		height = 12,
		icon = true,
		time = true,
		hideBlizzard = true, -- the game's own swing bar off while this one shows
		color = { r = 0.96, g = 0.55, b = 0.73 },
	},
	-- Hammer of Wrath with your target under 20%, Exorcism against undead and demons, Hammer of
	-- Justice while your target casts
	execute = { hammer = true, exorcism = true, interrupt = true, size = 48 },
	-- Your big cooldowns: a pulse in the middle when each is ready again
	cooldowns = {
		enabled = true,
		size = 80,
		alpha = 90, -- %
		color = { r = 1, g = 0.82, b = 0.35 }, -- the shine behind it
		spells = {
			divineShield = true, divineProtection = true, layOnHands = true, protection = true, bulwark = true,
			divineFavor = true, repentance = true, justice = true, voice = true, intervention = true,
		},
	},
	-- Your effects on your enemies, beside each nameplate, with their seconds
	debuffs = { enabled = true, size = 22, judgement = true, control = true, vindication = true },
	range = {
		enabled = true,
		friendly = true, -- also for friendly targets: within your heals' 40 yards or not
		threat = true,
		threatPct = 90, -- warn from this % of the tank's threat, as the game's tooltip shows it
		tankWarn = true, -- with Righteous Fury on: warn when you lose your target's aggro
		onlyCombat = false,
		style = "text", -- text | icon | both
		anchor = "plate", -- plate | free
		plateSide = "top", -- top | bottom | left | right
		plateGap = 2,
		units = "yards", -- yards | meters
		display = "number", -- number | bracket
		font = "fredoka", -- fredoka | changa | game
		words = true, -- "Melee" in words instead of a number
		unitLabel = false, -- yd or m after the number
		textSize = 26,
		colors = {
			melee = { r = 0.3, g = 1, b = 0.3 },
			judge = { r = 1, g = 0.82, b = 0 },
			ranged = { r = 0.45, g = 0.8, b = 1 },
			heal = { r = 0.96, g = 0.55, b = 0.73 },
			out = { r = 0.6, g = 0.6, b = 0.6 },
		},
	},
	minimapButton = { hide = false, angle = 200 },
	positions = {},
}
ns.DEFAULTS = defaults

local function Fill(saved, default)
	for k, v in pairs(default) do
		if saved[k] == nil then
			saved[k] = type(v) == "table" and Fill({}, v) or v
		elseif type(v) == "table" and type(saved[k]) == "table" then
			Fill(saved[k], v)
		end
	end
	return saved
end

-- Every ...God may be installed at once, and the family's shared files speak at a vendor or a
-- trainer: on another class this one keeps quiet, unless you typed one of its commands
function ns.Print(msg)
	if not (ns.inCommand or ns.IsPaladin()) then return end
	print(L.PREFIX .. msg)
end

-- Fonts as shared font objects, one per file, size and outline, applied with SetFontObject.
-- Each text loading the font file itself (SetFont on the FontString) left some texts undrawn in
-- Forever: FarmGod's tabs, 23 Nov 2026, had their text, shown, at full alpha and with a width,
-- and nothing on screen. The game's font goes in first, so a font that can't load still shows
local fontObjects, fontCount = {}, 0
function ns.UseFont(fontString, file, size, flags)
	local gameFont = GameFontNormal:GetFont()
	file, flags = file or gameFont, flags or ""
	local key = file .. "|" .. size .. "|" .. flags
	local font = fontObjects[key]
	if not font then
		fontCount = fontCount + 1
		font = CreateFont("PaladinGodFont" .. fontCount)
		font:SetFont(gameFont, size, flags)
		font:SetFont(file, size, flags)
		fontObjects[key] = font
	end
	-- The font object brings its own colour and shadow: the text keeps the ones it had
	local r, g, b, a = fontString:GetTextColor()
	local sx, sy = fontString:GetShadowOffset()
	local sr, sg, sb, sa = fontString:GetShadowColor()
	fontString:SetFontObject(font)
	if r then fontString:SetTextColor(r, g, b, a) end
	if sx then fontString:SetShadowOffset(sx, sy) end
	if sr then fontString:SetShadowColor(sr, sg, sb, sa) end
end

-- Forever hides some values from addons during combat
function ns.IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

function ns.IsPaladin()
	return select(2, UnitClass("player")) == "PALADIN"
end

-- Your buffs, everyone's, are hidden from addons in combat
function ns.AurasHidden()
	return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() or false
end

function ns.SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

function ns.SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture(id)
end

-- Do you know any of these ranks? Forever may give a spell other ids: then the spellbook
-- answers for its name
function ns.Knows(ids)
	for _, id in ipairs(ids) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not ns.IsSecret(known) then return true end
	end
	local name = ns.SpellName(ids[1])
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return type(info) == "table" and not ns.IsSecret(info)
	end
	return false
end

-- 1:05 or 1:02:03
function ns.Clock(seconds)
	seconds = floor(seconds)
	if seconds >= 3600 then
		return format("%d:%02d:%02d", floor(seconds / 3600), floor(seconds % 3600 / 60), seconds % 60)
	end
	return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

-- 12, 11 ... 1: whole seconds rounded up, as a countdown goes, for a time the game writes itself
-- because it's hidden from the addon. Without it the game writes "12 s"
local formatter
function ns.SecondsFormatter()
	if formatter == nil then
		formatter = false
		local rounding = Enum and Enum.NumericRuleFormatRounding
		if rounding and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
			local ok, made = pcall(C_StringUtil.CreateNumericRuleFormatter)
			if ok and made and pcall(made.SetBreakpoints, made, {
				{ threshold = 0, format = "" },
				{ threshold = 0.000001, format = "%d", step = 1, rounding = rounding.Up },
			}) then
				formatter = made
			end
		end
	end
	return formatter or nil
end

-- Hands a text to an aura container's button, for the game to write the seconds left in.
-- false when the game won't
function ns.GameWritesSeconds(button, text)
	local options = ns.SecondsFormatter() and { textFormatter = ns.SecondsFormatter() }
	return pcall(button.SetDurationText, button, text, options)
		or (options and pcall(button.SetDurationText, button, text)) or false
end

-- A living enemy targeted. A value the game hides counts as yes: the target is still there
function ns.EnemyTarget()
	if not UnitExists("target") then return false end
	local hostile = UnitCanAttack("player", "target")
	if ns.IsSecret(hostile) then hostile = true end
	if not hostile then return false end
	local dead = UnitIsDeadOrGhost("target")
	if ns.IsSecret(dead) then dead = false end
	return not dead
end

-- Dead, a ghost or on a flight: nothing to remind
function ns.Away()
	local dead = UnitIsDeadOrGhost("player")
	if ns.IsSecret(dead) then dead = false end
	return dead or (UnitOnTaxi and UnitOnTaxi("player")) or false
end

-- The addon's round font over the game's one, in case it can't load (a new file needs the
-- game restarted)
ns.FONTS = {
	fredoka = "Interface\\AddOns\\PaladinGod\\media\\FredokaOne-Regular.ttf",
	changa = "Interface\\AddOns\\PaladinGod\\media\\Changa-Bold.ttf",
}
function ns.FancyFont(fontString, size, flags)
	ns.UseFont(fontString, ns.FONTS[ns.db.range.font], size, flags)
end

-- The thin letters of the bars and the lists: the game's narrow Arial, over its usual font in
-- case it isn't there
ns.THIN_FONT = "Fonts\\ARIALN.TTF"
function ns.ThinFont(fontString, size)
	ns.UseFont(fontString, ns.THIN_FONT, size, "")
end

-- One pixel of the screen in a frame's own units: an edge one UI unit wide comes out blurry, or
-- not at all, depending on your UI scale
function ns.OnePixel(frame)
	if not (PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return 1 end
	local scale = frame:GetEffectiveScale()
	if ns.IsSecret(scale) or not scale or scale <= 0 then return 1 end
	return PixelUtil.GetPixelToUIUnitFactor() / scale
end

-- Each module adds the function that redraws it; the options call them all
ns.refreshers = {}
function ns.RefreshAll()
	for _, refresh in ipairs(ns.refreshers) do
		refresh()
	end
end

-- Displays the player can drag around while they are unlocked
ns.movers = {}
ns.unlocked = false

function ns.PlaceFrame(frame)
	local p = ns.db.positions[frame.moverKey]
	-- Some displays sit next to something of the game's until you move them
	if not p and frame.placeDefault and frame:placeDefault() then return end
	p = p or frame.defaultPoint
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- While unlocked each display gets a box on top of it, big enough to grab
local function SizeHandle(frame)
	local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
	if ns.IsSecret(w) or ns.IsSecret(h) then w, h = 0, 0 end
	frame.mover:SetSize(max(w + 16, 140), max(h + 16, 44))
end

function ns.Movable(frame, key, defaultPoint, label)
	frame.moverKey = key
	frame.defaultPoint = defaultPoint
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local handle = CreateFrame("Frame", nil, frame)
	handle:SetPoint("CENTER")
	handle:SetFrameLevel(frame:GetFrameLevel() + 20)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		if x and not ns.IsSecret(x) then
			ns.db.positions[key] = { point, relPoint, x, y }
		end
	end)
	local box = handle:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	box:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.35)
	local name = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("CENTER")
	name:SetText(label)
	handle:Hide()
	frame.mover = handle
	ns.movers[key] = frame
	ns.PlaceFrame(frame)
end

function ns.SetUnlocked(on)
	if InCombatLockdown() then
		ns.Print(L.NOT_IN_COMBAT)
		return
	end
	-- Every ...God may be installed at once: on another class this one shows nothing, not even samples.
	-- You asked (a command, the minimap button or the options): it says why
	if on and not ns.IsPaladin() then
		print(L.PREFIX .. L.OTHER_CLASS)
		return
	end
	ns.unlocked = on
	if not on then
		for _, frame in pairs(ns.movers) do ns.PlaceFrame(frame) end
	end
	ns.RefreshAll() -- while unlocked the displays show a sample, so the boxes fit them
	for _, frame in pairs(ns.movers) do
		SizeHandle(frame)
		frame.mover:SetShown(on)
	end
	ns.Print(on and L.UNLOCKED or L.LOCKED)
end

-- Slash command words: each module adds its own
ns.commands = {}

local function Help()
	for _, line in ipairs(L.HELP) do
		print(line)
	end
end

ns.commands.unlock = function() ns.SetUnlocked(true) end
ns.commands.desbloquear = ns.commands.unlock
ns.commands.lock = function() ns.SetUnlocked(false) end
ns.commands.bloquear = ns.commands.lock
ns.commands.help = Help
ns.commands.ayuda = Help

SLASH_PALADINGOD1 = "/paladingod"
SLASH_PALADINGOD2 = "/paladin"
SlashCmdList.PALADINGOD = function(msg)
	local word = strlower(strtrim(msg or ""))
	if word == "" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	end
	local command = ns.commands[word]
	if command then
		-- A command you typed always answers, whatever your class
		ns.inCommand = true
		local ok, err = pcall(command, word)
		ns.inCommand = false
		if not ok then error(err, 0) end
	else
		Help()
	end
end

-- Settings saved by an older version, brought up to date
function ns.MigrateSettings(saved, fresh)
	saved.version = 1
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	local fresh = PaladinGodDB == nil
	PaladinGodDB = Fill(PaladinGodDB or {}, defaults)
	ns.db = PaladinGodDB
	ns.MigrateSettings(PaladinGodDB, fresh)
	self:UnregisterEvent("ADDON_LOADED")
end)
