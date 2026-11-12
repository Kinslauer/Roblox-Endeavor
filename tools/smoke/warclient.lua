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
local cam = M.newInstance("Camera"); cam.ViewportSize = { X = 1280, Y = 720 }; cam.Name = "CurrentCamera"; cam.CFrame = M.CF.new(0, 5, 0); cam.FieldOfView = 70; cam.Parent = workspace_
Lighting.ClockTime, Lighting.Brightness, Lighting.FogEnd = 7.5, 1.5, 900
M.mkTree({ Client = { class = "Folder", children = TREE_WAR_CLIENT } }, game_:GetService("StarterPlayer"))
local client = game_:GetService("StarterPlayer").Client.Main
local Config = M.mockEnv.__require(RS.Shared.Config)
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
hum.CameraOffset = M.V3.new(0, 0, 0)
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
-- the screen and the controls (2026-11-11)
do
	local UIS = game_:GetService("UserInputService")
	local Enum_ = M.mockEnv.Enum
	local sent = {}
	for _, name in { "Stance", "Reload", "Lean", "Mark", "FieldMod", "Switch" } do
		RS.Remotes[name].OnServerEvent:Connect(function(_, a) table.insert(sent, { name, a }) end)
	end
	local function last(name) for i = #sent, 1, -1 do if sent[i][1] == name then return sent[i][2] end end return nil end
	local function count(name) local n = 0 for _, e in sent do if e[1] == name then n += 1 end end return n end
	local function down(key) UIS.InputBegan:Fire({ KeyCode = Enum_.KeyCode[key], UserInputType = Enum_.UserInputType.Keyboard }, false) end
	local function up(key) UIS.InputEnded:Fire({ KeyCode = Enum_.KeyCode[key], UserInputType = Enum_.UserInputType.Keyboard }, false) end
	local Hud = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.Hud)
	local el = Hud.Elements
	hum.WalkSpeed = 14
	RS.Remotes.Weapon.OnClientEvent:Fire("State", { Id = "AKM", Name = "AKM", Mode = "Auto", Chamber = true, BoltOpen = false, Jammed = false, Reloading = false, Mag = 24, MagSize = 30, Spare = 3,
		Parts = { Receiver = 90, Barrel = 80, Bolt = 70, Magazine = 60, Stock = 50 }, Attachments = {}, Busy = 0, Zoom = 1 }, "Primary", { Grenades = 2, Medkits = 1, Sandbags = 4 })
	run(0.2)
	local longest = 0
	for _, d in hudGui:GetDescendants() do if d.ClassName == "TextLabel" and d.Visible ~= false and type(d.Text) == "string" and (d.TextTransparency or 0) < 1 then longest = math.max(longest, #d.Text) end end
	check("screen: rounds as one number, nothing wordy", el.Rounds.Text == "24" and el.Mode.Text == "AUTO" and el.Grenades.Text == "2" and el.Status.Text == "" and longest <= 12)
	check("screen: the gun's parts stay hidden until the weapon is checked", el.Check.Visible == false)
	down("Y"); run(0.1)
	local shown = el.Check.Visible
	up("Y"); run(0.1)
	check("screen: Y held looks the weapon over", shown == true and el.Check.Visible == false)
	down("C"); run(0.1); up("C"); run(0.1)
	check("controls: a tap on C asks for a crouch", last("Stance") == "Crouch")
	char:SetAttribute("Stance", "Crouch"); run(0.3)
	check("controls: crouched is slower and the screen shows it", hum.WalkSpeed == Config.WarMovement.Stance.Crouch.Speed and el.StanceName == "Crouch")
	down("C"); run(0.6); up("C"); run(0.1)
	check("controls: holding C asks for prone (and the release adds nothing)", last("Stance") == "Prone" and count("Stance") == 2)
	char:SetAttribute("Stance", "Prone"); run(0.6)
	check("controls: prone crawls with the eye near the ground", hum.WalkSpeed == Config.WarMovement.Stance.Prone.Speed and hum.CameraOffset.Y < -1.2)
	down("E"); run(0.1); up("E")
	check("controls: Q / E while prone rolls instead of leaning", last("Lean") == nil)
	down("Space"); run(0.1); up("Space")
	check("controls: Space comes up one stance", last("Stance") == "Crouch")
	char:SetAttribute("Stance", "Stand"); run(0.3)
	down("E"); run(0.1)
	local leaned = last("Lean")
	up("E"); run(0.1)
	check("controls: E leans and letting go straightens", leaned == 1 and last("Lean") == 0)
	down("R"); run(0.1); up("R"); run(0.1)
	local quick = last("Reload")
	down("R"); run(0.6); up("R"); run(0.1)
	check("controls: R taps a quick reload, holding R keeps the magazine", quick == false and last("Reload") == true and count("Reload") == 2)
	down("Z"); run(0.3)
	local glass = el.Binos.Visible
	up("Z"); run(0.3)
	check("controls: Z raises the binoculars", glass == true and el.Binos.Visible == false)
	local enemy = M.newInstance("Model"); enemy.Name = "Enemy"
	local eh = M.newInstance("Part"); eh.Name = "Head"; eh.Parent = enemy
	enemy.Parent = workspace_
	RS.Remotes.Soldier.OnClientEvent:Fire("Marked", enemy, 9); run(0.1)
	check("screen: a marked figure wears a mark", Hud.Marked(enemy) == true and pg:FindFirstChild("Mark") ~= nil)
	run(9.5)
	check("screen: the mark fades", Hud.Marked(enemy) == false)
	-- the fitted parts: hold Y, 1-4 change a slot
	RS.Remotes.Weapon.OnClientEvent:Fire("State", { Id = "AKM", Name = "AKM", Mode = "Auto", Chamber = true, BoltOpen = false, Jammed = false, Reloading = false, Mag = 24, MagSize = 30, Spare = 3,
		Parts = { Receiver = 90, Barrel = 80, Bolt = 70, Magazine = 60, Stock = 50 }, Attachments = { Muzzle = { Id = "Suppressor", Condition = 100 } }, Busy = 0, Zoom = 1 }, "Primary",
		{ Grenades = 2, Medkits = 1, Sandbags = 4, Spares = { { Id = "PSO", Condition = 100 } } })
	run(0.1)
	local before = count("Switch")
	down("Y") run(0.1)
	check("parts: the checked weapon lists what is fitted, short and plain", el.Fit.Visible == true and el.Fit:FindFirstChildWhichIsA("TextLabel") ~= nil)
	down("Two") up("Two") run(0.1)
	check("parts: Y and 2 fits the carried scope", last("FieldMod") == "Optic" and count("Switch") == before)
	down("Three") up("Three") run(0.1)
	check("parts: Y and 3 with no spare takes the suppressor off", last("FieldMod") == "Muzzle")
	up("Y") run(0.1)
	down("Two") up("Two") run(0.1)
	check("parts: without Y, 2 still switches weapon", count("Switch") == before + 1 and el.Fit.Visible == false)
end
-- the gun in the view (2026-11-12): it floats, kicks on springs, and the round follows the bore
do
	local ViewGun = M.mockEnv.__require(game_:GetService("StarterPlayer").Client.ViewGun)
	local UIS = game_:GetService("UserInputService")
	local held = M.newInstance("Model"); held.Name = "HeldWeapon"
	held:SetAttribute("WeaponId", "AKM"); held:SetAttribute("Build", "Standard|||")
	local hand = M.newInstance("Part"); hand.Name = "RightHand"; hand.Parent = char
	local left = M.newInstance("Part"); left.Name = "LeftHand"; left.Parent = char
	local body = M.newInstance("Part"); body.Name = "Receiver"; body.Size = M.V3.new(0.2, 0.4, 2.2); body.CFrame = M.CF.new(0, 1500, 1.1); body.Parent = held
	local scope = M.newInstance("Part"); scope.Name = "Scope"; scope.Size = M.V3.new(0.2, 0.2, 0.6); scope.CFrame = M.CF.new(0, 1500.4, 0.3); scope:SetAttribute("Component", "Optic"); scope.Parent = held
	local grip = M.newInstance("Weld"); grip.Name = "Grip"; grip.C0 = M.CF.new(0, -0.1, -0.3); grip.C1 = M.CF.new(0, 0, 1.1); grip.Part0, grip.Part1 = hand, body; grip.Parent = body
	for name, v in { Carrier_Gunmetal = { M.V3.new(0.1, 0.1, 0.6), M.V3.new(0, 0.1, 0.9) }, Charging_Gunmetal = { M.V3.new(0.1, 0.04, 0.5), M.V3.new(0, 0.17, 0.6) },
		Magazine_Polymer = { M.V3.new(0.1, 0.5, 0.2), M.V3.new(0, -0.4, 1.0) } } do
		local p = M.newInstance("Part"); p.Name = name; p.Size = v[1]; p.CFrame = M.CF.new(0, 1500, 0) * M.CF.new(v[2].X, v[2].Y, v[2].Z); p.Parent = held
	end
	held.PrimaryPart = body
	held.Parent = char
	local sentDir
	RS.Remotes.Fire.OnServerEvent:Connect(function(_, d) sentDir = d end)
	cam.CameraType = M.mockEnv.Enum.CameraType.Custom
	run(0.5)
	local st = ViewGun.State()
	check("view gun: a copy of the held gun flies in front of the camera", ViewGun.Shown() and st.Gun ~= nil and st.Gun.Model.Parent == cam and st.Gun.Model ~= held)
	check("view gun: the one in the fist is hidden from its owner", body.LocalTransparencyModifier == 1)
	local dir = ViewGun.Direction()
	check("view gun: at rest the bore looks where the camera looks", dir ~= nil and dir:Dot(cam.CFrame.LookVector) > 0.99)
	-- a shot kicks the gun and the camera, and both come back
	RS.Remotes.Weapon.OnClientEvent:Fire("Recoil", 2, 1); run(1 / 30)
	st = ViewGun.State()
	local kicked = st.Kick.Magnitude > 0.5 and st.Punch.Magnitude > 0.1
	run(3)
	st = ViewGun.State()
	check("view gun: a shot kicks the gun and the camera on springs", kicked)
	check("view gun: the kick settles by itself", st.Kick.Magnitude < 0.05 and st.Punch.Magnitude < 0.05)
	-- turning leaves the gun behind for a moment, and the round goes where the gun points
	cam.CFrame = M.CF.new(0, 5, 0) * M.CF.Angles(0, math.rad(30), 0); run(1 / 30)
	st = ViewGun.State()
	local trailed = st.Lag.Magnitude > 0.5 and st.Lag.Magnitude <= Config.WarMovement.ViewGun.Lag.Hip + 0.01
	local offBore = ViewGun.Direction():Dot(cam.CFrame.LookVector) < 0.9999
	UIS.InputBegan:Fire({ UserInputType = M.mockEnv.Enum.UserInputType.MouseButton1, KeyCode = M.mockEnv.Enum.KeyCode.Unknown }, false)
	UIS.InputEnded:Fire({ UserInputType = M.mockEnv.Enum.UserInputType.MouseButton1, KeyCode = M.mockEnv.Enum.KeyCode.Unknown }, false)
	run(1 / 30)
	check("view gun: the gun trails a turn, inside its limit", trailed and offBore)
	check("view gun: the round is sent along the bore, not the camera", sentDir ~= nil and sentDir:Dot(cam.CFrame.LookVector) < 0.9999 and sentDir:Dot(cam.CFrame.LookVector) > 0.98)
	run(2)
	check("view gun: it catches up with the view", ViewGun.State().Lag.Magnitude < 0.05)
	-- at the sights the scope's housing fades (both eyes open)
	local copyScope
	for _, d in ViewGun.State().Gun.Model:GetDescendants() do if d.Name == "Scope" then copyScope = d end end
	UIS.InputBegan:Fire({ UserInputType = M.mockEnv.Enum.UserInputType.MouseButton2, KeyCode = M.mockEnv.Enum.KeyCode.Unknown }, false); run(1)
	local sg = ViewGun.State()
	local frame = sg.View * M.CF.Angles(0, math.pi, 0)
	local sightAt = cam.CFrame:PointToObjectSpace(frame:PointToWorldSpace(sg.Gun.Sight))
	local gripAt = cam.CFrame:PointToObjectSpace(frame:PointToWorldSpace(sg.Gun.GripAt))
	check("view gun: at the sights the scope fades and its line runs through the eye", copyScope ~= nil and copyScope.Transparency > 0.5 and sg.Aim > 0.95
		and math.abs(sightAt.X) < 0.03 and math.abs(sightAt.Y) < 0.03)
	check("view gun: aimed, the firing hand is an arm's bend ahead of the eye and below the sights", math.abs(gripAt.Z + Config.WarMovement.ViewGun.Rifle.Grip) < 0.05 and gripAt.Y < -0.2)
	UIS.InputEnded:Fire({ UserInputType = M.mockEnv.Enum.UserInputType.MouseButton2, KeyCode = M.mockEnv.Enum.KeyCode.Unknown }, false); run(1)
	check("view gun: lowered again the scope is solid", copyScope.Transparency < 0.05)
	-- animation made by code (2026-11-12): the gun's own pieces move, the off hand works them
	do
		local g = ViewGun.State().Gun
		local function at(name) -- a piece of the copy, in the gun's own frame
			local frame = ViewGun.State().View * M.CF.Angles(0, math.pi, 0)
			for _, d in g.Model:GetDescendants() do
				if d.Name == name then return frame:PointToObjectSpace(d.Position) end
			end
		end
		local function leftAt()
			return (g.AnchorRel * g.Left.CFrame).Position
		end
		local function state(over)
			local w = { Id = "AKM", Name = "AKM", Mode = "Auto", Chamber = true, BoltOpen = false, Jammed = false, Reloading = false, Mag = 24, MagSize = 30, Spare = 3,
				Parts = { Receiver = 90, Barrel = 80, Bolt = 70, Magazine = 60, Stock = 50 }, Attachments = {}, Busy = 0, Zoom = 1 }
			for k, v in over or {} do w[k] = v end
			if w.NoMag then w.Mag = nil end
			RS.Remotes.Weapon.OnClientEvent:Fire("State", w, "Primary", { Grenades = 2, Medkits = 1, Sandbags = 4 })
		end
		state(); run(1)
		local home, magHome = at("Carrier_Gunmetal"), at("Magazine_Polymer")
		check("gun motion: at rest every piece is where it was built", g.Motion ~= nil and math.abs(home.Z - 0.9) < 0.01 and math.abs(magHome.Y + 0.4) < 0.01
			and (leftAt() - g.LeftRest).Magnitude < 0.01)
		RS.Remotes.Weapon.OnClientEvent:Fire("Recoil", 1, 0.5); run(1 / 30)
		local thrown = at("Carrier_Gunmetal")
		local case = cam:FindFirstChild("Case")
		run(0.5)
		check("gun motion: a shot throws the carrier back and it runs home", thrown.Z < home.Z - 0.1 and math.abs(at("Carrier_Gunmetal").Z - home.Z) < 0.005)
		check("gun motion: a shot throws a case out of the port", case ~= nil)
		run(3)
		check("gun motion: the case is cleared away", cam:FindFirstChild("Case") == nil)
		state({ Chamber = false, BoltOpen = true, Mag = 0 }); run(0.4)
		check("gun motion: on the last round the action stays back", at("Carrier_Gunmetal").Z < home.Z - 0.25)
		-- the magazine is worked a step at a time (2026-11-12): out, in, and the action by its own key
		local function shownT(name)
			for _, d in g.Model:GetDescendants() do
				if d.Name == name then return d.Transparency end
			end
		end
		state({ Chamber = false, BoltOpen = true, NoMag = true, Reloading = true, Step = "Out", StepKeep = true, Busy = 0.6 }); run(0.36)
		local out, handOut = at("Magazine_Polymer"), leftAt()
		check("gun motion: kept, the magazine is pulled down out of the gun with the off hand on it", out.Y < magHome.Y - 0.15
			and (handOut - (out + M.V3.new(0, -0.25, 0))).Magnitude < 0.25 and g.Motion:Playing("MagOut"))
		state({ Chamber = false, BoltOpen = true, NoMag = true }); run(0.8)
		check("gun motion: with the magazine out the well is empty, the gun stays tipped and nothing else happens", shownT("Magazine_Polymer") == 1
			and not g.Motion:Playing("MagOut") and not g.Motion:Playing("MagIn") and not g.Motion:Playing("Rack")
			and ViewGun.Direction():Dot(cam.CFrame.LookVector) < 0.9985 and at("Carrier_Gunmetal").Z < home.Z - 0.25)
		state({ Chamber = false, BoltOpen = true, NoMag = true, Reloading = true, Step = "In", Busy = 0.9 }); run(0.5)
		local rising = at("Magazine_Polymer")
		check("gun motion: a magazine comes up and stops short of home", g.Motion:Playing("MagIn") and shownT("Magazine_Polymer") ~= 1
			and rising.Y < magHome.Y - 0.05 and rising.Y > magHome.Y - 0.6)
		local before = ViewGun.State().Kick
		run(0.17)
		check("gun motion: driven home, the magazine jolts the whole gun", (ViewGun.State().Kick - before).Magnitude > 0.2 and (at("Magazine_Polymer") - magHome).Magnitude < 0.03)
		state({ Chamber = false, BoltOpen = true, Mag = 30 }); run(0.8)
		check("gun motion: the magazine is in and the action still waits for the hand", (at("Magazine_Polymer") - magHome).Magnitude < 0.01
			and not g.Motion:Playing("MagIn") and at("Carrier_Gunmetal").Z < home.Z - 0.25 and ViewGun.Direction():Dot(cam.CFrame.LookVector) > 0.9995)
		do
			local function key(name, began)
				(if began then UIS.InputBegan else UIS.InputEnded):Fire({ KeyCode = M.mockEnv.Enum.KeyCode[name], UserInputType = M.mockEnv.Enum.UserInputType.Keyboard }, false)
			end
			key("T", true); key("T", false); run(0.3)
			local pulled = at("Charging_Gunmetal")
			check("gun motion: T, the hand draws the charging handle back", g.Motion:Playing("Rack") and pulled.Z < 0.6 - 0.15 and leftAt().Z < 0.5)
			state({ Mag = 29 }); run(1.2)
			check("gun motion: let go, the action is home and the hand back on the gun", math.abs(at("Carrier_Gunmetal").Z - home.Z) < 0.005
				and math.abs(at("Charging_Gunmetal").Z - 0.6) < 0.005 and (leftAt() - g.LeftRest).Magnitude < 0.01 and not g.Motion:Playing("Rack"))
		end
		-- a tap of R lets the magazine fall
		state({ NoMag = true, Reloading = true, Step = "Out", StepKeep = false, Busy = 0.4 }); run(0.2)
		check("gun motion: dropped, the magazine falls away from the gun", cam:FindFirstChild("DroppedMagazine") ~= nil and shownT("Magazine_Polymer") == 1)
		state({ NoMag = true, Reloading = true, Step = "In", Busy = 0.6 }); run(0.7)
		state({ Mag = 30 }); run(1)
		-- the small moves
		local function key(name, began)
			(if began then UIS.InputBegan else UIS.InputEnded):Fire({ KeyCode = M.mockEnv.Enum.KeyCode[name], UserInputType = M.mockEnv.Enum.UserInputType.Keyboard }, false)
		end
		local function down(name) key(name, true) end
		local function up(name) key(name, false) end
		down("Y"); run(0.8)
		local shown = ViewGun.Direction():Dot(cam.CFrame.LookVector)
		up("Y"); run(1)
		check("gun motion: checking the weapon turns it to show its side, then it comes back", shown < 0.95 and ViewGun.Direction():Dot(cam.CFrame.LookVector) > 0.999)
		down("T"); up("T"); run(0.25)
		local racking = g.Motion:Playing("Rack") and at("Carrier_Gunmetal").Z < home.Z - 0.1
		run(1)
		check("gun motion: T works the action by hand", racking and not g.Motion:Playing("Rack") and math.abs(at("Carrier_Gunmetal").Z - home.Z) < 0.005)
	end
	held:Destroy(); run(0.2)
	check("view gun: no gun in the hand, none in the view", ViewGun.Shown() == false and ViewGun.Direction() == nil)
end
check("no client errors", #M.errors == 0)
for _, e in M.errors do print(e) end
