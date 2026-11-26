local _, ns = ...
local L = ns.L

-- Your weapon's swing timer: a bar with the weapon's icon on a tag at its left, the minimalist one
-- HunterGod's swing timers have. Forever tells addons when each swing goes and how long the next
-- one takes (PLAYER_SWING), so no combat log is needed. The bar starts dim and lights up as the
-- swing comes, and flashes when it goes. It shows while you attack and goes a moment after you stop.
-- A paladin swings one weapon: only the main hand's swings count

local MAIN = 0 -- Enum.PlayerSwingType.MainHand
local SLOT = 16
local LINGER = 2 -- seconds the bar stays once its swing is done and no other comes
local FLASH = 0.18 -- the flash when a swing goes
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -100 }
local SAMPLE_SPEED = 3.6 -- for the sample, when the game doesn't say how fast your weapon is
local TEST_SECONDS = 6

local db, holder, bar
local swing -- { start, duration }
local inRange -- whether the target is in your weapon's reach, nil when the game can't tell
local sampleUntil = 0
local pending -- the Blizzard setting waits for the end of a fight

local function Sampling()
	return ns.unlocked or GetTime() < sampleUntil
end

local function Speed()
	local speed = UnitAttackSpeed and UnitAttackSpeed("player")
	if type(speed) ~= "number" or ns.IsSecret(speed) or speed <= 0 then return SAMPLE_SPEED end
	return speed
end

function ns.StyleSwing()
	if not holder then return end
	local px = ns.OnePixel(holder)
	local w, h = db.width, db.height
	local tagWidth = db.icon and h + 3 or 0
	holder:SetSize(tagWidth + w, h)
	bar.tag:ClearAllPoints()
	bar.tag:SetPoint("TOPLEFT")
	bar.tag:SetSize(h, h)
	bar.tag:SetShown(db.icon)
	bar.tagEdge:SetShown(db.icon)
	bar.tagEdge:ClearAllPoints()
	bar.tagEdge:SetPoint("TOPLEFT", bar.tag, -px, px)
	bar.tagEdge:SetPoint("BOTTOMRIGHT", bar.tag, px, -px)
	bar.tag:SetTexture(GetInventoryItemTexture("player", SLOT) or "Interface\\Icons\\INV_Misc_QuestionMark")
	bar.back:ClearAllPoints()
	bar.back:SetPoint("TOPRIGHT")
	bar.back:SetSize(w, h)
	bar.edge:ClearAllPoints()
	bar.edge:SetPoint("TOPLEFT", bar.back, -px, px)
	bar.edge:SetPoint("BOTTOMRIGHT", bar.back, px, -px)
	bar.shine:SetHeight(px)
	ns.UseFont(bar.time, ns.THIN_FONT, max(floor(h * 0.85), 9), "")
	bar.time:SetShadowOffset(1, -1)
	bar.time:SetShadowColor(0, 0, 0, 1)
	bar.time:SetTextColor(1, 1, 1)
	bar.time:SetShown(db.time)
	ns.UpdateSwing()
end

-- Paints the bar at this moment: how far its swing has come, lit up as it nears the end
local function Paint(now)
	local w = db.width
	local p, left = 1, 0
	if swing and swing.duration > 0 then
		p = min(max((now - swing.start) / swing.duration, 0), 1)
		left = max(swing.start + swing.duration - now, 0)
	end
	local c = db.color
	local r, g, b = c.r, c.g, c.b
	local away = inRange == false and not Sampling()
	if away then r, g, b = 0.5, 0.5, 0.48 end
	local k = 0.45 + 0.55 * p * p
	bar.fill:SetColorTexture(r * k, g * k, b * k, 1)
	bar.fill:SetWidth(max(w * p, 0.01))
	bar.fill:SetShown(p > 0)
	bar.shine:SetShown(p > 0)
	holder:SetAlpha(away and 0.55 or 1)
	local since = swing and now - swing.start or FLASH
	bar.flash:SetAlpha(since < FLASH and 0.55 * (1 - since / FLASH) or 0)
	bar.time:SetText(left > 0 and format("%.1f", left) or "")
end

local wasSampling = false

function ns.UpdateSwing()
	if not holder then return end
	local now = GetTime()
	local sampling = Sampling()
	-- The sample's swings aren't yours: they go with it
	if wasSampling and not sampling then swing = nil end
	wasSampling = sampling
	local on = db.enabled and ns.IsPaladin()
	if sampling then
		if on and (not swing or now >= swing.start + swing.duration) then
			swing = { start = now, duration = Speed() }
		end
	else
		on = on and swing ~= nil and now < swing.start + swing.duration + LINGER
	end
	if on then
		Paint(now)
		holder:Show()
	else
		holder:Hide()
	end
end

-- /paladingod swinglog: each swing the game reports, in the chat, to see what it hands over
local logging = false
local function Describe(value)
	if ns.IsSecret(value) then return "secret" end
	return tostring(value)
end

-- A swing just went: the next one comes in this long
local function Swing(duration, swingType)
	if logging then
		ns.Print(format("PLAYER_SWING type=%s duration=%s combat=%s", Describe(swingType), Describe(duration),
			tostring(InCombatLockdown())))
	end
	if ns.IsSecret(duration) or ns.IsSecret(swingType) or swingType ~= MAIN then return end
	if type(duration) ~= "number" or duration <= 0 or duration ~= duration or duration == math.huge then return end
	swing = { start = GetTime(), duration = duration }
	ns.UpdateSwing()
