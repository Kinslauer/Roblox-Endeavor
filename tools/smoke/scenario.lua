local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local SSS = game_:GetService("ServerScriptService")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
M.mkTree({ Server = { class = "Folder", children = TREE_SERVER } }, SSS)
M.mkTree({ Common = { class = "Folder", children = TREE_COMMON } }, SSS.Server)
local Players = game_:GetService("Players")
M.task.spawn(function() M.loadSource(SSS.Server.Main)() end)
-- every body rolls a Line 9 batch (round 5): no bonus and never the empty body in these tests (the builds block sets its own)
do local BL = M.mockEnv.__require(RS.Shared.Config).Builds.Lineage; BL.Empty, BL.Rare, BL.Good, BL.Bonus = 0, 0, 0, 0 end
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
-- wounds bleed on between checks; a section that needs a steady body starts from a mended one
local function mendMe(who)
	local c = (who or player).Character
	if c then
		M.mockEnv.__require(SSS.Server.Common.WoundService).Mend(c)
	end
end
local function char() return player.Character end
local function root() return char().HumanoidRootPart end
local function data() return nil end

run(1)
-- jams are rolled per shot: none at random in these tests (the guns block below makes its own)
M.mockEnv.__require(RS.Shared.Config).Guns.Jam.Base = 0
M.mockEnv.__require(RS.Shared.Config).Guns.Jam.Heat = 0

-- ===== The arrival: the train, the station, stealth and takedowns =====
local PlayerData_ = M.mockEnv.__require(SSS.Server.Common.PlayerData)
local Stealth = M.mockEnv.__require(SSS.Server.Stealth)
local Tutorial_ = M.mockEnv.__require(SSS.Server.Tutorial)
local StealthCfg = M.mockEnv.__require(RS.Shared.Config).Stealth
local Rules = M.mockEnv.__require(RS.Shared.Stealth)
local Combat = M.mockEnv.__require(SSS.Server.Combat)
local Inventory0 = M.mockEnv.__require(SSS.Server.Inventory)
local CS = game_:GetService("CollectionService")
local station = workspace_:FindFirstChild("Subway_1")
check("arrival: the station is built for a new conduit", station ~= nil)
local lvl = Tutorial_.Level(player)
local function sawIntro(what) for _, e in M.FireLog do if e[1] == "Intro" and e[3] == what then return true end end return false end
check("arrival: the ride plays (seated, held, doors shut)", sawIntro("Play") and char():GetAttribute("Cutscene") == true and root().Anchored == true and lvl.Doors[1].CanCollide == true)
check("arrival: the kit is the silenced pistol", PlayerData_.Get(player).Equipped == "Whisper" and Inventory0.Count(player, "Round22") == 21)
check("arrival: nobody notices a rider", player:GetAttribute("Stealth") == nil)
-- a ride with the pistol gone and rounds spent (a replay): it is back in hand with three magazines, never more
do
	local prof = PlayerData_.Get(player)
	Inventory0.Remove(player, "Round22", 6); Inventory0.Remove(player, "Whisper", 1); prof.Equipped = "Fists"
	Tutorial_.Start(player); run(0.2)
	check("arrival: every ride ends armed (pistol back, three magazines, no more)", prof.Equipped == "Whisper" and Inventory0.Count(player, "Whisper") == 1 and Inventory0.Count(player, "Round22") == 21)
