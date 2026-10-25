-- District 1 generator (brief build-order 6): streets, buildings, cover, lamps, a perimeter wall,
-- CitySpawn pads and one safe zone, all from shared/District.lua numbers and a fixed seed. Built
-- once at boot before WorldPhase.Init (so the CitySpawn pads are found) and regardless of
-- Config.Dev — the dev arena is a separate, offset structure (Arena.lua). Everything is anchored
-- parts under workspace.District; nothing needs Studio building.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.District)

local District = {}

local folder
local rng

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

-- World X/Z of the south-west corner of block (bx, bz), 1-based.
local function blockOrigin(bx, bz)
	local g = D.Grid
	local half = D.Extent() / 2
	local x = -half + g.StreetWidth + (bx - 1) * (g.BlockSize + g.StreetWidth)
	local z = -half + g.StreetWidth + (bz - 1) * (g.BlockSize + g.StreetWidth)
	return D.Origin.X + x, D.Origin.Z + z
end

local function centerBlock()
	return math.ceil(D.Grid.Blocks / 2)
end

local function ground()
	local extent = D.Extent()
	local top = D.GroundTop
	-- one street slab under everything (tagged PlayableArea: ambushes and ground checks use it)
	local street = part({ Name = "Streets", Size = Vector3.new(extent, 4, extent), Position = D.Origin + Vector3.new(0, top - 2, 0),
		Color = Color3.fromRGB(44, 44, 50), Material = Enum.Material.Asphalt })
	CollectionService:AddTag(street, "PlayableArea")
	-- the collapsed city beyond the wall: a darker apron so the horizon is not void
	part({ Name = "Outskirts", Size = Vector3.new(extent * 3, 2, extent * 3), Position = D.Origin + Vector3.new(0, top - 4, 0),
		Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.Ground })
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
	local body = part({ Name = "Building", Size = Vector3.new(w, h, d), Position = Vector3.new(x, top + h / 2, z), Color = pick(B.Palette), Material = Enum.Material.Concrete })
	if rng:NextNumber() < B.WindowChance then
		-- a lit window band two thirds of the way up, on the long side
		local y = top + h * rng:NextNumber(0.45, 0.8)
		part({ Name = "Windows", Size = Vector3.new(w + 0.2, 1.2, d + 0.2), Position = Vector3.new(x, y, z), Color = Color3.fromRGB(255, 230, 170),
			Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
	end
	if rng:NextNumber() < B.NeonChance then
		-- a vertical neon sign strip on a random face, lit
		local color = pick(B.Neon)
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
	for bx = 1, g.Blocks do
		for bz = 1, g.Blocks do
			if not (bx == c and bz == c) then
				local ox, oz = blockOrigin(bx, bz)
				local inner = g.BlockSize - 2 * B.Inset
				if rng:NextNumber() < B.RubbleChance then
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
					local pos = D.Origin + Vector3.new(x, top + kind.Size.Y / 2, z)
					if not D.InSafeZone(pos) or (pos - D.Origin).Magnitude > D.SafeZone.Radius - 6 then
						local yaw = if horizontal then 0 else math.pi / 2
						part({ Name = kind.Name, Size = kind.Size, CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw + rng:NextNumber(-0.2, 0.2), 0), Color = kind.Color, Material = kind.Material })
					end
				end
			end
		end
	end
end

local function lamps()
	local g, L = D.Grid, D.Lamps
	local top = D.GroundTop
	local half = D.Extent() / 2
	for i = 0, g.Blocks do
		local line = -half + g.StreetWidth / 2 + i * (g.BlockSize + g.StreetWidth)
		local s = -half + g.StreetWidth / 2
		while s < half do
			for _, p in { Vector3.new(s, 0, line + g.StreetWidth / 2 - 1), Vector3.new(line + g.StreetWidth / 2 - 1, 0, s) } do
				local pos = D.Origin + p
				if (pos - D.Origin).Magnitude > D.SafeZone.Radius then
					local post = part({ Name = "Lamp", Size = Vector3.new(0.6, L.Height, 0.6), Position = pos + Vector3.new(0, top + L.Height / 2, 0), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal })
					local head = part({ Size = Vector3.new(1.4, 0.6, 1.4), Position = pos + Vector3.new(0, top + L.Height + 0.3, 0), Color = L.Color, Material = Enum.Material.Neon, CanCollide = false })
					glow(head, L.Color, L.Range, L.Brightness)
					post.Name = "Lamp"
				end
			end
			s += L.Spacing
		end
	end
end

local function wall()
	local W = D.Wall
	local half = D.Extent() / 2 + W.Margin
	local top = D.GroundTop
	local len = half * 2 + W.Thickness
	for _, def in {
		{ Vector3.new(0, 0, half), Vector3.new(len, W.Height, W.Thickness) },
		{ Vector3.new(0, 0, -half), Vector3.new(len, W.Height, W.Thickness) },
		{ Vector3.new(half, 0, 0), Vector3.new(W.Thickness, W.Height, len) },
		{ Vector3.new(-half, 0, 0), Vector3.new(W.Thickness, W.Height, len) },
	} do
		part({ Name = "PerimeterWall", Size = def[2], Position = D.Origin + def[1] + Vector3.new(0, top + W.Height / 2, 0), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Concrete })
		local strip = part({ Size = Vector3.new(if def[2].X > def[2].Z then len else 0.4, 0.5, if def[2].X > def[2].Z then 0.4 else len),
			Position = D.Origin + def[1] * ((half - 0.4) / half) + Vector3.new(0, top + W.Height - 2, 0), Color = Color3.fromRGB(255, 50, 160), Material = Enum.Material.Neon, CanCollide = false })
		strip.Name = "WallStrip"
	end
end

local function safeZone()
	local S = D.SafeZone
	local g = D.Grid
	local top = D.GroundTop
	local c = centerBlock()
	local ox, oz = blockOrigin(c, c)
	-- plaza floor: NOT tagged PlayableArea, so ambushes never land here
	local floor = part({ Name = "Plaza", Size = Vector3.new(g.BlockSize, 0.5, g.BlockSize), Position = Vector3.new(ox + g.BlockSize / 2, top + 0.25, oz + g.BlockSize / 2), Color = S.FloorColor, Material = Enum.Material.Slate })
	-- the zone marker: an invisible anchor carrying the tag + Radius; Combat/NPCs read it
	local zone = part({ Name = "SafeZone", Size = Vector3.new(1, 1, 1), Position = D.Origin + Vector3.new(0, top + 0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	zone:SetAttribute("Radius", S.Radius)
	zone:SetAttribute("ZoneName", S.Name)
	CollectionService:AddTag(zone, "SafeZone")
	-- neon ring on the ground at the boundary so players can see where safety ends
	local segments = 48
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = D.Origin + Vector3.new(math.cos(a) * S.Radius, top + 0.6, math.sin(a) * S.Radius)
		part({ Name = "SafeRing", Size = Vector3.new(2 * math.pi * S.Radius / segments + 0.3, 0.15, 0.8), Material = Enum.Material.Neon, Color = S.RingColor, CanCollide = false,
			CFrame = CFrame.lookAt(p, Vector3.new(D.Origin.X, p.Y, D.Origin.Z)) })
	end
	-- beacon pylon
	local B = S.Beacon
	local pylon = part({ Name = "Beacon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(B.Height, B.Radius * 2, B.Radius * 2),
		CFrame = CFrame.new(D.Origin + Vector3.new(0, top + B.Height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Metal })
	local core = part({ Name = "BeaconCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(B.Height + 2, B.Radius * 0.6, B.Radius * 0.6),
		CFrame = CFrame.new(D.Origin + Vector3.new(0, top + B.Height / 2 + 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = S.RingColor, Material = Enum.Material.Neon, CanCollide = false })
	glow(core, S.RingColor, 60, 2)
	-- benches / planters as plaza cover (you can still be seen, not hit)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local p = D.Origin + Vector3.new(math.cos(a) * 18, top + 1.5, math.sin(a) * 18)
		part({ Name = "Planter", Size = Vector3.new(8, 2, 3), CFrame = CFrame.lookAt(p, Vector3.new(D.Origin.X, p.Y, D.Origin.Z)), Color = Color3.fromRGB(60, 80, 70), Material = Enum.Material.Concrete })
	end
	floor.Name = "Plaza"
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
		local pos = D.Origin + p
		local fromPlaza = (pos - D.Origin).Magnitude
		if fromPlaza >= S.MinFromSafeZone and fromPlaza <= S.MaxFromSafeZone then
			local pad = part({ Name = "SpawnPad", Size = Vector3.new(8, 0.4, 8), Position = pos + Vector3.new(0, top + 0.2, 0),
				Material = Enum.Material.Neon, Color = Color3.fromRGB(0, 220, 255), Transparency = 0.5, CanCollide = false })
			CollectionService:AddTag(pad, "CitySpawn")
			placed += 1
		end
	end
	return placed
end

function District.Init()
	if workspace:FindFirstChild("District") then
		return
	end
	rng = Random.new(D.Seed)
	folder = Instance.new("Folder")
	folder.Name = "District"
	folder.Parent = workspace
	lighting()
	ground()
	blocks()
	cover()
	lamps()
	wall()
	safeZone()
	local n = spawns()
	District.Built = { Spawns = n, Parts = #folder:GetChildren() }
	-- the legacy placeholder slab is never needed once a district exists
	local placeholder = workspace:FindFirstChild("PlaceholderCity")
	if placeholder then
		placeholder:Destroy()
	end
end

return District
