local addonName, ns = ...
local L = ns.L

-- A dark window with a menu down the side, in the paladin's class colour. Square pieces only:
-- Forever's client draws icons cut round with a mask as stripes
local WIDTH, HEIGHT = 660, 560
local SIDE = 170 -- the menu
local TOP = 60 -- the title bar
local PAGE_WIDTH = WIDTH - SIDE - 40
local ACCENT = ns.ACCENT
local TEXT = { 0.94, 0.92, 0.94 }
local MUTED = { 0.64, 0.6, 0.64 }
local window, scroll, scrollBar
local tabs, pages = {}, {}

local function SpellName(id)
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo and GetSpellInfo(id)
end

local function SpellIcon(id, fallback)
	return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
		or GetSpellTexture and GetSpellTexture(id) or fallback
end

-- Drawing pieces

local function Rect(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

-- A white block, to tint with SetVertexColor
local function Block(parent, layer, width, height)
	local t = Rect(parent, layer, 1, 1, 1)
	t:SetSize(width, height)
	return t
end

local function Icon(parent, size, texture, coords)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	t:SetTexture(texture)
	t:SetTexCoord(unpack(coords or { 0.08, 0.92, 0.08, 0.92 }))
	return t
end

-- The addon's round font, over the game's in case it can't load
local function Fancy(fs, size, flags)
	ns.UseFont(fs, ns.FONTS.fredoka, size, flags)
end

local function Text(parent, template, color)
	local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
	fs:SetTextColor(unpack(color or TEXT))
	fs:SetJustifyH("LEFT")
	return fs
end

-- A faint light behind a button while the mouse is on it
local function Highlight(button, alpha)
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, alpha or 0.04)
end

-- An on/off switch for a CheckButton; returns the function that draws it
local function Switch(button, width, height)
	local track = Block(button, "ARTWORK", width, height)
	local knob = Block(button, "OVERLAY", height - 4, height - 4)
	local function Paint()
		local on = button:GetChecked()
		if on then track:SetVertexColor(unpack(ACCENT)) else track:SetVertexColor(0.27, 0.23, 0.26) end
		local shade = on and 1 or 0.7
		knob:SetVertexColor(shade, shade, shade)
		knob:ClearAllPoints()
		knob:SetPoint(on and "RIGHT" or "LEFT", track, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
	end
	return track, Paint
end

local function Click()
	if SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

-- Controls: each one is a row of the page and knows how to read its setting back (Refresh)

-- A row with its text on the left, as tall as the text needs
local function Row(page, y, kind, text, textWidth, minHeight)
	local row = CreateFrame(kind, nil, page)
	local label = Text(row)
	label:SetPoint("LEFT", 10, 0)
	label:SetWidth(textWidth)
	label:SetText(text)
	local height = max(minHeight or 30, ceil(label:GetStringHeight() or 0) + 14)
	row:SetSize(PAGE_WIDTH, height)
	row:SetPoint("TOPLEFT", 0, y)
	row.label = label
	return row, y - height
end

local function Section(page, y, text)
	local title = page:CreateFontString(nil, "ARTWORK")
	Fancy(title, 14)
	title:SetTextColor(unpack(ACCENT))
	title:SetPoint("TOPLEFT", 10, y - 12)
	title:SetText(text)
	local line = Rect(page, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", title, "RIGHT", 10, 0)
	line:SetPoint("RIGHT", page, "RIGHT", -10, 0)
	return y - 36
end

-- Small grey words under a section
local function Hint(page, y, text)
	local hint = Text(page, "GameFontHighlightSmall", MUTED)
	hint:SetPoint("TOPLEFT", 10, y - 6)
	hint:SetWidth(PAGE_WIDTH - 20)
	hint:SetText(text)
	return y - 16 - ceil(hint:GetStringHeight() or 28)
end

local function Check(page, y, text, get, set, icon, coords)
	local row
	row, y = Row(page, y, "CheckButton", text, PAGE_WIDTH - (icon and 92 or 66))
	Highlight(row)
	if icon then
		local picture = Icon(row, 18, icon, coords)
		picture:SetPoint("LEFT", 10, 0)
		row.label:SetPoint("LEFT", 36, 0)
	end
	local switch, Paint = Switch(row, 34, 18)
	switch:SetPoint("RIGHT", -10, 0)
	row:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Paint()
		Click()
	end)
	row.Refresh = function()
		row:SetChecked(get())
		Paint()
	end
	row.setting = text
	table.insert(page.controls, row)
	return y
end

local function Slider(page, y, text, low, high, step, get, set)
	local row
	row, y = Row(page, y, "Frame", text, PAGE_WIDTH - 236)
	local value = Text(row, "GameFontHighlight", ACCENT)
	value:SetPoint("RIGHT", -10, 0)
	value:SetWidth(40)
	value:SetJustifyH("RIGHT")
	local slider = CreateFrame("Slider", nil, row)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(150, 18)
	slider:SetPoint("RIGHT", -58, 0)
	slider:EnableMouse(true)
	local track = Rect(slider, "BACKGROUND", 0.27, 0.23, 0.26)
	track:SetSize(150, 4)
	track:SetPoint("CENTER")
	local thumb = Block(slider, "OVERLAY", 10, 16)
	slider:SetThumbTexture(thumb)
	local fill = Rect(slider, "ARTWORK", unpack(ACCENT))
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		value:SetText(v)
		if not self.loading then set(v) end
	end)
	slider.Refresh = function()
		slider.loading = true
		slider:SetValue(get())
		value:SetText(get())
		slider.loading = false
	end
	slider.setting = text
	table.insert(page.controls, slider)
	return y
