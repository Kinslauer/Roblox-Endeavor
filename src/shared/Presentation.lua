-- Presentation registry (ADR-0004). Every placeholder the client draws has a slot here, so real
-- assets (uploaded animations, weapon models, sounds) replace the procedural stand-ins by editing
-- this table - never client code. An empty string / nil means "use the procedural placeholder".
--
-- Timing is NOT defined here: windup/active/end come from Weapons.lua (the same numbers the server
-- uses), so what the player sees always matches the parry and flick windows.
local Presentation = {}

-- ---------------------------------------------------------------------------------------------
-- Weapons: what sits in the right hand. ModelName = a Model under ReplicatedStorage.Assets.Weapons
-- (cloned when set; it must contain a Part named "Handle"). Otherwise WeaponView builds the
-- procedural placeholder named by Build, using Color / Accent / Length.
-- Procedural weapons extend along the handle's -Y (out of the fist, past the little finger), so
-- they point down at rest and forward/up when the arm is raised. Grip = extra CFrame applied to
-- the Handle relative to the hand (identity = gripped at the top of the shaft).
-- ---------------------------------------------------------------------------------------------
Presentation.Weapons = {
	Fists = { ModelName = "", Build = nil }, -- nothing in hand
	PipeClub = { ModelName = "", Build = "Club", Length = 3.4, Color = Color3.fromRGB(110, 110, 115), Grip = CFrame.identity },
	RebarBlade = { ModelName = "", Build = "Blade", Length = 3.6, Color = Color3.fromRGB(150, 120, 100), Accent = Color3.fromRGB(190, 185, 170), Grip = CFrame.identity },
	ShockBaton = { ModelName = "", Build = "Baton", Length = 2.8, Color = Color3.fromRGB(40, 40, 50), Accent = Color3.fromRGB(90, 200, 255), Grip = CFrame.identity },
	ScrapSpear = { ModelName = "", Build = "Spear", Length = 6.5, Color = Color3.fromRGB(120, 95, 70), Accent = Color3.fromRGB(170, 170, 175), Grip = CFrame.new(0, 2.2, 0), -- held a third of the way down
		TwoHanded = true, Stance = { Right = { 30, 0, -40 }, Left = { 45, 0, 40 } } }, -- measured: hands at (0.44, -0.4, -1.0) / (-0.17, 0, -1.3) from the root
	Sledge = { ModelName = "", Build = "Hammer", Length = 3.8, Color = Color3.fromRGB(80, 80, 85), Accent = Color3.fromRGB(60, 60, 65), Grip = CFrame.identity,
		TwoHanded = true, Stance = { Right = { 25, 0, -45 }, Left = { 35, 0, 50 } } },
	ArcPistol = { ModelName = "", Build = "Pistol", Length = 1.3, Color = Color3.fromRGB(50, 55, 65), Accent = Color3.fromRGB(120, 200, 255), Grip = CFrame.Angles(math.rad(-90), 0, 0) }, -- barrel runs down the arm line, so it points where the arm points
	ArcRifle = { ModelName = "", Build = "Rifle", Length = 3.2, Color = Color3.fromRGB(44, 48, 58), Accent = Color3.fromRGB(120, 200, 255), Grip = CFrame.Angles(math.rad(-90), 0, 0),
		TwoHanded = true, Stance = { Right = { 70, 0, -20 }, Left = { 85, 0, 45 } }, -- low ready: muzzle forward-down, left hand on the fore-end
		Sights = { Height = 0.2, Width = 0.08, NotchWidth = 0.16, Rear = 0.5, Front = -2.4, Color = Color3.fromRGB(18, 18, 22), Dot = Color3.fromRGB(120, 255, 120) } },
	HandOffset = Vector3.new(0, -0.3, 0), -- where the fist closes, relative to the hand part's centre
	-- TwoHanded: the left arm follows the swing (yaw/roll mirrored) and both arms hold the Stance at
	-- rest. Stance = { Right = {pitch,yaw,roll}, Left = {...} } shoulder degrees applied while idle;
	-- a weapon without one hangs at the side. StanceBlend = seconds to ease in/out.
	-- Shoulder sign convention (measured on the R15 rig): +pitch raises the arm FORWARD (+90 = level,
	-- pointing ahead), -pitch swings it backward; roll moves the hand across the body (right arm:
	-- negative = inward, left arm: positive = inward). Yaw mostly twists the arm about its own axis.
	StanceBlend = 0.25,
}

