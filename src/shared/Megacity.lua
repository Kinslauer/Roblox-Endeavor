-- The megacity beyond the old core: the industrial ring that covers the rest of the map, the few
-- green pockets left from before, the toxic sludge, the roads between them. Pure data and maths (no
-- Instances) so the server builder (server/Megacity.lua), the client's air (client/Air.lua) and the
-- map tools can all read it. The layout is fixed: the city is the same on every server.
--
-- Top-down, north = +Z. The core (server/City.lua: Transit Hub, Corp Plaza, the Sprawl, Blackout Zone,
-- the Crossroads) is the 1400-stud square around the origin. North of it the scarp drops into the
-- frontier valley (shared/Frontier.lua). Around its other three sides the industrial ring:
--
--   west band  (X -1700..-700)  THE STACKS (refinery, north)   SLAG FLATS (toxic pools, south)
--   east band  (X  700..1700)   PYLON FIELDS (power, north)    THE HAB BLOCKS (arcology, south)
--   south band (Z -1700..-700)  SCRAP SEA (west)  THE FOUNDRY (middle)  THE SUMPS (east, canals)
--
-- An artery road runs along Z = -750 and up both sides of the core; spurs reach each district.
-- A wall of dead megablocks closes the edge; past it the skyline goes on into the smog.
-- Green pockets (no hostiles settle there, clean air, wounds close slowly):
--   THE LAST GARDEN (a cracked botanical dome between the Foundry and the Sumps)
--   THE ROOTWORK (one ancient tree that broke a tower courtyard, between Scrap Sea and the Foundry)
--   FERNWELL (a spring in a hab courtyard, inside the Hab Blocks)
-- and, north of the wall, Verdant Reach (shared/Frontier.lua).
local Megacity = {}

Megacity.Top = 2 -- ground surface, same as the core
Megacity.Bounds = { X0 = -1700, X1 = 1700, Z0 = -1700, Z1 = 700 }
Megacity.CoreEdge = 700
Megacity.WallDepth = 60 -- the edge wall stands this deep inside the bounds

-- Air = the client's air profile there (Config.Megacity.Air). Types = the hostiles that settle there
-- (Population), instead of the danger tier's mix.
Megacity.Districts = {
	{ Name = "The Stacks", Style = "Stacks", Center = Vector3.new(-1200, 0, 350), Size = 700, Danger = "High", Air = "Smog",
		Color = Color3.fromRGB(74, 66, 60), Neon = Color3.fromRGB(255, 120, 30), Lockup = "Reinforced", Caches = 6 },
	{ Name = "Slag Flats", Style = "Slag", Center = Vector3.new(-1200, 0, -350), Size = 700, Danger = "High", Air = "Toxic",
		Color = Color3.fromRGB(56, 54, 50), Neon = Color3.fromRGB(190, 255, 60), Lockup = "Standard", Caches = 5,
		Types = { "Raider", "Brute", "Brute", "Shocker" } },
	{ Name = "Pylon Fields", Style = "Pylon", Center = Vector3.new(1200, 0, 350), Size = 700, Danger = "Medium", Air = "Haze",
		Color = Color3.fromRGB(64, 66, 72), Neon = Color3.fromRGB(110, 190, 255), Lockup = "Standard", Caches = 5,
		Types = { "Shocker", "Shocker", "Raider" } },
	{ Name = "The Hab Blocks", Style = "Hab", Center = Vector3.new(1200, 0, -350), Size = 700, Danger = "Medium", Air = "Haze",
		Color = Color3.fromRGB(70, 68, 76), Neon = Color3.fromRGB(255, 70, 190), Lockup = "Reinforced", Caches = 8 },
	{ Name = "Scrap Sea", Style = "Scrap", Center = Vector3.new(-1150, 0, -1200), Size = 800, Danger = "Medium", Air = "Smog",
		Color = Color3.fromRGB(84, 64, 50), Neon = Color3.fromRGB(255, 200, 60), Lockup = "Weak", Caches = 9 },
	{ Name = "The Foundry", Style = "Foundry", Center = Vector3.new(0, 0, -1200), Size = 800, Danger = "High", Air = "Smog",
		Color = Color3.fromRGB(62, 56, 54), Neon = Color3.fromRGB(255, 90, 20), Lockup = "Reinforced", Sealed = true, Caches = 6,
		Types = { "Brute", "Raider", "Raider", "Shocker" } },
	{ Name = "The Sumps", Style = "Sumps", Center = Vector3.new(1150, 0, -1200), Size = 800, Danger = "High", Air = "Toxic",
		Color = Color3.fromRGB(58, 62, 58), Neon = Color3.fromRGB(80, 255, 170), Lockup = "Standard", Caches = 6 },
}

