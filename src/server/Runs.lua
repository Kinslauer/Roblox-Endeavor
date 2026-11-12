-- Party runs in the shelters (round 6 of docs/Reference-Picks-Plan.md; Andy asked for five original tasks; the plan's
-- "Five party-run tasks"). One run at a time in Barrens Hall 2 (server/Barrens builds the level). The WORK ORDERS board
-- at the shaft foot hands out a task to whoever takes it and every party member standing with them; the run ends
-- when the task is done (each member gets a share of the stores, xp and credits through Builds.Earn: carried until
-- home), when the time runs out, or when nobody on it is left alive below.
--   Drain    sludge rises in the pipe gallery; turn its three valves in the order their gauges show; an overseer
--            comes down at each valve
--   Carry    one runner carries a STACK HARDWARE crate (slow, hands full) from the hall to the cage at the shaft foot
--   Fuses    cut the four fuses round the office's OUTPUT counter within one window; each cut wakes the room
--   Copy     the console copies the HANDS roll only while someone stands at it in the light and no guard is up;
--            noise anywhere below pauses it
--   Cage     take three cells from the hall, load them at the cage, then hold the cage while it climbs (waves come)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local R = Config.World.Runs
local Runs = {}
Runs.Order = { "Drain", "Carry", "Fuses", "Copy", "Cage" }
Runs.Names = { Drain = "DRAIN THE GALLERY", Carry = "CARRY THE CRATE", Fuses = "BLIND THE COUNTER", Copy = "COPY THE ROLL", Cage = "HOLD THE CAGE" }
Runs.Finished = Instance.new("BindableEvent") -- (task, ok, members)

local run -- the one in progress
local lastTask, readyAt = nil, 0
local board

local function lazy(name)
	return require(script.Parent[name])
end

