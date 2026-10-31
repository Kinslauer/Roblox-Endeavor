-- The world beyond the city: a grid of prebuilt CHUNKS assembled by a seed each server, plus the
-- ground height, the route north and what waits along it. Pure data and maths (no Instances) so the
-- server builder (server/Frontier.lua) and tools can read it; call Frontier.Generate(seed) first.
--
-- The map is four quadrants. The city (server/City.lua) fills the two southern ones: a 1400x1400
-- plateau at Y = 2 around the origin, "north" = +Z. The two northern quadrants are the frontier, a
-- 9 x 8 grid of 200-stud cells (X -900..900, Z 700..2300):
--   * row 1 is the SCARP: the city's northern limit, an overlook at the top of a cliff; a switchback
--     road zigzags down its face into the valley (its hairpins are rolled)
--   * the border cells are PEAKS: the mountain range that closes the valley
--   * everything inside is the VALLEY, 70 studs below the city, one chunk template per cell (forest,
--     glade, boulders, ruin, marsh, crater, meadow), rotated at random
--   * VERDANT REACH lands in one of the interior cells (rarely the same one twice): a round green
--     terrace, the only safe ground north of the wall - a market with a trader
--   * the seven SITES (encampments, stockpiles, relic sites) take cells of their own, the relic sites
--     at the foot of the peaks
-- The route is rolled too: a winding walk across the grid from the scarp foot to the Reach gate, with
-- a held checkpoint every other cell. Nothing north of the wall is ever a straight road.
local Frontier = {}

Frontier.CityEdge = 700 -- the city ground runs to |x|, |z| <= 700
Frontier.CityTop = 2 -- the city plateau's surface
Frontier.Floor = -70 -- the valley floor
Frontier.Bounds = { X0 = -1000, X1 = 1000, Z0 = -1000, Z1 = 2350 } -- terrain extent (studs)
Frontier.Cell = 200
Frontier.Cols, Frontier.Rows = 9, 8
Frontier.GridX0, Frontier.GridZ0 = -900, 700

-- The trader's stock, paid in war credits (profile.War.Credits: the Front's pay).
Frontier.Stock = {
	{ Id = "Medkit", Price = 30 },
	{ Id = "Ration", Price = 12 },
	{ Id = "ArcCell", Price = 3, Count = 5 },
	{ Id = "PipeGrenade", Price = 45 },
	{ Id = "BreachingCharge", Price = 120 },
	{ Id = "Rucksack", Price = 260 },
	{ Id = "FramePack", Price = 700 },
	{ Id = "ArcPistol", Price = 420 },
	{ Id = "PlatedHelm", Price = 300 },
	{ Id = "ServoGreaves", Price = 340 },
	{ Id = "ReflexOptic", Price = 500 },
	{ Id = "AudioPickup", Price = 380 },
}

-- The overlook at the city's north limit (the top of the scarp).
Frontier.Scarp = { Name = "The Scarp", Overlook = Vector3.new(120, Frontier.CityTop, 745), Danger = "High" }

-- The city's own checkpoints: fixed, the city is the same every server.
local CITY_ROUTE = {
	{ Key = "RailYard", Name = "Rail Yard", Position = Vector3.new(-230, 2, -250), Guards = { { "Raider", 3 } }, Barricade = { "FencePanel", "Crate", "Barrel" } },
	{ Key = "SprawlMarket", Name = "Sprawl Market", Position = Vector3.new(-430, 2, -80), Guards = { { "Raider", 2 }, { "Shocker", 1 } }, Barricade = { "CarWreck", "FencePanel" } },
	{ Key = "CanalBridge", Name = "Canal Bridge", Position = Vector3.new(-250, 2, 250), Guards = { { "Brute", 1 }, { "Raider", 2 } }, Barricade = { "Slab", "CarWreck", "FencePanel" } },
	{ Key = "BlackoutToll", Name = "Blackout Toll", Position = Vector3.new(0, 2, 300), Guards = { { "Shocker", 2 }, { "Brute", 1 } }, Scale = 1.15, Barricade = { "FencePanel", "FencePanel", "Barrel" } },
	{ Key = "NorthGate", Name = "North Gate", Position = Vector3.new(120, 2, 650), Guards = { { "Brute", 2 }, { "Shocker", 2 } }, Scale = 1.15, Barricade = { "CarWreck", "CarWreck", "Slab" } },
	{ Key = "ScarpOverlook", Name = "Scarp Overlook", Position = Vector3.new(120, 2, 745), Guards = { { "Warden", 1 }, { "Raider", 2 } }, Scale = 0.8, Boss = "Gatekeeper" },
}

