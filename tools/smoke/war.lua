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
Remotes.Reload:FireServer(); run(2.5)
Firearms.MalfunctionChance = malfunction
w = weaponState(u)
check("staged reload seats a fresh magazine and chambers", w.Mag == 19 and w.Chamber == true and w.Spare == 2)

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
	s.LastHit = { by = g, t = os.clock() }
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
local probe = Intro.Probe(M.V3.new(0, 1500, 5000))
check("intro: the probe builds and clears a cell and a simulation", type(probe) == "string" and probe:find("benches 5") ~= nil and workspace_:FindFirstChild("IntroCell_0") == nil)

check("no script errors", #M.errors == 0)
for _, e in M.errors do print(e) end
