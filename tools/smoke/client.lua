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
print("errors:", #M.errors)
for _, e in M.errors do print(e) end
