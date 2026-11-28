"""Loads the addon against a mocked WoW API (LuaJIT = Lua 5.1) and checks its behaviour.

Usage: python -I test_addon.py <PaladinGod folder> [enUS|esES]
Needs: pip install lupa
"""
import re
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ADDON = Path(sys.argv[1])
LOCALE = sys.argv[2] if len(sys.argv) > 2 else "enUS"
lua = LuaRuntime(unpack_returned_tuples=True)

printed = []
lua.globals().py_print = lambda *a: printed.append(" ".join(str(x) for x in a))
lua.globals().LOCALE = LOCALE

lua.execute(r'''
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end py_print(table.concat(t, " ")) end
format = string.format; strlower = string.lower; strupper = string.upper; max = math.max; min = math.min; abs = math.abs; floor = math.floor; ceil = math.ceil
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetLocale = function() return LOCALE end
-- A value the game hides from addons
SECRET = {}
-- A hidden value that still carries what it hides, for the game's own setters to use
function Hidden(v) return { hidden = v } end
local function Unwrap(v) if type(v) == "table" and v.hidden ~= nil then return v.hidden end return v end
issecretvalue = function(v) return v == SECRET or (type(v) == "table" and v.hidden ~= nil) end

SPELLS = {
  [465] = "Devotion Aura", [10290] = "Devotion Aura", [643] = "Devotion Aura", [10293] = "Devotion Aura",
  [7294] = "Retribution Aura", [10298] = "Retribution Aura", [19746] = "Concentration Aura",
  [19876] = "Shadow Resistance Aura", [19888] = "Frost Resistance Aura", [19891] = "Fire Resistance Aura",
  [19740] = "Blessing of Might", [19834] = "Blessing of Might", [19742] = "Blessing of Wisdom", [20217] = "Blessing of Kings",
  [25782] = "Greater Blessing of Might", [25894] = "Greater Blessing of Wisdom", [25898] = "Greater Blessing of Kings",
  [25780] = "Righteous Fury",
  [20154] = "Seal of Righteousness", [21084] = "Seal of Righteousness", [20287] = "Seal of Righteousness",
  [21082] = "Seal of the Crusader", [20162] = "Seal of the Crusader", [20375] = "Seal of Command",
  [20164] = "Seal of Justice", [20165] = "Seal of Light", [20166] = "Seal of Wisdom", [1311649] = "Seal of Fury",
  [19705] = "Well Fed",
  [679] = "Holy Strike", [20271] = "Judgement", [853] = "Hammer of Justice", [879] = "Exorcism",
  [24275] = "Hammer of Wrath", [635] = "Holy Light",
  [437063] = "Infusion of Light", [20050] = "Vengeance", [20178] = "Reckoning",
  [2383] = "Find Herbs", [2580] = "Find Minerals",
  [20216] = "Divine Favor", [20128] = "Redoubt", [1328551] = "Shieldsworn", [1311033] = "Iron Creed",
  [1311015] = "Templar's Bulwark", [10901] = "Power Word: Shield", [17] = "Power Word: Shield",
  [17543] = "Fire Protection", [17545] = "Holy Protection", [431624] = "Divine Aegis",
  [19752] = "Divine Intervention", [1225503] = "Reagent Economy",
  [642] = "Divine Shield", [498] = "Divine Protection", [633] = "Lay on Hands", [20066] = "Repentance",
}
-- How far each spell reaches
REACH = { ["Holy Strike"] = 5, Judgement = 10, ["Hammer of Justice"] = 10, Exorcism = 30, ["Hammer of Wrath"] = 30, ["Holy Light"] = 40 }

-- Game state the tests change
G = { class = "PALADIN", level = 20, known = {}, auras = {}, auraTimes = {}, secret = false, combat = false,
      now = 100, timers = {}, target = nil, dist = 27, secretRange = false, uncached = {}, items = {},
      group = false, raid = false, threat = nil, plate = nil, speed = {}, cursor = { 0, 100 }, dead = false, bags = {},
      epoch = 1000000, mounted = false, units = {}, unitAuras = {}, far = {}, health = 1, creature = nil,
      cvars = { showSwingTimer = "1" }, swingRange = nil, tipsLoading = false }
-- A screen pixel is half a UI unit here
PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }
C_CurveUtil = { CreateCurve = function()
  local c = { points = {} }
  function c:SetType() end
  function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
  return c
end }
local function EvalCurve(c, x)
  local p = c.points
  if x <= p[1][1] then return p[1][2] end
  for i = 2, #p do if x <= p[i][1] then local a, b = p[i - 1], p[i] return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1]) end end
  return p[#p][2]
end
-- The target's health: hidden in a fight
UnitHealth = function() if G.secret then return SECRET end return G.health * 1000 end
UnitHealthMax = function() if G.secret then return SECRET end return 1000 end
UnitHealthPercent = function(_, _, curve)
  local v = curve and EvalCurve(curve, G.health) or G.health
  if G.secret then return Hidden(v) end
  return v
end
UnitCreatureType = function() return G.creature end
time = function() return G.epoch end
NUM_BAG_SLOTS = 4
FOODS = { [700] = "Roast Raptor", [701] = "Freshly Baked Bread", [703] = "Roasted Boar Meat" }
ITEM_NAMES = { [17033] = "Symbol of Divinity", [21177] = "Symbol of Kings" }
-- A merchant's items, by slot
MERCHANT = {}
GetMerchantNumItems = function() return #MERCHANT end
GetMerchantItemID = function(i) return MERCHANT[i] end
ITEM_SPELL_TRIGGER_ONUSE = "Use:"
FOOD_TIPS = {
  [700] = "Use: Restores 1392 health over 27 sec. If you spend at least 10 seconds eating you will become well fed and gain 12 Stamina and Spirit for 15 min.",
  [701] = "Use: Restores 552 health over 24 sec. Must remain seated while eating.",
  [703] = "Use: Restores 58 health over 18 sec.  Must remain seated while eating.  If you spend at least 10 sec eating, you will become well fed and gain 1 Strength for 15 min.  Additionally, experience gained from kills is increased by 5%. (1 Sec Cooldown)",
}
C_Container = {
  GetContainerNumSlots = function(bag) return G.bags[bag] and #G.bags[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot) local it = G.bags[bag] and G.bags[bag][slot] if it then return { itemID = it[1], stackCount = it[2] } end end,
  GetContainerNumFreeSlots = function(bag) return G.free[bag] or (bag == 0 and 16 or 0), 0 end,
}
C_TooltipInfo = { GetBagItem = function(bag, slot)
  local it = G.bags[bag] and G.bags[bag][slot]
  if not it then return end
  if G.tipsLoading then return { lines = { { leftText = FOODS[it[1]] } } } end
  return { lines = { { leftText = FOODS[it[1]] }, { leftText = FOOD_TIPS[it[1]] } } }
end }

-- Units: you, your target, and your group's players in G.units[unit] = { name, class, dead, offline }
local function Member(u) return G.units[u] end
UnitClass = function(u) if u == "player" then return "Class", G.class end local m = Member(u) if m then return m.class, m.class end end
UnitName = function(u) if u == "player" then return "Me" end local m = Member(u) return m and m.name end
UnitLevel = function() return G.level end
GetMaxPlayerLevel = function() return 60 end
UnitRace = function() return "Human", "Human" end
GetTime = function() return G.now end
IsPlayerSpell = function(id) return G.known[id] or false end
local function KnownByName(name) for id in pairs(G.known) do if G.known[id] and SPELLS[id] == name then return true end end end
PASSIVE = {}
-- Spells the game says can't be cast now (no mana): by id, false or a hidden value
UNUSABLE = {}
C_Spell = {
  GetSpellName = function(id) return SPELLS[id] end,
  IsSpellPassive = function(id) return PASSIVE[id] or false end,
  IsSpellUsable = function(id) local u = UNUSABLE[id] if u == nil then return true, false end if u == SECRET then return SECRET end return false, true end,
  GetSpellTexture = function(id) return id end,
  GetSpellInfo = function(name) if KnownByName(name) then return { name = name, maxRange = REACH[name] } end end,
  IsSpellInRange = function(spell, unit)
    if unit ~= "target" then return not G.far[unit] end
    if G.secretRange then return SECRET end
    if REACH[spell] and KnownByName(spell) then return G.dist <= REACH[spell] end
  end,
}
-- Buffs: yours in G.auras (names in order) and G.auraTimes[name] = { ends, duration, spell id, source };
-- the group's in G.unitAuras[unit] = { { name, ends, mine } }. A "PLAYER" filter keeps your own
C_UnitAuras = { GetAuraDataByIndex = function(unit, i, filter)
  if G.secret then return SECRET end
  if unit == "player" then
    local name = G.auras[i] if not name then return end
    local t = G.auraTimes[name]
    return { name = name, expirationTime = t and t[1] or 0, duration = t and t[2] or 0, spellId = t and t[3], sourceUnit = t and t[4] }
  end
  local list = {}
  for _, a in ipairs(G.unitAuras[unit] or {}) do
    if not (filter and filter:find("PLAYER")) or a[3] then list[#list + 1] = a end
  end
  local a = list[i]
  if a then return { name = a[1], expirationTime = a[2] or 0, duration = a[2] and 3600 or 0 } end
end }
C_Secrets = { ShouldAurasBeSecret = function() return G.secret end }
-- The minimap's tracking list: { name, spellID, active, type }
G.tracking = {}
C_Minimap = {
  GetNumTrackingTypes = function() return #G.tracking end,
  GetTrackingInfo = function(i) return G.tracking[i] end,
}
IsInInstance = function() return G.instance, G.instance and "party" or "none" end
-- Spell cooldowns, by spell: what C_Spell.GetSpellCooldown hands over
COOLDOWNS = {}
C_Spell.GetSpellCooldown = function(id) return COOLDOWNS[id] end
-- Silenced, stunned or locked out: how many of those are on you
G.LOC = 0
C_LossOfControl = { GetActiveLossOfControlDataCount = function() return G.LOC end }
-- Its timer, as the game may give it in a fight: running while the spell shows cooling down, the
-- global cooldown too (it can't tell them apart)
C_Spell.GetSpellCooldownDuration = function(id)
  local cd = COOLDOWNS[id]
  return { IsZero = function() if cd and cd.secretZero then return SECRET end return not (cd and cd.isActive and not cd.gcd) end }
end
C_NamePlate = { GetNamePlateForUnit = function() return G.plate end }
UnitExists = function(u)
  if u == "target" then return G.target ~= nil end
  if u == "player" then return true end
  return Member(u) ~= nil
end
UnitCanAttack = function() return G.target and G.target.hostile end
UnitIsDead = function() return false end
UnitIsDeadOrGhost = function(u) if u == "player" then return G.dead end if u == "target" then return false end local m = Member(u) return m and m.dead or false end
UnitIsConnected = function(u) local m = Member(u) return not (m and m.offline) end
UnitIsUnit = function(a, b) return a == b or (G.me and a == G.me and b == "player") end
UnitOnTaxi = function() return G.taxi end
IsMounted = function() return G.mounted end
UnitAffectingCombat = function() return G.combat end
InCombatLockdown = function() return G.combat end
CheckInteractDistance = function(_, i) if G.secretRange then return SECRET end return G.dist <= (i == 3 and 8 or 28) end
GetUnitSpeed = function(u) return G.speed[u] or 0 end
IsInGroup = function() return G.group end
IsInRaid = function() return G.raid end
GetNumGroupMembers = function() local n = 0 for _ in pairs(G.units) do n = n + 1 end return n + 1 end
GetNumSubgroupMembers = function() local n = 0 for _ in pairs(G.units) do n = n + 1 end return n end
UnitDetailedThreatSituation = function() if G.threat then return G.threat[1], G.threat[2], G.threat[3], G.threat[4] end end
UnitAttackSpeed = function() return 3.6 end
UnitGetTotalAbsorbs = function() return G.absorb end
-- Your gear: by slot, { now, top }; free slots by bag (16 in the backpack unless said otherwise)
G.durability, G.free = {}, {}
GetInventoryItemDurability = function(slot) local d = G.durability[slot] if d then return d[1], d[2] end end
CanMerchantRepair = function() return G.canRepair end
-- What your target casts or channels: nil when nothing
UnitCastingInfo = function() if CASTING then return unpack(CASTING) end end
UnitChannelInfo = function() if CHANNELING then return unpack(CHANNELING) end end
GetInventoryItemID = function(_, slot) if slot == 16 then return 900 end end
GetInventoryItemTexture = function() return 1234 end
C_CVar = { GetCVar = function(k) return G.cvars[k] end, SetCVar = function(k, v) G.cvars[k] = v end }
C_SwingTimer = { IsTargetWithinSwingRange = function() return G.swingRange end, EnableRangeCheck = function() end }
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
  PRIEST = { r = 1, g = 1, b = 1 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
C_Item = {
  GetItemInfo = function(id) if ITEM_YARDS[id] then return "range item" end end,
  IsItemDataCachedByID = function(id) return not G.uncached[id] end,
  IsItemInRange = function(id)
    if G.secretRange then return SECRET end
    if G.uncached[id] or not ITEM_YARDS[id] then return nil end
    return G.dist <= ITEM_YARDS[id]
  end,
  RequestLoadItemDataByID = function() end,
  GetItemCount = function(id) return G.items[id] or 0 end,
  GetItemNameByID = function(id) return FOODS[id] or ITEM_NAMES[id] or "item " .. id end,
  GetItemIconByID = function(id) return id * 10 end,
  GetItemInfoInstant = function(id) if FOODS[id] then return id, "t", "s", "", 0, 0, 5 end return id, "t", "s", "", 0, 15, 0 end,
}
ITEM_YARDS = {}
function BuildItemYards(ns) for _, step in ipairs(ns.RANGE_ITEMS) do for _, id in ipairs(step[2]) do ITEM_YARDS[id] = step[1] end end end
C_Timer = { After = function(t, f) table.insert(G.timers, f) end, NewTicker = function() return { Cancel = function() end } end }
function RunTimers() local t = G.timers G.timers = {} for _, f in ipairs(t) do f() end end
GetCursorPosition = function() return G.cursor[1], G.cursor[2] end
C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }

-- Frames and textures: the methods the tests look at keep their state, the rest do nothing
local function Texture() local t = { shown = true } setmetatable(t, { __index = function(_, k) return function(self, ...)
  if k == "SetShown" then self.shown = (...) and true or false
  elseif k == "Hide" then self.shown = false elseif k == "Show" then self.shown = true
  elseif k == "IsShown" then return self.shown
  elseif k == "SetTexture" then self.tex = ... elseif k == "SetDesaturated" then self.desat = ...
  elseif k == "SetColorTexture" or k == "SetTextColor" or k == "SetVertexColor" then self.color = { ... }
  elseif k == "SetText" then
    -- As in the game: a text with no font can't be written
    if rawget(self, "isFont") and not rawget(self, "font") then error("FontString:SetText(): Font not set", 2) end
    self.text = ...
  elseif k == "GetStringWidth" then return #tostring(self.text or "") * 6
  elseif k == "SetWidth" then self.width = ... elseif k == "SetSize" then self.width, self.height = ...
  elseif k == "SetFormattedText" then
    if rawget(self, "isFont") and not rawget(self, "font") then error("FontString:SetFormattedText(): Font not set", 2) end
    local args = { ... }
    for i = 2, #args do if issecretvalue(args[i]) then self.hiddenText = true end args[i] = Unwrap(args[i]) end
    self.text = format(unpack(args))
  elseif k == "SetFont" then self.font = { ... }
  elseif k == "SetFontObject" then local o = ... self.fontObject = o self.font = o and o.font self.color = nil
  elseif k == "GetTextColor" then if rawget(self, "color") then return unpack(self.color) end
  elseif k == "SetPoint" then self.points = rawget(self, "points") or {} table.insert(self.points, { ... })
  elseif k == "ClearAllPoints" then self.points = {}
  elseif k == "GetText" then return self.text
  elseif k == "SetAlpha" then self.alpha = ...
  elseif k == "CreateAnimationGroup" then return CreateFrame("Frame") end
end end }) return t end
NAMED = {}
-- Secure frames, and what an addon tried to do to them in a fight
SECURE, BLOCKED = {}, {}
function Protected(frame)
  for _, s in ipairs(SECURE) do
    local p = s
    while p do
      if rawequal(p, frame) then return true end
      p = rawget(p, "parent")
    end
  end
  return false
end

function CreateFrame(kind, name, parent, template)
  local f = { scripts = {}, events = {}, kind = kind, parent = parent, template = template, shown = true, attrs = {}, width = 100, regions = 0, frameName = name }
  setmetatable(f, { __index = function(_, k)
    if k:match("^Create") then return function() return CreateFrame("Frame") end end
    if k:match("^%u") then return function() end end
  end })
  function f:SetScript(n, fn) self.scripts[n] = fn end
  function f:GetScript(n) return self.scripts[n] end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:RegisterUnitEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:CreateTexture() self.regions = self.regions + 1 return Texture() end
  -- A text made without a template has no font until it gets one; with one, it has the template's
  function f:CreateFontString(_, _, template) self.regions = self.regions + 1 local t = Texture() t.isFont = true if template then t.font = { template } end return t end
  function f:SetAlpha(a) self.alpha = Unwrap(a) self.hiddenAlpha = issecretvalue(a) end
  function f:SetShown(v) self.shown = v and true or false end
  function f:Hide() self.shown = false end function f:Show() self.shown = true end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown end
  function f:SetChecked(v) self.checked = v and true or false end
  function f:GetChecked() return self.checked end
  function f:GetFrameLevel() return 1 end
  function f:GetFrameStrata() return "MEDIUM" end
  function f:GetParent() return self.parent end
  function f:SetParent(p) self.parent = p end
  function f:SetPoint(...) self.point = { ... } end
  function f:GetPoint() local p = self.point return p[1], p[2], p[3], p[4], p[5] end
  function f:SetSize(w, h) self.width, self.height = w, h end
  function f:SetWidth(w) self.width = w end
  function f:SetHeight(h) self.height = h end
  function f:HookScript(n, fn) self.hooks = self.hooks or {} self.hooks[n] = fn end
  function f:GetWidth() return self.width end
  function f:GetHeight() return self.height end
  function f:GetCenter() return 0, 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetText(t) self.text = t end
  function f:GetText() return self.text end
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:SetScale(s) self.scale = s end
  function f:SetValue(v) self.value = Unwrap(v) self.hiddenValue = issecretvalue(v) end
  function f:SetMinMaxValues(a, b) self.minmax = { Unwrap(a), Unwrap(b) } end
  function f:SetStatusBarColor(...) self.barColor = { ... } end
  function f:Play() self.playing = true end
  function f:Stop() self.playing = false end
  function f:IsPlaying() return self.playing end
  -- Forever's aura container: one slot, whose button the addon dresses; the game plays what it's given
  if kind == "AuraContainer" then
    function f:SetEnabled(v) self.enabled = v end
    function f:SetUnit(u) self.unit = u end
    function f:SetAuraSlotCandidateFilters(key, filters) self.slots[key].options.candidateFilters = filters end
    function f:AddAuraSlot(key, filter, options)
      self.slot = { key = key, filter = filter, options = options }
      self.slots = self.slots or {}
      self.slots[key] = self.slot
      local button = CreateFrame("Button", nil, self)
      self.slot.button = button
      button.shownAnims, button.assignedAnims = {}, {}
      function button:AddAuraShownAnimation(g) table.insert(self.shownAnims, g) end
      function button:AddAuraAssignedAnimation(g) table.insert(self.assignedAnims, g) end
      function button:SetDurationText(text, opts) self.durationText = { text = text, options = opts } end
      function button:SetIcon(icon) self.iconTexture = icon end
      self.button = button
      options.initializeFrame(button)
    end
  end
  FRAMES = FRAMES or {} table.insert(FRAMES, f)
  if name then NAMED[name] = f end
  -- As in the game: in a fight a secure button, and any frame holding one, can't be shown, hidden,
  -- moved or changed by an addon (the game blocks it). Recorded in BLOCKED, the tests fail on it
  if type(template) == "string" and template:find("Secure") then SECURE[#SECURE + 1] = f end
  for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAttribute", "SetPoint", "ClearAllPoints", "SetParent", "SetSize" }) do
    local orig = rawget(f, method)
    if orig then
      f[method] = function(self, ...)
        if InCombatLockdown() and not ENTERING_COMBAT and Protected(self) then
          local info = debug.getinfo(2, "Sl")
          if info and info.source:sub(1, 1) == "@" then
            BLOCKED[#BLOCKED + 1] = info.source:sub(2) .. ":" .. tostring(info.currentline) .. " " .. method .. " on " .. tostring(name or "a secure frame")
          end
        end
        return orig(self, ...)
      end
    end
  end
  return f
end
-- Font objects: one per name, the last font set on it counts
FONT_OBJECTS = {}
function CreateFont(name)
  local f = { name = name }
  function f:SetFont(...) self.font = { ... } end
  function f:GetFont() return unpack(self.font) end
  FONT_OBJECTS[name] = f
  return f
end
UIParent = CreateFrame("Frame")
Minimap = CreateFrame("Frame")
ChatFrame1 = CreateFrame("Frame")
Minimap.width = 140
GameFontNormal = { GetFont = function() return "font" end }
UISpecialFrames = {}
CustomAuraContainerAuraProcessingPolicy = { None = 0 }
Enum = { NumericRuleFormatRounding = { Up = 2 } }
C_StringUtil = { CreateNumericRuleFormatter = function()
  return { SetBreakpoints = function(self, rules) self.rules = rules end }
end }
ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) COLOR_INFO = info end, GetColorRGB = function() return 0, 0, 1 end }
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
PlaySound = function() end
TOOLTIP = {}
GameTooltip = { SetOwner = function() TOOLTIP = {} end, AddLine = function(_, s) table.insert(TOOLTIP, s) end, Show = function() end }
GameTooltip_Hide = function() end
SlashCmdList = {}
-- Talent reset: the trainer's options, the game's price dialog, the gold and the server's clock
GOSSIP_OPTIONS = {}
C_GossipInfo = { GetOptions = function() return GOSSIP_OPTIONS end, SelectOption = function() end }
GossipFrame = CreateFrame("Frame")
POPUPS = {}
StaticPopup_FindVisible = function(which) return POPUPS[which] end
GetMoney = function() return G.money or 0 end
GetServerTime = function() return G.server or 0 end
date = os.date
ConfirmTalentWipe = function() end
hooksecurefunc = function(a, b, c)
  local t, key, fn = _G, a, b
  if type(a) == "table" then t, key, fn = a, b, c end
  local orig = t[key]
  t[key] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

-- The frames showing under a parent, in the order they were made
function ShownIcons(parent)
  local t = {}
  for _, f in ipairs(FRAMES) do if f.parent == parent and f.shown and (f.icon or f.template) then t[#t + 1] = f end end
  return t
end
function Same(a, b) return rawequal(a, b) end
-- The addon's frames that draw something and are on screen (shown, and every parent too), but the
-- minimap button's: what a player would see
function ShownOnScreen()
  local list, minimap = {}, NAMED.PaladinGodMinimapButton
  for i, f in ipairs(FRAMES) do
    if (rawget(f, "regions") or 0) > 0 then
      local p, visible, mine = f, true, false
      while p do
        if not p.shown then visible = false break end
        if rawequal(p, minimap) then mine = true end
        if rawequal(p, UIParent) then break end
        p = rawget(p, "parent")
      end
      if visible and not mine then list[#list + 1] = (rawget(f, "frameName") or f.kind .. " #" .. i) end
    end
  end
  return list
end
function Fire(event, ...) for _, f in ipairs(FRAMES) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
''')

