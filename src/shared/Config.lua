-- Central tuning file. Every number a designer will want to tweak lives here.
local Config = {}

Config.Phases = { Prologue = "Prologue", Open = "Open" }

-- Friend-testing mode: short prologue, the test arena is built (with armory, trainer and
-- dummies). Set Enabled = false for a real release.
Config.Dev = {
	Enabled = true,
	PrologueSeconds = 15, -- only used when Config.Tutorial.Enabled = false
	ArmoryPoints = 10, -- attribute points the arena instructor hands out per use
	PrologueMinSeconds = 8, -- Dev: the floor on the wait after everyone is ready (release uses Config.PrologueMinSeconds)
	ArenaOffset = Vector3.new(0, 0, -820), -- the dev arena sits south (-Z) of District 1, between the city and the hideout; north is the open world
	SpawnInArena = false, -- true = the arena's pads are also CitySpawns (spawn there for armory testing)
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

-- Open world. District 1 is generated at boot (shared/District.lua + server/District.lua) and tags
-- its own CitySpawn pads; tag more SpawnLocation-like parts "CitySpawn" in Studio to add spawns.
Config.CityFallbackRadius = 300
Config.CityFallbackHeight = 10

-- Universe 2 prototype: "the Range" (server/Range.lua), a first-person shooter zone built in this
-- place at Origin, entered through a Rift in Relay Plaza. Split into its own place once it is fun.
Config.Range = {
	Origin = Vector3.new(1400, 0, 0),
	UnlockKills = 1, -- Rift opens after this many kills (and Awakened); Config.Dev.Enabled bypasses
	RiftPlaza = Vector3.new(0, 2, 22), -- the Rift's spot in Relay Plaza (world)
	Loadout = { "ArcRifle" }, -- granted on first entry
	DeployCells = 4, -- the war's basic kit tops your Arc Cells up to this on every deploy
	Targets = { Distances = { 20, 40, 60, 80, 100 }, Health = 40, ResetSeconds = 3, LaneSpacing = 12 },
	Waves = { { Gunner = 2 }, { Gunner = 2, Drone = 2 }, { Gunner = 3, Drone = 3 } },
	WaveRing = 44, -- studs from the arena centre where a wave spawns
	WaveRewardScrap = 10,
	WaveRewardMoney = 25, -- the war pays money (Phase 3 wallet); scrap stays for the city loop
	EntryProtection = 4, -- seconds of ForceField after travelling
}

-- Phase 3 (design/phase-3-brief.md): the hideout between the worlds, extraction hubs, the wallet.
Config.Hideout = {
	Origin = Vector3.new(0, 0, -1400), -- a private room offset from the city; the swap point between worlds
	Size = 90, -- studs square
	ExtractSeconds = 4, -- hold X at a hub this long to extract
	TravelProtection = 4, -- seconds of ForceField after any world change
	Hubs = { Line = 2, FromEdge = 30 }, -- one station per district: on street line Line, FromEdge studs in from the south edge
	NoExtractInCombatSeconds = 6, -- hit a player (or been hit) this recently: the train will not take you
}

-- The war world's sides. Players pick one at the hideout; AI recruits fill every side. Switching
-- costs money and is not instant, so sides stay populated.
Config.War = {
	Factions = {
		{ Id = "Ashen", Name = "Ashen Compact", Color = Color3.fromRGB(255, 120, 60), Motto = "What burns, belongs to us." },
		{ Id = "Meridian", Name = "Meridian Union", Color = Color3.fromRGB(80, 170, 255), Motto = "Order is the only shelter." },
		{ Id = "Hollow", Name = "Hollow Court", Color = Color3.fromRGB(190, 110, 255), Motto = "Nothing left to lose." },
	},
	SwitchCost = 50, -- money to change sides once you have one
	-- Wardogs (design/gdd/war.md): a perpetual three-sided ticket battle over a moving hill, fought in
	-- the Range's arena until the war world is its own place. Every number is tuning.
	Tickets = 150, -- per side at the start of a round
	DeathTickets = 1, -- a side loses this many when one of its recruits (AI or player) dies
	HillDrainSeconds = 2, -- the side holding the hill costs each other side one ticket this often
	HillRadius = 16,
	CaptureSeconds = 12, -- uncontested seconds to flip the hill to your side
	HillMoveSeconds = 90, -- the hill moves on its own after this long...
	HillMoveOnCapture = true, -- ...or right after a capture
	HillPoints = { Vector3.new(0, 0, 0), Vector3.new(60, 0, -40), Vector3.new(-60, 0, -40), Vector3.new(0, 0, 50), Vector3.new(55, 0, 35), Vector3.new(-55, 0, 35) }, -- relative to the arena centre
	Bases = { Vector3.new(0, 0, 95), Vector3.new(-85, 0, -55), Vector3.new(85, 0, -55) }, -- one per side, relative to the arena centre
	-- AI recruits (Enemies.Defs.Recruit): pods re-enter at the base, the cloning facility trickles more
	Squad = 3, -- recruits per pod
	MaxRecruitsPerSide = 6,
	PodIntervalSeconds = 25,
	PodHeight = 140, -- studs above the base the pod appears at
	PodFallSeconds = 2.2,
	CloneIntervalSeconds = 18, -- the facility adds one recruit this often while under the cap
	-- recruits (AI) move on the hill when they have nobody to shoot
	-- downed players: an ally can revive, or you bleed out and redeploy from your base
	DownedSeconds = 20,
	ReviveSeconds = 2.5, -- hold X on a downed ally
	ReviveHealthFraction = 0.4,
	RedeploySeconds = 5, -- after bleeding out / dying
	-- pay (money): zone time, revives, takedowns
	MoneyPerZoneSecond = 1,
	MoneyPerRevive = 15,
	MoneyPerTakedown = 10,
	MoneyPerPlayerTakedown = 30,
	MoneyRoundWin = 60,
}

-- Supply (design/gdd/war.md §6, Phase 3 build order 3): conduits feed the war two ways. The faction
-- POOL (donated stash → points) decides the kit every AI recruit of that side spawns with; fielding
-- recruits spends it, so a side nobody supplies falls back to the basic kit. SHIPMENTS are your own
-- stash gear sent ahead: a crate lands at your base after a delay; open it and you fight with it —
-- die and it stays on the field, walk out and it goes back to the stash.
Config.Supply = {
	Value = { Material = 1, Consumable = 3, Weapon = 12, Armor = 10, Cybernetic = 15, Part = 8, Ammo = 1, Device = 15, Fragment = 1 }, -- pool points per donated item by Items.Defs[*].Type
	CostPerRecruit = 3, -- points a side spends for every recruit it fields (attrition drains the pool)
	Tiers = { -- in order; the highest tier whose Points the pool reaches is the kit (checked at spawn)
		{ Name = "Basic", Points = 0, HealthMult = 1, Resist = 0, DamageMult = 1 },
		{ Name = "Armed", Points = 60, HealthMult = 1.25, Resist = 0.08, DamageMult = 1.1, Helm = true },
		{ Name = "Plated", Points = 200, HealthMult = 1.5, Resist = 0.16, DamageMult = 1.2, Helm = true, Plate = true },
	},
	ShipmentSeconds = 45, -- the crate lands this long after you send it (wall clock, survives a rejoin)
	ShipmentMax = 6, -- items per shipment (weapons, armor, cybernetics, consumables - never materials)
	CrateHeight = 120,
	CrateFallSeconds = 2,
	CrateOpenSeconds = 1.5, -- hold X
}

-- The weapon bench (design/gdd/gunplay.md §4, Phase 3 build order 4): strip a gun to the frame and
-- rebuild it from parts (shared/Attachments.lua). Only at the hideout's workbench.
Config.Bench = {
	Zone = "Hideout", -- the player's Zone attribute the bench answers in
}

-- Places (Phase 3, build order 7; server/Travel.lua): the hideout, the Conduit world and the war as
-- separate places. Off until the places exist: with Enabled = false (or an id of 0) every trip is a
-- pivot inside this place. Set the published place ids and flip Enabled; nothing else changes.
Config.Places = {
	Enabled = false,
	Ids = { Hideout = 0, Conduit = 0, War = 0 },
}

-- Destruction (design/gdd/destruction.md; server/Destruction.lua, kinds in shared/Destruction.lua).
Config.Destruction = {
	PropsPerDistrict = 26, -- crates, barrels, signs, fences, terminals on the streets (never the plaza)
	PropsOnRoad = 10,
	Seed = 20261027, -- where the props stand: the same every cycle (authored, in effect)
	HeavyMult = 1.5, -- a heavy hits a prop this much harder
	ChunkSettleSeconds = 3, -- loose chunks freeze in place after this long
	ChunkCap = 150, -- loose gameplay chunks in the world; past it the oldest go
	ChunkImpulse = 18, -- studs/s outward from the hit
	SalvageHold = 1.2, -- seconds to hold X on salvage remains
	-- grab and throw (server/Grab.lua; destruction.md §4.5, §5): G grabs, hold G and let go to throw
	Grab = {
		Range = 8, GrabSeconds = 0.2, MaxCharge = 0.8, -- seconds of hold for a full charge
		ChargeSpeed = 0.6, SpeedPerStrength = 0.01, DamageExponent = 1.2, StaminaPerWillpower = 0.005,
		MinFlight = 4, -- studs before a throw can hit anyone (no point-blank spam)
		FlightSeconds = 2,
		LightVolume = 8, MediumVolume = 40, -- chunk volume (studs^3) up to which it is Light / Medium; above, Heavy
		Classes = {
			Light = { Grabbable = true, Speed = 75, Lift = 6, Damage = 12, Posture = 10, Knockback = 18, Stamina = 10 },
			-- ArmsNeeded: cybernetic arms with Lift that let you pick this class up anyway (shared/Cybernetics.lua)
			Medium = { Grabbable = false, ArmsNeeded = 1, Speed = 55, Lift = 9, Damage = 22, Posture = 20, Knockback = 30, Stamina = 18 }, -- story 004
			Heavy = { Grabbable = false, ArmsNeeded = 2, Speed = 35, Lift = 10, Damage = 40, Posture = 40, Knockback = 45, Stamina = 30 }, -- story 004
		},
	},
}

-- The Autonet (server/Autonet.lua; design/gdd/dematerialization.md §6): cybernetics are ripped in, and it hurts.
Config.Cyber = {
	RipSeconds = 4, -- one rip (a swap is two)
	RipHealthCost = 0.35, -- share of max health per rip, paid up front; never below 1 HP
	Range = 12, -- studs from the Autonet
}

-- The cycle (design/gdd/dematerialization.md; server/Cycle.lua): every Seconds the Conduit world comes
-- apart and is restored exactly. Starts when the world opens. Only player / enemy spawns, contact spots and
-- loot are re-drawn; profiles, the hideout and the war are never touched.
Config.Cycle = {
	Seconds = 3600,
	WarningSeconds = 60, -- the hum rises and lights flicker
	FlickerSeconds = 5, -- the colour drains
	WhiteoutSeconds = 1, -- the world is gone; everything is cleared and redrawn
	Seed = 20261026, -- cycle n draws from Random.new(Seed + n)
	GuardJitter = 0.06, -- road guards move up to this fraction of the road's length from their authored spot
	-- what the cycle never touches (besides profiles): positions inside these
	Exclude = {
		HideoutMargin = 30, -- studs past the hideout room's edge
		RangeRadius = 450, -- around Config.Range.Origin: the war and the range
		AboveY = 1000, -- the prologue plots
	},
}

-- Transport (design/gdd/world.md, server/Transport.lua): the lines between regions.
Config.Transport = {
	UnlockRadius = 16, -- stand this close to a hub once and it is yours
	BoardSeconds = 3, -- the wait on the platform (protected) before the ride
	Protection = 4, -- seconds of ForceField on arrival
}

-- Momentum & cancels (design/gdd/momentum.md): the Nero-study layer on top of the timing core.
Config.Momentum = {
	SideIFrameMult = 1.3, -- side dodges (|dot(dir, look)| < 0.5) get this much more i-frame time
	HopRefund = 10, -- stamina back when a dodge's i-frames absorb a hit
	PullTime = 0.25, -- seconds a Snatch takes to bring the target in
	PullStun = 0.6, -- hit-stun on a snatched target
	PullStop = 3, -- studs from the user the target lands
	GrabStunWindow = 1.5, -- a posture break this recent still counts as "open" for Buster
	-- Launcher + juggle (momentum.md 2.5). A melee heavy on an *open* enemy (stunned / just
	-- posture-broken) launches it: it is Juggled (helpless, stunned until it lands) and every hit
	-- while airborne pops it back up and deals bonus damage. Players and flyers are never launched.
	LaunchVelocity = 70, -- studs/s up (~12 studs of height, ~0.7 s of hang)
	LaunchDrift = 8, -- studs/s away from the attacker
	LaunchAirTime = 0.8, -- seconds the target counts as Juggled after a launch
	AirDamageMult = 1.35, -- damage multiplier against a Juggled target
	AirPopVelocity = 32, -- upward studs/s each hit gives a Juggled target
	AirPopExtend = 0.3, -- seconds each pop adds to the juggle
	MaxJuggleHits = 4, -- pops stop after this many hits (gravity wins; no infinite juggles)
	LandStun = 0.45, -- hit-stun after the juggle ends (the get-up)
	-- Enemy Step: a dodge pressed next to a Juggled enemy springs off it.
	EnemyStepRange = 9, -- studs from the airborne enemy
	EnemyStepRefund = 12, -- stamina back (the dodge itself still costs DodgeCost)
	EnemyStepHop = 34, -- extra upward studs/s on that dodge
}

-- Gunplay (design/gdd/gunplay.md): the Range's shooting rules. Per-weapon numbers live in
-- Weapons.Defs[id].Gun; these are the shared ones.
Config.Gunplay = {
	-- hit zones: multiplier by the body part the shot lands on (R15 part names; Default for anything else)
	Zones = { Head = 2.0, UpperTorso = 1.0, LowerTorso = 1.0, HumanoidRootPart = 1.0,
		LeftUpperArm = 0.7, LeftLowerArm = 0.7, LeftHand = 0.6, RightUpperArm = 0.7, RightLowerArm = 0.7, RightHand = 0.6,
		LeftUpperLeg = 0.75, LeftLowerLeg = 0.7, LeftFoot = 0.6, RightUpperLeg = 0.75, RightLowerLeg = 0.7, RightFoot = 0.6, Default = 1.0 },
	HeadshotStaggers = true, -- a headshot always breaks poise
	-- spread added to the weapon's own (degrees of cone half-angle), by the shooter's state
	Spread = { Moving = 1.2, Sprinting = 3.0, Airborne = 2.0, ADSSettle = 0.15 }, -- ADSSettle: seconds after raising the sights before ADS spread counts
	DefaultGun = { Magazine = 10, Reload = 1.5, Spread = { Hip = 3, ADS = 0.5 }, Recoil = { Pitch = 1.2, Yaw = 0.4, Recover = 7 } },
	-- Arc Cells (design/gdd/destruction.md §4.4a; owner: "all weapons are consistent"): a reload refills the
	-- magazine from one cell; no cell, no reload. Players and NPCs alike; NPC gunners carry a few (NpcCells
	-- {min, max}) and fight with their hands once they are out.
	CellItem = "ArcCell",
	CellsPerReload = 1,
	NpcCells = { 1, 3 },
	ReloadKey = Enum.KeyCode.R, -- client: manual reload (an empty-magazine shot reloads on its own)
}

-- Sprint: hold the key to run. Drains stamina; blocking cancels it; attacks still work (the swing
-- stops you anyway).
Config.Sprint = {
	Mult = 1.45, -- walk speed multiplier
	StaminaPerSecond = 8,
	MinStamina = 6, -- sprint ends below this
	FovBoost = 6, -- client: extra field of view while running
}

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
	BaseJumpPower = 50, -- x Gear JumpMult (piston legs); both set so either humanoid jump mode works
	BaseJumpHeight = 7.2,
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
	SetSkill = 4, Allocate = 10, UseItem = 4, EquipItem = 4, Unequip = 4, Craft = 4, TutorialSkip = 1, SetAppearance = 10, Sprint = 6, Reload = 4, ADS = 8, Bench = 6, Buy = 4, Terminal = 6, Autonet = 4, Grab = 6,
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
	AimCone = 55, -- degrees: a client-sent aim direction for a ranged shot may differ from the body's facing by at most this (yaw)
	AimMaxPitch = 80, -- degrees up/down
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
