-- Friend-testing arena (Config.Dev.Enabled). A neon coliseum with cover and a center platform,
-- eight CitySpawn pads, and an armory outside the south gate: free gear, attribute points,
-- respec, a recharge pad, and regenerating training dummies that show damage numbers.
-- Everything is generated from code so no Studio building is needed.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local Weapons = require(Shared.Weapons)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.Common.PlayerData)
local Stats = require(script.Parent.Stats)
local Rigs = require(script.Parent.Rigs)
local HeldWeapons = require(script.Parent.Common.HeldWeapons)
local Landmarks = require(script.Parent.Landmarks)
local Assets = require(Shared.Assets)

local Arena = {}

local GROUND_TOP = 2 -- top surface of the base slab
local ARENA_RADIUS = 84
local DARK = Color3.fromRGB(38, 40, 48)
local MID = Color3.fromRGB(58, 62, 74)
local CYAN = Color3.fromRGB(0, 220, 255)
local MAGENTA = Color3.fromRGB(255, 50, 160)

local folder

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

-- Vertical cylinder whose bottom sits at baseY.
local function column(radius, height, x, baseY, z, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	props.CFrame = CFrame.new(x, baseY + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props)
end

local function polar(radius, angle)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function glow(p, color)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 24, 1.5
	light.Parent = p
end

local function atmosphere()
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		return -- City.Atmosphere already dressed the sky
	end
	Lighting.ClockTime = 23
	Lighting.Ambient = Color3.fromRGB(45, 45, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(45, 45, 70)
	Lighting.Brightness = 1.2
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.7, 28, 1.6
	bloom.Parent = Lighting
end

local function buildRing()
	-- base slab doubles as the placeholder city ground
		column(ARENA_RADIUS - 2, 0.6, 0, GROUND_TOP, 0, { Name = "ArenaFloor", Color = MID, Material = Enum.Material.Slate })
	local floorTop = GROUND_TOP + 0.6

	-- neon boundary line on the floor
	for i = 1, 56 do
		local a = (i / 56) * math.pi * 2
		part({ Size = Vector3.new(5, 0.15, 0.7), Material = Enum.Material.Neon, Color = CYAN, CanCollide = false,
			CFrame = CFrame.lookAt(polar(ARENA_RADIUS - 4, a) + Vector3.new(0, floorTop + 0.1, 0), Vector3.new(0, floorTop + 0.1, 0)) })
	end

	-- perimeter wall with four gates (every 7th segment is left open)
	local segments, height = 28, 16
	local width = 2 * math.pi * ARENA_RADIUS / segments + 0.6
	for i = 0, segments - 1 do
		if i % 7 ~= 0 then
			local a = (i / segments) * math.pi * 2
			local pos = polar(ARENA_RADIUS, a) + Vector3.new(0, floorTop + height / 2, 0)
			local facing = Vector3.new(0, pos.Y, 0)
			part({ Name = "Wall", Size = Vector3.new(width, height, 3), CFrame = CFrame.lookAt(pos, facing), Color = DARK, Material = Enum.Material.Concrete })
			local strip = part({ Size = Vector3.new(width, 0.5, 0.5), Material = Enum.Material.Neon, Color = if i % 2 == 0 then CYAN else MAGENTA, CanCollide = false,
				CFrame = CFrame.lookAt(pos + Vector3.new(0, height / 2 - 1, 0) - (pos - facing).Unit * 1.6 * Vector3.new(1, 0, 1), facing) })
			if i % 4 == 0 then
				glow(strip, strip.Color)
			end
		end
	end

	-- cover: pillars and low barriers
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		local p = polar(46, a)
		column(5, 12, p.X, floorTop, p.Z, { Name = "Pillar", Color = DARK, Material = Enum.Material.Concrete })
		column(5.3, 0.4, p.X, floorTop + 11.6, p.Z, { Material = Enum.Material.Neon, Color = MAGENTA, CanCollide = false })
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local p = polar(26, a)
		part({ Name = "Barrier", Size = Vector3.new(16, 5, 2.5), CFrame = CFrame.lookAt(p + Vector3.new(0, floorTop + 2.5, 0), Vector3.new(0, floorTop + 2.5, 0)), Color = MID, Material = Enum.Material.Metal })
	end

	-- raised center platform
	column(14, 3, 0, floorTop, 0, { Name = "CenterPlatform", Color = MID, Material = Enum.Material.Metal })
	local ring = column(14.4, 0.3, 0, floorTop + 3, 0, { Material = Enum.Material.Neon, Color = CYAN, CanCollide = false })
	glow(ring, CYAN)

	-- spawn pads
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + math.pi / 8
		local p = polar(68, a)
		local pad = part({ Name = "SpawnPad", Size = Vector3.new(8, 0.4, 8), Position = p + Vector3.new(0, floorTop + 0.2, 0),
			Material = Enum.Material.Neon, Color = CYAN, Transparency = 0.5 })
		CollectionService:AddTag(pad, "CitySpawn")
	end
end

local function console(position, title, action, color, onUse)
	local body = part({ Name = title, Size = Vector3.new(7, 5, 3), Position = position + Vector3.new(0, 2.5, 0), Color = DARK, Material = Enum.Material.Metal })
	local screen = part({ Size = Vector3.new(5.6, 2.4, 0.3), Position = position + Vector3.new(0, 3.2, 1.6), Material = Enum.Material.Neon, Color = color, CanCollide = false })
	glow(screen, color)

	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(180, 40), Vector3.new(0, 5, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, title
	text.TextColor3, text.Font, text.TextScaled = color, Enum.Font.GothamBold, true
	text.Parent = billboard
	billboard.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = title, action, 0.25
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X -- E is flicker
	prompt.Parent = body
	prompt.Triggered:Connect(onUse)
end

local function giveAll(player, defs, skip)
	for id in defs do
		if id ~= skip and Inventory.Count(player, id) == 0 then
			Inventory.Add(player, id, 1)
		end
	end
end

local function recharge(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
		char:SetAttribute("Stamina", char:GetAttribute("MaxStamina"))
		char:SetAttribute("Charge", char:GetAttribute("MaxCharge"))
		char:SetAttribute("Posture", 0)
	end
end

local function respec(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local total = data.FreePoints
	for name, value in data.Stats do
		total += value
		data.Stats[name] = 0
	end
	data.FreePoints = total
	Gear.Recompute(player)
end

local function addDamageNumber(root, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(120, 36), Vector3.new(math.random(-20, 20) / 10, 4, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, ("-%d"):format(math.round(amount))
	text.TextColor3, text.Font, text.TextScaled = Color3.fromRGB(255, 220, 80), Enum.Font.GothamBold, true
	text.TextStrokeTransparency = 0.4
	text.Parent = billboard
	billboard.Parent = root
	Debris:AddItem(billboard, 1.2)
	game:GetService("TweenService"):Create(billboard, TweenInfo.new(1.1), { StudsOffset = billboard.StudsOffset + Vector3.new(0, 4, 0) }):Play()
	game:GetService("TweenService"):Create(text, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function dummy(position)
	local model, hum, root = NPCs.BuildRig("Training Dummy", { Health = 1000, Speed = 0 })
	root.Anchored = true
	model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 10)))
	model.Parent = folder
	local lastHit = 0
	local previous = hum.Health
	hum.HealthChanged:Connect(function(health)
		if health < previous - 0.4 then
			lastHit = os.clock()
			addDamageNumber(root, previous - health)
		end
		previous = health
	end)
	task.spawn(function()
		while model.Parent do
			task.wait(1)
			if os.clock() - lastHit > 3 and hum.Health < hum.MaxHealth then
				hum.Health = hum.MaxHealth
			end
		end
	end)
end

local function buildArmory()
	local z = 132
	local floorY = GROUND_TOP
	Landmarks.Register("Armory", Vector3.new(0, floorY + 10, z), "Test Armory", Color3.fromRGB(255, 80, 220))
	part({ Name = "ArmoryFloor", Size = Vector3.new(84, 1, 30), Position = Vector3.new(0, floorY + 0.5, z), Color = MID, Material = Enum.Material.Metal })
	part({ Name = "ArmoryBackWall", Size = Vector3.new(84, 14, 2), Position = Vector3.new(0, floorY + 8, z + 15), Color = DARK, Material = Enum.Material.Concrete })
	local sign = part({ Size = Vector3.new(40, 4, 0.5), Position = Vector3.new(0, floorY + 11, z + 13.8), Material = Enum.Material.Neon, Color = MAGENTA, CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size, title.BackgroundTransparency, title.Text = UDim2.fromScale(1, 1), 1, "TEST ARMORY"
	title.TextColor3, title.Font, title.TextScaled = Color3.new(0, 0, 0), Enum.Font.GothamBlack, true
	title.Parent = gui

	local y = Vector3.new(0, floorY + 1, z + 9)
	local spots = {}
	for i = 1, 7 do
		spots[i] = y + Vector3.new(-36 + (i - 1) * 12, 0, 0)
	end
	console(spots[1], "Weapons Rack", "Take all weapons", CYAN, function(player) giveAll(player, Weapons.Defs, "Fists") end)
	console(spots[2], "Armor Rack", "Take all armor", CYAN, function(player) giveAll(player, Armor.Pieces) end)
	console(spots[3], "Cybernetics Bay", "Take all implants", MAGENTA, function(player) giveAll(player, Cybernetics.Pieces) end)
	console(spots[4], "Supplies", "Take materials + meds", CYAN, function(player)
		Inventory.Add(player, "Scrap", 10)
		Inventory.Add(player, "Wire", 10)
		Inventory.Add(player, "Cloth", 10)
		Inventory.Add(player, "Medkit", 2)
	end)
	console(spots[5], "Instructor", ("+%d attribute points"):format(Config.Dev.ArmoryPoints), MAGENTA, function(player)
		local data = PlayerData.Get(player)
		if data then
			data.FreePoints += Config.Dev.ArmoryPoints
			Stats.Push(player)
		end
	end)
	console(spots[6], "Respec", "Refund all points", CYAN, respec)
	console(spots[7], "Recharge", "Full health/stamina/charge", MAGENTA, recharge)

	-- training dummies in front of the armory (they regenerate and show damage numbers)
	for i = -1, 1 do
		dummy(Vector3.new(i * 18, floorY + 2.5, 108))
	end
	-- a mannequin of every uploaded character rig, idling on a pad: look at it, it won't fight back
	local k = 0
	for typeName, id in Assets.Rigs do
		if id ~= 0 then
			local model, hum, root = Rigs.Build(id, typeName .. " (display)")
			if model then
				k += 1
				local pos = Vector3.new(44 + k * 8, floorY + 1 + hum.HipHeight + root.Size.Y / 2, 124)
				part({ Name = "DisplayPad", Size = Vector3.new(6, 0.4, 6), Position = Vector3.new(pos.X, floorY + 1.2, pos.Z), Material = Enum.Material.Neon, Color = MAGENTA, Transparency = 0.5 })
				model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -10)))
				model:SetAttribute("Display", true)
				model.Parent = folder
				root:SetNetworkOwner(nil)
				root.Anchored = true -- it stands still; the idle animation still plays on the limbs
				Rigs.Animate(model, hum)
				HeldWeapons.Attach(model, (NPCs.Types[typeName] or {}).Weapon)
				local label = Instance.new("BillboardGui")
				label.Size, label.StudsOffset, label.AlwaysOnTop = UDim2.fromOffset(160, 30), Vector3.new(0, 4.5, 0), true
				local text = Instance.new("TextLabel")
				text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, typeName
				text.TextColor3, text.Font, text.TextScaled = MAGENTA, Enum.Font.GothamBold, true
				text.Parent = label
				label.Parent = root
			end
		end
	end
end

function Arena.Init()
	if not Config.Dev.Enabled then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace
	atmosphere()
	buildRing()
	buildArmory()
	-- a recharge pad on the center platform so flicker/charge testing is never blocked
	console(Vector3.new(0, GROUND_TOP + 0.6 + 3, 0), "Recharge", "Full health/stamina/charge", CYAN, recharge)
end

return Arena
