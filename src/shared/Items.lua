local Armor = require(script.Parent.Armor)
local Attachments = require(script.Parent.Attachments)
local Cybernetics = require(script.Parent.Cybernetics)
local Weapons = require(script.Parent.Weapons)

local Items = {}

Items.Defs = {
	Scrap = { Name = "Scrap Metal", Type = "Material" },
	Wire = { Name = "Copper Wire", Type = "Material" },
	Cloth = { Name = "Torn Cloth", Type = "Material" },
	Medkit = { Name = "Medkit", Type = "Consumable", Heal = 45 },
	Ration = { Name = "Ration Pack", Type = "Consumable", Heal = 15, Stamina = 50 },
	Intel = { Name = "Raid Intel", Type = "Consumable", Intel = true }, -- read it (Use) and a contract lands on your board
	-- salvage (design/gdd/destruction.md §4.4): from enemies and supply today, from broken props once they break
	Glass = { Name = "Glass", Type = "Material" },
	SheetMetal = { Name = "Sheet Metal", Type = "Material" },
	Pipe = { Name = "Pipe", Type = "Material" },
	Battery = { Name = "Battery", Type = "Material" },
	Powder = { Name = "Black Powder", Type = "Material" },
	-- the reserve an arc weapon reloads from (Config.Gunplay.CellsPerReload per reload; both worlds, everyone)
	ArcCell = { Name = "Arc Cell", Type = "Ammo" },
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
for id, part in Attachments.Parts do -- weapon parts for the bench (shared/Attachments.lua)
	Items.Defs[id] = { Name = part.Name, Type = "Part", Slot = part.Slot }
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
	-- bench parts you can make; the better ones only drop (regional, see the loot tables)
	TacLight = { Output = "TacLight", Count = 1, Inputs = { Wire = 3, Scrap = 2 } },
	ExtMag = { Output = "ExtMag", Count = 1, Inputs = { Scrap = 5, Wire = 2 } },
	CompBarrel = { Output = "CompBarrel", Count = 1, Inputs = { Scrap = 8, Wire = 1 } },
	-- salvage (destruction.md §4.4)
	ArcCell = { Output = "ArcCell", Count = 6, Inputs = { Battery = 1, Wire = 2 } },
}

