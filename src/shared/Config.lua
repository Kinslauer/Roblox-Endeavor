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

-- The grid inventory (server/Inventory.lua): pockets without a pack, and what being over the carry limit costs.
Config.Inventory = {
	Pockets = { 6, 4 }, -- grid without a pack
	PocketCarry = 15, -- weight you move freely with without a pack
	OverweightSpeedMult = 0.6, -- walk speed while over the carry limit
	OverweightStaminaMult = 1.6, -- stamina costs while over
	-- searching a container: items reveal one at a time (bigger ones take longer); walking away stops it
	SearchBase = 0.45, -- seconds per item
	SearchPerCell = 0.12, -- extra seconds per cell of its footprint
	SearchReach = 14, -- studs; further than this and the search (and taking) stops
	CarryPerPackLevel = 5, -- extra carry per bench upgrade of the worn pack (each level also adds a row)
}

-- Combat stance (client, ported from combat-feel's Aim): the body faces where the camera looks, the camera sits
-- over the shoulder and the mouse is locked, so swings and bolts go where you look. Pauses while a panel is open.
Config.Aim = {
	DefaultOn = true,
	ToggleKey = Enum.KeyCode.LeftControl,
	FreeCursorKey = Enum.KeyCode.LeftAlt, -- hold to free the mouse without leaving the stance
	-- camera presets by weapon kind: melee far and high so the whole exchange reads, guns in over the shoulder
	Melee = { Distance = 15, ShoulderOffset = Vector3.new(0.9, 1.4, 0) },
	Ranged = { Distance = 9, ShoulderOffset = Vector3.new(1.75, 0.5, 0) },
}

-- HUD v2 (client, ported from combat-feel): bottom-centre bars, floating words, reticle, damage vignette, nameplates.
Config.Hud = {
	BarWidth = 480,
	DamageNumbers = { Life = 0.9, Rise = 3.5, Spread = 1.2, TextSize = 26, HeavyTextSize = 34, HeavyAmount = 20, MaxLive = 24,
		Colors = { Taken = Color3.fromRGB(255, 80, 80), Block = Color3.fromRGB(150, 170, 255), Parry = Color3.fromRGB(255, 255, 255),
			GuardBreak = Color3.fromRGB(255, 160, 0), Dodged = Color3.fromRGB(80, 255, 230) } },
	Reticle = { Size = 6, Gap = 5, Thickness = 2, Color = Color3.fromRGB(235, 235, 240), HitColor = Color3.fromRGB(255, 90, 60), HitSeconds = 0.12, HitScale = 1.8 },
	DamageFlash = { Color = Color3.fromRGB(200, 30, 30), Seconds = 0.35, MaxTransparency = 0.55 },
	Nameplates = { Offset = Vector3.new(-1.2, -0.6, 0), Size = UDim2.fromOffset(120, 16), TextSize = 12,
		Color = Color3.fromRGB(225, 225, 232), NpcColor = Color3.fromRGB(255, 150, 130), FadeStart = 30, FadeEnd = 70 },
}

-- Impact feel (client, ported from combat-feel's Presentation.Impacts): sparks, rings, shards, after-images,
-- camera shake (0..1 trauma) and FOV hitstop per event kind.
Config.Impacts = {
	Hit = { Hitstop = 0.05, Shake = 0.35, Sparks = { Count = 14, Color = Color3.fromRGB(255, 120, 60), Size = 0.35, Speed = 18, Life = 0.3 }, HeavyAmount = 20 },
	HeavyShakeMult = 1.8,
	HeavyHitstopMult = 2,
	Block = { Hitstop = 0, Shake = 0.15, Sparks = { Count = 8, Color = Color3.fromRGB(140, 170, 255), Size = 0.25, Speed = 12, Life = 0.25 } },
	Parry = { Hitstop = 0.1, Shake = 0.5, Sparks = { Count = 18, Color = Color3.fromRGB(255, 255, 255), Size = 0.3, Speed = 22, Life = 0.3 }, Ring = { Color = Color3.fromRGB(255, 255, 255), Size = 9, Life = 0.3 } },
	GuardBreak = { Hitstop = 0.12, Shake = 0.7, Shards = { Count = 16, Color = Color3.fromRGB(255, 170, 40), Size = 0.6, Speed = 26, Life = 0.6 } },
	Dodged = { Ghost = 0.35, Color = Color3.fromRGB(80, 255, 230) },
	BlackFlash = { Hitstop = 0.14, Shake = 1.0 },
	Explosion = { Shake = 0.6, Radius = 40 },
	Camera = { ShakeMagnitude = 0.6, ShakeDecay = 0.25, ShakeFrequency = 28, HitstopFov = -4 },
	MaxInstances = 60, -- live FX parts in workspace.FX at once
}

Config.City = {
	CacheRespawn = 240, -- seconds before an opened cache refills
	-- standing hostiles per district Danger (server/Population.lua)
	Population = {
		Cap = 36, -- hostiles alive at once from all sources, before Population stops adding
		Respawn = 150, -- seconds before a dead pack member returns
		PackRadius = 35, -- how far a pack wanders from its anchor
		Tiers = {
			Low = { Packs = 2, Size = { 2, 3 }, Types = { "Raider" } },
			Medium = { Packs = 3, Size = { 2, 4 }, Types = { "Raider", "Raider", "Shocker", "Brute" } },
			High = { Packs = 4, Size = { 3, 4 }, Types = { "Raider", "Shocker", "Shocker", "Brute" }, Scale = 1.15, Boss = 0.35 },
		},
	},
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
	CatchRange = 24, -- an in-flight chunk this close can be caught...
	CatchWindow = 0.25, -- ...if it would hit within this long after you press grab
	CatchStamina = 12,
	CatchLockout = 0.5, -- a missed catch leaves you open; stops G-spam from being a free parry
	GrabTime = 0.2,
	MaxChargeTime = 0.8, -- throw charge saturates here
	MinFlight = 3, -- studs a thrown chunk must travel before it can hit (no spam-drop damage)
	FlightTime = 4, -- seconds a throw stays "live"
	LooseChunkCap = 150, -- past this the oldest settled chunks are removed (then any unheld chunk)
	SalvageCap = 120, -- unlooted salvage remains per server, oldest first
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
	GoreLevel = "Restricted", -- "Moderate" | "Restricted" (design doc section 9). The content label itself is set in the Creator Dashboard.
}

Config.Gore = {
	BodyCap = 60, -- persistent corpses per server; oldest cleared first
	PoolCap = 80, -- blood pools per client
	PoolLifetime = 90,
}

-- The Front: the war world, a separate place in the same universe. Conduits "tap in" from a
-- Neural Net terminal and control a recruit there. The recruit's gear is the conduit's money.
Config.War = {
	PlaceId = 81481823786216, -- the Front place inside the Endeavor experience (universe 10773835758)
	Factions = { "Union", "Pact" },
	FactionColors = { Union = Color3.fromRGB(70, 110, 200), Pact = Color3.fromRGB(200, 60, 60) },
	UplinkSeconds = 4, -- the neural-net dive animation before the teleport
	StartingCredits = 1500,
	-- The hill: one sector is hot at a time. Presence, kills and captures inside it earn tickets.
	Hill = {
		TicketsPerPlayerPer5s = 1,
		TicketsPerKill = 3,
		CaptureTickets = 50,
		CaptureHoldSeconds = 60, -- majority held this long = captured, hill moves on
		MoveAfterSeconds = 420, -- it moves anyway after this
		SectorSize = 160,
		Sectors = 3, -- the front is a Sectors x Sectors grid; the hill walks it forever
	},
	-- Credits: each faction's income per minute per deployed conduit scales with its share of the scales.
	Income = { BasePerMinute = 60, ShareWeight = 1.5 }, -- income = Base * (0.5 + ShareWeight * (share - 0.5)) clamped
	Scales = { StoreName = "WarScales_v1", Decay = 0.0005 }, -- global tickets, decayed each tick so the scales keep tipping
	Death = { PartDamage = 40, ArmorDamage = 60 }, -- condition lost by parts/armor on a recruit's body (recoverable, damaged)
	LootHold = 2,
	RespawnSeconds = 8,
	Artillery = { Cooldown = 120, Shells = 6, Radius = 16, Damage = 110, Spread = 25, Delay = 6 },
	BodyCapPerSector = 60,
	Entrench = {
		DigSeconds = 4, -- hold to dig a foxhole with the entrenching tool every recruit carries
		FoxholeDepth = 3.5,
		FoxholeRadius = 3.2,
		MinClearance = 7, -- studs from a structure or another hole: you dig in the open, not through walls
		SandbagSeconds = 2.5,
		SandbagsCarried = 3, -- low sandbag sections a recruit can carry from the shop
		MaxPerSector = 40, -- earthworks cap per sector; the oldest collapse first
	},
	SectorRebuildSeconds = 240, -- an empty sector the hill has left rebuilds after this
}

Config.Hideouts = {
	Sites = 12, -- claimable sites laid out through the city and outskirts
	Radius = 34, -- compound half-size
	RaidBaseInterval = 420, -- seconds between NPC raid rolls per hideout at tier 1 (divided by RaidWeight)
	RaidersPerMember = 2,
	TurretHostileNPC = true,
	MedbayHealPerSecond = 2,
}

Config.SpawnSettle = 1.5 -- seconds the character is held in place after a spawn so the client receives the ground first

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
	SprintMult = 1.45,
	SprintStaminaPerSecond = 9,
	SprintMinStamina = 10,
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
	InputQueue = 0.4, -- an attack/heavy pressed this long (s) before you're free is held and played then
	KillCreditSeconds = 15,
}

return Config