end

-- One of a few values, with arrows to go through them: { { value, text, font =, icon = }, ... }
local function Choice(page, y, text, choices, get, set, icon)
	local row
	row, y = Row(page, y, "Frame", text, PAGE_WIDTH - (icon and 306 or 280), 34)
	if icon then
		local picture = Icon(row, 18, icon)
		picture:SetPoint("LEFT", 10, 0)
		row.label:SetPoint("LEFT", 36, 0)
	end
	local box = CreateFrame("Button", nil, row)
	box:SetSize(250, 26)
	box:SetPoint("RIGHT", -10, 0)
	Rect(box, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
	Highlight(box)
	local value = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", 26, 0)
	value:SetPoint("RIGHT", -26, 0)
	value:SetWordWrap(false)
	box:SetFontString(value)
	local picture = Icon(box, 16)
	local function Pick(step)
		local at = 1
		for i, c in ipairs(choices) do
			if c[1] == get() then at = i end
		end
		set(choices[(at - 1 + step) % #choices + 1][1])
		box.Refresh()
		Click()
	end
	box:SetScript("OnClick", function() Pick(1) end)
	for _, side in ipairs({ { "LEFT", "<", -1 }, { "RIGHT", ">", 1 } }) do
		local arrow = CreateFrame("Button", nil, box)
		arrow:SetSize(26, 26)
		arrow:SetPoint(side[1])
		local glyph = arrow:CreateFontString(nil, "ARTWORK")
		Fancy(glyph, 15)
		glyph:SetPoint("CENTER")
		glyph:SetText(side[2])
		glyph:SetTextColor(unpack(MUTED))
		arrow:SetScript("OnEnter", function() glyph:SetTextColor(unpack(ACCENT)) end)
		arrow:SetScript("OnLeave", function() glyph:SetTextColor(unpack(MUTED)) end)
		arrow:SetScript("OnClick", function() Pick(side[3]) end)
	end
	box.Refresh = function()
		for _, c in ipairs(choices) do
			if c[1] == get() then
				-- A font choice is written in that font
				ns.UseFont(value, c.font, c.font and 14 or 13)
				box:SetText(c[2])
				picture:SetShown(c.icon ~= nil)
				if c.icon then
					picture:SetTexture(c.icon)
					picture:ClearAllPoints()
					picture:SetPoint("RIGHT", value, "CENTER", -floor((value:GetStringWidth() or 0) / 2) - 5, 0)
				end
			end
		end
	end
	box.setting = text
	table.insert(page.controls, box)
	return y
end

local function PickColor(color, changed)
	local old = { r = color.r, g = color.g, b = color.b }
	local function apply()
		color.r, color.g, color.b = ColorPickerFrame:GetColorRGB()
		changed()
	end
	local function cancel()
		color.r, color.g, color.b = old.r, old.g, old.b
		changed()
	end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({ r = color.r, g = color.g, b = color.b, swatchFunc = apply, cancelFunc = cancel })
	else
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
		ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end
end

-- A row with a square of colour on the right: click it to pick another
local function Swatch(page, y, text, color, changed)
	local row
	row, y = Row(page, y, "Button", text, PAGE_WIDTH - 66)
	Highlight(row)
	local edge = Rect(row, "ARTWORK", 0, 0, 0, 1)
	edge:SetSize(36, 20)
	edge:SetPoint("RIGHT", -10, 0)
	local square = Rect(row, "OVERLAY", color.r, color.g, color.b, 1)
	square:SetSize(34, 18)
	square:SetPoint("CENTER", edge)
	row.Refresh = function() square:SetColorTexture(color.r, color.g, color.b, 1) end
	row:SetScript("OnClick", function()
		Click()
		PickColor(color, function()
			changed()
			row.Refresh()
		end)
	end)
	row.setting = text
	table.insert(page.controls, row)
	return y
end

-- A row that does something when you click it, its word on the right
local function Action(page, y, text, word, run)
	local row
	row, y = Row(page, y, "Button", text, PAGE_WIDTH - 130)
	Highlight(row)
	local label = Text(row, "GameFontHighlight", ACCENT)
	label:SetPoint("RIGHT", -10, 0)
	label:SetJustifyH("RIGHT")
	label:SetText(word)
	row:SetScript("OnClick", function()
		Click()
		run()
	end)
	row.Refresh = function() end
	row.setting = text
	table.insert(page.controls, row)
	return y
end

-- The range display as it will look, one sample per state: click one to change its colour
local SAMPLES = { melee = { 0, 5, 3 }, judge = { 5, 10, 8 }, ranged = { 15, 20, 18 }, heal = { 30, 35, 32 },
	out = { 35, 40, 37 } }
local SAMPLE_ORDER = { "melee", "judge", "ranged", "heal", "out" }

local function Preview(page, y, changed)
	local range = ns.db.range
	local card = CreateFrame("Frame", nil, page)
	card:SetSize(PAGE_WIDTH - 20, 96)
	card:SetPoint("TOPLEFT", 10, y - 4)
	Rect(card, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
	local hint = Text(card, "GameFontHighlightSmall", MUTED)
	hint:SetPoint("BOTTOM", 0, 6)
	hint:SetText(L.PREVIEW_HINT)
	for place, state in ipairs(SAMPLE_ORDER) do
		local s = SAMPLES[state]
		local sample = CreateFrame("Button", nil, card)
		Highlight(sample, 0.06)
		local square = sample:CreateTexture(nil, "ARTWORK")
		local number = sample:CreateFontString(nil, "ARTWORK")
		local unit = sample:CreateFontString(nil, "ARTWORK")
		local caption = Text(sample, "GameFontHighlightSmall", MUTED)
		caption:SetPoint("BOTTOM", 0, 4)
		caption:SetText(L.RANGE[state])
		sample.number, sample.unit = number, unit
		sample.Refresh = function()
			local cell = (PAGE_WIDTH - 20) / #SAMPLE_ORDER
			sample:SetSize(cell - 8, 70)
			sample:ClearAllPoints()
			sample:SetPoint("TOPLEFT", (place - 1) * cell + 4, -4)
			local c = range.colors[state]
			local size = min(range.textSize, 22)
			local font = ns.FONTS[range.font]
			-- Melee in words, as on the display
			local words = range.words and state == "melee"
			ns.UseFont(number, font, words and max(floor(size * 0.7), 10) or size, "THICKOUTLINE")
			ns.UseFont(unit, font, max(floor(size * 0.5), 8), "OUTLINE")
			number:SetText(words and L.RANGE.melee or ns.RangeNumber(s[1], s[2], s[3]))
			local unitShown = range.unitLabel and not words
			unit:SetText(unitShown and (range.units == "meters" and L.METERS or L.YARDS) or "")
			number:SetTextColor(c.r, c.g, c.b)
			unit:SetTextColor(c.r, c.g, c.b)
			square:SetColorTexture(c.r, c.g, c.b)
			-- Text, a colour square or both, centred together
			local showText, showSquare = range.style ~= "icon", range.style ~= "text"
			number:SetShown(showText)
			unit:SetShown(showText)
			square:SetShown(showSquare)
			local side = floor(size * 0.7)
			local width = (showSquare and side or 0) + (showSquare and showText and 6 or 0)
				+ (showText and (number:GetStringWidth() or 0) + (unitShown and 3 + (unit:GetStringWidth() or 0) or 0) or 0)
			local x = -width / 2
			square:SetSize(side, side)
			square:ClearAllPoints()
			square:SetPoint("LEFT", sample, "CENTER", x, 8)
			if showSquare then x = x + side + 6 end
			number:ClearAllPoints()
			number:SetPoint("LEFT", sample, "CENTER", x, 8)
			unit:ClearAllPoints()
			unit:SetPoint("BOTTOMLEFT", number, "BOTTOMRIGHT", 3, 2)
		end
		sample:SetScript("OnClick", function() PickColor(range.colors[state], changed) end)
		sample.setting = L.RANGE[state]
		table.insert(page.controls, sample)
	end
	return y - 108
end

-- Pages and the menu

local function UpdateScrollBar()
	local range, height = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
	if range < 1 or height < 1 then
		scrollBar:Hide()
		return
	end
	local thumb = max(height * height / (height + range), 30)
	scrollBar.thumb:SetHeight(thumb)
	scrollBar.thumb:ClearAllPoints()
	scrollBar.thumb:SetPoint("TOP", 0, -(scroll:GetVerticalScroll() or 0) / range * (height - thumb))
	scrollBar:Show()
end

local function NewPage(key, title, icon, coords)
	local page = CreateFrame("Frame", nil, scroll)
	page:SetSize(PAGE_WIDTH, 10)
	page:Hide()
	page.controls = {}
	page.key = key
	pages[#pages + 1] = page
	local tab = CreateFrame("Button", nil, window)
	tab:SetSize(SIDE, 38)
	tab:SetPoint("TOPLEFT", 0, -TOP - 12 - (#pages - 1) * 40)
	Highlight(tab)
	tab.selected = Rect(tab, "BACKGROUND", ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
	tab.selected:SetAllPoints()
	tab.bar = Rect(tab, "ARTWORK", unpack(ACCENT))
	tab.bar:SetPoint("TOPLEFT")
	tab.bar:SetPoint("BOTTOMLEFT")
	tab.bar:SetWidth(3)
	tab.icon = Icon(tab, 22, icon, coords)
	tab.icon:SetPoint("LEFT", 18, 0)
	tab.label = tab:CreateFontString(nil, "ARTWORK")
	Fancy(tab.label, 15)
	tab.label:SetPoint("LEFT", tab.icon, "RIGHT", 10, 0)
	tab.label:SetText(title)
	tab:SetScript("OnClick", function()
		ns.ShowOptionsPage(key)
		Click()
	end)
	tab.key = key
	tabs[#tabs + 1] = tab
	return page, -4
end

-- The page is as tall as what's on it, so the window scrolls when it doesn't fit
local function Done(page, y)
	page:SetHeight(-y + 12)
end

function ns.ShowOptionsPage(key)
	for i, page in ipairs(pages) do
		local on = page.key == key
		local tab = tabs[i]
		page:SetShown(on)
		tab.selected:SetShown(on)
		tab.bar:SetShown(on)
		tab.label:SetTextColor(unpack(on and TEXT or MUTED))
		if on then
			scroll:SetScrollChild(page)
			scroll:SetVerticalScroll(0)
			for _, control in ipairs(page.controls) do control.Refresh() end
		end
	end
	window.page = key
	UpdateScrollBar()
end

local function RefreshPage(key)
	for _, page in ipairs(pages) do
		if page.key == key and page:IsShown() then
			for _, control in ipairs(page.controls) do control.Refresh() end
		end
	end
end
ns.RefreshOptionsPage = RefreshPage

local function BuildWindow()
	window = CreateFrame("Frame", "PaladinGodOptions", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("HIGH")
	window:SetToplevel(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	table.insert(UISpecialFrames, "PaladinGodOptions") -- Escape closes it

	local edge = Rect(window, "BACKGROUND", 0, 0, 0, 0.9, -8)
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	Rect(window, "BACKGROUND", 0.08, 0.06, 0.08, 0.97, -7):SetAllPoints()
	local side = Rect(window, "BACKGROUND", 0.06, 0.04, 0.06, 0.98, -6)
	side:SetPoint("TOPLEFT")
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(SIDE)
	local head = Rect(window, "BACKGROUND", 0.06, 0.04, 0.06, 0.98, -6)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(TOP)
	local headLine = Rect(window, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
	headLine:SetPoint("TOPLEFT", 0, -TOP)
	headLine:SetPoint("TOPRIGHT", 0, -TOP)
	headLine:SetHeight(1)
	local sideLine = Rect(window, "ARTWORK", 1, 1, 1, 0.06)
	sideLine:SetPoint("TOPLEFT", SIDE, -TOP - 1)
	sideLine:SetPoint("BOTTOMLEFT", SIDE, 0)
	sideLine:SetWidth(1)

	local logo = window:CreateTexture(nil, "ARTWORK")
	logo:SetSize(38, 38)
	logo:SetPoint("TOPLEFT", 16, -11)
	logo:SetTexture("Interface\\AddOns\\PaladinGod\\media\\icon")
	local title = window:CreateFontString(nil, "ARTWORK")
	Fancy(title, 22)
	title:SetTextColor(unpack(TEXT))
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
	title:SetText("PaladinGod")
	local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	local version = GetMetadata and GetMetadata(addonName, "Version")
	local subtitle = Text(window, "GameFontHighlightSmall", MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
	subtitle:SetText(version and L.SUBTITLE .. "  ·  v" .. version or L.SUBTITLE)

	local close = CreateFrame("Button", nil, window)
	close:SetSize(32, 32)
	close:SetPoint("TOPRIGHT", -12, -14)
	Highlight(close, 0.08)
	local cross = close:CreateFontString(nil, "ARTWORK")
	cross:SetFont(GameFontNormal:GetFont(), 22, "")
	cross:SetPoint("CENTER", 0, 1)
	cross:SetText("×")
	cross:SetTextColor(unpack(MUTED))
	close:SetScript("OnEnter", function() cross:SetTextColor(1, 0.4, 0.35) end)
	close:SetScript("OnLeave", function() cross:SetTextColor(unpack(MUTED)) end)
	close:SetScript("OnClick", function() window:Hide() end)

	scroll = CreateFrame("ScrollFrame", nil, window)
	scroll:SetPoint("TOPLEFT", SIDE + 16, -TOP - 8)
	scroll:SetPoint("BOTTOMRIGHT", -24, 10)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(min(max((self:GetVerticalScroll() or 0) - delta * 40, 0), range))
		UpdateScrollBar()
	end)
	scroll:SetScript("OnScrollRangeChanged", UpdateScrollBar)
	scrollBar = CreateFrame("Frame", nil, window)
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 10, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 10, 0)
	scrollBar:SetWidth(4)
	Rect(scrollBar, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
	scrollBar.thumb = Rect(scrollBar, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
	scrollBar.thumb:SetWidth(4)
	scrollBar:Hide()
end

-- "Seal of Righteousness" and so on: each key's spell name, with its icon, for a Choice
local function SpellChoices(list, order, auto)
	local out = { { "auto", auto } }
	for _, key in ipairs(order) do
		local id = list[key][1]
		out[#out + 1] = { key, SpellName(id) or key, icon = SpellIcon(id) }
	end
	return out
end

local function ClassName(class)
	local names = LOCALIZED_CLASS_NAMES_MALE
	return names and names[class] or L.CLASSES[class] or class
end

local function Build()
	local db = ns.db
	BuildWindow()

	-- Reminders: your aura, blessing, Righteous Fury, seal and food
	local buffs = db.buffs
	local page, y = NewPage("buffs", L.TAB_BUFFS, SpellIcon(465, "Interface\\Icons\\Spell_Holy_DevotionAura"))
	local function Buffs() ns.UpdateBuffs() end
	y = Section(page, y, L.SEC_BUFFS)
	y = Check(page, y, L.OPT_BUFFS_ON, function() return buffs.enabled end, function(v) buffs.enabled = v Buffs() end)
	y = Check(page, y, L.OPT_AURA, function() return buffs.aura end, function(v) buffs.aura = v Buffs() end, SpellIcon(465))
	y = Choice(page, y, L.OPT_AURA_CHOICE, SpellChoices(ns.AURA_SPELLS, ns.AURA_ORDER, L.AURA_AUTO),
		function() return buffs.auraChoice end, function(v) buffs.auraChoice = v Buffs() end)
	y = Check(page, y, L.OPT_BLESSING, function() return buffs.blessing end, function(v) buffs.blessing = v Buffs() end,
		SpellIcon(19740))
	y = Choice(page, y, L.OPT_BLESSING_CHOICE, SpellChoices(ns.BLESSING_SPELLS, ns.BLESSING_ORDER, L.BLESSING_AUTO),
		function() return buffs.blessingChoice end, function(v) buffs.blessingChoice = v Buffs() end)
	local fury = SpellName(ns.FURY_SPELLS[1]) or "Righteous Fury"
	y = Choice(page, y, fury, { { "warn", L.FURY.warn }, { "tank", L.FURY.tank }, { "off", L.FURY.off } },
		function() return buffs.fury end, function(v) buffs.fury = v Buffs() end, SpellIcon(ns.FURY_SPELLS[1]))
	y = Slider(page, y, L.OPT_WARN_TIME, 1, 10, 1, function() return buffs.warnMinutes end,
		function(v) buffs.warnMinutes = v Buffs() end)
	y = Check(page, y, L.OPT_TEXT, function() return buffs.text end, function(v) buffs.text = v Buffs() end)
	y = Check(page, y, L.OPT_CLICK, function() return buffs.click end, function(v)
		buffs.click = v
		Buffs()
		ns.SyncReminders()
		ns.UpdateSeal()
	end)
	y = Hint(page, y, L.BUFFS_HINT)
	local seal = db.seal
	local function SealChanged() ns.StyleSeal() end
	y = Section(page, y, L.SEC_SEAL)
	y = Check(page, y, L.OPT_SEAL, function() return seal.enabled end, function(v) seal.enabled = v SealChanged() end,
		SpellIcon(ns.SEAL_SPELLS.righteousness[1]))
	y = Choice(page, y, L.OPT_SEAL_CHOICE, SpellChoices(ns.SEAL_SPELLS, ns.SEAL_ORDER, L.SEAL_AUTO),
		function() return seal.choice end, function(v) seal.choice = v SealChanged() end)
	y = Check(page, y, L.OPT_SEAL_TARGET, function() return seal.target end, function(v) seal.target = v SealChanged() end)
	y = Slider(page, y, L.OPT_SIZE, 24, 80, 2, function() return seal.size end, function(v) seal.size = v SealChanged() end)
	y = Hint(page, y, L.SEAL_HINT)
	y = Section(page, y, L.SEC_GATHER)
	y = Check(page, y, format(L.OPT_GATHER, SpellName(2383) or "Find Herbs", SpellName(2580) or "Find Minerals"),
		function() return db.gather.enabled end, function(v) db.gather.enabled = v ns.UpdateGather() end,
		SpellIcon(2580, "Interface\\Icons\\Spell_Nature_Earthquake"))
	y = Section(page, y, L.SEC_REAGENTS)
	y = Check(page, y, format(L.OPT_REAGENTS, SpellName(1225503) or "Reagent Economy"),
		function() return db.reagents.enabled end, function(v) db.reagents.enabled = v ns.RefreshReagents() end,
		ns.ItemIconOf and ns.ItemIconOf(21177))
	y = Check(page, y, ns.REAGENT_TEXT.OPT_BUY, function() return db.reagents.buy end, function(v) db.reagents.buy = v end)
	y = Check(page, y, ns.REAGENT_MAP_TEXT.OPT_MAP, function() return db.reagents.map end, function(v) db.reagents.map = v ns.RefreshReagentMap() end)
	y = Hint(page, y, L.REAGENTS_HINT)
	local repair = db.repair
	y = Section(page, y, L.SEC_REPAIR)
	y = Check(page, y, L.OPT_REPAIR, function() return repair.enabled end, function(v) repair.enabled = v ns.RefreshRepair() end,
		"Interface\\Icons\\Trade_BlackSmithing")
	y = Slider(page, y, L.OPT_REPAIR_LOW, 5, 75, 5, function() return repair.low end, function(v) repair.low = v ns.RefreshRepair() end)
	y = Slider(page, y, L.OPT_REPAIR_BAGS, 0, 10, 1, function() return repair.bags end, function(v) repair.bags = v ns.RefreshRepair() end)
	y = Check(page, y, ns.REPAIR_TEXT.OPT_AUTO, function() return db.repair.auto end, function(v) db.repair.auto = v end,
		"Interface\\Icons\\INV_Misc_Coin_02")
	y = Hint(page, y, L.REPAIR_HINT)
	y = Section(page, y, L.SEC_FOOD)
	y = Check(page, y, L.OPT_FOOD_ON, function() return db.food.enabled end, function(v) db.food.enabled = v Buffs() end,
		SpellIcon(19705))
	y = Section(page, y, L.SEC_RESPEC)
	y = Check(page, y, L.OPT_RESPEC, function() return db.respec.enabled end, function(v) db.respec.enabled = v end,
		"Interface\\Icons\\INV_Misc_Coin_01")
	y = Hint(page, y, L.RESPEC_HINT)
	Done(page, y)

	-- Your group's blessings
	local group = db.group
	local function GroupChanged() ns.UpdateGroup() end
	page, y = NewPage("group", L.TAB_GROUP, SpellIcon(20217, "Interface\\Icons\\Spell_Magic_MageArmor"))
	y = Section(page, y, L.SEC_GROUP)
	y = Check(page, y, L.OPT_GROUP, function() return group.enabled end, function(v) group.enabled = v GroupChanged() end,
		SpellIcon(20217))
	y = Slider(page, y, L.OPT_GROUP_ROWS, 3, 20, 1, function() return group.maxRows end,
		function(v) group.maxRows = v GroupChanged() end)
	y = Hint(page, y, L.GROUP_HINT)
	-- The family's group buffs: none for a paladin today, so the switch only shows should it get some
	if ns.GROUP_BUFFS and ns.GROUP_BUFFS.PALADIN then
		y = Check(page, y, L.OPT_GROUP_BUFFS, function() return db.groupBuffs.enabled end,
			function(v) db.groupBuffs.enabled = v ns.RefreshGroupBuffs() end)
	end
	y = Section(page, y, L.SEC_CLASSES)
	local perClass = {}
	for _, key in ipairs(ns.BLESSING_ORDER) do
		local id = ns.BLESSING_SPELLS[key][1]
		perClass[#perClass + 1] = { key, SpellName(id) or key, icon = SpellIcon(id) }
	end
	perClass[#perClass + 1] = { "none", L.GROUP_NONE }
	for _, class in ipairs(ns.CLASS_ORDER) do
		y = Choice(page, y, ClassName(class), perClass, function() return group.classes[class] end,
			function(v) group.classes[class] = v GroupChanged() end)
	end
	Done(page, y)

	-- Combat: the swing timer, Hammer of Wrath and Exorcism
	local swing = db.swing
	local function SwingChanged()
		ns.StyleSwing()
		ns.SwingBlizzard()
	end
	page, y = NewPage("combat", L.TAB_COMBAT, SpellIcon(24275, "Interface\\Icons\\Ability_ThunderClap"))
	y = Section(page, y, L.SEC_SWING)
	y = Check(page, y, L.OPT_SWING, function() return swing.enabled end, function(v) swing.enabled = v SwingChanged() end,
		"Interface\\Icons\\INV_Hammer_04")
	y = Slider(page, y, L.OPT_WIDTH, 80, 400, 5, function() return swing.width end, function(v) swing.width = v SwingChanged() end)
	y = Slider(page, y, L.OPT_HEIGHT, 6, 30, 1, function() return swing.height end, function(v) swing.height = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_ICON, function() return swing.icon end, function(v) swing.icon = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_TIME, function() return swing.time end, function(v) swing.time = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_BLIZZARD, function() return swing.hideBlizzard end,
		function(v) swing.hideBlizzard = v SwingChanged() end)
	y = Swatch(page, y, L.OPT_COLOR, swing.color, SwingChanged)
	y = Action(page, y, L.OPT_TEST, L.TRY, ns.TestSwing)
	y = Hint(page, y, L.SWING_HINT)
	local execute = db.execute
	local function ExecuteChanged() ns.StyleExecute() end
	y = Section(page, y, L.SEC_EXECUTE)
	y = Check(page, y, format(L.OPT_HAMMER, SpellName(24275) or "Hammer of Wrath"), function() return execute.hammer end,
		function(v) execute.hammer = v ExecuteChanged() end, SpellIcon(24275))
	y = Check(page, y, format(L.OPT_EXORCISM, SpellName(879) or "Exorcism"), function() return execute.exorcism end,
		function(v) execute.exorcism = v ExecuteChanged() end, SpellIcon(879))
	y = Check(page, y, format(L.OPT_INTERRUPT, SpellName(853) or "Hammer of Justice"), function() return execute.interrupt end,
		function(v) execute.interrupt = v ExecuteChanged() end, SpellIcon(853))
	y = Slider(page, y, L.OPT_SIZE, 24, 96, 2, function() return execute.size end, function(v) execute.size = v ExecuteChanged() end)
	y = Action(page, y, L.OPT_TEST, L.TRY, ns.TestExecute)
	y = Hint(page, y, L.EXECUTE_HINT)
	local cooldowns = db.cooldowns
	local function CooldownsChanged() ns.StyleCooldowns() end
	y = Section(page, y, L.SEC_COOLDOWNS)
	y = Check(page, y, L.OPT_COOLDOWNS, function() return cooldowns.enabled end,
		function(v) cooldowns.enabled = v CooldownsChanged() end)
	for _, entry in ipairs(ns.COOLDOWN_SPELLS) do
		local id = entry.ids[1]
		y = Check(page, y, SpellName(id) or entry.key, function() return cooldowns.spells[entry.key] end,
			function(v) cooldowns.spells[entry.key] = v end, SpellIcon(id))
	end
	y = Slider(page, y, L.OPT_SIZE, 40, 200, 5, function() return cooldowns.size end,
		function(v) cooldowns.size = v CooldownsChanged() ns.TestCooldowns() end)
	y = Slider(page, y, L.OPT_ALPHA, 20, 100, 5, function() return cooldowns.alpha end,
		function(v) cooldowns.alpha = v CooldownsChanged() ns.TestCooldowns() end)
	y = Swatch(page, y, L.OPT_SHINE_COLOR, cooldowns.color, function() CooldownsChanged() ns.TestCooldowns() end)
	y = Action(page, y, L.OPT_TEST, L.TRY, function() ns.TestCooldowns() end)
	y = Hint(page, y, L.COOLDOWNS_HINT)
	local debuffs = db.debuffs
	y = Section(page, y, L.SEC_DEBUFFS)
	y = Check(page, y, L.OPT_DEBUFFS, function() return debuffs.enabled end,
		function(v) debuffs.enabled = v ns.UpdateDebuffs() end, SpellIcon(20271))
	for _, group in ipairs(ns.DEBUFF_GROUPS) do
		y = Check(page, y, L.OPT_DEBUFF[group.key], function() return debuffs[group.key] end,
			function(v) debuffs[group.key] = v ns.UpdateDebuffs() end)
	end
	y = Slider(page, y, L.OPT_SIZE, 14, 40, 1, function() return debuffs.size end, function(v) debuffs.size = v end)
	y = Hint(page, y, L.DEBUFFS_HINT)
	local barrier = db.barrier
	local function BarrierChanged()
		ns.StyleBarrier()
		ns.UpdateBarrier()
	end
	local bulwark = SpellName(1311015) or "Templar's Bulwark"
	y = Section(page, y, L.SEC_BARRIER)
	y = Check(page, y, format(L.OPT_BARRIER, bulwark), function() return barrier.enabled end,
		function(v) barrier.enabled = v BarrierChanged() end, SpellIcon(1311015, "Interface\\Icons\\Spell_Holy_PowerWordShield"))
	y = Check(page, y, L.OPT_BARRIER_POTIONS, function() return barrier.potions end,
		function(v) barrier.potions = v BarrierChanged() end, SpellIcon(17545, "Interface\\Icons\\INV_Potion_09"))
	y = Slider(page, y, L.OPT_WIDTH, 60, 400, 5, function() return barrier.width end, function(v) barrier.width = v BarrierChanged() end)
	y = Slider(page, y, L.OPT_HEIGHT, 6, 40, 1, function() return barrier.height end, function(v) barrier.height = v BarrierChanged() end)
	y = Check(page, y, L.OPT_BARRIER_TEXT, function() return barrier.text end, function(v) barrier.text = v BarrierChanged() end)
	y = Check(page, y, L.OPT_BARRIER_TIME, function() return barrier.time end, function(v) barrier.time = v BarrierChanged() end)
	y = Check(page, y, L.OPT_BARRIER_ICON, function() return barrier.icon end, function(v) barrier.icon = v BarrierChanged() end)
	y = Swatch(page, y, format(L.OPT_BARRIER_COLOR, bulwark), barrier.colors.bulwark, BarrierChanged)
	y = Swatch(page, y, L.OPT_BARRIER_OTHER, barrier.color, BarrierChanged)
	y = Hint(page, y, L.BARRIER_HINT)
	Done(page, y)

	-- Procs: golden light while each is up. Each change shows the sample a moment
	local procs = db.procs
	local function ProcsChanged()
		ns.StyleProcs()
		ns.PeekProcs()
	end
	page, y = NewPage("procs", L.TAB_PROCS, SpellIcon(437063, "Interface\\Icons\\Spell_Holy_HolyBolt"))
	y = Section(page, y, L.SEC_PROCS_LOOK)
	y = Slider(page, y, L.OPT_PROCS_SIZE, 20, 200, 5, function() return procs.size end,
		function(v) ns.SetProcsSize(v) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_X, -600, 600, 5, function() return (ns.ProcsOffset()) end,
		function(v) ns.MoveProcs(v, select(2, ns.ProcsOffset())) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_Y, -400, 400, 5, function() return select(2, ns.ProcsOffset()) end,
		function(v) ns.MoveProcs((ns.ProcsOffset()), v) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_GAP, 40, 400, 5, function() return procs.gap end,
		function(v) procs.gap = v ProcsChanged() end)
	y = Slider(page, y, L.OPT_PROCS_ALPHA, 20, 100, 5, function() return procs.alpha end,
		function(v) procs.alpha = v ProcsChanged() end)
	y = Slider(page, y, L.OPT_PROCS_CALM, 0, 100, 5, function() return procs.calm end,
		function(v) procs.calm = v ProcsChanged() end)
	y = Check(page, y, L.OPT_PROCS_TIMER, function() return procs.timer end, function(v) procs.timer = v ProcsChanged() end)
	y = Slider(page, y, L.OPT_PROCS_TIMER_SIZE, 12, 40, 1, function() return procs.timerSize end,
		function(v) procs.timerSize = v ProcsChanged() end)
	for _, key in ipairs(ns.PROC_ORDER) do
		local o = procs[key]
		local name = ns.ProcName(key)
		local spell = ns.PROC_SPELLS[key][1]
		y = Section(page, y, name)
		y = Check(page, y, format(L.OPT_PROC[key], name), function() return o.enabled end, function(v)
			o.enabled = v
			ns.StyleProcs()
			if v then ns.PeekProcs(key) end
		end, SpellIcon(spell, "Interface\\Icons\\Spell_Holy_HolyBolt"))
		y = Swatch(page, y, L.OPT_COLOR, o.color, function()
			ns.StyleProcs()
			ns.PeekProcs(key)
		end)
		y = Action(page, y, L.OPT_TEST, L.TRY, function() ns.TestProcs(key) end)
	end
	y = Hint(page, y, L.PROCS_HINT)
	Done(page, y)

	-- Range
	local range = db.range
	local function RangeChanged()
		ns.StyleRange()
		ns.UpdateRange()
		RefreshPage("range") -- the preview follows
	end
	page, y = NewPage("range", L.TAB_RANGE, SpellIcon(20271, "Interface\\Icons\\Spell_Holy_RighteousFury"))
	y = Preview(page, y, RangeChanged)
	y = Section(page, y, L.SEC_DISTANCE)
	y = Check(page, y, L.OPT_RANGE_ON, function() return range.enabled end, function(v) range.enabled = v RangeChanged() end)
	y = Check(page, y, L.OPT_FRIENDLY, function() return range.friendly end, function(v) range.friendly = v RangeChanged() end)
	y = Check(page, y, L.OPT_ONLY_COMBAT, function() return range.onlyCombat end, function(v) range.onlyCombat = v RangeChanged() end)
	y = Check(page, y, L.OPT_WORDS, function() return range.words end, function(v) range.words = v RangeChanged() end)
	y = Check(page, y, L.OPT_UNIT_LABEL, function() return range.unitLabel end, function(v) range.unitLabel = v RangeChanged() end)
	y = Section(page, y, L.SEC_LOOK)
	y = Choice(page, y, L.OPT_DISPLAY, { { "number", L.DISPLAY.number }, { "bracket", L.DISPLAY.bracket } },
		function() return range.display end, function(v) range.display = v RangeChanged() end)
	y = Choice(page, y, L.OPT_UNITS, { { "yards", L.UNITS.yards }, { "meters", L.UNITS.meters } },
		function() return range.units end, function(v) range.units = v RangeChanged() end)
	y = Choice(page, y, L.OPT_FONT, {
		{ "fredoka", L.FONTS.fredoka, font = ns.FONTS.fredoka },
		{ "changa", L.FONTS.changa, font = ns.FONTS.changa },
		{ "game", L.FONTS.game },
	}, function() return range.font end, function(v) range.font = v RangeChanged() end)
	y = Choice(page, y, L.OPT_STYLE, { { "text", L.STYLE.text }, { "icon", L.STYLE.icon }, { "both", L.STYLE.both } },
		function() return range.style end, function(v) range.style = v RangeChanged() end)
	y = Choice(page, y, L.OPT_POSITION, { { "plate", L.POSITION.plate }, { "free", L.POSITION.free } },
		function() return range.anchor end, function(v) range.anchor = v RangeChanged() end)
	y = Choice(page, y, L.OPT_PLATE_SIDE, {
		{ "top", L.PLATE_SIDE.top }, { "bottom", L.PLATE_SIDE.bottom },
		{ "left", L.PLATE_SIDE.left }, { "right", L.PLATE_SIDE.right },
	}, function() return range.plateSide end, function(v) range.plateSide = v RangeChanged() end)
	y = Slider(page, y, L.OPT_PLATE_GAP, -20, 60, 1, function() return range.plateGap end,
		function(v) range.plateGap = v RangeChanged() end)
	y = Slider(page, y, L.OPT_SIZE, 12, 48, 1, function() return range.textSize end, function(v) range.textSize = v RangeChanged() end)
	Done(page, y)

	-- Aggro
	page, y = NewPage("threat", L.TAB_THREAT, "Interface\\Icons\\Ability_Warrior_Challange")
	y = Section(page, y, L.SEC_THREAT)
	y = Check(page, y, L.OPT_THREAT, function() return range.threat end, function(v) range.threat = v ns.UpdateThreat() end)
	y = Slider(page, y, L.OPT_THREAT_PCT, 50, 100, 5, function() return range.threatPct end, function(v) range.threatPct = v ns.UpdateThreat() end)
	y = Check(page, y, L.OPT_TANK_WARN, function() return range.tankWarn end, function(v) range.tankWarn = v ns.UpdateThreat() end,
		SpellIcon(ns.FURY_SPELLS[1]))
	y = Hint(page, y, L.THREAT_HINT)
	Done(page, y)

	-- At the foot of the menu: moving the displays and the minimap button
	local unlock = CreateFrame("Button", nil, window)
	unlock:SetSize(SIDE - 28, 30)
	unlock:SetPoint("BOTTOMLEFT", 14, 46)
	Rect(unlock, "BACKGROUND", ACCENT[1], ACCENT[2], ACCENT[3], 0.14):SetAllPoints()
	Highlight(unlock, 0.08)
	local unlockText = unlock:CreateFontString(nil, "ARTWORK")
	Fancy(unlockText, 13)
	unlockText:SetTextColor(unpack(ACCENT))
	unlock:SetFontString(unlockText)
	unlock:SetScript("OnClick", function()
		ns.SetUnlocked(not ns.unlocked)
		unlock:SetText(ns.unlocked and L.LOCK or L.UNLOCK)
	end)
	window.unlockButton = unlock
	local minimap = CreateFrame("CheckButton", nil, window)
	minimap:SetSize(SIDE - 20, 26)
	minimap:SetPoint("BOTTOMLEFT", 10, 12)
	Highlight(minimap)
	local switch, Paint = Switch(minimap, 28, 16)
	switch:SetPoint("LEFT", 4, 0)
	local minimapLabel = Text(minimap, "GameFontHighlightSmall", MUTED)
	minimapLabel:SetPoint("LEFT", switch, "RIGHT", 8, 0)
	minimapLabel:SetPoint("RIGHT", -4, 0)
	minimapLabel:SetText(L.OPT_MINIMAP_BUTTON)
	minimap:SetScript("OnClick", function(self)
		db.minimapButton.hide = not self:GetChecked()
		ns.UpdateMinimapButton()
		Paint()
		Click()
	end)
	window.minimapCheck = minimap
	window:SetScript("OnShow", function()
		minimap:SetChecked(not db.minimapButton.hide)
		Paint()
		unlock:SetText(ns.unlocked and L.LOCK or L.UNLOCK)
	end)
	window:Hide()
end

function ns.ToggleOptions(key)
	if not window then Build() end
	if window:IsShown() and not key then
		window:Hide()
		return
	end
	window:Show()
	ns.ShowOptionsPage(key or window.page or "buffs")
end

-- For the tests
function ns.OptionsWindow()
	return window, pages
end

ns.commands.options = function() ns.ToggleOptions() end
ns.commands.opciones = ns.commands.options
ns.commands.config = ns.commands.options