-- The green pockets. Radius = where the air clears and wounds close; the builder dresses that circle.
Megacity.Pockets = {
	{ Name = "The Last Garden", Key = "Garden", Center = Vector3.new(575, 0, -1250), Radius = 110, Danger = "Quiet", Pocket = true },
	{ Name = "The Rootwork", Key = "Rootwork", Center = Vector3.new(-575, 0, -1050), Radius = 85, Danger = "Quiet", Pocket = true },
	{ Name = "Fernwell", Key = "Fernwell", Center = Vector3.new(1400, 0, -560), Radius = 60, Danger = "Quiet", Pocket = true },
}

-- Roads (X/Z segments, width in studs). The artery, the ring up both sides of the core, the spurs.
Megacity.Roads = {
	{ A = Vector3.new(-1600, 0, -750), B = Vector3.new(1600, 0, -750), Width = 34, Name = "Artery" },
	{ A = Vector3.new(-750, 0, 680), B = Vector3.new(-750, 0, -750), Width = 26, Name = "WestRing" },
	{ A = Vector3.new(750, 0, 680), B = Vector3.new(750, 0, -750), Width = 26, Name = "EastRing" },
	{ A = Vector3.new(-750, 0, 350), B = Vector3.new(-1150, 0, 350), Width = 20, Name = "StacksSpur" },
	{ A = Vector3.new(-750, 0, -350), B = Vector3.new(-1150, 0, -350), Width = 20, Name = "SlagSpur" },
	{ A = Vector3.new(750, 0, 350), B = Vector3.new(1150, 0, 350), Width = 20, Name = "PylonSpur" },
	{ A = Vector3.new(750, 0, -350), B = Vector3.new(1150, 0, -350), Width = 20, Name = "HabSpur" },
	{ A = Vector3.new(0, 0, -700), B = Vector3.new(0, 0, -1150), Width = 24, Name = "FoundrySpur" },
	{ A = Vector3.new(-1150, 0, -750), B = Vector3.new(-1150, 0, -1150), Width = 20, Name = "ScrapSpur" },
}

-- The Sumps: islands between canals. Canal centre lines (local to the district centre) and width;
-- the canal bed and the sludge surface sit below the street.
Megacity.Canals = { Lines = { -270, -90, 90, 270 }, Width = 24, Bed = -6, Surface = -2 }

-- ===== sludge =====
-- Every toxic surface: { Center, Radius } circles (pools) and { Center, Half } rectangles (canals),
-- with Y = the sludge surface. A body whose root is within Wade studs above it is standing in it.
Megacity.Wade = 3.5
Megacity.Sludge = {}

local function addCircle(center, radius, y)
	table.insert(Megacity.Sludge, { Center = Vector3.new(center.X, y, center.Z), Radius = radius })
end
local function addRect(center, half, y)
	table.insert(Megacity.Sludge, { Center = Vector3.new(center.X, y, center.Z), Half = half })
end

function Megacity.GetDistrict(name)
	for _, d in Megacity.Districts do
		if d.Name == name or d.Style == name then
			return d
		end
	end
	return nil
end

local function onRoadRaw(x, z, margin)
	for _, r in Megacity.Roads do
		local abx, abz = r.B.X - r.A.X, r.B.Z - r.A.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then math.clamp(((x - r.A.X) * abx + (z - r.A.Z) * abz) / len2, 0, 1) else 0
		local d = math.sqrt((x - r.A.X - abx * t) ^ 2 + (z - r.A.Z - abz * t) ^ 2)
		if d < r.Width / 2 + (margin or 0) then
			return true
		end
	end
	return false
