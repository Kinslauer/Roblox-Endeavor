-- The frontier: everything north of the city wall, built from shared/Frontier (the layout and the
-- ground height) at startup.
--   * terrain (smooth terrain voxels) for the whole map outside the city plateau: the scarp face,
--     the valley bowl, the ring of mountains, the hills that close the city's other sides
--   * the switchback road down the scarp (asphalt slabs on the flattened face, hazard lamps,
--     wrecks) and the dirt trail that winds through the valley forest to the Reach
--   * the forest (trees, rocks, dead trees on the scarp)
--   * Verdant Reach: hedge ring, paths, greenhouse domes, solar towers, planter beds, lamps, and the
--     covered market at its heart: a safe zone with a trader (Remotes.Buy, paid in war credits)
--   * the sites in the ring: encampments, stockpiles and relic sites, each with its guards and its
--     loot containers (refilled after Config.Frontier.Refill)
--   * the route: checkpoints through the city and down the scarp, each held by a pack of rising
--     tier behind a barricade of breakable props; the next one is marked per player
-- Guards respawn like the city's population (Config.Frontier.Respawn), under their own cap.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local F = require(Shared.Frontier)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Common = script.Parent.Common
local Net = require(Common.Net)
local PlayerData = require(Common.PlayerData)
local Destruction = require(script.Parent.Destruction)
local Inventory = require(script.Parent.Inventory)
local Landmarks = require(script.Parent.Landmarks)
local Loot = require(script.Parent.Loot)
local Assets = require(Shared.Assets)
local ModelAssets = require(Common.ModelAssets)
local NPCs = require(script.Parent.NPCs)
local Quests = require(script.Parent.Quests)
local WorldPhase = require(script.Parent.WorldPhase)

local Frontier = {}
local C = Config.Frontier
local rng = Random.new(20261031) -- reseeded from the layout seed in Init
local folder
local alive = 0
local spawned = false
local H = F.Height

local PAL = {
	Trunk = Color3.fromRGB(86, 64, 46),
	Dead = Color3.fromRGB(70, 62, 56),
	Leaf = { Color3.fromRGB(62, 118, 58), Color3.fromRGB(84, 140, 66), Color3.fromRGB(52, 104, 76), Color3.fromRGB(110, 128, 54) },
	Rock = Color3.fromRGB(96, 94, 98),
	Road = Color3.fromRGB(48, 48, 54),
	Trail = Color3.fromRGB(128, 112, 86),
	Hazard = Color3.fromRGB(255, 150, 30),
	-- the Reach: bleached frames, solar glass, warm lamps
	Frame = Color3.fromRGB(226, 222, 206),
	Dome = Color3.fromRGB(190, 240, 230),
	Panel = Color3.fromRGB(30, 50, 90),
	Path = Color3.fromRGB(150, 140, 118),
	Lamp = Color3.fromRGB(255, 236, 200),
	Ring = Color3.fromRGB(170, 255, 170),
	Hedge = Color3.fromRGB(58, 110, 52),
	Tent = Color3.fromRGB(96, 92, 70),
	Concrete = Color3.fromRGB(120, 118, 112),
}

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

local function glow(p, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range or 18, brightness or 1.2
	light.Parent = p
	return light
end

local function ground(x, z)
	return if F.InCity(x, z) then F.CityTop else H(x, z)
end

local function slopeAt(x, z)
	local dx = H(x + 2, z) - H(x - 2, z)
	local dz = H(x, z + 2) - H(x, z - 2)
	return math.deg(math.atan(math.sqrt(dx * dx + dz * dz) / 4))
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- ===== terrain =====
local function materialAt(x, z, h, slope, dRoad, dTrail)
	if dRoad < 7 then
		return Enum.Material.Asphalt
	elseif dTrail < 6 then
		return Enum.Material.Ground
	end
	local R = F.Reach
	if (Vector3.new(x, 0, z) - flat(R.Center)).Magnitude <= R.Radius + 8 then
		return Enum.Material.LeafyGrass
	end
	if h > 250 then
		return Enum.Material.Snow
	elseif slope > 38 or h > 150 then
		return Enum.Material.Rock
	elseif z < 930 then
		return if slope > 20 then Enum.Material.Slate else Enum.Material.Ground
	end
	return Enum.Material.Grass
end

-- Nearest distance to a polyline (X/Z).
local function distTo(points, x, z)
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / len2, 0, 1) else 0
		local d = math.sqrt((x - a.X - abx * t) ^ 2 + (z - a.Z - abz * t) ^ 2)
		if d < best then
			best = d
		end
	end
	return best
end

local function writeTerrain()
	local terrain = workspace.Terrain
	local B = F.Bounds
	local RES, CHUNK = 4, 128
	local n = CHUNK / RES
	local chunks, voxels = 0, 0
	for cx = B.X0, B.X1 - 1, CHUNK do
		for cz = B.Z0, B.Z1 - 1, CHUNK do
			-- skip chunks that lie entirely under the city plateau
			if cx >= -F.CityEdge and cx + CHUNK <= F.CityEdge and cz >= -F.CityEdge and cz + CHUNK <= F.CityEdge then
				continue
			end
			local heights, mats = {}, {}
			local hmin, hmax = math.huge, -math.huge
			for i = 1, n do
				heights[i], mats[i] = {}, {}
				local x = cx + (i - 0.5) * RES
				for k = 1, n do
					local z = cz + (k - 0.5) * RES
					local h
					if F.InCity(x, z) then
						h = -1000 -- air: the city's own ground part is there
					else
						h = H(x, z)
						hmin, hmax = math.min(hmin, h), math.max(hmax, h)
					end
					heights[i][k] = h
				end
			end
			if hmax == -math.huge then
				continue
			end
			for i = 1, n do
				local x = cx + (i - 0.5) * RES
				for k = 1, n do
					local z = cz + (k - 0.5) * RES
					local h = heights[i][k]
					mats[i][k] = if h > -999 then materialAt(x, z, h, slopeAt(x, z), distTo(F.Switchbacks, x, z), distTo(F.Trail, x, z)) else Enum.Material.Air
				end
			end
			local y0 = math.floor((hmin - 10) / RES) * RES
			local y1 = math.ceil((hmax + 2) / RES) * RES + RES
			local ny = (y1 - y0) / RES
			local materials, occupancy = table.create(n), table.create(n)
			for i = 1, n do
				local mc, oc = table.create(ny), table.create(ny)
				for j = 1, ny do
					local bottom = y0 + (j - 1) * RES
					local mr, orow = table.create(n), table.create(n)
					for k = 1, n do
						local h = heights[i][k]
						-- live-measured: the rendered surface sits a half voxel above a column filled to h, so fill 2 lower
						local occ = math.clamp((h - 2 - bottom) / RES, 0, 1)
						orow[k] = occ
						mr[k] = if occ > 0 then mats[i][k] else Enum.Material.Air
					end
					mc[j], oc[j] = mr, orow
				end
				materials[i], occupancy[i] = mc, oc
			end
			local region = Region3.new(Vector3.new(cx, y0, cz), Vector3.new(cx + CHUNK, y1, cz + CHUNK))
			terrain:WriteVoxels(region, RES, materials, occupancy)
			chunks += 1
			voxels += n * n * ny
		end
	end
	return chunks, voxels
end

