-- Raids: a gate in the Blackout Zone opens a shared instance for up to MaxPlayers. Waves of
-- enemies, then a boss, then a vault of loot and a ride home. Permadeath still applies inside,
-- which is the point: raids are the high-risk, high-reward loop (Cursed Gear style).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local City = require(script.Parent.City)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local NPCs = require(script.Parent.NPCs)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local WorldPhase = require(script.Parent.WorldPhase)
local Assets = require(Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local R = Config.Raid
local Raids = {}
Raids.Completed = Instance.new("BindableEvent") -- (players)

local GROUND_TOP = 2
local active -- the one raid this server may run at a time


local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function buildArena()
	local folder = Instance.new("Folder")
	folder.Name = "RaidArena"
	local o = R.Origin
	part(folder, { Name = "Floor", Size = Vector3.new(R.Radius * 2 + 20, 4, R.Radius * 2 + 20), Position = o - Vector3.new(0, 2, 0), Color = Color3.fromRGB(28, 26, 34), Material = Enum.Material.Slate })
	local segments = 24
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2
		local pos = o + Vector3.new(math.cos(a) * (R.Radius + 8), 12, math.sin(a) * (R.Radius + 8))
		local wall = part(folder, { Name = "Wall", Size = Vector3.new(2 * math.pi * (R.Radius + 8) / segments + 1, 28, 3), CFrame = CFrame.lookAt(pos, Vector3.new(o.X, 12, o.Z)), Color = Color3.fromRGB(20, 20, 26), Material = Enum.Material.Concrete })
		ModelAssets.Shell(Assets.Compound.ArenaWall, wall, 22, folder)
	end
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local pos = o + Vector3.new(math.cos(a) * 32, 5, math.sin(a) * 32)
		local pillar = part(folder, { Name = "Pillar", Size = Vector3.new(6, 14, 6), Position = pos, Color = Color3.fromRGB(40, 36, 48), Material = Enum.Material.Metal })
		ModelAssets.Shell(Assets.Compound.ArenaPillar, pillar, 6, folder)
		local strip = part(folder, { Size = Vector3.new(6.3, 0.5, 6.3), Position = pos + Vector3.new(0, 7.2, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 30), CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 40, 40), 30, 1.5
		light.Parent = strip
	end
	folder.Parent = workspace
	return folder
end

local function announce(players, text, kind)
	for _, p in players do
		if p.Parent then
			Remotes.Announce:FireClient(p, text, kind or "Event")
		end
	end
end

local function raidHud(players, payload)
	for _, p in players do
		if p.Parent then
			Remotes.Raid:FireClient(p, payload)
		end
	end
end

local function living(players)
	local out = {}
	for _, p in players do
		local char = p.Parent and p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 and (root.Position - R.Origin).Magnitude < R.Radius + 30 then
			table.insert(out, p)
		end
	end
	return out
end

-- Drops members who died or left; they stop getting raid HUD updates and teleports.
local function prune(raid)
	local keep = living(raid.players)
	for _, p in raid.players do
		if not table.find(keep, p) and p.Parent then
			Remotes.Raid:FireClient(p, nil)
		end
	end
	raid.players = keep
end

-- Enemies still standing, read from the world rather than a counter so a destroyed or
-- fallen NPC can never leave the wave stuck.
local function enemiesAlive(raid)
	local n = 0
	for _, m in raid.folder:GetChildren() do
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			n += 1
		end
	end
	return n
end

local function spawnPoint(angleIndex, count)
	local a = (angleIndex / count) * math.pi * 2
	return R.Origin + Vector3.new(math.cos(a) * (R.Radius - 10), 4, math.sin(a) * (R.Radius - 10))
end

local function runWave(raid, index, wave, deadline)
	local members = raid.players
	local scale = 1 + R.ScalePerPlayer * math.max(0, #members - 1)
	local alive, total = 0, 0
	for _, n in wave do
		total += n
	end
	alive = total
	local boss = wave.Warden ~= nil
	raidHud(members, { Wave = index, Waves = #R.Waves, Remaining = alive, Total = total, Boss = boss })
	announce(members, if boss then "The Warden has entered the arena." else ("Wave %d / %d"):format(index, #R.Waves), if boss then "Emergence" else "Event")
	local i = 0
	local function member(player)
		return table.find(members, player) ~= nil
	end
	for typeName, n in wave do
		for _ = 1, n do
			i += 1
			NPCs.Spawn(typeName, spawnPoint(i, total), {
				Parent = raid.folder, Scale = scale, Filter = member,
				OnDied = function()
					alive -= 1
					raidHud(members, { Wave = index, Waves = #R.Waves, Remaining = alive, Total = total, Boss = boss })
				end,
			})
			task.wait(0.3)
		end
	end
	task.wait(1) -- let the last spawn settle before counting
	while raid.active and os.clock() < deadline do
		task.wait(0.5)
		prune(raid)
		members = raid.players
		if #members == 0 then
			return false
		end
		local left = enemiesAlive(raid)
		if left ~= alive then
			alive = left
			raidHud(members, { Wave = index, Waves = #R.Waves, Remaining = alive, Total = total, Boss = boss })
		end
		if alive == 0 then
			return true
		end
	end
	return false
end

local function reward(raid)
	local members = living(raid.players)
	local bundle = {}
	for _ = 1, 3 do
		for id, n in Items.Roll("Supply") do
			bundle[id] = (bundle[id] or 0) + n
		end
	end
	-- a raid always pays out at least one implant: the thing you cannot easily craft
	local implants = { "ReflexOptic", "TargetingLens", "ServoArm", "ArcGauntlet", "NeuralCore", "OverclockCore" }
	local implant = implants[math.random(#implants)]
	bundle[implant] = (bundle[implant] or 0) + 1
	local vault = Loot.Spawn(CFrame.new(R.Origin + Vector3.new(0, 3, 0)), bundle, { Label = "Raid Vault", Action = "Claim", Hold = 2, Lifetime = R.ExitDelay + 5, Size = Vector3.new(5, 5, 5), Color = Color3.fromRGB(255, 200, 60) })
	if vault then
		vault.Anchored = true
	end
	for _, p in members do
		Stats.AddXp(p, R.Xp)
		Quests.Progress(p, "raid", "Any", 1)
	end
	Raids.Completed:Fire(members)
	Remotes.Announce:FireAllClients(("%d conduit(s) cleared the Blackout raid."):format(#members), "Kill")
	announce(members, ("Raid cleared. Vault open: %ds until extraction."):format(R.ExitDelay), "Info")
	raidHud(members, { Done = true, Remaining = 0, Total = 0, Wave = #R.Waves, Waves = #R.Waves })
end

local function extract(raid)
	for _, p in raid.players do
		local char = p.Parent and p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(WorldPhase.GetSpawnCFrame(p))
			Combat.GrantIFrames(char, Config.SpawnProtection)
		end
		if p.Parent then
			Remotes.Raid:FireClient(p, nil)
		end
	end
end

local function finish(raid, success)
	raid.active = false
	if success then
		reward(raid)
		task.wait(R.ExitDelay)
	else
		announce(raid.players, "The raid has failed.", "Kill")
		task.wait(3)
	end
end

local function run(raid)
	task.wait(R.JoinWindow)
	raid.open = false
	prune(raid)
	if #raid.players > 0 then
		announce(raid.players, "Gate sealed. Survive.", "Emergence")
		local deadline = os.clock() + R.TimeLimit
		local ok, err = pcall(function()
			for index, wave in R.Waves do
				if not runWave(raid, index, wave, deadline) then
					finish(raid, false)
					return
				end
				task.wait(2)
			end
			finish(raid, true)
		end)
		if not ok then
			warn("[Raids] raid thread failed:", err)
			raid.active = false
		end
	end
	-- Unconditional epilogue: whatever happened above, everyone goes home and the slot frees up.
	extract(raid)
	raid.folder:Destroy()
	active = nil
end

local function join(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and WorldPhase.IsOpen()) then
		return
	end
	if active and not active.open then
		Remotes.Announce:FireClient(player, "A raid is already underway. Wait for the gate.", "Info")
		return
	end
	if not active then
		active = { players = {}, open = true, active = true, folder = Instance.new("Folder"), windowEndsAt = os.clock() + R.JoinWindow }
		active.folder.Name = "RaidEnemies"
		active.folder.Parent = workspace
		Remotes.Announce:FireAllClients(("%s opened the Blackout gate. %ds to join."):format(player.DisplayName, R.JoinWindow), "Event")
		task.spawn(run, active)
	end
	if table.find(active.players, player) or #active.players >= R.MaxPlayers then
		return
	end
	table.insert(active.players, player)
	local slot = #active.players
	char:PivotTo(CFrame.new(R.Origin + Vector3.new(math.cos(slot) * 8, 4, math.sin(slot) * 8)))
	Combat.GrantIFrames(char, math.max(0, active.windowEndsAt - os.clock()) + 1)
	Remotes.Raid:FireClient(player, { Wave = 0, Waves = #R.Waves, Remaining = 0, Total = 0, Joining = true })
end

local function buildGate()
	local district = City.GetDistrict("Blackout Zone")
	if not district then
		return
	end
	local c = district.Center
	local gate = Instance.new("Model")
	gate.Name = "RaidGate"
	local frame = part(gate, { Size = Vector3.new(14, 16, 2), Position = Vector3.new(c.X, GROUND_TOP + 8, c.Z - 40), Color = Color3.fromRGB(20, 20, 26), Material = Enum.Material.Metal })
	ModelAssets.Shell(Assets.Compound.RaidGate, frame, 14, gate)
	local portal = part(gate, { Size = Vector3.new(10, 12, 0.5), Position = frame.Position, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 30, 30), Transparency = 0.3, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 40, 40), 50, 3
	light.Parent = portal
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Blackout Gate", "Enter raid", 1.5
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = portal
	prompt.Triggered:Connect(join)
	gate.Parent = workspace
end

function Raids.Init()
	buildArena()
	buildGate()
end

return Raids
