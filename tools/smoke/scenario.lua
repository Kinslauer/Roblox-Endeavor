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
	local nd = #District.Districts
	check("districts built with their spawn pads", workspace_:FindFirstChild("District") ~= nil and DistrictServer.Built and DistrictServer.Built.Spawns == District.Spawns.Count and DistrictServer.Built.Districts == 2)
	check("arena pads are not CitySpawns in default dev config", #CS:GetTagged("CitySpawn") == District.Spawns.Count * nd)
	local plazaZones = 0
	for _, z in CS:GetTagged("SafeZone") do if z:GetAttribute("District") and z:GetAttribute("Radius") == District.SafeZone.Radius then plazaZones += 1 end end
	check("one plaza safe zone per district, tagged with its radius", plazaZones == nd)
	check("plaza centre is inside, a street pad is outside", District.InSafeZone(M.V3.new(0, 5, 0)) and not District.InSafeZone(M.V3.new(120, 5, 0)))
	-- District 2: its own plaza at the pitch, a gate street joining the two, spawn pads split by Awakened
	do
		local d2 = District.Districts[2]
		local inside, zone = District.InSafeZone(d2.Origin + M.V3.new(0, 5, 0))
		check("district 2 plaza is a safe zone with its own name", inside and zone:GetAttribute("ZoneName") == d2.Plaza)
		check("District.At tells the districts apart", District.At(M.V3.new(0, 5, 0)) == 1 and District.At(d2.Origin) == 2 and District.At(M.V3.new(District.Pitch() / 2, 5, 0)) == nil)
		local gate
		for _, p in workspace_.District:GetChildren() do
			if p.Name == "GateStreet" then gate = p end
		end
		check("gate street is a PlayableArea slab between the walls", gate ~= nil and CS:HasTag(gate, "PlayableArea") and gate.Position.X > District.Extent() / 2 and gate.Position.X < d2.Origin.X - District.Extent() / 2)
		local fresh, awakened = 0, 0
		for _, pad in CS:GetTagged("CitySpawn") do
			if pad:GetAttribute("SpawnFor") == "Fresh" then fresh += 1 elseif pad:GetAttribute("SpawnFor") == "Awakened" then awakened += 1 end
		end
		check("spawn pads split Fresh / Awakened", fresh == District.Spawns.Count and awakened == District.Spawns.Count)
		local WorldPhase = M.mockEnv.__require(SSS.Server.WorldPhase)
		local PlayerData = M.mockEnv.__require(SSS.Server.PlayerData)
		local prof = PlayerData.Get(player)
		local was = prof.Awakened
		prof.Awakened = false
		local freshCF = WorldPhase.GetSpawnCFrame(player)
		prof.Awakened = true
		local awakeCF = WorldPhase.GetSpawnCFrame(player)
		prof.Awakened = was
		check("fresh profiles spawn in District 1, Awakened ones in District 2", District.At(freshCF.Position) == 1 and District.At(awakeCF.Position) == 2)
	end
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
	-- back through the rift: the war lets you out into the hideout (Phase 3), first person released
	Range.Leave(player); run(0.3)
	check("rift back lands in the hideout, first person released", player:GetAttribute("Zone") == "Hideout" and player:GetAttribute("ForceFirstPerson") == nil)
	M.mockEnv.__require(SSS.Server.Hideout).Leave(player); run(0.2)
	check("hideout -> city clears the zone", player:GetAttribute("Zone") == nil)
	Combat.ClearProtection(me) -- travel protection would otherwise swallow the enemy checks below
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	run(0.5)
end
-- Gunplay (design/gdd/gunplay.md): magazines + reload, ADS state, hit zones, spread
do
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Weapons = M.mockEnv.__require(RS.Shared.Weapons)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	as(player)
	local me = player.Character
	local gun = Weapons.Defs.ArcRifle.Gun
	Combat.State(me).ammo.ArcRifle = nil -- the Range block spent some: start full
	Remotes.EquipItem:FireServer("ArcRifle"); run(0.3)
	check("ammo attributes follow the equipped gun", me:GetAttribute("Ammo") == gun.Magazine and me:GetAttribute("MaxAmmo") == gun.Magazine)
	me:PivotTo(M.CF.lookAt(M.V3.new(600, 5, 600), M.V3.new(600, 5, 590))) -- empty ground, facing -Z
	me:SetAttribute("Stamina", 100)
	for _ = 1, 3 do Remotes.Attack:FireServer(M.V3.new(0, 0, -1)); run(0.5) end -- End 0.30 + ComboCooldown 0.15 between shots
	check("each shot spends a round", me:GetAttribute("Ammo") == gun.Magazine - 3)
	run(0.5)
	Remotes.Heavy:FireServer(M.V3.new(0, 0, -1)); run(0.8)
	check("the charged shot burns three rounds", me:GetAttribute("Ammo") == gun.Magazine - 6)
	run(0.6)
	Remotes.Reload:FireServer(); run(0.1)
	check("reload marks the character", me:GetAttribute("Reloading") == true)
	local during = me:GetAttribute("Ammo")
	Remotes.Attack:FireServer(M.V3.new(0, 0, -1)); run(0.1)
	check("no shot while reloading", me:GetAttribute("Ammo") == during)
	run(gun.Reload + 0.1)
	check("magazine full after Reload seconds", me:GetAttribute("Ammo") == gun.Magazine and me:GetAttribute("Reloading") == false)
	Combat.State(me).ammo.ArcRifle = 0; Combat.SyncAmmo(me)
	Remotes.Attack:FireServer(M.V3.new(0, 0, -1)); run(0.1)
	check("an empty click starts a reload on its own", me:GetAttribute("Reloading") == true)
	run(gun.Reload + 0.2)
	-- ADS is a server-visible state; sprinting drops the sights
	Remotes.ADS:FireServer(true); run(0.1)
	check("ADS attribute set from the sights remote", me:GetAttribute("ADS") == true)
	Remotes.Sprint:FireServer(true); run(0.2)
	check("sprinting drops the sights", me:GetAttribute("ADS") == false)
	Remotes.Sprint:FireServer(false); run(0.3)
	-- hit zones: the same shot on the Head does Zones.Head times the body damage (sights up: tight spread)
	me:SetAttribute("Stamina", 100)
	local g = NPCs.Spawn("Grunt", M.V3.new(600, 5, 580))
	Combat.State(g).stunned = M.setNow() + 30 -- holds still, and cannot shoot back
	Remotes.ADS:FireServer(true); run(Config.Gunplay.Spread.ADSSettle + 0.1)
	local hp0 = g.Humanoid.Health
	Remotes.Attack:FireServer((g.HumanoidRootPart.Position - me.Head.Position).Unit); run(0.4)
	local bodyLoss = hp0 - g.Humanoid.Health
	hp0 = g.Humanoid.Health
	local mark = #M.FireLog
	Remotes.Attack:FireServer((g.Head.Position - me.Head.Position).Unit); run(0.4)
	local headLoss = hp0 - g.Humanoid.Health
	local headshot = false
	for i = mark + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "Headshot" and e[4] == g then headshot = true end end
	check("headshot multiplies damage by Zones.Head", bodyLoss > 0 and math.abs(headLoss / bodyLoss - Config.Gunplay.Zones.Head) < 0.05 and headshot)
	Remotes.ADS:FireServer(false); run(0.1)
	g:Destroy()
	-- spread: hip shots at the same aim do not all land on the same point
	local ends = {}
	for _ = 1, 5 do
		local m0 = #M.FireLog
		Remotes.Attack:FireServer(M.V3.new(0, 0, -1)); run(0.5)
		for i = m0 + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "Bolt" and e[4] == me then table.insert(ends, e[5]) end end
	end
	local scattered = false
	for i = 2, #ends do if (ends[i] - ends[1]).Magnitude > 0.5 then scattered = true end end
	check("hip fire scatters inside the spread cone", #ends >= 4 and scattered)
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	check("melee weapon clears the ammo counter", me:GetAttribute("Ammo") == nil)
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	run(0.5)
end
-- Hideout (design/phase-3-brief.md, build order 1): extraction hubs, the room, stash, wallet, faction, deploy/return
do
	local Hideout = M.mockEnv.__require(SSS.Server.Hideout)
	local Range = M.mockEnv.__require(SSS.Server.Range)
	local Wallet = M.mockEnv.__require(SSS.Server.Wallet)
	local PlayerData = M.mockEnv.__require(SSS.Server.PlayerData)
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	local District = M.mockEnv.__require(RS.Shared.District)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	local CS = game_:GetService("CollectionService")
	as(player)
	local me = player.Character
	local data = PlayerData.Get(player)
	check("hideout built with one station per district", workspace_:FindFirstChild("Hideout") ~= nil and Hideout.Built and Hideout.Built.Hubs == #District.Districts and #CS:GetTagged("ExtractHub") == #District.Districts)
	local hubPos = CS:GetTagged("ExtractHub")[1].Position
	check("the station stands inside its district's footprint", District.At(hubPos) == 1)
	-- extraction is refused mid-fight, allowed otherwise
	player:SetAttribute("LastCombat", M.setNow())
	check("no extraction while in combat", Hideout.Extract(player) == false and player:GetAttribute("Zone") == nil)
	player:SetAttribute("LastCombat", nil)
	local ok = Hideout.Extract(player)
	local pos = me.HumanoidRootPart.Position
	check("extracting takes you to the hideout", ok and player:GetAttribute("Zone") == "Hideout" and (pos - Config.Hideout.Origin).Magnitude < Config.Hideout.Size and data.Location == "Hideout")
	check("the hideout is a safe zone", District.InSafeZone(pos) == true)
	-- stash: everything not worn goes in, survives a wipe, comes back out
	Inventory.Add(player, "Wire", 5)
	local before = Inventory.Count(player, "Wire")
	local moved = Hideout.DepositAll(player)
	check("deposit moves unworn items into the stash", moved >= before and Inventory.Count(player, "Wire") == 0 and (data.Stash.Wire or 0) >= before and Inventory.Count(player, data.Equipped) == 1)
	-- wallet + faction
	Wallet.Add(player, 120)
	check("wallet pays into the Money attribute", Wallet.Get(player) == 120 and player:GetAttribute("Money") == 120)
	check("deploy refused without a side", Hideout.Deploy(player) == false and player:GetAttribute("Zone") == "Hideout")
	check("faction chosen at the hideout", Hideout.SetFaction(player, "Ashen") and data.Faction == "Ashen" and player:GetAttribute("Faction") == "Ashen")
	check("changing sides costs money", Hideout.SetFaction(player, "Meridian") and Wallet.Get(player) == 120 - Config.War.SwitchCost)
	-- deploy -> the Range (stand-in war world), leave -> back home, not the plaza
	check("deploy from the hideout enters the war zone", Hideout.Deploy(player) and player:GetAttribute("Zone") == "Range")
	Range.Leave(player); run(0.2)
	check("leaving the war returns to the hideout", player:GetAttribute("Zone") == "Hideout" and (me.HumanoidRootPart.Position - Config.Hideout.Origin).Magnitude < Config.Hideout.Size)
	-- persistence: money, stash and faction survive a permadeath wipe; Location does not
	local stashWire = data.Stash.Wire
	PlayerData.Reset(player)
	data = PlayerData.Get(player)
	check("money, stash and faction survive the wipe", data.Money == 120 - Config.War.SwitchCost and data.Stash.Wire == stashWire and data.Faction == "Meridian" and data.Location == "City")
	local back = Hideout.WithdrawAll(player)
	check("withdraw empties the stash into the inventory", back >= stashWire and Inventory.Count(player, "Wire") >= stashWire and next(data.Stash) == nil)
	-- back to the city for the rest of the scenario
	Hideout.Leave(player); run(0.2)
	check("return to the city leaves the hideout zone", player:GetAttribute("Zone") == nil and District.At(me.HumanoidRootPart.Position) ~= nil)
	M.mockEnv.__require(SSS.Server.Combat).ClearProtection(me)
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	run(0.5)
end
-- The war (design/gdd/war.md, Phase 3 build order 2): three sides, the moving hill, tickets, recruits, downed/revive, redeploy
do
	local War = M.mockEnv.__require(SSS.Server.War)
	local Hideout = M.mockEnv.__require(SSS.Server.Hideout)
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local Wallet = M.mockEnv.__require(SSS.Server.Wallet)
	local PlayerData = M.mockEnv.__require(SSS.Server.PlayerData)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	local CS = game_:GetService("CollectionService")
	as(player)
	local me = player.Character
	local data = PlayerData.Get(player)
	local W = Config.War
	check("war built: three bases and a hill", workspace_:FindFirstChild("War") ~= nil and #CS:GetTagged("WarBase") == 3 and #CS:GetTagged("WarHill") == 1 and workspace_:GetAttribute("War_Round") == 1)
	-- deploy from the hideout to your side's base
	Hideout.Extract(player); run(0.2)
	check("deploy puts you at your side's base, deployed and first person", Hideout.Deploy(player) and player:GetAttribute("Zone") == "Range" and me:GetAttribute("Deployed") == true and player:GetAttribute("ForceFirstPerson") == true and (me.HumanoidRootPart.Position - War.Sides()[data.Faction].Base).Magnitude < 10)
	Combat.ClearProtection(me)
	-- recruits arrive in pods for every side
	run(W.PodFallSeconds + 6)
	local alive = 0
	for _, side in War.Sides() do alive += side.Alive end
	check("pods opened into recruits on every side", alive >= 3 * math.min(W.Squad, W.MaxRecruitsPerSide) and workspace_:GetAttribute("War_Recruits_" .. data.Faction) >= W.Squad)
	-- friendly fire: an own-side recruit cannot hurt you, an enemy recruit can
	local mine, theirs
	for id, side in War.Sides() do for model in side.Recruits do if id == data.Faction then mine = mine or model else theirs = theirs or model end end end
	local hp = me.Humanoid.Health
	check("no friendly fire inside the war", Combat.Damage(mine, me, 10, {}) == "none" and me.Humanoid.Health == hp)
	check("the other sides can hurt you", Combat.Damage(theirs, me, 10, {}) == "hit" and me.Humanoid.Health < hp)
	-- the hill: stand on it alone -> your side takes it; the holder drains the others
	local hill = War.Hill()
	me.Humanoid.Health = me.Humanoid.MaxHealth
	Combat.Protect(me, 60) -- the recruits around the hill would otherwise kill the tester mid-check
	me:PivotTo(M.CF.new(hill.Position + M.V3.new(0, 3, 0)))
	local money0 = Wallet.Get(player)
	local ticketsBefore = {}
	for id, side in War.Sides() do ticketsBefore[id] = side.Tickets end
	run(W.CaptureSeconds + 1.5)
	check("a side alone on the hill captures it", hill.Owner == data.Faction and workspace_:GetAttribute("War_HillOwner") == data.Faction)
	check("zone time pays", Wallet.Get(player) > money0)
	run(W.HillDrainSeconds * 2 + 0.6)
	local drained = true
	for id, side in War.Sides() do if id ~= data.Faction and side.Tickets >= ticketsBefore[id] then drained = false end end
	check("holding the hill drains the other sides' tickets", drained and War.Sides()[data.Faction].Tickets == ticketsBefore[data.Faction])
	-- downed, then revived by an ally
	Combat.ClearProtection(me)
	me.Humanoid.Health = 10
	local r = Combat.Damage(theirs, me, 50, {})
	check("a lethal hit downs a deployed player instead of killing", r == "hit" and me:GetAttribute("Downed") == true and me.Humanoid.Health > 0 and me.HumanoidRootPart:FindFirstChild("RevivePrompt") ~= nil)
	local allyMoney = 0
	check("an ally revives you", War.Revive(me, mine) and me:GetAttribute("Downed") == false and me.Humanoid.Health >= me.Humanoid.MaxHealth * W.ReviveHealthFraction - 0.01)
	-- bleed out -> a war death: a ticket, no permadeath, redeploy
	local inv = M.mockEnv.__require(SSS.Server.Inventory).Count(player, "ArcRifle")
	local level, money1 = data.Level, Wallet.Get(player)
	local ticketsMine = War.Sides()[data.Faction].Tickets
	me.Humanoid.Health = 10
	Combat.Damage(theirs, me, 50, {}) -- downed again
	run(W.DownedSeconds + 0.5) -- nobody comes: bleed out
	check("bleeding out costs a ticket, not the character", War.Sides()[data.Faction].Tickets == ticketsMine - W.DeathTickets and PlayerData.Get(player) == data and data.Level == level and Wallet.Get(player) == money1)
	run(W.RedeploySeconds + 0.5)
	confirmLook(player) -- the earlier profile reset left the creator pending for the new body (test artifact)
	run(1)
	local me2 = player.Character
	check("redeployed at the base with a fresh body", me2 ~= nil and me2 ~= me and me2:GetAttribute("Deployed") == true and player:GetAttribute("Zone") == "Range" and (me2.HumanoidRootPart.Position - War.Sides()[data.Faction].Base).Magnitude < 10)
	-- takedowns pay; leaving ends the deployment
	local money2 = Wallet.Get(player)
	theirs.Humanoid.Health = 0; run(0.5) -- credited to us? only if we were the last attacker
	Combat.Damage(me2, mine, 0, {}) -- (no-op: same side)
	War.Leave(player); run(0.3)
	check("leaving the war returns to the hideout, undeployed", player:GetAttribute("Zone") == "Hideout" and me2:GetAttribute("Deployed") == nil)
	-- Supply (design/gdd/war.md §7, build order 3): the faction pool and shipments
	do
		local Supply = M.mockEnv.__require(SSS.Server.Supply)
		local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
		local SUP = Config.Supply
		local f = data.Faction
		data.Stash = { RiotPlate = 1, Scrap = 10 }
		local pts = Supply.Donate(player)
		check("donating the stash feeds your side's pool by item value", pts == SUP.Value.Armor + 10 * SUP.Value.Material and Supply.Points(f) == pts and next(data.Stash) == nil and workspace_:GetAttribute("War_Supply_" .. f) == pts)
		Supply.AddPoints(f, SUP.Tiers[2].Points + 40 - pts)
		check("the pool's points pick the kit tier", Supply.Tier(f).Name == SUP.Tiers[2].Name and workspace_:GetAttribute("War_Tier_" .. f) == SUP.Tiers[2].Name)
		-- a new round: every side re-fields; ours draws the Armed kit and pays for it
		local poolBefore = Supply.Points(f)
		War.EndRound(); run(2 + W.PodFallSeconds + 2)
		local armed, drawn = nil, 0
		for model in War.Sides()[f].Recruits do drawn += 1; if model:GetAttribute("Kit") == SUP.Tiers[2].Name then armed = armed or model end end
		check("supplied recruits spawn with the kit and the pool pays per recruit", armed ~= nil and math.abs(armed.Humanoid.MaxHealth - 90 * SUP.Tiers[2].HealthMult) < 0.01 and armed:GetAttribute("KitResist") == SUP.Tiers[2].Resist and Supply.Points(f) == poolBefore - drawn * SUP.CostPerRecruit)
		-- a shipment: stash gear sent ahead, landing as a crate at the base
		data.Stash = { ArcPistol = 1, Medkit = 2, Scrap = 5 }
		local pistol0, medkit0 = Inventory.Count(player, "ArcPistol"), Inventory.Count(player, "Medkit") -- what the body already carries
		local shipped = Supply.Ship(player)
		check("a shipment takes shippable stash gear and leaves the materials", shipped == 3 and data.Shipment and data.Shipment.Items.ArcPistol == 1 and data.Shipment.Items.Medkit == 2 and data.Stash.ArcPistol == nil and data.Stash.Scrap == 5 and player:GetAttribute("ShipmentCount") == 3)
		check("one shipment at a time", Supply.Ship(player) == 0)
		Hideout.Deploy(player); run(0.6)
		local me3 = player.Character
		Combat.ClearProtection(me3)
		local crates = 0
		for _, d in workspace_:GetDescendants() do if d.Name == "Crate_" .. player.Name then crates += 1 end end
		check("the crate waits for the shipment's delay", crates == 0)
		data.Shipment.ReadyAt = M.mockEnv.os.time() -- the mock's clock, not the host's
		run(0.6 + SUP.CrateFallSeconds + 0.5)
		crates = 0
		for _, d in workspace_:GetDescendants() do if d.Name == "Crate_" .. player.Name then crates += 1 end end
		check("a ready shipment lands as a crate while deployed", crates == 1)
		check("opening the crate hands over the field kit and equips the gun", War.OpenCrate(player) and Inventory.Count(player, "ArcPistol") == pistol0 + 1 and Inventory.Count(player, "Medkit") == medkit0 + 2 and data.Equipped == "ArcPistol" and data.Shipment == false and player:GetAttribute("ShipmentCount") == nil)
		-- walk out alive: the kit goes home to the stash
		War.Leave(player); run(0.3)
		check("leaving alive returns the field kit to the stash", Inventory.Count(player, "ArcPistol") == pistol0 and Inventory.Count(player, "Medkit") == medkit0 and data.Stash.ArcPistol == 1 and data.Stash.Medkit == 2)
		-- ship again, open, then die: the kit stays on the field as loot
		Supply.Ship(player)
		data.Shipment.ReadyAt = M.mockEnv.os.time() -- the mock's clock, not the host's
		Hideout.Deploy(player); run(SUP.CrateFallSeconds + 1)
		local me4 = player.Character
		Combat.ClearProtection(me4)
		War.OpenCrate(player)
		local enemy
		for id, side in War.Sides() do if id ~= f then for model in side.Recruits do enemy = enemy or model end end end
		me4.Humanoid.Health = 10
		Combat.Damage(enemy, me4, 50, {})
		run(W.DownedSeconds + 0.5)
		local kitLoot = 0
		for _, d in workspace_:GetDescendants() do if d.Name == "Lootable" and tostring(d:GetAttribute("Label")):find("field kit") then kitLoot += 1 end end
		check("dying on the field forfeits the kit where you fell", Inventory.Count(player, "ArcPistol") == pistol0 and data.Stash.ArcPistol == nil and kitLoot == 1)
		run(W.RedeploySeconds + 1.5)
		War.Leave(player); run(0.3)
		check("after the forfeit you leave with nothing extra in the stash", player:GetAttribute("Zone") == "Hideout" and data.Stash.Medkit == nil)
	end
	-- The weapon bench (design/gdd/gunplay.md §4, build order 4): fit / strip parts at the hideout only
	do
		local Bench = M.mockEnv.__require(SSS.Server.Bench)
		local Gear = M.mockEnv.__require(SSS.Server.Gear)
		local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
		local Attachments = M.mockEnv.__require(RS.Shared.Attachments)
		local meB = player.Character
		if Inventory.Count(player, "ArcPistol") == 0 then Inventory.Add(player, "ArcPistol", 1) end
		for _, id in { "ExtMag", "DotSight", "Scope4x", "Suppressor", "Brake" } do Inventory.Add(player, id, 1) end
		Gear.EquipWeapon(player, "ArcPistol"); run(0.3)
		local mags, ammo0 = Inventory.Count(player, "ExtMag"), meB:GetAttribute("Ammo")
		check("fitting a magazine at the bench grows the gun's magazine (no free rounds)", Bench.Fit(player, "ArcPistol", "ExtMag") and data.Builds.ArcPistol.Magazine == "ExtMag" and Inventory.Count(player, "ExtMag") == mags - 1 and meB:GetAttribute("MaxAmmo") == 15 and meB:GetAttribute("Ammo") == math.min(ammo0, 15) and tostring(player:GetAttribute("Builds")):find("ExtMag") ~= nil)
		check("a rifle-only part does not fit a sidearm", Bench.Fit(player, "ArcPistol", "Scope4x") == false and Inventory.Count(player, "Scope4x") == 1 and data.Builds.ArcPistol.Optic == nil)
		Bench.Fit(player, "ArcPistol", "DotSight")
		local eff = Combat.WeaponDefOf(meB, "ArcPistol")
		check("an optic tightens the aimed spread the server shoots with", math.abs(eff.Gun.Spread.ADS - 0.5 * 0.6) < 0.001 and eff.Gun.Spread.Hip == 2.4)
		Bench.Fit(player, "ArcPistol", "Suppressor")
		check("fitting into a taken slot hands the old part back", Bench.Fit(player, "ArcPistol", "Brake") and data.Builds.ArcPistol.Muzzle == "Brake" and Inventory.Count(player, "Suppressor") == 1 and Inventory.Count(player, "Brake") == 0)
		check("stripping a slot returns the part and clamps the magazine", Bench.Strip(player, "ArcPistol", "Magazine") and Inventory.Count(player, "ExtMag") == mags and meB:GetAttribute("MaxAmmo") == 9 and meB:GetAttribute("Ammo") == 9)
		check("stripping to the frame clears the build", Bench.StripAll(player, "ArcPistol") and data.Builds.ArcPistol == nil and Inventory.Count(player, "DotSight") == 1 and Inventory.Count(player, "Brake") == 1 and (tostring(player:GetAttribute("Builds")) == "{}" or tostring(player:GetAttribute("Builds")) == "[]"))
		check("the bench describes every slot", #Attachments.Describe(nil) == #Attachments.Slots)
		Hideout.Leave(player); run(0.2)
		check("no bench work outside the hideout", Bench.Fit(player, "ArcPistol", "ExtMag") == false and data.Builds.ArcPistol == nil)
		Hideout.Enter(player, { Quiet = true }); run(0.2)
	end
	-- back to the city for the rest of the scenario
	Hideout.Leave(player); run(0.2)
	Combat.ClearProtection(player.Character)
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	player.Character.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4))
	run(0.5)
end
-- Momentum (design/gdd/momentum.md): dodge-cancel keeps the combo, side dodges last longer, Snatch and Buster
do
	as(player)
	local me = player.Character
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Gear = M.mockEnv.__require(SSS.Server.Gear)
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	me:PivotTo(M.CF.lookAt(M.V3.new(200, 5, 200), M.V3.new(200, 5, 190))) -- facing -Z, empty street
	run(1)
	-- 1. combo survives a dodge: swing, dodge in the recovery, swing again -> combo index 2
	Remotes.Attack:FireServer(); run(0.35)
	Remotes.Dodge:FireServer(M.V3.new(1, 0, 0)); run(0.3)
	Remotes.Attack:FireServer(); run(0.1)
	local st = Combat.State(me)
	check("combo survives a dodge-cancel (next swing is combo 2)", st.combo == 2)
	run(1.5)
	-- 2. side dodge i-frames > back-step i-frames
	run(1)
	Remotes.Dodge:FireServer(M.V3.new(1, 0, 0)); local sideFrames = Combat.State(me).iframes - M.setNow()
	run(1.2)
	Remotes.Dodge:FireServer(M.V3.new(0, 0, 1)); local backFrames = Combat.State(me).iframes - M.setNow()
	check("side dodge has longer i-frames than a back-step", sideFrames > backFrames * 1.2)
	run(1.2)
	-- 3. Hop refund: a dodge that absorbs a hit gives stamina back
	local grunt = NPCs.Spawn("Grunt", M.V3.new(200, 5, 194))
	run(0.2)
	me:SetAttribute("Stamina", 50)
	Remotes.Dodge:FireServer(M.V3.new(1, 0, 0))
	local afterCost = me:GetAttribute("Stamina")
	Combat.Damage(grunt, me, 10, {})
	check("hop: a dodged hit refunds stamina", me:GetAttribute("Stamina") >= afterCost + Config.Momentum.HopRefund - 0.01)
	-- 4. Snatch pulls the grunt in and stuns it
	local SkillRunner = M.mockEnv.__require(SSS.Server.SkillRunner)
	local data = M.mockEnv.__require(SSS.Server.PlayerData).Get(player)
	data.Stats.Agility, data.Stats.Strength = 10, 10
	Gear.Recompute(player)
	data.SkillSlots["2"], data.SkillSlots["3"] = "Snatch", "Buster"
	run(1.2)
	grunt:PivotTo(M.CF.new(200, 5, 184)) -- 16 studs ahead
	me:SetAttribute("Stamina", 100)
	local gs = Combat.State(grunt)
	run(0.5)
	Remotes.UseSkill:FireServer(2); run(0.1)
	check("snatch stuns the target", gs.stunned > M.setNow())
	local v = grunt.HumanoidRootPart.AssemblyLinearVelocity
	check("snatch pulls the target toward the user", v ~= nil and v.Z > 10)
	-- 5. Buster: throw on a stunned target (big damage, posture reset); shove on a standing one
	grunt:PivotTo(M.CF.new(200, 5, 196)); grunt:SetAttribute("Posture", 30)
	local hp = grunt.Humanoid.Health
	run(0.6)
	gs.stunned = M.setNow() + 2 -- open
	Remotes.UseSkill:FireServer(3); run(0.1)
	check("buster throws an open target (heavy damage, posture reset)", grunt.Humanoid.Health <= hp - 30 and grunt:GetAttribute("Posture") == 0)
	grunt:PivotTo(M.CF.new(200, 5, 150)) -- out of its reach while the cooldown runs (it has 12 s of free hits otherwise)
	run(12) -- cooldown
	gs.stunned = 0; gs.brokenAt = nil
	local ms = Combat.State(me)
	ms.stunned, ms.busyUntil = 0, 0
	me.Humanoid.Health = me.Humanoid.MaxHealth
	hp = grunt.Humanoid.Health
	me:SetAttribute("Stamina", 100)
	me:PivotTo(M.CF.lookAt(M.V3.new(200, 5, 200), M.V3.new(200, 5, 190)))
	grunt:PivotTo(M.CF.new(200, 5, 196))
	Remotes.UseSkill:FireServer(3); run(0.1)
	local lost = hp - grunt.Humanoid.Health
	check("buster only shoves a standing target", lost > 0 and lost < 20)
	grunt:Destroy()
	-- 6. Launcher + juggle (momentum.md 2.5): a melee heavy on an open enemy launches it; hits while
	-- airborne pop it and deal bonus damage; a dodge next to it is an Enemy Step
	do
		local Enemies = M.mockEnv.__require(RS.Shared.Enemies)
		local Weapons = M.mockEnv.__require(RS.Shared.Weapons)
		run(1.5)
		Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
		me:PivotTo(M.CF.lookAt(M.V3.new(200, 5, 200), M.V3.new(200, 5, 190)))
		me:SetAttribute("Stamina", 100)
		local g3 = NPCs.Spawn("Grunt", M.V3.new(200, 5, 194))
		local s3 = Combat.State(g3)
		s3.stunned = M.setNow() + 5 -- open (stunned): the launch condition
		local mark = #M.FireLog
		Remotes.Heavy:FireServer(); run(Weapons.Defs.PipeClub.Heavy.Windup + 0.15)
		local v = g3.HumanoidRootPart.AssemblyLinearVelocity
		check("heavy on an open enemy launches it", g3:GetAttribute("Juggled") == true and v ~= nil and v.Y >= Config.Momentum.LaunchVelocity - 0.01)
		local launched = false
		for i = mark + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "Launch" and e[4] == g3 then launched = true end end
		check("Launch event fired for the client", launched)
		-- a plain hit while airborne: bonus damage + a pop
		local hp = g3.Humanoid.Health
		Combat.Damage(me, g3, 10, {})
		check("airborne target takes bonus damage and pops back up", math.abs((hp - g3.Humanoid.Health) - 10 * Config.Momentum.AirDamageMult) < 0.5 and g3.HumanoidRootPart.AssemblyLinearVelocity.Y >= Config.Momentum.AirPopVelocity - 0.01 and s3.juggleHits == 1)
		-- Enemy Step: dodge next to it -> stamina back and an upward DodgeMove
		me:SetAttribute("Stamina", 50)
		mark = #M.FireLog
		Remotes.Dodge:FireServer(M.V3.new(1, 0, 0)); run(0.05)
		local hop
		for i = mark + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "DodgeMove" then hop = e[4] end end
		check("enemy step: dodge off an airborne enemy hops and refunds stamina", hop ~= nil and hop.Y >= Config.Momentum.EnemyStepHop - 0.01 and me:GetAttribute("Stamina") >= 50 - Config.Combat.DodgeCost + Config.Momentum.EnemyStepRefund - 0.01)
		run(Config.Momentum.LaunchAirTime + Config.Momentum.AirPopExtend + 0.3)
		check("juggle ends: Juggled cleared on landing", g3:GetAttribute("Juggled") == false and not Combat.IsJuggled(g3))
		-- a heavy on a standing enemy does not launch
		run(Config.Combat.HeavyCooldown + 0.5)
		s3.stunned = 0; s3.brokenAt = nil
		me:SetAttribute("Stamina", 100)
		Remotes.Heavy:FireServer(); run(Weapons.Defs.PipeClub.Heavy.Windup + 0.15)
		check("heavy on a standing enemy only staggers", g3:GetAttribute("Juggled") == false)
		g3:Destroy()
	end
	me:PivotTo(M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4)))
	data.SkillSlots["2"], data.SkillSlots["3"] = nil, nil
	run(1)
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
		me.Humanoid.Health = me.Humanoid.MaxHealth -- the earlier grunt had 12 s on us during the Buster cooldown
		me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(300, 5, 312), M.V3.new(300, 5, 300)) -- outside its 7-stud reach
		local g2 = NPCs.Spawn("Grunt", M.V3.new(300, 5, 300))
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
	-- Drone: a flying body (no Weapon attribute, flight constraints), spawns Hover studs up, shoots
	-- through Combat.Swing from the air, and its spoils land on the ground
	do
		local hp = me.Humanoid.Health
		local spawnMark = #M.FireLog
		me.HumanoidRootPart.CFrame = M.CF.lookAt(M.V3.new(500, 5, 500), M.V3.new(500, 5, 496))
		local drone = NPCs.Spawn("Drone", M.V3.new(500, 5, 480))
		check("drone spawned as a flyer without a weapon", drone ~= nil and drone:GetAttribute("Flying") == true and drone:GetAttribute("Weapon") == nil and drone.HumanoidRootPart:FindFirstChild("FlightPosition") ~= nil)
		check("drone spawns at hover height", math.abs(drone.HumanoidRootPart.Position.Y - (5 + Enemies.Defs.Drone.Flying.Hover)) < 0.01)
		local shot = false
		run(1.2, function()
			for _, e in eventsSince(spawnMark) do if e[1] == "CombatEvent" and e[3] == "Swing" and e[4] == drone then shot = true return true end end
			return false
		end)
		check("drone fires through Combat.Swing", shot)
		check("drone steers its flight target toward the orbit, not the player", drone.HumanoidRootPart.FlightPosition.Position ~= nil and (drone.HumanoidRootPart.FlightPosition.Position - me.HumanoidRootPart.Position).Magnitude >= Enemies.Defs.Drone.KeepDistance[1] - 0.01)
		drone.Humanoid.Health = 0; run(0.5)
		check("drone body removed on death", not drone.Parent)
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

