-- Stopgap locomotion animations. Our characters are built by the server (see server/Rig.lua),
-- so Roblox's default Animate script never runs for them. This plays the stock R15 animations
-- until the real per-weapon set exists. Ids are Roblox's default R15 animations; swap freely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IDS = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation")).Locomotion

local player = Players.LocalPlayer

local function setup(char)
	local hum = char:WaitForChild("Humanoid")
	local animator = hum:WaitForChild("Animator")
	local tracks = {}
	for name, id in IDS do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Priority = if name == "idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
		track.Looped = name ~= "jump"
		tracks[name] = track
	end

	local current
	local function play(name, speed)
		local track = tracks[name]
		if current ~= track then
			if current then
				current:Stop(0.15)
			end
			current = track
			track:Play(0.15)
		end
		if speed then
			track:AdjustSpeed(speed)
		end
	end

	local function locomote(speed)
		if hum.FloorMaterial == Enum.Material.Air then
			return
		end
		if speed < 0.5 then
			play("idle")
		elseif speed < 17 then
			play("walk", speed / 14.5)
		else
			play("run", speed / 16)
		end
	end

	hum.Running:Connect(locomote)
	hum.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Jumping then
			play("jump")
		elseif state == Enum.HumanoidStateType.Freefall then
			play("fall")
		elseif state == Enum.HumanoidStateType.Landed then
			locomote(hum.MoveDirection.Magnitude * hum.WalkSpeed)
		end
	end)
	play("idle")
end

player.CharacterAdded:Connect(setup)
if player.Character then
	task.spawn(setup, player.Character)
end