-- ---------------------------------------------------------------------------------------------
-- Swings: per weapon Family (Weapons.Defs[id].Family), per label (combo index 1..n, "Heavy", or a
-- skill name). AnimationId "" = procedural pose timeline. Pose = right shoulder { pitch, yaw, roll }
-- in degrees at the peak of the windup, Swing = where the arm lands at impact (sign convention in
-- the note above Weapons: +pitch forward, roll across the body). Two-handed weapons add PoseL /
-- SwingL for the left arm; without them the left arm mirrors the right (yaw/roll flipped), which
-- only reads right when both hands stay near the centre line.
-- ---------------------------------------------------------------------------------------------
Presentation.Swings = {
	-- Keyframed swings (design/references/magoi-look-and-feel.md: held wind-ups, snappy strikes, a settle).
	-- An entry is a list of Keys, each a pose on the whole upper body:
	--   R / L   right / left shoulder { pitch, yaw, roll } (sign note above Weapons)
	--   Lean    waist pitch, degrees: + = back, - = forward         Twist  waist yaw: + = wind to the right
	--   Dip     studs the body sinks (root joint), + = down
	--   Phase   "Wind" (held at the end of the windup), "Mid" (inside the active frames, at Frac 0..1
	--           of them), "Strike" (the end of the active frames). The arm starts from wherever it is,
	--           reaches Wind over the windup (Sine), snaps Wind -> Mid -> Strike over the active frames
	--           (Quart), and settles Strike -> stance over the recovery (Sine). Timing is the server's.
	-- Legacy entries (Pose / Swing / PoseL / SwingL / Lean) still work: they become Wind + Strike.
	-- Trail = seconds the weapon trail lingers during the active frames (0 = none); Dust = puff size at
	-- the strike (0 = none). Labels: combo index 1..n, "Heavy", or a skill name; a missing index falls
	-- back to the family's Light, then Default.
	Default = {
		Light = { Keys = { { Phase = "Wind", R = { -70, 0, 40 }, Lean = 6, Twist = 20 }, { Phase = "Strike", R = { 75, 0, -55 }, Lean = -10, Twist = -15 } }, Trail = 0.12 },
		Heavy = { Keys = { { Phase = "Wind", R = { 165, 0, 10 }, Lean = 12, Twist = 10, Dip = -0.1 }, { Phase = "Strike", R = { 40, 0, -15 }, Lean = -18, Twist = -5, Dip = 0.35 } }, Trail = 0.2, Dust = 1 },
	},
	Families = {
		-- Fists: jab, cross, hook, uppercut; heavy = a wound-up haymaker.
		Fists = {
			[1] = { Keys = { { Phase = "Wind", R = { 40, 0, -10 }, Lean = 2, Twist = 10 }, { Phase = "Strike", R = { 92, 0, -12 }, Lean = -6, Twist = -8 } } },
			[2] = { Keys = { { Phase = "Wind", L = { 40, 0, 10 }, R = { 30, 0, -10 }, Twist = -12 }, { Phase = "Strike", L = { 95, 0, 10 }, R = { 30, 0, -10 }, Lean = -8, Twist = 12 } } },
			[3] = { Keys = { { Phase = "Wind", R = { 60, 0, 50 }, Lean = 4, Twist = 25 }, { Phase = "Mid", Frac = 0.5, R = { 85, 0, 0 } }, { Phase = "Strike", R = { 80, 0, -50 }, Lean = -6, Twist = -25 } } },
			[4] = { Keys = { { Phase = "Wind", R = { -20, 0, 10 }, Lean = 8, Dip = 0.3 }, { Phase = "Strike", R = { 120, 0, -5 }, Lean = -12, Dip = -0.2 } } },
			Light = { Keys = { { Phase = "Wind", R = { 40, 0, -10 }, Twist = 10 }, { Phase = "Strike", R = { 92, 0, -12 }, Lean = -6, Twist = -8 } } },
			Heavy = { Keys = { { Phase = "Wind", R = { -60, 0, 35 }, Lean = 10, Twist = 30 }, { Phase = "Strike", R = { 95, 0, -30 }, Lean = -14, Twist = -20, Dip = 0.2 } }, Dust = 0.6 },
		},
		-- Club (PipeClub): swing right-to-left, backhand, an overhead; heavy = the big chop.
		Blunt = {
			[1] = { Keys = { { Phase = "Wind", R = { -50, 0, 55 }, Lean = 6, Twist = 30 }, { Phase = "Strike", R = { 70, 0, -60 }, Lean = -10, Twist = -20 } }, Trail = 0.12 },
			[2] = { Keys = { { Phase = "Wind", R = { 40, 0, -80 }, Twist = -25 }, { Phase = "Mid", Frac = 0.5, R = { 70, 0, -10 } }, { Phase = "Strike", R = { 60, 0, 60 }, Lean = -6, Twist = 25 } }, Trail = 0.12 },
			[3] = { Keys = { { Phase = "Wind", R = { 160, 0, 10 }, Lean = 10, Dip = -0.1 }, { Phase = "Strike", R = { 35, 0, -15 }, Lean = -16, Dip = 0.3 } }, Trail = 0.16, Dust = 0.5 },
			Light = { Keys = { { Phase = "Wind", R = { -50, 0, 55 }, Twist = 30 }, { Phase = "Strike", R = { 70, 0, -60 }, Lean = -10, Twist = -20 } }, Trail = 0.12 },
			Heavy = { Keys = { { Phase = "Wind", R = { 170, 0, 15 }, Lean = 14, Twist = 12, Dip = -0.15 }, { Phase = "Strike", R = { 35, 0, -20 }, Lean = -20, Twist = -8, Dip = 0.4 } }, Trail = 0.22, Dust = 1 },
		},
		-- Blade (RebarBlade): diagonal cut, rising reverse cut, flat cut, overhead finisher; heavy = overhead.
		Blade = {
			[1] = { Keys = { { Phase = "Wind", R = { -60, 0, 45 }, Lean = 5, Twist = 28 }, { Phase = "Strike", R = { 70, 0, -62 }, Lean = -9, Twist = -22 } }, Trail = 0.14 },
			[2] = { Keys = { { Phase = "Wind", R = { 20, 0, -75 }, Lean = 4, Twist = -28 }, { Phase = "Mid", Frac = 0.5, R = { 65, 0, -20 } }, { Phase = "Strike", R = { 115, 0, 45 }, Lean = -6, Twist = 22 } }, Trail = 0.14 },
			[3] = { Keys = { { Phase = "Wind", R = { 85, 0, 70 }, Lean = 3, Twist = 40 }, { Phase = "Mid", Frac = 0.5, R = { 88, 0, 0 }, Twist = 0 }, { Phase = "Strike", R = { 80, 0, -80 }, Lean = -8, Twist = -38 } }, Trail = 0.16 },
			[4] = { Keys = { { Phase = "Wind", R = { 170, 0, 15 }, Lean = 12, Twist = 15, Dip = -0.15 }, { Phase = "Mid", Frac = 0.4, R = { 120, 0, 0 } }, { Phase = "Strike", R = { 30, 0, -12 }, Lean = -18, Twist = -6, Dip = 0.4 } }, Trail = 0.2, Dust = 0.6 },
			Light = { Keys = { { Phase = "Wind", R = { -60, 0, 45 }, Twist = 28 }, { Phase = "Strike", R = { 70, 0, -62 }, Lean = -9, Twist = -22 } }, Trail = 0.14 },
			Heavy = { Keys = { { Phase = "Wind", R = { 175, 0, 20 }, Lean = 15, Twist = 14, Dip = -0.15 }, { Phase = "Strike", R = { 40, 0, -15 }, Lean = -20, Twist = -8, Dip = 0.45 } }, Trail = 0.24, Dust = 1 },
		},
		-- Baton: jab, backhand, overhead crack; heavy = a two-step charge-up crack.
		Baton = {
			[1] = { Keys = { { Phase = "Wind", R = { 45, 0, -20 }, Twist = 10 }, { Phase = "Strike", R = { 95, 0, -15 }, Lean = -6, Twist = -8 } }, Trail = 0.1 },
			[2] = { Keys = { { Phase = "Wind", R = { 55, 0, -80 }, Twist = -25 }, { Phase = "Mid", Frac = 0.5, R = { 75, 0, -15 } }, { Phase = "Strike", R = { 65, 0, 55 }, Lean = -5, Twist = 25 } }, Trail = 0.1 },
			[3] = { Keys = { { Phase = "Wind", R = { 150, 0, 5 }, Lean = 8 }, { Phase = "Strike", R = { 45, 0, -15 }, Lean = -14, Dip = 0.25 } }, Trail = 0.14, Dust = 0.4 },
			Light = { Keys = { { Phase = "Wind", R = { 45, 0, -20 }, Twist = 10 }, { Phase = "Strike", R = { 95, 0, -15 }, Lean = -6, Twist = -8 } }, Trail = 0.1 },
			Heavy = { Keys = { { Phase = "Wind", R = { 160, 0, 15 }, Lean = 12, Twist = 12 }, { Phase = "Strike", R = { 40, 0, -15 }, Lean = -18, Twist = -6, Dip = 0.35 } }, Trail = 0.2, Dust = 0.8 },
		},
		-- Spear (the simplest combo, and even it is two thrusts and a swipe): the right hand drives,
		-- the left guides; the body winds to the right and uncoils into the thrust. 3 = the sweep.
		Spear = {
			[1] = { Keys = { { Phase = "Wind", R = { 60, 0, -30 }, L = { 70, 0, 40 }, Lean = 10, Twist = 25 }, { Phase = "Strike", R = { 96, 0, -5 }, L = { 100, 0, 8 }, Lean = -15, Twist = -10 } }, Trail = 0.12 },
			[2] = { Keys = { { Phase = "Wind", R = { 55, 0, -25 }, L = { 65, 0, 35 }, Lean = 8, Twist = 20, Dip = 0.1 }, { Phase = "Mid", Frac = 0.5, R = { 85, -8, -10 }, L = { 90, 0, 10 } }, { Phase = "Strike", R = { 92, -12, -4 }, L = { 97, 0, 10 }, Lean = -18, Twist = -15, Dip = 0.3 } }, Trail = 0.12 },
			[3] = { Keys = { { Phase = "Wind", R = { 80, 0, 70 }, L = { 85, 0, 90 }, Lean = 5, Twist = 40 }, { Phase = "Mid", Frac = 0.5, R = { 86, 0, 0 }, L = { 90, 0, 30 }, Twist = 0 }, { Phase = "Strike", R = { 80, 0, -80 }, L = { 85, 0, -10 }, Lean = -8, Twist = -40 } }, Trail = 0.18, Dust = 0.4 },
			Light = { Keys = { { Phase = "Wind", R = { 60, 0, -30 }, L = { 70, 0, 40 }, Lean = 10, Twist = 25 }, { Phase = "Strike", R = { 96, 0, -5 }, L = { 100, 0, 8 }, Lean = -15, Twist = -10 } }, Trail = 0.12 },
			Heavy = { Keys = { { Phase = "Wind", R = { 40, 0, -30 }, L = { 50, 0, 40 }, Lean = 15, Twist = 30, Dip = 0.2 }, { Phase = "Strike", R = { 102, 0, 0 }, L = { 106, 0, 10 }, Lean = -25, Twist = -15, Dip = 0.5 } }, Trail = 0.2, Dust = 0.8 },
		},
		-- Hammer (Sledge): a flat sweep, then the overhead; heavy = the slam, the body goes with it.
		Hammer = {
			[1] = { Keys = { { Phase = "Wind", R = { 75, 0, 55 }, L = { 80, 0, 85 }, Lean = 6, Twist = 35 }, { Phase = "Mid", Frac = 0.5, R = { 78, 0, -10 }, L = { 82, 0, 30 }, Twist = 0 }, { Phase = "Strike", R = { 70, 0, -75 }, L = { 75, 0, 0 }, Lean = -8, Twist = -35 } }, Trail = 0.2, Dust = 0.5 },
			[2] = { Keys = { { Phase = "Wind", R = { 165, 0, -10 }, L = { 165, 0, 10 }, Lean = 12, Dip = -0.15 }, { Phase = "Strike", R = { 35, 0, -20 }, L = { 40, 0, 20 }, Lean = -20, Dip = 0.45 } }, Trail = 0.22, Dust = 1 },
			Light = { Keys = { { Phase = "Wind", R = { 75, 0, 55 }, L = { 80, 0, 85 }, Twist = 35 }, { Phase = "Strike", R = { 70, 0, -75 }, L = { 75, 0, 0 }, Lean = -8, Twist = -35 } }, Trail = 0.2 },
			Heavy = { Keys = { { Phase = "Wind", R = { 175, 0, -10 }, L = { 175, 0, 10 }, Lean = 16, Dip = -0.2 }, { Phase = "Mid", Frac = 0.6, R = { 110, 0, -15 }, L = { 112, 0, 15 } }, { Phase = "Strike", R = { 30, 0, -22 }, L = { 35, 0, 22 }, Lean = -24, Dip = 0.6 } }, Trail = 0.28, Dust = 1.6 },
		},
		-- Sidearm: the arm comes up to the firing line and stays there (HoldAfter seconds since the
		-- last shot) before lowering; the heavy is a braced two-handed shot.
		Sidearm = { -- +90 = arm level, pointing forward (see the sign note above Weapons)
			Light = { AnimationId = "", Pose = { 90, 0, 0 }, Swing = { 90, 0, 0 }, HoldAfter = 2, Lean = { 0, 0 } },
			Heavy = { AnimationId = "", Pose = { 95, 0, -10 }, Swing = { 90, 0, -5 }, HoldAfter = 2, Lean = { 0, 0 } },
		},
		-- Rifle: shouldered with both hands; the lance heavy braces lower and leans in.
		Rifle = {
			Light = { AnimationId = "", Pose = { 90, 0, -15 }, PoseL = { 95, 0, 50 }, Swing = { 90, 0, -15 }, SwingL = { 95, 0, 50 }, HoldAfter = 2, Lean = { 0, 0 } },
			Heavy = { AnimationId = "", Pose = { 86, 0, -15 }, PoseL = { 92, 0, 50 }, Swing = { 90, 0, -15 }, SwingL = { 95, 0, 50 }, HoldAfter = 2, Lean = { 4, -6 } },
		},
	},
	HoldLower = 0.3, -- seconds to lower a held arm once HoldAfter runs out
	DefaultLean = { 6, -10 }, -- torso pitch (degrees; + = back at the wind-up, - = forward at impact) when a legacy entry has no Lean
	-- Flick cue: a glow that ramps during the windup and peaks Config.Flicker.Window before impact.
	Cue = { Color = Color3.fromRGB(255, 60, 60), ZoneColor = Color3.fromRGB(255, 200, 80), MaxBrightness = 6, MaxRange = 10 },
	HeavyColor = Color3.fromRGB(255, 170, 60),
	LightColor = Color3.fromRGB(230, 230, 255),
	TweenStyle = Enum.EasingStyle.Quad,
	-- Weapon trail (WeaponView builds it on every melee weapon; SwingAnimator switches it on for the
	-- active frames): a thin white ribbon from the hand to the tip, longer-lived on heavies.
	TrailColor = Color3.fromRGB(240, 240, 255), TrailHeavyColor = Color3.fromRGB(255, 200, 120), TrailWidth = 1,
	-- Dust (WorldFX): the ground answers a heavy strike, a dodge, a landing. Colour of the puff.
	DustColor = Color3.fromRGB(150, 135, 110),
}

