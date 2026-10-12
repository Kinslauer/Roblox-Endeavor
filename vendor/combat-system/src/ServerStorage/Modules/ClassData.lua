local module = {
	["Brawler"] = {
		["Attacks"] = {
			["Damage"] = 10,
			["PostureDamage"] = 2,
			{},
			{},
			{},
			{},
		},
		["Heavy"] = {
			["Damage"] = 15,	
			["PostureDamage"] = 6,
			["SFX"] = {"BrawlHeavy"},
		},
		["Range"] = 7,
		["Radius"] = .6,
		["Damage"] = 10,
	},
	
	["Sword"] = {
		["Attacks"] = {
			["Damage"] = 12,
			["PostureDamage"] = 2,
			{},
			{},
			{
				["Range"] = 10,
				["Radius"] = .8,
			},
		},
		["Heavy"] = {
			["Damage"] = 20,
			["PostureDamage"] = 8,
			["RotationLocked"] = true,
			["SFX"] = {"SwordSlash"},
			["HitCondition"] = function(entity,distance,radius)
				if distance < 8 then
					return true
				end
				return false
			end},
		["Range"] = 8,
	},
	
	
	["Blasters"] = {
		["Attacks"] = {
			["Damage"] = 12,
			["PostureDamage"] = 2,
			{
				["Range"] = 8,
				["Radius"] = .3,
			},
			{
				["Particles"] = "Explosion",
				["SFX"] = {"Explosion"},
			},
			{
				["Particles"] = "Explosion",
				["SFX"] = {"Explosion"},
			},
		},
		["Heavy"] = {
			["Damage"] = 10,	
			["PostureDamage"] = 2,
			["Particles"] = "Explosion",
			["VFX"] = "ExplosionProjectile",
			["SFX"] = {"Explosion"},
			["Projectile"] = true,
			["Emit"] = 1,
			["Velocity"] = 160,
			["Duration"] = 10,
			["HitCondition"] = function(entity,distance,radius)
				if distance < 4 then
					return true
				end
				return false
			end,
		},
		["Range"] = 12,
		["Radius"] = .6,
	},
	
	
	["Hammer"] = {
		["Attacks"] = {
			["Damage"] = 20,
			["PostureDamage"] = 5,
			{
				["Knockback"] = true,
				["RotationLocked"] = true
			},
			{
				["Knockback"] = true,
				["RotationLocked"] = true
			},
		},
		["Heavy"] = {
			["Damage"] = 40,	
			["PostureDamage"] = 15,
			["Hyperarmor"] = true,
			["Radius"] = .8,
			["SFX"] = {"SwordLunge"},
		},
		["Range"] = 12,
	},
	
	["Spear"] = {
		["Attacks"] = {
			["Damage"] = 6,
			["PostureDamage"] = 2,
			{
				["Range"] = 12,
				["Radius"] = .9,
			},
			{},
			{},
		},
		["Heavy"] = {
			["Damage"] = 15,
			["PostureDamage"] = 8,
			["Range"] = 12,
			["Radius"] = .9,
		},
		["Range"] = 11,
	},
	
	["Knight"] = {
		["Attacks"] = {
			["Damage"] = 12,
			["PostureDamage"] = 2,
			{},
			{},
			{},
		},
		["Heavy"] = {
			["Damage"] = 20,
			["PostureDamage"] = 8,
			["RotationLocked"] = true,
		},
		["Range"] = 8,
	},
	
	["Other"] = {
		["Attacks"] = {},
		["Heavy"] = {
			["Damage"] = 0,	
			["PostureDamage"] = 0,
		},
		["Skills"] = {
			["Rapid Punches"] = {
				["Range"] = 7,
				["ComboDamage"] = 2,
				["ComboPostureDamage"] = .2,
				["Cooldown"] = 20,
				[7] = {5,2,true}--7th hit {dmg,Posturedmg,knockback}
			},
		},
		
	}
}

return module
