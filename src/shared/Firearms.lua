-- Cold War era firearms for the Front (war world). Every gun is simulated as parts with their
-- own condition, and as a mechanical state: a chamber, a magazine, a bolt, a safety and a
-- selector. Nothing fires unless the mechanism says it can. Numbers are tuned for a TTK of
-- 2-4 torso hits at rifle range; everything here is a starting point for playtesting.
local Firearms = {}

-- Parts every gun has. Condition 0-100 on each; what wearing out does is per part:
--   Barrel    -> accuracy (spread) and velocity        Bolt   -> malfunction chance
--   Receiver  -> malfunction chance                     Magazine -> feed failures
--   Stock     -> recoil control                         Optic   -> sight picture (attachment)
Firearms.Parts = { "Receiver", "Barrel", "Bolt", "Magazine", "Stock" }

-- Ammo: velocity (studs/s), damage at the muzzle, falloff to this fraction at Range, armor penetration.
Firearms.Ammo = {
	["7.62x39"] = { Velocity = 715 * 3.3, Damage = 48, Range = 400, Falloff = 0.65, Pen = 0.55, Mass = 8 },
	["5.56x45"] = { Velocity = 960 * 3.3, Damage = 38, Range = 450, Falloff = 0.6, Pen = 0.5, Mass = 4 },
	["9x18"] = { Velocity = 315 * 3.3, Damage = 26, Range = 60, Falloff = 0.5, Pen = 0.2, Mass = 6 },
	[".45ACP"] = { Velocity = 260 * 3.3, Damage = 34, Range = 60, Falloff = 0.5, Pen = 0.2, Mass = 15 },
	["7.62x51"] = { Velocity = 840 * 3.3, Damage = 62, Range = 600, Falloff = 0.7, Pen = 0.7, Mass = 10 },
	["7.62x54R"] = { Velocity = 830 * 3.3, Damage = 70, Range = 800, Falloff = 0.75, Pen = 0.75, Mass = 10 },
}

-- Modes: which selector positions exist. RPM, Recoil (vertical, horizontal per shot), Spread
-- (base cone in degrees, hip), ADS multiplier, Reload stages in seconds, Faction (shop side).
Firearms.Defs = {
	AKM = { Name = "AKM", Class = "Rifle", Ammo = "7.62x39", MagSize = 30, Modes = { "Safe", "Auto", "Semi" }, RPM = 600,
		Recoil = { 1.9, 0.9 }, Spread = 2.4, AdsSpread = 0.45, Ergonomics = 0.55, Weight = 3.5, Faction = "Pact", Price = 900,
		Reload = { EjectMag = 0.6, InsertMag = 0.9, Rack = 0.5 }, Slots = { "Optic", "Muzzle", "Grip" } },
	M16A1 = { Name = "M16A1", Class = "Rifle", Ammo = "5.56x45", MagSize = 20, Modes = { "Safe", "Semi", "Auto" }, RPM = 750,
		Recoil = { 1.2, 0.6 }, Spread = 1.9, AdsSpread = 0.35, Ergonomics = 0.65, Weight = 3.0, Faction = "Union", Price = 950,
		Reload = { EjectMag = 0.5, InsertMag = 0.8, Rack = 0.45 }, Slots = { "Optic", "Muzzle", "Grip" } },
	SKS = { Name = "SKS", Class = "Carbine", Ammo = "7.62x39", MagSize = 10, Modes = { "Safe", "Semi" }, RPM = 400,
		Recoil = { 1.6, 0.7 }, Spread = 1.8, AdsSpread = 0.3, Ergonomics = 0.6, Weight = 3.8, Faction = "Pact", Price = 500,
		Reload = { EjectMag = 0.4, InsertMag = 1.4, Rack = 0.5 }, Slots = { "Optic" } },
	M14 = { Name = "M14", Class = "Battle Rifle", Ammo = "7.62x51", MagSize = 20, Modes = { "Safe", "Semi", "Auto" }, RPM = 700,
		Recoil = { 2.6, 1.1 }, Spread = 1.7, AdsSpread = 0.3, Ergonomics = 0.5, Weight = 4.1, Faction = "Union", Price = 1200,
		Reload = { EjectMag = 0.6, InsertMag = 0.9, Rack = 0.5 }, Slots = { "Optic", "Muzzle" } },
	Mosin = { Name = "Mosin-Nagant", Class = "Bolt Action", Ammo = "7.62x54R", MagSize = 5, Modes = { "Safe", "Semi" }, RPM = 40, BoltAction = true,
		Recoil = { 4.5, 1.5 }, Spread = 1.2, AdsSpread = 0.15, Ergonomics = 0.45, Weight = 4.0, Faction = "Pact", Price = 700,
		Reload = { EjectMag = 0, InsertMag = 2.4, Rack = 0.8 }, Slots = { "Optic" } },
	Makarov = { Name = "Makarov PM", Class = "Pistol", Ammo = "9x18", MagSize = 8, Modes = { "Safe", "Semi" }, RPM = 350,
		Recoil = { 1.1, 0.5 }, Spread = 2.8, AdsSpread = 0.6, Ergonomics = 0.85, Weight = 0.7, Faction = "Pact", Price = 250,
		Reload = { EjectMag = 0.4, InsertMag = 0.6, Rack = 0.35 }, Slots = {} },
	M1911 = { Name = "M1911A1", Class = "Pistol", Ammo = ".45ACP", MagSize = 7, Modes = { "Safe", "Semi" }, RPM = 350,
		Recoil = { 1.5, 0.6 }, Spread = 2.6, AdsSpread = 0.55, Ergonomics = 0.85, Weight = 1.1, Faction = "Union", Price = 300,
		Reload = { EjectMag = 0.4, InsertMag = 0.6, Rack = 0.35 }, Slots = {} },
}