-- ---------------------------------------------------------------------------------------------
-- Impacts: one entry per CombatEvent kind. Duration/colour of the placeholder effect; Hitstop and
-- Shake are consumed by story 003 (zero = off).
-- ---------------------------------------------------------------------------------------------
-- Flash    = Highlight pulse seconds        Hitstop = camera FOV punch seconds (local attacker/victim only)
-- Shake    = camera shake amplitude 0..1    Sparks  = { Count, Color, Size, Speed, Life } particle burst
-- Ring     = { Color, Size, Life } expanding flat ring   Ghost = after-image seconds   Shards = shatter burst
Presentation.Impacts = {
	Hit = { Color = Color3.fromRGB(255, 70, 70), Flash = 0.15, Hitstop = 0.05, Shake = 0.35,
		Sparks = { Count = 14, Color = Color3.fromRGB(255, 120, 60), Size = 0.35, Speed = 18, Life = 0.3 },
		HeavyAmount = 20 }, -- damage at/above this shakes with the Heavy multiplier
	HeavyShakeMult = 1.8,
	Block = { Color = Color3.fromRGB(150, 150, 255), Flash = 0.15, Hitstop = 0, Shake = 0.15,
		Sparks = { Count = 8, Color = Color3.fromRGB(140, 170, 255), Size = 0.25, Speed = 12, Life = 0.25 } },
	Parry = { Color = Color3.fromRGB(255, 255, 255), Flash = 0.2, Hitstop = 0.08, Shake = 0.5,
		Sparks = { Count = 18, Color = Color3.fromRGB(255, 255, 255), Size = 0.3, Speed = 22, Life = 0.3 },
		Ring = { Color = Color3.fromRGB(255, 255, 255), Size = 9, Life = 0.3 } },
	GuardBreak = { Color = Color3.fromRGB(255, 160, 0), Flash = 0.25, Hitstop = 0.1, Shake = 0.7,
		Shards = { Count = 16, Color = Color3.fromRGB(255, 170, 40), Size = 0.6, Speed = 26, Life = 0.6 } },
	Burst = { Color = Color3.fromRGB(80, 170, 255), Flash = 0.15, Hitstop = 0, Shake = 0.2 },
	Dodge = { Color = Color3.fromRGB(120, 255, 200), Flash = 0.15, Hitstop = 0, Shake = 0 },
	Dodged = { Color = Color3.fromRGB(80, 255, 230), Flash = 0.25, Hitstop = 0, Shake = 0, Ghost = 0.35 },
	Buff = { Color = Color3.fromRGB(255, 220, 120), Flash = 0.15, Hitstop = 0, Shake = 0 },
	Flick = { Color = Color3.fromRGB(255, 60, 60), Flash = 0.15, Hitstop = 0, Shake = 0.1, LevelScale = 0.5 },
	Feint = { Color = Color3.fromRGB(200, 200, 200), Flash = 0.15, Hitstop = 0, Shake = 0 },
	BlackFlash = { Color = Color3.fromRGB(255, 20, 20), Flash = 0.35, Hitstop = 0.12, Shake = 1.0, BannerSeconds = 1.2 },
	Safe = { Color = Color3.fromRGB(120, 255, 200), Flash = 0.2, Hitstop = 0, Shake = 0 }, -- a hit refused by the safe zone
	Snatch = { Color = Color3.fromRGB(120, 200, 255), Flash = 0.2, Hitstop = 0, Shake = 0.15, Beam = { Width = 0.25, Life = 0.25 } }, -- hook beam user -> target
	Buster = { Color = Color3.fromRGB(255, 200, 60), Flash = 0.3, Hitstop = 0.1, Shake = 0.8 }, -- throw (shove uses Flash only)
	Launch = { Color = Color3.fromRGB(255, 230, 120), Flash = 0.3, Hitstop = 0.06, Shake = 0.5, Streak = { Height = 10, Life = 0.3, Width = 0.6 } }, -- an open enemy sent up by a heavy
	Juggle = { Color = Color3.fromRGB(255, 230, 120), Flash = 0.12, Hitstop = 0.03, Shake = 0.2 }, -- each hit that keeps it up
	EnemyStep = { Color = Color3.fromRGB(120, 255, 200), Flash = 0.15, Hitstop = 0, Shake = 0.1 }, -- dodge off an airborne enemy
	Headshot = { Color = Color3.fromRGB(255, 120, 60), Flash = 0.2, Hitstop = 0.05, Shake = 0.25 }, -- gunplay: a shot that landed on the Head
	Bolt = { Color = Color3.fromRGB(120, 200, 255), Flash = 0.1,
		Muzzle = { Size = 1.2, Life = 0.08 },
		Sparks = { Count = 8, Color = Color3.fromRGB(160, 220, 255), Size = 0.25, Speed = 14, Life = 0.25 } },
	MaxInstances = 60, -- live placeholder FX parts allowed in workspace.FX at once
}

