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
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local Weapons = require(ReplicatedStorage.Shared:WaitForChild("Weapons"))
local Attachments = require(ReplicatedStorage.Shared:WaitForChild("Attachments"))
local HttpService = game:GetService("HttpService")
local Hud = require(script.Parent.Hud)
local CameraShake = require(script.Parent.CameraShake)
local CombatFX = require(script.Parent.CombatFX)
local TweenService = game:GetService("TweenService")
local A = Presentation.Aim

local player = Players.LocalPlayer

local Aim = {}
Aim.Enabled = A.DefaultOn

local function humanoidOf()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

-- The camera preset for what the character holds (Presentation.Aim.Melee / Ranged).
local function presetFor()
	local char = player.Character
	local def = char and Weapons.Defs[char:GetAttribute("Weapon") or ""] or Weapons.Defs.Fists
	local preset = if Weapons.IsGun(def) then A.Ranged else A.Melee
	return preset or {}, Weapons.IsGun(def)
end

-- Pin the third-person distance for a frame, then let the player scroll again.
local pinToken = 0
local function setDistance(distance)
	if not distance or player.CameraMode == Enum.CameraMode.LockFirstPerson then
		return
	end
	pinToken += 1
	local token = pinToken
	local minZ, maxZ = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = distance, distance
	task.delay(0.1, function()
		if token == pinToken then
			player.CameraMinZoomDistance, player.CameraMaxZoomDistance = math.min(minZ, distance), math.max(maxZ, distance)
		end
	end)
end

local function apply()
	local hum = humanoidOf()
	if hum then
		local preset = presetFor()
		hum.CameraOffset = if Aim.Enabled and not Aim.ADS and not Aim.FirstPerson then (preset.ShoulderOffset or A.ShoulderOffset) else Vector3.zero
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

-- Recoil (design/gdd/gunplay.md; numbers in Weapons.Defs[id].Gun.Recoil, defaults in
-- Config.Gunplay.DefaultGun): the camera itself kicks on every shot and settles back at Recover
-- degrees per second. Shots go along the camera (Input sends its LookVector), so recoil is honest -
-- the next shot lands where the kicked view points, and pulling down against it is a real skill.
-- A Pattern (list of {pitch, yaw}) replaces the random kick for consecutive shots.
-- Roblox's camera reads its own CFrame back every frame, so the kick is delivered as rotation
-- *deltas*: the impulse over KICK_TIME seconds, then the same amount back at Recover deg/s. If
-- you pull down against it meanwhile, the view ends lower than where it started - that is the
-- compensation skill, not a bug.
local KICK_TIME = 0.07
local pendingPitch, pendingYaw = 0, 0 -- still to deliver
local appliedPitch, appliedYaw = 0, 0 -- delivered, still to recover
local deliverRate, recoverRate = 0, 8 -- deg/s
local patternIndex, lastShotAt = 0, 0
local recoilRng = Random.new()

function Aim.Kick(pitch, yaw, recover)
	pendingPitch += pitch
	pendingYaw += yaw
	-- the whole pending kick lands within KICK_TIME; recovery waits until it has
	deliverRate = math.max(deliverRate, (math.abs(pendingPitch) + math.abs(pendingYaw)) / KICK_TIME)
	recoverRate = recover or recoverRate
end

local function towardZero(x, step)
	return if math.abs(x) <= step then 0 else x - math.sign(x) * step
end

local function applyRecoil(dt)
	if pendingPitch == 0 and pendingYaw == 0 and appliedPitch == 0 and appliedYaw == 0 then
		return
	end
	local dPitch, dYaw = 0, 0
	if pendingPitch ~= 0 or pendingYaw ~= 0 then
		-- deliver the pending kick at deliverRate (split by how much of each axis is left)
		local total = math.abs(pendingPitch) + math.abs(pendingYaw)
		local budget = math.min(total, deliverRate * dt)
		dPitch = pendingPitch * (budget / total)
		dYaw = pendingYaw * (budget / total)
		pendingPitch -= dPitch
		pendingYaw -= dYaw
		appliedPitch += dPitch
		appliedYaw += dYaw
		if pendingPitch == 0 and pendingYaw == 0 then
			deliverRate = 0
		end
	else
		-- nothing left to deliver: settle back at recoverRate
		local step = recoverRate * dt
		local rPitch, rYaw = towardZero(appliedPitch, step), towardZero(appliedYaw, step)
		dPitch, dYaw = rPitch - appliedPitch, rYaw - appliedYaw
		appliedPitch, appliedYaw = rPitch, rYaw
	end
	local camera = workspace.CurrentCamera
	if camera and (dPitch ~= 0 or dYaw ~= 0) then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(dPitch), math.rad(dYaw), 0)
	end
end

