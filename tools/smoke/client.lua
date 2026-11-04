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
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
