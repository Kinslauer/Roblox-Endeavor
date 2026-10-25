-- Central tuning file. Every number a designer will want to tweak lives here.
local Config = {}

Config.Phases = { Prologue = "Prologue", Open = "Open" }

-- Friend-testing mode: short prologue, the test arena is built (with armory, trainer and
-- dummies). Set Enabled = false for a real release.
Config.Dev = {
	Enabled = true,
	PrologueSeconds = 15, -- only used when Config.Tutorial.Enabled = false
	ArmoryPoints = 10, -- attribute points the arena instructor hands out per use
}

-- Prologue: every player is alone in a private plot far from everyone else.
Config.PrologueSeconds = 600 -- hard cap on the prologue (tutorial) per server
Config.PrologueMinSeconds = 30 -- earliest the world opens once every player finished the tutorial

-- The tutorial runs in each player's private room. When Enabled, the world opens as soon as
-- everyone has finished (or skipped) it, instead of on Dev.PrologueSeconds.
Config.Tutorial = {
	Enabled = true,
	ReplayAlways = false, -- true = run the tutorial even for profiles that finished it (testing)
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

Config.RespawnDelay = 5
Config.CombatLogSeconds = 15 -- leaving this soon after combat = permadeath
Config.CombatLogPunish = true
Config.LootHold = 1.5 -- seconds to hold X (ProximityPrompt) to loot / steal from a body
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

-- Remote rate limits: calls per second per player; capacity = rate * Burst (short bursts are fine).
Config.RateLimit = {
	Burst = 2,
	Attack = 6, Heavy = 4, Feint = 6, Flicker = 8, Block = 10, Dodge = 4, UseSkill = 6,
	SetSkill = 4, Allocate = 10, UseItem = 4, EquipItem = 4, Unequip = 4, Craft = 4, TutorialSkip = 1, SetAppearance = 10,
}

-- World events (server/Events.lua)
Config.Events = {
	SupplyRadius = 120, -- max distance from the chosen player a supply crate may land
	SupplyDropHeight = 150, -- how high above the ground it starts falling
	PlacementTries = 6,
}

-- Fair arrival: a fresh character in the open world cannot be damaged for this long, or until it
-- attacks. Shown as a ForceField.
Config.SpawnProtectionSeconds = 8

Config.Combat = {
	FeintRecovery = 0.18, -- feint = cancel a swing during its windup
	FeintRefund = 0.6, -- fraction of the swing's stamina you get back
	CriticalPostureMult = 1.75, -- heavy attacks crush blocks
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
