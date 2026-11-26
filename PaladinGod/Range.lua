local _, ns = ...
local L = ns.L

-- The range to your target, for a paladin: on an enemy, in your weapon's reach ("Melee"), within
-- 10 yards (Judgement and Hammer of Justice), within 30 (Exorcism, Hammer of Wrath) or out of all
-- of them; on a friend, within your heals' 40 yards or not. Your own spells answer first, and the
-- range steps of a few items fill in what they don't
local SPELLS = {
	strike = 679, -- Holy Strike: your weapon's reach
	judge = 20271, -- Judgement: 10 yards
	justice = 853, -- Hammer of Justice: 10 yards too
	ranged = 879, -- Exorcism: 30 yards
	wrath = 24275, -- Hammer of Wrath: 30 yards
	heal = 635, -- Holy Light: 40 yards
}
local MELEE, JUDGE, RANGED, HEAL = 5, 10, 30, 40
local YARD = 0.9144

-- Items whose use range measures the distance to a unit, by yards. From the Classic lists of
-- LibRangeCheck-3.0 (MIT); several per step in case one isn't cached.
ns.RANGE_ITEMS = {
	{ 5, { 8149, 15826, 16308, 17117, 22259, 22432 } },
	{ 10, { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689 } },
	{ 15, { 4559 } },
	{ 20, { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048 } },
	{ 25, { 13289 } },
	{ 30, { 835, 1404, 1434, 4479, 4480, 4481, 4941, 5079, 9328, 17202, 20084, 21038 } },
	{ 35, { 1399, 1402, 18904, 1258, 8688 } },
	{ 40, { 4945, 8348 } },
	{ 100, { 5418, 17162, 23715, 23718, 23719, 23721, 23722 } },
}
-- Interact distances in yards on Forever (as GoodRange measures them): 3 is the close one, 4 the
-- long one; Tauren and Undead are a little shorter
local INTERACT = { [3] = 8, [4] = 28 }
local INTERACT_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }

local db, frame, plate
-- Where the range and the aggro warning go when they aren't on the target's nameplate. You drag
-- these spots, never anchored to a nameplate: in Forever one that was can't be dragged
local rangeSpot = CreateFrame("Frame", "PaladinGodRangeSpot", UIParent)
rangeSpot:SetSize(80, 30)
local threatSpot = CreateFrame("Frame", "PaladinGodThreatSpot", UIParent)
threatSpot:SetSize(120, 20)
local elapsed = 0
local names = {} -- your spells by name: the game answers for the rank you know
local steps = {} -- { yards, item or interact }, ascending
local stepsMissing = false

-- true / false, or nil when the game doesn't say
local function Answer(v)
	if ns.IsSecret(v) then return nil end
	if v == true or v == 1 then return true end
	if v == false or v == 0 then return false end
end

local function InRange(spell, unit)
	if not spell then return end
	if C_Spell and C_Spell.IsSpellInRange then
		return Answer(C_Spell.IsSpellInRange(spell, unit))
	end
	return Answer(IsSpellInRange(spell, unit))
end

-- Only items the game has loaded give real answers
local function ItemReady(id)
	local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
	if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then return false end
	return getInfo(id) ~= nil
end

