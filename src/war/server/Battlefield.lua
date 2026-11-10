-- The Front: a large open war world. shared/FrontMap rolls the layout (a Cols x Rows grid of sectors between
-- the two faction rears, each held around its crest, a barrow of calcified clone bodies), WarTerrain writes
-- the ground, and this module dresses it: staged structures on their pads (Intact -> Damaged -> Ruined ->
-- Rubble), the dugouts each faction deploys from, wire, nests, wrecks, the dead, the skyline. Sectors the
-- hill has left rebuild on a timer. The fallen calcify where they lie and raise their sector's crest.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Assets = require(Shared.Assets)
local FrontMap = require(Shared.FrontMap)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local WarTerrain = require(script.Parent.WarTerrain)

local W = Config.War
local WC = W.World
local FW = Assets.FrontWorld
local Battlefield = {}
Battlefield.StructureDamaged = Instance.new("BindableEvent") -- (model, stage)
Battlefield.Lockers = {} -- the locker terminals at each base (Soldiers puts the recruit-app prompt on them)
Battlefield.Hot = nil -- the sector the hill is in (Hill keeps it current); recruits deploy one sector behind it

local folder, propsFolder, deadFolder
local sectors = {} -- [index] = { Center, Structures = {}, Rebuilt = os.clock(), Calcified = {}, Fallen = 0, Grown = 0 }
local structures = {} -- [model] = { stages = {...}, stage = 1, health, maxHealth, sector }
local rng = Random.new(42)

local part
local CONCRETE = Color3.fromRGB(120, 115, 105)
local BONE = Color3.fromRGB(184, 176, 160)

-- Ground height at (x, z): the terrain the layout describes.
function Battlefield.GroundAt(x, z)
	return FrontMap.Height(x, z)
end

-- An uploaded prop set down on the ground at (x, z) facing `yaw` degrees, `sink` studs into it and scaled,
-- or the generated part in `fallback` (a props table for part(), Position relative to the ground point)
-- when the asset is missing.
local function prop(parent, assetId, position, yaw, name, fallback, sink, scale)
	local y = Battlefield.GroundAt(position.X, position.Z) - (sink or 0)
	local cf = CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local model = ModelAssets.Spawn(assetId, cf, name, parent)
	if model then
		if scale and scale ~= 1 then
			pcall(function()
				model:ScaleTo(scale)
				model:PivotTo(cf)
			end)
		end
		return model
	end
	if not fallback then
		return nil
	end
	fallback.Name = name
	fallback.Position = Vector3.new(position.X, y, position.Z) + (fallback.Position or Vector3.zero)
	fallback.Orientation = fallback.Orientation or Vector3.new(0, yaw or 0, 0)
	return part(parent, fallback)
end

function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function Battlefield.SectorCenter(index)
	local c = FrontMap.SectorCenter(index)
	return Vector3.new(c.X, Battlefield.GroundAt(c.X, c.Z), c.Z)
end

function Battlefield.SectorAt(position)
	return FrontMap.SectorAt(position.X, position.Z)
end

-- The top of a sector's crest (the barrow it is held around): where the hill marker stands.
function Battlefield.Crest(index)
	local sec = FrontMap.Layout().Sectors[index]
	local crest = sec and sec.Crest
	if not crest then
		return Battlefield.SectorCenter(index)
	end
	local grown = sectors[index] and sectors[index].Grown or 0
	return Vector3.new(crest.X, Battlefield.GroundAt(crest.X, crest.Z) + grown, crest.Z)
end

