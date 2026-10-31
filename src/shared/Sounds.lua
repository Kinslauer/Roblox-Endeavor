-- Sound effects, synthesized by tools/sounds/synth.py and uploaded as Audio assets (ids are the
-- creator's own uploads, so they only play inside this experience). Sounds.Play(name, at, opts)
-- is the one client-side entry point: `at` is a BasePart (the sound follows it) or a Vector3.
local Sounds = {}

Sounds.Ids = {
	SwingLight = 82793406791053,
	SwingHeavy = 104887032501831,
	HitFlesh = 98460656959601,
	HitClang = 76343375577671,
	BlockThud = 74944156125100,
	GuardBreak = 99481053920716,
	BlackFlash = 130240353924169,
	FlickerTick = 82676627232898,
	Catch = 99877140397113,
	Devour = 127978669996985,
	BreakWood = 139279934336139,
	BreakMetal = 90931696296918,
	BreakGlass = 114576758412795,
	Explosion = 76066004503438,
	Collapse = 75705535584130,
	ShotRifle = 115269046285915,
	ShotPistol = 111241814570194,
	ShotMg = 76577017634785,
	ShotDistant = 85850996684972,
	DryClick = 98510338111928,
	Rack = 95321194320562,
	ImpactDirt = 87807811707604,
	ImpactFlesh = 118429901746744,
	Dig = 88314587694249,
	AmbCity = 75239004859369,
	AmbWind = 78591666343512,
	AmbFront = 102348000683973,
	ArtilleryWhistle = 121714797919348,
}

-- Per-sound defaults: Volume, Range (RollOffMaxDistance), Pitch jitter
Sounds.Defaults = {
	SwingLight = { Volume = 0.5, Range = 40, Jitter = 0.15 },
	SwingHeavy = { Volume = 0.7, Range = 50, Jitter = 0.1 },
	HitFlesh = { Volume = 0.8, Range = 60, Jitter = 0.15 },
	HitClang = { Volume = 0.9, Range = 80, Jitter = 0.1 },
	BlockThud = { Volume = 0.7, Range = 50, Jitter = 0.1 },
	GuardBreak = { Volume = 1, Range = 80 },
	BlackFlash = { Volume = 1, Range = 160 },
	FlickerTick = { Volume = 0.4, Range = 20, Jitter = 0.05 },
	Catch = { Volume = 0.8, Range = 50 },
	Devour = { Volume = 0.9, Range = 60 },
	BreakWood = { Volume = 0.8, Range = 90, Jitter = 0.1 },
	BreakMetal = { Volume = 0.8, Range = 110, Jitter = 0.1 },
	BreakGlass = { Volume = 0.7, Range = 90, Jitter = 0.1 },
	Explosion = { Volume = 1, Range = 300 },
	Collapse = { Volume = 1, Range = 250 },
	ShotRifle = { Volume = 1, Range = 400, Jitter = 0.05 },
	ShotPistol = { Volume = 0.9, Range = 250, Jitter = 0.05 },
	ShotMg = { Volume = 1, Range = 450, Jitter = 0.04 },
	ShotDistant = { Volume = 0.6, Range = 1200 },
	DryClick = { Volume = 0.6, Range = 15 },
	Rack = { Volume = 0.7, Range = 25 },
	ImpactDirt = { Volume = 0.6, Range = 60, Jitter = 0.2 },
	ImpactFlesh = { Volume = 0.8, Range = 60, Jitter = 0.15 },
	Dig = { Volume = 0.7, Range = 40, Jitter = 0.1 },
	ArtilleryWhistle = { Volume = 1, Range = 500 },
}

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

-- Plays a one-shot. opts: Volume, Pitch, Range override. Returns the Sound or nil.
function Sounds.Play(name, at, opts)
	local id = Sounds.Ids[name]
	if not id then
		return nil
	end
	opts = opts or {}
	local d = Sounds.Defaults[name] or {}
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = opts.Volume or d.Volume or 0.7
	sound.RollOffMaxDistance = opts.Range or d.Range or 80
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	local jitter = d.Jitter or 0
	sound.PlaybackSpeed = (opts.Pitch or 1) * (1 + (math.random() * 2 - 1) * jitter)
	if typeof(at) == "Instance" then
		sound.Parent = at
	elseif typeof(at) == "Vector3" then
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = at
		anchor.Parent = workspace.Terrain
		sound.Parent = anchor
		Debris:AddItem(anchor, 6)
	else
		sound.Parent = SoundService -- non-positional (UI, own-character feedback)
	end
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

-- Starts (or returns) a looping ambient bed in SoundService; one per name.
local loops = {}
function Sounds.Loop(name, volume)
	local id = Sounds.Ids[name]
	if not id then
		return nil
	end
	if loops[name] then
		loops[name].Volume = volume or loops[name].Volume
		return loops[name]
	end
	local sound = Instance.new("Sound")
	sound.Name = "Ambient_" .. name
	sound.SoundId = "rbxassetid://" .. id
	sound.Looped, sound.Volume = true, volume or 0.3
	sound.Parent = SoundService
	sound:Play()
	loops[name] = sound
	return sound
end

return Sounds
