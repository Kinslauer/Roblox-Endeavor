-- The Front client. Always first person (TTK helmetcam). The client never decides a hit:
-- it sends aim directions and button presses, and draws what the server says happened.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Firearms = require(Shared:WaitForChild("Firearms"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
Sounds.Loop("AmbFront", 0.4) -- wind over the mud and guns on the horizon
require(script.Parent:WaitForChild("Ambience")).Init() -- ash, horizon flashes, crests growing from the dead

-- Procedural soldier poses: Motor6D C0 offsets under the walk/idle animations. Every soldier holds
-- the rifle with both hands; shots kick the right arm; a reload drops the left hand to the magazine.
-- shared/Joints poses both joint systems (Motor6D and the newer avatar AnimationConstraints)
local Joints = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("Joints"))
local function pose(char, name, offset, seconds)
	Joints.Pose(char, name, offset, seconds)
end
local function holdPose(char, seconds)
	if char:GetAttribute("Stance") == "Prone" then
		-- lying behind the rifle: both arms reach past the head, elbows on the ground
		pose(char, "RightShoulder", CFrame.Angles(math.rad(158), 0, math.rad(-10)), seconds or 0.2)
		pose(char, "RightElbow", CFrame.Angles(math.rad(28), 0, 0), seconds or 0.2)
		pose(char, "LeftShoulder", CFrame.Angles(math.rad(150), 0, math.rad(30)), seconds or 0.2)
		pose(char, "LeftElbow", CFrame.Angles(math.rad(40), 0, 0), seconds or 0.2)
		return
	end
	pose(char, "RightShoulder", CFrame.Angles(math.rad(78), 0, math.rad(-12)), seconds or 0.2)
	pose(char, "RightElbow", CFrame.Angles(math.rad(55), 0, 0), seconds or 0.2)
	pose(char, "LeftShoulder", CFrame.Angles(math.rad(68), 0, math.rad(38)), seconds or 0.2)
	pose(char, "LeftElbow", CFrame.Angles(math.rad(75), 0, 0), seconds or 0.2)
end
local function kickPose(char)
	pose(char, "RightShoulder", CFrame.Angles(math.rad(90), 0, math.rad(-14)), 0.04)
	pose(char, "LeftShoulder", CFrame.Angles(math.rad(78), 0, math.rad(36)), 0.04)
	task.delay(0.06, function()
		holdPose(char, 0.14)
	end)
end
local function reloadPose(char)
	pose(char, "LeftShoulder", CFrame.Angles(math.rad(35), 0, math.rad(15)), 0.15)
	pose(char, "LeftElbow", CFrame.Angles(math.rad(95), 0, 0), 0.15)
	pose(char, "RightShoulder", CFrame.Angles(math.rad(65), 0, math.rad(-8)), 0.15)
end
local function bindSoldier(char)
	task.spawn(function()
		char:WaitForChild("RightUpperArm", 10)
		task.wait(0.2)
		holdPose(char, 0.3)
	end)
	char:GetAttributeChangedSignal("Stance"):Connect(function()
		holdPose(char, 0.3) -- the server folds the legs and lays the body down; the arms follow here
	end)
end
for _, other in Players:GetPlayers() do
	if other.Character then
		bindSoldier(other.Character)
	end
	other.CharacterAdded:Connect(bindSoldier)
end
Players.PlayerAdded:Connect(function(other)
	other.CharacterAdded:Connect(bindSoldier)
end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "FrontHUD", false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent or gui
	return inst
end
local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.Code
	props.TextSize = props.TextSize or 15
	return make("TextLabel", props, props.Parent)
end

-- ===== first person, always =====
player.CameraMode = Enum.CameraMode.LockFirstPerson
RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then
		return
	end
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Head" and p.Name ~= "HumanoidRootPart" then
			p.LocalTransparencyModifier = 0
		end
	end
	-- the one-piece body: everything but what sits on the head (the camera looks out from inside the helmet)
	local skin = char:FindFirstChild("Skin")
	if skin then
		for _, p in skin:GetChildren() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = if p:GetAttribute("HeadPiece") then 1 else 0
			end
		end
	end
end)
-- one-piece bodies follow their limbs (shared/Skin.lua)
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skin")).Start()

-- ===== HUD (war/client/Hud.lua): rounds, mode, spares; health, stance, three items; one thin bar =====
local Hud = require(script.Parent:WaitForChild("Hud"))
Hud.Init(gui)
local IntroFx = require(script.Parent:WaitForChild("IntroFx"))
IntroFx.Init({ Hud = gui }) -- the first link: stasis tank, barracks, simulation (war/server/Intro.lua)

local linkLost = false -- true between a recruit's death and the next one: U unlinks from anywhere
local function announce(text, kind, seconds)
	if kind == "Kill" then
		Hud.Feed(text)
		if not seconds then
			return
		end
	end
	Hud.Banner(text, kind, seconds)
end
Remotes.Announce.OnClientEvent:Connect(announce)

Remotes.Hill.OnClientEvent:Connect(Hud.Hill)
Remotes.Scales.OnClientEvent:Connect(Hud.Scales)

-- ===== weapon state =====
local weapon, slotName, kit = nil, "Primary", {}
local aiming = false
local recoilPitch, recoilYaw = 0, 0
local stance = "Stand"
local function describe()
	Hud.Weapon(weapon, slotName, kit)
end
Remotes.Weapon.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "State" then
		local wasReloading = weapon and weapon.Reloading
		weapon, slotName, kit = a, b, c or kit
		if player.Character then
			if weapon and weapon.Reloading and not wasReloading then
				reloadPose(player.Character)
			elseif wasReloading and not (weapon and weapon.Reloading) then
				holdPose(player.Character, 0.2)
			end
		end
		describe()
	elseif kind == "Recoil" then
		recoilPitch += a * (if aiming then 0.7 else 1)
		recoilYaw += (math.random() - 0.5) * 2 * b
	elseif kind == "Click" then
		Sounds.Play("DryClick")
		Hud.Flash(if a == "safe" then "SAFE" elseif a == "jam" then "JAM" else "EMPTY")
	elseif kind == "Shot" and typeof(a) == "Instance" then
		kickPose(a)
		-- near shots crack, far ones roll; loudness comes from the weapon's attachments (suppressors)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local far = root and (root.Position - b).Magnitude > 180
		Sounds.Play(if far then "ShotDistant" else "ShotRifle", b, { Volume = (if far then 0.6 else 1) * (tonumber(d) or 1) })
		local tracer = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 150),
			Size = Vector3.new(0.08, 0.08, 6), CFrame = CFrame.lookAt(b, b + c) * CFrame.new(0, 0, -6) }, workspace)
		Debris:AddItem(tracer, 0.06)
		local flash = make("PointLight", { Brightness = 3, Range = 10, Color = Color3.fromRGB(255, 200, 120) }, a:FindFirstChild("Head") or a)
		Debris:AddItem(flash, 0.05)
	elseif kind == "Impact" then
		Sounds.Play(if c then "ImpactFlesh" else "ImpactDirt", a)
		local puff = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(0.4, 0.4, 0.4), Position = a,
			Color = if c then Color3.fromRGB(150, 20, 20) else Color3.fromRGB(120, 110, 90), Material = Enum.Material.SmoothPlastic }, workspace)
		Debris:AddItem(puff, 0.5)
	end
