-- The open world v1 (Phase 3, build order 5; design/gdd/world.md, shared/Regions.lua):
--   * the wasteland ROAD north out of District 1 - a broken highway with wrecks, dead trees, sparse
--     lamps and fixed guards (raiders, a brute, and a warmonger at the far end)
--   * the solarpunk ENCLAVE "Verdant Reach": a round terrace of gardens, greenhouse domes and solar
--     towers around a covered market that is a safe zone with a trader (parts for money)
-- Everything is anchored parts from code with a seeded RNG, like the districts. The stations and the
-- train line are server/Transport.lua; the market trader's Buy is here (Remotes.Buy).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local D = require(Shared.District)
local Items = require(Shared.Items)
local R = require(Shared.Regions)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local RateLimit = require(script.Parent.RateLimit)
local Wallet = require(script.Parent.Wallet)

local Regions = {}

local folder
local rng
local TOP = D.GroundTop

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

local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 24, brightness or 1.5
	l.Parent = p
end

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function lamp(pos, color, lit)
	local post = part({ Name = "Lamp", Size = Vector3.new(0.6, 12, 0.6), Position = pos + Vector3.new(0, TOP + 6, 0), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal })
	local head = part({ Name = "LampHead", Size = Vector3.new(1.4, 0.6, 1.4), Position = pos + Vector3.new(0, TOP + 12.3, 0), Color = if lit then color else Color3.fromRGB(50, 50, 54), Material = if lit then Enum.Material.Neon else Enum.Material.Glass, CanCollide = false })
	if lit then
		glow(head, color, 34, 1.2)
	end
	return post
end

