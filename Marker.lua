--[[ RaidLeadKit - marking enemies on sight.

	Hold left Ctrl + left Shift and sweep the mouse over a pack: every enemy
	on the marking list gets its mark as it passes under the cursor. Rules
	with a mark of their own always get it; the rest take any mark no rule
	has claimed. A marked enemy is left alone for ten seconds, so going over
	the same pack again does not shuffle the marks around. ]]

local RLK = RaidLeadKit

local COOLDOWN = 10     -- seconds before the same enemy is marked again
local NOTICE_EVERY = 30 -- and before the "you cannot mark" line repeats

local marked = {}   -- guid -> when we marked it
local iconUsed = {} -- raid target index -> when it was given out
local reserved = {}
local noticeAt = 0

-- in 3.3.5 a creature's entry sits in the middle of its guid
local function npcIdOf(guid)
	if not guid or string.len(guid) < 12 then return end
	return tonumber(string.sub(guid, 9, 12), 16)
end

-- The guid is only taken apart when a rule actually asks for an npc id, so
-- a list of plain names costs one UnitName and a walk of short strings.
local function ruleFor(rules, unit, guid)
	local name = UnitName(unit)
	local id
	for _, rule in ipairs(rules) do
		local key = rule.key
		if type(key) == "number" then
			if id == nil then id = npcIdOf(guid) or false end
			if key == id then return rule end
		elseif key == name then
			return rule
		end
	end
end

-- a mark no rule asks for by name, the one out of use the longest
local function pickFree(now)
	wipe(reserved)
	for _, rule in ipairs(RLK.db.markRules) do
		if rule.icon and rule.icon > 0 then reserved[rule.icon] = true end
	end
	local oldest, oldestAt
	for i = 1, 8 do
		if not reserved[i] then
			local at = iconUsed[i]
			if not at or now - at >= COOLDOWN then return i end
			if not oldestAt or at < oldestAt then oldest, oldestAt = i, at end
		end
	end
	return oldest
end

local function canMark()
	return GetNumRaidMembers() == 0 or IsRaidLeader() or IsRaidOfficer()
end

function RLK:MarkUnit(unit)
	local rules = self.db and self.db.markRules
	if not rules or #rules == 0 or not UnitExists(unit) then return end
	-- living enemies only, and never another player
	if UnitIsDead(unit) or UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end

	-- the same enemy again within the window is left as it is
	local now, guid = GetTime(), UnitGUID(unit)
	local at = marked[guid]
	if at and now - at < COOLDOWN then return end

	local rule = ruleFor(rules, unit, guid)
	if not rule then return end

	if not canMark() then
		if now - noticeAt > NOTICE_EVERY then
			noticeAt = now
			self:Print("only the raid leader or an assistant can set marks")
		end
		return
	end

	local icon = rule.icon
	if icon == 0 then
		-- auto never takes a mark away from an enemy that already has one
		if GetRaidTargetIndex(unit) then return end
		icon = pickFree(now)
		if not icon then return end
	end
	SetRaidTarget(unit, icon)
	marked[guid] = now
	iconUsed[icon] = now
	return icon
end

-- Every mark is unique, so taking all eight onto yourself pulls them off
-- whatever had them; dropping your own leaves the field clean.
--
-- All nine calls in one frame is more than the server reliably takes: now
-- and then the last one is dropped and the skull stays on you. So the eight
-- go out in one frame and the one that takes the mark off in the next, and
-- that one is repeated until the client agrees the mark is gone.
local RETRY_EVERY, RETRIES = 0.25, 8

local clearer = CreateFrame("Frame")
local step, tries, since
clearer:Hide()
clearer:SetScript("OnUpdate", function(self, elapsed)
	if step == 1 then
		for i = 1, 8 do SetRaidTarget("player", i) end
		step = 2
		return
	elseif step == 2 then
		SetRaidTarget("player", 0)
		step = 3
		return
	end
	-- the answer comes back from the server, so give it time between tries
	since = since + elapsed
	if since < RETRY_EVERY then return end
	since = 0
	if not GetRaidTargetIndex("player") then
		self:Hide()
	elseif tries >= RETRIES then
		self:Hide()
		RLK:Print("could not take the last mark off you, try again")
	else
		tries = tries + 1
		SetRaidTarget("player", 0)
	end
end)

function RLK:ClearMarks()
	step, tries, since = 1, 0, 0
	wipe(marked)
	wipe(iconUsed)
	clearer:Show()
end

function RLK:MarkingHeld()
	return IsLeftControlKeyDown() and IsLeftShiftKeyDown()
end

-- The mouse passes over units all the time, so that event is only listened
-- to while both keys are down: the rest of the time the marker hears nothing
-- but the two keys themselves.
local f = CreateFrame("Frame")
f:RegisterEvent("MODIFIER_STATE_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local watching = false
local function watch(on)
	if on == watching then return end
	watching = on
	if on then
		f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	else
		f:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	end
end

f:SetScript("OnEvent", function(_, event, key)
	if event == "UPDATE_MOUSEOVER_UNIT" then
		-- a key let go while the window was not in focus never reaches us
		if not RLK:MarkingHeld() then return watch(false) end
		RLK:MarkUnit("mouseover")
	elseif event == "MODIFIER_STATE_CHANGED" then
		if key == "LCTRL" or key == "LSHIFT" then
			local held = RLK:MarkingHeld()
			watch(held)
			-- the keys can go down on an enemy already under the cursor
			if held then RLK:MarkUnit("mouseover") end
		end
	else
		wipe(marked)
		wipe(iconUsed)
	end
end)
