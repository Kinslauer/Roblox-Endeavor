-- Enemy variants (Enemy v2, design/gdd/enemies.md "Planned"). Every attack is a Weapons-style spec run
-- through Combat.Swing, so enemies get the same windup -> active -> end structure, the same Swing
-- telegraph the client draws for players, swing-cancel on hit stun, and hyperarmor flags.
--
-- Constraints baked into the numbers (see the GDD):
--   Windup >= 0.5  so the player can read the cue and parry inside Config.Combat.ParryWindow (0.22)
--   Active <= 0.25 so a well-timed dodge (DodgeIFrames 0.35 before armour) always clears the hit
--   Cadence = spec.End + Recovery, which is the player's punish window
--   Poise: light hits interrupt an enemy only every Poise.Hits-th hit (counter resets after
--   Poise.Reset seconds without a hit); heavies, flicked hits, parries and guard breaks always do.
--   Without it a player stun-locks any enemy with the light combo (owner playtest 2026-10-25).
local Weapons = require(script.Parent.Weapons)

local Enemies = {}

-- Appearance indices (shared/Appearance.lua) + tints so variants read at a distance.
local function look(bodyType, skin, hair, hairColor, cloth)
	return { Appearance = { BodyType = bodyType, SkinTone = skin, Face = 1, Hair = hair, HairColor = hairColor }, Cloth = cloth }
end

