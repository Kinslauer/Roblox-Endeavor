-- Hideouts: a conduit's claimed site in the city. Starts as a tinkerer's bench, grows into a
-- workshop and then a foundry. Everything here is data: tiers, modules, repair and upgrade
-- costs. The server (Hideouts.lua) enforces it; the client draws it.
local Hideout = {}

-- Tiers. Each unlocks recipes, a max upgrade level, more modules and a bigger vault, and costs
-- materials to reach. Raid pressure grows with tier too (big workshops are worth robbing).
Hideout.Tiers = {
	{ Name = "Tinkerer's Bench", MaxUpgrade = 1, Vault = 12, Modules = 3, RaidWeight = 1, Cost = {} },
	{ Name = "Workshop", MaxUpgrade = 2, Vault = 24, Modules = 6, RaidWeight = 2, Cost = { Scrap = 40, SheetMetal = 10, Wire = 10 } },
	{ Name = "Foundry", MaxUpgrade = 3, Vault = 48, Modules = 9, RaidWeight = 4, Cost = { Scrap = 120, SheetMetal = 30, Battery = 10, Powder = 6 } },
}

-- Modules you can build. Defense: which breach tier the walls use. Turret: damage per shot.
Hideout.Modules = {
	Vault = { Name = "Storage vault", Desc = "Store gear and materials. Anyone who breaches your walls can strip it.", Cost = { Scrap = 10, SheetMetal = 4 }, Tier = 1 },
	Walls = { Name = "Perimeter walls", Desc = "A compound wall with a gate. Gate tier rises with your workshop tier.", Cost = { Scrap = 30, SheetMetal = 8 }, Tier = 1 },
	Alarm = { Name = "Alarm", Desc = "Tells you and your crew the moment someone hostile is inside.", Cost = { Wire = 6, Battery = 2 }, Tier = 1 },
	Turret = { Name = "Arc turret", Desc = "Shoots anything hostile within 40 studs.", Cost = { Scrap = 25, Wire = 12, Battery = 4 }, Tier = 2, Damage = 14, Range = 40, Interval = 1.1 },
	Generator = { Name = "Generator", Desc = "Powers the turret and alarm. Without it they are scrap.", Cost = { Scrap = 15, Battery = 3, Wire = 4 }, Tier = 2 },
	Forge = { Name = "Forge", Desc = "Needed for +2 and +3 upgrades.", Cost = { Scrap = 50, SheetMetal = 20, Powder = 4 }, Tier = 2 },
	Bunks = { Name = "Bunks", Desc = "Your crew spawns here instead of the city.", Cost = { Cloth = 12, Scrap = 10 }, Tier = 1 },
	Medbay = { Name = "Medbay", Desc = "Slow healing while inside the compound.", Cost = { Cloth = 10, Wire = 4, Glass = 4 }, Tier = 2 },
}
Hideout.GateTier = { "Weak", "Standard", "Reinforced" } -- by workshop tier

-- Condition: what wears, how fast, and what repairing costs (materials per 10% missing).
Hideout.Wear = {
	WeaponPerHit = 0.6, -- every landed swing
	ArmorPerHitTaken = 1.2, -- the pieces you wear, per hit you take
	CyberPerHitTaken = 0.3,
	BrokenAt = 0, -- at this condition the item stops working until repaired
}
Hideout.RepairCost = { -- per 10% of condition missing
	Weapon = { Scrap = 1, Pipe = 0.3 },
	Armor = { SheetMetal = 0.5, Cloth = 0.5 },
	Cybernetic = { Wire = 0.6, Battery = 0.2 },
}
-- Upgrade costs per level (+1, +2, +3). Weapons gain damage, armor gains resists, cybers gain their bonus.
Hideout.UpgradeCost = {
	Weapon = { { Scrap = 15, Pipe = 2 }, { Scrap = 35, SheetMetal = 6, Powder = 1 }, { Scrap = 70, SheetMetal = 12, Battery = 3, Powder = 3 } },
	Armor = { { SheetMetal = 6, Cloth = 4 }, { SheetMetal = 14, Scrap = 20 }, { SheetMetal = 28, Scrap = 40, Battery = 2 } },
	Cybernetic = { { Wire = 8, Battery = 2 }, { Wire = 16, Battery = 5, Glass = 4 }, { Wire = 30, Battery = 10, Powder = 2 } },
}
Hideout.UpgradeBonus = { Weapon = 0.12, Armor = 0.04, Cybernetic = 0.15 } -- per level: +12% damage, +4 resist points, +15% implant bonuses
Hideout.ClaimCost = { Scrap = 10 }

-- Effect of condition on an item: 1.0 at 100%, 0.5 at 1%, 0 when broken.
function Hideout.ConditionMult(condition)
	condition = condition or 100
	if condition <= Hideout.Wear.BrokenAt then
		return 0
	end
	return 0.5 + 0.5 * condition / 100
end

-- Scale a cost table by a factor and round up.
function Hideout.ScaleCost(cost, factor)
	local out = {}
	for id, n in cost do
		local v = math.ceil(n * factor)
		if v > 0 then
			out[id] = v
		end
	end
	return out
end

return Hideout
