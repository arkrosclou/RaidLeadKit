--[[ RaidLeadKit - the button and the panel it opens on a click.

	Panel: the buffs, then the debuffs, in columns of as many rows as the
	options say; below them the shaman totems, paladin blessings and paladin
	auras, one line each. One icon per variant; row names live in the icon
	tooltips, and with Ctrl held an icon shows the game's own tooltip of the
	talent or spell instead.

	Icon states. Quiet is fine or out of reach; only what can be fixed stands
	out:
	  colour                          up, and on everyone who wants it
	  colour, yellow border           up, but some who want it lack it; the
	                                  corner says how many
	  colour, red border              not up, though someone here can provide
	                                  it (in a fight only, for a debuff - with
	                                  an enemy targeted - or a buff that comes
	                                  from a proc or a cooldown)
	  faded                           another variant of the row is up, so
	                                  this one would add nothing
	  black and white                 nobody here can provide it
	  black and white, "?"            someone of the class is here, but their
	                                  talents or pet are not known yet

	Icon text: time left at the top (when it runs out); bottom right how many
	lack the buff (yellow), the stacks of a debuff (white), or "?". ]]

local RLK = RaidLeadKit

local FLAT = "Interface\\Buttons\\WHITE8X8"
-- the Emblem of Conquest icon
local BUTTON_ICON = "Interface\\Icons\\Spell_Holy_ChampionsGrace"
-- icon cell: the icon (its size from the options) 2px inside, the rest is
-- the border; set again by RLK:LayoutPanel. Text keeps its size.
local CELL = 28
local GAP = 2
local PAD = 6
local COL_GAP = 8
local GROUP_GAP = 8       -- between the totem elements on their line
local LINE_LABEL = 58     -- "Totems" / "Blessings" / "Auras" in front of the bottom lines
local SCAN_EVERY = 1

local RED    = { 0.95, 0.15, 0.15 }
local YELLOW = { 1, 0.82, 0 }
local GREEN  = { 0.3, 1, 0.3 }
local FADED  = 0.3 -- alpha of a variant made needless by another one in its row

local LGT = LibStub("LibGroupTalents-1.0")

-- ---------------------------------------------------------------------------
-- text helpers
-- ---------------------------------------------------------------------------
local hexCache = {}
local function classHex(class)
	local hex = hexCache[class or ""]
	if hex then return hex end
	local c = RAID_CLASS_COLORS[class]
	hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
		or "|cffffffff"
	hexCache[class or ""] = hex
	return hex
end

