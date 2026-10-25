local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
local Players = game_:GetService("Players")
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
local Remotes = RS.Remotes

local function makePlayer(name, id)
	local player = M.newInstance("Player")
	player.Name, player.DisplayName, player.UserId = name, name, id
	player.Parent = Players
	function player:LoadCharacter()
		if self.Character then self.Character:Destroy() end
		local char = M.newInstance("Model"); char.Name = name
		local root = M.newInstance("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
		local head = M.newInstance("Part"); head.Name = "Head"; head.Parent = char
		local hum = M.newInstance("Humanoid"); hum.Parent = char
		char.PrimaryPart = root
		char:PivotTo(M.CF.new(0, 5, 0))
		char.Parent = workspace_
		self.Character = char
		self.CharacterAdded:Fire(char)
	end
	return player
end
local player = makePlayer("Tester", 123)
Players.PlayerAdded:Fire(player)
local function as(p) M.setPlayer(p) end
as(player)
-- The character creator blocks the first spawn until the look is confirmed.
local function confirmLook(p)
	as(p)
	Remotes.SetAppearance:FireServer({ BodyType = 2, SkinTone = 3, Hair = 4 }, true)
end
M.task.delay(0.5, function() confirmLook(player) end)

local function run(seconds, cond)
	local frames = math.floor(seconds * 30)
	for _ = 1, frames do
		M.step(1/30)
		if cond and cond() then return true end
	end
	return cond == nil
end
local function check(label, ok) print((ok and "PASS  " or "FAIL  ") .. label) end
local function char() return player.Character end
local function root() return char().HumanoidRootPart end
local function data() return nil end

run(1)
local plot = workspace_:FindFirstChild("Prologue_1")
local origin = plot:FindFirstChild("Console").Position - M.V3.new(20, 3.5, -20)
local function lastTutorial() local last for _, e in M.FireLog do if e[1] == "Tutorial" then last = e end end return last end
local function step() local e = lastTutorial(); return e and e[3], e and e[5] end

check("tutorial starts at step 1", step() == 1)

-- 1 move
root().CFrame = M.CF.new(plot.Console.Position + M.V3.new(2, 0, 0)); run(1)
check("step 2 after moving to console", step() == 2)

-- 2 attributes
for _ = 1, 5 do Remotes.Allocate:FireServer("Intelligence") end
run(1)
check("step 3 after spending 5 points", step() == 3)

-- 3 loot
local locker = workspace_:FindFirstChild("Lootable", true)
check("locker exists", locker ~= nil)
locker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
run(1)
check("step 4 after looting", step() == 4)

-- 4 craft
Remotes.Craft:FireServer("Medkit"); run(1)
check("step 5 after crafting medkit", step() == 5)

-- 5 armor
Remotes.EquipItem:FireServer("ScrapVest"); run(1)
check("step 6 after wearing armor", step() == 6)

-- 6 attack x4 (face the dummy)
local dummy = plot:FindFirstChild("Training Dummy")
local function face() local dp = dummy.HumanoidRootPart.Position; root().CFrame = M.CF.lookAt(dummy.HumanoidRootPart.Position + M.V3.new(0, 0, 5), dp) end
face()
local dummyHealth0 = dummy.Humanoid.Health
for _ = 1, 10 do if step() ~= 6 + 1 or true then Remotes.Attack:FireServer(); run(0.75) end if step() == 7 then break end end
check("dummy took damage", dummy.Humanoid.Health < dummyHealth0)
check("step 7 after 4 hits", step() == 7)

-- 7 heavy
run(1.5); Remotes.Heavy:FireServer(); run(1.5)
check("step 8 after heavy", step() == 8)

-- 8 flicker -> black flash: flick just before each swing (needs >=3 chained flicked hits)
local flashSeen = false
for _ = 1, 8 do
	run(0.5)
	Remotes.Flicker:FireServer(); Remotes.Attack:FireServer(); run(0.4)
	for _, e in M.FireLog do if e[3] == "BlackFlash" then flashSeen = true end end
	if step() == 9 then break end
end
check("black flash landed (step 9)", flashSeen and step() == 9)

local Combat = M.mockEnv.__require(SSS.Server.Combat)
-- 9 dodge: dummy telegraphs with a Highlight; dodge in the middle of the telegraph
local function telegraphStart() return dummy:FindFirstChildOfClass("Highlight") ~= nil end
local function waitTelegraph() return run(8, telegraphStart) end
local dodged = 0
for _ = 1, 4 do
	if step() ~= 9 then break end
	waitTelegraph(); run(0.55); face(); Remotes.Dodge:FireServer(M.V3.new(1, 0, 0))
	run(1.2)
end
check("step 10 after dodges", step() == 10)

-- 10 parry: press block just before the strike lands (telegraph 0.8s)
for _ = 1, 5 do
	if step() ~= 10 then break end
	waitTelegraph(); face(); run(0.62); Remotes.Block:FireServer(true); run(0.45); Remotes.Block:FireServer(false); run(0.5)
end
check("step 11 after parries", step() == 11)

-- 11 block: hold block through the strike
for _ = 1, 5 do
	if step() ~= 11 then break end
	waitTelegraph(); face(); Remotes.Block:FireServer(true); run(1.5); Remotes.Block:FireServer(false); run(0.5)
end
check("step 12 after blocks", step() == 12)

-- 12 feint: start a swing then cancel in the windup
for _ = 1, 4 do
	if step() ~= 12 then break end
	run(1); Remotes.Attack:FireServer(); run(0.05); Remotes.Feint:FireServer(); run(0.5)
end
check("step 13 (skill) after feints", step() == 13)

-- 13 skill (slot 1 auto-filled: Intelligence 5 unlocks Surge)
run(1); Remotes.UseSkill:FireServer(1); run(1)
check("step 14 after skill", step() == 14)

-- finale: world should open after min prologue time since all players ready
local openedAt = nil
check("world opens after tutorial", run(60, function() return workspace_:GetAttribute("Phase") == "Open" end))
run(8)
local pos = root().CFrame.Position
check("player teleported into the arena", math.abs(pos.Y - 6.9) < 3 or pos.Y < 100)
print("   player position after emergence:", pos.X, pos.Y, pos.Z)
check("plot removed", workspace_:FindFirstChild("Prologue_1") == nil)
local last = lastTutorial()
check("tutorial panel cleared", last and last[3] == nil)

-- open world: second player, PvP, permadeath
local p2 = makePlayer("Rival", 456)
Players.PlayerAdded:Fire(p2); as(p2); run(1); confirmLook(p2); run(1)
check("second player spawned in open world", p2.Character ~= nil and p2.Character.HumanoidRootPart.CFrame.Position.Y < 100)
-- story-001: the held weapon is replicated as a character attribute so every client can draw it
check("Weapon attribute replicated on spawn", p2.Character and p2.Character:GetAttribute("Weapon") == "PipeClub")
-- teleport them next to each other and fight
as(player)
local c1, c2 = player.Character, p2.Character
c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, 0), M.V3.new(0, 5, -4))
c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, -4), M.V3.new(0, 5, 0))
local before = c2.Humanoid.Health
Remotes.Attack:FireServer(); run(0.8)
check("PvP hit lands in the open world", c2.Humanoid.Health < before)
-- kill rival -> permadeath
local invBefore = 0
c2.Humanoid.Health = 0
run(0.5)
local lootable = workspace_:FindFirstChild("Lootable", true)
check("rival's remains dropped as loot", lootable ~= nil)
run(6); confirmLook(p2); run(2)
check("rival respawned as a fresh character", p2.Character ~= nil and p2.Character ~= c2 and p2.Character.Humanoid.Health > 0)
check("no script errors", #M.errors == 0)
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