-- The open world v1 (design/gdd/world.md, Phase 3 build order 5): the road, the enclave, the stations, the trader, the warmonger
do
	local Regions = M.mockEnv.__require(SSS.Server.Regions)
	local Transport = M.mockEnv.__require(SSS.Server.Transport)
	local R = M.mockEnv.__require(RS.Shared.Regions)
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local Wallet = M.mockEnv.__require(SSS.Server.Wallet)
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	local PlayerData = M.mockEnv.__require(SSS.Server.PlayerData)
	local Config = M.mockEnv.__require(RS.Shared.Config)
	local CS = game_:GetService("CollectionService")
	as(player)
	local me = player.Character
	local data = PlayerData.Get(player)
	local road, market = nil, nil
	for _, d in workspace_.Regions:GetChildren() do
		if d.Name == "Road" then road = d end
		if d.Name == "SafeZone" and d:GetAttribute("ZoneName") == R.Enclave.Market.Name then market = d end
	end
	local guards = 0
	for _, g in R.Road.Guards do guards += g.Count end
	check("the road and the enclave are built (playable road, safe market, all guards)", road ~= nil and CS:HasTag(road, "PlayableArea") and road:GetAttribute("Region") == "Road" and market ~= nil and Regions.Built.Guards == guards)
	local warmonger
	for _, m in workspace_:GetChildren() do if m:GetAttribute("EnemyType") == "Warmonger" then warmonger = m end end
	check("a warmonger holds the road's end", warmonger ~= nil and warmonger.Humanoid.MaxHealth == 340 and R.At(warmonger.HumanoidRootPart.Position) == "Road")
	check("regions know where you are", R.At(R.Enclave.Origin) == "Enclave" and R.At(M.V3.new(R.Road.X, 0, R.Road.Z0 + 50)) == "Road" and R.At(M.V3.new(0, 0, 0)) == nil and R.InMarket(R.Enclave.Origin) and not R.InMarket(R.Enclave.Origin + M.V3.new(100, 0, 0)))
	-- stations: two hubs; a ride needs the far end unlocked first
	check("two transport hubs stand", #CS:GetTagged("TransportHub") == 2 and Transport.Built.Hubs == 2)
	data.Hubs = {}
	me:PivotTo(M.CF.new(R.Hubs.City.Position + M.V3.new(0, 4, 0)))
	run(1.2)
	check("standing on a hub unlocks it", Transport.Unlocked(player, "City") and player:GetAttribute("HubsKnown") == 1)
	check("you cannot ride to a station you have never reached", Transport.Ride(player, "City", "Enclave") == false and player:GetAttribute("Boarding") == nil)
	me:PivotTo(M.CF.new(R.Hubs.Enclave.Position + M.V3.new(0, 4, 0)))
	run(1.2)
	check("reaching the far station on foot unlocks it", Transport.Unlocked(player, "Enclave") and player:GetAttribute("HubsKnown") == 2)
	Combat.State(me).lastHit = 0
	local rode = Transport.Ride(player, "Enclave", "City")
	check("boarding is a protected wait", rode and player:GetAttribute("Boarding") == true and me:FindFirstChildOfClass("ForceField") ~= nil)
	run(Config.Transport.BoardSeconds + 0.5)
	check("the train lands you on the far platform", player:GetAttribute("Boarding") == nil and (me.HumanoidRootPart.Position - R.Hubs.City.Position).Magnitude < 10)
	-- the trader: only in the market, for money
	Wallet.Add(player, 100)
	local money0, dots0 = Wallet.Get(player), Inventory.Count(player, "DotSight")
	check("no trading outside the market", Regions.Buy(player, "DotSight") == false and Wallet.Get(player) == money0)
	me:PivotTo(M.CF.new(R.Enclave.Origin + M.V3.new(0, 4, 0)))
	run(1.2)
	check("standing in the market flags you for the trader", player:GetAttribute("Market") == true)
	check("buying a part costs its price", Regions.Buy(player, "DotSight") and Inventory.Count(player, "DotSight") == dots0 + 1 and Wallet.Get(player) == money0 - Regions.Price("DotSight"))
	Wallet.Spend(player, Wallet.Get(player))
	check("no money, no part", Regions.Buy(player, "ExtMag") == false)
	-- the warmonger's dash closes a gap no walk could
	me:PivotTo(M.CF.lookAt(M.V3.new(600, 5, 600), M.V3.new(600, 5, 560)))
	me.Humanoid.Health = me.Humanoid.MaxHealth
	local wm = NPCs.Spawn("Warmonger", M.V3.new(600, 5, 566), { Despawn = false })
	local before = (wm.HumanoidRootPart.Position - me.HumanoidRootPart.Position).Magnitude
	run(0.7)
	local after = (wm.HumanoidRootPart.Position - me.HumanoidRootPart.Position).Magnitude
	check("the warmonger flicker-steps to within reach", before > 30 and after < 12)
	wm.Humanoid.Health = 0; run(0.5)
	me:PivotTo(M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4)))