-- ---------------------------------------------------------------------------------------------
-- Sounds: Id "" = silent. Consumed by Audio.lua (story 005).
-- ---------------------------------------------------------------------------------------------
local function sfx(id, volume, jitter)
	return { Id = id or "", Volume = volume or 0.5, PitchJitter = jitter or 0.08 }
end
-- Each slot: Id (empty = silent), Volume 0..1, PitchJitter = random +/- playback speed.
-- Placeholders are Roblox's built-in rbxasset:// sounds (no upload needed); replace with
-- "rbxassetid://<id>" once real SFX exist.
local B = "rbxasset://sounds/"
Presentation.Sounds = {
	SwingLight = sfx(B .. "swordslash.wav", 0.35, 0.12), SwingHeavy = sfx(B .. "swordlunge.wav", 0.6, 0.06),
	Hit = sfx(B .. "hit.wav", 0.4, 0.1), Block = sfx(B .. "metal.ogg", 0.6, 0.06), Parry = sfx(B .. "unsheath.wav", 0.8, 0.02), -- Hit was 0.7: too loud (owner playtest)
	GuardBreak = sfx(B .. "glassbreak.wav", 0.9, 0.02), Dodge = sfx(B .. "action_jump_land.mp3", 0.4, 0.1), Dodged = sfx(B .. "snap.wav", 0.4),
	Flick = sfx(B .. "clickfast.wav", 0.5, 0.05), BlackFlash = sfx(B .. "bass.wav", 1, 0),
	Feint = sfx(B .. "button.wav", 0.3), Bolt = sfx(B .. "paintball.wav", 0.6, 0.08), Buff = sfx(B .. "electronicpingshort.wav", 0.5),
	Burst = sfx(B .. "flashbulb.wav", 0.6), Stun = sfx(B .. "collide.wav", 0.5, 0.1), Safe = sfx(B .. "electronicpingshort.wav", 0.35, 0.02),
	Snatch = sfx(B .. "unsheath.wav", 0.5, 0.1), Buster = sfx(B .. "impact_explosion_01.mp3", 0.8, 0.05),
	Launch = sfx(B .. "swordlunge.wav", 0.7, 0.15), Juggle = sfx(B .. "hit.wav", 0.5, 0.15), EnemyStep = sfx(B .. "action_jump.mp3", 0.5, 0.05),
	Headshot = sfx(B .. "snap.wav", 0.7, 0.05), Reload = sfx(B .. "button.wav", 0.5, 0.1),
	MaxPerChar = 4, -- concurrent sounds per character; the oldest is cut when exceeded
	MaxDistance = 120, -- studs before a 3D sound is inaudible
	LocalMix = 0.6, -- volume multiplier for the extra 2D copy of the local player's own events
}

