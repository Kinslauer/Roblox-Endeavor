-- WeaponView (story 004, ADR-0004): draws the held weapon in every character's right hand, driven
-- by the replicated "Weapon" attribute Gear sets. Procedural part-built placeholders per
-- Presentation.Weapons[id].Build, or a clone of ReplicatedStorage.Assets.Weapons[ModelName] when
-- that slot is filled. Everything is client-side cosmetic: massless, non-colliding, under the
-- character in a Model named "WeaponView", so it dies with the character and never touches the
-- server hitbox (which filters the whole character out anyway).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presentation = require(Shared:WaitForChild("Presentation"))
local Attachments = require(Shared:WaitForChild("Attachments"))
local HttpService = game:GetService("HttpService")
local W = Presentation.Weapons

local WeaponView = {}

local MODEL_NAME = "WeaponView"
local HAND_WAIT = 5 -- seconds to wait for the hand part on a freshly spawned character

local current = setmetatable({}, { __mode = "k" }) -- char -> weaponId currently drawn

local function handOf(char)
	return char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.CastShadow = false
	for k, v in props do
		p[k] = v
	end
	return p
end

-- Each builder returns (model, handle, gripHalf): the Model, its gripped "Handle" part, and how far
-- the Handle's centre sits below the fist. Cylinder handles are rolled 90° so their X axis stands
-- on Y; "down the shaft" is then Handle local -X. Everything else is welded relative to the Handle.
local Builders = {}

local function weldTo(handle, child, offset)
	child.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = handle, child
	w.Parent = child
	child.Parent = handle.Parent
end

Builders.Club = function(spec)
	local model = Instance.new("Model")
	local handle = part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(spec.Length, 0.35, 0.35), Color = spec.Color, Material = Enum.Material.Metal })
	handle.Parent = model
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis is X; stand it on Y
	local head = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.0, 0.6, 0.6), Color = spec.Color, Material = Enum.Material.DiamondPlate })
	weldTo(handle, head, CFrame.new(-spec.Length / 2 + 0.4, 0, 0))
	return model, handle, spec.Length / 2
end

Builders.Blade = function(spec)
	local model = Instance.new("Model")
	local handle = part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.28, 0.28), Color = Color3.fromRGB(40, 35, 30), Material = Enum.Material.Fabric })
	handle.Parent = model
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local guard = part({ Size = Vector3.new(0.15, 0.3, 0.9), Color = spec.Color, Material = Enum.Material.CorrodedMetal })
	weldTo(handle, guard, CFrame.new(-0.5, 0, 0))
	local blade = part({ Size = Vector3.new(spec.Length - 1.2, 0.12, 0.55), Color = spec.Accent or spec.Color, Material = Enum.Material.CorrodedMetal })
	weldTo(handle, blade, CFrame.new(-0.55 - (spec.Length - 1.2) / 2, 0, 0))
	return model, handle, 0.45
end

Builders.Baton = function(spec)
	local model = Instance.new("Model")
	local handle = part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(spec.Length, 0.3, 0.3), Color = spec.Color, Material = Enum.Material.SmoothPlastic })
	handle.Parent = model
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local tip = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.4, 0.4), Color = spec.Accent or spec.Color, Material = Enum.Material.Neon })
	weldTo(handle, tip, CFrame.new(-spec.Length / 2 + 0.2, 0, 0))
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = tip.Color, 1.5, 6
	light.Parent = tip
	return model, handle, spec.Length / 2
end

Builders.Spear = function(spec)
	local model = Instance.new("Model")
	local handle = part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(spec.Length, 0.25, 0.25), Color = spec.Color, Material = Enum.Material.Wood })
	handle.Parent = model
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local head = part({ Shape = Enum.PartType.Wedge, Size = Vector3.new(0.12, 1.1, 0.4), Color = spec.Accent or spec.Color, Material = Enum.Material.Metal })
	weldTo(handle, head, CFrame.new(-spec.Length / 2 - 0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)))
	return model, handle, spec.Length / 2
end

