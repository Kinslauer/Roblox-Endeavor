-- The open world beyond the city (Phase 3, build order 5; design/gdd/world.md). The two districts are
-- the city; REGIONS are everything else, one at a time. The first is the solarpunk enclave north of
-- District 1, reached on foot along a wasteland road (so the station there can be unlocked), then by
-- train from any station you have already stood in (server/Transport.lua).
--
-- Coordinates: "north" is +Z, the way the district walls name their sides. District 1's north wall
-- has a gap on the gate street line; the road leaves through it.
local District = require(script.Parent.District)

local Regions = {}

local D1 = District.Districts[1]
local roadX = D1.Origin.X + District.StreetLine(District.Gate.Line) -- the road leaves on the gate line
local cityEdge = D1.Origin.Z + District.Extent() / 2 + District.Wall.Margin -- the north wall

-- The wasteland road: open ground from the city's north gap to the enclave's south edge.
Regions.Road = {
	Width = 22,
	Length = 420,
	X = roadX,
	Z0 = cityEdge, -- starts at the wall
	Seed = 20261028,
	Wrecks = 9, -- cars and rubble along the verge
	DeadTrees = 24,
	LampEvery = 70, -- sparse, half of them dark
	-- what guards the way, as fractions of the length (fixed, never despawning)
	Guards = {
		{ At = 0.3, Type = "Grunt", Count = 3 },
		{ At = 0.55, Type = "Brute", Count = 1 },
		{ At = 0.58, Type = "Grunt", Count = 2 },
		{ At = 0.85, Type = "Warmonger", Count = 1 }, -- the enclave's gate is held by a warmonger
	},
}

-- The solarpunk enclave: a round terrace of gardens, greenhouse domes and solar towers around a
-- covered market (a safe zone with a trader). Greener and safer than the city; the first parts.
Regions.Enclave = {
	Id = "Enclave",
	Name = "Verdant Reach",
	Seed = 20261029,
	Radius = 190,
	Origin = Vector3.new(roadX, 0, cityEdge + 420 + 190), -- road end + radius
	Market = { Radius = 48, Name = "Verdant Market" },
	Palette = {
		Ground = Color3.fromRGB(74, 92, 58), -- moss over old concrete
		Path = Color3.fromRGB(150, 140, 118), -- packed sand
		Dome = Color3.fromRGB(190, 240, 230),
		Frame = Color3.fromRGB(230, 225, 210), -- bleached white structure
		Panel = Color3.fromRGB(30, 50, 90), -- solar glass
		Leaf = { Color3.fromRGB(72, 140, 70), Color3.fromRGB(98, 160, 76), Color3.fromRGB(60, 120, 90) },
		Trunk = Color3.fromRGB(96, 72, 52),
		Lamp = Color3.fromRGB(255, 236, 200),
		Ring = Color3.fromRGB(170, 255, 170),
	},
	Domes = 9,
	Towers = 6,
	Beds = 28, -- planter beds along the paths
	Trees = 46,
	Lamps = 20,
	-- the trader's stock: parts and a sidearm, for money (Wallet). Prices are tuning.
	Stock = {
		{ Id = "ArcCell", Price = 8 }, -- one cell a purchase
		{ Id = "DotSight", Price = 40 },
		{ Id = "ExtMag", Price = 35 },
		{ Id = "Brake", Price = 60 },
		{ Id = "TacLight", Price = 25 },
		{ Id = "LaserSight", Price = 55 },
		{ Id = "MatchSlide", Price = 90 },
		{ Id = "CompBarrel", Price = 70 },
		{ Id = "ArcPistol", Price = 140 },
		{ Id = "Medkit", Price = 20 },
	},
}

-- Transport hubs (server/Transport.lua): where the lines stop. A hub unlocks when you stand on it;
-- a ride needs both ends unlocked. Positions are world space.
Regions.Hubs = {
	City = {
		Name = "Relay Terminal",
		Position = Vector3.new(roadX + 30, 0, D1.Origin.Z + District.StreetLine(District.Gate.Line + 1) - 6), -- inside District 1, by the north gate
		Lines = { "Enclave" },
	},
	Enclave = {
		Name = "Verdant Station",
		Position = Vector3.new(roadX + 36, 0, cityEdge + 420 + 40), -- just inside the enclave's south edge
		Lines = { "City" },
	},
}

-- Which region a world position is in: "Enclave", "Road", or nil (the city / elsewhere).
function Regions.At(position)
	local E = Regions.Enclave
	local d = Vector3.new(position.X - E.Origin.X, 0, position.Z - E.Origin.Z)
	if d.Magnitude <= E.Radius then
		return "Enclave"
	end
	local R = Regions.Road
	if math.abs(position.X - R.X) <= R.Width / 2 + 10 and position.Z >= R.Z0 - 5 and position.Z <= R.Z0 + R.Length + 5 then
		return "Road"
	end
	return nil
end

function Regions.InMarket(position)
	local E = Regions.Enclave
	local d = Vector3.new(position.X - E.Origin.X, 0, position.Z - E.Origin.Z)
	return d.Magnitude <= E.Market.Radius
end

return Regions