end)
Remotes.Soldier.OnClientEvent:Connect(function(kind, a, b)
	if kind == "HitMarker" then
		Hud.HitMarker(a, b)
	elseif kind == "Hurt" then
		Hud.Hurt()
	elseif kind == "Marked" then
		if typeof(a) == "Instance" then
			Hud.Mark(a, tonumber(b) or 8)
		end
	elseif kind == "Entrenching" then
		if a then
			announce(if a == "Dig" then ("> DIGGING . . . %ds"):format(b) else "> STACKING . . .", "Info", b)
		else
			announce("> BROKEN OFF", "Kill", 1)
		end
	elseif kind == "Deployed" then
		announce(("> LINK . . . %s%s"):format(tostring(a):upper(), if b then " . CONSCRIPT KIT . [M]" else ""), "Info", 5)
	elseif kind == "Died" then
		announce(if a then ("> LINK LOST . . . %s"):format(tostring(a):upper()) else "> LINK LOST", "Kill", Config.War.RespawnSeconds)
		linkLost = true
		task.delay(Config.War.RespawnSeconds, function()
			linkLost = false
		end)
		task.delay(1.2, function()
			if linkLost then
				announce("> LINK OPEN . . . [U] UNLINK", "Info", Config.War.RespawnSeconds - 1.5)
			end
		end)
	elseif kind == "Unlinking" then
		-- the stack goes home: the view closes to black, the teleport follows
		linkLost = false
		announce("> UNLINKING . . . STACK RETURNING", "Info", 10)
		local black = Instance.new("Frame")
		black.Size, black.BackgroundColor3, black.BackgroundTransparency, black.ZIndex = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 1, 40
		black.Parent = gui
		TweenService:Create(black, TweenInfo.new(tonumber(a) or 2), { BackgroundTransparency = 0 }):Play()
		task.delay(12, function()
			black:Destroy() -- still here: the teleport failed or is slow; the server says which
		end)
	elseif kind == "UnlinkFailed" then
		announce("> LINK HELD . . . NO ROUTE HOME", "Kill", 4)
	end
end)