Builders.Hammer = function(spec)
	local model = Instance.new("Model")
	local handle = part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(spec.Length, 0.35, 0.35), Color = spec.Color, Material = Enum.Material.Wood })
	handle.Parent = model
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	local head = part({ Size = Vector3.new(0.9, 0.9, 1.4), Color = spec.Accent or spec.Color, Material = Enum.Material.Metal })
	weldTo(handle, head, CFrame.new(-spec.Length / 2 + 0.3, 0, 0))
	return model, handle, spec.Length / 2
end

-- Iron sights for any barrel that runs along the Handle's -Z with its top at `top`. Rear: two posts
-- leaving a notch at z = Rear; front: one post + a glowing bead at z = Front. Both stand `Height`
-- tall, so their tops share one line. The "Sight" attachment is that line: at the rear notch, at
-- sight-top height, looking down the barrel. ViewModel puts the camera on it, so the front post sits
-- centred in the notch with tops level - the classic picture; the shot goes where the post's top is.
local function addSights(handle, spec, top, length)
	local S = spec.Sights or { Height = 0.14, Width = 0.08, NotchWidth = 0.14, Rear = 0.2, Front = -length + 0.4, Color = Color3.fromRGB(20, 20, 24), Dot = Color3.fromRGB(120, 255, 120) }
	for _, x in { -(S.NotchWidth / 2 + S.Width / 2), S.NotchWidth / 2 + S.Width / 2 } do
		local post = part({ Name = "RearSight", Size = Vector3.new(S.Width, S.Height, 0.1), Color = S.Color, Material = Enum.Material.SmoothPlastic })
		weldTo(handle, post, CFrame.new(x, top + S.Height / 2, S.Rear))
	end
	local front = part({ Name = "FrontSight", Size = Vector3.new(S.Width, S.Height, 0.08), Color = S.Color, Material = Enum.Material.SmoothPlastic })
	weldTo(handle, front, CFrame.new(0, top + S.Height / 2, S.Front))
	local dot = part({ Name = "FrontDot", Size = Vector3.new(S.Width * 0.6, S.Width * 0.6, 0.02), Color = S.Dot, Material = Enum.Material.Neon })
	weldTo(handle, dot, CFrame.new(0, top + S.Height - S.Width * 0.45, S.Front + 0.05))
	local sight = Instance.new("Attachment")
	sight.Name = "Sight"
	sight.CFrame = CFrame.new(0, top + S.Height, S.Rear)
	sight.Parent = handle
end

Builders.Pistol = function(spec)
	local model = Instance.new("Model")
	-- The grip is the Handle (held upright in the fist); the body sits on top and runs forward (-Z),
	-- so the barrel points where the hand points.
	local handle = part({ Name = "Handle", Size = Vector3.new(0.3, 0.8, 0.45), Color = spec.Color, Material = Enum.Material.SmoothPlastic })
	handle.Parent = model
	local body = part({ Size = Vector3.new(0.4, 0.5, spec.Length), Color = spec.Color, Material = Enum.Material.Metal })
	weldTo(handle, body, CFrame.new(0, 0.5, -spec.Length / 2 + 0.3))
	local emitter = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.3, 0.3), Color = spec.Accent or spec.Color, Material = Enum.Material.Neon })
	weldTo(handle, emitter, CFrame.new(0, 0.5, -spec.Length + 0.3) * CFrame.Angles(0, math.rad(90), 0))
	emitter.Name = "Muzzle" -- the bolt starts here (client/Impacts.lua onBolt)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = emitter.Color, 1, 4
	light.Parent = emitter
	addSights(handle, spec, 0.75, spec.Length)
	return model, handle, 0
end

