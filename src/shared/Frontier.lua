-- The world beyond the city: its shape, the way north and what waits along it. Pure data and maths
-- (no Instances) so both the server builder (server/Frontier.lua) and the client can read it.
--
-- The map is four quadrants. The city (server/City.lua) fills the two southern ones: a 1400x1400
-- plateau at Y = 2 around the origin, "north" = +Z. The two northern quadrants are the frontier:
--   * the SCARP: the city's northern limit, an overlook at the top of a cliff; a switchback road
--     zigzags down its face into the valley
--   * the VALLEY: a forest bowl 70 studs below the city, with a winding trail to the Reach
--   * VERDANT REACH: a round green terrace at the centre of the valley, high on the map's axis, the
--     only safe ground north of the wall - a market with a trader who sells for war credits
--   * the RIDGE: the mountain range and forest ringing the valley, where the encampments, stockpiles
--     and relic sites are: raid targets with real guards and the only places some gear is found
-- Nothing north of the wall is a straight road. The route winds through the city first (checkpoints
-- held by hostiles of rising tier), then the switchbacks, then the trail.
local Frontier = {}

Frontier.CityEdge = 700 -- the city ground runs to |x|, |z| <= 700
Frontier.CityTop = 2 -- the city plateau's surface
Frontier.Floor = -70 -- the valley floor
Frontier.Bounds = { X0 = -1000, X1 = 1000, Z0 = -1000, Z1 = 2350 } -- terrain extent (studs)

Frontier.Reach = {
	Name = "Verdant Reach",
	Center = Vector3.new(0, Frontier.Floor, 1550),
	Radius = 180, -- the flat terrace
	Market = 55, -- the covered market at its heart: a safe zone
	Danger = "Safe",
	-- the trader's stock, paid in war credits (profile.War.Credits: the Front's pay)
	Stock = {
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
	},
}

-- The overlook at the city's north limit (the top of the scarp).
Frontier.Scarp = { Name = "The Scarp", Overlook = Vector3.new(120, Frontier.CityTop, 745), Danger = "High" }

-- The switchback road down the scarp face: X, Y, Z. The terrain is flattened to it.
Frontier.Switchbacks = {
	Vector3.new(120, 2, 772),
	Vector3.new(340, -12, 802),
	Vector3.new(-260, -34, 838),
	Vector3.new(300, -56, 874),
	Vector3.new(0, -70, 912),
}

-- The valley trail from the foot of the scarp to the Reach's south gate (Y follows the ground).
Frontier.Trail = {
	Vector3.new(0, 0, 912),
	Vector3.new(-120, 0, 1000),
	Vector3.new(60, 0, 1090),
	Vector3.new(-80, 0, 1200),
	Vector3.new(90, 0, 1290),
	Vector3.new(0, 0, 1372),
}

-- The route north, in order. Each checkpoint is held; the next one is marked for you once you
-- stand at the previous. Guards = { Type, Count }, Scale = health/damage multiplier.
Frontier.Route = {
	{ Key = "RailYard", Name = "Rail Yard", Position = Vector3.new(-230, 2, -250), Guards = { { "Raider", 3 } }, Barricade = { "FencePanel", "Crate", "Barrel" } },
	{ Key = "SprawlMarket", Name = "Sprawl Market", Position = Vector3.new(-430, 2, -80), Guards = { { "Raider", 2 }, { "Shocker", 1 } }, Barricade = { "CarWreck", "FencePanel" } },
	{ Key = "CanalBridge", Name = "Canal Bridge", Position = Vector3.new(-250, 2, 250), Guards = { { "Brute", 1 }, { "Raider", 2 } }, Barricade = { "Slab", "CarWreck", "FencePanel" } },
	{ Key = "BlackoutToll", Name = "Blackout Toll", Position = Vector3.new(0, 2, 300), Guards = { { "Shocker", 2 }, { "Brute", 1 } }, Scale = 1.15, Barricade = { "FencePanel", "FencePanel", "Barrel" } },
	{ Key = "NorthGate", Name = "North Gate", Position = Vector3.new(120, 2, 650), Guards = { { "Brute", 2 }, { "Shocker", 2 } }, Scale = 1.15, Barricade = { "CarWreck", "CarWreck", "Slab" } },
	{ Key = "ScarpOverlook", Name = "Scarp Overlook", Position = Vector3.new(120, 2, 745), Guards = { { "Warden", 1 }, { "Raider", 2 } }, Scale = 0.8, Boss = "Gatekeeper" },
	{ Key = "Hairpin", Name = "Second Hairpin", Position = Vector3.new(-230, -34, 838), Guards = { { "Raider", 3 }, { "Shocker", 1 } }, Scale = 1.2 },
	{ Key = "ScarpFoot", Name = "Scarp Foot", Position = Vector3.new(0, -70, 912), Guards = { { "Brute", 1 }, { "Shocker", 2 } }, Scale = 1.2 },
	{ Key = "ValleyFord", Name = "Valley Ford", Position = Vector3.new(60, -70, 1090), Guards = { { "Shocker", 3 } }, Scale = 1.25 },
	{ Key = "ReachGate", Name = "Reach Gate", Position = Vector3.new(0, -70, 1372), Guards = { { "Raider", 3 }, { "Brute", 1 } }, Scale = 1.3 },
	{ Key = "Reach", Name = "Verdant Reach", Position = Vector3.new(0, -70, 1550), Guards = {} },
}

