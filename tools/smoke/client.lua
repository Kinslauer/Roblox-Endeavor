-- Runs the Endeavor client script against the mock with a fake LocalPlayer. Catches any error
-- in the client's top-level setup (which would otherwise kill input handling silently).
CLIENT_MODE = true
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local Players = game_:GetService("Players")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
-- the server normally creates the remotes; build them here
local remotesFolder = M.newInstance("Folder"); remotesFolder.Name = "Remotes"; remotesFolder.Parent = RS
local src = TREE_SHARED.Remotes.source
for name in src:gmatch('"(%a+)"') do if name ~= "Remotes" and name ~= "Folder" and name ~= "RemoteEvent" then local r = M.newInstance("RemoteEvent"); r.Name = name; r.Parent = remotesFolder end end
local player = M.newInstance("Player"); player.Name, player.DisplayName, player.UserId = "Tester", "Tester", 1
local pg = M.newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = player
player.Parent = Players; Players.LocalPlayer = player
local cam = M.newInstance("Camera"); cam.Name = "CurrentCamera"; cam.CFrame = M.CF.new(0, 5, 0); cam.Parent = workspace_
-- the client folder as Rojo builds it: StarterPlayerScripts.Client = { Main (LocalScript), Movement, ... }
M.mkTree({ Client = { class = "Folder", children = TREE_CLIENT } }, game_:GetService("StarterPlayer"))
local client = game_:GetService("StarterPlayer").Client.Main
local ok, err = pcall(function() M.loadSource(client)() end)
print("client ran:", ok, err or "")
for _ = 1, 30 do M.step(1/30) end
-- movement (client/Movement): a character arrives, the controller takes over jump and dodge
local function check(label, ok) print((ok and "PASS  " or "FAIL  ") .. label) end
local char = M.newInstance("Model"); char.Name = "Tester"
local root = M.newInstance("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
local lower = M.newInstance("Part"); lower.Name = "LowerTorso"; lower.Parent = char
local rootJoint = M.newInstance("Motor6D"); rootJoint.Name = "Root"; rootJoint.Transform = M.CF.new(); rootJoint.Parent = lower
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 128
local hum = M.newInstance("Humanoid"); hum.Name = "Humanoid"; hum.WalkSpeed = 16; hum.JumpHeight = 8; hum.Parent = char
local animator = M.newInstance("Animator"); animator.Name = "Animator"; animator.Parent = hum
char:SetAttribute("Stamina", 100); char:SetAttribute("MaxStamina", 100); char:SetAttribute("Posture", 0); char:SetAttribute("MaxPosture", 100); char:SetAttribute("Charge", 0); char:SetAttribute("MaxCharge", 100)
hum.Health, hum.MaxHealth = 100, 100
char.Parent = workspace_
player.Character = char
player.CharacterAdded:Fire(char)
for _ = 1, 10 do M.step(1/30) end
local Movement = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Movement)
-- momentum: full input does not arrive in one frame
hum.MoveDirection = M.V3.new(1, 0, 0)
M.step(1/60)
local moved = rawget(hum, "_moved")
check("movement: the move direction eases toward the input", moved and moved.X > 0 and moved.X < 1)
for _ = 1, 30 do M.step(1/30) end
check("movement: and reaches it", rawget(hum, "_moved") and math.abs(rawget(hum, "_moved").X - 1) < 1e-6)
-- jump on the ground goes through the humanoid
hum.Jump = true; M.step(1/30); hum.Jump = false; M.step(1/30)
local jumped = false
for _, e in M.FireLog do if e[1] == "HumanoidState" and e[2]:find("Jumping") then jumped = true end end
check("movement: Space on the ground jumps", jumped and Movement.Action() == "Jump")
-- in the air (past coyote time) the next Space is the double jump
hum.FloorMaterial = "Material.Air"
for _ = 1, 12 do M.step(1/30) end
hum.Jump = true; M.step(1/30); hum.Jump = false; M.step(1/30)
check("movement: Space in the air double jumps", Movement.Action() == "DoubleJump" and root.AssemblyLinearVelocity.Y > 20)
hum.Jump = true; M.step(1/30); hum.Jump = false; M.step(1/30)
check("movement: only once per airtime", Movement.Action() == "DoubleJump")
-- Q in the air: a dash, once; it tells the server
local fired = 0
local before = #M.FireLog
check("movement: Q in the air dashes", Movement.Dodge(M.V3.new(0, 0, -1)) == true and root:FindFirstChild("DashVelocity") ~= nil and Movement.Action() == "Dash")
for _ = 1, 30 do M.step(1/30) end
check("movement: the dash ends on its own", root:FindFirstChild("DashVelocity") == nil)
check("movement: one air dash per airtime", Movement.Dodge(M.V3.new(0, 0, -1)) == false)
-- landing refills both; Q on the ground rolls
hum.FloorMaterial = "Material.Concrete"
for _ = 1, 3 do M.step(1/30) end
check("movement: landing ends the airborne action", Movement.Action() == "None")
check("movement: Q on the ground rolls", Movement.Dodge(M.V3.new(1, 0, 0)) == true and root:FindFirstChild("RollVelocity") ~= nil and Movement.Action() == "Roll")
-- jump right after the roll starts = long jump
hum.Jump = true; M.step(1/30); hum.Jump = false; M.step(1/30)
check("movement: a jump out of a roll is a long jump", Movement.Action() == "LongJump" and root:FindFirstChild("LongJumpVelocity") ~= nil)
local played = {}
for _, e in M.FireLog do if e[1] == "AnimPlay" then played[e[2]] = true end end
check("movement: the template's animations play", played["rbxassetid://14181171022"] and played["rbxassetid://14145234694"])
-- no stamina, no dodge
for _ = 1, 40 do M.step(1/30) end
char:SetAttribute("Stamina", 0)
check("movement: no stamina, no dodge", Movement.Dodge(M.V3.new(1, 0, 0)) == false)
-- armour changes Q: forward still rolls, sides/back become a heavy step, no air dash; light gear is unchanged
char:SetAttribute("Stamina", 100)
hum.FloorMaterial = "Material.Concrete"
for _ = 1, 40 do M.step(1/30) end
char:SetAttribute("GearWeight", 4)
check("dodge: armoured, Q to the side is a heavy step", Movement.Dodge(M.V3.new(1, 0, 0)) == true and root:FindFirstChild("StepVelocity") ~= nil and Movement.Action() == "Step")
for _ = 1, 40 do M.step(1/30) end
check("dodge: armoured, Q forward still rolls", Movement.Dodge(M.V3.new(0, 0, -1)) == true and root:FindFirstChild("RollVelocity") ~= nil)
for _ = 1, 40 do M.step(1/30) end
char:SetAttribute("GearWeight", 1)
check("dodge: any armour at all makes a backstep heavy", Movement.Dodge(M.V3.new(0, 0, 1)) == true and Movement.Action() == "Step")
for _ = 1, 40 do M.step(1/30) end
hum.FloorMaterial = "Material.Air"
for _ = 1, 12 do M.step(1/30) end
check("dodge: no air dash in armour", Movement.Dodge(M.V3.new(0, 0, -1)) == false)
char:SetAttribute("GearWeight", 0)
check("dodge: light gear keeps the air dash", Movement.Dodge(M.V3.new(1, 0, 0)) == true and Movement.Action() == "Dash")
hum.FloorMaterial = "Material.Concrete"
for _ = 1, 40 do M.step(1/30) end
check("dodge: light gear rolls sideways", Movement.Dodge(M.V3.new(1, 0, 0)) == true and Movement.Action() == "Roll")
for _ = 1, 40 do M.step(1/30) end
-- combat animations (tools/anims via shared/Anims): a traced swing plays its body animation and stretches
-- each phase to the server's timing; hits, clashes, parries and the guard play theirs
local Assets = M.mockEnv.__require(RS.Shared.Assets)
local function playedId(name, from)
	local want = "rbxassetid://" .. tostring(Assets.Anims[name])
	for i = from + 1, #M.FireLog do local e = M.FireLog[i]; if e[1] == "AnimPlay" and e[2] == want then return true end end
	return false
