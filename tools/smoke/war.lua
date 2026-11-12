-- The Front: boots the war server and runs two recruits through deploy, shop, the weapon
-- mechanism, a firefight, death, looting, repair, the hill, artillery and a sector rebuild.
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_WAR } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
local Players = game_:GetService("Players")
-- a fixed world roll: the firefight, artillery and entrenching checks place recruits at fixed spots, so a random
-- roll can put a wall or a crest between them (set WAR_SEED to try another)
M.mockEnv.__require(RS.Shared.Config).War.World.Seed = tonumber(WAR_SEED) or 783990213
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
local Remotes = RS.Remotes
local Config = M.mockEnv.__require(RS.Shared.Config)
Config.Guns.Jam.Heat = 0 -- no jams from heat at random in these checks (the round 3 block makes its own)
Config.War.Intro.Enabled = false -- the first link (stasis tank intro) gets its own run at the end
local function run(seconds, cond) for _ = 1, math.floor(seconds * 30) do M.step(1/30); if cond and cond() then return true end end return cond == nil end
local function check(label, ok) print((ok and "PASS  " or "FAIL  ") .. label) end
local function as(p) M.setPlayer(p) end

local function makePlayer(name, id, faction)
	local player = M.newInstance("Player")
	player.Name, player.DisplayName, player.UserId = name, name, id
	rawset(player, "_joinData", { TeleportData = { Faction = faction } })
	player.Parent = Players
	function player:LoadCharacter()
		if self.Character then self.Character:Destroy() end
		local char = M.newInstance("Model"); char.Name = name
		for _, n in { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do local p = M.newInstance("Part"); p.Name = n; p.Parent = char end
		local hum = M.newInstance("Humanoid"); hum.Parent = char
		char.PrimaryPart = char.HumanoidRootPart
		char.Parent = workspace_
		self.Character = char
		self.CharacterAdded:Fire(char)
	end
	Players.PlayerAdded:Fire(player)
	return player
end

run(1)
local front = workspace_:FindFirstChild("Front")
local structures = game_:GetService("CollectionService"):GetTagged("Structure")
check("battlefield generated", front ~= nil and #structures >= 18)
check("both bases built", front:FindFirstChild("UnionBase") ~= nil and front:FindFirstChild("PactBase") ~= nil)

local u = makePlayer("Blue", 1, "Union")
local p = makePlayer("Red", 2, "Pact")
run(1)
local function lastApp(player) local last for _, e in M.FireLog do if e[1] == "RecruitApp" and e.player == player then last = e end end return last end
local function weaponState(player)
	local last
	for _, e in M.FireLog do if e[1] == "Weapon" and e.player == player and e[3] == "State" then last = e end end
	return last and last[4], last and last[5]
end
check("deployed with factions from teleport data", u.Character:GetAttribute("Faction") == "Union" and p.Character:GetAttribute("Faction") == "Pact")
local w = weaponState(u)
check("empty locker deploys a conscript sidearm", w ~= nil and w.Id == "M1911")

-- shop + order: the Union player buys an M16A1, ammo and a vest, orders them for next time
as(u)
Remotes.WarBuy:FireServer("M16A1"); Remotes.WarBuy:FireServer("Ammo"); Remotes.WarBuy:FireServer("FlakVest"); Remotes.WarBuy:FireServer("Grenade"); Remotes.WarBuy:FireServer("Grenade"); Remotes.WarBuy:FireServer("AKM"); run(0.3)
local snap = lastApp(u)[3]
check("shop sells own-faction gear only", snap.Locker.M16A1 ~= nil and snap.Locker.AKM == nil)
check("credits spent", snap.Credits == Config.War.StartingCredits - 950 - 60 - 300 - 180)
Remotes.WarOrder:FireServer({ Primary = "M16A1", Armor = "FlakVest" }); run(0.3)
check("order accepted", lastApp(u)[3].Loadout.Primary == "M16A1")

-- Red orders a bought Makarov so their body carries real gear later (conscript pistols are not loot)
as(p)
Remotes.WarBuy:FireServer("Makarov"); Remotes.WarOrder:FireServer({ Sidearm = "Makarov" }); run(0.2)
p.Character.Humanoid.Health = 0
as(u)
-- die and come back with the ordered rifle
u.Character.Humanoid.Health = 0
run(Config.War.RespawnSeconds + 1)
w = weaponState(u)
check("respawned carrying the ordered M16A1 with magazines", w ~= nil and w.Id == "M16A1" and w.Spare == 3)
check("conscript body left no loot", workspace_:FindFirstChild("RecruitRemains") == nil)
local uc, pc = u.Character, p.Character

-- the mechanism: safety, selector, dry fire, reload
local function fireAt(target)
	uc.HumanoidRootPart.CFrame = M.CF.lookAt(target.HumanoidRootPart.Position + M.V3.new(0, 0, 30), target.HumanoidRootPart.Position)
	Remotes.Fire:FireServer(uc.HumanoidRootPart.CFrame.LookVector)
end
-- a fresh gun can still jam at random; the mechanism checks below need it not to
local Firearms = M.mockEnv.__require(RS.Shared.Firearms)
local malfunction = Firearms.MalfunctionChance
Firearms.MalfunctionChance = function() return 0 end
pc.HumanoidRootPart.CFrame = M.CF.new(3000, 4, 3000) -- out past the world, where no prop stands between them
run(Config.SpawnProtection + 1)
fireAt(pc); run(0.1)
local lastClick for _, e in M.FireLog do if e[1] == "Weapon" and e.player == u and e[3] == "Click" then lastClick = e[4] end end
check("gun starts on Safe and refuses to fire", lastClick == "safe")
Remotes.Mode:FireServer(); run(0.1)
w = weaponState(u)
check("selector cycles to Semi", w.Mode == "Semi")
local hpBefore = pc.Humanoid.Health
for _ = 1, 25 do fireAt(pc); run(0.12) end
w = weaponState(u)
check("fired the magazine dry (bolt open)", w.Mag == 0 and w.BoltOpen == true and w.Chamber == false)
check("bullets hit the enemy through the ballistics path", pc.Humanoid.Health < hpBefore)
check("armor-less enemy took real damage", pc.Humanoid.Health < hpBefore - 20)
do
	local hurt = false
	for _, part in { "Head", "Chest", "Stomach", "ArmL", "ArmR", "LegL", "LegR" } do if (pc:GetAttribute("W_" .. part) or 1) < 1 then hurt = true end end
	check("wound: rounds land on body parts, not only the pool", hurt)
end
-- the magazine is worked a step at a time: R takes it out, R puts one in, T works the action
Remotes.Reload:FireServer(); run(0.9)
w = weaponState(u)
check("handling: R takes the magazine out and nothing more", w.Mag == nil and w.Chamber == false and not w.Reloading)
Remotes.Reload:FireServer(); run(1.2)
w = weaponState(u)
check("handling: R again seats a fresh magazine, the chamber still empty", w.Mag == 20 and w.Chamber == false and w.Spare == 2)
Remotes.Rack:FireServer(); run(0.6)
Firearms.MalfunctionChance = malfunction
w = weaponState(u)
check("handling: T works the action and chambers a round", w.Mag == 19 and w.Chamber == true and w.Spare == 2)

-- kill: hit until dead, then the body is lootable by the enemy who then repairs it
pc.Humanoid.Health = 30
for _ = 1, 10 do fireAt(pc); run(0.12); if pc.Humanoid.Health <= 0 then break end end
check("enemy recruit killed", pc.Humanoid.Health <= 0)
run(0.5)
local body
for _, b in workspace_:GetChildren() do if b.Name == "RecruitRemains" and b:GetAttribute("Label") == "Red's recruit" then body = b end end
check("fallen recruit leaves lootable remains", body ~= nil)
local kills = lastApp(u)[3].Kills
check("kill credited to the conduit", kills == 1)
-- loot it with the killer (Union looting a Pact Makarov)
uc.HumanoidRootPart.CFrame = M.CF.new(body.Position + M.V3.new(2, 2, 0)); run(0.1)
for _, pr in body:GetChildren() do if pr.ClassName == "ProximityPrompt" then pr.Triggered:Fire(u) end end
run(0.3)
snap = lastApp(u)[3]
check("looted enemy sidearm lands in the locker damaged", snap.Locker.Makarov ~= nil and snap.Locker.Makarov.condition < 100)
M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(u).War.Credits += 500 -- income takes minutes; fund the repair
Remotes.WarBuy:FireServer("Medkit"); run(0.2) -- refresh the snapshot
snap = lastApp(u)[3]
local creditsBefore = snap.Credits
Remotes.WarRepair:FireServer("Makarov"); run(0.3)
snap = lastApp(u)[3]
check("repair restores condition and costs credits", snap.Locker.Makarov.condition == 100 and snap.Credits < creditsBefore)

-- hill: standing in the hot sector earns tickets and the scales broadcast
local Battlefield = M.mockEnv.__require(SSS.Server.Battlefield)
local Hill = M.mockEnv.__require(SSS.Server.Hill)
local Factions = M.mockEnv.__require(SSS.Server.Factions)
local center = Battlefield.SectorCenter(Hill.Current())
local unionBefore = Factions.Scales().Union
uc.HumanoidRootPart.CFrame = M.CF.new(center + M.V3.new(0, 4, 0))
run(11)
check("presence in the hill earns tickets", Factions.Scales().Union > unionBefore)
local hillMsg for _, e in M.FireLog do if e[1] == "Hill" then hillMsg = e[3] end end
check("hill status reaches clients", hillMsg ~= nil and hillMsg.Counts.Union == 1)

-- artillery on the hill wrecks a structure stage and leaves a crater
local target
for _, m in structures do
	local e = m:FindFirstChild("Stage1") if e and Battlefield.SectorAt(e:GetPivot().Position) == Hill.Current() then target = m break end
end
check("found a structure in the hill", target ~= nil)
local tpos = target:FindFirstChild("Stage1"):GetPivot().Position
-- stand well clear of your own strike (still inside the hill sector)
uc.HumanoidRootPart.CFrame = M.CF.new(center + (M.V3.new(center.X, 0, center.Z) - M.V3.new(tpos.X, 0, tpos.Z)).Unit * 60 + M.V3.new(0, 4, 0))
local spread = Config.War.Artillery.Spread
Config.War.Artillery.Spread = 4 -- shells land on the target (the real spread can miss it entirely)
Remotes.Artillery:FireServer(M.V3.new(tpos.X, 2, tpos.Z)); run(Config.War.Artillery.Delay + 5)
Config.War.Artillery.Spread = spread
check("caller survived their own strike", uc.Humanoid.Health > 0)
check("artillery damaged the structure into a later stage", target:GetAttribute("Stage") >= 2)
check("craters left on the field", #game_:GetService("CollectionService"):GetTagged("Crater") >= 1)
check("artillery cooldown enforced", (function() Remotes.Artillery:FireServer(M.V3.new(tpos.X, 2, tpos.Z)); run(0.1); local n = 0 for _, e in M.FireLog do if e[1] == "Announce" and type(e[3]) == "string" and e[3]:find("reloading") then n += 1 end end return n >= 1 end)())

-- sector rebuild restores it
local sector = Battlefield.SectorAt(tpos)
Battlefield.RebuildSector(sector); run(0.2)
check("rebuild crews restore the structure", target:GetAttribute("Stage") == 1)

-- grenade
run(2)
local p2 = p.Character
p2.HumanoidRootPart.CFrame = M.CF.new(uc.HumanoidRootPart.Position + M.V3.new(0, 0, 6))
run(Config.SpawnProtection + 1)
local hpN = p2.Humanoid.Health
Remotes.Grenade:FireServer(M.V3.new(0, 0, 1)); run(0.1)
local nade = workspace_:FindFirstChild("FragGrenade")
check("grenade thrown", nade ~= nil)
if nade then nade.CFrame = M.CF.new(p2.HumanoidRootPart.Position + M.V3.new(2, 0, 0)); nade.AssemblyLinearVelocity = M.V3.zero end
run(4)
check("frag grenade hurt the enemy", p2.Humanoid.Health < hpN)
do -- wounds on the Front (common/WoundService): the blast concusses and wounds; the dressing (H) goes on a bleed first
	local SoldiersW = M.mockEnv.__require(SSS.Server.Soldiers)
	local WoundService = M.mockEnv.__require(SSS.Server.Common.WoundService)
	check("wound: the frag concussed and wounded the recruit", p2:GetAttribute("Concussed") == true and (p2:GetAttribute("W_Chest") or 1) < 1)
	local st = WoundService.Get(p2)
	if st then
		for part in st.Bleed do st.Bleed[part] = nil end
		st.Bleed.LegL = "Heavy"; WoundService.Push(p2)
	end
	local sp = SoldiersW.State(p)
	if sp then sp.Medkits = 1 end
	as(p); Remotes.Heal:FireServer(); run(0.2); as(u)
	check("wound: the dressing stops a heavy bleed and is spent", p2:GetAttribute("Bleed_LegL") == "" and sp ~= nil and sp.Medkits == 0)
	if st then st.Broken.LegR = true; WoundService.Push(p2) end
	check("wound: a broken leg sets the walking pace down", (p2:GetAttribute("WoundSpeed") or 1) < 1 and p2:GetAttribute("WoundNoSprint") == true)
	WoundService.Mend(p2)
end


-- entrenching: dig a foxhole in the open; a hit interrupts; sandbags need stock
as(u)
local E = Config.War.Entrench
uc = u.Character
uc.HumanoidRootPart.CFrame = Battlefield.HomeCFrame("Union") + M.V3.new(0, 0, 40) -- open ground in the rear
run(0.2)
Remotes.Entrench:FireServer("Dig"); run(E.DigSeconds + 0.5)
check("dug a foxhole", workspace_:FindFirstChild("Foxhole") ~= nil)
Remotes.Entrench:FireServer("Dig"); run(0.3)
local digMsg for _, e in M.FireLog do if e[1] == "Announce" and e.player == u and type(e[3]) == "string" and e[3]:find("already dug") then digMsg = true end end
check("cannot dig on top of your own hole", digMsg == true)
uc.HumanoidRootPart.CFrame = uc.HumanoidRootPart.CFrame + M.V3.new(20, 0, 0); run(0.2) -- clear of the hole
Remotes.Entrench:FireServer("Sandbag"); run(0.3)
local bagMsg for _, e in M.FireLog do if e[1] == "Announce" and e.player == u and type(e[3]) == "string" and e[3]:find("No sandbags") then bagMsg = true end end
check("sandbags need stock from the shop", bagMsg == true)

-- the open world: a layout with every sector typed and crested, dugouts to deploy from, the dead calcifying
local FrontMap = M.mockEnv.__require(RS.Shared.FrontMap)
local L = FrontMap.Layout()
local H = Config.War.Hill
local typed, crested = 0, 0
for _, sec in L.Sectors do
	typed += (sec.Type and 1 or 0)
	crested += (sec.Crest and sec.Crest.H > 0 and 1 or 0)
end
check("world: every sector typed and crested", #L.Sectors == H.Cols * H.Rows and typed == #L.Sectors and crested == #L.Sectors)
local kinds = {}
for _, s in L.Scatter do kinds[s.Kind] = (kinds[s.Kind] or 0) + 1 end
check("world: barrows, the calcified dead, wire and dugouts laid out", (kinds.Barrow or 0) >= H.Cols * H.Rows and (kinds.Calcified or 0) > 200 and (kinds.Wire or 0) > 20 and kinds.Dugout == H.Cols * H.Rows * 2)
local glade = 0
for _, sec in L.Sectors do glade += (sec.Type == "Glade" and 1 or 0) end
check("world: one pocket of green", glade == 1 and L.Glade ~= nil)
local risen, hMax = 0, -math.huge
for _, sec in L.Sectors do
	local h, tag = FrontMap.Sample(sec.Crest.X, sec.Crest.Z)
	local ok = (tag == "Barrow" or tag == "Glade") and h > Config.War.World.GroundLevel + 2
	risen += ok and 1 or 0
	hMax = math.max(hMax, h)
end
local hEdge = FrontMap.Height(L.PlayX + 150, 0)
check("world: crests rise, the outer barrows wall it in", risen == #L.Sectors and hEdge > hMax + 20)
-- deploying one sector behind the hill, on your own side
local hot = Hill.Current()
local hotSec = L.Sectors[hot]
local deploy = Battlefield.BaseCFrame("Union").Position
local behind = FrontMap.Index(hotSec.I - 1, hotSec.J)
check("world: Union deploys at its dugout behind the hill", behind ~= nil and FrontMap.SectorAt(deploy.X, deploy.Z) == behind)
local home = Battlefield.HomeCFrame("Pact").Position
check("world: bases sit in the rears", home.X > L.HalfX + 100)
-- the fallen calcify and feed the crest
local crestBefore = Battlefield.Crest(hot)
local fallAt = Battlefield.SectorCenter(hot)
for _ = 1, Config.War.World.GrowEvery do Battlefield.Fallen(fallAt) end
run(Config.War.World.CalcifySeconds + 1)
local fallen = 0
for _, d in workspace_:GetDescendants() do if d:GetAttribute("Fallen") then fallen += 1 end end
local grew for _, e in M.FireLog do if e[1] == "World" and e[3] == "CrestGrew" then grew = true end end
check("world: the fallen calcify where they lay", fallen >= Config.War.World.GrowEvery)
check("world: the crest grows from the dead", grew == true and Battlefield.Crest(hot).Y > crestBefore.Y)
-- ===== the first link: stasis tank, drain, chute, barracks, simulation, drop =====
local Soldiers = M.mockEnv.__require(SSS.Server.Soldiers)
local Intro = M.mockEnv.__require(SSS.Server.Intro)
local Simulation = M.mockEnv.__require(SSS.Server.Simulation)
local I = Config.War.Intro
I.Enabled = true
I.WakeSeconds, I.DrainSeconds, I.UnlatchSeconds, I.ChuteSeconds, I.LinkSeconds, I.DoneSeconds = 0.6, 0.5, 0.3, 0.5, 0.3, 0.3
local function stages(player) local out = {} for _, e in M.FireLog do if e[1] == "Tutorial" and e.player == player and e[3] == "Front" then table.insert(out, e[4]) end end return out end
local function lastStage(player, name) local last for _, e in M.FireLog do if e[1] == "Tutorial" and e.player == player and e[3] == "Front" and e[4] == name then last = e[5] end end return last end
local g = makePlayer("Green", 3, "Union")
as(g)
run(0.3)
local cell = workspace_:FindFirstChild("IntroCell_3")
check("intro: first link wakes cabled in a stasis tank", table.find(stages(g), "Wake") ~= nil and g.Character.HumanoidRootPart.Anchored == true and cell ~= nil and g.Character.HumanoidRootPart:FindFirstChild("Cable1") ~= nil)
check("intro: a recruit in its first link is not deployed (no hill, no income)", Soldiers.IsDeployed(g) == false and Soldiers.State(g) ~= nil and Soldiers.State(g).Intro == true)
run(1.3)
local fluid = cell.Chamber:FindFirstChild("TankFluid")
check("intro: the tank drains and the cables unlatch", fluid.Size.X < 1 and table.find(stages(g), "Unlatch") ~= nil and g.Character.HumanoidRootPart:FindFirstChild("Cable1") == nil)
run(0.4)
check("intro: the hatch opens into the chute", table.find(stages(g), "Chute") ~= nil and cell.Chamber.Hatch.CanCollide == false)
run(0.8)
local supply = cell:FindFirstChild("Supply")
check("intro: the barracks lays out five pieces of the conduit's supply", table.find(stages(g), "Barracks") ~= nil and supply ~= nil and #supply:GetChildren() == 5)
check("intro: set down in the barracks", g.Character.HumanoidRootPart.Position.Y < I.Origin.Y + 10)
local w0 = weaponState(g)
check("intro: nothing carried before taking it", w0 == nil)
for _, bench in supply:GetChildren() do
	for _, d in bench:GetDescendants() do if d.ClassName == "ProximityPrompt" then d.Triggered:Fire(g) end end
end
run(0.3)
local wg, _, kitg = weaponState(g)
local st = Soldiers.State(g)
check("intro: issue gear fills an empty locker (rifle, sidearm, vest, helmet, frags)", wg ~= nil and wg.Id == "M16A1" and st.Weapons.Sidearm ~= nil and st.Armor ~= nil and st.Armor.Id == "FlakVest" and st.Helmet ~= nil and st.Grenades == 2)
check("intro: equip count reaches the client", (lastStage(g, "Equip") or {}).Taken == 5)
run(3.5)
local ctx = Intro.Active(g)
local sim = ctx and ctx.sim
check("intro: links into the wireframe simulation", table.find(stages(g), "Sim") ~= nil and sim ~= nil and workspace_:FindFirstChild("Simulation_3") ~= nil)
check("intro: the city is built of breakable blocks", sim ~= nil and #sim.Buildings >= 10 and sim.Tower ~= nil)
-- RANGE and BREACH: break every target
for _, m in sim.Folder:GetChildren() do if m.Name == "SimTarget" then Soldiers.Damage(m, 100, g, "Torso", 0, "Bullet") end end
run(4.5)
local function drillsDone() local out = {} for _, e in M.FireLog do if e[1] == "Tutorial" and e.player == g and e[4] == "DrillDone" then out[e[5].Index] = true end end return out end
check("intro: range and breach drills finish when their targets break", drillsDone()[1] and drillsDone()[2])
-- a block breaks and the column above it falls
local steps = sim.ByName.Steps
local low = steps.Blocks["1,1,8"]
local above = steps.Blocks["1,2,8"]
Simulation.DamageBlock(low, 1000); run(0.6)
check("intro: a broken block brings down the column above it", low.Parent == nil and above.Parent == nil and steps.Blocks["1,4,8"] == nil)
-- ASCENT: reach the beacon
g.Character.HumanoidRootPart.CFrame = M.CF.new(sim.Beacon + M.V3.new(0, 3, 0)); run(2.5)
check("intro: ascent finishes at the beacon", drillsDone()[3])
-- CONTACT: hostiles come and shoot back
g.Character.HumanoidRootPart.CFrame = M.CF.new(sim.Center + M.V3.new(0, 3.5, 70))
run(8)
local hostiles = 0 for _, m in sim.Folder:GetChildren() do if m.Name == "SimHostile" then hostiles += 1 end end
local shots = 0 for _, e in M.FireLog do if e[1] == "Weapon" and e.player == g and e[3] == "Shot" and type(e[4]) == "table" and e[4].Name == "SimHostile" then shots += 1 end end
check("intro: contact drill spawns hostiles that shoot back", hostiles == Config.War.Intro.Sim.Hostiles and shots > 0)
local hum = g.Character.Humanoid
hum.Health = 5
Soldiers.Damage(g.Character, 80, nil, "Torso", 0, "Bullet")
check("intro: a fatal blow in the simulation desyncs instead of killing", hum.Health == hum.MaxHealth and table.find(stages(g), "Desync") ~= nil)
for _, m in sim.Folder:GetChildren() do if m.Name == "SimHostile" then Soldiers.Damage(m, 200, g, "Torso", 0, "Bullet") end end
run(2.5)
check("intro: contact finishes when the hostiles break", drillsDone()[4])
-- FIRE MISSION: artillery on the tower brings it down
g.Character.HumanoidRootPart.CFrame = M.CF.new(sim.Center + M.V3.new(20, 3.5, 40))
Remotes.Artillery:FireServer(sim.Center + M.V3.new(69, 2, 119)); run(Config.War.Intro.Sim.Artillery.Delay + 5)
check("intro: a fire mission collapses the tower", sim.Tower.Collapsed == true and drillsDone()[5])
check("intro: the battlefield takes no craters from the simulation", (function() for _, c in game_:GetService("CollectionService"):GetTagged("Crater") do if (c.Position - sim.Center).Magnitude < 400 then return false end end return true end)())
run(2)
local data = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(g)
wg = weaponState(g)
check("intro: drops onto the Front deployed, the cell and simulation gone", Soldiers.IsDeployed(g) and data.War.IntroDone == true and workspace_:FindFirstChild("IntroCell_3") == nil and workspace_:FindFirstChild("Simulation_3") == nil)
check("intro: the simulation spent nothing real (fresh magazines, full frags)", wg ~= nil and wg.Spare == 3 and Soldiers.State(g).Grenades == 2)
check("intro: lands near the faction base", math.abs(g.Character.HumanoidRootPart.Position.X - Battlefield.BaseCFrame("Union").Position.X) < 30)
-- issued gear is the recruit's, not loot
g.Character.HumanoidRootPart.CFrame = M.CF.new(0, 4, 300)
run(Config.SpawnProtection + 0.5)
local before = 0 for _, b in workspace_:GetChildren() do if b.Name == "RecruitRemains" then before += 1 end end
g.Character.Humanoid.Health = 0; run(0.5)
local after = 0 for _, b in workspace_:GetChildren() do if b.Name == "RecruitRemains" then after += 1 end end
check("intro: issued gear does not drop as loot", after == before)
run(Config.War.RespawnSeconds + 1)
check("intro: the next recruit deploys straight to the field", Soldiers.IsDeployed(g) and #stages(g) == #stages(g))
-- leaving in the middle of the first link gives the locker back what the order took
local y = makePlayer("Yellow", 4, "Pact")
run(0.2)
local ydata = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(y)
check("intro: second player gets its own slot", workspace_:FindFirstChild("IntroCell_4") ~= nil and Intro.Active(y) ~= nil and Intro.Active(y).slot == 1)
check("story: the stasis tanks carry the Line 9 crate stencil", (function()
	for _, d in workspace_.IntroCell_4:GetDescendants() do
		if d.Name == "TankPlate" then
			local label = d:FindFirstChildOfClass("SurfaceGui") and d:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel")
			return label ~= nil and label.Text:find("LINE 9") ~= nil
		end
	end
	return false
end)())
Intro.Active(y).kit.Issued.Primary = nil -- pretend the rifle came from the locker
Intro.Active(y).kit.Original.Grenades = 1
y.Parent = nil
Players.PlayerRemoving:Fire(y)
run(0.3)
check("intro: leaving mid-link refunds the locker and clears the cell", ydata.War.Locker.AKM ~= nil and ydata.War.Locker.Grenade ~= nil and workspace_:FindFirstChild("IntroCell_4") == nil)
-- the way home: unlink at your own base's locker; the recruit's gear goes back in the locker
do
	local gdata = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(g)
	local s = Soldiers.State(g)
	local function fired(kind) for _, e in M.FireLog do if e[1] == "Soldier" and e.player == g and e[3] == kind then return true end end return false end
	-- give the recruit something of its own to hand back
	s.Weapons.Primary = s.Weapons.Primary or s.Weapons.Sidearm
	s.Issued = {}
	s.Grenades = 2
	local primaryId = s.Weapons.Primary and s.Weapons.Primary.Id
	check("unlink: refused away from your own locker", Soldiers.Unlink(g) == false)
	local mine
	for _, l in Battlefield.Lockers do if l:GetAttribute("Faction") == "Union" then mine = l end end
	local lp = (if mine:IsA("Model") then mine.PrimaryPart else mine).Position
	g.Character.HumanoidRootPart.CFrame = M.CF.new(lp + M.V3.new(0, 0, 4))
	s.LastHit = { by = g, t = M.mockEnv.os.clock() }
	check("unlink: refused under fire", Soldiers.Unlink(g) == false)
	s.LastHit = nil
	game_:GetService("TeleportService").TeleportAsync = function() error("no teleports in the mock") end
	local nadesBefore = (gdata.War.Locker.Grenade and gdata.War.Locker.Grenade.count) or 0
	check("unlink: at your locker the link closes", Soldiers.Unlink(g) == true and fired("Unlinking"))
	check("unlink: the recruit's gear goes back in the locker", primaryId ~= nil and gdata.War.Locker[primaryId] ~= nil and gdata.War.Locker.Grenade.count == nadesBefore + 2)
	run(Config.War.UnlinkSeconds + 0.5)
	-- the teleport fails here: the failure path puts a fresh recruit on the field with the same locker
	check("unlink: a failed teleport hands the conduit a new recruit", fired("UnlinkFailed") and Soldiers.IsDeployed(g))
end
-- stances, lean, reloads and marking (2026-11-11)
do
	as(g)
	local MV = Config.WarMovement
	local gc = g.Character
	local hum, groot = gc.Humanoid, gc.HumanoidRootPart
	local s = Soldiers.State(g)
	hum.HipHeight = 2
	run(Config.SpawnSettle + 0.5)
	groot.CFrame = M.CF.new(-3000, 4, 3000) -- open ground, nobody near
	local mine = { FilterDescendantsInstances = { gc } }
	Remotes.Stance:FireServer("Crouch"); run(0.1)
	check("stance: C crouches (hips down, the body says so)", gc:GetAttribute("Stance") == "Crouch" and math.abs(hum.HipHeight - (2 - MV.Stance.Crouch.Drop)) < 0.01)
	Remotes.Stance:FireServer("Prone"); run(0.1)
	check("stance: prone lies on the ground", gc:GetAttribute("Stance") == "Prone" and hum.HipHeight == 0)
	Remotes.Stance:FireServer("Flying"); run(0.1)
	check("stance: an unknown stance is refused", gc:GetAttribute("Stance") == "Prone")
	local w = s.Weapons[s.Active]
	w.Mode, w.Chamber, w.Jammed, w.Busy = "Semi", true, false, 0
	local malf = Firearms.MalfunctionChance
	Firearms.MalfunctionChance = function() return 0 end
	Remotes.Fire:FireServer(groot.CFrame.LookVector); run(0.1)
	local kick for _, e in M.FireLog do if e[1] == "Weapon" and e.player == g and e[3] == "Recoil" then kick = e[4] end end
	check("stance: prone steadies the gun (spread and recoil)", w.Steady == MV.Stance.Prone.Spread and kick ~= nil and math.abs(kick - w.Def.Recoil[1] * Firearms.RecoilMult(w.Parts) * MV.Stance.Prone.Recoil) < 1e-4)
	Firearms.MalfunctionChance = malf
	local low = Soldiers.Eye(g, mine)
	check("stance: the prone eye is near the ground", low.Y < groot.Position.Y + 0.5)
	Remotes.Lean:FireServer(1); run(0.1)
	check("lean: no leaning while prone", (s.Lean or 0) == 0)
	Remotes.Stance:FireServer("Stand"); run(0.1)
	check("stance: standing restores the hips", gc:GetAttribute("Stance") == "Stand" and hum.HipHeight == 2)
	local mid = Soldiers.Eye(g, mine)
	Remotes.Lean:FireServer(1); run(0.1)
	local out = Soldiers.Eye(g, mine)
	check("lean: the eye and muzzle move out to the side", s.Lean == 1 and math.abs((out - mid).Magnitude - MV.Lean) < 0.05 and (out - mid).Unit:Dot(groot.CFrame.RightVector) > 0.99)
	Remotes.Lean:FireServer(0); run(0.1)
	-- reloads
	run(2)
	w.Busy, w.Reloading, w.Mag, w.Spare = 0, false, 5, { w.Def.MagSize, w.Def.MagSize }
	w.Chamber = true
	Remotes.Reload:FireServer(false); run(3)
	Remotes.Reload:FireServer(false); run(3)
	check("reload: a tap drops the half-used magazine; with a round chambered there is nothing to rack", w.Mag == w.Def.MagSize and w.Chamber == true and #w.Spare == 1 and w.Dropped == 5)
	w.Busy, w.Reloading, w.Mag = 0, false, 7
	Remotes.Reload:FireServer(true); run(4)
	check("reload: held, the magazine goes back in the pouch", w.Mag == nil and #w.Spare == 2 and w.Dropped == nil)
	Remotes.Reload:FireServer(false); run(4)
	check("reload: the fullest magazine goes in", w.Mag == w.Def.MagSize and #w.Spare == 1 and w.Spare[1] == 7)
	-- marking
	local function figure(name, at)
		local m = M.newInstance("Model"); m.Name = name
		local r = M.newInstance("Part"); r.Name = "HumanoidRootPart"; r.CFrame = M.CF.new(at); r.Parent = m
		local h = M.newInstance("Humanoid"); h.Name = "Humanoid"; h.Parent = m
		h.Health, h.MaxHealth = 100, 100
		m.Parent = workspace_
		return m
	end
	local function marks() local n = 0 for _, e in M.FireLog do if e[1] == "Soldier" and e.player == g and e[3] == "Marked" then n += 1 end end return n end
	local ahead = figure("Stranger", groot.Position + groot.CFrame.LookVector * 60)
	local behind = figure("Behind", groot.Position - groot.CFrame.LookVector * 60)
	local before = marks()
	Remotes.Mark:FireServer(behind); run(0.1)
	check("mark: nothing behind the spotter is marked", marks() == before)
	Remotes.Mark:FireServer(gc); run(0.1)
	check("mark: not yourself", marks() == before)
	Remotes.Mark:FireServer(ahead); run(0.1)
	check("mark: a figure in the glass is marked for the spotter's side", marks() == before + 1)
	ahead:Destroy(); behind:Destroy()
end
-- guns from components (2026-11-12)
do
	as(g)
	local GunParts = M.mockEnv.__require(RS.Shared.GunParts)
	local HeldWeapons = M.mockEnv.__require(SSS.Server.Common.HeldWeapons)
	local Recruit = M.mockEnv.__require(SSS.Server.Common.Recruit)
	local Guns = M.mockEnv.__require(SSS.Server.Guns)
	local whole = true
	for id, gun in GunParts.Guns do
		if not (Firearms.Defs[id] and table.find(Firearms.Defs[id].Slots, "Barrel") and gun.Receiver > 0 and gun.Muzzle > 0 and gun.Barrels.Standard and gun.Barrels.Short and gun.Barrels.Long) then whole = false end
		for _, b in gun.Barrels do if not (b.Asset > 0 and b.Muzzle.Z > 1 and b.End.Z >= b.Muzzle.Z) then whole = false end end
	end
	check("guns: every component gun has a receiver, a muzzle device and three barrels, and takes a barrel in its order", whole)
	local plain = GunParts.Pieces("AKM", {})
	local built = GunParts.Pieces("AKM", { Barrel = { Id = "BarrelShort" }, Muzzle = { Id = "Suppressor" }, Optic = { Id = "PSO" }, Grip = { Id = "Foregrip" } })
	local function piece(list, name) for _, p in list do if p.Name == name then return p end end end
	check("guns: a bare rifle is receiver, standard barrel and its own muzzle device", #plain == 3 and piece(plain, "Barrel").Asset == GunParts.Guns.AKM.Barrels.Standard.Asset and piece(plain, "Muzzle").Asset == GunParts.Guns.AKM.Muzzle)
	check("guns: a short barrel swaps the barrel and moves the muzzle device back", piece(built, "Barrel").Asset == GunParts.Guns.AKM.Barrels.Short.Asset and piece(built, "Muzzle").At.Z < piece(plain, "Muzzle").At.Z)
	check("guns: suppressor, scope and foregrip go on the muzzle, the receiver top and under the handguard", #built == 5 and piece(built, "Muzzle").Asset == GunParts.Accessories.Suppressor.Asset and piece(built, "Optic").At == GunParts.Guns.AKM.Optic and piece(built, "Grip").At == GunParts.Guns.AKM.Barrels.Short.Under)
	check("guns: each build has its own key", GunParts.Key("AKM", {}) ~= GunParts.Key("AKM", { Barrel = { Id = "BarrelLong" } }))
	local model = HeldWeapons.Assemble("M16A1", { Barrel = { Id = "BarrelLong" }, Optic = { Id = "Colt3x" } })
	local comps = {}
	if model then for _, part in model:GetChildren() do comps[part:GetAttribute("Component") or "?"] = true end end
	check("guns: the pieces are put together into one model", model ~= nil and comps.Receiver and comps.Barrel and comps.Muzzle and comps.Optic and not comps.Grip)
	check("guns: a gun that is not made of components is left to its one-piece model", HeldWeapons.Assemble("Mosin", {}) == nil)
	-- the numbers follow the barrel
	local short = Guns.Make("AKM", 100, { Barrel = { Id = "BarrelShort" } })
	local long = Guns.Make("AKM", 100, { Barrel = { Id = "BarrelLong" } })
	check("guns: a short barrel scatters and kicks more, a long one less", Guns.AttMult(short, "Spread") > 1 and Guns.AttMult(long, "Spread") < 1 and Guns.AttMult(short, "Recoil") > Guns.AttMult(long, "Recoil") and Guns.AttMult(long, "Velocity") > 1)
	-- ordering: the barrel is part of the order; the new guns are in the catalog
	local war = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(g).War
	for _, id in { "M16A1", "BarrelShort", "M1Garand", "Glock17", "Revolver", "Suppressor" } do war.Locker[id] = { count = 1, condition = 100 } end
	check("guns: an order takes a barrel", Recruit.Order(war, { Primary = "M16A1", Sidearm = "Glock17", Attachments = { Barrel = "BarrelShort", Muzzle = "Suppressor" } }) == true and war.Loadout.Attachments.Barrel == "BarrelShort")
	check("guns: a barrel does not go in the muzzle slot", Recruit.Order(war, { Primary = "M16A1", Attachments = { Muzzle = "BarrelShort" } }) == false)
	check("guns: the Garand is a rifle, the revolver a sidearm", Recruit.Order(war, { Primary = "M1Garand", Sidearm = "Revolver" }) == true and Recruit.Order(war, { Primary = "Revolver" }) == false)
	local cat = Recruit.Catalog()
	check("guns: the shop lists the new guns and barrels", cat.AK47 ~= nil and cat.AK47.Faction == "Pact" and cat.M1Garand.Faction == "Union" and cat.Glock17 ~= nil and cat.Glock17.Faction == nil and cat.BarrelLong.Slot == "Barrel")
	local rev = Guns.Make("Revolver", 100)
	check("guns: the revolver has six and no safety", rev.Mode == "Semi" and rev.Mag + 1 == 6 and Guns.Trigger(rev) == "fired")
end
-- gun families and changing parts in the field (2026-11-12)
do
	as(g)
	local Recruit = M.mockEnv.__require(SSS.Server.Common.Recruit)
	local Soldiers = M.mockEnv.__require(SSS.Server.Soldiers)
	local Battlefield = M.mockEnv.__require(SSS.Server.Battlefield)
	local D = Firearms.Defs
	check("family: guns of one pattern share a family", D.AKM.Family == "AK" and D.AK47.Family == "AK" and D.M14.Family == "Garand" and D.M1Garand.Family == "Garand" and D.M16A1.Family == "AR")
	local GP = M.mockEnv.__require(RS.Shared.GunParts)
	check("family: one more gun in each family, built on the family's own barrels", D.AK74.Family == "AK" and D.M4A1.Family == "AR" and D.M1A.Family == "Garand"
		and GP.Guns.AK74.Barrels.Short.Asset == GP.Guns.AKM.Barrels.Short.Asset and GP.Guns.AK74.Receiver ~= GP.Guns.AKM.Receiver and GP.Guns.AK74.Muzzle ~= GP.Guns.AKM.Muzzle
		and GP.Guns.M4A1.Barrels.Long.Asset == GP.Guns.M16A1.Barrels.Standard.Asset and GP.Guns.M4A1.Receiver ~= GP.Guns.M16A1.Receiver
		and GP.Guns.M1A.Barrels.Standard.Asset == GP.Guns.M14.Barrels.Standard.Asset and GP.Guns.M1A.Receiver ~= GP.Guns.M14.Receiver)
	check("family: the M16A1's scope sits on its carry handle, higher than on the flat top", GP.Guns.M16A1.Optic.Y > GP.Guns.M4A1.Optic.Y)
	check("family: the AK-74 fires its own round, the M1A is semi only", Firearms.Ammo[D.AK74.Ammo] ~= nil and D.AK74.Ammo ~= D.AKM.Ammo and not table.find(D.M1A.Modes, "Auto"))
	local Guns2 = M.mockEnv.__require(SSS.Server.Guns)
	local bolt, semi, auto = Guns2.Make("Mosin", 100), Guns2.Make("M16A1", 100), Guns2.Make("AKM", 100)
	bolt.Mode, semi.Mode = "Single", "Semi"
	local first = Guns2.Trigger(bolt)
	local second = Guns2.Trigger(bolt)
	Guns2.Rack(bolt)
	bolt.Busy, bolt.LastShot = 0, 0
	check("action: single shot fires once, then nothing until it is racked", Firearms.ActionOf(D.Mosin) == "Single" and first == "fired" and second ~= "fired" and bolt.Chamber == true and Guns2.Trigger(bolt) == "fired")
	check("action: semi-automatic loads the next round itself and has no automatic setting", Firearms.ActionOf(D.M16A1) == "Semi" and Firearms.ActionOf(D.M1Garand) == "Semi" and Guns2.Trigger(semi) == "fired" and semi.Chamber == true and not table.find(D.M16A1.Modes, "Auto"))
	check("action: the AKs are automatic, and the shop says which kind each gun is", Firearms.ActionOf(D.AKM) == "Auto" and Firearms.ActionOf(D.AK47) == "Auto" and Firearms.ActionOf(D.AK74) == "Auto" and auto.Mode == "Safe" and Recruit.Catalog().Mosin.Action == "Single" and Recruit.Catalog().M1Garand.Action == "Semi")
	check("family: each pattern has its own field rule", Firearms.CanField(D.M16A1, "Barrel") and not Firearms.CanField(D.AKM, "Barrel") and Firearms.CanField(D.AKM, "Muzzle") and Firearms.CanField(D.AKM, "Optic") and not Firearms.CanField(D.M14, "Optic") and Firearms.CanField(D.M14, "Muzzle"))
	local war = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(g).War
	for _, id in { "AKM", "BarrelShort", "Suppressor", "Compensator", "PSO", "Foregrip" } do war.Locker[id] = { count = 1, condition = 100 } end
	local okOrder = Recruit.Order(war, { Primary = "AKM", Attachments = { Muzzle = "Suppressor" }, Spares = { "Compensator", "BarrelShort", "Suppressor", "PSO", "Foregrip", "Nonsense" } })
	check("spares: an order carries loose parts that fit, never the same single part twice, at most four", okOrder == true and #war.Loadout.Spares == 4 and not table.find(war.Loadout.Spares, "Suppressor") and not table.find(war.Loadout.Spares, "Nonsense"))
	local kit = Recruit.Deploy(war)
	check("spares: the kit takes them out of the locker", kit ~= nil and #kit.Spares == 4 and war.Locker.Compensator == nil and war.Locker.PSO == nil)
	local faction = M.mockEnv.__require(SSS.Server.Factions).Of and M.mockEnv.__require(SSS.Server.Factions).Of(g) or "Pact"
	local s = Soldiers.Arm(g, kit, faction)
	local w = s.Weapons.Primary
	local root = g.Character.HumanoidRootPart
	local locker
	for _, l in Battlefield.Lockers do if l:GetAttribute("Faction") == faction then locker = l end end
	local lockerPos = locker and (if locker:IsA("Model") then locker.PrimaryPart.Position else locker.Position)
	root.CFrame = M.CF.new(lockerPos + M.V3.new(0, 5000, 0))
	local ok1 = Soldiers.FieldMod(g, "Muzzle", "Compensator")
	check("field: a muzzle device is changed on the spot, and the old one goes in the pouch", ok1 == true and w.Attachments.Muzzle.Id == "Compensator" and #s.Spares == 4)
	local okBusy, whyBusy = Soldiers.FieldMod(g, "Optic", "PSO")
	check("field: the hands are busy while a part goes on", okBusy == false and whyBusy == "Busy")
	w.Busy = 0
	local okB, whyB = Soldiers.FieldMod(g, "Barrel", "BarrelShort")
	check("field: an AK barrel is a barracks job", okB == false and whyB == "Barracks" and w.Attachments.Barrel == nil)
	local okM, whyM = Soldiers.FieldMod(g, "Optic", "Colt3x")
	check("field: a part that is not carried cannot be fitted", okM == false and whyM == "Missing")
	root.CFrame = M.CF.new(lockerPos + M.V3.new(6, 0, 0))
	check("barracks: by the locker the barrel can be changed", Soldiers.FieldMod(g, "Barrel", "BarrelShort") == true and w.Attachments.Barrel.Id == "BarrelShort")
	w.Busy = 0
	check("barracks: a part can be taken off again", Soldiers.FieldMod(g, "Barrel", nil) == true and w.Attachments.Barrel == nil and #s.Spares == 4)
	w.Busy = 0
	-- the AR's upper comes off anywhere
	local ar = Soldiers.Arm(g, { Primary = { Id = "M16A1", Condition = 100 }, Attachments = {}, Spares = { { Id = "BarrelShort", Condition = 80 } } }, faction)
	root.CFrame = M.CF.new(lockerPos + M.V3.new(0, 5000, 0))
	local okAR, whyAR = Soldiers.FieldMod(g, "Barrel", "BarrelShort")
	check("field: an AR barrel is changed in the field, and keeps its wear", okAR == true and ar.Weapons.Primary.Attachments.Barrel.Condition == 80 and M.mockEnv.__require(SSS.Server.Guns).Snapshot(ar.Weapons.Primary).Busy > 5)
end
do -- cybernetic limbs are shipped by the conduit: bought, fitted in the order, on the recruit, back in the locker
	local Recruit = M.mockEnv.__require(SSS.Server.Common.Recruit)
	local Firearms = M.mockEnv.__require(RS.Shared.Firearms)
	local Bodies = M.mockEnv.__require(SSS.Server.Bodies)
	local war = { Faction = "Union", Credits = 5000, Locker = {}, Deployments = 1 }
	check("cyber: the shop sells the four limbs to both sides", Recruit.Buy(war, "CyberArmR") == true and Recruit.Buy(war, "CyberLegL") == true and Recruit.Catalog().CyberArmL.Kind == "Cyber")
	check("cyber: only a limb in the locker can be fitted", Recruit.Order(war, { Cyber = { CyberArmL = true } }) == false and Recruit.Order(war, { Cyber = { CyberArmR = true, CyberLegL = true } }) == true)
	local kit = Recruit.Deploy(war)
	check("cyber: the limbs leave the locker with the recruit", kit.Cyber ~= nil and kit.Cyber.CyberArmR.Condition == 100 and kit.Cyber.CyberLegL ~= nil and war.Locker.CyberArmR == nil)
	local fx = Firearms.CyberEffect(kit.Cyber)
	check("cyber: an arm steadies the aim, limbs take less hurt, a wrecked one gives nothing", fx.Spread < 1 and fx.Limb < 1 and Firearms.CyberEffect({ CyberArmR = { Condition = 0 } }).Spread == 1)
	local look = {}
	local okWear = pcall(function() Bodies.Wear(u.Character, { Cyber = kit.Cyber }) end)
	check("cyber: the body takes the limbs without error", okWear)
end
do -- guns and ammo (round 3): loads, loose rounds by hand, heat, kinds of jam, ricochets, tired arms, dropped guns, tags
	local Recruit = M.mockEnv.__require(SSS.Server.Common.Recruit)
	local Guns = M.mockEnv.__require(SSS.Server.Guns)
	local FA = M.mockEnv.__require(RS.Shared.Firearms)
	local G = Config.Guns
	local malf = FA.MalfunctionChance
	FA.MalfunctionChance = function() return 0 end
	local war = { Faction = "Union", Credits = 5000, Locker = {}, Deployments = 1 }
	check("ammo: the shop sells AP and soft point ammunition", Recruit.Catalog().AmmoAP.Kind == "Ammo" and Recruit.Catalog().AmmoHP ~= nil and Recruit.Buy(war, "AmmoAP") == true and Recruit.Buy(war, "M16A1") == true)
	check("ammo: the order names the load, keeps it, and refuses a load that is not one",
		Recruit.Order(war, { Primary = "M16A1", Load = "AmmoAP" }) == true and Recruit.Order(war, { Primary = "M16A1" }) == true and war.Loadout.Load == "AmmoAP"
		and Recruit.Order(war, { Primary = "M16A1", Load = "Nonsense" }) == false)
	local kit = Recruit.Deploy(war)
	check("ammo: the magazines carry it, with a magazine of loose rounds", kit.Load == "AmmoAP" and kit.Magazines == 3 and kit.Loose == 1 and war.Locker.AmmoAP == nil)
	local faction = M.mockEnv.__require(SSS.Server.Factions).Of and M.mockEnv.__require(SSS.Server.Factions).Of(g) or "Union"
	local s = Soldiers.Arm(g, kit, faction)
	local w = s.Weapons.Primary
	check("ammo: AP in the rifle, twenty loose", w.Load == "AmmoAP" and w.Loose == 20 and Guns.Snapshot(w).Load == "AP" and FA.LoadOf("AmmoAP").Pen > 0)
	-- thumbing rounds in
	w.Spare, w.Mag, w.Busy, w.Reloading = {}, 5, 0, false
	check("mags: no magazine left, R takes out the one in the gun and it stays in the hand", Guns.Reload(w) == true and w.InHand == 5)
	run(w.Def.Reload.EjectMag * 2 + 0.4)
	check("mags: R again thumbs loose rounds into it", Guns.Reload(w) == true and w.HandLoading == true)
	run(15 * G.PerRound + w.Def.Reload.InsertMag * 2 + 0.4)
	check("mags: fifteen rounds thumbed in", w.Mag == 20 and w.Loose == 5 and not w.Reloading)
	-- heat
	w.Mode, w.Chamber, w.Busy, w.Jammed = "Semi", true, 0, false
	w.Heat, w.HeatAt, w.LastShot = 1, M.mockEnv.os.clock(), 0
	check("heat: a cooked barrel will not fire", Guns.Trigger(w) == "hot")
	w.Heat, w.Cooked = 0, nil
	check("heat: cooled, it fires, and the barrel warms", Guns.Trigger(w) == "fired" and Guns.Heat(w) > 0)
	-- kinds of jam
	local kinds = {}
	for _ = 1, 200 do kinds[Guns.JamKind()] = true end
	check("jam: three kinds", kinds.Stovepipe and kinds.Feed and kinds.DoubleFeed)
	w.Jammed, w.JamKind, w.Busy = true, "Stovepipe", 0
	Guns.Rack(w); run(FA.JamSeconds.Stovepipe + 0.3)
	check("jam: T racks a stovepipe out", w.Jammed == false and w.JamKind == nil)
	w.Jammed, w.JamKind, w.Busy = true, "DoubleFeed", 0
	Guns.Rack(w); run(0.2)
	check("jam: a rack does not clear a double feed", w.Jammed == true)
	Guns.Unjam(w); run(FA.JamSeconds.Feed + 0.1)
	check("jam: a double feed takes longer to clear", w.Jammed == true)
	run(FA.JamSeconds.DoubleFeed - FA.JamSeconds.Feed + 0.3)
	check("jam: and then it is clear", w.Jammed == false)
	-- a glance off plate
	local function dummy(at, name)
		local m = M.newInstance("Model"); m.Name = name
		local h = M.newInstance("Humanoid"); h.Parent = m
		local r = M.newInstance("Part"); r.Name = "HumanoidRootPart"; r.CFrame = M.CF.new(at); r.Parent = m
		m.Parent = workspace_
		return m
	end
	local gr = g.Character.HumanoidRootPart
	gr.CFrame = M.CF.new(-5000, 4, -5000)
	local o = gr.Position + M.V3.new(0, 1.5, 0)
	local a, b = dummy(o + M.V3.new(0, 0, -20), "PlateA"), dummy(o + M.V3.new(0, 0, -40), "PlateB")
	local hits = {}
	w.Aiming, w.Steady = true, 0
	Guns.Shoot(g, w, o, M.V3.new(0, 0, -1), function(model, zone, damage)
		table.insert(hits, { model, damage })
		return model == a -- the first one's plate stops it
	end)
	run(0.5)
	check("plate: a round stopped at a glance goes on into the next body, weaker", #hits == 2 and hits[1][1] == a and hits[2][1] == b and hits[2][2] < hits[1][2])
	w.Steady = nil
	a:Destroy(); b:Destroy()
	-- tired arms
	s.Active, w.Aiming = "Primary", true
	Soldiers.FatigueTick(4)
	local tired = w.Fatigue or 0
	w.Aiming = false
	Soldiers.FatigueTick(10)
	check("arms: a rifle held up tires the arms; at rest they come back", tired > 0.2 and w.Fatigue == nil)
	-- a dropped gun
	local ak = Guns.Make("AKM", 70)
	local dropped = Soldiers.DropGun(ak, gr.Position)
	check("drop: a fallen rifle lies with a prompt", dropped ~= nil and dropped.Parent ~= nil and dropped.Holder:FindFirstChild("Grab") ~= nil)
	check("drop: X swaps it for the rifle in your hands, which goes down in its place", Soldiers.Grab(g, dropped) == true and s.Weapons.Primary == ak
		and dropped.Parent == nil and workspace_.DroppedGuns:FindFirstChild("DroppedGun") ~= nil)
	-- tags
	s.Tags = 2
	local credits = war.Credits
	check("tags: the locker pays for tags taken off the fallen", Soldiers.PayTags(war, s) == 2 and war.Credits == credits + 2 * G.TagCredits and s.Tags == 0)
	FA.MalfunctionChance = malf
end
local probe = Intro.Probe(M.V3.new(0, 1500, 5000))
check("intro: the probe builds and clears a cell and a simulation", type(probe) == "string" and probe:find("benches 5") ~= nil and workspace_:FindFirstChild("IntroCell_0") == nil)

-- round 7: reprogrammed thralls stand up beside their conduit's recruit and fight for its side
do
	local PDw = M.mockEnv.__require(SSS.Server.Common.PlayerData)
	local ThrW = M.mockEnv.__require(SSS.Server.Thralls)
	local SoldiersT = M.mockEnv.__require(SSS.Server.Soldiers)
	local du = PDw.Get(u)
	du.War.Thralls = { { Type = "Raider", Name = "UNIT 0002" }, { Type = "Brute", Name = "UNIT 0007" }, { Type = "Raider", Name = "UNIT 0009" } }
	local okF = pcall(SoldiersT.Place, u)
	local list = ThrW.Fielded(u)
	check("thralls: placing the recruit fields up to two of its conduit's thralls", okF and #list == 2 and list[1].Model:GetAttribute("Owner") == u.UserId and list[1].Model:GetAttribute("Faction") == "Union")
	for _ = 1, 30 do M.step(0.1) end
	list[1].Hum:TakeDamage(1e5)
	for _ = 1, 5 do M.step(0.1) end
	check("thralls: a thrall that falls is gone for good", #du.War.Thralls == 2 and du.War.Thralls[1].Name == "UNIT 0007")
	ThrW.Recall(u)
	du.War.Thralls = nil
end

check("no script errors", #M.errors == 0)
for _, e in M.errors do print(e) end
