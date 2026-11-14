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
	-- the arrival (server/Tutorial.lua, server/Subway.lua): each new conduit's own station, off the map
	Origin = Vector3.new(0, 2600, 6000),
	Spacing = 1200,
	IntroTimeout = 75, -- the server ends the train ride itself if the client never reports it done
	CheckpointRadius = 12,
	CleanupSeconds = 12,
	KitWeapon = "Whisper",
	Kit = { Whisper = 1, Round22 = 21 }, -- three magazines of .22: the guards carry none of it (darts and bolts: crafted, or off the guards)
	Locker = { RebarBlade = 1, ScrapVest = 1, Medkit = 2, Round22 = 28, Round22Emp = 8, Scrap = 4 },
	Manifest = { Name = "LINE 9 MANIFEST", Text = "INBOUND: 1 . OUTBOUND: 0\nCARGO: STACK HARDWARE, 40 CRATES\nDELIVERY: FREIGHT LIFTS, CITY BAYS 01-12\nCONSIGNEE: WHOEVER SIGNS\nNOTE: NOTHING ON THIS LINE COMES BACK DOWN." },
}
-- Stealth (server/Stealth.lua, shared/Stealth.lua): light-level hiding, noise, guard awareness, takedowns.
-- Exposure 0..1 = the level's ambient plus every lit StealthLight that can see you (falloff by distance, blocked by
-- walls). A guard's sight range shrinks in the dark; crouching hides you more and silences your steps.
-- The way down (server/Barrens.lua; canon docs/LORE.md "The corporations and the underground"): a service shaft in
-- the Sumps plaza drops to a barrens hall under the city, where the brain slaves work their stations. One shared level.
Config.Barrens = {
	Enabled = true,
	Head = Vector3.new(1105, 2, -1245), -- the shaft head on the Sumps plaza (ground top)
	Origin = Vector3.new(6000, -300, 0), -- the level (floor of the shaft foot); above FallenPartsDestroyHeight (-500)
	DescendHold = 1.5,
	ClimbHold = 1.2,
	FadeSeconds = 0.8, -- the client's black before the drop
	Rows = 3, PerRow = 6, -- stations in the hall
	UnhookHold = 2.5,
	UnhookDamage = 30, -- the kick back through the conduit's own link
	UnhookNoise = 40,
	ScreenEvery = 2.5, -- seconds between output readings on the screens
	Ambient = 0.05,
}

