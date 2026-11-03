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
	ArenaOrigin = Vector3.new(3000, 0, 0), -- the test arena (the Pit + armory) is built here, off the map; F2 "Armory" teleports
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

-- Cybernetics are ripped in at an Autonet and nowhere else (ported from combat-feel's cybernetics.md). It hurts.
Config.Cyber = {
	RipSeconds = 4, -- one rip (a swap is two)
	RipHealthCost = 0.35, -- share of max health per rip, paid up front; never below 1 HP
	Range = 12, -- studs from an Autonet
}

-- Momentum (ported from combat-feel's momentum.md 2.5): side-dodge i-frames, the launcher, juggles, Enemy Step.
-- A melee heavy on an *open* hostile (staggered, or just out of its stagger) launches it: it is Juggled (helpless until
-- it lands) and every hit while airborne pops it up again and hurts more. Players are never launched.
Config.Momentum = {
	SideIFrameMult = 1.3, -- side dodges (|dot(dir, look)| < 0.5) get this much more i-frame time
	LaunchVelocity = 70, -- studs/s up (~12 studs of height, ~0.7 s of hang)
	LaunchDrift = 8, -- studs/s away from the attacker
	LaunchAirTime = 0.8, -- seconds the target counts as Juggled after a launch
	LaunchGrace = 0.6, -- a heavy launches if you *start* it while the target is staggered or up to this long after
	LaunchHold = true, -- starting that heavy keeps the open target staggered until it lands
	LaunchHoldReach = 1, -- studs past the heavy's range a target can be and still be held
	AirDamageMult = 1.35, -- damage multiplier against a Juggled target
	AirPopVelocity = 32, -- upward studs/s each hit gives a Juggled target
	AirPopExtend = 0.3, -- seconds each pop adds to the juggle
	MaxJuggleHits = 4, -- pops stop after this many hits
	LandStun = 0.45, -- hit-stun after the juggle ends (the get-up)
	EnemyStepRange = 9, -- studs from the airborne enemy a dodge springs off it
	EnemyStepRefund = 12, -- stamina back
	EnemyStepHop = 34, -- extra upward studs/s on that dodge
}

-- Visible implants (client, ported from combat-feel): what is in a body shows on it, for everyone. Limbs get a metal
-- shell (a copy of the body part a hair larger) plus a lit seam; eyes, ears, nose and core get small parts. A piece
-- with an icon model (ReplicatedStorage.Icons) is drawn with that model in the Fit box instead of the bits.
Config.Implants = {
	Metal = { Color = Color3.fromRGB(118, 116, 110), Material = Enum.Material.Metal, Grow = 1.04 },
	ArtGrow = 1.06,
	Slots = {
		Eyes = { Fit = { { Part = "Head", Offset = Vector3.new(0, 0.1, -0.5), Size = Vector3.new(0.9, 0.24, 0.25) } }, Bits = {
			{ Part = "Head", Offset = Vector3.new(-0.17, 0.1, -0.5), Size = Vector3.new(0.2, 0.1, 0.06), Neon = true },
			{ Part = "Head", Offset = Vector3.new(0.17, 0.1, -0.5), Size = Vector3.new(0.2, 0.1, 0.06), Neon = true } } },
		Ears = { Fit = { { Part = "Head", Offset = Vector3.new(0.52, 0.02, 0), Size = Vector3.new(0.16, 0.42, 0.4) }, { Part = "Head", Offset = Vector3.new(-0.52, 0.02, 0), Size = Vector3.new(0.16, 0.42, 0.4), Turn = 180 } }, Bits = {
			{ Part = "Head", Offset = Vector3.new(-0.52, 0.02, 0), Size = Vector3.new(0.1, 0.35, 0.3) }, { Part = "Head", Offset = Vector3.new(0.52, 0.02, 0), Size = Vector3.new(0.1, 0.35, 0.3) },
			{ Part = "Head", Offset = Vector3.new(-0.56, 0.02, 0), Size = Vector3.new(0.04, 0.12, 0.12), Neon = true }, { Part = "Head", Offset = Vector3.new(0.56, 0.02, 0), Size = Vector3.new(0.04, 0.12, 0.12), Neon = true } } },
		Nose = { Fit = { { Part = "Head", Offset = Vector3.new(0, -0.1, -0.54), Size = Vector3.new(0.24, 0.32, 0.2) } }, Bits = {
			{ Part = "Head", Offset = Vector3.new(0, -0.08, -0.53), Size = Vector3.new(0.16, 0.24, 0.12) }, { Part = "Head", Offset = Vector3.new(0, -0.2, -0.57), Size = Vector3.new(0.1, 0.04, 0.04), Neon = true } } },
		Core = { Fit = { { Part = "UpperTorso", Offset = Vector3.new(0, 0.05, -0.5), Size = Vector3.new(0.85, 0.8, 0.26) } }, Bits = {
			{ Part = "UpperTorso", Offset = Vector3.new(0, 0.05, -0.5), Size = Vector3.new(0.9, 0.8, 0.12) }, { Part = "UpperTorso", Offset = Vector3.new(0, 0.05, -0.56), Size = Vector3.new(0.22, 0.22, 0.05), Neon = true } } },
		LeftArm = { Shell = { "LeftUpperArm", "LeftLowerArm", "LeftHand" }, Bits = { { Part = "LeftLowerArm", Offset = Vector3.new(0, 0.45, 0), Size = Vector3.new(1.1, 0.08, 1.1), Neon = true } } },
		RightArm = { Shell = { "RightUpperArm", "RightLowerArm", "RightHand" }, Bits = { { Part = "RightLowerArm", Offset = Vector3.new(0, 0.45, 0), Size = Vector3.new(1.1, 0.08, 1.1), Neon = true } } },
		LeftLeg = { Shell = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }, Bits = { { Part = "LeftLowerLeg", Offset = Vector3.new(0, 0.45, 0), Size = Vector3.new(1.1, 0.08, 1.1), Neon = true } } },
		RightLeg = { Shell = { "RightUpperLeg", "RightLowerLeg", "RightFoot" }, Bits = { { Part = "RightLowerLeg", Offset = Vector3.new(0, 0.45, 0), Size = Vector3.new(1.1, 0.08, 1.1), Neon = true } } },
	},
	Accent = {
		ReflexOptic = Color3.fromRGB(255, 170, 60), TargetingLens = Color3.fromRGB(255, 60, 60), AudioPickup = Color3.fromRGB(90, 220, 200),
		EchoArray = Color3.fromRGB(120, 160, 255), ChemSniffer = Color3.fromRGB(170, 230, 80), BloodTracer = Color3.fromRGB(200, 30, 40),
		NeuralCore = Color3.fromRGB(140, 120, 255), OverclockCore = Color3.fromRGB(255, 90, 30), PlatedCore = Color3.fromRGB(200, 200, 190),
		ServoArm = Color3.fromRGB(255, 190, 90), ArcGauntlet = Color3.fromRGB(80, 200, 255), StriderLeg = Color3.fromRGB(120, 255, 170), PistonLeg = Color3.fromRGB(255, 220, 120),
	},
	DefaultAccent = Color3.fromRGB(80, 200, 255),
}
-- Senses (client): ears put pips on a ring for moving bodies you cannot see; the nose marks loot and wounded bodies.
Config.Senses = {
	Tick = 0.15, MoveSpeed = 6, RingScale = 0.16, PipSize = UDim2.fromOffset(18, 6), HearColor = Color3.fromRGB(235, 225, 200),
	ScentTick = 0.5, ScentColor = Color3.fromRGB(170, 230, 80), BloodColor = Color3.fromRGB(200, 30, 40), WoundedBelow = 0.5, MarkerSize = UDim2.fromOffset(10, 10),
}
-- The machine voice's look in chat (client; the words come from shared/Voice.lua)
Config.Voice = { NameColor = "#8FA3AD", TextColor = "#C9D6DC", BubbleText = Color3.fromRGB(200, 220, 228), BubbleBackground = Color3.fromRGB(24, 30, 34) }

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
	-- hostile group behaviour and movement (server/NPCs.lua, ported from combat-feel's Enemies.AI)
	AI = {
		Tick = 0.15, -- seconds between decisions
		Repath = 0.6, -- seconds between path recomputes while chasing
		RepathMove = 6, -- or sooner, when the target moved this far
		WaypointReach = 3.5, -- studs to consider a waypoint reached
		StuckSeconds = 1.5, -- no progress for this long -> recompute (and jump)
		AgentRadius = 2.5,
		AgentHeight = 5.5,
		MeleeAttackers = 1, -- melee bodies allowed to wind up / strike at one target at once
		SwingGap = 0.3, -- seconds after a strike before the next body may start its wind-up
		HoldGap = 5, -- studs outside its reach a waiting body holds
		CircleSpeed = 0.5, -- radians/s a waiting body drifts around you
		Spread = 7, -- studs: waiting bodies closer than this push apart
		SpreadPush = 0.25, -- radians per tick they push
		Leash = 110, -- studs from its spawn a hostile gives up a chase and walks back
	},
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

-- the world north of the city wall (shared/Frontier.lua, server/Frontier.lua)
Config.Frontier = {
	Cap = 80, -- frontier post guards alive at once (checkpoints + sites), on top of the city's population
	Respawn = 240, -- seconds before a dead guard returns to its post
	Refill = 600, -- seconds before an emptied site container is restocked
	CheckpointReach = 45, -- studs from a checkpoint that counts as reaching it
	DiscoverRadius = 150, -- studs from a site that marks it on your map for good
	Seed = 0, -- 0 = a new layout every server; any other number = always that layout
	AmbushRadius = 70, -- studs from a cell's centre that springs its ambush
	AmbushRest = 300, -- seconds before a sprung ambush can spring again
	PatrolLeg = 12, -- seconds between a patrol's waypoints
	WakeRadius = 420, -- a patrol, nest or bounty stands up once someone is this close to its cell
	SleepSeconds = 90, -- with nobody within twice WakeRadius for this long, a woken encounter stands down
	EncounterCap = 40, -- encounter bodies (patrols, nests, bounties, ambushes) alive at once
	RivalCrews = 2, -- crews of rival conduits walking between the sites (server/Terminal.lua: their intel)
	RivalCrewSize = 3,
	RivalLeg = 45, -- seconds a crew walks toward its next site before picking the one after
}

-- the cycle (server/Cycle.lua): period and warning are Config.Destruction.CycleSeconds/CycleWarning
Config.Cycle = {
	FlickerSeconds = 5, -- colour drains for this long before the white-out
	WhiteoutSeconds = 1,
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

-- How a body moves (client/Movement.lua, ported from Roblox's Platformer template). Accelerations are
-- how fast the move direction turns toward the input, per second, on a 0-1 scale: lower = heavier.
Config.Movement = {
	Gravity = 160, -- Workspace.Gravity (Roblox default 196.2); set by the server at startup
	JumpHeight = 8, -- studs; cybernetic legs multiply it (Gear JumpMult)
	DoubleJumpScale = 1, -- the double jump reaches this share of the jump height
	JumpCooldown = 0.15,
	CoyoteTime = 0.15, -- seconds after leaving a ledge that still count as grounded for a jump
	GroundAcceleration = 20,
	AirAcceleration = 15,
	LadderAcceleration = 20,
	-- the dodge (Q): a roll on the ground, a dash in the air (once per airtime)
	RollSpeed = 60, RollTime = 0.35, RollForceFactor = 1500,
	DashSpeed = 60, DashTime = 0.2, DashForceFactor = 1500,
	-- jump within this long after a roll starts = a long jump; flying into a wall stuns you
	LongJumpWindow = 0.3, LongJumpSpeed = 60, LongJumpHeight = 7, LongJumpForceFactor = 1500,
	WallCheckRadius = 1,
	StunBounceSpeed = 25, StunBounceHeight = 3, StunForceFactor = 1500, RecoverTime = 0.5,
	-- lean into movement (degrees)
	LeanRoll = 15, LeanPitch = 5, LeanSpeed = 10,
	AnimFade = 0.1,
	-- Roblox's own animations from the Platformer template
	Anims = {
		Roll = "rbxassetid://14181171022",
		Dash = "rbxassetid://14145234694",
		LongJump = "rbxassetid://14181783061",
		Stun = "rbxassetid://14181937710",
		Recover = "rbxassetid://14182254720",
	},
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
