--[[ RaidLeadKit - the checklist itself.

	One row per raid effect. The variants in a row are the interchangeable ways
	to get it (they do not stack), most common spec first.

	A variant is "in the raid" when someone has:
	  class   the class, always required
	  talent  this talent (spell id; its localized name is asked of
	          LibGroupTalents), when the effect comes from a talent
	  pet     a pet of this family (see PET_FAMILIES), when a pet provides it
	It is "active" when one of its auras is up - buffs on any raid member,
	debuffs on the target or a boss - cast by a player who fits the variant.

	Row flags:
	  count     a buff cast on people rather than an aura: the icon shows how
	            many still lack it, the tooltip who has it and who does not
	  audience  who the count is about: "mana" (mana users) or "physical"
	            (melee, tanks, hunters); everyone when not set
	  minor     hidden unless turned on
	Variant flag:
	  optional  a situational pick (resistances, Grounding, Crusader Aura):
	            never flagged as missing

	All ids were checked against the WotLK spell database. Auras are matched by
	name, so one id covers every rank. ]]

RaidLeadKit = RaidLeadKit or {}
local RLK = RaidLeadKit

-- UnitCreatureFamily returns a localized name: enUS and ruRU are known,
-- other clients leave pet variants as "unknown".
RLK.PET_FAMILIES = {
	IMP       = { "Imp", "Бес" },
	FELHUNTER = { "Felhunter", "Охотник Скверны" },
	WORM      = { "Worm", "Червь" },
	WASP      = { "Wasp", "Оса" },
	RHINO     = { "Rhino", "Люторог" },
	BAT       = { "Bat", "Летучая мышь" },
	COREHOUND = { "Core Hound", "Гончая Недр" },
}

