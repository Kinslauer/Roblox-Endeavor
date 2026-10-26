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
do -- Tutorial v2 lore: the creator and the first tutorial step each speak one line
	local Lore = M.mockEnv.__require(RS.Shared.Lore)
	local seen = {}
	for _, e in M.FireLog do if e[1] == "Announce" and e[4] == "Lore" then seen[e[3]] = true end end -- FireClient log: {name, "client", text, kind}
	check("lore lines at the creator and wake-up beats", seen[Lore.Get("Creator")] == true and seen[Lore.Get("WakeUp")] == true)
end

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
do
	local readySeen = false
	for _, e in M.FireLog do if e[1] == "PhaseChanged" and e[3] == "Ready" then readySeen = true end end
	check("ready players get the waiting screen signal", readySeen)
end
check("world opens after tutorial", run(60, function() return workspace_:GetAttribute("Phase") == "Open" end))
check("emergence time was published for the countdown", workspace_:GetAttribute("EmergenceAt") ~= nil)
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
c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, -4), M.V3.new(120, 5, 0))
local before = c2.Humanoid.Health
Remotes.Attack:FireServer(); run(0.8)
check("spawn protection: a fresh character cannot be hit", c2.Humanoid.Health == before and c2:FindFirstChild("SpawnProtection") ~= nil)
-- the rival swings (at nothing): offensive action forfeits protection
as(p2); Remotes.Attack:FireServer(); run(0.1); as(player)
check("attacking forfeits spawn protection", c2:FindFirstChild("SpawnProtection") == nil)
run(1)
Remotes.Attack:FireServer(); run(0.8)
check("PvP hit lands in the open world", c2.Humanoid.Health < before)
-- District 1: generated city, spawn pads, and the plaza safe zone that refuses damage in or out
do
	local District = M.mockEnv.__require(RS.Shared.District)
	local DistrictServer = M.mockEnv.__require(SSS.Server.District)
	local CS = game_:GetService("CollectionService")
	check("district built with its spawn pads", workspace_:FindFirstChild("District") ~= nil and DistrictServer.Built and DistrictServer.Built.Spawns == District.Spawns.Count)
	check("arena pads are not CitySpawns in default dev config", #CS:GetTagged("CitySpawn") == District.Spawns.Count)
	check("safe zone marker tagged with its radius", #CS:GetTagged("SafeZone") == 1 and CS:GetTagged("SafeZone")[1]:GetAttribute("Radius") == District.SafeZone.Radius)
	check("plaza centre is inside, a street pad is outside", District.InSafeZone(M.V3.new(0, 5, 0)) and not District.InSafeZone(M.V3.new(120, 5, 0)))
	-- both inside the plaza: nothing lands
	local hp = c2.Humanoid.Health
	c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, 0), M.V3.new(0, 5, -4))
	c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(0, 5, -4), M.V3.new(0, 5, 0))
	run(1.2); Remotes.Attack:FireServer(); run(0.8)
	check("no damage inside the safe zone", c2.Humanoid.Health == hp)
	-- attacker outside, victim just inside the ring: still refused
	c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(District.SafeZone.Radius + 2, 5, 0), M.V3.new(District.SafeZone.Radius - 2, 5, 0))
	c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(District.SafeZone.Radius - 2, 5, 0), M.V3.new(District.SafeZone.Radius + 2, 5, 0))
	run(1.2); Remotes.Attack:FireServer(); run(0.8)
	check("no damage into the safe zone from outside", c2.Humanoid.Health == hp)
	-- back to the street for the rest of the scenario
	c1.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, -4), M.V3.new(120, 5, 0))
	run(1.2)