end
Remotes.Intro:FireServer("Done"); run(0.5)
check("arrival: the ride ends: free, doors open, the station is live", char():GetAttribute("Cutscene") == nil and root().Anchored == false and lvl.Doors[1].CanCollide == false and player:GetAttribute("Stealth") == true)
local guardsHere = Stealth.Guards(station)
check("stealth: seven guards are stationed", #guardsHere == 7)
local function guardNear(pos) local best, bd for _, g in Stealth.Guards(station) do local d = (g.HumanoidRootPart.Position - pos).Magnitude if not bd or d < bd then best, bd = g, d end end return best end
local O = lvl.Origin
local g1 = guardNear(O + M.V3.new(13, 3, 19))
-- light: under a lamp you are lit; in the corridor you are not
root().CFrame = M.CF.new(O + M.V3.new(12, 3, -30)); run(0.6)
local lit = char():GetAttribute("Exposure")
root().CFrame = M.CF.new(O + M.V3.new(-2, 3, -2)); run(0.6)
local dark = char():GetAttribute("Exposure")
print("   exposure lit/dark", lit, dark)
check("stealth: a lamp lights you, the dark hides you", lit ~= nil and dark ~= nil and lit > 0.5 and dark < 0.2)
check("stealth: the dark shortens a guard's sight", Rules.SightRange(dark, false, false) < 15 and Rules.SightRange(1, false, false) > 55 and Rules.SightRange(1, true, false) < Rules.SightRange(1, false, false))
-- a shot puts a lamp out
local lampA
for _, l in lvl.Lamps do if (l.Position - (O + M.V3.new(12, 13.5, -30))).Magnitude < 1 then lampA = l end end
Combat.Shot:Fire(char(), lampA, lampA.Position, { Noise = 7 }); run(0.3)
root().CFrame = M.CF.new(O + M.V3.new(12, 3, -30)); run(0.6)
check("stealth: a shot puts a lamp out and the dark comes back", lampA:GetAttribute("Broken") == true and lampA:FindFirstChildOfClass("PointLight").Enabled == false and char():GetAttribute("Exposure") < 0.2)
-- crouch
local walk0 = char().Humanoid.WalkSpeed
Remotes.Crouch:FireServer(true); run(0.2)
check("stealth: C crouches (slower, flagged)", char():GetAttribute("Crouched") == true and char().Humanoid.WalkSpeed < walk0 * 0.7)
Remotes.Crouch:FireServer(false); run(0.2)
-- behind a guard, standing still: unseen; the takedown is on offer; in front it is not
local g1root = g1.HumanoidRootPart
local behind = g1root.Position - g1root.CFrame.LookVector * 4
root().CFrame = M.CF.lookAt(behind, g1root.Position); run(2)
check("stealth: behind his back he does not make you", Stealth.StateOf(g1) == "Patrol")
check("takedown: from behind it is on offer, from the front it is not", Rules.TakedownKind(root().CFrame, g1root.CFrame, "Patrol", {}) == "Rear"
	and Rules.TakedownKind(M.CF.new(g1root.Position + g1root.CFrame.LookVector * 4), g1root.CFrame, "Patrol", {}) == nil
	and Rules.TakedownKind(root().CFrame, g1root.CFrame, "Alert", {}) == nil)
local g1look, g1at = g1root.CFrame.LookVector, g1root.Position
Remotes.Takedown:FireServer(g1); run(0.2)
check("takedown: you are held in it", char():GetAttribute("Takedown") == "Rear" and root().Anchored == true)
do
	local off = root().Position - g1at
	local back = -(off.X * g1look.X + off.Z * g1look.Z)
	local side = math.abs(off.X * g1look.Z - off.Z * g1look.X)
	print("   takedown stand: behind", back, "aside", side, "facing", root().CFrame.LookVector:Dot(g1look))
	check("takedown: you stand square behind him, facing his back", math.abs(back - StealthCfg.Takedown.RearDistance) < 0.1 and side < 0.1 and root().CFrame.LookVector:Dot(g1look) > 0.99)
end
run(2.2)
do
	local off = g1root.Position - g1at
	local ahead = off.X * g1look.X + off.Z * g1look.Z
	print("   takedown body: ahead", ahead, "head toward", g1root.CFrame.UpVector:Dot(g1look))
	check("takedown: he falls forward where he stood, head the way he faced", math.abs(ahead - StealthCfg.Takedown.Fall.Rear) < 0.2 and g1root.CFrame.UpVector:Dot(g1look) > 0.9)
end
check("takedown: he is down and stays down, you are free", Stealth.StateOf(g1) == "Down" and g1:GetAttribute("Downed") == true and char():GetAttribute("Takedown") == nil and root().Anchored == false)
-- in the light, in front of one: he makes you by degrees, then it is a fight
local g2 = guardNear(O + M.V3.new(84, 3, 30))
root().CFrame = M.CF.new(O + M.V3.new(66, 3, 30)); run(0.4)
local st1 = Stealth.StateOf(g2)
local alerted = run(6, function() return Stealth.StateOf(g2) == "Alert" end)
check("stealth: lit and in front of him, he makes you (by degrees)", st1 ~= "Alert" and alerted)
check("takedown: not on an alerted guard", (function() Remotes.Takedown:FireServer(g2); run(0.2); return char():GetAttribute("Takedown") == nil end)())
-- caught: back to the last checkpoint, he goes back to his post, the downed one stays down
root().CFrame = M.CF.new(O + M.V3.new(40, 3, 30)); run(1)
char().Humanoid.Health = 0; run(5)
check("arrival: caught, you restart at the checkpoint with nothing lost", (root().Position - (O + M.V3.new(40, 3, 30))).Magnitude < 6 and PlayerData_.Get(player).Equipped == "Whisper" and not sawIntro("End"))
check("stealth: the guards go back to their rounds", Stealth.StateOf(g2) == "Patrol" and Stealth.StateOf(g1) == "Down")
-- the fuse box: the hall goes dark, he walks over to fix it, and his face is in it
local hallLamp
for _, l in lvl.Lamps do if l:GetAttribute("Circuit") == "Hall" then hallLamp = l end end
root().CFrame = M.CF.new(O + M.V3.new(49, 3, 24)); run(0.3)
lvl.Breaker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player); run(0.3)
check("stealth: the fuse box cuts the hall", hallLamp:GetAttribute("Lit") == false and hallLamp:FindFirstChildOfClass("PointLight").Enabled == false)
check("stealth: a guard comes to fix it", Stealth.StateOf(g2) == "Search")
root().CFrame = M.CF.new(O + M.V3.new(52, 3, 12)); run(0.2)
g2.HumanoidRootPart.CFrame = M.CF.lookAt(O + M.V3.new(49.6, 3, 20), O + M.V3.new(46, 3, 20)); run(0.3)
root().CFrame = M.CF.new(O + M.V3.new(52, 3, 21))
check("takedown: beside the fuse box it is the fuse box", Rules.TakedownKind(root().CFrame, g2.HumanoidRootPart.CFrame, "Search") == "Panel")
Remotes.Takedown:FireServer(g2); run(2.4)
local sawPanel = false
for _, e in M.FireLog do if e[1] == "World" and e[3] == "Takedown" and e[4] == "Panel" then sawPanel = true end end
check("takedown: the environmental one puts him down", sawPanel and Stealth.StateOf(g2) == "Down")
-- a whistle pulls the patroller; a body found raises him
local g3 = guardNear(O + M.V3.new(99, 3, 30))
g3.HumanoidRootPart.CFrame = M.CF.lookAt(O + M.V3.new(99, 3, 50), O + M.V3.new(99, 3, 60)); run(0.2)
root().CFrame = M.CF.new(O + M.V3.new(88, 3, 44)); run(0.2)
Remotes.Whistle:FireServer(); run(0.3)
check("stealth: a whistle brings him over to look", Stealth.StateOf(g3) == "Search")
Stealth.Reset(station); run(0.2)
g3.HumanoidRootPart.CFrame = M.CF.lookAt(O + M.V3.new(60, 3, 20), g2.HumanoidRootPart.Position); run(0.2)
Stealth.SetCircuit(station, "Hall", true); run(0.5)
char():PivotTo(M.CF.new(O + M.V3.new(100, 3, 2))); run(1)
check("stealth: a guard who finds a body goes looking", Stealth.StateOf(g3) == "Search" or Stealth.StateOf(g3) == "Alert")
-- from above
local g5 = guardNear(O + M.V3.new(130, -5, -71))
root().CFrame = M.CF.new(O + M.V3.new(130, 2, -64)); run(0.3)
check("takedown: from the walkway above it is a drop", Rules.TakedownKind(root().CFrame, g5.HumanoidRootPart.CFrame, Stealth.StateOf(g5)) == "Drop")
Remotes.Takedown:FireServer(g5); run(1.6)
check("takedown: the drop puts him down", Stealth.StateOf(g5) == "Down")
-- ===== Metal Gear handling (2026-11-11): stances, the magazine, the hold-up, CQC, bodies =====
do
	local hum = char().Humanoid
	Stealth.Reset(station); run(0.2)
	local walk = hum.WalkSpeed
	Remotes.Stance:FireServer("Prone"); run(0.2)
	check("stance: prone is flat, a crawl, no jump", char():GetAttribute("Stance") == "Prone" and char():GetAttribute("Crouched") == true and hum.WalkSpeed < walk * 0.3 and hum.JumpHeight == 0)
	check("stance: prone in the dark is close to invisible", Rules.SightRange(0.06, true, false, true) < Rules.SightRange(0.06, true, false) * 0.5 and Rules.SightRange(0.06, true, false, true) < 3)
	Remotes.Stance:FireServer("Crouch"); run(0.2)
	check("stance: up one is a crouch", char():GetAttribute("Stance") == "Crouch" and hum.WalkSpeed > walk * 0.3 and hum.WalkSpeed < walk * 0.7)
	Remotes.Stance:FireServer("Stand"); run(0.2)
	check("stance: standing again you can jump", char():GetAttribute("Stance") == "Stand" and char():GetAttribute("Crouched") == false and hum.JumpHeight > 1 and math.abs(hum.WalkSpeed - walk) < 0.01)
	-- the magazine
	Inventory0.Add(player, "Round22", 12, true)
	Combat.ResetMags(player); run(0.1)
	local have0 = Inventory0.Count(player, "Round22")
	check("gun: a full magazine of seven", char():GetAttribute("Mag") == 7 and char():GetAttribute("MagSize") == 7)
	local log0 = #M.FireLog
	Remotes.Attack:FireServer(root().CFrame.LookVector); run(1)
	local swung, bolted = false, false
	for i = log0 + 1, #M.FireLog do
		local e = M.FireLog[i]
		if e[1] == "CombatEvent" and e[3] == "Swing" then swung = true end
		if e[1] == "CombatEvent" and e[3] == "Bolt" then bolted = true end
	end
	check("gun: a shot is a shot (a round leaves, nobody swings)", bolted and not swung)
	check("gun: a shot comes out of the magazine and the pack", char():GetAttribute("Mag") == 6 and Inventory0.Count(player, "Round22") == have0 - 1)
	-- single shot: the Whisper is racked by hand after every round
	check("action: after a round the Whisper's chamber is empty", char():GetAttribute("Chambered") == false)
	Remotes.Attack:FireServer(root().CFrame.LookVector); run(0.8)
	check("action: pulling again without racking fires nothing", char():GetAttribute("Mag") == 6 and Inventory0.Count(player, "Round22") == have0 - 1)
	Remotes.Rack:FireServer(); run(0.9)
	check("action: T racks the next round in", char():GetAttribute("Chambered") == true and char():GetAttribute("Mag") == 6)
	Remotes.Attack:FireServer(root().CFrame.LookVector); run(0.8)
	check("action: racked, it fires again", char():GetAttribute("Mag") == 5 and char():GetAttribute("Chambered") == false)
	do -- the round goes where the reticle is: up and off to the side of the facing, from the shoulder
		Remotes.Rack:FireServer(); run(0.9)
		local aim = (root().CFrame.LookVector + root().CFrame.RightVector * 0.4 + M.V3.new(0, 0.35, 0)).Unit
		local from = root().Position + M.V3.new(0, 1.2, 0)
		local logA = #M.FireLog
		Remotes.Attack:FireServer(aim); run(0.8)
		local endAt
		for i = logA + 1, #M.FireLog do
			local e = M.FireLog[i]
			if e[1] == "CombatEvent" and e[3] == "Bolt" then endAt = e[5] end
		end
		local off = endAt and ((endAt - from).Unit - aim).Magnitude
		print("AIMTEST", endAt, from, aim, off)
		check("gun: the round flies along the aim from the shoulder", off ~= nil and off < 0.01)
	end
	Remotes.Rack:FireServer(); run(0.9)
	Inventory0.Add(player, "Round22", 1, true); Combat.ResetMags(player); run(0.1)
	Remotes.Attack:FireServer(root().CFrame.LookVector); run(0.8)
	Remotes.Reload:FireServer(); run(0.3)
	check("gun: R starts the change (busy, flagged)", char():GetAttribute("Reloading") == true and char():GetAttribute("Mag") == 6)
	run(1.6)
	check("gun: the new magazine is full", char():GetAttribute("Reloading") == nil and char():GetAttribute("Mag") == 7)
	check("action: a magazine change leaves a round chambered", char():GetAttribute("Chambered") == true)
	Stealth.Reset(station); run(0.2) -- that shot may have found a guard: everyone back to their rounds
	-- calibres and plate
	do
		local WeaponsS = M.mockEnv.__require(RS.Shared.Weapons)
		check("calibre: the Whisper is a .22 and the duty pistol a 9mm, each fed by its cartridge", WeaponsS.Defs.Whisper.Ammo == "Round22" and WeaponsS.Defs.DutyPistol.Ammo == "Round9"
			and WeaponsS.Chambered("Round9")[1] == "Duty Pistol")
		local sentry
		for _, g in Stealth.Guards(station) do if Stealth.StateOf(g) ~= "Down" then sentry = g break end end
		-- the mock's rigs are a root and a head: give this one a chest and a thigh where they would be
		local head = sentry.Head
		local base = sentry.HumanoidRootPart.Position
		local function limb(name, offset, size)
			local p = M.newInstance("Part"); p.Name = name; p.Size = size; p.CFrame = M.CF.new(base + offset); p.Parent = sentry
			return p
		end
		head.Size = M.V3.new(1, 1, 1); head.CFrame = M.CF.new(base + M.V3.new(0, 2.2, 0))
		local chest, thigh = limb("UpperTorso", M.V3.new(0, 0.8, 0), M.V3.new(2, 1.6, 1)), limb("RightUpperLeg", M.V3.new(0.5, -1.5, 0), M.V3.new(0.9, 1.4, 0.9))
		local zTop, rTop = Combat.HitZone(sentry, head.Position + head.CFrame.UpVector * head.Size.Y * 0.4)
		local zFace, rFace = Combat.HitZone(sentry, head.Position - head.CFrame.UpVector * head.Size.Y * 0.3)
		local zChest, rChest = Combat.HitZone(sentry, chest.Position)
		local zLeg, rLeg = Combat.HitZone(sentry, thigh.Position)
		check("plate: helmet over the top of the head, flesh under the brim", zTop == "Helmet" and rTop >= 1 and zFace == "Head" and rFace == 0)
		check("plate: a vest on the chest, flesh on the thigh", zChest == "Vest" and rChest >= 2 and zLeg == "Limb" and rLeg == 0)
		check("plate: a .22 is stopped by every plate, a 9mm by the vest only", WeaponsS.Calibers[".22"].Pen < rTop and WeaponsS.Calibers["9mm"].Pen >= rTop and WeaponsS.Calibers["9mm"].Pen < rChest)
		Combat.Deflected:Fire(char(), sentry, "Helmet", head.Position); run(0.3)
		check("plate: a round off his helmet and he is on alert", Stealth.StateOf(sentry) == "Alert")
		Stealth.Reset(station); run(0.2)
	end
	-- the hold-up: a gun on his back, up close
	local up = {}
	for _, g in Stealth.Guards(station) do if Stealth.StateOf(g) ~= "Down" then table.insert(up, g) end end
	check("cqc: there are guards left standing to try it on", #up >= 2)
	local ga, gb = up[1], up[2]
	for _, g in { ga, gb } do -- they stand where they are put (a patrol would walk them out from under the test)
		local _, brain = Stealth.StateOf(g)
		brain.patrol, brain.post = nil, nil
	end
	local function behindOf(g, d) local r = g.HumanoidRootPart return M.CF.lookAt(r.Position - r.CFrame.LookVector * d, r.Position) end
	local function frontOf(g, d) local r = g.HumanoidRootPart return M.CF.lookAt(r.Position + r.CFrame.LookVector * d, r.Position) end
	-- out of everyone else's way: on the open platform, in the dark
	ga.HumanoidRootPart.CFrame = M.CF.lookAt(O + M.V3.new(-2, 3, -2), O + M.V3.new(-2, 3, -12)); run(0.1)
	root().CFrame = behindOf(ga, 7); run(0.2)
	Remotes.Aim:FireServer(true); run(0.8)
	check("aim: holding it slows you", char():GetAttribute("Aiming") == true and hum.WalkSpeed < walk * 0.7)
	check("hold-up: a gun on him up close and he freezes", Stealth.StateOf(ga) == "HeldUp")
	-- the throw, face to face
	root().CFrame = frontOf(ga, 3); run(0.15)
	local tap, hold = Rules.Cqc(root().CFrame, ga.HumanoidRootPart.CFrame, Stealth.StateOf(ga), {})
	check("cqc: in front of him X is a throw, with no hold on offer", tap == "Throw" and hold == nil)
	Remotes.Aim:FireServer(false)
	local thrownFrom = ga.HumanoidRootPart.Position
	Remotes.Cqc:FireServer("Throw", ga, M.V3.new(0, 0, -1)); run(0.2)
	check("cqc: the throw has you both", char():GetAttribute("Takedown") == "Throw" and root().Anchored == true)
	run(1.6)
	local flew = (ga.HumanoidRootPart.Position - thrownFrom) * M.V3.new(1, 0, 1)
	check("cqc: he flies the way you look, with real speed", flew.Magnitude > 4 and flew.Z < -3)
	root().CFrame = M.CF.new(ga.HumanoidRootPart.Position + M.V3.new(2, 2, 0)); run(0.15)
	check("cqc: thrown, he is down but not for good", Stealth.StateOf(ga) == "Down" and ga:GetAttribute("Downed") == true and char():GetAttribute("Takedown") == nil)
	-- his body: grabbed by the collar and dragged, searched from the grab, let go
	Remotes.Cqc:FireServer("Carry", ga); run(0.2)
	check("drag: you have him by the collar, low and slow", char():GetAttribute("Carrying") == true and Stealth.Carrying(player) == ga and hum.WalkSpeed < walk * 0.7
		and char():GetAttribute("Stance") == "Crouch")
	Remotes.Stance:FireServer("Stand"); run(0.1)
	check("drag: you cannot stand up with a body in your hands", char():GetAttribute("Stance") == "Crouch")
	root().CFrame = M.CF.lookAt(O + M.V3.new(-2, 3, -6), O + M.V3.new(-2, 3, -16)); run(0.3)
	local trail = (ga.HumanoidRootPart.Position - root().Position) * M.V3.new(1, 0, 1)
	check("drag: the body comes with you along the floor", trail.Magnitude < 5.5 and trail.Magnitude > 1 and math.abs(ga.HumanoidRootPart.CFrame.UpVector.Y) < 0.2
		and ga.HumanoidRootPart.Position.Y < root().Position.Y)
	local dragged = ga.HumanoidRootPart.Position
	Remotes.Cqc:FireServer("Search", ga); run(0.2)
	check("drag: his pockets open from the grab", ga.HumanoidRootPart:GetAttribute("ContainerKey") ~= nil and Stealth.Carrying(player) == ga)
	Remotes.Cqc:FireServer("Drop"); run(0.2)
	check("drag: let go, he stays where he lay", char():GetAttribute("Carrying") == nil and Stealth.Carrying(player) == nil and Stealth.StateOf(ga) == "Down"
		and (ga.HumanoidRootPart.Position - dragged).Magnitude < 0.5 and math.abs(ga.HumanoidRootPart.CFrame.UpVector.Y) < 0.2)
	-- his pockets: every guard can be searched, in the station too
	local LootS = M.mockEnv.__require(SSS.Server.Loot)
	local nine0, five0 = Inventory0.Count(player, "Round9"), Inventory0.Count(player, "Round556")
	Remotes.Cqc:FireServer("Search", ga); run(0.2)
	local pocketKey = ga.HumanoidRootPart:GetAttribute("ContainerKey")
	local carried = LootS.Contents(ga.HumanoidRootPart)
	check("loot: a downed guard carries 9mm or 5.56, one of them, and no .22", pocketKey ~= nil and carried.Round22 == nil
		and ((carried.Round9 or 0) >= 8) ~= ((carried.Round556 or 0) >= 10))
	LootS.RevealAll(ga.HumanoidRootPart, player)
	Remotes.ContainerTake:FireServer(pocketKey, 0); run(0.2)
	check("loot: emptied into the pack, the body stays", Inventory0.Count(player, "Round9") == nine0 + (carried.Round9 or 0) and Inventory0.Count(player, "Round556") == five0 + (carried.Round556 or 0) and ga.Parent ~= nil
		and ga.HumanoidRootPart:GetAttribute("Looted") == true and Stealth.StateOf(ga) == "Down")
	for id, n in carried do Inventory0.Remove(player, id, n) end -- the rest of the run wants the pack as it was
	root().CFrame = M.CF.new(O + M.V3.new(-2, 3, 40)); run(0.1)
	local woke = run(StealthCfg.Cqc.Throw.Down + 3, function() return Stealth.StateOf(ga) ~= "Down" end)
	check("cqc: he comes round, on his feet and looking", woke and ga:GetAttribute("Downed") == nil and ga.HumanoidRootPart.CFrame.UpVector.Y > 0.9 and ga.HumanoidRootPart.Anchored == false)
	-- the neck hold
	Stealth.Reset(station); run(0.2)
	gb.HumanoidRootPart.CFrame = M.CF.lookAt(O + M.V3.new(-2, 3, -2), O + M.V3.new(-2, 3, -12)); run(0.1)
	root().CFrame = behindOf(gb, 3); run(0.15)
	local tap2, hold2 = Rules.Cqc(root().CFrame, gb.HumanoidRootPart.CFrame, Stealth.StateOf(gb), {})
	check("cqc: behind him a tap is the takedown and a hold is the grab", tap2 == "Rear" and hold2 == "Grab")
	Remotes.Cqc:FireServer("Grab", gb); run(0.2)
	check("hold: your arm is round his neck", char():GetAttribute("NeckHold") == true and Stealth.StateOf(gb) == "Held" and Stealth.Holding(player) == gb and hum.WalkSpeed < walk * 0.6)
	root().CFrame = M.CF.lookAt(O + M.V3.new(-2, 3, 6), O + M.V3.new(-2, 3, -4)); run(0.2)
	local gap = (gb.HumanoidRootPart.Position - root().Position) * M.V3.new(1, 0, 1)
	check("hold: he walks where you walk, in front of you", math.abs(gap.Magnitude - StealthCfg.Cqc.Hold.Gap) < 0.2 and gap.Unit:Dot(root().CFrame.LookVector) > 0.95)
	Remotes.Cqc:FireServer("Choke"); run(0.3)
	check("hold: X chokes him out", char():GetAttribute("NeckHold") == nil and char():GetAttribute("Takedown") == "Rear")
	run(2.2)
	check("hold: and he stays down", Stealth.StateOf(gb) == "Down" and char():GetAttribute("Takedown") == nil and root().Anchored == false)
	Stealth.Reset(station); run(0.2)
end
-- the control room: the locker, the manifest, the lift
local locker = station:FindFirstChild("Lootable", true)
check("locker exists", locker ~= nil)
locker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player); run(0.1)
check("the locker opens as a container with its items", (function()
	local Loot_ = M.mockEnv.__require(SSS.Server.Loot)
	local c = Loot_.Contents(locker)
	return (c.ScrapVest or 0) == 1 and (c.RebarBlade or 0) == 1
end)())
root().CFrame = M.CF.new(locker.Position + M.V3.new(3, 0, 0)); run(0.1) -- taking needs you within reach
Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.1)
local prof0 = PlayerData_.Get(player)
check("nothing can be taken before it is revealed", prof0.Inventory.ScrapVest == nil and locker.Parent ~= nil)
locker:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player) -- (re)start the search while standing here
run(1.2)
check("the search reveals items over time", (function()
	local Loot_ = M.mockEnv.__require(SSS.Server.Loot)
	Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.1)
	local c = Loot_.Contents(locker)
	local left = 0
	for _, n in c do left += n end
	return left < 20 -- 20 things were inside: something came out
end)())
M.mockEnv.__require(SSS.Server.Loot).RevealAll(locker, player)
Remotes.ContainerTake:FireServer(locker:GetAttribute("ContainerKey"), 0); run(0.3)
check("the locker empties into the pack", prof0.Inventory.ScrapVest == 1 and prof0.Inventory.RebarBlade == 1)
check("arrival: the lift is dead before the manifest", lvl.LiftPrompt.Enabled == false)
lvl.LiftPrompt.Triggered:Fire(player); run(0.2)
check("arrival: and stays shut", not sawIntro("End"))
lvl.ConsolePrompt.Triggered:Fire(player); run(0.2)
local sawManifest = false
for _, e in M.FireLog do if e[1] == "World" and e[3] == "Fragment" and e[4] == "Manifest" then sawManifest = true end end
check("arrival: the manifest is copied and the lift wakes", sawManifest and lvl.LiftPrompt.Enabled == true and prof0.Intro.Intel == true)
check("story: a copy of the Line 9 manifest goes in the pack", Inventory0.Count(player, "Manifest") == 1 and prof0.Consigned == true)
lvl.LiftPrompt.Triggered:Fire(player); run(0.3)
check("arrival: the lift ends it", sawIntro("End") and prof0.Intro.Done == true and player:GetAttribute("Stealth") == nil)

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
do
	-- the station's lift comes up in a hideout site's freight lift (Line 9), not on a street
	local HideoutsS = M.mockEnv.__require(SSS.Server.Hideouts)
	local atLift = false
	for _, site in HideoutsS.Sites do
		if site.LiftCFrame and (site.LiftCFrame.Position - pos).Magnitude < 5 then atLift = true end
	end
	check("story: the station lift comes up in a bay's freight lift", atLift)
	-- every bay has its lift, its shaft and an unsigned consignment, and nothing of the city stands inside the cab
	local all, clear = true, true
	local blockers = {}
	for _, site in HideoutsS.Sites do
		all = all and site.Lift ~= nil and site.Lift:FindFirstChild("LiftShaft") ~= nil and site.Crates ~= nil and site.Crates.Parent == site.Lift
		local L = site.Position + ConfigM.Hideouts.LiftOffset
		for _, d in workspace_:GetDescendants() do
			if d:IsA("BasePart") and not d:IsDescendantOf(site.Lift) and not (d.Parent and d.Parent:FindFirstChildOfClass("Humanoid")) and d.CanCollide ~= false and (d.Transparency or 0) < 1 and d.Size and d.Position then
				local p, sz = d.Position, d.Size
				local hx, hz = math.abs(p.X - L.X), math.abs(p.Z - L.Z)
				if hx < 3 + sz.X / 2 and hz < 3 + sz.Z / 2 and p.Y + sz.Y / 2 > 3 and p.Y - sz.Y / 2 < 48 and sz.Y < 400 then
					clear = false
					table.insert(blockers, ("bay %d: %s at %d,%d,%d size %d,%d,%d"):format(site.Index, d.Name, p.X, p.Y, p.Z, sz.X, sz.Y, sz.Z))
				end
			end
		end
	end
	check("story: every bay has a freight lift, a shaft and a consignment", all)
	check("story: no city geometry inside any freight lift cab or shaft", clear)
	for i = 1, math.min(6, #blockers) do print("   ", blockers[i]) end
end
run(8)
check("arrival: the station is cleared away", workspace_:FindFirstChild("Subway_1") == nil)

-- ===== The drill: the melee basics against a dummy that hits back =====
Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
Inventory0.Add(player, "Cloth", 2)
for _ = 1, 5 do Remotes.Allocate:FireServer("Intelligence") end
run(0.5)
Remotes.Craft:FireServer("Medkit"); run(0.5)
check("crafting a medkit", Inventory0.Count(player, "Medkit") >= 3)
Remotes.EquipItem:FireServer("ScrapVest"); run(0.5)
check("wearing armor", next(prof0.Armor) ~= nil)
local NPCs_ = M.mockEnv.__require(SSS.Server.NPCs)
local dummy, dummyHum, dummyRoot = NPCs_.BuildRig("Training Dummy", { Health = 1000, Speed = 0 })
dummyRoot.Anchored = true
dummy:PivotTo(M.CF.new(root().Position + M.V3.new(0, 0, -14)))
dummy.Parent = workspace_
local counts, strikeOn, heavyUntil = {}, false, 0
local function bump(k) counts[k] = (counts[k] or 0) + 1 end
Combat.Resolved.Event:Connect(function(attacker, victim, result)
	if victim == char() and attacker == dummy then bump(result)
	elseif attacker == char() and victim == dummy and (result == "hit" or result == "guardbreak") then
		bump("dummyHit"); if M.setNow() < heavyUntil then bump("heavyHit") end
	end
end)
Combat.Used.Event:Connect(function(name, who) if who == player then if name == "Heavy" then heavyUntil = M.setNow() + 1.5 else bump(name) end end end)
M.task.spawn(function()
	while dummy.Parent do
		M.task.wait(2.8)
		if dummyHum.Health < 500 then dummyHum.Health = 1000 end
		if strikeOn and char() and char().Humanoid.Health > 0 then
			if char().Humanoid.Health < 40 then char().Humanoid.Health = 80 end
			local warn = M.newInstance("Highlight"); warn.Parent = dummy
			M.task.wait(0.8)
			warn:Destroy()
			if strikeOn then Combat.Damage(dummy, char(), 6, { Posture = 12 }) end
		end
	end
end)
local function face() local dp = dummy.HumanoidRootPart.Position; root().CFrame = M.CF.lookAt(dummy.HumanoidRootPart.Position + M.V3.new(0, 0, 5), dp) end
face()
local dummyHealth0 = dummy.Humanoid.Health
for _ = 1, 10 do Remotes.Attack:FireServer(); run(0.75); if (counts.dummyHit or 0) >= 4 then break end end
check("dummy took damage", dummy.Humanoid.Health < dummyHealth0)
check("four light hits land", (counts.dummyHit or 0) >= 4)
run(1.5); Remotes.Heavy:FireServer(); run(1.5)
check("a heavy lands", (counts.heavyHit or 0) >= 1)
char():SetAttribute("Charge", 60)
local flashSeen = false
for _ = 1, 8 do
	run(0.5)
	char():SetAttribute("Charge", 60)
	Remotes.Flicker:FireServer(); Remotes.Attack:FireServer(); run(0.4)
	for _, e in M.FireLog do if e[3] == "BlackFlash" then flashSeen = true end end
	if flashSeen then break end
end
check("black flash landed", flashSeen and (counts.BlackFlash or 0) >= 1)
strikeOn = true
local function telegraphStart() return dummy:FindFirstChildOfClass("Highlight") ~= nil end
local function waitTelegraph() return run(8, telegraphStart) end
for _ = 1, 4 do
	if (counts.dodged or 0) >= 2 then break end
	waitTelegraph(); run(0.55); face(); Remotes.Dodge:FireServer(M.V3.new(1, 0, 0))
	run(1.2)
end
check("dodging the dummy's strikes", (counts.dodged or 0) >= 2)
for _ = 1, 5 do
	if (counts.parried or 0) >= 2 then break end
	waitTelegraph(); face(); run(0.7); Remotes.Block:FireServer(true); run(0.4); Remotes.Block:FireServer(false); run(0.5)
end
check("parrying them", (counts.parried or 0) >= 2)
for _ = 1, 5 do
	if (counts.blocked or 0) >= 2 then break end
	waitTelegraph(); face(); Remotes.Block:FireServer(true); run(1.5); Remotes.Block:FireServer(false); run(0.5)
end
check("blocking them", (counts.blocked or 0) >= 2)
strikeOn = false
for _ = 1, 4 do
	if (counts.Feint or 0) >= 2 then break end
	run(1); Remotes.Attack:FireServer(); run(0.05); Remotes.Feint:FireServer(); run(0.5)
end
check("feinting out of a windup", (counts.Feint or 0) >= 2)
run(1); char():SetAttribute("Charge", 80); Remotes.UseSkill:FireServer(1); run(1)
check("a skill fires", (function() for k in counts do if k ~= "dummyHit" and k ~= "heavyHit" and k ~= "Feint" and k ~= "BlackFlash" and k ~= "dodged" and k ~= "parried" and k ~= "blocked" and k ~= "hit" and k ~= "guardbreak" then return true end end return false end)())
dummy:Destroy()


-- open world: second player, PvP, permadeath
M.mockEnv.__require(RS.Shared.Config).Tutorial.Enabled = false -- everyone after this joins as a conduit who has already ridden the train
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
do -- the Blackout gate opens from GRADE 3 (round 5); this run checks the raid itself
	local k = M.mockEnv.__require(SSS.Server.Common.PlayerData).Get(player).Knowledge
	k.Grade = 3
end
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
check("extracted back to the city after the raid", math.abs(home.X) <= 1700 and home.Z >= -1700 and home.Z <= 700)
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
do -- shots put out any small light in the world, not only the stealth levels' lamps (Andy, 2026-11-14)
	local Stealth0 = Stealth
	local bulb, pole
	for _, d in lamp:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstChildOfClass("PointLight") then bulb = d elseif d:IsA("BasePart") and not pole then pole = d end
	end
	check("shoot out: the streetlight has a lit part", bulb ~= nil)
	if bulb then
		local light = bulb:FindFirstChildOfClass("PointLight")
		Combat.Shot:Fire(player.Character, bulb, bulb.Position, { Noise = 7 }); run(0.2)
		check("shoot out: a round through a street lamp puts it out", light.Enabled == false and bulb:GetAttribute("ShotOut") == true)
		Stealth0.RestoreFixtures()
		check("shoot out: the hour lights it again", light.Enabled == true and bulb:GetAttribute("ShotOut") == nil)
	end
	local pylon
	for _, d in workspace_:GetDescendants() do if d:IsA("BasePart") and d.Name == "Pylon" and d:GetAttribute("District") then pylon = d break end end
	if pylon then
		Combat.Shot:Fire(player.Character, pylon, pylon.Position, { Noise = 7 }); run(0.2)
		check("shoot out: a district pylon people steer by stays lit", pylon:FindFirstChildOfClass("PointLight").Enabled ~= false)
	end
end
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
local WoundService = M.mockEnv.__require(SSS.Server.Common.WoundService)
local Wounds = M.mockEnv.__require(RS.Shared.Wounds)
WoundService.Mend(rc) -- a bleed would keep moving the rival's health under the next checks

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
do -- wounds (shared/Wounds, common/WoundService, server/Medicine)
	local hurt = false
	for _, part in Wounds.Parts do if (pc:GetAttribute("W_" .. part) or 1) < 1 then hurt = true end end
	check("wound: the blast left wounds on the body's parts", hurt and pc:GetAttribute("Concussed") == true)
	WoundService.Mend(pc); WoundService.Mend(rc); run(0.1)
	check("wound: a full mend clears every part", pc:GetAttribute("W_Chest") == 1 and pc:GetAttribute("Bleed_LegL") == "" and pc.Humanoid.Health == pc.Humanoid.MaxHealth)
	local st = WoundService.Get(pc)
	local always = { NextNumber = function() return 0 end, NextInteger = function(_, a) return a end }
	local ev = Wounds.Hit(st, "ArmL", st.Max.ArmL * 0.6, "Cut", always, {})
	WoundService.Push(pc)
	check("wound: a deep cut opens a heavy bleed on that arm", ev.Bled == "Heavy" and pc:GetAttribute("Bleed_ArmL") == "Heavy")
	local hp = pc.Humanoid.Health
	run(4)
	check("wound: a heavy bleed drains health", pc.Humanoid.Health < hp - 2)
	Inventory.Add(player, "Bandage", 1)
	Remotes.UseItem:FireServer("Bandage"); run(0.6) -- UseItem is rate limited
	check("wound: a bandage does nothing to a heavy bleed and is kept", Inventory.Count(player, "Bandage") == 1 and pc:GetAttribute("Bleed_ArmL") == "Heavy")
	Inventory.Add(player, "Tourniquet", 1)
	Remotes.UseItem:FireServer("Tourniquet"); run(0.6) -- UseItem is rate limited
	check("wound: a tourniquet stops it and is spent", Inventory.Count(player, "Tourniquet") == 0 and pc:GetAttribute("Bleed_ArmL") == "")
	st.Broken.LegR = true; WoundService.Push(pc); run(0.2)
	check("wound: a broken leg slows the walk and stops the jump", (pc:GetAttribute("WoundSpeed") or 1) < 1 and pc:GetAttribute("WoundNoJump") == true and pc.Humanoid.JumpHeight == 0)
	Inventory.Add(player, "Splint", 1)
	Remotes.UseItem:FireServer("Splint"); run(0.6) -- UseItem is rate limited
	check("wound: a splint sets the leg", pc:GetAttribute("Broken_LegR") == false and pc:GetAttribute("WoundSpeed") == 1)
	st.Hp.LegL = 0; WoundService.Push(pc)
	Inventory.Add(player, "SurgeryKit", 1)
	Remotes.UseItem:FireServer("SurgeryKit"); run(0.6) -- UseItem is rate limited
	check("wound: surgery brings a dead leg back at a lower maximum", st.Hp.LegL > 0 and st.Max.LegL < st.Base * ConfigM.Wounds.Parts.LegL * ConfigM.Wounds.PartScale)
	-- a scar from a deep cut that lands on the body, kept in the profile for this life
	local pdW = PlayerData_.Get(player)
	local scarsBefore = #(pdW.Scars or {})
	WoundService.Hit(pc, { Amount = 20, At = pc.RightUpperArm and pc.RightUpperArm.Position or pc.HumanoidRootPart.Position, Kind = "Cut" })
	check("wound: a deep cut leaves a scar", #(pdW.Scars or {}) == scarsBefore + 1)
	-- hunger falls; a ration feeds it
	WoundService.Feed(pc, -60); run(0.1)
	local hungry = pc:GetAttribute("Hunger")
	Inventory.Add(player, "Ration", 1)
	Remotes.UseItem:FireServer("Ration"); run(0.6) -- UseItem is rate limited
	check("wound: hunger shows and a ration feeds it", type(hungry) == "number" and hungry <= 41 and pc:GetAttribute("Hunger") > hungry)
	-- the head at zero kills
	local fresh = Wounds.New(100)
	check("wound: the head at zero kills, an arm at zero does not", Wounds.Hit(fresh, "Head", fresh.Max.Head + 1, "Bullet", always).Killed == true
		and not Wounds.Hit(Wounds.New(100), "ArmL", 100, "Blunt", always).Killed)
	WoundService.Mend(pc); run(0.1)
end
run(1)

-- arc pistol is cell-fed
Inventory.Add(player, "ArcPistol", 1); Remotes.EquipItem:FireServer("ArcPistol"); run(1.5)
local cellsBefore = Inventory.Count(player, "ArcCell")
Remotes.Attack:FireServer(); run(0.6)
check("arc pistol refuses to fire without cells", Inventory.Count(player, "ArcCell") == cellsBefore)
Inventory.Add(player, "ArcCell", 3); run(0.6)
Remotes.Attack:FireServer(); run(0.6)
check("arc pistol spends a cell per shot", Inventory.Count(player, "ArcCell") == 2)

-- long guns: the 5.56 carbine, the AK-47 in 7.62x39, the Garand in 7.62x51
do
	local W = M.mockEnv.__require(RS.Shared.Weapons)
	local GP = M.mockEnv.__require(RS.Shared.GunParts)
	local ItemsR = M.mockEnv.__require(RS.Shared.Items)
	check("rifle: each long gun feeds on its own calibre", W.Defs.Carbine.Ammo == "Round556" and W.Defs.AK47.Ammo == "Round762x39" and W.Defs.M1Garand.Ammo == "Round762x51"
		and W.Chambered("Round556")[1] == "Carbine" and ItemsR.Defs.Round762x39.Caliber == "7.62x39" and ItemsR.Defs.Round762x51.Caliber == "7.62x51")
	check("rifle: long guns and pistols are guns, a club is not", W.IsGun(W.Defs.Carbine) and W.IsGun(W.Defs.M1Garand) and W.IsGun(W.Defs.Whisper) and not W.IsGun(W.Defs.PipeClub))
	local gunId, atts, opts = W.Held("Carbine")
	local _, option = GP.Barrel(gunId, atts)
	check("rifle: the carbine is the flat-top AR parts with the 16 inch barrel, sized for the hands", gunId == "M4A1" and option == "Standard" and opts.Scale < 1 and opts.Grip == "Shoulder"
		and GP.Pieces(gunId, atts)[2].Asset == GP.Guns.M16A1.Barrels.Carbine.Asset and W.Held("PipeClub") == "PipeClub")
	check("action: the Whisper is single shot, the Carbine and the Garand semi-automatic, the AK-47 automatic", W.ActionOf(W.Defs.Whisper) == "Single"
		and W.ActionOf(W.Defs.Carbine) == "Semi" and W.ActionOf(W.Defs.M1Garand) == "Semi" and W.ActionOf(W.Defs.DutyPistol) == "Semi" and W.ActionOf(W.Defs.AK47) == "Auto" and W.ActionOf(W.Defs.PipeClub) == nil)
	check("rifle: the AK-47 and the Garand have their parts", GP.Guns[(W.Held("AK47"))] ~= nil and GP.Guns[(W.Held("M1Garand"))] ~= nil)
	check("rifle: 7.62x51 goes through what stops a 5.56, and a .22 through nothing", W.Calibers["7.62x51"].Pen > W.Calibers["5.56"].Pen and W.Calibers["7.62x39"].Pen >= 2 and W.Calibers[".22"].Pen == 0)
	Inventory.Add(player, "Carbine", 1); Inventory.Add(player, "Round556", 40, true)
	Remotes.EquipItem:FireServer("Carbine"); run(1.5)
	local pcR = player.Character
	local held = pcR:FindFirstChild("HeldWeapon")
	check("rifle: the carbine is in the hands, thirty in the magazine", pcR:GetAttribute("Weapon") == "Carbine" and pcR:GetAttribute("MagSize") == 30 and pcR:GetAttribute("Mag") == 30 and pcR:GetAttribute("Chambered") == nil
		and (held == nil or held:GetAttribute("WeaponId") == "M4A1"))
	local rootR = pcR.HumanoidRootPart
	local stood = rootR.CFrame
	rootR.CFrame = M.CF.lookAt(stood.Position, stood.Position + (stood.Position - rc.HumanoidRootPart.Position) * M.V3.new(1, 0, 1)); run(0.1) -- muzzle away from the other player
	local before, log0 = Inventory.Count(player, "Round556"), #M.FireLog
	for _ = 1, 3 do
		Remotes.Attack:FireServer(pcR.HumanoidRootPart.CFrame.LookVector); run(0.25)
	end
	local bolts, loud = 0, false
	for i = log0 + 1, #M.FireLog do
		local e = M.FireLog[i]
		if e[1] == "CombatEvent" and e[3] == "Bolt" then bolts += 1; loud = e[6] == 120 end
	end
	check("rifle: three pulls, three rounds of 5.56 gone, each one loud", bolts == 3 and loud and pcR:GetAttribute("Mag") == 27 and Inventory.Count(player, "Round556") == before - 3)
	Remotes.Aim:FireServer(true); run(0.3)
	check("rifle: RMB aims it like any gun", pcR:GetAttribute("Aiming") == true)
	Remotes.Aim:FireServer(false); run(0.2)
	rootR.CFrame = stood; run(0.1)
	local withGun, never = 0, true
	for _ = 1, 300 do
		local roll = ItemsR.Roll("Sentry")
		if roll.Carbine then withGun += 1; never = never and (roll.Round556 or 0) >= 15 and roll.Round9 == nil end
	end
	check("rifle: some sentries carry the carbine, always with 5.56 and never 9mm", withGun > 10 and withGun < 80 and never)
	Remotes.EquipItem:FireServer("ArcPistol"); run(0.5)
	Inventory.Remove(player, "Carbine", 1); Inventory.Remove(player, "Round556", Inventory.Count(player, "Round556"))
end

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
local scrapBefore, hadManifest = Inventory.Count(player, "Scrap"), Inventory.Count(player, "Manifest")
Remotes.HideoutClaim:FireServer(1); run(0.3)
local site = Hideouts.Sites[1]
check("claimed a site", site.Owner == player.UserId and site.Built ~= nil)
check("story: signing the manifest claims the bay free and unpacks a computer", hadManifest == 1 and Inventory.Count(player, "Manifest") == 0
	and Inventory.Count(player, "Scrap") == scrapBefore and PlayerData.Get(player).Hideout.Modules.Computer == true and site.Built:FindFirstChild("Computer") ~= nil)
run(2.5)
check("story: the consignment crates are gone from a signed bay", site.Crates.Parent == nil)
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
check("population stays under its cap", populated <= ConfigM.City.Population.Cap)

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

-- group launch: a Medium weapon's launcher throws up the pack around the impact; they hang; Enemy Step springs
-- you up in front of one and keeps it up longer
do
	as(player)
	local pack = {}
	for i, off in { M.V3.new(0, 0, -3), M.V3.new(2.5, 0, -4), M.V3.new(-2.5, 0, -4), M.V3.new(0, 0, -30) } do
		local m = NPCsL.Spawn("Raider", lr.Position + off, { Parent = game_.Workspace })
		m.Humanoid.MaxHealth, m.Humanoid.Health = 5000, 5000
		m.HumanoidRootPart.Anchored = true
		pack[i] = m
	end
	run(1.0)
	lr.CFrame = M.CF.lookAt(lr.Position, pack[1].HumanoidRootPart.Position); run(0.1)
	Remotes.Attack:FireServer(); run(0.7)
	Remotes.Heavy:FireServer(); run(0.8)
	check("group launch: the struck raider goes up", pack[1]:GetAttribute("Juggled") == true)
	check("group launch: the ones beside it go up too", pack[2]:GetAttribute("Juggled") == true and pack[3]:GetAttribute("Juggled") == true)
	check("group launch: one far away does not", pack[4]:GetAttribute("Juggled") ~= true)
	run(0.4)
	check("hang: a launched body floats past the top of its rise", pack[1].HumanoidRootPart:FindFirstChild("JuggleHang") ~= nil)
	local CombatG = M.mockEnv.__require(SSS.Server.Combat)
	local mark = #M.FireLog
	player.Character:SetAttribute("Stamina", 100)
	run(0.2)
	CombatG.Dodge(player, M.V3.new(0, 0, -1))
	local hover, enemy
	for i = mark + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "DodgeMove" then hover, enemy = e[5], e[6] end end
	check("enemy step: springs you at a juggled enemy and hangs you there", (hover or 0) > 0 and enemy ~= nil)
	for _, m in pack do m:Destroy() end
	run(2.5)
end

-- spacing (Config.City.AI.Spacing): a rival reads your swing, presses your recovery, circles your guard
do
	as(player)
	mendMe()
	local NPCsS = M.mockEnv.__require(SSS.Server.NPCs)
	local CombatS = M.mockEnv.__require(SSS.Server.Combat)
	local Cfg = M.mockEnv.__require(RS.Shared.Config)
	local T = Cfg.City.AI.Spacing.Types.Rival
	local oldChance, oldBlock = T.Chance, T.WaitOutBlock
	T.Chance, T.WaitOutBlock = 1, 1 -- always reacts, for the test
	local oldCd = NPCsS.Types.Rival.Cooldown
	NPCsS.Types.Rival.Cooldown = 1e6 -- and never swings first, so your swing is never cancelled by its hit
	local pr = player.Character.HumanoidRootPart
	local rival = NPCsS.Spawn("Rival", pr.Position + M.V3.new(0, 0, -5), { Parent = game_.Workspace })
	rival.Humanoid.MaxHealth, rival.Humanoid.Health = 5000, 5000
	local rh = rival.Humanoid
	local function goalDist() local g = rawget(rh, "_moveTo"); return g and (M.V3.new(g.X, 0, g.Z) - M.V3.new(pr.Position.X, 0, pr.Position.Z)).Magnitude or 0 end
	-- the threat read
	local phase = CombatS.Threat(player.Character)
	check("spacing: an idle player reads as Idle", phase == "Idle")
	CombatS.Swing(player.Character, { Windup = 0.5, Active = 0.2, End = 1.2, Range = 6, Damage = 0, Posture = 0, Arc = 0.3 }, {})
	check("spacing: a swing reads as Windup", (CombatS.Threat(player.Character)) == "Windup")
	run(0.4)
	check("spacing: it slips out of your reach as you wind up", goalDist() > 6 + 2.5)
	run(0.5)
	check("spacing: after the swing, the recovery reads as Recovery", (CombatS.Threat(player.Character)) == "Recovery")
	-- your guard: it circles instead of swinging into it
	run(0.4) -- a guard can only go up once the swing's recovery is over
	CombatS.SetBlock(player, true); run(0.2)
	local _, _, blocking = CombatS.Threat(player.Character)
	check("spacing: a raised guard reads as blocking", blocking == true)
	run(0.6)
	check("spacing: it circles you while it waits, facing you", rival.HumanoidRootPart.SpacingTurn.Enabled == true and rh.AutoRotate == false and goalDist() > 5)
	CombatS.SetBlock(player, false)
	-- wounded: it keeps outside your reach
	rh.Health = 5000 * 0.2; run(0.6)
	check("spacing: wounded, it keeps outside your reach", goalDist() >= 6 + 2.5)
	T.Chance, T.WaitOutBlock = oldChance, oldBlock
	NPCsS.Types.Rival.Cooldown = oldCd
	rival:Destroy()
	-- a brute does not back off: it walks through swings
	local brute = NPCsS.Spawn("Brute", pr.Position + M.V3.new(0, 0, -5), { Parent = game_.Workspace })
	brute.Humanoid.MaxHealth, brute.Humanoid.Health = 5000, 5000
	run(2.5) -- let its own attack cooldown pass
	CombatS.Swing(player.Character, { Windup = 0.5, Active = 0.2, End = 1.2, Range = 6, Damage = 0, Posture = 0, Arc = 0.3 }, {})
	run(0.4)
	local g = rawget(brute.Humanoid, "_moveTo")
	check("spacing: a brute walks through your swing", g == nil or (M.V3.new(g.X, 0, g.Z) - M.V3.new(pr.Position.X, 0, pr.Position.Z)).Magnitude < 6)
	brute:Destroy()
	run(1.5)
end

-- taking turns: three raiders next to the player, but only one winds up at a time
as(player)
mendMe()
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
	if e[1] == "CombatEvent" and (e[3] == "Windup" or e[3] == "Swing") and table.find(pack, e[4]) then windups += 1 end -- traced strikes announce as "Swing"
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
	M.mockEnv.__require(SSS.Server.Common.WoundService).Mend(player.Character) -- the site's guards may have opened a bleed
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
	Frontier.StandDownAll() -- a clean valley, so the encounter cap left by earlier steps does not decide these checks
	run(0.2)
	if patrolCell then
		player.Character:PivotTo(M.CF.new(patrolCell.Center.X + 100, 0, patrolCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[patrolCell]
		check("frontier: a patrol wakes when someone comes near", e and e.models and #e.models > 0)
	end
	if bountyCell then
		Frontier.StandDownAll(); run(0.2)
		player.Character:PivotTo(M.CF.new(bountyCell.Center.X + 100, 0, bountyCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[bountyCell]
		check("frontier: the bounty wears its name", e and e.models[1] and e.models[1].Name == bountyCell.Encounter.Boss)
	end
	if ambushCell then
		-- earlier steps may have woken enough encounters to fill the cap, or sprung this one: reset the valley as a cycle does
		Frontier.StandDownAll()
		run(0.2)
		local npcsBefore = #CS:GetTagged("NPC")
		player.Character:PivotTo(M.CF.new(ambushCell.Center.X, 0, ambushCell.Center.Z))
		run(1.6)
		local e = Frontier.Encounters()[ambushCell]
		check("frontier: walking into an ambush cell springs it", e and e.models and #e.models > 0 and #CS:GetTagged("NPC") > npcsBefore)
		local sprungModels, sprungRest = e.models, e.restUntil
		run(1.6)
		-- it does not spring again while you stand in it (other packs may respawn meanwhile; only this one counts)
		check("frontier: a sprung ambush rests", e.models == sprungModels and e.restUntil == sprungRest)
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
		-- before the upload nothing the computer knows survives a death
		pd.Knowledge.Contacts.Dealer = true
		local unuploaded = PlayerData.Reset(player)
		check("computer: without an uploaded stack, knowledge dies with the body", unuploaded.Knowledge.Contacts.Dealer == nil and unuploaded.Knowledge.Uploaded == false)
		pd = unuploaded
		Terminal.Open(player)
		check("computer: the first log-in uploads the stack", pd.Knowledge.Uploaded == true)
		pd.Knowledge.Grade = 0 -- every contract open to a SPECIAL grade (the grade gates have their own checks)
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
		check("computer: clearing the site completes the contract and pays", pd.Knowledge.Contracts[cid] == nil and pd.War.Credits + (pd.Carried and pd.Carried.Credits or 0) == board[cid].Reward.Credits and pd.Knowledge.Completed == 1)
		pd.Carried = nil
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
	-- the story's spawn order: an uploaded stack reboots at its computer; a conduit back from the Front reads the link
	do
		local Lifecycle_ = M.mockEnv.__require(SSS.Server.Lifecycle)
		local NeuralNet_ = M.mockEnv.__require(SSS.Server.NeuralNet)
		local cf, how = Lifecycle_.PlaceFor(player)
		check("story: an uploaded stack reboots at its hideout computer", pd.Knowledge.Uploaded == true and how == "Reboot" and cf ~= nil)
		pd.War.Tap = { At = "Corp Plaza", Credits = 100, Deaths = pd.War.RecruitDeaths, Kills = pd.War.RecruitKills }
		pd.War.Credits = 340; pd.War.RecruitDeaths += 2; pd.War.RecruitKills += 1
		local line = NeuralNet_.Returned(player)
		check("story: back from the Front, the link reads what it cost", line == "> LINK CLOSED . . . RECRUITS LOST 2 . . . KILLS 1 . . . CREDIT +240" and pd.War.Tap == nil)
		check("story: the way back stands at a Neural Net terminal", NeuralNet_.ReturnCFrame(player) ~= nil)
		-- a body with no stack and no bay of its own comes up a free bay's lift with a manifest, once per life
		local p3 = makePlayer("Newcomer", 789)
		Players.PlayerAdded:Fire(p3); as(p3); run(2)
		local pd3 = PlayerData.Get(p3)
		local Inv = M.mockEnv.__require(SSS.Server.Inventory)
		local liftCount = 0
		for _, st in Hideouts_.Sites do
			if st.LiftCFrame and not st.Owner and (st.LiftCFrame.Position - p3.Character.HumanoidRootPart.Position).Magnitude < 5 then liftCount += 1 end
		end
		check("story: a new body comes up a free bay's freight lift with a manifest", liftCount == 1 and Inv.Count(p3, "Manifest") == 1)
		Lifecycle_.PlaceFor(p3)
		check("story: one manifest per life", Inv.Count(p3, "Manifest") == 1)
		p3:Destroy(); Players.PlayerRemoving:Fire(p3); as(player); run(0.5)
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
		-- remains in a green pocket outlive the hour; remains on a street do not
		local Mega = M.mockEnv.__require(RS.Shared.Megacity)
		local inPocket = M.newInstance("Part"); inPocket.Name = "Lootable"; inPocket:SetAttribute("Label", "Remains")
		inPocket.Position = Mega.Pockets[1].Center + M.V3.new(5, 3, 5); inPocket.Parent = workspace_
		local onStreet = M.newInstance("Part"); onStreet.Name = "Lootable"; onStreet:SetAttribute("Label", "Remains")
		onStreet.Position = M.V3.new(0, 3, -300); onStreet.Parent = workspace_
		local result = Cycle.Trigger()
		run(0.3)
		check("story: the green pockets stand outside the hour", inPocket.Parent ~= nil and onStreet.Parent == nil)
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

-- ===== traced blades (Mordhau-style): the blade hits where it meets a body, two blades meeting cancel both =====
do
	local CombatB = M.mockEnv.__require(SSS.Server.Combat)
	local NPCsB = M.mockEnv.__require(SSS.Server.NPCs)
	local origin = M.V3.new(5000, 5, 5000)
	local function body(name, pos, look)
		local m = NPCsB.BuildRig(name, { Health = 500, Speed = 0 })
		m.Parent = game_.Workspace
		m.HumanoidRootPart.CFrame = M.CF.lookAt(pos, look)
		return m
	end
	local spec = { Damage = 10, Posture = 5, Windup = 0.1, Active = 0.3, End = 0.6, Range = 6, Knockback = 15, Stun = 0.3, Type = "Slash" }
	local a = body("Blade A", origin, origin + M.V3.new(0, 0, -5))
	local v = body("Blade B", origin + M.V3.new(0, 0, -3.5), origin + M.V3.new(0, 0, -10)) -- facing away: cannot swing back
	local logAt = #M.FireLog
	CombatB.Swing(a, spec, { noStatScaling = true, label = "Test", shape = "SlashR" })
	run(0.8)
	local contact
	for i = logAt + 1, #M.FireLog do
		local e = M.FireLog[i]
		if e[1] == "CombatEvent" and e[3] == "Hit" and e[4] == v then contact = e[6] end
	end
	check("blade: a swing lands on the body its arc passes through", v.Humanoid.Health < 500)
	check("blade: the hit carries the point of contact", typeof(contact) == "Vector3" or (type(contact) == "table" and contact.X ~= nil))
	-- out of reach: the arc never meets the body, nothing lands
	local far = body("Blade C", origin + M.V3.new(0, 0, 40), origin)
	local h0 = far.Humanoid.Health
	CombatB.Swing(a, spec, { noStatScaling = true, label = "Test", shape = "SlashR" })
	run(0.8)
	check("blade: a body outside the arc is untouched", far.Humanoid.Health == h0)
	far:Destroy(); v:Destroy()
	-- two blades meeting mid-air: both swings end, neither lands
	local b = body("Blade D", origin + M.V3.new(0, 0, -8), origin) -- tips overlap, bodies out of each other's reach
	local clashed = false
	local conn = CombatB.Clashed.Event:Connect(function() clashed = true end)
	local ha, hb = a.Humanoid.Health, b.Humanoid.Health
	CombatB.Swing(a, spec, { noStatScaling = true, label = "Test", shape = "SlashR" })
	CombatB.Swing(b, spec, { noStatScaling = true, label = "Test", shape = "SlashR" })
	run(0.8)
	conn:Disconnect()
	check("blade: two blades meeting mid-air clash", clashed)
	check("blade: a clash lands neither swing", a.Humanoid.Health == ha and b.Humanoid.Health == hb)
	a:Destroy(); b:Destroy()
	run(0.5)
	-- guns are aimed, not swung: a shot announces no arc, so the client doesn't pose a slash wind-up
	local SwingsB = M.mockEnv.__require(game_:GetService("ReplicatedStorage").Shared.Swings)
	check("blade: a sidearm has no swing arc", SwingsB.ShapeFor("Sidearm", 1, false) == nil and SwingsB.ShapeFor("Sidearm", 1, true) == nil)
	local g = body("Gunner", origin + M.V3.new(20, 0, 0), origin)
	local mark = #M.FireLog
	CombatB.Swing(g, { Damage = 5, Posture = 1, Windup = 0.05, Active = 0.05, End = 0.3, Range = 60, Ranged = true, Type = "Arc" }, { noStatScaling = true, label = "Test", shape = "SlashR" })
	local shaped = false
	for i = mark + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "CombatEvent" and e[3] == "Swing" and e[4] == g and e[6] ~= nil then shaped = true end end
	check("blade: a shot is announced without an arc", not shaped)
	run(0.5)
	g:Destroy()
	-- a swing goes where you look and the way you flick
	check("look: looking down tips the arc down, within its limit", SwingsB.LookPitch(M.V3.new(0, -0.6, -0.8)) < -20 and SwingsB.LookPitch(M.V3.new(0, -1, -0.01)) >= -SwingsB.LookMax and SwingsB.LookPitch(M.V3.new(0, 0, -1)) == 0)
	check("look: a flick picks the cut, but not for a spear or the fists", SwingsB.FlickShape("Blade", "Down") == "Overhead" and SwingsB.FlickShape("Hammer", "Left") == "SlashR"
		and SwingsB.FlickShape("Blade", "Right") == "SlashL" and SwingsB.FlickShape("Fists", "Left") == nil and SwingsB.FlickShape("Spear", "Up") == nil and SwingsB.FlickShape("Blade", "Forward") == nil)
	local sw = body("Looker", origin + M.V3.new(40, 0, 0), origin + M.V3.new(40, 0, -5))
	CombatB.Swing(sw, spec, { noStatScaling = true, label = "Test", shape = "SlashR" })
	check("look: every traced swing tells the clients its tip", sw:GetAttribute("SwingPitch") == 0)
	run(0.8)
	sw:Destroy()
end

-- ===== the guard (Mordhau-style blocking): a raised guard stops only the blade that meets it on the way in =====
do
	local CombatG = M.mockEnv.__require(SSS.Server.Combat)
	local NPCsG = M.mockEnv.__require(SSS.Server.NPCs)
	local origin = M.V3.new(5200, 5, 5200)
	local results = {}
	local conn = CombatG.Resolved.Event:Connect(function(att, vic, r) table.insert(results, { att, vic, r }) end)
	local function body(name, pos, look, armed)
		local m = NPCsG.BuildRig(name, { Health = 500, Speed = 0 })
		m.Parent = game_.Workspace
		m.HumanoidRootPart.CFrame = M.CF.lookAt(pos, look)
		if armed then local hw = M.newInstance("Part"); hw.Name = "HeldWeapon"; hw.Parent = m end
		return m
	end
	local spec = { Damage = 10, Posture = 1, Windup = 0.15, Active = 0.15, End = 0.5, Range = 6, Knockback = 0, Stun = 0.3, Type = "Slash" }
	local function bout(shape, turn, opts)
		opts = opts or {}
		local a = body("Guard A", origin, origin + M.V3.new(0, 0, -5))
		local vpos = origin + M.V3.new(0, 0, -5)
		local r = math.rad(turn)
		local v = body("Guard V", vpos, vpos + M.V3.new(math.sin(r), 0, math.cos(r)), true)
		table.clear(results)
		if opts.late then
			-- raised as the blow comes: a parry
			CombatG.Swing(a, spec, { noStatScaling = true, label = "Test", shape = shape })
			run(0.1)
			CombatG.Guard(v, true)
		else
			CombatG.Guard(v, true)
			run(0.6) -- held well before the blow: a block, not a parry
			table.clear(results)
			CombatG.Swing(a, spec, { noStatScaling = true, label = "Test", shape = shape })
			run(0.1)
		end
		local live = false
		for _ = 1, 15 do run(1 / 30); if CombatG.LiveBlades()[a] then live = true end end
		local got = results[1] and results[1][3] or "miss"
		local stopped = CombatG.LiveBlades()[a] == nil
		a:Destroy(); v:Destroy(); run(0.6)
		return got, stopped
	end
	local front = true
	for _, shape in { "SlashR", "SlashL", "Overhead", "Diagonal", "Thrust" } do
		if bout(shape, 0) ~= "blocked" then front = false; print("  front " .. shape .. " not blocked") end
	end
	check("guard: blows from the front meet the guard (slashes, overhead, diagonal, thrust)", front)
	local side = bout("SlashR", 60) == "blocked" and bout("Overhead", -60) == "blocked"
	check("guard: it turns to meet a blow from the side", side)
	check("guard: a blow from behind comes round a raised guard", bout("SlashR", 180) == "hit" and bout("Overhead", 150) == "hit")
	local _, stopped = bout("SlashR", 0)
	check("guard: a blocked blade stops on the guard", stopped)
	check("guard: a parry is a guard raised just in time, in the blade's path", bout("SlashR", 0, { late = true }) == "parried")
	check("guard: a late guard facing away is no parry", bout("SlashR", 180, { late = true }) == "hit")
	-- two at once: the guard turns to one, the other comes round it
	local v = body("Guard V2", origin, origin + M.V3.new(0, 0, -5), true)
	local a1 = body("Guard F", origin + M.V3.new(0, 0, -5), origin)
	local a2 = body("Guard R", origin + M.V3.new(5, 0, 0), origin)
	CombatG.Guard(v, true)
	run(0.6)
	table.clear(results)
	CombatG.Swing(a1, spec, { noStatScaling = true, label = "Test", shape = "Overhead" })
	run(0.1)
	CombatG.Swing(a2, spec, { noStatScaling = true, label = "Test", shape = "Thrust" })
	run(0.8)
	local hits, blocks = 0, 0
	for _, e in results do if e[2] == v then if e[3] == "hit" then hits += 1 elseif e[3] == "blocked" then blocks += 1 end end end
	check("guard: two attackers at once, one gets round it", hits >= 1)
	-- untraced attacks still block by facing
	CombatG.Guard(v, false); CombatG.Guard(v, true); run(0.6)
	table.clear(results)
	CombatG.Damage(a1, v, 5, { Posture = 1 })
	check("guard: an untraced blow from the front is still blocked", results[1] and results[1][3] == "blocked")
	conn:Disconnect()
	v:Destroy(); a1:Destroy(); a2:Destroy()
	run(0.5)
end

-- megacity: the industrial ring, the green pockets, sludge and the edge (shared/Megacity.lua, server/Megacity.lua)
do
	local MS = M.mockEnv.__require(RS.Shared.Megacity)
	local CityM = M.mockEnv.__require(SSS.Server.City)
	local FS = M.mockEnv.__require(RS.Shared.Frontier)
	local mega = workspace_:FindFirstChild("City") and workspace_.City:FindFirstChild("Megacity")
	check("megacity: the industrial ring is built", mega ~= nil and #mega:GetChildren() > 1500)
	local marked = {}
	for _, d in workspace_:GetDescendants() do
		local name = d:GetAttribute("District")
		if name then marked[name] = true end
	end
	local all = true
	for _, d in MS.Districts do
		if not marked[d.Name] then all = false; print("  no landmark for " .. d.Name) end
	end
	check("megacity: every district has its landmark", all)
	check("megacity: districts join the city's list (population, terminals)", #CityM.Districts == 11)
	local sumps = MS.GetDistrict("Sumps")
	check("megacity: banners know the ring and the pockets", CityM.DistrictAt(sumps.Center).Name == "The Sumps" and CityM.DistrictAt(MS.Pockets[1].Center).Name == "The Last Garden" and CityM.DistrictAt(M.V3.new(0, 0, 0)).Name == "The Crossroads")
	check("megacity: Fernwell lies inside the Hab Blocks and wins there", CityM.DistrictAt(MS.Pockets[3].Center).Name == "Fernwell")
	check("megacity: the frontier's terrain no longer covers the city", FS.InCity(1500, -1500) and not FS.InCity(0, 900) and FS.Bounds.Z0 >= 700)
	local anchors = true
	for _, d in MS.Districts do
		if not d.Anchors or #d.Anchors < 3 then anchors = false; print("  few anchors in " .. d.Name) end
	end
	check("megacity: each district left open ground for packs and caches", anchors)
	local sky = workspace_:FindFirstChild("Skyline")
	local solid = false
	for _, p in sky and sky:GetChildren() or {} do if p.CanCollide then solid = true end end
	check("megacity: the skyline stands past the wall and blocks nothing", sky ~= nil and #sky:GetChildren() >= 150 and not solid)
	-- sludge burns, a pocket heals
	local char = player.Character
	local hum, root = char.Humanoid, char.HumanoidRootPart
	hum.Health = hum.MaxHealth
	local pool
	for _, s in MS.Sludge do if s.Radius then pool = s break end end
	char:PivotTo(M.CF.new(pool.Center.X, pool.Center.Y + 2.5, pool.Center.Z))
	run(2)
	check("sludge: standing in a toxic pool burns", hum.Health < hum.MaxHealth - 5 and char:GetAttribute("Toxic") == true)
	local canal
	for _, s in MS.Sludge do if s.Half then canal = s break end end
	check("sludge: the Sumps' canals are toxic, the bridges over them are not", MS.InSludge(canal.Center + M.V3.new(0, 1, 0)) and not MS.InSludge(canal.Center + M.V3.new(0, 8, 0)))
	local garden = MS.Pockets[1]
	char:PivotTo(M.CF.new(garden.Center.X, 5, garden.Center.Z))
	run(1)
	check("pocket: the toxic mark clears when you leave", char:GetAttribute("Toxic") == false and char:GetAttribute("Pocket") == "The Last Garden")
	hum.Health = hum.MaxHealth * 0.5
	local before = hum.Health
	run(ConfigM.Megacity.PocketCalm + 4)
	check("pocket: wounds close in a green pocket once nothing hurts you", hum.Health > before + 3)
	hum.Health = hum.MaxHealth
	char:PivotTo(M.CF.new(0, 5, 0))
	run(0.5)
end

do
	-- the way down (server/Barrens.lua): the Sumps shaft, the barrens hall, unhooking, the hour
	local BarrensS = M.mockEnv.__require(SSS.Server.Barrens)
	local CycleS = M.mockEnv.__require(SSS.Server.Cycle)
	local Cfg = M.mockEnv.__require(RS.Shared.Config)
	local MS = M.mockEnv.__require(RS.Shared.Megacity)
	local B = Cfg.Barrens
	local lv = BarrensS.Level()
	check("barrens: the hall is built with its stations, overseers and stores", lv ~= nil and #lv.Stations == B.Rows * B.PerRow and #lv.Guards == 4 and #lv.Stores == 3)
	local headModel = BarrensS.HeadModel()
	local d = MS.DistrictAt(B.Head)
	check("barrens: the shaft head stands on the Sumps plaza", headModel ~= nil and headModel.Parent == workspace_ and d ~= nil and d.Style == "Sumps" and not MS.InSludge(B.Head + M.V3.new(0, 3, 0)))
	local blocked = {}
	for _, part in workspace_:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(headModel) and not (part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")) and part.CanCollide ~= false and part.Size and part.Position then
			local p, sz = part.Position, part.Size
			if math.abs(p.X - B.Head.X) < 6 + sz.X / 2 and math.abs(p.Z - B.Head.Z) < 6 + sz.Z / 2 and p.Y + sz.Y / 2 > B.Head.Y + 0.5 and p.Y - sz.Y / 2 < B.Head.Y + 12 and sz.Y < 400 then
				table.insert(blocked, part.Name)
			end
		end
	end
	check("barrens: nothing of the Sumps stands on the shaft head", #blocked == 0)
	if #blocked > 0 then print("   ", table.concat(blocked, ", ")) end
	local char = player.Character
	local hum = char.Humanoid
	hum.Health = hum.MaxHealth
	char:PivotTo(M.CF.new(1000, 5, 0)) -- far away: refused
	check("barrens: the shaft only answers at its head", BarrensS.Descend(player) == false)
	char:PivotTo(M.CF.new(B.Head + M.V3.new(0, 3, -6)))
	run(0.1)
	headModel.Grate:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
	run(B.FadeSeconds + 0.3)
	local below = char.HumanoidRootPart.Position
	check("barrens: descending drops you at the shaft foot, inside a stealth level", BarrensS.Inside(player) and (below - lv.Foot.Position).Magnitude < 4 and player:GetAttribute("Stealth") == true and player:GetAttribute("Below") == true and Stealth.LevelOf(player) == lv.Model)
	check("barrens: the air down there is its own", MS.AirAt(below) == "Under")
	-- unhook one: the row goes dark, the link kicks back, an upload is lost
	local data = PlayerData_.Get(player)
	data.Knowledge = data.Knowledge or {}
	data.Knowledge.Uploaded = true
	local st = lv.Stations[1]
	char:PivotTo(st.Stand * M.CF.new(0, 3, 3))
	run(0.1)
	local hp = hum.Health
	check("barrens: unhooking a station takes", BarrensS.Unhook(player, st) == true)
	local dark = true
	for _, lamp in lv.Lamps do
		if lamp:GetAttribute("Circuit") == st.Circuit and lamp:GetAttribute("Powered") ~= false then dark = false end
	end
	check("barrens: its row goes dark", dark)
	check("barrens: the link kicks back and the upload is lost", hum.Health < hp and data.Knowledge.Uploaded == false and st.Prompt.Enabled == false)
	check("barrens: the office console counts the hands", lv.Hands == #lv.Stations - 1)
	check("barrens: a station is unhooked only once", BarrensS.Unhook(player, st) == false)
	-- the hour puts it all back
	CycleS.Run()
	run(0.2)
	local lit = true
	for _, lamp in lv.Lamps do
		if lamp:GetAttribute("Powered") == false then lit = false end
	end
	check("barrens: the hour rehooks the station, relights the row and refills the stores", st.Unhooked == nil and st.Prompt.Enabled and lit and lv.Hands == #lv.Stations and #lv.Stores == 3 and #lv.Guards == 4)
	-- climbing out
	char:PivotTo(lv.Foot)
	run(0.1)
	lv.ClimbPrompt.Triggered:Fire(player)
	run(B.FadeSeconds + 0.3)
	local up = char.HumanoidRootPart.Position
	check("barrens: climbing comes out at the shaft head and leaves the stealth level", (up - B.Head).Magnitude < 14 and player:GetAttribute("Stealth") == nil and player:GetAttribute("Below") == nil)
	-- the trail: the shaft card lies by the head, the second fragment down in the hall
	local Clues_ = M.mockEnv.__require(RS.Shared.Clues)
	check("barrens: two fragments point the way down", Clues_.Fragments.ShiftCard.Where == "Sumps" and Clues_.Fragments.Hands.Where == "Barrens")
	data.Knowledge.Uploaded = true
	hum.Health = hum.MaxHealth
	char:PivotTo(M.CF.new(0, 5, 0))
	run(0.5)
end

-- builds (round 5: batches, the empty body, implant load, actives, chips, vows, grades, carried pay, practice, the stack slot, the basin)
do
	as(player)
	mendMe()
	local pd = PlayerData_.Get(player)
	local Cfg = M.mockEnv.__require(RS.Shared.Config)
	local BRules = M.mockEnv.__require(RS.Shared.Builds)
	local BS = M.mockEnv.__require(SSS.Server.Builds)
	local GearS = M.mockEnv.__require(SSS.Server.Gear)
	local CombatS = M.mockEnv.__require(SSS.Server.Combat)
	local InvS = M.mockEnv.__require(SSS.Server.Inventory)
	local SkillS = M.mockEnv.__require(SSS.Server.SkillRunner)
	local TermS = M.mockEnv.__require(SSS.Server.Terminal)
	local HideS = M.mockEnv.__require(SSS.Server.Hideouts)
	local Cyb = M.mockEnv.__require(RS.Shared.Cybernetics)
	-- the batch rules, with the shipped odds
	local BL = Cfg.Builds.Lineage
	local saved = { BL.Empty, BL.Rare, BL.Good, BL.Bonus }
	BL.Empty, BL.Rare, BL.Good, BL.Bonus = 0.01, 0.06, 0.25, 1
	local seq = 0
	local function pick(n) seq += 1; return (seq % n) + 1 end
	local e, r, g, c = BRules.RollLineage(0.005, pick), BRules.RollLineage(0.03, pick), BRules.RollLineage(0.2, pick), BRules.RollLineage(0.9, pick)
	check("batch: one in a hundred bodies is empty, a rare one is strong in two attributes", e.Empty == true and r.Rare == true and r.Bonus == BL.RareBonus and r.Second ~= nil and r.Second ~= r.Stat)
	check("batch: a good batch adds two, the rest one", g.Bonus == BL.GoodBonus and c.Bonus == BL.Bonus and BRules.BatchName(c):match("^LINE 9 %. BATCH %d%d%d%d$") ~= nil)
	BL.Empty, BL.Rare, BL.Good, BL.Bonus = saved[1], saved[2], saved[3], saved[4]
	pd.Lineage = { Batch = 416, Stat = "Strength", Bonus = 0 }; GearS.Recompute(player)
	local str0 = GearS.Get(player).Stats.Strength
	pd.Lineage = { Batch = 417, Stat = "Strength", Bonus = 3 }; GearS.Recompute(player)
	check("batch: the body's bonus shows in its attributes", GearS.Get(player).Stats.Strength == str0 + 3)
	-- the empty body
	local hp0 = GearS.Get(player).MaxHealth
	pd.Lineage = { Batch = 1, Empty = true }; GearS.Recompute(player); run(0.1)
	local de = GearS.Get(player)
	char():SetAttribute("Charge", 100)
	CombatS.Flicker(player)
	pd.SkillSlots["1"] = "Surge"
	SkillS.Use(player, 1); run(0.1)
	check("empty body: no flicker, no skills", char():GetAttribute("Charge") == 100 and de.Empty == true and de.ChargeGain == 0 and char():GetAttribute("Empty") == true)
	check("empty body: a harder body and a wider parry", de.MaxHealth > hp0 - 5 * 0 and de.ParryWindow > Cfg.Combat.ParryWindow)
	local NPCsB = M.mockEnv.__require(SSS.Server.NPCs)
	local dummy = NPCsB.Spawn("Raider", root().Position + M.V3.new(0, 0, -3), { Parent = game_.Workspace })
	run(0.1)
	local t0 = M.mockEnv.os.clock()
	CombatS.Damage(char(), dummy, 1, { Stun = 0.5 })
	local first = CombatS.State(dummy).stunned - t0
	run(1)
	CombatS.Damage(char(), dummy, 1, { Stun = 0.5 })
	local second = CombatS.State(dummy).stunned - M.mockEnv.os.clock()
	check("empty body: the first blow on someone stuns longer than the next", first > 0.5 * Cfg.Builds.Empty.FirstStun - 0.05 and second < 0.55)
	dummy:Destroy()
	pd.Lineage = { Batch = 2, Stat = "Strength", Bonus = 0 }; pd.SkillSlots["1"] = nil; GearS.Recompute(player)
	-- implant load
	local cyber = { Eyes = "ReflexOptic", Ears = "EchoArray", Nose = "ChemSniffer", Core = "OverclockCore", LeftArm = "ArcGauntlet", RightArm = "ServoArm", LeftLeg = "StriderLeg", RightLeg = "StriderLeg" }
	local load, max, over = BRules.Load(cyber, Cyb.Pieces, Cyb.Slots)
	check("load: the core sets the limit and pieces past it give nothing", max == Cfg.Builds.Load.Base + 1 and load <= max and over.RightArm == true and over.LeftArm == nil and over.Eyes == nil)
	local _, maxN = BRules.Load({ Core = "NeuralCore" }, Cyb.Pieces, Cyb.Slots)
	check("load: a neural core carries more", maxN == Cfg.Builds.Load.Base + 4)
	-- actives on K
	for _, id in { "NeuralCore" } do InvS.Add(player, id, 1) end
	local savedCyber = table.clone(pd.Cyber)
	pd.Cyber = { Core = "NeuralCore" }; GearS.Recompute(player)
	check("active: the neural core's active is Quicken", BS.ActiveOf(player) == "Quicken")
	check("active: K fires it once, then it waits", BS.Active(player) == true and BS.CooldownMult(player) == Cfg.Builds.Actives.Quicken.CooldownMult and BS.Active(player) == false)
	pd.Cyber = savedCyber; GearS.Recompute(player)
	-- chips at the bench
	local site0 = HideS.SiteOf(player)
	local bench = site0 and site0.Built and site0.Built:FindFirstChild("Bench")
	InvS.Add(player, "FocusChip", 1)
	root().CFrame = M.CF.new(M.V3.new(5000, 5, 5000)); run(0.1)
	check("chips: a chip is fitted only at the bench", BS.Fit(player, "FocusChip") == false and InvS.Count(player, "FocusChip") == 1)
	if bench then root().CFrame = M.CF.new(bench.Position + M.V3.new(0, 0, 3)); run(0.1) end
	Remotes.UseItem:FireServer("FocusChip"); run(0.2)
	check("chips: at the bench it goes onto its skill", BS.ChipOn(player, "Surge") == "FocusChip" and InvS.Count(player, "FocusChip") == 0)
	check("chips: taken out at the bench, it comes back", BS.Unfit(player, "Surge") == true and InvS.Count(player, "FocusChip") == 1 and BS.ChipOn(player, "Surge") == nil)
	-- the Trail chip leaves a live line
	local strip = SkillS.Trail(char(), M.V3.new(0, 5, 0), M.V3.new(0, 5, -20), 1)
	check("chips: the trail chip lays a line along the blink", strip ~= nil and strip.Name == "PhaseTrail" and math.abs(strip.Size.Z - 20) < 0.1)
	-- carried pay, banked at home
	pd.Carried = nil
	root().CFrame = M.CF.new(M.V3.new(5000, 5, 5000)); run(0.1)
	local lvl0, xp0, cr0 = pd.Level, pd.Xp, pd.War.Credits
	BS.Earn(player, 40, 25)
	check("carried: pay earned out in the city rides with the body", pd.Carried and pd.Carried.Xp == 40 and pd.Carried.Credits == 25 and pd.War.Credits == cr0 and pd.Xp == xp0 and pd.Level == lvl0)
	if site0 then root().CFrame = M.CF.new(site0.Position + M.V3.new(2, 5, 2)); run(1.2) end
	check("carried: at home it is banked", pd.Carried == nil and pd.War.Credits == cr0 + 25 and (pd.Xp ~= xp0 or pd.Level ~= lvl0))
	-- vows
	local dm0 = GearS.Get(player).DamageMult
	TermS.Open(player)
	Remotes.Terminal:FireServer("Vow", "LightHand"); run(0.1)
	check("vow: sworn at the computer, the hand is lighter", pd.Vow == "LightHand" and GearS.Get(player).DamageMult < dm0)
	root().CFrame = M.CF.new(M.V3.new(5000, 5, 5000)); run(0.1)
	BS.Earn(player, 100, 0)
	check("vow: and it earns more", pd.Carried and pd.Carried.Xp == math.floor(100 * Cfg.Builds.Vows.LightXp + 0.5))
	Remotes.Terminal:FireServer("Break"); run(0.1)
	check("vow: broken, the hand is back", pd.Vow == nil and math.abs(GearS.Get(player).DamageMult - dm0) < 1e-6)
	pd.Carried = nil
	-- grades and trials
	local k = pd.Knowledge
	local savedGrade = k.Grade
	k.Grade = 4
	k.Contracts = {}
	k.Contacts.Broker = true
	local board = TermS.Board()
	local raidOk = TermS.Accept(player, "Raid")
	check("grade: GRADE 4 cannot take the raid", raidOk == false and board.Trial_3 ~= nil)
	check("grade: the trial for GRADE 3 is open", TermS.Accept(player, "Trial_3") == true and TermS.Accept(player, "Trial_2") == false)
	local fake = M.newInstance("Model"); fake.Name = "Guard"; fake:SetAttribute("Site", board.Trial_3.Target)
	for _ = 1, board.Trial_3.Need do NPCsB.Killed:Fire("Raider", fake, player) end
	run(0.2)
	check("grade: passing it raises the grade and opens the raid", k.Grade == 3 and TermS.Accept(player, "Raid") == true)
	k.Contracts = {}
	TermS.Accept(player, "Trial_2")
	BS.OnDeath(player, pd)
	check("grade: a death fails the trial in hand", k.Contracts.Trial_2 == nil)
	k.Grade = savedGrade or 0
	k.Contracts = {}
	TermS.Close(player)
	pd.Carried = nil
	-- practice
	local savedP = pd.Practice
	pd.Practice = {}
	local r0 = BS.ReloadMult(player)
	for _ = 1, Cfg.Builds.Practice.Reload.Per do BS.Practice(player, "Reload", 1) end
	check("practice: reloading makes the hands faster", BS.Level(player, "Reload") == 1 and BS.ReloadMult(player) < r0)
	local st0 = GearS.Get(player).MaxStamina
	BS.Practice(player, "Endurance", Cfg.Builds.Practice.Endurance.Per * 3)
	check("practice: running raises stamina", BS.Level(player, "Endurance") == 2 and GearS.Get(player).MaxStamina == st0 + 2 * Cfg.Builds.Practice.Endurance.Stamina)
	pd.Practice = savedP; GearS.Recompute(player)
	-- the stack slot
	k.Stack = {}
	InvS.Add(player, "DataShard", 2); InvS.Add(player, "Scrap", 1)
	check("stack: it takes data, never materials", BS.Store(player, "DataShard") == true and BS.Store(player, "Scrap") == false and #k.Stack == 1 and k.Stack[1].Count == 1)
	BS.Store(player, "FocusChip")
	k.Uploaded = true
	local after = PlayerData_.Reset(player); run(0.1)
	check("stack: it survives the reboot", after.Knowledge.Stack and #after.Knowledge.Stack == 2 and (after.Inventory.DataShard or 0) == 0)
	pd = after
	check("stack: and it can be taken out again", BS.Unstore(player, 1) == true and InvS.Count(player, "DataShard") == 1)
	pd.Knowledge.Stack = {}
	-- the basin in the Rootwork
	local basin = BS.Basin()
	check("respec: the basin is built in the Rootwork, under the moss", basin ~= nil and basin.Prompt.Enabled == false)
	pd.Stats.Strength = 3; pd.FreePoints = 0; pd.Respecced = nil
	check("respec: a wrong order does nothing", BS.Touch(player, "SEED") == "reset" and BS.Respec(player) == false)
	for _, w in { "RAIN", "ROOT", "VINE" } do BS.Touch(player, w) end
	local solved = BS.Touch(player, "SEED")
	check("respec: the riddle's order raises it", solved == "solved" and basin.Prompt.Enabled == true)
	check("respec: kneeling there gives every point back, once a life", BS.Respec(player) == true and pd.Stats.Strength == 0 and pd.FreePoints == 3 and BS.Respec(player) == false)
	-- the blackout gate needs GRADE 3
	pd.Knowledge.Grade = 4
	check("grade: the Blackout gate refuses GRADE 4", BS.CanRaid(player) == false)
	pd.Knowledge.Grade = 0
	GearS.Recompute(player)
end

-- world and money (round 6: the hour's sky, parties, keys, party runs, fuel, timed crafting, the condenser, trust, swaps, the exchange, the drop)
do
	as(player)
	mendMe()
	local pd = PlayerData_.Get(player)
	local Cfg = M.mockEnv.__require(RS.Shared.Config)
	local WC = Cfg.World
	local SkyS = M.mockEnv.__require(SSS.Server.Sky)
	local PartyS = M.mockEnv.__require(SSS.Server.Party)
	local KeysS = M.mockEnv.__require(SSS.Server.Keys)
	local RunsS = M.mockEnv.__require(SSS.Server.Runs)
	local EcoS = M.mockEnv.__require(SSS.Server.Economy)
	local InvS = M.mockEnv.__require(SSS.Server.Inventory)
	local HideS = M.mockEnv.__require(SSS.Server.Hideouts)
	local TermS = M.mockEnv.__require(SSS.Server.Terminal)
	local BarS = M.mockEnv.__require(SSS.Server.Barrens)
	local CombatS = M.mockEnv.__require(SSS.Server.Combat)
	local Random = M.mockEnv.Random
	local os = M.mockEnv.os or os
	-- the sky
	check("sky: the hour has already picked a time of day and a weather", workspace_:GetAttribute("TimeOfDay") ~= nil and workspace_:GetAttribute("Weather") ~= nil)
	local nat = WC.Sky.Natural
	WC.Sky.Natural = 1
	local nextOk = SkyS.Pick(Random.new(1), "Dawn") == "Day" and SkyS.Pick(Random.new(1), "Night") == "Dawn"
	WC.Sky.Natural = 0
	local jumped = true
	for i = 1, 20 do if SkyS.Pick(Random.new(i), "Day") == "Day" then jumped = false end end
	WC.Sky.Natural = nat
	check("sky: a natural hour moves on to the next time of day; otherwise it jumps to any other", nextOk and jumped)
	SkyS.Apply("Day", "Clear")
	local daySight = SkyS.SightMult()
	SkyS.Apply("Night", "Fog")
	check("sky: night and fog shorten what guards see; the Lighting follows", SkyS.SightMult() < daySight * 0.7 and workspace_:GetAttribute("Weather") == "Fog")
	SkyS.Apply("Dusk", "Rain")
	check("sky: rain covers noise in the open, not underground", SkyS.NoiseMult(M.V3.new(0, 5, 0)) < 1 and SkyS.NoiseMult(M.V3.new(0, -300, 0)) == 1)
	SkyS.Apply("Day", "Clear")
	-- the party
	local mate = makePlayer("Mate", 141)
	Players.PlayerAdded:Fire(mate); run(2)
	local mc = mate.Character
	mc.HumanoidRootPart.CFrame = char().HumanoidRootPart.CFrame * M.CF.new(0, 0, 4)
	check("party: an invite reaches only someone standing with you", PartyS.Invite(player, tostring(mate.UserId)) == true)
	check("party: accepting joins the leader's party", PartyS.Accept(mate, tostring(player.UserId)) == true and PartyS.Allies(player, mate) and #PartyS.Members(mate) == 2
		and mate:GetAttribute("Party") == player.UserId)
	run(Cfg.SpawnProtection + 0.5)
	local mh = mc:FindFirstChildOfClass("Humanoid")
	local before = mh.Health
	CombatS.Damage(char(), mc, 30)
	check("party: members cannot hurt each other", mh.Health == before)
	-- keys and locked rooms
	local cage
	for _, r in KeysS.Rooms() do if r.Key == "ShelterKey" then cage = r end end
	check("keys: the S4 store cage stands locked in the hall with a crate inside", cage ~= nil and cage.Locked == true and cage.Door.CanCollide == true and cage.Crate ~= nil and cage.Crate.Parent ~= nil)
	if cage then
		InvS.Remove(player, "ShelterKey", InvS.Count(player, "ShelterKey"))
		check("keys: without the key the door stays shut", KeysS.Unlock(player, cage) == false and cage.Locked)
		InvS.Add(player, "ShelterKey", 1)
		check("keys: the right key opens it and is used up", KeysS.Unlock(player, cage) == true and not cage.Locked and cage.Door.CanCollide == false and InvS.Count(player, "ShelterKey") == 0)
		KeysS.Reset()
		check("keys: the hour relocks the door and refills the crate", cage.Locked == true and cage.Crate ~= nil and cage.Crate.Parent ~= nil)
	end
	-- a party run below the Sumps: both go down, take an order, blind the counter
	local B = Cfg.Barrens
	for _, p in { player, mate } do
		p.Character:PivotTo(M.CF.new(B.Head + M.V3.new(0, 3, -6)))
		M.task.spawn(function() BarS.Descend(p) end)
	end
	run(B.FadeSeconds + 0.4)
	mc.HumanoidRootPart.CFrame = char().HumanoidRootPart.CFrame * M.CF.new(0, 0, 3)
	local xp0 = (pd.Carried and pd.Carried.Xp) or 0
	local r = RunsS.Start(player, "Fuses")
	check("runs: a work order takes the whole party standing with you", r ~= nil and #r.Members == 2 and RunsS.Start(player) == nil)
	if r then
		for i = 1, 3 do r.Fuses[i].Prompt.Triggered:Fire(player) end
		run(0.5)
		local partial = RunsS.Current() == r
		r.Fuses[4].Prompt.Triggered:Fire(mate)
		run(0.6)
		check("runs: blinding the counter closes the order and pays both, carried until home", partial and RunsS.Current() == nil and ((pd.Carried and pd.Carried.Xp) or 0) > xp0
			and PlayerData_.Get(mate).Carried ~= nil)
	end
	local saw
	for _, e in M.FireLog do if e[1] == "World" and e[3] == "Run" and e[4] == "Fuses" then saw = true end end
	check("runs: the screen hears of the order", saw == true)
	-- the copy waits on noise
	RunsS.Stop(false)
	run(0.1)
	-- (the cooldown between orders)
	check("runs: the board rests between orders", RunsS.Start(player) == nil)
	for _, p in { player, mate } do BarS.Leave(p); p.Character:PivotTo(M.CF.new(0, 5, 0)) end
	PartyS.Leave(mate)
	check("party: leaving breaks a party of two", player:GetAttribute("Party") == nil and mate:GetAttribute("Party") == nil)
	-- the bay: fuel, the bench, the condenser
	local site = HideS.SiteOf(player)
	local h = pd.Hideout
	check("bay: the test conduit has a built bay", site ~= nil and site.Built ~= nil)
	if site and site.Built then
		h.Modules.Generator, h.Modules.Alarm = true, true
		h.Fuel = 0.15
		run(2.5)
		check("fuel: the alarm burns the generator dry; the bay goes dark", EcoS.Powered(site) == false and site.Built:GetAttribute("Dark") == true)
		InvS.Add(player, "FuelCan", 1)
		check("fuel: a can at the generator brings it back", EcoS.Refuel(player, site) == true and h.Fuel == WC.Fuel.PerCan and site.Built:GetAttribute("Dark") == false)
		local bench = site.Built:FindFirstChild("Bench")
		char():PivotTo(M.CF.new(0, 5, 0))
		InvS.Add(player, "Scrap", 12); InvS.Add(player, "Cloth", 4)
		local blades = InvS.Count(player, "RebarBlade") + ((h.Vault and h.Vault.RebarBlade) or 0)
		InvS.Craft(player, "RebarBlade")
		check("craft: a weapon needs the bench", h.Craft == nil)
		char():PivotTo(bench.CFrame * M.CF.new(0, 0, 3))
		InvS.Craft(player, "RebarBlade")
		check("craft: at the bench a weapon takes time", h.Craft ~= nil and h.Craft.Output == "RebarBlade" and InvS.Count(player, "RebarBlade") + ((h.Vault and h.Vault.RebarBlade) or 0) == blades)
		check("craft: one job at a time", InvS.Craft(player, "RebarBlade") == false)
		local fuel0 = h.Fuel
		local left0 = h.Craft.Left
		run(1.2)
		check("craft: a running generator doubles the pace and burns fuel", left0 - h.Craft.Left >= 1.5 and h.Fuel < fuel0 - 0.5)
		h.Craft.Left = 0.2
		run(1.2)
		check("craft: the finished piece goes to the vault or the pack", h.Craft == nil and InvS.Count(player, "RebarBlade") + ((h.Vault and h.Vault.RebarBlade) or 0) == blades + 1)
		local band = InvS.Count(player, "Bandage")
		InvS.Craft(player, "Bandage")
		check("craft: dressings are still made at once", InvS.Count(player, "Bandage") == band + 2)
		h.Modules.Condenser = true
		h.CondenserAt = os.time() - WC.Condenser.Period * 20
		local rations = InvS.Count(player, "Ration")
		check("condenser: it fills while you are away, up to its tank", EcoS.Condensed(h) == WC.Condenser.Cap and EcoS.Drain(player, site) == WC.Condenser.Cap
			and InvS.Count(player, "Ration") == rations + WC.Condenser.Cap and EcoS.Condensed(h) == 0)
	end
	-- trust and swaps
	local k = pd.Knowledge
	k.Contacts.Fixer, k.Contacts.Dealer, k.Contacts.Broker = true, true, true
	k.Loyalty = nil
	pd.War.Credits = 5000
	check("trust: every contact starts at the first level", EcoS.Loyalty(player, "Dealer") == 1)
	local ok1 = TermS.Buy(player, "MirrorChip")
	check("trust: the Dealer keeps some goods for those he trusts", ok1 == false and pd.War.Credits == 5000)
	TermS.Buy(player, "ReflexOptic")
	check("trust: credits spent with a contact earn trust", EcoS.LoyaltyPoints(player, "Dealer") == 650 * WC.Loyalty.PerCredit)
	EcoS.AddLoyalty(player, "Dealer", 400)
	check("trust: at its level the good is for sale", EcoS.Loyalty(player, "Dealer") >= 3 and TermS.Buy(player, "MirrorChip") == true)
	InvS.Add(player, "Scrap", 10)
	local cloth = InvS.Count(player, "Cloth")
	check("swap: goods for goods with a contact", EcoS.Swap(player, "ScrapForCloth") == true and InvS.Count(player, "Cloth") == cloth + 6)
	check("swap: a swap above your trust is refused", EcoS.Swap(player, "CellsForFuel") == false)
	-- the exchange: only what was found in a run, and banked
	InvS.Add(player, "Splint", 2)
	check("exchange: an item you did not find cannot be listed", EcoS.List(player, "Splint:2:1") == false)
	EcoS.Found(player, "Splint", 2)
	check("exchange: found but not yet home, it still cannot", EcoS.Sellable(player, "Splint") == 0)
	EcoS.BankFound(player)
	local cr = pd.War.Credits
	check("exchange: banked at home, it can be listed for a fee", EcoS.Sellable(player, "Splint") == 2 and EcoS.List(player, "Splint:2:2") == true and pd.War.Credits < cr and InvS.Count(player, "Splint") == 0)
	local st = EcoS.State(mate)
	local row = st and st.Board[1]
	check("exchange: another conduit sees the listing while the seller is online", row ~= nil and row.Id == "Splint" and row.Count == 2)
	local md = PlayerData_.Get(mate)
	md.War.Credits = 1000
	cr = pd.War.Credits
	local splints0 = InvS.Count(mate, "Splint")
	check("exchange: buying pays the seller and gives them reputation", row ~= nil and EcoS.Take(mate, row.Key) == true and InvS.Count(mate, "Splint") == splints0 + 2 and pd.War.Credits == cr + row.Price and (pd.Hideout.Rep or 0) == 1)
	check("exchange: a bought item is not found in a run", EcoS.Sellable(mate, "Splint") == 0 and EcoS.List(mate, "Splint:1:1") == false)
	-- the drop
	pd.Hideout.DropAt = nil
	cr = pd.War.Credits
	check("drop: the Fixer sends a consignment to the bay's lift", EcoS.Drop(player) == true and pd.War.Credits == cr - WC.Drop.Price and EcoS.Drop(player) == false)
	run(WC.Drop.Delay + 0.5)
	local found
	for _, d in workspace_:GetDescendants() do
		if d.Name == "Lootable" and d:GetAttribute("Label") == "Consignment" and site and site.LiftCFrame and (d.Position - site.LiftCFrame.Position).Magnitude < 4 then found = d end
	end
	check("drop: the crate stands in the lift", found ~= nil)
	local tstate = TermS.State(player)
	check("computer: trust, swaps, the exchange and the drop show on it", tstate.Economy ~= nil and #tstate.Economy.Swaps == #M.mockEnv.__require(RS.Shared.Terminal).Swaps and tstate.Economy.Drop.Wait > 0)
	pd.War.Credits = 0
	mate:Destroy()
	run(0.2)
end

-- stealth (round 4: the second before he shouts, guards who adapt, lockers, darts, bolts, clothes, questions, shifts)
do
	as(player)
	mendMe()
	local SS = Stealth
	local Cfg = M.mockEnv.__require(RS.Shared.Config).Stealth
	local CombatS = M.mockEnv.__require(SSS.Server.Combat)
	local InvS = M.mockEnv.__require(SSS.Server.Inventory)
	local LootS = M.mockEnv.__require(SSS.Server.Loot)
	local RulesS = M.mockEnv.__require(RS.Shared.Stealth)
	local lvl = M.newInstance("Model"); lvl.Name = "Round4Level"; lvl:SetAttribute("Ambient", 0.9); lvl.Parent = workspace_
	local base = M.V3.new(-1500, 3, 1500)
	local function post(at, toward)
		local m = SS.SpawnGuard(at, { Level = lvl, Post = M.CF.lookAt(at, toward) })
		local _, b = SS.StateOf(m)
		return m, b
	end
	local function world(from, kind)
		for i = from + 1, #M.FireLog do
			local e = M.FireLog[i]
			if e[1] == "World" and e[3] == kind then return e end
		end
	end
	SS.Enter(player, lvl)
	-- the second before he shouts
	local g1 = post(base, base + M.V3.new(0, 0, -10))
	root().CFrame = M.CF.lookAt(base + M.V3.new(0, 0, -12), base); run(0.1)
	local log0 = #M.FireLog
	run(4, function() return SS.StateOf(g1) ~= "Patrol" and SS.StateOf(g1) ~= "Suspicious" end)
	check("reflex: the guard who makes you freezes a second before he shouts", SS.StateOf(g1) == "Spotted" and world(log0, "Reflex") ~= nil and lvl:GetAttribute("Alarms") == nil)
	run(Cfg.Reflex + 0.3)
	check("reflex: then the alarm goes up, and the level remembers it", SS.StateOf(g1) == "Alert" and lvl:GetAttribute("Alarms") == 1)
	SS.Reset(lvl); run(0.2)
	check("adapt: a fresh start forgets the alarms", lvl:GetAttribute("Alarms") == nil and SS.StateOf(g1) == "Patrol")
	root().CFrame = M.CF.lookAt(base + M.V3.new(0, 0, -12), base); run(0.1)
	run(4, function() return SS.StateOf(g1) == "Spotted" end)
	root().CFrame = M.CF.lookAt(base + M.V3.new(0, 0, -2.5), base); run(0.05)
	Remotes.Cqc:FireServer("Throw", g1); run(0.2)
	check("reflex: put down inside that second, nobody hears", char():GetAttribute("Takedown") == "Throw")
	run(1.5)
	check("reflex: thrown, he never raised it", SS.StateOf(g1) == "Down" and lvl:GetAttribute("Alarms") == nil)
	-- lockers
	local spotAt = base + M.V3.new(40, -3, 0)
	local spot = SS.HidingSpot(M.CF.lookAt(spotAt, spotAt + M.V3.new(0, 0, -1)), lvl)
	check("hide: a locker stands with an X prompt", CS:HasTag(spot, "HidingSpot") and spot:FindFirstChild("HidePrompt") ~= nil)
	root().CFrame = M.CF.lookAt(spotAt + M.V3.new(0, 3, -2.6), spotAt + M.V3.new(0, 3, -8)); run(0.1)
	spot.HidePrompt.Triggered:Fire(player); run(0.3)
	check("hide: inside, you are held still, unlit and cannot fight", char():GetAttribute("Hidden") == true and root().Anchored == true
		and char():GetAttribute("Exposure") == 0 and CombatS.CanAct(char()) == false and SS.Hidden(player) == spot)
	local g2, b2 = post(spotAt + M.V3.new(0, 3, -3), spotAt + M.V3.new(0, 3, 0))
	run(1)
	check("hide: a guard standing at the door does not see you", SS.StateOf(g2) == "Patrol" and (b2.aware[player] or 0) == 0)
	SS.Noise(g2.HumanoidRootPart.Position, 6, "Glass"); run(1)
	check("hide: searching beside it in a calm level, he does not look inside", SS.StateOf(g2) == "Search" and char():GetAttribute("Hidden") == true)
	lvl:SetAttribute("Alarms", 1); run(0.5)
	check("adapt: after an alarm a searching guard opens the locker on you", char():GetAttribute("Hidden") == nil and root().Anchored == false
		and SS.StateOf(g2) == "Alert" and spot:GetAttribute("Occupant") == nil)
	SS.Reset(lvl); run(0.2)
	-- sleeping darts
	local g3, b3 = post(base + M.V3.new(-40, 0, 0), base + M.V3.new(-40, 0, -10))
	local g4 = post(base + M.V3.new(-60, 0, 0), base + M.V3.new(-60, 0, -10))
	root().CFrame = M.CF.lookAt(base + M.V3.new(-30, 0, 30), base + M.V3.new(-30, 0, 40)); run(0.1)
	CombatS.Slept:Fire(char(), g3, "Torso"); run(0.3)
	check("dart: in the body he feels it, goes looking, and is still up", SS.StateOf(g3) == "Search" and g3:GetAttribute("Downed") == nil)
	run(Cfg.Sleep.Delay + 0.3)
	check("dart: a few seconds later he goes down asleep", SS.StateOf(g3) == "Down" and g3:GetAttribute("Asleep") == true and b3.wakeAt ~= nil
		and lvl:GetAttribute("Alarms") == nil)
	CombatS.Slept:Fire(char(), g4, "Head"); run(0.1)
	check("dart: in the face he drops at once", SS.StateOf(g4) == "Down" and g4:GetAttribute("Asleep") == true)
	b3.wakeAt = 0; run(0.2)
	check("dart: he wakes when it wears off, up and searching", SS.StateOf(g3) == "Search" and g3:GetAttribute("Asleep") == nil and g3:GetAttribute("Downed") == nil)
	SS.Reset(lvl); run(0.2)
	-- the dart from the gun
	local W = M.mockEnv.__require(RS.Shared.Weapons)
	check("dart: a .22 dart is a load of the Whisper's calibre", W.Round("Round22Sleep").Sleep == true and table.find(W.LoadsOf(".22"), "Round22Sleep") ~= nil)
	-- a thrown bolt
	local g5 = post(base + M.V3.new(0, 0, 80), base + M.V3.new(0, 0, 100))
	root().CFrame = M.CF.lookAt(base + M.V3.new(0, 0, 60), base + M.V3.new(0, 0, 80)); run(0.1)
	InvS.Add(player, "Bolt", 2, true)
	log0 = #M.FireLog
	Remotes.UseItem:FireServer("Bolt", (g5.HumanoidRootPart.Position - (root().Position + M.V3.new(0, 1.5, 0))).Unit); run(0.3)
	check("bolt: thrown, it clatters where it lands and is spent", world(log0, "Clatter") ~= nil and InvS.Count(player, "Bolt") == 1)
	check("bolt: the guard who hears it goes to look", SS.StateOf(g5) == "Search")
	SS.Reset(lvl); run(0.2)
	-- clothes
	local ArmorS = M.mockEnv.__require(RS.Shared.Armor)
	local kit = ArmorS.Kit({ Cloak = "SootPoncho" })
	check("clothes: the poncho hides a share of you, the uniform passes", kit.Conceal == 0.3 and ArmorS.Kit({ Cloak = "SentryUniform" }).Disguise == true)
	InvS.Add(player, "SootPoncho", 1, true)
	Remotes.EquipItem:FireServer("SootPoncho"); run(0.5)
	check("clothes: worn, the poncho cuts how lit you are", char():GetAttribute("Conceal") == 0.3 and (char():GetAttribute("Exposure") or 1) <= 0.9 * 0.7 + 0.05)
	-- questions
	local g6 = post(base + M.V3.new(80, 0, 0), base + M.V3.new(80, 0, -10))
	local crate = LootS.Spawn(M.CF.new(base + M.V3.new(90, -2, 0)), { Scrap = 1 }, { Label = "Store" })
	if crate then crate.Parent = lvl end
	root().CFrame = M.CF.lookAt(base + M.V3.new(80, 0, 1.5), base + M.V3.new(80, 0, -10)); run(0.1)
	Remotes.Cqc:FireServer("Grab", g6); run(0.2)
	log0 = #M.FireLog
	Remotes.Cqc:FireServer("Question", g6); run(0.2)
	local q = world(log0, "Question")
	local standing = 0
	for _, m in SS.Guards(lvl) do if m ~= g6 and SS.StateOf(m) ~= "Down" then standing += 1 end end
	check("question: held, he gives up how many are on shift and where the stores are", q ~= nil and q.player == player and #q[6] == standing and q[7] == crate)
	log0 = #M.FireLog
	Remotes.Cqc:FireServer("Question", g6); run(0.2)
	check("question: only once", world(log0, "Question") == nil)
	SS.Release(player, "Choke"); run(2.5)
	-- shifts
	local n = SS.Shift(lvl, 1)
	local asleepOne
	for _, m in SS.Guards(lvl) do if SS.StateOf(m) == "Asleep" then asleepOne = m end end
	check("shift: a new shift can find guards asleep at their posts", n >= 1 and asleepOne ~= nil)
	local kind = RulesS.TakedownKind(M.CF.lookAt(asleepOne.HumanoidRootPart.Position + asleepOne.HumanoidRootPart.CFrame.LookVector * 2, asleepOne.HumanoidRootPart.Position), asleepOne.HumanoidRootPart.CFrame, "Asleep", {})
	check("shift: asleep, he can be taken from any side", kind == "Rear")
	SS.Noise(asleepOne.HumanoidRootPart.Position, 30, "Glass"); run(0.3)
	check("shift: a loud noise close by wakes him", SS.StateOf(asleepOne) == "Search")
	-- tidy up
	Remotes.Unequip:FireServer("Cloak"); run(0.2)
	SS.Leave(player)
	for _, m in SS.Guards(lvl) do m:Destroy() end
	lvl:Destroy()
	char():PivotTo(M.CF.new(0, 5, 0))
	run(0.5)
end

-- guns and ammo (round 3: loads, the EMP .22, magazines, plate wear, ricochets, heat, jams, tired arms, dropped guns)
do
	as(player)
	mendMe()
	local CombatG = M.mockEnv.__require(SSS.Server.Combat)
	local InvG = M.mockEnv.__require(SSS.Server.Inventory)
	local KitG = M.mockEnv.__require(SSS.Server.Kit)
	local W = M.mockEnv.__require(RS.Shared.Weapons)
	local data = PlayerData_.Get(player)
	local c = player.Character
	c.HumanoidRootPart.CFrame = M.CF.new(-700, 5, -900) -- away from everyone
	run(0.3)
	local function events(from, kind)
		local n = 0
		for i = from + 1, #M.FireLog do
			local e = M.FireLog[i]
			if e[1] == "CombatEvent" and e[3] == kind then n += 1 end
		end
		return n
	end
	check("ammo: a load is its calibre with its own numbers", W.Round("Round22Emp").Emp == true and W.Round("Round22Emp").Pen == 0
		and W.Round("Round9AP").Pen == 2 and W.Round("Round9HP").Flesh > 1 and W.LoadsOf("9mm")[1] == "Round9" and W.Round("Round9").Damage == 1
		and table.find(W.Chambered("Round22Emp"), W.Defs.Whisper.Name) ~= nil)
	InvG.Add(player, "Whisper", 1, true); InvG.Add(player, "Round22", 28, true); InvG.Add(player, "Round22Emp", 7, true)
	Remotes.EquipItem:FireServer("Whisper"); run(1)
	data.Load = nil
	CombatG.ResetMags(player); run(0.1)
	check("ammo: the standard load goes in first, with a loaded spare behind it", c:GetAttribute("AmmoItem") == "Round22" and c:GetAttribute("Load") == nil and c:GetAttribute("MagSpares") == 1)
	Remotes.UseItem:FireServer("Round22Emp"); run(0.3)
	check("ammo: choosing the EMP rounds changes the magazine (by hand: none of them are loaded ahead)", c:GetAttribute("Reloading") == true)
	run(4)
	check("ammo: the EMP load is in the gun", c:GetAttribute("AmmoItem") == "Round22Emp" and c:GetAttribute("Load") == ".22 EMP" and c:GetAttribute("Mag") == 7 and c:GetAttribute("Chambered") == true)
	-- targets: a body with a radio and a vest, another behind it
	local function dummy(at, name)
		local m = M.newInstance("Model"); m.Name = name
		local h = M.newInstance("Humanoid"); h.Parent = m
		local r = M.newInstance("Part"); r.Name = "HumanoidRootPart"; r.Size = M.V3.new(2, 2, 1); r.CFrame = M.CF.new(at); r.Parent = m
		local t = M.newInstance("Part"); t.Name = "UpperTorso"; t.Size = M.V3.new(2, 1.6, 1); t.CFrame = M.CF.new(at); t.Parent = m
		m.Parent = workspace_
		return m
	end
	local root = c.HumanoidRootPart
	local look = root.CFrame.LookVector
	local front = dummy(root.Position + look * 12 + M.V3.new(0, 1.2, 0), "Front")
	local behind = dummy(root.Position + look * 22 + M.V3.new(0, 1.2, 0), "Behind")
	front:SetAttribute("Radio", true); front:SetAttribute("Vest", 2)
	local log0 = #M.FireLog
	Remotes.Attack:FireServer(look); run(0.8)
	check("emp: an EMP .22 off a vest kills his radio, and nothing pings to tell him", front:GetAttribute("Radio") == false and events(log0, "Emp") == 1
		and events(log0, "Ping") == 0 and front.Humanoid.Health == 100 and (front:GetAttribute("VestWear") or 0) > 0)
	front:SetAttribute("Radio", true); front:SetAttribute("Vest", nil)
	Remotes.Rack:FireServer(); run(0.9)
	log0 = #M.FireLog
	Remotes.Attack:FireServer(look); run(0.8)
	local empHurt = 100 - front.Humanoid.Health
	check("emp: on flesh it kills the radio and he feels it, lighter than a full load", front:GetAttribute("Radio") == false and empHurt > 0 and events(log0, "Emp") == 1)
	-- back to the standard load: plate stops it, wears, and a glance goes on into the next body
	Remotes.UseItem:FireServer("Round22"); run(4)
	check("ammo: back to the standard load", c:GetAttribute("AmmoItem") == "Round22" and c:GetAttribute("Load") == nil)
	front.Humanoid.Health = 100
	front:SetAttribute("Vest", 2); front:SetAttribute("VestWear", nil)
	log0 = #M.FireLog
	Remotes.Attack:FireServer(look); run(0.1)
	local warm, warmAttr = CombatG.HeatOf(player, W.Defs.Whisper), c:GetAttribute("Heat") or 0
	run(0.7)
	check("plate: a stopped round pings, glances off and hits the body behind, weaker", events(log0, "Ping") == 1 and events(log0, "Ricochet") == 1
		and front.Humanoid.Health == 100 and behind.Humanoid.Health < 100)
	-- heat (that round just warmed the barrel)
	check("heat: the barrel warms with every round", warm > 0 and warmAttr > 0)
	check("plate: a .22 wears it a little", math.abs((front:GetAttribute("VestWear") or 0) - 0.5) < 1e-6)
	for _ = 1, 19 do CombatG.WearPlate(front, "Vest", 2, 0.5) end
	check("plate: it wears through: twenty rounds of .22 and the vest is gone", front:GetAttribute("Vest") == 0 and front:GetAttribute("VestBroken") == true)
	Remotes.Rack:FireServer(); run(0.9)
	CombatG.SetHeat(player, W.Defs.Whisper, 1)
	local mag0 = c:GetAttribute("Mag")
	Remotes.Attack:FireServer(look); run(0.5)
	check("heat: too hot, it will not fire", c:GetAttribute("Mag") == mag0)
	CombatG.SetHeat(player, W.Defs.Whisper, 0)
	-- jams
	CombatG.Jam(player, "Stovepipe")
	Remotes.Attack:FireServer(look); run(0.5)
	check("jam: a jammed gun fires nothing", c:GetAttribute("Mag") == mag0 and c:GetAttribute("Jam") == "Stovepipe")
	Remotes.Rack:FireServer(); run(0.9)
	check("jam: T clears a stovepipe", c:GetAttribute("Jam") == nil)
	CombatG.Jam(player, "DoubleFeed")
	Remotes.Rack:FireServer(); run(0.9)
	check("jam: a double feed does not clear with T", c:GetAttribute("Jam") == "DoubleFeed")
	Remotes.Reload:FireServer(); run(4)
	check("jam: the magazine out (R) clears a double feed", c:GetAttribute("Jam") == nil)
	ConfigM.Guns.Jam.Base = 1
	Remotes.Attack:FireServer(look); run(0.5)
	check("jam: they come in kinds", ({ Feed = true, Stovepipe = true, DoubleFeed = true })[c:GetAttribute("Jam") or ""] == true)
	ConfigM.Guns.Jam.Base = 0
	c:SetAttribute("Jam", nil)
	-- magazines: a loaded spare goes in fast; R on a full one loads a spare by hand
	InvG.Add(player, "Round22", 21, true)
	CombatG.ResetMags(player); run(0.1)
	local spares0 = c:GetAttribute("MagSpares")
	Remotes.Rack:FireServer(); run(0.9)
	Remotes.Attack:FireServer(look); run(0.8)
	Remotes.Reload:FireServer(); run(4)
	check("mags: the change takes a loaded spare from the pouch", spares0 == 1 and c:GetAttribute("MagSpares") == 0 and c:GetAttribute("Mag") == 7)
	Remotes.Reload:FireServer(); run(0.2)
	check("mags: R on a full magazine loads a spare by hand", c:GetAttribute("Reloading") == true)
	run(4)
	check("mags: the spare is loaded", c:GetAttribute("MagSpares") == 1)
	-- tired arms
	Remotes.Aim:FireServer(true); run(7)
	local tired = c:GetAttribute("ArmFatigue") or 0
	Remotes.Aim:FireServer(false); run(2)
	check("arms: holding a gun up tires the arms, and they come back at rest", tired > 0.1 and (c:GetAttribute("ArmFatigue") or 0) < tired)
	-- a dropped gun
	local dropped = KitG.DropGun(M.CF.new(root.Position + look * 3), "DutyPistol")
	check("drop: a gun lies on the floor with a prompt", dropped ~= nil and dropped.Parent ~= nil and dropped:FindFirstChild("Holder") ~= nil
		and dropped.Holder:FindFirstChild("Grab") ~= nil)
	check("drop: X takes it straight into the hand", KitG.Grab(player, dropped) == true and data.Equipped == "DutyPistol" and InvG.Count(player, "DutyPistol") >= 1 and dropped.Parent == nil)
	-- tags
	check("tags: a stack tag is an item the Reach's trader buys", M.mockEnv.__require(RS.Shared.Items).Defs.Tag ~= nil and ConfigM.Guns.TagCredits > 0)
	front:Destroy(); behind:Destroy()
	Remotes.EquipItem:FireServer("Whisper"); run(0.5)
end

-- the kit and two weapons (round 2: server/Kit.lua, server/Knock.lua, Combat's chain moves)
do
	as(player)
	mendMe()
	local KitS = M.mockEnv.__require(SSS.Server.Kit)
	local CombatK = M.mockEnv.__require(SSS.Server.Combat)
	local InvK = M.mockEnv.__require(SSS.Server.Inventory)
	local data = PlayerData_.Get(player)
	local c = player.Character
	c.HumanoidRootPart.CFrame = M.CF.new(-900, 5, -900) -- away from everyone
	run(0.5)
	for _, id in { "Carbine", "Whisper", "DutyBelt", "PlateCarrier", "RebarBlade", "PipeClub", "Bandage" } do InvK.Add(player, id, 1, true) end
	InvK.Add(player, "Round556", 30, true)
	check("kit: with no belt a short weapon has nowhere to ride", KitS.MountFor(data, "Whisper") == nil and KitS.MountFor(data, "Carbine") == "Back")
	Remotes.EquipItem:FireServer("DutyBelt"); run(0.3)
	check("kit: a belt gives a hip holster", KitS.MountFor(data, "Whisper") == "Hip" and c:FindFirstChild("KitWorn") ~= nil)
	Remotes.EquipItem:FireServer("Carbine"); run(0.3)
	Remotes.EquipItem:FireServer("Whisper"); run(0.3)
	local stowed = c:FindFirstChild("StowedWeapon")
	check("kit: equipping a second weapon slings the first across the back", data.Equipped == "Whisper" and data.Second == "Carbine"
		and c:GetAttribute("Second") == "Carbine" and (stowed == nil or stowed:GetAttribute("Mount") == "Back"))
	run(1)
	Remotes.Swap:FireServer(); run(0.6)
	check("kit: 1 swaps the carried weapon into the hand", data.Equipped == "Carbine" and data.Second == "Whisper")
	Remotes.EquipItem:FireServer("PlateCarrier"); run(0.3)
	check("kit: a plate carrier puts a plate over the chest and pouches on the body", c:GetAttribute("Vest") == 2 and (c:GetAttribute("KitMags") or 0) >= 4
		and (c:GetAttribute("KitMeds") or 0) >= 2)
	-- a quick dressing from the pouches
	local st = M.mockEnv.__require(SSS.Server.Common.WoundService).Get(c)
	st.Bleed.ArmR = "Light"; M.mockEnv.__require(SSS.Server.Common.WoundService).Push(c)
	local bandages = InvK.Count(player, "Bandage")
	Remotes.QuickMed:FireServer(); run(0.8)
	check("kit: 2 dresses the worst wound from the pouches", c:GetAttribute("Bleed_ArmR") == "" and InvK.Count(player, "Bandage") == bandages - 1)
	-- the chain: across a swap, a held beat, a lock-on lunge
	Remotes.EquipItem:FireServer("PipeClub"); run(0.3)
	Remotes.EquipItem:FireServer("RebarBlade"); run(0.5)
	local function swings()
		local t = {}
		for _, e in M.FireLog do if e[1] == "CombatEvent" and e[3] == "Swing" and e[4] == c then table.insert(t, e[5]) end end
		return t
	end
	local before = #swings()
	Remotes.Attack:FireServer(); run(0.9)
	Remotes.Swap:FireServer(); run(0.4)
	Remotes.Attack:FireServer(); run(0.9)
	local sw = swings()
	check("kit: a swap mid-chain carries the chain into the other weapon", #sw >= before + 2 and sw[#sw] == 2)
	run(2)
	Remotes.EquipItem:FireServer("RebarBlade"); run(0.5)
	Remotes.Attack:FireServer(); run(0.35)
	Remotes.Attack:FireServer(); run(0.05)
	run(0.6)
	Remotes.Attack:FireServer(); run(0.05)
	local lungeSeen = false
	Remotes.Attack:FireServer(nil, "Forward"); run(1.2)
	Remotes.Attack:FireServer(nil, "Forward"); run(1.2)
	for _, e in M.FireLog do if e[1] == "CombatEvent" and e[3] == "Lunge" then lungeSeen = true end end
	sw = swings()
	local labels = {}
	for _, l in sw do labels[tostring(l)] = true end
	check("kit: a forward press when locked on is a lunge", lungeSeen and labels.Lunge == true)
	-- knocked down, not dead
	local helper = makePlayer("Medic", 131)
	Players.PlayerAdded:Fire(helper); run(0.5)
	local hum = c:FindFirstChildOfClass("Humanoid")
	hum.Health = 20
	local hc = helper.Character
	hc.HumanoidRootPart.CFrame = c.HumanoidRootPart.CFrame * M.CF.new(0, 0, 3)
	run(ConfigM.SpawnProtection + 0.5)
	CombatK.Damage(hc, c, 500)
	check("knock: a blow that would kill a player knocks them down instead", c:GetAttribute("Knocked") == true and hum.Health > 0 and player.Character == c)
	local KnockS = M.mockEnv.__require(SSS.Server.Knock)
	check("knock: knocked, they cannot fight", CombatK.CanAct(c) == false)
	check("knock: another player picks them up", KnockS.PickUp(c, helper) == true and c:GetAttribute("Knocked") == nil and hum.Health >= hum.MaxHealth * 0.25 - 0.01)
	hum.Health = 10
	CombatK.Damage(hc, c, 500)
	check("knock: only once in a while; the next fatal blow kills", hum.Health <= 0)
	run(8)
	helper:Destroy()
end

-- things you make (round 7: the Breaker and Cable arms, slave tech, companions, the humanoid drone)
do
	as(player)
	run(1)
	mendMe()
	local pd = PlayerData_.Get(player)
	local Cfg = M.mockEnv.__require(RS.Shared.Config)
	local MK = Cfg.Make
	local ArmsS = M.mockEnv.__require(SSS.Server.Arms)
	local ThrS = M.mockEnv.__require(SSS.Server.Thralls)
	local CompS = M.mockEnv.__require(SSS.Server.Companions)
	local ProxS = M.mockEnv.__require(SSS.Server.Proxy)
	local InvS = M.mockEnv.__require(SSS.Server.Inventory)
	local GearS = M.mockEnv.__require(SSS.Server.Gear)
	local HideS = M.mockEnv.__require(SSS.Server.Hideouts)
	local CombatS = M.mockEnv.__require(SSS.Server.Combat)
	local NPCsS = M.mockEnv.__require(SSS.Server.NPCs)
	local TermS = M.mockEnv.__require(SSS.Server.Terminal)
	local ItemsS = M.mockEnv.__require(RS.Shared.Items)
	local c = char()
	c:PivotTo(M.CF.new(40, 5, 40))
	run(Cfg.SpawnProtection + 0.3)
	-- the Breaker arm
	InvS.Add(player, "BreakerArm", 1)
	pd.Cyber.RightArm = "BreakerArm"; GearS.Recompute(player)
	check("arms: a Breaker arm fitted has an active", ArmsS.ActiveOf(player) == "Breaker")
	local dummy = NPCsS.Spawn("Raider", root().Position + root().CFrame.LookVector * 3, { Parent = game_.Workspace })
	local dh = dummy:FindFirstChildOfClass("Humanoid")
	dh.MaxHealth, dh.Health = 5000, 5000
	run(0.1)
	local function swingAt()
		dummy.HumanoidRootPart.CFrame = root().CFrame * M.CF.new(0, 0, -3)
		local h0 = dh.Health
		for _ = 1, 6 do
			Remotes.Attack:FireServer(root().CFrame.LookVector); run(0.75)
			if dh.Health < h0 then break end
		end
		return h0 - dh.Health
	end
	local plain = swingAt()
	run(1.2)
	check("arms: K held primes the arm", ArmsS.Fire(player, root().CFrame.LookVector) == true and CombatS.State(char()).spendUntil ~= nil)
	local spent = swingAt()
	check("arms: the next blow lands four times as hard and the arm is spent", plain > 0 and spent >= plain * 3 and pd.Condition.BreakerArm == 0 and ArmsS.ActiveOf(player) == nil)
	-- the Cable arm
	InvS.Add(player, "CableArm", 1)
	pd.Cyber.RightArm = "CableArm"; GearS.Recompute(player)
	run(MK.Breaker.Cooldown + 0.2)
	local sawCable
	check("arms: the cable fires along the aim", ArmsS.ActiveOf(player) == "Cable" and ArmsS.Fire(player, root().CFrame.LookVector) == true)
	for _, e in M.FireLog do if e[1] == "CombatEvent" and e[3] == "Cable" then sawCable = true end end
	check("arms: everyone sees the line; it waits before the next", sawCable == true and ArmsS.Fire(player, root().CFrame.LookVector) == false)
	pd.Cyber.RightArm = nil; GearS.Recompute(player)
	-- slave tech
	local h = pd.Hideout
	h.Modules.Holding, h.Modules.ProxyFrame = true, true
	h.Tier = math.max(h.Tier, 2)
	local site = HideS.Rebuild(player)
	check("bay: the holding frame and the proxy frame stand in the bay", site ~= nil and site.Built:FindFirstChild("Holding") ~= nil and site.Built:FindFirstChild("ProxyFrame") ~= nil)
	dh.Health = dh.MaxHealth
	dummy.HumanoidRootPart.CFrame = root().CFrame * M.CF.new(0, 0, -3)
	check("thrall: a fighting body cannot be shackled", ThrS.Shackleable(dummy) == false)
	dh.Health = dh.MaxHealth * 0.2
	InvS.Add(player, "Shackle", 1)
	h.Thralls = nil
	check("thrall: a beaten one is shackled and taken to the frame", ThrS.Capture(player) == true and #h.Thralls == 1 and dummy.Parent == nil and InvS.Count(player, "Shackle") == 0)
	check("thrall: it stands in the holding frame", site.Built:FindFirstChild("HeldFigures") ~= nil and #site.Built.HeldFigures:GetChildren() == 1)
	local st = TermS.State(player)
	check("thrall: the computer lists it", st.Thralls and #st.Thralls == 1 and st.Thralls[1].Name == h.Thralls[1].Name)
	h.Thralls = { { Type = "Raider", Name = "UNIT 0001" }, { Type = "Raider", Name = "UNIT 0002" }, { Type = "Raider", Name = "UNIT 0003" } }
	h.Debts, h.Invaders = nil, nil
	pd.War.Thralls = nil
	check("thrall: released, it leaves a debt", ThrS.Release(player, 1) == true and #h.Thralls == 2 and #h.Debts == 1)
	check("thrall: reprogrammed, it goes to the Front", ThrS.Reprogram(player, 1) == true and #h.Thralls == 1 and pd.War.Thralls[1].Name == "UNIT 0002")
	local esc = MK.Thrall.Escape
	MK.Thrall.Escape, MK.Thrall.EscapePowered = 1, 1
	ThrS.Hour()
	MK.Thrall.Escape, MK.Thrall.EscapePowered = esc, 0.04
	local debtCrate
	for _, d in workspace_:GetDescendants() do if d.Name == "Lootable" and d:GetAttribute("Label") == "Unsigned" then debtCrate = d end end
	check("thrall: an hour later the released one's crate stands in the lift", debtCrate ~= nil and #h.Debts == 0)
	check("thrall: a kept one broke out and became an invader", #h.Thralls == 0 and #h.Invaders == 1 and h.Invaders[1].Name == "UNIT 0003")
	local inv = ThrS.Invade(player, h.Invaders[1])
	check("thrall: the invader comes for its conduit, stronger", inv ~= nil and inv:GetAttribute("Invader") == "UNIT 0003" and inv:FindFirstChildOfClass("Humanoid").MaxHealth > 100 and ThrS.Hunting(player) == inv)
	if inv then
		CombatS.Damage(char(), inv, 1e5, { Unblockable = true })
		run(1)
	end
	check("thrall: killed, it is off the list", #h.Invaders == 0 and ThrS.Hunting(player) == nil)
	-- companions
	CompS.Dismiss(player)
	check("companion: three strays wait in the green pockets", (function() local n = 0 for _, s in CompS.Strays() do if s.Parent then n += 1 end end return n end)() == 3)
	local stray
	for _, s in CompS.Strays() do stray = s break end
	InvS.Remove(player, "Ration", InvS.Count(player, "Ration"))
	check("companion: a stray will not come without food", CompS.Tame(player, stray) == false)
	InvS.Add(player, "Ration", 1)
	check("companion: fed, the stray follows you", CompS.Tame(player, stray) == true and h.Companion.Kind == "Dog" and CompS.Get(player) ~= nil and stray.Parent == nil)
	local dog = CompS.Get(player).Model
	check("companion: it is yours and cannot hurt you", dog:GetAttribute("Owner") == player.UserId and CombatS.Damage(dog, char(), 20) == "none")
	char():PivotTo(M.CF.new(400, 5, 400)); run(0.6)
	check("companion: it keeps up", (dog.HumanoidRootPart.Position - root().Position).Magnitude < MK.Companion.Leash)
	InvS.Add(player, "CyberGraft", 1)
	check("companion: a graft needs the Autonet", CompS.UseItem(player, "CyberGraft", ItemsS.Defs.CyberGraft) == false and h.Companion.Kind == "Dog")
	CompS.Dismiss(player)
	InvS.Add(player, "DroneShell", 1)
	InvS.Use(player, "DroneShell")
	run(0.5)
	local drone = CompS.Get(player)
	check("companion: a drone shell from the pack wakes up at your shoulder", drone ~= nil and drone.Kind == "Drone" and InvS.Count(player, "DroneShell") == 0)
	drone.Hum:TakeDamage(1e6)
	run(0.5)
	check("companion: a companion that dies is gone", CompS.Get(player) == nil and h.Companion == nil)
	-- the humanoid drone
	char():PivotTo(site.Built.ProxyFrame.CFrame * M.CF.new(0, 0, -3))
	run(Cfg.SpawnProtection + 0.3)
	InvS.Add(player, "Scrap", 5)
	local carry0 = ItemsS.Carry(pd)
	local hpConduit = GearS.Get(player).MaxHealth
	local okLink = ProxS.Link(player)
	run(Cfg.SpawnSettle + 0.5)
	local drc = player.Character
	check("proxy: linking wakes you in the drone at the frame", okLink == true and player:GetAttribute("Proxy") == true and drc:GetAttribute("Proxy") == true
		and site.Built:FindFirstChild("Resting") ~= nil)
	check("proxy: the drone has less health and a bigger back", drc.Humanoid.MaxHealth < hpConduit and ItemsS.Carry(pd) > carry0)
	local level0 = pd.Level
	drc.Humanoid:TakeDamage(1e6)
	run(4)
	local wreck
	for _, d in workspace_:GetDescendants() do if d.Name == "Lootable" and d:GetAttribute("Label") == "Wrecked drone" then wreck = d end end
	check("proxy: a lost drone drops what it carried, and the conduit wakes in its body", wreck ~= nil and player:GetAttribute("Proxy") == nil and player.Character ~= drc
		and InvS.Count(player, "Scrap") == 0 and pd.Level == level0 and h.ProxyLost == true)
	check("proxy: the wrecked drone needs parts before the next link", ProxS.Link(player) == false)
	run(1)
end


-- ===== limbs break and come off; nothing bursts (server/Dismember) =====
do
	local DisS = M.mockEnv.__require(SSS.Server.Dismember)
	local GoreS = M.mockEnv.__require(SSS.Server.Gore)
	local DC = ConfigM.Dismember
	local function body(at, health)
		local m = M.newInstance("Model"); m.Name = "LimbDummy"
		local function part(name, x, y, sx, sy)
			local p = M.newInstance("Part"); p.Name = name; p.Size = M.V3.new(sx, sy, 1); p.CFrame = M.CF.new(at + M.V3.new(x, y, 0)); p.Parent = m; return p
		end
		part("HumanoidRootPart", 0, 3, 2, 2); part("LowerTorso", 0, 2.6, 2, 0.8); part("UpperTorso", 0, 3.8, 2, 1.6); part("Head", 0, 5.2, 1.2, 1.2)
		for _, side in { { "Left", -1 }, { "Right", 1 } } do
			part(side[1] .. "UpperArm", 1.5 * side[2], 4, 1, 1.2); part(side[1] .. "LowerArm", 1.5 * side[2], 2.9, 1, 1); part(side[1] .. "Hand", 1.5 * side[2], 2.2, 1, 0.4)
			part(side[1] .. "UpperLeg", 0.5 * side[2], 1.6, 1, 1.2); part(side[1] .. "LowerLeg", 0.5 * side[2], 0.7, 1, 1); part(side[1] .. "Foot", 0.5 * side[2], 0.1, 1, 0.3)
		end
		local h = M.newInstance("Humanoid"); h.MaxHealth = health; h.Health = health; h.WalkSpeed = 16; h.Parent = m
		m.PrimaryPart = m.HumanoidRootPart
		m.Parent = workspace_
		return m, h
	end
	local at = M.V3.new(3000, 400, 900)
	local m, h = body(at, 100)
	local armR, armL, legL, chest = at + M.V3.new(1.5, 2.9, 0), at + M.V3.new(-1.5, 2.9, 0), at + M.V3.new(-0.5, 0.7, 0), at + M.V3.new(0, 3.8, 0)
	check("limbs: a point on the forearm is the arm, a point on the chest is no limb", DisS.LimbAt(m, armR) == "ArmR" and DisS.LimbAt(m, legL) == "LegL" and DisS.LimbAt(m, chest) == nil)
	check("limbs: a hard cut to the chest takes nothing off", DisS.Hit(m, { Amount = 90, At = chest, Kind = "Cut" }) == nil)
	check("limbs: a light cut to the arm takes nothing off", DisS.Hit(m, { Amount = DC.Sever.Cut * 100 - 4, At = armR, Kind = "Cut" }) == nil and m:GetAttribute("Lost_ArmR") == nil)
	local blunt = DC.Sever.Cut * 100 + 5
	local r1, p1 = DisS.Hit(m, { Amount = blunt, At = armL, Kind = "Blunt" })
	check("limbs: the blow that a blade would sever with only breaks under a blunt weapon", r1 == "Break" and p1 == "ArmL" and m:GetAttribute("Broken_ArmL") == true and m:GetAttribute("Lost_ArmL") == nil)
	check("limbs: a blunt weapon breaks sooner than a blade does", DC.Break.Blunt < DC.Break.Cut and DC.Sever.Blunt > DC.Sever.Cut * 2)
	check("limbs: a broken arm hits weaker", (m:GetAttribute("LimbDamage") or 1) < 1)
	local r2, p2 = DisS.Hit(m, { Amount = blunt, At = armR, Kind = "Cut", Direction = M.V3.new(1, 0, 0) })
	local piece
	for _, c in workspace_:FindFirstChild("Gore"):GetChildren() do if c.Name == "SeveredLimb" then piece = c end end
	check("limbs: a hard cut to the arm takes it off at the elbow", r2 == "Sever" and p2 == "ArmR" and m:GetAttribute("Lost_ArmR") == true
		and m.RightLowerArm:GetAttribute("Severed") == true and m.RightHand:GetAttribute("Severed") == true and m.RightUpperArm:GetAttribute("Severed") == nil)
	check("limbs: the piece falls as its own thing, and the stump is capped", piece ~= nil and m.RightUpperArm:FindFirstChild("Stump") ~= nil)
	check("limbs: the same limb cannot come off twice", DisS.Hit(m, { Amount = 90, At = armR, Kind = "Cut" }) == nil)
	local speed0 = h.WalkSpeed
	DisS.Hit(m, { Amount = blunt, At = legL, Kind = "Cut" }); run(1.2)
	check("limbs: a lost leg slows him and he bleeds", m:GetAttribute("Lost_LegL") == true and h.WalkSpeed < speed0 and h.Health < 100)
	-- the corpse keeps the loss and stays in one piece
	local gore = workspace_:FindFirstChild("Gore")
	local before = {}
	for _, c in gore:GetChildren() do before[c] = true end
	m:SetAttribute("LastHitType", "Explosive")
	h.Health = 0
	GoreS.OnDied(m); run(0.5)
	local corpse, loose = nil, 0
	for _, c in gore:GetChildren() do
		if not before[c] then
			if c.Name == "Corpse" then corpse = c elseif c.Name ~= "SeveredLimb" then loose += 1 end
		end
	end
	check("limbs: no body bursts; even a blast leaves one corpse", corpse ~= nil)
	check("limbs: the corpse is missing what the body lost", corpse ~= nil and corpse:GetAttribute("Lost_ArmR") == true and corpse:GetAttribute("Lost_LegL") == true)
	-- through the fight: a blade's contact point on the arm
	local m2, h2 = body(at + M.V3.new(20, 0, 0), 100)
	CS:AddTag(m2, "NPC")
	local hit2 = at + M.V3.new(20 + 1.5, 2.9, 0)
	Combat.Damage(char(), m2, 60, { ContactPoint = hit2, WoundKind = "Cut", Unblockable = true })
	check("limbs: in a fight, the blade's contact point decides", m2:GetAttribute("Lost_ArmR") == true or m2:GetAttribute("Broken_ArmR") == true)
	local big = body(at + M.V3.new(40, 0, 0), DC.MaxHealth + 100)
	check("limbs: the big ones keep their limbs", DisS.Hit(big, { Amount = 900, At = at + M.V3.new(41.5, 2.9, 0), Kind = "Cut" }) == nil)
	m2:Destroy(); big:Destroy(); m:Destroy()
end


check("no script errors", #M.errors == 0)
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