-- Valley checkpoint flavours, dealt along the rolled trail in order.
local TRAIL_STOPS = {
	{ Name = "Valley Ford", Guards = { { "Shocker", 3 } }, Scale = 1.25 },
	{ Name = "Fallen Bridge", Guards = { { "Raider", 3 }, { "Brute", 1 } }, Scale = 1.25 },
	{ Name = "Dead Crossing", Guards = { { "Shocker", 2 }, { "Raider", 2 } }, Scale = 1.3 },
	{ Name = "Burnt Clearing", Guards = { { "Brute", 2 } }, Scale = 1.3 },
	{ Name = "Stone Steps", Guards = { { "Shocker", 2 }, { "Brute", 1 } }, Scale = 1.35 },
}

-- Sites. Kind: Encampment (raiders living there, a stockpile crate), Stockpile (a locked store: fewer
-- guards, better goods), Relic (the only source of some gear, held by the worst of them; placed at the
-- foot of the peaks). Stock = { { table, rolls } ... }, Fixed = guaranteed items. Chunk = the cell
-- template that carries it.
local SITE_DEFS = {
	{ Key = "RidgeWatch", Name = "Ridge Watch", Kind = "Encampment", Chunk = "Camp", Danger = "High",
		Guards = { { "Raider", 4 }, { "Shocker", 1 } }, Scale = 1.2, Stock = { { "Supply", 2 } }, Fixed = { Medkit = 1 } },
	{ Key = "LoggingCamp", Name = "Logging Camp", Kind = "Encampment", Chunk = "Logging", Danger = "High",
		Guards = { { "Raider", 5 } }, Scale = 1.2, Stock = { { "Supply", 2 }, { "Crate", 3 } }, Fixed = { Scrap = 6 } },
	{ Key = "HuntersShack", Name = "Hunter's Shack", Kind = "Stockpile", Chunk = "Shack", Danger = "Medium",
		Guards = { { "Raider", 2 } }, Scale = 1.1, Stock = { { "Supply", 1 } }, Fixed = { Medkit = 2, Ration = 3 } },
	{ Key = "PumpStation", Name = "Pump Station", Kind = "Stockpile", Chunk = "Pump", Danger = "High",
		Guards = { { "Brute", 1 }, { "Raider", 2 } }, Scale = 1.25, Stock = { { "Vault", 1 }, { "Supply", 1 } }, Fixed = { Battery = 3 } },
	{ Key = "SignalMast", Name = "Signal Mast", Kind = "Relic", Chunk = "Mast", Danger = "Severe", Foot = true,
		Guards = { { "Shocker", 3 }, { "Raider", 2 } }, Scale = 1.35, Stock = { { "Relic", 1 }, { "Vault", 1 } }, Fixed = { EchoArray = 1 } },
	{ Key = "Dropship", Name = "Crashed Dropship", Kind = "Relic", Chunk = "Dropship", Danger = "Severe", Foot = true,
		Guards = { { "Warden", 1 }, { "Shocker", 2 } }, Scale = 1.0, Boss = "Pilot", Stock = { { "Relic", 1 }, { "Vault", 1 } }, Fixed = { ConduitHarness = 1 } },
	{ Key = "OldMine", Name = "Old Mine", Kind = "Relic", Chunk = "Mine", Danger = "Severe", Foot = true,
		Guards = { { "Brute", 2 }, { "Shocker", 2 }, { "Raider", 2 } }, Scale = 1.3, Stock = { { "Relic", 1 }, { "Vault", 2 } }, Fixed = { OverclockCore = 1 } },
}

-- Valley chunk templates and how often they are dealt (server/Frontier.lua builds each).
local VALLEY_CHUNKS = { "Forest", "Forest", "Forest", "Forest", "Glade", "Glade", "Boulders", "Ruin", "Marsh", "Crater" }

Frontier.Regions = {
	Reach = { Name = "Verdant Reach", Danger = "Safe", Safe = true },
	Scarp = { Name = "The Scarp", Danger = "High" },
	Valley = { Name = "The Valley", Danger = "High" },
	Ridge = { Name = "The Ridge", Danger = "Severe" },
}

-- ===== helpers =====
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function nearestOnPolyline(points, x, z)
	local bestD, bestY = math.huge, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / len2, 0, 1) else 0
		local px, pz = a.X + abx * t, a.Z + abz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < bestD then
			bestD, bestY = d, a.Y + (b.Y - a.Y) * t
		end
	end
	return bestD, bestY