local function level()
	local ok, L = pcall(function()
		return lazy("Barrens").Level()
	end)
	return ok and L or nil
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(p, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.PixelsPerStud, gui.LightInfluence = face, 72, 1
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, true
	l.Text, l.Font, l.TextColor3 = text, Enum.Font.Michroma, color or Color3.fromRGB(220, 200, 150)
	l.Parent = gui
	gui.Parent = p
	return l
end

local function prompt(p, action, hold)
	local pr = Instance.new("ProximityPrompt")
	pr.ObjectText, pr.ActionText, pr.HoldDuration = "", action, hold or 0.5
	pr.MaxActivationDistance, pr.RequiresLineOfSight, pr.KeyboardKeyCode = 7, false, Enum.KeyCode.X
	pr.Parent = p
	return pr
end

local function say(members, text, kind)
	for _, m in members do
		Remotes.Announce:FireClient(m, text, kind or "Emergence")
	end
end

local function rootOf(player)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and c:FindFirstChild("HumanoidRootPart"), c
end

local function alive(r)
	local n = 0
	for _, m in r.Members do
		if m.Parent and rootOf(m) and lazy("Barrens").Inside(m) then
			n += 1
		end
	end
	return n
end

-- an overseer sent at the runners, already on alert
local function sendGuard(r, at)
	local L = level()
	local Stealth = lazy("Stealth")
	local ok, model = pcall(Stealth.SpawnGuard, at, { Level = L.Model, Loot = "Overseer" })
	if ok and model then
		table.insert(r.Guards, model)
		local target = r.Members[1]
		for _, m in r.Members do
			if rootOf(m) then
				target = m
				break
			end
		end
		if target then
			Stealth.Alarm(model, target)
		end
		return model
	end
	return nil
end

-- ===== the tasks =====
local TASKS = {}

TASKS.Drain = {
	Start = function(r, L, at)
		local order = { 1, 2, 3 }
		for i = 3, 2, -1 do
			local j = r.Rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		r.Order, r.Step, r.Level = order, 0, 0
		r.Sludge = part(r.Folder, { Name = "RunSludge", CFrame = CFrame.new(at(51, -0.5, 0)), Size = Vector3.new(78, 1, 11.6), Color = Color3.fromRGB(90, 110, 40),
			Material = Enum.Material.Mud, Transparency = 0.15, CanCollide = false })
		for i, x in { 25, 50, 75 } do
			local valve = part(r.Folder, { Name = "RunValve", CFrame = CFrame.new(at(x, 3.2, -5.4)) * CFrame.Angles(math.pi / 2, 0, 0), Size = Vector3.new(1.6, 0.4, 1.6),
				Color = Color3.fromRGB(150, 40, 30), Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder })
			local gauge = part(r.Folder, { Name = "RunGauge", CFrame = CFrame.new(at(x, 5.6, -5.8)), Size = Vector3.new(1.6, 1.6, 0.2), Color = Color3.fromRGB(230, 226, 210), Material = Enum.Material.SmoothPlastic })
			label(gauge, Enum.NormalId.Back, tostring(table.find(order, i)), Color3.fromRGB(30, 20, 20))
			local pr = prompt(valve, "Turn", 1.2)
			pr.Triggered:Connect(function(player)
				if r ~= run or not table.find(r.Members, player) then
					return
				end
				if order[r.Step + 1] == i then
					r.Step += 1
					valve.Color = Color3.fromRGB(60, 140, 60)
					pr.Enabled = false
					sendGuard(r, at(88, 3, 0))
				else
					r.Level = math.min(R.Drain.Top, r.Level + 0.6) -- the wrong one: a surge
				end
			end)
		end
	end,
	Step = function(r, dt, L, at)
		if r.Step >= 3 then
			return "done"
		end
		r.Level = math.min(R.Drain.Top, r.Level + R.Drain.Rise * dt * 10)
		r.Sludge.Size = Vector3.new(78, math.max(0.2, r.Level), 11.6)
		r.Sludge.CFrame = CFrame.new(at(51, r.Level / 2, 0))
		for _, m in r.Members do
			local root, c = rootOf(m)
			if root then
				local rel = root.Position - L.Origin
				if rel.X > 12 and rel.X < 90 and math.abs(rel.Z) < 6 and rel.Y - 2.5 < r.Level then
					c:FindFirstChildOfClass("Humanoid"):TakeDamage(R.Drain.Damage * dt)
				end
			end
		end
		return nil
	end,
}

TASKS.Carry = {
	Start = function(r, L, at)
		local crate = part(r.Folder, { Name = "RunCrate", CFrame = CFrame.new(at(180, 1.5, -40)), Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(60, 66, 60), Material = Enum.Material.Metal, CanCollide = false })
		label(crate, Enum.NormalId.Front, "STACK HARDWARE\nLINE 9 . 41/40", Color3.fromRGB(235, 225, 200))
		r.Crate, r.Goal = crate, at(0, 1.5, 6)
		local pr = prompt(crate, "Lift", 1)
		r.CratePrompt = pr
		pr.Triggered:Connect(function(player)
			if r ~= run or not table.find(r.Members, player) or r.Holder then
				return
			end
			r.Holder = player
			pr.Enabled = false
			local c = player.Character
			c:SetAttribute("RunCrate", true)
			pcall(function()
				lazy("Stats").Apply(player, false)
			end)
		end)
		part(r.Folder, { Name = "RunCage", CFrame = CFrame.new(at(0, 0.15, 6)), Size = Vector3.new(6, 0.3, 6), Color = Color3.fromRGB(216, 166, 26), Material = Enum.Material.Neon, CanCollide = false })
	end,
	Step = function(r, dt, L, at)
		local holder = r.Holder
		if holder then
			local root, c = rootOf(holder)
			if not root then
				-- the runner fell: the crate lies where they did
				if c then
					c:SetAttribute("RunCrate", nil)
				end
				r.Holder = nil
				r.CratePrompt.Enabled = true
				return nil
			end
			r.Crate.CFrame = root.CFrame * CFrame.new(0, 0.6, -2.2)
			r.NoiseAt = (r.NoiseAt or 0) + dt
			if r.NoiseAt > 6 then
				r.NoiseAt = 0
				pcall(lazy("Stealth").Noise, root.Position, 30, "Clatter", holder)
			end
			if (Vector3.new(root.Position.X - r.Goal.X, 0, root.Position.Z - r.Goal.Z)).Magnitude < 5 then
				c:SetAttribute("RunCrate", nil)
				pcall(function()
					lazy("Stats").Apply(holder, false)
				end)
				return "done"
			end
		end
		return nil
	end,
	Stop = function(r)
		if r.Holder and r.Holder.Character then
			r.Holder.Character:SetAttribute("RunCrate", nil)
		end
	end,
}

TASKS.Fuses = {
	Start = function(r, L, at)
		r.Cut, r.Fuses = 0, {}
		for _, spot in { { 194.2, -12 }, { 194.2, 12 }, { 219.8, -12 }, { 219.8, 12 } } do
			local fuse = part(r.Folder, { Name = "RunFuse", CFrame = CFrame.new(at(spot[1], 4, spot[2])), Size = Vector3.new(0.6, 1.6, 1.2), Color = Color3.fromRGB(216, 166, 26), Material = Enum.Material.Neon })
			local pr = prompt(fuse, "Cut", 0.8)
			table.insert(r.Fuses, { Part = fuse, Prompt = pr })
			pr.Triggered:Connect(function(player)
				if r ~= run or not table.find(r.Members, player) then
					return
				end
				if r.Cut == 0 then
					r.WindowEnds = os.clock() + R.Fuses.Window
				end
				r.Cut += 1
				pr.Enabled = false
				fuse.Color, fuse.Material = Color3.fromRGB(30, 30, 30), Enum.Material.Metal
				pcall(lazy("Stealth").Noise, fuse.Position, 60, "Glass", player) -- each cut wakes the room
			end)
		end
	end,
	Step = function(r)
		if r.Cut >= #r.Fuses then
			return "done"
		end
		if r.Cut > 0 and os.clock() > r.WindowEnds then
			-- too slow: the ring comes back on
			r.Cut = 0
			for _, f in r.Fuses do
				f.Prompt.Enabled = true
				f.Part.Color, f.Part.Material = Color3.fromRGB(216, 166, 26), Enum.Material.Neon
			end
			say(r.Members, "> OUTPUT . RESTORED", "Warning")
		end
		return nil
	end,
}

TASKS.Copy = {
	Start = function(r, L, at)
		r.Copied, r.PausedUntil, r.Console = 0, 0, at(209.8, 3, 0)
	end,
	Step = function(r, dt, L)
		if r.Copied >= R.Copy.Seconds then
			return "done"
		end
		if os.clock() < r.PausedUntil then
			return nil
		end
		for _, g in lazy("Stealth").Guards(L.Model) do
			local state = lazy("Stealth").StateOf(g)
			if state == "Alert" or state == "Search" or state == "Spotted" then
				return nil -- a guard is up: the copy waits
			end
		end
		for _, m in r.Members do
			local root, c = rootOf(m)
			if root and (root.Position - r.Console).Magnitude <= R.Copy.Reach and (c:GetAttribute("Exposure") or 0) >= R.Copy.Light then
				r.Copied += dt
				break
			end
		end
		return nil
	end,
	Heard = function(r)
		r.PausedUntil = os.clock() + 4
	end,
}

TASKS.Cage = {
	Start = function(r, L, at)
		r.Loaded, r.Held, r.WaveAt = 0, 0, 0
		r.Cage = part(r.Folder, { Name = "RunCage", CFrame = CFrame.new(at(0, 0.15, 6)), Size = Vector3.new(6, 0.3, 6), Color = Color3.fromRGB(216, 166, 26), Material = Enum.Material.Neon, CanCollide = false })
		local pr = prompt(r.Cage, "Load", 0.6)
		pr.Triggered:Connect(function(player)
			if r ~= run or not table.find(r.Members, player) then
				return
			end
			local Inventory = lazy("Inventory")
			local n = math.min(Inventory.Count(player, "CageCell"), R.Cage.Cells - r.Loaded)
			if n > 0 then
				Inventory.Remove(player, "CageCell", n)
				r.Loaded += n
			end
		end)
		-- the cells: at three stations of the hall
		for i, z in { -30, 0, 30 } do
			local cell = part(r.Folder, { Name = "RunCell", CFrame = CFrame.new(at(120 + i * 18, 1, z + 4)), Size = Vector3.new(1, 1.4, 1), Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon })
			local cp = prompt(cell, "Take", 0.4)
			cp.Triggered:Connect(function(player)
				if r ~= run or not table.find(r.Members, player) or not cell.Parent then
					return
				end
				lazy("Inventory").Add(player, "CageCell", 1)
				cell:Destroy()
			end)
		end
	end,
	Step = function(r, dt, L, at)
		if r.Loaded < R.Cage.Cells then
			return nil
		end
		if r.Held >= R.Cage.Hold then
			return "done"
		end
		local inside = false
		for _, m in r.Members do
			local root = rootOf(m)
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(r.Cage.Position.X, 0, r.Cage.Position.Z)).Magnitude <= R.Cage.Reach then
				inside = true
			end
		end
		if inside then
			r.Held += dt -- the cage only climbs while someone holds it
		end
		r.WaveAt -= dt
		if r.WaveAt <= 0 then
			r.WaveAt = R.Cage.Wave
			sendGuard(r, at(40, 3, 0))
			sendGuard(r, at(70, 3, 0))
		end
		return nil
	end,
}