-- ===== aiming, stance, lean, recoil =====
local MV = Config.WarMovement
local lean, leanNow, leanReach = 0, 0, MV.Lean
local rollTilt = 0 -- view tilt during a prone roll
local popUp = false -- stood up out of a crouch to aim over cover
local binos = false
local sprinting = false
local mantling = false
local shove -- { Velocity, Until, Seconds }: a dive or a prone roll carries the body for a moment

local function myParts()
	local char = player.Character
	return char, char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end
local rayCache, rayChar
local function rayParams()
	if rayChar ~= player.Character or not rayCache then
		rayChar = player.Character
		rayCache = RaycastParams.new()
		rayCache.FilterType = Enum.RaycastFilterType.Exclude
		rayCache.FilterDescendantsInstances = { rayChar }
	end
	return rayCache
end
local function wantStance(name)
	Remotes.Stance:FireServer(name)
end
local function setLean(side)
	if lean ~= side then
		lean = side
		Remotes.Lean:FireServer(side)
	end
end
-- low cover: something in front of the chest with clear air over it
local function lowCoverAhead()
	local _, root = myParts()
	if not root then
		return false
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local params = rayParams()
	return workspace:Raycast(root.Position, flat * 3.2, params) ~= nil and workspace:Raycast(root.Position + Vector3.new(0, 2.6, 0), flat * 3.6, params) == nil
end
local function setAim(on)
	if on and (binos or mantling) then
		return
	end
	aiming = on
	Remotes.Aim:FireServer(on)
	Hud.Aim(on)
	local zoom = (weapon and weapon.Zoom) or 1
	local class = weapon and Firearms.Defs[weapon.Id] and Firearms.Defs[weapon.Id].Class
	local seconds = MV.SightSeconds[class] or MV.SightSeconds.Default -- the snap to the sights
	TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = if on then 62 / zoom else 70 }):Play()
	-- crouched behind low cover: aiming rises over it, letting go drops back
	if on and stance == "Crouch" and lowCoverAhead() then
		popUp = true
		wantStance("Stand")
	elseif not on and popUp then
		popUp = false
		wantStance("Crouch")
	end