lua.execute('''
-- PLAYER_REGEN_DISABLED is the last moment the game lets an addon change its secure buttons
ENTERING_COMBAT = false
local fire = Fire
Fire = function(event, ...)
  ENTERING_COMBAT = event == "PLAYER_REGEN_DISABLED"
  fire(event, ...)
  ENTERING_COMBAT = false
end
-- Globals an addon file leaves behind: only its own name's, SLASH_ and BINDING_ are fine
LEAKS = {}
setmetatable(_G, { __newindex = function(t, k, v)
  local info = debug.getinfo(2, "Sl")
  if info and info.source:sub(1, 1) == "@" and type(k) == "string" and not k:find("^PaladinGod")
    and not k:find("^SLASH_") and not k:find("^BINDING_") then
    LEAKS[#LEAKS + 1] = info.source:sub(2) .. ":" .. tostring(info.currentline) .. " " .. k
  end
  rawset(t, k, v)
end })
''')

load = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
ns = lua.table()
toc = Path(ADDON, "PaladinGod.toc").read_text(encoding="utf-8")
for fname in re.findall(r"^(\w+\.lua)$", toc, re.M):
    load(Path(ADDON, fname).read_text(encoding="utf-8"), fname)("PaladinGod", ns)

G = lua.globals()
S = G.G  # the game state
L = ns.L
es = LOCALE in ("esES", "esMX")
fails = []