-- ===== the run =====
local function finish(r, ok)
	if run ~= r then
		return
	end
	run = nil
	readyAt = os.clock() + R.Cooldown
	local def = TASKS[r.Task]
	if def.Stop then
		pcall(def.Stop, r)
	end
	for _, g in r.Guards do
		if g.Parent then
			g:Destroy()
		end
	end
	r.Folder:Destroy()
	if ok then
		say(r.Members, "> ORDER . CLOSED", "Reward")
		for _, m in r.Members do
			if m.Parent then
				local bundle = Items.Roll("Barrens")
				local Inventory = lazy("Inventory")
				for id, n in bundle do
					Inventory.Add(m, id, n)
				end
				pcall(function()
					lazy("Builds").Earn(m, R.Xp, R.Credits)
				end)
			end
		end
	else
		say(r.Members, "> ORDER . VOID", "Warning")
	end
	for _, m in r.Members do
		if m.Parent then
			Remotes.World:FireClient(m, "Run", nil)
		end
	end
	Runs.Finished:Fire(r.Task, ok, r.Members)
end

function Runs.Start(player, taskName)
	local L = level()
	if not L or run or os.clock() < readyAt then
		return nil
	end
	local root = rootOf(player)
	if not root then
		return nil
	end
	local members = {}
	local okP, party = pcall(function()
		return lazy("Party").Members(player)
	end)
	for _, m in (okP and party) or { player } do
		local mr = rootOf(m)
		if mr and (mr.Position - root.Position).Magnitude <= R.JoinReach then
			table.insert(members, m)
		end
	end
	if #members == 0 then
		members = { player }
	end
	local rng = Random.new()
	if not taskName then
		local options = {}
		for _, t in Runs.Order do
			if t ~= lastTask then
				table.insert(options, t)
			end
		end
		taskName = options[rng:NextInteger(1, #options)]
	end
	if not TASKS[taskName] then
		return nil
	end
	lastTask = taskName
	local folder = Instance.new("Folder")
	folder.Name = "Run"
	folder.Parent = L.Model
	local r = { Task = taskName, Members = members, EndsAt = os.clock() + R.Seconds, Guards = {}, Folder = folder, Rng = rng }
	run = r
	local function at(x, y, z)
		return L.Origin + Vector3.new(x, y, z)
	end
	TASKS[taskName].Start(r, L, at)
	say(members, "> WORK ORDER . " .. Runs.Names[taskName])
	for _, m in members do
		Remotes.World:FireClient(m, "Run", taskName, R.Seconds)
	end
	task.spawn(function()
		local last = os.clock()
		while run == r do
			task.wait(0.2)
			local now = os.clock()
			local dt = now - last
			last = now
			if run ~= r then
				break
			end
			if now > r.EndsAt or alive(r) == 0 then
				finish(r, false)
				break
			end
			local okS, result = pcall(TASKS[taskName].Step, r, dt, L, at)
			if not okS then
				warn("[Runs] " .. tostring(result))
				finish(r, false)
				break
			end
			if result == "done" then
				finish(r, true)
				break
			end
		end
	end)
	return r
end

function Runs.Current()
	return run
end

-- Tests and tools: close the current run now.
function Runs.Stop(ok)
	if run then
		finish(run, ok == true)
	end
end

function Runs.Heard(position, kind)
	if run and TASKS[run.Task].Heard and kind ~= "Step" then
		local L = level()
		if L and position.Y < L.Origin.Y + 40 then
			TASKS[run.Task].Heard(run)
		end
	end
end

function Runs.Init()
	local L = level()
	if not L then
		return
	end
	board = part(L.Model, { Name = "WorkOrders", CFrame = CFrame.lookAt(L.Origin + Vector3.new(6, 4, -9.6), L.Origin + Vector3.new(6, 4, 0)), Size = Vector3.new(4, 3, 0.3),
		Color = Color3.fromRGB(26, 28, 30), Material = Enum.Material.Metal })
	label(board, Enum.NormalId.Front, "S4 . WORK ORDERS", Color3.fromRGB(216, 166, 26))
	local pr = prompt(board, "Take order", 1)
	pr.Triggered:Connect(function(player)
		if not Runs.Start(player) then
			Remotes.Announce:FireClient(player, "> NO ORDERS", "Info")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if run then
			local i = table.find(run.Members, player)
			if i then
				table.remove(run.Members, i)
			end
		end
	end)
end

return Runs
