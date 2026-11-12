-- The air where you stand (shared/Megacity.AirAt, Config.Megacity.Air): the smog thickens and yellows
-- in the industrial ring, turns green over the sludge, greys to ash north of the wall, and clears in
-- the few green pockets left. Blends the Atmosphere and the city's colour grade, drifts motes (ash,
-- smut, pollen) round the camera, sets the ambient loops, and tints the screen while the server says
-- you stand in sludge (character attribute "Toxic"). Nothing here explains itself.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Megacity = require(Shared:WaitForChild("Megacity"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Air = {}
local C = Config.Megacity
local player = Players.LocalPlayer
local current -- profile name
local motes, motePart
local toxicGrade
local warned = false

-- Ambient loop volumes per air (missing ids are skipped by Sounds.Loop).
local AMBIENT = {
	City = { AmbCity = 0.35, AmbWind = 0.2, AmbIndustry = 0.05, AmbGarden = 0 },
	Haze = { AmbCity = 0.3, AmbWind = 0.2, AmbIndustry = 0.15, AmbGarden = 0 },
	Smog = { AmbCity = 0.15, AmbWind = 0.15, AmbIndustry = 0.4, AmbGarden = 0 },
	Toxic = { AmbCity = 0.12, AmbWind = 0.25, AmbIndustry = 0.25, AmbGarden = 0 },
	Ash = { AmbCity = 0.05, AmbWind = 0.35, AmbIndustry = 0.05, AmbGarden = 0 },
	Under = { AmbCity = 0, AmbWind = 0, AmbIndustry = 0.5, AmbGarden = 0 },
	Clean = { AmbCity = 0.06, AmbWind = 0.1, AmbIndustry = 0, AmbGarden = 0.35 },
}

local MOTES = {
	Ash = { Color = Color3.fromRGB(200, 196, 190), Rate = 60, Size = 0.18, Fall = -2.5, Light = 0 },
	Smut = { Color = Color3.fromRGB(120, 140, 60), Rate = 50, Size = 0.15, Fall = -1.2, Light = 0.2 },
	Pollen = { Color = Color3.fromRGB(255, 240, 170), Rate = 30, Size = 0.14, Fall = 0.3, Light = 0.6 },
}

local function where()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	local focus = cam and cam.Focus
	return if focus then focus.Position elseif cam then cam.CFrame.Position else Vector3.zero
end

local function regionAt(position)
	local c, r = workspace:GetAttribute("ReachCenter"), workspace:GetAttribute("ReachRadius")
	if typeof(c) == "Vector3" and r and (Vector3.new(position.X - c.X, 0, position.Z - c.Z)).Magnitude <= r then
		return "Reach"
	end
	return nil
end

local function ensureMotes()
	if motePart and motePart.Parent then
		return
	end
	motePart = Instance.new("Part")
	motePart.Name = "AirMotes"
	motePart.Anchored, motePart.CanCollide, motePart.CanQuery, motePart.CanTouch = true, false, false, false
	motePart.Transparency = 1
	motePart.Size = Vector3.new(90, 50, 90)
	motePart.Parent = workspace.CurrentCamera
	motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Lifetime = NumberRange.new(5, 9)
	motes.Speed = NumberRange.new(0.2, 1)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.RotSpeed = NumberRange.new(-60, 60)
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	motes.Rate = 0
	motes.Parent = motePart
end

local function setMotes(kind)
	ensureMotes()
	local m = kind and MOTES[kind]
	if not m then
		motes.Rate = 0
		return
	end
	motes.Color = ColorSequence.new(m.Color)
	motes.Size = NumberSequence.new(m.Size)
	motes.LightEmission = m.Light
	motes.Acceleration = Vector3.new(0.6, m.Fall, 0.3)
	motes.Rate = m.Rate
end

local function blend(name)
	local p = C.Air[name] or C.Air.City
	local info = TweenInfo.new(C.AirBlend, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Density = p.Density, Offset = p.Offset, Haze = p.Haze, Glare = p.Glare, Color = p.Color, Decay = p.Decay }):Play()
	end
	local grade = Lighting:FindFirstChild("CityGrade")
	if grade then
		TweenService:Create(grade, info, { TintColor = p.Tint, Saturation = p.Saturation }):Play()
	end
	setMotes(p.Motes)
	for loop, volume in AMBIENT[name] or AMBIENT.City do
		local sound = Sounds.Loop(loop, 0)
		if sound then
			TweenService:Create(sound, info, { Volume = volume }):Play()
		end
	end
end

local function setToxic(on)
	if not toxicGrade then
		toxicGrade = Instance.new("ColorCorrectionEffect")
		toxicGrade.Name = "ToxicGrade"
		toxicGrade.Enabled = true
		toxicGrade.TintColor = Color3.new(1, 1, 1)
		toxicGrade.Parent = Lighting
	end
	local info = TweenInfo.new(if on then 0.4 else 1.5)
	TweenService:Create(toxicGrade, info, {
		TintColor = if on then Color3.fromRGB(205, 255, 160) else Color3.new(1, 1, 1),
		Saturation = if on then -0.35 else 0,
		Contrast = if on then 0.15 else 0,
	}):Play()
end

function Air.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if motePart and cam then
			motePart.CFrame = CFrame.new(cam.CFrame.Position)
		end
		acc += dt
		if acc < 0.4 then
			return
		end
		acc = 0
		local ok, err = pcall(function()
			local pos = where()
			local name = Megacity.AirAt(pos, regionAt(pos))
			if name ~= current then
				current = name
				blend(name)
			end
		end)
		if not ok and not warned then
			warned = true
			warn("[Air] " .. tostring(err))
		end
	end)
	local function watch(char)
		local was = false
		char:GetAttributeChangedSignal("Toxic"):Connect(function()
			local on = char:GetAttribute("Toxic") == true
			if on ~= was then
				was = on
				setToxic(on)
			end
		end)
		if toxicGrade then
			setToxic(false)
		end
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

-- For tests: the profile in use.
function Air.Current()
	return current
end

return Air
