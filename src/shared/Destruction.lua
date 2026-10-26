-- Destruction data (design/gdd/destruction.md §4.1–4.4; server/Destruction.lua builds and breaks them).
-- Break types are separate from combat's resist Type: an attack's spec.Break, or its weapon family's default.
-- Prop kinds: Health, Resist per break type (0..1, 1 = immune), Salvage = an Items.LootTables entry, Chunks =
-- how many pieces it breaks into, and how it looks (built procedurally until authored models exist).
local Destruction = {}

Destruction.FamilyBreak = { Fists = "Blunt", Blunt = "Blunt", Baton = "Blunt", Hammer = "Blunt", Blade = "Blade", Spear = "Blade" }

function Destruction.BreakTypeOf(spec, weaponDef)
	if spec.Break then
		return spec.Break
	end
	if spec.Type == "Arc" then
		return "Arc"
	end
	return (weaponDef and Destruction.FamilyBreak[weaponDef.Family or ""]) or "Blunt"
end

Destruction.Kinds = {
	Crate = { Name = "Crate", Health = 30, Resist = {}, Salvage = "SalvageCrate", Chunks = 4,
		Size = Vector3.new(4, 3.5, 4), Color = Color3.fromRGB(120, 92, 60), Material = "WoodPlanks" },
	Barrel = { Name = "Barrel", Health = 40, Resist = { Blade = 0.5 }, Salvage = "SalvageBarrel", Chunks = 3,
		Size = Vector3.new(3, 4, 3), Color = Color3.fromRGB(110, 60, 45), Material = "CorrodedMetal", Shape = "Cylinder" },
	StreetSign = { Name = "Street Sign", Health = 25, Resist = { Blade = 0.3 }, Salvage = "SalvageSign", Chunks = 2,
		Size = Vector3.new(0.4, 8, 0.4), Plate = Vector3.new(3, 2, 0.2), Color = Color3.fromRGB(70, 74, 80), PlateColor = Color3.fromRGB(40, 110, 70), Material = "Metal" },
	Fence = { Name = "Fence Panel", Health = 35, Resist = { Arc = 0.5 }, Salvage = "SalvageFence", Chunks = 3,
		Size = Vector3.new(8, 5, 0.4), Color = Color3.fromRGB(90, 92, 96), Material = "DiamondPlate" },
	Terminal = { Name = "Terminal", Health = 30, Resist = { Blade = 0.5, Arc = -0.5 }, Salvage = "SalvageTerminal", Chunks = 3, -- arc fries it
		Size = Vector3.new(2.5, 5, 1.5), Color = Color3.fromRGB(40, 44, 52), Material = "Metal", Screen = Color3.fromRGB(90, 200, 255) },
	Streetlight = { Name = "Streetlight", Health = 60, Resist = { Blade = 0.7 }, Salvage = "SalvageStreetlight", Chunks = 2 }, -- the district / road lamps, adopted
}

return Destruction