end
local CE = RS.Remotes.CombatEvent
local mark = #M.FireLog
CE.OnClientEvent:Fire("Swing", char, "Light", "SlashR", 0.3, 0.2, 0.8, 6)
M.step(1/30)
check("anims: a traced swing plays its body animation", playedId("Swing_SlashR", mark))
for _ = 1, 9 do M.step(1/30) end -- into the strike
local Anims = M.mockEnv.__require(RS.Shared.Anims)
local track = Anims.Track(char, "Swing_SlashR")
check("anims: the strike phase is stretched to the server's Active", track and track.Speed and math.abs(track.Speed - 0.2 / 0.2) < 1e-6)
CE.OnClientEvent:Fire("Hit", char, 12, M.V3.new(1, 0.2, 0), M.V3.new(-1, 0, 0), nil)
M.step(1/30)
check("anims: a hit plays a reaction", playedId("Hit_Right", mark) or playedId("Hit_Left", mark) or playedId("Hit_Front", mark) or playedId("Hit_High", mark))
CE.OnClientEvent:Fire("Swing", char, "Light", "Overhead", 0.3, 0.2, 0.8, 6)
M.step(1/30)
CE.OnClientEvent:Fire("Clash", char, M.V3.new(0, 3, -2), nil)
M.step(1/30)
check("anims: a clash stops the swing and recoils", playedId("Recoil", mark) and not Anims.Track(char, "Swing_Overhead").IsPlaying)
CE.OnClientEvent:Fire("Parry", char)
CE.OnClientEvent:Fire("GuardBreak", char)
char:SetAttribute("Blocking", true)
M.step(1/30)
check("anims: parry, guard break and the guard play", playedId("Parry", mark) and playedId("Stagger", mark) and playedId("Block", mark))
-- the guard: with a weapon in hand the arms are driven (weapon across the front, off hand bracing it) and turn
-- toward an incoming swing; letting go of F relaxes them
do
	-- a small arm rig: the shoulders hang off the root, the arms are solved to the guard every step (client/ArmIK)
	local ArmIK = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.ArmIK)
	local function joint(name, at)
		local j = M.newInstance("Motor6D"); j.Name = name; j.C0 = M.CF.new(at); j.C1 = M.CF.new(); j.Transform = M.CF.new()
		j.Part0 = root; j.Parent = char; return j
	end
	local rs, ls = joint("RightShoulder", M.V3.new(0.86, 1.5, 0)), joint("LeftShoulder", M.V3.new(-0.86, 1.5, 0))
	local re = joint("RightElbow", M.V3.new(0, -1, 0)); joint("LeftElbow", M.V3.new(0, -1, 0))
	joint("RightWrist", M.V3.new(0, -0.9, 0)); joint("LeftWrist", M.V3.new(0, -0.9, 0))
	local held = M.newInstance("Model"); held.Name = "HeldWeapon"; held.Parent = char
	char:SetAttribute("Blocking", false)
	for _ = 1, 40 do M.step(1/30) end
	char:SetAttribute("Blocking", true)
	for _ = 1, 10 do M.step(1/30) end
	local DOWN = M.V3.new(0, -1, 0)
	local function angle(cf) return math.acos(math.clamp(cf:VectorToWorldSpace(DOWN):Dot(DOWN), -1, 1)) end -- how far the limb is lifted
	check("guard: the weapon arm is solved up into the guard", ArmIK.Active(char, "Right") and angle(rs.Transform) > 0.5)
	check("guard: the off hand comes up to brace it", ArmIK.Active(char, "Left") and angle(ls.Transform) > 0.5)
	check("guard: the elbow is bent, not locked", angle(re.Transform) > 0.3)
	-- an enemy winding up a slash off to the right: the guard swings toward it
	local foe = M.newInstance("Model"); foe.Name = "Foe"
	local froot = M.newInstance("Part"); froot.Name = "HumanoidRootPart"; froot.Parent = foe
	local fh = M.newInstance("Humanoid"); fh.Parent = foe
	froot.CFrame = M.CF.lookAt(root.Position + M.V3.new(5, 0, -3), root.Position)
	foe.Parent = workspace_
	local before = rs.Transform:VectorToWorldSpace(DOWN)
	CE.OnClientEvent:Fire("Swing", foe, "Light", "SlashL", 0.5, 0.2, 0.9, 6)
	for _ = 1, 8 do M.step(1/30) end
	check("guard: turns toward the blade coming in", (rs.Transform:VectorToWorldSpace(DOWN) - before).Magnitude > 0.05)
	-- the swing: the hand is put on the traced blade's grip, the elbow coiled in the wind-up
	char:SetAttribute("Blocking", false)
	for _ = 1, 12 do M.step(1/30) end
	check("guard: let go, the arms go back to the animation", not ArmIK.Active(char, "Right") and not ArmIK.Active(char, "Left"))
	CE.OnClientEvent:Fire("Swing", char, "Light", "SlashR", 0.3, 0.2, 0.8, 6)
	for _ = 1, 6 do M.step(1/30) end
	local coil = angle(re.Transform)
	check("swing: the arm is driven to the blade's grip", ArmIK.Active(char, "Right"))
	for _ = 1, 6 do M.step(1/30) end
	check("swing: coiled in the wind-up, thrown out in the strike", coil > angle(re.Transform) + 0.15)
	for _ = 1, 40 do M.step(1/30) end
	check("swing: after it the arm is handed back", not ArmIK.Active(char, "Right"))
	local S0, G0 = M.V3.new(0, 0, 0), M.V3.new(0, -1, -1)
	local E0 = ArmIK.Solve(S0, G0, 1, 0.9, M.V3.new(0.5, -0.7, 0.4))
	check("arm: the solved elbow keeps both bone lengths", math.abs((E0 - S0).Magnitude - 1) < 1e-3 and math.abs((G0 - E0).Magnitude - 0.9) < 1e-3)
	char:SetAttribute("Blocking", true)
	for _ = 1, 3 do M.step(1/30) end
	char:SetAttribute("Blocking", false)
	for _ = 1, 3 do M.step(1/30) end
	check("guard: released, the arms are let go", not Anims.Track(char, "Block").IsPlaying)