end
local function setBinos(on)
	if on == binos or (on and (mantling or IntroFx.Active and camera.CameraType == Enum.CameraType.Scriptable)) then
		return
	end
	if on and aiming then
		setAim(false)
	end
	binos = on
	Hud.Binoculars(on)
	UserInputService.MouseDeltaSensitivity = if on then 0.25 else 1
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = if on then MV.Binoculars.Fov else 70 }):Play()
end

local function onStance(char)
	stance = char:GetAttribute("Stance") or "Stand"
	Hud.Stance(stance)
	if stance == "Prone" then
		lean = 0
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, stance == "Stand") -- no hopping from a crouch
		end)
	end
end
local function bindMine(char)
	lean, popUp, shove = 0, false, nil
	setBinos(false)
	onStance(char)
	char:GetAttributeChangedSignal("Stance"):Connect(function()
		onStance(char)
	end)
end
if player.Character then
	bindMine(player.Character)
end
player.CharacterAdded:Connect(bindMine)

RunService.RenderStepped:Connect(function(dt)
	-- recoil kicks the camera, then settles
	if recoilPitch ~= 0 or recoilYaw ~= 0 then
		local kickP, kickY = recoilPitch * math.min(1, dt * 18), recoilYaw * math.min(1, dt * 18)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(kickP), math.rad(kickY), 0)
		recoilPitch -= kickP
		recoilYaw -= kickY
		if math.abs(recoilPitch) < 0.01 then recoilPitch = 0 end
		if math.abs(recoilYaw) < 0.01 then recoilYaw = 0 end
	end
	local _, root, hum = myParts()
	if hum and root then
		Hud.Health(hum.Health / math.max(1, hum.MaxHealth))
		-- lean: the eye moves out to the side and the view tilts; next to cover it goes out past the corner
		if lean ~= 0 then
			local params = rayParams()
			local look = root.CFrame.LookVector
			local eye = root.Position + Vector3.new(0, 1.5, 0)
			leanReach = if workspace:Raycast(eye, Vector3.new(look.X, 0, look.Z) * MV.PeekReach, params) then MV.Peek else MV.Lean
			local wall = workspace:Raycast(eye, root.CFrame.RightVector * lean * (leanReach + 0.4), params)
			if wall then
				leanReach = math.max(0, (wall.Position - eye).Magnitude - 0.4)
			end
		end
		leanNow += (lean - leanNow) * math.min(1, dt * 14)
		local offset = Vector3.new(leanNow * leanReach, 0, 0)
		if stance == "Prone" then
			offset += MV.ProneCamera
		end
		hum.CameraOffset = hum.CameraOffset:Lerp(offset, math.min(1, dt * 12))
		local tilt = leanNow * MV.LeanRoll + rollTilt
		if math.abs(tilt) > 0.05 then
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, -math.rad(tilt))
		end
	end
end)

-- binoculars: a figure held in the glass for a moment is marked
local dwellOn, dwell, markedAt = nil, 0, {}
RunService.Heartbeat:Connect(function(dt)
	if not binos then
		return
	end
	local B = MV.Binoculars
	local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * B.Range, rayParams())
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if model and not model:FindFirstChildOfClass("Humanoid") then
		model = nil
	end
	if model ~= dwellOn then
		dwellOn, dwell = model, 0
	end
	if model and os.clock() - (markedAt[model] or 0) > 2 then
		dwell += dt
		if dwell >= B.Dwell then
			markedAt[model] = os.clock()
			dwell = 0
			Remotes.Mark:FireServer(model)
			Sounds.Play("DryClick", nil, { Volume = 0.35 })
		end
	else
		dwell = 0
	end
	Hud.Dwell(dwell / B.Dwell)
end)

