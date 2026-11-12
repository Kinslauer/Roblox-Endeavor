-- The way down (canon: docs/LORE.md "The corporations and the underground", Andy 2026-11-12: the shelters under the
-- city hold the barrens, where cybernetic brain slaves make power by hand; the world the conduits experience seems
-- to run on it; a conduit who tried to free them lost the connection to his stack; players can go down there).
--
-- A service shaft on the Sumps plaza (Config.Barrens.Head) drops to one shared level (Config.Barrens.Origin): the
-- shaft foot, a pipe gallery with a fuse box, the barrens hall (rows of stations: a pale figure wired to a screen,
-- working a crank), and the overseers' office with the stores. It is a stealth level (server/Stealth.lua): lamps on
-- circuits, overseers who patrol and notice by degrees, real deaths. Nothing explains itself.
--   Descend / Climb: hold X at the shaft head / the ladder.
--   Unhook: hold X at a station. The figure slumps, its row goes dark, the hall hears it, and the conduit's own link
--   kicks back: damage, and an uploaded stack loses its upload (log in at the hideout computer again).
-- The hour reaches the barrens like everywhere else outside the green pockets: Barrens.Reset (from Cycle.Run)
-- rehooks the stations, relights the rows, stands the overseers back up and refills the stores.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local Stealth = require(script.Parent.Stealth)
local Loot = require(script.Parent.Loot)
local PlayerData = require(script.Parent.Common.PlayerData)
local Rigs = require(script.Parent.Common.Rigs)

local B = Config.Barrens
local Barrens = {}
Barrens.Unhooked = Instance.new("BindableEvent") -- (player, station)

local CONCRETE = Color3.fromRGB(52, 50, 50)
local DARK = Color3.fromRGB(28, 27, 28)
local STEEL = Color3.fromRGB(66, 70, 76)
local RUST = Color3.fromRGB(88, 58, 42)
local HAZARD = Color3.fromRGB(216, 166, 26)
local SODIUM = Color3.fromRGB(255, 176, 96)
local RED = Color3.fromRGB(255, 60, 44)
local SCREEN = Color3.fromRGB(150, 220, 255)
local SKIN = Color3.fromRGB(176, 170, 164)

local level -- { Model, Stations, Guards, Stores, Office, Foot, ... }
local head -- the shaft head model on the plaza
local inside = {} -- player -> true while below

local function box(parent, name, cf, size, material, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = material or Enum.Material.Concrete
	p.Color = color or CONCRETE
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(part, face, text, color, ppsOverride)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsOverride or 72
	gui.LightInfluence = 0.4
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.Michroma
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(214, 220, 226)
	label.Parent = gui
	return label
end

local function prompt(parent, action, hold, distance)
	local pr = Instance.new("ProximityPrompt")
	pr.ObjectText, pr.ActionText = "", action
	pr.KeyboardKeyCode = Enum.KeyCode.X
	pr.HoldDuration, pr.MaxActivationDistance, pr.RequiresLineOfSight = hold, distance or 8, false
	pr.Parent = parent
	return pr
end

-- ===== the shaft head on the Sumps plaza =====
local function buildHead()
	local model = Instance.new("Model")
	model.Name = "SumpShaft"
	local c = B.Head
	local function at(x, y, z)
		return CFrame.new(c + Vector3.new(x, y, z))
	end
	-- a low concrete collar with a rusted grate, a winch frame over it, a red lamp
	for _, w in { { 0, -4.6, 10, 1.2 }, { 0, 4.6, 10, 1.2 }, { -4.6, 0, 1.2, 8 }, { 4.6, 0, 1.2, 8 } } do
		box(model, "Collar", at(w[1], 0.9, w[2]), Vector3.new(w[3], 1.8, w[4]), Enum.Material.Concrete, CONCRETE)
	end
	local grate = box(model, "Grate", at(0, 1.2, 0), Vector3.new(8, 0.3, 8), Enum.Material.DiamondPlate, RUST)
	grate.Transparency = 0.05
	box(model, "Dark", at(0, 0.6, 0), Vector3.new(8, 0.2, 8), Enum.Material.SmoothPlastic, Color3.new(0, 0, 0)).CanCollide = false
	for _, x in { -4.6, 4.6 } do
		box(model, "WinchLeg", at(x, 5.5, 0), Vector3.new(0.6, 9, 0.6), Enum.Material.CorrodedMetal, RUST)
	end
	box(model, "WinchBeam", at(0, 10.2, 0), Vector3.new(10, 0.6, 0.6), Enum.Material.CorrodedMetal, RUST)
	local drum = box(model, "WinchDrum", at(0, 9.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.6, 3, 1.6), Enum.Material.Metal, STEEL)
	drum.Shape = Enum.PartType.Cylinder
	box(model, "Cable", at(0, 5, 0), Vector3.new(0.15, 8.4, 0.15), Enum.Material.Metal, DARK).CanCollide = false
	local lamp = box(model, "Lamp", at(0, 10.8, 0), Vector3.new(0.8, 0.6, 0.8), Enum.Material.Neon, RED)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = RED, 14, 1.2
	light.Parent = lamp
	local plate = box(model, "Plate", at(0, 1.2, -5.25), Vector3.new(4, 1, 0.1), Enum.Material.Metal, Color3.fromRGB(26, 28, 30))
	sign(plate, Enum.NormalId.Back, "SERVICE . S4 . NO ENTRY", HAZARD)
	-- the hum: what's down there can be heard from the plaza
	local hum = Instance.new("Sound")
	hum.Name = "Hum"
	hum.SoundId = "rbxassetid://" .. tostring(Sounds.Ids.AmbIndustry or Sounds.Ids.AmbCity)
	hum.Looped, hum.Volume, hum.PlaybackSpeed = true, 0.5, 0.55
	hum.RollOffMaxDistance, hum.RollOffMinDistance = 60, 8
	hum.Parent = grate
	pcall(function()
		hum:Play()
	end)
	model.PrimaryPart = grate
	model:SetAttribute("Barrens", "Head")
	model.Parent = workspace
	return model, prompt(grate, "Descend", B.DescendHold, 9)
end

-- ===== the level =====
local function build()
	local origin = B.Origin
	local model = Instance.new("Model")
	model.Name = "Barrens"
	model:SetAttribute("Ambient", B.Ambient)
	local L = { Model = model, Origin = origin, Stations = {}, Lamps = {}, Guards = {}, Stores = {}, GuardSpecs = {}, StoreSpots = {} }

	local function at(x, y, z)
		return origin + Vector3.new(x, y, z)
	end
	local function block(name, x0, x1, y0, y1, z0, z1, material, color)
		return box(model, name, CFrame.new(at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), material, color)
	end
	local function lamp(x, y, z, circuit, range, brightness, color, opts)
		local p = block("Lamp", x - 1.6, x + 1.6, y - 0.25, y + 0.25, z - 0.5, z + 0.5, Enum.Material.Neon, color or SODIUM)
		p.CanCollide = false
		p:SetAttribute("Circuit", circuit)
		p:SetAttribute("Lit", true)
		if opts and opts.Unbreakable then
			p:SetAttribute("Unbreakable", true)
		end
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = range or 30, brightness or 1.4, color or SODIUM
		light.Shadows = true
		light.Parent = p
		CollectionService:AddTag(p, "StealthLight")
		table.insert(L.Lamps, p)
		return p
	end

	-- A. the shaft foot (x -10..10, z -10..10): the ladder up, the cable, a red lamp; the way on is east
	block("FootFloor", -10, 10, -2, 0, -10, 10, Enum.Material.Concrete, CONCRETE)
	block("FootCeiling", -10, 10, 16, 18, -10, 10, Enum.Material.Concrete, DARK)
	block("FootW", -12, -10, 0, 16, -10, 10, Enum.Material.Concrete, DARK)
	block("FootN", -10, 10, 0, 16, 10, 12, Enum.Material.Concrete, DARK)
	block("FootS", -10, 10, 0, 16, -12, -10, Enum.Material.Concrete, DARK)
	block("FootE1", 10, 12, 0, 16, -10, -4, Enum.Material.Concrete, DARK)
	block("FootE2", 10, 12, 0, 16, 4, 10, Enum.Material.Concrete, DARK)
	block("FootE3", 10, 12, 9, 16, -4, 4, Enum.Material.Concrete, DARK)
	block("ShaftMouth", -4, 4, 15.9, 16, -4, 4, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0)).CanCollide = false
	local ladder = block("Ladder", -9.8, -9.4, 0, 16, -1.5, 1.5, Enum.Material.Metal, STEEL)
	for y = 1, 15, 1.5 do
		block("Rung", -9.4, -9, y, y + 0.2, -1.4, 1.4, Enum.Material.Metal, RUST).CanCollide = false
	end
	block("Cable", -0.08, 0.08, 0, 16, -0.08, 0.08, Enum.Material.Metal, DARK).CanCollide = false
	lamp(-6, 15, 6, "Foot", 18, 0.8, RED, { Unbreakable = true })
	L.Foot = CFrame.lookAt(at(-4, 3, 0), at(10, 3, 0))
	L.ClimbPrompt = prompt(ladder, "Climb", B.ClimbHold, 8)

	-- B. the pipe gallery (x 12..90, z -6..6, 10 high), with a fuse box that cuts the hall
	block("GalleryFloor", 10, 92, -2, 0, -6, 6, Enum.Material.DiamondPlate, Color3.fromRGB(46, 48, 52))
	block("GalleryCeiling", 10, 92, 10, 12, -6, 6, Enum.Material.Concrete, DARK)
	block("GalleryN", 12, 90, 0, 10, 6, 8, Enum.Material.Concrete, CONCRETE)
	block("GalleryS", 12, 90, 0, 10, -8, -6, Enum.Material.Concrete, CONCRETE)
	for _, z in { -5.2, 5.2 } do
		for i, y in { 7.5, 8.8 } do
			local pipe = box(model, "Pipe", CFrame.new(at(51, y, z)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(78, 0.9 - i * 0.15, 0.9 - i * 0.15), Enum.Material.CorrodedMetal, RUST)
			pipe.Shape = Enum.PartType.Cylinder
		end
	end
	lamp(30, 9.6, 0, "Gallery", 24, 1.0)
	lamp(70, 9.6, 0, "Gallery", 24, 1.0)
	local breaker = block("Breaker", 64, 66.8, 2.4, 6, 5.2, 6, Enum.Material.Metal, Color3.fromRGB(110, 112, 104))
	breaker:SetAttribute("Circuit", "Hall")
	breaker:SetAttribute("Takedown", "Panel")
	breaker:SetAttribute("Stand", at(65.4, 3, 2.6))
	CollectionService:AddTag(breaker, "Breaker")
	CollectionService:AddTag(breaker, "TakedownSpot")
	block("BreakerStripe", 64.2, 66.6, 5.2, 5.6, 5.12, 5.2, Enum.Material.Neon, HAZARD).CanCollide = false
	L.Breaker = breaker
	L.BreakerPrompt = prompt(breaker, "Cut", 0.6, 7)
	local gs = block("Sign", 88, 89.9, 6.5, 8.5, -5.9, -5.8, Enum.Material.Metal, Color3.fromRGB(20, 22, 26))
	sign(gs, Enum.NormalId.Back, "HALL 2  >", HAZARD)

	-- C. the barrens hall (x 90..190, z -50..50, 24 high)
	block("HallFloor", 90, 190, -2, 0, -50, 50, Enum.Material.Concrete, Color3.fromRGB(44, 42, 42))
	block("HallCeiling", 90, 190, 24, 26, -50, 50, Enum.Material.Concrete, DARK)
	block("HallW1", 90, 92, 0, 24, -50, -6, Enum.Material.Concrete, CONCRETE)
	block("HallW2", 90, 92, 0, 24, 6, 50, Enum.Material.Concrete, CONCRETE)
	block("HallW3", 90, 92, 10, 24, -6, 6, Enum.Material.Concrete, CONCRETE)
	block("HallN", 90, 190, 0, 24, 50, 52, Enum.Material.Concrete, CONCRETE)
	block("HallS", 90, 190, 0, 24, -52, -50, Enum.Material.Concrete, CONCRETE)
	block("HallE1", 190, 192, 0, 24, -50, -5, Enum.Material.Concrete, CONCRETE)
	block("HallE2", 190, 192, 0, 24, 5, 50, Enum.Material.Concrete, CONCRETE)
	block("HallE3", 190, 192, 10, 24, -5, 5, Enum.Material.Concrete, CONCRETE)
	for _, x in { 110, 140, 170 } do
		for _, z in { -46, 46 } do
			block("Pillar", x - 1.5, x + 1.5, 0, 24, z - 1.5, z + 1.5, Enum.Material.Concrete, Color3.fromRGB(62, 60, 58))
		end
	end
	-- the trunk cable along the ceiling: every station's line runs up into it
	block("Trunk", 96, 186, 21, 22.4, -1, 1, Enum.Material.CorrodedMetal, Color3.fromRGB(40, 38, 36))
	local hs = block("Sign", 92, 92.1, 13, 16, -24, -10, Enum.Material.Metal, Color3.fromRGB(20, 22, 26))
	sign(hs, Enum.NormalId.Right, "BARRENS . HALL 2", Color3.fromRGB(200, 204, 210))

	-- the stations: a figure at a crank, a screen in front of it, a line from its head into the trunk
	local rowZ = { -30, 0, 30 }
	local x0, step = 108, 15
	for r = 1, math.min(B.Rows, #rowZ) do
		local z = rowZ[r]
		local circuit = "Row" .. r
		lamp(122, 22.6, z, circuit, 34, 1.3)
		lamp(166, 22.6, z, circuit, 34, 1.3)
		for i = 1, B.PerRow do
			local x = x0 + (i - 1) * step
			local station = { Row = r, Circuit = circuit, Index = (r - 1) * B.PerRow + i }
			station.Stand = CFrame.lookAt(at(x, 0, z), at(x, 0, z + 5))
			block("Plinth", x - 1.8, x + 1.8, 0, 0.4, z - 1.6, z + 1.6, Enum.Material.DiamondPlate, STEEL)
			-- the crank: a frame and a wheel at hand height
			block("CrankPost", x - 0.25, x + 0.25, 0.4, 3.6, z + 2.2, z + 2.7, Enum.Material.Metal, STEEL)
			local wheel = box(model, "Crank", CFrame.new(at(x, 3.8, z + 2.1)) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 2.2, 2.2), Enum.Material.Metal, RUST)
			wheel.Shape = Enum.PartType.Cylinder
			-- the screen
			local screen = block("Screen", x - 1.6, x + 1.6, 5.4, 7.6, z + 3.4, z + 3.6, Enum.Material.Neon, Color3.fromRGB(16, 30, 38))
			station.Screen = screen
			station.Readout = sign(screen, Enum.NormalId.Front, "OUTPUT 1.00", SCREEN, 60)
			local glow = Instance.new("SurfaceLight")
			glow.Face, glow.Range, glow.Brightness, glow.Angle, glow.Color = Enum.NormalId.Front, 6, 0.6, 70, SCREEN
			glow.Parent = screen
			-- the line from the head up into the trunk
			local line = block("Line", x - 0.1, x + 0.1, 6.6, 21, z - 0.1, z + 0.1, Enum.Material.Metal, Color3.fromRGB(22, 22, 24))
			line.CanCollide = false
			station.Line = line
			-- the figure (a pale skin; a block figure where the skin cannot load)
			local figure = Rigs.Statue("Raider", station.Stand * CFrame.new(0, 3.4, 0), model, { Color = SKIN, Bare = true, Name = "Bound" })
			if not figure then
				figure = Instance.new("Model")
				figure.Name = "Bound"
				local torso = box(figure, "Torso", station.Stand * CFrame.new(0, 3.6, 0), Vector3.new(1.6, 2.2, 0.9), Enum.Material.SmoothPlastic, SKIN)
				box(figure, "Head", station.Stand * CFrame.new(0, 5.3, 0), Vector3.new(1, 1.1, 1), Enum.Material.SmoothPlastic, SKIN)
				for _, s in { -1, 1 } do
					box(figure, "Leg", station.Stand * CFrame.new(s * 0.45, 1.5, 0), Vector3.new(0.6, 2.4, 0.6), Enum.Material.SmoothPlastic, SKIN)
					box(figure, "Arm", station.Stand * CFrame.new(s * 0.7, 3.8, 1.1) * CFrame.Angles(math.rad(-70), 0, 0), Vector3.new(0.45, 2.1, 0.45), Enum.Material.SmoothPlastic, SKIN)
				end
				for _, p in figure:GetChildren() do
					p.CanCollide = false
				end
				figure.PrimaryPart = torso
				figure.Parent = model
			end
			figure:SetAttribute("Station", station.Index)
			-- stand it on the plinth (a skin's hips are not at a fixed height): feet on the plate, the head where it is
			local bcf, bsize = figure:GetBoundingBox()
			local bottom = bcf.Position.Y - bsize.Y / 2
			figure:PivotTo(figure:GetPivot() + Vector3.new(0, origin.Y + 0.4 - bottom, 0))
			local headY = 0.4 + bsize.Y - 0.85
			station.Figure = figure
			station.Rest = figure:GetPivot()
			line.Size = Vector3.new(0.2, 21 - headY, 0.2)
			line.CFrame = CFrame.new(at(x, (21 + headY) / 2, z))
			-- a halo of contacts round the head
			local ring = box(model, "Halo", station.Stand * CFrame.new(0, headY, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.25, 1.6, 1.6), Enum.Material.Metal, Color3.fromRGB(40, 40, 44))
			ring.Shape = Enum.PartType.Cylinder
			ring.CanCollide = false
			station.Halo = ring
			station.Prompt = prompt(block("StationPrompt", x - 0.5, x + 0.5, 2.5, 3.5, z + 1.2, z + 1.8, Enum.Material.SmoothPlastic, DARK), "Unhook", B.UnhookHold, 6)
			station.Prompt.Parent.Transparency = 1
			station.Prompt.Parent.CanCollide = false
			table.insert(L.Stations, station)
		end
	end

	-- D. the office (x 192..222, z -16..16), its window onto the hall, the stores
	block("OfficeFloor", 192, 222, -2, 0, -16, 16, Enum.Material.DiamondPlate, Color3.fromRGB(44, 48, 56))
	block("OfficeCeiling", 192, 222, 10, 12, -16, 16, Enum.Material.Concrete, DARK)
	block("OfficeE", 220, 222, 0, 10, -16, 16, Enum.Material.Concrete, CONCRETE)
	block("OfficeN", 192, 222, 0, 10, 14, 16, Enum.Material.Concrete, CONCRETE)
	block("OfficeS", 192, 222, 0, 10, -16, -14, Enum.Material.Concrete, CONCRETE)
	block("Desk", 202, 210, 0, 3.4, -4, 4, Enum.Material.Metal, Color3.fromRGB(40, 46, 56))
	local console = block("Console", 209.6, 210, 3.4, 6.6, -3, 3, Enum.Material.Neon, Color3.fromRGB(0, 160, 200))
	L.Console = sign(console, Enum.NormalId.Right, "", Color3.fromRGB(8, 20, 26), 60)
	lamp(206, 9.6, -9, "Office", 20, 1.1, Color3.fromRGB(220, 236, 255))
	lamp(206, 9.6, 9, "Office", 20, 1.1, Color3.fromRGB(220, 236, 255))
	L.StoreSpots = { CFrame.new(at(217, 1.2, -11)), CFrame.new(at(217, 1.2, 11)), CFrame.new(at(84, 1.2, -3.5)) }

	-- who works here: an overseer at the gallery's end, two walking the aisles, one at the desk
	L.GuardSpecs = {
		{ At = at(80, 3, 0), Post = CFrame.lookAt(at(80, 3, 0), at(40, 3, 0)) },
		{ At = at(100, 3, -15), Patrol = { at(100, 3, -15), at(184, 3, -15) }, Wait = 3 },
		{ At = at(184, 3, 15), Patrol = { at(184, 3, 15), at(100, 3, 15) }, Wait = 3 },
		{ At = at(212, 3, 0), Post = CFrame.lookAt(at(212, 3, 0), at(198, 3, 0)) },
	}
	L.Fragments = { at(96, 0, -44), at(186, 0, 44), at(200, 0, -12), at(40, 0, -3) }
	model.Parent = workspace
	return L
end

-- ===== state =====
local function readout()
	if not level then
		return
	end
	local hands = 0
	for _, s in level.Stations do
		if not s.Unhooked then
			hands += 1
		end
	end
	level.Hands = hands
	level.Console.Text = ("> BARRENS . HALL 2\n> HANDS %d/%d\n> OUTPUT %s"):format(hands, #level.Stations, if hands == #level.Stations then "NOMINAL" else "FALLING")
end

local function spawnGuards()
	for _, m in level.Guards do
		if m.Parent then
			m:Destroy()
		end
	end
	level.Guards = {}
	for _, spec in level.GuardSpecs do
		local ok, model = pcall(Stealth.SpawnGuard, spec.At, { Level = level.Model, Patrol = spec.Patrol, Post = spec.Post, Wait = spec.Wait, Loot = "Overseer" })
		if ok and model then
			table.insert(level.Guards, model)
		else
			warn("[Barrens] overseer failed:", model)
		end
	end
end

local function fillStores()
	for _, part in level.Stores do
		if part.Parent then
			part:Destroy()
		end
	end
	level.Stores = {}
	for i, cf in level.StoreSpots do
		local part = Loot.Spawn(cf, Items.Roll(if i < 3 then "Barrens" else "Overseer"), { Label = "Store", Mesh = "CrateB", Hold = 0.8 })
		if part then
			part.Anchored = true
			part.Parent = level.Model
			table.insert(level.Stores, part)
		end
	end
end

local function hook(station)
	station.Unhooked = nil
	station.Figure:PivotTo(station.Rest)
	station.Line.Transparency = 0
	station.Readout.Text = "OUTPUT 1.00"
	station.Prompt.Enabled = true
end

-- The hour: everything down here back as it was.
function Barrens.Reset()
	if not level then
		return
	end
	for _, s in level.Stations do
		hook(s)
	end
	for _, circuit in { "Row1", "Row2", "Row3", "Hall", "Gallery", "Office" } do
		Stealth.SetCircuit(level.Model, circuit, true)
	end
	for _, p in level.Lamps do
		p:SetAttribute("Lit", true)
	end
	level.Breaker:SetAttribute("Cut", nil)
	spawnGuards()
	fillStores()
	readout()
end

-- ===== going down and coming up =====
local function fade(player)
	Remotes.World:FireClient(player, "Shaft", B.FadeSeconds)
end

function Barrens.Descend(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (level and root and hum and hum.Health > 0) or inside[player] then
		return false
	end
	if (root.Position - B.Head).Magnitude > 14 then
		return false
	end
	inside[player] = true
	fade(player)
	task.wait(B.FadeSeconds)
	if not (char.Parent and hum.Health > 0) then
		inside[player] = nil
		return false
	end
	char:PivotTo(level.Foot)
	Stealth.Enter(player, level.Model)
	player:SetAttribute("Below", true)
	return true
end

function Barrens.Climb(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (level and root and inside[player]) then
		return false
	end
	if (root.Position - level.Foot.Position).Magnitude > 20 then
		return false
	end
	fade(player)
	task.wait(B.FadeSeconds)
	Barrens.Leave(player)
	if char.Parent then
		char:PivotTo(CFrame.new(B.Head + Vector3.new(0, 3, -8)))
	end
	return true
end

-- Off the level (climbed, died, left the server).
function Barrens.Leave(player)
	if not inside[player] then
		return
	end
	inside[player] = nil
	player:SetAttribute("Below", nil)
	if Stealth.LevelOf(player) == (level and level.Model) then
		Stealth.Leave(player)
	end
end

function Barrens.Inside(player)
	return inside[player] == true
end

-- ===== unhooking =====
-- Never a clean win (canon): the row goes dark, the hall hears it, and the conduit's own link kicks back.
function Barrens.Unhook(player, station)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (level and station and not station.Unhooked and root and hum and hum.Health > 0 and inside[player]) then
		return false
	end
	if (root.Position - station.Stand.Position).Magnitude > 9 then
		return false
	end
	station.Unhooked = true
	station.Prompt.Enabled = false
	-- the figure slumps forward over the crank; the line hangs dead; the screen reads nothing
	station.Figure:PivotTo(station.Rest * CFrame.new(0, -1.6, 0.6) * CFrame.Angles(math.rad(-38), 0, 0))
	station.Line.Transparency = 1
	station.Readout.Text = "--"
	Remotes.World:FireAllClients("Sparks", station.Screen.Position)
	-- its row goes dark: what it made lit them
	Stealth.SetCircuit(level.Model, station.Circuit, false)
	Stealth.Noise(station.Stand.Position, B.UnhookNoise, "Glass", player)
	-- the kick back: the conduit's link
	hum:TakeDamage(B.UnhookDamage)
	local data = PlayerData.Get(player)
	local k = data and data.Knowledge
	if k and k.Uploaded then
		k.Uploaded = false
		Remotes.Announce:FireClient(player, "> STACK . . . NO CARRIER", "Info")
	else
		Remotes.Announce:FireClient(player, "> LINK . . . NO CARRIER", "Info")
	end
	Remotes.World:FireClient(player, "Flicker", 1.5)
	readout()
	Barrens.Unhooked:Fire(player, station)
	return true
end

-- ===== screens =====
local function screens()
	local rng = Random.new()
	while level do
		task.wait(B.ScreenEvery)
		for _, s in level.Stations do
			if not s.Unhooked then
				s.Readout.Text = ("OUTPUT %.2f"):format(rng:NextNumber(0.86, 1.0))
			end
		end
	end
end

-- Where a fragment can lie down here (CluesServer "Barrens").
function Barrens.FragmentSpot(rng)
	if not level then
		return nil
	end
	return level.Fragments[rng:NextInteger(1, #level.Fragments)]
end

function Barrens.Level()
	return level
end

function Barrens.HeadModel()
	return head
end

function Barrens.Init()
	if not B.Enabled then
		return
	end
	local t0 = os.clock()
	level = build()
	local headModel, descend = buildHead()
	head = headModel
	descend.Triggered:Connect(function(player)
		task.spawn(Barrens.Descend, player)
	end)
	level.ClimbPrompt.Triggered:Connect(function(player)
		task.spawn(Barrens.Climb, player)
	end)
	level.BreakerPrompt.Triggered:Connect(function(player)
		if inside[player] then
			Stealth.Breaker(player, level.Breaker)
		end
	end)
	for _, s in level.Stations do
		s.Prompt.Triggered:Connect(function(player)
			Barrens.Unhook(player, s)
		end)
	end
	local function watch(player)
		player.CharacterAdded:Connect(function(char)
			Barrens.Leave(player) -- a new body is never below
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					Barrens.Leave(player)
				end)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		Barrens.Leave(player)
	end)
	Barrens.Reset()
	task.spawn(screens)
	print(("[Barrens] %d stations, %d overseers, %d stores in %.1fs"):format(#level.Stations, #level.Guards, #level.Stores, os.clock() - t0))
end

return Barrens
