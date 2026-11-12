local Armor = require(script.Parent.Armor)
local Cybernetics = require(script.Parent.Cybernetics)
local Weapons = require(script.Parent.Weapons)

local Items = {}

Items.Defs = {
	Scrap = { Name = "Scrap Metal", Type = "Material" },
	Wire = { Name = "Copper Wire", Type = "Material" },
	Cloth = { Name = "Torn Cloth", Type = "Material" },
	Medkit = { Name = "Medkit", Type = "Consumable", Heal = 45, Treat = "Bandage" },
	Ration = { Name = "Ration Pack", Type = "Consumable", Heal = 15, Stamina = 50, Food = 45 },
	-- treatments for the wounds (shared/Wounds.Treatments): kept when there is nothing to treat
	Bandage = { Name = "Bandage", Type = "Consumable", Treat = "Bandage" },
	Tourniquet = { Name = "Tourniquet", Type = "Consumable", Treat = "Tourniquet" },
	Hemostat = { Name = "Hemostatic Pack", Type = "Consumable", Treat = "Hemostat" },
	Splint = { Name = "Splint", Type = "Consumable", Treat = "Splint" },
	Painkillers = { Name = "Painkillers", Type = "Consumable", Treat = "Painkillers" },
	SurgeryKit = { Name = "Surgery Kit", Type = "Consumable", Treat = "SurgeryKit" },
	-- salvage materials (from broken props)
	Glass = { Name = "Glass", Type = "Material" },
	SheetMetal = { Name = "Sheet Metal", Type = "Material" },
	Pipe = { Name = "Pipe", Type = "Material" },
	Battery = { Name = "Battery", Type = "Material" },
	Powder = { Name = "Powder", Type = "Material" },
	SignPlating = { Name = "Sign Plating", Type = "Material" },
	ArcCell = { Name = "Arc Cell", Type = "Ammo" },
	-- cartridges by calibre (owner, 2026-11-12): any gun chambered for a calibre feeds on it (Weapons.Calibers)
	Round22 = { Name = ".22 LR", Type = "Ammo", Caliber = ".22" },
	Round9 = { Name = "9mm", Type = "Ammo", Caliber = "9mm" },
	Round556 = { Name = "5.56", Type = "Ammo", Caliber = "5.56" },
	Round762x39 = { Name = "7.62x39", Type = "Ammo", Caliber = "7.62x39" },
	Round762x51 = { Name = "7.62x51", Type = "Ammo", Caliber = "7.62x51" },
	-- loads inside a calibre (Weapons.Loads): Use one from the pack to load it next
	Round22Emp = { Name = ".22 EMP", Type = "Ammo", Caliber = ".22" },
	Round9AP = { Name = "9mm AP", Type = "Ammo", Caliber = "9mm" },
	Round9HP = { Name = "9mm HP", Type = "Ammo", Caliber = "9mm" },
	Round556AP = { Name = "5.56 AP", Type = "Ammo", Caliber = "5.56" },
	Round762x39AP = { Name = "7.62x39 AP", Type = "Ammo", Caliber = "7.62x39" },
	Round22Sleep = { Name = ".22 Dart", Type = "Ammo", Caliber = ".22" }, -- round 4: puts a guard to sleep
	-- round 4 (stealth): key 3 throws one; where it lands it clatters and the guards who hear go to look
	Bolt = { Name = "Bolt", Type = "Consumable", Throwable = "Bolt" },
	-- tags from the dead (round 3): what is left of a conduit's stack link on the body
	Tag = { Name = "Stack Tag", Type = "Material" },
	DutyPistol = { Name = "Duty Pistol", Type = "Weapon" },
	Carbine = { Name = "Carbine", Type = "Weapon" },
	AK47 = { Name = "AK-47", Type = "Weapon" },
	M1Garand = { Name = "M1 Garand", Type = "Weapon" },
	PipeGrenade = { Name = "Pipe Grenade", Type = "Consumable", Throwable = "Grenade" },
	BreachingCharge = { Name = "Breaching Charge", Type = "Consumable", Plantable = "Charge" },
	-- packs: worn on the back, they set the size of your grid and how much you can carry at speed
	Satchel = { Name = "Satchel", Type = "Pack", Grid = { 7, 5 }, Carry = 25, Size = { 2, 2 }, Weight = 1 },
	Rucksack = { Name = "Rucksack", Type = "Pack", Grid = { 9, 6 }, Carry = 40, Size = { 3, 3 }, Weight = 2 },
	FramePack = { Name = "Frame Pack", Type = "Pack", Grid = { 11, 7 }, Carry = 60, Size = { 3, 4 }, Weight = 3.5 },
	-- the Line 9 consignment (server/Tutorial.lua, server/Hideouts.lua): signing it at a freight-lift bay claims that
	-- site and unpacks the crates into a computer. One per life; it drops with everything else.
	-- round 5 (builds): skill chips, fitted at the hideout bench (shared/Builds.Chips), and data shards read at home.
	-- Data = true: the stack slot takes it (never materials)
	FocusChip = { Name = "Focus Chip", Type = "Chip", Data = true },
	HookChip = { Name = "Hook Chip", Type = "Chip", Data = true },
	TrailChip = { Name = "Trail Chip", Type = "Chip", Data = true },
	BreathChip = { Name = "Breath Chip", Type = "Chip", Data = true },
	MirrorChip = { Name = "Mirror Chip", Type = "Chip", Data = true },
	ArcChip = { Name = "Arc Chip", Type = "Chip", Data = true },
	DataShard = { Name = "Data Shard", Type = "Data", Data = true },
	-- round 6 (world and money): keys open locked rooms (server/Keys), fuel runs the bay's generator, cells load the
	-- shelter cage (server/Runs)
	StrongroomKey = { Name = "Strongroom Key", Type = "Key" },
	ShelterKey = { Name = "S4 Store Key", Type = "Key" },
	FuelCan = { Name = "Fuel Can", Type = "Material", Fuel = true },
	CageCell = { Name = "Cage Cell", Type = "Material" },
	Manifest = { Name = "Line 9 Manifest", Type = "Material", Size = { 1, 1 }, Weight = 0.05, Stack = 1 },
}