def check(cond, msg):
    print(("OK   " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


def slash(arg):
    printed.clear()
    G.SlashCmdList.PALADINGOD(arg)
    return list(printed)


def know(*ids, on=True):
    for i in ids:
        S.known[i] = on
    G.Fire("SPELLS_CHANGED")


def auras(**times):
    """auras(name=(seconds left, duration[, spell id[, who cast it]])) puts those buffs on you"""
    S.auras = lua.table(*[n.replace("_", " ") for n in times])
    S.auraTimes = lua.table()
    for n, (left, *rest) in times.items():
        S.auraTimes[n.replace("_", " ")] = lua.table(S.now + left if left else 0, *rest)
    G.Fire("UNIT_AURA", "player")


def tick(seconds=0):
    S.now = S.now + seconds
    ns.UpdateBuffs()
    ns.UpdateSeal()


group, members = ns.RemindersState()


def icons():
    """The reminders above you: (icon, grey, text)"""
    return [(f.icon.tex, bool(f.icon.desat), f.text.text or "") for f in G.ShownIcons(group).values()]


def click_of(key):
    b = G.NAMED["PaladinGodReminderClick" + key]
    return (b.attrs["type1"], b.attrs["spell1"], b.attrs["unit1"]) if b.shown else None


# ---------------------------------------------------------------- Login: a level 20 paladin
S.known = lua.table()
for i in (465, 19740, 25780, 20154, 21082, 679, 20271, 879, 635):
    S.known[i] = True
G.BuildItemYards(ns)
G.Fire("ADDON_LOADED", "PaladinGod")
G.Fire("PLAYER_LOGIN")
db = G.PaladinGodDB
check(db.buffs.enabled and db.seal.enabled and db.group.enabled and db.range.enabled and db.swing.enabled,
      "settings filled in from the defaults")
check(db.group.classes.WARRIOR == "might" and db.group.classes.MAGE == "wisdom", "each class has its blessing")
check(icons() == [(465, True, ""), (19740, True, "")], f"no buffs on: Devotion Aura and Blessing of Might, grey: {icons()}")
check(click_of("aura") == ("spell", "Devotion Aura", "player") and click_of("blessing") == ("spell", "Blessing of Might", "player"),
      f"a click casts each on you: {click_of('aura')}, {click_of('blessing')}")
food = G.NAMED["PaladinGodFood"]
check(food.shown and G.NAMED["PaladinGodFoodRow"].shown and G.NAMED["PaladinGodFoodRow"].text.text == L.FOOD_MISSING,
      "and the small food reminder")
check(food.point[1] == "LEFT" and G.Same(food.point[2], G.ChatFrame1), "beside the chat until you move it")
slash("")
check(G.NAMED["PaladinGodOptions"] is not None and G.NAMED["PaladinGodOptions"].shown, "/paladingod opens the options")
slash("")
check(G.SlashCmdList.PALADINGOD is not None and G.SLASH_PALADINGOD2 == "/paladin", "/paladin works too")

# ---------------------------------------------------------------- Buffs on, and running out
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3500, 3600), Well_Fed=(800, 900))
check(icons() == [] and not food.shown, "aura, blessing and Well Fed on: nothing")
check(db.lastAura == "devotion" and db.lastBlessing == "might", "it remembers which ones")
S.now = S.now + 3420
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(80, 3600), Well_Fed=(800, 900))
check(icons() == [(19740, False, "1:20")], f"the blessing in its last 2 minutes: in colour with its time: {icons()}")
db.buffs.warnMinutes = 1
ns.UpdateBuffs()
check(icons() == [], "warning only in the last minute: not yet")
db.buffs.warnMinutes = 2
# Another paladin's aura and blessing on you aren't yours
auras(Devotion_Aura=(0, 0, 465, "party1"), Blessing_of_Might=(3600, 3600, 19740, "party1"), Well_Fed=(800, 900))
check(icons() == [(465, True, ""), (19740, True, "")], f"another paladin's aura and blessing don't count: {icons()}")
auras(Retribution_Aura=(0, 0), Blessing_of_Kings=(3600, 3600), Well_Fed=(800, 900))
check(icons() == [] and db.lastAura == "retribution", "any aura of yours will do, and it's remembered")
db.buffs.auraChoice = "devotion"
ns.UpdateBuffs()
check(icons() == [(465, True, "")], "Devotion Aura chosen, Retribution on: Devotion Aura")
db.buffs.auraChoice = "auto"
auras(Devotion_Aura=(0, 0), Greater_Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
check(icons() == [], "a Greater Blessing counts")
S.mounted = True
auras(Well_Fed=(800, 900))
check(icons() == [], "mounted: casting would get you off, nothing")
S.mounted = False
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))

# ---------------------------------------------------------------- In combat Forever hides your buffs
db.seal.enabled = False  # the seal's own reminder in a fight is checked further on
S.combat, S.secret = True, True
G.Fire("PLAYER_REGEN_DISABLED")
G.Fire("UNIT_AURA", "player")
check(icons() == [], "in combat, buffs hidden: still known to be on")
check(click_of("aura") is None, "no click in a fight")
S.combat, S.secret = False, False
auras(Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
G.Fire("PLAYER_REGEN_ENABLED")
check(icons() == [(465, True, "")], "the aura gone before the fight")
S.combat, S.secret = True, True
G.Fire("PLAYER_REGEN_DISABLED")
check(icons() == [(465, True, "")], "in the fight it still shows: an aura matters in combat")
auras(Well_Fed=(800, 900))
S.auras = lua.table()
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 465)
check(icons() == [], "Devotion Aura cast in combat: taken as on")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", G.SECRET)
check(icons() == [], "a hidden spell id is left alone")
S.now = S.now + 3700
ns.UpdateBuffs()
check(icons() == [], "the blessing runs out in the fight: it waits for the end of it")
S.combat, S.secret = False, False
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
G.Fire("PLAYER_REGEN_ENABLED")
check(icons() == [], "out of combat the buffs are read again")

db.seal.enabled = True
# ---------------------------------------------------------------- Righteous Fury
S.group = True
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Righteous_Fury=(1800, 1800), Well_Fed=(800, 900))
check(icons() == [(25780, False, L.FURY_WARN)], f"Righteous Fury on in a group, not tanking: a warning: {icons()}")
check(click_of("fury") == ("cancelaura", "Righteous Fury", "player"), f"a click takes it off: {click_of('fury')}")
check(ns.IsTank(), "with it on you count as the tank")
S.group = False
ns.UpdateBuffs()
check(icons() == [], "solo it does no harm: nothing")
db.buffs.fury = "tank"
ns.UpdateBuffs()
check(icons() == [], "tanking, with 30 minutes left: nothing")
S.now = S.now + 1700
ns.UpdateBuffs()
check(icons() == [(25780, False, "1:40")], f"tanking, in its last minutes: its time: {icons()}")
check(click_of("fury") == ("spell", "Righteous Fury", "player"), "a click casts it again")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
check(icons() == [(25780, True, "")], "tanking without it: grey")
db.buffs.fury = "off"
ns.UpdateBuffs()
check(icons() == [], "it can be left alone")
db.buffs.fury = "warn"
S.group = False

# ---------------------------------------------------------------- Clicks and the options for them
auras(Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
check(click_of("aura") is not None, "the aura's click is there")
db.buffs.click = False
ns.UpdateBuffs()
ns.SyncReminders()
check(click_of("aura") is None, "clicking can be turned off")
db.buffs.click = True
ns.UpdateBuffs()
ns.SyncReminders()
db.buffs.text = False
S.now = S.now + 3500
auras(Blessing_of_Might=(100, 3600), Well_Fed=(800, 900))
blessing = G.NAMED["PaladinGodBlessing"]
check(blessing.text.shown and blessing.text.text == "1:40", "the time left shows whatever the words option says")
db.buffs.text = True
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))

# ---------------------------------------------------------------- Food
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600))
check(food.shown and icons() == [], "no Well Fed: the small food reminder")
menu = G.NAMED["PaladinGodFoodMenu"]


def menu_rows():
    return [(r.text.text, r.attrs["type"], r.attrs["item"]) for r in G.ShownIcons(menu).values()] if menu.shown else []


S.bags = lua.table_from({0: lua.table_from([lua.table(700, 5), lua.table(701, 10), lua.table(703, 2)])})
G.Fire("BAG_UPDATE_DELAYED")
G.NAMED["PaladinGodFoodRow"].scripts.OnClick(G.NAMED["PaladinGodFoodRow"])
check(menu_rows() == [("Roast Raptor  x5", "item", "item:700"), ("Roasted Boar Meat  x2", "item", "item:703")],
      f"a click: your food that makes you Well Fed, not the bread: {menu_rows()}")
G.Fire("PLAYER_REGEN_DISABLED")
check(not menu.shown, "a fight starts: the list goes")
G.Fire("PLAYER_REGEN_ENABLED")
S.level = 60
ns.UpdateBuffs()
check(not food.shown, "at level 60 there's no XP to gain: no food reminder")
S.level = 20
S.dead = True
ns.UpdateBuffs()
check(not food.shown and icons() == [], "dead: no reminders")
S.dead = False
out = slash("bufos" if es else "buffs")
print("     /paladingod buffs:", out)
check(len(out) == 3 and "Devotion Aura" in out[0] and "Blessing of Might" in out[0]
      and out[1] == L.PREFIX + L.FOOD_STOCK % "Roast Raptor x5, Roasted Boar Meat x2", "/paladingod buffs says what it sees")
S.bags = lua.table()
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))

# ---------------------------------------------------------------- Reagents running low (Reagents.lua, the family's)
foodrow = G.NAMED["PaladinGodFoodRow"]


def extras():
    """The small list beside the chat: (text, icon, greyed)"""
    if not food.shown:
        return []
    rows = [fr for fr in G.FRAMES.values() if G.Same(fr.parent, food) and fr.shown and fr.text]
    rows.sort(key=lambda fr: -fr.point[5])
    return [(fr.text.text, fr.icon.tex, bool(fr.icon.desat)) for fr in rows]


check(db.reagents.enabled and extras() == [], "reagents on by default; no Divine Intervention known: nothing")
S["items"][17033] = 0
know(19752)  # Divine Intervention, from level 30
symbol = (ns.REAGENT_TEXT.NONE % "Symbol of Divinity", 170330, True)
check(extras() == [symbol], f"Divine Intervention learned, no Symbol of Divinity: it says so, beside the chat: {extras()}")
row = G.NAMED["PaladinGodReagent1"]
row.scripts.OnEnter(row)
check(G.TOOLTIP[1] == ns.REAGENT_TEXT.FOR % "Divine Intervention", f"its tooltip says what it's for: {list(G.TOOLTIP.values())}")
S["items"][17033] = 1
G.Fire("BAG_UPDATE_DELAYED")
check(extras() == [], "one in the bags: enough")
S["items"][17033] = 0
G.Fire("BAG_UPDATE_DELAYED")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600))
check(extras() == [(L.FOOD_MISSING, 19705, True), symbol], f"with the food reminder, under it: {extras()}")
foodrow.scripts.OnClick(foodrow)
check(G.NAMED["PaladinGodFoodMenu"].shown and G.Same(G.NAMED["PaladinGodFoodMenu"].point[2], foodrow), "the food row still opens its list")
foodrow.scripts.OnClick(foodrow)
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
G.MERCHANT = lua.table(4470, 17033)
printed.clear()
G.Fire("MERCHANT_SHOW")
check(printed == [L.PREFIX + ns.REAGENT_TEXT.VENDOR % ("Symbol of Divinity", 0)], f"a vendor that sells it says so: {printed}")
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(extras() == [], "not in a fight")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
know(1225503)  # Reagent Economy, the legacy talent
check(extras() == [], "with Reagent Economy vendors' reagents don't count")
know(1225503, on=False)
db.reagents.enabled = False
ns.RefreshReagents()
check(extras() == [], "it can be turned off")
db.reagents.enabled = True
know(19752, on=False)

# ---------------------------------------------------------------- Gear and bags (Repair.lua, the family's)
check(db.repair.enabled and db.repair.low == 25 and db.repair.bags == 2, "gear and bags reminder on by default, at 25% and 2 slots")
S.durability = lua.table_from({1: lua.table(10, 100), 5: lua.table(90, 100)})
G.Fire("UPDATE_INVENTORY_DURABILITY")
worn = (ns.REPAIR_TEXT.WORN % 10, "Interface\\Icons\\Trade_BlackSmithing", False)
check(extras() == [worn], f"your helm at 10%: it says so beside the chat: {extras()}")
S.free = lua.table_from({0: 1})
G.Fire("BAG_UPDATE_DELAYED")
check(extras() == [worn, (ns.REPAIR_TEXT.BAGS % 1, "Interface\\Icons\\INV_Misc_Bag_08", False)], f"and one free bag slot: {extras()}")
S.canRepair = True
printed.clear()
G.Fire("MERCHANT_SHOW")
check(L.PREFIX + ns.REPAIR_TEXT.VENDOR % 10 in printed, f"a vendor who repairs says how worn your gear is: {printed}")
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(extras() == [], "not in a fight")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
db.repair.low, db.repair.bags = 5, 0
ns.RefreshRepair()
check(extras() == [], "your lines: under 5%, no free slot")
db.repair.low, db.repair.bags = 25, 2
db.repair.enabled = False
ns.RefreshRepair()
check(extras() == [], "it can be turned off")
db.repair.enabled = True
S.durability = lua.table()
S.free = lua.table()
S.canRepair = False
ns.RefreshRepair()

