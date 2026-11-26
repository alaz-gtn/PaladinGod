local _, ns = ...

-- Your group's missing buffs, from GroupBuffs.lua (the same file in every ...God addon), as
-- reminders in the row: the buff's icon with how many lack it, and a click out of combat casts it on
-- the first of them in range. A paladin's group buffs are the blessings, which Blessings.lua lists
-- by player, so the shared file brings none for the paladin today: these only show should it get some
local MAX = 3 -- reminders at most, one per buff
local frames = {}
local inCombat = false

function ns.UpdateGroupBuffs()
	if not ns.db then return end
	local list = {}
	if not inCombat and not ns.unlocked and ns.IsPaladin() and not ns.Away() and ns.GroupBuffReminders then
		list = ns.GroupBuffReminders()
	end
	for i, f in ipairs(frames) do
		local r = list[i]
		if r then
			f.icon:SetTexture(r.icon)
			f.icon:SetDesaturated(true)
			f.text:SetText(r.count)
			f.text:SetTextColor(1, 0.85, 0.4)
			f.entry = r
			if not f:IsShown() then f:Show() end
		else
			f.entry = nil
			if f:IsShown() then f:Hide() end
		end
	end
	ns.SyncReminders()
end
ns.GroupBuffsChanged = ns.UpdateGroupBuffs

for i = 1, MAX do
	local f = CreateFrame("Frame", "PaladinGodGroupBuff" .. i, UIParent)
	f:Hide()
	ns.StyleReminder(f)
	frames[i] = f
	ns.AddReminder("groupbuff" .. i, f, function()
		local r = f.entry
		-- Only with someone in range to cast it on, and out of combat
		if inCombat or not (r and r.unit) then return end
		return r.spell, "spell", r.unit
	end, function(tip)
		local r = f.entry
		if not r then return end
		tip:AddLine(r.text, 1, 1, 1)
		if r.click then tip:AddLine(r.click, 0.4, 0.7, 1) end
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		ns.UseFont(frames[1].text, ns.THIN_FONT, 15, "OUTLINE")
		for i = 2, MAX do ns.UseFont(frames[i].text, ns.THIN_FONT, 15, "OUTLINE") end
		table.insert(ns.refreshers, ns.UpdateGroupBuffs)
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	end
	ns.UpdateGroupBuffs()
end)
