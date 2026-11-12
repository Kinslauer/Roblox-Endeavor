-- The first link into a recruit. The recruit jolts awake in a stasis tank (the client makes the view
-- frantic, then the clone's memories sync in flashes of the war world). The tank drains, the cables
-- unlatch, the floor opens and a chute drops it into a barracks where its conduit's supply is laid out:
-- the ordered locker gear, with issue gear filling any empty slot. Once everything is fitted the
-- recruit links into the simulation (Simulation.lua), a wireframe city it can break while it learns to
-- fight, and then drops onto the Front at its faction's base.
--
-- Everything is built per player in the sky, far from the battlefield (Config.War.Intro.Origin, one
-- slot per player). Nothing here explains itself: the client gets stage names, never instructions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Firearms = require(Shared.Firearms)
local Remotes = require(Shared.Remotes)
local Assets = require(Shared.Assets)
local Net = require(script.Parent.Common.Net)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local PlayerData = require(script.Parent.Common.PlayerData)
local Recruit = require(script.Parent.Common.Recruit)
local Soldiers = require(script.Parent.Soldiers)
local Bodies = require(script.Parent.Bodies)
local Rigs = require(script.Parent.Common.Rigs)
local Simulation = require(script.Parent.Simulation)

local I = Config.War.Intro
local Intro = {}

local active = {} -- [player] = ctx
local slots = {} -- [index] = player
local seen = {} -- [userId] = true once the intro finished on this server (dev replay plays it once per server)

local METAL = Color3.fromRGB(58, 62, 68)
local DARK = Color3.fromRGB(28, 30, 34)
local TEAL = Color3.fromRGB(70, 210, 200)

-- ===== helpers =====
local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Color, p.Material = METAL, Enum.Material.Metal
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function cylinder(parent, props, height, diameter, center)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	return part(parent, props)
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness or 1
	l.Parent = parent
	return l
end

-- a box room: floor top at y0, walls `h` high, open where `skip` says ("Ceiling", "N", "S", "E", "W")
local function room(parent, center, w, d, h, color, skip)
	skip = skip or {}
	local y0 = center.Y
	if not skip.Floor then
		part(parent, { Name = "Floor", Size = Vector3.new(w, 1, d), CFrame = CFrame.new(center - Vector3.new(0, 0.5, 0)), Color = color })
	end
	if not skip.Ceiling then
		part(parent, { Name = "Ceiling", Size = Vector3.new(w, 1, d), CFrame = CFrame.new(center + Vector3.new(0, h + 0.5, 0)), Color = color })
	end
	local walls = {
		N = { Vector3.new(w, h, 1), Vector3.new(0, h / 2, d / 2 + 0.5) },
		S = { Vector3.new(w, h, 1), Vector3.new(0, h / 2, -d / 2 - 0.5) },
		E = { Vector3.new(1, h, d), Vector3.new(w / 2 + 0.5, h / 2, 0) },
		W = { Vector3.new(1, h, d), Vector3.new(-w / 2 - 0.5, h / 2, 0) },
	}
	for side, spec in walls do
		if not skip[side] then
			part(parent, { Name = "Wall" .. side, Size = spec[1], CFrame = CFrame.new(center + spec[2]), Color = color })
		end
	end
	return y0
end

local function slotOrigin(index)
	return I.Origin + I.SlotStep * (index - 1)
end

local function takeSlot(player)
	local i = 1
	while slots[i] do
		i += 1
	end
	slots[i] = player
	return i
end

local function notify(ctx, stage, data)
	if ctx.player.Parent then
		Remotes.Tutorial:FireClient(ctx.player, "Front", stage, data or {})
	end
end

-- ===== the kit: the conduit's order, with issue gear in every slot it leaves empty =====
function Intro.Curate(kit, faction)
	local issue = I.Issue[faction] or I.Issue.Union
	kit.Original = { Magazines = kit.Magazines or 0, Grenades = kit.Grenades or 0, Medkits = kit.Medkits or 0, Sandbags = kit.Sandbags or 0 }
	kit.Issued = {}
	for _, slot in { "Primary", "Sidearm", "Armor", "Helmet" } do
		if not kit[slot] and issue[slot] then
			kit[slot] = { Id = issue[slot], Condition = 100 }
			kit.Issued[slot] = true
		end
	end
	kit.Attachments = kit.Attachments or {}
	for _, key in { "Magazines", "Grenades", "Medkits", "Sandbags" } do
		kit[key] = math.max(kit[key] or 0, issue[key] or 0)
	end
	return kit
end

-- the locker gets back what the deployment took from it (left or died before the drop)
local function refund(player, kit)
	local data = PlayerData.Get(player)
	if not (data and kit) or kit.Refunded then
		return
	end
	kit.Refunded = true
	local war = data.War
	for _, slot in { "Primary", "Sidearm", "Armor", "Helmet" } do
		local entry = kit[slot]
		if entry and not (kit.Issued and kit.Issued[slot]) then
			Recruit.LockerAdd(war, entry.Id, entry.Condition, 1)
		end
	end
	if not (kit.Issued and kit.Issued.Primary) then
		for _, att in kit.Attachments or {} do
			Recruit.LockerAdd(war, att.Id, att.Condition, 1)
		end
		for _, att in kit.Spares or {} do
			Recruit.LockerAdd(war, att.Id, att.Condition, 1)
		end
	end
	local o = kit.Original or {}
	if (o.Magazines or 0) > 0 then
		Recruit.LockerAdd(war, "Ammo", 100, o.Magazines)
	end
	if (o.Grenades or 0) > 0 then
		Recruit.LockerAdd(war, "Grenade", 100, o.Grenades)
	end
	if (o.Medkits or 0) > 0 then
		Recruit.LockerAdd(war, "Medkit", 100, o.Medkits)
	end
	if (o.Sandbags or 0) > 0 then
		Recruit.LockerAdd(war, "Sandbags", 100, 1)
	end
	war.Deployments = math.max(0, war.Deployments - 1)
end

-- ===== the cell: stasis chamber over a chute over the barracks =====
-- Slot origin o = the barracks floor top. The chamber floor sits CHAMBER studs above it.
local CHAMBER = 40
local TANK_Z = -8
local TANK_H = 11
local TANK_D = 7.2

local function silhouette(parent, base)
	-- another clone, still growing: a dark shape hanging in the fluid (the recruits' own body, unclothed in colour)
	if Bodies.Ready and Rigs.Statue("Recruit", CFrame.new(base + Vector3.new(0, 4.9, 0)) * CFrame.Angles(0, math.pi, 0), parent,
		{ Name = "Clone", Groups = { Under = true } }) then
		return
	end
	for _, spec in { { Vector3.new(1.8, 2.2, 1), 3.9 }, { Vector3.new(1.1, 1.1, 1.1), 5.6 }, { Vector3.new(1.6, 2.6, 0.9), 1.6 } } do
		part(parent, { Name = "Clone", Size = spec[1], CFrame = CFrame.new(base + Vector3.new(0, spec[2] + 1, 0)), Color = Color3.fromRGB(20, 26, 30), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Transparency = 0.15 })
	end
end

local function tank(parent, base, occupied, n)
	if not occupied then -- the occupied tank stands on its hatch instead
		cylinder(parent, { Name = "TankBase", Color = DARK }, 1.2, TANK_D + 1.4, base + Vector3.new(0, 0.6, 0))
	end
	cylinder(parent, { Name = "TankLid", Color = DARK }, 1.4, TANK_D + 1.4, base + Vector3.new(0, TANK_H + 0.7, 0))
	local glass = cylinder(parent, { Name = "TankGlass", Material = Enum.Material.Glass, Color = Color3.fromRGB(160, 220, 230), Transparency = 0.75, CanCollide = false, CanQuery = false },
		TANK_H, TANK_D, base + Vector3.new(0, TANK_H / 2, 0))
	local liquid = cylinder(parent, { Name = "TankFluid", Material = Enum.Material.SmoothPlastic, Color = TEAL, Transparency = 0.55, CanCollide = false, CanQuery = false },
		TANK_H - 0.4, TANK_D - 0.3, base + Vector3.new(0, (TANK_H - 0.4) / 2 + 0.1, 0))
	local glow = part(parent, { Name = "TankGlow", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(base + Vector3.new(0, TANK_H, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
	light(glow, TEAL, 14, if occupied then 2 else 0.8)
	-- the ring of ribs that actually holds a body in (the glass itself does not collide)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local at = base + Vector3.new(math.cos(a) * (TANK_D / 2 + 0.1), TANK_H / 2, math.sin(a) * (TANK_D / 2 + 0.1))
		part(parent, { Name = "TankRib", Size = Vector3.new(2.9, TANK_H, 0.3), CFrame = CFrame.lookAt(at, base + Vector3.new(0, TANK_H / 2, 0)),
			Color = DARK, Transparency = if i % 2 == 0 then 0 else 1 })
	end
	if not occupied then
		silhouette(parent, base)
	end
	-- the lid's stencil: these tanks are the crates that come up Line 9 in the city (shared/Config Tutorial.Manifest)
	local plate = part(parent, { Name = "TankPlate", Size = Vector3.new(3.2, 0.7, 0.1), CFrame = CFrame.new(base + Vector3.new(0, TANK_H + 0.7, TANK_D / 2 + 0.76)),
		Color = Color3.fromRGB(70, 66, 58), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.LightInfluence = Enum.NormalId.Back, 0.4
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextScaled, label.Font = UDim2.fromScale(1, 1), 1, true, Enum.Font.Code
	label.Text, label.TextColor3 = ("LINE 9 . STACK HARDWARE . %02d/40"):format(n or 1), Color3.fromRGB(230, 220, 190)
	label.Parent = gui
	return glass, liquid
end

local function buildCell(o, ctx)
	local folder = Instance.new("Folder")
	folder.Name = "IntroCell_" .. ctx.player.UserId
	local cell = { Folder = folder, Origin = o }

	-- the barracks: concrete, bunks, a sealed door, the conduit's supply on benches
	local barracks = Instance.new("Folder")
	barracks.Name = "Barracks"
	barracks.Parent = folder
	room(barracks, o, 40, 30, 12, Color3.fromRGB(84, 82, 76), { Ceiling = true })
	-- ceiling around the chute mouth (a 6x6 hole over TANK_Z)
	local cy = o.Y + 12.5
	part(barracks, { Name = "Ceiling", Size = Vector3.new(40, 1, 15 - (TANK_Z + 3)), CFrame = CFrame.new(o.X, cy, o.Z + (15 + TANK_Z + 3) / 2), Color = Color3.fromRGB(70, 68, 64) })
	part(barracks, { Name = "Ceiling", Size = Vector3.new(40, 1, (TANK_Z - 3) + 15), CFrame = CFrame.new(o.X, cy, o.Z + (TANK_Z - 3 - 15) / 2), Color = Color3.fromRGB(70, 68, 64) })
	part(barracks, { Name = "Ceiling", Size = Vector3.new(17, 1, 6), CFrame = CFrame.new(o.X - 11.5, cy, o.Z + TANK_Z), Color = Color3.fromRGB(70, 68, 64) })
	part(barracks, { Name = "Ceiling", Size = Vector3.new(17, 1, 6), CFrame = CFrame.new(o.X + 11.5, cy, o.Z + TANK_Z), Color = Color3.fromRGB(70, 68, 64) })
	for _, x in { -10, 10 } do
		local lamp = part(barracks, { Name = "Lamp", Size = Vector3.new(4, 0.3, 1), CFrame = CFrame.new(o + Vector3.new(x, 11.8, 4)), Color = Color3.fromRGB(255, 214, 160), Material = Enum.Material.Neon })
		light(lamp, Color3.fromRGB(255, 205, 150), 26, 1.4)
	end
	part(barracks, { Name = "LandingMat", Size = Vector3.new(6, 0.4, 6), CFrame = CFrame.new(o + Vector3.new(0, 0.2, TANK_Z)), Color = Color3.fromRGB(50, 56, 44), Material = Enum.Material.Fabric })
	-- the way out is shut: drops go through the panel (later), the first one through the simulation
	local door = part(barracks, { Name = "BlastDoor", Size = Vector3.new(10, 9, 1.2), CFrame = CFrame.new(o + Vector3.new(0, 4.5, 14.6)), Color = Color3.fromRGB(60, 58, 50), Material = Enum.Material.DiamondPlate })
	local doorLamp = part(barracks, { Name = "DoorLamp", Size = Vector3.new(1, 0.5, 0.3), CFrame = CFrame.new(o + Vector3.new(0, 9.8, 14.1)), Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon })
	cell.DoorLamp = doorLamp
	cell.Door = door
	for _, x in { -13, 13 } do
		if not ModelAssets.Spawn(Assets.Hideout.Bunks, CFrame.new(o + Vector3.new(x, 0, -11)), "Bunks", barracks) then
			part(barracks, { Name = "Bunks", Size = Vector3.new(7, 5, 3), CFrame = CFrame.new(o + Vector3.new(x, 2.5, -11)), Color = Color3.fromRGB(70, 74, 60) })
		end
	end

	-- the chute: a lit steel shaft from the chamber floor down through the barracks ceiling
	local chute = Instance.new("Folder")
	chute.Name = "Chute"
	chute.Parent = folder
	local shaftH = CHAMBER - 13
	local shaftC = o + Vector3.new(0, 13 + shaftH / 2, TANK_Z)
	for _, spec in { { Vector3.new(7, shaftH, 0.6), Vector3.new(0, 0, 3.3) }, { Vector3.new(7, shaftH, 0.6), Vector3.new(0, 0, -3.3) }, { Vector3.new(0.6, shaftH, 6), Vector3.new(3.3, 0, 0) }, { Vector3.new(0.6, shaftH, 6), Vector3.new(-3.3, 0, 0) } } do
		part(chute, { Name = "Shaft", Size = spec[1], CFrame = CFrame.new(shaftC + spec[2]), Color = DARK, Material = Enum.Material.DiamondPlate })
	end
	for k = 0, 3 do
		local strip = part(chute, { Name = "ShaftLight", Size = Vector3.new(5, 0.25, 0.1), CFrame = CFrame.new(o + Vector3.new(0, 16 + k * 6.5, TANK_Z - 2.95)), Color = Color3.fromRGB(255, 180, 90), Material = Enum.Material.Neon, CanCollide = false })
		if k % 2 == 0 then
			light(strip, Color3.fromRGB(255, 170, 90), 10, 0.8)
		end
	end

	-- the stasis chamber: three tanks in a row, the middle one is this recruit's
	local chamber = Instance.new("Folder")
	chamber.Name = "Chamber"
	chamber.Parent = folder
	local floorY = o.Y + CHAMBER
	local cc = Vector3.new(o.X, floorY, o.Z + TANK_Z + 5)
	-- chamber floor with the tank's 6x6 drop hole
	-- the chamber spans z TANK_Z-7 .. TANK_Z+17; the drop hole is 6x6 around (0, TANK_Z)
	part(chamber, { Name = "Floor", Size = Vector3.new(28, 1, 14), CFrame = CFrame.new(o.X, floorY - 0.5, o.Z + TANK_Z + 10), Color = DARK })
	part(chamber, { Name = "Floor", Size = Vector3.new(28, 1, 4), CFrame = CFrame.new(o.X, floorY - 0.5, o.Z + TANK_Z - 5), Color = DARK })
	part(chamber, { Name = "Floor", Size = Vector3.new(11, 1, 6), CFrame = CFrame.new(o.X - 8.5, floorY - 0.5, o.Z + TANK_Z), Color = DARK })
	part(chamber, { Name = "Floor", Size = Vector3.new(11, 1, 6), CFrame = CFrame.new(o.X + 8.5, floorY - 0.5, o.Z + TANK_Z), Color = DARK })
	room(chamber, cc, 28, 24, 16, DARK, { Floor = true })
	for _, x in { -12, 12 } do
		local strip = part(chamber, { Name = "Strip", Size = Vector3.new(0.3, 12, 0.3), CFrame = CFrame.new(o + Vector3.new(x, CHAMBER + 7, TANK_Z + 14)), Color = TEAL, Material = Enum.Material.Neon, CanCollide = false })
		light(strip, TEAL, 16, 0.6)
	end
	local base = Vector3.new(o.X, floorY, o.Z + TANK_Z)
	local crate = ((ctx.player.UserId or 0) * 7 + (ctx.slot or 0)) % 38 + 2
	local glass, liquid = tank(chamber, base, true, crate)
	tank(chamber, base + Vector3.new(-8.5, 0, 0), false, crate - 1)
	tank(chamber, base + Vector3.new(8.5, 0, 0), false, crate + 1)
	-- the hatch under this recruit's tank
	local hatch = part(chamber, { Name = "Hatch", Size = Vector3.new(6.4, 0.6, 6.4), CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(40, 44, 46), Material = Enum.Material.DiamondPlate })
	cell.Glass, cell.Liquid, cell.Hatch = glass, liquid, hatch
	cell.TankBase = base
	cell.FloatCF = CFrame.new(base + Vector3.new(0, 5.4, 0)) * CFrame.Angles(0, math.pi, 0) -- facing out of the row (+Z)
	cell.StandCF = CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.pi, 0)
	cell.LandCF = CFrame.new(o + Vector3.new(0, 3.5, TANK_Z))
	folder.Parent = workspace
	return cell
end

-- ===== the barracks benches =====
local function displayModel(parent, id, cf, fallbackSize, color)
	local spec = Assets.Weapons[id]
	local worn = Assets.Worn[id]
	local model = (spec and ModelAssets.Spawn(spec.Id, cf, "Display", parent)) or (worn and ModelAssets.Spawn(worn.Id, cf, "Display", parent))
	if not model then
		model = part(parent, { Name = "Display", Size = fallbackSize, CFrame = cf * CFrame.new(0, fallbackSize.Y / 2, 0), Color = color or Color3.fromRGB(60, 64, 56), CanCollide = false })
	end
	return model
end

local function pieceName(kit, piece)
	if piece == "Supplies" then
		local bits = {}
		if (kit.Magazines or 0) > 0 then
			table.insert(bits, ("%d mags"):format(kit.Magazines))
		end
		if (kit.Grenades or 0) > 0 then
			table.insert(bits, ("%d frags"):format(kit.Grenades))
		end
		if (kit.Medkits or 0) > 0 then
			table.insert(bits, ("%d dressing"):format(kit.Medkits))
		end
		if (kit.Sandbags or 0) > 0 then
			table.insert(bits, "sandbags")
		end
		return table.concat(bits, ", ")
	end
	local entry = kit[piece]
	local def = entry and (Firearms.Defs[entry.Id] or Firearms.Armor[entry.Id])
	local name = (def and def.Name) or (entry and entry.Id) or piece
	if entry and entry.Condition < 100 then
		name ..= (" (%d%%)"):format(entry.Condition)
	end
	if piece == "Primary" then
		for _, att in kit.Attachments or {} do
			local a = Firearms.Attachments[att.Id]
			if a then
				name ..= " + " .. a.Name
			end
		end
	end
	return name
end

local BENCHES = {
	Primary = { Vector3.new(-17, 0, 0), "rack" },
	Sidearm = { Vector3.new(-17, 0, 7), "bench" },
	Armor = { Vector3.new(17, 0, 0), "stand" },
	Helmet = { Vector3.new(17, 0, 7), "shelf" },
	Supplies = { Vector3.new(8, 0, 11.5), "crate" },
}

local function layOut(ctx)
	local o, kit = ctx.cell.Origin, ctx.kit
	local folder = Instance.new("Folder")
	folder.Name = "Supply"
	folder.Parent = ctx.cell.Folder
	ctx.total, ctx.taken = 0, 0
	for _, piece in Soldiers.Pieces(kit) do
		local spec = BENCHES[piece]
		local at = o + spec[1]
		local facing = if spec[1].X < 0 then math.pi / 2 elseif spec[1].X > 0 then -math.pi / 2 else math.pi
		local holder = Instance.new("Model")
		holder.Name = "Bench_" .. piece
		holder.Parent = folder
		local bench
		if piece == "Supplies" then
			bench = ModelAssets.Spawn(Assets.Front.AmmoCrate, CFrame.new(at) * CFrame.Angles(0, facing, 0), "Crate", holder)
			bench = bench and bench.PrimaryPart
			if not bench then
				bench = part(holder, { Name = "Crate", Size = Vector3.new(4, 2.6, 2.6), CFrame = CFrame.new(at + Vector3.new(0, 1.3, 0)), Color = Color3.fromRGB(70, 78, 46), Material = Enum.Material.Wood })
			end
		else
			local h = if piece == "Armor" then 1 else 3
			bench = part(holder, { Name = "Bench", Size = Vector3.new(2.6, h, 5), CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(66, 70, 64), Material = Enum.Material.Metal })
			local top = at + Vector3.new(0, h, 0)
			local entry = kit[piece]
			if piece == "Primary" or piece == "Sidearm" then
				-- laid flat across the bench, muzzle toward the back wall
				displayModel(holder, entry.Id, CFrame.new(top) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, 0, 0), Vector3.new(0.4, 0.6, if piece == "Primary" then 3.4 else 1.2))
			elseif piece == "Armor" then
				part(holder, { Name = "Stand", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = CFrame.new(top + Vector3.new(0, 1.6, 0)), Color = DARK })
				displayModel(holder, entry.Id, CFrame.new(top + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, facing, 0), Vector3.new(2, 2, 1))
			else
				displayModel(holder, entry.Id, CFrame.new(top) * CFrame.Angles(0, facing, 0), Vector3.new(1.4, 0.8, 1.6))
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = pieceName(kit, piece), "Take", 0.35
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 9, false, Enum.KeyCode.X
		prompt.Parent = bench
		ctx.total += 1
		ctx.benches = ctx.benches or {}
		ctx.benches[piece] = holder
		prompt.Triggered:Connect(function(who)
			if who ~= ctx.player or not holder.Parent then
				return
			end
			if Soldiers.Give(who, piece) then
				holder:Destroy()
				ctx.taken += 1
				notify(ctx, "Equip", { Taken = ctx.taken, Total = ctx.total, Piece = piece })
			end
		end)
	end
end

-- ===== cables: the recruit hangs on them in the fluid until the unlatch =====
local function cables(ctx, root)
	local made = {}
	for i, offset in { Vector3.new(-0.5, 0.6, 0.55), Vector3.new(0.5, 0.6, 0.55), Vector3.new(0, -0.4, 0.6) } do
		local a0 = Instance.new("Attachment")
		a0.Name, a0.Position = "Cable" .. i, offset
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "Cable" .. i
		a1.Parent = ctx.cell.Glass
		a1.WorldPosition = ctx.cell.TankBase + Vector3.new((i - 2) * 1.6, TANK_H - 0.2, -1.5)
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1, beam.CurveSize0, beam.CurveSize1 = 0.18, 0.3, -1, 2
		beam.Color = ColorSequence.new(Color3.fromRGB(30, 34, 36))
		beam.Transparency = NumberSequence.new(0)
		beam.FaceCamera = true
		beam.Parent = root
		-- the latch on the spine
		local latch = Instance.new("Part")
		latch.Name, latch.Size, latch.Color, latch.Material = "Latch", Vector3.new(0.5, 0.35, 0.3), Color3.fromRGB(80, 86, 92), Enum.Material.Metal
		latch.CanCollide, latch.Massless, latch.CanQuery = false, true, false
		latch.CFrame = root.CFrame * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = latch, root
		weld.Parent = latch
		latch.Parent = root.Parent
		table.insert(made, { a0, a1, beam, latch, weld })
	end
	return made
end

local function unlatch(made)
	for _, set in made do
		set[3]:Destroy()
		set[1]:Destroy()
		set[5]:Destroy()
		local latch = set[4]
		latch.Parent = workspace
		latch.CanCollide = true
		latch.AssemblyLinearVelocity = Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
		game:GetService("Debris"):AddItem(latch, 12)
	end
end

-- ===== the run =====
local function alive(ctx)
	local hum = ctx.char and ctx.char:FindFirstChildOfClass("Humanoid")
	return active[ctx.player] == ctx and ctx.player.Parent ~= nil and ctx.char ~= nil and ctx.char.Parent ~= nil and hum ~= nil and hum.Health > 0
end

-- waits up to `seconds`, or until `cond()`; false when the intro ended under it. A dev skip ends it early.
local function hold(ctx, seconds, cond)
	local untilT = os.clock() + seconds
	while os.clock() < untilT do
		if not alive(ctx) then
			return false
		end
		if ctx.skip then
			ctx.skip = false
			return true
		end
		if cond and cond() then
			return true
		end
		task.wait(0.1)
	end
	return alive(ctx)
end

local function cleanup(ctx)
	if ctx.cell then
		ctx.cell.Folder:Destroy()
	end
	if ctx.sim then
		Simulation.Destroy(ctx.sim)
	end
	for i, p in slots do
		if p == ctx.player then
			slots[i] = nil
		end
	end
	if active[ctx.player] == ctx then
		active[ctx.player] = nil
	end
end

local function run(ctx)
	local player = ctx.player
	local o = slotOrigin(ctx.slot)
	ctx.cell = buildCell(o, ctx)
	task.spawn(function()
		ctx.sim = Simulation.Build(o + Vector3.new(0, 0, 40 + I.Sim.Size / 2), player, function(stage, data)
			notify(ctx, stage, data)
		end)
	end)
	player:LoadCharacter()
	local char = player.Character
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not (root and hum) or active[player] ~= ctx then
		cleanup(ctx)
		return
	end
	ctx.char = char
	char:SetAttribute("Faction", ctx.faction)
	Bodies.Dress(char, ctx.faction)
	char:SetAttribute("Intro", true)
	hum.MaxHealth, hum.Health = 100, 100
	hum.WalkSpeed = 0
	Soldiers.Arm(player, ctx.kit, ctx.faction, { Pending = true, Intro = true })
	Soldiers.WatchDeath(player, char)
	-- out of the tank a clone has nothing but the wrap it grew in; the battle attire waits in the barracks
	local fresh = Soldiers.State(player)
	if fresh then
		fresh.Bare = true
		Soldiers.Push(player)
	end

	-- 1. the tank: hanging in the fluid, cabled in, jolting awake
	char:PivotTo(ctx.cell.FloatCF)
	root.Anchored = true
	local made = cables(ctx, root)
	local data = PlayerData.Get(player)
	notify(ctx, "Wake", { Seconds = I.WakeSeconds, Fluid = ctx.cell.Liquid, Tank = ctx.cell.TankBase, Recruit = data and data.War.Deployments or 1, Faction = ctx.faction })
	if not hold(ctx, I.WakeSeconds) then
		return cleanup(ctx)
	end

	-- 2. the drain: the fluid sinks, the body settles onto the hatch
	notify(ctx, "Drain", { Seconds = I.DrainSeconds })
	local fluid = ctx.cell.Liquid
	local info = TweenInfo.new(I.DrainSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(fluid, info, { Size = Vector3.new(0.2, fluid.Size.Y, fluid.Size.Z), CFrame = CFrame.new(ctx.cell.TankBase + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2) }):Play()
	TweenService:Create(root, info, { CFrame = ctx.cell.StandCF }):Play()
	if not hold(ctx, I.DrainSeconds) then
		return cleanup(ctx)
	end
	root.CFrame = ctx.cell.StandCF

	-- 3. the unlatch: cables drop away, the recruit stands on its own
	unlatch(made)
	notify(ctx, "Unlatch", { Seconds = I.UnlatchSeconds })
	root.Anchored = false
	hum.WalkSpeed = Config.WarMovement.WalkSpeed
	if not hold(ctx, I.UnlatchSeconds) then
		return cleanup(ctx)
	end

	-- 4. the chute: the hatch slides away under the recruit's feet
	local hatch = ctx.cell.Hatch
	hatch.CanCollide = false
	TweenService:Create(hatch, TweenInfo.new(0.35), { CFrame = hatch.CFrame * CFrame.new(0, -0.2, 6.6), Transparency = 0.2 }):Play()
	notify(ctx, "Chute", {})
	local landY = o.Y + 6
	if not hold(ctx, I.ChuteSeconds, function()
		return root.Position.Y < landY
	end) then
		return cleanup(ctx)
	end
	if root.Position.Y >= landY or root.Position.Y < o.Y - 20 then
		char:PivotTo(ctx.cell.LandCF) -- stuck on a ledge or fell through: set down on the mat
	end

	-- 5. the barracks: the conduit's supply, laid out for this recruit
	layOut(ctx)
	local landed = Soldiers.State(player)
	if landed then
		landed.Bare = nil -- the basic battle attire: undershirt, trousers, boots, the side's armband
		Soldiers.Push(player)
	end
	notify(ctx, "Barracks", { Taken = 0, Total = ctx.total })
	hold(ctx, I.BarracksSeconds, function()
		return ctx.taken >= ctx.total
	end)
	if not alive(ctx) then
		return cleanup(ctx)
	end
	local s = Soldiers.State(player)
	for piece in (s and s.Pending) or {} do -- whatever is left is fitted anyway
		Soldiers.Give(player, piece)
		local bench = ctx.benches and ctx.benches[piece]
		if bench then
			bench:Destroy()
		end
	end
	ctx.cell.DoorLamp.Color = Color3.fromRGB(90, 255, 120)
	notify(ctx, "Equipped", {})
	if not hold(ctx, 2.5) then
		return cleanup(ctx)
	end

	-- 6. the link: white-out, then the wireframe city
	notify(ctx, "Link", { Seconds = I.LinkSeconds })
	if not hold(ctx, I.LinkSeconds) then
		return cleanup(ctx)
	end
	if not hold(ctx, 20, function()
		return ctx.sim ~= nil
	end) or not ctx.sim then
		return cleanup(ctx)
	end
	local finished = Simulation.Run(ctx.sim, function()
		return alive(ctx)
	end, function()
		if ctx.skip then
			ctx.skip = false
			return true
		end
		return false
	end)
	if not finished or not alive(ctx) then
		return cleanup(ctx)
	end

	-- 7. the drop: out of the simulation, onto the Front
	notify(ctx, "Done", { Seconds = I.DoneSeconds })
	if not hold(ctx, I.DoneSeconds) then
		return cleanup(ctx)
	end
	if data then
		data.War.IntroDone = true
	end
	seen[player.UserId] = true
	char:SetAttribute("Intro", nil)
	ctx.finished = true
	cleanup(ctx)
	Soldiers.Place(player, { Fresh = true })
	notify(ctx, "Landed", {})
end

-- ===== API used by Soldiers =====
function Intro.Needed(player, war)
	if not I.Enabled or active[player] then
		return active[player] ~= nil
	end
	if Config.Dev.Enabled and I.ReplayInDev and not seen[player.UserId] then
		return true
	end
	return not war.IntroDone
end

function Intro.Begin(player, faction, kit)
	if active[player] then
		return
	end
	local ctx = { player = player, faction = faction, kit = Intro.Curate(kit, faction) }
	ctx.slot = takeSlot(player)
	active[player] = ctx
	task.spawn(run, ctx)
	return ctx
end

function Intro.Active(player)
	return active[player]
end

function Intro.Abort(player, s)
	local ctx = active[player]
	refund(player, (ctx and ctx.kit) or (s and s.Kit))
	if ctx then
		cleanup(ctx)
	end
end

function Intro.Desync(player)
	local ctx = active[player]
	if ctx and ctx.sim then
		Simulation.Desync(ctx.sim)
	else
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
end

function Intro.Artillery(player, target)
	local ctx = active[player]
	if ctx and ctx.sim then
		Simulation.Artillery(ctx.sim, target)
	end
end

function Intro.Skip(player)
	local ctx = active[player]
	if ctx then
		ctx.skip = true
	end
end

-- Builds a cell (with its barracks laid out) and a simulation at `origin` with no player in them, breaks
-- a few blocks and a target, then removes it all. For the real-server check (tools/realserver/frontcheck.py),
-- which cannot spawn a player. Returns a summary string.
function Intro.Probe(origin)
	local fake = { UserId = 0, Parent = nil, Name = "Probe" }
	local ctx = { player = fake, faction = "Union", kit = Intro.Curate({ Attachments = {}, Magazines = 0, Grenades = 0, Medkits = 0, Sandbags = 0 }, "Union") }
	ctx.cell = buildCell(origin, ctx)
	layOut(ctx)
	local sim = Simulation.Build(origin + Vector3.new(0, 0, 40 + I.Sim.Size / 2), fake, function() end)
	local parts = #ctx.cell.Folder:GetDescendants() + #sim.Folder:GetDescendants()
	local broke = 0
	for _, b in sim.Buildings do
		for _, p in b.Blocks do
			if Simulation.DamageBlock(p, 1000) then
				broke += 1
			end
			break
		end
	end
	local clones, figures, bodied, low = 0, 0, 0, math.huge
	for _, d in ctx.cell.Folder:GetDescendants() do
		if d.Name == "Clone" and d:IsA("Model") then
			clones += 1
		end
	end
	for _, d in sim.Folder:GetChildren() do
		if d:FindFirstChildOfClass("Humanoid") then
			figures += 1
			if d:FindFirstChild("Skin") then
				bodied += 1
				low = math.min(low, d.LeftFoot.Position.Y - d.LeftFoot.Size.Y / 2 - sim.Center.Y)
			end
		end
	end
	local summary = ("cell+sim descendants %d, buildings %d, benches %d, blocks broken %d, tank clones with a body %d, figures %d (with a body %d, soles %.2f over the floor)"):format(
		parts, #sim.Buildings, ctx.total or 0, broke, clones, figures, bodied, if bodied > 0 then low else 0)
	Simulation.Destroy(sim)
	ctx.cell.Folder:Destroy()
	return summary
end

function Intro.Init()
	Soldiers.Intro = Intro
	Simulation.Init()
	Net.On("TutorialSkip", { rate = 2, burst = 3 }, function(player)
		if Config.Dev.Enabled then
			Intro.Skip(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		seen[player.UserId] = nil
	end)
end

return Intro
