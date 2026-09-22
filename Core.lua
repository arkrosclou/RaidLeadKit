--[[ RaidLeadKit - who in the group can provide each variant, and what is up.

	Nothing here runs on a timer. Roster, pet and talent changes only mark the
	state dirty; it is worked out again when the panel is opened (see
	RLK:Refresh). The scan for active auras runs once a second, and only while
	the panel is open (Display.lua). ]]

RaidLeadKit = RaidLeadKit or {}
local RLK = RaidLeadKit

-- variant states, in rising order of news
RLK.NONE, RLK.UNKNOWN, RLK.IN_RAID = 1, 2, 3

local LGT = LibStub("LibGroupTalents-1.0")

RLK.defaults = {
	point = { "CENTER", "CENTER", 0, 200 },
	locked = false,
	showMinor = false,
	hidden = false,
	anchor = "auto", -- see RLK.ANCHORS
	buttonSize = 32, -- the button
	iconSize = 24,   -- the icons in the panel
	rows = 12,        -- rows per column before the next column starts
	lootWarning = true, -- warn on a boss pull when master loot is not set
}

function RLK:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff2020Raid|rLeadKit: " .. tostring(msg))
end

-- every row list with the kind of aura its variants leave
local SECTIONS


-- ---------------------------------------------------------------------------
-- data prep: localized names, lookups
-- ---------------------------------------------------------------------------
local famKeyByName = {} -- localized pet family -> PET_FAMILIES key
RLK.variantsByAura = { buff = {}, debuff = {} } -- aura name -> { variant, ... }

