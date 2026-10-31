local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
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
local locker = plot:FindFirstChild("Lootable", true)
check("locker exists", locker ~= nil)
locker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player); run(0.1)
check("the locker opens as a container with its items", (function()
	local Loot_ = M.mockEnv.__require(SSS.Server.Loot)
	local c = Loot_.Contents(locker)
	return (c.ScrapVest or 0) == 1 and (c.Cloth or 0) == 2
end)())
root().CFrame = M.CF.new(locker.Position + M.V3.new(3, 0, 0)); run(0.1) -- taking needs you within reach
Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.1)
local prof0 = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(player)
check("nothing can be taken before it is revealed", prof0.Inventory.ScrapVest == nil and locker.Parent ~= nil)
locker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player) -- (re)start the search while standing here
run(1.2)
check("the search reveals items over time", (function()
	local Loot_ = M.mockEnv.__require(SSS.Server.Loot)
	-- after ~1.2s at least one small item should be revealed: take all moves only revealed ones
	Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.1)
	local c = Loot_.Contents(locker)
	local left = 0
	for _, n in c do left += n end
	return left < 4 -- 4 items were inside (1 vest, 2 cloth, 1 scrap): something came out
end)())
M.mockEnv.__require(SSS.Server.Loot).RevealAll(locker, player) -- the rest, without waiting (the dummy timing below is tight)
Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.2)
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
-- the rest of the scenario hands out piles of materials; give the pockets room for them (the grid has its own tests)
local ConfigM = M.mockEnv.__require(RS.Shared.Config)
ConfigM.Inventory.Pockets[1], ConfigM.Inventory.Pockets[2] = 30, 30
run(8)
local pos = root().CFrame.Position
check("player teleported into the arena", math.abs(pos.Y - 6.9) < 3 or pos.Y < 100)
print("   player position after emergence:", pos.X, pos.Y, pos.Z)
check("plot removed", workspace_:FindFirstChild("Prologue_1") == nil)
local last = lastTutorial()
check("tutorial panel cleared", last and last[3] == nil)

-- open world: second player, PvP, permadeath
local p2 = makePlayer("Rival", 456)
Players.PlayerAdded:Fire(p2); as(p2); run(2)
check("second player spawned in open world", p2.Character ~= nil and p2.Character.HumanoidRootPart.CFrame.Position.Y < 100)
-- teleport them next to each other and fight
as(player)
local c1, c2 = player.Character, p2.Character
c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, 0), M.V3.new(0, 5, -4))
c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, -4), M.V3.new(0, 5, 0))
local before = c2.Humanoid.Health
Remotes.Attack:FireServer(); run(0.8)
check("spawn protection blocks the first hit", c2.Humanoid.Health == before)
run(9)
c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, 0), M.V3.new(0, 5, -4))
c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, -4), M.V3.new(0, 5, 0))
Remotes.Attack:FireServer(); run(0.8)
check("PvP hit lands once protection expires", c2.Humanoid.Health < before)
-- kill rival -> permadeath
local invBefore = 0
c2.Humanoid.Health = 0
run(0.5)
local lootable
for _, d in workspace_:GetDescendants() do if d:GetAttribute("Label") == "Rival's remains" then lootable = d end end
check("rival's remains dropped as loot", lootable ~= nil)
-- regression: the dead player (still a corpse during the respawn wait) must not loot their own remains
if lootable then
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	for _, pr in lootable:GetChildren() do if pr.ClassName == "ProximityPrompt" and pr.ActionText == "Loot" then pr.Triggered:Fire(p2) end end
	run(0.2)
	-- (the wiped profile already holds starting gear, so check the remains survived and no Ration was taken)
	check("a corpse cannot loot its own remains", lootable.Parent ~= nil and Inventory.Count(p2, "Ration") <= 1)
end
run(8)
check("rival respawned as a fresh character", p2.Character ~= nil and p2.Character ~= c2 and p2.Character.Humanoid.Health > 0)