# ---------------------------------------------------------------- Herbalism or Mining: their tracking
check(db.gather.enabled, "the gathering tracking reminder is on by default")
G.Fire("MINIMAP_UPDATE_TRACKING")
check(icons() == [] and ns.GatherReminder() is None, "no gathering profession: no tracking reminder")


def tracking(*rows):
    S.tracking = lua.table(*[lua.table(name=n, spellID=i, active=a, type="spell") for n, i, a in rows])
    G.Fire("MINIMAP_UPDATE_TRACKING")


tracking(("Find Herbs", 2383, False))
check(icons() == [(2383, True, "")], f"a herbalist without Find Herbs on: its icon in the row, grey: {icons()}")
check(click_of("gather") == ("spell", "Find Herbs", "player"), f"a click turns it on: {click_of('gather')}")
grow = G.NAMED["PaladinGodGather"]
check(G.Same(grow.parent, group) and all(list(l.color.values()) == [0, 0, 0, 1] for l in grow.lines.values()),
      "in the row, with the same thin black edge")
tracking(("Find Herbs", 2383, True))
check(icons() == [] and db.gather.last == "herbs", "Find Herbs on: gone, and it remembers it was herbs")
tracking(("Find Herbs", 2383, False), ("Find Minerals", 2580, True))
check(icons() == [] and db.gather.last == "minerals", "herbalist and miner: Find Minerals on counts too")
tracking(("Find Herbs", 2383, False), ("Find Minerals", 2580, False))
check(icons() == [(2580, True, "")], f"both off: the one you had on last, Find Minerals: {icons()}")
db.gather.last = None
ns.UpdateGather()
check(icons() == [(2383, True, "")], "nothing remembered: the first you have, Find Herbs")
S.instance = True
G.Fire("PLAYER_ENTERING_WORLD")
check(icons() == [], "in a dungeon, raid or battleground: no reminder")
S.instance = False
S.taxi = True
ns.UpdateGather()
check(icons() == [], "nor on a flight")
S.taxi = False
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check((2383, True, "") not in icons(), "nor in a fight")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(icons() == [(2383, True, "")], "back after it")
S.tracking[1].active = G.SECRET
G.Fire("MINIMAP_UPDATE_TRACKING")
check(icons() == [], "the game hides the tracking list: no guessing")
tracking(("Find Herbs", 2383, False))
db.gather.enabled = False
ns.UpdateGather()
check(icons() == [], "it can be turned off")
db.gather.enabled = True
tracking()
check(icons() == [], "no gathering profession left: gone")

# ---------------------------------------------------------------- The seal
seal = ns.SealState()
base = seal.base
SEAL_ROW = (20154, True, "")
check(SEAL_ROW not in icons() and not base.shown, "out of combat, no enemy targeted: no seal reminder")
S.target = lua.table(hostile=True)
G.Fire("PLAYER_TARGET_CHANGED")
check(icons() == [SEAL_ROW], f"an enemy targeted, no seal: your seal, grey, with the other reminders: {icons()}")
srow = ns.SealState().reminder
check(G.Same(srow.parent, group) and all(list(l.color.values()) == [0, 0, 0, 1] for l in srow.lines.values()),
      "in the row, with the same thin black edge")
check(click_of("seal") == ("spell", "Seal of Righteousness", "player"), f"a click casts it: {click_of('seal')}")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Seal_of_Righteousness=(30, 30, 20154))
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 20154)
check(icons() == [] and not base.shown, "cast: the reminder goes, and the game draws the seal and its seconds")
check(ns.SealState().ends == S.now + 30, "on for 30 seconds")
S.combat, S.secret = True, True
G.Fire("PLAYER_REGEN_DISABLED")
check(click_of("seal") is None, "a fight starts: no click")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 21082)
check(icons() == [] and db.lastSeal == "crusader" and ns.SealState().key == "crusader",
      "Seal of the Crusader cast in the fight: on, and remembered")
S.target = None
G.Fire("PLAYER_TARGET_CHANGED")
tick(31)
check(icons() == [(21082, True, "")], f"it runs out in the fight, no target needed: grey, the one you cast last: {icons()}")
S.combat, S.secret = False, False
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
G.Fire("PLAYER_REGEN_ENABLED")
check(icons() == [], "the fight over, no enemy: gone")
db.seal.choice = "righteousness"
S.target = lua.table(hostile=True)
G.Fire("PLAYER_TARGET_CHANGED")
check(icons() == [SEAL_ROW] and click_of("seal")[1] == "Seal of Righteousness", "the seal you choose")
db.seal.choice = "auto"
db.seal.target = False
ns.UpdateSeal()
check(icons() == [], "out of combat it can wait for the fight")
db.seal.target = True
db.seal.enabled = False
ns.UpdateSeal()
check(icons() == [], "and it can be turned off")
db.seal.enabled = True
# The game's own drawing, on top
box = seal.container
check(box is not None and box.slot.filter == "HELPFUL" and box.unit == "player" and box.enabled,
      "an aura container watches your seals")
watched = sorted(box.slot.options.candidateFilters.includeSpellIDs.keys())
check(20154 in watched and 21082 in watched and 1311649 in watched and 20375 in watched,
      f"every rank of every seal, Forever's Seal of Fury too: {len(watched)}")
dressed = ns.SealState().dressed
rules = box.button.durationText.options.textFormatter.rules
check(dressed.timed and G.Same(box.button.durationText.text, dressed.text) and rules[2].format == "%d",
      "the game writes its seconds, whole")
check(box.button.iconTexture is not None, "and puts its icon in")
holder = ns.SealState().holder
check(G.Same(holder.point[2], seal.place), "over the addon's icon")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Seal_of_Righteousness=(30, 30, 999100))
newbox = ns.SealState().container
check(not G.Same(newbox, box) and 999100 in newbox.slot.options.candidateFilters.includeSpellIDs.keys() and not box.enabled,
      "a seal with another number: a new container watches it too")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
G.Fire("PLAYER_TARGET_CHANGED")
check(all(list(l.color.values()) == [0, 0, 0, 1] for l in dressed.lines.values()), "with the reminders' black edge")
db.seal.size = 56
ns.RefreshAll()
check(base.width == 56 and ns.SealState().holder.width == 56, "its size is yours to set")
db.seal.size = 40
ns.RefreshAll()
S.target = None
G.Fire("PLAYER_TARGET_CHANGED")

# ---------------------------------------------------------------- Your group's blessings
know(19742)  # Blessing of Wisdom
gs = ns.GroupState()
gholder = gs.holder


def rows():
    if not gholder.shown:
        return []
    return [(r.text.text, r.icon.tex, r.time.text, r.attrs["type"], r.attrs["spell"], r.attrs["unit"])
            for r in G.ShownIcons(gholder).values()]


S.group = True
S.units = lua.table_from({
    "party1": lua.table(name="Garrosh", **{"class": "WARRIOR"}),
    "party2": lua.table(name="Jaina", **{"class": "MAGE"}),
    "party3": lua.table(name="Anduin", **{"class": "PRIEST"}),
})
S.unitAuras = lua.table_from({"party3": lua.table_from([lua.table("Blessing of Wisdom", S.now + 3000, False)])})
G.Fire("GROUP_ROSTER_UPDATE")
check(rows() == [("Garrosh", 19740, "", "spell", "Blessing of Might", "party1"),
                 ("Jaina", 19742, "", "spell", "Blessing of Wisdom", "party2")],
      f"who lacks your blessing, each with theirs; another paladin's Wisdom covers the priest: {rows()}")
first = list(G.ShownIcons(gholder).values())[0]
check(tuple(round(c, 2) for c in first.text.color.values())[:3] == (0.78, 0.61, 0.43), "names in their class colour")
S.unitAuras.party1 = lua.table_from([lua.table("Blessing of Might", S.now + 3600, True)])
G.Fire("UNIT_AURA", "party1")
check([r[0] for r in rows()] == ["Jaina"], f"Garrosh blessed: gone ({rows()})")
S.unitAuras.party1 = lua.table_from([lua.table("Blessing of Might", S.now + 80, True)])
G.Fire("UNIT_AURA", "party1")
check(rows() == [("Jaina", 19742, "", "spell", "Blessing of Wisdom", "party2"),
                 ("Garrosh", 19740, "1:20", "spell", "Blessing of Might", "party1")],
      f"his running out: after the missing ones, with its time: {rows()}")
S.far.party2 = True
ns.UpdateGroup()
check(list(G.ShownIcons(gholder).values())[0].alpha == 0.5, "too far away: greyed out")
S.far = lua.table()
db.group.maxRows = 1
ns.UpdateGroup()
check([r[0] for r in rows()] == ["Jaina", L.GROUP_MORE % 1] and rows()[1][3] is None, f"too many for the list: {rows()}")
db.group.maxRows = 10
db.group.classes.MAGE = "none"
ns.UpdateGroup()
check([r[0] for r in rows()] == ["Garrosh"], "a class set to none is left out")
db.group.classes.MAGE = "kings"
ns.UpdateGroup()
check(rows()[0][4] == "Blessing of Wisdom", "Kings not learned yet: the first you know instead")
db.group.classes.MAGE = "wisdom"
S.units.party2.dead = True
ns.UpdateGroup()
check([r[0] for r in rows()] == ["Garrosh"], "the dead are left out")
S.units.party2.dead = False
S.combat, S.secret = True, True
G.Fire("PLAYER_REGEN_DISABLED")
check(not gholder.shown, "a fight starts: the list goes")
ns.UpdateGroup()
check(not gholder.shown, "and can't come back in it")
S.combat, S.secret = False, False
G.Fire("PLAYER_REGEN_ENABLED")
check(len(rows()) == 2, "back after it")
db.group.enabled = False
ns.UpdateGroup()
check(not gholder.shown, "it can be turned off")
db.group.enabled = True
# A raid: you are one of the raid's numbers
S.raid = True
S.me = "raid1"
S.units = lua.table_from({"raid1": lua.table(name="Me", **{"class": "PALADIN"}),
                          "raid2": lua.table(name="Thrall", **{"class": "SHAMAN"})})
S.unitAuras = lua.table()
G.Fire("GROUP_ROSTER_UPDATE")
check([r[0] for r in rows()] == ["Thrall"], f"in a raid, everyone but you: {rows()}")
S.raid, S.me, S.group = False, None, False
S.units = lua.table()
G.Fire("GROUP_ROSTER_UPDATE")
check(not gholder.shown, "no group: no list")


# ---------------------------------------------------------------- Your class's group buffs (GroupBuffs.lua, the family's)
check(ns.GROUP_BUFFS.PALADIN is None, "the shared file brings no group buffs for a paladin: the blessings go by player")
gb = G.NAMED["PaladinGodGroupBuff1"]
S.group = True
S.units = lua.table_from({"party1": lua.table(name="Garrosh", **{"class": "WARRIOR"}),
                          "party2": lua.table(name="Jaina", **{"class": "MAGE"})})
S.unitAuras = lua.table()
G.Fire("GROUP_ROSTER_UPDATE")
check(not gb.shown, "so nothing shows in the row")
# Should it get some one day, the row shows them: tried with a made-up one
ns.GROUP_BUFFS.PALADIN = lua.eval('{ { key = "test", cast = { 19740 }, also = {} } }')
G.Fire("GROUP_ROSTER_UPDATE")
check(gb.shown and gb.text.text == 2 and gb.icon.tex == 19740 and click_of("groupbuff1") == ("spell", "Blessing of Might", "party1"),
      f"two lack it: its icon with 2, a click casts it on the first in range: {click_of('groupbuff1')}")
S.far.party1 = True
G.Fire("GROUP_ROSTER_UPDATE")
check(click_of("groupbuff1") == ("spell", "Blessing of Might", "party2"), "the first one out of range: the next")
S.far = lua.table()
S.combat = True
G.Fire("PLAYER_REGEN_DISABLED")
check(not gb.shown, "not in a fight")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
db.groupBuffs.enabled = False
ns.RefreshGroupBuffs()
check(not gb.shown, "it can be turned off")
db.groupBuffs.enabled = True
ns.GROUP_BUFFS.PALADIN = None
S.group = False
S.units = lua.table()
G.Fire("GROUP_ROSTER_UPDATE")
check(not gb.shown and click_of("groupbuff1") is None, "back to none")

# ---------------------------------------------------------------- Procs: each with its own look and place
S.secret = False
MEDIA = "Interface\\AddOns\\PaladinGod\\media\\"
PROCS = (("infusion", 437063), ("divinefavor", 20216), ("vengeance", 20050), ("redoubt", 20128),
         ("shieldsworn", 1328551), ("reckoning", 20178), ("ironcreed", 1311033))
