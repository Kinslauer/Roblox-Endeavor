-- Asset registry for models built in Blender (tools/models) and uploaded through Open Cloud.
-- Props come in conditions: A intact, B worn, C wrecked. A spawn (and every rematerialization)
-- picks one at random, so the city never comes back quite the same. 0 / missing = not uploaded:
-- the game falls back to generated geometry.
local Assets = {}

Assets.Props = {
	Barrel = { A = 138973181515358, B = 79636233128816, C = 125842135926276 },
	CarWreck = { A = 135300185326024, B = 124730379936688, C = 93646164483240 },
	Crate = { A = 109129830991009, B = 138128084039228, C = 134823881595914 },
	FencePanel = { A = 135294127218303, B = 137469842853638, C = 88889940788521 },
	Slab = { A = 93218341089544, B = 85304351471716, C = 74338036722155 },
	StreetSign = { A = 81980116475569, B = 133194607355983, C = 135676038796551 },
	Streetlight = { A = 113165102986052 },
	Terminal = { A = 94139217691513, B = 79807106490326, C = 132427649381419 },
	VendingMachine = { A = 138968722251708, B = 93355970908453, C = 132176714647904 },
	WindowPane = { A = 93084252250236, B = 86227491449117, C = 107425218490351 },
}

Assets.Chunks = {
	LampHead = 102315743005097,
	PipeLong = 97783263877959,
	PipeShort = 136810514088811,
}

-- Buildings per district style: [style] = { { Id, Height, Collapsed } ... }. City.tower picks one whose
-- height class fits the district and rolls Collapsed by the district's Collapse chance.
Assets.Buildings = {
	Transit = {
		{ Id = 127292690964822, Height = 16, Collapsed = false },
		{ Id = 123328971264435, Height = 28, Collapsed = false },
		{ Id = 126527051147462, Height = 40, Collapsed = false },
		{ Id = 140082823721054, Height = 16, Collapsed = true },
		{ Id = 80388090754028, Height = 28, Collapsed = true },
		{ Id = 124529424193237, Height = 40, Collapsed = true },
	},
	Corp = {
		{ Id = 100673641895848, Height = 44, Collapsed = false },
		{ Id = 102115072037501, Height = 76, Collapsed = false },
		{ Id = 131917010107929, Height = 108, Collapsed = false },
		{ Id = 83480503628071, Height = 44, Collapsed = true },
		{ Id = 136541096106617, Height = 76, Collapsed = true },
		{ Id = 109374262907940, Height = 108, Collapsed = true },
	},
	Sprawl = {
		{ Id = 105370784022791, Height = 9, Collapsed = false },
		{ Id = 106326847400008, Height = 15, Collapsed = false },
		{ Id = 104460521756486, Height = 22, Collapsed = false },
		{ Id = 109508146985957, Height = 9, Collapsed = true },
		{ Id = 107665691190154, Height = 15, Collapsed = true },
		{ Id = 122556073961573, Height = 22, Collapsed = true },
	},
	Blackout = {
		{ Id = 116818105369683, Height = 22, Collapsed = false },
		{ Id = 117319727727542, Height = 46, Collapsed = false },
		{ Id = 114976683337134, Height = 70, Collapsed = false },
		{ Id = 98793224659140, Height = 22, Collapsed = true },
		{ Id = 120670767685060, Height = 46, Collapsed = true },
		{ Id = 114306096688948, Height = 70, Collapsed = true },
	},
	Outskirts = {
		{ Id = 77282177830136, Height = 7, Collapsed = false },
		{ Id = 119170534861661, Height = 11, Collapsed = false },
		{ Id = 86369990451471, Height = 16, Collapsed = false },
		{ Id = 71479955444102, Height = 7, Collapsed = true },
		{ Id = 90300686818780, Height = 11, Collapsed = true },
		{ Id = 128795308345139, Height = 16, Collapsed = true },
	},
}

-- Character rigs (R15 limb meshes, see server/Rigs.lua): [npcType] = assetId
Assets.Rigs = {
	Raider = 106712459976546,
	Brute = 89905917757019,
	Shocker = 117184966040084,
	Warden = 80181254073544,
}