end
-- aimed shots: a ranged attack follows a client aim direction inside Config.Combat.AimCone (pitch too)
do
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	as(player)
	local me = player.Character
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -10)) -- facing -Z
	Inventory.Add(player, "ArcPistol", 1)
	Remotes.EquipItem:FireServer("ArcPistol"); run(0.5)
	check("arc pistol equipped", me:GetAttribute("Weapon") == "ArcPistol")
	local function lastBolt(n) for i = #M.FireLog, n + 1, -1 do local e = M.FireLog[i] if e[1] == "CombatEvent" and e[3] == "Bolt" then return e[5] end end return nil end
	local mark = #M.FireLog
	Remotes.Attack:FireServer(M.V3.new(0, 0.5, -0.866)); run(0.6) -- 30 degrees up, straight ahead
	local up = lastBolt(mark)
	check("aimed shot follows the camera pitch", up ~= nil and up.Y > 30)
	run(1)
	mark = #M.FireLog
	Remotes.Attack:FireServer(M.V3.new(0, 0, 1)); run(0.6) -- behind the body: outside the cone
	local back = lastBolt(mark)
	check("aim outside the cone falls back to the body's facing", back ~= nil and back.Z < 0 and math.abs(back.Y - 5) < 3) -- flat, ahead
	run(1)
	Remotes.EquipItem:FireServer("PipeClub"); run(0.5)
