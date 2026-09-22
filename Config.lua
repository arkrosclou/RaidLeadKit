--[[ RaidLeadKit - slash commands + Interface Options panel ]]

local RLK = RaidLeadKit

function RLK:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(self.options)
	InterfaceOptionsFrame_OpenToCategory(self.options) -- the first call only opens the frame
end

function RLK:ResetPosition()
	self.db.point = { "CENTER", "CENTER", 0, 200 }
	self.button:ClearAllPoints()
	self.button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
end

-- ---------------------------------------------------------------------------
-- slash
-- ---------------------------------------------------------------------------
SLASH_RAIDLEADKIT1 = "/rlk"
SLASH_RAIDLEADKIT2 = "/raidleadkit"
SlashCmdList["RAIDLEADKIT"] = function(msg)
	local cmd = string.lower(strtrim(msg or ""))
	local db = RLK.db
	if cmd == "" or cmd == "config" then
		RLK:OpenOptions()
	elseif cmd == "minor" then
		db.showMinor = not db.showMinor
		RLK:ApplySettings()
		RLK:Print("minor debuffs " .. (db.showMinor and "shown" or "hidden"))
	elseif cmd == "lock" then
		db.locked = not db.locked
		RLK:Print("button " .. (db.locked and "locked" or "unlocked"))
	elseif cmd == "show" or cmd == "hide" then
		db.hidden = cmd == "hide"
		RLK:ApplySettings()
	elseif cmd == "toggle" then
		RLK:TogglePanel()
	elseif cmd == "loot" then
		db.lootWarning = not db.lootWarning
		RLK:Print("master loot warning " .. (db.lootWarning and "on" or "off"))
	elseif cmd == "loottest" then
		RLK:WarnLoot(true)
	elseif cmd == "reset" then
		RLK:ResetPosition()
		db.hidden = false
		RLK:ApplySettings()
	else
		RLK:Print("commands: config | toggle | minor | lock | show | hide | reset | loot | loottest")
	end
	if RLK.RefreshOptions then RLK:RefreshOptions() end
end

-- ---------------------------------------------------------------------------
-- options panel
-- ---------------------------------------------------------------------------
-- One column, every widget placed below the previous one by a running y.
local PAD = 16

local widgetCount = 0
local function uniqueName(kind)
	widgetCount = widgetCount + 1
	return "RaidLeadKit" .. kind .. widgetCount
end

local function header(parent, y, text)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", PAD, y)
	fs:SetText(text)
	return y - 22
end