-- Sites in the ring around the valley. Kind: Encampment (raiders living there, a stockpile crate),
-- Stockpile (a locked store: fewer guards, better goods), Relic (the only source of some gear, held
-- by the worst of them). Stock = { { table, rolls } ... }, Fixed = guaranteed items.
-- Positions are polar around the Reach's centre: Angle (degrees clockwise from north), Distance.
Frontier.Sites = {
	{ Key = "RidgeWatch", Name = "Ridge Watch", Kind = "Encampment", Angle = 50, Distance = 430, Danger = "High",
		Guards = { { "Raider", 4 }, { "Shocker", 1 } }, Scale = 1.2, Stock = { { "Supply", 2 } }, Fixed = { Medkit = 1 } },
	{ Key = "LoggingCamp", Name = "Logging Camp", Kind = "Encampment", Angle = -140, Distance = 400, Danger = "High",
		Guards = { { "Raider", 5 } }, Scale = 1.2, Stock = { { "Supply", 2 }, { "Crate", 3 } }, Fixed = { Scrap = 6 } },
	{ Key = "HuntersShack", Name = "Hunter's Shack", Kind = "Stockpile", Angle = 140, Distance = 380, Danger = "Medium",
		Guards = { { "Raider", 2 } }, Scale = 1.1, Stock = { { "Supply", 1 } }, Fixed = { Medkit = 2, Ration = 3 } },
	{ Key = "PumpStation", Name = "Pump Station", Kind = "Stockpile", Angle = -95, Distance = 400, Danger = "High",
		Guards = { { "Brute", 1 }, { "Raider", 2 } }, Scale = 1.25, Stock = { { "Vault", 1 }, { "Supply", 1 } }, Fixed = { Battery = 3 } },
	{ Key = "SignalMast", Name = "Signal Mast", Kind = "Relic", Angle = -45, Distance = 560, Danger = "Severe",
		Guards = { { "Shocker", 3 }, { "Raider", 2 } }, Scale = 1.35, Stock = { { "Relic", 1 }, { "Vault", 1 } }, Fixed = { EchoArray = 1 } },
	{ Key = "Dropship", Name = "Crashed Dropship", Kind = "Relic", Angle = 100, Distance = 430, Danger = "Severe",
		Guards = { { "Warden", 1 }, { "Shocker", 2 } }, Scale = 1.0, Boss = "Pilot", Stock = { { "Relic", 1 }, { "Vault", 1 } }, Fixed = { ConduitHarness = 1 } },
	{ Key = "OldMine", Name = "Old Mine", Kind = "Relic", Angle = 0, Distance = 520, Danger = "Severe",
		Guards = { { "Brute", 2 }, { "Shocker", 2 }, { "Raider", 2 } }, Scale = 1.3, Stock = { { "Relic", 1 }, { "Vault", 2 } }, Fixed = { OverclockCore = 1 } },
}

for _, site in Frontier.Sites do
	local a = math.rad(site.Angle)
	site.Position = Vector3.new(Frontier.Reach.Center.X + math.sin(a) * site.Distance, 0, Frontier.Reach.Center.Z + math.cos(a) * site.Distance)
end