-- ===== roads and trail =====
local function ribbon(points, width, thickness, color, material, name, lift)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (flat(b) - flat(a)).Magnitude
		local steps = math.max(1, math.ceil(len / 14))
		for s = 0, steps - 1 do
			local t0, t1 = s / steps, (s + 1) / steps
			local p0 = flat(a):Lerp(flat(b), t0)
			local p1 = flat(a):Lerp(flat(b), t1)
			local y0, y1 = H(p0.X, p0.Z), H(p1.X, p1.Z)
			local from, to = Vector3.new(p0.X, y0, p0.Z), Vector3.new(p1.X, y1, p1.Z)
			local mid = (from + to) / 2 + Vector3.new(0, lift or 0, 0)
			local seg = (to - from).Magnitude + 1.5
			part({ Name = name, Size = Vector3.new(width, thickness, seg), CFrame = CFrame.lookAt(mid, mid + (to - from)), Color = color, Material = material })
		end
	end
end

local function hazardLamp(position, lit)
	local pole = part({ Name = "LampPole", Size = Vector3.new(0.6, 8, 0.6), Position = position + Vector3.new(0, 4, 0), Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal })
	local head = part({ Name = "LampHead", Size = Vector3.new(1.2, 1.2, 1.2), Position = position + Vector3.new(0, 8.4, 0), Color = PAL.Hazard, Material = if lit then Enum.Material.Neon else Enum.Material.Plastic, CanCollide = false })
	if lit then
		glow(head, PAL.Hazard, 26, 1.4)
	end
	return pole
end

