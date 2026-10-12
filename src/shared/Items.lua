local Armor = require(script.Parent.Armor)
local Weapons = require(script.Parent.Weapons)

local Items = {}

Items.Defs = {
	Scrap = { Name = "Scrap Metal", Type = "Material" },
	Wire = { Name = "Copper Wire", Type = "Material" },
	Cloth = { Name = "Torn Cloth", Type = "Material" },
	Medkit = { Name = "Medkit", Type = "Consumable", Heal = 45 },
	Ration = { Name = "Ration Pack", Type = "Consumable", Heal = 15, Stamina = 50 },
}

-- Weapons and armor are defined in their own modules; register them as items here.
for id, weapon in Weapons.Defs do
	Items.Defs[id] = { Name = weapon.Name, Type = "Weapon" }
end
for id, piece in Armor.Pieces do
	Items.Defs[id] = { Name = piece.Name, Type = "Armor", Slot = piece.Slot }
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
	RiotPlate = { Output = "RiotPlate", Count = 1, Inputs = { Scrap = 16, Cloth = 4 } },
	ArcHood = { Output = "ArcHood", Count = 1, Inputs = { Wire = 4, Cloth = 2 } },
	ServoGreaves = { Output = "ServoGreaves", Count = 1, Inputs = { Wire = 5, Scrap = 4 } },
	ConduitHarness = { Output = "ConduitHarness", Count = 1, Inputs = { Wire = 8, Scrap = 6, Cloth = 3 } },
}

-- Each entry rolls independently: { item, chance, min, max }
Items.LootTables = {
	Supply = {
		{ "Scrap", 1, 3, 7 }, { "Wire", 0.7, 1, 4 }, { "Cloth", 0.7, 1, 3 },
		{ "Medkit", 0.5, 1, 2 }, { "Ration", 0.6, 1, 2 },
		{ "RebarBlade", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 }, { "ScrapSpear", 0.12, 1, 1 }, { "Sledge", 0.06, 1, 1 }, { "ArcPistol", 0.05, 1, 1 },
		{ "PlatedHelm", 0.1, 1, 1 }, { "RiotPlate", 0.06, 1, 1 }, { "ArcHood", 0.08, 1, 1 }, { "ConduitHarness", 0.04, 1, 1 }, { "ServoGreaves", 0.07, 1, 1 },
	},
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
