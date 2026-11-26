local _, ns = ...
local L = ns.L

-- Herbalism or Mining without its tracking on, out in the world: one more reminder in the row, with
-- the icon of the tracking a click puts on. What to show comes from Gathering.lua, the same file in
-- every ...God addon (ns.GatherReminder); this puts it in PaladinGod's row, and keeps it away in a
-- fight and while you're dead
local frame
local inCombat = false

function ns.UpdateGather()
	if not ns.db then return end
	local pick
	if ns.unlocked then
		-- A sample to drag
		if ns.db.gather.enabled then pick = { spell = ns.SpellName(ns.GATHER[1].spell), icon = ns.SpellIcon(ns.GATHER[1].spell) } end
	elseif ns.IsPaladin() and not inCombat and not ns.Away() then
		pick = ns.GatherReminder()
	end
	if not pick then
		frame.spellName = nil
		if frame:IsShown() then frame:Hide() end
		return
	end
	frame.icon:SetTexture(pick.icon)
	frame.icon:SetDesaturated(true)
	frame.text:SetText("")
	frame.spellName = pick.spell
	if not frame:IsShown() then frame:Show() end
	ns.SyncReminders()
end
ns.GatherChanged = ns.UpdateGather

frame = CreateFrame("Frame", "PaladinGodGather", UIParent)
frame:Hide()
ns.StyleReminder(frame)
ns.AddReminder("gather", frame, function()
	if inCombat then return end
	return frame.spellName
end, function(tip)
	tip:AddLine(frame.spellName or "?", 1, 1, 1)
	tip:AddLine(L.GATHER_OFF, 1, 0.5, 0.4)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		table.insert(ns.refreshers, ns.UpdateGather)
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		-- A flight, dying and coming back
		for _, name in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
			pcall(self.RegisterEvent, self, name)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	end
	ns.UpdateGather()
end)