for key, spell in PROCS:
    st = ns.ProcsState(key)
    c = st.container
    w = sorted(c.slot.options.candidateFilters.includeSpellIDs.keys()) if c else []
    check(c is not None and c.slot.filter == "HELPFUL" and c.unit == "player" and w == [spell],
          f"{key}: an aura container watching its buff {w}")
    d = st.dressed
    check(d is not None and d.ready and len(c.button.shownAnims) > 0 and len(c.button.assignedAnims) > 0,
          f"{key}: the game takes its animations")
    check(G.Same(c.button.durationText.text, d.timer), f"{key}: and writes its seconds")


def look(key):
    """Which textures a proc draws, and where (the heights and sides its pieces sit at)"""
    d = ns.ProcsState(key).dressed
    files = sorted({e[1].tex.replace(MEDIA, "") for e in d.tinted.values()})
    heights = sorted({e[3] for e in d.placed.values()})
    sides = sorted({e[2] for e in d.placed.values()})
    return files, heights, sides


check(look("infusion") == (["light_core", "light_glow", "proc_aura"], [0], [-1, 1]),
      f"Infusion of Light: light falling at your sides {look('infusion')}")
check(look("reckoning") == (["proc_aura", "rise_core", "rise_glow"], [0], [-1, 1]),
      f"Reckoning: light rising at your sides {look('reckoning')}")
check(look("vengeance") == (["halo_base", "halo_core", "halo_glow", "proc_spot"], [-150], [0]),
      f"Vengeance: a circle at your feet {look('vengeance')}")
check(look("redoubt") == look("vengeance"), "Redoubt: the circle at your feet, in its own colour")
check(look("shieldsworn") == (["halo_rev_core", "halo_rev_glow", "proc_spot"], [-150], [0]),
      f"Shieldsworn: a wider ring turning the other way {look('shieldsworn')}")
check(look("divinefavor") == (["halo_core", "halo_glow", "proc_spot"], [150], [0]),
      f"Divine Favor: a halo over your head {look('divinefavor')}")
check(look("ironcreed") == (["proc_spot", "shield_core", "shield_glow"], [10], [0]),
      f"Iron Creed: a shield in front of you {look('ironcreed')}")
colors = {key: tuple(round(v, 2) for v in ns.ProcsState(key).dressed.tinted[2][1].color.values())[:3] for key, _ in PROCS}
check(len(set(colors.values())) == len(PROCS), f"each in its own colour: {colors}")
inf = ns.ProcsState("infusion").dressed
check(inf.calm.alpha == 0.2 and inf.strike.alpha == 0.6, "the burst at 60%, the calm at 20%")
place = ns.ProcsState("infusion").place
check(ns.ProcsState("infusion").holder.scale == 0.4, "at 40% of its size")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Infusion_of_Light=(10, 15, 999200))
check(999200 in ns.ProcsState("infusion").container.slot.options.candidateFilters.includeSpellIDs.keys()
      and db.procs.learned[999200] == "infusion", "an Infusion of Light with another number is learned")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Vengeance=(0, 0, 20050))
check(ns.ProcsState("vengeance").container is None or 20050 not in
      ns.ProcsState("vengeance").container.slot.options.candidateFilters.includeSpellIDs.keys(),
      "one that never ends is a passive: left out")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Divine_Favor=(0, 0, 20216))
check(20216 in ns.ProcsState("divinefavor").container.slot.options.candidateFilters.includeSpellIDs.keys()
      and not db.procs.ignored[20216], "Divine Favor lasts until you use it: not a passive")
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
out = slash("procs")
spot = ns.ProcsState("infusion").spot
shown = [key for key, _ in PROCS if ns.ProcsState(key).sampleFrame.shown]
check(spot.shown and shown == ["infusion", "divinefavor", "vengeance", "ironcreed"],
      f"/paladingod procs shows one for each place: {shown}")
spot.scripts.OnUpdate(spot, 0.1)
check(ns.ProcsState("divinefavor").sample.timer.text == "" and ns.ProcsState("infusion").sample.timer.text == "15",
      "Divine Favor's sample has no countdown, Infusion of Light's counts from 15")
check(len(out) == len(PROCS), f"and says what each watches: {out}")
S.now = S.now + 6
G.RunTimers()
check(not spot.shown, "a few seconds later they're gone")
ns.TestProcs("shieldsworn")
check(ns.ProcsState("shieldsworn").sampleFrame.shown and not ns.ProcsState("infusion").sampleFrame.shown,
      "trying one shows that one")
S.now = S.now + 6
G.RunTimers()

# ---------------------------------------------------------------- Shields: Templar's Bulwark, potions
bar = G.NAMED["PaladinGodBarrier"]
status = next(fr for fr in G.FRAMES.values() if fr.kind == "StatusBar" and G.Same(fr.parent, bar))
S.absorb = 0
ns.UpdateBarrier()
check(not bar.shown, "no shield: no bar")
S.absorb = 2400
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Templar_s_Bulwark=(8, 8, 1311015))
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1311015)
G.RunTimers()
check(bar.shown and list(status.minmax.values()) == [0, 2400] and status.value == 2400 and bar.text.text == "2400"
      and bar.time.text == "8", f"Templar's Bulwark: a full bar with what it absorbs and its 8 seconds ({bar.text.text}, {bar.time.text})")
check(tuple(round(v, 2) for v in status.barColor.values()) == (1, 0.82, 0.3) and bar.icon.tex == 1311015, "in gold, with its icon")
S.absorb = 900
S.now = S.now + 3
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(status.value == 900 and bar.time.text == "5", "hits taken: less left")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(not bar.shown, "broken: the bar goes")
S.combat, S.secret = True, True
G.Fire("PLAYER_REGEN_DISABLED")
S.absorb = G.Hidden(1800)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17545)
G.RunTimers()
check(bar.shown and status.hiddenValue and bar.text.hiddenText and bar.time.text == "2:00"
      and tuple(round(v, 2) for v in status.barColor.values()) == (1, 0.85, 0.35),
      "a Greater Holy Protection Potion in a fight, hidden: the game fills the bar, two minutes, holy's colour")
S.now = S.now + 121
ns.UpdateBarrier()
check(not bar.shown, "after its two minutes it goes")
S.combat, S.secret = False, False
G.Fire("PLAYER_REGEN_ENABLED")
db.barrier.potions = False
S.absorb = 500
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17543)
G.RunTimers()
check(not bar.shown, "potions can be left out")
db.barrier.potions = True
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
S.absorb = 300
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Power_Word__Shield=(30, 30, 10901))
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(bar.shown and tuple(round(v, 2) for v in status.barColor.values()) == (1, 0.92, 0.6), "a priest's shield on you: it shows too")
S.absorb = 0
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
S.absorb = 250
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900), Divine_Aegis=(12, 12, 431624))
G.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(bar.shown and tuple(round(v, 2) for v in status.barColor.values()) == (1, 0.97, 0.82),
      "another class's shield (a priest's Divine Aegis): known too, in its colour")
db.barrier.enabled = False
ns.UpdateBarrier()
check(not bar.shown, "the bar can be turned off")
db.barrier.enabled = True
S.absorb = 0
auras(Devotion_Aura=(0, 0), Blessing_of_Might=(3600, 3600), Well_Fed=(800, 900))
ns.UpdateBarrier()

# ---------------------------------------------------------------- The swing timer
sw = ns.SwingState()
sholder, sbar = sw.holder, sw.bar
check(not sholder.shown, "not attacking: no bar")
check(S.cvars.showSwingTimer == "0" and db.swing.restoreBlizzard, "the game's own swing bar is turned off")
G.Fire("PLAYER_SWING", 3.6, 0)
check(sholder.shown and sbar.time.text == "3.6" and sbar.tag.tex == 1234, "a swing: the bar, its seconds and your weapon")
G.Fire("PLAYER_SWING", 1.8, 1)
check(sbar.time.text == "3.6", "an off-hand swing isn't a paladin's: left alone")
S.now = S.now + 1.8
ns.UpdateSwing()
check(sbar.time.text == "1.8" and abs(sbar.fill.width - 100) < 1e-6, f"halfway: half full ({sbar.fill.width})")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, False, True)
ns.UpdateSwing()
check(sholder.alpha == 0.55, "out of your weapon's reach: dimmed")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, True, True)
S.now = S.now + 4
ns.UpdateSwing()
check(not sholder.shown, "done and nothing more: gone a moment later")
db.swing.hideBlizzard = False
ns.SwingBlizzard()
check(S.cvars.showSwingTimer == "1", "the game's bar back when you want it")
db.swing.hideBlizzard = True
ns.SwingBlizzard()
slash("golpe" if es else "swing")
check(sholder.shown, "/paladingod swing tries it")
S.now = S.now + 7
G.RunTimers()
check(not sholder.shown, "and it goes")

# ---------------------------------------------------------------- Hammer of Wrath and Exorcism
ex = ns.ExecuteState()
hammer, exo, eholder = ex.hammer, ex.exorcism, ex.holder
S.target = lua.table(hostile=True)
S.creature = "Undead"
G.Fire("PLAYER_TARGET_CHANGED")
check(exo.shown and eholder.shown and not hammer.shown, "an undead targeted: Exorcism")
G.COOLDOWNS[879] = lua.table(isActive=True, duration=15, startTime=S.now, isOnGCD=False)
ns.UpdateExecute()
check(not exo.shown, "cooling down: not yet")
G.COOLDOWNS[879] = lua.table(isActive=True, duration=1.5, startTime=S.now, isOnGCD=True)
ns.UpdateExecute()
check(exo.shown, "the global cooldown doesn't hide it")
G.COOLDOWNS[879] = lua.table(isActive=True, duration=G.SECRET, isOnGCD=G.SECRET)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 879)
check(not exo.shown, "in a fight the game won't say whose cooldown: by when you cast it")
S.now = S.now + 16
ns.UpdateExecute()
check(exo.shown, "fifteen seconds on: ready")
G.COOLDOWNS[879] = None
S.creature = "Beast"
G.Fire("PLAYER_TARGET_CHANGED")
check(not exo.shown and not eholder.shown, "a beast: nothing")
S.creature = G.SECRET
G.Fire("PLAYER_TARGET_CHANGED")
check(not exo.shown, "its kind hidden: no guessing")
S.creature = "Beast"
G.Fire("PLAYER_TARGET_CHANGED")
S.health = 0.5
know(24275)
check(not hammer.shown, "Hammer of Wrath learned, target at 50%: nothing")
S.health = 0.15
ns.UpdateExecute()
check(hammer.shown and hammer.alpha == 1 and not hammer.hiddenAlpha, "at 15%: the hammer")
G.UNUSABLE[24275] = False
ns.UpdateExecute()
check(not hammer.shown, "not enough mana for it: the game says so, nothing")
G.UNUSABLE[24275] = G.SECRET
ns.UpdateExecute()
check(hammer.shown, "a hidden answer doesn't count")
G.UNUSABLE[24275] = None
S.secret = True
ns.UpdateExecute()
check(hammer.shown and hammer.hiddenAlpha and hammer.alpha == 1, "health hidden in a fight: the game shows it itself")
S.health = 0.6
ns.UpdateExecute()
check(hammer.hiddenAlpha and hammer.alpha == 0, "and hides it over 20%")
S.secret = False
S.health = 1
db.execute.hammer = False
db.execute.exorcism = False
S.creature = "Undead"
G.Fire("PLAYER_TARGET_CHANGED")
check(not exo.shown and not hammer.shown, "both can be turned off")
db.execute.hammer = True
db.execute.exorcism = True
slash("martillo" if es else "hammer")
check(exo.shown and hammer.shown and hammer.alpha == 1, "/paladingod hammer shows both")
S.now = S.now + 5
G.RunTimers()
S.target = None
G.Fire("PLAYER_TARGET_CHANGED")
check(not eholder.shown, "no target: nothing")


# ---------------------------------------------------------------- Hammer of Justice while your target casts
S.target = lua.table(hostile=True)
S.creature = "Beast"
G.Fire("PLAYER_TARGET_CHANGED")
justice = ns.ExecuteState().justice
S.dist = 8
G.CASTING = lua.table("Shadow Bolt", "Shadow Bolt", 136197, 0, 3000, False)
know(853)
ns.UpdateExecute()
check(justice.shown and justice.box.text.text == L.INTERRUPT_WORD and justice.box.icon.tex == 853,
      "your target casting, Hammer of Justice ready and in reach: its icon, to stop it")