local function prepare(rows, kind)
	local horde = UnitFactionGroup("player") == "Horde"
	for _, row in ipairs(rows) do
		row.kind = kind
		for _, v in ipairs(row.variants) do
			v.row = row
			local id = (horde and v.hordeSpell) or v.spell
			v.spellId = id
			v.name, _, v.icon = GetSpellInfo(id)
			v.name = v.name or ("spell " .. id)
			v.talentName = v.talent and GetSpellInfo(v.talent)
			v.providers, v.unknown, v.holders = {}, {}, {}
			v.state = RLK.NONE
			for _, auraId in ipairs(v.auras) do
				local aura = GetSpellInfo(auraId)
				if aura then
					local list = RLK.variantsByAura[kind][aura] or {}
					list[#list + 1] = v
					RLK.variantsByAura[kind][aura] = list
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- group members
-- ---------------------------------------------------------------------------
-- unit tokens of everyone in the group, the player included; reused table
local units = {}

function RLK:GroupUnits()
	wipe(units)
	local raid = GetNumRaidMembers()
	if raid > 0 then
		for i = 1, raid do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, GetNumPartyMembers() do units[#units + 1] = "party" .. i end
	end
	return units
end

local function petToken(unit)
	if unit == "player" then return "pet" end
	return (unit:gsub("(%d+)$", "pet%1"))
end

-- the owner of a pet token ("raidpet5" -> "raid5", "pet" -> "player")
local function ownerToken(unit)
	if unit == "pet" then return "player" end
	local kind, n = unit:match("^(%a-)pet(%d+)$")
	if kind then return kind .. n end
	return unit
end
RLK.ownerToken = ownerToken

-- Can this member provide the variant? true, false, or nil for "cannot tell yet".
local function provides(v, unit)
	if v.pet then
		local pet = petToken(unit)
		if not UnitExists(pet) then return nil end
		local key = famKeyByName[UnitCreatureFamily(pet) or ""]
		if not key then return nil end -- no family, or a client language we do not know
		return key == v.pet
	end
	if v.talentName then
		-- no spec means the talents have not arrived yet
		if not LGT:GetUnitTalentSpec(unit) then return nil end
		return LGT:UnitHasTalent(unit, v.talentName) ~= nil
	end
	return true
end

-- Does this member care about the row's buff? (see "audience" in Data.lua)
local PHYSICAL = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, HUNTER = true }
local CASTER = { MAGE = true, WARLOCK = true, PRIEST = true }

function RLK:Wants(row, unit, class)
	local a = row.audience
	if a == "mana" then
		return UnitPowerType(unit) == 0
	elseif a == "physical" then
		if PHYSICAL[class] then return true end
		if CASTER[class] then return false end
		-- hybrids go by their role; not known yet counts them in
		local role = LGT:GetUnitRole(unit)
		return role == nil or role == "melee" or role == "tank"
	end
	return true
end

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------
RLK.dirty = true

function RLK:MarkDirty()
	self.dirty = true
	if self.OnDirty then self:OnDirty() end
end

-- The group as last read: { unit, name, class, here, covered }. The entries
-- are reused from read to read, so a scan a second makes no garbage.
--   here     false for anyone whose auras cannot be read (out of range,
--            dead, offline); they are left out of the missing counts
--   covered  [row] = true when the member carries any variant of the row
RLK.members = {}
local memberPool = {}

local function readMembers()
	local members = RLK.members
	local units = RLK:GroupUnits()
	for i, unit in ipairs(units) do
		local m = memberPool[i]
		if not m then
			m = { covered = {} }
			memberPool[i] = m
		end
		local _, class = UnitClass(unit)
		m.unit, m.name, m.class = unit, UnitName(unit), class
		members[i] = m
	end
	for i = #units + 1, #members do members[i] = nil end
	return members
end

-- v.state, v.providers (names) and v.unknown (names) for every variant
function RLK:Refresh()
	if not self.dirty then return end
	self.dirty = false

	local members = readMembers()
	for _, s in ipairs(SECTIONS) do
		for _, row in ipairs(s.rows) do
			for _, v in ipairs(row.variants) do
				wipe(v.providers)
				wipe(v.unknown)
				for _, m in ipairs(members) do
					if m.class == v.class then
						local ok = provides(v, m.unit)
						if ok then
							v.providers[#v.providers + 1] = m.name
						elseif ok == nil then
							v.unknown[#v.unknown + 1] = m.name
						end
					end
				end
				v.state = #v.providers > 0 and self.IN_RAID or #v.unknown > 0 and self.UNKNOWN or self.NONE
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- active auras
-- ---------------------------------------------------------------------------
local DEBUFF_UNITS = { "target", "focus", "boss1", "boss2", "boss3", "boss4" }

-- The class behind an aura's caster, pets counting as their owner; nil when
-- the caster cannot be seen (out of range, a totem).
local function casterClass(caster)
	if not caster then return nil end
	local _, class = UnitClass(ownerToken(caster))
	return class
end

-- Does an aura cast by this class belong to the variant? With no caster to
-- go by, every variant whose class is in the group counts.
local function fits(v, class)
	if class then return v.class == class end
	return v.state ~= RLK.NONE
end

-- v.active, and while up: v.holders (member entries carrying a buff),
-- v.expires (soonest end, nil when it does not run out), v.stacks (debuffs);
-- row.active and row.missing; RLK.fighting
function RLK:ScanActive()
	for _, s in ipairs(SECTIONS) do
		for _, row in ipairs(s.rows) do
			for _, v in ipairs(row.variants) do
				v.active, v.expires, v.stacks = false, nil, nil
				wipe(v.holders)
			end
		end
	end

	local buffs = self.variantsByAura.buff
	for _, m in ipairs(readMembers()) do
		local unit = m.unit
		m.here = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)
		wipe(m.covered)
		local i = 1
		while true do
			local name, _, _, _, _, duration, expires, caster = UnitBuff(unit, i)
			if not name then break end
			local list = buffs[name]
			if list then
				local class = casterClass(caster)
				for _, v in ipairs(list) do
					if fits(v, class) then
						v.active = true
						local holders = v.holders
						if holders[#holders] ~= m then holders[#holders + 1] = m end
						if duration and duration > 0 and (not v.expires or expires < v.expires) then
							v.expires = expires
						end
						m.covered[v.row] = true
					end
				end
			end
			i = i + 1
		end
	end

	-- debuffs: the first hostile unit in DEBUFF_UNITS order that carries one wins
	local debuffs = self.variantsByAura.debuff
	for _, unit in ipairs(DEBUFF_UNITS) do
		if UnitExists(unit) and UnitCanAttack("player", unit) then
			local i = 1
			while true do
				local name, _, _, count, _, duration, expires, caster = UnitDebuff(unit, i)
				if not name then break end
				local list = debuffs[name]
				if list then
					local class = casterClass(caster)
					for _, v in ipairs(list) do
						if not v.active and fits(v, class) then
							v.active = true
							v.stacks = count and count > 1 and count or nil
							v.expires = duration and duration > 0 and expires or nil
						end
					end
				end
				i = i + 1
			end
		end
	end

	-- per row: is any variant up, and for counted rows how many still lack it
	for _, s in ipairs(SECTIONS) do
		for _, row in ipairs(s.rows) do
			row.active = false
			for _, v in ipairs(row.variants) do
				if v.active then row.active = true break end
			end
			row.missing = row.count and self:RowMissing(row) or 0
		end
	end

	-- a missing debuff only matters with an enemy to put it on
	self.fighting = UnitAffectingCombat("player") and UnitExists("target")
		and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

-- For a counted row: how many members want the buff but carry no variant of
-- it. With lists = true also those members, and the ones whose auras could
-- not be read (not counted); only a tooltip asks for them.
function RLK:RowMissing(row, lists)
	local n, missing, away = 0, lists and {}, lists and {}
	for _, m in ipairs(self.members) do
		if not m.covered[row] and self:Wants(row, m.unit, m.class) then
			if m.here then
				n = n + 1
				if missing then missing[#missing + 1] = m end
			elseif away then
				away[#away + 1] = m
			end
		end
	end
	return n, missing, away
end
-- ---------------------------------------------------------------------------
-- init + events
-- ---------------------------------------------------------------------------
local function copy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = copy(x) end
	return t
end

function RLK:Init()
	RaidLeadKitDB = RaidLeadKitDB or {}
	RaidLeadKitDB.scale = nil -- replaced by buttonSize / iconSize
	for k, v in pairs(self.defaults) do
		if RaidLeadKitDB[k] == nil then RaidLeadKitDB[k] = copy(v) end
	end
	self.db = RaidLeadKitDB

	for key, names in pairs(self.PET_FAMILIES) do
		for _, n in ipairs(names) do famKeyByName[n] = key end
	end
	SECTIONS = {
		{ rows = self.BUFFS, kind = "buff" },
		{ rows = self.DEBUFFS, kind = "debuff" },
		{ rows = self.TOTEMS, kind = "buff" },
		{ rows = self.PALADIN_BLESSINGS, kind = "buff" },
		{ rows = self.PALADIN_AURAS, kind = "buff" },
	}
	for _, s in ipairs(SECTIONS) do prepare(s.rows, s.kind) end

	local function dirty() RLK:MarkDirty() end
	LGT.RegisterCallback(self, "LibGroupTalents_Update", dirty)
	LGT.RegisterCallback(self, "LibGroupTalents_Remove", dirty)
	LGT.RegisterCallback(self, "LibGroupTalents_RoleChange", dirty)

	self:CreateDisplay()
	-- missing when Config.lua was added to the .toc after the client started:
	-- /reload does not pick up new files, a restart does
	if self.InitConfig then self:InitConfig() end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		RLK:Init()
		self:RegisterEvent("RAID_ROSTER_UPDATE")
		self:RegisterEvent("PARTY_MEMBERS_CHANGED")
		self:RegisterEvent("UNIT_PET")
	end
	RLK:MarkDirty()
end)