local function check(parent, y, label, get, set)
	local cb = CreateFrame("CheckButton", uniqueName("Check"), parent, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", PAD - 4, y)
	_G[cb:GetName() .. "Text"]:SetText(label)
	cb:SetScript("OnClick", function(s) set(s:GetChecked() and true or false) end)
	cb.get = get
	return cb, y - 26
end

function RLK:InitConfig()
	local db = self.db
	local options = CreateFrame("Frame", "RaidLeadKitOptions", UIParent)
	options.name = "|cffff2020Raid|rLeadKit"
	self.options = options

	-- everything sits in a scroll frame: the options area is not tall enough
	-- for all of it
	local scroll = CreateFrame("ScrollFrame", "RaidLeadKitOptionsScroll", options, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)
	local panel = CreateFrame("Frame", nil, scroll)
	panel:SetWidth(420)
	panel:SetHeight(1)
	scroll:SetScrollChild(panel)

	local checks, radios = {}, {}

	local y = -PAD
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", PAD, y)
	title:SetText("|cffff2020Raid|rLeadKit")
	y = y - 22
	local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", PAD, y)
	note:SetText("Left-click the button for the checklist, right-click for these options, drag to move it.")
	y = y - 24

	-- 1. button and panel
	y = header(panel, y, "Button")
	local cb
	cb, y = check(panel, y, "Show the button", function() return not db.hidden end,
		function(v) db.hidden = not v self:ApplySettings() end)
	checks[#checks + 1] = cb
	cb, y = check(panel, y, "Lock the button in place", function() return db.locked end,
		function(v) db.locked = v end)
	checks[#checks + 1] = cb
	cb, y = check(panel, y, "Show minor debuffs (cast speed, melee hit, healing, judgements)",
		function() return db.showMinor end, function(v) db.showMinor = v self:ApplySettings() end)
	checks[#checks + 1] = cb

	-- Two keys can open the checklist, like any action in Esc > Key Bindings
	-- (where the same two show): click a button, then press a key or a
	-- combination; right-click clears it. Two, because the game names a key by
	-- the character it types: one key is "]" in one layout and "ї" in another.
	local BINDING = "RAIDLEADKIT_TOGGLE"
	local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
	local keyButtons = {}

	local function keyOf(slot)
		return (select(slot, GetBindingKey(BINDING)))
	end
	-- Puts key (nil clears) in a slot. The game keeps an action's keys in the
	-- order they were bound, so all of them are bound again in slot order.
	local function setSlot(slot, key)
		local keys = { GetBindingKey(BINDING) }
		for _, k in ipairs(keys) do SetBinding(k) end
		keys[slot] = key
		for i = 1, 2 do
			if keys[i] and (i == slot or keys[i] ~= key) then SetBinding(keys[i], BINDING) end
		end
		SaveBindings(GetCurrentBindingSet())
	end
	local function refreshKeys()
		for slot, b in ipairs(keyButtons) do
			local key = keyOf(slot)
			b:SetText("Key " .. slot .. ": " .. (key and GetBindingText(key, "KEY_") or "not set"))
		end
	end

	for slot = 1, 2 do
		local b = CreateFrame("Button", uniqueName("Key"), panel, "UIPanelButtonTemplate")
		b:SetPoint("TOPLEFT", PAD + (slot - 1) * 190, y - 2)
		b:SetWidth(180)
		b:SetHeight(22)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(s, mouse)
			if InCombatLockdown() then
				self:Print("key bindings cannot change in combat")
				return
			end
			if mouse == "RightButton" then
				setSlot(slot, nil)
				refreshKeys()
				return
			end
			s.waiting = true
			s:SetText("Press a key (Esc cancels)")
			s:EnableKeyboard(true)
		end)
		b:SetScript("OnKeyDown", function(s, key)
			if not s.waiting or MODIFIERS[key] then return end
			s.waiting = false
			s:EnableKeyboard(false)
			if key ~= "ESCAPE" then
				local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
					.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
				local before = GetBindingAction(combo)
				setSlot(slot, combo)
				local was = (before and before ~= "" and before ~= BINDING)
					and (" (it was " .. (_G["BINDING_NAME_" .. before] or before) .. ")") or ""
				self:Print("checklist key " .. slot .. ": " .. GetBindingText(combo, "KEY_") .. was)
			end
			refreshKeys()
		end)
		b:SetScript("OnHide", function(s)
			s.waiting = false
			s:EnableKeyboard(false)
		end)
		keyButtons[slot] = b
	end
	local keyNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	keyNote:SetPoint("TOPLEFT", PAD, y - 28)
	keyNote:SetText("Keys that open the checklist; right-click a button to clear it.")
	y = y - 46
	y = header(panel, y - 4, "Raid leader")
	cb, y = check(panel, y, "Warn me on a boss pull when master loot is not set",
		function() return db.lootWarning end, function(v) db.lootWarning = v end)
	checks[#checks + 1] = cb
	local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	test:SetPoint("TOPLEFT", PAD + 24, y)
	test:SetWidth(120)
	test:SetHeight(20)
	test:SetText("Test the warning")
	test:SetScript("OnClick", function() self:WarnLoot(true) end)
	y = y - 26

	-- sliders: label above, value in the label, applied as it moves
	local sliders = {}
	local function slider(label, minV, maxV, step, lowText, highText, show, get, set)
		y = y - 18
		local s = CreateFrame("Slider", uniqueName("Slider"), panel, "OptionsSliderTemplate")
		local name = s:GetName()
		s:SetPoint("TOPLEFT", PAD + 4, y)
		s:SetWidth(220)
		s:SetMinMaxValues(minV, maxV)
		s:SetValueStep(step)
		_G[name .. "Low"]:SetText(lowText)
		_G[name .. "High"]:SetText(highText)
		s:SetScript("OnValueChanged", function(_, v)
			v = math.floor(v / step + 0.5) * step
			_G[name .. "Text"]:SetText(label .. ": " .. show(v))
			if get() ~= v then set(v) end
		end)
		s.refresh = function()
			s:SetValue(get())
			_G[name .. "Text"]:SetText(label .. ": " .. show(get()))
		end
		sliders[#sliders + 1] = s
		y = y - 40
	end
	local px = function(v) return v .. " px" end
	slider("Button size", 16, 64, 1, "16", "64", px,
		function() return db.buttonSize end,
		function(v) db.buttonSize = v self:ApplySettings() end)
	slider("Icon size", 12, 48, 1, "12", "48", px,
		function() return db.iconSize end,
		function(v) db.iconSize = v self:ApplySettings() end)
	slider("Rows per column", 4, 30, 1, "4", "30", tostring,
		function() return db.rows end,
		function(v) db.rows = v self:ApplySettings() end)

	-- 2. where the panel opens
	y = header(panel, y, "The checklist opens")
	for _, a in ipairs(self.ANCHORS) do
		local r = CreateFrame("CheckButton", uniqueName("Radio"), panel, "UIRadioButtonTemplate")
		r:SetPoint("TOPLEFT", PAD, y)
		_G[r:GetName() .. "Text"]:SetText(a.label)
		r.key = a.key
		r:SetScript("OnClick", function()
			db.anchor = a.key
			self:RefreshOptions()
			self:ApplySettings()
		end)
		radios[#radios + 1] = r
		y = y - 20
	end

	y = y - 12
	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetPoint("TOPLEFT", PAD, y)
	reset:SetWidth(160)
	reset:SetHeight(22)
	reset:SetText("Reset button position")
	reset:SetScript("OnClick", function() self:ResetPosition() end)
	y = y - 22
	panel:SetHeight(-y + PAD)

	function self:RefreshOptions()
		for _, c in ipairs(checks) do c:SetChecked(c.get()) end
		for _, r in ipairs(radios) do r:SetChecked(r.key == db.anchor) end
		for _, s in ipairs(sliders) do s.refresh() end
		refreshKeys()
	end
	options:SetScript("OnShow", function() self:RefreshOptions() end)
	InterfaceOptions_AddCategory(options)
end
