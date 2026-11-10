-- Builds the megacity's industrial ring around the core (layout: shared/Megacity.lua), the green
-- pockets, the edge wall and the skyline past it, and runs the two things the place does to a body:
-- toxic sludge burns, a green pocket lets wounds close.
--
-- Everything here is generated from parts with a fixed seed (the city is the same on every server).
-- Big industrial shapes use the Blender kit in Assets.Industry when it loads and fall back to parts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Assets = require(Shared.Assets)
local M = require(Shared.Megacity)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local Destruction = require(script.Parent.Destruction)

local Megacity = {}
local C = Config.Megacity
local TOP = M.Top
local rng = Random.new(90210)
local folder, skyFolder
local api -- City's helpers: cache(district, position), lockup(district, position, tier), tower(style, x, z, footprint)
local counts = { parts = 0, lights = 0, emitters = 0, kit = 0, props = 0 }

local PAL = {
	Ground = Color3.fromRGB(46, 44, 42),
	Road = Color3.fromRGB(40, 40, 44),
	Line = Color3.fromRGB(150, 140, 100),
	Rust = Color3.fromRGB(110, 62, 40),
	RustDark = Color3.fromRGB(72, 46, 36),
	Steel = Color3.fromRGB(88, 90, 96),
	Concrete = Color3.fromRGB(96, 94, 90),
	ConcreteDark = Color3.fromRGB(58, 56, 56),
	Soot = Color3.fromRGB(34, 32, 32),
	Sludge = Color3.fromRGB(150, 190, 40),
	Molten = Color3.fromRGB(255, 120, 30),
	Warning = Color3.fromRGB(200, 40, 34),
	White = Color3.fromRGB(210, 206, 196),
	Leaf = { Color3.fromRGB(58, 122, 54), Color3.fromRGB(84, 146, 62), Color3.fromRGB(46, 106, 72), Color3.fromRGB(104, 136, 50) },
	Bark = Color3.fromRGB(78, 58, 42),
	Moss = Color3.fromRGB(70, 110, 52),
	Glass = Color3.fromRGB(170, 220, 210),
	Sky = Color3.fromRGB(26, 24, 30),
}

-- ===== primitives =====
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or folder
	counts.parts += 1
	return p
end

-- A vertical cylinder standing on `base` (its bottom centre).
local function column(base, radius, height, props, parent)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	props.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props, parent)
end

-- A cylinder from a to b.
local function pipe(a, b, radius, props, parent)
	local len = (b - a).Magnitude
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(len, radius * 2, radius * 2)
	props.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	return part(props, parent)
end

-- A box from a to b (thickness w x h).
local function beam(a, b, w, h, props, parent)
	local len = (b - a).Magnitude
	props.Size = Vector3.new(w, h, len)
	props.CFrame = CFrame.lookAt((a + b) / 2, b)
	return part(props, parent)
end

local function ball(center, size, props, parent)
	props.Shape = Enum.PartType.Ball
	props.Size = size
	props.CFrame = props.CFrame or CFrame.new(center)
	return part(props, parent)
end

local function glow(p, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range or 24, brightness or 1.2
	light.Shadows = false
	light.Parent = p
	counts.lights += 1
	return light
end

local function seq(a, b)
	return NumberSequence.new(a, b)
end

-- Smoke from a chimney top. kind: "Soot" (dark), "Steam" (white), "Sludge" (green bubbles), "Sparks".
local function emit(p, kind, scale)
	scale = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	if kind == "Soot" or kind == "Steam" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(if kind == "Soot" then Color3.fromRGB(60, 54, 50) else Color3.fromRGB(220, 218, 210))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * scale), NumberSequenceKeypoint.new(1, 30 * scale) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(10, 16)
		e.Rate = 3
		e.Speed = NumberRange.new(6 * scale, 10 * scale)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Acceleration = Vector3.new(3, 0.5, 1.5) -- the wind takes it east
		e.RotSpeed = NumberRange.new(-12, 12)
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "Sludge" then
		e.Color = ColorSequence.new(Color3.fromRGB(170, 220, 60))
		e.Size = seq(0.6, 0)
		e.Transparency = seq(0.2, 1)
		e.Lifetime = NumberRange.new(1, 2)
		e.Rate = 6
		e.Speed = NumberRange.new(1, 3)
		e.LightEmission = 0.6
		e.EmissionDirection = Enum.NormalId.Top
	elseif kind == "Sparks" then
		e.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
		e.Size = seq(0.25, 0)
		e.Lifetime = NumberRange.new(0.2, 0.5)
		e.Rate = 10
		e.Speed = NumberRange.new(8, 16)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
	elseif kind == "Fireflies" then
		e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		e.Size = seq(0.25, 0.15)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 8)
		e.Rate = 8
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Acceleration = Vector3.new(0, 0.2, 0)
	end
	e.Parent = p
	counts.emitters += 1
	return e
end

-- A Blender kit model if it loads (scaled to `scale`), else nil so the caller builds parts.
local function kit(id, cf, scale, name)
	if not id then
		return nil
	end
	local model = ModelAssets.Spawn(id, cf, name, folder)
	if model then
		counts.kit += 1
		if scale and scale ~= 1 then
			pcall(function()
				model:ScaleTo(scale)
			end)
		end
	end
	return model
end

local function prop(id, position, yaw)
	counts.props += 1
	return Destruction.SpawnProp(id, CFrame.new(position.X, TOP, position.Z) * CFrame.Angles(0, yaw or rng:NextNumber(0, math.pi * 2), 0))
end

local function v2(x, z)
	return Vector3.new(x, 0, z)
end

local function at(x, z, y)
	return Vector3.new(x, y or TOP, z)
end

-- ===== placement =====
local PLAZA = 60

local function inSludge(x, z, margin)
	for _, s in M.Sludge do
		local dx, dz = x - s.Center.X, z - s.Center.Z
		if s.Radius then
			if dx * dx + dz * dz < (s.Radius + margin) ^ 2 then
				return true
			end
		elseif math.abs(dx) < s.Half.X + margin and math.abs(dz) < s.Half.Z + margin then
			return true
		end
	end
	return false
end

local function nearPocket(x, z, margin)
	for _, p in M.Pockets do
		if (v2(x, z) - v2(p.Center.X, p.Center.Z)).Magnitude < p.Radius + margin then
			return true
		end
	end
	return false
end

-- Is a lot of radius r at x/z free to build on inside district d?
local function clear(d, x, z, r)
	if d then
		local lx, lz = x - d.Center.X, z - d.Center.Z
		if math.abs(lx) > d.Size / 2 - r - 8 or math.abs(lz) > d.Size / 2 - r - 8 then
			return false
		end
		if math.sqrt(lx * lx + lz * lz) < PLAZA + r then
			return false
		end
	end
	return not M.OnRoad(x, z, r + 4) and not inSludge(x, z, r + 4) and not nearPocket(x, z, r + 10)
end

-- Jittered lots over a district: returns { Vector3 } of free lot centres.
local function lots(d, pitch, r)
	local out = {}
	local half = d.Size / 2
	for x = d.Center.X - half + pitch / 2, d.Center.X + half - pitch / 2, pitch do
		for z = d.Center.Z - half + pitch / 2, d.Center.Z + half - pitch / 2, pitch do
			local px, pz = x + rng:NextNumber(-pitch * 0.18, pitch * 0.18), z + rng:NextNumber(-pitch * 0.18, pitch * 0.18)
			if clear(d, px, pz, r) then
				table.insert(out, at(px, pz))
			end
		end
	end
	return out
end

local function pick(weights)
	local total = 0
	for _, w in weights do
		total += w[2]
	end
	local roll = rng:NextNumber(0, total)
	for _, w in weights do
		roll -= w[2]
		if roll <= 0 then
			return w[1]
		end
	end
	return weights[#weights][1]
end

-- Spots for caches and population anchors, filled by each builder.
local function remember(d, position)
	d.Spots = d.Spots or {}
	table.insert(d.Spots, position)
end

-- ===== ground, roads, wall =====
local function slab(x0, x1, z0, z1, color, material, name, top, thick)
	thick = thick or 4
	top = top or TOP
	return part({ Name = name or "MegaGround", Size = Vector3.new(x1 - x0, thick, z1 - z0), Position = Vector3.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2),
		Color = color or PAL.Ground, Material = material or Enum.Material.Concrete })
end

local FLOORS = {
	Stacks = { Color3.fromRGB(52, 48, 46), Enum.Material.Concrete },
	Slag = { Color3.fromRGB(40, 38, 36), Enum.Material.Basalt },
	Pylon = { Color3.fromRGB(78, 76, 72), Enum.Material.Pebble },
	Hab = { Color3.fromRGB(60, 58, 64), Enum.Material.Pavement },
	Scrap = { Color3.fromRGB(78, 58, 44), Enum.Material.Ground },
	Foundry = { Color3.fromRGB(44, 40, 40), Enum.Material.Slate },
}

local function buildGround()
	local B = M.Bounds
	local E = M.CoreEdge
	-- west and east bands beside the core
	slab(B.X0, -E, -E, B.Z1)
	slab(E, B.X1, -E, B.Z1)
	-- the south band, leaving the Sumps' square open (it builds its own sunken floor)
	local s = M.GetDistrict("Sumps")
	local sx0, sx1 = s.Center.X - s.Size / 2, s.Center.X + s.Size / 2
	local sz0, sz1 = s.Center.Z - s.Size / 2, s.Center.Z + s.Size / 2
	slab(B.X0, -200, B.Z0, -E)
	slab(-200, sx0, B.Z0, -E)
	slab(sx1, B.X1, B.Z0, -E)
	slab(sx0, sx1, B.Z0, sz0)
	slab(sx0, sx1, sz1, -E)
	-- each district's own floor, a hair above the base so the two never fight
	for _, d in M.Districts do
		local f = FLOORS[d.Style]
		if f then
			local h = d.Size / 2
			slab(d.Center.X - h, d.Center.X + h, d.Center.Z - h, d.Center.Z + h, f[1], f[2], "DistrictFloor", TOP + 0.06, 0.12)
		end
	end
