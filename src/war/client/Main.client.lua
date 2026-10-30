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
end)

-- ===== HUD =====
local crosshair = label({ Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, -10, 0.5, -10), Text = "+", TextSize = 22, TextColor3 = Color3.fromRGB(230, 230, 230) })
local weaponPanel = label({ Size = UDim2.fromOffset(300, 110), Position = UDim2.new(1, -320, 1, -130), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Bottom, Text = "" })
local healthLabel = label({ Size = UDim2.fromOffset(240, 20), Position = UDim2.new(0, 20, 1, -40), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local kitLabel = label({ Size = UDim2.fromOffset(240, 20), Position = UDim2.new(0, 20, 1, -62), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local hillLabel = label({ Size = UDim2.fromOffset(520, 44), Position = UDim2.new(0.5, -260, 0, 16), TextSize = 16, Text = "" })
local scaleBack = make("Frame", { Size = UDim2.fromOffset(400, 10), Position = UDim2.new(0.5, -200, 0, 64), BackgroundColor3 = Config.War.FactionColors.Pact })
local scaleFill = make("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Config.War.FactionColors.Union }, scaleBack)
local banner = label({ Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 84), TextSize = 22, Text = "", TextTransparency = 1 })
local hitMarker = label({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0.5, -20), Text = "x", TextSize = 26, TextColor3 = Color3.fromRGB(255, 80, 80), TextTransparency = 1 })
local hurtFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(180, 0, 0), BackgroundTransparency = 1, ZIndex = 5 })

local KIND_COLORS = { Event = Color3.fromRGB(255, 200, 60), Kill = Color3.fromRGB(230, 230, 230), Info = Color3.fromRGB(120, 220, 255), Emergence = Color3.fromRGB(255, 90, 90) }
local bannerToken = 0
local function announce(text, kind, seconds)
	bannerToken += 1
	local token = bannerToken
	banner.Text, banner.TextColor3, banner.TextTransparency = text, KIND_COLORS[kind] or Color3.new(1, 1, 1), 0
	task.delay(seconds or 5, function()
		if token == bannerToken then
			banner.TextTransparency = 1
		end
	end)
end
Remotes.Announce.OnClientEvent:Connect(announce)

Remotes.Hill.OnClientEvent:Connect(function(h)
	local lead = if h.Holder then ("%s holding %ds / %ds"):format(h.Holder, h.Held, h.Need) else "contested"
	hillLabel.Text = ("HILL: sector %d   Union %d  -  Pact %d   (%s)   moves in %dm%02ds"):format(h.Sector, h.Counts.Union, h.Counts.Pact, lead, h.MovesIn // 60, h.MovesIn % 60)
end)
Remotes.Scales.OnClientEvent:Connect(function(s)
	scaleFill.Size = UDim2.fromScale(math.clamp(s.UnionShare, 0.02, 0.98), 1)
end)

-- ===== weapon state =====
local weapon, slotName, kit = nil, "Primary", {}
local aiming = false
local recoilPitch, recoilYaw = 0, 0
local function describe()
	if not weapon then
		weaponPanel.Text = "unarmed"
		return
	end
	local parts = {}
	for _, name in Firearms.Parts do
		table.insert(parts, ("%s %d%%"):format(name:sub(1, 3), weapon.Parts[name] or 100))
	end
	local mag = if weapon.Mag == nil then "NO MAG" else ("mag %d/%d"):format(weapon.Mag, weapon.MagSize)
	local status = if weapon.Jammed then "JAMMED (T to clear)" elseif weapon.BoltOpen then "BOLT OPEN (R)" elseif not weapon.Chamber then "EMPTY CHAMBER (T)" else "ready"
	weaponPanel.Text = ("%s  [%s]\n%s   %s   spare %d\n%s\n%s"):format(weapon.Name, slotName, weapon.Mode:upper(), mag, weapon.Spare, status, table.concat(parts, "  "))
	kitLabel.Text = ("grenades %d   dressings %d   armor %s   helmet %s"):format(kit.Grenades or 0, kit.Medkits or 0,
		if kit.Armor then ("%d%%"):format(kit.Armor.Condition) else "-", if kit.Helmet then ("%d%%"):format(kit.Helmet.Condition) else "-")
end
Remotes.Weapon.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "State" then
		weapon, slotName, kit = a, b, c or kit
		describe()
	elseif kind == "Recoil" then
		recoilPitch += a * (if aiming then 0.7 else 1)
		recoilYaw += (math.random() - 0.5) * 2 * b
	elseif kind == "Click" then
		crosshair.Text = if a == "dry" then "click" elseif a == "safe" then "SAFE" elseif a == "jam" then "JAM" else "+"
		task.delay(0.4, function() crosshair.Text = "+" end)
	elseif kind == "Shot" and typeof(a) == "Instance" then
		local tracer = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 150),
			Size = Vector3.new(0.08, 0.08, 6), CFrame = CFrame.lookAt(b, b + c) * CFrame.new(0, 0, -6) }, workspace)
		Debris:AddItem(tracer, 0.06)
		local flash = make("PointLight", { Brightness = 3, Range = 10, Color = Color3.fromRGB(255, 200, 120) }, a:FindFirstChild("Head") or a)
		Debris:AddItem(flash, 0.05)
	elseif kind == "Impact" then
		local puff = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(0.4, 0.4, 0.4), Position = a,
			Color = if c then Color3.fromRGB(150, 20, 20) else Color3.fromRGB(120, 110, 90), Material = Enum.Material.SmoothPlastic }, workspace)
		Debris:AddItem(puff, 0.5)
	end
