-- CameraShake (story 003): one additive shaker for the local camera plus a FOV "hitstop" punch.
-- Runs after Roblox's camera scripts each frame (BindToRenderStep at Camera + 1), so it only ever
-- offsets what the default camera already decided and never fights it. Tuning: Presentation.Camera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local CAM = Presentation.Camera

local CameraShake = {}

local trauma = 0 -- 0..1, decays to 0; amplitude is applied squared so small hits stay subtle
local seed = math.random() * 100
local fovTween, baseFov

-- amount: 0..1 (Presentation.Impacts[kind].Shake). Stacks, capped at 1.
function CameraShake.Add(amount)
	if amount and amount > 0 then
		trauma = math.min(1, trauma + amount)
	end
end

-- seconds: a brief FOV punch that reads as the frame "catching" on impact.
function CameraShake.Hitstop(seconds)
	if not seconds or seconds <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if fovTween then
		fovTween:Cancel()
	else
		baseFov = camera.FieldOfView
	end
	camera.FieldOfView = baseFov + CAM.HitstopFov
	fovTween = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = baseFov })
	fovTween.Completed:Once(function()
		fovTween = nil
	end)
	fovTween:Play()
end

local function step(dt)
	if trauma <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local t = os.clock() * CAM.ShakeFrequency
	local amp = trauma * trauma * CAM.ShakeMagnitude
	local offset = Vector3.new(
		(math.noise(seed, t, 0) * 2) * amp,
		(math.noise(seed + 10, t, 0) * 2) * amp,
		0
	)
	local roll = math.noise(seed + 20, t, 0) * 2 * amp * 0.05
	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
	trauma = math.max(0, trauma - dt / CAM.ShakeDecay)
end

function CameraShake.Init()
	RunService:BindToRenderStep("ConduitCameraShake", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraShake
