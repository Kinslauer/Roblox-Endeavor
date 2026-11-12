-- The subway: the level every new conduit arrives in (server/Tutorial.lua runs it).
-- A train car at a dead platform, a ticket hall, a service tunnel with a live rail, a lower hall under a
-- catwalk, and a control room at the bottom with a gear locker and the line's manifest. Nothing here explains
-- itself: a guard with his back turned, a lamp you can put out, a fuse box by a post, a walkway over a man.
--
-- Subway.Build(origin) returns the level: { Model, Origin, Seat, Doors, Checkpoints, Guards, Locker, Console, Lift,
-- Breaker, Lamps }. Coordinates below are local: +X east, +Z north, y 0 = the arrival platform's floor.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local Subway = {}

local CONCRETE = Color3.fromRGB(58, 60, 66)
local DARK = Color3.fromRGB(34, 36, 42)
local TILE = Color3.fromRGB(96, 104, 106)
local STEEL = Color3.fromRGB(70, 76, 86)
local RUST = Color3.fromRGB(92, 62, 44)
local HAZARD = Color3.fromRGB(216, 166, 26)
local WARM = Color3.fromRGB(255, 226, 170)
local COLD = Color3.fromRGB(190, 226, 255)
local RED = Color3.fromRGB(255, 70, 50)

function Subway.Build(origin)
	local model = Instance.new("Model")
	model.Name = "Subway"
	model:SetAttribute("Ambient", 0.05)
	local level = { Model = model, Origin = origin, Guards = {}, Lamps = {}, Checkpoints = {}, Doors = {} }

	local function at(x, y, z)
		return origin + Vector3.new(x, y, z)
	end
	-- a block from its corners
	local function box(name, x0, x1, y0, y1, z0, z1, material, color, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		p.CFrame = CFrame.new(at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		p.Material = material or Enum.Material.Concrete
		p.Color = color or CONCRETE
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent or model
		return p
	end
	local function sign(part, face, text, color, size)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 72 -- sharp up close (24 read as low resolution)
		gui.LightInfluence = 0.6
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.Font = Enum.Font.Michroma
		label.TextScaled = size == nil
		label.TextSize = (size or 14) * 3
		label.TextColor3 = color or Color3.fromRGB(214, 220, 226)
		label.Parent = gui
		return label
	end
	-- a ceiling lamp guards see by and you can put out
	local function lamp(x, y, z, circuit, range, brightness, color, opts)
		local p = box("Lamp", x - 2, x + 2, y - 0.25, y + 0.25, z - 0.6, z + 0.6, Enum.Material.Neon, color or WARM)
		p.CanCollide = false
		p:SetAttribute("Circuit", circuit)
		p:SetAttribute("Lit", true)
		if opts and opts.Unbreakable then
			p:SetAttribute("Unbreakable", true)
		end
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = range or 32, brightness or 1.5, color or WARM
		light.Shadows = true
		light.Enabled = true
		light.Parent = p
		CollectionService:AddTag(p, "StealthLight")
		table.insert(level.Lamps, p)
		return p
	end
	local function spot(kind, x, y, z, attrs)
		local p = box("TakedownSpot", x - 0.5, x + 0.5, y - 0.5, y + 0.5, z - 0.5, z + 0.5, Enum.Material.SmoothPlastic, DARK)
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false
		p:SetAttribute("Takedown", kind)
		for k, v in attrs or {} do
			p:SetAttribute(k, v)
		end
		CollectionService:AddTag(p, "TakedownSpot")
		return p
	end
	local function ramp(name, from, to, width, alongX)
		-- a walkable slab from one point to another (centres of its two ends, top surface)
		local a, b = at(from.X, from.Y, from.Z), at(to.X, to.Y, to.Z)
		local p = Instance.new("Part")
		p.Name, p.Anchored = name, true
		p.Size = Vector3.new(width, 1, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.5, 0)
		p.Material, p.Color = Enum.Material.DiamondPlate, STEEL
		p.Parent = model
		return p
	end

	-- ===== A. the arrival platform =====
	box("Trackbed", -18, -3, -6, -4, -46, 46, Enum.Material.Slate, DARK)
	box("Platform", -3, 22, -6, 0, -46, 46, Enum.Material.Concrete, CONCRETE)
	box("PlatformEdge", -3, -1.8, 0, 0.06, -44, 44, Enum.Material.SmoothPlastic, HAZARD).CanCollide = false
	box("Ceiling", -18, 22, 14, 16, -46, 46, Enum.Material.Concrete, DARK)
	box("WallW", -18, -16, -6, 14, -46, 46, Enum.Material.Concrete, DARK)
	box("WallS", -18, 22, -6, 14, -46, -44, Enum.Material.Concrete, DARK)
	box("WallN", -18, 22, -6, 14, 44, 46, Enum.Material.Concrete, DARK)
	box("WallE1", 20, 22, 0, 14, -46, 26, Enum.Material.Concrete, TILE)
	box("WallE2", 20, 22, 0, 14, 34, 46, Enum.Material.Concrete, TILE)
	box("WallE3", 20, 22, 9, 14, 26, 34, Enum.Material.Concrete, TILE)
	for _, z in { -43.9, 43.9 } do -- the tunnel mouths
		box("Portal", -16, -3, -4, 6, z - 0.1, z + 0.1, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0))
	end
	for _, x in { -12, -7 } do
		box("Rail", x - 0.15, x + 0.15, -4, -3.7, -44, 44, Enum.Material.Metal, STEEL)
	end
	for _, z in { -30, -10, 10, 30 } do
		box("Pillar", 7, 9, 0, 14, z - 1, z + 1, Enum.Material.Concrete, TILE)
	end
	local lineSign = box("Sign", 19.8, 20, 7, 10, -8, 8, Enum.Material.Metal, Color3.fromRGB(20, 24, 30))
	sign(lineSign, Enum.NormalId.Left, "LINE 9  .  SUBLEVEL 3")
	local exitSign = box("Sign", 19.8, 20, 9.4, 11, 27, 33, Enum.Material.Metal, Color3.fromRGB(20, 24, 30))
	sign(exitSign, Enum.NormalId.Left, "CONCOURSE  >", Color3.fromRGB(255, 200, 90))
	lamp(12, 13.5, -30, "Platform", 30, 1.3, COLD)
	lamp(12, 13.5, 22, "Platform", 30, 1.5, COLD)

	-- the train car: floor level with the platform, doors on the platform side. The car is 12.6 wide (x -15.8..-3.2),
	-- 56 long, 10.9 high inside (tools/models/train.py; resized 2026-11-11, "the train car is too small"). The mesh
	-- shell is what you see; the blocks below are what you stand on and what stops rays (invisible under a shell).
	local car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = model
	local CX = -9.5 -- the car's centre line
	local shell = ModelAssets.Spawn(Assets.Subway and Assets.Subway.Car, CFrame.new(at(CX, -3.4, 0)), "CarShell", car)
	local hide = shell and 1 or 0
	local function carBox(name, x0, x1, y0, y1, z0, z1, material, color)
		local p = box(name, CX + x0, CX + x1, y0, y1, z0, z1, material, color, car)
		p.Transparency = hide
		return p
	end
	if shell then
		for _, p in shell:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide, p.CanQuery = false, false
			end
		end
	end
	-- a door leaf mesh riding on a door block (the block slides; the leaf is welded to it)
	local function dressDoor(door, platformSide)
		local id = shell and Assets.Subway and Assets.Subway.Door
		if not id then
			return
		end
		local leaf = ModelAssets.Spawn(id, CFrame.new(door.Position - Vector3.new(0, door.Size.Y / 2, 0)), "DoorLeaf", door)
		if not leaf then
			return
		end
		if platformSide then
			leaf:PivotTo(leaf:GetPivot() * CFrame.Angles(0, math.pi, 0))
		end
		for _, p in leaf:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = door, p
				w.Parent = p
			end
		end
		door.Transparency = 1
	end
	carBox("Floor", -6.0, 6.0, -0.6, 0, -28, 28, Enum.Material.DiamondPlate, Color3.fromRGB(52, 56, 62))
	carBox("Under", -5.8, 5.8, -3.4, -0.6, -27, 27, Enum.Material.Metal, Color3.fromRGB(26, 28, 32))
	carBox("Roof", -6.3, 6.3, 10.9, 11.6, -28, 28, Enum.Material.Metal, STEEL)
	carBox("EndS", -6.3, 6.3, 0, 10.9, -28, -27.6, Enum.Material.Metal, STEEL)
	carBox("EndN", -6.3, 6.3, 0, 10.9, 27.6, 28, Enum.Material.Metal, STEEL)
	carBox("SideW_Low", -6.3, -6.0, 0, 3.4, -28, 28, Enum.Material.Metal, STEEL)
	carBox("SideW_High", -6.3, -6.0, 7.9, 10.9, -28, 28, Enum.Material.Metal, STEEL)
	local glassW = carBox("GlassW", -6.25, -6.1, 3.4, 7.9, -28, 28, Enum.Material.Glass, Color3.fromRGB(30, 40, 50))
	glassW.Transparency = if shell then 1 else 0.55
	for _, seg in { { -28, -4 }, { 4, 28 } } do
		carBox("SideE_Low", 6.0, 6.3, 0, 3.4, seg[1], seg[2], Enum.Material.Metal, STEEL)
		carBox("SideE_High", 6.0, 6.3, 7.9, 10.9, seg[1], seg[2], Enum.Material.Metal, STEEL)
		local g = carBox("GlassE", 6.1, 6.25, 3.4, 7.9, seg[1], seg[2], Enum.Material.Glass, Color3.fromRGB(30, 40, 50))
		g.Transparency = if shell then 1 else 0.55
	end
	carBox("DoorHead", 6.0, 6.3, 9.0, 10.9, -4, 4, Enum.Material.Metal, STEEL)
	carBox("DoorHeadW", -6.3, -6.0, 9.0, 10.9, -4, 4, Enum.Material.Metal, STEEL)
	-- the far side's doors stay shut
	for _, seg in { { -4, 0 }, { 0, 4 } } do
		local d = box("DoorW", CX - 6.3, CX - 6.0, 0, 9.0, seg[1], seg[2], Enum.Material.Metal, Color3.fromRGB(88, 96, 108), car)
		dressDoor(d, false)
	end
	-- benches: the cushion top is at 1.5, 1.4 deep, against both walls
	for _, seg in { { -24, -7 }, { 7, 24 } } do
		carBox("BenchW", -5.8, -4.4, 0, 1.5, seg[1], seg[2], Enum.Material.Fabric, Color3.fromRGB(60, 44, 40))
		carBox("BenchE", 4.4, 5.8, 0, 1.5, seg[1], seg[2], Enum.Material.Fabric, Color3.fromRGB(60, 44, 40))
	end
	for _, z in { -16, 0, 16 } do
		local tube = box("CarLight", CX - 0.4, CX + 0.4, 10.4, 10.6, z - 3, z + 3, Enum.Material.Neon, COLD, car)
		tube.CanCollide = false
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Color = 20, 0.9, COLD
		l.Parent = tube
	end
	-- the line display over the north end door (the shell's screen sits just behind it)
	local carSign = box("CarSign", CX - 2.2, CX + 2.2, 7.9, 8.5, 27.18, 27.26, Enum.Material.Glass, Color3.fromRGB(16, 20, 24), car)
	level.CarSign = sign(carSign, Enum.NormalId.Front, "> LINE 9 . . . OUTBOUND", Color3.fromRGB(255, 170, 60))
	-- the doors: closed until the ride is over
	for i, seg in { { -4, 0 }, { 0, 4 } } do
		local door = box("Door", CX + 6.0, CX + 6.3, 0, 9.0, seg[1], seg[2], Enum.Material.Metal, Color3.fromRGB(88, 96, 108), car)
		door:SetAttribute("Slide", if i == 1 then -3.8 else 3.8)
		dressDoor(door, true)
		table.insert(level.Doors, door)
	end
	level.Car = car
	level.CarCFrame = CFrame.new(at(CX, 0, 0))
	-- you ride on the west bench facing the doors (root 3.75 in from the centre line: the hips land over the cushion)
	level.Seat = CFrame.lookAt(at(CX - 3.75, 3, 12), at(CX + 6, 3, 12))
	level.Stand = level.CarCFrame * CFrame.new(0, 3, 9) -- in the aisle, facing the doors (client/Intro.lua ends the ride here)

	-- ===== B. the corridor =====
	box("CorridorFloor", 22, 46, -2, 0, 24, 36, Enum.Material.Concrete, CONCRETE)
	box("CorridorCeiling", 22, 46, 9, 11, 24, 36, Enum.Material.Concrete, DARK)
	box("CorridorS", 22, 44, 0, 9, 24, 26, Enum.Material.Concrete, TILE)
	box("CorridorN", 22, 44, 0, 9, 34, 36, Enum.Material.Concrete, TILE)
	lamp(33, 8.6, 30, "Corridor", 12, 0.5, RED, { Unbreakable = true })

	-- ===== C. the ticket hall =====
	box("HallFloor", 44, 108, -2, 0, -2, 62, Enum.Material.Concrete, TILE)
	box("HallCeiling", 44, 108, 14, 16, -2, 62, Enum.Material.Concrete, DARK)
	box("HallW1", 44, 46, 0, 14, -2, 26, Enum.Material.Concrete, CONCRETE)
	box("HallW2", 44, 46, 0, 14, 34, 62, Enum.Material.Concrete, CONCRETE)
	box("HallW3", 44, 46, 9, 14, 26, 34, Enum.Material.Concrete, CONCRETE)
	box("HallE1", 106, 108, 0, 14, -2, 44, Enum.Material.Concrete, CONCRETE)
	box("HallE2", 106, 108, 0, 14, 52, 62, Enum.Material.Concrete, CONCRETE)
	box("HallE3", 106, 108, 9, 14, 44, 52, Enum.Material.Concrete, CONCRETE)
	box("HallS", 44, 108, 0, 14, -2, 0, Enum.Material.Concrete, CONCRETE)
	box("HallN", 44, 108, 0, 14, 60, 62, Enum.Material.Concrete, CONCRETE)
	box("Barrier", 71.5, 72.5, 0, 4, 0, 24, Enum.Material.Metal, STEEL)
	box("Barrier", 71.5, 72.5, 0, 4, 36, 60, Enum.Material.Metal, STEEL)
	for _, z in { 28, 32 } do -- three lanes, each wide enough for a guard to walk (a 2-stud lane stopped them)
		box("Turnstile", 71, 73, 0, 3.6, z - 0.3, z + 0.3, Enum.Material.Metal, Color3.fromRGB(120, 126, 134))
	end
	local booth = box("Booth", 76, 86, 0, 10, 2, 12, Enum.Material.Metal, Color3.fromRGB(46, 52, 60))
	sign(booth, Enum.NormalId.Back, "TICKETS", Color3.fromRGB(120, 130, 140))
	for _, p in { { 58, 15 }, { 58, 45 }, { 90, 15 }, { 90, 45 } } do
		box("Pillar", p[1] - 1.5, p[1] + 1.5, 0, 14, p[2] - 1.5, p[2] + 1.5, Enum.Material.Concrete, CONCRETE)
	end
	for _, c in { { 52, 50 }, { 64, 6 }, { 100, 30 } } do -- crates to stand behind
		box("Crate", c[1] - 2, c[1] + 2, 0, 4.2, c[2] - 2, c[2] + 2, Enum.Material.WoodPlanks, RUST)
	end
	lamp(62, 13.5, 30, "Hall", 30, 1.6)
	lamp(84, 13.5, 30, "Hall", 34, 1.6)
	lamp(96, 13.5, 12, "Hall", 30, 1.4)
	lamp(96, 13.5, 50, "Hall", 30, 1.4)
	-- the fuse box: cuts the hall; whoever comes to fix it stands with his face in it
	local breaker = box("Breaker", 46, 46.8, 2.4, 6, 18.6, 21.4, Enum.Material.Metal, Color3.fromRGB(110, 112, 104))
	breaker:SetAttribute("Circuit", "Hall")
	breaker:SetAttribute("Takedown", "Panel")
	breaker:SetAttribute("Stand", at(49.6, 3, 20))
	CollectionService:AddTag(breaker, "Breaker")
	CollectionService:AddTag(breaker, "TakedownSpot")
	local stripe = box("BreakerStripe", 46.8, 46.86, 5.2, 5.6, 18.8, 21.2, Enum.Material.Neon, HAZARD)
	stripe.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText = "", "Cut"
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.6, 7, false
	prompt.Parent = breaker
	level.Breaker = breaker

	-- ===== D. the stairs and the service tunnel =====
	box("StairCeiling", 108, 128, 9, 11, 42, 54, Enum.Material.Concrete, DARK)
	box("StairS", 108, 126, -10, 9, 42, 44, Enum.Material.Concrete, CONCRETE)
	box("StairN", 108, 142, -10, 9, 52, 54, Enum.Material.Concrete, CONCRETE)
	box("StairUnder", 108, 128, -10, -8.5, 44, 52, Enum.Material.Concrete, DARK)
	box("StairCap", 128, 142, 9, 11, 42, 54, Enum.Material.Concrete, DARK)
	box("StairCapWall", 128, 140, 2, 9, 43.4, 44, Enum.Material.Concrete, DARK)
	box("StairCapWallW", 126, 128, 2, 9, 42, 44, Enum.Material.Concrete, DARK)
	ramp("Stairs", Vector3.new(108, 0, 48), Vector3.new(128, -8, 48), 8)
	box("TunnelFloor", 122, 142, -10, -8, -40, 52, Enum.Material.Slate, DARK)
	box("TunnelCeiling", 122, 142, 2, 4, -40, 44, Enum.Material.Concrete, DARK)
	box("TunnelE", 140, 142, -8, 9, -40, 52, Enum.Material.Concrete, DARK)
	-- west wall with two alcoves to stand in while the torch goes by
	box("TunnelW", 126, 128, -8, 2, 26, 44, Enum.Material.Concrete, DARK)
	box("TunnelW", 126, 128, -8, 2, -4, 20, Enum.Material.Concrete, DARK)
	box("TunnelW", 126, 128, -8, 2, -40, -10, Enum.Material.Concrete, DARK)
	for _, z in { 23, -7 } do
		box("Alcove", 122, 124, -8, 2, z - 3, z + 3, Enum.Material.Concrete, DARK)
		box("Alcove", 124, 128, -8, 2, z - 3.6, z - 3, Enum.Material.Concrete, DARK)
		box("Alcove", 124, 128, -8, 2, z + 3, z + 3.6, Enum.Material.Concrete, DARK)
	end
	local live = box("LiveRail", 138.2, 138.8, -8, -7.4, -36, 40, Enum.Material.Neon, HAZARD)
	live.CanCollide = false
	for _, z in { 30, 14, -2, -18, -34 } do
		spot("Rail", 138.5, -7.5, z)
	end
	local railSign = box("Sign", 139.8, 140, -3, -1, 30, 36, Enum.Material.Metal, HAZARD)
	sign(railSign, Enum.NormalId.Left, "LIVE RAIL", Color3.fromRGB(20, 20, 20))
	lamp(134, 1.6, 36, "Tunnel", 15, 0.7, RED, { Unbreakable = true })
	lamp(134, 1.6, -22, "Tunnel", 15, 0.7, RED, { Unbreakable = true })

	-- ===== E. the lower hall =====
	box("LowerFloor", 98, 148, -10, -8, -102, -40, Enum.Material.Concrete, CONCRETE)
	box("PitFloor", 148, 162, -16, -14, -102, -40, Enum.Material.Slate, DARK)
	box("PitWall", 147.5, 148, -14, -8, -102, -40, Enum.Material.Concrete, DARK)
	box("PitEdge", 146.6, 148, -8, -7.94, -100, -42, Enum.Material.SmoothPlastic, HAZARD).CanCollide = false
	box("LowerCeiling", 98, 162, 10, 12, -102, -38, Enum.Material.Concrete, DARK)
	box("LowerW", 98, 100, -8, 10, -102, -38, Enum.Material.Concrete, CONCRETE)
	box("LowerE", 160, 162, -14, 10, -102, -38, Enum.Material.Concrete, DARK)
	box("LowerN1", 98, 128, -8, 10, -40, -38, Enum.Material.Concrete, CONCRETE)
	box("LowerN2", 140, 162, -14, 10, -40, -38, Enum.Material.Concrete, CONCRETE)
	box("LowerN3", 128, 140, 2, 10, -40, -38, Enum.Material.Concrete, CONCRETE)
	box("LowerS1", 98, 126, -8, 10, -102, -100, Enum.Material.Concrete, CONCRETE)
	box("LowerS2", 134, 162, -14, 10, -102, -100, Enum.Material.Concrete, CONCRETE)
	box("LowerS3", 126, 134, 1, 10, -102, -100, Enum.Material.Concrete, CONCRETE)
	-- the walkway: up the ramp by the tunnel mouth, along the west side, across the hall
	ramp("WalkwayRamp", Vector3.new(126, -8, -45), Vector3.new(110, -1, -45), 6)
	local function walkway(x0, x1, z0, z1)
		box("Walkway", x0, x1, -1.6, -1, z0, z1, Enum.Material.DiamondPlate, STEEL)
	end
	walkway(104, 110, -66, -42)
	walkway(104, 156, -66, -60)
	walkway(150, 156, -96, -66)
	for _, r in { { 104, 156, -59.9 }, { 110, 150, -66.1 } } do -- handrails (thin: they do not stop a drop)
		local rail = box("Handrail", r[1], r[2], 1.6, 1.9, r[3] - 0.15, r[3] + 0.15, Enum.Material.Metal, RUST)
		rail.CanCollide = false
	end
	for _, x in { 112, 130, 148 } do
		box("Hanger", x - 0.2, x + 0.2, -1, 10, -66.3, -65.9, Enum.Material.Metal, RUST).CanCollide = false
	end
	for _, c in { { 112, -84 }, { 120, -56 }, { 138, -84 } } do
		box("Crate", c[1] - 2.5, c[1] + 2.5, -8, -3.6, c[2] - 2.5, c[2] + 2.5, Enum.Material.WoodPlanks, RUST)
	end
	for _, z in { -56, -72, -88 } do
		spot("Ledge", 147.6, -5, z, { DropTo = at(153, -14, z), Stand = at(146.2, -5, z) })
	end
	lamp(130, 9.6, -72, "Deep", 30, 1.6)
	lamp(112, 9.6, -90, "Deep", 26, 1.2)
	lamp(142, 9.6, -92, "Deep", 24, 1.2, COLD)
	local doorSign = box("Sign", 126, 134, 1.4, 3, -100.2, -100, Enum.Material.Metal, Color3.fromRGB(20, 24, 30))
	sign(doorSign, Enum.NormalId.Back, "CONTROL", Color3.fromRGB(255, 200, 90))

	-- ===== F. the control room =====
	box("RoomFloor", 112, 148, -10, -8, -128, -102, Enum.Material.DiamondPlate, Color3.fromRGB(44, 48, 56))
	box("RoomCeiling", 112, 148, 4, 6, -128, -102, Enum.Material.Concrete, DARK)
	box("RoomW", 112, 114, -8, 4, -128, -102, Enum.Material.Concrete, CONCRETE)
	box("RoomE", 146, 148, -8, 4, -128, -102, Enum.Material.Concrete, CONCRETE)
	box("RoomS", 112, 148, -8, 4, -128, -126, Enum.Material.Concrete, CONCRETE)
	local desk = box("Desk", 124, 136, -8, -4.6, -125.6, -121.6, Enum.Material.Metal, Color3.fromRGB(40, 46, 56))
	local console = box("Console", 127, 133, -4.6, -1.2, -125.6, -124.8, Enum.Material.Neon, Color3.fromRGB(0, 190, 230))
	level.ConsoleText = sign(console, Enum.NormalId.Front, "> LINE 9 . . . MANIFEST", Color3.fromRGB(8, 20, 26))
	local cp = Instance.new("ProximityPrompt")
	cp.ObjectText, cp.ActionText = "", "Copy"
	cp.KeyboardKeyCode = Enum.KeyCode.X
	cp.HoldDuration, cp.MaxActivationDistance, cp.RequiresLineOfSight = 1.2, 9, false
	cp.Parent = console
	level.Console, level.ConsolePrompt = console, cp
	local deskLight = Instance.new("PointLight")
	deskLight.Range, deskLight.Brightness, deskLight.Color = 12, 0.8, Color3.fromRGB(0, 190, 230)
	deskLight.Parent = console
	_ = desk
	level.LockerCFrame = CFrame.new(at(118, -5.5, -108))
	-- the way out: a service lift that only answers once the manifest is copied
	local lift = box("Lift", 141, 146, -8, 2, -118, -110, Enum.Material.Metal, Color3.fromRGB(64, 70, 80))
	local liftGlow = box("LiftGlow", 140.9, 141, -3, -2.4, -116, -112, Enum.Material.Neon, RED)
	liftGlow.CanCollide = false
	local lp = Instance.new("ProximityPrompt")
	lp.ObjectText, lp.ActionText = "", "Surface"
	lp.KeyboardKeyCode = Enum.KeyCode.X
	lp.HoldDuration, lp.MaxActivationDistance, lp.RequiresLineOfSight = 1, 9, false
	lp.Enabled = false
	lp.Parent = lift
	level.Lift, level.LiftPrompt, level.LiftGlow = lift, lp, liftGlow

	-- lockers to stand in (round 4): one in the ticket hall by the way in, one in the lower hall
	level.Lockers = {}
	local okStealth, Stealth = pcall(require, script.Parent.Stealth)
	if okStealth then
		for _, spot in { { at(50, 0, 1.2), Vector3.new(0, 0, 1) }, { at(101.2, -8, -60), Vector3.new(1, 0, 0) } } do
			local ok, body = pcall(Stealth.HidingSpot, CFrame.lookAt(spot[1], spot[1] + spot[2]), model)
			if ok then
				table.insert(level.Lockers, body)
			end
		end
	end
	-- ===== who is stationed here =====
	level.Guards = {
		-- his back to the train: the first thing you learn
		{ At = at(13, 3, 19), Post = CFrame.lookAt(at(13, 3, 19), at(17, 3, 30)) },
		-- the hall: one watches the way in from under a lamp, one walks the far wall
		{ At = at(84, 3, 30), Post = CFrame.lookAt(at(84, 3, 30), at(46, 3, 30)) },
		{ At = at(99, 3, 8), Patrol = { at(99, 3, 8), at(99, 3, 54) }, Wait = 3.5 },
		-- the tunnel: a torch walking the rail
		{ At = at(133, -5, 38), Patrol = { at(133, -5, 38), at(133, -5, -30) }, Wait = 2.5, Torch = true },
		-- the lower hall: one under the walkway watching the tunnel mouth, one along the pit
		{ At = at(130, -5, -71), Post = CFrame.lookAt(at(130, -5, -71), at(132, -5, -40)) },
		{ At = at(144, -5, -52), Patrol = { at(144, -5, -52), at(144, -5, -94) }, Wait = 4 },
		-- the control room: at the desk, facing the screens
		{ At = at(130, -5, -119), Post = CFrame.lookAt(at(130, -5, -119), at(130, -5, -126)) },
	}
	level.Checkpoints = {
		CFrame.lookAt(at(-9.5, 3, 0), at(0, 3, 0)),
		CFrame.lookAt(at(40, 3, 30), at(50, 3, 30)),
		CFrame.lookAt(at(112, 3, 48), at(120, 3, 48)),
		CFrame.lookAt(at(134, -5, -34), at(134, -5, -44)),
		CFrame.lookAt(at(130, -5, -105), at(130, -5, -115)),
	}
	return level
end

-- Slides the train doors open (or shut).
function Subway.SetDoors(level, open)
	for _, door in level.Doors do
		local slide = door:GetAttribute("Slide") or 0
		local home = door:GetAttribute("Home")
		if not home then
			home = door.Position
			door:SetAttribute("Home", home)
		end
		door.CFrame = CFrame.new(if open then home + Vector3.new(0, 0, slide) else home)
		door.CanCollide = not open
	end
end

return Subway