end)
Remotes.Soldier.OnClientEvent:Connect(function(kind, a, b)
	if kind == "HitMarker" then
		hitMarker.TextColor3 = if b then Color3.fromRGB(255, 40, 40) else (if a == "Head" then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(230, 230, 230))
		hitMarker.TextTransparency = 0
		task.delay(0.15, function() hitMarker.TextTransparency = 1 end)
	elseif kind == "Hurt" then
		hurtFrame.BackgroundTransparency = 0.55
		TweenService:Create(hurtFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	elseif kind == "Deployed" then
		announce(("Deployed with the %s%s."):format(a, if b then " as a conscript: order a loadout (M) before next time" else ""), "Info", 6)
	elseif kind == "Died" then
		announce(if a then ("Your recruit was killed by %s. Their gear is on the field."):format(a) else "Your recruit is dead. Their gear is on the field.", "Kill", Config.War.RespawnSeconds)
	end
end)

-- ===== aiming, lean, recoil =====
local lean = 0
local function setAim(on)
	aiming = on
	Remotes.Aim:FireServer(on)
	local zoom = (weapon and weapon.Zoom) or 1
	TweenService:Create(camera, TweenInfo.new(0.18), { FieldOfView = if on then 70 / zoom else 70 }):Play()
end
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
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		healthLabel.Text = ("HP %d"):format(hum.Health)
		-- lean: offset the camera sideways and roll it a little
		local target = lean * 1.6
		camera.CFrame = camera.CFrame * CFrame.new(target * dt * 10, 0, 0) * CFrame.Angles(0, 0, -math.rad(lean * 8) * dt * 10)
	end
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
	if kind == "Explosion" then
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
		announce(("Incoming! Shells land in %ds."):format(b), "Emergence", b)
	end
end)

-- ===== input (TTK/Tarkov layout) =====
local firing = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = true
		Remotes.Fire:FireServer(camera.CFrame.LookVector)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAim(true)
	elseif key == Enum.KeyCode.R then
		Remotes.Reload:FireServer()
	elseif key == Enum.KeyCode.T then
		if weapon and weapon.Jammed then Remotes.Unjam:FireServer() else Remotes.Rack:FireServer() end
	elseif key == Enum.KeyCode.B then
		Remotes.Mode:FireServer()
	elseif key == Enum.KeyCode.One or key == Enum.KeyCode.Two then
		Remotes.Switch:FireServer()
	elseif key == Enum.KeyCode.G then
		Remotes.Grenade:FireServer(camera.CFrame.LookVector)
	elseif key == Enum.KeyCode.H then
		Remotes.Heal:FireServer()
	elseif key == Enum.KeyCode.Q then
		lean = -1
	elseif key == Enum.KeyCode.E then
		lean = 1
	elseif key == Enum.KeyCode.K then
		-- artillery: on the point you are looking at
		local ray = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 600)
		if ray then
			Remotes.Artillery:FireServer(ray.Position)
		end
	elseif key == Enum.KeyCode.M then
		app.Visible = not app.Visible
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAim(false)
	elseif input.KeyCode == Enum.KeyCode.Q and lean == -1 then
		lean = 0
	elseif input.KeyCode == Enum.KeyCode.E and lean == 1 then
		lean = 0
	end
end)
-- full auto: keep sending trigger pulls while held; the server's RPM gate decides what fires
RunService.Heartbeat:Connect(function()
	if firing and weapon and weapon.Mode == "Auto" then
		Remotes.Fire:FireServer(camera.CFrame.LookVector)
	end
end)
