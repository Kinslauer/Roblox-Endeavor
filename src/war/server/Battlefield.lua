-- The Front: a Sectors x Sectors grid of 160-stud sectors. Each has a few structures with
-- authored stages (Intact -> Damaged -> Ruined -> Rubble), trenches and sandbags. The two
-- faction bases sit beyond opposite edges. Sectors the hill has left rebuild on a timer.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Assets = require(Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local W = Config.War
local H = W.Hill
local Battlefield = {}
Battlefield.StructureDamaged = Instance.new("BindableEvent") -- (model, stage)

local GROUND_TOP = 2
local folder
local sectors = {} -- [index] = { Center, Structures = {}, Rebuilt = os.clock() }
local structures = {} -- [model] = { stages = {...}, stage = 1, health, maxHealth, sector }
local rng = Random.new(42)

local part
local MUD = Color3.fromRGB(70, 60, 45)
local CONCRETE = Color3.fromRGB(120, 115, 105)

-- An uploaded prop set down on the ground at (x, GROUND_TOP, z) facing `yaw` degrees, or the
-- generated box in `fallback` (a props table for part()) when the asset is missing.
local function prop(parent, assetId, position, yaw, name, fallback)
	local cf = CFrame.new(position.X, GROUND_TOP, position.Z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local model = ModelAssets.Spawn(assetId, cf, name, parent)
	if model then
		return model
	end
	fallback.Name = name
	fallback.Orientation = Vector3.new(0, yaw or 0, 0)
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
	local n = H.Sectors
	local i, j = (index - 1) % n, math.floor((index - 1) / n)
	return Vector3.new((i - (n - 1) / 2) * H.SectorSize, 0, (j - (n - 1) / 2) * H.SectorSize)
end

function Battlefield.SectorAt(position)
	local n, s = H.Sectors, H.SectorSize
	local i = math.floor(position.X / s + n / 2)
	local j = math.floor(position.Z / s + n / 2)
	if i < 0 or j < 0 or i >= n or j >= n then
		return nil
	end
	return j * n + i + 1
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

local function spawnStructure(sector, center, w, d, h)
	local model = Instance.new("Model")
	model.Name = "Structure"
	model:SetAttribute("Stage", 1)
	local entry = { stages = {}, stage = 1, health = STAGE_HEALTH[1], center = center, w = w, d = d, h = h, color = Color3.fromRGB(rng:NextInteger(100, 150), rng:NextInteger(80, 110), rng:NextInteger(60, 90)), sector = sector }
	for stage = 1, 4 do
		local holder = Instance.new("Model")
		holder.Name = "Stage" .. stage
		buildStage(holder, stage, center + Vector3.new(0, GROUND_TOP, 0), w, d, h, entry.color)
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

function Battlefield.StructuresNear(position, radius)
	local out = {}
	for model, entry in structures do
		if (entry.center - position).Magnitude <= radius + math.max(entry.w, entry.d) / 2 then
			table.insert(out, model)
		end
	end
	return out
end

-- Craters: carve terrain when the place has terrain; always leave a scorch disc.
function Battlefield.Crater(position, radius)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and terrain.FillBall then
		pcall(function()
			terrain:FillBall(position - Vector3.new(0, radius * 0.4, 0), radius, Enum.Material.Air)
			terrain:FillBall(position - Vector3.new(0, radius * 0.9, 0), radius * 1.1, Enum.Material.Mud)
		end)
	end
	local scorch = part(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = CFrame.new(position.X, GROUND_TOP + 0.06, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(25, 22, 20), Material = Enum.Material.Ground, CanCollide = false, CanQuery = false })
	scorch.Name = "Crater"
	CollectionService:AddTag(scorch, "Crater")
	local index = Battlefield.SectorAt(position)
	if index then
		scorch:SetAttribute("Sector", index)
	else
		game:GetService("Debris"):AddItem(scorch, 600) -- outside the grid nothing rebuilds it, so it fades
	end
end

local function buildSector(index)
	local c = Battlefield.SectorCenter(index)
	local s = H.SectorSize
	sectors[index] = { Center = c, Structures = {}, Rebuilt = os.clock() }
	-- a village block: 5-7 buildings on a loose grid, so every sector has rooms to clear
	local placed = {}
	for _ = 1, rng:NextInteger(5, 7) do
		local off
		for _ = 1, 10 do
			off = Vector3.new(rng:NextNumber(-s * 0.38, s * 0.38), 0, rng:NextNumber(-s * 0.38, s * 0.38))
			local ok = true
			for _, p in placed do
				if (p - off).Magnitude < 34 then
					ok = false
					break
				end
			end
			if ok then
				break
			end
		end
		table.insert(placed, off)
		spawnStructure(index, c + off, rng:NextNumber(16, 26), rng:NextNumber(14, 22), rng:NextNumber(8, 13))
	end
	-- two trench lines (sunken walkways with sandbag lips), one each way
	local function trench(center, length, horizontal)
		local size = if horizontal then Vector3.new(length, 4, 6) else Vector3.new(6, 4, length)
		part(folder, { Name = "Trench", Size = size, Position = center + Vector3.new(0, GROUND_TOP - 2, 0), Color = MUD, Material = Enum.Material.Mud, CanCollide = false, CanQuery = false })
		part(folder, { Name = "TrenchFloor", Size = Vector3.new(size.X, 1, size.Z), Position = center + Vector3.new(0, GROUND_TOP - 3.5, 0), Color = MUD, Material = Enum.Material.Mud })
		for side = -1, 1, 2 do
			local lip = if horizontal then Vector3.new(0, 0, side * 3.8) else Vector3.new(side * 3.8, 0, 0)
			local n = math.floor(length / 6)
			for i = 1, n do
				local along = (i - 0.5) * 6 - length / 2
				local at = center + lip + (if horizontal then Vector3.new(along, 0, 0) else Vector3.new(0, 0, along))
				prop(folder, if rng:NextNumber() < 0.3 then Assets.Front.Sandbags.B else Assets.Front.Sandbags.A, at, if horizontal then 0 else 90, "Sandbags",
					{ Size = Vector3.new(6, 2, 1.5), Position = at + Vector3.new(0, GROUND_TOP + 1, 0), Color = Color3.fromRGB(140, 125, 90), Material = Enum.Material.Fabric })
			end
		end
	end
	trench(Vector3.new(c.X, 0, c.Z + rng:NextNumber(-s * 0.35, s * 0.35)), s * 0.7, true)
	trench(Vector3.new(c.X + rng:NextNumber(-s * 0.35, s * 0.35), 0, c.Z), s * 0.5, false)
	-- earth berms and sandbag nests: low cover between the buildings
	for _ = 1, 5 do
		part(folder, { Name = "Berm", Size = Vector3.new(rng:NextNumber(10, 18), 2.5, 4), Position = c + Vector3.new(rng:NextNumber(-s * 0.45, s * 0.45), GROUND_TOP + 1.2, rng:NextNumber(-s * 0.45, s * 0.45)), Color = MUD, Material = Enum.Material.Ground, Orientation = Vector3.new(0, rng:NextNumber(0, 180), 0) })
	end
	for _ = 1, 7 do
		local at = c + Vector3.new(rng:NextNumber(-s * 0.45, s * 0.45), 0, rng:NextNumber(-s * 0.45, s * 0.45))
		prop(folder, if rng:NextNumber() < 0.4 then Assets.Front.Sandbags.B else Assets.Front.Sandbags.A, at, rng:NextNumber(0, 180), "Sandbags",
			{ Size = Vector3.new(6, 2, 1.5), Position = at + Vector3.new(0, GROUND_TOP + 1, 0), Color = Color3.fromRGB(140, 125, 90), Material = Enum.Material.Fabric })
	end
	-- tank traps along the sector's edges and ammo crates by the nests
	for _ = 1, rng:NextInteger(3, 5) do
		local edge = rng:NextInteger(1, 4)
		local u = rng:NextNumber(-s * 0.45, s * 0.45)
		local at = c + (if edge == 1 then Vector3.new(u, 0, s * 0.46) elseif edge == 2 then Vector3.new(u, 0, -s * 0.46) elseif edge == 3 then Vector3.new(s * 0.46, 0, u) else Vector3.new(-s * 0.46, 0, u))
		prop(folder, Assets.Front.Hedgehog, at, rng:NextNumber(0, 360), "Hedgehog",
			{ Size = Vector3.new(4, 4, 4), Position = at + Vector3.new(0, GROUND_TOP + 2, 0), Color = Color3.fromRGB(96, 54, 32), Material = Enum.Material.CorrodedMetal })
	end
	for _ = 1, 3 do
		local at = c + Vector3.new(rng:NextNumber(-s * 0.4, s * 0.4), 0, rng:NextNumber(-s * 0.4, s * 0.4))
		prop(folder, Assets.Front.AmmoCrate, at, rng:NextNumber(0, 360), "AmmoCrate",
			{ Size = Vector3.new(2, 1.3, 1.2), Position = at + Vector3.new(0, GROUND_TOP + 0.65, 0), Color = Color3.fromRGB(70, 78, 46), Material = Enum.Material.Metal })
	end
	-- wrecks: a burnt-out truck or two per sector
	for _ = 1, rng:NextInteger(1, 2) do
		local at = c + Vector3.new(rng:NextNumber(-s * 0.4, s * 0.4), 0, rng:NextNumber(-s * 0.4, s * 0.4))
		prop(folder, if rng:NextNumber() < 0.5 then Assets.Front.Truck.B else Assets.Front.Truck.A, at, rng:NextNumber(0, 180), "Wreck",
			{ Size = Vector3.new(7, 4, 14), Position = at + Vector3.new(0, GROUND_TOP + 2, 0), Color = Color3.fromRGB(50, 45, 40), Material = Enum.Material.CorrodedMetal })
	end
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

function Battlefield.BaseCFrame(faction)
	local n = H.Sectors
	local x = (if faction == "Union" then -1 else 1) * (n / 2 * H.SectorSize + 60)
	return CFrame.new(x + rng:NextNumber(-10, 10), GROUND_TOP + 4, rng:NextNumber(-40, 40))
end

function Battlefield.Init()
	folder = Instance.new("Folder")
	folder.Name = "Front"
	folder.Parent = workspace
	local n = H.Sectors
	local size = n * H.SectorSize + 300
	part(folder, { Name = "Ground", Size = Vector3.new(size, 4, size), Position = Vector3.new(0, 0, 0), Color = MUD, Material = Enum.Material.Ground })
	for index = 1, n * n do
		buildSector(index)
	end
	-- faction bases: a bunker each, beyond the grid edges
	for _, faction in W.Factions do
		local cf = Battlefield.BaseCFrame(faction)
		local bunker = part(folder, { Name = faction .. "Base", Size = Vector3.new(40, 12, 60), Position = Vector3.new(cf.Position.X + (if faction == "Union" then -30 else 30), GROUND_TOP + 6, 0), Color = Color3.fromRGB(80, 85, 80), Material = Enum.Material.Concrete })
		bunker:SetAttribute("Faction", faction)
		local flag = part(folder, { Size = Vector3.new(0.5, 20, 0.5), Position = Vector3.new(cf.Position.X, GROUND_TOP + 10, 0), Color = W.FactionColors[faction], Material = Enum.Material.Neon })
		flag.Name = faction .. "Flag"
	end
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime, Lighting.Brightness = 7.5, 1.5
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(110, 105, 100), Color3.fromRGB(120, 115, 110)
	Lighting.FogEnd, Lighting.FogColor = 900, Color3.fromRGB(150, 145, 135)
end

Battlefield.Sectors = sectors
return Battlefield
