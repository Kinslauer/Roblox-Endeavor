-- Runs the Front client against the mock with a fake LocalPlayer, then plays the first link's stages
-- (stasis tank to the drop) through it the way the server sends them. Catches errors in the client's
-- setup and in every stage handler.
CLIENT_MODE = true
local game_, workspace_ = M.game, M.workspace
local RS = game_:GetService("ReplicatedStorage")
local Players = game_:GetService("Players")
local Lighting = game_:GetService("Lighting")
M.mkTree({ Shared = { class = "Folder", children = TREE_SHARED } }, RS)
local remotesFolder = M.newInstance("Folder"); remotesFolder.Name = "Remotes"; remotesFolder.Parent = RS
local src = TREE_SHARED.Remotes.source
for name in src:gmatch('"(%a+)"') do if name ~= "Remotes" and name ~= "Folder" and name ~= "RemoteEvent" then local r = M.newInstance("RemoteEvent"); r.Name = name; r.Parent = remotesFolder end end
local player = M.newInstance("Player"); player.Name, player.DisplayName, player.UserId = "Tester", "Tester", 1
local pg = M.newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = player
player.Parent = Players; Players.LocalPlayer = player
local cam = M.newInstance("Camera"); cam.Name = "CurrentCamera"; cam.CFrame = M.CF.new(0, 5, 0); cam.FieldOfView = 70; cam.Parent = workspace_
Lighting.ClockTime, Lighting.Brightness, Lighting.FogEnd = 7.5, 1.5, 900
M.mkTree({ Client = { class = "Folder", children = TREE_WAR_CLIENT } }, game_:GetService("StarterPlayer"))
local client = game_:GetService("StarterPlayer").Client.Main
local function check(label, ok) print((ok and "PASS  " or "FAIL  ") .. label) end
local ok, err = pcall(function() M.loadSource(client)() end)
check("front client boots", ok)
if not ok then print(err) end
local function run(seconds) for _ = 1, math.floor(seconds * 30) do M.step(1 / 30) end end
run(1)
-- a recruit in a tank
local char = M.newInstance("Model"); char.Name = "Tester"
local root = M.newInstance("Part"); root.Name = "HumanoidRootPart"; root.CFrame = M.CF.new(0, 1505, -8); root.Parent = char
local head = M.newInstance("Part"); head.Name = "Head"; head.CFrame = M.CF.new(0, 1507, -8); head.Parent = char
local hum = M.newInstance("Humanoid"); hum.Name = "Humanoid"; hum.WalkSpeed = 0; hum.Parent = char
hum.Health, hum.MaxHealth = 100, 100
char.Parent = workspace_
player.Character = char
player.CharacterAdded:Fire(char)
run(0.5)
local fluid = M.newInstance("Part"); fluid.Name = "TankFluid"; fluid.Size = M.V3.new(10.6, 7, 7); fluid.CFrame = M.CF.new(0, 1505.4, -8); fluid.Parent = workspace_
local IntroFx = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.IntroFx)
local T = RS.Remotes.Tutorial
local hudGui = pg:FindFirstChild("FrontHUD")
T.OnClientEvent:Fire("Front", "Wake", { Seconds = 4, Fluid = fluid, Tank = M.V3.new(0, 1500, -8), Recruit = 7, Faction = "Union" })
run(0.3)
check("intro client: the wake hides the HUD and takes the camera", IntroFx.Active == true and hudGui.Enabled == false and tostring(cam.CameraType):find("Scriptable") ~= nil)
check("intro client: the tank is lit on this client only", Lighting:FindFirstChild("IntroGrade") ~= nil and Lighting:FindFirstChild("IntroBlur") ~= nil)
run(7)
check("intro client: after the sync the eyes are handed back", tostring(cam.CameraType):find("Custom") ~= nil)
for _, stage in { "Drain", "Unlatch", "Chute" } do T.OnClientEvent:Fire("Front", stage, { Seconds = 1 }); run(0.4) end
T.OnClientEvent:Fire("Front", "Barracks", { Taken = 0, Total = 5 }); run(0.2)
check("intro client: the HUD comes back in the barracks", hudGui.Enabled == true)
T.OnClientEvent:Fire("Front", "Equip", { Taken = 3, Total = 5 }); run(0.8)
local line
for _, d in pg:GetDescendants() do if d.ClassName == "TextLabel" and type(d.Text) == "string" and d.Text:find("SUPPLY") then line = d.Text end end
check("intro client: supply count as machine text", line ~= nil and line:find("3/5") ~= nil)
for _, stage in { "Equipped", "Link", "Sim" } do T.OnClientEvent:Fire("Front", stage, { Seconds = 1 }); run(1.2) end
check("intro client: the simulation darkens the world", Lighting.ClockTime == 0 and Lighting:FindFirstChild("IntroSky") ~= nil)
T.OnClientEvent:Fire("Front", "Drill", { Index = 2, Total = 5, Name = "BREACH", Keys = "G", Done = 1, Need = 3 }); run(1)
for _, d in pg:GetDescendants() do if d.ClassName == "TextLabel" and type(d.Text) == "string" and d.Text:find("DRILL") then line = d.Text end end
check("intro client: drill line", line ~= nil and line:find("BREACH") ~= nil and line:find("1/3") ~= nil)
RS.Remotes.World.OnClientEvent:Fire("SimBreak", M.V3.new(0, 1503, 200), 6, false); run(0.1)
local shards = 0 for _, d in workspace_:GetChildren() do if d.Name == "SimShard" then shards += 1 end end
check("intro client: a broken block shatters into shards", shards >= 3)
for _, stage in { "DrillDone", "Desync", "SimDone", "Done" } do T.OnClientEvent:Fire("Front", stage, { Name = "BREACH", Seconds = 1 }); run(0.5) end
T.OnClientEvent:Fire("Front", "Landed", {}); run(0.5)
check("intro client: landing restores the Front's light and the HUD", IntroFx.Active == false and Lighting.ClockTime == 7.5 and Lighting.FogEnd == 900 and Lighting:FindFirstChild("IntroGrade") == nil and Lighting:FindFirstChild("IntroSky") == nil and hudGui.Enabled == true)
check("no client errors", #M.errors == 0)
for _, e in M.errors do print(e) end
