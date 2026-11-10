-- The simulation: a wireframe city a recruit links into on its first link, to learn to fight before
-- the Front. Everything in it breaks: rounds chip blocks, frags and fire missions bring buildings down,
-- a column falls when the block under it goes, a building collapses once enough of its ground layer
-- is gone. Nothing in it kills: a fatal blow desyncs the recruit back to the drill's start.
--
-- Five drills run in order, each one a place in the city: RANGE (targets in the open), BREACH (targets
-- sealed in a block shell), ASCENT (climb the steps to the beacon), CONTACT (hostile wireframes that
-- move and shoot back), FIRE MISSION (bring the tower down with artillery). Kills count whenever they
-- happen, so a drill whose targets are already broken finishes at once. The client only gets the
-- drill's name, its count and the keys it uses, as machine text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Guns = require(script.Parent.Guns)
local Soldiers = require(script.Parent.Soldiers)

local S = Config.War.Intro.Sim
local B = S.Block
local Simulation = {}

local sims = {} -- [sim] = true
local blockInfo = {} -- [part] = { sim, building, key, hp }

local CITY = Color3.fromRGB(70, 200, 255)
local EDGE = Color3.fromRGB(120, 235, 255)
local TARGET = Color3.fromRGB(235, 240, 255)
local HOSTILE = Color3.fromRGB(255, 90, 70)
local BEACON = Color3.fromRGB(120, 255, 150)

local rng = Random.new()

-- ===== building blocks =====
local function wire(p, color, thickness)
	local box = Instance.new("SelectionBox")
	box.Adornee, box.Color3, box.LineThickness = p, color, thickness or 0.05
	box.SurfaceTransparency, box.SurfaceColor3 = 1, color
	box.Parent = p
	return box
end

local function holo(parent, props, color, edge)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material, p.Color, p.Transparency = Enum.Material.ForceField, color, 0.15
	for k, v in props do
		p[k] = v
	end
	wire(p, edge or color)
	p.Parent = parent
	return p
end

local function keyOf(x, y, z)
	return x .. "," .. y .. "," .. z
end

-- A building of B-stud blocks. corner = local (x, z) of its low corner; w, d, h in blocks.
-- opts.hollow keeps only the outer shell (and a roof); opts.steps makes a staircase (column k is k high).
local function building(sim, name, corner, w, d, h, opts)
	opts = opts or {}
	local b = { Name = name, Blocks = {}, Ground = 0, GroundBroken = 0, Count = 0, Broken = 0, Collapsed = false }
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = sim.Folder
	b.Folder = folder
	local c = sim.Center
	for gx = 1, w do
		for gz = 1, d do
			local top = h
			if opts.steps then
				top = math.ceil(gz / (opts.stepDepth or 2))
			end
			for gy = 1, top do
				local shell = gx == 1 or gx == w or gz == 1 or gz == d or gy == top
				if not opts.hollow or shell then
					local pos = c + Vector3.new(corner.X + (gx - 0.5) * B, (gy - 0.5) * B, corner.Y + (gz - 0.5) * B)
					local p = holo(folder, { Name = "Block", Size = Vector3.new(B - 0.06, B - 0.06, B - 0.06), CFrame = CFrame.new(pos) }, CITY, EDGE)
					local key = keyOf(gx, gy, gz)
					b.Blocks[key] = p
					blockInfo[p] = { sim = sim, building = b, key = key, hp = S.BlockHealth, gx = gx, gy = gy, gz = gz }
					b.Count += 1
					if gy == 1 then
						b.Ground += 1
					end
				end
			end
		end
	end
	table.insert(sim.Buildings, b)
	sim.ByName[name] = b
	return b
end

local breakBlock
local function collapse(b)
	if b.Collapsed then
		return
	end
	b.Collapsed = true
	local sim
	for p, info in blockInfo do
		if info.building == b then
			sim = info.sim
			local delay = (info.gy - 1) * 0.12 + rng:NextNumber(0, 0.25)
			task.delay(delay, function()
				if p.Parent then
					breakBlock(p, true)
				end
			end)
		end
	end
	if sim then
		Remotes.World:FireClient(sim.Player, "SimCollapse", b.Folder:GetAttribute("Center") or sim.Center, b.Count)
	end
