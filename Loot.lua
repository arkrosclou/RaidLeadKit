--[[ RaidLeadKit - master loot reminder.

	When you lead a raid and a boss is pulled while the loot method is not
	master loot, a raid-warning style message shows on your screen, with its
	sound, and a line in your chat. Only you see it; nothing goes to the raid.
	Once per pull. ]]

local RLK = RaidLeadKit

-- the client's own names for the loot methods, English when one is missing
local METHOD_NAMES = {
	freeforall      = LOOT_FREE_FOR_ALL or "Free for All",
	roundrobin      = LOOT_ROUND_ROBIN or "Round Robin",
	group           = LOOT_GROUP_LOOT or "Group Loot",
	needbeforegreed = LOOT_NEED_BEFORE_GREED or "Need before Greed",
	master          = LOOT_MASTER_LOOTER or "Master Looter",
}

local warned = false -- this pull has had its warning

function RLK:WarnLoot(test)
	local method = GetLootMethod()
	local text = "Master loot is not set: " .. (METHOD_NAMES[method] or tostring(method))
	if test then text = text .. " (test)" end
	RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
	PlaySound("RaidWarning")
	self:Print("|cffff2020" .. text .. "|r")
end

local function check()
	if warned or not RLK.db or not RLK.db.lootWarning then return end
	if GetNumRaidMembers() == 0 or not IsRaidLeader() then return end
	-- a boss pull: boss frames are up
	if not UnitExists("boss1") then return end
	if GetLootMethod() == "master" then return end
	warned = true
	RLK:WarnLoot()
end

local f = CreateFrame("Frame")
f:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT") -- boss frames appear on the pull
f:RegisterEvent("PLAYER_REGEN_DISABLED")          -- in case they were there first
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		warned = false -- the next pull warns again
	else
		check()
	end
end)