RLK.BUFFS = {
	{ name = "Stats +10%", count = true, variants = {
		{ spell = 20217, class = "PALADIN", auras = { 20217, 25898 } },               -- Blessing of Kings
		{ spell = 20911, class = "PALADIN", talent = 20911, auras = { 20911, 25899 } }, -- Blessing of Sanctuary
	}},
	{ name = "Stats", count = true, variants = {
		{ spell = 48469, class = "DRUID", auras = { 48469, 48470 } },                  -- Mark / Gift of the Wild
	}},
	{ name = "Stamina", count = true, variants = {
		{ spell = 48161, class = "PRIEST", auras = { 48161, 48162 } },                 -- Power Word / Prayer of Fortitude
	}},
	{ name = "Health", count = true, variants = {
		{ spell = 47440, class = "WARRIOR", auras = { 47440 } },                       -- Commanding Shout
		{ spell = 47982, class = "WARLOCK", pet = "IMP", auras = { 47982 } },          -- Blood Pact
	}},
	{ name = "Intellect", count = true, audience = "mana", variants = {
		{ spell = 42995, class = "MAGE", auras = { 42995, 43002, 61024, 61316 } },     -- Arcane / Dalaran Intellect, Brilliance
		{ spell = 57567, class = "WARLOCK", pet = "FELHUNTER", auras = { 57567 } },    -- Fel Intelligence
	}},
	{ name = "Spirit", count = true, audience = "mana", variants = {
		{ spell = 48073, class = "PRIEST", talent = 14752, auras = { 48073, 48074 } }, -- Divine Spirit / Prayer of Spirit
		{ spell = 57567, class = "WARLOCK", pet = "FELHUNTER", auras = { 57567 } },    -- Fel Intelligence
	}},
	{ name = "Attack Power", count = true, audience = "physical", variants = {
		{ spell = 48932, class = "PALADIN", auras = { 48932, 48934 } },                -- Blessing of Might
		{ spell = 47436, class = "WARRIOR", auras = { 47436 } },                       -- Battle Shout
	}},
	{ name = "Attack Power +10%", variants = {
		{ spell = 53137, class = "DEATHKNIGHT", talent = 53137, auras = { 53137 } },   -- Abomination's Might
		{ spell = 30802, class = "SHAMAN", talent = 30802, auras = { 30809 } },        -- Unleashed Rage
		{ spell = 19506, class = "HUNTER", talent = 19506, auras = { 19506 } },        -- Trueshot Aura
	}},
	{ name = "Strength & Agility", count = true, audience = "physical", variants = {
		{ spell = 57623, class = "DEATHKNIGHT", auras = { 57623 } },                   -- Horn of Winter
		{ spell = 58643, class = "SHAMAN", auras = { 58646 } },                        -- Strength of Earth Totem
	}},
	{ name = "Melee Haste +20%", variants = {
		{ spell = 55610, class = "DEATHKNIGHT", talent = 55610, auras = { 55610 } },   -- Improved Icy Talons
		{ spell = 8512, class = "SHAMAN", auras = { 8515 } },                          -- Windfury Totem
	}},
	{ name = "Spell Haste +5%", variants = {
		{ spell = 3738, class = "SHAMAN", auras = { 2895 } },                          -- Wrath of Air Totem
	}},
	{ name = "Haste +3%", variants = {
		{ spell = 53379, class = "PALADIN", talent = 53379, auras = { 53379 } },       -- Swift Retribution
		{ spell = 48384, class = "DRUID", talent = 48384, auras = { 50170 } },         -- Improved Moonkin Form
	}},
	{ name = "Melee Crit +5%", variants = {
		{ spell = 17007, class = "DRUID", talent = 17007, auras = { 24932 } },         -- Leader of the Pack
		{ spell = 29801, class = "WARRIOR", talent = 29801, auras = { 29801 } },       -- Rampage
	}},
	{ name = "Spell Crit +5%", variants = {
		{ spell = 24907, class = "DRUID", talent = 24858, auras = { 24907 } },         -- Moonkin Aura
		{ spell = 51466, class = "SHAMAN", talent = 51466, auras = { 51470 } },        -- Elemental Oath
	}},
	{ name = "Spell Power", variants = {
		{ spell = 47236, class = "WARLOCK", talent = 47236, auras = { 48090 } },       -- Demonic Pact
		{ spell = 57722, class = "SHAMAN", talent = 30706, auras = { 57658 } },        -- Totem of Wrath
		{ spell = 58656, class = "SHAMAN", auras = { 58656 } },                        -- Flametongue Totem
	}},
	{ name = "Damage +3%", variants = {
		{ spell = 31869, class = "PALADIN", talent = 31869, auras = { 31869 } },       -- Sanctified Retribution
		{ spell = 31579, class = "MAGE", talent = 31579, auras = { 31583 } },          -- Arcane Empowerment
		{ spell = 34455, class = "HUNTER", talent = 34455, auras = { 75447 } },        -- Ferocious Inspiration
	}},
	{ name = "Damage Taken -3%", variants = {
		{ spell = 20911, class = "PALADIN", talent = 20911, auras = { 20911, 25899 } }, -- Blessing of Sanctuary
		{ spell = 57470, class = "PRIEST", talent = 57470, auras = { 63944 } },        -- Renewed Hope
		{ spell = 50720, class = "WARRIOR", talent = 50720, auras = { 50720 } },       -- Vigilance
	}},
	{ name = "Healing Received +6%", variants = {
		{ spell = 20138, class = "PALADIN", talent = 20138, auras = { 63514 } },       -- Improved Devotion Aura
		{ spell = 33891, class = "DRUID", talent = 33891, auras = { 34123 } },         -- Tree of Life
	}},
	{ name = "Armor +25% (after a crit heal)", variants = {
		{ spell = 14892, class = "PRIEST", talent = 14892, auras = { 15363 } },        -- Inspiration
		{ spell = 16176, class = "SHAMAN", talent = 16176, auras = { 16237 } },        -- Ancestral Healing -> Ancestral Fortitude
	}},
	{ name = "Armor", variants = {
		{ spell = 48942, class = "PALADIN", auras = { 48942 } },                       -- Devotion Aura
		{ spell = 58753, class = "SHAMAN", auras = { 58754 } },                        -- Stoneskin Totem
	}},
	{ name = "Mana per 5", count = true, audience = "mana", variants = {
		{ spell = 48936, class = "PALADIN", auras = { 48936, 48938 } },                -- Blessing of Wisdom
		{ spell = 58774, class = "SHAMAN", auras = { 58777 } },                        -- Mana Spring Totem
	}},
	{ name = "Replenishment", variants = {                                             -- one aura for all, told apart by its caster
		{ spell = 31878, class = "PALADIN", talent = 31878, auras = { 57669 } },       -- Judgements of the Wise
		{ spell = 34914, class = "PRIEST", talent = 34914, auras = { 57669 } },        -- Vampiric Touch
		{ spell = 53290, class = "HUNTER", talent = 53290, auras = { 57669 } },        -- Hunting Party
		{ spell = 54117, class = "WARLOCK", talent = 54117, auras = { 57669 } },       -- Improved Soul Leech
		{ spell = 44557, class = "MAGE", talent = 44557, auras = { 57669 } },          -- Enduring Winter
	}},
	{ name = "Heroism", variants = {
		{ spell = 32182, hordeSpell = 2825, class = "SHAMAN", auras = { 32182, 2825 } }, -- Heroism / Bloodlust
	}},
}