-- A structure: a building with four stage models. Health is per stage; dropping below a
-- threshold swaps to the next one. Rubble keeps low cover, so fights reshape, not flatten.
local function buildStage(model, stage, center, w, d, h, color)
	local parts = {}
	if stage == 1 then
		parts[#parts + 1] = part(model, { Size = Vector3.new(w, h, 1), Position = center + Vector3.new(0, h / 2, d / 2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(w, h, 1), Position = center + Vector3.new(0, h / 2, -d / 2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(1, h, d), Position = center + Vector3.new(w / 2, h / 2, 0), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(1, h, d / 2), Position = center + Vector3.new(-w / 2, h / 2, d / 4), Color = color, Material = Enum.Material.Brick }) -- doorway
		parts[#parts + 1] = part(model, { Size = Vector3.new(w, 1, d), Position = center + Vector3.new(0, h, 0), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood })
	elseif stage == 2 then
		parts[#parts + 1] = part(model, { Size = Vector3.new(w, h, 1), Position = center + Vector3.new(0, h / 2, d / 2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.6, h * 0.7, 1), Position = center + Vector3.new(-w * 0.2, h * 0.35, -d / 2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(1, h, d), Position = center + Vector3.new(w / 2, h / 2, 0), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.5, 1, d * 0.5), Position = center + Vector3.new(w * 0.25, h, d * 0.25), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood })
	elseif stage == 3 then
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.7, h * 0.5, 1), Position = center + Vector3.new(w * 0.15, h * 0.25, d / 2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(1, h * 0.45, d * 0.6), Position = center + Vector3.new(w / 2, h * 0.22, -d * 0.2), Color = color, Material = Enum.Material.Brick })
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.4, 2, d * 0.4), Position = center + Vector3.new(-w * 0.2, 1, 0), Color = CONCRETE, Material = Enum.Material.Concrete })
	else
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.5, 2.5, d * 0.5), Position = center + Vector3.new(0, 1.25, 0), Color = CONCRETE, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, 20, 8) })
		parts[#parts + 1] = part(model, { Size = Vector3.new(w * 0.3, 1.5, 3), Position = center + Vector3.new(w * 0.3, 0.75, d * 0.3), Color = CONCRETE, Material = Enum.Material.Concrete })
	end
	return parts
end

local STAGE_HEALTH = { 300, 220, 160 } -- health of stages 1-3; rubble (4) is indestructible

local function spawnStructure(sector, pad)
	local model = Instance.new("Model")
	model.Name = "Structure"
	model:SetAttribute("Stage", 1)
	local kit = Assets.FrontBuildings[pad.Kit]
	local w, d, h = 18, 16, 9
	if kit then
		w, d, h = kit.Width, kit.Depth, kit.Height
	end
	local ground = Battlefield.GroundAt(pad.X, pad.Z)
	local center = Vector3.new(pad.X, ground, pad.Z)
	local yaw = rng:NextInteger(0, 3) * 90 + rng:NextNumber(-8, 8)
	local entry = { stages = {}, stage = 1, health = STAGE_HEALTH[1], center = center, w = w, d = d, h = h, color = Color3.fromRGB(rng:NextInteger(100, 150), rng:NextInteger(80, 110), rng:NextInteger(60, 90)), sector = sector }
	for stage = 1, 4 do
		local holder = kit and ModelAssets.Spawn(kit.Stages[stage], CFrame.new(center - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(yaw), 0), "Stage" .. stage, nil)
		if not holder then
			holder = Instance.new("Model")
			holder.Name = "Stage" .. stage
			buildStage(holder, stage, center, w, d, h, entry.color)
		end
		entry.stages[stage] = holder
	end
	entry.stages[1].Parent = model
	CollectionService:AddTag(model, "Structure")
	model.Parent = folder
	structures[model] = entry
	table.insert(sectors[sector].Structures, model)
	return model
end

local function setStage(model, entry, stage)
	entry.stages[entry.stage].Parent = nil
	entry.stage = stage
	entry.health = STAGE_HEALTH[stage] or math.huge
	entry.stages[stage].Parent = model
	model:SetAttribute("Stage", stage)
	Remotes.World:FireAllClients("StructureStage", entry.center, stage)
	Battlefield.StructureDamaged:Fire(model, stage)
end

-- Explosive damage to a structure (bullets do nothing to walls here; that's the doc's rule)
function Battlefield.DamageStructure(model, amount)
	local entry = structures[model]
	if not entry or entry.stage >= 4 then
		return
	end
	entry.health -= amount
	if entry.health <= 0 then
		setStage(model, entry, entry.stage + 1)
	end
end

-- Structures whose footprint reaches within `radius` of `position` (measured flat: roofs count).
function Battlefield.StructuresNear(position, radius)
	local out = {}
	for model, entry in structures do
		local dx, dz = entry.center.X - position.X, entry.center.Z - position.Z
		if math.sqrt(dx * dx + dz * dz) <= radius + math.max(entry.w, entry.d) / 2 then
			table.insert(out, model)
		end
	end
	return out
end

-- Craters: carve the terrain and leave a scorch disc on the new floor.
function Battlefield.Crater(position, radius)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local ground = Battlefield.GroundAt(position.X, position.Z)
	local y = math.min(position.Y, ground + radius * 0.3)
	if terrain and terrain.FillBall then
		pcall(function()
			terrain:FillBall(Vector3.new(position.X, y - radius * 0.4, position.Z), radius, Enum.Material.Air)
			terrain:FillBall(Vector3.new(position.X, y - radius * 1.25, position.Z), radius * 1.05, Enum.Material.Mud)
		end)
	end
	local scorch = part(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 1.6, radius * 1.6), CFrame = CFrame.new(position.X, y - radius * 0.2, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(25, 22, 20), Material = Enum.Material.Ground, CanCollide = false, CanQuery = false, Transparency = 0.2 })
	scorch.Name = "Crater"
	CollectionService:AddTag(scorch, "Crater")
	local index = Battlefield.SectorAt(position)
	if index then
		scorch:SetAttribute("Sector", index)
	else
		game:GetService("Debris"):AddItem(scorch, 600) -- outside the grid nothing rebuilds it, so it fades
	end
