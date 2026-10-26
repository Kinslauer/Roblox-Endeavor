-- The Range (Phase-2 build-order 2): Universe 2's first-person shooter prototype, built inside this
-- place at Config.Range.Origin so it is playable today. A Rift in Relay Plaza takes you there once
-- you have Awakened and scored a kill; a Rift inside brings you back. Inside: first person is forced
-- (player attribute ForceFirstPerson, read by client/Aim), only ranged weapons fire (Combat checks
-- the Zone attribute), the Arc Rifle is granted, a target lane scores hits by distance, and a wave
-- arena spawns Gunners. Everything is anchored parts from code (no Studio building).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Lore = require(Shared.Lore)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.PlayerData)
local Wallet = require(script.Parent.Wallet)

local R = Config.Range
local Range = {}
Range.Zone = "Range"

local folder
local O = R.Origin
local TOP = 2
local DARK, MID, CYAN, MAGENTA = Color3.fromRGB(30, 32, 40), Color3.fromRGB(58, 62, 74), Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 50, 160)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or folder
	return p
end

local function glow(p, color, range)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 24, 1.5
	l.Parent = p
end

local function announce(player, text)
	Remotes.Announce:FireClient(player, text, "Event")
end

-- A hold-X console, same look as the arena's.
local function console(position, title, action, color, onUse)
	local body = part({ Name = title, Size = Vector3.new(7, 5, 3), Position = position + Vector3.new(0, 2.5, 0), Color = DARK, Material = Enum.Material.Metal })
	local screen = part({ Size = Vector3.new(5.6, 2.4, 0.3), Position = position + Vector3.new(0, 3.2, 1.6), Material = Enum.Material.Neon, Color = color, CanCollide = false })
	glow(screen, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(200, 40), Vector3.new(0, 5, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, title
	text.TextColor3, text.Font, text.TextScaled = color, Enum.Font.GothamBold, true
	text.Parent = billboard
	billboard.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = title, action, 0.4
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = body
	prompt.Triggered:Connect(onUse)
	return body
end

-- A Rift: a tall neon ring you walk up to.
local function rift(position, title, action, onUse)
	local ring = part({ Name = "Rift", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9), CFrame = CFrame.new(position + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = MAGENTA, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.15 })
	glow(ring, MAGENTA, 40)
	local core = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = ring.CFrame, Color = Color3.fromRGB(20, 0, 30), Material = Enum.Material.ForceField, CanCollide = false })
	core.Name = "RiftCore"
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(240, 44), Vector3.new(0, 6, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, title
	text.TextColor3, text.Font, text.TextScaled = MAGENTA, Enum.Font.GothamBlack, true
	text.Parent = billboard
	billboard.Parent = ring
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = title, action, 0.6
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = ring
	prompt.Triggered:Connect(onUse)
	return ring
end

-- ---------------------------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------------------------
local firingLine = O + Vector3.new(0, TOP, 70) -- you stand here, shooting toward -Z
local arenaCenter = O + Vector3.new(0, TOP, -150)
Range.ArenaCenter = arenaCenter -- the war (server/War.lua) fights here
Range.FiringLine = firingLine

local function buildGround()
	part({ Name = "RangeFloor", Size = Vector3.new(220, 4, 340), Position = O + Vector3.new(0, TOP - 2, -40), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.Concrete })
	-- walls
	for _, d in { { Vector3.new(0, 0, 132), Vector3.new(224, 30, 4) }, { Vector3.new(0, 0, -212), Vector3.new(224, 30, 4) }, { Vector3.new(112, 0, -40), Vector3.new(4, 30, 348) }, { Vector3.new(-112, 0, -40), Vector3.new(4, 30, 348) } } do
		part({ Name = "RangeWall", Size = d[2], Position = O + d[1] + Vector3.new(0, TOP + 15, 0), Color = DARK, Material = Enum.Material.Concrete })
	end
	-- a wall between the lane and the arena with a gate in the middle
	for _, x in { -62, 62 } do
		part({ Name = "LaneWall", Size = Vector3.new(100, 14, 3), Position = O + Vector3.new(x, TOP + 7, -60), Color = MID, Material = Enum.Material.Metal })
	end
	-- firing line stripe + distance markers
	part({ Name = "FiringLine", Size = Vector3.new(120, 0.2, 1), Position = firingLine + Vector3.new(0, 0.1, 0), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
	for _, dist in R.Targets.Distances do
		local marker = part({ Name = "Marker", Size = Vector3.new(120, 0.15, 0.5), Position = firingLine + Vector3.new(0, 0.08, -dist), Color = Color3.fromRGB(255, 190, 40), Material = Enum.Material.Neon, CanCollide = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.Parent = marker
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, ("%d"):format(dist)
		label.TextColor3, label.Font, label.TextScaled = Color3.new(0, 0, 0), Enum.Font.GothamBlack, true
		label.Parent = gui
	end
	-- cover in the arena
	local rng = Random.new(7)
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local r = 14 + (i % 3) * 9
		local p = arenaCenter + Vector3.new(math.cos(a) * r, 2, math.sin(a) * r)
		part({ Name = "Cover", Size = Vector3.new(6 + rng:NextInteger(0, 4), 4, 2.5), CFrame = CFrame.lookAt(p, Vector3.new(arenaCenter.X, p.Y, arenaCenter.Z)), Color = MID, Material = Enum.Material.Metal })
	end
	local pad = part({ Name = "ArenaPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16, 16), CFrame = CFrame.new(arenaCenter + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = CYAN, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false })
	glow(pad, CYAN, 30)
	-- lights
	for z = 100, -200, -50 do
		for _, x in { -100, 100 } do
			local head = part({ Size = Vector3.new(2, 0.5, 2), Position = O + Vector3.new(x, TOP + 26, z), Color = Color3.fromRGB(255, 230, 200), Material = Enum.Material.Neon, CanCollide = false })
			glow(head, head.Color, 90)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Targets: dummies that drop when killed and stand back up
-- ---------------------------------------------------------------------------------------------
local targets = {}

local function target(lane, dist)
	local pos = firingLine + Vector3.new(lane * R.Targets.LaneSpacing, 0, -dist)
	local model, hum, root = NPCs.BuildRig(("Target %d"):format(dist), { Health = R.Targets.Health, Speed = 0 })
	root.Anchored = true
	root.Color = Color3.fromRGB(230, 90, 90)
	model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 2.5, 0), pos + Vector3.new(0, 2.5, 10)))
	model:SetAttribute("Distance", dist)
	model:SetAttribute("Target", true) -- not a kill: no XP/quest/lore credit beyond the score
	model.Parent = folder
	local up = model:GetPivot()
	local down = up * CFrame.new(0, -1.5, -1) * CFrame.Angles(math.rad(-80), 0, 0)
	local standing = true
	hum.HealthChanged:Connect(function(h)
		if h <= 0 and standing then
			standing = false
			model:PivotTo(down)
			local attacker = Combat.GetKiller(model)
			-- credit the shooter with a scored hit
			for _, p in Players:GetPlayers() do
				if p.Character and (p.Character.Name == attacker or p.Name == attacker) then
					local score = (p:GetAttribute("RangeScore") or 0) + dist
					p:SetAttribute("RangeScore", score)
					announce(p, ("Target down at %d studs  (+%d, score %d)"):format(dist, dist, score))
				end
			end
			task.delay(R.Targets.ResetSeconds, function()
				if model.Parent then
					hum.Health = hum.MaxHealth
					model:PivotTo(up)
					standing = true
				end
			end)
		end
	end)
	table.insert(targets, model)
	return model
end

local function buildTargets()
	local n = #R.Targets.Distances
	for i, dist in R.Targets.Distances do
		target(i - (n + 1) / 2, dist)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Waves
-- ---------------------------------------------------------------------------------------------
local wave = { index = 0, alive = 0, running = false }

local function startWave(player)
	if wave.running then
		announce(player, "A wave is already running.")
		return false
	end
	wave.index = wave.index % #R.Waves + 1
	local comp = R.Waves[wave.index]
	wave.running, wave.alive = true, 0
	local i = 0
	for typeName, count in comp do
		for _ = 1, count do
			i += 1
			local a = (i / 6) * math.pi * 2
			local pos = arenaCenter + Vector3.new(math.cos(a) * R.WaveRing, 3, math.sin(a) * R.WaveRing)
			local m = NPCs.Spawn(typeName, pos)
			if m then
				wave.alive += 1
				m.Humanoid.Died:Once(function()
					wave.alive -= 1
					if wave.alive <= 0 and wave.running then
						wave.running = false
						for _, p in Players:GetPlayers() do
							if p:GetAttribute("Zone") == Range.Zone then
								Inventory.Add(p, "Scrap", R.WaveRewardScrap)
								Wallet.Add(p, R.WaveRewardMoney) -- the war pays (Phase 3 wallet)
								announce(p, ("Wave %d cleared. +%d scrap, +%d money."):format(wave.index, R.WaveRewardScrap, R.WaveRewardMoney))
							end
						end
					end
				end)
			end
		end
	end
	Remotes.Announce:FireAllClients(("Wave %d: %d hostiles."):format(wave.index, wave.alive), "Event")
	return true
end
Range.StartWave = startWave -- exposed for tests / later console variants

-- ---------------------------------------------------------------------------------------------
-- Travel
-- ---------------------------------------------------------------------------------------------
function Range.Unlocked(player)
	if Config.Dev.Enabled then
		return true
	end
	local data = PlayerData.Get(player)
	return data ~= nil and data.Awakened == true and (data.Kills or 0) >= R.UnlockKills
end

function Range.Enter(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false
	end
	if not Range.Unlocked(player) then
		announce(player, ("The Rift does not answer yet. Awaken and take %d life first."):format(R.UnlockKills))
		return false
	end
	for _, id in R.Loadout do
		if Inventory.Count(player, id) == 0 then
			Inventory.Add(player, id, 1)
		end
	end
	Gear.EquipWeapon(player, R.Loadout[1])
	player:SetAttribute("Zone", Range.Zone)
	player:SetAttribute("ForceFirstPerson", true)
	char:PivotTo(CFrame.lookAt(firingLine + Vector3.new(0, 4, 8), firingLine + Vector3.new(0, 4, -20)))
	Combat.Protect(char, R.EntryProtection)
	local data = PlayerData.Get(player)
	if data and not data.RiftSeen then
		data.RiftSeen = true
		Remotes.Announce:FireClient(player, Lore.Get("FirstRift"), "Lore")
	end
	announce(player, "The Range. Ranged weapons only. Right mouse: sights. X at the Rift to go back.")
	return true
end

-- Where leaving takes you. The hideout (Phase 3) installs itself here; without it, Relay Plaza.
Range.OnLeave = nil

function Range.Leave(player)
	local char = player.Character
	player:SetAttribute("Zone", nil)
	player:SetAttribute("ForceFirstPerson", nil)
	if Range.OnLeave then
		Range.OnLeave(player)
		return
	end
	if char and char:FindFirstChild("HumanoidRootPart") then
		char:PivotTo(CFrame.new(R.RiftPlaza + Vector3.new(0, 4, 6)))
		Combat.Protect(char, R.EntryProtection)
	end
	announce(player, "Back in Relay Plaza.")
end

function Range.InZone(player)
	return player:GetAttribute("Zone") == Range.Zone
end

function Range.Init()
	if workspace:FindFirstChild("Range") then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Range"
	folder.Parent = workspace
	buildGround()
	buildTargets()
	rift(R.RiftPlaza, "Rift", "Enter the Range", function(player) Range.Enter(player) end)
	rift(firingLine + Vector3.new(0, 0, 18), "Rift", "Return", function(player) Range.Leave(player) end)
	console(arenaCenter + Vector3.new(0, 0, 30), "Wave Console", "Start the next wave", MAGENTA, startWave)
	-- leaving the zone by dying: Lifecycle.Spawn clears the Zone / ForceFirstPerson attributes
	Range.Built = { Targets = #targets }
end

return Range
