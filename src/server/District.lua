-- District generator (brief build-order 6; District 2 = Phase-2 build-order 4): for every entry of
-- shared District.Districts, streets, buildings, cover, lamps, a perimeter wall, CitySpawn pads and
-- a plaza safe zone, all from shared/District.lua numbers and that district's seed; then a gate
-- street joining neighbours through their walls. Built once at boot before WorldPhase.Init (so the
-- CitySpawn pads are found) and regardless of Config.Dev — the dev arena is a separate, offset
-- structure (Arena.lua). Everything is anchored parts under workspace.District; nothing needs
-- Studio building.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.District)

local District = {}

local folder
local rng
local ctx -- the district being built (an entry of D.Districts); falls back to the D.* tables

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
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range or 24, brightness or 1.5
	light.Parent = p
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function lighting()
	local L = D.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Ambient, Lighting.OutdoorAmbient = L.Ambient, L.Ambient
	Lighting.Brightness = L.Brightness
	if not Lighting:FindFirstChild("DistrictBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "DistrictBloom"
		bloom.Intensity, bloom.Size, bloom.Threshold = L.Bloom.Intensity, L.Bloom.Size, L.Bloom.Threshold
		bloom.Parent = Lighting
	end
end

-- World X/Z of the south-west corner of block (bx, bz), 1-based, in the current district.
local function blockOrigin(bx, bz)
	local g = D.Grid
	local half = D.Extent() / 2
	local x = -half + g.StreetWidth + (bx - 1) * (g.BlockSize + g.StreetWidth)
	local z = -half + g.StreetWidth + (bz - 1) * (g.BlockSize + g.StreetWidth)
	return ctx.Origin.X + x, ctx.Origin.Z + z
end

local function centerBlock()
	return math.ceil(D.Grid.Blocks / 2)
end

-- The collapsed city beyond the walls: one dark apron under every district so the horizon is not void.
local function outskirts()
	local extent = D.Extent()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, d in D.Districts do
		minX, maxX = math.min(minX, d.Origin.X), math.max(maxX, d.Origin.X)
		minZ, maxZ = math.min(minZ, d.Origin.Z), math.max(maxZ, d.Origin.Z)
	end
	local pad = extent * 1.5
	part({ Name = "Outskirts", Size = Vector3.new(maxX - minX + 2 * pad, 2, maxZ - minZ + 2 * pad),
		Position = Vector3.new((minX + maxX) / 2, D.GroundTop - 4, (minZ + maxZ) / 2), Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.Ground })
end

local function ground()
	local extent = D.Extent()
	local top = D.GroundTop
	-- one street slab under everything (tagged PlayableArea: ambushes and ground checks use it)
	local street = part({ Name = "Streets", Size = Vector3.new(extent, 4, extent), Position = ctx.Origin + Vector3.new(0, top - 2, 0),
		Color = Color3.fromRGB(44, 44, 50), Material = Enum.Material.Asphalt })
	CollectionService:AddTag(street, "PlayableArea")
	street:SetAttribute("District", ctx.Name)
	-- kerbs: a raised pavement rim around every block
	local g = D.Grid
	local c = centerBlock()
	for bx = 1, g.Blocks do
		for bz = 1, g.Blocks do
			if not (bx == c and bz == c) then
				local x, z = blockOrigin(bx, bz)
				part({ Name = "Pavement", Size = Vector3.new(g.BlockSize, 0.5, g.BlockSize), Position = Vector3.new(x + g.BlockSize / 2, top + 0.25, z + g.BlockSize / 2),
					Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Concrete })
			end
		end
	end
end

local function building(x, z, w, d, h, top)
	local B = D.Buildings
	local body = part({ Name = "Building", Size = Vector3.new(w, h, d), Position = Vector3.new(x, top + h / 2, z), Color = pick(ctx.Palette or B.Palette), Material = Enum.Material.Concrete })
	if rng:NextNumber() < B.WindowChance then
		-- a lit window band two thirds of the way up, on the long side
		local y = top + h * rng:NextNumber(0.45, 0.8)
		part({ Name = "Windows", Size = Vector3.new(w + 0.2, 1.2, d + 0.2), Position = Vector3.new(x, y, z), Color = Color3.fromRGB(255, 230, 170),
			Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
	end
	if rng:NextNumber() < B.NeonChance then
		-- a vertical neon sign strip on a random face, lit
		local color = pick(ctx.Neon or B.Neon)
		local side = rng:NextInteger(0, 3)
		local len = math.min(h * 0.6, 24)
		local y = top + h - len / 2 - 2
		local offset = ({ Vector3.new(w / 2 + 0.4, 0, 0), Vector3.new(-w / 2 - 0.4, 0, 0), Vector3.new(0, 0, d / 2 + 0.4), Vector3.new(0, 0, -d / 2 - 0.4) })[side + 1]
		local size = if side < 2 then Vector3.new(0.6, len, 2.5) else Vector3.new(2.5, len, 0.6)
		local sign = part({ Name = "Sign", Size = size, Position = Vector3.new(x, y, z) + offset, Color = color, Material = Enum.Material.Neon, CanCollide = false })
		glow(sign, color, 30, 1.2)
	end
	return body
end

local function rubble(x, z, w, d, top)
	-- a collapsed building: a low broken slab, a leaning wall piece and debris you can climb on
	part({ Name = "Rubble", Size = Vector3.new(w, 3, d), Position = Vector3.new(x, top + 1.5, z), Color = Color3.fromRGB(60, 58, 60), Material = Enum.Material.Slate })
	part({ Name = "RubbleWall", Size = Vector3.new(w * 0.6, 14, 2), CFrame = CFrame.new(x, top + 7, z - d / 2 + 3) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, 0),
		Color = Color3.fromRGB(50, 50, 56), Material = Enum.Material.Concrete })
	for _ = 1, 4 do
		local s = rng:NextNumber(3, 7)
		part({ Name = "Debris", Size = Vector3.new(s, s * 0.6, s), CFrame = CFrame.new(x + rng:NextNumber(-w / 3, w / 3), top + 3 + s * 0.3, z + rng:NextNumber(-d / 3, d / 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = Color3.fromRGB(66, 62, 64), Material = Enum.Material.Concrete })
	end
end

local function blocks()
	local g, B = D.Grid, D.Buildings
	local c = centerBlock()
	local top = D.GroundTop + 0.5
	local rubbleChance = ctx.RubbleChance or B.RubbleChance
	for bx = 1, g.Blocks do
		for bz = 1, g.Blocks do
			if not (bx == c and bz == c) then
				local ox, oz = blockOrigin(bx, bz)
				local inner = g.BlockSize - 2 * B.Inset
				if rng:NextNumber() < rubbleChance then
					rubble(ox + g.BlockSize / 2, oz + g.BlockSize / 2, inner, inner, top)
				else
					-- split the block into a 2x2 of lots and fill PerBlock of them
					local n = rng:NextInteger(B.PerBlock[1], B.PerBlock[2])
					local lots = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
					for i = #lots, 2, -1 do -- shuffle
						local j = rng:NextInteger(1, i)
						lots[i], lots[j] = lots[j], lots[i]
					end
					local lot = inner / 2
					for i = 1, math.min(n, 4) do
						local lx, lz = lots[i][1], lots[i][2]
						local w, d = lot - rng:NextNumber(0, 6), lot - rng:NextNumber(0, 6)
						local h = rng:NextNumber(B.MinHeight, B.MaxHeight)
						local x = ox + B.Inset + lx * lot + lot / 2
						local z = oz + B.Inset + lz * lot + lot / 2
						building(x, z, w, d, h, top)
					end
				end
			end
		end
	end
end

local function cover()
	local g, C = D.Grid, D.Cover
	local top = D.GroundTop
	local half = D.Extent() / 2
	-- one pass per street segment, both orientations
	for i = 0, g.Blocks do
		local streetCenter = -half + g.StreetWidth / 2 + i * (g.BlockSize + g.StreetWidth)
		for seg = 1, g.Blocks do
			local along = -half + g.StreetWidth + (seg - 1) * (g.BlockSize + g.StreetWidth) + g.BlockSize / 2
			for _, horizontal in { true, false } do
				local n = rng:NextInteger(C.PerStreet[1], C.PerStreet[2])
				for _ = 1, n do
					local kind = pick(C.Kinds)
					local side = rng:NextNumber(-g.StreetWidth / 2 + 3, g.StreetWidth / 2 - 3)
					local shift = rng:NextNumber(-g.BlockSize / 2 + 8, g.BlockSize / 2 - 8)
					local x, z
					if horizontal then
						x, z = along + shift, streetCenter + side
					else
						x, z = streetCenter + side, along + shift
					end
					local pos = ctx.Origin + Vector3.new(x, top + kind.Size.Y / 2, z)
					if (pos - ctx.Origin).Magnitude > D.SafeZone.Radius - 6 then
						local yaw = if horizontal then 0 else math.pi / 2
						part({ Name = kind.Name, Size = kind.Size, CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw + rng:NextNumber(-0.2, 0.2), 0), Color = kind.Color, Material = kind.Material })
					end
				end
			end
		end
	end
end

local function lamp(pos, color)
	local L = D.Lamps
	local top = D.GroundTop
	local post = part({ Name = "Lamp", Size = Vector3.new(0.6, L.Height, 0.6), Position = pos + Vector3.new(0, top + L.Height / 2, 0), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal })
	local head = part({ Name = "LampHead", Size = Vector3.new(1.4, 0.6, 1.4), Position = pos + Vector3.new(0, top + L.Height + 0.3, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	glow(head, color, L.Range, L.Brightness)
	return post
end

local function lamps()
	local g, L = D.Grid, D.Lamps
	local half = D.Extent() / 2
	local color = ctx.LampColor or L.Color
	for i = 0, g.Blocks do
		local line = -half + g.StreetWidth / 2 + i * (g.BlockSize + g.StreetWidth)
		local s = -half + g.StreetWidth / 2
		while s < half do
			for _, p in { Vector3.new(s, 0, line + g.StreetWidth / 2 - 1), Vector3.new(line + g.StreetWidth / 2 - 1, 0, s) } do
				local pos = ctx.Origin + p
				if (pos - ctx.Origin).Magnitude > D.SafeZone.Radius then
					lamp(pos, color)
				end
			end
			s += L.Spacing
		end
	end
end

-- Perimeter wall. A side named in ctx.Gates gets a gap one street wide on the gate's street line.
local function wall()
	local W, G, g = D.Wall, D.Gate, D.Grid
	local half = D.Extent() / 2 + W.Margin
	local top = D.GroundTop
	local len = half * 2 + W.Thickness
	local gap = g.StreetWidth + 2
	local gateZ = D.StreetLine(G.Line)
	local sides = {
		{ Name = "North", Center = Vector3.new(0, 0, half), Along = "X" },
		{ Name = "South", Center = Vector3.new(0, 0, -half), Along = "X" },
		{ Name = "East", Center = Vector3.new(half, 0, 0), Along = "Z" },
		{ Name = "West", Center = Vector3.new(-half, 0, 0), Along = "Z" },
	}
	for _, side in sides do
		local pieces
		if ctx.Gates and ctx.Gates[side.Name] and side.Along == "Z" then
			-- two pieces either side of the gap (the gap is centred on gateZ)
			local lo, hi = -half - W.Thickness / 2, gateZ - gap / 2
			pieces = { { (lo + hi) / 2, hi - lo }, { (gateZ + gap / 2 + half + W.Thickness / 2) / 2, half + W.Thickness / 2 - (gateZ + gap / 2) } }
		else
			pieces = { { 0, len } }
		end
		for _, piece in pieces do
			local size = if side.Along == "X" then Vector3.new(piece[2], W.Height, W.Thickness) else Vector3.new(W.Thickness, W.Height, piece[2])
			local center = if side.Along == "X" then side.Center + Vector3.new(piece[1], 0, 0) else side.Center + Vector3.new(0, 0, piece[1])
			part({ Name = "PerimeterWall", Size = size, Position = ctx.Origin + center + Vector3.new(0, top + W.Height / 2, 0), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Concrete })
			local strip = part({ Name = "WallStrip", Size = if side.Along == "X" then Vector3.new(piece[2], 0.5, 0.4) else Vector3.new(0.4, 0.5, piece[2]),
				Position = ctx.Origin + center * ((half - 0.4) / half) + Vector3.new(0, top + W.Height - 2, 0), Color = Color3.fromRGB(255, 50, 160), Material = Enum.Material.Neon, CanCollide = false })
			strip.Name = "WallStrip"
		end
	end
end

local function safeZone()
	local S = D.SafeZone
	local g = D.Grid
	local top = D.GroundTop
	local c = centerBlock()
	local ox, oz = blockOrigin(c, c)
	local ringColor = ctx.RingColor or S.RingColor
	-- plaza floor: NOT tagged PlayableArea, so ambushes never land here
	part({ Name = "Plaza", Size = Vector3.new(g.BlockSize, 0.5, g.BlockSize), Position = Vector3.new(ox + g.BlockSize / 2, top + 0.25, oz + g.BlockSize / 2), Color = ctx.FloorColor or S.FloorColor, Material = Enum.Material.Slate })
	-- the zone marker: an invisible anchor carrying the tag + Radius; Combat/NPCs read it
	local zone = part({ Name = "SafeZone", Size = Vector3.new(1, 1, 1), Position = ctx.Origin + Vector3.new(0, top + 0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	zone:SetAttribute("Radius", S.Radius)
	zone:SetAttribute("ZoneName", ctx.Plaza or S.Name)
	zone:SetAttribute("District", ctx.Name)
	CollectionService:AddTag(zone, "SafeZone")
	-- neon ring on the ground at the boundary so players can see where safety ends
	local segments = 48
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = ctx.Origin + Vector3.new(math.cos(a) * S.Radius, top + 0.6, math.sin(a) * S.Radius)
		part({ Name = "SafeRing", Size = Vector3.new(2 * math.pi * S.Radius / segments + 0.3, 0.15, 0.8), Material = Enum.Material.Neon, Color = ringColor, CanCollide = false,
			CFrame = CFrame.lookAt(p, Vector3.new(ctx.Origin.X, p.Y, ctx.Origin.Z)) })
	end
	-- beacon pylon
	local B = S.Beacon
	part({ Name = "Beacon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(B.Height, B.Radius * 2, B.Radius * 2),
		CFrame = CFrame.new(ctx.Origin + Vector3.new(0, top + B.Height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Metal })
	local core = part({ Name = "BeaconCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(B.Height + 2, B.Radius * 0.6, B.Radius * 0.6),
		CFrame = CFrame.new(ctx.Origin + Vector3.new(0, top + B.Height / 2 + 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = ringColor, Material = Enum.Material.Neon, CanCollide = false })
	glow(core, ringColor, 60, 2)
	-- benches / planters as plaza cover (you can still be seen, not hit)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local p = ctx.Origin + Vector3.new(math.cos(a) * 18, top + 1.5, math.sin(a) * 18)
		part({ Name = "Planter", Size = Vector3.new(8, 2, 3), CFrame = CFrame.lookAt(p, Vector3.new(ctx.Origin.X, p.Y, ctx.Origin.Z)), Color = Color3.fromRGB(60, 80, 70), Material = Enum.Material.Concrete })
	end
	return zone
end

local function spawns()
	local S = D.Spawns
	local g = D.Grid
	local top = D.GroundTop
	local half = D.Extent() / 2
	local placed, tries = 0, 0
	while placed < S.Count and tries < 200 do
		tries += 1
		-- pick a random street point: a random street line and a random position along it
		local i = rng:NextInteger(0, g.Blocks)
		local line = -half + g.StreetWidth / 2 + i * (g.BlockSize + g.StreetWidth)
		local along = rng:NextNumber(-half + 10, half - 10)
		local p = if rng:NextNumber() < 0.5 then Vector3.new(along, 0, line) else Vector3.new(line, 0, along)
		local pos = ctx.Origin + p
		local fromPlaza = (pos - ctx.Origin).Magnitude
		if fromPlaza >= S.MinFromSafeZone and fromPlaza <= S.MaxFromSafeZone then
			local pad = part({ Name = "SpawnPad", Size = Vector3.new(8, 0.4, 8), Position = pos + Vector3.new(0, top + 0.2, 0),
				Material = Enum.Material.Neon, Color = ctx.RingColor or Color3.fromRGB(0, 220, 255), Transparency = 0.5, CanCollide = false })
			pad:SetAttribute("SpawnFor", ctx.SpawnFor)
			pad:SetAttribute("District", ctx.Name)
			CollectionService:AddTag(pad, "CitySpawn")
			placed += 1
		end
	end
	return placed
end

-- The gate street from district a (east wall) to district b (west wall): a PlayableArea slab
-- between the two street edges, lamps, and a neon arch in each wall gap.
local function gate(a, b)
	local G, W, g = D.Gate, D.Wall, D.Grid
	local top = D.GroundTop
	local half = D.Extent() / 2
	local z = a.Origin.Z + D.StreetLine(G.Line)
	local x0, x1 = a.Origin.X + half, b.Origin.X - half -- street edges
	local slab = part({ Name = "GateStreet", Size = Vector3.new(x1 - x0, 4, g.StreetWidth), Position = Vector3.new((x0 + x1) / 2, top - 2, z), Color = Color3.fromRGB(44, 44, 50), Material = Enum.Material.Asphalt })
	CollectionService:AddTag(slab, "PlayableArea")
	slab:SetAttribute("Gate", true)
	-- kerbs so the corridor reads as a street, not a floor
	for _, dz in { -g.StreetWidth / 2 - 1.5, g.StreetWidth / 2 + 1.5 } do
		part({ Name = "GateKerb", Size = Vector3.new(x1 - x0, 1, 3), Position = Vector3.new((x0 + x1) / 2, top + 0.5, z + dz), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Concrete })
	end
	-- lamps down both kerbs
	local x = x0 + 10
	while x < x1 - 5 do
		for _, dz in { -g.StreetWidth / 2 - 1.5, g.StreetWidth / 2 + 1.5 } do
			lamp(Vector3.new(x, 0, z + dz), D.Lamps.Color)
		end
		x += D.Lamps.Spacing
	end
	-- arches in the two wall gaps
	for _, wx in { a.Origin.X + half + W.Margin, b.Origin.X - half - W.Margin } do
		for _, dz in { -(g.StreetWidth + 2) / 2 - 1, (g.StreetWidth + 2) / 2 + 1 } do
			part({ Name = "GatePillar", Size = Vector3.new(W.Thickness + 1, G.Arch.Height, 2), Position = Vector3.new(wx, top + G.Arch.Height / 2, z + dz), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Metal })
		end
		local beam = part({ Name = "GateBeam", Size = Vector3.new(W.Thickness + 1, 1.5, g.StreetWidth + 6), Position = Vector3.new(wx, top + G.Arch.Height + 0.75, z), Color = G.Arch.Color, Material = Enum.Material.Neon, CanCollide = false })
		glow(beam, G.Arch.Color, 40, 1.5)
		local label = Instance.new("BillboardGui")
		label.Size, label.StudsOffset, label.AlwaysOnTop, label.MaxDistance = UDim2.fromOffset(260, 40), Vector3.new(0, 3, 0), true, 140
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		text.Text = if wx < (a.Origin.X + b.Origin.X) / 2 then ("→ %s"):format(b.Name) else ("%s ←"):format(a.Name)
		text.TextColor3, text.Font, text.TextScaled = G.Arch.Color, Enum.Font.GothamBold, true
		text.Parent = label
		label.Parent = beam
	end
end

local function build(def)
	ctx = def
	rng = Random.new(def.Seed)
	ground()
	blocks()
	cover()
	lamps()
	wall()
	safeZone()
	return spawns()
end

function District.Init()
	if workspace:FindFirstChild("District") then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "District"
	folder.Parent = workspace
	lighting()
	outskirts()
	local spawnsByDistrict = {}
	for _, def in D.Districts do
		spawnsByDistrict[def.Name] = build(def)
	end
	for i = 1, #D.Districts - 1 do
		gate(D.Districts[i], D.Districts[i + 1])
	end
	ctx = nil
	District.Built = { Spawns = spawnsByDistrict[D.Districts[1].Name], SpawnsByDistrict = spawnsByDistrict, Districts = #D.Districts, Parts = #folder:GetChildren() }
	-- the legacy placeholder slab is never needed once a district exists
	local placeholder = workspace:FindFirstChild("PlaceholderCity")
	if placeholder then
		placeholder:Destroy()
	end
end

return District