-- Weapons held in the right hand (see server/HeldWeapons.lua): [weaponId] = { Id, Grip }
-- Grip "Melee" (default): business end along Roblox +Z from the grip; "Pistol": grip along -Z, barrel along +Y.
Assets.Weapons = {
	PipeClub = { Id = 98352702068074 },
	RebarBlade = { Id = 109978068606651 },
	ShockBaton = { Id = 90209087116064 },
	ScrapSpear = { Id = 103214457247078 },
	Sledge = { Id = 140412858794705 },
	ArcPistol = { Id = 137041276570028, Grip = "Pistol" },
	-- the Front's firearms (tools/models/firearms.py): grip at the origin, barrel along Roblox +Z
	AKM = { Id = 92592283500275, Grip = "Rifle" },
	M16A1 = { Id = 75033829373197, Grip = "Rifle" },
	SKS = { Id = 113075471282186, Grip = "Rifle" },
	M14 = { Id = 95671280962993, Grip = "Rifle" },
	Mosin = { Id = 75786990315304, Grip = "Rifle" },
	Makarov = { Id = 132304088878022, Grip = "Rifle" },
	M1911 = { Id = 79755833559332, Grip = "Rifle" },
}

-- The Front's battlefield props (see war/server/Battlefield.lua and Soldiers.lua), tools/models/front.py.
-- Sandbags/Truck have condition variants A (fresh) / B (torn, gutted); the rest are single models.
Assets.Front = {
	Sandbags = { A = 95928144285816, B = 132747554423751 },
	LowSandbags = 98333994567972,
	Truck = { A = 100644987503518, B = 98573307241675 },
	Hedgehog = 102101837213656,
	AmmoCrate = 89789308888628,
}

-- The Front's staged buildings (tools/models/front_buildings.py): Stages[1..4] = intact, damaged,
-- ruined, rubble. Battlefield picks the kit nearest the footprint it wanted.
Assets.FrontBuildings = {
	Farmhouse = { Width = 18, Depth = 16, Height = 9, Stages = { 90952332269870, 106074559329466, 77239609557564, 116251743217738 } },
	Hall = { Width = 24, Depth = 20, Height = 12, Stages = { 72519396548568, 83800228553052, 94898623532790, 99432007888838 } },
}

-- Hideout modules (tools/models/hideout.py, server/Hideouts.lua): the mesh rides inside the module's
-- collider part, which turns invisible. Bench[tier] follows the hideout tier.
Assets.Hideout = {
	Bench = { 103394639391010, 139720531727657, 91895806024932 },
	Vault = 105765126742613,
	Bunks = 103383159042765,
	Generator = 117479185712477,
	Turret = 105708684013715,
	Forge = 133914256901308,
	Medbay = 104351297744980,
}

-- Compound pieces (tools/models/compound.py): hideout wall panels tile along the generated wall parts,
-- a gate frame stands over the breach panel, and the raid arena's walls, pillars and gate get shells.
Assets.Compound = {
	WallPanel = 90340909566537, -- 10 wide, 9 tall
	GateFrame = 77590307627537,
	ArenaWall = 133068520008602, -- 22 wide, 28 tall
	ArenaPillar = 119840636382667,
	RaidGate = 113137125539955,
}

-- The Front's faction bases (tools/models/base.py): bunker shell (hollow, door toward the grid), flagpole
-- (the Cloth_Flag part is recoloured per faction) and the locker terminal that opens the recruit app.
Assets.Base = {
	Bunker = 114043336589277,
	Flag = 72596583156716,
	Locker = 111491796184766,
}

-- Worn gear (tools/models/worn.py, common/WornGear.lua): armor and cybernetics welded onto limbs, keyed
-- by item id. Limb "UpperLeg" goes on both legs.
Assets.Worn = {
	ScavHelm = { Id = 91709410827611, Limb = "Head" },
	PlatedHelm = { Id = 92859674573572, Limb = "Head" },
	ArcHood = { Id = 94718008402702, Limb = "Head" },
	Helmet = { Id = 73112723341170, Limb = "Head" },
	ScrapVest = { Id = 77827178367213, Limb = "UpperTorso" },
	RiotPlate = { Id = 101619565204054, Limb = "UpperTorso" },
	ConduitHarness = { Id = 96609756104129, Limb = "UpperTorso" },
	FlakVest = { Id = 91405959496523, Limb = "UpperTorso" },
	SteelPlate = { Id = 88180546853294, Limb = "UpperTorso" },
	ScrapGreaves = { Id = 78063481367635, Limb = "UpperLeg" },
	ServoGreaves = { Id = 127667007495817, Limb = "UpperLeg" },
	PlatedGreaves = { Id = 114276638981555, Limb = "UpperLeg" },
	ReflexOptic = { Id = 131871131352328, Limb = "Head" },
	TargetingLens = { Id = 134076533137550, Limb = "Head" },
	ServoArm = { Id = 99881854714921, Limb = "LeftLowerArm" },
	ArcGauntlet = { Id = 110756870292079, Limb = "LeftLowerArm" },
	NeuralCore = { Id = 114038010201506, Limb = "UpperTorso" },
	OverclockCore = { Id = 128521678913563, Limb = "UpperTorso" },
}

