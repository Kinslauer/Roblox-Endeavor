-- ViewModel: the first-person weapon view. Roblox's first-person mode hides every part of your
-- character, so this draws a separate arm + weapon under the Camera (parts under the Camera are
-- never hidden and render on top of the world) whenever the camera is in first person and a ranged
-- weapon is equipped. This is also the foundation of Universe 2's shooter view.
--
-- Sight picture (the point of the module): the weapon's "Sight" attachment is the aim line - at the
-- rear notch, at sight-top height, looking down the barrel. While aiming down sights the model is
-- placed so that line runs through the camera's origin along the camera's look vector, so the front
-- post sits centred in the rear notch with its top level with the rear posts, and the point of aim
-- is exactly where the server fires (Input sends the camera direction; Combat validates it).
-- From the hip the weapon sits low-right and the reticle is the reference instead.
--
-- Presentation only. Slots live in Presentation.ViewModel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local Weapons = require(ReplicatedStorage.Shared:WaitForChild("Weapons"))
local WeaponView = require(script.Parent.WeaponView)
local CombatFX = require(script.Parent.CombatFX)
local Aim = require(script.Parent.Aim)
local V = Presentation.ViewModel

local player = Players.LocalPlayer
local ViewModel = {}
ViewModel.Visible = false

local model, handle, sightLocal -- current rig; sightLocal = Sight CFrame in handle space
local builtFor -- weapon id the rig was built for
local builtBuilds -- the Builds attribute the rig's parts were drawn from (server/Bench.lua)
local HttpService = game:GetService("HttpService")
local adsAlpha = 0 -- 0 hip .. 1 sights
local recoil = 0 -- current kick (studs back / degrees up), decays
local swayCF = CFrame.identity
local lastCamLook = Vector3.zero

local function rangedWeapon()
	local char = player.Character
	local id = char and char:GetAttribute("Weapon")
	local def = id and Weapons.Defs[id]
	local first = def and def.Attacks and def.Attacks[1]
	return if first and first.Ranged then id else nil
end

local function inFirstPerson(camera)
	if player.CameraMode == Enum.CameraMode.LockFirstPerson then
		return true
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	return head ~= nil and (camera.CFrame.Position - head.Position).Magnitude < V.FirstPersonDistance
end

local function skinColor()
	local char = player.Character
	local hand = char and char:FindFirstChild("RightHand")
	return hand and hand.Color or Color3.fromRGB(230, 200, 180)
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function destroy()
	if model then
		model:Destroy()
	end
	model, handle, sightLocal, builtFor = nil, nil, nil, nil
	ViewModel.Visible = false
end

local function build(weaponId)
	destroy()
	local wm, wh = WeaponView.Build(weaponId)
	if not wm then
		return
	end
	local sight = wh:FindFirstChild("Sight")
	if not sight then
		wm:Destroy()
		return -- weapon has no aim line: nothing to put in front of the eye
	end
	model = Instance.new("Model")
	model.Name = "ViewModel"
	for _, d in wm:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	wm.Parent = model
	handle = wh
	sightLocal = sight.CFrame
	do -- the bench's visible parts (torch, laser) on the first-person gun too
		local ok, builds = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Builds") or "{}")
		WeaponView.AddPartViews(wh, ok and type(builds) == "table" and builds[weaponId] or nil)
		builtBuilds = player:GetAttribute("Builds")
	end
	-- Right arm: forearm + hand behind the grip, in handle space (grip is upright at the origin,
	-- barrel runs -Z). Colours follow the character's skin so it reads as "your" arm.
	local skin = skinColor()
	local hand = part({ Name = "Hand", Size = Vector3.new(0.5, 0.9, 0.6), Color = skin, Material = Enum.Material.SmoothPlastic }, model)
	local forearm = part({ Name = "Forearm", Size = Vector3.new(0.45, 0.45, 1.6), Color = skin, Material = Enum.Material.SmoothPlastic }, model)
	local sleeve = part({ Name = "Sleeve", Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.Fabric }, model)
	-- offsets from the handle, applied every frame after the handle is placed
	model:SetAttribute("Arm", true)
	ViewModel.ArmOffsets = {
		[hand] = CFrame.new(0, -0.05, 0.25),
		[forearm] = CFrame.new(0.15, -0.55, 1.0) * CFrame.Angles(math.rad(-25), math.rad(8), 0),
		[sleeve] = CFrame.new(0.3, -0.9, 1.7) * CFrame.Angles(math.rad(-25), math.rad(8), 0),
	}
	model.PrimaryPart = handle
	model.Parent = workspace.CurrentCamera
	builtFor = weaponId
end

-- Place the rig so its Sight attachment sits at `sightWorld`.
local function place(sightWorld)
	local handleCF = sightWorld * sightLocal:Inverse()
	model:PivotTo(handleCF)
	for p, offset in ViewModel.ArmOffsets do
		p.CFrame = handleCF * offset
	end
end

local function step(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local weaponId = rangedWeapon()
	local show = weaponId ~= nil and inFirstPerson(camera) and Aim.Active()
	if not show then
		if model then
			destroy()
		end
		adsAlpha = 0
		return
	end
	if builtFor ~= weaponId or not model or model.Parent ~= camera or builtBuilds ~= player:GetAttribute("Builds") then
		build(weaponId)
		if not model then
			return
		end
	end
	ViewModel.Visible = true

	-- hip <-> sights blend
	local target = if Aim.ADS then 1 else 0
	local rate = dt / math.max(V.BlendTime, 0.01)
	adsAlpha = adsAlpha + math.clamp(target - adsAlpha, -rate, rate)
	-- sway: the weapon lags the camera turn a little, more from the hip
	local look = camera.CFrame.LookVector
	local turn = look - lastCamLook
	lastCamLook = look
	local swayAmount = V.Sway * (1 - adsAlpha * 0.8)
	local swayTarget = CFrame.Angles(turn.Y * swayAmount, -(camera.CFrame:VectorToObjectSpace(turn).X) * swayAmount, 0)
	swayCF = swayCF:Lerp(swayTarget, math.clamp(dt * 12, 0, 1))
	-- recoil decays back
	recoil = math.max(recoil - dt * V.RecoilRecover, 0)
	local kick = CFrame.new(0, 0, recoil * V.RecoilBack) * CFrame.Angles(math.rad(recoil * V.RecoilPitch), 0, 0)

	local hipOffset = CFrame.new(V.HipOffset) * CFrame.Angles(math.rad(V.HipAngles.X), math.rad(V.HipAngles.Y), math.rad(V.HipAngles.Z))
	local adsOffset = CFrame.new(0, 0, -V.EyeDistance) -- the aim line passes through the camera origin
	local offset = hipOffset:Lerp(adsOffset, adsAlpha)
	place(camera.CFrame * swayCF * offset * kick)
end

local function onSwing(char, info)
	if char ~= player.Character or type(info) ~= "table" or not model then
		return
	end
	recoil = math.min(recoil + (if info.label == "Heavy" then V.RecoilHeavy else V.RecoilLight), 1)
end

function ViewModel.Init()
	RunService:BindToRenderStep("ConduitViewModel", Enum.RenderPriority.Camera.Value + 3, step)
	CombatFX.On("Swing", onSwing)
	player.CharacterRemoving:Connect(destroy)
end

return ViewModel
