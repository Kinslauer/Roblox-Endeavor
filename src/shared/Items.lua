local Armor = require(script.Parent.Armor)
local Cybernetics = require(script.Parent.Cybernetics)
local Weapons = require(script.Parent.Weapons)

local Items = {}

Items.Defs = {
	Scrap = { Name = "Scrap Metal", Type = "Material" },
	Wire = { Name = "Copper Wire", Type = "Material" },
	Cloth = { Name = "Torn Cloth", Type = "Material" },
	Medkit = { Name = "Medkit", Type = "Consumable", Heal = 45 },
	Ration = { Name = "Ration Pack", Type = "Consumable", Heal = 15, Stamina = 50 },
	-- salvage materials (from broken props)
	Glass = { Name = "Glass", Type = "Material" },
	SheetMetal = { Name = "Sheet Metal", Type = "Material" },
	Pipe = { Name = "Pipe", Type = "Material" },
	Battery = { Name = "Battery", Type = "Material" },
	Powder = { Name = "Powder", Type = "Material" },
	SignPlating = { Name = "Sign Plating", Type = "Material" },
	ArcCell = { Name = "Arc Cell", Type = "Ammo" },
	PipeGrenade = { Name = "Pipe Grenade", Type = "Consumable", Throwable = "Grenade" },
	BreachingCharge = { Name = "Breaching Charge", Type = "Consumable", Plantable = "Charge" },
}

-- Weapons and armor are defined in their own modules; register them as items here.
for id, weapon in Weapons.Defs do
	Items.Defs[id] = { Name = weapon.Name, Type = "Weapon" }
end
for id, piece in Armor.Pieces do
	Items.Defs[id] = { Name = piece.Name, Type = "Armor", Slot = piece.Slot }
end
for id, piece in Cybernetics.Pieces do
	Items.Defs[id] = { Name = piece.Name, Type = "Cybernetic", Slot = piece.Slot }
end

Items.Recipes = {
	Medkit = { Output = "Medkit", Count = 1, Inputs = { Cloth = 2, Scrap = 1 } },
	RebarBlade = { Output = "RebarBlade", Count = 1, Inputs = { Scrap = 6, Cloth = 1 } },
	ScrapSpear = { Output = "ScrapSpear", Count = 1, Inputs = { Scrap = 5, Cloth = 2 } },
	ShockBaton = { Output = "ShockBaton", Count = 1, Inputs = { PipeClub = 1, Wire = 3, Scrap = 2 } },
	Sledge = { Output = "Sledge", Count = 1, Inputs = { Scrap = 12, Wire = 1 } },
	ArcPistol = { Output = "ArcPistol", Count = 1, Inputs = { Scrap = 6, Wire = 5 } },
	ScavHelm = { Output = "ScavHelm", Count = 1, Inputs = { Cloth = 2, Scrap = 2 } },
	ScrapVest = { Output = "ScrapVest", Count = 1, Inputs = { Cloth = 4, Scrap = 3 } },
	ScrapGreaves = { Output = "ScrapGreaves", Count = 1, Inputs = { Cloth = 3, Scrap = 2 } },
	PlatedHelm = { Output = "PlatedHelm", Count = 1, Inputs = { Scrap = 8 } },
	PlatedGreaves = { Output = "PlatedGreaves", Count = 1, Inputs = { Scrap = 10, Cloth = 2 } },
	RiotPlate = { Output = "RiotPlate", Count = 1, Inputs = { Scrap = 10, SignPlating = 2, Cloth = 4 } },
	-- salvage recipes
	ArcCell = { Output = "ArcCell", Count = 6, Inputs = { Battery = 1, Wire = 2 } },
	PipeGrenade = { Output = "PipeGrenade", Count = 1, Inputs = { Pipe = 1, Powder = 2, Wire = 1 } },
	BreachingCharge = { Output = "BreachingCharge", Count = 1, Inputs = { SheetMetal = 1, Powder = 3, Wire = 2, Battery = 1 } },
	SignPlating = { Output = "SignPlating", Count = 1, Inputs = { SheetMetal = 3, Cloth = 1 } },
	ArcHood = { Output = "ArcHood", Count = 1, Inputs = { Wire = 4, Cloth = 2 } },
	ServoGreaves = { Output = "ServoGreaves", Count = 1, Inputs = { Wire = 5, Scrap = 4 } },
	ConduitHarness = { Output = "ConduitHarness", Count = 1, Inputs = { Wire = 8, Scrap = 6, Cloth = 3 } },
}