-- ---------------------------------------------------------------------------------------------
-- Camera: shake magnitudes are studs of offset at Shake = 1; consumed by story 003.
-- ---------------------------------------------------------------------------------------------
-- ShakeMagnitude = studs of camera offset at Shake 1; ShakeDecay = seconds to settle; ShakeFrequency = Hz
-- HitstopFov = degrees of FOV punch at Hitstop; the punch lasts the impact's Hitstop seconds.
Presentation.Camera = { ShakeMagnitude = 0.6, ShakeDecay = 0.25, ShakeFrequency = 28, HitstopFov = -4 }

-- ---------------------------------------------------------------------------------------------
-- Locomotion: stock R15 clips played on server-built bodies (players via client/Animate, enemies
-- via server/NPCs). Swap for custom animations by id; "" disables that clip.
-- ---------------------------------------------------------------------------------------------
Presentation.Locomotion = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}

-- ---------------------------------------------------------------------------------------------
-- Aim: the combat stance (client/Aim.lua). Shoulder offset is in studs relative to the character.
-- ---------------------------------------------------------------------------------------------
Presentation.Aim = {
	DefaultOn = true,
	ToggleKey = Enum.KeyCode.LeftControl,
	FreeCursorKey = Enum.KeyCode.LeftAlt, -- hold to free the mouse (click HUD buttons) without leaving the stance
	ShoulderOffset = Vector3.new(1.75, 0.5, 0), -- fallback when a weapon type has no preset below
	-- Camera presets by weapon type (client/Aim.lua applies one when the weapon changes; scrolling
	-- still zooms afterwards). Melee sits far and high so the whole exchange reads - the wind-up, the
	-- dodge, the second enemy (design/references/magoi-look-and-feel.md); guns come in over the shoulder.
	Melee = { Distance = 15, ShoulderOffset = Vector3.new(0.9, 1.4, 0) },
	Ranged = { Distance = 9, ShoulderOffset = Vector3.new(1.75, 0.5, 0) },
	-- Ranged weapons: right mouse = aim down sights (first person, narrow FOV) while held; the
	-- weapon's special (its Heavy) moves to SpecialKeys. Melee weapons keep right mouse = heavy.
	ADS = { Fov = 42, NormalFov = 70, ZoomTime = 0.12, FirstPerson = true },
	FirstPersonKey = Enum.KeyCode.C, -- toggle a locked first-person camera (hip-fire view model) any time
	FirstPersonFov = 75,
	SpecialKeys = { Enum.UserInputType.MouseButton3, Enum.KeyCode.G },
}

