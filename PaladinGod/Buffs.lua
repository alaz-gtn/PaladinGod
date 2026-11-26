local _, ns = ...
local L = ns.L

-- Every rank of each aura and blessing: the name covers them all, the ids say which you know
local AURAS = {
	devotion = { 465, 10290, 643, 10291, 1032, 10292, 10293 },
	retribution = { 7294, 10298, 10299, 10300, 10301 },
	concentration = { 19746 },
	shadow = { 19876, 19895, 19896 },
	frost = { 19888, 19897, 19898 },
	fire = { 19891, 19899, 19900 },
}
local AURA_ORDER = { "devotion", "retribution", "concentration", "shadow", "frost", "fire" }
-- In Forever every blessing lasts an hour, and Kings is everyone's from level 20
local BLESSINGS = {
	might = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 },
	wisdom = { 19742, 19850, 19852, 19853, 19854, 25290 },
	kings = { 20217 },
}
local BLESSING_ORDER = { "might", "wisdom", "kings" }
-- The greater ones (from level 52, with Symbol of Kings) count as the same blessing
local GREATER = { might = { 25782, 25916 }, wisdom = { 25894, 25918 }, kings = { 25898 } }
local FURY = { 25780 } -- Righteous Fury: 30 minutes in Forever
ns.AURA_SPELLS, ns.AURA_ORDER = AURAS, AURA_ORDER
ns.BLESSING_SPELLS, ns.BLESSING_ORDER, ns.GREATER_BLESSINGS = BLESSINGS, BLESSING_ORDER, GREATER
ns.FURY_SPELLS = FURY
-- How long each lasts until the game says otherwise
local DURATION = { blessing = 3600, fury = 1800 }
-- Every Well Fed has this name; in Forever cooked food also gives +5% XP from kills
local WELL_FED = 19705

local db
local byName = {} -- spell name -> { slot, key }
local known = {} -- by slot and key: what you've learned
local wellFedName
-- Well Fed in lower case: what the game calls it, and the English and your language's words in
-- case Forever names the buff otherwise
local fedWords = { "well fed" }
-- By slot (aura, blessing, fury, food): GetTime() when it runs out (math.huge for no end), false
-- when it isn't on you, nil while the addon hasn't seen your buffs yet
local ends = {}
local wearing = {} -- by slot: the key of the one that's on you
local lasts = {} -- by slot: how long it lasts, as the game said last time
local inCombat = false
local frames = {} -- by slot: the reminder icons
local food -- the small list beside the chat: the food reminder and your reagents running low
local foodRow -- the food reminder in it

local function Learn()
	wipe(byName)
	for slot, list in pairs({ aura = AURAS, blessing = BLESSINGS }) do
		known[slot] = known[slot] or {}
		for key, ids in pairs(list) do
			local name = ns.SpellName(ids[1])
			if name then byName[name] = { slot = slot, key = key } end
			known[slot][key] = ns.Knows(ids)
		end
	end
	for key, ids in pairs(GREATER) do
		local name = ns.SpellName(ids[1])
		if name then byName[name] = { slot = "blessing", key = key, greater = true } end
	end
	local fury = ns.SpellName(FURY[1])
	if fury then byName[fury] = { slot = "fury", key = "fury" } end
	known.fury = ns.Knows(FURY)
	wellFedName = ns.SpellName(WELL_FED)
	fedWords = { "well fed", strlower(L.WELL_FED) }
	if wellFedName then fedWords[#fedWords + 1] = strlower(wellFedName) end
end

local function IsFedName(name)
	if type(name) ~= "string" then return false end
	local low = strlower(name)
	for _, word in ipairs(fedWords) do
		if low == word then return true end
	end
	return false
end

-- Put on by you: another paladin's aura or blessing on you isn't yours. When the game doesn't say
-- who, it counts
local function Yours(aura)
	local source = aura.sourceUnit
	if not ns.IsSecret(source) and source ~= nil then return source == "player" end
	local mine = aura.isFromPlayerOrPlayerPet
	if not ns.IsSecret(mine) and mine ~= nil then return mine and true or false end
	return true
end

-- Reads your buffs; false when the game hides them (in combat, in Forever). Then what you
-- cast keeps the count
local function Scan()
	if ns.AurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
	local found = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) or ns.IsSecret(aura.expirationTime) then return false end
		local spell = byName[aura.name]
		local slot = spell and spell.slot or (IsFedName(aura.name) and "food")
		if slot and not found[slot] and (slot == "food" or slot == "fury" or Yours(aura)) then
			local duration = aura.duration
			if spell and not ns.IsSecret(duration) and type(duration) == "number" and duration > 0 then
				lasts[slot] = duration
			end
			local expires = aura.expirationTime
			found[slot] = { key = spell and spell.key, ends = type(expires) == "number" and expires > 0 and expires or math.huge }
		end
	end
	for _, slot in ipairs({ "aura", "blessing", "fury", "food" }) do
		ends[slot] = found[slot] and found[slot].ends or false
		wearing[slot] = found[slot] and found[slot].key
	end
	if wearing.aura then ns.db.lastAura = wearing.aura end
	if wearing.blessing then ns.db.lastBlessing = wearing.blessing end
	return true