Config.Stealth = {
	Tick = 0.1, -- guard brains and noise
	ExposureTick = 0.2,
	Ambient = 0.06, -- a stealth level's floor light (the level folder's "Ambient" attribute wins)
	FlashlightExposure = 0.95, -- caught in a guard's torch beam
	CrouchVisibility = 0.72, -- crouched, a guard's sight range is multiplied by this
	CrouchSpeedMult = 0.5,
	SightRange = 62, -- studs at full light
	DarkSight = 0.1, -- share of SightRange left in total darkness
	SightFOV = 105, -- degrees, whole cone; Alert/Search widen it
	SearchFOV = 150,
	Bump = 2.8, -- studs: walking into a guard is noticed whatever the light
	FillRate = 1.5, -- awareness per second at point blank in full view
	SearchFill = 1.6, -- multiplier while the guard is searching (it is looking for you)
	Decay = 0.22, -- awareness lost per second out of sight
	SuspectAt = 0.3, -- awareness where the guard stops and turns to look
	SuspectWalk = 0.6, -- ...and starts walking over
	AlertLose = 6, -- seconds out of sight before an alerted guard falls back to searching
	SearchSeconds = 14,
	CallRadius = 48, -- an alerted guard calls the others within this
	PatrolSpeed = 6, SearchSpeed = 9, SuspectSpeed = 4,
	PostTurn = 0.08, -- how fast a standing guard turns back to its post (alpha per tick)
	Noise = { Sprint = 24, Walk = 9, Crouch = 0, Whistle = 22, Glass = 18, Melee = 20, Breaker = 10 },
	-- any small light in the world a round can put out (Stealth.ShootOut): the lit part at most MaxSize studs long,
	-- or one of the same model within Reach of where the round hit (its housing)
	ShootOut = { MaxSize = 8, Reach = 2 },
	StepNoiseAwareness = 0.9, -- awareness per second from hearing your steps (no sight needed)
	WhistleCooldown = 3,
	BodyAlarm = true, -- a guard that sees a downed one goes searching and calls the rest
	-- how guards find their way: agent size for the route planner, when to plan again, and the fuse box errand
	Path = { Radius = 1.5, Height = 5.5, Spacing = 4, Reach = 2, Replan = 3, Refresh = 6, Stuck = 1.2, FixWalk = 140, FixSeconds = 40 },
	FixDelay = 4, -- seconds a guard spends at a cut breaker before the lights come back
	Takedown = {
		Reach = 5.5, -- studs from the guard
		BehindDot = -0.2, -- guard facing . (guard -> you) below this = behind it
		DropMin = 4.5, DropMax = 22, DropReach = 9, -- from above: height window and how far off to the side
		EnvReach = 7.5, -- a TakedownSpot this close to the guard turns the takedown into it
		Seconds = { Rear = 1.7, Drop = 1.1, Panel = 1.9, Rail = 1.7, Ledge = 1.5 },
		RearDistance = 1.5, -- studs behind the guard the attacker is stood, square to its back (the animations are fitted to this)
		Fall = { Rear = 0.9, Drop = 0.8, Panel = 0.6, Rail = 0.6, Ledge = 0.6 }, -- how far ahead the body lies (the animations' last key)
		Noise = { Rear = 0, Drop = 7, Panel = 14, Rail = 12, Ledge = 8 },
		IFrames = 2,
	},
	DownSeconds = 0, -- 0 = a downed guard stays down (the subway); the open world sets its own
	-- Metal Gear handling (owner, 2026-11-11). Stances: C tap = crouch, hold C = prone, sprint + C = dive, Space = up one.
	Stance = {
		ProneSpeedMult = 0.22, -- crawl
		ProneVisibility = 0.45, -- prone, a guard's sight range is multiplied by this...
		ProneDark = 0.3, ProneDarkVisibility = 0.4, -- ...and by this again while your exposure is under ProneDark
		ProneHold = 0.3, -- seconds C is held for prone
		Dive = { Speed = 34, Seconds = 0.45 }, RollSpeed = 22, RollSeconds = 0.4, RollCooldown = 0.7,
		CameraDrop = { Crouch = -1.3, Prone = -2.3 },
	},
	-- Aiming a gun (hold RMB): slower, tighter, over the shoulder; V looks down the sights.
	Aim = { SpeedMult = 0.55, Distance = 4.5, Fov = 55, SightFov = 48, ShoulderOffset = Vector3.new(1.6, 0.55, 0),
		-- the upper body bends at the waist so the gun points at what the reticle is on (degrees; Rate = how fast it follows,
		-- GunHeight = where the gun sits above the root while aiming)
		Pitch = { Max = 55, Rate = 18, GunHeight = 1.8 } },
	-- A guard that has not made you and finds a gun on him up close freezes with his hands up.
	HoldUp = { Range = 13, Cone = 14, Keep = 5, Grace = 0.35 }, -- studs, degrees off your aim, seconds he stays frozen after the gun leaves him, seconds on him first
	-- CQC on X. Tap in front or beside: a throw (he is out for Down seconds, then gets up and searches).
	-- Hold behind: a neck hold you can walk with; X chokes him out (he stays down), G throws him down.
	Cqc = {
		Throw = { Reach = 5, Seconds = 1.1, Down = 25, Noise = 9, Stand = 1.5, Fall = 1.4, Side = 1.3,
			-- he leaves your hands with real speed, the way you look (owner, 2026-11-12: "the throw should have some
			-- real velocity, i tried to throw a guard into the wall and he fell to the floor"). Release = the share
			-- of Seconds at which he is let go; Speed / Lift in studs a second; Radius = his body in the sweep.
			Release = 0.55, Speed = 44, Lift = 9, Radius = 0.9, MaxSeconds = 1.2,
			-- into a wall faster than Slam.Speed: hurt, down for longer, and loud. Into another guard: both go down.
			Slam = { Speed = 16, Damage = 45, DownMult = 2, Noise = 16 } }, -- Fall/Side = where he lands (the animation's last key)
		Hold = { Seconds = 12, SpeedMult = 0.45, Gap = 0.95, Press = 0.3 }, -- he breaks free after Seconds; Press = how long X is held to grab
		-- dragging a body by the collar: Ahead = studs in front of you the hands hold it, Collar = from the hands to his
		-- hips, Length = from the hands to his feet (the body trails that far)
		Carry = { Reach = 5, SpeedMult = 0.75, Ahead = 1.2, Collar = 1.7, Length = 4.8 },
	},
	-- The wall (Q with a gun out): back to it; hold RMB at its end to lean out and aim.
	Cover = { Reach = 3.2, Stand = 1.05, Step = 1.9, SpeedMult = 0.5, EdgeProbe = 2.2 },
	-- Round 4 of docs/Reference-Picks-Plan.md (stealth):
	-- the moment a guard makes you he freezes for Reflex seconds before he shouts (take him now and nobody hears)
	Reflex = 1.0,
	-- a sleeping dart (.22 Sleep): he staggers, looks for you, and goes down after Delay (at once in the head);
	-- he sleeps Seconds, then wakes and searches
	Sleep = { Delay = 3.5, Seconds = 75 },
	-- a thrown bolt (key 3): where it lands it clatters, and the guards who hear it go to look
	Bolt = { Speed = 70, Seconds = 2.5, Noise = 26, Lifetime = 20 },
	-- lockers and crawl spaces (X): inside, a guard only finds you if he comes right up to it while searching and
	-- the level is on its toes (Adapt.CheckHiding)
	Hide = { Reach = 6, Find = 4 },
	-- clothes: Conceal takes a share off your exposure; a Disguise passes at a distance (awareness fills at Fill
	-- beyond Close studs, until he is on alert)
	Disguise = { Close = 9, Fill = 0.15 },
	-- guards who adapt: every alarm in a level adds to its Alarms count (to Max); each one sharpens sight and the
	-- fill, and from CheckHiding on, searching guards open the lockers
	Adapt = { Sight = 0.12, Fill = 0.15, Max = 3, CheckHiding = 1 },
	-- questioning a held guard (E during the neck hold): what he gives up shows for Seconds
	Question = { Seconds = 20, Reach = 160 },
	-- shifts: at the hour, this share of the posted guards below the city are asleep at their posts; noise wakes them
	Shift = { SleepShare = 0.35, WakeNoise = 0.5 },
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
	LaunchAirTime = 1.5, -- seconds the target counts as Juggled after a launch (long enough for two hits and a step)
	LaunchGrace = 0.6, -- a heavy launches if you *start* it while the target is staggered or up to this long after
	LaunchHold = true, -- starting that heavy keeps the open target staggered until it lands
	LaunchHoldReach = 1, -- studs past the heavy's range a target can be and still be held
	AirDamageMult = 1.35, -- damage multiplier against a Juggled target
	AirPopVelocity = 18, -- upward studs/s each hit gives a Juggled target (it is floating: a little goes far)
	AirPopExtend = 0.5, -- seconds each pop adds to the juggle
	MaxJuggleHits = 5, -- pops stop after this many hits
	-- hang: past the top of the launch a juggled body floats down on HangGravity of normal gravity, so it lingers
	-- in front of you instead of dropping straight out of the combo
	HangBelow = 16, -- studs/s: the float starts once the body rises slower than this
	HangGravity = 0.2,
	-- group launch: a Medium or Heavy weapon's launcher throws up every hostile within this many studs of the
	-- impact point (Weapons Mass), not just the one it hit
	GroupLaunch = { Medium = 6, Heavy = 10 },
	LandStun = 0.45, -- hit-stun after the juggle ends (the get-up)
	EnemyStepRange = 9, -- studs from the airborne enemy a dodge springs off it
	EnemyStepRefund = 12, -- stamina back
	EnemyStepHop = 34, -- minimum upward studs/s on that dodge
	-- Enemy Step carries you up to the juggled body's height, StepFront studs in front of it, holds you there for
	-- StepHover seconds (facing it) and keeps it up StepExtend seconds longer: room for two more hits
	StepFront = 3.5, StepHover = 0.7, StepExtend = 0.45, StepMaxRise = 22,
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
		ServoArm = Color3.fromRGB(255, 190, 90), ArcGauntlet = Color3.fromRGB(80, 200, 255), BreakerArm = Color3.fromRGB(255, 70, 40), CableArm = Color3.fromRGB(230, 230, 120), StriderLeg = Color3.fromRGB(120, 255, 170), PistonLeg = Color3.fromRGB(255, 220, 120),
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
	-- first person (P, or V while aiming). Offsets are from Roblox's own eye, CameraBase above the body's root
	-- (shoulder height on the Conduit body; the head's middle is 2.29 up, measured on a real server).
	FirstPerson = {
		CameraBase = 1.5,
		Eye = Vector3.new(0, 0.82, -0.15), -- in the head, a little forward
		SightAbove = 0.07, SightBack = 0, -- aiming: this far above the top of the gun
		EyeRate = 14, -- how fast the eye goes between the two
		-- a melee weapon at rest is held up in view: the hand from the right shoulder, and the way the weapon runs
		Rest = { Hand = Vector3.new(-0.2, 0.45, -1.45), Blade = Vector3.new(-0.3, 0.85, -0.42), Fist = Vector3.new(0.45, 1.7, -1.2) },
	},
}

-- HUD v2 (client, ported from combat-feel): bottom-centre bars, floating words, reticle, damage vignette, nameplates.
Config.Hud = {
	BarWidth = 480,
	VitalsHold = 4, -- seconds the health/stamina/posture block stays up after any bar moves
	VitalsLow = 0.6, -- ...and it stays up while health is under this share
	DamageNumbers = { Life = 0.9, Rise = 3.5, Spread = 1.2, TextSize = 26, HeavyTextSize = 34, HeavyAmount = 20, MaxLive = 24,
		Colors = { Taken = Color3.fromRGB(255, 80, 80), Block = Color3.fromRGB(150, 170, 255), Parry = Color3.fromRGB(255, 255, 255),
			GuardBreak = Color3.fromRGB(255, 160, 0), Dodged = Color3.fromRGB(80, 255, 230) } },
	Reticle = { Size = 6, Gap = 5, Thickness = 2, Color = Color3.fromRGB(235, 235, 240), HitColor = Color3.fromRGB(255, 90, 60), HitSeconds = 0.12, HitScale = 1.8 },
	DamageFlash = { Color = Color3.fromRGB(200, 30, 30), Seconds = 0.35, MaxTransparency = 0.55 },
	Nameplates = { Offset = Vector3.new(-1.2, -0.6, 0), Size = UDim2.fromOffset(120, 16), TextSize = 12,
		Color = Color3.fromRGB(225, 225, 232), NpcColor = Color3.fromRGB(255, 150, 130), FadeStart = 30, FadeEnd = 70 },
}

-- Places (client): no markers through the world; a place's name shows in the top banner as you enter it
-- (districts, regions, sites, marked spots), then not again for BannerCooldown seconds.
Config.Places = { BannerCooldown = 300, BannerSeconds = 4, EnterRadius = 45 }

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
		-- Spacing (ideas from KrugKrew's "best swordfighting ai", 2022): read the player's swing and guard.
		--   Backoff: when you wind up, it may step out of your reach sideways, after a reaction time
		--   Press: your recovery (or a stagger) is its opening; it comes straight in
		--   Strafe: on its own cooldown it circles you instead of standing still
		--   WaitOutBlock: chance it circles your raised guard for a moment instead of swinging into it
		--   Wary: below this share of health it keeps out of reach and only comes in on an opening
		--   RushGive: studs it gives ground (as a sidestep) when you charge it
		-- Hyperarmored bodies (Brute, Warden) only press: they walk through your swings.
		Spacing = {
			DefaultReach = 6, -- your reach when you have not swung yet and your weapon is unknown
			BackoffMargin = 2.5, -- studs outside your reach it retreats to
			StrafeTurn = 0.5, -- radians around you per step while circling
			BlockWait = 1.2, -- longest it circles a raised guard
			TurnResponsiveness = 25, -- how fast it turns to face you while spacing
			Types = {
				Raider = { React = 0.25, Chance = 0.4, Backoff = true, Press = true, Strafe = true, WaitOutBlock = 0.35, Wary = 0.3 },
				Shocker = { React = 0.2, Chance = 0.55, Backoff = true, Press = true, Strafe = true, WaitOutBlock = 0.5, Wary = 0.35, RushGive = 3 },
				Rival = { React = 0.12, Chance = 0.75, Backoff = true, Press = true, Strafe = true, WaitOutBlock = 0.6, Wary = 0.3, RushGive = 2 },
				Brute = { Press = true },
				Warden = { Press = true },
			},
		},
	},
	-- standing hostiles per district Danger (server/Population.lua)
	Population = {
		Cap = 48, -- hostiles alive at once from all sources, before Population stops adding (11 districts since the industrial ring)
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

-- Limbs that break and come off (server/Dismember, client/Limbs). Sever / Break: the share of the body's max health one
-- blow has to take, landing directly on an arm or a leg, by kind of blow. Blades take limbs; blunt weapons break them
-- and only the heaviest blow takes one; bullets only break.
Config.Dismember = {
	Direct = 0.4, -- studs from the limb's box the contact may be (and nearer to it than to the trunk)
	Sever = { Cut = 0.22, Blast = 0.3, Blunt = 0.55 },
	Break = { Blunt = 0.16, Blast = 0.18, Bullet = 0.3, Cut = 0.6 },
	KillBonus = 1.4, -- the blow that kills counts for this much more
	MaxHealth = 400, -- bodies with more health than this keep their limbs (Wardens)
	ArmDamage = 0.55, BrokenArm = 0.75, -- an enemy's damage with an arm lost / broken
	LegSpeed = 0.45, BrokenLeg = 0.65, -- an enemy's speed with a leg lost / broken
	Bleed = { PerSecond = 0.025, Seconds = 14 }, -- share of max health a stump costs an enemy each second
	Piece = { Life = 45, Speed = 13, Lift = 15, Spin = 14, Color = Color3.fromRGB(38, 36, 40) },
	Limp = { Arm = 0.85, Leg = 0.55 }, -- client: how much of the animation a broken arm ignores / a broken leg keeps
}
Config.Gore = {
	BodyCap = 60, -- persistent corpses per server; oldest cleared first
	PoolCap = 80, -- blood pools per client
	PoolLifetime = 90,
}

-- The Front: the war world, a separate place in the same universe. Conduits "tap in" from a
-- Neural Net terminal and control a recruit there. The recruit's gear is the conduit's money.
Config.War = {
	LooseMagazines = 1, -- loose rounds a recruit carries, in magazines' worth (thumbed in by hand: Config.Guns.PerRound)
	PlaceId = 81481823786216, -- the Front place inside the Endeavor experience (universe 10773835758)
	HomePlaceId = 120490278050491, -- Endeavor: where an unlinked conduit goes back to (war/server/Soldiers.lua Unlink)
	UnlinkHold = 2.5, -- seconds holding X at the base locker to unlink
	UnlinkReach = 14, -- studs from your own faction's locker
	GunScale = 0.55, -- the parts are modelled at 0.19 studs an inch, over twice the body's scale: a rifle in the hand is shrunk to this
	BarracksReach = 40, -- within this of your own locker every part of the gun can be changed
	UnlinkCalm = 10, -- no unlinking within this many seconds of being hit
	UnlinkSeconds = 2.5, -- the link closing before the teleport
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
		SectorSize = 200,
		Cols = 7, Rows = 5, -- the front is a Cols (west-east) x Rows grid of sectors; the hill walks it forever
	},
	-- The open world (shared/FrontMap.lua, war/server/Battlefield.lua + WarTerrain.lua): terrain from a seeded layout.
	World = {
		Seed = 0, -- 0 = a new layout every server; set a number to keep one (and to draw it with tools/smoke)
		GroundLevel = 4, -- the mean ground height
		RearDepth = 220, -- studs from the battlefield's edge back to a faction's base
		Margin = 110, -- walkable ground beyond the bases and the north/south edges, before the outer barrows
		EdgeHeight = 80, -- how high the outer barrows rise
		TrenchWidth = 3.5, TrenchDepth = 5.5, -- half width and depth of a trench cut
		CanalWidth = 16, CanalDepth = 8, CanalWater = 2.5, -- the east-west canal: half width, depth, standing water
		Smokestacks = 9, -- on the skyline beyond the outer barrows
		RearCraters = 70, RearDead = 40, RearStumps = 50, -- scattered outside the sector grid (rears and margins)
		-- the fallen calcify: a recruit's body turns to a pale figure where it fell after CalcifySeconds, and every
		-- GrowEvery of them in a sector raises that sector's crest by GrowStuds (up to MaxGrow per server). Past
		-- CalcifiedCap figures in a sector the oldest sinks into the ground.
		CalcifySeconds = 45, GrowEvery = 4, GrowStuds = 0.8, MaxGrow = 12, CalcifiedCap = 30,
	},
	-- Credits: each faction's income per minute per deployed conduit scales with its share of the scales.
	Income = { BasePerMinute = 60, ShareWeight = 1.5 }, -- income = Base * (0.5 + ShareWeight * (share - 0.5)) clamped
	Scales = { StoreName = "WarScales_v1", Decay = 0.0005 }, -- global tickets, decayed each tick so the scales keep tipping
	Death = { PartDamage = 40, ArmorDamage = 60 }, -- condition lost by parts/armor on a recruit's body (recoverable, damaged)
	LootHold = 2,
	RespawnSeconds = 8,
	Artillery = { Cooldown = 120, Shells = 6, Radius = 16, Damage = 110, Spread = 25, Delay = 6 },
	BodyCapPerSector = 12, -- lootable remains per sector (x Cols x Rows)
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
	-- The first link into a recruit (war/server/Intro.lua + Simulation.lua, war/client/IntroFx.lua): the recruit
	-- jolts awake in a stasis tank, the clone's memories sync, the tank drains, the cables unlatch, a chute
	-- drops it into a barracks stocked by its conduit, and a simulation link drops it into a wireframe city
	-- to learn to fight. Built per player in the sky, far off the battlefield.
	Intro = {
		Enabled = true,
		ReplayInDev = true, -- with Config.Dev.Enabled the intro plays on every join and F2 skips a stage (testing)
		Origin = Vector3.new(0, 1500, 0), -- slot 1; slot n sits at Origin + (n - 1) * SlotStep
		SlotStep = Vector3.new(500, 0, 0),
		WakeSeconds = 10, -- the frantic wake-up and the memory sync, before the tank drains
		DrainSeconds = 6,
		UnlatchSeconds = 2.5,
		ChuteSeconds = 5, -- the fall is given this long before the recruit is set down in the barracks
		BarracksSeconds = 150, -- whatever is still on the racks after this is fitted anyway
		LinkSeconds = 3, -- the simulation link (white-out) before the wireframe city
		DoneSeconds = 4, -- the drop out of the simulation onto the Front
		-- what the conduit's supply fills in when the locker does not cover a slot (first-time conduits own
		-- nothing). Issued pieces are the recruit's, not loot: they never drop on the body.
		Issue = {
			Union = { Primary = "M16A1", Sidearm = "M1911", Armor = "FlakVest", Helmet = "Helmet", Magazines = 3, Grenades = 2, Medkits = 1, Sandbags = 3 },
			Pact = { Primary = "AKM", Sidearm = "Makarov", Armor = "FlakVest", Helmet = "Helmet", Magazines = 3, Grenades = 2, Medkits = 1, Sandbags = 3 },
		},
		Sim = {
			Size = 300, -- the simulation floor is Size x Size studs
			Block = 6, -- wireframe city blocks are Block-stud cubes; a recruit can mantle one block high
			BlockHealth = 70,
			BulletBlockDamage = 0.6, -- share of a round's damage a block takes (everything breaks in the simulation)
			CollapseShare = 0.45, -- a building comes down once this share of its ground layer is gone
			TargetHealth = 40,
			Hostiles = 5,
			HostileHealth = 60,
			HostileDamage = 9,
			HostileFireSeconds = 1.4,
			HostileAccuracy = 0.45, -- hit chance at 20 studs; falls off with range and when the recruit sprints
			Artillery = { Shells = 6, Radius = 14, Damage = 140, Spread = 7, Delay = 3, Cooldown = 12 },
			ResupplyBelow = 2, -- spare magazines refill to 4 whenever they drop below this in the simulation
		},
	},
}

-- Front movement (war client): sprint and climbing over ledges. Grounded, first person; the
-- simulation teaches the same moves the Front uses.
Config.WarMovement = {
	WalkSpeed = 14,
	SprintSpeed = 22,
	MantleHeight = 6.6, -- highest ledge (above the feet) a recruit can pull up onto
	MantleReach = 3, -- studs ahead of the chest the ledge must be
	MantleSeconds = 0.38,
	-- Stances (owner, 2026-11-11: crouch and prone, Metal Gear handling in first person). Speed is the walk
	-- speed, Drop lowers the hips (studs; Prone lies on the ground), Spread/Recoil scale the gun, Hit scales
	-- how often the simulation's hostiles connect.
	Stance = {
		Stand = { Speed = 14, Spread = 1, Recoil = 1, Hit = 1 },
		Crouch = { Speed = 8, Drop = 1.1, Spread = 0.72, Recoil = 0.8, Hit = 0.75 },
		Prone = { Speed = 3.6, Spread = 0.45, Recoil = 0.55, Hit = 0.5 },
	},
	StanceSeconds = 0.22, -- stand <-> crouch; prone takes ProneSeconds
	ProneSeconds = 0.4,
	ProneHoldSeconds = 0.3, -- hold C this long to go prone; a tap crouches
	ProneCamera = Vector3.new(0, -1.7, -1.2), -- eye near the ground, ahead of the hips
	DiveSpeed = 34, -- sprint + C: a dive to prone
	DiveLift = 9,
	RollSpeed = 17, -- Q / E while prone: a roll to the side
	RollSeconds = 0.45,
	RollCooldown = 0.9,
	Lean = 1.3, -- Q / E: studs the eye and muzzle move sideways
	Peek = 2.6, -- the same next to cover (a wall within PeekReach ahead): out past the corner
	PeekReach = 3.5,
	LeanRoll = 9, -- degrees the view tilts
	SightSeconds = { Pistol = 0.08, Default = 0.12 }, -- the snap to the sights
	-- The gun in the first-person view (war/client/ViewGun.lua; owner, 2026-11-12: "The realistic gun handling,
	-- recoil, and visuals are the primary goals for weapons"). Positions are studs from the eye in the camera's
	-- frame (right, up, back); angles are degrees (pitch up, yaw left, roll).
	ViewGun = {
		Enabled = true,
		GunScale = 0.55, -- the size of a parts-built rifle in the hand (same as Config.War.GunScale)
		LongGun = 1.6, -- a gun longer than this is a rifle: butt in the shoulder, the off hand forward
		Reach = 0.75, -- the farthest ahead of the old grip point the off hand's palm goes
		-- Grip = the firing hand this far ahead of the eye when aimed; Hip = the move from there when not aiming;
		-- Pull = butt to grip on a parts-built rifle (PullShare of the length on a whole model); GripDrop = the
		-- grip below the bore (pistol: share of the height below the top); Wrist = how far the wrist leans back
		-- from straight down (degrees); Palm = the hand's centre out from the middle of the gun
		Rifle = { Grip = 0.85, Hip = Vector3.new(0.26, -0.34, 0), Pull = 1.38, PullShare = 0.33, GripDrop = 0.36, BoreDrop = 0.25, Wrist = 35, Palm = 0.1 },
		Pistol = { Grip = 1.55, Hip = Vector3.new(0.2, -0.3, 0.35), PullShare = 0.22, GripDrop = 0.62, BoreDrop = 0.12, Wrist = 12, Palm = 0.08 },
		HipRoll = -5,
		Carry = { Offset = Vector3.new(-0.16, -0.22, 0.12), Rotation = Vector3.new(-28, 38, 12) }, -- sprinting, binoculars: lowered across the body
		AimRate = 14, PoseRate = 9,
		Elbow = Vector3.new(1.6, -2.2, 0.4), -- where the elbows point, from the root (the left one mirrored)
		-- the gun trails a turn: Gain = share of the turn it is left behind by, Hip / Aim = the most it may trail
		Lag = { Frequency = 3.2, Damping = 0.62, Gain = 0.55, Hip = 5, Aim = 1.1 },
		Sway = { Rate = 1.5, Degrees = 0.32, Aim = 0.4 }, -- the breath; Aim = its share at the sights
		Steady = { Stand = 1, Crouch = 0.65, Prone = 0.3 },
		Bob = { Rate = 0.55, Side = 0.035, Drop = 0.045 },
		-- a shot: the server's recoil (degrees) becomes speed on the gun's spring, which overshoots and settles
		Recoil = { Frequency = 5.5, Damping = 0.5, Rise = 90, Twist = 40, Roll = 30, Back = 5, Hop = 1.2, Shift = 0.6, AimShare = 0.75 },
		Camera = { Frequency = 6, Damping = 0.6, Rise = 18, Twist = 14, Roll = 10 }, -- the punch that comes back
		OpticFade = 0.72, -- a scope's housing at the eye (both eyes open)
		Flash = { Size = 0.45, Seconds = 0.045, Brightness = 4, Range = 18, Color = Color3.fromRGB(255, 214, 150) },
	},
	-- Weapon animation made by code (war/client/GunMotion.lua): key poses on a timeline joined by easing curves.
	-- Positions are in the gun's own frame (studs: +X the gun's left, +Y up, +Z along the barrel), rotations are
	-- degrees (pitch up, yaw left, roll: negative tips the top of the gun to the right).
	GunMotion = {
		Enabled = true,
		Seconds = { Rack = 0.5, Release = 0.25, Draw = 0.45, Selector = 0.18 },
		TriggerSeconds = 0.12, TriggerPull = 0.02,
		Draw = { Position = Vector3.new(0.05, -0.9, -0.2), Rotation = Vector3.new(-48, -8, 10) }, -- where a drawn gun comes from
		Selector = Vector3.new(1.4, 0, -3),
		-- every contact of hand and metal jolts the gun's springs (Rot degrees a second: pitch up, yaw left, roll;
		-- Pos studs a second in the gun's frame: +Z the muzzle): the magazine stripped out, driven home, tugged; the
		-- action hitting its rear stop and slamming shut
		Jolt = {
			Strip = { Rot = Vector3.new(-60, 0, 45), Pos = Vector3.new(0, -1.6, 0) },
			Seat = { Rot = Vector3.new(170, 0, -110), Pos = Vector3.new(0, 3, 0) },
			Tug = { Rot = Vector3.new(-30, 0, 18), Pos = Vector3.new(0, -1, 0) },
			Back = { Rot = Vector3.new(50, 0, 0), Pos = Vector3.new(0, 0, -4) },
			Home = { Rot = Vector3.new(-120, 0, 0), Pos = Vector3.new(0, 0, 5) },
		},
		-- a magazine going in, as shares of its own length: it stops Short of home, backs off by WindUp, is driven
		-- in; the hand comes off by Rebound and pulls by Tug to feel that it holds
		Seat = { Short = 0.35, WindUp = 0.12, Rebound = 0.3, Tug = 0.12 },
		Bare = 0.4, -- how much of the magazine-change pose the gun keeps while its well is empty
		DropMag = { Seconds = 4, Spin = 5, Bounce = 0.25 }, -- a magazine let fall
		FirstShot = 1.3, FirstShotAfter = 0.35, -- the first round after a pause kicks the view harder
		Land = { Dip = 0.012, Pitch = 0.5, Max = 60 }, -- the gun dips on a landing and floats on a jump (per stud a second of fall)
		Brass = { Size = Vector3.new(0.035, 0.035, 0.1), Speed = 9, Up = 5, Back = 2.5, Spin = 28, Seconds = 2.2, Bounce = 0.35, Max = 14,
			Color = Color3.fromRGB(196, 158, 84) },
		-- Travel = how far the action runs, as a share of its own length; CycleSeconds = one shot's trip back and
		-- home, CycleBack = the share of it going back; Well = the way a magazine leaves; Pouch = where the off hand
		-- takes it; MagGrip / HandleGrip = the hand's centre from the magazine's foot / from the handle
		Rifle = {
			Travel = 0.5, CycleSeconds = 0.085, CycleBack = 0.35,
			Check = { Position = Vector3.new(0.16, 0.1, -0.08), Rotation = Vector3.new(8, 32, -14) },
			Reload = { Position = Vector3.new(0.1, 0.07, -0.05), Rotation = Vector3.new(13, 9, -24) },
			RackRotation = Vector3.new(5, 5, -12), HandleGrip = Vector3.new(0.05, 0, -0.04),
			Well = Vector3.new(0, -1, 0), Pouch = Vector3.new(0.45, -1.0, -0.6), MagGrip = Vector3.new(0.06, -0.05, 0),
		},
		Pistol = {
			Travel = 0.3, CycleSeconds = 0.07, CycleBack = 0.35,
			Check = { Position = Vector3.new(0.14, 0.1, -0.45), Rotation = Vector3.new(6, 38, -10) },
			Reload = { Position = Vector3.new(0.14, 0.14, -0.5), Rotation = Vector3.new(24, 10, -30) },
			RackRotation = Vector3.new(8, 14, -26), HandleGrip = Vector3.new(0.04, 0.03, 0),
			Well = Vector3.new(0, -0.95, -0.31), Pouch = Vector3.new(0.3, -1.1, -1.1), MagGrip = Vector3.new(0.05, -0.05, 0),
		},
	},
	-- Jointed fingers on the first-person hands (war/client/Fingers.lua). Angles in degrees, lengths in studs.
	Fingers = {
		Enabled = true,
		Group = "ViewGun", -- the collision group of the gun in the view and the hands (registered by the server)
		Rate = 22, -- how fast a finger goes to where it should be
		SolveEvery = 0.06, -- seconds between working out a hand's hold again
		Step = 9, -- a joint closes in steps of this until it touches
		Palm = Vector3.new(0, -0.17, 0), -- the middle of the palm from the wrist (y down the hand, z to the little finger)
		PalmGap = 0.004, -- air between the palm and what it holds
		Limits = { Finger = { 88, 100, 70 }, Thumb = { 30, 55, 65 } }, -- the most each joint bends, knuckle first
		Register = { 14, 16, 10 }, -- the firing finger off the trigger, along the frame
		-- an idle digit: fingers { spread, knuckle, middle, tip }; the thumb's first number is its turn to the fingers
		Relax = { Thumb = { 0.35, 8, 14, 10 }, Index = { 4, 16, 24, 14 }, Middle = { 0, 22, 30, 18 }, Ring = { -3, 26, 34, 20 }, Pinky = { -7, 30, 36, 22 } },
		Spread = { Index = 4, Middle = 0, Ring = -3, Pinky = -7 },
		ThumbSwing = 48, ThumbTuck = 14, ThumbRoll = 70, Opp = 0.75, -- the thumb: swung out from the fingers, turned to face them
		FiringThumb = { Swing = 20, Opp = 0.1 }, -- the firing hand's thumb lies forward along the gun
		ReachSpread = 30, -- the most the firing finger swings sideways for the trigger
		ArmReach = 1.6, MinReach = 0.2, -- shoulder to wrist is 1.70 at most: the off hand slides back along the gun to stay inside this (never closer to the grip than MinReach)
		TriggerHold = 0.8, -- the finger stays on the trigger this long after a shot from the hip
		-- the firing hand: the middle of the palm from the trigger's face (FromTrigger), out from the gun's middle
		-- (Out), the forearm leaving this far back from straight down (Wrist)
		Right = {
			Rifle = { FromTrigger = Vector3.new(0, -0.09, -0.24), Out = 0.045, Wrist = 100 },
			Pistol = { FromTrigger = Vector3.new(0, -0.1, -0.25), Out = 0.057, Wrist = 102 },
		},
		-- the off hand, by what it does: Normal = the way the palm faces, Wrist = the way the forearm leaves (both
		-- in the gun's frame: +X its left, +Y up, +Z the muzzle). Cup's Offset is from the firing hand's palm.
		Left = {
			Support = { Normal = Vector3.new(0, 1, 0), Wrist = Vector3.new(0.75, -0.55, -0.35) },
			Cup = { Normal = Vector3.new(-1, 0, 0), Wrist = Vector3.new(0.12, 0.05, -0.99), Offset = Vector3.new(0.062, -0.035, 0.02) },
			Mag = { Normal = Vector3.new(-1, 0, 0), Wrist = Vector3.new(0.3, -0.45, -0.84) },
			MagPistol = { Normal = Vector3.new(0, 1, 0), Wrist = Vector3.new(0.55, -0.25, -0.8) },
			Clip = { Normal = Vector3.new(0, -1, 0), Wrist = Vector3.new(0.7, 0.25, -0.65) },
			Handle = { Normal = Vector3.new(0, -1, 0), Wrist = Vector3.new(0.75, 0.15, -0.65) },
		},
	},
	CarefulReloadHold = 0.32, -- hold R this long: the half-used magazine goes back in the pouch
	QuickReload = 0.8, -- time multipliers on the magazine change
	CarefulReload = 1.35,
	Binoculars = { Fov = 16, Dwell = 0.35, Range = 700, Seconds = 9, ThroughWalls = true },
}

Config.Hideouts = {
	Sites = 12, -- claimable sites laid out through the city and outskirts
	Radius = 34, -- compound half-size
	RaidBaseInterval = 420, -- seconds between NPC raid rolls per hideout at tier 1 (divided by RaidWeight)
	RaidersPerMember = 2,
	TurretHostileNPC = true,
	MedbayHealPerSecond = 2,
	-- the Line 9 freight lift in each site's back corner (server/Hideouts.lua buildLift): new bodies come up here
	LiftOffset = Vector3.new(24, 0, 24),
	LiftHeight = 11,
	LiftShaft = 34, -- the shaft stands this far above the cab roof, a red lamp on top
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
	-- ...in light gear only (every worn piece Light, not overweight: GearWeight 0). Armoured, Q toward where you
	-- face or travel still rolls; Q to the sides or back is a heavy step that loses speed, length and i-frames
	-- per point of armour weight (Light 0, Medium 1, Heavy 2 per piece: 0..6), and there is no air dash.
	StepHoverHold = 0.88, -- share of gravity held off while hanging in front of a juggled enemy after Enemy Step
	ForwardDot = 0.5, -- dodge direction . facing/travel above this = "forward" (a roll)
	Step = { Speed = 46, Time = 0.34, SlowPerWeight = 0.09, MinMult = 0.45, IFrameLossPerWeight = 0.08, MinIFrameMult = 0.5 },
	-- jump within this long after a roll starts = a long jump; flying into a wall stuns you
	LongJumpWindow = 0.3, LongJumpSpeed = 60, LongJumpHeight = 7, LongJumpForceFactor = 1500,
	WallCheckRadius = 1,
	StunBounceSpeed = 25, StunBounceHeight = 3, StunForceFactor = 1500, RecoverTime = 0.5,
	-- lean into movement (degrees)
	LeanRoll = 15, LeanPitch = 5, LeanSpeed = 10, HipTurn = 62, -- HipTurn: degrees the hips turn into a sideways move
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

-- The Conduit body (server/Body.lua): each life rolls a jacket and a trim colour.
Config.Body = {
	Jackets = {
		Color3.fromRGB(44, 46, 54), -- gunmetal
		Color3.fromRGB(58, 62, 44), -- olive drab
		Color3.fromRGB(70, 42, 34), -- oxblood
		Color3.fromRGB(32, 40, 60), -- night navy
		Color3.fromRGB(150, 146, 134), -- bone
		Color3.fromRGB(24, 24, 26), -- black
	},
	Trims = {
		Color3.fromRGB(0, 215, 255), -- cyan
		Color3.fromRGB(255, 50, 170), -- magenta
		Color3.fromRGB(255, 170, 30), -- amber
		Color3.fromRGB(110, 255, 90), -- acid
		Color3.fromRGB(255, 60, 60), -- red
		Color3.fromRGB(230, 230, 255), -- white
	},
}

Config.Combat = {
	Headshot = 2.5, -- a round in the head of a body the game runs, when the weapon names no Headshot of its own
	HeadshotPlayers = 1.5, -- and in a player's
	-- the traced blade (shared/Swings, Combat.traceBlade)
	HitStop = 0.06, -- seconds the blade holds when it bites into a body
	ClashRadius = 0.9, -- studs between two live blades that counts as meeting
	ClashRecover = 0.45, -- both fighters are busy this long after a clash
	ClashPush = 22, -- and are pushed apart this hard
	GlanceRecover = 0.4, -- a blade stopped by a wall
	BodyRadius = 1.25, -- a body's capsule radius for blade hits
	-- the guard (shared/Swings.GuardPose): a traced blade is blocked only where it meets the guard before the body
	GuardRadius = 0.9, -- studs between a blade and the guard that counts as meeting it
	GuardFollow = 16, -- how fast a raised guard turns to a blade (1/s, exponential; the clients pose it the same)
	GuardCover = 100, -- degrees off your facing a swinger can stand and still be met by the guard (past it: around you)
	GuardSight = 16, -- studs: blades nearer than this are what a guard turns toward (the nearest one)
	BlockRecoil = 0.3, -- a blade stopped by a guard: the swinger can't act for at least this long
	BladeProbe = 1.1, -- studs: sphere swept at the blade's middle and tip for props
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
	BlockMinFacing = 0.1, -- untraced attacks (shots, throws, area strikes): from behind (dot < this) they bypass block
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
	InputQueue = 0.6, -- an attack/heavy pressed this long (s) before you're free is held and played then
	KillCreditSeconds = 15,
}

-- The megacity's industrial ring, green pockets and air (shared/Megacity.lua, server/Megacity.lua, client/Air.lua).
Config.Megacity = {
	SludgeDamage = 6, -- health per second standing in toxic sludge (pools, the Sumps' canals)
	SludgeTick = 0.5, -- seconds between sludge checks
	PocketRegen = 1.5, -- health per second inside a green pocket while nothing has hurt you for PocketCalm seconds
	PocketCalm = 8,
	SkylineTowers = 150, -- unreachable silhouettes past the edge wall
	SkylineStacks = 14, -- of which smoking chimneys
	-- Air profiles the client blends to by where the camera is (Megacity.AirAt). Atmosphere fields plus
	-- Tint (colour grade) and Motes (drifting particles: Ash, Smut, Pollen, Spores or nil).
	Air = {
		City = { Density = 0.42, Offset = 0.35, Haze = 2.2, Glare = 0.25, Color = Color3.fromRGB(120, 90, 160), Decay = Color3.fromRGB(60, 40, 90), Tint = Color3.fromRGB(225, 235, 255), Saturation = -0.08 },
		Smog = { Density = 0.52, Offset = 0.3, Haze = 3.2, Glare = 0.1, Color = Color3.fromRGB(150, 120, 90), Decay = Color3.fromRGB(90, 60, 40), Tint = Color3.fromRGB(255, 232, 205), Saturation = -0.2, Motes = "Ash" },
		Toxic = { Density = 0.5, Offset = 0.3, Haze = 3.0, Glare = 0.15, Color = Color3.fromRGB(140, 160, 80), Decay = Color3.fromRGB(70, 90, 30), Tint = Color3.fromRGB(230, 255, 205), Saturation = -0.15, Motes = "Smut" },
		Haze = { Density = 0.46, Offset = 0.32, Haze = 2.6, Glare = 0.2, Color = Color3.fromRGB(120, 110, 150), Decay = Color3.fromRGB(70, 50, 90), Tint = Color3.fromRGB(230, 232, 255), Saturation = -0.12 },
		Ash = { Density = 0.4, Offset = 0.25, Haze = 2.4, Glare = 0.1, Color = Color3.fromRGB(140, 130, 120), Decay = Color3.fromRGB(80, 70, 66), Tint = Color3.fromRGB(240, 236, 230), Saturation = -0.3, Motes = "Ash" },
		Under = { Density = 0.3, Offset = 0.1, Haze = 1.4, Glare = 0, Color = Color3.fromRGB(70, 60, 56), Decay = Color3.fromRGB(30, 26, 24), Tint = Color3.fromRGB(255, 226, 210), Saturation = -0.35, Motes = "Smut" },
		Clean = { Density = 0.22, Offset = 0.15, Haze = 0.6, Glare = 0.3, Color = Color3.fromRGB(170, 210, 200), Decay = Color3.fromRGB(90, 130, 120), Tint = Color3.fromRGB(240, 255, 240), Saturation = 0.12, Motes = "Pollen" },
	},
	AirBlend = 2.5, -- seconds to blend from one air to the next
}

-- Wounds (both places; shared/Wounds rules, common/WoundService state). Ideas from Tarkov's health system; our own
-- numbers. Parts share the body's max health; head or chest at zero kills; a limb at zero is "out" (blacked).
Config.Wounds = {
	Parts = { Head = 0.12, Chest = 0.26, Stomach = 0.18, ArmL = 0.11, ArmR = 0.11, LegL = 0.11, LegR = 0.11 },
	-- each part holds its share x PartScale of max health, so the shares add to more than the whole: the body's pool
	-- (the Humanoid) still ends a life spread over many hits; a part at zero is a concentrated wound
	PartScale = 2,
	HeadBlow = 0.4, -- the share of a non-bullet hit that the head part takes (the body's pool still takes all of it)
	SpreadPerShake = 0.12, -- Front: a gun's spread grows this much per degree of shake (pain, a bad arm)
	-- chance of a bleed from one hit, by kind; Heavy when the hit takes at least HeavyShare of the part's max
	Bleed = { Cut = 0.55, Bullet = 0.45, Blast = 0.35, Blunt = 0.06, Arc = 0 },
	HeavyShare = 0.45,
	BleedPerSecond = { Light = 0.25, Heavy = 0.8 }, -- health lost per second, from the bleeding part
	-- broken bones: blunt and blast on arms and legs, more likely the harder the hit; a limb knocked out by a blow
	-- breaks; a hard landing breaks a leg
	Fracture = { Blunt = 0.35, Blast = 0.45, Bullet = 0.12, Cut = 0.04 },
	FractureMinShare = 0.25,
	FallSpeed = 95, -- landing faster than this (studs/s) can break a leg
	-- how a body moves and aims with its wounds
	LegOutSpeed = 0.72, -- per leg out or broken (two: multiplied)
	ArmShake = 1.6, -- degrees of aim drift per arm out or broken
	ArmMelee = 0.8, -- melee damage per arm out or broken
	PainShake = 1.2, -- degrees of drift at full pain
	PainDecay = 0.04, -- pain lost per second
	PainPerShare = 0.9, -- pain from a hit, per share of the part's max it took
	Bruise = 0.18, -- share of a round stopped by plate that still lands as a blunt bruise on that part
	BruisePain = 0.25,
	Concussion = { Seconds = 9, Radius = 1.6 }, -- blast radius multiple that still concusses
	Painkiller = 150, -- seconds pain does not show and broken legs carry you at walking pace
	Surgery = { Floor = 1, MaxShare = 0.6 }, -- a dead limb back at 1 hp, its max cut to 60% for this life
	Lost = { Blast = 0.5, Cut = 0.3, Blunt = 0.03 }, -- chance a limb already out is lost to one more such hit (Endeavor only)
	ScarMin = 14, -- a cut this big leaves a scar for the life
	MaxScars = 10,
	Hunger = { Start = 100, PerMinute = 2.2, Low = 20, StaminaRegenLow = 0.6, StarveDamage = 0.25 },
	Doctor = { Price = 120, Seconds = 4 }, -- Verdant Reach: everything mended, lost limbs too, for war credits
	HomeHeal = { PartPerSecond = 0.02, MendSeconds = 90 }, -- in your own compound with a medbay: parts heal, breaks mend
}

-- The kit and two weapons (round 2 of docs/Reference-Picks-Plan.md; server/Kit.lua, Combat, client/Style.lua)
Config.Kit = {
	SwapSeconds = 0.3, -- drawing the other weapon: the hand goes to its mount and back
	-- where a carried second weapon rides: long ones across the back (a sling, always there), short ones need a place
	-- on the kit (a belt's holster or frog, a rig's chest holster)
	Long = { Rifle = true, Spear = true, Hammer = true, Blunt = true, Blade = true },
	MedSeconds = 0.6, -- a quick dressing from a pouch (key 2)
	MagReload = 0.75, -- reload time with magazines in rig pouches
	Lock = { Range = 45, Cone = 0.45, Forward = 0.6, Back = -0.6 }, -- lock-on (middle mouse): reach, cone, stick
	-- moves that come out of the chain (Combat.Attack): a pause before the next press, an attack out of a roll,
	-- and the two direction moves while locked on (forward: a lunge; back: a rising cut)
	Delay = { After = 0.3, Window = 0.6, Damage = 1.3, Posture = 1.6 },
	Roll = { Window = 0.45, Damage = 1.15, Reach = 2 },
	Lunge = { Damage = 1.2, Reach = 5, Speed = 70, Seconds = 0.18, Stamina = 1.5 },
	Rising = { Damage = 0.9, Stamina = 1.4 },
	ShotPop = { Velocity = 9, Extend = 0.25, Max = 14 }, -- rounds into a juggled body keep it up (their own count)
	ComboReset = 2.5, -- the corner count clears after this long without a hit landing
	Knock = { Seconds = 30, Revive = 3, Finish = 1.2, ReviveShare = 0.25, Again = 90, Crawl = 3 },
}

-- Guns and ammo (round 3 of docs/Reference-Picks-Plan.md; Endeavor's Combat and the Front's Guns/Soldiers)
Config.Guns = {
	-- magazines: the kit's spares are loaded ahead; with none loaded, the change is thumbing rounds in by hand
	Spares = 1, -- loaded spare magazines with no rig pouches (each pouch adds one)
	PerRound = 0.18, -- seconds to thumb one round into a magazine
	HandBase = 0.5, -- share of the gun's ReloadSeconds a by-hand reload still takes (out, in, slide)
	-- plate wears through: each round that meets it adds half of (1 + its Pen), the plate breaks at Hits x rating
	-- (a sentry's helmet takes 8 rounds of .22 or 4 of 9mm; a carrier's plate 20 of .22, 10 of 9mm)
	PlateHits = { Helmet = 4, Vest = 5, Bracers = 3, Shins = 3 },
	-- a stopped round that met plate at a glance goes on (|direction . surface| below Dot) with Damage of its force
	Ricochet = { Dot = 0.4, Damage = 0.35, Range = 60 },
	-- the barrel heats per shot and cools per second; past Hot the round wanders, at 1 the gun will not fire
	Heat = { Pistol = 0.05, Rifle = 0.03, Auto = 0.022, Cool = 0.12, Hot = 0.6, Spread = 3 },
	-- jams: chance per shot (base, plus Heat x heat^2, plus Wear x (1 - condition)); kinds by weight; seconds to clear
	Jam = { Base = 0.004, Heat = 0.08, Kinds = { Feed = 0.45, Stovepipe = 0.4, DoubleFeed = 0.15 },
		Clear = { Feed = 0.8, Stovepipe = 0.5, DoubleFeed = 0.6 } },
	-- tired arms: aiming tires the arms by the gun's weight, rest brings them back; tired arms drift the round
	Fatigue = { Rate = 0.025, Recover = 0.25, Drift = 2.5, Sway = 0.9, Weight = { Sidearm = 1, Rifle = 3.2 } },
	MetresPerStud = 0.28, -- range marks (the number under the reticle while aiming)
	DropSeconds = 120, -- a gun dropped by the dead lies this long
	TagCredits = 15, -- what the Reach's trader pays for a stack tag
	-- the Front: a glance off plate (Guns.Shoot) keeps this share of its speed; heat spreads a Front gun by this
	FrontRicochetSpeed = 0.5, FrontHeatSpread = 2.5,
	RadioRadius = 140, -- a guard with a working radio calls the whole level (voice: Config.Stealth.CallRadius)
}

-- The Front's gun handling on Endeavor's guns, in every hand near the camera (client/GunFeel.lua; the timelines and
-- jolts are Config.WarMovement.GunMotion, shared with the Front)
Config.GunFeel = {
	Enabled = true,
	Range = 90, -- bodies this near the camera have their guns worked piece by piece
	ScanEvery = 0.4,
	HearMech = 45, -- the metal of the hands (magazine, slide, cases landing) is heard this near
	WholeShare = 0.35, -- how much of the Front's whole-gun moves the gun makes in a third-person hand
	JoltShare = 0.5, -- and of every contact's jolt
	Spring = { Frequency = 6, Damping = 0.45 }, -- the gun's jolt in the hand
	-- a shot's jolt (degrees a second: muzzle up, twist, roll; studs a second: up, back)
	Kick = { Pistol = { Rise = 520, Twist = 90, Roll = 120, Hop = 1.2, Back = 3 }, Rifle = { Rise = 260, Twist = 60, Roll = 80, Hop = 0.6, Back = 2.5 } },
	-- the reload as shares of the server's time: magazine out, a beat, magazine in, then the action if it was empty
	Reload = { Out = 0.34, Gap = 0.06, In = 0.36, Rack = 0.2 },
	Brass = { Speed = 7, Up = 6, Back = 2, Seconds = 6, Max = 24, PistolSize = 1.6, RifleSize = 1.3 },
	Flash = { Size = 0.55, Seconds = 0.05, Brightness = 5, Range = 20, ShadowWithin = 60, Color = Color3.fromRGB(255, 206, 140) },
	Smoke = { Count = 3, Size = 1.1, Seconds = 1.4, Speed = 2.5, Rise = 1.2, Transparency = 0.72, Color = Color3.fromRGB(200, 196, 188) },
	FarSound = 180, -- a shot further than this is heard as the distant report
	Tail = { Volume = 0.55, MinNoise = 21 }, -- the city answering a loud shot
}

-- Jointed fingers on every body (client/Hands.lua; the finger rules are Config.WarMovement.Fingers)
Config.Hands = {
	Enabled = true,
	Range = 70, Max = 14, -- the nearest Max bodies within Range get them
	Far = 28, -- beyond this the hands are placed every second frame
	ScanEvery = 0.5, HoldEvery = 0.12, -- seconds between choosing bodies, and between choosing each hand's hold
	Rate = 16, -- how fast a finger goes to its hold
	Reference = Vector2.new(0.2867, 0.564), -- the soldier's hand part (X wide, Y long) the pieces were made for
	-- a hold = a handle of this radius in the palm (Tilt degrees from straight across the hand); Trigger = a gun grip
	Holds = {
		Grip = { Radius = 0.07, Tilt = 18 }, -- a blade's or a baton's grip
		Haft = { Radius = 0.085, Tilt = 14 }, -- a hammer's or a spear's
		Fist = { Radius = 0.026, Tilt = 10 },
		Pistol = { Radius = 0.07, Tilt = 16, Trigger = true }, -- HeldWeapons.HandgunGrip lays the grip on this same handle
		Rifle = { Radius = 0.075, Tilt = 16, Trigger = true },
		Support = { Radius = 0.1, Tilt = 4 },
		Cup = { Radius = 0.12, Tilt = 0 },
		Mag = { Radius = 0.06, Tilt = 0 },
		Pinch = { Radius = 0.035, Tilt = 30 },
		Grab = { Radius = 0.16, Tilt = 0 },
	},
	Families = { Blade = "Grip", Baton = "Grip", Blunt = "Haft", Hammer = "Haft", Spear = "Haft" },
	TriggerCaps = { 34, 58, 30 }, -- the first finger on the trigger bends no further than this
	OffHandReach = 0.42, OffHandAlong = 2.2, -- the off hand closes on the haft when its palm is this near the weapon's line
}

-- Builds (round 5 of docs/Reference-Picks-Plan.md; shared/Builds.lua, server/Builds.lua)
Config.Builds = {
	-- each body's Line 9 batch: Empty first, then Rare, then Good; the rest roll Bonus
	Lineage = { Empty = 0.01, Rare = 0.06, Good = 0.25, Bonus = 1, GoodBonus = 2, RareBonus = 4, RareSecond = 2 },
	-- the empty body: no flicker, no skills, a harder body
	Empty = { Health = 1.15, Damage = 1.12, Posture = 20, ParryBonus = 0.06, FirstStun = 1.6, FirstWindow = 4 },
	-- implant load: the core sets the limit
	Load = { Base = 7, ByKind = { Eyes = 1, Ears = 1, Nose = 1, Core = 1, Arm = 2, Leg = 1 } },
	Actives = {
		Quicken = { Seconds = 10, Cooldown = 90, CooldownMult = 0.5 },
		Spike = { Window = 15, Cooldown = 60, Power = 2 },
	},
	Chips = {
		FocusReach = 1.8, FocusCone = 0.5, -- cos of the half angle
		HookStun = 1.4, HookPull = 45,
		TrailSeconds = 1.6, TrailWidth = 3.5, TrailDamage = 9, TrailTick = 0.4,
		BreathPain = 0.5,
		MirrorShare = 1.0,
		ArcJump = 14, ArcShare = 0.5,
	},
	Vows = { LightDamage = 0.75, LightXp = 1.5, ThinHealth = 0.7, ThinCharge = 1.5, OpenReach = 60 },
	Grades = { Start = 4, Raid = 3, Severe = 2, High = 3 },
	Practice = {
		Endurance = { Per = 40, Max = 10, Stamina = 4 }, -- a point per second of sprinting
		Reload = { Per = 6, Max = 10, Faster = 0.03 }, -- a point per reload
		Search = { Per = 10, Max = 10, Faster = 0.05 }, -- a point per item found in a container
	},
	Bank = { Every = 1, LiftReach = 12 }, -- earnings are banked inside your own bay (or at a bay's lift while you have none)
	Stack = { Slots = 3 },
	DataShardXp = 300, -- a data shard read at home
	Respec = { Window = 120 }, -- seconds a solved riddle keeps the basin open
}

-- World and money (round 6 of docs/Reference-Picks-Plan.md)
Config.World = {
	-- the hour picks a time of day and a weather (server/Sky.lua). Natural = the chance it moves on to the next time
	-- (dawn, day, dusk, night); otherwise any other time comes.
	Sky = {
		Pocket = "Day", Natural = 0.5, Start = "Night",
		Times = {
			Dawn = { Clock = 6.3, Brightness = 1.5, Ambient = Color3.fromRGB(66, 58, 70), Outdoor = Color3.fromRGB(92, 80, 92), Fog = Color3.fromRGB(110, 84, 86), FogEnd = 1300, Sight = 0.9 },
			Day = { Clock = 13, Brightness = 2.3, Ambient = Color3.fromRGB(86, 84, 92), Outdoor = Color3.fromRGB(120, 118, 124), Fog = Color3.fromRGB(140, 130, 118), FogEnd = 1600, Sight = 1 },
			Dusk = { Clock = 18.3, Brightness = 1.4, Ambient = Color3.fromRGB(70, 48, 58), Outdoor = Color3.fromRGB(96, 64, 70), Fog = Color3.fromRGB(104, 64, 58), FogEnd = 1300, Sight = 0.9 },
			Night = { Clock = 22.5, Brightness = 1.1, Ambient = Color3.fromRGB(38, 36, 62), Outdoor = Color3.fromRGB(42, 40, 70), Fog = Color3.fromRGB(26, 22, 44), FogEnd = 1400, Sight = 0.75 },
		},
		Order = { "Dawn", "Day", "Dusk", "Night" },
		Weather = { Clear = 0.55, Rain = 0.25, Fog = 0.2 },
		Rain = { Sight = 0.85, Noise = 0.7 }, -- rain covers noise outdoors
		Fog = { Sight = 0.6, Density = 0.22, Haze = 2.5 },
	},
	Party = { Max = 4, InviteSeconds = 60, ShareRadius = 250, InviteReach = 30 },
	-- party runs in the shelters (server/Runs.lua): one at a time in Barrens Hall 2
	Runs = { Seconds = 420, JoinReach = 30, Xp = 250, Credits = 200, Cooldown = 120,
		Drain = { Rise = 0.018, Top = 3.6, Damage = 6 }, Carry = { SpeedMult = 0.6 }, Fuses = { Window = 30, Count = 4 },
		Copy = { Seconds = 40, Reach = 5, Light = 0.4 }, Cage = { Cells = 3, Hold = 50, Reach = 9, Wave = 15 } },
	Keys = { ShelterKey = "S4 STORE", StrongroomKey = "STRONGROOM" },
	Craft = { Seconds = { Weapon = 90, Armor = 120, Cybernetic = 150 }, TierMult = { 1, 0.75, 0.5 }, FuelPerSecond = 1 },
	Fuel = { Start = 600, PerCan = 300, Idle = 0.1, Max = 3000 }, -- seconds of running; Idle = per second the turret and alarm burn
	Condenser = { Period = 900, Cap = 6, Output = "Ration" }, -- makes a little while you are away (real time)
	Loyalty = { Levels = { 0, 120, 360, 800 }, PerCredit = 0.1, PerContract = 30 },
	Exchange = { Fee = 0.1, Slots = 2, SlotsPerRep = 5, MaxSlots = 6, Mults = { 1, 1.5, 2 },
		Values = { Material = 6, Ammo = 2, Consumable = 25, Weapon = 160, Armor = 130, Cybernetic = 320, Chip = 420, Data = 110, Pack = 90 } },
	Drop = { Price = 250, Delay = 40, Cooldown = 600 },
}

-- Round 7 of docs/Reference-Picks-Plan.md, things you make (server/Arms, Thralls, Companions, Proxy).
Config.Make = {
	Arm = { Hold = 0.35 }, -- K held this long fires the arm's active (a tap stays the core's)
	-- the Breaker arm: the next melee blow within Window lands Mult times as hard, through any guard, and the arm
	-- breaks (condition 0) until it is repaired at the bench
	Breaker = { Window = 6, Mult = 4, Knockback = 70, Stun = 1.6, Cooldown = 4 },
	-- the Cable arm: a line to where you aim. A body is dragged to you; a wall pulls you to it.
	Cable = { Range = 70, Cooldown = 5, Speed = 95, Stun = 0.9, PullSeconds = 0.45, Hold = 4 },
	Thrall = {
		Below = 0.3, -- a body under this share of its health (or down, asleep, held) can be shackled
		Reach = 7, MaxKept = 3,
		Escape = 0.2, EscapePowered = 0.04, -- the chance each hour that a kept one breaks out (a running generator holds the frame)
		InvadeEvery = 25, InvadeChance = 0.12, InvadeRange = { 45, 70 }, InvaderHealth = 1.6, InvaderDamage = 1.3,
		DebtDelay = 1, -- hours until a released one's debt arrives at the bay's lift
		-- on the Front (src/war/server/Thralls): reprogrammed ones fight beside their conduit's recruit
		Front = { Max = 2, Health = 100, Damage = 20, FireSeconds = 1.6, Accuracy = 0.35, Range = 150, Hold = 30 },
	},
	Companion = {
		Follow = 7, Leash = 90, Aggro = 38, Think = 0.2, SniffEvery = 6, Sniff = 55,
		Kinds = {
			Dog = { Name = "Dog", Health = 90, Damage = 9, Speed = 22, Bite = 1.1, Sniff = true },
			Cyberdog = { Name = "Cyberdog", Health = 170, Damage = 13, Speed = 24, Bite = 1.0, Resist = 0.3, Shock = 0.6 },
			Drone = { Name = "Drone", Health = 60, Damage = 7, Speed = 26, Shoot = 1.4, Range = 45, Fly = 6 },
			Hybrid = { Name = "Hybrid", Health = 130, Damage = 10, Speed = 23, Bite = 1.1, Sniff = true, Shoot = 2.2, Range = 35 },
		},
		StrayRespawn = 600,
	},
	-- the humanoid drone a conduit sends on a run in its place: less health, weak hands, steady with a gun, a big
	-- back; its loss costs what it carried, never the stack
	Proxy = { Health = 0.6, Melee = 0.5, Gun = 1.2, Spread = 0.7, Carry = 1.7, Tint = Color3.fromRGB(96, 100, 108),
		Rebuild = { SheetMetal = 4, Wire = 6, Battery = 2 } },
}

return Config