end

breakBlock = function(p, quiet)
	local info = blockInfo[p]
	if not info then
		return
	end
	blockInfo[p] = nil
	local b, sim = info.building, info.sim
	b.Blocks[info.key] = nil
	b.Broken += 1
	if info.gy == 1 then
		b.GroundBroken += 1
	end
	if sim.Player.Parent then
		Remotes.World:FireClient(sim.Player, "SimBreak", p.Position, p.Size.X, quiet == true)
	end
	p:Destroy()
	-- the column above loses its footing
	local above = b.Blocks[keyOf(info.gx, info.gy + 1, info.gz)]
	if above then
		task.delay(0.14, function()
			if above.Parent and not b.Blocks[keyOf(info.gx, info.gy, info.gz)] then
				breakBlock(above, true)
			end
		end)
	end
	if b.Ground > 0 and b.GroundBroken / b.Ground >= S.CollapseShare then
		collapse(b)
	end
end

local function damageBlock(p, amount)
	local info = blockInfo[p]
	if not info then
		return false
	end
	info.hp -= amount
	if info.hp <= 0 then
		breakBlock(p)
	end
	return true
end
Simulation.DamageBlock = damageBlock

-- ===== targets and hostiles (non-player humanoids: Soldiers.Damage and Guns.Shoot treat them as bodies) =====
local function figure(sim, cf, color, health, name)
	local model = Instance.new("Model")
	model.Name = name
	local root = holo(model, { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = cf, Transparency = 1 }, color)
	root:FindFirstChildOfClass("SelectionBox"):Destroy()
	local torso = holo(model, { Name = "UpperTorso", Size = Vector3.new(2, 2, 1), CFrame = cf }, color)
	local head = holo(model, { Name = "Head", Size = Vector3.new(1.1, 1.1, 1.1), CFrame = cf * CFrame.new(0, 1.6, 0) }, color)
	local legL = holo(model, { Name = "LeftUpperLeg", Size = Vector3.new(0.9, 2, 0.9), CFrame = cf * CFrame.new(-0.5, -2, 0) }, color)
	local legR = holo(model, { Name = "RightUpperLeg", Size = Vector3.new(0.9, 2, 0.9), CFrame = cf * CFrame.new(0.5, -2, 0) }, color)
	local armL = holo(model, { Name = "LeftUpperArm", Size = Vector3.new(0.7, 1.9, 0.7), CFrame = cf * CFrame.new(-1.35, 0, 0) }, color)
	local armR = holo(model, { Name = "RightUpperArm", Size = Vector3.new(0.7, 1.9, 0.7), CFrame = cf * CFrame.new(1.35, 0, 0) }, color)
	for _, p in { torso, head, legL, legR, armL, armR } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, p
		weld.Parent = p
	end
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health = health, health
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.HipHeight = 2
	hum.RequiresNeck = false -- these bodies are welded blocks with no neck joint; with it they would die at once
	hum.Parent = model
	model.PrimaryPart = root
	model.Parent = sim.Folder
	return model, hum, root
end

local function onFigureDown(sim, model, drill)
	if sim.Player.Parent then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				Remotes.World:FireClient(sim.Player, "SimBreak", p.Position, math.max(p.Size.X, p.Size.Y), true)
			end
		end
	end
	sim.Kills[drill] = (sim.Kills[drill] or 0) + 1
	model:Destroy()
end

local function target(sim, drill, localPos, faceLocal)
	local c = sim.Center
	local at = c + localPos + Vector3.new(0, 3, 0)
	local face = c + (faceLocal or Vector3.new(localPos.X, 0, localPos.Z - 50)) + Vector3.new(0, 3, 0)
	local model, hum = figure(sim, CFrame.lookAt(at, Vector3.new(face.X, at.Y, face.Z)), TARGET, S.TargetHealth, "SimTarget")
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	sim.Need[drill] = (sim.Need[drill] or 0) + 1
	hum.Died:Once(function()
		onFigureDown(sim, model, drill)
	end)
	return model