RLK.DEBUFFS = {
	{ name = "Armor -20%", variants = {
		{ spell = 47467, class = "WARRIOR", auras = { 47467 } },                       -- Sunder Armor
		{ spell = 48669, class = "ROGUE", auras = { 48669 } },                         -- Expose Armor
		{ spell = 55754, class = "HUNTER", pet = "WORM", auras = { 55754 } },          -- Acid Spit
	}},
	{ name = "Armor -5%", variants = {
		{ spell = 770, class = "DRUID", auras = { 770, 16857 } },                      -- Faerie Fire (+ Feral)
		{ spell = 50511, class = "WARLOCK", auras = { 50511 } },                       -- Curse of Weakness
		{ spell = 56631, class = "HUNTER", pet = "WASP", auras = { 56631 } },          -- Sting
	}},
	{ name = "Physical Damage +4%", variants = {
		{ spell = 29859, class = "WARRIOR", talent = 29859, auras = { 30070 } },       -- Blood Frenzy
		{ spell = 51682, class = "ROGUE", talent = 51682, auras = { 58683 } },         -- Savage Combat
	}},
	{ name = "Bleed Damage +30%", variants = {
		{ spell = 33917, class = "DRUID", talent = 33917, auras = { 48564, 48566 } },  -- Mangle (Bear / Cat)
		{ spell = 46854, class = "WARRIOR", talent = 46854, auras = { 46857 } },       -- Trauma
		{ spell = 57393, class = "HUNTER", pet = "RHINO", auras = { 57393 } },         -- Stampede
	}},
	{ name = "Spell Damage +13%", variants = {
		{ spell = 47865, class = "WARLOCK", auras = { 47865 } },                       -- Curse of the Elements
		{ spell = 51099, class = "DEATHKNIGHT", talent = 51099, auras = { 51735 } },   -- Ebon Plaguebringer -> Ebon Plague
		{ spell = 48506, class = "DRUID", talent = 48506, auras = { 60433 } },         -- Earth and Moon
	}},
	{ name = "Spell Crit +5%", variants = {
		{ spell = 17793, class = "WARLOCK", talent = 17793, auras = { 17800 } },       -- Improved Shadow Bolt -> Shadow Mastery
		{ spell = 11095, class = "MAGE", talent = 11095, auras = { 22959 } },          -- Improved Scorch
		{ spell = 11180, class = "MAGE", talent = 11180, auras = { 12579 } },          -- Winter's Chill
	}},
	{ name = "Crit +3%", variants = {
		{ spell = 20335, class = "PALADIN", talent = 20335, auras = { 21183 } },       -- Heart of the Crusader
		{ spell = 57722, class = "SHAMAN", talent = 30706, auras = { 30708 } },        -- Totem of Wrath
		{ spell = 31226, class = "ROGUE", talent = 31226, auras = { 31226 } },         -- Master Poisoner
	}},
	{ name = "Spell Hit +3%", variants = {
		{ spell = 33191, class = "PRIEST", talent = 33191, auras = { 33198 } },        -- Misery
		{ spell = 33600, class = "DRUID", talent = 33600, auras = { 770 } },           -- Improved Faerie Fire (rides on Faerie Fire)
	}},
	{ name = "Attack Power Reduction", variants = {
		{ spell = 47437, class = "WARRIOR", auras = { 47437 } },                       -- Demoralizing Shout
		{ spell = 48560, class = "DRUID", auras = { 48560 } },                         -- Demoralizing Roar
		{ spell = 9452, class = "PALADIN", talent = 9452, auras = { 26017 } },         -- Vindication
		{ spell = 50511, class = "WARLOCK", auras = { 50511 } },                       -- Curse of Weakness
		{ spell = 55487, class = "HUNTER", pet = "BAT", auras = { 55487 } },           -- Demoralizing Screech
	}},
	{ name = "Attack Speed Reduction", variants = {
		{ spell = 49909, class = "DEATHKNIGHT", auras = { 55095 } },                   -- Icy Touch -> Frost Fever
		{ spell = 47502, class = "WARRIOR", auras = { 47502 } },                       -- Thunder Clap
		{ spell = 53695, class = "PALADIN", talent = 53695, auras = { 68055 } },       -- Judgements of the Just
		{ spell = 48483, class = "DRUID", talent = 48483, auras = { 58181 } },         -- Infected Wounds
	}},
	{ name = "Hunter's Mark", variants = {
		{ spell = 53338, class = "HUNTER", auras = { 53338 } },
	}},
	-- minor rows: trash, a few bosses, PvP; hidden unless turned on
	{ name = "Cast Speed Reduction", minor = true, variants = {
		{ spell = 11719, class = "WARLOCK", auras = { 11719 } },                       -- Curse of Tongues
		{ spell = 5761, class = "ROGUE", auras = { 5760 } },                           -- Mind-numbing Poison
		{ spell = 31589, class = "MAGE", talent = 31589, auras = { 31589 } },          -- Slow
		{ spell = 58611, class = "HUNTER", pet = "COREHOUND", auras = { 58611 } },     -- Lava Breath
	}},
	{ name = "Melee Hit Reduction", minor = true, variants = {
		{ spell = 48468, class = "DRUID", talent = 5570, auras = { 48468 } },          -- Insect Swarm
		{ spell = 3043, class = "HUNTER", auras = { 3043 } },                          -- Scorpid Sting
	}},
	{ name = "Healing Reduction", minor = true, variants = {
		{ spell = 47486, class = "WARRIOR", talent = 12294, auras = { 47486 } },       -- Mortal Strike
		{ spell = 57975, class = "ROGUE", auras = { 57975, 57978 } },                  -- Wound Poison
		{ spell = 49050, class = "HUNTER", auras = { 49050 } },                        -- Aimed Shot
		{ spell = 46910, class = "WARRIOR", talent = 46910, auras = { 56112 } },       -- Furious Attacks
	}},
	{ name = "Judgement of Light", minor = true, variants = {
		{ spell = 20271, class = "PALADIN", auras = { 20185 } },
	}},
	{ name = "Judgement of Wisdom", minor = true, variants = {
		{ spell = 53408, class = "PALADIN", auras = { 20186 } },
	}},
}

