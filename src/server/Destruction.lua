-- Destruction, story 001 (design/gdd/destruction.md §4.1–4.4, §6): props break, and what breaks is salvage.
--   * Props: crates, barrels, street signs, fence panels and terminals placed on the city's streets and the
--     road (Config.Destruction, a fixed seed: the same layout every cycle), plus every district / road
--     streetlight, adopted. Each is a Model tagged "Destructible" with Kind and Health attributes.
--   * Hits: Combat calls Destruction.Hit for melee arcs and gun rays that reach a prop (Combat.PropHit);
--     damage scales by the hit's break type against the kind's Resist (shared/Destruction.lua).
--   * Break: the intact parts are hidden, 2-6 chunks fly out (server-owned, tagged "DebrisChunk": the
--     grab-and-throw story picks these up), they freeze after ChunkSettleSeconds, and past ChunkCap the oldest
--     go. Salvage remains roll the kind's table (Loot.Spawn: hold X).
--   * The cycle restores every broken prop exactly and clears the chunks (Cycle.Dematerialized).
-- Props in a safe zone can't be hurt (same rule as bodies).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local District = require(Shared.District)
local Items = require(Shared.Items)
local Regions = require(Shared.Regions)
local SD = require(Shared.Destruction)
local Combat = require(script.Parent.Combat)
local Cycle = require(script.Parent.Cycle)
local Loot = require(script.Parent.Loot)

local Destruction = {}

local DC = Config.Destruction
Destruction.Tag, Destruction.ChunkTag = "Destructible", "DebrisChunk"
local TOP = District.GroundTop
local folder, chunkFolder
local chunks = {} -- in spawn order: { part, bornAt }

local function pivotOf(model)
	local pp = model.PrimaryPart
	return if pp then pp.Position else model:GetPivot().Position
end

local function mat(name)
	return Enum.Material[name or "Metal"]
end

