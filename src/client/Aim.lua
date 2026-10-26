-- Aim (brief build-order 2): combat stance. While on, the character faces where the camera looks,
-- the camera sits over the right shoulder and the mouse drives the view, so melee cones and the
-- arc pistol (both fire along the character's facing on the server) go where you look.
-- Toggle with Presentation.Aim.ToggleKey; on by default. The stance pauses (cursor freed, body
-- stops tracking) while a menu needs the mouse - the character creator, a HUD panel, or while
-- Presentation.Aim.FreeCursorKey is held. Pure client: the server never knows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GameSettings = UserSettings():GetService("UserGameSettings")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local Hud = require(script.Parent.Hud)
local CameraShake = require(script.Parent.CameraShake)
local TweenService = game:GetService("TweenService")
local A = Presentation.Aim

local player = Players.LocalPlayer

local Aim = {}
Aim.Enabled = A.DefaultOn

local function humanoidOf()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

local function apply()
	local hum = humanoidOf()
	if hum then
		hum.CameraOffset = if Aim.Enabled and not Aim.ADS and not Aim.FirstPerson then A.ShoulderOffset else Vector3.zero
		hum.AutoRotate = not Aim.Enabled
	end
	-- CameraRelative makes the character face the camera's yaw while moving; the step below
	-- keeps it facing while standing still too.
	GameSettings.RotationType = if Aim.Enabled then Enum.RotationType.CameraRelative else Enum.RotationType.MovementRelative
	if not Aim.Enabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- Runs on Heartbeat (after physics): turn the body to the camera's yaw while standing still.
-- Heartbeat rather than RenderStepped so it also works when Studio is not rendering (minimised).
local function faceCamera()
	if not Aim.Active() then
		return
	end
	local hum, root = humanoidOf()
	if not hum or not root or hum.Health <= 0 or hum.Sit or hum.PlatformStand then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		return
	end
	-- Only yaw: keep the physics-owned position, turn the body toward the camera.
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

-- Runs after Roblox's camera scripts each rendered frame: they reset MouseBehavior, so we re-lock it.
local function lockMouse()
	if Aim.Enabled then
		UserInputService.MouseBehavior = if Aim.Active() then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	end
end

-- The stance is actually steering the camera/body right now (on, and no menu wants the mouse).
function Aim.Active()
	return Aim.Enabled and not Hud.MenuOpen() and not UserInputService:IsKeyDown(A.FreeCursorKey)
end

-- First-person mode (Presentation.Aim.FirstPersonKey): camera locked to the head, hip-fire view
-- model when a ranged weapon is held. ADS works on top of it; leaving ADS returns here, not to the
-- shoulder camera. The shooter universe runs with this forced on.
Aim.FirstPerson = false
local fovTween
local function setFov(fov)
	local camera = workspace.CurrentCamera
	CameraShake.BaseFov = fov
	if camera then
		if fovTween then
			fovTween:Cancel()
		end
		fovTween = TweenService:Create(camera, TweenInfo.new(A.ADS.ZoomTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov })
		fovTween:Play()
	end
end

local function applyCameraMode()
	local first = Aim.FirstPerson or (Aim.ADS and A.ADS.FirstPerson)
	player.CameraMode = if first then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
end

function Aim.SetFirstPerson(on)
	Aim.FirstPerson = on == true
	applyCameraMode()
	if not Aim.ADS then
		setFov(if Aim.FirstPerson then A.FirstPersonFov else A.ADS.NormalFov)
	end
	apply()
end

-- Aim down sights (ranged weapons, right mouse held): first person + narrow FOV while on.
Aim.ADS = false
function Aim.SetADS(on)
	on = on and Aim.Enabled and not Hud.MenuOpen()
	if on == Aim.ADS then
		return
	end
	Aim.ADS = on
	setFov(if on then A.ADS.Fov elseif Aim.FirstPerson then A.FirstPersonFov else A.ADS.NormalFov)
	applyCameraMode()
	apply()
end

function Aim.Set(on)
	Aim.Enabled = on
	if not on then
		Aim.SetADS(false)
	end
	apply()
end

function Aim.Init()
	player.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
	-- the server forces first person in shooter zones through a player attribute
	local forcedOn = false
	local function forced()
		if player:GetAttribute("ForceFirstPerson") then
			forcedOn = true
			Aim.SetFirstPerson(true)
		elseif forcedOn then
			forcedOn = false
			Aim.SetFirstPerson(false)
		end
	end
	player:GetAttributeChangedSignal("ForceFirstPerson"):Connect(forced)
	forced()
	apply()
	RunService.Heartbeat:Connect(faceCamera)
	RunService:BindToRenderStep("ConduitAim", Enum.RenderPriority.Camera.Value + 2, lockMouse)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == A.ToggleKey then
			if Hud.MenuOpen() then
				Hud.CloseAll() -- "lock my camera" while a panel is up means: put the panels away
			else
				Aim.Set(not Aim.Enabled)
			end
		elseif input.KeyCode == A.FirstPersonKey and not Hud.MenuOpen() and not player:GetAttribute("ForceFirstPerson") then
			Aim.SetFirstPerson(not Aim.FirstPerson)
		end
	end)
end

return Aim