end
-- air: the smog follows where you stand (client/Air.lua)
do
	local Air = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Air)
	local MS = M.mockEnv.__require(RS.Shared.Megacity)
	local saved = root.CFrame
	root.CFrame = M.CF.new(0, 5, 0)
	for _ = 1, 20 do M.step(1/30) end
	check("air: the core breathes city air", Air.Current() == "City")
	root.CFrame = M.CF.new(MS.Pockets[1].Center.X, 5, MS.Pockets[1].Center.Z)
	for _ = 1, 20 do M.step(1/30) end
	check("air: a green pocket clears it", Air.Current() == "Clean")
	local slag = MS.GetDistrict("Slag")
	root.CFrame = M.CF.new(slag.Center.X, 5, slag.Center.Z)
	for _ = 1, 20 do M.step(1/30) end
	check("air: over the slag it turns toxic", Air.Current() == "Toxic")
	char:SetAttribute("Toxic", true)
	M.step(1/30)
	check("air: standing in sludge tints the screen", game_:GetService("Lighting"):FindFirstChild("ToxicGrade") ~= nil)
	char:SetAttribute("Toxic", false)
	root.CFrame = saved
	for _ = 1, 20 do M.step(1/30) end
end
-- handling (client/Handling.lua): stances on C / Space, and with a gun out RMB aims, V is the sights, R reloads
do
	local Handling = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Handling)
	local ConfigC = M.mockEnv.__require(RS.Shared.Config)
	local UIS = game_:GetService("UserInputService")
	local sent = {}
	for _, name in { "Stance", "Aim", "Reload", "Heavy", "UseSkill", "Attack" } do
		sent[name] = {}
		remotesFolder[name].OnServerEvent:Connect(function(_, a) table.insert(sent[name], a == nil and true or a) end)
	end
	local function last(name) return sent[name][#sent[name]] end
	local function down(key, kind) UIS.InputBegan:Fire({ KeyCode = key or "KeyCode.Unknown", UserInputType = kind or "UserInputType.Keyboard" }, false) end
	local function up(key, kind) UIS.InputEnded:Fire({ KeyCode = key or "KeyCode.Unknown", UserInputType = kind or "UserInputType.Keyboard" }, false) end
	local function wait(seconds) for _ = 1, math.ceil(seconds * 30) do M.step(1/30) end end
	char:SetAttribute("Weapon", "RebarBlade"); wait(0.1)
	local y0 = hum.CameraOffset.Y
	down("KeyCode.C"); wait(0.1); up("KeyCode.C"); wait(0.1)
	check("handling: a tap of C asks for a crouch", last("Stance") == "Crouch")
	char:SetAttribute("Stance", "Crouch"); char:SetAttribute("Crouched", true); wait(0.2)
	check("handling: crouched, the camera comes down", y0 - hum.CameraOffset.Y > 1)
	down("KeyCode.C"); wait(0.5)
	check("handling: holding C asks for prone", last("Stance") == "Prone")
	up("KeyCode.C"); wait(0.1)
	check("handling: letting go after the hold asks for nothing more", last("Stance") == "Prone")
	char:SetAttribute("Stance", "Prone"); wait(0.2)
	check("handling: prone, the camera is on the floor", y0 - hum.CameraOffset.Y > 2)
	down("KeyCode.Space"); wait(0.1)
	check("handling: Space comes up one stance, not a jump", last("Stance") == "Crouch")
	char:SetAttribute("Stance", "Stand"); char:SetAttribute("Crouched", false); wait(0.2)
	-- a blade out: the right button is the heavy attack, R is a skill
	local heavies = #sent.Heavy
	down(nil, "UserInputType.MouseButton2"); wait(0.1); up(nil, "UserInputType.MouseButton2")
	down("KeyCode.R"); wait(0.1)
	check("handling: with a blade RMB is the heavy and R a skill", #sent.Heavy == heavies + 1 and #sent.UseSkill >= 1 and #sent.Reload == 0 and not Handling.Aiming())
	-- the pistol out
	char:SetAttribute("Weapon", "Whisper"); wait(0.3)
	check("handling: the pistol is held at the ready", Anims.Track(char, "Pistol_Ready") ~= nil and Anims.Track(char, "Pistol_Ready").IsPlaying)
	heavies = #sent.Heavy
	local skills = #sent.UseSkill
	down(nil, "UserInputType.MouseButton2"); wait(0.3)
	check("handling: with a gun RMB aims (no heavy), in over the shoulder", Handling.Aiming() and last("Aim") == true and #sent.Heavy == heavies
		and math.abs(hum.CameraOffset.X - ConfigC.Stealth.Aim.ShoulderOffset.X) < 0.01 and Anims.Track(char, "Aim_Pistol").IsPlaying)
	down("KeyCode.V"); wait(0.2)
	check("handling: V goes down the sights", Handling.Sights() and player.CameraMaxZoomDistance == 0.5)
	down("KeyCode.R"); wait(0.1)
	check("handling: R changes the magazine, not a skill", #sent.Reload == 1 and #sent.UseSkill == skills)
	up(nil, "UserInputType.MouseButton2"); wait(0.3)
	check("handling: letting go lowers the gun and leaves the sights", not Handling.Aiming() and last("Aim") == false and not Handling.Sights() and player.CameraMaxZoomDistance > 1
		and not Anims.Track(char, "Aim_Pistol").IsPlaying)
	char:SetAttribute("Weapon", "Fists"); wait(0.2)
end
do -- the wounds seen from inside (shared/WoundFx): the body outline shows only while something is wrong
	local WoundFx = M.mockEnv.__require(RS.Shared.WoundFx)
	local el = WoundFx.Elements()
	local c = player.Character
	local function steps(n) for _ = 1, n do WoundFx.Step(c, os.clock(), 1 / 30) end end
	steps(40)
	check("woundfx: a whole body shows no outline", el.Body ~= nil and el.Body.Visible == false)
	c:SetAttribute("W_ArmL", 0.2); c:SetAttribute("Bleed_ArmL", "Heavy"); c:SetAttribute("Broken_LegR", true); c:SetAttribute("Pain", 0.6)
	steps(40)
	check("woundfx: a wound shows the outline, the hurt arm red, the break marked, pain blurs", el.Body.Visible == true
		and el.Boxes.ArmL.BackgroundColor3 ~= el.Boxes.Chest.BackgroundColor3 and el.Boxes.LegR.Break.Visible == true and el.Blur.Size > 1)
	for _, k in { "W_ArmL", "Bleed_ArmL", "Broken_LegR", "Pain" } do c:SetAttribute(k, nil) end
end
do -- client/Style: the quiet combo count, the lunge, the swap and quick-med keys
	local Style = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Style)
	local c = player.Character
	Style.Event("Hit", workspace_, 5, nil, nil, c); Style.Event("Hit", workspace_, 5, nil, nil, c)
	check("style: hits you land count up in the corner", Style.Count() >= 2)
	Style.Event("Lunge", M.V3.new(0, 0, -70), 0.2)
	check("style: a lunge pushes the body forward", c.HumanoidRootPart:FindFirstChild("LungeVelocity") ~= nil)
	local okKeys, keysErr = pcall(function()
		return Style.Began({ UserInputType = "UserInputType.Keyboard" }, "KeyCode.One") == true and Style.Began({ UserInputType = "UserInputType.Keyboard" }, "KeyCode.Two") == true
	end)
	if not okKeys then print("style keys error:", keysErr) end
	check("style: 1 and 2 are the swap and the quick dressing", okKeys and keysErr == true)
	-- round 3: the range under the dot while aiming a gun, tired arms, a hot barrel
	c:SetAttribute("Aiming", true); c:SetAttribute("Mag", 7); c:SetAttribute("ArmFatigue", 0.5); c:SetAttribute("Heat", 0.9)
	local okGun, gunErr = pcall(Style.Gun, 1 / 30)
	if not okGun then print("style gun error:", gunErr) end
	check("style: a gun aimed runs the range mark, the sway and the heat without error", okGun)
	for _, k in { "Aiming", "Mag", "ArmFatigue", "Heat" } do c:SetAttribute(k, nil) end
	Style.Gun(1 / 30)
end
-- round 4: the second before he shouts, a bolt, a locker, what a held guard says
do
	local StealthC = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Stealth)
	local c = player.Character
	local guard = M.newInstance("Model"); guard.Name = "G"
	local gr = M.newInstance("Part"); gr.Name = "HumanoidRootPart"; gr.Parent = guard
	guard.Parent = workspace_
	local ok, err = pcall(function()
		assert(StealthC.World("Reflex", guard, 1) == true)
		assert(StealthC.World("Clatter", M.V3.new(0, 1, 10), M.V3.new(0, 2, 0), 0.3) == true)
		assert(StealthC.World("Hide", c, gr, true) == true)
		assert(StealthC.World("Hide", c, gr, false, true) == true)
		assert(StealthC.World("Question", guard, "Two more on shift.", { guard }, gr, 5) == true)
	end)
	if not ok then print("stealth4 error:", err) end
	check("stealth4: the spotted flash, the clatter, the locker and the answer draw without error", ok)
	local okKey2, three = pcall(function()
		return M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Style).Began({ UserInputType = "UserInputType.Keyboard" }, "KeyCode.Three")
	end)
	check("stealth4: 3 throws a bolt", okKey2 and three == true)
	for _ = 1, 30 do M.step(1 / 30) end