-- ===== recruit app (M) =====
local app = make("ScrollingFrame", { Size = UDim2.fromOffset(520, 440), Position = UDim2.new(0.5, -260, 0.5, -220), BackgroundColor3 = Color3.fromRGB(12, 14, 20), Visible = false, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4 })
make("UIListLayout", { Padding = UDim.new(0, 3) }, app)
local snapshot
local function row(text, buttons, color)
	local r = make("Frame", { Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1 }, app)
	label({ Size = UDim2.new(1, -10 - 70 * #buttons, 1, 0), Position = UDim2.fromOffset(6, 0), Text = text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
	for i, b in buttons do
		make("TextButton", { Size = UDim2.fromOffset(66, 22), Position = UDim2.new(1, -70 * (#buttons - i + 1), 0, 2), Text = b.text, BackgroundColor3 = b.color or Color3.fromRGB(60, 80, 120), TextColor3 = Color3.new(1, 1, 1), TextSize = 12 }, r).Activated:Connect(b.fn)
	end
end
local function renderApp()
	for _, c in app:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not snapshot then
		return
	end
	local s = snapshot
	row(("RECRUIT APP  -  %s  -  %d credits  -  %d deployments, %d kills, %d deaths"):format(s.Faction, s.Credits, s.Deployments, s.Kills, s.Deaths), {}, Config.War.FactionColors[s.Faction])
	row("-- NEXT ORDER (built from your locker) --", {})
	local lo = s.Loadout or {}
	row(("Primary: %s   Sidearm: %s   Armor: %s   Helmet: %s"):format(lo.Primary or "-", lo.Sidearm or "-", lo.Armor or "-", lo.Helmet or "-"), {})
	local atts = lo.Attachments or {}
	row(("Optic: %s   Muzzle: %s   Grip: %s"):format(atts.Optic or "-", atts.Muzzle or "-", atts.Grip or "-"), {})
	row("-- LOCKER (X = put in next order, Fix = repair) --", {})
	local ids = {}
	for id in s.Locker do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ids do
		local slot = s.Locker[id]
		local item = s.Catalog[id] or { Kind = "?", Name = id }
		local buttons = {}
		if item.Kind == "Weapon" then
			local isPistol = item.Class == "Pistol"
			table.insert(buttons, { text = if isPistol then "Sidearm" else "Primary", fn = function()
				local order = { Primary = lo.Primary, Sidearm = lo.Sidearm, Armor = lo.Armor, Helmet = lo.Helmet, Attachments = atts }
				order[if isPistol then "Sidearm" else "Primary"] = id
				Remotes.WarOrder:FireServer(order)
			end })
		elseif item.Kind == "Attachment" then
			table.insert(buttons, { text = "Mount", fn = function()
				local a = table.clone(atts); a[item.Slot] = id
				Remotes.WarOrder:FireServer({ Primary = lo.Primary, Sidearm = lo.Sidearm, Armor = lo.Armor, Helmet = lo.Helmet, Attachments = a })
			end })
		elseif item.Kind == "Armor" then
			local isHelmet = Firearms.Armor[id] and Firearms.Armor[id].Head
			table.insert(buttons, { text = "Wear", fn = function()
				local order = { Primary = lo.Primary, Sidearm = lo.Sidearm, Armor = lo.Armor, Helmet = lo.Helmet, Attachments = atts }
				order[if isHelmet then "Helmet" else "Armor"] = id
				Remotes.WarOrder:FireServer(order)
			end })
		end
		if slot.condition < 100 then
			table.insert(buttons, { text = "Fix", color = Color3.fromRGB(120, 90, 40), fn = function() Remotes.WarRepair:FireServer(id) end })
		end
		row(("%s x%d  (%d%%)"):format(item.Name, slot.count, slot.condition), buttons, if slot.condition < 50 then Color3.fromRGB(255, 150, 120) else nil)
	end
	row("-- SHOP --", {})
	local cids = {}
	for id, item in s.Catalog do
		if not item.Faction or item.Faction == s.Faction then table.insert(cids, id) end
	end
	table.sort(cids, function(a, b) return s.Catalog[a].Price < s.Catalog[b].Price end)
	for _, id in cids do
		local item = s.Catalog[id]
		row(("%s  -  %d cr"):format(item.Name, item.Price), { { text = "Buy", color = Color3.fromRGB(50, 110, 70), fn = function() Remotes.WarBuy:FireServer(id) end } },
			if item.Price > s.Credits then Color3.fromRGB(140, 140, 140) else nil)
	end
end
Remotes.RecruitApp.OnClientEvent:Connect(function(snap, open)
	snapshot = snap
	if open then
		app.Visible = true
	end
	renderApp()
end)

-- ===== explosions / world =====
Remotes.World.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Dig" then
		Sounds.Play("Dig", a)
		local puff = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(3, 1, 3), Position = a + Vector3.new(0, 1, 0), Color = Color3.fromRGB(70, 60, 45), Material = Enum.Material.Ground, Transparency = 0.3 }, workspace)
		TweenService:Create(puff, TweenInfo.new(1), { Transparency = 1, Position = a + Vector3.new(0, 4, 0) }):Play()
		Debris:AddItem(puff, 1)
	elseif kind == "Explosion" then
		Sounds.Play("Explosion", a)
		local sphere = make("Part", { Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 150, 60), Size = Vector3.new(2, 2, 2), Position = a, Transparency = 0.1 }, workspace)
		TweenService:Create(sphere, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(b * 2, b * 2, b * 2), Transparency = 1 }):Play()
		Debris:AddItem(sphere, 0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - a).Magnitude < b * 4 then
			recoilPitch += 3
			recoilYaw += (math.random() - 0.5) * 4
		end
	elseif kind == "ArtilleryWarning" then
		task.delay(math.max(0, (tonumber(b) or 0) - 2), function()
			Sounds.Play("ArtilleryWhistle", a)
		end)
		announce(("> INCOMING . . . %ds"):format(b), "Emergence", b)
	end
end)

-- ===== movement: stance speeds, sprint (Shift), dives and rolls, pulling up over a ledge (Space at a wall) =====
RunService.Heartbeat:Connect(function()
	local _, root, hum = myParts()
	if not (hum and root) or mantling then
		return
	end
	-- the server freezes a recruit (WalkSpeed 0: digging, the tank); anything else is ours to pace
	if hum.WalkSpeed > 0.5 then
		local running = sprinting and stance == "Stand" and not aiming and not binos and hum.MoveDirection.Magnitude > 0.1
		local speed = if running then MV.SprintSpeed else MV.Stance[stance].Speed
		if aiming or binos then
			speed = math.min(speed, MV.Stance.Crouch.Speed) -- sights up: a slow, level walk
		end
		hum.WalkSpeed = speed
		local fov = if running then 78 elseif aiming or binos then nil else 70
		if fov and not IntroFx.Active and math.abs(camera.FieldOfView - fov) > 0.5 then
			camera.FieldOfView += (fov - camera.FieldOfView) * 0.15
		end
	end
	-- a dive or a roll carries the body; it fades out over its time
	if shove then
		local left = shove.Until - os.clock()
		if left <= 0 or root.Anchored then
			shove, rollTilt = nil, 0
		else
			local u = left / shove.Seconds
			local v = shove.Velocity * (0.35 + 0.65 * u)
			root.AssemblyLinearVelocity = Vector3.new(v.X, root.AssemblyLinearVelocity.Y, v.Z)
			rollTilt = (shove.Tilt or 0) * math.sin((1 - u) * math.pi)
		end
	end
end)

-- sprint + C: throw yourself flat
local function dive()
	local _, root, hum = myParts()
	if not (root and hum) or hum.Health <= 0 or root.Anchored then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	sprinting = false
	wantStance("Prone")
	root.AssemblyLinearVelocity = flat.Unit * MV.DiveSpeed + Vector3.new(0, MV.DiveLift, 0)
	shove = { Velocity = flat.Unit * MV.DiveSpeed, Seconds = 0.45, Until = os.clock() + 0.45 }
	recoilPitch -= 2.5 -- the view dips with the body
end
-- Q / E while prone: roll to the side
local rollReady = 0
local function proneRoll(side)
	local _, root, hum = myParts()
	if not (root and hum) or os.clock() < rollReady or root.Anchored or hum.WalkSpeed < 0.5 then
		return
	end
	rollReady = os.clock() + MV.RollCooldown
	shove = { Velocity = root.CFrame.RightVector * side * MV.RollSpeed, Seconds = MV.RollSeconds, Until = os.clock() + MV.RollSeconds, Tilt = side * 16 }
end

local function tryMantle()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if mantling or not (root and hum) or hum.Health <= 0 or root.Anchored or hum.WalkSpeed < 1 then
		return
	end
	local params = rayParams()
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	local feet = root.Position.Y - hum.HipHeight - root.Size.Y / 2
	-- a wall in front of the chest...
	local wall = workspace:Raycast(Vector3.new(root.Position.X, feet + 2.2, root.Position.Z), flat * MV.MantleReach, params)
	if not wall or math.abs(wall.Normal.Y) > 0.5 then
		return
	end
	-- ...with a top within reach and room to stand on it
	local probe = wall.Position + flat * 1.2 + Vector3.new(0, 0, 0)
	local top = workspace:Raycast(Vector3.new(probe.X, feet + MV.MantleHeight + 0.6, probe.Z), Vector3.new(0, -(MV.MantleHeight + 0.4), 0), params)
	if not top or top.Normal.Y < 0.7 then
		return
	end
	local rise = top.Position.Y - feet
	if rise < 1.5 or rise > MV.MantleHeight then
		return
	end
	if workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 5, 0), params) then
		return -- no headroom
	end
	mantling = true
	local start = root.CFrame
	local lift = root.Position.Y + rise + 0.3
	local finish = CFrame.lookAt(Vector3.new(top.Position.X, top.Position.Y + hum.HipHeight + root.Size.Y / 2 + 0.1, top.Position.Z) + flat * 0.6,
		Vector3.new(top.Position.X, top.Position.Y + hum.HipHeight + root.Size.Y / 2 + 0.1, top.Position.Z) + flat * 2)
	Sounds.Play("Mantle", nil, { Volume = 0.5 })
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / MV.MantleSeconds, 0, 1)
		-- up first, then over the lip
		local upU = math.clamp(u / 0.6, 0, 1)
		local overU = math.clamp((u - 0.45) / 0.55, 0, 1)
		local pos = start.Position:Lerp(Vector3.new(start.Position.X, lift, start.Position.Z), 1 - (1 - upU) ^ 2)
		pos = pos:Lerp(finish.Position, overU * overU)
		if root.Parent then
			root.CFrame = CFrame.lookAt(pos, pos + flat)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-4 * math.sin(u * math.pi)), 0, 0)
		if u >= 1 then
			conn:Disconnect()
			mantling = false
		end
	end)
