-- Destructible world props and breach points (docs/systems/destruction-and-salvage.md).
-- Fractures are authored, not computed: each prop lists the chunks it breaks into. Until real
-- models exist the server builds both the intact prop and its chunks from these part lists.
local Props = {}

-- Damage types that can break the world. Combat maps weapon families onto these.
Props.DamageTypes = { "Blunt", "Blade", "Arc", "Thrown", "Explosive", "Sledge" }

-- Weight classes for grabbable chunks.
Props.Weights = {
	Light = { Speed = 90, Damage = 14, Posture = 10, Stamina = 10, Knockback = 25, SpeedMult = 1, CanBlock = true },
	Medium = { Speed = 60, Damage = 26, Posture = 22, Stamina = 22, Knockback = 40, SpeedMult = 0.8, CanBlock = false },
	Heavy = { Speed = 40, Damage = 45, Posture = 40, Stamina = 35, Knockback = 60, SpeedMult = 0.55, CanBlock = false, StrengthReq = 15 },
}

local CONCRETE, METAL, GLASS, NEON = Enum.Material.Concrete, Enum.Material.Metal, Enum.Material.Glass, Enum.Material.Neon

-- Parts: intact model pieces (Size, Offset from the prop origin, Color, Material, Transparency?).
-- Chunks: what it breaks into { Name, Weight, Size, Color, Material, Improvised? (usable as a club), Durability }.
-- Resist: per damage type, 0-1. Salvage: loot table in Items.LootTables.
Props.Defs = {
	Streetlight = {
		Health = 60, Resist = { Blade = 0.8, Arc = 0 }, Salvage = "Streetlight",
		Parts = {
			{ Size = Vector3.new(0.8, 14, 0.8), Offset = Vector3.new(0, 7, 0), Color = Color3.fromRGB(70, 72, 80), Material = METAL },
			{ Size = Vector3.new(3, 0.6, 1), Offset = Vector3.new(1.2, 13.8, 0), Color = Color3.fromRGB(70, 72, 80), Material = METAL },
			{ Size = Vector3.new(1.6, 0.4, 0.8), Offset = Vector3.new(2.2, 13.4, 0), Color = Color3.fromRGB(255, 240, 200), Material = NEON, Light = true },
		},
		Chunks = {
			{ Name = "Pipe", Weight = "Light", Size = Vector3.new(0.8, 6, 0.8), Color = Color3.fromRGB(70, 72, 80), Material = METAL, Improvised = true, Durability = 6 },
			{ Name = "Pipe", Weight = "Light", Size = Vector3.new(0.8, 5, 0.8), Color = Color3.fromRGB(70, 72, 80), Material = METAL, Improvised = true, Durability = 6 },
			{ Name = "Light Head", Weight = "Medium", Size = Vector3.new(3, 1, 1), Color = Color3.fromRGB(90, 90, 100), Material = METAL },
		},
	},
	StreetSign = {
		Health = 35, Resist = { Arc = 0.6 }, Salvage = "Sign",
		Parts = {
			{ Size = Vector3.new(0.3, 8, 0.3), Offset = Vector3.new(0, 4, 0), Color = Color3.fromRGB(80, 80, 85), Material = METAL },
			{ Size = Vector3.new(3, 2, 0.2), Offset = Vector3.new(0, 7.5, 0), Color = Color3.fromRGB(40, 120, 60), Material = METAL },
		},
		Chunks = {
			{ Name = "Sign Plate", Weight = "Light", Size = Vector3.new(3, 2, 0.2), Color = Color3.fromRGB(40, 120, 60), Material = METAL, Improvised = true, Durability = 5 },
			{ Name = "Pipe", Weight = "Light", Size = Vector3.new(0.3, 5, 0.3), Color = Color3.fromRGB(80, 80, 85), Material = METAL, Improvised = true, Durability = 4 },
		},
	},
	Crate = {
		Health = 25, Resist = {}, Salvage = "Crate",
		Parts = { { Size = Vector3.new(3, 3, 3), Offset = Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(110, 85, 50), Material = Enum.Material.WoodPlanks } },
		Chunks = {
			{ Name = "Plank", Weight = "Light", Size = Vector3.new(3, 0.3, 1), Color = Color3.fromRGB(110, 85, 50), Material = Enum.Material.WoodPlanks, Improvised = true, Durability = 3 },
			{ Name = "Plank", Weight = "Light", Size = Vector3.new(3, 0.3, 1), Color = Color3.fromRGB(110, 85, 50), Material = Enum.Material.WoodPlanks },
		},
	},
	Barrel = {
		Health = 40, Resist = { Blade = 0.5 }, Salvage = "Barrel", Volatile = true, -- Volatile: explodes when broken by Explosive/Arc
		Parts = { { Size = Vector3.new(2.5, 3.5, 2.5), Offset = Vector3.new(0, 1.75, 0), Color = Color3.fromRGB(140, 50, 40), Material = METAL, Shape = Enum.PartType.Cylinder, Vertical = true } },
		Chunks = { { Name = "Barrel Lid", Weight = "Light", Size = Vector3.new(2.4, 0.2, 2.4), Color = Color3.fromRGB(140, 50, 40), Material = METAL } },
	},
	FencePanel = {
		Health = 45, Resist = { Blade = 0.4, Arc = 0.7 }, Salvage = "Fence",
		Parts = { { Size = Vector3.new(6, 5, 0.3), Offset = Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(90, 95, 100), Material = Enum.Material.DiamondPlate, Transparency = 0.3 } },
		Chunks = {
			{ Name = "Fence Post", Weight = "Light", Size = Vector3.new(0.4, 5, 0.4), Color = Color3.fromRGB(90, 95, 100), Material = METAL, Improvised = true, Durability = 5 },
			{ Name = "Fence Mesh", Weight = "Medium", Size = Vector3.new(4, 3, 0.3), Color = Color3.fromRGB(90, 95, 100), Material = Enum.Material.DiamondPlate },
		},
	},
	VendingMachine = {
		Health = 90, Resist = { Blade = 0.6 }, Salvage = "Vending",
		Parts = {
			{ Size = Vector3.new(3.5, 7, 3), Offset = Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(40, 60, 120), Material = METAL },
			{ Size = Vector3.new(2.5, 4, 0.2), Offset = Vector3.new(0, 4, -1.5), Color = Color3.fromRGB(120, 200, 255), Material = GLASS, Transparency = 0.4 },
		},
		Chunks = {
			{ Name = "Vending Machine", Weight = "Heavy", Size = Vector3.new(3.5, 7, 3), Color = Color3.fromRGB(40, 60, 120), Material = METAL },
			{ Name = "Glass Shard", Weight = "Light", Size = Vector3.new(1.2, 1.2, 0.2), Color = Color3.fromRGB(120, 200, 255), Material = GLASS },
		},
	},
	Terminal = {
		Health = 50, Resist = { Blade = 0.5 }, Salvage = "Terminal",
		Parts = {
			{ Size = Vector3.new(2, 4.5, 1.2), Offset = Vector3.new(0, 2.25, 0), Color = Color3.fromRGB(50, 50, 60), Material = METAL },
			{ Size = Vector3.new(1.5, 1, 0.2), Offset = Vector3.new(0, 3.5, -0.7), Color = Color3.fromRGB(0, 220, 255), Material = NEON, Light = true },
		},
		Chunks = { { Name = "Casing", Weight = "Medium", Size = Vector3.new(2, 2, 1.2), Color = Color3.fromRGB(50, 50, 60), Material = METAL } },
	},
	CarWreck = {
		Health = 120, Resist = { Blade = 0.7, Arc = 0.3 }, Salvage = "Car",
		Parts = {
			{ Size = Vector3.new(6, 2.5, 12), Offset = Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(70, 65, 60), Material = Enum.Material.CorrodedMetal },
			{ Size = Vector3.new(5, 1.8, 5), Offset = Vector3.new(0, 3.6, -1), Color = Color3.fromRGB(60, 55, 50), Material = Enum.Material.CorrodedMetal },
		},
		Chunks = {
			{ Name = "Car Door", Weight = "Medium", Size = Vector3.new(0.3, 2.5, 4), Color = Color3.fromRGB(70, 65, 60), Material = Enum.Material.CorrodedMetal },
			{ Name = "Car Hood", Weight = "Medium", Size = Vector3.new(5, 0.3, 4), Color = Color3.fromRGB(70, 65, 60), Material = Enum.Material.CorrodedMetal },
			{ Name = "Car Body", Weight = "Heavy", Size = Vector3.new(6, 2, 8), Color = Color3.fromRGB(60, 55, 50), Material = Enum.Material.CorrodedMetal },
		},
	},
	WindowPane = {
		Health = 10, Resist = {}, Salvage = "Window", Cosmetic = true, -- tiny props don't leave grabbable chunks
		Parts = { { Size = Vector3.new(6, 6, 0.2), Offset = Vector3.new(0, 3, 0), Color = Color3.fromRGB(120, 180, 220), Material = GLASS, Transparency = 0.5 } },
		Chunks = {},
	},
	Slab = {
		Health = 200, Resist = { Blade = 0.9, Arc = 0.9, Blunt = 0.3 }, Salvage = "Slab",
		Parts = { { Size = Vector3.new(6, 1.2, 4), Offset = Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(95, 95, 100), Material = CONCRETE } },
		Chunks = { { Name = "Concrete Slab", Weight = "Heavy", Size = Vector3.new(6, 1.2, 4), Color = Color3.fromRGB(95, 95, 100), Material = CONCRETE } },
	},
}

-- Breach point tiers. Allowed: damage types that can damage it at all.
Props.BreachTiers = {
	Weak = { Health = 60, Allowed = { Blunt = true, Thrown = true, Explosive = true, Sledge = true }, Color = Color3.fromRGB(110, 85, 50), Material = Enum.Material.WoodPlanks, Label = "Boarded door" },
	Standard = { Health = 160, Allowed = { Sledge = true, Explosive = true }, Color = Color3.fromRGB(80, 80, 90), Material = METAL, Label = "Steel door" },
	Reinforced = { Health = 300, Allowed = { Explosive = true }, Color = Color3.fromRGB(50, 55, 70), Material = Enum.Material.DiamondPlate, Label = "Reinforced shutter" },
	Sealed = { Health = math.huge, Allowed = {}, Color = Color3.fromRGB(20, 20, 30), Material = METAL, Label = "Sealed vault" },
}

return Props
