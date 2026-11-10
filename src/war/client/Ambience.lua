-- The Front's weather, drawn on each client: ash falling around the camera, guns flashing on the horizon
-- beyond the outer barrows, and a shudder of dust when a crest grows from the dead (World "CrestGrew").
-- Nothing here explains anything; it only shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Ambience = {}

local camera = workspace.CurrentCamera
local holder

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end

-- Ash: a box of slow grey flakes that follows the camera.
local function ash()
	holder = make("Part", { Name = "AshFall", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(120, 1, 120) }, workspace)
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 144, 136), Color3.fromRGB(96, 92, 88)),
		Size = NumberSequence.new(0.18, 0.12),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(0.85, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(9, 14),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(1.5, -0.6, 0.8),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightInfluence = 1,
	}, holder)
	RunService.RenderStepped:Connect(function()
		local p = camera.CFrame.Position
		holder.CFrame = CFrame.new(p.X, p.Y + 40, p.Z)
	end)
end

-- Distant guns: a flash low on the horizon every few seconds, sometimes a rolling boom a beat later.
local function horizon()
	local rng = Random.new()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(2.5, 9))
			local a = rng:NextNumber(0, math.pi * 2)
			local origin = camera.CFrame.Position
			local at = Vector3.new(origin.X + math.cos(a) * 1500, 30 + rng:NextNumber(0, 40), origin.Z + math.sin(a) * 1500)
			local flash = make("Part", { Name = "GunFlash", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 190, 120), Shape = Enum.PartType.Ball, Size = Vector3.new(60, 30, 60), Position = at, Transparency = 0.55, CastShadow = false }, workspace)
			make("PointLight", { Color = Color3.fromRGB(255, 170, 100), Range = 60, Brightness = 3 }, flash)
			for _ = 1, rng:NextInteger(1, 3) do
				task.wait(0.06)
				flash.Transparency = 0.55 + rng:NextNumber(0, 0.4)
			end
			Debris:AddItem(flash, 0.35)
			if rng:NextNumber() < 0.4 then
				task.delay(rng:NextNumber(1.5, 3.5), function()
					Sounds.Play("ShotDistant", nil, { Volume = 0.25, Pitch = 0.45 })
				end)
			end
		end
	end)
end

-- A crest grew: dust breathes off it and the ground groans.
local function crestGrew(position)
	local p = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(16, 1, 16), Position = position }, workspace)
	local e = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(196, 188, 170)),
		Size = NumberSequence.new(3, 10),
		Transparency = NumberSequence.new(0.5, 1),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(80, 80),
		Rate = 0,
	}, p)
	e:Emit(30)
	Sounds.Play("Collapse", position, { Volume = 0.6, Pitch = 0.5, Range = 300 })
	Debris:AddItem(p, 6)
end

function Ambience.Init()
	ash()
	horizon()
	Remotes.World.OnClientEvent:Connect(function(kind, _, position)
		if kind == "CrestGrew" and typeof(position) == "Vector3" then
			crestGrew(position)
		end
	end)
end

return Ambience