-- Each entry rolls independently: { item, chance, min, max }
Items.LootTables = {
	Supply = {
		{ "Scrap", 1, 3, 7 }, { "Wire", 0.7, 1, 4 }, { "Cloth", 0.7, 1, 3 }, { "ArcCell", 0.5, 4, 10 }, { "Powder", 0.25, 1, 2 }, { "PipeGrenade", 0.15, 1, 2 },
		{ "Medkit", 0.5, 1, 2 }, { "Ration", 0.6, 1, 2 },
		{ "RebarBlade", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 }, { "ScrapSpear", 0.12, 1, 1 }, { "Sledge", 0.06, 1, 1 }, { "ArcPistol", 0.05, 1, 1 },
		{ "PlatedHelm", 0.1, 1, 1 }, { "RiotPlate", 0.06, 1, 1 }, { "ArcHood", 0.08, 1, 1 }, { "ConduitHarness", 0.04, 1, 1 }, { "ServoGreaves", 0.07, 1, 1 },
		{ "ReflexOptic", 0.06, 1, 1 }, { "TargetingLens", 0.05, 1, 1 }, { "ServoArm", 0.05, 1, 1 }, { "ArcGauntlet", 0.04, 1, 1 }, { "NeuralCore", 0.04, 1, 1 }, { "OverclockCore", 0.02, 1, 1 },
	},
	Vault = {
		{ "Scrap", 1, 6, 12 }, { "Wire", 1, 3, 6 }, { "Battery", 0.8, 1, 3 }, { "Powder", 0.7, 2, 4 }, { "ArcCell", 0.8, 6, 12 },
		{ "Medkit", 0.8, 1, 3 }, { "BreachingCharge", 0.5, 1, 1 }, { "PipeGrenade", 0.5, 1, 3 },
		{ "Sledge", 0.2, 1, 1 }, { "ArcPistol", 0.2, 1, 1 }, { "RiotPlate", 0.15, 1, 1 }, { "ConduitHarness", 0.12, 1, 1 },
		{ "ReflexOptic", 0.12, 1, 1 }, { "ServoArm", 0.12, 1, 1 }, { "NeuralCore", 0.1, 1, 1 }, { "OverclockCore", 0.05, 1, 1 },
	},
	-- salvage from broken props
	Streetlight = { { "Pipe", 1, 1, 2 }, { "Battery", 0.8, 1, 1 }, { "Glass", 0.6, 1, 2 } },
	Sign = { { "SheetMetal", 1, 1, 2 }, { "Pipe", 0.6, 1, 1 } },
	Crate = { { "Scrap", 0.8, 1, 3 }, { "Cloth", 0.6, 1, 2 }, { "Ration", 0.3, 1, 1 } },
	Barrel = { { "Scrap", 0.8, 1, 2 }, { "Powder", 0.35, 1, 2 } },
	Fence = { { "Pipe", 0.9, 1, 2 }, { "SheetMetal", 0.5, 1, 1 } },
	Vending = { { "Glass", 0.9, 1, 3 }, { "Battery", 0.7, 1, 1 }, { "Ration", 0.6, 1, 2 }, { "SheetMetal", 0.4, 1, 1 } },
	Terminal = { { "Battery", 0.9, 1, 2 }, { "Wire", 0.8, 1, 3 } },
	Car = { { "SheetMetal", 1, 2, 4 }, { "Scrap", 0.8, 2, 4 }, { "Battery", 0.3, 1, 1 } },
	Window = { { "Glass", 0.8, 1, 2 } },
	Slab = { { "Scrap", 0.5, 1, 2 } },
	Raider = {
		{ "Scrap", 0.9, 1, 3 }, { "Cloth", 0.5, 1, 2 }, { "Wire", 0.35, 1, 2 }, { "Ration", 0.3, 1, 1 },
		{ "PipeClub", 0.1, 1, 1 }, { "ScavHelm", 0.08, 1, 1 }, { "ScrapVest", 0.08, 1, 1 }, { "ScrapGreaves", 0.08, 1, 1 },
	},
}

local rng = Random.new()
function Items.Roll(tableName)
	local result = {}
	for _, entry in Items.LootTables[tableName] or {} do
		if rng:NextNumber() <= entry[2] then
			result[entry[1]] = (result[entry[1]] or 0) + rng:NextInteger(entry[3], entry[4])
		end
	end
	return result
end

return Items
