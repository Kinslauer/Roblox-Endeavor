-- Limbs: what a broken or lost limb looks like (server/Dismember decides; owner, 2026-11-13: "limbs should
-- specifically fall off ... animate all of that"). For every body in the world, players and enemies:
--   * World "Sever"(model, part, position, direction): blood thrown the way the blow went, a stump that pumps for a
--     while, the body's reaction (Lose_Arm / Lose_Leg animations), a pool where the piece lands.
--   * World "Break"(model, part, position): the crack, and a flinch.
--   * Attributes Broken_<part> / Lost_<part> on the model, every frame after the animation step: a broken arm hangs
--     and swings loose instead of following the animation; a broken leg is carried stiff; a body short of a leg
--     tips onto its good side at each step.
-- The mesh of a lost limb is folded away by shared/Skin; the falling piece and the stump cap are the server's.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Anims = require(Shared:WaitForChild("Anims"))
local ArmIK = require(script.Parent:WaitForChild("ArmIK"))

local D = Config.Dismember
local Limbs = {}

local PARTS = { "ArmL", "ArmR", "LegL", "LegR" }
local JOINTS = { ArmL = { "LeftShoulder", "LeftElbow", "Left" }, ArmR = { "RightShoulder", "RightElbow", "Right" },
	LegL = { "LeftHip", "LeftKnee", "Left" }, LegR = { "RightHip", "RightKnee", "Right" } }
local UPPER = { ArmL = "LeftUpperArm", ArmR = "RightUpperArm", LegL = "LeftUpperLeg", LegR = "RightUpperLeg" }
local BLOOD = Color3.fromRGB(120, 10, 15)

local hurt = {} -- model -> { part = "Broken" | "Lost" }
Limbs.Hurt = hurt

local function joint(model, name)
	local j = model:FindFirstChild(name, true)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return j
	end
	return nil
end

local function read(model)
	local state
	for _, part in PARTS do
		local what = if model:GetAttribute("Lost_" .. part) then "Lost" elseif model:GetAttribute("Broken_" .. part) then "Broken" else nil
		if what then
			state = state or {}
			state[part] = what
		end
	end
	hurt[model] = state
end

local function follow(model)
	if not model:IsA("Model") or model:GetAttribute("LimbsWatched") then
		return
	end
	model:SetAttribute("LimbsWatched", true)
	for _, part in PARTS do
		for _, prefix in { "Lost_", "Broken_" } do
			model:GetAttributeChangedSignal(prefix .. part):Connect(function()
				read(model)
			end)
		end
	end
	model.Destroying:Connect(function()
		hurt[model] = nil
	end)
	read(model)
end

-- blood from a point, thrown along a direction: a short burst and, on a stump, a pulse that dies away
local function emitter(parent, direction, rate, speed)
	local at = Instance.new("Attachment")
	if direction then
		at.WorldCFrame = CFrame.lookAt(parent.Position, parent.Position + direction)
	end
	at.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(BLOOD)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.08) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(22, 22)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = rate
	e.LightInfluence = 1
	e.Parent = at
	return e, at
end

local function pool(position, size)
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0))
	if not hit then
		return
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Color = Color3.fromRGB(96, 8, 12)
	p.Material = Enum.Material.SmoothPlastic
	p.Size = Vector3.new(0.06, 0.4, 0.4)
	p.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = workspace
	game:GetService("TweenService"):Create(p, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.06, size, size) }):Play()
	Debris:AddItem(p, Config.Gore.PoolLifetime)
end