-- Grid footprint { w, h }, weight (kg-ish) and stack size per item. Anything not listed here takes
-- the defaults of its Type below.
local SHAPES = {
	Scrap = { Size = { 1, 1 }, Weight = 1.0, Stack = 20 },
	Wire = { Size = { 1, 1 }, Weight = 0.3, Stack = 20 },
	Cloth = { Size = { 1, 1 }, Weight = 0.2, Stack = 20 },
	Glass = { Size = { 1, 1 }, Weight = 0.4, Stack = 10 },
	SheetMetal = { Size = { 2, 1 }, Weight = 1.5, Stack = 10 },
	Pipe = { Size = { 1, 2 }, Weight = 1.5, Stack = 10 },
	Battery = { Size = { 1, 1 }, Weight = 0.8, Stack = 10 },
	Powder = { Size = { 1, 1 }, Weight = 0.3, Stack = 20 },
	SignPlating = { Size = { 2, 2 }, Weight = 2.0, Stack = 5 },
	ArcCell = { Size = { 1, 1 }, Weight = 0.1, Stack = 30 },
	Round22 = { Size = { 1, 1 }, Weight = 0.04, Stack = 50 },
	Round9 = { Size = { 1, 1 }, Weight = 0.1, Stack = 30 },
	Round22Emp = { Size = { 1, 1 }, Weight = 0.04, Stack = 50 },
	Round9AP = { Size = { 1, 1 }, Weight = 0.1, Stack = 30 },
	Round9HP = { Size = { 1, 1 }, Weight = 0.1, Stack = 30 },
	Round556AP = { Size = { 1, 1 }, Weight = 0.12, Stack = 30 },
	Round762x39AP = { Size = { 1, 1 }, Weight = 0.16, Stack = 30 },
	Tag = { Size = { 1, 1 }, Weight = 0.02, Stack = 20 },
	Round22Sleep = { Size = { 1, 1 }, Weight = 0.04, Stack = 50 },
	Bolt = { Size = { 1, 1 }, Weight = 0.15, Stack = 10 },
	FuelCan = { Size = { 1, 2 }, Weight = 2.5, Stack = 2 },
	CageCell = { Size = { 1, 1 }, Weight = 1.5, Stack = 3 },
	SootPoncho = { Size = { 2, 2 }, Weight = 0.8 },
	SentryUniform = { Size = { 2, 2 }, Weight = 1.2 },
	Round556 = { Size = { 1, 1 }, Weight = 0.12, Stack = 30 },
	Round762x39 = { Size = { 1, 1 }, Weight = 0.16, Stack = 30 },
	Round762x51 = { Size = { 1, 1 }, Weight = 0.25, Stack = 24 },
	DutyPistol = { Size = { 2, 1 }, Weight = 1.0 },
	Carbine = { Size = { 4, 2 }, Weight = 3.0 },
	AK47 = { Size = { 4, 2 }, Weight = 3.9 },
	M1Garand = { Size = { 5, 2 }, Weight = 4.3 },
	Medkit = { Size = { 1, 1 }, Weight = 0.6, Stack = 5 },
	Ration = { Size = { 1, 1 }, Weight = 0.4, Stack = 5 },
	Bandage = { Size = { 1, 1 }, Weight = 0.1, Stack = 5 },
	Tourniquet = { Size = { 1, 1 }, Weight = 0.15, Stack = 3 },
	Hemostat = { Size = { 1, 1 }, Weight = 0.2, Stack = 3 },
	Splint = { Size = { 1, 2 }, Weight = 0.4, Stack = 2 },
	Painkillers = { Size = { 1, 1 }, Weight = 0.1, Stack = 4 },
	SurgeryKit = { Size = { 2, 1 }, Weight = 1.2, Stack = 1 },
	PlateCarrier = { Size = { 3, 3 }, Weight = 6 },
	TacticalVest = { Size = { 3, 2 }, Weight = 2 },
	DutyBelt = { Size = { 2, 1 }, Weight = 0.8 },
	DropLegRig = { Size = { 2, 2 }, Weight = 1.2 },
	PipeGrenade = { Size = { 1, 1 }, Weight = 0.8, Stack = 5 },
	BreachingCharge = { Size = { 2, 1 }, Weight = 2.0, Stack = 3 },
	PipeClub = { Size = { 1, 3 }, Weight = 3 },
	RebarBlade = { Size = { 1, 3 }, Weight = 3 },
	ShockBaton = { Size = { 1, 2 }, Weight = 2 },
	ScrapSpear = { Size = { 1, 5 }, Weight = 3 },
	Sledge = { Size = { 2, 4 }, Weight = 8 },
	ArcPistol = { Size = { 2, 1 }, Weight = 1.5 },
	Whisper = { Size = { 2, 1 }, Weight = 1.2 },
	ScavHelm = { Size = { 2, 2 }, Weight = 1.5 },
	PlatedHelm = { Size = { 2, 2 }, Weight = 4 },
	ArcHood = { Size = { 2, 2 }, Weight = 1 },
	ScrapVest = { Size = { 3, 3 }, Weight = 4 },
	RiotPlate = { Size = { 3, 3 }, Weight = 9 },
	ConduitHarness = { Size = { 3, 3 }, Weight = 3 },
	ScrapGreaves = { Size = { 2, 2 }, Weight = 2.5 },
	ServoGreaves = { Size = { 2, 2 }, Weight = 3 },
	PlatedGreaves = { Size = { 2, 2 }, Weight = 5 },
}
local TYPE_DEFAULTS = {
	Material = { Size = { 1, 1 }, Weight = 0.5, Stack = 20 },
	Consumable = { Size = { 1, 1 }, Weight = 0.5, Stack = 5 },
	Ammo = { Size = { 1, 1 }, Weight = 0.1, Stack = 30 },
	Weapon = { Size = { 1, 3 }, Weight = 3, Stack = 1 },
	Armor = { Size = { 2, 2 }, Weight = 3, Stack = 1 },
	Cybernetic = { Size = { 1, 1 }, Weight = 0.5, Stack = 1 },
	Pack = { Size = { 2, 2 }, Weight = 1, Stack = 1 },
	Chip = { Size = { 1, 1 }, Weight = 0.05, Stack = 1 },
	Key = { Size = { 1, 1 }, Weight = 0.05, Stack = 3 },
	Data = { Size = { 1, 1 }, Weight = 0.05, Stack = 5 },
}
function Items.Shape(id)
	local def = Items.Defs[id]
	local base = TYPE_DEFAULTS[def and def.Type] or TYPE_DEFAULTS.Material
	local s = SHAPES[id] or {}
	return { Size = def and def.Size or s.Size or base.Size, Weight = def and def.Weight or s.Weight or base.Weight, Stack = def and def.Stack or s.Stack or base.Stack }