Builders.Rifle = function(spec)
	local model = Instance.new("Model")
	-- Pistol grip is the Handle; receiver + barrel run forward (-Z), stock runs back (+Z).
	local handle = part({ Name = "Handle", Size = Vector3.new(0.3, 0.9, 0.5), Color = spec.Color, Material = Enum.Material.SmoothPlastic })
	handle.Parent = model
	local receiver = part({ Size = Vector3.new(0.45, 0.55, 1.6), Color = spec.Color, Material = Enum.Material.Metal })
	weldTo(handle, receiver, CFrame.new(0, 0.5, -0.4))
	local barrel = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(spec.Length - 1.2, 0.22, 0.22), Color = Color3.fromRGB(70, 74, 84), Material = Enum.Material.Metal })
	weldTo(handle, barrel, CFrame.new(0, 0.6, -1.2 - (spec.Length - 1.2) / 2) * CFrame.Angles(0, math.rad(90), 0))
	local foreEnd = part({ Size = Vector3.new(0.4, 0.4, 1.0), Color = spec.Color, Material = Enum.Material.SmoothPlastic })
	weldTo(handle, foreEnd, CFrame.new(0, 0.3, -1.7))
	local stock = part({ Size = Vector3.new(0.35, 0.5, 1.0), Color = spec.Color, Material = Enum.Material.SmoothPlastic })
	weldTo(handle, stock, CFrame.new(0, 0.35, 0.9))
	local emitter = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.3, 0.3), Color = spec.Accent or spec.Color, Material = Enum.Material.Neon })
	weldTo(handle, emitter, CFrame.new(0, 0.6, -spec.Length + 0.1) * CFrame.Angles(0, math.rad(90), 0))
	emitter.Name = "Muzzle" -- the bolt starts here (client/Impacts.lua onBolt)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = emitter.Color, 1, 5
	light.Parent = emitter
	local cell = part({ Size = Vector3.new(0.2, 0.3, 0.6), Color = spec.Accent or spec.Color, Material = Enum.Material.Neon, Transparency = 0.3 })
	weldTo(handle, cell, CFrame.new(0, 0.5, -0.4) * CFrame.new(0.3, 0, 0)) -- glowing power cell on the right of the receiver
	addSights(handle, spec, 0.775, spec.Length) -- receiver top is at 0.5 + 0.275
	return model, handle, 0
end

-- Build a weapon's procedural model without attaching it to anyone (the first-person ViewModel).
-- Returns model, handle or nil when the weapon has no procedural build.
function WeaponView.Build(weaponId)
	local spec = W[weaponId]
	local builder = spec and spec.Build and Builders[spec.Build]
	if not builder then
		return nil
	end
	local model, handle = builder(spec)
	model.Name = "Weapon"
	model.PrimaryPart = handle
	return model, handle
end

local function clear(char)
	local old = char:FindFirstChild(MODEL_NAME)
	if old then
		old:Destroy()
	end
	current[char] = nil
end

-- The bench's parts, as far as they show: a torch (TacLight) and a laser (LaserSight) on the
-- handle, driven by the owner's Builds attribute (server/Bench.lua). Stat changes are invisible here.
local function buildOf(char, weaponId)
	local owner = Players:GetPlayerFromCharacter(char)
	local raw = owner and owner:GetAttribute("Builds")
	if not raw then
		return nil
	end
	local ok, builds = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(builds) == "table" and builds[weaponId] or nil
end

local function addPartViews(char, weaponId, model, handle)
	WeaponView.AddPartViews(handle, buildOf(char, weaponId))
end

-- Also used by ViewModel for the first-person gun. `build` = { [slot] = partId } or nil.
function WeaponView.AddPartViews(handle, build)
	if not (build and handle) then
		return
	end
	local eff = Attachments.Apply({ Attacks = { { Ranged = true } }, Gun = {} }, build)
	if eff.Light then
		local torch = Instance.new("SpotLight")
		torch.Name = "TacLight"
		torch.Face = Enum.NormalId.Front
		torch.Angle, torch.Range, torch.Brightness = 40, eff.Light, 3
		torch.Color = Color3.fromRGB(255, 245, 220)
		torch.Parent = handle
	end
	if eff.Laser then
		local a0 = Instance.new("Attachment")
		a0.CFrame = CFrame.new(0.15, 0.5, -0.3)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.CFrame = CFrame.new(0.15, 0.5, -60)
		a1.Parent = handle
		local beam = Instance.new("Beam")
		beam.Name = "LaserSight"
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.03, 0.03
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
		beam.Transparency = NumberSequence.new(0.2)
		beam.LightEmission, beam.FaceCamera = 1, true
		beam.Parent = handle
	end
end