-- names, each in its class colour; entries are member tables or plain names.
-- With limit, the rest is summed up as "+N more".
local function nameList(list, class, limit)
	local out = {}
	for i, e in ipairs(list) do
		if limit and i > limit then
			out[#out + 1] = string.format("|cff999999+%d more|r", #list - limit)
			break
		end
		if type(e) == "table" then
			out[i] = classHex(e.class) .. e.name .. "|r"
		else
			out[i] = classHex(class) .. e .. "|r"
		end
	end
	return table.concat(out, ", ")
end

local function timeText(left)
	if left >= 3600 then return string.format("%dh", math.floor(left / 3600)) end
	if left >= 60 then return string.format("%dm", math.floor(left / 60)) end
	return string.format("%d", math.max(left, 0))
end

-- one number per distinct text timeText can give, so a timer is only turned
-- into a string when what it shows changes (once a minute for a long buff)
local function timeKey(left)
	if left >= 3600 then return 100000 + math.floor(left / 3600) end
	if left >= 60 then return 1000 + math.floor(left / 60) end
	return math.max(math.floor(left), 0)
end

-- ---------------------------------------------------------------------------
-- tooltip
-- ---------------------------------------------------------------------------
local function showTooltip(cell)
	local v = cell.variant
	local row = v.row
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")

	-- Ctrl held: the game's own tooltip, of the talent if one is needed,
	-- otherwise of the spell
	if IsControlKeyDown() then
		GameTooltip:SetHyperlink("spell:" .. (v.talent or v.spellId))
		GameTooltip:Show()
		return
	end

	GameTooltip:AddLine(row.name)
	local c = RAID_CLASS_COLORS[v.class]
	local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[v.class] or v.class
	GameTooltip:AddDoubleLine(v.name, className, 1, 1, 1, c and c.r or 1, c and c.g or 1, c and c.b or 1)
	if v.talentName then
		GameTooltip:AddLine("talent: " .. v.talentName, 0.7, 0.7, 0.7)
	elseif v.pet then
		GameTooltip:AddLine("pet: " .. RLK.PET_FAMILIES[v.pet][1], 0.7, 0.7, 0.7)
	end

	-- what is up
	GameTooltip:AddLine(" ")
	if v.active then
		local line = "Active"
		if v.stacks then line = line .. string.format(", %d stacks", v.stacks) end
		if v.expires then line = line .. ", " .. timeText(v.expires - GetTime()) .. " left" end
		GameTooltip:AddLine(line, GREEN[1], GREEN[2], GREEN[3])
	elseif row.active then
		local by = {}
		for _, o in ipairs(row.variants) do
			if o.active then by[#by + 1] = o.name end
		end
		GameTooltip:AddLine("Covered by " .. table.concat(by, ", "), 0.6, 0.6, 0.6)
	elseif v.state == RLK.IN_RAID then
		GameTooltip:AddLine("Not up", RED[1], RED[2], RED[3])
	end
	-- who carries it, for buffs that are not counted (Vigilance, Inspiration,
	-- the raid-wide auras); a long list is cut short
	if not row.count and row.kind == "buff" and v.active and #v.holders > 0 then
		GameTooltip:AddLine(string.format("On (%d): %s", #v.holders, nameList(v.holders, nil, 10)), 1, 1, 1, true)
	end
	if row.count then
		GameTooltip:AddLine(" ")
		if #v.holders > 0 then
			GameTooltip:AddLine(string.format("Buffed (%d): %s", #v.holders, nameList(v.holders)), 1, 1, 1, true)
		end
		local _, missing, away = RLK:RowMissing(row, true)
		if #missing > 0 then
			GameTooltip:AddLine(string.format("Missing (%d): %s", #missing, nameList(missing)), 1, 0.3, 0.3, true)
		else
			GameTooltip:AddLine("Nobody is missing it", 0.3, 1, 0.3)
		end
		if #away > 0 then
			GameTooltip:AddLine(string.format("Can't see (%d): %s", #away, nameList(away)), 0.5, 0.5, 0.5, true)
		end
	end

	-- who could provide it
	GameTooltip:AddLine(" ")
	if #v.providers > 0 then
		GameTooltip:AddLine("Can provide: " .. nameList(v.providers, v.class), 1, 1, 1, true)
	end
	if #v.unknown > 0 then
		local why = v.pet and "pet unknown: " or "talents unknown: "
		GameTooltip:AddLine(why .. nameList(v.unknown, v.class), 0.7, 0.7, 0.7, true)
	end
	if #v.providers == 0 and #v.unknown == 0 then
		GameTooltip:AddLine("Nobody in the group", 0.5, 0.5, 0.5)
	end
	GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- cells
-- ---------------------------------------------------------------------------
local function createCell(parent, v)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetBackdrop({ bgFile = FLAT })
	cell:SetBackdropColor(0, 0, 0, 0)
	cell:EnableMouse(true)
	cell:SetScript("OnEnter", showTooltip)
	cell:SetScript("OnLeave", function() GameTooltip:Hide() end)

	cell.tex = cell:CreateTexture(nil, "ARTWORK")
	cell.tex:SetPoint("TOPLEFT", 2, -2)
	cell.tex:SetPoint("BOTTOMRIGHT", -2, 2)
	cell.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	cell.tex:SetTexture(v.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

	cell.time = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	cell.time:SetPoint("TOP", 0, -1)
	cell.count = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	cell.count:SetPoint("BOTTOMRIGHT", 0, 1)

	cell.variant = v
	return cell
end

-- colour or black and white; the vertex colour is the fallback where the
-- client cannot desaturate
local function setGrey(tex, grey)
	local ok = tex:SetDesaturated(grey)
	if grey then
		if not ok then tex:SetVertexColor(0.4, 0.4, 0.4) end
		tex:SetAlpha(0.6)
	else
		tex:SetVertexColor(1, 1, 1)
		tex:SetAlpha(1)
	end
end

-- sets a font string only when its text changes
local function setText(fs, text, r, g, b)
	if fs.cText ~= text then
		fs.cText = text
		fs:SetText(text)
	end
	if r and fs.cR ~= r then
		fs.cR = r
		fs:SetTextColor(r, g, b)
	end
end

-- one of: "ok", "partial", "missing", "faded", "none", "unknown"
local function lookOf(v)
	local row = v.row
	if v.active then
		return (row.count and row.missing > 0) and "partial" or "ok"
	end
	if row.active then return "faded" end
	if v.state == RLK.IN_RAID then
		-- Never "missing": a situational pick; a proc or cooldown buff out of
		-- combat; a debuff without an enemy to put it on.
		if v.optional
			or (v.combat and not RLK.inCombat)
			or (row.kind == "debuff" and not RLK.fighting) then
			return "ok"
		end
		return "missing"
	end
	return v.state == RLK.UNKNOWN and "unknown" or "none"
end

local BORDERS = { partial = YELLOW, missing = RED }

local function drawCell(cell)
	local v = cell.variant
	local look = lookOf(v)
	if cell.look ~= look then
		cell.look = look
		setGrey(cell.tex, look == "none" or look == "unknown"
			or (look == "faded" and v.state ~= RLK.IN_RAID))
		if look == "faded" then cell.tex:SetAlpha(FADED) end
		local border = BORDERS[look]
		if border then
			cell:SetBackdropColor(border[1], border[2], border[3], 1)
		else
			cell:SetBackdropColor(0, 0, 0, 0)
		end
	end

	local left = v.active and v.expires and v.expires - GetTime()
	local tk = left and timeKey(left) or false
	if cell.cTimeKey ~= tk then
		cell.cTimeKey = tk
		setText(cell.time, left and timeText(left) or "")
	end

	-- the corner: how many lack it, the stacks, or "?"; compared as a number
	-- first so an unchanged count makes no new string
	local n, r, g, b
	if look == "partial" then
		n, r, g, b = v.row.missing, YELLOW[1], YELLOW[2], YELLOW[3]
	elseif v.active and v.stacks then
		n, r, g, b = v.stacks, 1, 1, 1
	elseif look == "unknown" then
		n, r, g, b = -1, 0.8, 0.8, 0.8
	else
		n = false
	end
	if cell.cCount ~= n then
		cell.cCount = n
		setText(cell.count, n == -1 and "?" or n and tostring(n) or "", r, g, b)
	end
end

-- ---------------------------------------------------------------------------
-- panel
-- ---------------------------------------------------------------------------
local function rowFrame(panel, row)
	local r = CreateFrame("Frame", nil, panel)

	-- faint stripe on every other row, to follow a row by eye
	r.bg = r:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints()
	r.bg:SetTexture(1, 1, 1, 0.04)
	r.data = row
	r.cells = {}
	for i, v in ipairs(row.variants) do
		r.cells[i] = createCell(r, v)
	end
	return r
end

-- sizes and places the icons of a row for the current CELL
local function sizeRow(r)
	r:SetHeight(CELL)
	for i, cell in ipairs(r.cells) do
		cell:SetWidth(CELL)
		cell:SetHeight(CELL)
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", (i - 1) * (CELL + GAP), 0)
	end
	r.width = #r.cells * (CELL + GAP) - GAP
end

-- a section: buffs or debuffs, cut into columns at layout time
local function buildSection(panel, rows, title)
	local section = { rows = {} }
	section.label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	section.label:SetText(title)
	for _, row in ipairs(rows) do section.rows[#section.rows + 1] = rowFrame(panel, row) end
	return section
end

-- a bottom line: several rows side by side, behind a label
local function buildLine(panel, rows, title)
	local line = { rows = {} }
	line.label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.label:SetText(title)
	for _, row in ipairs(rows) do line.rows[#line.rows + 1] = rowFrame(panel, row) end
	return line
end

-- The section's shown rows, top to bottom, then on into the next column
-- every perColumn rows. Each column is as wide as its widest row. Returns
-- the x after the section and the most rows in one of its columns.
local function layoutSection(section, x, top, perColumn)
	local shown = {}
	for _, r in ipairs(section.rows) do
		if r.data.minor and not RLK.db.showMinor then r:Hide() else shown[#shown + 1] = r end
	end
	if #shown == 0 then
		section.label:Hide()
		return x, 0
	end
	section.label:ClearAllPoints()
	section.label:SetPoint("BOTTOMLEFT", RLK.panel, "TOPLEFT", x, top + 2)
	section.label:Show()

	local tallest = 0
	for first = 1, #shown, perColumn do
		local last = math.min(first + perColumn - 1, #shown)
		local width = 0
		for i = first, last do width = math.max(width, shown[i].width) end
		for i = first, last do
			local r, n = shown[i], i - first
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", x, top - n * (CELL + GAP))
			r:SetWidth(width)
			if n % 2 == 1 then r.bg:Show() else r.bg:Hide() end
			r:Show()
		end
		tallest = math.max(tallest, last - first + 1)
		x = x + width + COL_GAP
	end
	return x, tallest
end

local function layoutLine(line, y)
	line.label:ClearAllPoints()
	line.label:SetPoint("LEFT", RLK.panel, "TOPLEFT", PAD, y - CELL / 2)
	local x = PAD + LINE_LABEL
	for _, r in ipairs(line.rows) do
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", x, y)
		r:SetWidth(r.width)
		r.bg:Hide()
		r:Show()
		x = x + r.width + GROUP_GAP
	end
	return x - GROUP_GAP + PAD
end

local eachRow

function RLK:LayoutPanel()
	local p = self.panel
	CELL = self.db.iconSize + 4
	eachRow(p, sizeRow)
	local top = -PAD - 14 -- under the section labels
	local x, rows = PAD, 0
	for _, section in ipairs(p.sections) do
		local tallest
		x, tallest = layoutSection(section, x, top, self.db.rows)
		rows = math.max(rows, tallest)
	end
	-- wide enough for the talent status next to the labels
	local width = math.max(x - COL_GAP + PAD, 200)

	local y = top - rows * (CELL + GAP) - PAD
	for _, line in ipairs(p.lines) do
		width = math.max(width, layoutLine(line, y))
		y = y - (CELL + GAP)
	end
	p:SetWidth(width)
	p:SetHeight(-y + PAD - GAP)
end

-- Where the panel opens against the button: panel point, button point, x, y.
-- "auto" picks the side away from the screen edges.
RLK.ANCHORS = {
	{ key = "auto",      label = "Automatic (away from the screen edges)" },
	{ key = "below",     label = "Below, growing right",  "TOPLEFT",     "BOTTOMLEFT",  0, -2 },
	{ key = "belowLeft", label = "Below, growing left",   "TOPRIGHT",    "BOTTOMRIGHT", 0, -2 },
	{ key = "above",     label = "Above, growing right",  "BOTTOMLEFT",  "TOPLEFT",     0, 2 },
	{ key = "aboveLeft", label = "Above, growing left",   "BOTTOMRIGHT", "TOPRIGHT",    0, 2 },
	{ key = "right",     label = "To the right",          "TOPLEFT",     "TOPRIGHT",    2, 0 },
	{ key = "left",      label = "To the left",           "TOPRIGHT",    "TOPLEFT",     -2, 0 },
}

local function anchorPanel(button, panel)
	local a
	for _, x in ipairs(RLK.ANCHORS) do
		if x.key == RLK.db.anchor then a = x end
	end
	panel:ClearAllPoints()
	if a and a[1] then
		panel:SetPoint(a[1], button, a[2], a[3], a[4])
		return
	end
	-- auto
	local x, y = button:GetCenter()
	local right = x and x > UIParent:GetWidth() / 2
	local up = y and y < UIParent:GetHeight() / 2
	local h = right and "RIGHT" or "LEFT"
	panel:SetPoint((up and "BOTTOM" or "TOP") .. h, button, (up and "TOP" or "BOTTOM") .. h, 0, up and 2 or -2)
end

-- after a change in the options
function RLK:ApplySettings()
	local db, b, p = self.db, self.button, self.panel
	b:SetWidth(db.buttonSize)
	b:SetHeight(db.buttonSize)
	if db.hidden then
		b:Hide()
		p:Hide()
	else
		b:Show()
	end
	self:LayoutPanel()
	if p:IsShown() then
		anchorPanel(b, p)
		self:UpdatePanel()
	end
end

function eachRow(p, fn)
	for _, section in ipairs(p.sections) do
		for _, r in ipairs(section.rows) do fn(r) end
	end
	for _, line in ipairs(p.lines) do
		for _, r in ipairs(line.rows) do fn(r) end
	end
end

-- an open tooltip of one of our icons is built again (new scan, Ctrl)
function RLK:RefreshTooltip()
	local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
	if owner and owner.variant and owner:GetParent() and owner:GetParent():GetParent() == self.panel then
		owner:GetScript("OnEnter")(owner)
	end
end

local function drawRow(r)
	if r:IsShown() then
		for _, cell in ipairs(r.cells) do drawCell(cell) end
	end
end

function RLK:UpdatePanel()
	local p = self.panel
	self:Refresh()
	self:ScanActive()
	eachRow(p, drawRow)
	self:RefreshTooltip()
	local got, missing = LGT:GetTalentCount()
	if missing and missing > 0 then
		p.status:SetFormattedText("talents: %d/%d", got or 0, (got or 0) + missing)
	else
		p.status:SetText("")
	end
end

function RLK:CreateDisplay()
	local db = self.db

	-- the button
	local b = CreateFrame("Button", "RaidLeadKitButton", UIParent)

	-- LOW: the game's own windows (character, bags, spellbook) open over it
	b:SetFrameStrata("LOW")
	b:SetClampedToScreen(true)
	b:SetMovable(true)
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(s)
		if not RLK.db.locked then
			RLK.panel:Hide()
			s:StartMoving()
		end
	end)
	b:SetScript("OnDragStop", function(s)
		s:StopMovingOrSizing()
		local pt, _, rp, x, y = s:GetPoint()
		RLK.db.point = { pt, rp, x, y }
	end)
	-- the icon fills the whole button: an inset over a black backdrop showed
	-- as a dark strip wherever the UI scale rounded the inset to 2px
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetTexture(BUTTON_ICON)
	b:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
	self.button = b

	-- the panel
	local p = CreateFrame("Frame", "RaidLeadKitPanel", UIParent)
	p:SetFrameStrata("LOW")
	p:SetClampedToScreen(true)
	p:EnableMouse(true)
	p:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
	p:SetBackdropColor(0.04, 0.04, 0.05, 0.92)
	p:SetBackdropBorderColor(0, 0, 0, 1)
	p:Hide()
	self.panel = p

	-- no title: the talent status shares the line of the section labels
	p.status = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	p.status:SetPoint("TOPRIGHT", -PAD, -PAD - 1)

	p.sections = {
		buildSection(p, self.BUFFS, "Buffs"),
		buildSection(p, self.DEBUFFS, "Debuffs"),
	}
	p.lines = {
		buildLine(p, self.TOTEMS, "Totems"),
		buildLine(p, self.PALADIN_BLESSINGS, "Blessings"),
		buildLine(p, self.PALADIN_AURAS, "Auras"),
	}
	self:LayoutPanel()

	-- a left click opens and closes the panel, Escape closes it too; a right
	-- click opens the options. While open, the active auras are scanned once
	-- a second.
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			if RLK.OpenOptions then RLK:OpenOptions() end
		else
			RLK:TogglePanel()
		end
	end)
	tinsert(UISpecialFrames, p:GetName())
	-- Ctrl pressed or let go over an icon swaps the tooltip at once
	p:SetScript("OnEvent", function() RLK:RefreshTooltip() end)
	p:RegisterEvent("MODIFIER_STATE_CHANGED")
	local sinceScan = 0
	p:SetScript("OnShow", function()
		sinceScan = 0
		RLK:UpdatePanel()
	end)
	p:SetScript("OnUpdate", function(s, dt)
		sinceScan = sinceScan + dt
		if sinceScan >= SCAN_EVERY or RLK.updateSoon then
			RLK.updateSoon = false
			sinceScan = 0
			RLK:UpdatePanel()
		end
	end)

	self:ApplySettings()
end

-- the button, the key binding and /rlk toggle all come here
function RLK:TogglePanel()
	local p = self.panel
	if p:IsShown() then
		p:Hide()
	else
		anchorPanel(self.button, p)
		p:Show()
	end
end

-- A roster or talent change while the panel is open shows up on the next
-- frame; a burst of roster events costs one update.
function RLK:OnDirty()
	self.updateSoon = true
end
