-- Central tuning file. Every number a designer will want to tweak lives here.
local Config = {}

Config.Phases = { Prologue = "Prologue", Open = "Open" }

-- Friend-testing mode: short prologue, the test arena is built (with armory, trainer and
-- dummies). Set Enabled = false for a real release.
Config.Dev = {
	Enabled = true,
	PrologueSeconds = 15, -- only used when Config.Tutorial.Enabled = false
	CycleSeconds = 600, -- faster dematerialization while testing
	ArmoryPoints = 10, -- attribute points the arena instructor hands out per use
}

-- Prologue: every player is alone in a private plot far from everyone else.
Config.PrologueSeconds = 600 -- hard cap on the prologue (tutorial) per server
Config.PrologueMinSeconds = 30 -- earliest the world opens once every player finished the tutorial

-- The tutorial runs in each player's private room. When Enabled, the world opens as soon as
-- everyone has finished (or skipped) it, instead of on Dev.PrologueSeconds.
Config.Tutorial = {
	Enabled = true,
	DummyInterval = 2.8, -- seconds between training-dummy strikes
	DummyTelegraph = 0.8, -- red flash before a strike lands (the dodge/parry cue)
	DummyDamage = 6,
	DummyPosture = 12,
}
Config.EmergenceCinematic = 6 -- seconds between the announcement and the teleport
Config.PlotOrigin = Vector3.new(0, 2000, 0)
Config.PlotSpacing = 1500

-- Open world. Tag SpawnLocation-like parts with "CitySpawn" in Studio to place spawns.
Config.CityFallbackRadius = 300
Config.CityFallbackHeight = 10

Config.City = {
	CacheRespawn = 240, -- seconds before an opened cache refills
}

Config.Raid = {
	JoinWindow = 20, -- seconds the gate stays open after someone starts a raid
	MaxPlayers = 6,
	TimeLimit = 600,
	Waves = {
		{ Raider = 4 },
		{ Raider = 3, Shocker = 2 },
		{ Brute = 1, Raider = 2, Shocker = 2 },
		{ Warden = 1 }, -- the boss wave
	},
	ScalePerPlayer = 0.25, -- enemy health/damage multiplier per extra raider
	Origin = Vector3.new(-3000, 50, 0), -- the raid instance is built far from the city
	Radius = 70,
	ExitDelay = 25, -- seconds to loot the vault before being sent home
	Xp = 400,
}

Config.Devour = {
	Hold = 3, -- seconds; longer than looting, and you can't do both
	XpBase = 40,
	XpPerLevel = 20,
	HealFraction = 0.3,
	NpcXp = 15,
}

Config.Destruction = {
	GrabRange = 8,
	GrabTime = 0.2,
	MaxChargeTime = 0.8, -- throw charge saturates here
	MinFlight = 3, -- studs a thrown chunk must travel before it can hit (no spam-drop damage)
	FlightTime = 4, -- seconds a throw stays "live"
	LooseChunkCap = 150, -- past this the oldest settled chunks freeze, then fade
	SettleTime = 3,
	ChunkLifetime = 180,
	Explosion = {
		Grenade = { Radius = 14, Damage = 55, World = 120, Fuse = 2.5, Speed = 70 },
		Charge = { Radius = 10, Damage = 40, World = 400, Fuse = 4, PlantRange = 7 },
		Barrel = { Radius = 11, Damage = 45, World = 100 },
	},
	NoiseRadius = 120, -- NPCs this close investigate a breach or explosion
	CycleSeconds = 3600, -- dematerialization: everything broken returns to intact
	CycleWarning = 60,
	GoreLevel = "Moderate", -- "Moderate" | "Restricted" (see design doc section 9); only Moderate is built
}

Config.SpawnProtection = 8 -- seconds of invulnerability after spawning into the open world

Config.RespawnDelay = 5
Config.CombatLogSeconds = 15 -- leaving this soon after combat = permadeath
Config.CombatLogPunish = true
Config.OwnerLockout = 60 -- seconds a dead player's new character cannot take their own old remains
Config.LootHold = 1.5 -- seconds to hold E to loot / steal from a body
Config.CorpseLifetime = 300

Config.Stats = {
	Names = { "Strength", "Fortitude", "Agility", "Intelligence", "Willpower" },
	StartingPoints = 10,
	PointsPerLevel = 3,
	MaxPerStat = 50,
	BaseHealth = 100,
	HealthPerFortitude = 8,
	BaseStamina = 100,
	StaminaPerWillpower = 4,
	BaseWalkSpeed = 15,
	WalkSpeedPerAgility = 0.1,
	DamagePerStrength = 0.03,
	PostureDamagePerStrength = 0.02,
	PhysicalResistPerFortitude = 0.004,
	ChargePerIntelligence = 0.01,
	MaxCharge = 100,
}

-- Flickering cursed energy (Black Flash). Tap the flicker key (E) just BEFORE your swing connects.
-- A well-timed flick boosts that hit and starts a chain; chain hits escalate until the third
-- consecutive flick lands a Black Flash: x2.5 damage, guard-breaking, big stun, and you enter
-- the Zone (wider flick window, Black Flash needs one fewer link, charge refund).
-- Mis-timed flicks just waste charge. Getting hit, dodged or parried breaks the chain.
Config.Flicker = {
	MaxLevel = 3, -- consecutive flick hits needed for a Black Flash
	Window = 0.28, -- press at most this long before impact (x FlickerRate)
	Cooldown = 0.3, -- minimum time between presses
	Cost = 6, -- charge per press (divided by FlickerRate)
	ChainTime = 3.5, -- seconds a chain survives between hits
	DamageMult = { 1.25, 1.6 }, -- chain links 1 and 2 (the 3rd is the Black Flash)
	BlackFlashMult = 2.5,
	BlackFlashPosture = 2,
	BlackFlashStun = 1.0,
	BlackFlashKnockback = 55,
	ZoneTime = 8,
	ZoneWindowMult = 1.5,
	FlashRefund = 25, -- charge returned by a Black Flash
	RatePerIntelligence = 0.01,
}

Config.Combat = {
	FeintRecovery = 0.18, -- feint = cancel a swing during its windup
	FeintRefund = 0.6, -- fraction of the swing's stamina you get back
	CriticalPostureMult = 1.75, -- heavy attacks crush blocks
	ParryWindow = 0.22, -- block pressed this recently before impact = parry
	ParryRearm = 0.6, -- time block must have been released before a new press can parry again
	ParryStun = 1.1,
	ParryPostureRelief = 25,
	GuardBreakStun = 1.4,
	BlockReduction = 0.7,
	BlockMinFacing = 0.1, -- hits from behind (dot < this) bypass block
	BasePosture = 80,
	PosturePerWillpower = 2,
	PostureRegenPerSecond = 10,
	PostureRegenDelay = 1.5,
	HitStunDefault = 0.35,
	DodgeCost = 18,
	DodgeCooldown = 0.9,
	DodgeIFrames = 0.35,
	DodgeSpeed = 60,
	StaminaRegenPerSecond = 22,
	StaminaRegenDelay = 0.9,
	ChargePerHit = 8,
	MaxResist = 0.75,
	HeavyCooldown = 1.2,
	KillCreditSeconds = 15,
}

return Config
