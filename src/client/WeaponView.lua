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
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = emitter.Color, 1, 4
	light.Parent = emitter
	-- Iron sights. Body top is at y = 0.75; both sights stand 0.14 tall, so their tops share y = 0.89.
	-- Rear: two posts leaving a 0.14 notch at the back of the slide. Front: one post near the muzzle.
	-- The "Sight" attachment is the aim line: at the rear notch, at sight-top height, looking down
	-- the barrel (-Z). ViewModel puts the camera on this line so the front post sits centred in the
	-- notch with its top level with the rear posts - the classic sight picture; the shot goes where
	-- the top of the front post is.
	local S = spec.Sights or { Height = 0.14, Width = 0.08, NotchWidth = 0.14, Rear = 0.2, Front = -spec.Length + 0.4, Color = Color3.fromRGB(20, 20, 24), Dot = Color3.fromRGB(120, 255, 120) }
	local top = 0.75
	for _, x in { -(S.NotchWidth / 2 + S.Width / 2), S.NotchWidth / 2 + S.Width / 2 } do
		local post = part({ Name = "RearSight", Size = Vector3.new(S.Width, S.Height, 0.1), Color = S.Color, Material = Enum.Material.SmoothPlastic })
		weldTo(handle, post, CFrame.new(x, top + S.Height / 2, S.Rear))
	end
	local front = part({ Name = "FrontSight", Size = Vector3.new(S.Width, S.Height, 0.08), Color = S.Color, Material = Enum.Material.SmoothPlastic })
	weldTo(handle, front, CFrame.new(0, top + S.Height / 2, S.Front))
	local dot = part({ Name = "FrontDot", Size = Vector3.new(S.Width * 0.6, S.Width * 0.6, 0.02), Color = S.Dot, Material = Enum.Material.Neon })
	weldTo(handle, dot, CFrame.new(0, top + S.Height - S.Width * 0.45, S.Front + 0.05)) -- a glowing bead just under the post's top, on the shooter's side
	local sight = Instance.new("Attachment")
	sight.Name = "Sight"
	sight.CFrame = CFrame.new(0, top + S.Height, S.Rear)
	sight.Parent = handle
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
	local gripOffset = CFrame.new(W.HandOffset) * (spec.Grip or CFrame.identity) * CFrame.new(0, -(gripHalf or 0), 0)
	model:PivotTo(hand.CFrame * gripOffset * handle.CFrame.Rotation)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, handle
	weld.Parent = handle
	model.Parent = char
	current[char] = weaponId
end

local function watch(char)
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