-- ---------------------------------------------------------------------------------------------
-- The road
-- ---------------------------------------------------------------------------------------------
local function road()
	local Rd = R.Road
	rng = Random.new(Rd.Seed)
	local z0, len, x = Rd.Z0, Rd.Length, Rd.X
	local slab = part({ Name = "Road", Size = Vector3.new(Rd.Width, 4, len), Position = Vector3.new(x, TOP - 2, z0 + len / 2), Color = Color3.fromRGB(48, 46, 50), Material = Enum.Material.Asphalt })
	CollectionService:AddTag(slab, "PlayableArea")
	slab:SetAttribute("Region", "Road")
	-- a wasteland apron either side, lower and rougher
	part({ Name = "Waste", Size = Vector3.new(Rd.Width + 160, 3, len + 40), Position = Vector3.new(x, TOP - 3.5, z0 + len / 2), Color = Color3.fromRGB(60, 54, 46), Material = Enum.Material.Ground })
	-- cracked centre line
	local z = z0 + 8
	while z < z0 + len - 8 do
		part({ Name = "RoadLine", Size = Vector3.new(0.6, 0.1, 6), Position = Vector3.new(x, TOP + 0.05, z), Color = Color3.fromRGB(150, 140, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		z += 14
	end
	-- wrecks and rubble on the verges
	for _ = 1, Rd.Wrecks do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = Vector3.new(x + side * rng:NextNumber(Rd.Width / 2 - 2, Rd.Width / 2 + 14), 0, z0 + rng:NextNumber(20, len - 20))
		if rng:NextNumber() < 0.6 then
			local w = part({ Name = "Wreck", Size = Vector3.new(14, 5, 6), CFrame = CFrame.new(p + Vector3.new(0, TOP + 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(70, 50, 50), Material = Enum.Material.CorrodedMetal })
			w.Name = "Wreck"
		else
			part({ Name = "Rubble", Size = Vector3.new(rng:NextNumber(6, 12), rng:NextNumber(1.5, 4), rng:NextNumber(5, 9)), CFrame = CFrame.new(p + Vector3.new(0, TOP + 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = Color3.fromRGB(80, 78, 74), Material = Enum.Material.Concrete })
		end
	end
	-- dead trees
	for _ = 1, Rd.DeadTrees do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = Vector3.new(x + side * rng:NextNumber(Rd.Width / 2 + 6, Rd.Width / 2 + 60), 0, z0 + rng:NextNumber(5, len - 5))
		local h = rng:NextNumber(10, 22)
		part({ Name = "DeadTree", Size = Vector3.new(1.2, h, 1.2), CFrame = CFrame.new(p + Vector3.new(0, TOP + h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color = Color3.fromRGB(60, 50, 44), Material = Enum.Material.Wood })
		part({ Name = "DeadBranch", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(p + Vector3.new(0, TOP + h * 0.7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(0.6, 1.1)), Color = Color3.fromRGB(60, 50, 44), Material = Enum.Material.Wood, CanCollide = false })
	end
	-- sparse lamps, half dead
	z = z0 + 30
	local i = 0
	while z < z0 + len - 20 do
		i += 1
		lamp(Vector3.new(x + (if i % 2 == 0 then 1 else -1) * (Rd.Width / 2 + 2), 0, z), Color3.fromRGB(255, 200, 150), i % 2 == 1)
		z += Rd.LampEvery
	end
	-- guards: placed, never despawning, home where they stand
	local guards = 0
	for _, g in Rd.Guards do
		for k = 1, g.Count do
			local gp = Vector3.new(x + rng:NextNumber(-Rd.Width / 2 + 3, Rd.Width / 2 - 3), TOP + 3.5, z0 + len * g.At + (k - 1) * 5)
			if NPCs.Spawn(g.Type, gp, { Despawn = false }) then
				guards += 1
			end
		end
	end
	return guards
end

-- ---------------------------------------------------------------------------------------------
-- The enclave
-- ---------------------------------------------------------------------------------------------
local function ring(center, radius, n, name, size, color, material)
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		part({ Name = name, Size = size, CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), Color = color, Material = material, CanCollide = false })
	end
end

local function tree(p, P)
	local h = rng:NextNumber(9, 16)
	part({ Name = "Trunk", Size = Vector3.new(1.4, h, 1.4), Position = p + Vector3.new(0, TOP + h / 2, 0), Color = P.Trunk, Material = Enum.Material.Wood })
	local r = rng:NextNumber(5, 8)
	local canopy = part({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 1.6, r * 2), Position = p + Vector3.new(0, TOP + h + r * 0.4, 0), Color = P.Leaf[rng:NextInteger(1, #P.Leaf)], Material = Enum.Material.Grass, CanCollide = false })
	canopy.Name = "Canopy"
end

local function dome(p, P, r)
	local sphere = part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 2, r * 2), Position = p + Vector3.new(0, TOP + r * 0.35, 0), Color = P.Dome, Material = Enum.Material.Glass, Transparency = 0.45 })
	sphere.Name = "Dome"
	part({ Name = "DomeBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, r * 2.2, r * 2.2), CFrame = CFrame.new(p + Vector3.new(0, TOP + 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = P.Frame, Material = Enum.Material.Concrete })
	-- planted inside: a green bed and a warm grow-lamp
	part({ Name = "Bed", Size = Vector3.new(r * 1.1, 1, r * 1.1), Position = p + Vector3.new(0, TOP + 1.6, 0), Color = P.Leaf[1], Material = Enum.Material.Grass, CanCollide = false })
	local grow = part({ Name = "GrowLamp", Size = Vector3.new(1, 0.4, 1), Position = p + Vector3.new(0, TOP + r * 0.9, 0), Color = Color3.fromRGB(255, 180, 230), Material = Enum.Material.Neon, CanCollide = false })
	glow(grow, Color3.fromRGB(255, 180, 230), r * 2.5, 1.2)
end

local function tower(p, P)
	local h = rng:NextNumber(26, 40)
	part({ Name = "Mast", Size = Vector3.new(2, h, 2), Position = p + Vector3.new(0, TOP + h / 2, 0), Color = P.Frame, Material = Enum.Material.Metal })
	local panel = part({ Name = "SolarPanel", Size = Vector3.new(16, 0.6, 10), CFrame = CFrame.new(p + Vector3.new(0, TOP + h + 1, 0)) * CFrame.Angles(math.rad(-25), rng:NextNumber(0, math.pi), 0), Color = P.Panel, Material = Enum.Material.Glass })
	panel.Reflectance = 0.3
	local cell = part({ Name = "Cell", Size = Vector3.new(1.2, 3, 1.2), Position = p + Vector3.new(0, TOP + h - 3, 0), Color = Color3.fromRGB(120, 255, 200), Material = Enum.Material.Neon, CanCollide = false })
	glow(cell, Color3.fromRGB(120, 255, 200), 24, 1)
end

local function enclave()
	local E = R.Enclave
	local P = E.Palette
	local O = E.Origin
	rng = Random.new(E.Seed)
	-- the terrace: a round ground disc (NOT PlayableArea: no ambushes here - this is the safer place)
	part({ Name = "Terrace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, E.Radius * 2, E.Radius * 2), CFrame = CFrame.new(O + Vector3.new(0, TOP - 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = P.Ground, Material = Enum.Material.Grass })
	-- paths: a cross and a ring of packed sand
	for _, rot in { 0, math.pi / 2 } do
		part({ Name = "Path", Size = Vector3.new(10, 0.3, E.Radius * 2 - 10), CFrame = CFrame.new(O + Vector3.new(0, TOP + 0.15, 0)) * CFrame.Angles(0, rot, 0), Color = P.Path, Material = Enum.Material.Sand })
	end
	ring(O + Vector3.new(0, TOP + 0.15, 0), E.Radius * 0.6, 56, "PathRing", Vector3.new(2 * math.pi * E.Radius * 0.6 / 56 + 0.4, 0.3, 8), P.Path, Enum.Material.Sand)
	-- the market: a covered round plaza at the centre, the safe zone
	local M = E.Market
	part({ Name = "MarketFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, M.Radius * 2, M.Radius * 2), CFrame = CFrame.new(O + Vector3.new(0, TOP + 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(200, 190, 170), Material = Enum.Material.Slate })
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		part({ Name = "MarketPost", Size = Vector3.new(1.4, 14, 1.4), Position = O + Vector3.new(math.cos(a) * (M.Radius - 4), TOP + 7, math.sin(a) * (M.Radius - 4)), Color = P.Frame, Material = Enum.Material.Wood })
	end
	local roof = part({ Name = "MarketRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, M.Radius * 2 + 6, M.Radius * 2 + 6), CFrame = CFrame.new(O + Vector3.new(0, TOP + 14.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = P.Dome, Material = Enum.Material.Glass, Transparency = 0.35 })
	roof.Name = "MarketRoof"
	local zone = part({ Name = "SafeZone", Size = Vector3.new(1, 1, 1), Position = O + Vector3.new(0, TOP + 0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	zone:SetAttribute("Radius", M.Radius)
	zone:SetAttribute("ZoneName", M.Name)
	zone:SetAttribute("Region", E.Id)
	CollectionService:AddTag(zone, "SafeZone")
	ring(O + Vector3.new(0, TOP + 0.6, 0), M.Radius, 40, "SafeRing", Vector3.new(2 * math.pi * M.Radius / 40 + 0.3, 0.15, 0.8), P.Ring, Enum.Material.Neon)
	-- market stalls + the trader's counter
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2 + 0.3
		local p = O + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)
		part({ Name = "Stall", Size = Vector3.new(8, 3, 3), CFrame = CFrame.lookAt(p + Vector3.new(0, TOP + 1.8, 0), Vector3.new(O.X, TOP + 1.8, O.Z)), Color = Color3.fromRGB(110, 85, 60), Material = Enum.Material.Wood })
		part({ Name = "Awning", Size = Vector3.new(9, 0.3, 4), CFrame = CFrame.lookAt(p + Vector3.new(0, TOP + 4.2, 0), Vector3.new(O.X, TOP + 4.2, O.Z)), Color = P.Leaf[(i % #P.Leaf) + 1], Material = Enum.Material.Fabric, CanCollide = false })
	end
	local counter = part({ Name = "Trader", Size = Vector3.new(10, 3.5, 3), Position = O + Vector3.new(0, TOP + 2, -10), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Wood })
	local sign = part({ Name = "TraderSign", Size = Vector3.new(8, 1.2, 0.3), Position = O + Vector3.new(0, TOP + 7, -10), Color = P.Ring, Material = Enum.Material.Neon, CanCollide = false })
	glow(sign, P.Ring, 24, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop, billboard.MaxDistance = UDim2.fromOffset(260, 44), Vector3.new(0, 2, 0), true, 120
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "TRADER  ·  open your inventory (Tab) to buy"
	text.TextColor3, text.Font, text.TextScaled = P.Ring, Enum.Font.GothamBold, true
	text.Parent = billboard
	billboard.Parent = sign
	counter:SetAttribute("Trader", true)
	-- domes, towers, beds, trees, lamps around the terrace (never on the market or the station's corner)
	local function spot(rMin, rMax)
		for _ = 1, 20 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(rMin, rMax)
			local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local onPath = math.abs(p.X - O.X) < 8 or math.abs(p.Z - O.Z) < 8 or math.abs(r - E.Radius * 0.6) < 6
			local nearStation = (p - Vector3.new(R.Hubs.Enclave.Position.X, 0, R.Hubs.Enclave.Position.Z)).Magnitude < 30
			if not onPath and not nearStation then
				return p
			end
		end
		return nil
	end
	for _ = 1, E.Domes do
		local p = spot(M.Radius + 24, E.Radius - 30)
		if p then
			dome(p, P, rng:NextNumber(9, 14))
		end
	end
	for _ = 1, E.Towers do
		local p = spot(M.Radius + 30, E.Radius - 16)
		if p then
			tower(p, P)
		end
	end
	for _ = 1, E.Beds do
		local p = spot(M.Radius + 10, E.Radius - 12)
		if p then
			part({ Name = "PlanterBed", Size = Vector3.new(rng:NextNumber(5, 9), 1.4, rng:NextNumber(3, 5)), CFrame = CFrame.new(p + Vector3.new(0, TOP + 0.7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = P.Frame, Material = Enum.Material.Concrete })
			part({ Name = "Crop", Size = Vector3.new(4.5, 1.2, 2.5), CFrame = CFrame.new(p + Vector3.new(0, TOP + 1.8, 0)), Color = P.Leaf[rng:NextInteger(1, #P.Leaf)], Material = Enum.Material.Grass, CanCollide = false })
		end
	end
	for _ = 1, E.Trees do
		local p = spot(M.Radius + 8, E.Radius - 6)
		if p then
			tree(p, P)
		end
	end
	for i = 1, E.Lamps do
		local a = (i / E.Lamps) * math.pi * 2
		lamp(O + Vector3.new(math.cos(a) * (E.Radius * 0.6 + 6), 0, math.sin(a) * (E.Radius * 0.6 + 6)), P.Lamp, true)
	end
	-- a low hedge wall at the edge, with the road's opening to the south
	for i = 1, 72 do
		local a = (i / 72) * math.pi * 2
		local p = O + Vector3.new(math.cos(a) * (E.Radius - 2), 0, math.sin(a) * (E.Radius - 2))
		local isRoadGap = math.abs(p.X - R.Road.X) < R.Road.Width / 2 + 6 and p.Z < O.Z
		if not isRoadGap then
			part({ Name = "Hedge", Size = Vector3.new(2 * math.pi * (E.Radius - 2) / 72 + 0.5, 4, 3), CFrame = CFrame.lookAt(p + Vector3.new(0, TOP + 2, 0), Vector3.new(O.X, TOP + 2, O.Z)), Color = P.Leaf[2], Material = Enum.Material.Grass })
		end
	end
	-- the name over the gate
	local gatePos = Vector3.new(R.Road.X, TOP + 18, O.Z - E.Radius + 2)
	local arch = part({ Name = "EnclaveArch", Size = Vector3.new(R.Road.Width + 10, 1.5, 2), Position = gatePos, Color = P.Ring, Material = Enum.Material.Neon, CanCollide = false })
	glow(arch, P.Ring, 50, 1.5)
	for _, dx in { -(R.Road.Width / 2 + 4), R.Road.Width / 2 + 4 } do
		part({ Name = "ArchPost", Size = Vector3.new(2, 18, 2), Position = Vector3.new(R.Road.X + dx, TOP + 9, O.Z - E.Radius + 2), Color = P.Frame, Material = Enum.Material.Concrete })
	end
	local label = Instance.new("BillboardGui")
	label.Size, label.StudsOffset, label.AlwaysOnTop, label.MaxDistance = UDim2.fromOffset(300, 44), Vector3.new(0, 3, 0), true, 200
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(1, 1), 1, E.Name:upper()
	t.TextColor3, t.Font, t.TextScaled = P.Ring, Enum.Font.GothamBold, true
	t.Parent = label
	label.Parent = arch
end

-- ---------------------------------------------------------------------------------------------
-- The trader (Remotes.Buy): parts for money, only while standing in the market
-- ---------------------------------------------------------------------------------------------
function Regions.Price(itemId)
	for _, entry in R.Enclave.Stock do
		if entry.Id == itemId then
			return entry.Price
		end
	end
	return nil
end

function Regions.Buy(player, itemId)
	if type(itemId) ~= "string" then
		return false
	end
	local price = Regions.Price(itemId)
	if not price or not Items.Defs[itemId] then
		return false
	end
	if not player:GetAttribute("Market") then
		announce(player, "The trader is in Verdant Market.")
		return false
	end
	if not Wallet.Spend(player, price) then
		announce(player, ("Not enough money (%d)."):format(price))
		return false
	end
	Inventory.Add(player, itemId, 1)
	announce(player, ("Bought %s for %d."):format(Items.Defs[itemId].Name, price))
	return true
end

-- Every second: who is in the market (the HUD's trader section reads the Market attribute).
local function watchMarket()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local inside = root ~= nil and R.InMarket(root.Position)
			if (player:GetAttribute("Market") == true) ~= inside then
				player:SetAttribute("Market", if inside then true else nil)
			end
		end
	end)
end

function Regions.Init()
	if workspace:FindFirstChild("Regions") then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Regions"
	folder.Parent = workspace
	local guards = road()
	enclave()
	Remotes.Buy.OnServerEvent:Connect(RateLimit.Wrap("Buy", Config.RateLimit.Buy, Regions.Buy))
	watchMarket()
	Regions.Built = { Guards = guards, Parts = #folder:GetChildren() }
end

return Regions