-- ---------------------------------------------------------------------------------------------
-- Hud: the combat overlay (client/HudCombat.lua). Numbers float up from the victim; the reticle
-- sits at screen centre while Aim is on and blinks on a confirmed hit; DamageFlash tints the
-- screen edges when the local player takes damage.
-- ---------------------------------------------------------------------------------------------
Presentation.Hud = {
	DamageNumbers = {
		Life = 0.9, Rise = 3.5, Spread = 1.2, -- seconds, studs up, studs of random sideways scatter
		TextSize = 26, HeavyTextSize = 34, HeavyAmount = 20,
		Colors = { Hit = Color3.fromRGB(255, 235, 200), Heavy = Color3.fromRGB(255, 150, 60), Taken = Color3.fromRGB(255, 80, 80),
			Block = Color3.fromRGB(150, 170, 255), Parry = Color3.fromRGB(255, 255, 255), GuardBreak = Color3.fromRGB(255, 160, 0),
			Dodged = Color3.fromRGB(80, 255, 230), BlackFlash = Color3.fromRGB(255, 20, 20), Safe = Color3.fromRGB(120, 255, 200),
			Snatch = Color3.fromRGB(120, 200, 255), Buster = Color3.fromRGB(255, 200, 60), Launch = Color3.fromRGB(255, 230, 120), Headshot = Color3.fromRGB(255, 120, 60) },
		MaxLive = 24,
	},
	Reticle = { Size = 6, Gap = 5, Thickness = 2, Color = Color3.fromRGB(235, 235, 240), HitColor = Color3.fromRGB(255, 90, 60), HitSeconds = 0.12, HitScale = 1.8 },
	DamageFlash = { Color = Color3.fromRGB(200, 30, 30), Seconds = 0.35, MaxTransparency = 0.55 },
}