-- Loot containers and the Neural Net terminal shell (tools/models/loot.py): meshes ride inside the lootable
-- part / terminal body, which turn invisible. Loot.Spawn picks by label unless opts.Mesh names one.
Assets.Loot = {
	CrateA = 135218922360091, -- supply / cache crate
	CrateB = 116144381772246, -- vault cache, glowing lock
	Stash = 74319019375137, -- remains, spoils, salvage
	Terminal = 83359264941281,
}

-- Roblox drops Blender material colours on import, so every part is named "<Part>_<Material>"
-- and the material is applied from this table when the model is loaded.
Assets.Materials = {
	Steel = { Color = Color3.fromRGB(80, 82, 88), Material = Enum.Material.Metal },
	DarkMetal = { Color = Color3.fromRGB(42, 42, 46), Material = Enum.Material.Metal },
	Rust = { Color = Color3.fromRGB(96, 54, 32), Material = Enum.Material.CorrodedMetal },
	Housing = { Color = Color3.fromRGB(46, 46, 50), Material = Enum.Material.Metal },
	Lens = { Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 220, 150) },
	Wood = { Color = Color3.fromRGB(110, 78, 44), Material = Enum.Material.WoodPlanks },
	OldWood = { Color = Color3.fromRGB(78, 62, 42), Material = Enum.Material.WoodPlanks },
	Paint = { Color = Color3.fromRGB(140, 42, 36), Material = Enum.Material.Metal },
	SignGreen = { Color = Color3.fromRGB(26, 108, 56), Material = Enum.Material.Metal },
	SignWhite = { Color = Color3.fromRGB(218, 218, 205), Material = Enum.Material.SmoothPlastic },
	Glass = { Color = Color3.fromRGB(120, 170, 205), Material = Enum.Material.Glass, Transparency = 0.45 },
	Neon = { Color = Color3.fromRGB(0, 200, 245), Material = Enum.Material.Neon, Light = Color3.fromRGB(0, 200, 255) },
	NeonPink = { Color = Color3.fromRGB(245, 50, 155), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 60, 160) },
	Concrete = { Color = Color3.fromRGB(102, 102, 108), Material = Enum.Material.Concrete },
	Tyre = { Color = Color3.fromRGB(22, 22, 22), Material = Enum.Material.Rubber },
	Chainlink = { Color = Color3.fromRGB(102, 108, 115), Material = Enum.Material.DiamondPlate, Transparency = 0.35 },
	Burnt = { Color = Color3.fromRGB(32, 26, 24), Material = Enum.Material.Slate },
	Screen = { Color = Color3.fromRGB(14, 80, 115), Material = Enum.Material.Neon, Light = Color3.fromRGB(30, 150, 230) },
	-- characters
	Hood = { Color = Color3.fromRGB(41, 38, 43), Material = Enum.Material.Fabric },
	Jacket = { Color = Color3.fromRGB(61, 51, 43), Material = Enum.Material.Fabric },
	Cloth = { Color = Color3.fromRGB(51, 48, 46), Material = Enum.Material.Fabric },
	Grip = { Color = Color3.fromRGB(32, 30, 28), Material = Enum.Material.Rubber },
	Bandage = { Color = Color3.fromRGB(168, 153, 128), Material = Enum.Material.Fabric },
	Skin = { Color = Color3.fromRGB(158, 122, 97), Material = Enum.Material.SmoothPlastic },
	Boot = { Color = Color3.fromRGB(26, 23, 23), Material = Enum.Material.Leather },
	Goggle = { Color = Color3.fromRGB(255, 115, 38), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 120, 40) },
	Strap = { Color = Color3.fromRGB(31, 28, 26), Material = Enum.Material.Leather },
	Plate = { Color = Color3.fromRGB(71, 76, 84), Material = Enum.Material.DiamondPlate },
	ArcCoil = { Color = Color3.fromRGB(25, 204, 255), Material = Enum.Material.Neon, Light = Color3.fromRGB(40, 200, 255) },
	Chrome = { Color = Color3.fromRGB(140, 145, 158), Material = Enum.Material.Metal },
	WardenRed = { Color = Color3.fromRGB(140, 20, 36), Material = Enum.Material.Fabric },
	Visor = { Color = Color3.fromRGB(255, 25, 25), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 40, 40) },
	Coat = { Color = Color3.fromRGB(33, 31, 38), Material = Enum.Material.Fabric },
	Sandbag = { Color = Color3.fromRGB(150, 132, 92), Material = Enum.Material.Fabric },
	SandbagDark = { Color = Color3.fromRGB(112, 96, 62), Material = Enum.Material.Fabric },
	Char = { Color = Color3.fromRGB(28, 26, 25), Material = Enum.Material.CorrodedMetal },
	Olive = { Color = Color3.fromRGB(70, 78, 46), Material = Enum.Material.Metal },
	Rubber = { Color = Color3.fromRGB(23, 23, 26), Material = Enum.Material.Rubber },
	-- buildings
	DarkConcrete = { Color = Color3.fromRGB(44, 44, 51), Material = Enum.Material.Concrete },
	Panel = { Color = Color3.fromRGB(66, 69, 84), Material = Enum.Material.Metal },
	Brick = { Color = Color3.fromRGB(97, 61, 43), Material = Enum.Material.Brick },
	GlassDark = { Color = Color3.fromRGB(20, 26, 36), Material = Enum.Material.Glass, Transparency = 0.15 },
	GlassCorp = { Color = Color3.fromRGB(26, 46, 66), Material = Enum.Material.Glass, Transparency = 0.2 },
	GlassLit = { Color = Color3.fromRGB(217, 191, 115), Material = Enum.Material.Neon },
	NeonAmber = { Color = Color3.fromRGB(255, 158, 38), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 170, 60) },
	NeonRed = { Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 50, 50) },
	SootBrick = { Color = Color3.fromRGB(58, 42, 36), Material = Enum.Material.Brick },
	Plaster = { Color = Color3.fromRGB(158, 148, 128), Material = Enum.Material.Concrete },
	Canvas = { Color = Color3.fromRGB(92, 97, 76), Material = Enum.Material.Fabric },
	Mattress = { Color = Color3.fromRGB(140, 128, 108), Material = Enum.Material.Fabric },
	Yellow = { Color = Color3.fromRGB(178, 152, 38), Material = Enum.Material.Metal },
	White = { Color = Color3.fromRGB(216, 222, 224), Material = Enum.Material.SmoothPlastic },
	Ember = { Color = Color3.fromRGB(255, 115, 25), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 120, 30) },
	Red = { Color = Color3.fromRGB(178, 30, 30), Material = Enum.Material.SmoothPlastic },
	Hazard = { Color = Color3.fromRGB(216, 166, 26), Material = Enum.Material.Metal },
	Flag = { Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.Fabric },
	Rubble = { Color = Color3.fromRGB(84, 82, 79), Material = Enum.Material.Concrete },
}