G.CASTING = lua.table(G.SECRET, G.SECRET, G.SECRET, G.SECRET, G.SECRET, False)
ns.UpdateExecute()
check(justice.shown, "in a fight what it casts is hidden, but not that it casts")
G.CASTING = None
ns.UpdateExecute()
check(not justice.shown, "not casting: nothing")
G.CHANNELING = lua.table("Mind Flay", "Mind Flay", 1, 0, 3000, False)
ns.UpdateExecute()
check(justice.shown, "channelling counts too")
S.dist = 20
ns.UpdateExecute()
check(not justice.shown, "out of the hammer's 10 yards: not yet")
S.dist = 8
G.COOLDOWNS[853] = lua.table(isActive=True, duration=60, startTime=S.now, isOnGCD=False)
ns.UpdateExecute()
check(not justice.shown, "the hammer cooling down: nothing")
G.COOLDOWNS[853] = None
db.execute.interrupt = False
ns.UpdateExecute()
check(not justice.shown, "it can be turned off")
db.execute.interrupt = True
G.CHANNELING = None
S.target = None
G.Fire("PLAYER_TARGET_CHANGED")

# ---------------------------------------------------------------- Big cooldowns: a pulse when each is back
cd = ns.CooldownsState()
cplace, cart, cpoller = cd.place, cd.art, cd.poller
know(642)  # Divine Shield
check(cd.spells.divineShield.spell == 642 and cd.spells.layOnHands.spell is None, "the ones you know are watched")


def cooldown(spell, **kw):
    G.COOLDOWNS[spell] = lua.table(**kw)


def poll():
    cpoller.scripts.OnUpdate(cpoller, 0.2)


def frame(t):
    S.now = S.now + t
    cplace.scripts.OnUpdate(cplace, t)


cooldown(642, isActive=False, duration=0)
G.Fire("SPELL_UPDATE_COOLDOWN")
check(not cplace.shown, "ready from the start: nothing")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 642)
cooldown(642, isActive=True, duration=300, startTime=S.now, isOnGCD=False)
G.Fire("SPELL_UPDATE_COOLDOWN")
check(cpoller.shown and cd.spells.divineShield.own, "Divine Shield cast: watched")
S.now = S.now + 300
cooldown(642, isActive=False, duration=0)
poll()
check(cplace.shown and cart.icon.tex == 642, "back: its icon pops up in the middle")
frame(0.2)
check(abs(cart.box.alpha - 0.9) < 1e-9, f"held at its strength: {cart.box.alpha}")
frame(2)
check(not cplace.shown, "gone in under a second")
# The global cooldown isn't its own, even when the game hides how long it is
S.combat = True
cooldown(642, isActive=True, duration=G.SECRET, isOnGCD=G.SECRET)
G.Fire("SPELL_UPDATE_COOLDOWN")
S.now = S.now + 1.4
cooldown(642, isActive=False, duration=G.SECRET, isOnGCD=G.SECRET)
poll()
check(not cplace.shown, "a hidden global cooldown: no pulse")
# In combat, instant spells one after another: the global cooldown never stops, and the game won't
# say whose cooldown it is (its timer may even count the global one)


def gcd(active):
    G.COOLDOWNS[61304] = lua.table(isActive=active, duration=G.SECRET, startTime=G.SECRET)


def hidden_cd(spell):
    cooldown(spell, isActive=True, duration=G.SECRET, startTime=G.SECRET, isOnGCD=G.SECRET)


for _ in range(5):
    gcd(True)
    hidden_cd(642)
    G.Fire("SPELL_UPDATE_COOLDOWN")
    for _ in range(7):
        S.now = S.now + 0.2
        poll()
gcd(False)
cooldown(642, isActive=False, duration=G.SECRET, startTime=G.SECRET, isOnGCD=G.SECRET)
poll()
check(not cplace.shown, "in combat, five global cooldowns in a row: no pulse")
# Divine Shield cast in a fight, unseen (its number hidden): once the global cooldown is over it
# still cools down, so it's its own
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", G.SECRET)
gcd(True)
hidden_cd(642)
G.Fire("SPELL_UPDATE_COOLDOWN")
S.now = S.now + 1.5
gcd(False)
poll()
for i in range(9):
    gcd(i % 2 == 0)
    S.now = S.now + 1.5
    poll()
cooldown(642, isActive=False, duration=G.SECRET, startTime=G.SECRET, isOnGCD=G.SECRET)
gcd(True)
poll()
check(cplace.shown and cart.icon.tex == 642, "in combat, Divine Shield back after its own cooldown, even under other global cooldowns: pulse")
frame(2)
G.COOLDOWNS[61304] = None
# A mob silences you: every spell shows cooling down for 4 s, and none of them was
S.LOC = 1
for _ in range(20):
    hidden_cd(642)
    S.now = S.now + 0.2
    poll()
S.LOC = 0
cooldown(642, isActive=False, duration=G.SECRET, startTime=G.SECRET, isOnGCD=G.SECRET)
poll()
check(not cplace.shown, "a silence ending: no pulse")
S.LOC = 1
cooldown(642, isActive=True, duration=4, startTime=S.now, isOnGCD=False)
G.Fire("SPELL_UPDATE_COOLDOWN")
for _ in range(20):
    S.now = S.now + 0.2
    poll()
S.LOC = 0  # the game says it's over a moment before the spells
S.now = S.now + 0.2
poll()
cooldown(642, isActive=False, duration=0, startTime=0, isOnGCD=False)
S.now = S.now + 0.1
poll()
check(not cplace.shown, "a silence ending, its time showing: no pulse")
# Divine Shield already cooling down when the silence comes: it still pulses when it's back
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 642)
cooldown(642, isActive=True, duration=300, startTime=S.now, isOnGCD=False)
G.Fire("SPELL_UPDATE_COOLDOWN")
S.LOC = 1
S.now = S.now + 4
poll()
S.LOC = 0
S.now = S.now + 296
cooldown(642, isActive=False, duration=0, startTime=0, isOnGCD=False)
poll()
check(cplace.shown and cart.icon.tex == 642, "cooling down before a silence: its pulse still comes")
frame(2)
S.combat = False
# Two back at once: one after the other
know(498)  # Divine Protection
for spell in (642, 498):
    cooldown(spell, isActive=True, duration=300, startTime=S.now, isOnGCD=False)
G.Fire("SPELL_UPDATE_COOLDOWN")
S.now = S.now + 300
for spell in (642, 498):
    cooldown(spell, isActive=False, duration=0)
poll()
check(cplace.shown and cart.icon.tex == 642 and len(list(cd.queue.values())) == 1, "two back at once: the first now")
frame(1)
check(cplace.shown and cart.icon.tex == 498, "and the next after it")
frame(2)
check(not cplace.shown, "then nothing")
db.cooldowns.spells.divineShield = False
cooldown(642, isActive=True, duration=300, startTime=S.now, isOnGCD=False)
G.Fire("SPELL_UPDATE_COOLDOWN")
S.now = S.now + 300
cooldown(642, isActive=False, duration=0)
poll()
check(not cplace.shown, "each one can be turned off")
db.cooldowns.spells.divineShield = True
slash("reutilizacion" if es else "cooldowns")
check(cplace.shown, "/paladingod cooldowns tries it")
frame(2)
G.COOLDOWNS[642] = None
G.COOLDOWNS[498] = None

# ---------------------------------------------------------------- Your effects beside your enemies' nameplates
dslots = ns.DebuffsState().slots
first = dslots[1]
c = first.container
check(len(list(dslots.values())) == 40 and c.unit == "nameplate1" and c.enabled, "an aura container on each enemy nameplate")
check(set(c.slots.keys()) == {"PaladinGodjudgement", "PaladinGodcontrol", "PaladinGodvindication"}
      and all(s.filter == "HARMFUL|PLAYER" for s in c.slots.values()), "a slot for each kind, yours only")


def ids(key):
    return sorted(c.slots["PaladinGod" + key].options.candidateFilters.includeSpellIDs.keys())


check(20188 in ids("judgement") and 20186 in ids("judgement") and 853 in ids("control") and 20066 not in ids("control")
      and ids("vindication") == [1], f"only the spells you know: Judgement and Hammer of Justice, not Repentance {ids('control')}")
know(20066)
check(20066 in ids("control"), "Repentance learned: watched too")
db.debuffs.judgement = False
ns.UpdateDebuffs()
check(ids("judgement") == [1], "a kind can be turned off")
db.debuffs.judgement = True
ns.UpdateDebuffs()
b = c.slots.PaladinGodcontrol.button
check(b.width == 22 and b.point[1] == "RIGHT" and b.point[4] == -25 and all(list(l.color.values()) == [0, 0, 0, 1] for l in b.lines.values()),
      f"small, with the reminders' black edge, in its place: {list(b.point.values())}")
check(G.Same(b.durationText.text, b.timer) and b.iconTexture is not None, "the game writes its seconds and puts its icon in")
plate = G.CreateFrame("Frame")
plate.UnitFrame = False  # a plate without its unit frame: the plate itself
S.plate = plate
G.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(G.Same(first.holder.parent, plate) and first.holder.shown and first.holder.point[1] == "RIGHT", "on the plate, left of its bar")
S.plate = None

# ---------------------------------------------------------------- Range
rng = G.NAMED["PaladinGodRange"]
S.target = lua.table(hostile=True)
yd = L.YARDS
db.range.display = "bracket"


def range_at(dist):
    S.dist = dist
    ns.UpdateRange()
    return rng.text.text if rng.shown else None


def colour():
    return tuple(round(c, 2) for c in rng.text.color.values())[:3]


check(range_at(3) == L.RANGE.melee and colour() == (0.3, 1, 0.3), f"3 yd: Melee, in words, green ({rng.text.text})")
check(range_at(8) == "5-8" and colour() == (1, 0.82, 0), f"8 yd: Judgement's 10 yards, yellow ({rng.text.text})")
check(range_at(18) == "15-20" and colour() == (0.45, 0.8, 1), f"18 yd: Exorcism's 30, blue ({rng.text.text})")
check(range_at(33) == "30-35" and colour() == (0.6, 0.6, 0.6), f"33 yd: out of range, grey ({rng.text.text})")
db.range.words = False
check(range_at(3) == "0-5", "melee as a number if you like")
db.range.words = True
db.range.unitLabel = True
range_at(18)
check(rng.unit.text == yd, "yd after it if you want")
db.range.unitLabel = False
S.target = lua.table(hostile=False)
check(range_at(33) == "30-35" and colour() == (0.96, 0.55, 0.73), f"a friend at 33 yd: within your heals ({rng.text.text})")
check(range_at(45) == "40-100" and colour() == (0.6, 0.6, 0.6), f"at 45 yd: out of them ({rng.text.text})")
db.range.friendly = False
check(range_at(20) is None, "friends can be left out")
db.range.friendly = True
S.target = lua.table(hostile=True)
S.secretRange = True
check(range_at(20) is None, "the game hides the range: nothing shown")
S.secretRange = False
db.range.display = "number"
check(range_at(18) is not None and rng.text.text.isdigit(), f"one number: {rng.text.text}")
db.range.onlyCombat = True
check(range_at(18) is None, "only in combat: nothing out of it")
db.range.onlyCombat = False
out = slash("rango" if es else "range")
check(len(out) == 2 and "Exorcism" in out[0], f"/paladingod range: {out}")
slash("meters")
check(db.range.units == "meters", "metres")
slash("yards")

# ---------------------------------------------------------------- Aggro
thr = G.NAMED["PaladinGodThreat"]
S.threat = lua.table(False, 1, 95, 95)
ns.UpdateThreat()
check(not thr.shown, "solo: you always have the aggro, nothing to say")
S.group = True
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 95, f"in a group at 95%: {thr.text.text}")
S.threat = lua.table(True, 3, 100, 130)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT_PULLED, "you pulled it")
db.buffs.fury = "tank"
ns.UpdateThreat()
check(not thr.shown, "tanking and you have it: nothing")
S.threat = lua.table(False, 1, 90, 90)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT_LOST, "tanking and it turns away: aggro lost")
db.range.tankWarn = False
ns.UpdateThreat()
check(not thr.shown, "that warning can be turned off")
db.range.tankWarn = True
db.buffs.fury = "warn"
S.threat = lua.table(G.SECRET, G.SECRET, G.SECRET, G.SECRET)
ns.UpdateThreat()
check(not thr.shown, "hidden threat: nothing")
S.threat = None
S.group = False
S.target = None
ns.UpdateRange()

# ---------------------------------------------------------------- Moving the displays
ns.SetUnlocked(True)
check(len(icons()) == 5 and food.shown and base.shown and gholder.shown and sholder.shown and eholder.shown
      and rng.shown and thr.shown and spot.shown and bar.shown and ns.CooldownsState().place.shown
      and ns.ExecuteState().justice.shown, "unlocked: samples of everything to drag")
check(click_of("aura") is None and click_of("seal") is None, "the click buttons stay out of the way")
check(all(f.mover.shown for f in ns.movers.values()), "each with its handle")
check(set(ns.movers.keys()) >= {"reminders", "food", "seal", "group", "procs", "swing", "execute", "range", "threat", "barrier", "cooldowns"},
      f"all of them: {sorted(ns.movers.keys())}")
