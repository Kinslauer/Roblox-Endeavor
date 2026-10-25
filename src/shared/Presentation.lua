-- Presentation registry (ADR-0004). Every placeholder the client draws has a slot here, so real
-- assets (uploaded animations, weapon models, sounds) replace the procedural stand-ins by editing
-- this table - never client code. An empty string / nil means "use the procedural placeholder".
--
-- Timing is NOT defined here: windup/active/end come from Weapons.lua (the same numbers the server
-- uses), so what the player sees always matches the parry and flick windows.
local Presentation = {}

-- ---------------------------------------------------------------------------------------------
-- Weapons: what sits in the right hand. ModelName = a Model under ReplicatedStorage.Assets.Weapons
-- (cloned when set). Otherwise WeaponView builds the placeholder named by Build.
-- Grip = CFrame offset from the RightHand (R15) / Right Arm (R6) to the Handle.
-- ---------------------------------------------------------------------------------------------
Presentation.Weapons = {
	Fists = { ModelName = "", Build = nil }, -- nothing in hand
	PipeClub = { ModelName = "", Build = "Club", Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(110, 110, 115) },
	RebarBlade = { ModelName = "", Build = "Blade", Grip = CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(150, 120, 100) },
	ShockBaton = { ModelName = "", Build = "Baton", Grip = CFrame.new(0, -1.1, 0) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(40, 40, 50), Accent = Color3.fromRGB(90, 200, 255) },
	ScrapSpear = { ModelName = "", Build = "Spear", Grip = CFrame.new(0, -2.2, 0) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(120, 95, 70) },
	Sledge = { ModelName = "", Build = "Hammer", Grip = CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(80, 80, 85) },
	ArcPistol = { ModelName = "", Build = "Pistol", Grip = CFrame.new(0, -0.4, -0.3) * CFrame.Angles(0, 0, 0), Color = Color3.fromRGB(50, 55, 65), Accent = Color3.fromRGB(120, 200, 255) },
}

-- ---------------------------------------------------------------------------------------------
-- Swings: per weapon Family (Weapons.Defs[id].Family), per label (combo index 1..n, "Heavy", or a
-- skill name). AnimationId "" = procedural Motor6D tween. Pose values are the procedural wind-back
-- in degrees for the right shoulder: { pitch, yaw, roll } at the peak of the windup.
-- ---------------------------------------------------------------------------------------------
Presentation.Swings = {
	Default = {
		Light = { AnimationId = "", Pose = { -110, 0, 35 }, Swing = { 20, -20, -40 } },
		Heavy = { AnimationId = "", Pose = { -175, 0, 8 }, Swing = { 45, -10, -20 } }, -- overhead wind-up, chop down
	},
	Families = {
		Fists = { Light = { AnimationId = "", Pose = { -80, 0, 20 }, Swing = { 10, -30, -10 } }, Heavy = { AnimationId = "", Pose = { -130, 0, 40 }, Swing = { 20, -40, -20 } } },
		Blunt = {}, Blade = {}, Baton = {}, Spear = { Light = { AnimationId = "", Pose = { -60, 0, 10 }, Swing = { 40, 0, -10 } } }, Hammer = {}, Sidearm = { Light = { AnimationId = "", Pose = { -90, 0, 0 }, Swing = { -90, 0, 0 } } },
	},
	-- Flick cue: a glow that ramps during the windup and peaks Config.Flicker.Window before impact.
	Cue = { Color = Color3.fromRGB(255, 60, 60), ZoneColor = Color3.fromRGB(255, 200, 80), MaxBrightness = 6, MaxRange = 10 },
	HeavyColor = Color3.fromRGB(255, 170, 60),
	LightColor = Color3.fromRGB(230, 230, 255),
	TweenStyle = Enum.EasingStyle.Quad,
}

-- ---------------------------------------------------------------------------------------------
-- Impacts: one entry per CombatEvent kind. Duration/colour of the placeholder effect; Hitstop and
-- Shake are consumed by story 003 (zero = off).
-- ---------------------------------------------------------------------------------------------
Presentation.Impacts = {
	Hit = { Color = Color3.fromRGB(255, 70, 70), Flash = 0.15, Hitstop = 0.05, Shake = 0.35 },
	Block = { Color = Color3.fromRGB(150, 150, 255), Flash = 0.15, Hitstop = 0, Shake = 0.15 },
	Parry = { Color = Color3.fromRGB(255, 255, 255), Flash = 0.2, Hitstop = 0.08, Shake = 0.5 },
	GuardBreak = { Color = Color3.fromRGB(255, 160, 0), Flash = 0.25, Hitstop = 0.1, Shake = 0.7 },
	Burst = { Color = Color3.fromRGB(80, 170, 255), Flash = 0.15, Hitstop = 0, Shake = 0.2 },
	Dodge = { Color = Color3.fromRGB(120, 255, 200), Flash = 0.15, Hitstop = 0, Shake = 0 },
	Dodged = { Color = Color3.fromRGB(80, 255, 230), Flash = 0.25, Hitstop = 0, Shake = 0 },
	Buff = { Color = Color3.fromRGB(255, 220, 120), Flash = 0.15, Hitstop = 0, Shake = 0 },
	Flick = { Color = Color3.fromRGB(255, 60, 60), Flash = 0.15, Hitstop = 0, Shake = 0.1, LevelScale = 0.5 },
	Feint = { Color = Color3.fromRGB(200, 200, 200), Flash = 0.15, Hitstop = 0, Shake = 0 },
	BlackFlash = { Color = Color3.fromRGB(255, 20, 20), Flash = 0.35, Hitstop = 0.12, Shake = 1.0, BannerSeconds = 1.2 },
	Bolt = { Color = Color3.fromRGB(120, 200, 255), Flash = 0.1 },
	MaxInstances = 60, -- live placeholder FX parts allowed in workspace.FX at once
}

-- ---------------------------------------------------------------------------------------------
-- Sounds: Id "" = silent. Consumed by story 005.
-- ---------------------------------------------------------------------------------------------
local function sfx(volume, jitter)
	return { Id = "", Volume = volume or 0.5, PitchJitter = jitter or 0.08 }
end
Presentation.Sounds = {
	SwingLight = sfx(0.4), SwingHeavy = sfx(0.6), Hit = sfx(0.7), Block = sfx(0.6), Parry = sfx(0.8, 0.02),
	GuardBreak = sfx(0.9, 0.02), Dodge = sfx(0.4), Dodged = sfx(0.4), Flick = sfx(0.5), BlackFlash = sfx(1, 0),
	Feint = sfx(0.3), Bolt = sfx(0.6), Buff = sfx(0.5), Burst = sfx(0.6),
	PoolSize = 4,
}

-- ---------------------------------------------------------------------------------------------
-- Camera: shake magnitudes are studs of offset at Shake = 1; consumed by story 003.
-- ---------------------------------------------------------------------------------------------
Presentation.Camera = { ShakeMagnitude = 0.6, ShakeDecay = 0.25, ShakeFrequency = 28 }

-- Look up the swing entry for a weapon family and label; falls back to Default.
function Presentation.SwingFor(family, label)
	local key = if label == "Heavy" then "Heavy" else "Light"
	local fam = Presentation.Swings.Families[family]
	local entry = fam and (fam[label] or fam[key])
	return entry or Presentation.Swings.Default[key]
end

return Presentation
