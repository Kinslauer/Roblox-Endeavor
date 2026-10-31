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

check("no script errors", #M.errors == 0)
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