end

-- ===== the city =====
local DRILLS = {
	{ Name = "RANGE", Keys = "LMB . RMB . R . B" },
	{ Name = "BREACH", Keys = "G" },
	{ Name = "ASCENT", Keys = "SHIFT . SPACE" },
	{ Name = "CONTACT", Keys = "H . Q / E" },
	{ Name = "FIRE MISSION", Keys = "K" },
}
Simulation.Drills = DRILLS

function Simulation.Build(center, player, notify)
	local sim = { Center = center, Player = player, Notify = notify, Buildings = {}, ByName = {}, Kills = {}, Need = {}, Hostiles = {}, ArtilleryReady = 0, Drill = 1 }
	local folder = Instance.new("Folder")
	folder.Name = "Simulation_" .. player.UserId
	sim.Folder = folder
	local half = S.Size / 2
	local c = center
	-- the floor: a dark slab with a lit grid, and walls of light at the edge
	local floor = Instance.new("Part")
	floor.Name, floor.Anchored, floor.Size = "SimFloor", true, Vector3.new(S.Size, 2, S.Size)
	floor.CFrame = CFrame.new(c - Vector3.new(0, 1, 0))
	floor.Color, floor.Material = Color3.fromRGB(8, 14, 24), Enum.Material.SmoothPlastic
	floor.Parent = folder
	for k = -half, half, 20 do
		for _, along in { "X", "Z" } do
			local line = Instance.new("Part")
			line.Name, line.Anchored, line.CanCollide, line.CanQuery = "Grid", true, false, false
			line.Material, line.Color = Enum.Material.Neon, Color3.fromRGB(30, 110, 150)
			line.Size = if along == "X" then Vector3.new(S.Size, 0.05, 0.12) else Vector3.new(0.12, 0.05, S.Size)
			line.CFrame = CFrame.new(c + (if along == "X" then Vector3.new(0, 0.03, k) else Vector3.new(k, 0.03, 0)))
			line.Parent = folder
		end
	end
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local wall = Instance.new("Part")
		wall.Name, wall.Anchored = "SimEdge", true
		wall.Size = if side.X ~= 0 then Vector3.new(1, 90, S.Size) else Vector3.new(S.Size, 90, 1)
		wall.CFrame = CFrame.new(c + side * (half + 0.5) + Vector3.new(0, 45, 0))
		wall.Material, wall.Color, wall.Transparency = Enum.Material.ForceField, CITY, 0.6
		wall.Parent = folder
	end
	local roof = Instance.new("Part")
	roof.Name, roof.Anchored, roof.Transparency, roof.Size = "SimLid", true, 1, Vector3.new(S.Size, 1, S.Size)
	roof.CFrame = CFrame.new(c + Vector3.new(0, 90, 0))
	roof.Parent = folder

	-- checkpoints (local x, z) and facing for each drill
	sim.Checkpoints = {
		{ Vector3.new(0, 0, -135), Vector3.new(0, 0, -80) },
		{ Vector3.new(-48, 0, -95), Vector3.new(-48, 0, -48) },
		{ Vector3.new(42, 0, -95), Vector3.new(42, 0, -60) },
		{ Vector3.new(0, 0, -15), Vector3.new(0, 0, 60) },
		{ Vector3.new(30, 0, 60), Vector3.new(69, 0, 119) },
	}

	-- 1. RANGE: six targets in the open, near to far
	for i, pos in { Vector3.new(-14, 0, -105), Vector3.new(10, 0, -100), Vector3.new(-4, 0, -88), Vector3.new(20, 0, -80), Vector3.new(-24, 0, -72), Vector3.new(4, 0, -62) } do
		target(sim, 1, pos, Vector3.new(0, 0, -135))
	end
	-- 2. BREACH: a sealed shell with three targets inside
	building(sim, "Bunker", Vector2.new(-60, -60), 4, 4, 2, { hollow = true })
	for _, pos in { Vector3.new(-51, 0, -51), Vector3.new(-45, 0, -45), Vector3.new(-45, 0, -51) } do
		target(sim, 2, pos, Vector3.new(-48, 0, -95))
	end
	-- 3. ASCENT: steps up to a beacon four blocks high
	building(sim, "Steps", Vector2.new(36, -76), 2, 8, 4, { steps = true, stepDepth = 2 })
	sim.Beacon = c + Vector3.new(42, 4 * B, -76 + 7 * B)
	local beacon = Instance.new("Part")
	beacon.Name, beacon.Anchored, beacon.CanCollide, beacon.CanQuery = "Beacon", true, false, false
	beacon.Shape, beacon.Size = Enum.PartType.Cylinder, Vector3.new(40, 2.4, 2.4)
	beacon.CFrame = CFrame.new(sim.Beacon + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Material, beacon.Color, beacon.Transparency = Enum.Material.Neon, BEACON, 0.55
	beacon.Parent = folder
	sim.BeaconPart = beacon
	-- 4. CONTACT: a few streets of solid blocks to fight through
	for i, spec in {
		{ -40, 10, 3, 2, 3 }, { -10, 25, 2, 2, 2 }, { 25, 15, 3, 3, 4 }, { -36, 52, 2, 3, 5 }, { 8, 58, 3, 2, 2 },
		{ 42, 48, 2, 2, 3 }, { -52, 92, 3, 3, 4 }, { -6, 96, 2, 2, 3 }, { 30, 92, 2, 3, 2 }, { -20, 74, 3, 1, 1 }, { 18, 34, 4, 1, 1 },
	} do
		building(sim, "City" .. i, Vector2.new(spec[1], spec[2]), spec[3], spec[4], spec[5])
	end
	-- 5. FIRE MISSION: the tower
	local tower = building(sim, "Tower", Vector2.new(60, 110), 3, 3, 8)
	tower.Folder:SetAttribute("Center", c + Vector3.new(69, 12, 119))
	sim.Tower = tower
	folder.Parent = workspace
	sims[sim] = true
	return sim
end

function Simulation.Contains(sim, position)
	local d = position - sim.Center
	local half = S.Size / 2 + 4
	return math.abs(d.X) <= half and math.abs(d.Z) <= half and d.Y > -30 and d.Y < 200
end

local function simAt(position)
	for sim in sims do
		if Simulation.Contains(sim, position) then
			return sim
		end
	end
	return nil
end

local function placeAt(sim, index)
	local char = sim.Player.Character
	local cp = sim.Checkpoints[index]
	if char and cp then
		local at = sim.Center + cp[1] + Vector3.new(0, 3.5, 0)
		local face = sim.Center + cp[2] + Vector3.new(0, 3.5, 0)
		char:PivotTo(CFrame.lookAt(at, face))
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

function Simulation.Desync(sim)
	local char = sim.Player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
	end
	placeAt(sim, sim.Drill)
	sim.Notify("Desync", { Drill = sim.Drill })
end

-- ===== hostiles =====
local function lineOfSight(fromPos, toPos, ignore)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(fromPos, toPos - fromPos, ray)
	return hit
end

local function spawnHostiles(sim)
	local c = sim.Center
	for i = 1, S.Hostiles do
		local at = c + Vector3.new(-50 + (i - 1) * 25 + rng:NextNumber(-4, 4), 4, 122 + rng:NextNumber(-6, 6))
		local model, hum, root = figure(sim, CFrame.lookAt(at, at - Vector3.new(0, 0, 1)), HOSTILE, S.HostileHealth, "SimHostile")
		hum.WalkSpeed = 11
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p ~= root then
				p.CanCollide, p.Massless = false, true -- the root carries the body; limbs only take hits
			end
		end
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local h = { Model = model, Hum = hum, Root = root, NextFire = os.clock() + 1.5 + rng:NextNumber(0, 1.5), NextMove = 0 }
		table.insert(sim.Hostiles, h)
		sim.Need[4] = (sim.Need[4] or 0) + 1
		hum.Died:Once(function()
			h.Dead = true
			onFigureDown(sim, model, 4)
		end)
	end
end

local function hostileThink(sim, h)
	local char = sim.Player.Character
	local proot = char and char:FindFirstChild("HumanoidRootPart")
	local phum = char and char:FindFirstChildOfClass("Humanoid")
	if h.Dead or not h.Root.Parent or not (proot and phum) then
		return
	end
	local now = os.clock()
	local here = h.Root.Position
	local toPlayer = proot.Position - here
	local dist = toPlayer.Magnitude
	if now >= h.NextMove then
		-- close to a fighting distance, sideways as often as forward
		h.NextMove = now + rng:NextNumber(2.5, 4.5)
		local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
		local forward = if flat.Magnitude > 0 then flat.Unit else Vector3.new(0, 0, 1)
		local side = forward:Cross(Vector3.yAxis)
		local advance = if dist > 45 then rng:NextNumber(10, 18) else rng:NextNumber(-6, 4)
		local spot = here + forward * advance + side * rng:NextNumber(-14, 14)
		h.Hum:MoveTo(Vector3.new(spot.X, sim.Center.Y + 3, spot.Z))
	end
	if now >= h.NextFire and dist < 160 then
		h.NextFire = now + S.HostileFireSeconds * rng:NextNumber(0.8, 1.3)
		local eye = here + Vector3.new(0, 1.6, 0)
		local aim = proot.Position + Vector3.new(0, 1.2, 0)
		local ignore = {}
		for _, other in sim.Hostiles do
			table.insert(ignore, other.Model)
		end
		local blocked = lineOfSight(eye, aim, ignore)
		if blocked and not blocked.Instance:IsDescendantOf(char) then
			return -- no shot through cover; the wall takes it
		end
		local chance = S.HostileAccuracy * math.clamp(20 / math.max(dist, 1), 0.3, 1.2)
		local v = proot.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > Config.WarMovement.WalkSpeed + 2 then
			chance *= 0.6 -- a sprinting recruit is harder to hit
		end
		local dir = (aim - eye).Unit
		Remotes.Weapon:FireClient(sim.Player, "Shot", h.Model, eye, dir, 0.7)
		if rng:NextNumber() < chance then
			local roll = rng:NextNumber()
			local zone = if roll < 0.1 then "Head" elseif roll < 0.75 then "Torso" else "Limb"
			Soldiers.Damage(char, S.HostileDamage * (if zone == "Head" then 2 elseif zone == "Limb" then 0.6 else 1), nil, zone, 0.2, "Bullet")
		else
			local miss = aim + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1.5, 2), rng:NextNumber(-3, 3))
			Remotes.Weapon:FireClient(sim.Player, "Impact", miss, Vector3.yAxis, false)
		end
	end
