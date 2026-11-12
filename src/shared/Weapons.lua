-- Weapons own the melee/ranged moveset: combo chain, heavy attack, timings and reach.
-- Skills and resistances come from stats + armor, never from the weapon.
--
-- Every attack is defined by its frame data (frames at 60 per second), fighting-game style:
--   Startup  - frames before the weapon is live (the wind-up; what you can react to)
--   Active   - frames the weapon is live (shared/Swings traces it; it hits whatever it passes)
--   Recovery - frames after, until you can act again (what you get punished in)
-- frames(damage, posture, startup, active, recovery, range, extra) stores those and derives the seconds the
-- combat code runs on: Windup = Startup/60, Active = Active/60, End = (Startup + Active + Recovery)/60.
-- Other fields (seconds / studs):
--   Range  - reach (ranged weapons: raycast length)
--   Arc    - min dot(look, toTarget); 0.3 ~ 145deg cone, 0.7 ~ narrow thrust (non-traced fallbacks)
--   Damage / Posture - raw values, scaled by stats at runtime
--   Knockback (studs/s push), Stun (hit-stun on target), Hyperarmor, Type ("Physical"|"Arc"), Ranged
-- Weapon Mass ("Light" | "Medium" | "Heavy"): how big it swings. A Medium or Heavy weapon's launcher throws up
-- everything around the impact (Config.Momentum.GroupLaunch).
local Weapons = {}

Weapons.FPS = 60

local function frames(damage, posture, startup, active, recovery, range, extra)
	local spec = {
		Damage = damage, Posture = posture, Range = range, Arc = 0.3, Stamina = math.floor(damage * 0.6 + 2),
		Startup = startup, ActiveFrames = active, Recovery = recovery,
		Windup = startup / Weapons.FPS, Active = active / Weapons.FPS, End = (startup + active + recovery) / Weapons.FPS,
	}
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end
Weapons.Frames = frames

-- "8f / 7f / 18f": an attack's frame data as a line (inventory tooltip)
function Weapons.FrameLine(spec)
	return ("%df startup  %df active  %df recovery"):format(spec.Startup or 0, spec.ActiveFrames or 0, spec.Recovery or 0)
end

Weapons.Defs = {
	Fists = {
		Name = "Fists", Family = "Fists", ComboReset = 0.7, ComboCooldown = 0.35,
		Attacks = {
			frames(6, 3, 6, 7, 12, 6),
			frames(6, 3, 6, 7, 12, 6),
			frames(6, 3, 6, 7, 12, 6),
			frames(9, 6, 8, 8, 16, 6, { Knockback = 30 }),
		},
		Heavy = frames(12, 8, 18, 9, 21, 6, { Knockback = 35, Stamina = 14 }),
	},
	PipeClub = {
		Name = "Pipe Club", Family = "Blunt", Mass = "Medium", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			frames(12, 5, 10, 8, 16, 7),
			frames(12, 5, 10, 8, 16, 7),
			frames(18, 10, 13, 10, 19, 7, { Knockback = 35 }),
		},
		Heavy = frames(26, 14, 24, 10, 26, 7.5, { Knockback = 45, Stamina = 20 }),
	},
	RebarBlade = {
		Name = "Rebar Blade", Family = "Blade", ComboReset = 0.7, ComboCooldown = 0.45,
		Attacks = {
			frames(11, 4, 7, 8, 14, 8),
			frames(11, 4, 7, 8, 14, 8),
			frames(13, 5, 8, 8, 14, 9, { Arc = 0.2 }),
			frames(17, 9, 12, 10, 20, 9, { Knockback = 30 }),
		},
		Heavy = frames(24, 12, 21, 11, 25, 8.5, { Arc = 0.0, Stamina = 20 }),
	},
	ShockBaton = {
		Name = "Shock Baton", Family = "Baton", ComboReset = 0.7, ComboCooldown = 0.4, ChargeBonus = 6,
		Attacks = {
			frames(10, 4, 7, 7, 14, 7, { Type = "Arc" }),
			frames(10, 4, 7, 7, 14, 7, { Type = "Arc" }),
			frames(16, 10, 11, 8, 20, 7, { Type = "Arc", Knockback = 25, Stun = 0.6 }),
		},
		Heavy = frames(22, 12, 21, 10, 23, 7, { Type = "Arc", Stamina = 18, Stun = 0.7 }),
	},
	ScrapSpear = {
		Name = "Scrap Spear", Family = "Spear", ComboReset = 0.8, ComboCooldown = 0.45,
		Attacks = {
			frames(8, 3, 8, 7, 14, 11, { Arc = 0.6 }),
			frames(8, 3, 8, 7, 14, 11, { Arc = 0.6 }),
			frames(12, 6, 11, 8, 14, 12, { Arc = 0.6, Knockback = 25 }),
		},
		Heavy = frames(20, 10, 21, 10, 23, 13, { Arc = 0.7, Knockback = 30, Stamina = 18 }),
	},
	Sledge = {
		Name = "Sledge", Family = "Hammer", Mass = "Heavy", ComboReset = 0.9, ComboCooldown = 0.7,
		Attacks = {
			frames(24, 12, 18, 10, 17, 8, { Knockback = 40 }),
			frames(24, 12, 18, 10, 23, 8, { Knockback = 40 }),
		},
		Heavy = frames(44, 28, 36, 12, 36, 9, { Hyperarmor = true, Knockback = 60, Stamina = 30 }),
	},
	ArcPistol = {
		Name = "Arc Pistol", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.3, ChargeBonus = 3, Ammo = "ArcCell",
		Attacks = {
			frames(9, 3, 5, 3, 17, 90, { Type = "Arc", Ranged = true, Stamina = 8 }),
		},
		Heavy = frames(22, 10, 30, 3, 39, 110, { Type = "Arc", Ranged = true, Stamina = 22, Knockback = 20 }),
	},
	-- a suppressed slug pistol: weak, but a guard two rooms off does not hear it (Noise = the radius it carries,
	-- server/Stealth; anything without one is loud). Made for putting lights out.
	Whisper = {
		Name = "Whisper", Family = "Sidearm", ComboReset = 0.5, ComboCooldown = 0.25, ChargeBonus = 1, Ammo = "Subsonic", Noise = 7,
		MagSize = 7, ReloadSeconds = 1.5, Headshot = 8, -- one quiet round in the head drops a sentry
		Attacks = {
			frames(12, 4, 6, 3, 19, 120, { Ranged = true, Stamina = 4 }),
		},
		Heavy = frames(12, 4, 6, 3, 19, 120, { Ranged = true, Stamina = 4 }),
	},
}

return Weapons
