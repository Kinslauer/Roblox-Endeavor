-- The Front: boots the war server and runs two recruits through deploy, shop, the weapon
-- mechanism, a firefight, death, looting, repair, the hill, artillery and a sector rebuild.
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_WAR } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
local Players = game_:GetService("Players")
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
local Remotes = RS.Remotes
local Config = M.mockEnv.__require(RS.Shared.Config)
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

-- die and come back with the ordered rifle
u.Character.Humanoid.Health = 0
run(Config.War.RespawnSeconds + 1)
w = weaponState(u)
check("respawned carrying the ordered M16A1 with magazines", w ~= nil and w.Id == "M16A1" and w.Spare == 3)
local uc, pc = u.Character, p.Character

-- the mechanism: safety, selector, dry fire, reload
local function fireAt(target)
	uc.HumanoidRootPart.CFrame = M.CF.lookAt(target.HumanoidRootPart.Position + M.V3.new(0, 0, 30), target.HumanoidRootPart.Position)
	Remotes.Fire:FireServer(uc.HumanoidRootPart.CFrame.LookVector)
end
pc.HumanoidRootPart.CFrame = M.CF.new(0, 4, 0)
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
check("looted enemy sidearm lands in the locker damaged", snap.Locker.Makarov ~= nil and snap.Locker.Makarov.condition < 70)
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
Remotes.Artillery:FireServer(M.V3.new(tpos.X, 2, tpos.Z)); run(Config.War.Artillery.Delay + 5)
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

check("no script errors", #M.errors == 0)
for _, e in M.errors do print(e) end