ns.SetUnlocked(False)
check(icons() == [] and not base.shown and not gholder.shown and not sholder.shown and not eholder.shown
      and not thr.shown and not spot.shown, "locked: back to what's real")
S.combat = True
out = slash("unlock")
check(not ns.unlocked and out[0] == L.PREFIX + L.NOT_IN_COMBAT, "not in combat")
S.combat = False

# ---------------------------------------------------------------- Options
win, pages = ns.OptionsWindow()
page = {p.key: p for p in pages.values()}
check(set(page.keys()) == {"buffs", "group", "combat", "procs", "range", "threat"}, f"pages: {list(page.keys())}")
ns.ShowOptionsPage("buffs")
controls = {c.setting: c for c in page["buffs"].controls.values()}
aura = controls[L.OPT_AURA_CHOICE]
check(aura.text == L.AURA_AUTO, f"aura choice: {aura.text}")
aura.scripts.OnClick(aura)
check(db.buffs.auraChoice == "devotion" and aura.text == "Devotion Aura", f"next: {aura.text}")
db.buffs.auraChoice = "auto"
fury = controls["Righteous Fury"]
fury.scripts.OnClick(fury)
check(db.buffs.fury == "tank", "Righteous Fury: tank")
db.buffs.fury = "warn"
check(controls[L.OPT_SEAL_CHOICE] is not None and controls[L.OPT_SEAL_TARGET] is not None and controls[L.OPT_FOOD_ON] is not None
      and controls[L.OPT_RESPEC] is not None, "the seal, food and trainer options are there")
ns.ShowOptionsPage("group")
gcontrols = {c.setting: c for c in page["group"].controls.values()}
warrior = gcontrols[L.CLASSES.WARRIOR]
check(warrior.text == "Blessing of Might", f"the warrior's blessing: {warrior.text}")
warrior.scripts.OnClick(warrior)
check(db.group.classes.WARRIOR == "wisdom", "and the next one")
db.group.classes.WARRIOR = "might"
check(len([c for c in page["group"].controls.values() if c.setting in L.CLASSES.values()]) == 9, "a choice for each class")
ns.ShowOptionsPage("combat")
ccontrols = {c.setting: c for c in page["combat"].controls.values()}
blz = ccontrols[L.OPT_SWING_BLIZZARD]
blz.checked = False
blz.scripts.OnClick(blz)
check(not db.swing.hideBlizzard and S.cvars.showSwingTimer == "1", "the game's swing bar comes back from the options")
blz.checked = True
blz.scripts.OnClick(blz)
check(S.cvars.showSwingTimer == "0", "and goes again")
check(ccontrols[L.OPT_HAMMER % "Hammer of Wrath"] is not None and ccontrols[L.OPT_EXORCISM % "Exorcism"] is not None,
      "Hammer of Wrath and Exorcism switches")
ns.ShowOptionsPage("procs")
pcontrols = {c.setting: c for c in page["procs"].controls.values()}
size = pcontrols[L.OPT_PROCS_SIZE]
size.scripts.OnValueChanged(size, 80)
check(db.procs.size == 80 and ns.ProcsState("infusion").holder.scale == 0.8 and spot.shown, "procs' size, shown as it changes")
inf_switch = pcontrols[L.OPT_PROC.infusion % "Infusion of Light"]
inf_switch.checked = False
inf_switch.scripts.OnClick(inf_switch)
check(not db.procs.infusion.enabled and not ns.ProcsState("infusion").holder.shown, "a proc switched off: the game shows nothing")
inf_switch.checked = True
inf_switch.scripts.OnClick(inf_switch)
ns.ShowOptionsPage("range")
rcontrols = {c.setting: c for c in page["range"].controls.values()}
check(all(L.RANGE[s] in rcontrols for s in ("melee", "judge", "ranged", "heal", "out")), "a preview sample for each state")
ns.ShowOptionsPage("threat")
check(any(c.setting == L.OPT_TANK_WARN for c in page["threat"].controls.values()), "the aggro page, with the tank's warning")
win.Hide(win)
S.now = S.now + 10
G.RunTimers()

# ---------------------------------------------------------------- Not a paladin
S["class"] = "WARRIOR"
auras()
S.target = lua.table(hostile=True)
G.Fire("PLAYER_TARGET_CHANGED")
ns.RefreshAll()
check(icons() == [] and not food.shown and not base.shown and range_at(3) is None and not eholder.shown,
      "a warrior sees none of it")
G.Fire("PLAYER_SWING", 2.0, 0)
check(not sholder.shown, "nor its swing")
S["class"] = "PALADIN"
S.target = None

# ---------------------------------------------------------------- Another class: nothing at all on screen
# Every ...God is installed together: on a mage, PaladinGod must show nothing but its minimap button
# and its options, whatever would set its reminders off
S["class"] = "MAGE"
SPELLS = G.SPELLS
SPELLS[3561] = "Teleport: Stormwind"
SPELLS[1459] = "Arcane Intellect"
know(3561, 1459, 2383)  # a mage who teleports, buffs Intellect and picks herbs
auras()  # no food, no seal, no aura, nothing
S["items"][17031] = 0  # no Rune of Teleportation
S.durability = lua.table_from({1: lua.table(5, 100)})
S.free = lua.table_from({0: 2})
S.group = True
S.units = lua.table_from({"party1": lua.table(name="Garrosh", **{"class": "WARRIOR"}),
                          "party2": lua.table(name="Jaina", **{"class": "MAGE"})})
S.unitAuras = lua.table()
S.tracking = lua.table(lua.table(name="Find Herbs", spellID=2383, active=False, type="spell"))
S.target = lua.table(hostile=True)
S.creature = "Undead"
S.health = 0.1
S.absorb = 400
for event in ("PLAYER_TARGET_CHANGED", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "GROUP_ROSTER_UPDATE",
              "MINIMAP_UPDATE_TRACKING", "UNIT_ABSORB_AMOUNT_CHANGED"):
    G.Fire(event, "player")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1311015)
G.Fire("PLAYER_SWING", 3.0, 0)
G.RunTimers()
ns.RefreshAll()
for proc in ("infusion", "vengeance"):
    ns.TestProcs(proc)
ns.TestCooldowns()
ns.TestExecute()
ns.TestSwing()
check(len(list(ns.ReagentReminders().values())) > 0 and len(list(ns.GroupBuffReminders().values())) > 0
      and len(list(ns.RepairReminders().values())) > 0 and ns.GatherReminder() is not None,
      "the shared files would warn a mage: runes, Intellect, gear and bags, herbs")
check(list(G.ShownOnScreen().values()) == [], f"on a mage, with all of that, nothing of PaladinGod shows: {list(G.ShownOnScreen().values())}")
out = slash("unlock")
check(not ns.unlocked and out == [L.PREFIX + L.OTHER_CLASS], f"moving the displays: not on a mage, and why ({out})")
printed.clear()
ns.SetUnlocked(True)  # the minimap button's or the options' way, not a command
check(not ns.unlocked and printed == [L.PREFIX + L.OTHER_CLASS], f"from a button too, it says why: {printed}")
ns.unlocked = True  # even forced on, as if it had been left so
ns.RefreshAll()
check(list(G.ShownOnScreen().values()) == [], f"nor any sample to move: {list(G.ShownOnScreen().values())}")
ns.unlocked = False
G.NAMED["PaladinGodMinimapButton"].shown = True
check(G.NAMED["PaladinGodMinimapButton"].shown, "the minimap button stays")

# Nor in the chat: the family's shared files speak at a vendor or a trainer, and on a mage this one
# keeps quiet; a command typed still answers
S["class"] = "MAGE"
S.durability = lua.table_from({1: lua.table(40, 100)})
S.canRepair = True
S["items"][17031] = 0
know(3561)
G.MERCHANT = lua.table(17031)
G.Fire("BAG_UPDATE_DELAYED")
G.Fire("UPDATE_INVENTORY_DURABILITY")
check(len(list(ns.RepairReminders().values())) > 0 and len(list(ns.ReagentReminders().values())) > 0,
      "the shared files have something to say to a mage: worn gear, runes")
printed.clear()
G.Fire("MERCHANT_SHOW")
G.Fire("CONFIRM_TALENT_WIPE", 10000, 0)
G.RunTimers()
check(printed == [], f"on a mage, at a vendor who repairs and sells runes, and at the trainer: nothing in the chat: {printed}")
out = slash("help")
check(len(out) > 0, "a command typed still answers")
out = slash("rango" if es else "range")
check(len(out) > 0 and out[0].startswith(L.PREFIX), f"through the addon's own print too: {out[:1]}")
check(not ns.inCommand, "and nothing stays switched on after a command")
S["class"] = "PALADIN"
printed.clear()
G.Fire("MERCHANT_SHOW")
check(L.PREFIX + ns.REPAIR_TEXT.VENDOR % 40 in printed, f"a paladin still hears the vendor: {printed}")
S.durability = lua.table()
S.canRepair = False
S["items"][17031] = None
G.MERCHANT = lua.table()
know(3561, on=False)
S["class"] = "PALADIN"
S.target = None
S.creature = None
S.health = 1
S.absorb = 0
S.group = False
S.units = lua.table()
S.tracking = lua.table()
S.durability = lua.table()
S.free = lua.table()
S["items"][17031] = None
know(3561, 1459, 2383, on=False)
G.Fire("GROUP_ROSTER_UPDATE")
G.Fire("BAG_UPDATE_DELAYED")
S.now = S.now + 10
G.RunTimers()
ns.RefreshAll()

out = slash("help")
check(len(out) == len(list(L.HELP.values())), "help lists the commands")
slash("boton" if es else "button")
check(db.minimapButton.hide and not G.NAMED["PaladinGodMinimapButton"].shown, "the minimap button can be hidden")
slash("button")

# ---------------------------------------------------------------- Talent reset price at the trainer
rs = ns.RespecState()
rnote = rs.note
S.server, S.money = 1795600000, 500000
G.GOSSIP_OPTIONS = lua.eval('{ { gossipOptionID = 101, name = "I am here for training." }, { gossipOptionID = 102, name = "I wish to unlearn my class or legacy talents." } }')
G.Fire("GOSSIP_SHOW")
check(rnote.shown and (L.RESPEC_UNKNOWN % "PaladinGod") in rnote.body.text, "your class trainer: the note under its window")
G.Fire("GOSSIP_CLOSED")
S["class"] = "MAGE"
G.Fire("GOSSIP_SHOW")
check(not rnote.shown, "another class: not this addon's trainer")
S["class"] = "PALADIN"

print()
blocked = sorted(set(G.BLOCKED.values()))
# ---------------------------------------------------------------- At a merchant: repair and buy reagents (shared files)
# (ClassGods/test_vendor_block.py: the same block in every ...God harness)
lua.execute('''
G.bought = {}
G.prices = {}
GetMerchantNumItems = function() return #G.merchant end
GetMerchantItemID = function(i) return G.merchant[i] end
GetMerchantItemInfo = function(i) local id = G.merchant[i] return "item " .. id, 0, G.prices[id] or 100, 1, -1, true end
GetMerchantItemMaxStack = function() return 20 end
BuyMerchantItem = function(i, n)
  local id = G.merchant[i]
  table.insert(G.bought, n)
  G.items[id] = (G.items[id] or 0) + n
  G.money = G.money - (G.prices[id] or 100) * n
end
GetMoney = function() return G.money or 0 end
GetRepairAllCost = function() return G.repairCost or 0, (G.repairCost or 0) > 0 end
RepairAllItems = function() G.repaired = (G.repaired or 0) + 1 G.money = G.money - G.repairCost G.repairCost = 0 end
CanMerchantRepair = function() return G.repairs end
GetCoinTextureString = nil
''')
if S["items"] is None:
    S["items"] = lua.table()
S.merchant = lua.table()
VT = ns.REPAIR_TEXT
me = {"HunterGod": "HUNTER", "MageGod": "MAGE", "WarriorGod": "WARRIOR", "PaladinGod": "PALADIN", "RogueGod": "ROGUE",
      "PriestGod": "PRIEST", "ShamanGod": "SHAMAN", "WarlockGod": "WARLOCK", "DruidGod": "DRUID"}[Path(ADDON).resolve().name]
S["class"] = me
other = "PRIEST" if me != "PRIEST" else "MAGE"
check(db.repair.auto is False and VT.OPT_AUTO, "repairing at a merchant: an option, off by default")
S.repairs, S.repairCost, S.money, S.repaired = True, 12345, 100000, 0
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 0, "off: it doesn't repair")
db.repair.auto = True
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and S.money == 100000 - 12345 and len(printed) == 1 and VT.REPAIRED % "1g 23s 45c" in printed[0],
      f"on: it repairs everything and says what it cost: {list(printed)}")
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1, "nothing worn: it doesn't repair again")
S.repairCost, S.money = 50000, 1000
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and len(printed) == 1 and VT.SHORT % "5g 0s 0c" in printed[0],
      f"not enough money: says so and doesn't repair: {list(printed)}")