-- Shown again at the bottom, one group per totem element: which one is up,
-- and how many are out of its reach. Totems, like the paladin auras, reach
-- party and raid members in range.
RLK.TOTEMS = {
	{ name = "Earth Totems", count = true, variants = {
		{ spell = 58643, class = "SHAMAN", auras = { 58646 } },                        -- Strength of Earth Totem
		{ spell = 58753, class = "SHAMAN", auras = { 58754 } },                        -- Stoneskin Totem
	}},
	{ name = "Fire Totems", count = true, variants = {
		{ spell = 57722, class = "SHAMAN", talent = 30706, auras = { 57658 } },        -- Totem of Wrath
		{ spell = 58656, class = "SHAMAN", auras = { 58656 } },                        -- Flametongue Totem
		{ spell = 58745, optional = true, class = "SHAMAN", auras = { 58744 } },                        -- Frost Resistance Totem
	}},
	{ name = "Water Totems", count = true, variants = {
		{ spell = 58774, class = "SHAMAN", auras = { 58777 } },                        -- Mana Spring Totem
		{ spell = 58739, optional = true, class = "SHAMAN", auras = { 58738 } },                        -- Fire Resistance Totem
	}},
	{ name = "Air Totems", count = true, variants = {
		{ spell = 8512, class = "SHAMAN", auras = { 8515 } },                          -- Windfury Totem
		{ spell = 3738, class = "SHAMAN", auras = { 2895 } },                          -- Wrath of Air Totem
		{ spell = 8177, optional = true, class = "SHAMAN", auras = { 8178 } },                          -- Grounding Totem
		{ spell = 58749, optional = true, class = "SHAMAN", auras = { 58748 } },                        -- Nature Resistance Totem
	}},
}

-- One row per blessing, so each tooltip lists who is missing that blessing,
-- among the members it is meant for.
RLK.PALADIN_BLESSINGS = {
	{ name = "Blessing of Kings", count = true, variants = {
		{ spell = 20217, class = "PALADIN", auras = { 20217, 25898 } },
	}},
	{ name = "Blessing of Might", count = true, audience = "physical", variants = {
		{ spell = 48932, class = "PALADIN", auras = { 48932, 48934 } },
	}},
	{ name = "Blessing of Wisdom", count = true, audience = "mana", variants = {
		{ spell = 48936, class = "PALADIN", auras = { 48936, 48938 } },
	}},
	{ name = "Blessing of Sanctuary", count = true, variants = {
		{ spell = 20911, class = "PALADIN", talent = 20911, auras = { 20911, 25899 } },
	}},
}

RLK.PALADIN_AURAS = {
	{ name = "Paladin Auras", count = true, variants = {
		{ spell = 48942, class = "PALADIN", auras = { 48942 } },                       -- Devotion Aura
		{ spell = 54043, class = "PALADIN", auras = { 54043 } },                       -- Retribution Aura
		{ spell = 19746, class = "PALADIN", auras = { 19746 } },                       -- Concentration Aura
		{ spell = 48945, optional = true, class = "PALADIN", auras = { 48945 } },                       -- Frost Resistance Aura
		{ spell = 48943, optional = true, class = "PALADIN", auras = { 48943 } },                       -- Shadow Resistance Aura
		{ spell = 48947, optional = true, class = "PALADIN", auras = { 48947 } },                       -- Fire Resistance Aura
		{ spell = 32223, optional = true, class = "PALADIN", auras = { 32223 } },                       -- Crusader Aura
	}},
}