end

-- ===== the dressing: one builder per scatter kind (FrontMap's L.Scatter) =====
local SANDBAG = Color3.fromRGB(140, 125, 90)
local BUILD = {}
function BUILD.Barrow(s)
	if s.Top then
		-- a fused cap on a crest or mound: the terrain is the barrow, the mesh is its surface of bodies
		local scale = if s.Big then 1.7 else (if s.H then 0.9 + s.H / 14 else 1.15)
		return prop(propsFolder, FW.Barrow[rng:NextInteger(1, 2)], s, s.Yaw, "Barrow", nil, 3.2 * scale, scale)
	end
	return prop(propsFolder, FW.Barrow[rng:NextInteger(1, 2)], s, s.Yaw, "Barrow",
		{ Shape = Enum.PartType.Ball, Size = Vector3.new(14, 6, 14), Position = Vector3.new(0, 0, 0), Color = BONE, Material = Enum.Material.Limestone }, 2.2, rng:NextNumber(0.8, 1.1))
end
function BUILD.Calcified(s)
	return prop(deadFolder, FW.Calcified[if rng:NextNumber() < 0.7 then 1 else 2], s, s.Yaw, "Calcified",
		{ Size = Vector3.new(2, 1, 5.5), Position = Vector3.new(0, 0.3, 0), Color = BONE, Material = Enum.Material.Limestone }, rng:NextNumber(0.2, 0.6))
end
function BUILD.Wire(s)
	return prop(propsFolder, FW.Wire, s, s.Yaw, "Wire", { Size = Vector3.new(10, 2.6, 1.6), Position = Vector3.new(0, 1.3, 0), Color = Color3.fromRGB(60, 50, 44), Material = Enum.Material.CorrodedMetal, Transparency = 0.5 }, 0.2)
end
function BUILD.Nest(s)
	return prop(propsFolder, if rng:NextNumber() < 0.35 then Assets.Front.Sandbags.B else Assets.Front.Sandbags.A, s, s.Yaw, "Sandbags",
		{ Size = Vector3.new(6, 2, 1.5), Position = Vector3.new(0, 1, 0), Color = SANDBAG, Material = Enum.Material.Fabric }, 0.3)
end
function BUILD.Crate(s)
	return prop(propsFolder, Assets.Front.AmmoCrate, s, s.Yaw, "AmmoCrate", { Size = Vector3.new(2, 1.3, 1.2), Position = Vector3.new(0, 0.65, 0), Color = Color3.fromRGB(70, 78, 46), Material = Enum.Material.Metal }, 0.1)
end
function BUILD.Hedgehog(s)
	return prop(propsFolder, Assets.Front.Hedgehog, s, s.Yaw, "Hedgehog", { Size = Vector3.new(4, 4, 4), Position = Vector3.new(0, 2, 0), Color = Color3.fromRGB(96, 54, 32), Material = Enum.Material.CorrodedMetal }, 0.4)
end
function BUILD.Wreck(s)
	local model = prop(propsFolder, if rng:NextNumber() < 0.5 then Assets.Front.Truck.B else Assets.Front.Truck.A, s, s.Yaw, "Wreck",
		{ Size = Vector3.new(7, 4, 14), Position = Vector3.new(0, 2, 0), Color = Color3.fromRGB(50, 45, 40), Material = Enum.Material.CorrodedMetal }, 0.5)
	return model
end
function BUILD.FieldGun(s)
	return prop(propsFolder, FW.FieldGun, s, s.Yaw, "FieldGun", { Size = Vector3.new(3, 2.5, 8), Position = Vector3.new(0, 1.25, 0), Color = Color3.fromRGB(62, 68, 42), Material = Enum.Material.Metal }, 0.2)
end
function BUILD.Stump(s)
	return prop(propsFolder, FW.Stump[if rng:NextNumber() < 0.6 then 1 else 2], s, s.Yaw, "Stump",
		{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.4, 1.4), Position = Vector3.new(0, 2, 0), Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(70, 62, 56), Material = Enum.Material.Wood }, 0.3, rng:NextNumber(0.8, 1.3))