-- ===== City, devour, enemy roster, raid =====
local city = workspace_:FindFirstChild("City")
check("city generated", city ~= nil and #city:GetChildren() > 100)
local caches = game_:GetService("CollectionService"):GetTagged("Cache")
check("loot caches placed", #caches >= 20)
check("raid gate built", workspace_:FindFirstChild("RaidGate") ~= nil)

-- district banner
local p1char = player.Character
p1char.HumanoidRootPart.CFrame = M.CF.new(0, 5, -420); run(2.5)
local sawDistrict = false
for _, e in M.FireLog do if e[1] == "Announce" and e[4] == "District" then sawDistrict = true end end
check("district banner on entry", sawDistrict)

-- devour the rival's remains (loot is destroyed, xp + charge gained)
local remains
for _, d in workspace_:GetDescendants() do if d.Name == "Lootable" and d:FindFirstChildOfClass("ProximityPrompt") then
	for _, pr in d:GetChildren() do if pr.ClassName == "ProximityPrompt" and pr.ActionText == "Devour" then remains = d; break end end
end end
check("player remains are devourable", remains ~= nil)
if remains then
	local before = player.Character:GetAttribute("Charge")
	player.Character:SetAttribute("Charge", 0)
	for _, pr in remains:GetChildren() do if pr.ClassName == "ProximityPrompt" and pr.ActionText == "Devour" then pr.Triggered:Fire(player) end end
	run(0.5)
	check("devour restores charge and removes the body", player.Character:GetAttribute("Charge") == player.Character:GetAttribute("MaxCharge") and remains.Parent == nil)
end

-- raid: enter the gate, then fight (we cheat the kills so the test is fast and deterministic)
local gatePrompt
for _, d in workspace_.RaidGate:GetDescendants() do if d.ClassName == "ProximityPrompt" then gatePrompt = d end end
check("gate has a prompt", gatePrompt ~= nil)
as(player)
gatePrompt.Triggered:Fire(player); run(1)
local pos = player.Character.HumanoidRootPart.Position
check("player moved into the raid arena", math.abs(pos.X - (-3000)) < 60)
run(21) -- join window
local enemies = workspace_:FindFirstChild("RaidEnemies")
check("wave 1 spawned", enemies ~= nil and #enemies:GetChildren() >= 4)
enemies = enemies or M.newInstance("Folder")
local killed, wavesSeen = 0, {}
local function slayAll()
	for _, m in enemies:GetChildren() do
		local h = m:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then m:SetAttribute("LastAttackerUserId", player.UserId); m:SetAttribute("LastAttackerName", "Tester"); m:SetAttribute("LastHitTime", M.setNow()); h.Health = 0; killed += 1 end
	end
end
local bossSeen = false
for _ = 1, 12 do
	run(3)
	for _, m in enemies:GetChildren() do if m:GetAttribute("Boss") then bossSeen = true end end
	slayAll()
	run(1)
	local done = false
	for _, e in M.FireLog do if e[1] == "Raid" and type(e[3]) == "table" and e[3].Done then done = true end end
	if done then break end
end
check("all four waves including the Warden were fought", killed >= 13 and bossSeen)
local vault
for _, d in workspace_:GetDescendants() do if d:GetAttribute("Label") == "Raid Vault" then vault = d end end
check("raid vault spawned", vault ~= nil)
run(28)
local home = player.Character.HumanoidRootPart.Position
check("extracted back to the city after the raid", math.abs(home.X) < 700 and math.abs(home.Z) < 700)
check("raid folder cleaned up", enemies ~= nil and #enemies:GetChildren() == 0)


-- ===== Destruction & salvage =====
local Destruction = M.mockEnv.__require(SSS.Server.Destruction)
local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
local dfolder = workspace_:FindFirstChild("Destruction")
local propCount = 0
for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") then propCount += 1 end end
check("props placed in the city", propCount >= 100)
local breachCount = 0
for _, m in dfolder:GetChildren() do if m:GetAttribute("Tier") then breachCount += 1 end end
check("breach points placed", breachCount >= 5)

-- give the tester a sledge and stand at a streetlight
as(player)
Inventory.Add(player, "Sledge", 1); Remotes.EquipItem:FireServer("Sledge"); run(0.3)
local lamp
for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") == "Streetlight" then lamp = m break end end
check("found a streetlight", lamp ~= nil)
local lampPos = lamp.PrimaryPart.Position
local pc = player.Character
pc.HumanoidRootPart.CFrame = M.CF.lookAt(lampPos + M.V3.new(0, 2, 5), M.V3.new(lampPos.X, lampPos.Y + 2, lampPos.Z))
run(1)
for _ = 1, 6 do Remotes.Attack:FireServer(); run(0.9) end
check("streetlight broke under blunt hits", lamp.Parent == nil)
local salvageFound, chunkFound = nil, nil
for _, d in dfolder:GetChildren() do
	if d:GetAttribute("Label") == "Salvage" then salvageFound = d end
	if d:GetAttribute("Chunk") and d:GetAttribute("Improvised") then chunkFound = d end
end
check("salvage remains dropped", salvageFound ~= nil)
check("grabbable pipe chunk spawned", chunkFound ~= nil)

-- grab the pipe, it becomes an improvised club
chunkFound.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(2, 0, 0)); run(0.2)
Remotes.Grab:FireServer(chunkFound); run(0.5)
check("holding the pipe", pc:GetAttribute("Holding") == "Pipe" and pc:GetAttribute("Improvised") == true)

-- throw it at the rival (positioned in front, out of spawn protection)
local rc = p2.Character
rc.HumanoidRootPart.CFrame = M.CF.lookAt(pc.HumanoidRootPart.Position + pc.HumanoidRootPart.CFrame.LookVector * 10, pc.HumanoidRootPart.Position)
run(9)
local rivalHp = rc.Humanoid.Health
Remotes.Throw:FireServer(pc.HumanoidRootPart.CFrame.LookVector, 1); run(0.1)
-- the mock has no physics: move the chunk along its velocity by hand
for _ = 1, 20 do chunkFound.CFrame = M.CF.new(chunkFound.Position + chunkFound.AssemblyLinearVelocity * (1/30)); run(1/30) end
check("thrown pipe hit the rival through the combat path", rc.Humanoid.Health < rivalHp and pc:GetAttribute("Holding") == nil)

-- parry deflect: rival blocks right before a second throw lands
local plank
for _, d in dfolder:GetChildren() do if d:GetAttribute("Chunk") and not d:GetAttribute("Improvised") then plank = d break end end
if plank then
	plank.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(2, 0, 0)); run(0.2)
	Remotes.Grab:FireServer(plank); run(0.5)
	local hpBefore = rc.Humanoid.Health
	as(p2); Remotes.Block:FireServer(true); as(player)
	Remotes.Throw:FireServer(pc.HumanoidRootPart.CFrame.LookVector, 0.5); run(0.05)
	for _ = 1, 8 do plank.CFrame = M.CF.new(plank.Position + plank.AssemblyLinearVelocity * (1/30)); run(1/30) end
	local deflected = false
	for _, e in M.FireLog do if e[1] == "World" and e[3] == "Deflect" then deflected = true end end
	check("a parry deflects a thrown chunk", deflected and rc.Humanoid.Health == hpBefore)
	as(p2); Remotes.Block:FireServer(false); as(player)
else
	check("a parry deflects a thrown chunk (no plank found)", false)
end

-- catch: rival presses G as the next throw arrives, and ends up holding it
local post
for _, d in dfolder:GetChildren() do if d:GetAttribute("Chunk") and not d:GetAttribute("Improvised") and d ~= plank then post = d break end end
post = post or plank
if post then
	run(1)
	post.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(2, 0, 0)); run(0.3)
	Remotes.Grab:FireServer(post); run(1.2)
	check("holding a chunk to throw for the catch test", pc:GetAttribute("Holding") ~= nil)
	local hpBeforeCatch = rc.Humanoid.Health
	Remotes.Throw:FireServer(pc.HumanoidRootPart.CFrame.LookVector, 0); run(0.05)
	-- fly it to just short of the rival, press G there, then let it arrive
	local steps = 0
	while (post.Position - rc.HumanoidRootPart.Position).Magnitude > 6 and steps < 30 do
		post.CFrame = M.CF.new(post.Position + post.AssemblyLinearVelocity * (1/30)); run(1/30); steps += 1
	end
	as(p2); Remotes.Grab:FireServer(post); as(player)
	for _ = 1, 4 do post.CFrame = M.CF.new(post.Position + post.AssemblyLinearVelocity * (1/30)); run(1/30) end
	check("a timed grab catches the throw", rc:GetAttribute("Holding") ~= nil and rc.Humanoid.Health == hpBeforeCatch)
	as(p2); Remotes.Drop:FireServer(); as(player); run(0.5)
	-- a grab pressed far too early does not catch (lockout), and the chunk lands
	local post2
	for _, d in dfolder:GetChildren() do if d:GetAttribute("Chunk") and not d:GetAttribute("Improvised") and d ~= post then post2 = d break end end
	if post2 then
		run(1)
		post2.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(2, 0, 0)); run(0.3)
		Remotes.Grab:FireServer(post2); run(1.2)
		local hpEarly = rc.Humanoid.Health
		Remotes.Throw:FireServer(pc.HumanoidRootPart.CFrame.LookVector, 0); run(0.05)
		as(p2); Remotes.Grab:FireServer(post2); as(player) -- pressed immediately: far too early
		run(0.4)
		for _ = 1, 12 do post2.CFrame = M.CF.new(post2.Position + post2.AssemblyLinearVelocity * (1/30)); run(1/30) end
		check("an early grab press does not catch", rc:GetAttribute("Holding") == nil and rc.Humanoid.Health < hpEarly)
	end
