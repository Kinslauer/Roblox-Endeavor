-- District blockout data (brief build-order 6; District 2 is Phase-2 build-order 4). The server
-- builds every entry of District.Districts from these numbers at boot (server/District.lua);
-- nothing here is hand-placed. When hand-built districts exist they replace the generator, and only
-- the SafeZone / Spawn helpers below stay in use.
--
-- Layout: each district is a Blocks x Blocks grid of city blocks separated by streets. The centre
-- block is the plaza, and the plaza plus a ring of street around it is a safe zone: no damage in or
-- out. Street ground is tagged "PlayableArea" (ambush placement, NPC ground checks); the plaza is
-- not, so events never land inside the safe zone. Spawn pads are tagged "CitySpawn" and carry a
-- SpawnFor attribute ("Fresh" | "Awakened"): WorldPhase picks pads by the player's profile, so new
-- players wake in District 1 and returning ones in District 2. Districts share one grid and sit
-- side by side along +X, joined by a gate street through both perimeter walls (District.Gate).
local CollectionService = game:GetService("CollectionService")

local District = {}

District.Seed = 20261025 -- District 1's seed (kept for the Districts table below)
District.Grid = { Blocks = 5, BlockSize = 60, StreetWidth = 18 } -- 5*60 + 6*18 = 408 studs square
District.GroundTop = 2 -- Y of the street surface (the arena uses the same ground level)
District.Origin = Vector3.new(0, 0, 0) -- centre of District 1's plaza (Range.RiftPlaza etc. are relative to the world, i.e. this)

District.Buildings = {
	PerBlock = { 2, 4 }, -- how many boxes share one block
	Inset = 3, -- studs between a building and the kerb
	MinHeight = 16, MaxHeight = 64,
	Palette = { Color3.fromRGB(38, 40, 48), Color3.fromRGB(52, 54, 64), Color3.fromRGB(30, 32, 40), Color3.fromRGB(64, 60, 70) },
	Neon = { Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 50, 160), Color3.fromRGB(255, 190, 40), Color3.fromRGB(120, 255, 120) },
	NeonChance = 0.65, -- chance a building wears a neon sign strip
	WindowChance = 0.5, -- chance of a lit window band
	RubbleChance = 0.35, -- chance a block has a collapsed building (low broken slab) instead of a tower
}

District.Cover = {
	PerStreet = { 1, 3 }, -- props per street segment (one segment = one block length)
	Kinds = {
		{ Name = "Crate", Size = Vector3.new(4, 4, 4), Color = Color3.fromRGB(90, 80, 60), Material = Enum.Material.Wood },
		{ Name = "Barrier", Size = Vector3.new(10, 4, 2), Color = Color3.fromRGB(110, 110, 115), Material = Enum.Material.Concrete },
		{ Name = "Wreck", Size = Vector3.new(14, 5, 6), Color = Color3.fromRGB(70, 50, 50), Material = Enum.Material.CorrodedMetal },
		{ Name = "Dumpster", Size = Vector3.new(8, 5, 4), Color = Color3.fromRGB(40, 70, 60), Material = Enum.Material.Metal },
	},
}

District.Lamps = { Spacing = 30, Height = 12, Color = Color3.fromRGB(255, 200, 150), Range = 34, Brightness = 1.2 }

District.SafeZone = {
	Radius = 46, -- studs from the plaza centre; covers the plaza and the first ring of street
	FloorColor = Color3.fromRGB(70, 74, 86),
	RingColor = Color3.fromRGB(120, 255, 200),
	Beacon = { Radius = 4, Height = 40 }, -- a tall neon pylon so the plaza is visible from any street
	Name = "Relay Plaza",
}

District.Spawns = {
	Count = 8,
	MinFromSafeZone = 60, -- pads spawn you in the streets, not in the plaza (you walk in)
	MaxFromSafeZone = 150,
}

District.Wall = { Height = 36, Thickness = 4, Margin = 20 } -- perimeter: the rest of the city is "collapsed"

-- Lighting for the whole open world (moved here from the dev arena so it applies without Config.Dev).
District.Lighting = { ClockTime = 23, Ambient = Color3.fromRGB(45, 45, 70), Brightness = 1.2, Bloom = { Intensity = 0.7, Size = 28, Threshold = 1.6 } }

-- Total side length of the built area (streets + blocks, without the wall margin).
function District.Extent()
	local g = District.Grid
	return g.Blocks * g.BlockSize + (g.Blocks + 1) * g.StreetWidth
end

-- The gate street between neighbouring districts: it leaves District 1 through its east wall and
-- enters District 2 through its west wall, along street line `Line` (0..Blocks; line 3 is the
-- street just north of the plaza). Length = open ground between the two walls.
District.Gate = { Line = 3, Length = 60, Arch = { Height = 16, Color = Color3.fromRGB(255, 50, 160) } }

-- Centre-to-centre distance between neighbouring districts.
function District.Pitch()
	return District.Extent() + 2 * District.Wall.Margin + District.Gate.Length
end

-- Z (relative to a district's origin) of street line i.
function District.StreetLine(i)
	local g = District.Grid
	return -District.Extent() / 2 + g.StreetWidth / 2 + i * (g.BlockSize + g.StreetWidth)
end

-- The districts, in build order. Each has its own seed, plaza name, palette and spawn class;
-- anything missing falls back to the District 1 tables above. Gate = which wall(s) have the gap.
District.Districts = {
	{
		Name = "District 1", Seed = District.Seed, Origin = District.Origin, SpawnFor = "Fresh",
		Plaza = "Relay Plaza", Gates = { East = true },
	},
	{
		Name = "District 2", Seed = 20261026, Origin = District.Origin + Vector3.new(District.Pitch(), 0, 0), SpawnFor = "Awakened",
		Plaza = "Ferrite Court", Gates = { West = true },
		-- rust and sodium light: the older, ironworks half of the city
		Palette = { Color3.fromRGB(58, 44, 40), Color3.fromRGB(72, 54, 46), Color3.fromRGB(40, 34, 34), Color3.fromRGB(84, 62, 50) },
		Neon = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 220, 90), Color3.fromRGB(0, 220, 255) },
		RingColor = Color3.fromRGB(255, 190, 80), LampColor = Color3.fromRGB(255, 170, 90),
		FloorColor = Color3.fromRGB(80, 66, 60), RubbleChance = 0.5,
	},
}

-- Which district a world position falls in (by grid footprint), or nil in the gate / outskirts.
function District.At(position)
	local half = District.Extent() / 2
	for i, d in District.Districts do
		if math.abs(position.X - d.Origin.X) <= half and math.abs(position.Z - d.Origin.Z) <= half then
			return i, d
		end
	end
	return nil
end

-- Is this world position inside any safe zone? Safe zones are parts tagged "SafeZone" with a
-- Radius attribute (cylindrical, infinite height). Works on both server and client.
function District.InSafeZone(position)
	for _, zone in CollectionService:GetTagged("SafeZone") do
		local radius = zone:GetAttribute("Radius") or 0
		local d = Vector3.new(position.X - zone.Position.X, 0, position.Z - zone.Position.Z)
		if d.Magnitude <= radius then
			return true, zone
		end
	end
	return false, nil
end

return District