end
function BUILD.DeadTree(s)
	return prop(propsFolder, Assets.Frontier.Dead, s, s.Yaw, "DeadTree",
		{ Size = Vector3.new(1.5, 14, 1.5), Position = Vector3.new(0, 7, 0), Color = Color3.fromRGB(70, 62, 56), Material = Enum.Material.Wood }, 0.5, rng:NextNumber(0.9, 1.5))
end
function BUILD.Chimney(s)
	return prop(propsFolder, FW.Chimney, s, s.Yaw, "Chimney", { Size = Vector3.new(7, 26, 7), Position = Vector3.new(0, 13, 0), Color = Color3.fromRGB(107, 61, 46), Material = Enum.Material.Brick }, 0.5)
end
function BUILD.Pylon(s)
	local model = prop(propsFolder, FW.Pylon, s, s.Yaw, "Pylon", nil, 0.3)
	if model then
		-- a broken pylon leans: tip it a little about its base
		model:PivotTo(model:GetPivot() * CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), 0, math.rad(rng:NextNumber(-9, 9))))
	end
	return model
end
function BUILD.Rubble(s)
	local y = Battlefield.GroundAt(s.X, s.Z)
	local size = Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(1, 2.5), rng:NextNumber(2, 5))
	return part(propsFolder, { Name = "Rubble", Size = size, CFrame = CFrame.new(s.X, y + size.Y * 0.3, s.Z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), math.rad(s.Yaw), rng:NextNumber(-0.3, 0.3)),
		Color = if rng:NextNumber() < 0.5 then CONCRETE else Color3.fromRGB(107, 61, 46), Material = if rng:NextNumber() < 0.5 then Enum.Material.Concrete else Enum.Material.Brick })
end
function BUILD.Dugout(s)
	return prop(propsFolder, FW.Dugout, s, s.Yaw, "Dugout", { Size = Vector3.new(7, 3, 8), Position = Vector3.new(0, 1.5, 0), Color = SANDBAG, Material = Enum.Material.Fabric }, 0.6)
end
-- the last green: one living tree on the glade's crest, a ring of growth around it
function BUILD.LiveTree(s)
	local broad = Assets.Frontier.Broad
	return prop(propsFolder, broad and broad[1], s, s.Yaw, "LastTree", { Size = Vector3.new(2, 16, 2), Position = Vector3.new(0, 8, 0), Color = Color3.fromRGB(86, 64, 46), Material = Enum.Material.Wood }, 0.4, 1.6)
end
function BUILD.Bush(s)
	local broad = Assets.Frontier.Broad
	return prop(propsFolder, broad and broad[2], s, s.Yaw, "Growth", { Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3, 4), Position = Vector3.new(0, 1, 0), Color = Color3.fromRGB(62, 118, 58), Material = Enum.Material.Grass }, 0.3, rng:NextNumber(0.5, 0.8))