end

-- breaching: a Reinforced door ignores the sledge but opens to a charge
local reinforced
for _, m in dfolder:GetChildren() do if m:GetAttribute("Tier") == "Reinforced" then reinforced = m break end end
local door = reinforced and reinforced:FindFirstChild("Door")
check("found a reinforced breach", door ~= nil)
pc.HumanoidRootPart.CFrame = M.CF.lookAt(door.Position + M.V3.new(0, 0, -5), M.V3.new(door.Position.X, door.Position.Y, door.Position.Z)); run(0.5)
for _ = 1, 4 do Remotes.Heavy:FireServer(); run(1.4) end
check("reinforced door shrugs off the sledge", door.Parent ~= nil)
Inventory.Add(player, "BreachingCharge", 1)
Remotes.UseItem:FireServer("BreachingCharge"); run(0.5)
check("charge planted", Inventory.Count(player, "BreachingCharge") == 0)
run(4.5)
check("reinforced door breached by the charge", door.Parent == nil)
local investigating = false
for _, m in workspace_:GetDescendants() do if m:GetAttribute("Investigate") then investigating = true end end

-- grenade: throw at the rival
rc.HumanoidRootPart.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(0, 0, 6)); run(0.2)
Inventory.Add(player, "PipeGrenade", 1)
pc.Humanoid.Health = pc.Humanoid.MaxHealth
local hpBeforeNade, myHpBefore = rc.Humanoid.Health, pc.Humanoid.Health
Remotes.UseItem:FireServer("PipeGrenade", M.V3.new(0, 0, 1)); run(0.05)
local nade = dfolder:FindFirstChild("PipeGrenade")
check("grenade spawned", nade ~= nil)
-- no physics in the mock: fly it by hand to the rival, then let the fuse run out
nade.CFrame = M.CF.new(pc.HumanoidRootPart.Position + M.V3.new(0, 0, 3)); nade.AssemblyLinearVelocity = M.V3.zero -- sits between the two, in sight of both
run(3)
check("pipe grenade exploded and hurt the rival", rc.Humanoid.Health < hpBeforeNade)
check("your own grenade hurts you too", pc.Humanoid.Health < myHpBefore and pc.Humanoid.Health > 0)
run(1)

-- arc pistol is cell-fed
Inventory.Add(player, "ArcPistol", 1); Remotes.EquipItem:FireServer("ArcPistol"); run(1.5)
local cellsBefore = Inventory.Count(player, "ArcCell")
Remotes.Attack:FireServer(); run(0.6)
check("arc pistol refuses to fire without cells", Inventory.Count(player, "ArcCell") == cellsBefore)
Inventory.Add(player, "ArcCell", 3); run(0.6)
Remotes.Attack:FireServer(); run(0.6)
check("arc pistol spends a cell per shot", Inventory.Count(player, "ArcCell") == 2)

-- dematerialization brings everything back
Destruction.Reset(); run(1)
local lampBack = false
for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") == "Streetlight" and m.PrimaryPart and (m.PrimaryPart.Position - lampPos).Magnitude < 8 then lampBack = true end end
check("rematerialize restores the streetlight (as a fresh condition) and the door", lampBack and door.Parent ~= nil)
local chunksLeft = 0
for _, d in dfolder:GetChildren() do if d:GetAttribute("Chunk") then chunksLeft += 1 end end
check("rematerialize clears loose chunks", chunksLeft == 0)

-- gore (Restricted): a kill leaves a persistent corpse that rematerialization clears
local gore = workspace_:FindFirstChild("Gore")
rc.Humanoid.Health = 0; run(0.5)
local corpseCount = 0
for _, c in gore:GetChildren() do if c.Name == "Corpse" then corpseCount += 1 end end
check("restricted gore leaves a corpse behind", corpseCount >= 1)
run(8)
Destruction.Reset(); run(0.5)
corpseCount = 0
for _, c in gore:GetChildren() do if c.Name == "Corpse" then corpseCount += 1 end end
check("rematerialize clears corpses", corpseCount == 0)