end

-- ===== artillery inside the simulation: its own guns, short cooldown, on the point you look at =====
function Simulation.Artillery(sim, targetPos)
	if not Simulation.Contains(sim, targetPos) then
		return
	end
	local A = S.Artillery
	if os.clock() < sim.ArtilleryReady then
		return
	end
	sim.ArtilleryReady = os.clock() + A.Cooldown
	Remotes.World:FireClient(sim.Player, "ArtilleryWarning", targetPos, A.Delay)
	task.delay(A.Delay, function()
		for i = 1, A.Shells do
			task.delay(i * 0.45, function()
				if sims[sim] then
					local at = targetPos + Vector3.new(rng:NextNumber(-A.Spread, A.Spread), rng:NextNumber(0, 6), rng:NextNumber(-A.Spread, A.Spread))
					Soldiers.Explode(at, A.Radius, A.Damage, sim.Player)
				end
			end)
		end
	end)
end

-- ===== the drills =====
local function progress(sim)
	local i = sim.Drill
	local d = DRILLS[i]
	local done, need
	if i == 3 then
		done, need = if sim.Climbed then 1 else 0, 1
	elseif i == 5 then
		done, need = if sim.Tower.Collapsed then 1 else 0, 1
	else
		done, need = math.min(sim.Kills[i] or 0, sim.Need[i] or 0), sim.Need[i] or 0
	end
	return done, need, d