end

local function buildRoads()
	for _, r in M.Roads do
		local a, b = at(r.A.X, r.A.Z, TOP + 0.1), at(r.B.X, r.B.Z, TOP + 0.1)
		local len = (b - a).Magnitude
		part({ Name = "Road", Size = Vector3.new(r.Width, 0.2, len + r.Width), CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b), Color = PAL.Road, Material = Enum.Material.Asphalt })
		part({ Name = "RoadLine", Size = Vector3.new(0.6, 0.22, len), CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b), Color = PAL.Line, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		-- lamps and wrecks along it: every one is breakable salvage
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local n = math.floor(len / 90)
		for k = 1, n do
			local p = a + dir * (k * 90) + side * (r.Width / 2 + 3) * (if k % 2 == 0 then 1 else -1)
			if not M.InCore(p.X, p.Z) then
				prop("Streetlight", p, 0)
				if rng:NextNumber() < 0.45 then
					local w = a + dir * (k * 90 + rng:NextNumber(10, 40)) + side * rng:NextNumber(-r.Width / 3, r.Width / 3)
					prop(if rng:NextNumber() < 0.6 then "CarWreck" else "Slab", w)
				end
			end
		end
	end
end

-- The edge: a wall of dead megablocks, different heights, lit windows here and there.
local function wallRun(a, b, inward)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local n = math.ceil(len / 110)
	local seg = len / n
	for i = 0, n - 1 do
		local h = rng:NextNumber(120, 260)
		local depth = M.WallDepth + rng:NextNumber(-10, 20)
		local mid = a + dir * (seg * (i + 0.5)) - inward * (depth / 2 - M.WallDepth / 2)
		local cf = CFrame.lookAt(at(mid.X, mid.Z, TOP + h / 2), at(mid.X, mid.Z, TOP + h / 2) + inward)
		part({ Name = "EdgeBlock", Size = Vector3.new(seg + 2, h, depth), CFrame = cf, Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
		-- lit floors on the face that looks into the city
		for _ = 1, rng:NextInteger(0, 3) do
			local y = rng:NextNumber(12, h - 10)
			local c = ({ Color3.fromRGB(255, 170, 80), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 80, 160) })[rng:NextInteger(1, 3)]
			part({ Name = "EdgeWindows", Size = Vector3.new(seg * rng:NextNumber(0.3, 0.8), 1.2, 0.4), CFrame = cf * CFrame.new(rng:NextNumber(-seg * 0.2, seg * 0.2), y - h / 2, -depth / 2 - 0.2), Color = c, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		end
		if rng:NextNumber() < 0.3 then
			-- a warning light on the roofline
			part({ Name = "EdgeBeacon", Size = Vector3.new(3, 3, 3), Position = at(mid.X, mid.Z, TOP + h + 1.5), Color = PAL.Warning, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		end
	end
end

local function buildWall()
	local B = M.Bounds
	wallRun(at(B.X0, B.Z0), at(B.X1, B.Z0), Vector3.new(0, 0, 1)) -- south
	wallRun(at(B.X0, B.Z0), at(B.X0, B.Z1), Vector3.new(1, 0, 0)) -- west
	wallRun(at(B.X1, B.Z0), at(B.X1, B.Z1), Vector3.new(-1, 0, 0)) -- east
	-- north, beside the scarp's ridges (the frontier's own hills close |x| < 980)
	wallRun(at(B.X0, B.Z1), at(-980, B.Z1), Vector3.new(0, 0, -1))
	wallRun(at(980, B.Z1), at(B.X1, B.Z1), Vector3.new(0, 0, -1))
end

-- Past the wall: the rest of the planet, the same city on and on into the smog. Unreachable, no
-- collisions, no shadows; a few chimneys smoke.
local function buildSkyline()
	skyFolder = Instance.new("Folder")
	skyFolder.Name = "Skyline"
	skyFolder.Parent = workspace
	local B = M.Bounds
	local function outside(x, z)
		if x > B.X0 - 120 and x < B.X1 + 120 and z > B.Z0 - 120 and z < B.Z1 + 40 then
			return false
		end
		-- the frontier valley (and its ring of peaks) is open country to the north
		if z > B.Z1 - 40 and z < 2450 and math.abs(x) < 1150 then
			return false
		end
		-- keep the test arena and the raid instance clear
		local arena = Config.Dev.ArenaOrigin
		if math.abs(x - arena.X) < 600 and math.abs(z - arena.Z) < 600 then
			return false
		end
		local raid = Config.Raid.Origin
		if math.abs(x - raid.X) < 600 and math.abs(z - raid.Z) < 600 then
			return false
		end
		return true
	end
	local placed, stacks, tries = 0, 0, 0
	while placed < C.SkylineTowers and tries < C.SkylineTowers * 20 do
		tries += 1
		local x, z = rng:NextNumber(-3200, 3200), rng:NextNumber(-3300, 3400)
		if outside(x, z) then
			placed += 1
			local far = math.max(math.abs(x) - B.X1, B.Z0 - z, z - B.Z1, 0)
			if stacks < C.SkylineStacks and rng:NextNumber() < 0.15 then
				stacks += 1
				local h = rng:NextNumber(380, 720)
				local r = rng:NextNumber(14, 26)
				local stack = column(at(x, z, 0), r, h, { Name = "SkyStack", Color = PAL.Soot, Material = Enum.Material.Concrete, CanCollide = false, CastShadow = false }, skyFolder)
				column(at(x, z, h - 30), r + 0.6, 6, { Name = "SkyStackBand", Color = PAL.Warning, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, skyFolder)
				local top = part({ Name = "SkyStackTop", Size = Vector3.new(r, 1, r), Position = at(x, z, h + 1), Transparency = 1, CanCollide = false, CastShadow = false }, skyFolder)
				local e = emit(top, "Soot", 3)
				e.Rate = 1.5
				e.Lifetime = NumberRange.new(20, 30)
				stack:SetAttribute("Skyline", true)
			else
				local w, dpt = rng:NextNumber(70, 220), rng:NextNumber(70, 220)
				-- taller the further out, so they show over the haze and over the peaks
				local h = rng:NextNumber(160, 420) + far * rng:NextNumber(0.1, 0.35)
				local cf = CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				local tower = part({ Name = "SkyTower", Size = Vector3.new(w, h, dpt), CFrame = cf, Color = PAL.Sky, Material = Enum.Material.Concrete, CanCollide = false, CastShadow = false }, skyFolder)
				tower:SetAttribute("Skyline", true)
				for _ = 1, rng:NextInteger(0, 2) do
					local c = ({ Color3.fromRGB(255, 150, 70), Color3.fromRGB(90, 180, 255), Color3.fromRGB(255, 60, 150) })[rng:NextInteger(1, 3)]
					part({ Name = "SkyWindows", Size = Vector3.new(w + 0.4, 3, dpt + 0.4), CFrame = cf * CFrame.new(0, rng:NextNumber(-h * 0.4, h * 0.45), 0), Color = c, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CastShadow = false }, skyFolder)
				end
				if rng:NextNumber() < 0.5 then
					part({ Name = "SkyBeacon", Size = Vector3.new(8, 8, 8), Position = Vector3.new(x, h + 4, z), Color = PAL.Warning, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, skyFolder)
				end
			end
		end
	end
	return placed, stacks
end

-- ===== the Stacks: refinery =====
local function smokestack(base, r, h, smoke)
	local id = Assets.Industry and Assets.Industry.Smokestack
	local model = kit(id, CFrame.new(base), h / 120, "Smokestack")
	if not model then
		column(base, r + 2, 6, { Name = "StackPlinth", Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
		column(base, r, h, { Name = "Smokestack", Color = Color3.fromRGB(96, 84, 76), Material = Enum.Material.Brick })
		for k = 1, 2 do
			column(base + Vector3.new(0, h - 6 - k * 7, 0), r + 0.3, 3, { Name = "StackBand", Color = if k == 1 then PAL.Warning else PAL.White, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
		column(base + Vector3.new(0, h, 0), r + 0.6, 1.5, { Name = "StackRim", Color = PAL.Soot, Material = Enum.Material.Metal })
	end
	if smoke then
		local top = part({ Name = "StackMouth", Size = Vector3.new(r, 1, r), Position = base + Vector3.new(0, h + 2, 0), Transparency = 1, CanCollide = false, CastShadow = false })
		emit(top, "Soot", r / 5)
	end
end

local function tank(base, r, h)
	local id = Assets.Industry and Assets.Industry.Tank
	if kit(id, CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), r / 12, "Tank") then
		return
	end
	local color = ({ Color3.fromRGB(168, 160, 146), Color3.fromRGB(120, 112, 100), PAL.Rust })[rng:NextInteger(1, 3)]
	column(base, r, h, { Name = "Tank", Color = color, Material = Enum.Material.CorrodedMetal })
	ball(base + Vector3.new(0, h, 0), Vector3.new(r * 2, r * 0.6, r * 2), { Name = "TankDome", Color = color, Material = Enum.Material.CorrodedMetal })
	column(base + Vector3.new(0, h * 0.55, 0), r + 0.4, 1, { Name = "TankBand", Color = PAL.Soot, Material = Enum.Material.Metal, CanCollide = false })
	-- a ladder up the side: climbable
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, h, 2)
	truss.Position = base + Vector3.new(r + 1, h / 2, 0)
	truss.Color = PAL.Steel
	truss.Parent = folder
end

local function flare(base, h)
	column(base, 1.4, h, { Name = "FlareStack", Color = PAL.Steel, Material = Enum.Material.Metal })
	local tip = part({ Name = "FlareTip", Size = Vector3.new(3, 4, 3), Position = base + Vector3.new(0, h + 2, 0), Color = PAL.Molten, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 12, 18
	fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 60, 20)
	fire.Parent = tip
	glow(tip, PAL.Molten, 60, 2)
	-- guy wires
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		beam(base + Vector3.new(0, h * 0.7, 0), base + Vector3.new(math.cos(a) * h * 0.35, 0, math.sin(a) * h * 0.35), 0.2, 0.2, { Name = "GuyWire", Color = PAL.Steel, Material = Enum.Material.Metal, CanCollide = false })
	end
end

local function pipeRack(a, b)
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local len = (b - a).Magnitude
	for k = 0, math.floor(len / 16) do
		local p = a + dir * (k * 16)
		for _, s in { -1, 1 } do
			part({ Name = "RackPost", Size = Vector3.new(1, 12, 1), Position = p + side * (s * 4) + Vector3.new(0, 6, 0), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
		end
		part({ Name = "RackBeam", Size = Vector3.new(9, 1, 1), CFrame = CFrame.lookAt(p + Vector3.new(0, 12, 0), p + Vector3.new(0, 12, 0) + side), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
	end
	for s = -1, 1 do
		pipe(a + side * (s * 2.6) + Vector3.new(0, 13.4, 0), b + side * (s * 2.6) + Vector3.new(0, 13.4, 0), 1.2, { Name = "RackPipe", Color = ({ PAL.Rust, PAL.Steel, Color3.fromRGB(140, 130, 60) })[s + 2], Material = Enum.Material.CorrodedMetal })
	end
	-- a walkway on top
	beam(a + Vector3.new(0, 15, 0), b + Vector3.new(0, 15, 0), 8, 0.4, { Name = "RackDeck", Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
end

local function buildStacks(d)
	local spots = lots(d, 110, 40)
	local racks = {}
	for _, p in spots do
		local kind = pick({ { "Stacks", 0.35 }, { "Tanks", 0.3 }, { "Flare", 0.1 }, { "Rack", 0.25 } })
		if kind == "Stacks" then
			for k = 1, rng:NextInteger(2, 3) do
				local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				smokestack(p + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14), rng:NextNumber(4, 7), rng:NextNumber(70, 150), rng:NextNumber() < 0.6)
			end
		elseif kind == "Tanks" then
			for i = -1, 1, 2 do
				for j = -1, 1, 2 do
					tank(p + Vector3.new(i * 15, 0, j * 15), rng:NextNumber(9, 12), rng:NextNumber(14, 24))
				end
			end
			pipe(p + Vector3.new(-15, 4, 0), p + Vector3.new(15, 4, 0), 1, { Name = "TankPipe", Color = PAL.Steel, Material = Enum.Material.Metal })
		elseif kind == "Flare" then
			flare(p, rng:NextNumber(60, 90))
			prop("Barrel", p + Vector3.new(8, 0, 6))
		else
			table.insert(racks, p)
		end
		remember(d, p + Vector3.new(30, 1.5, 30))
	end
	-- racks run between neighbouring rack lots
	for i, p in racks do
		local q = racks[i + 1] or (d.Center + Vector3.new(PLAZA + 10, 0, 0))
		if (q - p).Magnitude < 260 and (q - p).Magnitude > 20 then
			pipeRack(p, q)
		else
			pipeRack(p - Vector3.new(30, 0, 0), p + Vector3.new(30, 0, 0))
		end
	end
	-- the landmark: the great stack beside the plaza, seen from everywhere
	smokestack(d.Center + Vector3.new(-40, 0, -40), 11, 230, true)
	local beacon = part({ Name = "GreatStackBeacon", Size = Vector3.new(4, 4, 4), Position = d.Center + Vector3.new(-40, 234, -40), Color = PAL.Warning, Material = Enum.Material.Neon, CanCollide = false })
	beacon:SetAttribute("District", d.Name)
end

-- ===== Slag Flats =====
local function buildSlag(d)
	for _, s in M.Sludge do
		if s.Radius and M.DistrictAt(s.Center) == d then
			local pool = column(at(s.Center.X, s.Center.Z, s.Center.Y - 0.3), s.Radius, 0.32, { Name = "SludgePool", Color = PAL.Sludge, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, CastShadow = false })
			pool:SetAttribute("Sludge", true)
			column(at(s.Center.X, s.Center.Z, TOP), s.Radius + 3, 0.2, { Name = "SludgeCrust", Color = Color3.fromRGB(70, 74, 34), Material = Enum.Material.Slate, CanCollide = false })
			if rng:NextNumber() < 0.6 then
				emit(pool, "Sludge")
			end
		end
	end
	for _, p in lots(d, 100, 34) do
		local kind = pick({ { "Heap", 0.5 }, { "Crane", 0.2 }, { "Conveyor", 0.3 } })
		if kind == "Heap" then
			for _ = 1, rng:NextInteger(2, 4) do
				local w, h = rng:NextNumber(30, 60), rng:NextNumber(14, 26)
				local c = p + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
				ball(c, Vector3.new(w, h * 2, w * rng:NextNumber(0.7, 1)), { Name = "SlagHeap", Color = Color3.fromRGB(46, 42, 40), Material = Enum.Material.Basalt, CFrame = CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) })
				if rng:NextNumber() < 0.35 then
					part({ Name = "SlagGlow", Size = Vector3.new(w * 0.3, 0.6, 1.2), CFrame = CFrame.new(c + Vector3.new(0, h * 0.9, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, math.pi), 0), Color = PAL.Molten, Material = Enum.Material.Neon, CanCollide = false })
				end
			end
		elseif kind == "Crane" then
			local yaw = rng:NextNumber(0, math.pi)
			local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
			for _, s in { -1, 1 } do
				beam(cf:PointToWorldSpace(Vector3.new(s * 22, 0, -6)), cf:PointToWorldSpace(Vector3.new(s * 20, 40, 0)), 1.6, 1.6, { Name = "CraneLeg", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
				beam(cf:PointToWorldSpace(Vector3.new(s * 22, 0, 6)), cf:PointToWorldSpace(Vector3.new(s * 20, 40, 0)), 1.6, 1.6, { Name = "CraneLeg", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			end
			beam(cf:PointToWorldSpace(Vector3.new(-26, 41, 0)), cf:PointToWorldSpace(Vector3.new(26, 41, 0)), 3, 3, { Name = "CraneBeam", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			local hx = rng:NextNumber(-14, 14)
			beam(cf:PointToWorldSpace(Vector3.new(hx, 40, 0)), cf:PointToWorldSpace(Vector3.new(hx, 18, 0)), 0.3, 0.3, { Name = "CraneCable", Color = PAL.Soot, Material = Enum.Material.Metal, CanCollide = false })
			part({ Name = "CraneHook", Size = Vector3.new(3, 4, 3), CFrame = cf * CFrame.new(hx, 16, 0), Color = PAL.Soot, Material = Enum.Material.Metal })
		else
			local yaw = rng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
			local low, high = p - dir * 36, p + dir * 30
			ball(high, Vector3.new(36, 44, 30), { Name = "SlagHeap", Color = Color3.fromRGB(50, 46, 42), Material = Enum.Material.Basalt })
			beam(low + Vector3.new(0, 1, 0), high + Vector3.new(0, 24, 0), 5, 1.2, { Name = "Conveyor", Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
			for k = 1, 3 do
				local q = low:Lerp(high, k / 4)
				part({ Name = "ConveyorLeg", Size = Vector3.new(1, 24 * k / 4, 1), Position = q + Vector3.new(0, 12 * k / 4, 0), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
			end
		end
		remember(d, p + Vector3.new(26, 1.5, -26))
	end
	-- the landmark: a ladle the size of a house, tipped over, still glowing inside
	local c = d.Center + Vector3.new(44, 0, -44)
	local ladle = part({ Name = "GiantLadle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 26, 26), CFrame = CFrame.new(c + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0.6, 1.1), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
	ladle:SetAttribute("District", d.Name)
	local inner = part({ Name = "LadleGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 22, 22), CFrame = ladle.CFrame * CFrame.new(11.2, 0, 0), Color = PAL.Molten, Material = Enum.Material.Neon, CanCollide = false })
	glow(inner, PAL.Molten, 50, 2)
end

-- ===== Pylon Fields: power =====
local function pylonTower(base, yaw, h)
	local id = Assets.Industry and Assets.Industry.Pylon
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	if kit(id, cf, h / 60, "Pylon") then
		return cf
	end
	local w = 6
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			beam(cf:PointToWorldSpace(Vector3.new(sx * w, 0, sz * w)), cf:PointToWorldSpace(Vector3.new(sx * 1.2, h, sz * 1.2)), 0.7, 0.7, { Name = "PylonLeg", Color = PAL.Steel, Material = Enum.Material.Metal })
		end
	end
	for k = 1, 3 do
		local y = h * k / 4
		local s = w * (1 - k / 4) + 1.2 * (k / 4)
		part({ Name = "PylonBrace", Size = Vector3.new(s * 2, 0.5, s * 2), CFrame = cf * CFrame.new(0, y, 0), Color = PAL.Steel, Material = Enum.Material.Metal, Transparency = 0, CanCollide = false })
	end
	for _, y in { h * 0.7, h * 0.88 } do
		part({ Name = "PylonArm", Size = Vector3.new(26, 0.8, 0.8), CFrame = cf * CFrame.new(0, y, 0), Color = PAL.Steel, Material = Enum.Material.Metal })
	end
	part({ Name = "PylonTop", Size = Vector3.new(1.2, 6, 1.2), CFrame = cf * CFrame.new(0, h + 3, 0), Color = PAL.Steel, Material = Enum.Material.Metal })
	return cf
end

local function coolingTower(base, r, h)
	local id = Assets.Industry and Assets.Industry.CoolingTower
	if not kit(id, CFrame.new(base), h / 100, "CoolingTower") then
		-- a waisted hyperboloid from stacked rings
		local rings = 10
		for i = 0, rings - 1 do
			local t = (i + 0.5) / rings
			local waist = 0.7
			local rr = r * (waist + (1 - waist) * ((t - 0.72) / 0.72) ^ 2 * 1.4)
			column(base + Vector3.new(0, h * i / rings, 0), math.max(rr, r * waist), h / rings + 0.2, { Name = "CoolingTower", Color = Color3.fromRGB(150, 146, 138), Material = Enum.Material.Concrete })
		end
	end
	local mouth = part({ Name = "TowerMouth", Size = Vector3.new(r, 1, r), Position = base + Vector3.new(0, h + 2, 0), Transparency = 1, CanCollide = false, CastShadow = false })
	emit(mouth, "Steam", r / 6)
end

local function transformerYard(p)
	local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	-- chain-link fence
	for _, s in { -1, 1 } do
		part({ Name = "YardFence", Size = Vector3.new(44, 7, 0.3), CFrame = cf * CFrame.new(0, 3.5, s * 20), Color = PAL.Steel, Material = Enum.Material.DiamondPlate, Transparency = 0.55 })
		part({ Name = "YardFence", Size = Vector3.new(0.3, 7, 40), CFrame = cf * CFrame.new(s * 22, 3.5, 0), Color = PAL.Steel, Material = Enum.Material.DiamondPlate, Transparency = 0.55 })
	end
	local sparked = false
	for i = -1, 1 do
		for j = -1, 1, 2 do
			local box = part({ Name = "Transformer", Size = Vector3.new(8, 8, 6), CFrame = cf * CFrame.new(i * 13, 4, j * 8), Color = Color3.fromRGB(96, 104, 92), Material = Enum.Material.Metal })
			for k = -1, 1 do
				part({ Name = "Insulator", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.2, 1.2), CFrame = box.CFrame * CFrame.new(k * 2.5, 5.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 90, 60), Material = Enum.Material.Glass, CanCollide = false })
			end
			if not sparked and rng:NextNumber() < 0.25 then
				sparked = true
				local arc = part({ Name = "Arc", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = box.CFrame * CFrame.new(0, 7.2, 0), Color = Color3.fromRGB(150, 210, 255), Material = Enum.Material.Neon, CanCollide = false })
				emit(arc, "Sparks")
				glow(arc, Color3.fromRGB(120, 190, 255), 22, 1.6)
			end
		end
	end
end

local function buildPylon(d)
	-- three power lines across the district, west to east
	local h = 58
	for _, off in { -230, 0, 230 } do
		local prev
		for x = d.Center.X - d.Size / 2 + 40, d.Center.X + d.Size / 2 - 40, 115 do
			local z = d.Center.Z + off
			if clear(nil, x, z, 8) and (v2(x, z) - v2(d.Center.X, d.Center.Z)).Magnitude > PLAZA + 10 then
				pylonTower(at(x, z), 0, h)
				local here = at(x, z)
				if prev then
					for _, s in { -1, 1 } do
						for _, y in { h * 0.7, h * 0.88 } do
							pipe(prev + Vector3.new(0, y, s * 12), here + Vector3.new(0, y, s * 12), 0.15, { Name = "PowerLine", Color = PAL.Soot, Material = Enum.Material.Metal, CanCollide = false, CastShadow = false })
						end
					end
				end
				prev = here
			else
				prev = nil
			end
		end
	end
	local towers = 0
	for _, p in lots(d, 130, 46) do
		if math.abs(p.Z - d.Center.Z) % 230 < 30 or math.abs(p.Z - d.Center.Z) % 230 > 200 then
			continue -- under a power line
		end
		if towers < 2 and rng:NextNumber() < 0.35 then
			towers += 1
			coolingTower(p, 34, 100)
		elseif rng:NextNumber() < 0.75 then
			transformerYard(p)
		else
			-- a substation hut
			local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			part({ Name = "Substation", Size = Vector3.new(20, 12, 14), CFrame = cf * CFrame.new(0, 6, 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
			part({ Name = "SubstationRoof", Size = Vector3.new(22, 1, 16), CFrame = cf * CFrame.new(0, 12.5, 0), Color = PAL.ConcreteDark, Material = Enum.Material.Metal })
			prop("Terminal", cf * Vector3.new(0, 0, 10))
		end
		remember(d, p + Vector3.new(0, 1.5, 26))
	end
	if towers == 0 then
		coolingTower(d.Center + Vector3.new(220, 0, 120), 34, 100)
	end
	-- the landmark: a coil spire humming over the plaza
	local base = d.Center + Vector3.new(-42, 0, 42)
	column(base, 3, 70, { Name = "ArcSpire", Color = PAL.Steel, Material = Enum.Material.Metal })
	for k = 1, 5 do
		local ring = column(base + Vector3.new(0, 30 + k * 7, 0), 6 - k * 0.6, 1, { Name = "ArcCoil", Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
		if k == 5 then
			glow(ring, Color3.fromRGB(110, 190, 255), 70, 2)
			emit(ring, "Sparks")
			ring:SetAttribute("District", d.Name)
		end
	end
end

-- ===== the Hab Blocks: arcology =====
local NEON = { Color3.fromRGB(255, 70, 190), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 180, 60), Color3.fromRGB(180, 120, 255) }

local function megablock(p, w, dpt, h)
	local lift = 22
	local yaw = rng:NextInteger(0, 3) * math.pi / 2
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	-- stilts and the stair core: the street runs underneath
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "HabStilt", Size = Vector3.new(7, lift, 7), CFrame = cf * CFrame.new(sx * (w / 2 - 4), lift / 2, sz * (dpt / 2 - 4)), Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
		end
	end
	part({ Name = "HabCore", Size = Vector3.new(14, lift, 14), CFrame = cf * CFrame.new(0, lift / 2, 0), Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
	local body = part({ Name = "HabBlock", Size = Vector3.new(w, h, dpt), CFrame = cf * CFrame.new(0, lift + h / 2, 0), Color = Color3.fromRGB(78, 76, 84), Material = Enum.Material.Concrete })
	-- lit floors and signs
	for _ = 1, rng:NextInteger(3, 6) do
		local face = rng:NextInteger(1, 4)
		local y = rng:NextNumber(4, h - 4) - h / 2
		local c = NEON[rng:NextInteger(1, #NEON)]
		local strip
		if face <= 2 then
			local s = if face == 1 then 1 else -1
			strip = part({ Name = "HabWindows", Size = Vector3.new(w * rng:NextNumber(0.3, 0.9), 0.8, 0.3), CFrame = body.CFrame * CFrame.new(0, y, s * (dpt / 2 + 0.15)), Color = c, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		else
			local s = if face == 3 then 1 else -1
			strip = part({ Name = "HabWindows", Size = Vector3.new(0.3, 0.8, dpt * rng:NextNumber(0.3, 0.9)), CFrame = body.CFrame * CFrame.new(s * (w / 2 + 0.15), y, 0), Color = c, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		end
		strip:SetAttribute("Lit", true)
	end
	-- a vertical sign at a corner, the only light in the street below
	if rng:NextNumber() < 0.6 then
		local c = NEON[rng:NextInteger(1, #NEON)]
		local sign = part({ Name = "HabSign", Size = Vector3.new(1, 26, 4), CFrame = cf * CFrame.new(w / 2 + 1.5, lift + 20, dpt / 2 - 6), Color = c, Material = Enum.Material.Neon, CanCollide = false })
		glow(sign, c, 36, 1.4)
	end
	-- laundry and cables strung between stilts
	beam(cf:PointToWorldSpace(Vector3.new(-w / 2 + 4, lift - 4, -dpt / 2 + 4)), cf:PointToWorldSpace(Vector3.new(w / 2 - 4, lift - 5, dpt / 2 - 4)), 0.15, 0.15, { Name = "Cable", Color = PAL.Soot, Material = Enum.Material.Metal, CanCollide = false, CastShadow = false })
	return body, cf
end

-- A low terrace block you can climb (a truss ladder) with a roof to fight on.
local function terrace(p, w, dpt, h)
	local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
	part({ Name = "Terrace", Size = Vector3.new(w, h, dpt), CFrame = cf * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(86, 80, 78), Material = Enum.Material.Brick })
	part({ Name = "TerraceParapet", Size = Vector3.new(w, 3, 1), CFrame = cf * CFrame.new(0, h + 1.5, dpt / 2 - 0.5), Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, h, 2)
	truss.CFrame = cf * CFrame.new(w / 2 - 4, h / 2, -dpt / 2 - 1)
	truss.Color = PAL.Steel
	truss.Parent = folder
	-- rooftop clutter
	prop(({ "Crate", "Barrel", "Terminal" })[rng:NextInteger(1, 3)], cf * Vector3.new(rng:NextNumber(-w / 3, w / 3), 0, rng:NextNumber(-dpt / 3, dpt / 3)) + Vector3.new(0, h, 0))
	return cf * CFrame.new(0, h, 0)
end

local function buildHab(d)
	local roofs = {}
	for _, p in lots(d, 140, 50) do
		if rng:NextNumber() < 0.55 then
			megablock(p, rng:NextNumber(60, 86), rng:NextNumber(60, 86), rng:NextNumber(110, 260))
			-- market stalls in the shade underneath
			for k = 1, 2 do
				local s = p + Vector3.new(rng:NextNumber(-18, 18), 0, rng:NextNumber(-18, 18))
				part({ Name = "Stall", Size = Vector3.new(8, 3, 3), CFrame = CFrame.new(s + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = Color3.fromRGB(120, 90, 70), Material = Enum.Material.WoodPlanks })
				if k == 1 then
					local lamp = part({ Name = "StallLamp", Size = Vector3.new(1, 1, 1), Position = s + Vector3.new(0, 6, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
					glow(lamp, Color3.fromRGB(255, 190, 120), 18, 1)
				end
			end
		else
			local roof = terrace(p, rng:NextNumber(36, 50), rng:NextNumber(36, 50), rng:NextNumber(26, 40))
			table.insert(roofs, roof)
		end
		remember(d, p + Vector3.new(0, 1.5, 0))
	end
	-- skybridges between neighbouring terrace roofs
	for i = 1, #roofs - 1 do
		local a, b = roofs[i].Position, roofs[i + 1].Position
		if (b - a).Magnitude < 190 then
			local ya = math.min(a.Y, b.Y)
			beam(Vector3.new(a.X, ya + 0.5, a.Z), Vector3.new(b.X, ya + 0.5, b.Z), 6, 1, { Name = "Skybridge", Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
		end
	end
	-- the landmark: the spire block, tallest thing on the east side
	local spire = megablock(d.Center + Vector3.new(-55, 0, 60), 50, 50, 380)
	part({ Name = "SpireCrown", Size = Vector3.new(52, 6, 52), CFrame = spire.CFrame * CFrame.new(0, 193, 0), Color = Color3.fromRGB(255, 70, 190), Material = Enum.Material.Neon, CanCollide = false }):SetAttribute("District", d.Name)
end

-- ===== Scrap Sea =====
local JUNK = { Color3.fromRGB(120, 70, 46), Color3.fromRGB(70, 84, 96), Color3.fromRGB(90, 96, 70), Color3.fromRGB(110, 100, 90), Color3.fromRGB(130, 50, 40) }

local function junkHeap(p, size)
	local id = Assets.Industry and Assets.Industry.JunkPile
	if kit(id, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), size / 50, "JunkPile") then
		return
	end
	for _ = 1, rng:NextInteger(4, 7) do
		local w = rng:NextNumber(size * 0.4, size * 0.8)
		local c = p + Vector3.new(rng:NextNumber(-size * 0.3, size * 0.3), 0, rng:NextNumber(-size * 0.3, size * 0.3))
		ball(c, Vector3.new(w, w * rng:NextNumber(0.5, 0.8), w * rng:NextNumber(0.7, 1)), { Name = "JunkHeap", Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
	end
	for _ = 1, rng:NextInteger(8, 14) do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, size * 0.45)
		local c = p + Vector3.new(math.cos(a) * r, size * 0.3 * (1 - r / (size * 0.5)), math.sin(a) * r)
		part({ Name = "Junk", Size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 4), rng:NextNumber(6, 12)), CFrame = CFrame.new(c) * CFrame.Angles(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0, math.pi), rng:NextNumber(-0.8, 0.8)),
			Color = JUNK[rng:NextInteger(1, #JUNK)], Material = Enum.Material.CorrodedMetal })
	end
end

local function cubeWall(a, b)
	local dir = (b - a).Unit
	local n = math.floor((b - a).Magnitude / 6.2)
	for k = 0, n do
		local base = a + dir * (k * 6.2)
		for lvl = 0, rng:NextInteger(0, 2) do
			part({ Name = "ScrapCube", Size = Vector3.new(6, 6, 6), CFrame = CFrame.lookAt(base + Vector3.new(0, 3 + lvl * 6, 0), base + Vector3.new(0, 3 + lvl * 6, 0) + dir) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
				Color = JUNK[rng:NextInteger(1, #JUNK)], Material = Enum.Material.CorrodedMetal })
		end
	end
end

local function magnetCrane(base, yaw)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	part({ Name = "CraneTower", Size = Vector3.new(6, 60, 6), CFrame = cf * CFrame.new(0, 30, 0), Color = Color3.fromRGB(200, 150, 40), Material = Enum.Material.Metal })
	part({ Name = "CraneBoom", Size = Vector3.new(4, 4, 70), CFrame = cf * CFrame.new(0, 60, 22), Color = Color3.fromRGB(200, 150, 40), Material = Enum.Material.Metal })
	part({ Name = "CraneCab", Size = Vector3.new(8, 6, 8), CFrame = cf * CFrame.new(0, 55, -4), Color = PAL.Steel, Material = Enum.Material.Metal })
	beam(cf:PointToWorldSpace(Vector3.new(0, 58, 50)), cf:PointToWorldSpace(Vector3.new(0, 26, 50)), 0.3, 0.3, { Name = "CraneCable", Color = PAL.Soot, Material = Enum.Material.Metal, CanCollide = false })
	part({ Name = "Magnet", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = cf * CFrame.new(0, 25, 50) * CFrame.Angles(0, 0, math.pi / 2), Color = PAL.Soot, Material = Enum.Material.Metal })
	part({ Name = "HangingWreck", Size = Vector3.new(5, 4, 11), CFrame = cf * CFrame.new(0, 21, 50) * CFrame.Angles(0.1, 0.4, 0.05), Color = JUNK[2], Material = Enum.Material.CorrodedMetal })
	return cf
end

local function buildScrap(d)
	local spots = lots(d, 120, 44)
	for i, p in spots do
		local kind = pick({ { "Heap", 0.55 }, { "Cubes", 0.3 }, { "Crane", 0.15 } })
		if kind == "Heap" then
			junkHeap(p, rng:NextNumber(40, 70))
		elseif kind == "Cubes" then
			local yaw = rng:NextNumber(0, math.pi)
			local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
			cubeWall(p - dir * 30, p + dir * 30)
			cubeWall(p - dir * 30 + Vector3.new(-dir.Z, 0, dir.X) * 14, p + dir * 10 + Vector3.new(-dir.Z, 0, dir.X) * 14)
		else
			magnetCrane(p, rng:NextNumber(0, math.pi * 2))
		end
		-- breakable wrecks between the heaps
		if i % 2 == 0 then
			prop(({ "CarWreck", "CarWreck", "Barrel", "Crate", "Slab" })[rng:NextInteger(1, 5)], p + Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50)))
		end
		remember(d, p + Vector3.new(36, 1.5, 0))
	end
	local cf = magnetCrane(d.Center + Vector3.new(50, 0, -40), 0.5)
	local light = part({ Name = "CraneLight", Size = Vector3.new(2, 2, 2), CFrame = cf * CFrame.new(0, 63, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
	glow(light, Color3.fromRGB(255, 200, 80), 60, 1.6)
	light:SetAttribute("District", d.Name)
end

-- ===== the Foundry =====
local function furnaceHall(p, yaw)
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local L, W, H = 130, 46, 34
	for _, s in { -1, 1 } do
		-- long walls with doorways
		for k = -2, 2 do
			if k ~= 0 then
				part({ Name = "HallWall", Size = Vector3.new(1.5, H, L / 5 - 1), CFrame = cf * CFrame.new(s * W / 2, H / 2, k * L / 5), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
			else
				part({ Name = "HallWall", Size = Vector3.new(1.5, H - 14, L / 5 - 1), CFrame = cf * CFrame.new(s * W / 2, 14 + (H - 14) / 2, 0), Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
			end
		end
	end
	-- the roof, holed, on trusses
	for k = -3, 3 do
		part({ Name = "HallTruss", Size = Vector3.new(W, 2, 1.5), CFrame = cf * CFrame.new(0, H, k * L / 7), Color = PAL.Steel, Material = Enum.Material.Metal })
		if rng:NextNumber() < 0.7 then
			part({ Name = "HallRoof", Size = Vector3.new(W + 2, 1, L / 7), CFrame = cf * CFrame.new(0, H + 1.5, k * L / 7 + L / 14), Color = PAL.Soot, Material = Enum.Material.CorrodedMetal })
		end
	end
	-- the molten channel down the middle
	part({ Name = "ChannelLip", Size = Vector3.new(7, 0.3, L - 8), CFrame = cf * CFrame.new(0, 0.15, 0), Color = PAL.Soot, Material = Enum.Material.Slate, CanCollide = false })
	part({ Name = "MoltenChannel", Size = Vector3.new(4, 0.3, L - 10), CFrame = cf * CFrame.new(0, 0.25, 0), Color = PAL.Molten, Material = Enum.Material.Neon, CanCollide = false })
	for k = -1, 1 do
		glow(part({ Name = "HallGlow", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 4, k * 40), Transparency = 1, CanCollide = false }), PAL.Molten, 40, 1.6)
	end
	-- an overhead ladle crane
	part({ Name = "HallCrane", Size = Vector3.new(W - 4, 3, 4), CFrame = cf * CFrame.new(0, H - 4, rng:NextNumber(-40, 40)), Color = Color3.fromRGB(200, 150, 40), Material = Enum.Material.Metal })
	-- a catwalk along one wall, reached by a ladder
	part({ Name = "Catwalk", Size = Vector3.new(5, 0.6, L - 6), CFrame = cf * CFrame.new(-W / 2 + 3.5, 18, 0), Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, 18, 2)
	truss.CFrame = cf * CFrame.new(-W / 2 + 2, 9, L / 2 - 6)
	truss.Color = PAL.Steel
	truss.Parent = folder
	return cf
end

local function blastFurnace(p, h)
	local id = Assets.Industry and Assets.Industry.BlastFurnace
	if not kit(id, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), h / 70, "BlastFurnace") then
		column(p, 15, 10, { Name = "FurnaceBase", Color = PAL.Soot, Material = Enum.Material.Slate })
		column(p + Vector3.new(0, 10, 0), 12, h * 0.55, { Name = "Furnace", Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
		column(p + Vector3.new(0, 10 + h * 0.55, 0), 8, h * 0.25, { Name = "FurnaceThroat", Color = PAL.RustDark, Material = Enum.Material.CorrodedMetal })
		column(p + Vector3.new(0, 10 + h * 0.8, 0), 4, h * 0.25, { Name = "FurnaceTop", Color = PAL.Steel, Material = Enum.Material.Metal })
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			pipe(p + Vector3.new(0, 10 + h * 0.85, 0), p + Vector3.new(math.cos(a) * 26, 6, math.sin(a) * 26), 2, { Name = "Downcomer", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
		end
	end
	local tap = part({ Name = "Taphole", Size = Vector3.new(4, 3, 1), Position = p + Vector3.new(0, 3, -15.5), Color = PAL.Molten, Material = Enum.Material.Neon, CanCollide = false })
	glow(tap, PAL.Molten, 34, 2)
	local top = part({ Name = "FurnaceMouth", Size = Vector3.new(4, 1, 4), Position = p + Vector3.new(0, h + 12, 0), Transparency = 1, CanCollide = false, CastShadow = false })
	emit(top, "Soot", 1.2)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 6, 12
	fire.Parent = top
end

local function rails(a, b)
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for _, s in { -1, 1 } do
		beam(a + side * (s * 2.4) + Vector3.new(0, 0.3, 0), b + side * (s * 2.4) + Vector3.new(0, 0.3, 0), 0.5, 0.5, { Name = "Rail", Color = PAL.Steel, Material = Enum.Material.Metal })
	end
	for k = 1, 3 do
		local c = a:Lerp(b, k / 4 + rng:NextNumber(-0.05, 0.05))
		part({ Name = "OreCar", Size = Vector3.new(7, 5, 10), CFrame = CFrame.lookAt(c + Vector3.new(0, 3, 0), c + Vector3.new(0, 3, 0) + dir), Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
		ball(c + Vector3.new(0, 5.5, 0), Vector3.new(6, 3, 9), { Name = "Ore", Color = Color3.fromRGB(90, 50, 40), Material = Enum.Material.Slate, CanCollide = false })
	end
end

local function buildFoundry(d)
	for _, p in lots(d, 165, 66) do
		local kind = pick({ { "Hall", 0.5 }, { "Furnace", 0.3 }, { "Ore", 0.2 } })
		if kind == "Hall" then
			local cf = furnaceHall(p, rng:NextInteger(0, 1) * math.pi / 2)
			remember(d, cf * Vector3.new(0, 1.5, 30))
		elseif kind == "Furnace" then
			blastFurnace(p, rng:NextNumber(55, 80))
			remember(d, p + Vector3.new(30, 1.5, 30))
		else
			for _ = 1, 3 do
				local c = p + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
				ball(c, Vector3.new(rng:NextNumber(20, 34), rng:NextNumber(14, 24), rng:NextNumber(20, 34)), { Name = "OrePile", Color = Color3.fromRGB(96, 50, 38), Material = Enum.Material.Slate })
			end
			rails(p + Vector3.new(-60, 0, 30), p + Vector3.new(60, 0, 30))
			remember(d, p + Vector3.new(0, 1.5, -30))
		end
	end
	-- the landmark: the mother furnace, south of the plaza
	blastFurnace(d.Center + Vector3.new(0, 0, -70), 120)
	local crown = part({ Name = "MotherFurnaceLight", Size = Vector3.new(3, 3, 3), Position = d.Center + Vector3.new(0, 134, -70), Color = PAL.Warning, Material = Enum.Material.Neon, CanCollide = false })
	crown:SetAttribute("District", d.Name)
end

-- ===== the Sumps: canals =====
local function buildSumps(d)
	local K = M.Canals
	local half = d.Size / 2
	local x0, z0 = d.Center.X - half, d.Center.Z - half
	-- the sunken bed under everything, then the islands between the canals
	slab(x0, x0 + d.Size, z0, z0 + d.Size, Color3.fromRGB(40, 44, 38), Enum.Material.Mud, "CanalBed", K.Bed, 4)
	local edges = { -half }
	for _, off in K.Lines do
		table.insert(edges, off - K.Width / 2)
		table.insert(edges, off + K.Width / 2)
	end
	table.insert(edges, half)
	local islands = {}
	for i = 1, #edges, 2 do
		for j = 1, #edges, 2 do
			local ax0, ax1 = edges[i], edges[i + 1]
			local az0, az1 = edges[j], edges[j + 1]
			local isl = slab(d.Center.X + ax0, d.Center.X + ax1, d.Center.Z + az0, d.Center.Z + az1, Color3.fromRGB(70, 72, 68), Enum.Material.Concrete, "Island", TOP, TOP - K.Bed)
			table.insert(islands, { Part = isl, I = (i + 1) / 2, J = (j + 1) / 2, Center = isl.Position, X0 = ax0, X1 = ax1, Z0 = az0, Z1 = az1 })
		end
	end
	-- the sludge itself
	for _, s in M.Sludge do
		if s.Half and M.DistrictAt(s.Center) == d then
			local p = part({ Name = "CanalSludge", Size = Vector3.new(s.Half.X * 2, 0.4, s.Half.Z * 2), Position = s.Center - Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(120, 160, 50), Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false, CastShadow = false })
			p:SetAttribute("Sludge", true)
		end
	end
	-- ramps out of each canal stretch, and bridges between neighbouring islands
	local n = #K.Lines + 1
	local byIJ = {}
	for _, isl in islands do
		byIJ[isl.I .. "," .. isl.J] = isl
	end
	for _, isl in islands do
		local right = byIJ[(isl.I + 1) .. "," .. isl.J]
		local up = byIJ[isl.I .. "," .. (isl.J + 1)]
		local zmid = d.Center.Z + (isl.Z0 + isl.Z1) / 2
		local xmid = d.Center.X + (isl.X0 + isl.X1) / 2
		if right then
			local xa, xb = d.Center.X + isl.X1, d.Center.X + right.X0
			local zb = zmid + rng:NextNumber(-20, 20)
			part({ Name = "Bridge", Size = Vector3.new(xb - xa + 6, 1, 10), Position = Vector3.new((xa + xb) / 2, TOP + 0.5, zb), Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
			for _, s in { -1, 1 } do
				part({ Name = "BridgeRail", Size = Vector3.new(xb - xa + 6, 3, 0.4), Position = Vector3.new((xa + xb) / 2, TOP + 2.5, zb + s * 4.8), Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			end
			-- a ramp down the island's wall into the canal (the way out if you fall in)
			local rz = zmid + (if zb > zmid then -30 else 30)
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = Vector3.new(6, TOP - K.Bed, 16)
			w.CFrame = CFrame.new(xa + 3, (TOP + K.Bed) / 2, rz) * CFrame.Angles(0, math.pi / 2, 0)
			w.Color, w.Material = Color3.fromRGB(70, 72, 68), Enum.Material.Concrete
			w.Parent = folder
		end
		if up then
			local za, zb = d.Center.Z + isl.Z1, d.Center.Z + up.Z0
			local xb = xmid + rng:NextNumber(-20, 20)
			part({ Name = "Bridge", Size = Vector3.new(10, 1, zb - za + 6), Position = Vector3.new(xb, TOP + 0.5, (za + zb) / 2), Color = PAL.Steel, Material = Enum.Material.DiamondPlate })
			for _, s in { -1, 1 } do
				part({ Name = "BridgeRail", Size = Vector3.new(0.4, 3, zb - za + 6), Position = Vector3.new(xb + s * 4.8, TOP + 2.5, (za + zb) / 2), Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			end
			local rx = xmid + (if xb > xmid then -30 else 30)
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = Vector3.new(6, TOP - K.Bed, 16)
			w.CFrame = CFrame.new(rx, (TOP + K.Bed) / 2, za + 3) * CFrame.Angles(0, math.pi, 0)
			w.Color, w.Material = Color3.fromRGB(70, 72, 68), Enum.Material.Concrete
			w.Parent = folder
		end
	end
	-- on the islands: pump houses, stilt shacks, outfalls; the middle island is the plaza
	for _, isl in islands do
		local c = isl.Part.Position
		local top = at(c.X, c.Z)
		local wide = isl.X1 - isl.X0
		if isl.I == math.ceil(n / 2) and isl.J == math.ceil(n / 2) then
			continue
		end
		local kind = pick({ { "Pump", 0.35 }, { "Shacks", 0.45 }, { "Empty", 0.2 } })
		if kind == "Pump" then
			part({ Name = "PumpHouse", Size = Vector3.new(24, 14, 18), Position = top + Vector3.new(0, 7, 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
			column(top + Vector3.new(14, 0, 0), 3, 26, { Name = "PumpStack", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			local mouth = part({ Name = "PumpMouth", Size = Vector3.new(3, 1, 3), Position = top + Vector3.new(14, 28, 0), Transparency = 1, CanCollide = false, CastShadow = false })
			emit(mouth, "Steam", 0.5)
		elseif kind == "Shacks" then
			for _ = 1, rng:NextInteger(2, 4) do
				local s = top + Vector3.new(rng:NextNumber(-wide * 0.3, wide * 0.3), 0, rng:NextNumber(-wide * 0.3, wide * 0.3))
				local yaw = rng:NextNumber(0, math.pi)
				local cf = CFrame.new(s) * CFrame.Angles(0, yaw, 0)
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						part({ Name = "ShackStilt", Size = Vector3.new(0.8, 6, 0.8), CFrame = cf * CFrame.new(sx * 5, 3, sz * 4), Color = Color3.fromRGB(80, 66, 50), Material = Enum.Material.Wood })
					end
				end
				part({ Name = "Shack", Size = Vector3.new(11, 7, 9), CFrame = cf * CFrame.new(0, 9.5, 0), Color = JUNK[rng:NextInteger(1, #JUNK)], Material = Enum.Material.CorrodedMetal })
				part({ Name = "ShackRoof", Size = Vector3.new(13, 0.5, 11), CFrame = cf * CFrame.new(0, 13.3, 0) * CFrame.Angles(0.12, 0, 0), Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			end
		end
		-- an outfall pipe pouring into the canal on the island's south edge
		if rng:NextNumber() < 0.4 then
			local edgeZ = d.Center.Z + isl.Z0
			local mouth = Vector3.new(c.X + rng:NextNumber(-20, 20), TOP - 1, edgeZ)
			pipe(mouth + Vector3.new(0, 0, 4), mouth - Vector3.new(0, 0, 1), 1.6, { Name = "Outfall", Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
			part({ Name = "OutfallStream", Size = Vector3.new(2, TOP - 1 - K.Surface, 1), Position = Vector3.new(mouth.X, (TOP - 1 + K.Surface) / 2, edgeZ - 1.5), Color = PAL.Sludge, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CastShadow = false })
		end
		remember(d, top + Vector3.new(wide * 0.3, 1.5, 0))
	end
	-- the landmark: the great outfall in the plaza's water tower
	local base = d.Center + Vector3.new(40, 0, 40)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "WaterTowerLeg", Size = Vector3.new(1.4, 40, 1.4), Position = base + Vector3.new(sx * 7, 22, sz * 7), Color = PAL.Rust, Material = Enum.Material.CorrodedMetal })
		end
	end
	column(base + Vector3.new(0, 42, 0), 11, 16, { Name = "WaterTower", Color = Color3.fromRGB(90, 110, 80), Material = Enum.Material.CorrodedMetal })
	local lamp = part({ Name = "WaterTowerLamp", Size = Vector3.new(2, 2, 2), Position = base + Vector3.new(0, 60, 0), Color = Color3.fromRGB(80, 255, 170), Material = Enum.Material.Neon, CanCollide = false })
	glow(lamp, Color3.fromRGB(80, 255, 170), 50, 1.5)
	lamp:SetAttribute("District", d.Name)
end

-- ===== the green pockets =====
local function tree(x, z, scale)
	local list = if rng:NextNumber() < 0.5 then Assets.Frontier.Broad else Assets.Frontier.Pines
	local model = kit(list and list[rng:NextInteger(1, #list)], CFrame.new(x, TOP - 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), scale, "Tree")
	if model then
		CollectionService:AddTag(model, "Tree")
		return
	end
	local h = 12 * scale
	part({ Name = "Trunk", Size = Vector3.new(1.6 * scale, h, 1.6 * scale), Position = at(x, z, TOP + h / 2), Color = PAL.Bark, Material = Enum.Material.Wood })
	for i = 1, 2 do
		local r = (6 - i) * scale
		ball(at(x, z, TOP + h - 2 + i * 3), Vector3.new(r * 2, r * 1.7, r * 2), { Name = "Canopy", Color = PAL.Leaf[rng:NextInteger(1, #PAL.Leaf)], Material = Enum.Material.Grass, CanCollide = false })
	end
end

local function moss(p, radius)
	column(at(p.X, p.Z, TOP + 0.02), radius, 0.14, { Name = "Moss", Color = PAL.Moss, Material = Enum.Material.Grass })
end

local function flowers(p)
	local c = ({ Color3.fromRGB(230, 200, 80), Color3.fromRGB(220, 120, 160), Color3.fromRGB(150, 180, 255), Color3.fromRGB(255, 255, 230) })[rng:NextInteger(1, 4)]
	part({ Name = "Flowers", Size = Vector3.new(rng:NextNumber(2, 5), 0.6, rng:NextNumber(2, 5)), Position = at(p.X, p.Z, TOP + 0.4), Color = c, Material = Enum.Material.Grass, CanCollide = false })
end

local function shrub(p, s)
	ball(at(p.X, p.Z, TOP + s * 0.3), Vector3.new(s * 2, s * 1.3, s * 2), { Name = "Shrub", Color = PAL.Leaf[rng:NextInteger(1, #PAL.Leaf)], Material = Enum.Material.Grass, CanCollide = false })
end

local function fireflies(p, r)
	local zone = part({ Name = "Fireflies", Size = Vector3.new(r * 2, 8, r * 2), Position = at(p.X, p.Z, TOP + 5), Transparency = 1, CanCollide = false, CastShadow = false, CanQuery = false })
	emit(zone, "Fireflies")
end

local function inPocket(pk, margin)
	local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * (pk.Radius - margin)
	return pk.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function buildGarden(pk)
	local c, R = pk.Center, pk.Radius
	moss(c, R)
	-- the dome's ring wall and its glass, most of it fallen
	local n = 28
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = at(c.X + math.cos(a) * (R - 4), c.Z + math.sin(a) * (R - 4))
		local face = CFrame.lookAt(p, at(c.X, c.Z)) * CFrame.Angles(0, math.pi / 2, 0)
		local seg = 2 * math.pi * (R - 4) / n
		part({ Name = "DomeCurb", Size = Vector3.new(seg + 0.5, 4, 2), CFrame = face * CFrame.new(0, 2, 0), Color = PAL.White, Material = Enum.Material.Concrete })
		if i % 7 == 0 then
			continue -- doorways
		end
		if rng:NextNumber() < 0.6 then
			local gh = rng:NextNumber(4, 16)
			part({ Name = "DomeGlass", Size = Vector3.new(seg - 0.6, gh, 0.3), CFrame = face * CFrame.new(0, 4 + gh / 2, 0), Color = PAL.Glass, Material = Enum.Material.Glass, Transparency = 0.6, CastShadow = false })
		end
	end
	-- ribs up to a broken crown
	local ribs = 8
	for i = 0, ribs - 1 do
		local a = i / ribs * math.pi * 2 + 0.2
		local stop = if rng:NextNumber() < 0.4 then rng:NextInteger(2, 4) else 6
		local prev
		for k = 0, stop do
			local t = k / 6 * math.pi / 2
			local p = Vector3.new(c.X + math.cos(a) * (R - 4) * math.cos(t), TOP + 4 + 70 * math.sin(t), c.Z + math.sin(a) * (R - 4) * math.cos(t))
			if prev then
				beam(prev, p, 1.6, 1.6, { Name = "DomeRib", Color = PAL.White, Material = Enum.Material.Metal })
			end
			prev = p
		end
	end
	-- the garden inside, gone wild: big trees, shrubs, flowers, a clean pond
	for _ = 1, 16 do
		local p = inPocket(pk, 16)
		if (v2(p.X, p.Z) - v2(c.X, c.Z)).Magnitude > 22 then
			tree(p.X, p.Z, rng:NextNumber(1.8, 3))
		end
	end
	for _ = 1, 24 do
		shrub(inPocket(pk, 10), rng:NextNumber(2, 5))
	end
	for _ = 1, 30 do
		flowers(inPocket(pk, 8))
	end
	pcall(function()
		workspace.Terrain:FillCylinder(CFrame.new(c.X, TOP + 0.6, c.Z), 1.2, 14, Enum.Material.Water)
	end)
	column(at(c.X, c.Z, TOP), 15.5, 0.8, { Name = "PondEdge", Color = Color3.fromRGB(110, 108, 100), Material = Enum.Material.Cobblestone, CanCollide = false })
	fireflies(c, R * 0.7)
	api.cache(pk, at(c.X + 30, c.Z + 26, TOP + 1.5))
end

local function buildRootwork(pk)
	local c, R = pk.Center, pk.Radius
	moss(c, R)
	-- what is left of the tower it broke: four wall stubs and rubble
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		local p = at(c.X + math.cos(a) * (R - 8), c.Z + math.sin(a) * (R - 8))
		local h = rng:NextNumber(10, 34)
		part({ Name = "RuinWall", Size = Vector3.new(rng:NextNumber(30, 50), h, 3), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), at(c.X, c.Z, TOP + h / 2)) * CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)), Color = PAL.ConcreteDark, Material = Enum.Material.Concrete })
	end
	for _ = 1, 10 do
		local p = inPocket(pk, 6)
		part({ Name = "Rubble", Size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(1, 3), rng:NextNumber(3, 8)), CFrame = CFrame.new(p + Vector3.new(0, 0.8, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), 0), Color = PAL.Concrete, Material = Enum.Material.Concrete })
	end
	-- the tree: older than the city
	local id = Assets.Industry and Assets.Industry.GiantTree
	if not kit(id, CFrame.new(at(c.X, c.Z, TOP - 0.5)), 1, "GiantTree") then
		local base = at(c.X, c.Z, TOP - 1)
		local top = base + Vector3.new(4, 72, -3)
		pipe(base, top, 8, { Name = "GiantTrunk", Color = PAL.Bark, Material = Enum.Material.Wood })
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2
			pipe(base + Vector3.new(0, 6, 0), base + Vector3.new(math.cos(a) * 30, -1, math.sin(a) * 30), rng:NextNumber(2.5, 4), { Name = "GiantRoot", Color = PAL.Bark, Material = Enum.Material.Wood })
		end
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.3
			local from = base:Lerp(top, rng:NextNumber(0.55, 0.85))
			local to = from + Vector3.new(math.cos(a) * 30, rng:NextNumber(8, 18), math.sin(a) * 30)
			pipe(from, to, rng:NextNumber(1.8, 3), { Name = "GiantBranch", Color = PAL.Bark, Material = Enum.Material.Wood })
			ball(to, Vector3.new(34, 22, 34), { Name = "GiantCanopy", Color = PAL.Leaf[rng:NextInteger(1, #PAL.Leaf)], Material = Enum.Material.Grass, CanCollide = false })
		end
		ball(top + Vector3.new(0, 6, 0), Vector3.new(50, 30, 50), { Name = "GiantCanopy", Color = PAL.Leaf[1], Material = Enum.Material.Grass, CanCollide = false })
	end
	-- vines down the ruin, glowing caps in the roots
	for _ = 1, 18 do
		local p = inPocket(pk, 10)
		local len = rng:NextNumber(8, 20)
		part({ Name = "Vine", Size = Vector3.new(0.3, len, 0.3), Position = p + Vector3.new(0, TOP + 24 - len / 2, 0), Color = PAL.Leaf[3], Material = Enum.Material.Grass, CanCollide = false, CastShadow = false })
	end
	for _ = 1, 14 do
		local p = inPocket(pk, 8)
		local cap = ball(at(p.X, p.Z, TOP + 0.6), Vector3.new(1.4, 0.8, 1.4), { Name = "GlowCap", Color = Color3.fromRGB(110, 255, 220), Material = Enum.Material.Neon, CanCollide = false })
		if rng:NextNumber() < 0.15 then
			glow(cap, Color3.fromRGB(110, 255, 220), 14, 0.8)
		end
	end
	for _ = 1, 16 do
		shrub(inPocket(pk, 8), rng:NextNumber(1.5, 3.5))
	end
	fireflies(c, R * 0.7)
	api.cache(pk, at(c.X - 24, c.Z + 20, TOP + 1.5))
end

local function buildFernwell(pk)
	local c, R = pk.Center, pk.Radius
	moss(c, R)
	-- the spring: a stone ring around clean water, a shaft of light from a gap in the blocks above
	column(at(c.X, c.Z, TOP), 8, 2.4, { Name = "WellRing", Color = Color3.fromRGB(120, 118, 108), Material = Enum.Material.Cobblestone })
	column(at(c.X, c.Z, TOP + 2.3), 6.8, 0.3, { Name = "WellWater", Color = Color3.fromRGB(90, 160, 190), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	part({ Name = "LightShaft", Size = Vector3.new(14, 200, 14), Position = at(c.X, c.Z, TOP + 100), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, Transparency = 0.93, CanCollide = false, CastShadow = false, CanQuery = false })
	-- ferns: three fronds per clump
	for _ = 1, 40 do
		local p = inPocket(pk, 4)
		if (v2(p.X, p.Z) - v2(c.X, c.Z)).Magnitude > 10 then
			local yaw = rng:NextNumber(0, math.pi * 2)
			for k = 0, 2 do
				part({ Name = "Frond", Size = Vector3.new(0.2, 1.4, 3.4), CFrame = CFrame.new(at(p.X, p.Z, TOP + 0.9)) * CFrame.Angles(0, yaw + k * 2.1, 0) * CFrame.new(0, 0, 1.4) * CFrame.Angles(-0.7, 0, 0),
					Color = PAL.Leaf[rng:NextInteger(1, #PAL.Leaf)], Material = Enum.Material.Grass, CanCollide = false, CastShadow = false })
			end
		end
	end
	for _ = 1, 4 do
		local p = inPocket(pk, 14)
		tree(p.X, p.Z, rng:NextNumber(1.3, 1.8))
	end
	fireflies(c, R * 0.6)
	api.cache(pk, at(c.X + 18, c.Z - 14, TOP + 1.5))
end

-- ===== the gaps =====
-- Between the districts: low ruins and wrecks, so the ring reads as one place.
local GAPS = { Style = "Outskirts", Color = Color3.fromRGB(52, 50, 56), Neon = Color3.fromRGB(120, 120, 140), Height = { 6, 18 }, Collapse = 0.65 }
local function buildGaps()
	local B = M.Bounds
	local placed = 0
	for _ = 1, 400 do
		if placed >= 70 then
			break
		end
		local x, z = rng:NextNumber(B.X0 + 90, B.X1 - 90), rng:NextNumber(B.Z0 + 90, B.Z1 - 20)
		if not M.InCore(x, z) and not M.DistrictAt(at(x, z)) and clear(nil, x, z, 18) then
			placed += 1
			api.tower(GAPS, x, z, rng:NextNumber(14, 26))
			if rng:NextNumber() < 0.5 then
				prop(({ "CarWreck", "Slab", "Barrel", "FencePanel", "Crate" })[rng:NextInteger(1, 5)], at(x + rng:NextNumber(-20, 20), z + rng:NextNumber(-20, 20)))
			end
		end
	end
	return placed
end

-- ===== the place's effect on bodies =====
local lastHurt = {} -- [player] = os.clock() of the last health loss
local lastHealth = {}

local function bodyLoop()
	local acc = 0
	local regenAcc = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc += dt
		regenAcc += dt
		if acc < C.SludgeTick then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				-- track hurt (the pocket only heals the calm)
				local prev = lastHealth[player]
				if prev and hum.Health < prev - 0.01 then
					lastHurt[player] = now
				end
				local toxic = M.InSludge(root.Position)
				if toxic then
					hum:TakeDamage(C.SludgeDamage * step)
					lastHurt[player] = now
				end
				if char:GetAttribute("Toxic") ~= toxic then
					char:SetAttribute("Toxic", toxic)
				end
				local pocket = M.PocketAt(root.Position)
				local name = pocket and pocket.Name or nil
				if char:GetAttribute("Pocket") ~= name then
					char:SetAttribute("Pocket", name)
				end
				if pocket and not toxic and now - (lastHurt[player] or 0) >= C.PocketCalm and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + C.PocketRegen * step)
				end
				lastHealth[player] = hum.Health
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHurt[player], lastHealth[player] = nil, nil
	end)
end

-- ===== entry =====
local BUILDERS = { Stacks = buildStacks, Slag = buildSlag, Pylon = buildPylon, Hab = buildHab, Scrap = buildScrap, Foundry = buildFoundry, Sumps = buildSumps }
local POCKETS = { Garden = buildGarden, Rootwork = buildRootwork, Fernwell = buildFernwell }

-- Builds everything into `parentFolder`. helpers = { cache, lockup, tower } from City.
function Megacity.Build(parentFolder, helpers)
	api = helpers
	folder = Instance.new("Folder")
	folder.Name = "Megacity"
	folder.Parent = parentFolder or workspace
	local t0 = os.clock()
	buildGround()
	buildRoads()
	buildWall()
	local sky, skyStacks = buildSkyline()
	for _, d in M.Districts do
		local ok, err = pcall(BUILDERS[d.Style], d)
		if not ok then
			warn("[Megacity] " .. d.Name .. " failed to build: " .. tostring(err))
		end
		-- every district: its locked building, its caches, its spawn pads where the danger allows
		local h = d.Size / 2
		local lock = at(d.Center.X - h + 30, d.Center.Z + h - 30)
		if d.Style == "Sumps" then
			lock = at(d.Center.X - h + 40, d.Center.Z + h - 40)
		end
		api.lockup(d, Vector3.new(lock.X, 0, lock.Z), d.Lockup or "Weak")
		if d.Sealed then
			api.lockup(d, Vector3.new(d.Center.X + h - 30, 0, d.Center.Z + h - 30), "Sealed")
		end
		local spots = d.Spots or {}
		d.Anchors = table.clone(spots)
		for _ = 1, math.min(d.Caches or 4, #spots) do
			api.cache(d, table.remove(spots, rng:NextInteger(1, #spots)))
		end
		if d.Danger ~= "High" then
			for k = 1, 2 do
				local pad = part({ Name = "SpawnPad", Size = Vector3.new(6, 0.4, 6), Position = at(d.Center.X + (k == 1 and -18 or 18), d.Center.Z, TOP + 0.2), Material = Enum.Material.Neon, Color = d.Neon, Transparency = 0.6 })
				CollectionService:AddTag(pad, "CitySpawn")
			end
		end
	end
	for _, pk in M.Pockets do
		local ok, err = pcall(POCKETS[pk.Key], pk)
		if not ok then
			warn("[Megacity] " .. pk.Name .. " failed to build: " .. tostring(err))
		end
	end
	local gaps = buildGaps()
	bodyLoop()
	print(("[Megacity] %d parts, %d kit models, %d props, %d lights, %d emitters, %d skyline (%d stacks), %d gap ruins in %.1fs")
		:format(counts.parts, counts.kit, counts.props, counts.lights, counts.emitters, sky, skyStacks, gaps, os.clock() - t0))
	return folder
end

function Megacity.Counts()
	return counts
end

return Megacity