end
function BUILD.Pine(s)
	local pines = Assets.Frontier.Pines
	return prop(propsFolder, pines and pines[rng:NextInteger(1, #pines)], s, s.Yaw, "Growth", { Size = Vector3.new(1, 10, 1), Position = Vector3.new(0, 5, 0), Color = Color3.fromRGB(52, 104, 76), Material = Enum.Material.Grass }, 0.3, rng:NextNumber(0.6, 1.0))
end

-- fire and smoke on a few wrecks: the war is still burning
local function burn(model, smokeOnly)
	local anchor = if model:IsA("Model") then model.PrimaryPart else model
	if not anchor then
		return
	end
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = Color3.fromRGB(40, 36, 32), 0.25, 6, 6
	smoke.Parent = anchor
	if not smokeOnly then
		local fire = Instance.new("Fire")
		fire.Heat, fire.Size, fire.Color, fire.SecondaryColor = 9, 5, Color3.fromRGB(255, 120, 40), Color3.fromRGB(120, 30, 10)
		fire.Parent = anchor
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 140, 60), 18, 1.4
		light.Parent = anchor
	end
end

local function buildSkyline(L)
	for _, s in L.Skyline do
		local y = Battlefield.GroundAt(s.X, s.Z)
		local cf = CFrame.new(s.X, y - 10, s.Z)
		local model = ModelAssets.Spawn(FW.Smokestack, cf, "Smokestack", propsFolder)
		local top
		if model then
			pcall(function()
				model:ScaleTo(s.Scale)
				model:PivotTo(cf)
			end)
			local _, size = model:GetBoundingBox()
			top = cf.Position + Vector3.new(0, size.Y, 0)
		else
			local h = 40 * s.Scale
			part(propsFolder, { Name = "Smokestack", Size = Vector3.new(7 * s.Scale, h, 7 * s.Scale), Position = cf.Position + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(90, 55, 44), Material = Enum.Material.Brick, CanCollide = false })
			top = cf.Position + Vector3.new(0, h, 0)
		end
		-- the smoke: one big slow plume each
		local vent = part(propsFolder, { Name = "Plume", Size = Vector3.new(4, 1, 4), Position = top, Transparency = 1, CanCollide = false, CanQuery = false })
		local plume = Instance.new("ParticleEmitter")
		plume.Texture = "rbxasset://textures/particles/smoke_main.dds"
		plume.Color = ColorSequence.new(Color3.fromRGB(46, 42, 38), Color3.fromRGB(110, 104, 96))
		plume.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12 * s.Scale / 4), NumberSequenceKeypoint.new(1, 60 * s.Scale / 4) })
		plume.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		plume.Lifetime = NumberRange.new(18, 26)
		plume.Rate = 1.2
		plume.Speed = NumberRange.new(10, 16)
		plume.SpreadAngle = Vector2.new(12, 12)
		plume.Acceleration = Vector3.new(4, 1, 2)
		plume.LightInfluence = 0.6
		plume.Parent = vent
	end
end

local function buildWorld(L)
	for index, sec in L.Sectors do
		sectors[index] = { Center = sec.Center, Structures = {}, Rebuilt = os.clock(), Calcified = {}, Fallen = 0, Grown = 0, Type = sec.Type }
		for _, pad in sec.Pads do
			spawnStructure(index, pad)
		end
	end
	local counts = {}
	local wrecks = {}
	for _, s in L.Scatter do
		local fn = BUILD[s.Kind]
		local model = fn and fn(s)
		if model then
			counts[s.Kind] = (counts[s.Kind] or 0) + 1
			if s.Kind == "Wreck" then
				table.insert(wrecks, model)
			end
		end
	end
	for i, model in wrecks do
		if i % 3 == 1 then
			burn(model, i % 2 == 0)
		end
	end
	buildSkyline(L)
	-- the outer barrows are a wall: nobody walks off the map
	local px, pz = L.PlayX + 40, L.PlayZ + 40
	for _, w in { { Vector3.new(px, 150, 0), Vector3.new(4, 300, pz * 2 + 8) }, { Vector3.new(-px, 150, 0), Vector3.new(4, 300, pz * 2 + 8) },
		{ Vector3.new(0, 150, pz), Vector3.new(px * 2 + 8, 300, 4) }, { Vector3.new(0, 150, -pz), Vector3.new(px * 2 + 8, 300, 4) } } do
		part(folder, { Name = "Boundary", Position = w[1], Size = w[2], Transparency = 1, CanQuery = false })
	end
	return counts
end