local function newPart(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function finish(model, kind)
	local K = SD.Kinds[kind]
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Health", K.Health)
	model:SetAttribute("MaxHealth", K.Health)
	model:SetAttribute("Broken", false)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("IntactTransparency", p.Transparency)
			p:SetAttribute("IntactCollide", p.CanCollide)
		end
	end
	model.PrimaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") -- sounds and FX attach here
	CollectionService:AddTag(model, Destruction.Tag)
	return model
end

-- Procedural props (stand-ins for authored models: the GDD's fractures-are-authored rule applies once they exist).
local BUILD = {
	Crate = function(model, K, cf)
		newPart(model, { Name = "Body", Size = K.Size, CFrame = cf * CFrame.new(0, K.Size.Y / 2, 0), Color = K.Color, Material = mat(K.Material) })
	end,
	Barrel = function(model, K, cf)
		newPart(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(K.Size.Y, K.Size.X, K.Size.Z), CFrame = cf * CFrame.new(0, K.Size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = K.Color, Material = mat(K.Material) })
	end,
	StreetSign = function(model, K, cf)
		newPart(model, { Name = "Post", Size = K.Size, CFrame = cf * CFrame.new(0, K.Size.Y / 2, 0), Color = K.Color, Material = mat(K.Material) })
		newPart(model, { Name = "Plate", Size = K.Plate, CFrame = cf * CFrame.new(0, K.Size.Y - K.Plate.Y / 2, 0.3), Color = K.PlateColor, Material = Enum.Material.SmoothPlastic })
	end,
	Fence = function(model, K, cf)
		newPart(model, { Name = "Panel", Size = K.Size, CFrame = cf * CFrame.new(0, K.Size.Y / 2, 0), Color = K.Color, Material = mat(K.Material), Transparency = 0.25 })
	end,
	Terminal = function(model, K, cf)
		newPart(model, { Name = "Body", Size = K.Size, CFrame = cf * CFrame.new(0, K.Size.Y / 2, 0), Color = K.Color, Material = mat(K.Material) })
		newPart(model, { Name = "Screen", Size = Vector3.new(K.Size.X - 0.5, 1.4, 0.1), CFrame = cf * CFrame.new(0, K.Size.Y - 1.2, -K.Size.Z / 2 - 0.05), Color = K.Screen, Material = Enum.Material.Neon, CanCollide = false })
	end,
}

function Destruction.Spawn(kind, cframe)
	local K = SD.Kinds[kind]
	local model = Instance.new("Model")
	model.Name = K.Name
	BUILD[kind](model, K, cframe)
	model.Parent = folder
	return finish(model, kind)
end

-- Street spots of a district that are not in its plaza's safe zone (intersections and mid-block verges).
local function streetSpots(origin, rng, n)
	local spots = {}
	local g = District.Grid
	local tries = 0
	while #spots < n and tries < n * 20 do
		tries += 1
		local along = rng:NextInteger(0, g.Blocks)
		local across = District.StreetLine(rng:NextInteger(0, g.Blocks - 1)) + rng:NextNumber(g.StreetWidth * 0.5, g.BlockSize + g.StreetWidth * 0.5)
		local line = District.StreetLine(along) + (if rng:NextNumber() < 0.5 then -1 else 1) * (g.StreetWidth / 2 - 2)
		local p = if rng:NextNumber() < 0.5 then origin + Vector3.new(line, 0, across) else origin + Vector3.new(across, 0, line)
		if not District.InSafeZone(p + Vector3.new(0, TOP, 0)) then
			table.insert(spots, p)
		end
	end
	return spots
end

local PLACED = { "Crate", "Crate", "Barrel", "Barrel", "StreetSign", "Fence", "Terminal" }

local function placeProps()
	local rng = Random.new(DC.Seed)
	local n = 0
	for _, d in District.Districts do
		for _, p in streetSpots(d.Origin, rng, DC.PropsPerDistrict) do
			local kind = PLACED[rng:NextInteger(1, #PLACED)]
			Destruction.Spawn(kind, CFrame.new(p + Vector3.new(0, TOP, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			n += 1
		end
	end
	local Rd = Regions.Road
	for _ = 1, DC.PropsOnRoad do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = Vector3.new(Rd.X + side * (Rd.Width / 2 + rng:NextNumber(2, 6)), TOP, Rd.Z0 + Rd.Length * rng:NextNumber(0.08, 0.92))
		local kind = PLACED[rng:NextInteger(1, 4)] -- crates, barrels on the road
		Destruction.Spawn(kind, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		n += 1
	end
	return n
end

-- The existing lamps (District / Regions build a "Lamp" post and a "LampHead" above it) become streetlights.
local function adoptLamps()
	local n = 0
	for _, name in { "District", "Regions" } do
		local f = workspace:FindFirstChild(name)
		if f then
			local heads = {}
			for _, d in f:GetDescendants() do
				if d.Name == "LampHead" and d:IsA("BasePart") then
					table.insert(heads, d)
				end
			end
			local posts = {}
			for _, d in f:GetDescendants() do
				if d.Name == "Lamp" and d:IsA("BasePart") then
					table.insert(posts, d)
				end
			end
			for _, post in posts do
				local best
				for _, head in heads do
					local dx, dz = head.Position.X - post.Position.X, head.Position.Z - post.Position.Z
					if head.Parent and dx * dx + dz * dz < 1 and head.Position.Y > post.Position.Y then
						best = head
						break
					end
				end
				if best and not District.InSafeZone(post.Position) then
					local model = Instance.new("Model")
					model.Name = "Streetlight"
					model.Parent = post.Parent
					post.Parent, best.Parent = model, model
					finish(model, "Streetlight")
					n += 1
				end
			end
		end
	end
	return n
end

local function pruneChunks()
	while #chunks > DC.ChunkCap do
		local oldest = table.remove(chunks, 1)
		if oldest[1].Parent then
			oldest[1]:Destroy()
		end
	end
end

local function spawnChunks(model, K, point)
	local pieces = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(pieces, p)
		end
	end
	local per = math.max(1, math.floor(K.Chunks / math.max(#pieces, 1) + 0.5))
	for _, p in pieces do
		local axis = if p.Size.X >= p.Size.Y and p.Size.X >= p.Size.Z then "X" elseif p.Size.Y >= p.Size.Z then "Y" else "Z"
		for i = 1, per do
			local size = p.Size
			local offset = Vector3.zero
			if axis == "X" then
				size = Vector3.new(p.Size.X / per, p.Size.Y, p.Size.Z)
				offset = Vector3.new((i - 0.5) * size.X - p.Size.X / 2, 0, 0)
			elseif axis == "Y" then
				size = Vector3.new(p.Size.X, p.Size.Y / per, p.Size.Z)
				offset = Vector3.new(0, (i - 0.5) * size.Y - p.Size.Y / 2, 0)
			else
				size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z / per)
				offset = Vector3.new(0, 0, (i - 0.5) * size.Z - p.Size.Z / 2)
			end
			local c = Instance.new("Part")
			c.Name = "Chunk"
			c.Size = size * 0.92
			c.CFrame = p.CFrame * CFrame.new(offset)
			c.Color, c.Material, c.Transparency = p.Color, if p.Material == Enum.Material.Neon then Enum.Material.Glass else p.Material, p:GetAttribute("IntactTransparency") or 0
			c.Anchored, c.CanCollide = false, true
			c:SetAttribute("Kind", model:GetAttribute("Kind"))
			c:SetAttribute("From", p.Name) -- a post is a pipe, a plate is sheet metal (grab and throw reads this)
			CollectionService:AddTag(c, Destruction.ChunkTag)
			c.Parent = chunkFolder
			local away = c.Position - point
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 1, 0)
			c.AssemblyLinearVelocity = (away + Vector3.new(0, 0.6, 0)) * DC.ChunkImpulse
			table.insert(chunks, { c, os.clock() })
			task.delay(DC.ChunkSettleSeconds, function()
				if c.Parent and not c:GetAttribute("Held") then
					c.Anchored = true -- settled: stop costing physics
				end
			end)
		end
	end
	pruneChunks()
end

local function breakProp(model, point)
	local kind = model:GetAttribute("Kind")
	local K = SD.Kinds[kind]
	model:SetAttribute("Broken", true)
	model:SetAttribute("Health", 0)
	local base
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			base = base or p
			p.Transparency, p.CanCollide, p.CanQuery = 1, false, false
			local light = p:FindFirstChildWhichIsA("Light")
			if light then
				light:SetAttribute("WasEnabled", light.Enabled)
				light.Enabled = false
			end
		end
	end
	spawnChunks(model, K, point or (base and base.Position) or Vector3.zero)
	local at = pivotOf(model)
	local ground = Vector3.new(at.X, TOP + 0.8, at.Z)
	local bundle = Items.Roll(K.Salvage)
	if next(bundle) then
		Loot.Spawn(CFrame.new(ground + Vector3.new(0, 0.5, 0)), bundle, { Label = K.Name .. " salvage", Action = "Salvage", Hold = DC.SalvageHold, Size = Vector3.new(2.2, 0.6, 2.2), Color = Color3.fromRGB(95, 85, 70), Lifetime = Config.Cycle.Seconds })
	end
	Combat.FX("PropBreak", model, ground)
end

-- Damage to a prop from a hit. Returns the damage dealt (after resist), or nil when nothing happened.
function Destruction.Damage(model, amount, breakType, point)
	if not (model and model:GetAttribute("Kind")) or model:GetAttribute("Broken") then
		return nil
	end
	local K = SD.Kinds[model:GetAttribute("Kind")]
	local pivot = pivotOf(model)
	if District.InSafeZone(pivot) then
		return nil
	end
	local dealt = amount * (1 - math.clamp((K.Resist or {})[breakType] or 0, -2, 1))
	if dealt <= 0 then
		return 0
	end
	local hp = (model:GetAttribute("Health") or K.Health) - dealt
	model:SetAttribute("Health", math.max(0, hp))
	Combat.FX("PropHit", model, point or pivot)
	if hp <= 0 then
		breakProp(model, point)
	end
	return dealt
end

-- Combat's hook (Combat.PropHit): a melee arc or a gun ray reached a prop.
local function onCombatHit(attacker, model, damage, spec, weaponDef, heavy, point)
	local breakType = SD.BreakTypeOf(spec, weaponDef)
	Destruction.Damage(model, damage * (if heavy then DC.HeavyMult else 1), breakType, point)
end

-- The cycle: everything comes back exactly; the chunks are gone.
function Destruction.Restore()
	local n = 0
	for _, model in CollectionService:GetTagged(Destruction.Tag) do
		if model:GetAttribute("Broken") then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = p:GetAttribute("IntactTransparency") or 0
					p.CanCollide = p:GetAttribute("IntactCollide") ~= false
					p.CanQuery = true
					local light = p:FindFirstChildWhichIsA("Light")
					if light and light:GetAttribute("WasEnabled") ~= nil then
						light.Enabled = light:GetAttribute("WasEnabled")
					end
				end
			end
			model:SetAttribute("Broken", false)
			n += 1
		end
		model:SetAttribute("Health", model:GetAttribute("MaxHealth"))
	end
	for _, c in chunks do
		if c[1].Parent then
			c[1]:Destroy()
		end
	end
	table.clear(chunks)
	return n
end

function Destruction.Chunks()
	return chunks
end

function Destruction.Init()
	folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = workspace
	chunkFolder = Instance.new("Folder")
	chunkFolder.Name = "Debris"
	chunkFolder.Parent = workspace
	local placed = placeProps()
	local lamps = adoptLamps()
	Combat.PropHit = onCombatHit
	Cycle.Dematerialized.Event:Connect(Destruction.Restore)
	Destruction.Built = { Props = placed, Streetlights = lamps }
end

return Destruction
