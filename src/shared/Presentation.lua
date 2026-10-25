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
	ScrapSpear = { ModelName = "", Build = "Spear", Length = 6.5, Color = Color3.fromRGB(120, 95, 70), Accent = Color3.fromRGB(170, 170, 175), Grip = CFrame.new(0, 2.2, 0) }, -- held a third of the way down
	Sledge = { ModelName = "", Build = "Hammer", Length = 3.8, Color = Color3.fromRGB(80, 80, 85), Accent = Color3.fromRGB(60, 60, 65), Grip = CFrame.identity },
	ArcPistol = { ModelName = "", Build = "Pistol", Length = 1.3, Color = Color3.fromRGB(50, 55, 65), Accent = Color3.fromRGB(120, 200, 255), Grip = CFrame.identity }, -- grip upright, barrel along the hand's forward
	HandOffset = Vector3.new(0, -0.3, 0), -- where the fist closes, relative to the hand part's centre
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
	Bolt = { Color = Color3.fromRGB(120, 200, 255), Flash = 0.1,
		Muzzle = { Size = 1.2, Life = 0.08 },
		Sparks = { Count = 8, Color = Color3.fromRGB(160, 220, 255), Size = 0.25, Speed = 14, Life = 0.25 } },
	MaxInstances = 60, -- live placeholder FX parts allowed in workspace.FX at once
}

-- ---------------------------------------------------------------------------------------------
-- Sounds: Id "" = silent. Consumed by Audio.lua (story 005).
-- ---------------------------------------------------------------------------------------------
local function sfx(volume, jitter)
	return { Id = "", Volume = volume or 0.5, PitchJitter = jitter or 0.08 }
end
-- Each slot: Id = "rbxassetid://..." (empty = silent), Volume 0..1, PitchJitter = random +/- playback speed.
Presentation.Sounds = {
	SwingLight = sfx(0.4), SwingHeavy = sfx(0.6), Hit = sfx(0.7), Block = sfx(0.6), Parry = sfx(0.8, 0.02),
	GuardBreak = sfx(0.9, 0.02), Dodge = sfx(0.4), Dodged = sfx(0.4), Flick = sfx(0.5), BlackFlash = sfx(1, 0),
	Feint = sfx(0.3), Bolt = sfx(0.6), Buff = sfx(0.5), Burst = sfx(0.6), Stun = sfx(0.5),
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

-- Look up the swing entry for a weapon family and label; falls back to Default.
function Presentation.SwingFor(family, label)
	local key = if label == "Heavy" then "Heavy" else "Light"
	local fam = Presentation.Swings.Families[family]
	local entry = fam and (fam[label] or fam[key])
	return entry or Presentation.Swings.Default[key]
end

return Presentation
