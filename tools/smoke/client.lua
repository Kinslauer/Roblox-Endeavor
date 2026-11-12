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
	local function joint(name) local j = M.newInstance("Motor6D"); j.Name = name; j.C0 = M.CF.new(); j.Parent = char; return j end
	local rs, ls, rw = joint("RightShoulder"), joint("LeftShoulder"), joint("RightWrist")
	joint("RightElbow"); joint("LeftElbow")
	local held = M.newInstance("Model"); held.Name = "HeldWeapon"; held.Parent = char
	char:SetAttribute("Blocking", false); M.step(1/30)
	char:SetAttribute("Blocking", true)
	for _ = 1, 10 do M.step(1/30) end
	local DOWN = M.V3.new(0, -1, 0)
	local function angle(cf) return math.acos(math.clamp(cf:VectorToWorldSpace(DOWN):Dot(DOWN), -1, 1)) end -- how far the limb is lifted
	check("guard: the weapon arm is raised into the guard", angle(rs.C0) > 0.5)
	check("guard: the off hand comes up to brace it", angle(ls.C0) > 0.5)
	-- an enemy winding up a slash off to the right: the guard swings toward it
	local foe = M.newInstance("Model"); foe.Name = "Foe"
	local froot = M.newInstance("Part"); froot.Name = "HumanoidRootPart"; froot.Parent = foe
	local fh = M.newInstance("Humanoid"); fh.Parent = foe
	froot.CFrame = M.CF.lookAt(root.Position + M.V3.new(5, 0, -3), root.Position)
	foe.Parent = workspace_
	local before = rs.C0:VectorToWorldSpace(DOWN)
	CE.OnClientEvent:Fire("Swing", foe, "Light", "SlashL", 0.5, 0.2, 0.9, 6)
	for _ = 1, 8 do M.step(1/30) end
	check("guard: turns toward the blade coming in", (rs.C0:VectorToWorldSpace(DOWN) - before).Magnitude > 0.05)
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
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
