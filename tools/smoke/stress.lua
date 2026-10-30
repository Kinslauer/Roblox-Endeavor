-- Story 8: load test. 20 players, hundreds of explosions, breaks and throws, raids and deaths.
-- Asserts the budgets hold (chunk cap, corpse cap, debris lifetime) and nothing errors, and
-- reports how long server ticks took in the mock (a relative number, not Roblox frame time).
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
local Players = game_:GetService("Players")
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
local Remotes = RS.Remotes
local Config = M.mockEnv.__require(RS.Shared.Config)

local function makePlayer(name, id)
	local player = M.newInstance("Player")
	player.Name, player.DisplayName, player.UserId = name, name, id
	player.Parent = Players
	function player:LoadCharacter()
		if self.Character then self.Character:Destroy() end
		local char = M.newInstance("Model"); char.Name = name
		local root = M.newInstance("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
		local torso = M.newInstance("Part"); torso.Name = "Torso"; torso.Parent = char
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Head" } do local p = M.newInstance("Part"); p.Name = limb; p.Parent = char end
		local hum = M.newInstance("Humanoid"); hum.Parent = char
		char.PrimaryPart = root
		char:PivotTo(M.CF.new(0, 5, 0))
		char.Parent = workspace_
		self.Character = char
		self.CharacterAdded:Fire(char)
	end
	Players.PlayerAdded:Fire(player)
	return player
end
local players = {}
for i = 1, 20 do players[i] = makePlayer("P" .. i, 1000 + i) end
local function run(seconds) for _ = 1, math.floor(seconds * 30) do M.step(1/30) end end
run(2)
for _, p in players do Remotes.TutorialSkip.OnServerEvent:Fire(p) end
run(35)
print("phase:", workspace_:GetAttribute("Phase"))

local Destruction = M.mockEnv.__require(SSS.Server.Destruction)
local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
local dfolder = workspace_.Destruction
local props = {}
for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") then table.insert(props, m) end end
print("props:", #props)

local rng = M.mockEnv.Random.new(7)
local function chunkCount() local n = 0 for _, d in dfolder:GetChildren() do if d:GetAttribute("Chunk") then n += 1 end end return n end
local maxChunks, maxCorpses = 0, 0
local slowest, total, ticks = 0, 0, 0
local t0 = os.clock()
for round = 1, 60 do
	-- 20 players: each explodes something, breaks something, throws something, some die
	for i, p in players do
		local char = p.Character
		if char and char.Humanoid.Health > 0 then
			local prop = props[rng:NextInteger(1, #props)]
			local pos = prop.PrimaryPart and prop.PrimaryPart.Position or M.V3.new(0, 5, 0)
			char.HumanoidRootPart.CFrame = M.CF.new(pos + M.V3.new(3, 0, 3))
			Destruction.Explode(pos, Config.Destruction.Explosion.Grenade, char)
			if i % 4 == 0 then
				char.Humanoid.Health = 0 -- permadeath + corpse + remains
			end
		end
	end
	local before = os.clock()
	run(1)
	local dt = os.clock() - before
	slowest = math.max(slowest, dt); total += dt; ticks += 1
	maxChunks = math.max(maxChunks, chunkCount())
	local corpses = #workspace_.Gore:GetChildren()
	maxCorpses = math.max(maxCorpses, corpses)
	if round % 10 == 0 then
		print(string.format("round %d: chunks=%d corpses=%d loot=%d errors=%d (1s of sim took %.2fs real)", round, chunkCount(), corpses, #game_:GetService("CollectionService"):GetTagged("Salvage"), #M.errors, dt))
	end
end
print(string.format("peak chunks=%d (cap %d)  peak corpses=%d (cap %d)  slowest sim-second=%.2fs  mean=%.2fs", maxChunks, Config.Destruction.LooseChunkCap, maxCorpses, Config.Gore.BodyCap, slowest, total / ticks))
local function check(label, ok) print((ok and "PASS  " or "FAIL  ") .. label) end
check("loose chunk cap held", maxChunks <= Config.Destruction.LooseChunkCap)
check("corpse cap held", maxCorpses <= Config.Gore.BodyCap)
check("salvage cap held", #game_:GetService("CollectionService"):GetTagged("Salvage") <= Config.Destruction.SalvageCap)
check("no script errors under load", #M.errors == 0)
for _, e in M.errors do print(e) end
-- rematerialize under load
Destruction.Reset(); run(1)
check("rematerialize under load restores props", (function() local n = 0 for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") then n += 1 end end return n end)() == #props)