end
-- builds (round 5): the loadout panel's rows and the open book readout
do
	local BuildC = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Build)
	local rows = {}
	local okRows, n = pcall(function()
		BuildC.Pack = { FocusChip = 1, DataShard = 2, Scrap = 4 }
		return BuildC.Rows({}, function(_, text) table.insert(rows, text) end, { Build = {
			Lineage = { Batch = 417, Stat = "Strength", Bonus = 2 }, Batch = "LINE 9 . BATCH 0417", Grade = "GRADE 4", Vow = "OPEN BOOK",
			Load = 5, LoadMax = 11, Active = "Quicken", Chips = { Surge = "FocusChip" }, Practice = { Endurance = 1, Reload = 0, Search = 2 },
			Carried = { Xp = 40, Credits = 25 }, Stack = { { Id = "DataShard", Count = 1 } }, StackSlots = 3 } })
	end)
	local text = table.concat(rows, "|")
	if not okRows then print("builds error:", n) end
	check("builds: the loadout shows the batch, grade, load, carried pay, chips and the stack", okRows and text:find("BATCH 0417", 1, true) ~= nil and text:find("CARRIED", 1, true) ~= nil
		and text:find("FOCUS CHIP", 1, true) ~= nil and text:find("[1] Data Shard", 1, true) ~= nil and text:find("Scrap", 1, true) == nil)
	local okStep = pcall(function()
		local c = player.Character
		if c then c:SetAttribute("Vow", "OpenBook") end
		for _ = 1, 10 do M.step(1 / 30) end
		if c then c:SetAttribute("Vow", nil) end
	end)
	check("builds: the open book readout runs without error", okStep and #M.errors == 0)
end
-- things you make (round 7): K held fires the arm, the cable pull, the companion and holding-frame rows
do
	local MakeC = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Make)
	local BuildC = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Build)
	BuildC.KDown = M.mockEnv.os.clock() - 1
	for _ = 1, 3 do M.step(1 / 30) end
	check("make: K held past the threshold fires the arm once", BuildC.ArmFired == true)
	BuildC.KDown, BuildC.ArmFired = nil, nil
	local World = game_:GetService("ReplicatedStorage").Remotes.World
	local okPull = pcall(function()
		World.OnClientEvent:Fire("Cable", player.Character.HumanoidRootPart.Position + M.V3.new(0, 0, -30))
		for _ = 1, 5 do M.step(1 / 30) end
		World.OnClientEvent:Fire("Sniff", {})
	end)
	check("make: the cable pulls this body", okPull and player.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 20)
	local rows = {}
	local okRows = pcall(function()
		MakeC.TerminalRows({}, function(_, text) table.insert(rows, text) end, { Thralls = { { Index = 1, Name = "UNIT 4471", Type = "Raider" } }, Invaders = 1 }, function() return function() end end)
	end)
	local text = table.concat(rows, "|")
	check("make: the computer lists the holding frame and who is out", okRows and text:find("UNIT 4471", 1, true) ~= nil and text:find("1 OUT", 1, true) ~= nil and #M.errors == 0)
end
-- world and money (round 6): the party list, the invite, the run clock, the computer's economy rows
do
	local BayC = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Bay)
	local World = game_:GetService("ReplicatedStorage").Remotes.World
	local okEv = pcall(function()
		World.OnClientEvent:Fire("Party", { player.UserId, 999 }, player.UserId)
		World.OnClientEvent:Fire("PartyInvite", 999, "Mate")
		World.OnClientEvent:Fire("Run", "Fuses", 420)
		for _ = 1, 12 do M.step(1 / 30) end
	end)
	check("bay: the party, the invite and the work-order clock draw", okEv and BayC.Elements ~= nil and BayC.Elements.Invite.Visible == true and BayC.Elements.Clock.Visible == true
		and BayC.Elements.Clock.Text:find("FUSES", 1, true) ~= nil)
	local rows = {}
	local okRows = pcall(function()
		BayC.Rows({}, function(_, text) table.insert(rows, text) end)
		BayC.TerminalRows({}, function(_, text) table.insert(rows, text) end, { Credits = 100, Apps = { RAIDS = true, HOUSE = true, MARKET = true }, Economy = {
			Loyalty = { Broker = 1, Fixer = 2, Dealer = 1 }, Swaps = { { Id = "A", Contact = "Fixer", Text = "10 Scrap for 6 Cloth" }, { Id = "B", Contact = "Dealer", Text = "x", Lock = 2 } },
			Board = { { Key = "1:1", Seller = "Mate", Name = "Splint", Count = 2, Price = 50 } }, Mine = {}, Found = { { Id = "Splint", Name = "Splint", Count = 1, Value = 25 } },
			Slots = 2, Rep = 0, Mults = { 1, 1.5, 2 }, Fee = 0.1, Drop = { Price = 250, Wait = 0 } } }, function() return function() end end)
	end)
	local text = table.concat(rows, "|")
	check("bay: the loadout answers the invite; the computer shows trust, swaps, the exchange and the drop", okRows and text:find("Mate asks you to join", 1, true) ~= nil
		and text:find("TRUST", 1, true) ~= nil and text:find("EXCHANGE", 1, true) ~= nil and text:find("LINE 9 DROP", 1, true) ~= nil and text:find("found: Splint", 1, true) ~= nil)
	World.OnClientEvent:Fire("Run", nil)
	for _ = 1, 5 do M.step(1 / 30) end
	check("bay: the clock goes when the order closes", BayC.Elements and BayC.Elements.Clock.Visible == false and #M.errors == 0)
end
-- the Front's gun handling on Endeavor's guns (client/GunFeel.lua) and jointed fingers on every body (client/Hands.lua)
do
	local Hd = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Handling)
	local GF, HandsC = Hd.GunFeel, Hd.Hands
	local Config = M.mockEnv.__require(RS.Shared.Config)
	local HP = M.mockEnv.__require(RS.Shared.HandParts)
	local Combat = RS.Remotes.CombatEvent
	char = player.Character
	char:SetAttribute("Weapon", "DutyPistol"); char:SetAttribute("Mag", 15); char:SetAttribute("MagSize", 15)
	local hand = char:FindFirstChild("RightHand") or M.newInstance("Part"); hand.Name = "RightHand"; hand.Size = M.V3.new(0.28, 0.56, 0.35); hand.Parent = char
	local lhand = char:FindFirstChild("LeftHand") or M.newInstance("Part"); lhand.Name = "LeftHand"; lhand.Size = M.V3.new(0.28, 0.56, 0.35); lhand.CFrame = M.CF.new(-1, 3, 0); lhand.Parent = char
	for _, n in { "LeftUpperArm", "RightUpperArm" } do
		if not char:FindFirstChild(n) then local p = M.newInstance("Part"); p.Name = n; p.Parent = char end
	end
	while char:FindFirstChild("HeldWeapon") do char.HeldWeapon:Destroy() end -- an earlier check's gun
	-- a whole pistol as HeldWeapons leaves it: authored barrel +Y, grip down -Z, every part welded to the first
	local held = M.newInstance("Model"); held.Name = "HeldWeapon"; held:SetAttribute("WeaponId", "DutyPistol"); held:SetAttribute("Build", "")
	local frame = M.newInstance("Part"); frame.Name = "Frame_Polymer"; frame.Size = M.V3.new(0.25, 1.4, 0.9); frame.CFrame = M.CF.new(); frame.Parent = held
	local grip = M.newInstance("Weld"); grip.Name = "Grip"; grip.Part0, grip.Part1 = hand, frame; grip.C0 = M.CF.new(0, -0.1, 0) * M.CF.Angles(-math.pi / 2, 0, 0); grip.C1 = M.CF.new(); grip.Parent = frame
	local welds = {}
	for name, v in { Slide_Gunmetal = { M.V3.new(0.24, 1.5, 0.25), M.V3.new(0, 0.2, 0.35) }, Magazine_Polymer = { M.V3.new(0.18, 0.2, 0.8), M.V3.new(0, -0.3, -0.5) },
		Trigger_Polymer = { M.V3.new(0.05, 0.08, 0.12), M.V3.new(0, 0.1, -0.1) } } do
		local p = M.newInstance("Part"); p.Name = name; p.Size = v[1]; p.CFrame = M.CF.new(v[2].X, v[2].Y, v[2].Z); p.Parent = held
		local w = M.newInstance("Weld"); w.Part0, w.Part1 = frame, p; w.C0 = p.CFrame; w.Parent = p
		welds[string.split(name, "_")[1]] = w
	end
	held.PrimaryPart = frame
	held.Parent = char
	for _ = 1, 20 do M.step(1 / 30) end
	local st = GF.State()
	local g = st.Guns[char]

	check("gunfeel: the gun in the hand is measured: its slide, magazine and trigger move on their own", g ~= nil and g.Shape.Action == "Slide" and g.Moving.Magazine ~= nil and g.Moving.Trigger ~= nil)
	local base = welds.Slide.C0
	local muzzle = GF.Shot(char)
	M.step(1 / 60); M.step(1 / 60)
	local cycled = (welds.Slide.C0.Position - base.Position).Magnitude > 0.05
	for _ = 1, 30 do M.step(1 / 30) end
	check("gunfeel: a shot cycles the slide, flashes at the muzzle and throws a case", muzzle ~= nil and cycled and #st.Casings >= 1)
	check("gunfeel: the slide comes home", (welds.Slide.C0.Position - base.Position).Magnitude < 1e-3)
	local magBase = welds.Magazine.C0
	local shown = GF.Reload(char, 1.8)
	for _ = 1, 9 do M.step(1 / 30) end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local ik = hum and hum:FindFirstChild("GunFeelLeft")
	check("gunfeel: a reload strips the magazine out with the off hand on it", shown == true and (welds.Magazine.C0.Position - magBase.Position).Magnitude > 0.05 and ik ~= nil and ik.Enabled == true)
	for _ = 1, 80 do M.step(1 / 30) end
	check("gunfeel: the magazine is driven home and the hand lets go", (welds.Magazine.C0.Position - magBase.Position).Magnitude < 1e-3 and ik.Enabled == false and #M.errors == 0)
	char:SetAttribute("Mag", 0)
	GF.Shot(char)
	for _ = 1, 20 do M.step(1 / 30) end
	check("gunfeel: on the last round the slide stays back", (welds.Slide.C0.Position - base.Position).Magnitude > 0.05)
	char:SetAttribute("Mag", 15)
	-- a hand-racked gun: the shot leaves its case in, the rack throws it
	char:SetAttribute("Weapon", "Whisper"); held:SetAttribute("WeaponId", "Whisper")
	for _ = 1, 20 do M.step(1 / 30) end
	g = st.Guns[char]
	local before = st.Casings[#st.Casings]
	GF.Shot(char)
	for _ = 1, 10 do M.step(1 / 30) end
	local kept = st.Casings[#st.Casings] == before
	Combat.OnClientEvent:Fire("Rack", char, 0.55)
	for _ = 1, 25 do M.step(1 / 30) end
	check("gunfeel: the Whisper keeps its case until it is racked, then throws it", g ~= nil and g.Shape.Manual == true and kept and st.Casings[#st.Casings] ~= before)
	-- the fingers: the pieces the server leaves, the body's mitten hands hidden, a jointed hand on each wrist
	local viewHands = M.newInstance("Folder"); viewHands.Name = "ViewHands"
	for piece in HP.Centres do
		for _, mat in { "Flesh", "HideLeather", "PlateSteel" } do
			local p = M.newInstance("Part"); p.Name = piece .. "_" .. mat; p.Size = M.V3.new(0.05, 0.1, 0.05); p.Parent = viewHands
		end
	end
	viewHands.Parent = RS
	local skin = M.newInstance("Model"); skin.Name = "Skin"
	local mitts = M.newInstance("Part"); mitts.Name = "Hands_HideLeather"; mitts.Transparency = 0; mitts.Color = M.mockEnv.Color3.fromRGB(158, 148, 140); mitts.Parent = skin
	skin.Parent = char
	for _ = 1, 30 do M.step(1 / 30) end
	local hs = HandsC.State()
	local b = hs.Bodies[char]
	local count = 0
	if b and b.Sides.Right then for _ in b.Sides.Right.Parts do count += 1 end end
	check("hands: the body's mittens are hidden and a jointed hand is on each wrist", b ~= nil and b.Sides.Right ~= nil and b.Sides.Left ~= nil and count == 17 and mitts.LocalTransparencyModifier == 1
		and b.Sides.Right.Model.Parent == cam)
	check("hands: the pieces are the body's own material and colour", b ~= nil and b.Sides.Right.Parts.Palm.Name == "Palm_HideLeather" and b.Sides.Right.Parts.Palm.Color == mitts.Color)
	local function curl(p, name) return p[name][2] + p[name][3] + p[name][4] end
	local relax, fist, grip = HandsC.Hold("Open", 1), HandsC.Hold("Fist", 1), HandsC.Hold("Grip", 1)
	local wide = HandsC.Hold("Haft", 1)
	check("hands: a fist closes tighter than a sword grip, and a haft is wider still", curl(fist, "Middle") > curl(grip, "Middle") and curl(grip, "Middle") > curl(wide, "Middle") and curl(wide, "Middle") > curl(relax, "Middle"))
	local off, on = HandsC.Hold("Pistol", 1, false), HandsC.Hold("Pistol", 1, true)
	check("hands: the firing finger lies along the frame until the gun is aimed", curl(on, "Index") > curl(off, "Index") + 20 and curl(off, "Middle") > 60)
	char:SetAttribute("Aiming", true)
	for _ = 1, 10 do M.step(1 / 30) end
	check("hands: aiming puts the right hand's finger on the trigger", b.Sides.Right.Goal == on)
	char:SetAttribute("Aiming", nil)
	-- a melee weapon: the right hand round its grip
	held:Destroy()
	char:SetAttribute("Weapon", "RebarBlade")
	local blade = M.newInstance("Model"); blade.Name = "HeldWeapon"; blade:SetAttribute("WeaponId", "RebarBlade")
	local bp = M.newInstance("Part"); bp.Name = "Blade_Steel"; bp.Parent = blade
	local bg = M.newInstance("Weld"); bg.Name = "Grip"; bg.Part0, bg.Part1 = hand, bp; bg.C1 = M.CF.new(); bg.Parent = bp
	blade.PrimaryPart = bp
	blade.Parent = char
	for _ = 1, 10 do M.step(1 / 30) end
	check("hands: a blade in the hand is gripped, the empty off hand hangs open", b.Sides.Right.Goal == grip and b.Sides.Left.Goal == HandsC.Hold("Open", -1) and #M.errors == 0)
	blade:Destroy()
	char:SetAttribute("Weapon", "Fists")
	for _ = 1, 10 do M.step(1 / 30) end
	check("hands: fists are closed", b.Sides.Right.Goal == fist and b.Sides.Left.Goal == HandsC.Hold("Fist", -1))
	skin:Destroy()
	for _ = 1, 30 do M.step(1 / 30) end
	check("hands: a body that loses its skin loses the jointed hands", HandsC.State().Bodies[char] == nil and #M.errors == 0)
end
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