-- ===== the ground =====
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Height of a polyline (X/Z) at the nearest point, with the distance to it.
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

-- Raw ground (before flattening): the valley bowl, the ring of mountains, the scarp, the hills
-- that close the city's other three sides.
local function raw(x, z)
	local R = Frontier.Reach
	local dx, dz = x - R.Center.X, z - R.Center.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local ang = math.deg(math.atan2(dx, dz)) -- 0 = north of the Reach
	-- the ring: full for |ang| < 125, gone by 155 (the south stays open toward the scarp)
	local gap = 1 - smooth((math.abs(ang) - 125) / 30)
	local mountain = (260 * smooth((d - 330) / 330) + 140 * smooth((d - 640) / 320)) * gap
	local mdetail = (mountain / 260) * 45 * math.noise(x / 70, z / 70, 7.3)
	-- the valley walls east and west, and the far north
	local border = 220 * smooth((math.abs(x) - 640) / 180) + 220 * smooth((z - 2080) / 200)
	local floor = Frontier.Floor + 6 * math.noise(x / 110, z / 110, 1.1) + 2 * math.noise(x / 30, z / 30, 2.2)
	local h = floor + math.max(mountain + mdetail, border)
	-- the scarp: the plateau's north face, from Y = 2 at z 770 to the floor by z 900
	if z < 900 and math.abs(x) <= 720 then
		local plateau = Frontier.CityTop + (Frontier.Floor - Frontier.CityTop) * smooth((z - 770) / 130)
		h = math.max(h, plateau)
	end
	-- outside the city to the south, east and west: wreckage hills rising to mountains
	if z < 770 then
		local out = math.max(math.abs(x) - 700, -z - 700, 0)
		local hills = Frontier.CityTop + 180 * smooth(out / 240) + (out > 0 and 8 * math.noise(x / 60, z / 60, 3.3) or 0)
		if out > 0 then
			h = math.max(h, hills)
		end
	end
	return h
end

-- Ground height at a world X/Z, with the road, the trail, the Reach and the sites flattened in.
function Frontier.Height(x, z)
	local h = raw(x, z)
	-- the Reach terrace
	local R = Frontier.Reach
	local dr = math.sqrt((x - R.Center.X) ^ 2 + (z - R.Center.Z) ^ 2)
	if dr < R.Radius + 60 then
		h = h + (Frontier.Floor - h) * (1 - smooth((dr - R.Radius) / 60))
	end
	-- the switchbacks carry their own heights; the trail hugs the ground but smooths it
	local dsw, ysw = nearestOnPolyline(Frontier.Switchbacks, x, z)
	if dsw < 18 then
		h = h + (ysw - h) * (1 - smooth((dsw - 7) / 11))
	end
	-- the sites: a flat disc each
	for _, site in Frontier.Sites do
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

-- Is this X/Z under the city plateau (the City's own ground part covers it)?
function Frontier.InCity(x, z)
	return math.abs(x) <= Frontier.CityEdge and math.abs(z) <= Frontier.CityEdge
end

-- Where a position is: a region table { Name, Danger, Safe? } or nil for the city.
Frontier.Regions = {
	Reach = { Name = "Verdant Reach", Danger = "Safe", Safe = true },
	Scarp = { Name = "The Scarp", Danger = "High" },
	Valley = { Name = "The Valley", Danger = "High" },
	Ridge = { Name = "The Ridge", Danger = "Severe" },
}
function Frontier.RegionAt(position)
	local x, z = position.X, position.Z
	if z <= Frontier.CityEdge then
		return nil
	end
	local R = Frontier.Reach
	local dr = math.sqrt((x - R.Center.X) ^ 2 + (z - R.Center.Z) ^ 2)
	if dr <= R.Radius then
		return "Reach"
	end
	if z < 930 and math.abs(x) <= 720 then
		return "Scarp"
	end
	if dr <= 420 or (z < 1250 and math.abs(x) <= 520) then
		return "Valley"
	end
	return "Ridge"
end

function Frontier.InMarket(position)
	local R = Frontier.Reach
	return (Vector3.new(position.X, 0, position.Z) - Vector3.new(R.Center.X, 0, R.Center.Z)).Magnitude <= R.Market
end

function Frontier.Site(key)
	for _, site in Frontier.Sites do
		if site.Key == key then
			return site
		end
	end
	return nil
end

return Frontier
