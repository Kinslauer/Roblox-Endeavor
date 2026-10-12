local Items = {}

Items.Defs = {
	Fists = { Name = "Fists", Type = "Weapon", Damage = 6, Range = 5, Width = 5, Cooldown = 0.45, Windup = 0.12, StaminaCost = 6, Knockback = 20 },
	PipeClub = { Name = "Pipe Club", Type = "Weapon", Damage = 14, Range = 6, Width = 6, Cooldown = 0.55, Windup = 0.16, StaminaCost = 9, Knockback = 28 },
	RebarBlade = { Name = "Rebar Blade", Type = "Weapon", Damage = 20, Range = 7, Width = 6, Cooldown = 0.6, Windup = 0.18, StaminaCost = 11, Knockback = 30 },
	ShockBaton = { Name = "Shock Baton", Type = "Weapon", Damage = 17, Range = 6.5, Width = 6, Cooldown = 0.5, Windup = 0.14, StaminaCost = 10, Knockback = 25, ChargeBonus = 6 },
	Scrap = { Name = "Scrap Metal", Type = "Material" },
	Wire = { Name = "Copper Wire", Type = "Material" },
	Cloth = { Name = "Torn Cloth", Type = "Material" },
	Medkit = { Name = "Medkit", Type = "Consumable", Heal = 45 },
	Ration = { Name = "Ration Pack", Type = "Consumable", Heal = 15, Stamina = 50 },
}

Items.Recipes = {
	Medkit = { Output = "Medkit", Count = 1, Inputs = { Cloth = 2, Scrap = 1 } },
	RebarBlade = { Output = "RebarBlade", Count = 1, Inputs = { Scrap = 6, Cloth = 1 } },
	ShockBaton = { Output = "ShockBaton", Count = 1, Inputs = { PipeClub = 1, Wire = 3, Scrap = 2 } },
}

-- Each entry rolls independently: { item, chance, min, max }
Items.LootTables = {
	Supply = {
		{ "Scrap", 1, 3, 7 }, { "Wire", 0.7, 1, 4 }, { "Cloth", 0.7, 1, 3 },
		{ "Medkit", 0.5, 1, 2 }, { "Ration", 0.6, 1, 2 }, { "RebarBlade", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 },
	},
	Raider = {
		{ "Scrap", 0.9, 1, 3 }, { "Cloth", 0.5, 1, 2 }, { "Wire", 0.35, 1, 2 }, { "Ration", 0.3, 1, 1 }, { "PipeClub", 0.1, 1, 1 },
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