-- Each entry rolls independently: { item, chance, min, max }. The weapon an enemy holds is NOT listed here:
-- NPCs.packCarry adds it, so every enemy drops the thing it was hitting you with (plus what is rolled below).
Items.LootTables = {
	Supply = {
		{ "Scrap", 1, 3, 7 }, { "Wire", 0.7, 1, 4 }, { "Cloth", 0.7, 1, 3 },
		{ "Medkit", 0.5, 1, 2 }, { "Ration", 0.6, 1, 2 },
		{ "RebarBlade", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 }, { "ScrapSpear", 0.12, 1, 1 }, { "Sledge", 0.06, 1, 1 }, { "ArcPistol", 0.05, 1, 1 },
		{ "PlatedHelm", 0.1, 1, 1 }, { "RiotPlate", 0.06, 1, 1 }, { "ArcHood", 0.08, 1, 1 }, { "ConduitHarness", 0.04, 1, 1 }, { "ServoGreaves", 0.07, 1, 1 },
		{ "ReflexOptic", 0.06, 1, 1 }, { "TargetingLens", 0.05, 1, 1 }, { "ServoArm", 0.05, 1, 1 }, { "ArcGauntlet", 0.04, 1, 1 }, { "NeuralCore", 0.04, 1, 1 }, { "OverclockCore", 0.02, 1, 1 },
		{ "DotSight", 0.05, 1, 1 }, { "ExtMag", 0.05, 1, 1 }, -- city parts: the common ones
		{ "ArcCell", 0.6, 2, 5 }, { "Battery", 0.35, 1, 2 }, { "Glass", 0.4, 1, 3 }, { "SheetMetal", 0.3, 1, 2 }, { "Pipe", 0.3, 1, 2 }, { "Powder", 0.1, 1, 2 },
	},
	Raider = {
		{ "Scrap", 0.9, 1, 3 }, { "Cloth", 0.5, 1, 2 }, { "Wire", 0.35, 1, 2 }, { "Ration", 0.3, 1, 1 },
		{ "ScavHelm", 0.08, 1, 1 }, { "ScrapVest", 0.08, 1, 1 }, { "ScrapGreaves", 0.08, 1, 1 },
		{ "TacLight", 0.04, 1, 1 }, { "LaserSight", 0.02, 1, 1 },
		{ "Pipe", 0.25, 1, 1 }, { "Glass", 0.15, 1, 2 },
	},
	Brute = {
		{ "Scrap", 1, 2, 5 }, { "Cloth", 0.5, 1, 2 }, { "Ration", 0.4, 1, 1 },
		{ "PlatedHelm", 0.06, 1, 1 }, { "RiotPlate", 0.06, 1, 1 }, { "PlatedGreaves", 0.06, 1, 1 },
		{ "CompBarrel", 0.05, 1, 1 }, { "LongBarrel", 0.04, 1, 1 },
		{ "SheetMetal", 0.5, 1, 3 }, { "Pipe", 0.3, 1, 2 },
	},
	Gunner = {
		{ "Scrap", 0.9, 1, 3 }, { "Wire", 0.8, 2, 4 }, { "Cloth", 0.4, 1, 2 },
		{ "ArcHood", 0.06, 1, 1 },
		{ "DotSight", 0.06, 1, 1 }, { "Brake", 0.04, 1, 1 }, { "MatchSlide", 0.03, 1, 1 }, -- the Range: sidearm parts
		{ "Battery", 0.3, 1, 1 }, -- (the cells it carries for its gun come with the gun: NPCs.packCarry)
	},
	Rival = { -- a rival conduit crew: they carry what they were working on
		{ "Intel", 0.6, 1, 1 }, { "Scrap", 0.8, 2, 5 }, { "Wire", 0.5, 1, 3 }, { "Medkit", 0.3, 1, 1 },
		{ "DotSight", 0.08, 1, 1 }, { "ExtMag", 0.08, 1, 1 }, { "ArcHood", 0.05, 1, 1 },
		{ "ArcCell", 0.5, 2, 4 }, { "Battery", 0.3, 1, 2 }, { "Powder", 0.15, 1, 2 },
	},
	Warmonger = { -- the open world's elite: cybernetics and the good parts
		{ "Scrap", 1, 6, 12 }, { "Wire", 1, 4, 8 }, { "Medkit", 0.6, 1, 2 },
		{ "NeuralCore", 0.2, 1, 1 }, { "OverclockCore", 0.1, 1, 1 }, { "ConduitHarness", 0.2, 1, 1 }, { "ArcPistol", 0.3, 1, 1 },
		{ "LongBarrel", 0.3, 1, 1 }, { "Suppressor", 0.25, 1, 1 }, { "MatchSlide", 0.2, 1, 1 },
		{ "Battery", 0.6, 1, 3 }, { "Powder", 0.4, 1, 3 }, { "SheetMetal", 0.5, 2, 4 },
	},
	Recruit = { -- war-world recruits: the rifle in their hands always drops (NPCs.packCarry); this is what else they carry
		{ "Ration", 0.5, 1, 2 }, { "Scrap", 0.6, 1, 3 }, { "Wire", 0.4, 1, 2 }, { "Medkit", 0.2, 1, 1 },
		{ "Suppressor", 0.02, 1, 1 }, { "LongBarrel", 0.02, 1, 1 }, -- the war: a rare rifle part off a recruit
		{ "Powder", 0.15, 1, 2 }, { "SheetMetal", 0.2, 1, 2 },
	},
	Drone = { -- machine parts: wire and scrap, a rare optic
		{ "Wire", 1, 2, 5 }, { "Scrap", 0.8, 1, 3 },
		{ "ReflexOptic", 0.04, 1, 1 }, { "TargetingLens", 0.03, 1, 1 },
		{ "Scope4x", 0.04, 1, 1 }, { "LightBolt", 0.03, 1, 1 }, -- drones carry the rifle optics
		{ "Battery", 0.7, 1, 2 }, { "Glass", 0.3, 1, 1 },
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