end

-- ===== input: Metal Gear handling in first person =====
-- LMB fire, RMB sights, R reload (hold: keep the magazine), T rack/unjam, B selector, 1/2 switch, G frag,
-- H dressing, C crouch (hold: prone; at a sprint: dive), Space up a stance / over a ledge, Q/E lean
-- (prone: roll), Z binoculars, Y check weapon, K artillery, F dig, V sandbags, M app, U unlink.
local firing = false
local held = {} -- [KeyCode] = token while a hold-or-tap key is down

local function holdKey(key, seconds, onHold)
	local token = {}
	held[key] = token
	task.delay(seconds, function()
		if held[key] == token then
			held[key] = true -- the hold fired: the release does nothing
			onHold()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if binos then
			return
		end
		firing = true
		sprinting = false -- the rifle comes up: no shooting at a run
		Remotes.Fire:FireServer(camera.CFrame.LookVector)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		sprinting = false
		setAim(true)
	elseif key == Enum.KeyCode.R then
		holdKey(key, MV.CarefulReloadHold, function()
			Remotes.Reload:FireServer(true) -- careful: the magazine goes back in the pouch
		end)
	elseif key == Enum.KeyCode.T then
		Sounds.Play("Rack")
		if weapon and weapon.Jammed then Remotes.Unjam:FireServer() else Remotes.Rack:FireServer() end
	elseif key == Enum.KeyCode.B then
		Remotes.Mode:FireServer()
	elseif key == Enum.KeyCode.One or key == Enum.KeyCode.Two then
		Remotes.Switch:FireServer()
	elseif key == Enum.KeyCode.G then
		Remotes.Grenade:FireServer(camera.CFrame.LookVector)
	elseif key == Enum.KeyCode.H then
		Remotes.Heal:FireServer()
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.E then
		local side = if key == Enum.KeyCode.Q then -1 else 1
		if stance == "Prone" then
			proneRoll(side)
		else
			setLean(side)
		end
	elseif key == Enum.KeyCode.C then
		local _, _, hum = myParts()
		if sprinting and stance == "Stand" and hum and hum.MoveDirection.Magnitude > 0.1 then
			dive()
		else
			holdKey(key, MV.ProneHoldSeconds, function()
				wantStance("Prone")
			end)
		end
	elseif key == Enum.KeyCode.Z then
		setBinos(true)
	elseif key == Enum.KeyCode.Y then
		Hud.Check(true)
	elseif key == Enum.KeyCode.K then
		-- artillery: on the point you are looking at
		local ray = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 600)
		if ray then
			Remotes.Artillery:FireServer(ray.Position)
		end
	elseif key == Enum.KeyCode.F then
		Remotes.Entrench:FireServer("Dig")
	elseif key == Enum.KeyCode.V then
		Remotes.Entrench:FireServer("Sandbag")
	elseif key == Enum.KeyCode.M then
		app.Visible = not app.Visible
	elseif key == Enum.KeyCode.U and linkLost then
		Remotes.Unlink:FireServer()
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		sprinting = true
		popUp = false
		if stance ~= "Stand" then
			wantStance("Stand") -- running starts on your feet
		end
		if aiming then
			setAim(false)
		end
	elseif key == Enum.KeyCode.Space then
		if stance ~= "Stand" then
			popUp = false
			wantStance(if stance == "Prone" then "Crouch" else "Stand")
		else
			tryMantle()
		end
	elseif key == Enum.KeyCode.F2 and Config.Dev.Enabled then
		Remotes.TutorialSkip:FireServer() -- testing: skip the current stage of the first link
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local key = input.KeyCode
	local tapped = held[key] ~= nil and held[key] ~= true
	held[key] = nil
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAim(false)
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
		sprinting = false
	elseif key == Enum.KeyCode.Q and lean == -1 then
		setLean(0)
	elseif key == Enum.KeyCode.E and lean == 1 then
		setLean(0)
	elseif key == Enum.KeyCode.R and tapped then
		Remotes.Reload:FireServer(false) -- quick: a half-used magazine is left where it falls
	elseif key == Enum.KeyCode.C and tapped then
		popUp = false
		wantStance(if stance == "Stand" then "Crouch" elseif stance == "Crouch" then "Stand" else "Crouch")
	elseif key == Enum.KeyCode.Z then
		setBinos(false)
	elseif key == Enum.KeyCode.Y then
		Hud.Check(false)
	end
end)
-- full auto: keep sending trigger pulls while held; the server's RPM gate decides what fires
local lastAuto = 0
RunService.Heartbeat:Connect(function()
	if firing and weapon and weapon.Mode == "Auto" then
		local rpm = (Firearms.Defs[weapon.Id] and Firearms.Defs[weapon.Id].RPM) or 600
		if os.clock() - lastAuto >= 60 / rpm then
			lastAuto = os.clock()
			Remotes.Fire:FireServer(camera.CFrame.LookVector)
		end
	end
end)