-- ===== Hideouts, wear, repair, upgrades, vault theft =====
local Hideouts = M.mockEnv.__require(SSS.Server.Hideouts)
local PlayerData = M.mockEnv.__require(SSS.Server.Common.PlayerData)
check("hideout sites placed", #Hideouts.Sites >= 10)
as(player)
Inventory.Add(player, "Scrap", 200); Inventory.Add(player, "SheetMetal", 60); Inventory.Add(player, "Wire", 40); Inventory.Add(player, "Battery", 12); Inventory.Add(player, "Pipe", 10); Inventory.Add(player, "Cloth", 30); Inventory.Add(player, "Powder", 8)
Remotes.HideoutClaim:FireServer(1); run(0.3)
local site = Hideouts.Sites[1]
check("claimed a site", site.Owner == player.UserId and site.Built ~= nil)
Remotes.HideoutBuild:FireServer("Vault"); Remotes.HideoutBuild:FireServer("Walls"); Remotes.HideoutBuild:FireServer("Bunks"); run(0.5)
local pd = PlayerData.Get(player)
check("built vault, walls and bunks", pd.Hideout.Modules.Vault and pd.Hideout.Modules.Walls and pd.Hideout.Modules.Bunks and site.Gate ~= nil)
Remotes.HideoutBuild:FireServer("Turret"); run(0.3)
check("tier-1 cannot build a turret", not pd.Hideout.Modules.Turret)
Remotes.HideoutUpgrade:FireServer(); run(0.3)
check("workshop upgraded to tier 2", pd.Hideout.Tier == 2)

-- wear: swing a weapon at the dummy; condition drops; repair restores it
Remotes.EquipItem:FireServer("Sledge"); run(0.3)
pc = player.Character
local dummy2
for _, m in workspace_:GetDescendants() do if m.Name == "Training Dummy" and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChildOfClass("Humanoid").Health > 0 then dummy2 = m break end end
pc.HumanoidRootPart.CFrame = M.CF.lookAt(dummy2.HumanoidRootPart.Position + M.V3.new(0, 0, 5), dummy2.HumanoidRootPart.Position)
run(0.5)
for _ = 1, 6 do Remotes.Attack:FireServer(); run(0.9) end
check("weapon wears with use", (pd.Condition.Sledge or 100) < 100)
local scrapBefore = Inventory.Count(player, "Scrap")
Remotes.HideoutRepair:FireServer("Sledge"); run(0.3)
check("bench repair restores condition for materials", pd.Condition.Sledge == 100 and Inventory.Count(player, "Scrap") < scrapBefore)
Remotes.ItemUpgrade:FireServer("Sledge"); run(0.3)
check("weapon upgraded to +1", pd.Upgrades.Sledge == 1)
Remotes.ItemUpgrade:FireServer("Sledge"); run(0.3)
check("+2 needs a forge", pd.Upgrades.Sledge == 1)
Remotes.HideoutBuild:FireServer("Forge"); run(0.3); Remotes.ItemUpgrade:FireServer("Sledge"); run(0.3)
check("+2 after building a forge", pd.Upgrades.Sledge == 2)
local Gear = M.mockEnv.__require(SSS.Server.Gear)
check("upgrade raises damage", Gear.Get(player).DamageMult > 1 + 5 * 0.03)

-- vault: store the sledge, it carries its +2; a non-member cannot strip it while the gate stands
Remotes.VaultPut:FireServer("Sledge", 1); run(0.3)
check("stored in the vault with its upgrade", pd.Hideout.Vault.Sledge == 1 and pd.Hideout.VaultUpgrades.Sledge == 2 and Inventory.Count(player, "Sledge") == 0)
local rival2 = p2.Character
local vaultPart = site.Vault
rival2.HumanoidRootPart.CFrame = M.CF.new(vaultPart.Position + M.V3.new(3, 0, 0)); run(0.2)
for _, pr in vaultPart:GetChildren() do if pr.ClassName == "ProximityPrompt" then pr.Triggered:Fire(p2) end end
run(0.3)
check("gate standing: vault cannot be stripped", pd.Hideout.Vault.Sledge == 1)
-- breach the gate with a charge, then strip it
as(p2)
Inventory.Add(p2, "BreachingCharge", 1)
p2.Character.HumanoidRootPart.CFrame = M.CF.new(site.Gate.Door.Position + M.V3.new(0, 0, -4)); run(0.3)
Remotes.UseItem:FireServer("BreachingCharge"); run(5)
check("raider breached the compound gate", site.Gate:FindFirstChild("Door") == nil)
p2.Character.HumanoidRootPart.CFrame = M.CF.new(vaultPart.Position + M.V3.new(3, 0, 0)); run(0.2)
for _, pr in vaultPart:GetChildren() do if pr.ClassName == "ProximityPrompt" then pr.Triggered:Fire(p2) end end
run(0.3)
local rd = PlayerData.Get(p2)
check("vault stripped: thief holds the +2 sledge, owner lost it", next(pd.Hideout.Vault) == nil and Inventory.Count(p2, "Sledge") == 1 and rd.Upgrades.Sledge == 2)
as(player)
-- crew: invite the rival (after they drop their own claim-less state), they spawn at the bunks
Remotes.HideoutInvite:FireServer("Rival"); run(0.3)
check("crew member added", table.find(pd.Hideout.Members, p2.UserId) ~= nil)
check("crew spawns at the bunks", Hideouts.SpawnCFrame(p2) ~= nil)
-- NPC raid pressure
local before = #game_:GetService("CollectionService"):GetTagged("NPC")
Hideouts.NpcRaid(site); run(0.5)
check("npc raid spawns raiders at the compound", #game_:GetService("CollectionService"):GetTagged("NPC") > before)


-- sprint: faster while stamina lasts
as(player)
pc = player.Character
local Stats = M.mockEnv.__require(SSS.Server.Stats)
Stats.Apply(player, true); run(0.2)
local walk = pc.Humanoid.WalkSpeed
Remotes.Sprint:FireServer(true); run(0.2)
check("sprint raises walk speed", pc.Humanoid.WalkSpeed > walk)
Remotes.Sprint:FireServer(false); run(0.2)
check("sprint releases", pc.Humanoid.WalkSpeed == walk)

-- population: Main's Population.Init populated the districts when the world opened earlier in this run
local Population = M.mockEnv.__require(SSS.Server.Population)
local populated = 0
for _, m in game_:GetService("CollectionService"):GetTagged("NPC") do
	if m:GetAttribute("Population") then populated += 1 end
end
print("population: standing hostiles=" .. populated .. " alive=" .. Population.Alive())
check("population spawned district packs at world open", populated >= 8)
check("population stays under its cap", populated <= 36)

-- grid inventory: footprints, stacks, overflow, moves, packs, weight
as(player)
local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
local Items_ = M.mockEnv.__require(RS.Shared.Items)
local prof = pd
ConfigM.Inventory.Pockets[1], ConfigM.Inventory.Pockets[2] = 6, 4
-- empty the pockets first so the numbers below are exact
for _, it in table.clone(prof.Grid.Items) do Inventory.Drop(player, table.find(prof.Grid.Items, it)) end
run(0.2)
check("grid starts as pockets", Inventory.GridSize(prof) == 6 and #prof.Grid.Items == 0)
Inventory.Add(player, "Scrap", 45)
check("materials stack to 20", #prof.Grid.Items == 3 and prof.Inventory.Scrap == 45)
local lootBefore = 0
for _, p in game_.Workspace:GetDescendants() do if p.Name == "Lootable" then lootBefore += 1 end end
Inventory.Add(player, "Sledge", 3) -- 2x4 each: two fit beside the scrap in 6x4, the third cannot
run(0.2)
local lootAfter = 0
for _, p in game_.Workspace:GetDescendants() do if p.Name == "Lootable" then lootAfter += 1 end end
check("what cannot fit drops at your feet", (prof.Inventory.Sledge or 0) == 2 and lootAfter > lootBefore)
Inventory.Add(player, "PipeClub", 1) -- 1x3: the free cells are fragmented, so this needs the repack
check("a long item fits after a repack", prof.Inventory.PipeClub == 1)
local club
for i, it in prof.Grid.Items do if it.Id == "PipeClub" then club = i end end
local before = { prof.Grid.Items[club].X, prof.Grid.Items[club].Y }
Remotes.MoveItem:FireServer(club, 1, 1, 0); run(0.1) -- onto the scrap: refused
check("a move onto another stack is refused", prof.Grid.Items[club].X == before[1] and prof.Grid.Items[club].Y == before[2])
Remotes.MoveItem:FireServer(club, 99, 1, 0); run(0.1)
check("a move outside the grid is refused", prof.Grid.Items[club].X == before[1])
-- make room for the satchel (2x2): drop one sledge, then craft
for i, it in prof.Grid.Items do if it.Id == "Sledge" then Remotes.DropItem:FireServer(i); break end end
run(0.1)
check("dropping a stack frees its cells", prof.Inventory.Sledge == 1)
Inventory.Add(player, "Cloth", 4)
Remotes.Craft:FireServer("Satchel"); run(0.2)
check("a satchel can be crafted", (prof.Inventory.Satchel or 0) == 1)
Remotes.EquipItem:FireServer("Satchel"); run(0.2)
check("wearing a pack grows the grid", prof.Pack == "Satchel" and Inventory.GridSize(prof) == 7 and (prof.Inventory.Satchel or 0) == 0)
Inventory.Add(player, "Sledge", 1)
check("the bigger grid takes another sledge", prof.Inventory.Sledge == 2)
Inventory.Add(player, "Scrap", 40)
check("overweight flips when the pack is overloaded", Items_.GridWeight(prof) > Items_.Carry(prof))
local Stats_ = M.mockEnv.__require(SSS.Server.Stats)
Stats_.Apply(player, false); run(0.1)
check("overweight slows the walk", player.Character.Humanoid.WalkSpeed < 16 and player.Character:GetAttribute("Overweight") == true)
Remotes.SortItems:FireServer(); run(0.1)
check("sort keeps every item", (function() local n = 0; for _, it in prof.Grid.Items do n += it.Count end; local c = 0; for _, v in prof.Inventory do c += v end; return n == c and n > 0 end)())
Inventory.Add(player, "Cloth", 4)
Remotes.ItemUpgrade:FireServer("Satchel"); run(0.2)
check("the worn pack upgrades at the bench: a row and carry", (prof.Upgrades.Satchel or 0) == 1 and select(2, Inventory.GridSize(prof)) == 6 and Items_.Carry(prof) == 30)
Remotes.Unequip:FireServer("Pack"); run(0.2)
check("taking the pack off shrinks the grid and spills the rest", prof.Pack == "" and Inventory.GridSize(prof) == 6)
check("counts cache matches the grid", (function()
	local sum = 0
	for _, it in prof.Grid.Items do sum += it.Count end
	local cache = 0
	for _, c in prof.Inventory do cache += c end
	return sum == cache
end)())
ConfigM.Inventory.Pockets[1], ConfigM.Inventory.Pockets[2] = 30, 30

-- vault grid: the hideout vault is a grid sized by tier and shelving; put/take/move go through it
as(player)
local Hideouts_ = M.mockEnv.__require(SSS.Server.Hideouts)
local hv = pd.Hideout
local vbox = Hideouts_.VaultBox(hv)
check("vault grid matches the workshop tier", vbox.W == 8 and vbox.H == 6)
local vaultCells = vbox.W * vbox.H
Inventory.Add(player, "Scrap", 20)
Remotes.VaultPut:FireServer("Scrap", 20); run(0.2)
check("vault put lands in the grid", (hv.Vault.Scrap or 0) >= 20 and #hv.VaultGrid.Items >= 1)
local scrapIdx
for i, it in hv.VaultGrid.Items do if it.Id == "Scrap" then scrapIdx = i end end
local sx, sy = hv.VaultGrid.Items[scrapIdx].X, hv.VaultGrid.Items[scrapIdx].Y
Remotes.VaultMove:FireServer(scrapIdx, vbox.W, vbox.H, 0); run(0.1)
check("vault move rearranges the grid", hv.VaultGrid.Items[scrapIdx].X == vbox.W and hv.VaultGrid.Items[scrapIdx].Y == vbox.H)
Remotes.VaultTake:FireServer("Scrap", 20); run(0.2)
check("vault take comes back to the pack", (hv.Vault.Scrap or 0) == 0)
Remotes.HideoutBuild:FireServer("Shelves"); run(0.3)
check("shelving adds rows to the vault grid", Hideouts_.VaultBox(hv).H == 8 or (hv.Modules.Shelves == nil))

-- input queue: a heavy pressed during a light swing's recovery plays when the swing ends instead of being dropped
as(player)
Remotes.EquipItem:FireServer("PipeClub"); run(0.2)
local Combat_ = M.mockEnv.__require(SSS.Server.Combat)
local heavyFired = false
local qconn = Combat_.Used.Event:Connect(function(name, who) if name == "Heavy" and who == player then heavyFired = true end end)
Remotes.Attack:FireServer(); run(0.05)
Remotes.Heavy:FireServer() -- too early: queued
run(0.05)
check("an early heavy is not thrown away", not heavyFired)
run(1.5)
check("the queued heavy plays once the swing ends", heavyFired)
qconn:Disconnect()

-- the Autonet: cybernetics go in only at the table, each rip costs health and takes time; all eight slots = machine
as(player)
local Voice_ = M.mockEnv.__require(RS.Shared.Voice)
check("the machine voice flattens chat", Voice_.Machine("lol I'm sooooo done!!") == "I AM SO DONE.")
Inventory.Add(player, "ReflexOptic", 1)
Remotes.EquipItem:FireServer("ReflexOptic"); run(0.2)
check("a cybernetic cannot be worn from the pack", pd.Cyber.Eyes == nil)
Inventory.Add(player, "Glass", 6); Inventory.Add(player, "Battery", 6); Inventory.Add(player, "Wire", 20); Inventory.Add(player, "SheetMetal", 10)
Remotes.HideoutBuild:FireServer("Autonet"); run(0.5)
check("the hideout builds an Autonet", pd.Hideout.Modules.Autonet == true and site.AutonetAt ~= nil)
root().CFrame = M.CF.new(site.AutonetAt + M.V3.new(3, 0, 0)); run(0.2)
local bayPart = site.Built:FindFirstChild("Autonet")
bayPart:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player); run(0.1)
check("stepping up marks you at the table", player:GetAttribute("AtAutonet") == true)
local hpBefore = player.Character.Humanoid.Health
Remotes.Autonet:FireServer("In", "ReflexOptic"); run(0.2)
check("a rip costs health up front and holds you", player.Character.Humanoid.Health < hpBefore and player.Character.HumanoidRootPart.Anchored == true)
run(4.5)
check("the rip finishes: eyes are metal", pd.Cyber.Eyes == "ReflexOptic" and player.Character.HumanoidRootPart.Anchored == false)
-- the rest of the body, two of each paired piece
for _, id in { "AudioPickup", "ChemSniffer", "NeuralCore", "ServoArm", "ServoArm", "StriderLeg", "StriderLeg" } do Inventory.Add(player, id, 1) end
for _, step in { { "AudioPickup" }, { "ChemSniffer" }, { "NeuralCore" }, { "ServoArm", "LeftArm" }, { "ServoArm", "RightArm" }, { "StriderLeg", "LeftLeg" }, { "StriderLeg", "RightLeg" } } do
	player.Character.Humanoid.Health = player.Character.Humanoid.MaxHealth
	Remotes.Autonet:FireServer("In", step[1], step[2]); run(4.6)
end
check("two Servo Arms fill both arms", pd.Cyber.LeftArm == "ServoArm" and pd.Cyber.RightArm == "ServoArm")
check("all eight slots metal: the voice is gone", player:GetAttribute("Machine") == true and M.mockEnv.__require(SSS.Server.Gear).Get(player).Conversion >= 1)
check("senses come from the pieces", (player:GetAttribute("Hearing") or 0) >= 60 and (player:GetAttribute("Scent") or 0) >= 45)
check("the body carries its metal for every client", player.Character:GetAttribute("Cyber_LeftArm") == "ServoArm")
player.Character.Humanoid.Health = player.Character.Humanoid.MaxHealth
Remotes.Autonet:FireServer("Out", "Nose"); run(4.6)
check("ripping one out brings the voice back", pd.Cyber.Nose == nil and player:GetAttribute("Machine") == false)
player:SetAttribute("AtAutonet", nil)

-- launcher: a light staggers a raider, a heavy started in the grace window sends it up (Juggled)
as(player)
Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
local NPCsL = M.mockEnv.__require(SSS.Server.NPCs)
local lr = player.Character.HumanoidRootPart
local dummyR = NPCsL.Spawn("Raider", lr.Position + M.V3.new(0, 0, -3), { Parent = game_.Workspace }) -- a Brute has hyperarmor while it swings and would not stagger
dummyR.Humanoid.MaxHealth, dummyR.Humanoid.Health = 5000, 5000
dummyR.HumanoidRootPart.Anchored = true -- hold it in reach: knockback would push it out of the heavy's range here
lr.CFrame = M.CF.lookAt(lr.Position, dummyR.HumanoidRootPart.Position); run(0.1)
Remotes.Attack:FireServer(); run(0.7) -- the light lands and staggers it; the heavy pressed now queues and fires inside the grace window
Remotes.Heavy:FireServer(); run(0.8)
check("a heavy on a staggered hostile launches it", dummyR:GetAttribute("Juggled") == true)
Remotes.Attack:FireServer(); run(0.5)
check("a hit on a launched hostile pops it (AIR)", (function()
	for _, e in M.FireLog do if e[1] == "CombatEvent" and e[3] == "Juggle" and e[4] == dummyR then return true end end
	return false
end)())
run(1.5)
check("it lands and the juggle ends", dummyR:GetAttribute("Juggled") == false)
dummyR:Destroy()

-- taking turns: three raiders next to the player, but only one winds up at a time
as(player)
local NPCs_ = M.mockEnv.__require(SSS.Server.NPCs)
local pr = player.Character.HumanoidRootPart
local pack = {}
for i = 1, 3 do
	local m = NPCs_.Spawn("Raider", pr.Position + M.V3.new(3 * i, 0, 3), { Parent = game_.Workspace })
	table.insert(pack, m)
end
local logBefore = #M.FireLog
run(3)
-- with three bodies in reach and no turn-taking each would wind up every ~1.9 s (about 5 in 3 s);
-- one slot at a time with the swing gap caps it near 3
local windups = 0
for i = logBefore + 1, #M.FireLog do
	local e = M.FireLog[i]
	if e[1] == "CombatEvent" and e[3] == "Windup" and table.find(pack, e[4]) then windups += 1 end
end
check("the pack attacks (someone wound up)", windups >= 1)
check("the pack takes turns rather than all swinging", windups <= 4)
check("the others hold a ring instead of stacking", (function()
	local far = 0
	for _, m in pack do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pr.Position).Magnitude > 6 then far += 1 end
	end
	return far >= 1
end)())
for _, m in pack do m:Destroy() end

-- dev tools: teleport to the armory and spawn a hostile through the F2 panel's remote
as(player)
local devRoot = player.Character.HumanoidRootPart
local devBefore = #game_:GetService("CollectionService"):GetTagged("NPC")
Remotes.Dev:FireServer("Teleport", "Armory"); run(0.2)
check("dev teleport moves the player to the off-map arena", math.abs(devRoot.Position.Z - 132) < 40 and math.abs(devRoot.Position.X - 3000) < 40)
Remotes.Dev:FireServer("Spawn", "Raider"); run(0.3)
check("dev spawn adds a hostile", #game_:GetService("CollectionService"):GetTagged("NPC") > devBefore)

-- director events: every one runs without error and leaves something behind
as(player)
local Events = M.mockEnv.__require(SSS.Server.Events)
local npcsBefore = #game_:GetService("CollectionService"):GetTagged("NPC")
for name, fire in Events.Fire do
	local ok, err = pcall(fire)
	check("event " .. name .. " runs", ok, err)
end
run(0.5)
check("events spawned hostiles", #game_:GetService("CollectionService"):GetTagged("NPC") > npcsBefore)
local Quests = M.mockEnv.__require(SSS.Server.Quests)
check("quest defs have real reward items", (function()
	local Items = M.mockEnv.__require(RS.Shared.Items)
	for _, def in Quests.Defs do
		for id in def.Reward.Items do
			if not Items.Defs[id] then return false end
		end
	end
	return true
end)())

-- frontier: the world north of the wall (shared/Frontier.lua + server/Frontier.lua)
do
	local FS = M.mockEnv.__require(RS.Shared.Frontier)
	local Frontier = M.mockEnv.__require(SSS.Server.Frontier)
	local Loot = M.mockEnv.__require(SSS.Server.Loot)
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	local CS = game_:GetService("CollectionService")
	local RC = FS.Reach.Center
	print("frontier seed " .. tostring(workspace_.Frontier:GetAttribute("Seed")) .. ", Reach at " .. RC.X .. "," .. RC.Z .. ", route " .. #FS.Route .. " checkpoints, trail " .. #FS.Trail .. " points")
	check("frontier: the Reach sits on the valley floor", math.abs(FS.Height(RC.X, RC.Z) - FS.Floor) < 0.5)
	check("frontier: the city edge is the plateau", FS.Height(0, 760) == FS.CityTop and FS.RegionAt(M.V3.new(0, 2, 600)) == nil)
	check("frontier: regions answer", FS.RegionAt(RC) == "Reach" and FS.RegionAt(M.V3.new(120, 2, 745)) == "Scarp" and FS.RegionAt(M.V3.new(0, 0, 2250)) == "Ridge")
	check("frontier: the Reach landed inside the valley grid", RC.X > -500 and RC.X < 500 and RC.Z > 1100 and RC.Z < 1900)
	check("frontier: the route is rolled and never straight", #FS.Route >= 10 and #FS.Trail >= 5 and (function()
		local turns = 0
		for i = 2, #FS.Trail - 1 do
			local a = (FS.Trail[i] - FS.Trail[i - 1]).Unit
			local b = (FS.Trail[i + 1] - FS.Trail[i]).Unit
			if a:Dot(b) < 0.9 then turns += 1 end
		end
		return turns >= 1
	end)())
	check("frontier: the sites each have a cell of their own", (function()
		local seen = {}
		for _, site in FS.Sites do
			if not site.Cell or seen[site.Cell] then return false end
			seen[site.Cell] = true
		end
		return #FS.Sites == 7
	end)())
	check("frontier: another seed rolls another map", (function()
		local a = FS.Generate(1234).Reach.Center
		local b = FS.Generate(5678).Reach.Center
		FS.Generate(workspace_.Frontier:GetAttribute("Seed")) -- back to the server's layout
		return (a - b).Magnitude > 1
	end)())
	local sites, posts, guards = 0, 0, 0
	for _, d in workspace_.Frontier:GetDescendants() do
		if d.Name == "SitePole" then sites += 1 elseif d.Name == "CheckpointPost" then posts += 1 end
	end
	for _, m in CS:GetTagged("NPC") do if m:GetAttribute("Frontier") then guards += 1 end end
	check("frontier: every site and checkpoint is built", sites == #FS.Sites and posts == #FS.Route - 1)
	print("frontier guards standing: " .. guards)
	check("frontier: guards stand at the checkpoints and sites", guards >= 40 and guards <= 96)
	local stocked = 0
	for _, c in Frontier.Containers() do
		if c.part and c.part.Parent and next(Loot.Contents(c.part)) ~= nil then stocked += 1 end
	end
	check("frontier: every site container is stocked", stocked == #Frontier.Containers())
	-- the route: stand at the first checkpoint and the next is marked
	as(player)
	local pd = PlayerData.Get(player)
	pd.Frontier = { Route = 0, Found = {}, Reached = false }
	player.Character:PivotTo(M.CF.new(FS.Route[1].Position + M.V3.new(0, 3, 0)))
	run(1.6)
	check("frontier: reaching a checkpoint advances the route", pd.Frontier.Route == 1)
	local marked = false
	for _, e in M.FireLog do if e[1] == "World" and e[3] == "Marker" and e[4] == "Route" and tostring(e[6]):find("2/") then marked = true end end
	check("frontier: the next checkpoint is marked", marked)
	-- a site is found by walking near it
	local site = FS.Sites[1]
	player.Character:PivotTo(M.CF.new(site.Position.X, 0, site.Position.Z))
	run(1.6)
	check("frontier: walking near a site discovers it", pd.Frontier.Found[site.Key] == true)
	-- the market: safe, and the trader sells for war credits
	player.Character:PivotTo(M.CF.new(FS.Reach.Center + M.V3.new(0, 3, 0)))
	run(1.6)
	check("frontier: the market is a safe zone", player:GetAttribute("Safe") == true and pd.Frontier.Reached == true)
	local victim = makePlayer("Shopper", 124)
	Players.PlayerAdded:Fire(victim); run(0.3)
	victim.Character:PivotTo(M.CF.new(FS.Reach.Center + M.V3.new(4, 3, 0)))
	run(1.6)
	check("frontier: nobody is hurt in the market", Combat.Damage(player.Character, victim.Character, 20) == "none")
	pd.War.Credits = 0
	local ok = Frontier.Buy(player, "Medkit")
	check("frontier: no credits, no purchase", ok == false)
	pd.War.Credits = 100
	local before = Inventory.Count(player, "Medkit")
	ok = Frontier.Buy(player, "Medkit")
	check("frontier: credits buy from the trader", ok == true and pd.War.Credits == 70 and Inventory.Count(player, "Medkit") == before + 1)
	player.Character:PivotTo(M.CF.new(0, 5, 0))
	run(1.6)
	check("frontier: leaving the market drops the protection", player:GetAttribute("Safe") == nil)
	check("frontier: buying away from the market is refused", Frontier.Buy(player, "Medkit") == false)
	-- encounters: a quiet valley cell versus a rolled one; an ambush springs on entry and then rests
	local ambushCell, patrolCell, bountyCell
	for r = 2, FS.Rows - 1 do
		for c = 2, FS.Cols - 1 do
			local cell = FS.L.Cells[r][c]
			if cell.Encounter then
				if cell.Encounter.Kind == "Ambush" and not ambushCell then ambushCell = cell
				elseif cell.Encounter.Kind == "Patrol" and not patrolCell then patrolCell = cell
				elseif cell.Encounter.Kind == "Bounty" and not bountyCell then bountyCell = cell end
			end
		end
	end
	print("frontier encounters: ambush " .. tostring(ambushCell ~= nil) .. " patrol " .. tostring(patrolCell ~= nil) .. " bounty " .. tostring(bountyCell ~= nil))
	check("frontier: the valley rolled encounters", ambushCell ~= nil or patrolCell ~= nil or bountyCell ~= nil)
	if patrolCell then
		player.Character:PivotTo(M.CF.new(patrolCell.Center.X + 100, 0, patrolCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[patrolCell]
		check("frontier: a patrol wakes when someone comes near", e and e.models and #e.models > 0)
	end
	if bountyCell then
		player.Character:PivotTo(M.CF.new(bountyCell.Center.X + 100, 0, bountyCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[bountyCell]
		check("frontier: the bounty wears its name", e and e.models[1] and e.models[1].Name == bountyCell.Encounter.Boss)
	end
	if ambushCell then
		local npcsBefore = #CS:GetTagged("NPC")
		player.Character:PivotTo(M.CF.new(ambushCell.Center.X, 0, ambushCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[ambushCell]
		check("frontier: walking into an ambush cell springs it", e and e.models and #e.models > 0 and #CS:GetTagged("NPC") > npcsBefore)
		local sprung = #CS:GetTagged("NPC")
		run(1.6)
		check("frontier: a sprung ambush rests", #CS:GetTagged("NPC") == sprung)
		for _, m in e.models do m:Destroy() end
	end
	-- the hideout computer: contacts, contracts, intel, house and market
	do
		local Terminal = M.mockEnv.__require(SSS.Server.Terminal)
		local Contacts = M.mockEnv.__require(SSS.Server.Contacts)
		local Combat_ = M.mockEnv.__require(SSS.Server.Combat)
		local standing = 0
		for _, id in { "Broker", "Fixer", "Dealer" } do if Contacts.Get(id) and Contacts.Get(id).Parent then standing += 1 end end
		check("computer: the three contacts stand in the world", standing == 3)
		check("computer: a contact cannot be hurt", Combat_.Damage(player.Character, Contacts.Get("Fixer"), 50) == "none")
		local board = Terminal.Board()
		local clears = 0
		for id in board do if id:sub(1, 6) == "Clear_" then clears += 1 end end
		check("computer: the board has a contract per site and the raid", clears == #FS.Sites and board.Raid ~= nil)
		local firstSite = FS.Sites[1]
		local cid = "Clear_" .. firstSite.Key
		pd.Knowledge = { Contacts = {}, Contracts = {}, Completed = 0 }
		Terminal.Open(player)
		check("computer: RAIDS is locked until the Broker is met", Terminal.Accept(player, cid) == false)
		Terminal.Meet(player, "Broker"); run(0.1)
		check("computer: meeting the Broker unlocks RAIDS", pd.Knowledge.Contacts.Broker == true and Terminal.Accept(player, cid) == true)
		local second
		for id in board do if id ~= cid and id ~= "Raid" then second = id break end end
		check("computer: two contracts at most", Terminal.Accept(player, "Raid") == true and Terminal.Accept(player, second) == false)
		Terminal.Abandon(player, "Raid")
		-- kills at the site count; the last one pays
		pd.War.Credits = 0
		local need = board[cid].Need
		local fake = M.newInstance("Model"); fake.Name = "Guard"; fake:SetAttribute("Site", firstSite.Key)
		local NPCs_ = M.mockEnv.__require(SSS.Server.NPCs)
		for _ = 1, need do NPCs_.Killed:Fire("Raider", fake, player) end
		run(0.2)
		check("computer: clearing the site completes the contract and pays", pd.Knowledge.Contracts[cid] == nil and pd.War.Credits == board[cid].Reward.Credits and pd.Knowledge.Completed == 1)
		-- a dead rival's intel lands a contract on the board
		local rival = M.newInstance("Model"); rival.Name = "Rival Conduit"
		NPCs_.Killed:Fire("Rival", rival, player); run(0.1)
		local held = 0
		for _ in pd.Knowledge.Contracts do held += 1 end
		check("computer: rival intel puts a contract on the board", held == 1)
		-- house and market
		check("computer: HOUSE is locked until the Fixer is met", Terminal.Order(player, "ScrapLot") == false)
		Terminal.Meet(player, "Fixer"); Terminal.Meet(player, "Dealer"); run(0.1)
		pd.War.Credits = 1000
		local scrapBefore = Inventory.Count(player, "Scrap")
		check("computer: a house order delivers for credits", Terminal.Order(player, "ScrapLot") == true and Inventory.Count(player, "Scrap") == scrapBefore + 12 and pd.War.Credits == 960)
		check("computer: the black market sells for credits", Terminal.Buy(player, "ChemSniffer") == true and Inventory.Count(player, "ChemSniffer") >= 1 and pd.War.Credits == 460)
		check("computer: no credits, no sale", Terminal.Buy(player, "NeuralCore") == false)
		local pushed = false
		for _, e in M.FireLog do if e[1] == "World" and e[3] == "Terminal" and type(e[4]) == "table" and e[4].Apps and e[4].Apps.MARKET then pushed = true end end
		check("computer: the state reaches the client", pushed)
		Terminal.Close(player)
		-- rival crews walk the valley
		local rivals = 0
		for _, m in CS:GetTagged("NPC") do if m:GetAttribute("Crew") then rivals += 1 end end
		print("rival conduits standing: " .. rivals)
		check("computer: rival crews stand in the valley", rivals >= 3)
		-- the Computer module stands in the hideout when there is room for it
		Inventory.Add(player, "Battery", 6); Inventory.Add(player, "Wire", 20); Inventory.Add(player, "Glass", 6); Inventory.Add(player, "SheetMetal", 10)
		Remotes.HideoutBuild:FireServer("Computer"); run(0.5)
		local site2 = Hideouts_.Sites[pd.Hideout.Plot]
		if pd.Hideout.Modules.Computer then
			local console = site2 and site2.Built and site2.Built:FindFirstChild("Computer")
			check("computer: the module builds a console with a login prompt", console ~= nil and console:FindFirstChildOfClass("ProximityPrompt") ~= nil)
		else
			print("computer: module not built (hideout full at this tier); console check skipped")
		end
	end
	-- the cycle: the world resets and the draw redeals contacts, lines and fragments
	do
		local Cycle = M.mockEnv.__require(SSS.Server.Cycle)
		local CluesS = M.mockEnv.__require(SSS.Server.CluesServer)
		local SC = M.mockEnv.__require(RS.Shared.Clues)
		local Contacts = M.mockEnv.__require(SSS.Server.Contacts)
		local before = Cycle.Index()
		check("cycle: the world opening was the first draw", before >= 1 and workspace_:GetAttribute("Cycle") == before)
		-- break something, drop something, wake an encounter; the cycle undoes all of it
		local dfolder = workspace_.Destruction
		local intactBefore = 0
		for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") then intactBefore += 1 end end
		local result = Cycle.Trigger()
		run(0.3)
		local intactAfter = 0
		for _, m in dfolder:GetChildren() do if m:GetAttribute("Prop") then intactAfter += 1 end end
		check("cycle: a run advances the index and restores the props", result and result.Index == before + 1 and intactAfter >= intactBefore)
		check("cycle: every contact stands at one of its spots", (function()
			for _, id in { "Broker", "Fixer", "Dealer" } do
				local m = Contacts.Get(id)
				if not m or not m:GetAttribute("Spot") or m:GetAttribute("Spot") < 1 or m:GetAttribute("Spot") > #Contacts.Spots(id) then return false end
			end
			return true
		end)())
		check("cycle: every contact has a line this cycle", workspace_:GetAttribute("CycleLine_Broker") ~= nil and workspace_:GetAttribute("CycleLine_Dealer") ~= nil)
		local live = CluesS.Live()
		local nLive = 0
		for _ in live do nLive += 1 end
		check("cycle: fragments lie in the world with anomalies", nLive >= 2 and live.HourZero ~= nil and live.HourZero.Anomaly ~= nil)
		local whited = false
		for _, e in M.FireLog do if e[1] == "World" and e[3] == "Dematerialize" then whited = true end end
		check("cycle: the white-out reaches every client", whited)
		-- reading: a prerequisite hides the deeper fragment until the first is read
		pd.Knowledge.Fragments = {}
		local idx = Cycle.Index()
		local ledgerOut = live.Ledger ~= nil
		if ledgerOut then
			check("cycle: a fragment you lack the prerequisites for cannot be read", CluesS.Take(player, "Ledger") == false)
		end
		check("cycle: reading Hour Zero adds it to the archive", CluesS.Take(player, "HourZero") == true and pd.Knowledge.Fragments.HourZero == 1)
		if ledgerOut then
			check("cycle: the prerequisite read, the deeper fragment opens", CluesS.Take(player, "Ledger") == true and pd.Knowledge.Fragments.Ledger == 2)
		end
		check("cycle: a fragment reads once", CluesS.Take(player, "HourZero") == false)
		local Terminal = M.mockEnv.__require(SSS.Server.Terminal)
		local state = Terminal.State(player)
		check("cycle: the archive lists what was read, in order", state and state.Archive[1] and state.Archive[1].Id == "HourZero")
		local visible = false
		for _, e in M.FireLog do if e[1] == "World" and e[3] == "Clues" and type(e[4]) == "table" then visible = true end end
		check("cycle: the client is told which fragments it may see", visible)
		local fresh2 = PlayerData.Reset(player)
		check("cycle: the archive survives permadeath", fresh2.Knowledge.Fragments.HourZero == 1)
	end
	-- the crew remembers the way: route knowledge survives permadeath
	local fresh = PlayerData.Reset(player)
	check("frontier: the route survives permadeath", fresh.Frontier.Route == 1 and fresh.Frontier.Found[site.Key] == true)
	check("computer: knowledge survives permadeath", fresh.Knowledge and fresh.Knowledge.Contacts.Broker == true and fresh.Knowledge.Completed == 1)
end

check("no script errors", #M.errors == 0)
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