local function build(char, weaponId)
	local spec = W[weaponId]
	clear(char)
	if not spec or (not spec.Build and (spec.ModelName or "") == "") then
		return -- Fists / unknown: empty hand
	end
	local hand = handOf(char)
	local waited = 0
	while not hand and waited < HAND_WAIT and char.Parent do
		task.wait(0.1)
		waited += 0.1
		hand = handOf(char)
	end
	if not hand or char:GetAttribute("Weapon") ~= weaponId then
		return -- despawned, or the weapon changed while we waited
	end

	local model, handle, gripHalf
	if spec.ModelName and spec.ModelName ~= "" then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local source = assets and assets:FindFirstChild("Weapons") and assets.Weapons:FindFirstChild(spec.ModelName)
		if source and source:FindFirstChild("Handle") then
			model = source:Clone()
			handle = model.Handle
			gripHalf = handle.Size.Y / 2
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
				end
			end
		else
			warn(("[WeaponView] asset %q not found under ReplicatedStorage.Assets.Weapons; using the procedural %s"):format(spec.ModelName, tostring(spec.Build)))
		end
	end
	if not model then
		local builder = Builders[spec.Build]
		if not builder then
			return
		end
		model, handle, gripHalf = builder(spec)
	end

	model.Name = MODEL_NAME
	model.PrimaryPart = handle
	-- Place the Handle so its top sits in the fist (keeping the builder's roll), then weld it on.
	local melee = spec.Build ~= "Pistol" and spec.Build ~= "Rifle"
	local grip = spec.Grip or (melee and W.MeleeGrip) or CFrame.identity -- melee: square to the forearm (Presentation.Weapons.MeleeGrip)
	local gripOffset = CFrame.new(W.HandOffset) * grip * CFrame.new(0, -(gripHalf or 0), 0)
	model:PivotTo(hand.CFrame * gripOffset * handle.CFrame.Rotation)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, handle
	weld.Parent = handle
	model.Parent = char
	current[char] = weaponId
	addPartViews(char, weaponId, model, handle)
	if spec.Build and (spec.ModelName or "") == "" and spec.Build ~= "Pistol" and spec.Build ~= "Rifle" then
		WeaponView.AddTrail(handle, spec.Length or 3, gripHalf or 0)
	end
end

-- The swing trail (SwingAnimator switches it on for a swing's active frames): a ribbon from the
-- grip to the tip. Procedural melee handles stand on Y with the shaft down local -X (see Builders).
function WeaponView.AddTrail(handle, length, gripHalf)
	local S = Presentation.Swings
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailGrip"
	a0.CFrame = CFrame.new(gripHalf * 0.4, 0, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.CFrame = CFrame.new(-(length - gripHalf), 0, 0)
	a1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Enabled = false
	trail.Lifetime = 0.12
	trail.MinLength = 0.05
	trail.LightEmission, trail.LightInfluence = 1, 0
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, S.TrailWidth or 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.Color = ColorSequence.new(S.TrailColor or Color3.new(1, 1, 1))
	trail.Parent = handle
	return trail
end

local function watch(char)
	local owner = Players:GetPlayerFromCharacter(char)
	if owner then
		owner:GetAttributeChangedSignal("Builds"):Connect(function()
			if char.Parent and current[char] then
				local id = current[char]
				current[char] = nil
				task.spawn(build, char, id) -- parts changed: redraw the gun
			end
		end)
	end
	local function refresh()
		local id = char:GetAttribute("Weapon")
		if id ~= current[char] then
			task.spawn(build, char, id)
		end
	end
	char:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	refresh()
end

local function watchPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then
		watch(p.Character)
	end
end

local COMBATANT_TAG = "Combatant" -- server/NPCs tags enemy bodies; they carry a Weapon attribute too

function WeaponView.Init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	CollectionService:GetInstanceAddedSignal(COMBATANT_TAG):Connect(watch)
	for _, model in CollectionService:GetTagged(COMBATANT_TAG) do
		watch(model)
	end
end

-- Exposed for other presentation modules (e.g. the swing cue glows the weapon when there is one).
function WeaponView.HandleOf(char)
	local model = char and char:FindFirstChild(MODEL_NAME)
	return model and model:FindFirstChild("Handle")
end

return WeaponView