end
-- The Range (Universe 2 prototype): Rift travel, forced first person, rifle, ranged-only, targets, waves
do
	local Range = M.mockEnv.__require(SSS.Server.Range)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	as(player)
	local me = player.Character
	check("range built with its targets", workspace_:FindFirstChild("Range") ~= nil and Range.Built and Range.Built.Targets == #Config.Range.Targets.Distances)
	local entered = Range.Enter(player)
	run(0.5)
	local pos = me.HumanoidRootPart.CFrame.Position
	check("rift takes you to the range firing line", entered and (pos - (Config.Range.Origin + M.V3.new(0, 2, 70))).Magnitude < 20)
	check("range forces first person and marks the zone", player:GetAttribute("ForceFirstPerson") == true and player:GetAttribute("Zone") == "Range")
	check("arc rifle granted and equipped on entry", me:GetAttribute("Weapon") == "ArcRifle")
	-- melee is refused inside
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	local hp = me.Humanoid.Health
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local before = #M.FireLog
	Remotes.Attack:FireServer(); run(0.3)
	local swung = false
	for i = before + 1, #M.FireLog do local e = M.FireLog[i] if e[1] == "CombatEvent" and e[3] == "Swing" and e[4] == me then swung = true end end
	check("melee swing refused in the range", not swung)
	Remotes.EquipItem:FireServer("ArcRifle"); run(0.3)
	-- shoot the nearest target (20 studs down the lane): aim straight at it
	local target
	for _, m in workspace_.Range:GetChildren() do if m.Name == "Target 20" then target = m end end
	check("20-stud target exists", target ~= nil)
	local hp0 = target.Humanoid.Health
	me:PivotTo(M.CF.lookAt(target.HumanoidRootPart.Position + M.V3.new(0, 0, 20), target.HumanoidRootPart.Position)) -- PivotTo moves the Head too (aimed shots start there)
	local dir = (target.HumanoidRootPart.Position - me.Head.Position).Unit
	local mark2 = #M.FireLog
	for _ = 1, 4 do Remotes.Attack:FireServer(dir); run(0.4) end
	check("rifle shots knock the target down", target.Humanoid.Health < hp0)
	-- back through the rift
	Range.Leave(player); run(0.3)
	check("rift back clears the zone flags", player:GetAttribute("Zone") == nil and player:GetAttribute("ForceFirstPerson") == nil)
	Combat.ClearProtection(me) -- travel protection would otherwise swallow the enemy checks below
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	run(0.5)
end
-- sprint: shift speeds the body up and drains stamina; releasing restores both
do
	as(player)
	local me = player.Character
	local Gear = M.mockEnv.__require(SSS.Server.Gear)
	local base = Gear.OfChar(me).WalkSpeed
	local st0 = me:GetAttribute("Stamina")
	Remotes.Sprint:FireServer(true); run(1.0)
	check("sprint multiplies walk speed", math.abs(me.Humanoid.WalkSpeed - base * 1.45) < 0.05 and me:GetAttribute("Sprinting") == true)
	check("sprint drains stamina", me:GetAttribute("Stamina") < st0)
	Remotes.Sprint:FireServer(false); run(0.3)
	check("sprint off restores walk speed", math.abs(me.Humanoid.WalkSpeed - base) < 0.05 and me:GetAttribute("Sprinting") == false)
end
-- rate limit: a burst of 40 Attack remotes is cut to the configured budget
do
	local RateLimit = M.mockEnv.__require(SSS.Server.RateLimit)
	local allowed = 0
	for _ = 1, 40 do if RateLimit.Allow(player, "ProbeRemote", 6) then allowed += 1 end end
	check("rate limit caps a 40-call burst at rate*burst", allowed == 12)
end
-- Enemy v2: a Grunt telegraphs (Swing) before it can hit, and a timed block parries it
do
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Enemies = M.mockEnv.__require(RS.Shared.Enemies)
	local me = player.Character
	-- park the rival far away so the grunt picks us
	c2.HumanoidRootPart.CFrame = M.CF.new(400, 5, 400)
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(50, 5, 50), M.V3.new(50, 5, 46))
	local function eventsSince(n) local out = {} for i = n + 1, #M.FireLog do table.insert(out, M.FireLog[i]) end return out end
	local mark = #M.FireLog
	local hpBefore = me.Humanoid.Health
	local spawnedAt = M.setNow()
	local grunt = NPCs.Spawn("Grunt", M.V3.new(50, 5, 46)) -- in range: its AI swings on the first tick
	check("grunt spawned with a Weapon attribute", grunt ~= nil and grunt:GetAttribute("Weapon") == "PipeClub")
	local swung = false
	run(1, function()
		for _, e in eventsSince(mark) do if e[1] == "CombatEvent" and e[3] == "Swing" and e[4] == grunt then swung = true return true end end
		return false
	end)
	check("grunt attacks through Combat.Swing (Swing event emitted)", swung)
	local windup = Enemies.Defs.Grunt.Attack.Windup
	local elapsed = M.setNow() - spawnedAt
	run(math.max(0, windup * 0.8 - elapsed))
	check("no damage before the windup ends", me.Humanoid.Health == hpBefore)
	-- block now: inside the parry window (ParryWindow 0.22 >= the ~0.12 s left of the windup)
	Remotes.Block:FireServer(true); run(0.5); Remotes.Block:FireServer(false)
	local parried = false
	for _, e in eventsSince(mark) do if e[1] == "CombatEvent" and e[3] == "Parry" and e[4] == me then parried = true end end
	check("timed block parries the grunt", parried and me.Humanoid.Health == hpBefore)
	local gs = M.mockEnv.__require(SSS.Server.Combat).State(grunt)
	check("parried grunt is stunned", gs.stunned > M.setNow())
	grunt.Humanoid.Health = 0; run(0.5)
	check("grunt death drops spoils", workspace_:FindFirstChild("Lootable", true) ~= nil)
	-- poise: a Grunt shrugs off the first light hit and staggers on the second; a heavy always staggers
	do
		local Combat2 = M.mockEnv.__require(SSS.Server.Combat)
		local g2 = NPCs.Spawn("Grunt", M.V3.new(300, 5, 300))
		me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(300, 5, 304), M.V3.new(300, 5, 300))
		Combat2.Damage(me, g2, 5, {})
		local s2 = Combat2.State(g2)
		local firstStunned = s2.stunned > M.setNow()
		Combat2.Damage(me, g2, 5, {})
		local secondStunned = s2.stunned > M.setNow()
		check("poise: first light hit does not stagger a Grunt, second does", not firstStunned and secondStunned)
		run(1.5)
		Combat2.Damage(me, g2, 5, { Staggers = true })
		check("poise: a heavy (Staggers) always staggers", s2.stunned > M.setNow())
		g2:Destroy()
	end
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	c2.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, -4), M.V3.new(120, 5, 0))
end

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