-- ===== the fallen calcify =====
-- A recruit fell at `position`: after a while the body turns to calcite where it lies, and every few of
-- them raise the sector's crest. Too many in one sector and the oldest sink into the ground.
function Battlefield.Fallen(position)
	local index = Battlefield.SectorAt(position)
	local sec = index and sectors[index]
	if not sec then
		return
	end
	task.delay(WC.CalcifySeconds, function()
		if not folder or not folder.Parent then
			return
		end
		local model = BUILD.Calcified({ X = position.X + rng:NextNumber(-1, 1), Z = position.Z + rng:NextNumber(-1, 1), Yaw = rng:NextNumber(0, 360) })
		if model then
			model:SetAttribute("Fallen", true)
			table.insert(sec.Calcified, model)
		end
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		while #sec.Calcified > WC.CalcifiedCap do
			local oldest = table.remove(sec.Calcified, 1)
			if oldest.Parent then
				local at = oldest:GetPivot().Position
				oldest:Destroy()
				if terrain and terrain.FillBall then
					pcall(function()
						terrain:FillBall(at, 1.8, Enum.Material.Limestone)
					end)
				end
			end
		end
		sec.Fallen += 1
		if sec.Fallen % WC.GrowEvery == 0 and sec.Grown < WC.MaxGrow then
			-- the crest grows: calcite piles on its top
			local crest = Battlefield.Crest(index)
			sec.Grown += WC.GrowStuds
			if terrain and terrain.FillBall then
				pcall(function()
					terrain:FillBall(crest + Vector3.new(0, WC.GrowStuds - 7, 0), 9, Enum.Material.Limestone)
				end)
			end
			Remotes.World:FireAllClients("CrestGrew", index, crest)
		end
	end)
end

-- Rebuild a sector: structures back to Intact, craters cleared. Fiction: rebuild crews.
function Battlefield.RebuildSector(index)
	local sector = sectors[index]
	if not sector then
		return
	end
	for _, model in sector.Structures do
		local entry = structures[model]
		if entry and entry.stage ~= 1 then
			setStage(model, entry, 1)
		end
	end
	for _, scorch in CollectionService:GetTagged("Crater") do
		if scorch:GetAttribute("Sector") == index then
			scorch:Destroy()
		end
	end
	sector.Rebuilt = os.clock()
	Remotes.Announce:FireAllClients(("Rebuild crews have restored sector %d."):format(index), "Info")
end

-- A faction's base, at the back of its rear.
function Battlefield.HomeCFrame(faction)
	local base = FrontMap.Layout().Bases[faction]
	local x = base.X + rng:NextNumber(-10, 10)
	local z = base.Z + rng:NextNumber(-40, 40)
	return CFrame.new(x, Battlefield.GroundAt(x, z) + 4, z)
end

-- Where a recruit of `faction` deploys: the faction's dugout in the sector behind the hill on its own side
-- (Union to the west, Pact to the east), or the base when the hill sits on the faction's own line.
function Battlefield.BaseCFrame(faction)
	local L = FrontMap.Layout()
	local hot = Battlefield.Hot
	if hot and L.Sectors[hot] then
		local sec = L.Sectors[hot]
		local col = sec.I + (if faction == "Union" then -1 else 1)
		local index = FrontMap.Index(col, sec.J)
		local dugout = index and L.Sectors[index].Dugouts[faction]
		if dugout then
			local x = dugout.X + dugout.Out * 7 + rng:NextNumber(-2, 2)
			local z = dugout.Z + rng:NextNumber(-3, 3)
			-- face the fight
			local look = Vector3.new(-dugout.Out, 0, 0)
			local at = Vector3.new(x, Battlefield.GroundAt(x, z) + 4, z)
			return CFrame.lookAt(at, at + look)
		end
	end
	return Battlefield.HomeCFrame(faction)
end