local function buildRoads()
	ribbon(F.Switchbacks, 16, 1.2, PAL.Road, Enum.Material.Asphalt, "ScarpRoad", 0.1)
	-- a faded centre line
	ribbon(F.Switchbacks, 0.6, 1.3, Color3.fromRGB(150, 140, 90), Enum.Material.Concrete, "RoadLine", 0.15)
	ribbon(F.Trail, 9, 1.0, PAL.Trail, Enum.Material.Ground, "ValleyTrail", 0.05)
	-- hazard lamps along the switchbacks (half of them dark), wrecks on the verge
	for i = 1, #F.Switchbacks - 1 do
		local a, b = F.Switchbacks[i], F.Switchbacks[i + 1]
		local len = (flat(b) - flat(a)).Magnitude
		local dir = (flat(b) - flat(a)).Unit
		local perp = Vector3.new(-dir.Z, 0, dir.X)
		for along = 30, len - 20, 60 do
			local p = flat(a) + dir * along + perp * 9.5
			hazardLamp(Vector3.new(p.X, H(p.X, p.Z), p.Z), rng:NextNumber() < 0.5)
		end
		for _ = 1, 2 do
			local along = rng:NextNumber(20, len - 20)
			local p = flat(a) + dir * along + perp * rng:NextNumber(-5, 5)
			Destruction.SpawnProp(if rng:NextNumber() < 0.6 then "CarWreck" else "Slab", CFrame.new(p.X, H(p.X, p.Z), p.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
	-- the overlook: a railed ledge at the top of the scarp with a view of the valley
	local o = F.Scarp.Overlook
	part({ Name = "OverlookDeck", Size = Vector3.new(40, 1, 14), Position = Vector3.new(o.X, F.CityTop + 0.4, o.Z + 8), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	for k = -2, 2 do
		part({ Name = "RailPost", Size = Vector3.new(0.5, 3.5, 0.5), Position = Vector3.new(o.X + k * 9.5, F.CityTop + 2.2, o.Z + 14.5), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal })
	end
	part({ Name = "Rail", Size = Vector3.new(40, 0.4, 0.4), Position = Vector3.new(o.X, F.CityTop + 3.8, o.Z + 14.5), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal })
	local sign = part({ Name = "OverlookSign", Size = Vector3.new(8, 2.4, 0.3), Position = Vector3.new(o.X - 16, F.CityTop + 5, o.Z + 2), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Metal })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.TextColor3 = PAL.Hazard
	label.Text = "CITY LIMITS\nVERDANT REACH 1.2 km"
	label.Parent = gui
end

-- ===== chunks =====
-- Spawns a kit model (scaled, yawed at random) or returns nil so the caller builds parts instead.
local function kit(id, x, y, z, scale, name)
	if not id then
		return nil
	end
	local model = ModelAssets.Spawn(id, CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), name, folder)
	if model and scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	return model
end

local function tree(x, z, y)
	local list = if rng:NextNumber() < 0.6 then Assets.Frontier.Pines else Assets.Frontier.Broad
	local model = kit(list[rng:NextInteger(1, #list)], x, y - 0.5, z, rng:NextNumber(0.75, 1.3), "Tree")
	if model then
		CollectionService:AddTag(model, "Tree")
		return model
	end
	local h = rng:NextNumber(9, 16)
	local trunk = part({ Name = "Trunk", Size = Vector3.new(1.4, h, 1.4), Position = Vector3.new(x, y + h / 2 - 0.5, z), Color = PAL.Trunk, Material = Enum.Material.Wood })
	local leaf = PAL.Leaf[rng:NextInteger(1, #PAL.Leaf)]
	for i = 1, 2 do
		local r = rng:NextNumber(5, 8) - (i - 1) * 1.5
		part({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 2, r * 2), Position = Vector3.new(x + rng:NextNumber(-2, 2), y + h - 2 + (i - 1) * 4, z + rng:NextNumber(-2, 2)), Color = leaf, Material = Enum.Material.Grass, CanCollide = false })
	end
	CollectionService:AddTag(trunk, "Tree")
	return trunk
end

local function deadTree(x, z, y)
	if kit(Assets.Frontier.Dead, x, y - 0.5, z, rng:NextNumber(0.7, 1.2), "DeadTree") then
		return
	end
	local h = rng:NextNumber(7, 12)
	part({ Name = "DeadTrunk", Size = Vector3.new(1.1, h, 1.1), CFrame = CFrame.new(x, y + h / 2 - 0.5, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)), Color = PAL.Dead, Material = Enum.Material.Wood })
	part({ Name = "DeadBranch", Size = Vector3.new(0.5, 4, 0.5), CFrame = CFrame.new(x, y + h * 0.7, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(0.6, 1.1)), Color = PAL.Dead, Material = Enum.Material.Wood, CanCollide = false })
end

local function rock(x, z, y, size)
	local rocks = Assets.Frontier.Rocks
	if kit(rocks[rng:NextInteger(1, #rocks)], x, y - 0.6, z, size / 6, "Rock") then
		return
	end
	part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.7, size * 0.8), CFrame = CFrame.new(x, y + size * 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = PAL.Rock, Material = Enum.Material.Slate })
end

local function clearOf(x, z)
	-- keep the trail, the road, the Reach and the sites clear
	if distTo(F.Trail, x, z) < 12 or distTo(F.Switchbacks, x, z) < 14 then
		return false
	end
	if (Vector3.new(x, 0, z) - flat(F.Reach.Center)).Magnitude < F.Reach.Radius + 14 then
		return false
	end
	for _, site in F.Sites do
		if (Vector3.new(x, 0, z) - flat(site.Position)).Magnitude < 40 then
			return false
		end
	end
	for _, cp in F.Route do
		if (Vector3.new(x, 0, z) - flat(cp.Position)).Magnitude < 24 then
			return false
		end
	end
	return true
end

-- Scatter over a cell: calls fn(x, z, y, slope) at jittered grid points that are clear of the roads,
-- the Reach and the sites. `pitch` studs between points, `chance` to place.
local function scatter(cell, pitch, chance, fn)
	local half = F.Cell / 2 - 6
	local placed = 0
	for x = cell.Center.X - half, cell.Center.X + half, pitch do
		for z = cell.Center.Z - half, cell.Center.Z + half, pitch do
			local px, pz = x + rng:NextNumber(-pitch * 0.4, pitch * 0.4), z + rng:NextNumber(-pitch * 0.4, pitch * 0.4)
			if rng:NextNumber() < chance and clearOf(px, pz) then
				if fn(px, pz, H(px, pz), slopeAt(px, pz)) then
					placed += 1
				end
			end
		end
	end
	return placed
end

local counts = { trees = 0, rocks = 0, dead = 0 }
local function treeIf(px, pz, y, s)
	if s < 30 and y < 170 then
		tree(px, pz, y)
		counts.trees += 1
		return true
	elseif s >= 30 and y < 260 and rng:NextNumber() < 0.4 then
		rock(px, pz, y, rng:NextNumber(4, 11))
		counts.rocks += 1
		return true
	end
	return false
end

local function fallenLog(x, z, y)
	part({ Name = "FallenLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(rng:NextNumber(9, 14), 1.6, 1.6), CFrame = CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = PAL.Trunk, Material = Enum.Material.Wood })
end

local function flowers(x, z, y)
	local c = ({ Color3.fromRGB(230, 200, 80), Color3.fromRGB(220, 120, 160), Color3.fromRGB(150, 180, 255) })[rng:NextInteger(1, 3)]
	part({ Name = "Flowers", Size = Vector3.new(rng:NextNumber(3, 6), 0.8, rng:NextNumber(3, 6)), Position = Vector3.new(x, y + 0.3, z), Color = c, Material = Enum.Material.Grass, CanCollide = false })
end

-- The chunk templates. Each builds one 200-stud cell; the ground under it already carries the
-- chunk's own shape (shared/Frontier raw()).
local CHUNKS = {}
function CHUNKS.Forest(cell)
	scatter(cell, 27, 0.6, treeIf)
end
function CHUNKS.Glade(cell)
	scatter(cell, 26, 0.3, function(px, pz, y, s)
		if (Vector3.new(px, 0, pz) - cell.Center).Magnitude < 50 then
			return false -- the open middle
		end
		return treeIf(px, pz, y, s)
	end)
	for _ = 1, 3 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 40)
		local p = cell.Center + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		if clearOf(p.X, p.Z) then
			if rng:NextNumber() < 0.5 then
				fallenLog(p.X, p.Z, H(p.X, p.Z))
			else
				flowers(p.X, p.Z, H(p.X, p.Z))
			end
		end
	end
end
function CHUNKS.Meadow(cell)
	scatter(cell, 30, 0.18, treeIf)
	scatter(cell, 40, 0.3, function(px, pz, y)
		flowers(px, pz, y)
		return true
	end)
end
function CHUNKS.Boulders(cell)
	scatter(cell, 22, 0.55, function(px, pz, y)
		rock(px, pz, y, rng:NextNumber(5, 14))
		counts.rocks += 1
		return true
	end)
	scatter(cell, 36, 0.15, treeIf)
end
function CHUNKS.Marsh(cell)
	-- a pond in the hollow: water over the lowered ground; dead trees around it
	workspace.Terrain:FillBlock(CFrame.new(cell.Center.X, F.Floor - 5, cell.Center.Z), Vector3.new(120, 9, 120), Enum.Material.Water)
	scatter(cell, 26, 0.45, function(px, pz, y)
		if (Vector3.new(px, 0, pz) - cell.Center).Magnitude < 58 then
			return false
		end
		deadTree(px, pz, y)
		counts.dead += 1
		return true
	end)
end
function CHUNKS.Crater(cell)
	-- a blast bowl: scorched rocks on the rim, what the blast left in the middle
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local p = cell.Center + Vector3.new(math.sin(a) * 62, 0, math.cos(a) * 62)
		local r = part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 5, 6), CFrame = CFrame.new(p.X, H(p.X, p.Z) + 1, p.Z) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(50, 46, 46), Material = Enum.Material.Slate })
		r.Name = "ScorchedRock"
	end
	scatter(cell, 30, 0.3, function(px, pz, y)
		if (Vector3.new(px, 0, pz) - cell.Center).Magnitude < 75 then
			return false
		end
		deadTree(px, pz, y)
		counts.dead += 1
		return true
	end)
	local spoils = Items.Roll("Supply")
	if next(spoils) == nil then
		spoils.Scrap = 4
	end
	Loot.Spawn(CFrame.new(cell.Center.X, H(cell.Center.X, cell.Center.Z) + 2, cell.Center.Z), spoils, { Label = "Blast Remains", Mesh = "Stash" })
end
function CHUNKS.Ruin(cell)
	-- two collapsed buildings from the Sprawl kit, a loose yard of props
	for k = 1, 2 do
		local off = Vector3.new(k == 1 and -45 or 45, 0, k == 1 and 30 or -35)
		local p = cell.Center + off
		local entry = Assets.PickBuilding("Sprawl", 8, 22, 1, rng)
		if entry and clearOf(p.X, p.Z) then
			local y = H(p.X, p.Z)
			ModelAssets.Spawn(entry.Id, CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, cell.Rot + (k - 1) * math.pi / 2, 0), "Building", folder)
		end
	end
	for _ = 1, 4 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, 40)
		local p = cell.Center + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		if clearOf(p.X, p.Z) then
			Destruction.SpawnProp(({ "Crate", "Barrel", "Slab", "CarWreck" })[rng:NextInteger(1, 4)], CFrame.new(p.X, H(p.X, p.Z), p.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
	scatter(cell, 30, 0.2, treeIf)
end
function CHUNKS.Peaks(cell)
	scatter(cell, 34, 0.3, function(px, pz, y, s)
		if s >= 25 and y < 260 then
			rock(px, pz, y, rng:NextNumber(4, 12))
			counts.rocks += 1
			return true
		elseif s < 25 and y < 150 then
			tree(px, pz, y)
			counts.trees += 1
			return true
		end
		return false
	end)
end
function CHUNKS.Scarp()
	-- the face itself is handled once below (dead trees and boulders between the switchbacks)
end
-- site chunks: the site in the middle, thin woods around it
for _, kind in { "Camp", "Logging", "Shack", "Pump", "Mast", "Dropship", "Mine" } do
	CHUNKS[kind] = function(cell)
		scatter(cell, 30, 0.3, function(px, pz, y, s)
			if (Vector3.new(px, 0, pz) - cell.Center).Magnitude < 60 then
				return false
			end
			return treeIf(px, pz, y, s)
		end)
	end
end
CHUNKS.Reach = function() end -- buildReach does it

local function buildChunks()
	local built = {}
	for r = 1, F.Rows do
		for c = 1, F.Cols do
			local cell = F.L.Cells[r][c]
			local builder = CHUNKS[cell.Type] or CHUNKS.Forest
			builder(cell)
			built[cell.Type] = (built[cell.Type] or 0) + 1
		end
	end
	-- the scarp: dead trees and boulders on the face, between the switchbacks
	for _ = 1, 40 do
		local px, pz = rng:NextNumber(-520, 520), rng:NextNumber(780, 925)
		if clearOf(px, pz) then
			if rng:NextNumber() < 0.6 then
				deadTree(px, pz, H(px, pz))
				counts.dead += 1
			else
				rock(px, pz, H(px, pz), rng:NextNumber(3, 8))
				counts.rocks += 1
			end
		end
	end
	return built
end

-- ===== Verdant Reach =====
local function lamp(position, color, lit)
	part({ Name = "LampPost", Size = Vector3.new(0.5, 7, 0.5), Position = position + Vector3.new(0, 3.5, 0), Color = PAL.Frame, Material = Enum.Material.Metal })
	local head = part({ Name = "LampGlobe", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = position + Vector3.new(0, 7.3, 0), Color = color, Material = if lit then Enum.Material.Neon else Enum.Material.Glass, CanCollide = false })
	if lit then
		glow(head, color, 24, 1.2)
	end
end

local function buildReach()
	local R = F.Reach
	local c = R.Center
	local y = F.Floor
	-- hedge ring with gates south (the trail) and north
	local n = 40
	local g = R.GateAngle or math.pi -- the trail's gate; the back gate is opposite
	local function nearGate(a, width)
		local d = math.abs(((a - g + math.pi) % (2 * math.pi)) - math.pi)
		local d2 = math.abs(((a - g) % (2 * math.pi)) - math.pi)
		return math.min(d, d2) < width
	end
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		if nearGate(a, math.rad(9)) then
			continue -- the two gates
		end
		local p = c + Vector3.new(math.sin(a) * R.Radius, 0, math.cos(a) * R.Radius)
		part({ Name = "Hedge", Size = Vector3.new(2 * math.pi * R.Radius / n + 0.5, 5, 3), CFrame = CFrame.lookAt(Vector3.new(p.X, y + 2.5, p.Z), Vector3.new(c.X, y + 2.5, c.Z)) * CFrame.Angles(0, math.pi / 2, 0), Color = PAL.Hedge, Material = Enum.Material.Grass })
	end
	-- gate posts and lamps at the south gate
	local gateDir = Vector3.new(math.sin(g), 0, math.cos(g)) -- from the centre to the gate
	local gateSide = Vector3.new(-gateDir.Z, 0, gateDir.X)
	for _, sx in { -1, 1 } do
		part({ Name = "GatePost", Size = Vector3.new(1.5, 9, 1.5), Position = c + gateDir * R.Radius + gateSide * (sx * 10) + Vector3.new(0, 4.5, 0), Color = PAL.Frame, Material = Enum.Material.Concrete })
		lamp(c + gateDir * (R.Radius - 6) + gateSide * (sx * 12), PAL.Lamp, true)
	end
	-- sand paths: a cross between the gates and a ring
	ribbon({ c - gateDir * R.Radius, c + gateDir * R.Radius }, 8, 0.6, PAL.Path, Enum.Material.Sand, "ReachPath", 0.05)
	ribbon({ c - gateSide * R.Radius, c + gateSide * R.Radius }, 8, 0.6, PAL.Path, Enum.Material.Sand, "ReachPath", 0.05)
	local ringPts = {}
	for i = 0, 24 do
		local a = i / 24 * math.pi * 2
		table.insert(ringPts, c + Vector3.new(math.sin(a) * 110, 0, math.cos(a) * 110))
	end
	ribbon(ringPts, 6, 0.6, PAL.Path, Enum.Material.Sand, "ReachPath", 0.05)
	-- greenhouse domes with grow lamps, between the ring path and the hedge
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2 + 0.2
		local r = 148
		local p = c + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		local domeModel = Assets.Frontier.Dome and ModelAssets.Spawn(Assets.Frontier.Dome, CFrame.new(p.X, y, p.Z) * CFrame.lookAt(Vector3.zero, Vector3.new(c.X - p.X, 0, c.Z - p.Z)).Rotation, "Dome", folder)
		if domeModel then
			local grow = part({ Name = "GrowLight", Size = Vector3.new(1, 1, 1), Position = Vector3.new(p.X, y + 6, p.Z), Transparency = 1, CanCollide = false })
			glow(grow, Color3.fromRGB(255, 120, 220), 26, 0.8)
		else
			local dome = part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(22, 22, 22), Position = Vector3.new(p.X, y + 1, p.Z), Color = PAL.Dome, Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false })
			glow(dome, Color3.fromRGB(255, 120, 220), 26, 0.8)
			part({ Name = "DomeBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 23, 23), CFrame = CFrame.new(p.X, y + 0.5, p.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = PAL.Frame, Material = Enum.Material.Concrete })
		end
		for k = 1, 3 do
			part({ Name = "GrowBed", Size = Vector3.new(6, 1.2, 1.6), Position = Vector3.new(p.X + (k - 2) * 3.2, y + 1, p.Z), Color = PAL.Leaf[2], Material = Enum.Material.Grass, CanCollide = false })
		end
	end
	-- solar towers
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p = c + Vector3.new(math.sin(a) * 80, 0, math.cos(a) * 80)
		if not (Assets.Frontier.Tower and ModelAssets.Spawn(Assets.Frontier.Tower, CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, -a, 0), "SolarTower", folder)) then
			part({ Name = "TowerMast", Size = Vector3.new(1.2, 26, 1.2), Position = Vector3.new(p.X, y + 13, p.Z), Color = PAL.Frame, Material = Enum.Material.Metal })
			part({ Name = "SolarPanel", Size = Vector3.new(12, 0.4, 8), CFrame = CFrame.new(p.X, y + 26, p.Z) * CFrame.Angles(-0.5, a, 0), Color = PAL.Panel, Material = Enum.Material.Glass, CanCollide = false })
		end
	end
	-- planter beds along the cross paths, trees, lamps
	for i = 1, 28 do
		local a = (i % 4) * math.pi / 2
		local d = 24 + math.floor((i - 1) / 4) * 18
		local side = if i % 2 == 0 then 8 else -8
		local p = c + Vector3.new(math.sin(a) * d + math.cos(a) * side, 0, math.cos(a) * d - math.sin(a) * side)
		part({ Name = "Planter", Size = Vector3.new(6, 1.4, 2.4), CFrame = CFrame.new(p.X, y + 0.7, p.Z) * CFrame.Angles(0, a, 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
		part({ Name = "PlanterGreen", Size = Vector3.new(5.4, 1.2, 1.8), CFrame = CFrame.new(p.X, y + 1.9, p.Z) * CFrame.Angles(0, a, 0), Color = PAL.Leaf[(i % #PAL.Leaf) + 1], Material = Enum.Material.Grass, CanCollide = false })
	end
	for _ = 1, 40 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(40, R.Radius - 14)
		local p = c + Vector3.new(math.sin(a) * d, 0, math.cos(a) * d)
		if distTo({ c - gateDir * R.Radius, c + gateDir * R.Radius }, p.X, p.Z) > 8 and distTo({ c - gateSide * R.Radius, c + gateSide * R.Radius }, p.X, p.Z) > 8 and math.abs(d - 110) > 7 and math.abs(d - 148) > 14 then
			tree(p.X, p.Z, y)
		end
	end
	for i = 1, 20 do
		local a = i / 20 * math.pi * 2
		lamp(c + Vector3.new(math.sin(a) * 118, 0, math.cos(a) * 118), PAL.Lamp, true)
	end
	-- the market: a covered round plaza at the centre, stalls, the trader's counter
	local roof = part({ Name = "MarketRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, R.Market * 2, R.Market * 2), CFrame = CFrame.new(c.X, y + 12, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = PAL.Dome, Material = Enum.Material.Glass, Transparency = 0.4 })
	roof.CanCollide = false
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local p = c + Vector3.new(math.sin(a) * (R.Market - 3), 0, math.cos(a) * (R.Market - 3))
		part({ Name = "MarketPost", Size = Vector3.new(1, 12, 1), Position = Vector3.new(p.X, y + 6, p.Z), Color = PAL.Frame, Material = Enum.Material.Metal })
	end
	local ring = part({ Name = "SafeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R.Market * 2, R.Market * 2), CFrame = CFrame.new(c.X, y + 0.15, c.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = PAL.Ring, Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false })
	ring:SetAttribute("SafeZone", "Verdant Market")
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.3
		local p = c + Vector3.new(math.sin(a) * 30, 0, math.cos(a) * 30)
		part({ Name = "Stall", Size = Vector3.new(8, 3, 3), CFrame = CFrame.new(p.X, y + 1.5, p.Z) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
		part({ Name = "Awning", Size = Vector3.new(9, 0.3, 4), CFrame = CFrame.new(p.X, y + 5, p.Z) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.2, 0, 0), Color = PAL.Leaf[(i % 4) + 1], Material = Enum.Material.Fabric, CanCollide = false })
	end
	local counter = part({ Name = "TraderCounter", Size = Vector3.new(10, 3.2, 3), Position = Vector3.new(c.X, y + 1.6, c.Z + 8), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local screen = part({ Name = "TraderSign", Size = Vector3.new(6, 1.6, 0.3), Position = Vector3.new(c.X, y + 5.2, c.Z + 8), Color = PAL.Ring, Material = Enum.Material.Neon, CanCollide = false })
	glow(screen, PAL.Ring, 20, 1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.new(0, 0, 0)
	label.Text = "VERDANT MARKET - TRADER"
	label.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Trader"
	prompt.ActionText = "Browse wares"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player)
		Frontier.OpenMarket(player)
	end)
	counter:SetAttribute("Trader", true)
	Landmarks.Register("Reach", Vector3.new(c.X, y + 16, c.Z), "Verdant Reach", PAL.Ring)
	Landmarks.Register("Scarp", F.Scarp.Overlook + Vector3.new(0, 10, 0), "City limits: the Scarp", PAL.Hazard)
end

-- ===== guards =====
-- Living frontier bodies: posts (checkpoints, sites) and encounters are capped separately.
local function countAlive(encounter)
	local n = 0
	for _, model in CollectionService:GetTagged("NPC") do
		if model:GetAttribute("Frontier") and (model:GetAttribute("Encounter") == true) == (encounter == true) then
			local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				n += 1
			end
		end
	end
	return n
end

-- opts: NoRespawn (an encounter body stays dead until its encounter rolls again), OnDied(model, position),
-- Patrol = { points } (walks the loop instead of wandering the anchor)
local function spawnGuard(typeName, anchor, radius, scale, bossName, opts)
	opts = opts or {}
	if countAlive(opts.Encounter) >= (if opts.Encounter then C.EncounterCap else C.Cap) then
		return nil
	end
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, radius)
	local x, z = anchor.X + math.cos(a) * r, anchor.Z + math.sin(a) * r
	local model
	model = NPCs.Spawn(typeName, Vector3.new(x, ground(x, z) + 3.5, z), {
		Parent = folder,
		Scale = scale,
		OnDied = function()
			alive -= 1
			if opts.OnDied then
				local root = model and model:FindFirstChild("HumanoidRootPart")
				opts.OnDied(model, root and root.Position or anchor)
			end
			if not opts.NoRespawn then
				task.delay(C.Respawn, function()
					if WorldPhase.IsOpen() then
						spawnGuard(typeName, anchor, radius, scale, bossName, opts)
					end
				end)
			end
		end,
	})
	if model then
		alive += 1
		model:SetAttribute("Frontier", true)
		if opts.Encounter then
			model:SetAttribute("Encounter", true)
		end
		for k, v in opts.Attrs or {} do
			model:SetAttribute(k, v)
		end
		if bossName then
			model.Name = bossName
		end
		if opts.Patrol then
			-- walk the loop: each leg is a point of the patrol, taken in turn
			task.spawn(function()
				local i = rng:NextInteger(1, #opts.Patrol)
				while model.Parent do
					if not model:GetAttribute("Investigate") then
						i = (i % #opts.Patrol) + 1
						local p = opts.Patrol[i]
						model:SetAttribute("Investigate", Vector3.new(p.X, ground(p.X, p.Z), p.Z))
						model:SetAttribute("InvestigateUntil", os.clock() + (opts.Leg or C.PatrolLeg))
					end
					task.wait(opts.Leg or C.PatrolLeg)
				end
			end)
			return model
		end
		-- stand their ground: wander a little around the anchor
		task.spawn(function()
			while model.Parent do
				task.wait(rng:NextNumber(8, 16))
				if model.Parent and not model:GetAttribute("Investigate") then
					local wa, wr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, radius)
					model:SetAttribute("Investigate", Vector3.new(anchor.X + math.cos(wa) * wr, ground(anchor.X, anchor.Z), anchor.Z + math.sin(wa) * wr))
					model:SetAttribute("InvestigateUntil", os.clock() + 8)
				end
			end
		end)
	end
	return model
end

local function spawnPack(def, anchor, radius, opts)
	local models = {}
	for _, g in def.Guards or {} do
		for i = 1, g[2] do
			local m = spawnGuard(g[1], anchor, radius, def.Scale or 1, if def.Boss and i == 1 and g == def.Guards[1] then def.Boss else nil, opts)
			if m then
				table.insert(models, m)
			end
		end
	end
	return models
end

-- ===== encounters =====
-- Each valley cell may carry one (shared/Frontier ENCOUNTERS). Patrols, nests and bounties stand from
-- world open and come back after Config.Frontier.Respawn; ambushes sleep in the cell until someone
-- walks in, then rest. Encounters count toward the frontier cap like guards.
local encounters = {} -- cell -> { def, state, until }

local function patrolLoop(cell)
	-- a loop through the cell and whichever neighbours are valley ground
	local pts = { cell.Center + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40)) }
	for _, d in { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } do
		local nr, nc = cell.Row + d[1], cell.Col + d[2]
		local n = F.L.Cells[nr] and F.L.Cells[nr][nc]
		if n and n.Zone == "Valley" and n.Type ~= "Reach" and rng:NextNumber() < 0.6 then
			table.insert(pts, n.Center + Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50)))
		end
	end
	if #pts < 2 then
		table.insert(pts, cell.Center + Vector3.new(60, 0, -60))
	end
	return pts
end

local function startEncounter(cell)
	local e = cell.Encounter
	local entry = encounters[cell] or { def = e }
	encounters[cell] = entry
	entry.started = true
	entry.lastNear = os.clock()
	local anchor = cell.Center + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
	if e.Kind == "Patrol" then
		entry.models = spawnPack(e, anchor, 10, { Patrol = patrolLoop(cell), Encounter = true })
	elseif e.Kind == "Nest" then
		entry.models = spawnPack(e, anchor, 14, { Encounter = true })
		local spoils = Items.Roll("Supply")
		for id, n in Items.Roll("Vault") do
			spoils[id] = (spoils[id] or 0) + n
		end
		if next(spoils) == nil then
			spoils.ArcCell = 8
		end
		if not entry.stash or not entry.stash.Parent then
			entry.stash = Loot.Spawn(CFrame.new(anchor.X, ground(anchor.X, anchor.Z) + 2, anchor.Z), spoils, { Label = "Shocker Nest", Mesh = "Stash" })
		end
	elseif e.Kind == "Bounty" then
		entry.models = spawnPack({ Guards = e.Guards, Scale = e.Scale, Boss = e.Boss }, anchor, 8, {
			Encounter = true,
			Attrs = { Bounty = true },
			OnDied = function(_, position)
				-- the bounty: relic-table spoils where it fell, announced to everyone
				local spoils = Items.Roll("Relic")
				if next(spoils) == nil then
					spoils.ArcCell = 10
				end
				Loot.Spawn(CFrame.new(position + Vector3.new(0, 2, 0)), spoils, { Label = e.Boss .. "'s Hoard", Mesh = "CrateB" })
				Remotes.Announce:FireAllClients(("%s has fallen in the valley."):format(e.Boss), "Event")
			end,
		})
	end
end

local function springAmbush(cell, player)
	local e = cell.Encounter
	local entry = encounters[cell] or { def = e }
	encounters[cell] = entry
	entry.restUntil = os.clock() + C.AmbushRest
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local around = root and root.Position or cell.Center
	-- they come out of the trees behind and beside you
	local anchor = Vector3.new(around.X, 0, around.Z) + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20))
	entry.models = spawnPack(e, anchor, 18, { NoRespawn = true, Encounter = true })
	Remotes.Announce:FireClient(player, "Ambush!", "Emergence")
	for _, m in entry.models do
		m:SetAttribute("Investigate", around)
		m:SetAttribute("InvestigateUntil", os.clock() + 10)
	end
end

-- A woken encounter nobody is near any more stands down (its bodies vanish) and wakes again later.
local function standDown(entry)
	for _, m in entry.models or {} do
		if m.Parent then
			m:Destroy()
		end
	end
	entry.models = nil
	entry.started = false
end

local function encounterTick(now)
	-- who is near which woken encounter
	for cell, entry in encounters do
		if entry.started then
			local near = false
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - cell.Center).Magnitude <= C.WakeRadius * 2 then
					near = true
					break
				end
			end
			if near then
				entry.lastNear = now
			elseif now - (entry.lastNear or now) > C.SleepSeconds then
				standDown(entry)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			continue
		end
		local cell = F.CellAt(root.Position.X, root.Position.Z)
		if cell and cell.Encounter and cell.Encounter.Kind == "Ambush" then
			local entry = encounters[cell]
			local resting = entry and entry.restUntil and now < entry.restUntil
			if not resting and (Vector3.new(root.Position.X, 0, root.Position.Z) - cell.Center).Magnitude <= C.AmbushRadius then
				springAmbush(cell, player)
			end
		end
		-- standing encounters wake as you come near (so the valley is not full of bodies nobody sees)
		local flatPos = Vector3.new(root.Position.X, 0, root.Position.Z)
		for _, c in F.L.Cells do
			for _, other in c do
				if other.Encounter and other.Encounter.Kind ~= "Ambush" and not (encounters[other] and encounters[other].started) then
					if (flatPos - other.Center).Magnitude <= C.WakeRadius then
						startEncounter(other)
					end
				end
			end
		end
	end
end

function Frontier.Encounters()
	return encounters
end

-- ===== sites =====
local containers = {} -- { site, position, label, mesh, part, emptiedAt }

local function bundleFor(site)
	local bundle = {}
	for _, stock in site.Stock or {} do
		for _ = 1, stock[2] do
			for id, n in Items.Roll(stock[1]) do
				bundle[id] = (bundle[id] or 0) + n
			end
		end
	end
	for id, n in site.Fixed or {} do
		bundle[id] = (bundle[id] or 0) + n
	end
	if next(bundle) == nil then
		bundle.Scrap = 3
	end
	return bundle
end

local function placeContainer(entry)
	entry.part = Loot.Spawn(CFrame.new(entry.position + Vector3.new(0, 1.5, 0)), bundleFor(entry.site), { Label = entry.label, Mesh = entry.mesh, Size = Vector3.new(4, 1.6, 4) })
	entry.emptiedAt = nil
	if entry.part then
		entry.part:SetAttribute("Site", entry.site.Key)
	end
end

local function addContainer(site, position, label, mesh)
	local entry = { site = site, position = position, label = label, mesh = mesh }
	table.insert(containers, entry)
	placeContainer(entry)
	return entry
end

local function campfire(position)
	local pit = part({ Name = "Firepit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 36, 34), Material = Enum.Material.Slate })
	local flame = part({ Name = "Flame", Size = Vector3.new(1.4, 2, 1.4), Position = position + Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon, CanCollide = false })
	glow(flame, Color3.fromRGB(255, 150, 60), 28, 1.6)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 5, 10
	fire.Parent = pit
	return pit
end

local function tent(position, yaw)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	if Assets.Frontier.Tent and ModelAssets.Spawn(Assets.Frontier.Tent, cf, "Tent", folder) then
		return
	end
	for _, s in { -1, 1 } do
		part({ Name = "TentSide", Size = Vector3.new(7, 0.3, 6), CFrame = cf * CFrame.new(s * 2.2, 2.2, 0) * CFrame.Angles(0, 0, s * 0.9), Color = PAL.Tent, Material = Enum.Material.Fabric })
	end
	part({ Name = "TentBack", Size = Vector3.new(6, 4, 0.3), CFrame = cf * CFrame.new(0, 2, -3), Color = PAL.Tent, Material = Enum.Material.Fabric })
end

local function hut(position, yaw, w, d, h)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part({ Name = "HutFloor", Size = Vector3.new(w, 1, d), CFrame = cf * CFrame.new(0, 0.5, 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	part({ Name = "HutWall", Size = Vector3.new(w, h, 1), CFrame = cf * CFrame.new(0, h / 2, -d / 2), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	for _, s in { -1, 1 } do
		part({ Name = "HutWall", Size = Vector3.new(1, h, d), CFrame = cf * CFrame.new(s * w / 2, h / 2, 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	end
	-- front wall with a doorway
	for _, s in { -1, 1 } do
		part({ Name = "HutWall", Size = Vector3.new(w / 2 - 2.5, h, 1), CFrame = cf * CFrame.new(s * (w / 4 + 1.25), h / 2, d / 2), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	end
	part({ Name = "HutRoof", Size = Vector3.new(w + 1, 0.8, d + 1), CFrame = cf * CFrame.new(0, h + 0.4, 0), Color = Color3.fromRGB(80, 78, 76), Material = Enum.Material.Metal })
	return cf
end

local SITE_COLORS = { Encampment = Color3.fromRGB(255, 120, 60), Stockpile = Color3.fromRGB(120, 200, 255), Relic = Color3.fromRGB(255, 80, 220) }

local function buildSite(site)
	local p = site.Position
	local y = H(p.X, p.Z)
	site.Y = y
	local base = Vector3.new(p.X, y, p.Z)
	site.Ground = base
	if site.Kind == "Encampment" then
		campfire(base)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2 + 0.4
			tent(base + Vector3.new(math.sin(a) * 13, 0, math.cos(a) * 13), -a + math.pi)
		end
		-- a loose barricade of breakable panels
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			Destruction.SpawnProp(if i % 3 == 0 then "Barrel" else "FencePanel", CFrame.new(base + Vector3.new(math.sin(a) * 24, 0, math.cos(a) * 24)) * CFrame.Angles(0, -a + math.pi / 2, 0))
		end
		addContainer(site, base + Vector3.new(0, 0, -9), site.Name .. " Stockpile", "CrateA")
		if site.Key == "LoggingCamp" then
			for i = 1, 6 do
				part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 1.6, 1.6), CFrame = CFrame.new(base + Vector3.new(16, 0.8 + (i > 3 and 1.5 or 0), (i % 3) * 1.8 - 1.8)), Color = PAL.Trunk, Material = Enum.Material.Wood })
			end
		end
	elseif site.Kind == "Stockpile" then
		local cf = hut(base, site.Rot or 0, 16, 12, 7)
		addContainer(site, (cf * CFrame.new(0, 0.5, -2)).Position, site.Name .. " Store", "CrateB")
		Destruction.SpawnProp("Crate", cf * CFrame.new(9, 0, 4))
		Destruction.SpawnProp("Barrel", cf * CFrame.new(-9, 0, 5))
		if site.Key == "PumpStation" then
			part({ Name = "PumpTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 9, 9), CFrame = CFrame.new(base + Vector3.new(0, 4.5, -16)), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.CorrodedMetal })
			part({ Name = "PumpPipe", Size = Vector3.new(1.2, 1.2, 30), Position = base + Vector3.new(0, 1, -30), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.CorrodedMetal })
		end
	else -- Relic
		if site.Key == "SignalMast" then
			local mast = part({ Name = "Mast", Size = Vector3.new(2, 70, 2), Position = base + Vector3.new(0, 35, -10), Color = Color3.fromRGB(120, 40, 40), Material = Enum.Material.Metal })
			local beacon = part({ Name = "MastBeacon", Size = Vector3.new(2.5, 2.5, 2.5), Position = base + Vector3.new(0, 71, -10), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon, CanCollide = false })
			glow(beacon, Color3.fromRGB(255, 40, 40), 90, 2)
			for i = 1, 3 do
				local a = i / 3 * math.pi * 2
				part({ Name = "GuyWire", Size = Vector3.new(0.2, 48, 0.2), CFrame = CFrame.new(base + Vector3.new(math.sin(a) * 9, 22, math.cos(a) * 9 - 10)) * CFrame.Angles(0, a, 0.38), Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Metal, CanCollide = false })
			end
			mast:SetAttribute("Relic", true)
			hut(base + Vector3.new(14, 0, 4), 0, 10, 8, 5)
			addContainer(site, base + Vector3.new(14, 0.5, 2), "Relay Vault", "CrateB")
		elseif site.Key == "Dropship" then
			local cf = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(0.15, (site.Rot or 0) + 0.6, 0.3)
			part({ Name = "Hull", Size = Vector3.new(28, 7, 10), CFrame = cf, Color = Color3.fromRGB(70, 74, 80), Material = Enum.Material.DiamondPlate })
			part({ Name = "Wing", Size = Vector3.new(6, 0.8, 22), CFrame = cf * CFrame.new(-6, 2, 0), Color = Color3.fromRGB(70, 74, 80), Material = Enum.Material.DiamondPlate })
			part({ Name = "WingBroken", Size = Vector3.new(6, 0.8, 12), CFrame = CFrame.new(base + Vector3.new(18, 1, -12)) * CFrame.Angles(0.4, 1.2, 0.5), Color = Color3.fromRGB(70, 74, 80), Material = Enum.Material.DiamondPlate })
			local fire = campfire(base + Vector3.new(-12, 0, 8))
			fire.Name = "WreckFire"
			addContainer(site, base + Vector3.new(0, 7, 0), "Dropship Cargo", "CrateB")
			addContainer(site, base + Vector3.new(14, 0.5, 6), "Pilot's Locker", "Stash")
		else -- OldMine: a timbered tunnel mouth into the mountain, the vault at its end
			-- the tunnel runs into the nearest wall of peaks
			local cell = site.Cell
			local dir = if cell and cell.Col == 2 then Vector3.new(-1, 0, 0) elseif cell and cell.Col == F.Cols - 1 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
			local cf = CFrame.lookAt(base, base + dir)
			for i = 0, 5 do
				local seg = cf * CFrame.new(0, 0, -i * 6 - 8)
				part({ Name = "MineFloor", Size = Vector3.new(10, 1, 6.5), CFrame = seg * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Slate })
				part({ Name = "MineRoof", Size = Vector3.new(11, 1, 6.5), CFrame = seg * CFrame.new(0, 8.5, 0), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Slate })
				for _, s in { -1, 1 } do
					part({ Name = "MineWall", Size = Vector3.new(1, 8, 6.5), CFrame = seg * CFrame.new(s * 5, 4.5, 0), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Slate })
					part({ Name = "Timber", Size = Vector3.new(0.8, 8, 0.8), CFrame = seg * CFrame.new(s * 4.3, 4.5, 2.5), Color = PAL.Trunk, Material = Enum.Material.Wood })
				end
				part({ Name = "Timber", Size = Vector3.new(10, 0.8, 0.8), CFrame = seg * CFrame.new(0, 8, 2.5), Color = PAL.Trunk, Material = Enum.Material.Wood })
				local l = part({ Name = "MineLamp", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = seg * CFrame.new(0, 7.6, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
				glow(l, Color3.fromRGB(255, 190, 110), 14, 0.9)
			end
			part({ Name = "MineEnd", Size = Vector3.new(10, 9, 1), CFrame = cf * CFrame.new(0, 4.5, -41.5), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Slate })
			addContainer(site, (cf * CFrame.new(0, 1, -38)).Position, "Mine Vault", "CrateB")
			addContainer(site, (cf * CFrame.new(3, 1, -20)).Position, "Miner's Cache", "Stash")
			Destruction.SpawnProp("Crate", cf * CFrame.new(-6, 0, 2))
			Destruction.SpawnProp("Barrel", cf * CFrame.new(7, 0, 1))
		end
	end
	-- a site marker: a dim flag so it can be found from afar once you know where to look
	local pole = part({ Name = "SitePole", Size = Vector3.new(0.4, 12, 0.4), Position = base + Vector3.new(6, 6, 6), Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal })
	part({ Name = "SiteFlag", Size = Vector3.new(4, 2.4, 0.2), Position = base + Vector3.new(8, 11, 6), Color = SITE_COLORS[site.Kind], Material = Enum.Material.Fabric, CanCollide = false })
	pole:SetAttribute("Site", site.Key)
end

-- ===== the route =====
local function buildCheckpoint(index)
	local cp = F.Route[index]
	if cp.Key == "Reach" then
		return
	end
	local p = cp.Position
	local y = ground(p.X, p.Z)
	local base = Vector3.new(p.X, y, p.Z)
	local prev = if index > 1 then F.Route[index - 1].Position else Vector3.new(0, 0, -420)
	local dir = (flat(prev) - flat(p))
	dir = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, -1)
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	-- the barricade faces the way you come from
	for i, propId in cp.Barricade or {} do
		local off = (i - (#cp.Barricade + 1) / 2) * 6
		local pos = base + dir * 10 + perp * off
		Destruction.SpawnProp(propId, CFrame.new(pos.X, ground(pos.X, pos.Z), pos.Z) * CFrame.lookAt(Vector3.zero, dir).Rotation)
	end
	-- a checkpoint post with a hazard light and the name
	local post = part({ Name = "CheckpointPost", Size = Vector3.new(0.8, 9, 0.8), Position = base + Vector3.new(0, 4.5, 0) + perp * 7, Color = Color3.fromRGB(50, 50, 56), Material = Enum.Material.Metal })
	local head = part({ Name = "CheckpointLight", Size = Vector3.new(1.6, 1.6, 1.6), Position = post.Position + Vector3.new(0, 5.2, 0), Color = PAL.Hazard, Material = Enum.Material.Neon, CanCollide = false })
	glow(head, PAL.Hazard, 30, 1.5)
	local sign = part({ Name = "CheckpointSign", Size = Vector3.new(6, 1.4, 0.3), CFrame = CFrame.lookAt(post.Position + Vector3.new(0, 2.6, 0), post.Position + Vector3.new(0, 2.6, 0) + dir), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Metal, CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.TextColor3 = PAL.Hazard
	label.Text = ("%d  %s"):format(index, cp.Name:upper())
	label.Parent = gui
	post:SetAttribute("Checkpoint", cp.Key)
end

-- ===== runtime =====
local function dataOf(player)
	local data = PlayerData.Get(player)
	if data then
		data.Frontier = data.Frontier or { Route = 0, Found = {}, Reached = false }
		return data.Frontier
	end
	return nil
end

local function routeMarker(player, fd)
	local nextCp = F.Route[fd.Route + 1]
	if nextCp then
		Remotes.World:FireClient(player, "Marker", "Route", nextCp.Position + Vector3.new(0, 8, 0), ("Route north %d/%d: %s"):format(fd.Route + 1, #F.Route, nextCp.Name), nil, PAL.Hazard)
	else
		Remotes.World:FireClient(player, "MarkerClear", "Route")
	end
end

local function sendFound(player, fd)
	for key in fd.Found do
		local site = F.Site(key)
		if site then
			Remotes.World:FireClient(player, "Marker", "Site_" .. key, site.Position + Vector3.new(0, (site.Y or 0) + 14, 0), ("%s (%s)"):format(site.Name, site.Kind), nil, SITE_COLORS[site.Kind])
		end
	end
end

function Frontier.Stock(player)
	local data = PlayerData.Get(player)
	local list = {}
	for _, s in F.Stock do
		local def = Items.Defs[s.Id]
		table.insert(list, { Id = s.Id, Name = def and def.Name or s.Id, Price = s.Price, Count = s.Count or 1 })
	end
	return { Stock = list, Credits = data and data.War.Credits or 0 }
end

function Frontier.OpenMarket(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and F.InMarket(root.Position) then
		Remotes.World:FireClient(player, "Market", Frontier.Stock(player))
	end
end

-- Buy from the trader: inside the market only, paid in war credits, into the pack (overflow drops).
function Frontier.Buy(player, itemId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not F.InMarket(root.Position) then
		return false, "You are not at the market"
	end
	local entry
	for _, s in F.Stock do
		if s.Id == itemId then
			entry = s
		end
	end
	local data = PlayerData.Get(player)
	if not entry or not data then
		return false, "Not for sale"
	end
	if (data.War.Credits or 0) < entry.Price then
		return false, ("Not enough credits (%d needed)"):format(entry.Price)
	end
	data.War.Credits -= entry.Price
	Inventory.Add(player, itemId, entry.Count or 1)
	Remotes.Announce:FireClient(player, ("Bought %s for %d credits"):format(Items.Defs[itemId] and Items.Defs[itemId].Name or itemId, entry.Price), "Reward")
	Remotes.World:FireClient(player, "Market", Frontier.Stock(player))
	return true
end

local current, inMarket = {}, {}

local function tick()
	local now = os.clock()
	if spawned then
		encounterTick(now)
	end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local fd = root and dataOf(player)
		if not root or not fd then
			continue
		end
		local pos = root.Position
		-- region banners
		local regionKey = F.RegionAt(pos)
		if regionKey ~= current[player] then
			current[player] = regionKey
			local region = regionKey and F.Regions[regionKey]
			if region then
				Remotes.Announce:FireClient(player, if region.Safe then region.Name .. "  -  safe haven" else ("%s  -  danger: %s"):format(region.Name, region.Danger), "District")
				if regionKey == "Reach" and not fd.Reached then
					fd.Reached = true
					Quests.Progress(player, "explore", "Reach", 1)
				end
			end
		end
		-- the market is a safe zone
		local safe = F.InMarket(pos)
		if safe ~= (inMarket[player] or false) then
			inMarket[player] = safe
			player:SetAttribute("Safe", safe or nil)
			if not safe then
				Remotes.World:FireClient(player, "MarketClose")
			end
		end
		-- the route: reach the next checkpoint to be shown the one after
		local nextCp = F.Route[fd.Route + 1]
		if nextCp and (flat(pos) - flat(nextCp.Position)).Magnitude <= C.CheckpointReach then
			fd.Route += 1
			Remotes.Announce:FireClient(player, ("Checkpoint %d/%d: %s"):format(fd.Route, #F.Route, nextCp.Name), "District")
			routeMarker(player, fd)
		end
		-- sites are found by walking near them; found ones stay marked
		for _, site in F.Sites do
			if not fd.Found[site.Key] and (flat(pos) - flat(site.Position)).Magnitude <= C.DiscoverRadius then
				fd.Found[site.Key] = true
				Remotes.Announce:FireClient(player, ("%s  -  %s, danger: %s"):format(site.Name, site.Kind, site.Danger), "District")
				Remotes.World:FireClient(player, "Marker", "Site_" .. site.Key, site.Position + Vector3.new(0, (site.Y or 0) + 14, 0), ("%s (%s)"):format(site.Name, site.Kind), nil, SITE_COLORS[site.Kind])
			end
		end
	end
	-- containers: an emptied one comes back after a while
	for _, entry in containers do
		if not entry.part or not entry.part.Parent then
			entry.emptiedAt = entry.emptiedAt or now
			if now - entry.emptiedAt >= C.Refill then
				placeContainer(entry)
			end
		end
	end
end

-- Spawns every checkpoint's and site's guards. Once; later calls are ignored.
function Frontier.Populate()
	if spawned then
		return
	end
	spawned = true
	for _, cp in F.Route do
		if cp.Guards and #cp.Guards > 0 then
			spawnPack(cp, cp.Position, 14)
		end
	end
	for _, site in F.Sites do
		spawnPack(site, site.Ground or site.Position, 18, { Attrs = { Site = site.Key } })
	end
	-- rival crews: other conduits working the same contracts, walking between the sites
	for crew = 1, C.RivalCrews do
		local points = {}
		local order = table.clone(F.Sites)
		for i = #order, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for i = 1, math.min(3, #order) do
			table.insert(points, order[i].Position + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40)))
		end
		local start = points[1]
		spawnPack({ Guards = { { "Rival", C.RivalCrewSize } }, Scale = 1 }, start, 8, { Patrol = points, Leg = C.RivalLeg, Encounter = true, Attrs = { Crew = crew } })
	end
	local kinds = {}
	for r = 2, F.Rows - 1 do
		for c = 2, F.Cols - 1 do
			local cell = F.L.Cells[r][c]
			if cell.Encounter then
				kinds[cell.Encounter.Kind] = (kinds[cell.Encounter.Kind] or 0) + 1
			end
		end
	end
	local list = {}
	for k, n in kinds do
		table.insert(list, k .. "=" .. n)
	end
	table.sort(list)
	print("[Frontier] encounters rolled: " .. table.concat(list, " ") .. " (they wake as players come near); guards alive " .. alive)
end

function Frontier.Alive()
	return alive
end

function Frontier.Containers()
	return containers
end

function Frontier.Layout()
	return F.L
end

function Frontier.Init()
	local seed = if C.Seed and C.Seed ~= 0 then C.Seed else Random.new():NextInteger(1, 2 ^ 30)
	F.Generate(seed)
	rng = Random.new(seed)
	folder = Instance.new("Folder")
	folder.Name = "Frontier"
	folder:SetAttribute("Seed", seed)
	folder.Parent = workspace
	local t0 = os.clock()
	local chunks, voxels = writeTerrain()
	local t1 = os.clock()
	buildRoads()
	local built = buildChunks()
	local trees, rocks, dead = counts.trees, counts.rocks, counts.dead
	buildReach()
	for _, site in F.Sites do
		buildSite(site)
	end
	for i in F.Route do
		buildCheckpoint(i)
	end
	local kinds = {}
	for kind, n in built do
		table.insert(kinds, kind .. "=" .. n)
	end
	table.sort(kinds)
	print(("[Frontier] seed %d: terrain %d chunks / %d voxels in %.1fs; cells %s; %d trees, %d rocks, %d dead trees, %d sites, %d checkpoints, %d containers; Reach at (%d, %d); total %.1fs"):format(
		seed, chunks, voxels, t1 - t0, table.concat(kinds, " "), trees, rocks, dead, #F.Sites, #F.Route - 1, #containers, F.Reach.Center.X, F.Reach.Center.Z, os.clock() - t0))
	folder:SetAttribute("Built", true)

	Net.On("Buy", { rate = 4, burst = 6, args = { "string" } }, function(player, itemId)
		local ok, why = Frontier.Buy(player, itemId)
		if not ok then
			Remotes.Announce:FireClient(player, why, "Warning")
		end
	end)

	if WorldPhase.IsOpen() then
		Frontier.Populate()
	end
	WorldPhase.Changed.Event:Connect(function()
		if WorldPhase.IsOpen() then
			Frontier.Populate()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5)
			local fd = dataOf(player)
			if fd then
				routeMarker(player, fd)
				sendFound(player, fd)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		current[player], inMarket[player] = nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Frontier] tick:", err)
			end
		end
	end)
end

return Frontier