end
ns.SwingEvent = Swing -- for the tests

local function CheckRange()
	if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then return end
	local ok, within = pcall(C_SwingTimer.IsTargetWithinSwingRange, MAIN)
	-- Nil means the game couldn't tell: not out of range
	if ok and type(within) == "boolean" and not ns.IsSecret(within) then
		inRange = within
	else
		inRange = nil
	end
end

-- The game's own swing bars, through its setting: off while this one does the job, back on (if
-- this turned them off) when you turn this one off
local function Blizzard()
	if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	local current = C_CVar.GetCVar("showSwingTimer")
	if current == nil then return end
	if db.enabled and db.hideBlizzard and ns.IsPaladin() then
		if current ~= "0" then
			db.restoreBlizzard = true
			pcall(C_CVar.SetCVar, "showSwingTimer", "0")
		end
	elseif db.restoreBlizzard then
		db.restoreBlizzard = nil
		pcall(C_CVar.SetCVar, "showSwingTimer", "1")
	end
end
ns.SwingBlizzard = Blizzard

-- /paladingod swing, and the options' button: the bar swinging for a few seconds
function ns.TestSwing()
	sampleUntil = GetTime() + TEST_SECONDS
	swing = nil
	ns.UpdateSwing()
	C_Timer.After(TEST_SECONDS + 0.1, function()
		swing = nil
		ns.UpdateSwing()
	end)
end
ns.commands.swing = ns.TestSwing
ns.commands.golpe = ns.TestSwing
ns.commands.golpes = ns.TestSwing
ns.commands.swinglog = function()
	logging = not logging
	ns.Print(format("swing log %s; Blizzard's setting showSwingTimer = %s", logging and "on" or "off",
		tostring(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showSwingTimer"))))
end

-- For the tests
function ns.SwingState()
	return { holder = holder, bar = bar, swing = swing, inRange = inRange }
end

local events = CreateFrame("Frame")
-- Events this client may not have: registering one it doesn't know would stop the file here
local function Listen(event)
	pcall(events.RegisterEvent, events, event)
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.swing
		holder = CreateFrame("Frame", "PaladinGodSwing", UIParent)
		holder:SetFrameStrata("MEDIUM")
		bar = CreateFrame("Frame", nil, holder)
		bar:SetAllPoints(holder)
		bar.tagEdge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
		bar.tagEdge:SetColorTexture(0, 0, 0, 1)
		bar.tag = bar:CreateTexture(nil, "ARTWORK")
		bar.tag:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
		bar.edge:SetColorTexture(0, 0, 0, 1)
		bar.back = bar:CreateTexture(nil, "BACKGROUND")
		bar.back:SetColorTexture(0.06, 0.03, 0.05, 0.85)
		bar.fill = bar:CreateTexture(nil, "BORDER")
		bar.fill:SetPoint("TOPLEFT", bar.back)
		bar.fill:SetPoint("BOTTOMLEFT", bar.back)
		-- A thread of light along the top of what's filled
		bar.shine = bar:CreateTexture(nil, "ARTWORK")
		bar.shine:SetColorTexture(1, 1, 1, 0.14)
		bar.shine:SetPoint("TOPLEFT", bar.fill)
		bar.shine:SetPoint("TOPRIGHT", bar.fill)
		bar.flash = bar:CreateTexture(nil, "OVERLAY")
		bar.flash:SetColorTexture(1, 1, 1, 1)
		bar.flash:SetAllPoints(bar.back)
		bar.flash:SetAlpha(0)
		bar.time = bar:CreateFontString(nil, "OVERLAY")
		bar.time:SetPoint("RIGHT", bar.back, "RIGHT", -4, 0)
		holder:SetScript("OnUpdate", function()
			if Sampling() or swing then ns.UpdateSwing() end
		end)
		holder:Hide()
		ns.Movable(holder, "swing", DEFAULT_POINT, L.SWING_NAME)
		table.insert(ns.refreshers, ns.StyleSwing)
		Listen("PLAYER_SWING")
		Listen("PLAYER_SWING_RANGE_UPDATE")
		Listen("WEAPON_SLOT_CHANGED")
		Listen("PLAYER_TARGET_CHANGED")
		Listen("PLAYER_EQUIPMENT_CHANGED")
		Listen("PLAYER_REGEN_ENABLED")
		Listen("UI_SCALE_CHANGED")
		Listen("DISPLAY_SIZE_CHANGED")
		if C_SwingTimer and C_SwingTimer.EnableRangeCheck then pcall(C_SwingTimer.EnableRangeCheck, MAIN, true) end
		ns.StyleSwing()
		Blizzard()
	elseif event == "PLAYER_SWING" then
		Swing(...)
	elseif event == "PLAYER_SWING_RANGE_UPDATE" then
		local swingType, within, checks = ...
		if ns.IsSecret(swingType) or ns.IsSecret(within) or ns.IsSecret(checks) or swingType ~= MAIN then return end
		if checks then inRange = within and true or false else inRange = nil end
		ns.UpdateSwing()
	elseif event == "PLAYER_TARGET_CHANGED" then
		CheckRange()
		ns.UpdateSwing()
	elseif event == "WEAPON_SLOT_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
		-- Another weapon: its icon, and no swing left from the one before
		if not GetInventoryItemID("player", SLOT) then swing = nil end
		ns.StyleSwing()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = nil
			Blizzard()
		end
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		ns.StyleSwing()
	end
end)