function Battlefield.Init()
	folder = Instance.new("Folder")
	folder.Name = "Front"
	folder.Parent = workspace
	propsFolder = Instance.new("Folder")
	propsFolder.Name = "Dressing"
	propsFolder.Parent = folder
	deadFolder = Instance.new("Folder")
	deadFolder.Name = "Calcified"
	deadFolder.Parent = folder
	local started = os.clock()
	local L = FrontMap.Generate(WC.Seed)
	rng = Random.new(L.Seed)
	folder:SetAttribute("Seed", L.Seed)
	-- load every model the dressing uses at once (one by one this took ~15 s on a live server)
	do
		local ids = {}
		local function collect(t)
			for _, v in t do
				if type(v) == "number" then
					ids[v] = true
				elseif type(v) == "table" then
					collect(v)
				end
			end
		end
		collect(FW)
		collect(Assets.Front)
		collect(Assets.Base)
		collect({ Assets.Frontier.Dead, Assets.Frontier.Broad, Assets.Frontier.Pines })
		for _, kit in Assets.FrontBuildings do
			collect(kit.Stages)
		end
		local pending = 0
		for id in ids do
			pending += 1
			task.spawn(function()
				ModelAssets.Template(id)
				pending -= 1
			end)
		end
		local waited = os.clock()
		while pending > 0 and os.clock() - waited < 30 do
			task.wait(0.05)
		end
	end
	local loadSeconds = os.clock() - started
	local chunks = WarTerrain.Write()
	local terrainSeconds = os.clock() - started - loadSeconds
	local counts = buildWorld(L)
	local total = 0
	for _, n in counts do
		total += n
	end
	local nStructures = 0
	for _ in structures do
		nStructures += 1
	end
	print(("[Front] world seed %d: models loaded in %.1fs, %d terrain chunks in %.1fs, %d structures, %d props, built in %.1fs"):format(L.Seed, loadSeconds, chunks, terrainSeconds, nStructures, total, os.clock() - started))
	-- faction bases: a bunker each at the back of its rear, facing the field
	for _, faction in W.Factions do
		local home = L.Bases[faction]
		local inward = if faction == "Union" then 1 else -1
		local bx = home.X - inward * 30
		local function at(x, z)
			return Battlefield.GroundAt(x, z)
		end
		local bunkerCF = CFrame.new(bx, at(bx, 0), 0) * CFrame.Angles(0, -inward * math.pi / 2, 0)
		local bunker = ModelAssets.Spawn(Assets.Base.Bunker, bunkerCF, faction .. "Base", folder)
		if not bunker then
			bunker = part(folder, { Name = faction .. "Base", Size = Vector3.new(40, 12, 60), Position = Vector3.new(bx, at(bx, 0) + 6, 0), Color = CONCRETE, Material = Enum.Material.Concrete })
		end
		bunker:SetAttribute("Faction", faction)
		local fx = home.X + inward * 6
		local flag = ModelAssets.Spawn(Assets.Base.Flag, CFrame.new(fx, at(fx, 22), 22), faction .. "Flag", folder)
		if flag then
			for _, p in flag:GetDescendants() do
				if p:IsA("BasePart") and p.Name:match("_Flag$") then
					p.Color = W.FactionColors[faction]
				end
			end
		else
			flag = part(folder, { Name = faction .. "Flag", Size = Vector3.new(0.5, 20, 0.5), Position = Vector3.new(home.X, at(home.X, 0) + 10, 0), Color = W.FactionColors[faction], Material = Enum.Material.Neon })
		end
		local locker = ModelAssets.Spawn(Assets.Base.Locker, CFrame.new(fx, at(fx, -22), -22) * CFrame.Angles(0, -inward * math.pi / 2, 0), faction .. "Locker", folder)
		if not locker then
			locker = part(folder, { Name = faction .. "Locker", Size = Vector3.new(4, 6, 2), Position = Vector3.new(fx, at(fx, -22) + 3, -22), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal })
		end
		locker:SetAttribute("Faction", faction)
		table.insert(Battlefield.Lockers, locker)
	end
	-- the light: a low brown overcast, haze that eats the distance, colour drained out of everything
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime, Lighting.Brightness = 16.8, 1.6
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(96, 90, 84), Color3.fromRGB(118, 110, 102)
	Lighting.FogEnd, Lighting.FogColor = 1400, Color3.fromRGB(140, 128, 114)
	pcall(function()
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atmosphere.Density, atmosphere.Offset = 0.42, 0.18
		atmosphere.Color, atmosphere.Decay = Color3.fromRGB(168, 150, 128), Color3.fromRGB(96, 84, 72)
		atmosphere.Glare, atmosphere.Haze = 0.15, 2.4
		atmosphere.Parent = Lighting
		local grade = Lighting:FindFirstChild("FrontGrade") or Instance.new("ColorCorrectionEffect")
		grade.Name = "FrontGrade"
		grade.Saturation, grade.Contrast, grade.Brightness = -0.32, 0.12, -0.02
		grade.TintColor = Color3.fromRGB(255, 240, 222)
		grade.Parent = Lighting
	end)
end

Battlefield.Sectors = sectors
return Battlefield