end

-- The one to put on: the one you chose, or the last you had, or the first you know
local function Wanted(slot, choice, last, order)
	local pick = choice == "auto" and last or choice
	if pick and known[slot][pick] then return pick end
	for _, key in ipairs(order) do
		if known[slot][key] then return key end
	end
end

-- Is the one on you the one wanted? With "auto" any will do
local function Fits(choice, want, on)
	if not on then return false end
	return choice == "auto" or on == want
end

-- Free to cast: not mounted (casting would get you off)
local function Mounted()
	return IsMounted and IsMounted() or false
end

-- Righteous Fury on, as far as the addon knows: Range.lua's aggro warning asks
function ns.FuryOn()
	local e = ends.fury
	return e and e > GetTime() or false
end

-- Tanking: Righteous Fury on, or you said you tank
function ns.IsTank()
	return (db and db.fury == "tank") or ns.FuryOn()
end

local function SpellOf(slot, key)
	if slot == "aura" then return AURAS[key][1] end
	if slot == "blessing" then return BLESSINGS[key][1] end
	return FURY[1]
end

-- Shows a reminder icon. left: seconds it has left (0 when it's missing); warn: on, but it
-- shouldn't be
local function Remind(slot, key, left, warn)
	local f = frames[slot]
	local id = SpellOf(slot, key)
	f.icon:SetTexture(ns.SpellIcon(id))
	-- Grey while it's missing, in colour with its time left while it runs out
	f.icon:SetDesaturated(left == 0 and not warn)
	local text = ""
	if warn then
		text = L.FURY_WARN
		f.text:SetTextColor(1, 0.25, 0.2)
	elseif left > 0 then
		text = ns.Clock(left)
		f.text:SetTextColor(1, 0.85, 0.4)
	end
	f.text:SetText(text)
	f.text:SetShown(db.text or left > 0)
	f.spellName = ns.SpellName(id)
	f.cancel = warn or nil
	f.missing = left == 0 and not warn
	if not f:IsShown() then f:Show() end
	-- The click follows what it casts now
	ns.SyncReminders()
end

local function Clear(slot)
	local f = frames[slot]
	f.spellName, f.cancel = nil, nil
	if f:IsShown() then f:Hide() end
end

-- Which reminders show now, and how
local function Update()
	if not db then return end
	local now, warnAt = GetTime(), db.warnMinutes * 60
	local function Left(slot)
		local e = ends[slot]
		return e and max(e - now, 0) or 0
	end
	if ns.unlocked then
		-- Samples to drag around
		if db.enabled and db.aura then Remind("aura", "devotion", 0) else Clear("aura") end
		if db.enabled and db.blessing then Remind("blessing", "might", 95) else Clear("blessing") end
		if db.enabled and db.fury ~= "off" then Remind("fury", "fury", 0, db.fury == "warn") else Clear("fury") end
		return
	end
	local on = db.enabled and ns.IsPaladin() and not ns.Away()
	-- Your aura, in combat too: it lasts until you take it off, so the one from before the fight holds
	local auraKey = on and db.aura and ends.aura ~= nil and Wanted("aura", db.auraChoice, ns.db.lastAura, AURA_ORDER)
	if auraKey and not Fits(db.auraChoice, auraKey, ends.aura and wearing.aura) and (inCombat or not Mounted()) then
		Remind("aura", auraKey, 0)
	else
		Clear("aura")
	end
	-- Your blessing on you, out of combat: missing or in its last minutes
	local blessKey = on and db.blessing and not inCombat and ends.blessing ~= nil
		and Wanted("blessing", db.blessingChoice, ns.db.lastBlessing, BLESSING_ORDER)
	local fits = blessKey and Fits(db.blessingChoice, blessKey, ends.blessing and wearing.blessing)
	local blessLeft = fits and Left("blessing") or 0
	if blessKey and not Mounted() and (not fits or blessLeft <= warnAt) then
		Remind("blessing", fits and wearing.blessing or blessKey, blessLeft)
	else
		Clear("blessing")
	end
	-- Righteous Fury: a tank's reminder, or a warning for whoever doesn't tank and has it on in a group
	local furyOn = ends.fury and Left("fury") > 0
	if on and known.fury and ends.fury ~= nil and db.fury == "tank" and (not furyOn or Left("fury") <= warnAt)
		and (inCombat or not Mounted()) then
		Remind("fury", "fury", furyOn and Left("fury") or 0)
	elseif on and db.fury == "warn" and furyOn and IsInGroup() then
		Remind("fury", "fury", 0, true)
	else
		Clear("fury")
	end
end

-- The small food reminder beside the chat, out of combat, and the list of your XP food it opens
local ROW, ROW_GAP = 22, 2
local PINK = ns.ACCENT
local TEXT_PINK = { 1, 0.86, 0.92 }
local menu = CreateFrame("Frame", "PaladinGodFoodMenu", UIParent)
menu:SetSize(120, 22)
menu:Hide()
local menuRows = {}

local function FoodMissing()
	if not ns.db.food.enabled or not ns.IsPaladin() or inCombat or ns.Away() then return false end
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
	if UnitLevel("player") >= maxLevel then return false end
	return ends.food == false
end

-- The XP food in your bags: food whose tooltip promises Well Fed (in Forever, cooked food, which
-- also gives +5% XP from kills). Each item is looked at once its tooltip has loaded
local xpFood = {} -- by item: true / false
local foodStock = {} -- { id, count }, in the order of your bags

local function IsXPFood(id, bag, slot)
	if xpFood[id] ~= nil then return xpFood[id] end
	local getInfo = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	local classID, subclassID = select(6, getInfo(id))
	-- Food & Drink only
	if classID ~= 0 or subclassID ~= 5 then
		xpFood[id] = false
		return false
	end
	if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
	local data = C_TooltipInfo.GetBagItem(bag, slot)
	if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
	local use = strlower(ITEM_SPELL_TRIGGER_ONUSE or "Use:")
	local loaded = false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if type(text) == "string" and not ns.IsSecret(text) then
			local low = strlower(text)
			for _, word in ipairs(fedWords) do
				if low:find(word, 1, true) then
					xpFood[id] = true
					return true
				end
			end
			-- What eating it does, written out: the game has its text
			if low:sub(1, #use) == use and #low > #use + 8 then loaded = true end
		end
	end
	-- Read before the game had loaded what it does: looked at again next time, not written off
	if loaded then xpFood[id] = false end
	return false
end

local function ScanFood()
	wipe(foodStock)
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
	local byID = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = type(info) == "table" and info.itemID
			if id and not ns.IsSecret(id) and IsXPFood(id, bag, slot) then
				local entry = byID[id]
				if not entry then
					entry = { id = id, count = 0 }
					byID[id] = entry
					foodStock[#foodStock + 1] = entry
				end
				local count = info.stackCount
				entry.count = entry.count + (not ns.IsSecret(count) and type(count) == "number" and count or 1)
			end
		end
	end
end

local function ItemIcon(item)
	return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item) or GetItemIcon and GetItemIcon(item)
end
ns.ItemIconOf = ItemIcon

-- A dark bar with a pink stripe on its left, the icon in a thin pink frame and light pink text
local function DarkRow(b)
	b.back = b:CreateTexture(nil, "BACKGROUND")
	b.back:SetAllPoints()
	b.back:SetColorTexture(0.06, 0.03, 0.05, 0.85)
	b.stripe = b:CreateTexture(nil, "BORDER")
	b.stripe:SetPoint("TOPLEFT")
	b.stripe:SetPoint("BOTTOMLEFT")
	b.stripe:SetWidth(2)
	b.stripe:SetColorTexture(PINK[1], PINK[2], PINK[3], 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("LEFT", 6, 0)
	b.icon:SetSize(ROW - 6, ROW - 6)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.edge = b:CreateTexture(nil, "BORDER")
	b.edge:SetPoint("TOPLEFT", b.icon, -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
	b.edge:SetColorTexture(PINK[1], PINK[2], PINK[3], 0.9)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
	b.text:SetShadowOffset(1, -1)
	b.text:SetShadowColor(0, 0, 0, 1)
	b.text:SetTextColor(TEXT_PINK[1], TEXT_PINK[2], TEXT_PINK[3])
end
ns.DarkRow = DarkRow

local function MenuRow_OnEnter(self)
	if not self.itemID then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
	GameTooltip:AddLine(L.CLICK_EAT, 0.4, 0.8, 1)
	GameTooltip:Show()
end

local function MenuRow(i)
	local b = menuRows[i]
	if b then return b end
	b = CreateFrame("Button", "PaladinGodFoodMenu" .. i, menu, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	DarkRow(b)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	b:SetScript("OnEnter", MenuRow_OnEnter)
	b:SetScript("OnLeave", GameTooltip_Hide)
	-- Once you've picked one the list goes (the game has eaten it by then)
	b:HookScript("OnClick", function(self, _, down)
		if not down and self.itemID and not InCombatLockdown() then menu:Hide() end
	end)
	menuRows[i] = b
	return b
end

local function FillMenu()
	local list = {}
	for _, f in ipairs(foodStock) do
		local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(f.id)
		list[#list + 1] = { id = f.id, text = format("%s  x%d", name or "?", f.count), icon = ItemIcon(f.id) }
	end
	if #list == 0 then list[1] = { text = L.NO_XP_FOOD, icon = ns.SpellIcon(WELL_FED) } end
	local width = 120
	for i, r in ipairs(list) do
		local b = MenuRow(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW + ROW_GAP))
		b:SetHeight(ROW)
		ns.ThinFont(b.text, 13)
		b.text:SetText(r.text)
		b.icon:SetTexture(r.icon)
		b.icon:SetDesaturated(r.id == nil)
		b.itemID = r.id
		local use = r.id and ("item:" .. r.id) or nil
		if b:GetAttribute("type") ~= (use and "item" or nil) then b:SetAttribute("type", use and "item" or nil) end
		if b:GetAttribute("item") ~= use then b:SetAttribute("item", use) end
		width = max(width, b.text:GetStringWidth() + ROW + 24)
		b:Show()
	end
	for i = 1, #list do menuRows[i]:SetWidth(width) end
	for i = #list + 1, #menuRows do menuRows[i]:Hide() end
	menu:SetSize(width, #list * (ROW + ROW_GAP) - ROW_GAP)
end

local function ToggleFoodMenu()
	if InCombatLockdown() then return end
	if menu:IsShown() then
		menu:Hide()
		return
	end
	ScanFood()
	FillMenu()
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", foodRow, "TOPRIGHT", 4, 0)
	menu:Show()
end
ns.ToggleFoodMenu = ToggleFoodMenu

-- The small list beside the chat, out of combat: the food reminder (a click lists your XP food) and
-- your reagents running low, from Reagents.lua, the family's file. Plain buttons: the food one only
-- opens its list, which is built out of combat, and the reagents' say what they're for
local reagentRows = {}

local function ItemName(item)
	return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item) or ("item " .. item)
end

local function Reagent_OnEnter(self)
	if not self.tip then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if self.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.item) end
	GameTooltip:AddLine(self.tip, 0.4, 0.8, 1)
	GameTooltip:Show()
end

local function ReagentRow(i)
	local b = reagentRows[i]
	if b then return b end
	b = CreateFrame("Button", "PaladinGodReagent" .. i, food)
	b:SetSize(150, ROW)
	DarkRow(b)
	b:SetScript("OnEnter", Reagent_OnEnter)
	b:SetScript("OnLeave", GameTooltip_Hide)
	reagentRows[i] = b
	return b
end

local function UpdateFood()
	local fed = (ns.unlocked and ns.db.food.enabled) or FoodMissing()
	-- Under the food: your reagents running low, then your gear and bags (Repair.lua, the family's)
	local reagents = {}
	if ns.unlocked then
		-- Samples to drag
		if ns.db.reagents.enabled then
			reagents[#reagents + 1] = { item = 21177, text = format(ns.REAGENT_TEXT.LOW, ItemName(21177), 3) }
		end
		if ns.db.repair.enabled then
			reagents[#reagents + 1] = { icon = "Interface\\Icons\\Trade_BlackSmithing", text = format(ns.REPAIR_TEXT.WORN, 18) }
		end
	elseif ns.IsPaladin() and not inCombat and not ns.Away() then
		for _, r in ipairs(ns.ReagentReminders and ns.ReagentReminders() or {}) do reagents[#reagents + 1] = r end
		for _, r in ipairs(ns.RepairReminders and ns.RepairReminders() or {}) do reagents[#reagents + 1] = r end
	end
	local width, y = 120, 0
	local function Place(b)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", food, "TOPLEFT", 0, -y)
		y = y + ROW + ROW_GAP
		width = max(width, b.text:GetStringWidth() + ROW + 24)
		b:Show()
	end
	if fed then
		foodRow.icon:SetTexture(ns.SpellIcon(WELL_FED))
		foodRow.icon:SetDesaturated(true)
		ns.ThinFont(foodRow.text, 13)
		foodRow.text:SetText(L.FOOD_MISSING)
		Place(foodRow)
	else
		foodRow:Hide()
		menu:Hide()
	end
	for i, r in ipairs(reagents) do
		local b = ReagentRow(i)
		b.icon:SetTexture(r.icon or ItemIcon(r.item))
		b.icon:SetDesaturated(r.count == 0)
		ns.ThinFont(b.text, 13)
		b.text:SetText(r.text)
		b.item, b.tip = r.item, r.uses
		Place(b)
	end
	for i = #reagents + 1, #reagentRows do reagentRows[i]:Hide() end
	-- All as long as the longest, so they stack as one block
	foodRow:SetWidth(width)
	for i = 1, #reagents do reagentRows[i]:SetWidth(width) end
	food:SetSize(width, max(y - ROW_GAP, ROW))
	food:SetShown(y > 0)
end

-- Everything that shows now
function ns.UpdateBuffs()
	Update()
	UpdateFood()
end
-- Reagents.lua and Repair.lua say when your reagents, gear or bags may have changed
ns.ReagentsChanged = function() ns.UpdateBuffs() end
ns.RepairChanged = function() ns.UpdateBuffs() end

-- /paladingod bufos: what the addon sees
local function Describe(slot)
	local e = ends[slot]
	if e == nil then return L.BUFF_UNKNOWN end
	if e == false then return L.BUFF_NONE end
	local key = wearing[slot]
	local name = key and ns.SpellName(SpellOf(slot, key)) or (slot == "food" and wellFedName) or "?"
	if e == math.huge then return format(L.BUFF_ON, name) end
	return format(L.BUFF_LEFT, name, ns.Clock(max(e - GetTime(), 0)))
end

local function BuffsReport()
	Learn()
	local seen = Scan()
	local fed = Describe("food")
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
	if ends.food == false and UnitLevel("player") >= maxLevel then fed = L.FOOD_MAX_LEVEL end
	ns.Print(format(L.BUFFS_REPORT, Describe("aura"), Describe("blessing"), Describe("fury"), ns.SealReport and ns.SealReport() or "?", fed))
	-- The food it took for not giving XP gets a fresh look
	for id, yes in pairs(xpFood) do
		if not yes then xpFood[id] = nil end
	end
	ScanFood()
	local stock = {}
	for _, f in ipairs(foodStock) do
		local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(f.id)
		stock[#stock + 1] = format("%s x%d", name or ("item " .. f.id), f.count)
	end
	ns.Print(format(L.FOOD_STOCK, #stock > 0 and table.concat(stock, ", ") or L.BUFF_NONE))
	if not seen then
		ns.Print(L.BUFFS_HIDDEN)
		return
	end
	local names = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		names[#names + 1] = aura.name
	end
	ns.Print(format(L.BUFFS_SEEN, #names > 0 and table.concat(names, ", ") or L.BUFF_NONE))
end
ns.commands.buffs = BuffsReport
ns.commands.bufos = BuffsReport

-- For the tests
function ns.BuffState(slot)
	return ends[slot], wearing[slot]
end

-- A spell you cast: an aura, a blessing or Righteous Fury
local function Cast(spellID)
	local name = ns.SpellName(spellID)
	local spell = name and byName[name]
	if not spell then return end
	-- Out of combat your buffs say whether it went on you (a blessing can go on anyone)
	if Scan() then return end
	-- In combat they're hidden: an aura or Righteous Fury is on you now. A blessing may have gone
	-- on someone else: only one that was missing on you is taken as yours
	if spell.slot == "blessing" and ends.blessing and ends.blessing > GetTime() then return end
	if spell.slot == "aura" then
		ends.aura, wearing.aura = math.huge, spell.key
		ns.db.lastAura = spell.key
	else
		ends[spell.slot] = GetTime() + (lasts[spell.slot] or DURATION[spell.slot])
		wearing[spell.slot] = spell.key
	end
end

local function Tooltip(slot)
	return function(tip)
		local f = frames[slot]
		tip:AddLine(f.spellName or "?", 1, 1, 1)
		if f.cancel then tip:AddLine(L.FURY_WARN_TIP, 1, 0.5, 0.4, true) end
	end
end

local function Reminder(slot)
	local f = CreateFrame("Frame", "PaladinGod" .. slot:gsub("^%l", string.upper), UIParent)
	f:Hide()
	ns.StyleReminder(f)
	frames[slot] = f
	ns.AddReminder(slot, f, function()
		if not f.spellName or inCombat then return end
		return f.spellName, f.cancel and "cancelaura" or "spell"
	end, Tooltip(slot))
	return f
end
Reminder("aura")
Reminder("blessing")
Reminder("fury")

-- Until you move it, beside the chat, out of the way
food = CreateFrame("Frame", "PaladinGodFood", UIParent)
food:SetSize(150, ROW)
food:Hide()
foodRow = CreateFrame("Button", "PaladinGodFoodRow", food)
foodRow:SetSize(150, ROW)
foodRow:Hide()
DarkRow(foodRow)
foodRow:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
foodRow:SetScript("OnClick", ToggleFoodMenu)
foodRow:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(L.CLICK_FOOD, 0.4, 0.8, 1)
	GameTooltip:Show()
end)
foodRow:SetScript("OnLeave", GameTooltip_Hide)
function food:placeDefault()
	if not ChatFrame1 then return false end
	self:ClearAllPoints()
	self:SetPoint("LEFT", ChatFrame1, "RIGHT", 25, 0)
	return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		db = ns.db.buffs
		Learn()
		Scan()
		ScanFood()
		ns.Movable(food, "food", { "CENTER", "CENTER", 0, 125 }, L.FOOD_NAME)
		ns.UseFont(frames.aura.text, ns.THIN_FONT, 15, "OUTLINE")
		ns.UseFont(frames.blessing.text, ns.THIN_FONT, 15, "OUTLINE")
		ns.UseFont(frames.fury.text, ns.THIN_FONT, 15, "OUTLINE")
		table.insert(ns.refreshers, ns.UpdateBuffs)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		-- Mounting, a flight, dying and coming back
		for _, name in ipairs({ "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
			pcall(self.RegisterEvent, self, name)
		end
		-- The time left ticks on its own
		local since = 0
		self:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < 0.5 then return end
			since = 0
			ns.UpdateBuffs()
		end)
	elseif event == "UNIT_AURA" then
		Scan()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or not spellID or ns.IsSecret(spellID) then return end
		Cast(spellID)
	elseif event == "BAG_UPDATE_DELAYED" then
		ScanFood()
		if menu:IsShown() and not InCombatLockdown() then FillMenu() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		-- Before the game locks its buttons for the fight
		menu:Hide()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		Scan()
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then
		Learn()
	elseif event == "PLAYER_DEAD" then
		-- Your aura and seal go when you die
		if not Scan() then ends.aura, wearing.aura = false, nil end
	else
		Scan()
	end
	ns.UpdateBuffs()
end)