end
-- carried weight and the carry limit of a profile (pack or pockets); pure, so Gear can use them too
local Config = require(script.Parent.Config)
function Items.GridWeight(profile)
	local total = 0
	for _, item in (profile.Grid and profile.Grid.Items) or {} do
		total += Items.Shape(item.Id).Weight * item.Count
	end
	if profile.Pack and profile.Pack ~= "" and Items.Defs[profile.Pack] then
		total += Items.Shape(profile.Pack).Weight
	end
	return total
end
function Items.Carry(profile)
	local pack = profile.Pack and profile.Pack ~= "" and Items.Defs[profile.Pack]
	local level = if pack and profile.Upgrades then (profile.Upgrades[profile.Pack] or 0) else 0
	return if pack and pack.Carry then pack.Carry + level * Config.Inventory.CarryPerPackLevel else Config.Inventory.PocketCarry
end
-- footprint after rotation (rot 1 swaps width and height)
function Items.Footprint(id, rot)
	local size = Items.Shape(id).Size
	return if rot == 1 then size[2] else size[1], if rot == 1 then size[1] else size[2]
end

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
	Bandage = { Output = "Bandage", Count = 2, Inputs = { Cloth = 1 } },
	Tourniquet = { Output = "Tourniquet", Count = 1, Inputs = { Cloth = 1, Wire = 1 } },
	Splint = { Output = "Splint", Count = 1, Inputs = { Cloth = 1, Pipe = 1 } },
	TacticalVest = { Output = "TacticalVest", Count = 1, Inputs = { Cloth = 6, Wire = 2 } },
	DutyBelt = { Output = "DutyBelt", Count = 1, Inputs = { Cloth = 3, Scrap = 2 } },
	DropLegRig = { Output = "DropLegRig", Count = 1, Inputs = { Cloth = 4, Scrap = 2, Wire = 1 } },
	Satchel = { Output = "Satchel", Count = 1, Inputs = { Cloth = 4, Scrap = 1 } },
	Rucksack = { Output = "Rucksack", Count = 1, Inputs = { Cloth = 8, Scrap = 4, Wire = 2 } },
	FramePack = { Output = "FramePack", Count = 1, Inputs = { Cloth = 10, SheetMetal = 2, Wire = 4, Pipe = 2 } },
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
	Round22 = { Output = "Round22", Count = 10, Inputs = { Powder = 1, Scrap = 1 } },
	Round9 = { Output = "Round9", Count = 6, Inputs = { Powder = 1, Scrap = 1 } },
	Round22Emp = { Output = "Round22Emp", Count = 6, Inputs = { Powder = 1, Battery = 1 } },
	Round9HP = { Output = "Round9HP", Count = 6, Inputs = { Powder = 1, Scrap = 1, Wire = 1 } },
	Round22Sleep = { Output = "Round22Sleep", Count = 4, Inputs = { Powder = 1, Glass = 1 } },
	Bolt = { Output = "Bolt", Count = 3, Inputs = { Scrap = 1 } },
	SootPoncho = { Output = "SootPoncho", Count = 1, Inputs = { Cloth = 4, Powder = 1 } },
	Round556 = { Output = "Round556", Count = 4, Inputs = { Powder = 1, Scrap = 1 } },
	Round762x39 = { Output = "Round762x39", Count = 4, Inputs = { Powder = 1, Scrap = 1 } },
	Round762x51 = { Output = "Round762x51", Count = 3, Inputs = { Powder = 1, Scrap = 1 } },
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
		{ "Medkit", 0.5, 1, 2 }, { "Ration", 0.6, 1, 2 }, { "Bandage", 0.5, 1, 2 }, { "Tourniquet", 0.2, 1, 1 }, { "Splint", 0.15, 1, 1 },
		{ "Painkillers", 0.2, 1, 2 }, { "Hemostat", 0.1, 1, 1 }, { "FuelCan", 0.25, 1, 1 },
		{ "RebarBlade", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 }, { "ScrapSpear", 0.12, 1, 1 }, { "Sledge", 0.06, 1, 1 }, { "ArcPistol", 0.05, 1, 1 },
		{ "PlatedHelm", 0.1, 1, 1 }, { "RiotPlate", 0.06, 1, 1 }, { "ArcHood", 0.08, 1, 1 }, { "ConduitHarness", 0.04, 1, 1 }, { "ServoGreaves", 0.07, 1, 1 },
		{ "ReflexOptic", 0.06, 1, 1 }, { "TargetingLens", 0.05, 1, 1 }, { "ServoArm", 0.05, 1, 1 }, { "ArcGauntlet", 0.04, 1, 1 }, { "NeuralCore", 0.04, 1, 1 }, { "OverclockCore", 0.02, 1, 1 },
		{ "AudioPickup", 0.05, 1, 1 }, { "ChemSniffer", 0.05, 1, 1 }, { "StriderLeg", 0.05, 1, 1 }, { "PistonLeg", 0.03, 1, 1 }, { "PlatedCore", 0.03, 1, 1 },
	},
	Vault = {
		{ "Scrap", 1, 6, 12 }, { "Wire", 1, 3, 6 }, { "Battery", 0.8, 1, 3 }, { "Powder", 0.7, 2, 4 }, { "ArcCell", 0.8, 6, 12 },
		{ "Medkit", 0.8, 1, 3 }, { "BreachingCharge", 0.5, 1, 1 }, { "PipeGrenade", 0.5, 1, 3 },
		{ "Hemostat", 0.4, 1, 2 }, { "SurgeryKit", 0.2, 1, 1 }, { "Painkillers", 0.4, 1, 2 }, { "PlateCarrier", 0.2, 1, 1 },
		{ "Sledge", 0.2, 1, 1 }, { "ArcPistol", 0.2, 1, 1 }, { "RiotPlate", 0.15, 1, 1 }, { "ConduitHarness", 0.12, 1, 1 },
		{ "ReflexOptic", 0.12, 1, 1 }, { "ServoArm", 0.12, 1, 1 }, { "NeuralCore", 0.1, 1, 1 }, { "OverclockCore", 0.05, 1, 1 },
		{ "EchoArray", 0.08, 1, 1 }, { "BloodTracer", 0.08, 1, 1 }, { "PistonLeg", 0.08, 1, 1 }, { "PlatedCore", 0.08, 1, 1 },
	},
	-- the frontier's relic sites: the only place some gear turns up reliably (server/Frontier.lua)
	Relic = {
		{ "ArcCell", 1, 10, 20 }, { "Medkit", 1, 2, 3 }, { "BreachingCharge", 0.6, 1, 2 }, { "PipeGrenade", 0.6, 2, 3 },
		{ "SurgeryKit", 0.35, 1, 1 }, { "Hemostat", 0.5, 1, 2 },
		{ "ArcPistol", 0.5, 1, 1 }, { "Sledge", 0.3, 1, 1 }, { "RiotPlate", 0.35, 1, 1 }, { "ConduitHarness", 0.4, 1, 1 }, { "PlatedHelm", 0.35, 1, 1 },
		{ "NeuralCore", 0.4, 1, 1 }, { "OverclockCore", 0.3, 1, 1 }, { "PistonLeg", 0.4, 1, 1 }, { "PlatedCore", 0.4, 1, 1 }, { "EchoArray", 0.3, 1, 1 },
		{ "BloodTracer", 0.3, 1, 1 }, { "TargetingLens", 0.35, 1, 1 }, { "ArcGauntlet", 0.35, 1, 1 }, { "FramePack", 0.15, 1, 1 },
		{ "DataShard", 0.6, 1, 2 }, { "FocusChip", 0.12, 1, 1 }, { "TrailChip", 0.12, 1, 1 }, { "ArcChip", 0.1, 1, 1 }, { "BreathChip", 0.12, 1, 1 },
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
	Rival = {
		{ "Scrap", 0.8, 1, 3 }, { "Wire", 0.6, 1, 3 }, { "Medkit", 0.45, 1, 1 }, { "ArcCell", 0.5, 4, 8 }, { "Ration", 0.4, 1, 2 },
		{ "RebarBlade", 0.1, 1, 1 }, { "PlatedHelm", 0.08, 1, 1 }, { "ConduitHarness", 0.05, 1, 1 }, { "ReflexOptic", 0.05, 1, 1 }, { "PipeGrenade", 0.2, 1, 1 },
		{ "Round762x51", 0.3, 5, 16 }, { "M1Garand", 0.08, 1, 1 },
		{ "DataShard", 0.25, 1, 1 }, { "TrailChip", 0.03, 1, 1 }, { "FocusChip", 0.03, 1, 1 }, { "StrongroomKey", 0.06, 1, 1 }, -- a crew that works the valley keeps a long rifle
	},
	-- station sentries carry what security carries: 9mm for a sidearm (sometimes the sidearm itself) or 5.56 for a
	-- rifle (sometimes the carbine itself), never the .22 a conduit's quiet pistol takes (owner, 2026-11-12)
	Sentry = {
		{ Pick = {
			{ Weight = 0.65, Items = { { "Round9", 1, 8, 15 }, { "Round9HP", 0.15, 4, 8 }, { "DutyPistol", 0.3, 1, 1 } } },
			{ Weight = 0.35, Items = { { "Round556", 1, 15, 30 }, { "Round556AP", 0.12, 5, 10 }, { "Carbine", 0.35, 1, 1 } } },
		} },
		{ "Scrap", 0.8, 1, 2 }, { "Ration", 0.45, 1, 1 }, { "Cloth", 0.4, 1, 2 }, { "Wire", 0.3, 1, 2 },
		{ "Medkit", 0.15, 1, 1 }, { "ShockBaton", 0.08, 1, 1 }, { "Bandage", 0.35, 1, 2 }, { "Tourniquet", 0.12, 1, 1 },
		{ "PlateCarrier", 0.06, 1, 1 }, { "DutyBelt", 0.12, 1, 1 }, -- security's own kit
		{ "SentryUniform", 0.1, 1, 1 }, { "Bolt", 0.3, 1, 3 }, { "StrongroomKey", 0.04, 1, 1 },
	},
	-- the barrens under the Sumps (server/Barrens.lua): the stores of the hall, rich in implants and cells
	Barrens = {
		{ "ArcCell", 1, 10, 20 }, { "Battery", 0.9, 2, 4 }, { "Wire", 0.8, 3, 6 }, { "Medkit", 0.6, 1, 2 },
		{ "SurgeryKit", 0.25, 1, 1 }, { "Hemostat", 0.4, 1, 1 }, { "Splint", 0.3, 1, 1 },
		{ "ReflexOptic", 0.3, 1, 1 }, { "TargetingLens", 0.3, 1, 1 }, { "AudioPickup", 0.3, 1, 1 }, { "ChemSniffer", 0.3, 1, 1 },
		{ "ServoArm", 0.3, 1, 1 }, { "ArcGauntlet", 0.25, 1, 1 }, { "NeuralCore", 0.3, 1, 1 }, { "OverclockCore", 0.2, 1, 1 },
		{ "PlatedCore", 0.2, 1, 1 }, { "StriderLeg", 0.25, 1, 1 }, { "PistonLeg", 0.2, 1, 1 }, { "EchoArray", 0.2, 1, 1 }, { "BloodTracer", 0.2, 1, 1 },
		{ "DataShard", 0.5, 1, 2 }, { "HookChip", 0.1, 1, 1 }, { "MirrorChip", 0.1, 1, 1 }, { "BreathChip", 0.08, 1, 1 },
	},
	-- the hall's overseers' pockets
	Overseer = {
		{ "Round9", 0.8, 4, 10 }, { "Round9AP", 0.2, 3, 8 }, { "ArcCell", 0.7, 3, 8 }, { "Battery", 0.5, 1, 2 }, { "Medkit", 0.35, 1, 1 }, { "Ration", 0.4, 1, 1 },
		{ "ShockBaton", 0.12, 1, 1 }, { "ReflexOptic", 0.06, 1, 1 }, { "NeuralCore", 0.05, 1, 1 },
		{ "Round22Sleep", 0.25, 3, 6 }, { "SentryUniform", 0.08, 1, 1 },
		{ "DataShard", 0.3, 1, 1 }, { "MirrorChip", 0.04, 1, 1 }, { "HookChip", 0.04, 1, 1 }, { "ShelterKey", 0.1, 1, 1 },
	},
	Raider = {
		{ "Scrap", 0.9, 1, 3 }, { "Cloth", 0.5, 1, 2 }, { "Wire", 0.35, 1, 2 }, { "Ration", 0.3, 1, 1 }, { "Bandage", 0.3, 1, 1 },
		{ "PipeClub", 0.1, 1, 1 }, { "ScavHelm", 0.08, 1, 1 }, { "ScrapVest", 0.08, 1, 1 }, { "ScrapGreaves", 0.08, 1, 1 },
		{ "ChemSniffer", 0.03, 1, 1 },
		{ "Round762x39", 0.3, 6, 18 }, { "Round762x39AP", 0.08, 4, 10 }, { "AK47", 0.05, 1, 1 }, { "StrongroomKey", 0.02, 1, 1 }, { "FuelCan", 0.08, 1, 1 }, -- the gun every scavenger can keep running
	},
}

local rng = Random.new()
function Items.Roll(tableName)
	local result = {}
	local function roll(entries)
		for _, entry in entries do
			if entry.Pick then
				-- exactly one of several bundles, by weight (a guard carries pistol rounds or rifle rounds, not both)
				local total = 0
				for _, option in entry.Pick do
					total += option.Weight or 1
				end
				local at = rng:NextNumber() * total
				for _, option in entry.Pick do
					at -= option.Weight or 1
					if at <= 0 then
						roll(option.Items)
						break
					end
				end
			elseif rng:NextNumber() <= entry[2] then
				result[entry[1]] = (result[entry[1]] or 0) + rng:NextInteger(entry[3], entry[4])
			end
		end
	end
	roll(Items.LootTables[tableName] or {})
	return result
end

return Items