local function sever(model, part, position, direction)
	if typeof(model) ~= "Instance" then
		return
	end
	follow(model)
	local upper = model:FindFirstChild(UPPER[part] or "")
	local stump = upper and upper:FindFirstChild("Stump")
	local at = if typeof(position) == "Vector3" then position else (upper and upper.Position)
	if not at then
		return
	end
	local dir = if typeof(direction) == "Vector3" and direction.Magnitude > 0.05 then direction.Unit else Vector3.yAxis
	Sounds.Play("ImpactFlesh", at, { Volume = 1, Pitch = 0.7 })
	Sounds.Play("GuardBreak", at, { Volume = 0.5, Pitch = 1.4 })
	-- the cut: a hard burst the way the blade went
	local carrier = Instance.new("Part")
	carrier.Anchored, carrier.CanCollide, carrier.CanQuery, carrier.Transparency = true, false, false, 1
	carrier.Size = Vector3.one * 0.2
	carrier.Position = at
	carrier.Parent = workspace
	local burst = emitter(carrier, dir + Vector3.new(0, 0.5, 0), 0, 26)
	burst:Emit(46)
	Debris:AddItem(carrier, 1.5)
	-- the stump pumps, weaker each beat
	if stump then
		local e, a = emitter(stump, nil, 0, 13)
		a.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- out of the end of the limb (down the upper arm)
		task.spawn(function()
			for beat = 1, 14 do
				if not stump.Parent then
					break
				end
				e:Emit(math.max(3, 16 - beat))
				if beat % 3 == 1 then
					pool(stump.Position, 1.2 + beat * 0.12)
				end
				task.wait(0.55 + beat * 0.03)
			end
			a:Destroy()
		end)
	end
	pool(at + dir * 2.5, 2.2)
	if Anims.Mine(model) then
		local name = "Lose_" .. part
		if Anims.Has(name) then
			Anims.Play(model, name, { fade = 0.05, weight = 9 })
		end
	end
end

local function broke(model, part, position)
	if typeof(model) ~= "Instance" then
		return
	end
	follow(model)
	local at = if typeof(position) == "Vector3" then position else (model:FindFirstChild("HumanoidRootPart") and model.HumanoidRootPart.Position)
	if at then
		Sounds.Play("GuardBreak", at, { Volume = 0.9, Pitch = 1.7 })
		Sounds.Play("ImpactFlesh", at, { Volume = 0.7, Pitch = 0.85 })
	end
	if Anims.Mine(model) and Anims.Has("Hit_Heavy") then
		Anims.Play(model, "Hit_Heavy", { fade = 0.04, weight = 7 })
	end
end

-- after the animation step: the limp arm, the stiff leg, the hop
local function step()
	local now = os.clock()
	for model, state in hurt do
		if not model.Parent then
			hurt[model] = nil
			continue
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local moving = hum and hum.MoveDirection.Magnitude > 0.1
		for part, what in state do
			local names = JOINTS[part]
			local a, b = joint(model, names[1]), joint(model, names[2])
			if not (a and b) then
				continue
			end
			local side = if names[3] == "Right" then 1 else -1
			if part == "ArmL" or part == "ArmR" then
				if what == "Broken" and not ArmIK.Active(model, names[3]) then
					-- it hangs from the shoulder and swings with the body instead of doing what the animation asks
					local sway = math.sin(now * (if moving then 7 else 2.2) + side) * (if moving then 9 else 2.5)
					a.Transform = a.Transform:Lerp(CFrame.Angles(math.rad(sway), 0, math.rad(side * 5)), D.Limp.Arm)
					b.Transform = b.Transform:Lerp(CFrame.Angles(math.rad(10 + sway * 0.6), 0, 0), D.Limp.Arm)
				end
			else
				if what == "Broken" then
					-- carried stiff: it keeps only part of the stride
					a.Transform = CFrame.identity:Lerp(a.Transform, D.Limp.Leg)
					b.Transform = CFrame.identity:Lerp(b.Transform, D.Limp.Leg * 0.6)
				end
				if moving then
					-- short of a leg, or sparing one: the body drops onto that side each step and heaves back
					local root = joint(model, "Root")
					if root then
						local beat = math.abs(math.sin(now * 5.5))
						local deep = if what == "Lost" then 1 else 0.5
						root.Transform = CFrame.new(0, -0.22 * deep * beat, 0) * CFrame.Angles(0, 0, math.rad(-side * 9 * deep * beat)) * root.Transform
					end
				end
			end
		end
	end
end

function Limbs.Start()
	local function watchCharacter(char)
		follow(char)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			watchCharacter(p.Character)
		end
		p.CharacterAdded:Connect(watchCharacter)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(watchCharacter)
	end)
	for _, tag in { "NPC", "Corpse" } do
		for _, m in CollectionService:GetTagged(tag) do
			follow(m)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(follow)
	end
	Remotes.World.OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "Sever" then
			sever(a, b, c, d)
		elseif kind == "Break" then
			broke(a, b, c)
		end
	end)
	RunService.Stepped:Connect(step)
end

return Limbs