end
Megacity.OnRoad = onRoadRaw

do
	-- Slag Flats: pools rolled once from a fixed seed, clear of the plaza and the spur
	local slag = Megacity.GetDistrict("Slag")
	local rng = Random.new(41)
	local tries = 0
	local pools = 0
	while pools < 10 and tries < 200 do
		tries += 1
		local x = slag.Center.X + rng:NextNumber(-300, 300)
		local z = slag.Center.Z + rng:NextNumber(-300, 300)
		local r = rng:NextNumber(18, 42)
		local ok = (Vector3.new(x, 0, z) - slag.Center).Magnitude > 80 + r and not onRoadRaw(x, z, r + 6)
		for _, s in Megacity.Sludge do
			if ok and (Vector3.new(x, 0, z) - Vector3.new(s.Center.X, 0, s.Center.Z)).Magnitude < s.Radius + r + 30 then
				ok = false
			end
		end
		if ok then
			addCircle(Vector3.new(x, 0, z), r, Megacity.Top + 0.15)
			pools += 1
		end
	end
	-- the Sumps: the canals
	local sumps = Megacity.GetDistrict("Sumps")
	local C = Megacity.Canals
	local half = sumps.Size / 2
	for _, off in C.Lines do
		addRect(sumps.Center + Vector3.new(off, 0, 0), Vector3.new(C.Width / 2, 0, half), C.Surface)
		addRect(sumps.Center + Vector3.new(0, 0, off), Vector3.new(half, 0, C.Width / 2), C.Surface)
	end
end

-- ===== queries =====
function Megacity.InCity(x, z)
	local B = Megacity.Bounds
	return x >= B.X0 and x <= B.X1 and z >= B.Z0 and z <= B.Z1
end

function Megacity.InCore(x, z)
	return math.abs(x) <= Megacity.CoreEdge and math.abs(z) <= Megacity.CoreEdge
end

-- The green pocket at a position, or nil.
function Megacity.PocketAt(position)
	for _, p in Megacity.Pockets do
		local dx, dz = position.X - p.Center.X, position.Z - p.Center.Z
		if dx * dx + dz * dz <= p.Radius * p.Radius then
			return p
		end
	end
	return nil
end

-- The outer district at a position, or nil (the core and the gaps between districts).
function Megacity.DistrictAt(position)
	for _, d in Megacity.Districts do
		if math.abs(position.X - d.Center.X) <= d.Size / 2 and math.abs(position.Z - d.Center.Z) <= d.Size / 2 then
			return d
		end
	end
	return nil
end

-- True when a body whose root is at `position` is standing in sludge.
function Megacity.InSludge(position)
	for _, s in Megacity.Sludge do
		local dy = position.Y - s.Center.Y
		if dy > -12 and dy < Megacity.Wade then
			local dx, dz = position.X - s.Center.X, position.Z - s.Center.Z
			if s.Radius then
				if dx * dx + dz * dz <= s.Radius * s.Radius then
					return true
				end
			elseif math.abs(dx) <= s.Half.X and math.abs(dz) <= s.Half.Z then
				return true
			end
		end
	end
	return false
end

-- The air profile name at a position (Config.Megacity.Air): a pocket's "Clean", a district's own,
-- "Ash" in the frontier wastes, "City" in the core and the gaps.
function Megacity.AirAt(position, frontierRegion)
	if position.Y < -150 then
		return "Under" -- the barrens under the city (server/Barrens.lua)
	end
	if Megacity.PocketAt(position) then
		return "Clean"
	end
	local d = Megacity.DistrictAt(position)
	if d then
		return d.Air
	end
	if position.Z > Megacity.Bounds.Z1 then
		if frontierRegion == "Reach" then
			return "Clean"
		end
		return "Ash"
	end
	return "City"
end

return Megacity