end
-- The hideout computer (design/gdd/raids.md, Phase 3 build order 6): contacts, the board, a raid with a lead, intel, the house, the black market, rival crews
do
	local Raids = M.mockEnv.__require(SSS.Server.Raids)
	local Terminal = M.mockEnv.__require(SSS.Server.Terminal)
	local Rivals = M.mockEnv.__require(SSS.Server.Rivals)
	local Hideout = M.mockEnv.__require(SSS.Server.Hideout)
	local NPCs = M.mockEnv.__require(SSS.Server.NPCs)
	local Combat = M.mockEnv.__require(SSS.Server.Combat)
	local Wallet = M.mockEnv.__require(SSS.Server.Wallet)
	local Inventory = M.mockEnv.__require(SSS.Server.Inventory)
	local PlayerData = M.mockEnv.__require(SSS.Server.PlayerData)
	local RD = M.mockEnv.__require(RS.Shared.Raids)
	as(player)
	local me = player.Character
	local data = PlayerData.Get(player)
	local contacts, rivals = 0, 0
	for _, m in workspace_:GetChildren() do
		if m:GetAttribute("Contact") then contacts += 1 end
		if m:GetAttribute("EnemyType") == "Rival" then rivals += 1 end
	end
	check("three contacts stand in the world and two rival crews work it", contacts == 3 and rivals == 4 and Rivals.Crews().RoadCrew.Alive == 2)
	-- the board: locked until the broker
	data.Contacts, data.Board, data.Raid = {}, { { Id = "highway_cull" } }, false
	local board = Raids.Board(player)
	check("the board fills to three contracts", #board == RD.BoardSize and board[1].Id == "highway_cull")
	check("a contract needs its contact", Raids.Accept(player, 1) == false and data.Raid == false)
	check("meeting the broker opens RAIDS", Terminal.Meet(player, "Broker") and data.Contacts.Broker == true and Terminal.State(player).Contacts.Broker == true)
	check("taking a contract starts the raid and the HUD line", Raids.Accept(player, 1) and data.Raid and data.Raid.Id == "highway_cull" and tostring(player:GetAttribute("RaidLine")):find("Clear the Highway") ~= nil and #Raids.Board(player) == RD.BoardSize)
	-- kills count toward the step (the killer is the player)
	me:PivotTo(M.CF.lookAt(M.V3.new(700, 5, 700), M.V3.new(700, 5, 690)))
	Combat.ClearProtection(me)
	for i = 1, 4 do
		local g = NPCs.Spawn("Grunt", M.V3.new(700, 5, 692), { Despawn = false })
		Combat.Damage(me, g, 9999, {}); run(0.3)
	end
	local step = data.Raid.Steps[data.Raid.Step]
	check("four raider kills finish the objective: the extract step", step.Kind == "extract")
	-- every enemy drops everything it carries (owner, 2026-10-26): its weapon is always among it
	local gunner = NPCs.Spawn("Gunner", M.V3.new(720, 5, 692), { Despawn = false })
	local carry = NPCs.Carrying(gunner)
	check("an enemy carries its weapon and a loot roll from the moment it spawns", carry ~= nil and carry.ArcPistol == 1 and (gunner:GetAttribute("Carrying") or 0) >= 1)
	Combat.Damage(me, gunner, 9999, {}); run(0.4)
	local dropped = false
	for _, d in workspace_:GetChildren() do if d.Name == "Lootable" and (d.Position - M.V3.new(720, 5, 692)).Magnitude < 12 then dropped = true end end
	check("its whole carry hits the ground where it died", dropped)
	-- a lead: doing its first objective continues the raid with the bonus
	step.Lead = "dead_drop"
	Raids.Sync(player)
	local wrecks = RD.Points.RoadWrecks
	me:PivotTo(M.CF.new(wrecks + M.V3.new(0, 4, 0)))
	run(1.3)
	check("following the lead chains the contracts and stacks the pay", #data.Raid.Chain == 2 and data.Raid.Chain[2] == "dead_drop" and data.Raid.Bonus == RD.LeadBonus and data.Raid.Steps[data.Raid.Step].Kind == "extract")
	-- extraction pays everything in the chain
	local money0 = Wallet.Get(player)
	Combat.State(me).lastHit = 0
	local me0 = me
	Hideout.Extract(player); run(0.3)
	check("extracting pays the whole chain with the lead bonus", data.Raid == false and Wallet.Get(player) == money0 + math.floor((60 + 45) * RD.LeadBonus + 0.5) and player:GetAttribute("RaidLine") == nil)
	-- intel puts a contract on the board
	local n0 = #Raids.Board(player)
	Inventory.Add(player, "Intel", 1)
	Inventory.Use(player, "Intel"); run(0.1)
	check("reading intel adds a contract to the board", #data.Board == n0 + 1 and data.Board[1].FromIntel == true and Inventory.Count(player, "Intel") == 0)
	-- the house and the market: their contacts first
	Wallet.Add(player, 300)
	local m1 = Wallet.Get(player)
	check("no house orders without the fixer", Terminal.Order(player, "Rug") == false and Wallet.Get(player) == m1)
	Terminal.Meet(player, "Fixer")
	check("ordering a furnishing publishes it for the owner", Terminal.Order(player, "Rug") and data.House.Rug == true and Wallet.Get(player) == m1 - 30 and tostring(player:GetAttribute("House")):find("Rug") ~= nil and Terminal.Order(player, "Rug") == false)
	check("no black market without the dealer", Terminal.Buy(player, "Suppressor") == false)
	Terminal.Meet(player, "Dealer")
	local sup0 = Inventory.Count(player, "Suppressor")
	check("the black market sells for money", Terminal.Buy(player, "Suppressor") and Inventory.Count(player, "Suppressor") == sup0 + 1 and Wallet.Get(player) == m1 - 30 - 110)
	local state = Terminal.State(player)
	check("the computer's state is complete", state.Contacts.Broker and state.Contacts.Fixer and state.Contacts.Dealer and #state.Board == RD.BoardSize + 1 and #state.House == #RD.House and #state.Market == #RD.Market and state.Money == Wallet.Get(player))
	-- the "hear" tell: a body that first sees you says so (Bark attribute); a rival crew on your hold point contests it
	Hideout.Enter(player, { Quiet = true }); run(0.2)
	me = player.Character
	me:PivotTo(M.CF.lookAt(M.V3.new(800, 5, 800), M.V3.new(800, 5, 780)))
	me.Humanoid.Health = me.Humanoid.MaxHealth
	Combat.Protect(me, 30)
	local barker = NPCs.Spawn("Grunt", M.V3.new(800, 5, 785), { Despawn = false })
	run(0.6)
	local bark = barker:GetAttribute("Bark")
	check("an enemy barks once on first sight", type(bark) == "string" and bark:find("|") ~= nil)
	barker.Humanoid.Health = 0; run(0.4)
	data.Contacts.Broker = true
	data.Board = { { Id = "hold_the_gate" } }; Raids.Board(player)
	Raids.Accept(player, 1)
	local gate = RD.Points.EnclaveGate
	local squatter = NPCs.Spawn("Rival", gate + M.V3.new(3, 5, 0), { Despawn = false, Home = gate })
	me:PivotTo(M.CF.new(gate + M.V3.new(0, 4, 2)))
	run(2.5)
	check("a rival on your hold point contests it: no progress", data.Raid.Hold == 0 and data.Raid.Contested == true and tostring(player:GetAttribute("RaidLine")):find("contested") ~= nil)
	squatter.Humanoid.Health = 0; run(2.5)
	check("with the rival gone the hold counts again", data.Raid.Hold > 0 and data.Raid.Contested == false)
	Raids.Abandon(player)
	Hideout.Enter(player, { Quiet = true }); run(0.2)
	Terminal.Open(player)
	local wasOpen = player:GetAttribute("Terminal") == true
	Hideout.Leave(player); run(0.2)
	check("leaving the hideout closes the computer", wasOpen and player:GetAttribute("Terminal") == nil)
	-- the places door (Config.Places, server/Travel.lua): a pivot today, a teleport once the places exist
	do
		local Travel = M.mockEnv.__require(SSS.Server.Travel)
		local Config = M.mockEnv.__require(RS.Shared.Config)
		check("with places off every trip stays in this place", Travel.To(player, "Hideout", "Hideout") == false and Travel.Here() == nil)
		Config.Places.Enabled = true
		Config.Places.Ids.Hideout = 12345
		local took = Travel.To(player, "Hideout", "Hideout")
		check("with a hideout place set the door becomes a teleport and records where you are going", took == true and data.Location == "Hideout")
		Config.Places.Enabled = false
		Config.Places.Ids.Hideout = 0
		run(0.3)
		if not PlayerData.Get(player) then PlayerData.Load(player) end -- Travel released the session on the way out
		data = PlayerData.Get(player)
	end
	player.Character:PivotTo(M.CF.lookAt(M.V3.new(120, 5, 0), M.V3.new(120, 5, -4)))
	-- attack animations (Presentation.Swings keyframes): every melee combo step and heavy resolves to
	-- a keyed swing with a wind-up and a strike; the spear's three are two thrusts and a swipe
	do
		local Presentation = M.mockEnv.__require(RS.Shared.Presentation)
		local Weapons = M.mockEnv.__require(RS.Shared.Weapons)
		local ok, count, families = true, 0, {}
		for id, def in Weapons.Defs do
			if not Weapons.IsGun(def) and def.Attacks then
				for i = 1, #def.Attacks do
					local e = Presentation.SwingFor(def.Family, i)
					local wind, strike = false, false
					for _, k in e.Keys or {} do
						wind = wind or k.Phase == "Wind"
						strike = strike or k.Phase == "Strike"
					end
					ok = ok and e.Keys ~= nil and wind and strike
					count += 1
				end
				local heavy = Presentation.SwingFor(def.Family, "Heavy")
				ok = ok and heavy.Keys ~= nil and heavy.Dust ~= nil
				families[def.Family] = true
			end
		end
		check(("every melee combo step has a keyed swing (%d steps, wind + strike) and every heavy raises dust"):format(count), ok and count >= 15)
		local spear = Presentation.Swings.Families.Spear
		local thrust1 = spear[1].Keys[#spear[1].Keys].R[1] > 90 and spear[1].Keys[1].Twist > 0
		local thrust2 = spear[2].Keys[#spear[2].Keys].Dip ~= nil and #spear[2].Keys == 3
		local swipe = spear[3].Keys[1].R[3] > 0 and spear[3].Keys[#spear[3].Keys].R[3] < 0 -- right to left across the body
		check("the spear combo is thrust, low thrust, swipe (distinct keyed swings)", thrust1 and thrust2 and swipe)
	end
end
check("no script errors", #M.errors == 0)
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