end
Frontier.NearestOnPolyline = nearestOnPolyline

function Frontier.CellCenter(col, row)
	return Vector3.new(Frontier.GridX0 + (col - 0.5) * Frontier.Cell, 0, Frontier.GridZ0 + (row - 0.5) * Frontier.Cell)
end

function Frontier.CellAt(x, z)
	local col = math.floor((x - Frontier.GridX0) / Frontier.Cell) + 1
	local row = math.floor((z - Frontier.GridZ0) / Frontier.Cell) + 1
	if col < 1 or col > Frontier.Cols or row < 1 or row > Frontier.Rows then
		return nil
	end
	return Frontier.L and Frontier.L.Cells[row][col]
end

-- ===== the layout =====
local L -- the current layout (Frontier.L)

-- Rolls a layout from a seed: the cell grid, the Reach, the sites, the switchbacks, the trail and the
-- route. Deterministic for a seed, so a server can announce its seed and anyone can redraw its map.
function Frontier.Generate(seed)
	local rng = Random.new(seed)
	L = { Seed = seed, Cells = {}, Sites = {}, Route = {} }
	Frontier.L = L
	local cols, rows = Frontier.Cols, Frontier.Rows
	for r = 1, rows do
		L.Cells[r] = {}
		for c = 1, cols do
			local zone = if r == 1 then "Scarp" elseif r == rows or c == 1 or c == cols then "Peaks" else "Valley"
			L.Cells[r][c] = { Row = r, Col = c, Center = Frontier.CellCenter(c, r), Zone = zone, Type = zone, Rot = rng:NextInteger(0, 3) * math.pi / 2 }
		end
	end
	-- the Reach: an interior cell with valley cells all around it (rows 3..6, cols 3..7)
	local rr, rc = rng:NextInteger(4, rows - 2), rng:NextInteger(3, cols - 2)
	local reachCell = L.Cells[rr][rc]
	reachCell.Type = "Reach"
	local center = reachCell.Center + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
	L.Reach = { Name = "Verdant Reach", Center = Vector3.new(center.X, Frontier.Floor, center.Z), Radius = 180, Market = 55, Danger = "Safe", Cell = reachCell }
	for dr = -1, 1 do
		for dc = -1, 1 do
			local cell = L.Cells[rr + dr][rc + dc]
			if cell.Type == "Valley" then
				cell.Type = "Meadow"
			end
		end
	end
	-- the sites: each takes a free valley cell; relic sites at the foot of the peaks; keep them apart
	local function free(cell)
		return cell.Type == "Valley"
	end
	local function footOfPeaks(cell)
		return cell.Row == rows - 1 or cell.Col == 2 or cell.Col == cols - 1
	end
	local function farFromSites(cell)
		for _, s in L.Sites do
			if math.abs(s.Cell.Row - cell.Row) + math.abs(s.Cell.Col - cell.Col) < 2 then
				return false
			end
		end
		return true
	end
	for _, def in SITE_DEFS do
		local site = table.clone(def)
		local candidates = {}
		for r = 2, rows - 1 do
			for c = 2, cols - 1 do
				local cell = L.Cells[r][c]
				if free(cell) and farFromSites(cell) and (not def.Foot or footOfPeaks(cell)) then
					table.insert(candidates, cell)
				end
			end
		end
		if #candidates == 0 then
			for r = 2, rows - 1 do
				for c = 2, cols - 1 do
					if free(L.Cells[r][c]) then
						table.insert(candidates, L.Cells[r][c])
					end
				end
			end
		end
		local cell = candidates[rng:NextInteger(1, #candidates)]
		cell.Type = def.Chunk
		cell.Site = site
		site.Cell = cell
		site.Rot = cell.Rot
		site.Position = cell.Center + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
		table.insert(L.Sites, site)
	end
	-- every other valley cell gets a template
	for r = 2, rows - 1 do
		for c = 2, cols - 1 do
			local cell = L.Cells[r][c]
			if cell.Type == "Valley" then
				cell.Type = VALLEY_CHUNKS[rng:NextInteger(1, #VALLEY_CHUNKS)]
			end
		end
	end
	-- the switchbacks: from the North Gate down the face, three rolled hairpins, to a rolled foot
	local footX = rng:NextNumber(-260, 260)
	L.Switchbacks = {
		Vector3.new(120, 2, 772),
		Vector3.new(rng:NextNumber(240, 380), -12, 802),
		Vector3.new(rng:NextNumber(-340, -200), -34, 838),
		Vector3.new(rng:NextNumber(200, 360), -56, 874),
		Vector3.new(footX, Frontier.Floor, 912),
	}
	-- the trail: a winding walk across the grid from the foot cell to the Reach's edge
	local footCol = math.clamp(math.floor((footX - Frontier.GridX0) / Frontier.Cell) + 1, 2, cols - 1)
	local path = { L.Cells[2][footCol] }
	local visited = { [L.Cells[2][footCol]] = true }
	local cur = path[1]
	local steps, laterals = 0, 0
	while steps < 40 do
		steps += 1
		local dr, dc = rr - cur.Row, rc - cur.Col
		if math.abs(dr) + math.abs(dc) <= 1 then
			break -- next to the Reach
		end
		local options, closerSet = {}, {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nr, nc = cur.Row + d[1], cur.Col + d[2]
			if nr >= 2 and nr <= rows - 1 and nc >= 2 and nc <= cols - 1 then
				local cell = L.Cells[nr][nc]
				if not visited[cell] and cell.Type ~= "Reach" then
					local closer = (math.abs(rr - nr) + math.abs(rc - nc)) < (math.abs(dr) + math.abs(dc))
					closerSet[cell] = closer
					-- the walk is at least six cells and bends at least twice: it detours while it is still short
					-- or straight, then heads for the Reach
					local detour = steps <= 6 - (math.abs(dr) + math.abs(dc)) or laterals < 2
					for _ = 1, if closer then (if detour then 1 else 4) elseif detour then 4 elseif steps <= 5 then 1 else 0 do
						table.insert(options, cell)
					end
				end
			end
		end
		if #options == 0 then
			break
		end
		cur = options[rng:NextInteger(1, #options)]
		if not closerSet[cur] then
			laterals += 1
		end
		visited[cur] = true
		table.insert(path, cur)
	end
	L.Path = path
	-- the gate: where the trail meets the hedge, facing the last cell
	local last = path[#path].Center
	local toCenter = Vector3.new(L.Reach.Center.X - last.X, 0, L.Reach.Center.Z - last.Z)
	local dirIn = if toCenter.Magnitude > 0 then toCenter.Unit else Vector3.new(0, 0, 1)
	L.Reach.GateAngle = math.atan2(-dirIn.X, -dirIn.Z) -- angle (from north, clockwise) of the gate on the ring
	local gate = L.Reach.Center - dirIn * L.Reach.Radius
	L.Reach.Gate = Vector3.new(gate.X, Frontier.Floor, gate.Z)
	local trail = { Vector3.new(footX, 0, 912) }
	for i, cell in path do
		local j = if i == 1 then Vector3.new((footX - cell.Center.X) * 0.5, 0, 0) else Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50))
		table.insert(trail, Vector3.new(cell.Center.X + j.X, 0, cell.Center.Z + j.Z))
	end
	table.insert(trail, Vector3.new(L.Reach.Gate.X, 0, L.Reach.Gate.Z))
	L.Trail = trail
	for _, cell in path do
		cell.Trail = true
	end
	-- the route: the city's fixed checkpoints, then the rolled ones
	for _, cp in CITY_ROUTE do
		table.insert(L.Route, table.clone(cp))
	end
	local hp = L.Switchbacks[3]
	table.insert(L.Route, { Key = "Hairpin", Name = "Second Hairpin", Position = hp + Vector3.new(30, 0, 0), Guards = { { "Raider", 3 }, { "Shocker", 1 } }, Scale = 1.2 })
	table.insert(L.Route, { Key = "ScarpFoot", Name = "Scarp Foot", Position = Vector3.new(footX, Frontier.Floor, 912), Guards = { { "Brute", 1 }, { "Shocker", 2 } }, Scale = 1.2 })
	local stop = 0
	for i = 3, #trail - 1, 3 do
		stop += 1
		local def = TRAIL_STOPS[((stop - 1) % #TRAIL_STOPS) + 1]
		table.insert(L.Route, { Key = "Stop" .. stop, Name = def.Name, Position = Vector3.new(trail[i].X, Frontier.Floor, trail[i].Z), Guards = def.Guards, Scale = def.Scale })
	end
	table.insert(L.Route, { Key = "ReachGate", Name = "Reach Gate", Position = L.Reach.Gate - dirIn * 12, Guards = { { "Raider", 3 }, { "Brute", 1 } }, Scale = 1.3 })
	table.insert(L.Route, { Key = "Reach", Name = "Verdant Reach", Position = L.Reach.Center, Guards = {} })
	Frontier.Route, Frontier.Sites, Frontier.Reach, Frontier.Switchbacks, Frontier.Trail = L.Route, L.Sites, L.Reach, L.Switchbacks, L.Trail
	return L
end

-- ===== the ground =====
-- Raw ground (before flattening): the valley bowl, the peaks at the border, the scarp, the hills
-- that close the city's other three sides, and what each chunk does to its cell.
local function raw(x, z)
	local floor = Frontier.Floor + 6 * math.noise(x / 110, z / 110, L.Seed % 97 + 1.1) + 2 * math.noise(x / 30, z / 30, 2.2)
	-- the peaks: the border cells rise to a range; the first valley cells are its foot
	local e = math.min(x - (Frontier.GridX0 - 100), (Frontier.GridX0 + Frontier.Cols * Frontier.Cell + 100) - x, (Frontier.GridZ0 + Frontier.Rows * Frontier.Cell + 50) - z)
	local mountain = 360 * smooth((300 - e) / 300)
	local mdetail = (mountain / 360) * 50 * math.noise(x / 70, z / 70, 7.3)
	local h = floor + mountain + mdetail
	-- chunk modifiers
	local cell = Frontier.CellAt(x, z)
	if cell then
		local d = (Vector3.new(x, 0, z) - cell.Center).Magnitude
		if cell.Type == "Crater" then
			h -= 26 * (1 - smooth((d - 30) / 60))
		elseif cell.Type == "Marsh" then
			h -= 7 * (1 - smooth((d - 50) / 50))
		elseif cell.Type == "Boulders" then
			h += 10 * math.noise(x / 22, z / 22, 4.4) * (1 - smooth((d - 60) / 50))
		end
	end
	-- the scarp: the plateau's north face, from Y = 2 at z 770 to the floor by z 900
	if z < 900 and math.abs(x) <= 720 then
		local plateau = Frontier.CityTop + (Frontier.Floor - Frontier.CityTop) * smooth((z - 770) / 130)
		h = math.max(h, plateau)
	end
	-- outside the city to the south, east and west: wreckage hills rising to mountains
	if z < 770 then
		local out = math.max(math.abs(x) - 700, -z - 700, 0)
		if out > 0 then
			h = math.max(h, Frontier.CityTop + 180 * smooth(out / 240) + 8 * math.noise(x / 60, z / 60, 3.3))
		end
	end
	return h
end

-- Ground height at a world X/Z, with the road, the Reach and the sites flattened in.
function Frontier.Height(x, z)
	local h = raw(x, z)
	local R = L.Reach
	local dr = math.sqrt((x - R.Center.X) ^ 2 + (z - R.Center.Z) ^ 2)
	if dr < R.Radius + 60 then
		h = h + (Frontier.Floor - h) * (1 - smooth((dr - R.Radius) / 60))
	end
	local dsw, ysw = nearestOnPolyline(L.Switchbacks, x, z)
	if dsw < 18 then
		h = h + (ysw - h) * (1 - smooth((dsw - 7) / 11))
	end
	for _, site in L.Sites do
		local ds = math.sqrt((x - site.Position.X) ^ 2 + (z - site.Position.Z) ^ 2)
		if ds < 44 then
			if not site.Y then
				site.Y = raw(site.Position.X, site.Position.Z)
			end
			h = h + (site.Y - h) * (1 - smooth((ds - 26) / 18))
		end
	end
	return h
end

function Frontier.InCity(x, z)
	return math.abs(x) <= Frontier.CityEdge and math.abs(z) <= Frontier.CityEdge
end

-- Where a position is: "Reach", "Scarp", "Valley", "Ridge" or nil for the city.
function Frontier.RegionAt(position)
	local x, z = position.X, position.Z
	if z <= Frontier.CityEdge then
		return nil
	end
	local R = L.Reach
	if math.sqrt((x - R.Center.X) ^ 2 + (z - R.Center.Z) ^ 2) <= R.Radius then
		return "Reach"
	end
	if z < 930 and math.abs(x) <= 720 then
		return "Scarp"
	end
	local cell = Frontier.CellAt(x, z)
	if not cell or cell.Zone == "Peaks" or (cell.Site and cell.Site.Kind == "Relic") then
		return "Ridge"
	end
	return "Valley"
end

function Frontier.InMarket(position)
	local R = L.Reach
	return math.sqrt((position.X - R.Center.X) ^ 2 + (position.Z - R.Center.Z) ^ 2) <= R.Market
end

function Frontier.Site(key)
	for _, site in L.Sites do
		if site.Key == key then
			return site
		end
	end
	return nil
end

return Frontier
