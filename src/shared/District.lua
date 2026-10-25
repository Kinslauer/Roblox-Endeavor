-- District 1 blockout data (brief build-order 6). The server builds the first district from these
-- numbers at boot (server/District.lua); nothing here is hand-placed. When hand-built districts
-- exist they replace the generator, and only the SafeZone / Spawn helpers below stay in use.
--
-- Layout: a Blocks x Blocks grid of city blocks separated by streets. The centre block is the
-- plaza, and the plaza plus a ring of street around it is the one safe zone: no damage in or out.
-- Street ground is tagged "PlayableArea" (ambush placement, NPC ground checks); the plaza is not,
-- so events never land inside the safe zone. Spawn pads are tagged "CitySpawn".
local CollectionService = game:GetService("CollectionService")

local District = {}

District.Seed = 20261025 -- deterministic layout: same city every boot until the seed changes
District.Grid = { Blocks = 5, BlockSize = 60, StreetWidth = 18 } -- 5*60 + 6*18 = 408 studs square
District.GroundTop = 2 -- Y of the street surface (the arena uses the same ground level)
District.Origin = Vector3.new(0, 0, 0) -- centre of the plaza

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