end

-- Runs the drills in order. alive() false ends it (returns false); skip() true finishes the current drill.
function Simulation.Run(sim, alive, skip)
	local player = sim.Player
	placeAt(sim, 1)
	sim.Notify("Sim", { Drills = #DRILLS })
	local lastShown, lastSupply = nil, os.clock()
	while sim.Drill <= #DRILLS do
		if not alive() or not sims[sim] then
			return false
		end
		local i = sim.Drill
		if i == 4 and not sim.HostilesUp then
			sim.HostilesUp = true
			spawnHostiles(sim)
		end
		if i == 3 and not sim.Climbed then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - sim.Beacon).Magnitude < 9 and root.Position.Y > sim.Beacon.Y then
				sim.Climbed = true
				if sim.BeaconPart then
					sim.BeaconPart:Destroy()
				end
			end
		end
		if i == 4 then
			for _, h in sim.Hostiles do
				hostileThink(sim, h)
			end
		end
		local done, need, d = progress(sim)
		local shown = i .. ":" .. done .. "/" .. need
		if shown ~= lastShown then
			lastShown = shown
			sim.Notify("Drill", { Index = i, Total = #DRILLS, Name = d.Name, Keys = d.Keys, Done = done, Need = need })
		end
		if skip() then
			done = need
			if i == 3 then
				sim.Climbed = true
			elseif i == 5 then
				collapse(sim.Tower)
			end
		end
		if done >= need and need > 0 then
			sim.Notify("DrillDone", { Index = i, Name = d.Name })
			sim.Drill += 1
			lastShown = nil
			if sim.Drill <= #DRILLS then
				task.wait(1.5)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local cp = sim.Checkpoints[sim.Drill]
				-- only carried to the next drill when far from it; a recruit already there keeps its footing
				if root and cp and (root.Position - (sim.Center + cp[1])).Magnitude > 70 then
					placeAt(sim, sim.Drill)
				end
			end
		end
		-- the simulation keeps a recruit stocked: frags and a dressing come back
		if os.clock() - lastSupply > 6 then
			lastSupply = os.clock()
			local s = Soldiers.State(player)
			if s and (s.Grenades < 2 or s.Medkits < 1) then
				s.Grenades, s.Medkits = math.max(s.Grenades, 2), math.max(s.Medkits, 1)
				Soldiers.Push(player)
			end
		end
		task.wait(0.25)
	end
	sim.Notify("SimDone", {})
	return true
end

function Simulation.Destroy(sim)
	sims[sim] = nil
	for p, info in blockInfo do
		if info.sim == sim then
			blockInfo[p] = nil
		end
	end
	sim.Folder:Destroy()
end

function Simulation.Init()
	-- rounds chip blocks
	Guns.OnSurface = function(part, position, damage, shooter)
		if blockInfo[part] then
			damageBlock(part, damage * S.BulletBlockDamage)
		end
	end
	-- frags and shells: blocks, targets and hostiles inside the simulation; the battlefield is left alone
	Soldiers.ExplodeHook = function(origin, radius, damage, attacker)
		local sim = simAt(origin)
		if not sim then
			return false
		end
		for p, info in table.clone(blockInfo) do
			if info.sim == sim and p.Parent then
				local dist = math.max(0, (p.Position - origin).Magnitude - B * 0.5)
				if dist <= radius then
					damageBlock(p, damage * (1 - (dist / radius) ^ 1.5) * 1.3)
				end
			end
		end
		for _, model in sim.Folder:GetChildren() do
			local hum = model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
			local root = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
			if hum and root and hum.Health > 0 then
				local dist = (root.Position - origin).Magnitude
				if dist <= radius then
					Soldiers.Damage(model, damage * (1 - (dist / radius) ^ 1.5), attacker, "Torso", 0.3, "Explosive")
				end
			end
		end
		return true
	end
end

return Simulation
