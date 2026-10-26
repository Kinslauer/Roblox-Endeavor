-- Weapons own the melee/ranged moveset: combo chain, heavy attack, timings and reach.
-- Skills and resistances come from stats + armor, never from the weapon.
--
-- Attack spec fields (seconds / studs):
--   Windup  - delay before the hitbox opens      Active - how long the hitbox stays open
--   End     - total time before the next input   Range  - reach (ranged weapons: raycast length)
--   Arc     - min dot(look, toTarget); 0.3 ~ 145deg cone, 0.7 ~ narrow thrust
--   Damage / Posture - raw values, scaled by stats at runtime
--   Knockback (studs/s push), Stun (hit-stun on target), Hyperarmor, Type ("Physical"|"Arc"), Ranged
local Weapons = {}

local function hit(damage, posture, windup, active, finish, range, extra)
	local spec = {
		Damage = damage, Posture = posture, Windup = windup, Active = active,
		End = finish, Range = range, Arc = 0.3, Stamina = math.floor(damage * 0.6 + 2),
	}
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end

Weapons.Defs = {
	Fists = {
		Name = "Fists", Family = "Fists", ComboReset = 0.7, ComboCooldown = 0.35,
		Attacks = {
			hit(6, 3, 0.10, 0.12, 0.30, 6),
			hit(6, 3, 0.10, 0.12, 0.30, 6),
			hit(6, 3, 0.10, 0.12, 0.34, 6),
			hit(9, 6, 0.14, 0.14, 0.55, 6, { Knockback = 30 }),
		},
		Heavy = hit(12, 8, 0.30, 0.15, 0.80, 6, { Knockback = 35, Stamina = 14 }),
	},
	PipeClub = {
		Name = "Pipe Club", Family = "Blunt", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			hit(12, 5, 0.16, 0.14, 0.50, 7),
			hit(12, 5, 0.16, 0.14, 0.50, 7),
			hit(18, 10, 0.22, 0.16, 0.70, 7, { Knockback = 35 }),
		},
		Heavy = hit(26, 14, 0.40, 0.16, 1.00, 7.5, { Knockback = 45, Stamina = 20 }),
	},
	RebarBlade = {
		Name = "Rebar Blade", Family = "Blade", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			hit(11, 4, 0.12, 0.14, 0.40, 8),
			hit(11, 4, 0.12, 0.14, 0.40, 8),
			hit(13, 5, 0.14, 0.14, 0.45, 9, { Arc = 0.2 }),
			hit(17, 9, 0.20, 0.16, 0.70, 9, { Knockback = 30 }),
		},
		Heavy = hit(24, 12, 0.35, 0.18, 0.95, 8.5, { Arc = 0.0, Stamina = 20 }),
	},
	ShockBaton = {
		Name = "Shock Baton", Family = "Baton", ComboReset = 0.7, ComboCooldown = 0.4, ChargeBonus = 6,
		Attacks = {
			hit(10, 4, 0.12, 0.12, 0.40, 7, { Type = "Arc" }),
			hit(10, 4, 0.12, 0.12, 0.40, 7, { Type = "Arc" }),
			hit(16, 10, 0.18, 0.14, 0.65, 7, { Type = "Arc", Knockback = 25, Stun = 0.6 }),
		},
		Heavy = hit(22, 12, 0.35, 0.16, 0.90, 7, { Type = "Arc", Stamina = 18, Stun = 0.7 }),
	},
	ScrapSpear = {
		Name = "Scrap Spear", Family = "Spear", ComboReset = 0.8, ComboCooldown = 0.45,
		Attacks = {
			hit(8, 3, 0.14, 0.12, 0.40, 11, { Arc = 0.6 }),
			hit(8, 3, 0.14, 0.12, 0.40, 11, { Arc = 0.6 }),
			hit(12, 6, 0.18, 0.14, 0.55, 12, { Arc = 0.6, Knockback = 25 }),
		},
		Heavy = hit(20, 10, 0.35, 0.16, 0.90, 13, { Arc = 0.7, Knockback = 30, Stamina = 18 }),
	},
	Sledge = {
		Name = "Sledge", Family = "Hammer", ComboReset = 0.9, ComboCooldown = 0.7,
		Attacks = {
			hit(24, 12, 0.30, 0.16, 0.75, 8, { Knockback = 40 }),
			hit(24, 12, 0.30, 0.16, 0.85, 8, { Knockback = 40 }),
		},
		Heavy = hit(44, 28, 0.60, 0.20, 1.40, 9, { Hyperarmor = true, Knockback = 60, Stamina = 30 }),
	},
	ArcPistol = {
		Name = "Arc Pistol", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.3, ChargeBonus = 3,
		Attacks = {
			hit(9, 3, 0.08, 0.05, 0.42, 90, { Type = "Arc", Ranged = true, Stamina = 8 }),
		},
		Heavy = hit(22, 10, 0.50, 0.05, 1.20, 110, { Type = "Arc", Ranged = true, Stamina = 22, Knockback = 20 }),
	},
	-- Universe 2 / the Range: a two-handed semi-auto rifle. Fast shots, long reach, and a charged
	-- "lance" heavy that staggers. Only usable (and only obtainable) through the Rift at first.
	ArcRifle = {
		Name = "Arc Rifle", Family = "Rifle", ComboReset = 0.4, ComboCooldown = 0.15, ChargeBonus = 4,
		Attacks = {
			hit(14, 4, 0.05, 0.05, 0.30, 160, { Type = "Arc", Ranged = true, Stamina = 5 }),
		},
		Heavy = hit(40, 16, 0.60, 0.05, 1.30, 220, { Type = "Arc", Ranged = true, Stamina = 24, Knockback = 30, Stun = 0.6 }),
	},
}

return Weapons
