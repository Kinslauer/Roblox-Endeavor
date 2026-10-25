-- Enemy variants (Enemy v2, design/gdd/enemies.md "Planned"). Every attack is a Weapons-style spec run
-- through Combat.Swing, so enemies get the same windup -> active -> end structure, the same Swing
-- telegraph the client draws for players, swing-cancel on hit stun, and hyperarmor flags.
--
-- Constraints baked into the numbers (see the GDD):
--   Windup >= 0.5  so the player can read the cue and parry inside Config.Combat.ParryWindow (0.22)
--   Active <= 0.25 so a well-timed dodge (DodgeIFrames 0.35 before armour) always clears the hit
--   Cadence = spec.End + Recovery, which is the player's punish window
local Weapons = require(script.Parent.Weapons)

local Enemies = {}

-- Appearance indices (shared/Appearance.lua) + tints so variants read at a distance.
local function look(bodyType, skin, hair, hairColor, cloth)
	return { Appearance = { BodyType = bodyType, SkinTone = skin, Face = 1, Hair = hair, HairColor = hairColor }, Cloth = cloth }
end

Enemies.Defs = {
	Grunt = {
		Name = "Raider Grunt", QuestTag = "Raider", Weapon = "PipeClub",
		Health = 70, Speed = 13, Aggro = 90, Leash = 120, DespawnAfter = 60,
		Range = Weapons.Defs.PipeClub.Attacks[3].Range,
		Attack = { Damage = 12, Posture = 8, Windup = 0.6, Active = 0.16, End = 0.9, Range = 7, Arc = 0.3, Knockback = 25, Stamina = 0 },
		Label = 3, -- which player swing pose the client shows (combo index or "Heavy")
		Recovery = { 0.6, 1.2 }, -- idle after a swing (random in range): the punish window
		Xp = 35, Loot = "Raider",
		Look = look(2, 4, 2, 1, Color3.fromRGB(110, 40, 40)),
	},
	Brute = {
		Name = "Raider Brute", QuestTag = "Raider", Weapon = "Sledge",
		Health = 160, Speed = 11, Aggro = 90, Leash = 120, DespawnAfter = 60,
		Range = 9, MaxPosture = 140,
		Attack = { Damage = 30, Posture = 24, Windup = 0.9, Active = 0.2, End = 1.6, Range = 9, Arc = 0.3, Knockback = 45, Hyperarmor = true, Stamina = 0 },
		Label = "Heavy",
		Recovery = { 1.0, 1.8 },
		Xp = 90, Loot = "Brute",
		Look = look(3, 5, 1, 1, Color3.fromRGB(55, 55, 65)),
	},
	Gunner = {
		Name = "Raider Gunner", QuestTag = "Raider", Weapon = "ArcPistol",
		Health = 55, Speed = 14, Aggro = 110, Leash = 140, DespawnAfter = 60,
		Range = 60, KeepDistance = { 18, 30 }, -- backs off below, closes above
		Attack = { Damage = 10, Posture = 3, Windup = 0.5, Active = 0.05, End = 1.4, Range = 60, Arc = 0.3, Ranged = true, Type = "Arc", Stamina = 0 },
		Label = 1,
		Recovery = { 0.8, 1.6 },
		Xp = 50, Loot = "Gunner",
		Look = look(1, 2, 3, 4, Color3.fromRGB(50, 70, 95)),
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