-- Attachments change the numbers; they are parts too (condition applies).
Firearms.Attachments = {
	IronSights = { Name = "Iron sights", Slot = "Optic", Zoom = 1, Price = 0 },
	PSO = { Name = "PSO-1 4x", Slot = "Optic", Zoom = 4, AdsTime = 0.15, Faction = "Pact", Price = 400 },
	Colt3x = { Name = "Colt 3x scope", Slot = "Optic", Zoom = 3, AdsTime = 0.12, Faction = "Union", Price = 380 },
	Suppressor = { Name = "Suppressor", Slot = "Muzzle", Loudness = 0.35, Velocity = 0.95, Recoil = 0.9, Price = 450 },
	Compensator = { Name = "Compensator", Slot = "Muzzle", Recoil = 0.8, Loudness = 1.2, Price = 220 },
	Foregrip = { Name = "Foregrip", Slot = "Grip", Recoil = 0.85, Ergonomics = 0.1, Price = 180 },
}

-- Body armor for recruits: plates stop a share of bullet damage, pen eats into that.
Firearms.Armor = {
	FlakVest = { Name = "Flak vest", Protection = 0.25, Durability = 60, Weight = 2, Price = 300 },
	SteelPlate = { Name = "Steel plate carrier", Protection = 0.5, Durability = 100, Weight = 7, Price = 900 },
	Helmet = { Name = "Steel helmet", Protection = 0.3, Durability = 40, Weight = 1.5, Price = 250, Head = true },
}

-- Hit zone damage multipliers.
Firearms.Zones = { Head = 2.5, Torso = 1.0, Limb = 0.6 }

-- Condition -> effect helpers (all pure; the client uses them for the inspect screen too).
function Firearms.MalfunctionChance(parts)
	local worst = math.min(parts.Receiver or 100, parts.Bolt or 100)
	local mag = parts.Magazine or 100
	-- a mint gun jams ~0.2% of shots; at 30% condition about 6%; a wrecked magazine misfeeds often
	return 0.002 + (1 - worst / 100) ^ 2 * 0.12 + (1 - mag / 100) ^ 2 * 0.1
end

function Firearms.SpreadMult(parts)
	return 1 + (1 - (parts.Barrel or 100) / 100) * 1.5
end

function Firearms.RecoilMult(parts)
	return 1 + (1 - (parts.Stock or 100) / 100) * 0.6
end

function Firearms.RepairCost(def, parts)
	local missing = 0
	for _, name in Firearms.Parts do
		missing += 100 - (parts[name] or 100)
	end
	return math.ceil(def.Price * 0.004 * missing)
end

return Firearms