-- Applies the named material to every part of a loaded model.
function Assets.Dress(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local matName = part.Name:match("_(%w+)$")
			local spec = matName and Assets.Materials[matName]
			if spec then
				part.Color = spec.Color
				part.Material = spec.Material
				part.Transparency = spec.Transparency or 0
				if spec.Light and not part:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight")
					light.Color, light.Range, light.Brightness = spec.Light, 16, 1
					light.Parent = part
				end
			end
		end
	end
end

-- Picks a building for a district style whose height is within [minH, maxH]; collapsed ones
-- are chosen with probability `collapseChance`. Returns the entry or nil.
function Assets.PickBuilding(style, minH, maxH, collapseChance, rng)
	local kit = Assets.Buildings[style]
	if not kit then
		return nil
	end
	local wantCollapsed = (rng and rng:NextNumber() or math.random()) < collapseChance
	local pool, fallback = {}, {}
	for _, entry in kit do
		if entry.Id ~= 0 then
			if entry.Collapsed == wantCollapsed then
				if entry.Height >= minH * 0.7 and entry.Height <= maxH * 1.3 then
					table.insert(pool, entry)
				end
				table.insert(fallback, entry)
			end
		end
	end
	if #pool == 0 then
		pool = fallback
	end
	if #pool == 0 then
		return nil
	end
	return pool[(rng and rng:NextInteger(1, #pool)) or math.random(#pool)]
end

-- Picks a random condition's asset id for a prop, or nil.
function Assets.PickProp(propId, rng)
	local set = Assets.Props[propId]
	if not set then
		return nil
	end
	local ids = {}
	for _, cond in { "A", "B", "C" } do
		if set[cond] and set[cond] ~= 0 then
			table.insert(ids, set[cond])
		end
	end
	if #ids == 0 then
		return nil
	end
	return ids[(rng and rng:NextInteger(1, #ids)) or math.random(#ids)]
end

return Assets