local function BuildSteps()
	wipe(steps)
	stepsMissing = false
	for _, step in ipairs(ns.RANGE_ITEMS) do
		local found
		for _, id in ipairs(step[2]) do
			if ItemReady(id) then
				found = id
				break
			end
			if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
		end
		if found then
			steps[#steps + 1] = { step[1], item = found }
		else
			stepsMissing = true
		end
	end
	local race = select(2, UnitRace("player"))
	for index, yards in pairs(INTERACT_RACE[race] or INTERACT) do
		steps[#steps + 1] = { yards, interact = index }
	end
	table.sort(steps, function(a, b) return a[1] < b[1] end)
	-- Items that weren't loaded yet are tried again in a while
	if stepsMissing then C_Timer.After(5, BuildSteps) end
end

local function CheckStep(step, unit)
	if step.item then
		local check = C_Item and C_Item.IsItemInRange or IsItemInRange
		return Answer(check(step.item, unit))
	end
	return Answer(CheckInteractDistance(unit, step.interact))
end

-- Only spells you know answer
local function LearnNames()
	for key, id in pairs(SPELLS) do
		names[key] = ns.Knows({ id }) and ns.SpellName(id) or nil
	end
end

local function StepAt(field, value)
	for _, step in ipairs(steps) do
		if step[field] == value then return step end
	end
end

local function Within(yards, unit)
	local step = StepAt(1, yards)
	return step and CheckStep(step, unit)
end

-- A spell's answer, or the range step's when it doesn't give one
local function Reach(unit, yards, ...)
	for i = 1, select("#", ...) do
		local v = InRange(names[select(i, ...)], unit)
		if v ~= nil then return v end
	end
	return Within(yards, unit)
end

local function Hostile(unit)
	local hostile = UnitCanAttack("player", unit)
	if ns.IsSecret(hostile) then return true end
	return hostile and true or false
end

-- melee | judge | ranged | out on an enemy, heal | out on a friend; nil when the game doesn't say
function ns.RangeState(unit)
	if not Hostile(unit) then
		local heal = Reach(unit, HEAL, "heal")
		if heal == nil then return nil end
		return heal and "heal" or "out"
	end
	local melee = Reach(unit, MELEE, "strike")
	if melee then return "melee" end
	local judge = Reach(unit, JUDGE, "judge", "justice")
	-- Without those items loaded, the close interact distance (8 yards) stands in
	if judge == nil and melee == nil then
		local close = StepAt("interact", 3)
		judge = close and CheckStep(close, unit)
	end
	if judge then return "judge" end
	local ranged = Reach(unit, RANGED, "ranged", "wrath")
	if ranged then return "ranged" end
	if ranged == false or judge == false then return "out" end
end

-- The distance to the unit in yards for its state: low, high (high is nil past the last step)
function ns.RangeDistance(unit, state)
	local low, high
	if state == "melee" then
		return 0, MELEE
	elseif state == "judge" then
		low, high = MELEE, JUDGE
	elseif state == "ranged" then
		low, high = JUDGE, RANGED
	elseif state == "heal" then
		low, high = 0, HEAL
	else
		low = Hostile(unit) and RANGED or HEAL
	end
	for _, step in ipairs(steps) do
		local yards = step[1]
		if yards > low and (not high or yards < high) then
			local v = CheckStep(step, unit)
			if v then
				high = yards
				break
			elseif v == false then
				low = yards
			end
		end
	end
	return low, high
end

-- /paladingod rango: what each check says about your target
local function RangeReport()
	if not UnitExists("target") then
		ns.Print(L.RANGE_NO_TARGET)
		return
	end
	local function Say(v)
		if v == nil then return "?" end
		return v and L.RANGE_YES or L.RANGE_NO
	end
	local state = ns.RangeState("target")
	local low, high = ns.RangeDistance("target", state)
	local spells = {}
	for _, key in ipairs({ "strike", "judge", "ranged", "heal" }) do
		if names[key] then spells[#spells + 1] = format("%s: %s", names[key], Say(InRange(names[key], "target"))) end
	end
	ns.Print(format(L.RANGE_REPORT, state and L.RANGE[state] or "?", low, high or 0,
		#spells > 0 and table.concat(spells, ", ") or "-"))
	local parts = {}
	for _, step in ipairs(steps) do
		parts[#parts + 1] = format("%d:%s", step[1], Say(CheckStep(step, "target")))
	end
	ns.Print(L.RANGE_STEPS .. table.concat(parts, "  ") .. (stepsMissing and ("  " .. L.RANGE_LOADING) or ""))
end
ns.commands.range = RangeReport
ns.commands.rango = RangeReport

-- One number from the range steps. Each time the target crosses a step, its distance is known
-- exactly; between crossings it keeps moving at the rate of the last two, and holds still while
-- neither of you moves. (The same idea as GoodRange's estimate.)
local estimate = {}
local RATE_WINDOW = 10 -- s; an older crossing is too stale to give a rate

local function Moving()
	local mine, theirs = GetUnitSpeed("player"), GetUnitSpeed("target")
	if ns.IsSecret(mine) or ns.IsSecret(theirs) or mine == nil or theirs == nil then return true end
	return mine > 0 or theirs > 0
end

function ns.EstimateDistance(now, low, high)
	local e = estimate
	if not high then
		wipe(e) -- past the last step there is nothing to measure
		return nil
	end
	if e.low and (low ~= e.low or high ~= e.high) then
		-- Which step was crossed: the near edge of the new range going away, its far edge coming closer
		local edge
		if low >= e.high then
			edge = low
		elseif high <= e.low then
			edge = high
		end
		if edge then
			if e.edge and e.edge ~= edge and now - e.edgeT < RATE_WINDOW then
				e.rate = (edge - e.edge) / (now - e.edgeT)
			else
				e.rate = nil
			end
			e.edge, e.edgeT = edge, now
			e.value = edge
		else
			wipe(e) -- the steps themselves changed: start again
		end
	end
	if not e.value then
		e.value = (low + high) / 2
	elseif e.rate and e.valueT and Moving() then
		e.value = e.value + e.rate * (now - e.valueT)
	end
	e.low, e.high, e.valueT = low, high, now
	e.value = min(max(e.value, low), high)
	return e.value
end

local function TargetPlate()
	if db.anchor ~= "plate" or ns.unlocked or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	return C_NamePlate.GetNamePlateForUnit("target")
end

-- Beside the plate's health bar, not its wider click area
local function PlateBar(p)
	local unitFrame = p.UnitFrame
	local bar = unitFrame and (unitFrame.healthBar
		or unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
	return bar or p
end

-- On the target's nameplate: above or under it, or beside its health bar
local PLATE_SIDES = {
	top = { "BOTTOM", "TOP", 0, 1 },
	bottom = { "TOP", "BOTTOM", 0, -1 },
	left = { "RIGHT", "LEFT", -1, 0 },
	right = { "LEFT", "RIGHT", 1, 0 },
}

local function Anchor(newPlate)
	plate = newPlate
	frame.placed = newPlate and (db.plateSide .. db.plateGap) -- placed again when these change
	frame:ClearAllPoints()
	if plate then
		local side = PLATE_SIDES[db.plateSide] or PLATE_SIDES.top
		local to = side[3] ~= 0 and PlateBar(plate) or plate
		frame:SetPoint(side[1], to, side[2], side[3] * db.plateGap, side[4] * db.plateGap)
	else
		frame:SetPoint("CENTER", rangeSpot)
	end
end

-- The number on the display: the estimate, or the range between two checks
function ns.RangeNumber(low, high, value)
	local scale = db.units == "meters" and YARD or 1
	if db.display == "number" and value then
		return tostring(floor(value * scale + 0.5))
	elseif high then
		return format("%d-%d", floor(low * scale + 0.5), floor(high * scale + 0.5))
	end
	return format("%d+", floor(low * scale + 0.5))
end

local function Show(state, low, high, value)
	local c = db.colors[state]
	-- Melee in words, a little smaller; any other distance is the number alone, its colour saying
	-- the rest
	local words = db.words and state == "melee" or false
	if words ~= frame.words then
		ns.UseFont(frame.text, ns.FONTS[db.font], words and max(floor(db.textSize * 0.7), 10) or db.textSize, "THICKOUTLINE")
		frame.words = words
	end
	frame.text:SetText(words and L.RANGE.melee or ns.RangeNumber(low, high, value))
	local unitShown = db.unitLabel and not words
	frame.unit:SetText(unitShown and (db.units == "meters" and L.METERS or L.YARDS) or "")
	for _, part in ipairs({ frame.text, frame.unit }) do
		part:SetTextColor(c.r, c.g, c.b)
	end
	frame.icon:SetColorTexture(c.r, c.g, c.b)
	local text, icon = db.style ~= "icon", db.style ~= "text"
	local width = (icon and db.textSize * 0.7 or 0) + (icon and text and 6 or 0)
		+ (text and frame.text:GetStringWidth() + (unitShown and 3 + frame.unit:GetStringWidth() or 0) or 0)
	frame:SetSize(max(width, 16), db.textSize + 4)
	frame:Show()
end

function ns.StyleRange()
	local text, icon = db.style ~= "icon", db.style ~= "text"
	local unitSize = max(floor(db.textSize * 0.5), 8)
	-- A thick black outline keeps the number readable on any ground
	local font = ns.FONTS[db.font]
	ns.UseFont(frame.text, font, db.textSize, "THICKOUTLINE")
	frame.words = false -- the number's size: melee's word sets its own when it shows
	ns.UseFont(frame.unit, font, unitSize, "OUTLINE")
	frame.icon:SetSize(db.textSize * 0.7, db.textSize * 0.7)
	frame.text:SetShown(text)
	frame.unit:SetShown(text)
	frame.icon:SetShown(icon)
	frame.iconBorder:SetShown(icon)
	frame.icon:ClearAllPoints()
	frame.text:ClearAllPoints()
	if icon then
		frame.icon:SetPoint("LEFT", 1, 0)
		frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
	else
		frame.text:SetPoint("LEFT", 0, 0)
	end
	frame.unit:ClearAllPoints()
	frame.unit:SetPoint("BOTTOMLEFT", frame.text, "BOTTOMRIGHT", 3, db.textSize * 0.08)
	if ns.StyleThreat then ns.StyleThreat() end
end

function ns.UpdateRange()
	if not db.enabled or not ns.IsPaladin() then
		frame:Hide()
		return
	end
	local newPlate = TargetPlate()
	if newPlate ~= plate or (plate and frame.placed ~= db.plateSide .. db.plateGap) then Anchor(newPlate) end
	if ns.unlocked then
		Show("ranged", 20, 25, 22) -- a sample to drag around
		return
	end
	local dead = UnitIsDead("target")
	if ns.IsSecret(dead) then dead = false end
	if not UnitExists("target") or dead or UnitIsUnit("target", "player") or (not Hostile("target") and not db.friendly)
		or (db.onlyCombat and not UnitAffectingCombat("player")) then
		frame:Hide()
		return
	end
	local state = ns.RangeState("target")
	if not state then
		frame:Hide()
		return
	end
	local low, high = ns.RangeDistance("target", state)
	Show(state, low, high, ns.EstimateDistance(GetTime(), low, high))
end

local function UnitsCommand(word)
	db.units = (word == "yards" or word == "yardas") and "yards" or "meters"
	ns.UpdateRange()
	ns.Print(format(L.UNITS_SET, strlower(L.UNITS[db.units])))
end
for _, word in ipairs({ "meters", "metres", "metros", "yards", "yardas" }) do
	ns.commands[word] = UnitsCommand
end

frame = CreateFrame("Frame", "PaladinGodRange", UIParent)
frame:SetSize(80, 18)
frame:Hide()
frame.iconBorder = frame:CreateTexture(nil, "BORDER")
frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.iconBorder:SetPoint("TOPLEFT", frame.icon, -1, 1)
frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, 1, -1)
frame.iconBorder:SetColorTexture(0, 0, 0, 0.9)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.unit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

-- The aggro warning, under the target's nameplate. Not tanking: before you pull the aggro off the
-- tank. Tanking (Righteous Fury on): when your target turns away from you
local threat = CreateFrame("Frame", "PaladinGodThreat", UIParent)
threat:SetSize(120, 20)
threat:Hide()
threat.text = threat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
threat.text:SetPoint("CENTER")
threat.blink = threat:CreateAnimationGroup()
threat.blink:SetLooping("BOUNCE")
local threatFade = threat.blink:CreateAnimation("Alpha")
threatFade:SetFromAlpha(1)
threatFade:SetToAlpha(0.3)
threatFade:SetDuration(0.35)

function ns.StyleThreat()
	ns.UseFont(threat.text, ns.FONTS[db.font], 16, "THICKOUTLINE")
end

-- Do you have the target's aggro, and your threat as the game's tooltip shows it: next to the
-- threat of whoever has the aggro, rounded. status is nil while it isn't fighting you
local function ThreatOnTarget()
	local ok, tanking, status, _, raw = pcall(UnitDetailedThreatSituation, "player", "target")
	if not ok or ns.IsSecret(tanking) or ns.IsSecret(status) or ns.IsSecret(raw) then return end
	return tanking, type(raw) == "number" and floor(raw + 0.5) or nil, status
end

function ns.UpdateThreat()
	local text, alarm
	if db.threat and ns.IsPaladin() then
		if ns.unlocked then
			text = format(L.THREAT, 95)
		elseif UnitExists("target") and IsInGroup() then
			-- Solo you always have the aggro: nothing to warn about then
			local tanking, percent, status = ThreatOnTarget()
			if ns.IsTank and ns.IsTank() then
				if db.tankWarn and tanking == false and status ~= nil then text, alarm = L.THREAT_LOST, true end
			elseif tanking then
				text, alarm = L.THREAT_PULLED, true
			elseif percent and percent >= db.threatPct then
				text = format(L.THREAT, percent)
			end
		end
	end
	if not text then
		threat.blink:Stop()
		threat:Hide()
		threat.anchor = nil -- placed again when it shows
		return
	end
	-- Placed only when where it hangs changes: placing it on every update undid a drag
	local targetPlate = not ns.unlocked and C_NamePlate and C_NamePlate.GetNamePlateForUnit
		and C_NamePlate.GetNamePlateForUnit("target")
	-- With the range under the nameplate, the warning goes under the range
	local under = targetPlate and db.enabled and db.anchor == "plate" and db.plateSide == "bottom" and -2
	local anchor = under and "under" or targetPlate or "free"
	if threat.anchor ~= anchor then
		threat.anchor = anchor
		threat:ClearAllPoints()
		if under then
			threat:SetPoint("TOP", frame, "BOTTOM", 0, under)
		elseif targetPlate then
			threat:SetPoint("TOP", targetPlate, "BOTTOM", 0, -2)
		else
			threat:SetPoint("CENTER", threatSpot)
		end
	end
	threat.text:SetText(text)
	if alarm then
		threat.text:SetTextColor(1, 0.15, 0.15)
		if not threat.blink:IsPlaying() then threat.blink:Play() end
	else
		threat.text:SetTextColor(1, 0.55, 0.1)
		threat.blink:Stop()
	end
	threat:SetWidth(threat.text:GetStringWidth() + 8)
	threat:Show()
end

-- A small driver that keeps running while the display is hidden
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event)
	if event == "SPELLS_CHANGED" then
		LearnNames()
		return
	elseif event == "PLAYER_TARGET_CHANGED" then
		wipe(estimate) -- a new target starts a new estimate
		return
	end
	db = ns.db.range
	LearnNames()
	BuildSteps()
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	ns.Movable(rangeSpot, "range", { "CENTER", "CENTER", 0, -140 }, L.TAB_RANGE)
	ns.Movable(threatSpot, "threat", { "CENTER", "CENTER", 0, -200 }, L.THREAT_NAME) -- clear of the range's box
	Anchor(nil)
	ns.StyleRange()
	table.insert(ns.refreshers, function()
		Anchor(TargetPlate())
		ns.StyleRange()
		ns.UpdateRange()
		ns.UpdateThreat()
	end)
	local threatElapsed = 0
	driver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		threatElapsed = threatElapsed + dt
		if threatElapsed >= 0.2 then
			threatElapsed = 0
			ns.UpdateThreat()
		end
		if elapsed < 0.05 then return end
		elapsed = 0
		ns.UpdateRange()
	end)
end)
