local module = {
	["Rapid Punches"] = {
		["Class"] = "Brawler",
		["Level"] = 0,
		["Range"] = 7,
		["ComboDamage"] = 2,
		["ComboPostureDamage"] = .2,
		["Cooldown"] = 10,
		[7] = {--8th hit
			["Damage"] = 5,
			["PostureDamage"] = 2,
			["Knockback"] = true
		},
		["Compatible"] = {
			["Brawler"] = true,
			["Blasters"] = true,
		},
	},
	["Thrust Combo"] = {
		["Class"] = "Spear",
		["Level"] = 0,
		["Range"] = 12,
		["ComboDamage"] = 5,
		["ComboPostureDamage"] = .5,
		["Cooldown"] = 10,
		["VFX"] = "ThrustCombo",
		[3] = {
			["Damage"] = 10,
			["PostureDamage"] = 2,
			["Knockback"] = true
		},
		["Compatible"] = {
			["Spear"] = true,
			["Sword"] = true,
			["Knight"] = true,
		},
	},
	["Critical Strike"] = {
		["Class"] = "Sword",
		["Level"] = 0,
		["Range"] = 10,
		["Cooldown"] = 10,
		["SFX"] = {"CriticalStrike"},
		[0] = {
			["Damage"] = 40,
			["PostureDamage"] = 10,
			["Knockback"] = true
		},
		["Compatible"] = {
			["Spear"] = true,
			["Sword"] = true,
			["Knight"] = true,
		},
	},
	["Shield Strike"] = {
		["Class"] = "Knight",
		["Level"] = 0,
		["Range"] = 10,
		["Cooldown"] = 10,
		[0] = {
			["Damage"] = 10,
			["PostureDamage"] = 4,
			["StunScale"] = 5,
		},
		["Compatible"] = {
			["Knight"] = true,
		},
	}
}

return module