-- Our weapon builds (server/Bench.lua publishes them as one JSON player attribute).
local builds = {}
local function readBuilds()
	local raw = player:GetAttribute("Builds")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw or "{}")
	builds = if ok and type(decoded) == "table" then decoded else {}
end
player:GetAttributeChangedSignal("Builds"):Connect(readBuilds)
readBuilds()
local function buildOf(weaponId)
	return builds[weaponId]
end

-- Our own ranged Swing: kick by the weapon's recoil spec (pattern position resets after a pause).
local function onOwnSwing(char, info)
	if char ~= player.Character or type(info) ~= "table" then
		return
	end
	local def = Weapons.Defs[info.weapon]
	if not Weapons.IsGun(def) then
		return
	end
	def = Attachments.Apply(def, buildOf(info.weapon)) -- the bench's parts change the kick (shared/Attachments.lua)
	local R = (def.Gun and def.Gun.Recoil) or Config.Gunplay.DefaultGun.Recoil
	local now = os.clock()
	patternIndex = if now - lastShotAt > 0.6 then 1 else patternIndex + 1
	lastShotAt = now
	local kick = R.Pattern and R.Pattern[math.min(patternIndex, #R.Pattern)]
	local pitch = if kick then kick[1] else R.Pitch
	local yaw = if kick then kick[2] else R.Yaw * recoilRng:NextNumber(-1, 1)
	local heavy = info.label == "Heavy"
	local mult = (if heavy then 2.2 else 1) * (if Aim.ADS then 0.85 else 1)
	Aim.Kick(pitch * mult, yaw * mult, R.Recover)
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

-- Sprint reads as a small FOV push (Config.Sprint.FovBoost) on whatever the base FOV is.
local function baseFov()
	local fov = if Aim.ADS then A.ADS.Fov elseif Aim.FirstPerson then A.FirstPersonFov else A.ADS.NormalFov
	local char = player.Character
	if char and char:GetAttribute("Sprinting") and not Aim.ADS then
		fov += Config.Sprint.FovBoost
	end
	return fov
end

-- Remember the third-person zoom when we lock to first person and put it back on the way out
-- (Roblox otherwise returns you to a default distance). The restore pins Min/Max zoom to the saved
-- distance for one frame, then releases them.
local savedZoom, zoomLimits
local function currentZoom()
	local camera, char = workspace.CurrentCamera, player.Character
	local head = char and char:FindFirstChild("Head")
	if camera and head then
		return (camera.CFrame.Position - head.Position).Magnitude
	end
	return nil
end

local function restoreZoom()
	if not savedZoom then
		return
	end
	local zoom = savedZoom
	savedZoom = nil
	zoomLimits = zoomLimits or { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = zoom, zoom
	task.delay(0.1, function()
		player.CameraMinZoomDistance, player.CameraMaxZoomDistance = zoomLimits[1], zoomLimits[2]
	end)
end

local function applyCameraMode()
	local first = Aim.FirstPerson or (Aim.ADS and A.ADS.FirstPerson)
	local wasFirst = player.CameraMode == Enum.CameraMode.LockFirstPerson
	if first and not wasFirst then
		local z = currentZoom()
		if z and z > 1.5 then
			savedZoom = z
		end
	end
	player.CameraMode = if first then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	if not first and wasFirst then
		restoreZoom()
	end
end

function Aim.SetFirstPerson(on)
	Aim.FirstPerson = on == true
	applyCameraMode()
	setFov(baseFov())
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
	setFov(baseFov())
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
	local function watchSprint(char)
		char:GetAttributeChangedSignal("Sprinting"):Connect(function()
			setFov(baseFov())
		end)
	end
	-- the camera preset follows the weapon type: melee far and high, guns in close
	local lastGun = nil
	local function watchWeapon(char)
		local function refresh(force)
			local preset, gun = presetFor()
			apply()
			if force or gun ~= lastGun then
				lastGun = gun
				setDistance(preset.Distance)
			end
		end
		char:GetAttributeChangedSignal("Weapon"):Connect(refresh)
		task.delay(0.5, refresh, true) -- a fresh body: the default camera distance is Roblox's, not ours
	end
	player.CharacterAdded:Connect(function(char)
		task.defer(apply)
		watchSprint(char)
		watchWeapon(char)
	end)
	if player.Character then
		watchSprint(player.Character)
		watchWeapon(player.Character)
	end
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
	RunService:BindToRenderStep("ConduitRecoil", Enum.RenderPriority.Camera.Value + 1, applyRecoil) -- before Aim / ViewModel read the camera
	RunService:BindToRenderStep("ConduitAim", Enum.RenderPriority.Camera.Value + 2, lockMouse)
	CombatFX.On("Swing", onOwnSwing)
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