S.money = 100000
S.repairs = False
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and not printed, "a merchant who doesn't repair: nothing")
S.repairs = True
S["class"] = other
printed.clear()
G.Fire("MERCHANT_SHOW")
check(S.repaired == 1 and not printed, "another class: this addon doesn't repair (that class's own does)")
S["class"] = me
S.repairs, S.repairCost = False, 0
db.repair.auto = False

own = ns.REAGENTS[me] if ns.REAGENTS else None
r = None
if own:
    for i in range(1, len(own) + 1):
        if own[i].vendor and own[i].stock and G.C_Spell.GetSpellName(own[i].spells[1]):
            r = own[i]
            break
if r:
    RT2 = ns.REAGENT_TEXT
    check(db.reagents.buy is False and RT2.OPT_BUY, "buying reagents: an option, off by default")
    # Only its spell known: a better rank would take over
    for i in range(1, len(own) + 1):
        for j in range(1, len(own[i].spells) + 1):
            S.known[own[i].spells[j]] = None
    know(r.spells[1])
    G.Fire("SPELLS_CHANGED")
    S["items"][r.item] = 2
    S.merchant = lua.table(159, r.item)
    S.money = 1000000
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(len(S.bought) == 0, "off: it doesn't buy")
    db.reagents.buy = True
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    want = r.stock - 2
    check(S["items"][r.item] == r.stock and sum(S.bought[i] for i in range(1, len(S.bought) + 1)) == want
          and all(S.bought[i] <= 20 for i in range(1, len(S.bought) + 1)),
          f"on: it buys up to {r.stock}, at most a stack at a time: {S['items'][r.item]}")
    money = f"{want * 100 // 10000}g {want * 100 // 100 % 100}s 0c"
    check(len(printed) == 1 and RT2.BOUGHT.split("%d")[0] in printed[0] and money in printed[0],
          f"and says what it bought and spent: {list(printed)}")
    bought = len(S.bought)
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(len(S.bought) == bought and not printed, "enough already: nothing")
    S["items"][r.item] = 0
    S.money = 250
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 2, f"only what the money pays for: {S['items'][r.item]}")
    S.money = 0
    S["items"][r.item] = 0
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 0 and len(printed) == 1 and RT2.SHORT.split("%s")[0] in printed[0],
          f"no money: says so: {list(printed)}")
    S.money = 1000000
    S["class"] = other
    printed.clear()
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == 0, "another class: this addon doesn't buy")
    S["class"] = me
    db.reagents.enabled = False
    G.Fire("MERCHANT_SHOW")
    check(S["items"][r.item] == r.stock, "it buys with the low reagent reminder off too")
    db.reagents.enabled = True
    db.reagents.buy = False
    know(r.spells[1], on=False)
    G.Fire("SPELLS_CHANGED")
    S["items"][r.item] = 0
    S.merchant = lua.table()
    G.Fire("BAG_UPDATE_DELAYED")

# ---------------------------------------------------------------- Reagent vendors on the world map (shared files)
# (ClassGods/test_reagentmap_block.py: the same block in every ...God harness that spends reagents)
lua.execute('''
HBD_PINS_WORLDMAP_SHOW_PARENT = 1
local pinsLib = {
  AddWorldMapIconMap = function(_, ref, pin, m, x, y) G.mapPins = (G.mapPins or 0) + 1 G.lastPin = pin end,
  RemoveAllWorldMapIcons = function() G.mapPins = 0 end,
}
LibStub = setmetatable({}, { __call = function(_, name) if name == "HereBeDragons-Pins-2.0" then return pinsLib end end })
UnitFactionGroup = function() return G.faction or "Alliance" end
''')
MT = ns.REAGENT_MAP_TEXT
me = {"MageGod": "MAGE", "PriestGod": "PRIEST", "DruidGod": "DRUID", "PaladinGod": "PALADIN", "RogueGod": "ROGUE",
      "ShamanGod": "SHAMAN", "WarlockGod": "WARLOCK"}[Path(ADDON).resolve().name]
S["class"] = me
own = ns.REAGENTS[me]
r = None
for i in range(1, len(own) + 1):
    if own[i].vendor and G.C_Spell.GetSpellName(own[i].spells[1]):
        r = own[i]
        break
check(db.reagents.map is True and MT.OPT_MAP, "reagent vendors on the map: an option, on by default")
for i in range(1, len(own) + 1):
    for j in range(1, len(own[i].spells) + 1):
        S.known[own[i].spells[j]] = None
G.Fire("SPELLS_CHANGED")
ns.RefreshReagentMap()
check(S.mapPins == 0, f"none of its spells known: no vendors on the map ({S.mapPins})")
know(r.spells[1])
G.Fire("SPELLS_CHANGED")
vendors = ns.REAGENT_VENDORS


def expected(side):
    n = 0
    for _, v in vendors.items():
        sells = any(v["items"][k] == r.item for k in range(1, len(v["items"]) + 1))
        if sells and v.side in (side, "B"):
            n += 1
    return n


S.faction = "Alliance"
ns.RefreshReagentMap()
check(S.mapPins == expected("A") and S.mapPins > 0, f"its spell known: the Alliance vendors of {r.item} ({S.mapPins})")
pin = S.lastPin
check(pin["items"][1] == r.item, "the pin is that reagent")
S.faction = "Horde"
ns.RefreshReagentMap()
check(S.mapPins == expected("H") and S.mapPins > 0, f"a Horde character: the Horde ones ({S.mapPins})")
S.faction = None
db.reagents.map = False
ns.RefreshReagentMap()
check(S.mapPins == 0, "turned off: none")
db.reagents.map = True
S["class"] = "HUNTER"
ns.RefreshReagentMap()
check(S.mapPins == 0, "another class: this addon draws none")
S["class"] = me
S.known[1225503] = True
G.Fire("SPELLS_CHANGED")
ns.RefreshReagentMap()
check(S.mapPins == 0, "with Reagent Economy: none")
S.known[1225503] = None
know(r.spells[1], on=False)
G.Fire("SPELLS_CHANGED")
lua.execute("LibStub = nil")

# ---------------------------------------------------------------- Missing buffs your group can give (shared file)
# (ClassGods/test_groupneeds_block.py: the same block in every ...God harness)
me = {"HunterGod": "HUNTER", "MageGod": "MAGE", "WarriorGod": "WARRIOR", "PaladinGod": "PALADIN", "RogueGod": "ROGUE",
      "PriestGod": "PRIEST", "ShamanGod": "SHAMAN", "WarlockGod": "WARLOCK", "DruidGod": "DRUID"}[Path(ADDON).resolve().name]
party = [c if c != me else "WARRIOR" for c in ("MAGE", "PRIEST", "DRUID", "PALADIN")]
lua.execute('''
local saved = { IsInInstance = IsInInstance, IsInGroup = IsInGroup, IsInRaid = IsInRaid, UnitExists = UnitExists,
  UnitIsUnit = UnitIsUnit, UnitClass = UnitClass, aura = C_UnitAuras.GetAuraDataByIndex, SendChatMessage = SendChatMessage,
  UnitIsDeadOrGhost = UnitIsDeadOrGhost, InCombatLockdown = InCombatLockdown, name = C_Spell.GetSpellName }
G.needs = { party = {}, buffs = {}, inside = false, sent = {} }
IsInInstance = function() return G.needs.inside, G.needs.inside and "party" or "none" end
IsInGroup = function() return #G.needs.party > 0 end
IsInRaid = function() return false end
UnitExists = function(u) local i = type(u) == "string" and u:match("^party(%d)$") if i then return G.needs.party[tonumber(i)] ~= nil end return saved.UnitExists(u) end
UnitIsUnit = function(a, b) return a == b end
UnitClass = function(u)
  if u == "player" then return "X", G.needs.class end
  local i = type(u) == "string" and u:match("^party(%d)$")
  if i then return "X", G.needs.party[tonumber(i)] end
  return saved.UnitClass(u)
end
C_UnitAuras.GetAuraDataByIndex = function(u, i, f)
  if u ~= "player" then return saved.aura(u, i, f) end
  local n = G.needs.buffs[i]
  if n then return { name = n } end
end
C_Spell.GetSpellName = function(id) return saved.name(id) or ("spell " .. id) end
SendChatMessage = function(msg, channel) table.insert(G.needs.sent, msg .. "|" .. channel) end
UnitIsDeadOrGhost = function() return false end
InCombatLockdown = function() return G.needs.combat end
function G.RestoreNeeds()
  IsInInstance, IsInGroup, IsInRaid, UnitExists = saved.IsInInstance, saved.IsInGroup, saved.IsInRaid, saved.UnitExists
  UnitIsUnit, UnitClass, C_UnitAuras.GetAuraDataByIndex = saved.UnitIsUnit, saved.UnitClass, saved.aura
  SendChatMessage, UnitIsDeadOrGhost, InCombatLockdown, C_Spell.GetSpellName = saved.SendChatMessage, saved.UnitIsDeadOrGhost, saved.InCombatLockdown, saved.name
end
''')
N = S.needs
N["class"] = me
NT = ns.GROUP_NEEDS_TEXT
check(db.groupNeeds.enabled is True and NT.OPT and NT.OPT_ANYWHERE, "the missing buffs row: an option, on by default")
st = ns.GroupNeedsState()
gbar = st.bar


def shown():
    ns.UpdateGroupNeeds()
    bs = st.buttons
    return [bs[i].entry.key for i in range(1, len(bs) + 1) if bs[i].shown] if gbar.shown else []


def name_of(i):
    return G.C_Spell.GetSpellName(i)


want = [k for k, c in (("intellect", "MAGE"), ("fortitude", "PRIEST"), ("mark", "DRUID"), ("blessing", "PALADIN"))
        if c in party and c != me and not (k == "intellect" and me in ("WARRIOR", "ROGUE"))]
N.party = lua.table(*party)
check(shown() == [], "in a group, out in the world: nothing")
N.inside = True
check(shown() == want, f"in a dungeon with {party}: what they can give you ({shown()})")
N.buffs = lua.table(name_of(21562))
check("fortitude" not in shown(), "Prayer of Fortitude on you: Fortitude isn't missing")
N.buffs = lua.table()
first = [b for b in (st.buttons[i] for i in range(1, len(st.buttons) + 1)) if b.shown and b.entry.key != "blessing"][0]
first.scripts.OnClick(first)
check(list(N.sent.values()) == [NT.ASK % first.entry.name + "|PARTY"], f"a click asks for it in the party chat: {list(N.sent.values())}")
first.scripts.OnClick(first)
check(len(N.sent) == 1, "a second click right away: not asked again")
S.now = S.now + 11
first.scripts.OnClick(first)
check(len(N.sent) == 2, "after a while: asked again")
if "blessing" in want:
    pal = [b for b in (st.buttons[i] for i in range(1, len(st.buttons) + 1)) if b.shown and b.entry.key == "blessing"][0]
    pal.scripts.OnClick(pal)
    check(st.menu.shown, "the blessing: a click opens the blessings")
    kings = st.menu.rows[3]
    kings.scripts.OnClick(kings)
    check(not st.menu.shown and db.groupNeeds.blessing == "kings" and list(N.sent.values())[-1] == NT.ASK % name_of(20217) + "|PARTY",
          f"picking Kings asks for it and remembers it: {list(N.sent.values())[-1]}")
    N.buffs = lua.table(name_of(25898))
    check("blessing" not in shown(), "Greater Blessing of Kings on you, one paladin: no blessing missing")
    N.buffs = lua.table()
    db.groupNeeds.blessing = "wisdom"
N.combat = True
check(shown() == [], "in a fight: nothing")
N.combat = None
db.groupNeeds.enabled = False
check(shown() == [], "turned off: nothing")
db.groupNeeds.enabled = True
N.inside = False
db.groupNeeds.anywhere = True
check(shown() == want, "with 'also outside': out in the world too")
db.groupNeeds.anywhere = False
N.inside = True
N["class"] = "HUNTER" if me != "HUNTER" else "MAGE"
check(shown() == [], "another class's character: this addon draws nothing")
N["class"] = me
N.party = lua.table()
check(shown() == [], "alone: nothing")
S.RestoreNeeds()
ns.UpdateGroupNeeds()

check(not blocked, f"nothing secure touched in a fight (the game blocks it): {blocked}")
leaks = sorted(set(G.LEAKS.values()))
check(not leaks, f"no globals left behind: {leaks}")

print("FAILURES:" if fails else f"All good ({LOCALE}).", fails if fails else "")
sys.exit(1 if fails else 0)
