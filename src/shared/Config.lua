-- Central tuning file. Every number a designer will want to tweak lives here.
local Config = {}

Config.Phases = { Prologue = "Prologue", Open = "Open" }

-- Prologue: every player is alone in a private plot far from everyone else.
Config.PrologueSeconds = 420 -- how long the "singleplayer" illusion lasts per server
Config.EmergenceCinematic = 6 -- seconds between the announcement and the teleport
Config.PlotOrigin = Vector3.new(0, 2000, 0)
Config.PlotSpacing = 1500

-- Open world. Tag SpawnLocation-like parts with "CitySpawn" in Studio to place spawns.
Config.CityFallbackRadius = 300
Config.CityFallbackHeight = 10

Config.RespawnDelay = 5
Config.CombatLogSeconds = 15 -- leaving this soon after combat = permadeath
Config.CombatLogPunish = true
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

Config.Combat = {
	ParryWindow = 0.22, -- block pressed this recently before impact = parry
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