Enemies.Defs = {
	Grunt = {
		Name = "Raider Grunt", QuestTag = "Raider", Weapon = "PipeClub",
		Health = 70, Speed = 17, Aggro = 90, Leash = 120, DespawnAfter = 60, -- a shade faster than a base player (15)
		Range = Weapons.Defs.PipeClub.Attacks[3].Range,
		Attack = { Damage = 12, Posture = 8, Windup = 0.6, Active = 0.16, End = 0.8, Range = 7, Arc = 0.3, Knockback = 25, Stamina = 0 },
		Label = 3, -- which player swing pose the client shows (combo index or "Heavy")
		Recovery = { 0.35, 0.9 }, -- idle after a swing (random in range): the punish window
		Poise = { Hits = 2, Reset = 2.5 },
		Xp = 35, Loot = "Raider",
		Look = look(2, 4, 2, 1, Color3.fromRGB(110, 40, 40)),
	},
	Brute = {
		Name = "Raider Brute", QuestTag = "Raider", Weapon = "Sledge",
		Health = 160, Speed = 13, Aggro = 90, Leash = 120, DespawnAfter = 60,
		Range = 9, MaxPosture = 140,
		Attack = { Damage = 30, Posture = 24, Windup = 0.9, Active = 0.2, End = 1.4, Range = 9, Arc = 0.3, Knockback = 45, Hyperarmor = true, Stamina = 0 },
		Label = "Heavy",
		Recovery = { 0.8, 1.5 },
		Poise = { Hits = 3, Reset = 3 },
		Xp = 90, Loot = "Brute",
		Look = look(3, 5, 1, 1, Color3.fromRGB(55, 55, 65)),
	},
	Gunner = {
		Name = "Raider Gunner", QuestTag = "Raider", Weapon = "ArcPistol",
		Health = 55, Speed = 16, Aggro = 110, Leash = 140, DespawnAfter = 60,
		Range = 60, KeepDistance = { 18, 30 }, -- backs off below, closes above
		Attack = { Damage = 10, Posture = 3, Windup = 0.5, Active = 0.05, End = 1.4, Range = 60, Arc = 0.3, Ranged = true, Type = "Arc", Stamina = 0 },
		Label = 1,
		Recovery = { 0.7, 1.4 },
		Poise = { Hits = 1, Reset = 2 }, -- flimsy: every hit interrupts
		Xp = 50, Loot = "Gunner",
		Look = look(1, 2, 3, 4, Color3.fromRGB(50, 70, 95)),
	},
	-- Phase-3 war world: the infantry. Every side's AI recruits are this variant, tinted by faction
	-- (NPCs.Spawn opts.Faction / opts.Cloth); they draw the basic kit (Arc Rifle) until the faction
	-- pool exists. They target the other two sides - players and recruits alike - and walk to the hill
	-- when nobody is in sight (opts.Home as a function).
	Recruit = {
		Name = "Recruit", QuestTag = "Recruit", Weapon = "ArcRifle",
		Health = 90, Speed = 16, Aggro = 120, Leash = 400, DespawnAfter = 600,
		Range = 110, KeepDistance = { 18, 40 },
		Attack = { Damage = 11, Posture = 3, Windup = 0.45, Active = 0.05, End = 1.0, Range = 110, Arc = 0.3, Ranged = true, Type = "Arc", Stamina = 0 },
		Label = 1,
		Recovery = { 0.5, 1.1 },
		Poise = { Hits = 2, Reset = 2 },
		Xp = 30, Loot = "Gunner",
		Look = look(2, 3, 2, 2, Color3.fromRGB(70, 70, 76)),
	},
	-- Phase-2 Range enemy: a flying sentry. Weak, fast, keeps a distance band in the air and strafes
	-- around you while it fires; its rotors glow with the windup (the swing cue sits on its body).
	-- Flying enemies use a physics-driven body (NPCs.lua "Flying"), not pathfinding, and have no Weapon
	-- attribute (the bolt leaves its eye).
	Drone = {
		Name = "Sentry Drone", QuestTag = "Drone",
		Health = 32, Speed = 24, Aggro = 95, Leash = 170, DespawnAfter = 60,
		Flying = {
			Hover = 9, -- studs above the target's feet (or home ground when idle)
			Strafe = 1.1, -- orbit speed around the target, radians per second
			FlipEvery = { 1.5, 3.5 }, -- seconds between orbit-direction changes (random in range)
			Bob = 0.5, -- vertical wobble amplitude, studs
			Responsiveness = 12, -- AlignPosition responsiveness (higher = snappier)
		},
		Range = 55, KeepDistance = { 14, 26 },
		Attack = { Damage = 7, Posture = 2, Windup = 0.45, Active = 0.05, End = 0.8, Range = 55, Arc = 0.3, Ranged = true, Type = "Arc", Stamina = 0 },
		Label = 1,
		Recovery = { 0.4, 0.9 },
		Poise = { Hits = 1, Reset = 2 }, -- every hit knocks it off its line
		Xp = 40, Loot = "Drone",
		Look = { Body = Color3.fromRGB(48, 52, 62), Accent = Color3.fromRGB(255, 60, 60), Rotor = Color3.fromRGB(120, 200, 255) },
	},
}

-- Ambush composition: weighted pick per slot, at most one Brute per group.
Enemies.Ambush = {
	GroupSize = { 2, 4 },
	Weights = { Grunt = 60, Gunner = 25, Brute = 15 },
	MaxBrutes = 1,
	Ring = 55, -- studs from the target player
	RingShrink = 0.7, -- multiply the ring by this after each failed placement round
	PlacementTries = 6,
	-- Per-district overrides (index into District.Districts; NPCs.SpawnAmbush looks the centre up
	-- with District.At). District 2 is the veterans' half: bigger, heavier groups.
	ByDistrict = {
		[2] = { GroupSize = { 3, 5 }, Weights = { Grunt = 40, Gunner = 35, Brute = 25 }, MaxBrutes = 2 },
	},
}

-- Pathing / AI cadence
Enemies.AI = {
	Tick = 0.15, -- seconds between decisions
	Repath = 0.6, -- seconds between path recomputes while chasing
	RepathMove = 6, -- or sooner, when the target moved this far
	WaypointReach = 3.5, -- studs to consider a waypoint reached
	StuckSeconds = 1.5, -- no progress for this long -> recompute (and jump)
	AgentRadius = 2.5,
	AgentHeight = 5.5,
}

return Enemies