-- ---------------------------------------------------------------------------------------------
-- ViewModel: the first-person arm + weapon (client/ViewModel.lua). Offsets are in camera space
-- (x right, y up, z back), studs; angles in degrees. EyeDistance = how far in front of the eye
-- the rear sight sits while aiming down sights (the aim line always passes through the eye).
-- ---------------------------------------------------------------------------------------------
Presentation.ViewModel = {
	FirstPersonDistance = 1.5, -- camera this close to the head counts as first person
	EyeDistance = 0.9,
	HipOffset = Vector3.new(0.65, -0.55, -1.4), HipAngles = Vector3.new(0, -6, 0),
	BlendTime = 0.12, -- hip <-> sights
	Sway = 0.6, -- weapon lag on camera turns (0 = rigid)
	RecoilLight = 0.35, RecoilHeavy = 0.8, RecoilRecover = 3, -- kick per shot (0..1) and decay per second
	RecoilBack = 0.25, RecoilPitch = 6, -- studs back / degrees up at kick 1
}

-- Look up the swing entry for a weapon family and label; falls back to Default.
function Presentation.SwingFor(family, label)
	local key = if label == "Heavy" then "Heavy" else "Light"
	local fam = Presentation.Swings.Families[family]
	local entry = fam and (fam[label] or fam[key])
	return entry or Presentation.Swings.Default[key]
end

return Presentation
