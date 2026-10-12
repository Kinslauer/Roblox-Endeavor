-- Armor is the second half of a build. Each piece contributes resistances, posture, stat
-- bonuses and TAGS; skills unlock and scale off the stats + tags you are actually wearing.
local Armor = {}

Armor.Slots = { "Head", "Chest", "Legs" }
Armor.WeightScore = { Light = 0, Medium = 1, Heavy = 2 } -- heavier = more stamina cost, slower, sturdier block

-- Resist: 0-1 damage reduction per damage type. Posture: extra max posture.
-- Stats: bonuses to effective stats. Tags: counted for skill requirements/bonuses.
-- ChargeGain: extra conduit charge per hit (fraction). Speed: walk speed multiplier delta.
Armor.Pieces = {
	ScavHelm = { Name = "Scav Helm", Slot = "Head", Weight = "Light", Resist = { Physical = 0.03 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	PlatedHelm = { Name = "Plated Helm", Slot = "Head", Weight = "Heavy", Resist = { Physical = 0.08 }, Posture = 12, Tags = { "Plated" } },
	ArcHood = { Name = "Arc-Lined Hood", Slot = "Head", Weight = "Light", Resist = { Arc = 0.12 }, Stats = { Intelligence = 2 }, ChargeGain = 0.10, Tags = { "Conduit" } },

	ScrapVest = { Name = "Scrap Vest", Slot = "Chest", Weight = "Light", Resist = { Physical = 0.06 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	RiotPlate = { Name = "Riot Plate", Slot = "Chest", Weight = "Heavy", Resist = { Physical = 0.16 }, Posture = 25, Stats = { Fortitude = 2 }, Speed = -0.04, Tags = { "Plated" } },
	ConduitHarness = { Name = "Conduit Harness", Slot = "Chest", Weight = "Medium", Resist = { Physical = 0.06, Arc = 0.15 }, Stats = { Intelligence = 3 }, ChargeGain = 0.25, Tags = { "Conduit" } },

	ScrapGreaves = { Name = "Scrap Greaves", Slot = "Legs", Weight = "Light", Resist = { Physical = 0.04 }, Stats = { Agility = 1 }, Tags = { "Scav" } },
	ServoGreaves = { Name = "Servo Greaves", Slot = "Legs", Weight = "Medium", Resist = { Physical = 0.05, Arc = 0.05 }, Stats = { Agility = 2 }, Speed = 0.04, Tags = { "Conduit" } },
	PlatedGreaves = { Name = "Plated Greaves", Slot = "Legs", Weight = "Heavy", Resist = { Physical = 0.1 }, Posture = 12, Tags = { "Plated" } },
}

return Armor
