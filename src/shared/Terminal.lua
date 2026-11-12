-- The hideout computer (ported from combat-feel's Terminal/Contacts/Rivals, adapted to the frontier):
-- one console in the hideout (module "Computer"), three apps, every app locked until you meet its
-- contact out in the world. What the computer knows (contacts met, contracts on the board) is uploaded
-- consciousness: it survives permadeath with the hideout (profile.Knowledge).
--   RAIDS  (the Broker, at the Verdant Market): contracts on the frontier's sites and bounties and the
--          Blackout raid, paid in war credits and gear. Rival conduit crews work the same contracts;
--          a dead rival's intel puts one straight on your board.
--   HOUSE  (the Fixer, under the Crossroads span): materials for the hideout, delivered to your pack.
--   MARKET (the Dealer, on the Scarp Overlook): the black market - cybernetics and gear at a price.
local Terminal = {}

Terminal.Contacts = {
	Broker = { Name = "The Broker", App = "RAIDS", Where = "Reach", Line = "Contracts. Sites, bounties, the Blackout. Pay on completion. Don't die in the middle of one." },
	Fixer = { Name = "The Fixer", App = "HOUSE", Where = "Crossroads", Line = "Anything for the house, delivered. Credits up front. Don't ask where it comes from." },
	Dealer = { Name = "The Dealer", App = "MARKET", Where = "Scarp", Line = "Cores, arms, lenses. Pulled from people who no longer need them. Credits only." },
}

-- HOUSE: material bundles for the hideout, paid in war credits.
Terminal.House = {
	{ Id = "ScrapLot", Name = "Scrap lot (12 Scrap Metal)", Price = 40, Items = { Scrap = 12 } },
	{ Id = "SheetLot", Name = "Sheet lot (6 Sheet Metal)", Price = 60, Items = { SheetMetal = 6 } },
	{ Id = "WireLot", Name = "Wire spool (8 Copper Wire)", Price = 50, Items = { Wire = 8 } },
	{ Id = "CellLot", Name = "Cells (3 Batteries)", Price = 70, Items = { Battery = 3 } },
	{ Id = "PowderLot", Name = "Powder keg (4 Powder)", Price = 80, Items = { Powder = 4 } },
	{ Id = "GlassLot", Name = "Glass crate (4 Glass)", Price = 45, Items = { Glass = 4 } },
	{ Id = "ClothLot", Name = "Cloth bale (10 Torn Cloth)", Price = 30, Items = { Cloth = 10 } },
	-- round 6: goods a contact only sells to someone they trust (Loyalty = the level it needs)
	{ Id = "FuelLot", Name = "Fuel (2 cans)", Price = 90, Items = { FuelCan = 2 }, Loyalty = 2 },
	{ Id = "KeyLot", Name = "Strongroom key", Price = 260, Items = { StrongroomKey = 1 }, Loyalty = 3 },
}

-- MARKET: the black market. Dearer than the Reach's trader; sells what the trader will not.
Terminal.Market = {
	{ Id = "ReflexOptic", Price = 650 },
	{ Id = "TargetingLens", Price = 700 },
	{ Id = "ServoArm", Price = 800 },
	{ Id = "ArcGauntlet", Price = 900 },
	{ Id = "NeuralCore", Price = 1100 },
	{ Id = "StriderLeg", Price = 750 },
	{ Id = "ChemSniffer", Price = 500 },
	{ Id = "RiotPlate", Price = 600 },
	{ Id = "Sledge", Price = 450 },
	{ Id = "BreachingCharge", Price = 150, Count = 2 },
	{ Id = "FocusChip", Price = 900, Loyalty = 2 }, { Id = "HookChip", Price = 900, Loyalty = 2 }, { Id = "TrailChip", Price = 900, Loyalty = 2 },
	{ Id = "BreathChip", Price = 700, Loyalty = 2 }, { Id = "MirrorChip", Price = 1000, Loyalty = 3 }, { Id = "ArcChip", Price = 1000, Loyalty = 3 },
	{ Id = "Round9AP", Price = 120, Count = 15, Loyalty = 2 },
	{ Id = "ShelterKey", Price = 400, Loyalty = 4 },
}

-- Swaps (round 6): goods for goods, no credits. Each needs a level of the contact's trust and earns Points of it.
Terminal.Swaps = {
	{ Id = "ScrapForCloth", Contact = "Fixer", Give = { Scrap = 10 }, Get = { Cloth = 6 }, Loyalty = 1, Points = 8 },
	{ Id = "CellsForFuel", Contact = "Fixer", Give = { Battery = 2 }, Get = { FuelCan = 1 }, Loyalty = 2, Points = 12 },
	{ Id = "TagsForAmmo", Contact = "Broker", Give = { Tag = 3 }, Get = { Round9 = 30 }, Loyalty = 1, Points = 15 },
	{ Id = "PowderForKey", Contact = "Broker", Give = { Powder = 4, Tag = 4 }, Get = { StrongroomKey = 1 }, Loyalty = 2, Points = 25 },
	{ Id = "ShardsForChip", Contact = "Dealer", Give = { DataShard = 3 }, Get = { BreathChip = 1 }, Loyalty = 2, Points = 30 },
	{ Id = "CoreParts", Contact = "Dealer", Give = { Battery = 4, Glass = 3, Wire = 6 }, Get = { ChemSniffer = 1 }, Loyalty = 3, Points = 30 },
}

-- RAIDS: contract templates. The server rolls one Clear per frontier site, one Bounty per rolled bounty
-- cell, and the Blackout raid. Rewards scale with the site's danger.
Terminal.Rewards = {
	Clear = { Medium = { Credits = 180, Items = { Medkit = 2 } }, High = { Credits = 300, Items = { Medkit = 2, PipeGrenade = 2 } }, Severe = { Credits = 520, Items = { BreachingCharge = 1, ArcCell = 10 } } },
	Bounty = { Credits = 400, Items = { Medkit = 2, Powder = 3 } },
	Raid = { Credits = 350, Items = { ArcCell = 12 } },
	Trial = { Credits = 150, Items = { DataShard = 1 } }, -- a passed trial raises the grade (shared/Builds)
}
Terminal.MaxActive = 2 -- contracts you can hold at once

return Terminal
