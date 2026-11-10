-- The arrival, as the player sees it (server/Tutorial.lua seats the character and waits for "Done").
-- A title on black; the inside of a train car in a tunnel; a hooded figure on the bench. The train brakes into
-- a dead station. The figure stands, throws the cloak off (a pistol on the thigh, a weapon across the back),
-- draws and racks the slide, steps into the aisle. The camera comes round behind to where the game is played
-- from, then pushes in to first person, and the doors open.
--
-- Everything here is local: the cloak, the holstered pistol and the weapon on the back are client-side copies
-- from ReplicatedStorage.IntroKit (server/IntroKit.lua), the tunnel outside the windows is a few moving lights.
-- Hold Space to skip.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Anims = require(Shared:WaitForChild("Anims"))
local Kit = require(script.Parent:WaitForChild("UI"))

local UI = Kit.Theme
local player = Players.LocalPlayer

local Intro = {}

local hud, setFirstPerson
local screen, cover, title, rule, barTop, barBottom, skipLine
local active = false
local token = 0

function Intro.Active()
	return active
end

-- The timeline (seconds). Shots are cut on these; the body's animations start on them.
local T = {
	TitleIn = 0.6, TitleOut = 3.2, Open = 3.6,
	Aisle = 3.6, Close = 9.0, Brake = 13.2, Stand = 15.6, Cloak = 17.4, CloakLet = 17.95, Draw = 19.3, Rack = 20.3, RackClick = 20.85,
	Step = 22.2, Behind = 23.6, Push = 26.4, End = 27.6,
}
Intro.Timeline = T

local function ease(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
local function span(t, a, b)
	return math.clamp((t - a) / (b - a), 0, 1)
end

local function buildScreen()
	screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset, screen.DisplayOrder = "Intro", false, true, 50
	screen.Parent = player:WaitForChild("PlayerGui")
	cover = Kit.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, screen)
	title = Kit.label({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.5, -44), Text = Kit.spaced("Endeavor", 2), Font = UI.Title, TextSize = 44, TextTransparency = 1, ZIndex = 6, Parent = screen })
	rule = Kit.make("Frame", { Size = UDim2.fromOffset(0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 24), BackgroundColor3 = UI.Accent, BorderSizePixel = 0, ZIndex = 6 }, screen)
	barTop = Kit.make("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 }, screen)
	barBottom = Kit.make("Frame", { Size = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 }, screen)
	skipLine = Kit.make("Frame", { Size = UDim2.fromOffset(0, 2), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), BackgroundColor3 = UI.Text, BorderSizePixel = 0, ZIndex = 7 }, screen)
end

local function showTitle(seconds)
	Kit.tween(title, 1.2, { TextTransparency = 0 })
	Kit.tween(rule, 1.6, { Size = UDim2.fromOffset(280, 1) })
	task.delay(seconds, function()
		Kit.tween(title, 0.8, { TextTransparency = 1 })
		Kit.tween(rule, 0.8, { Size = UDim2.fromOffset(0, 1) })
	end)
end

local function fade(to, seconds)
	Kit.tween(cover, seconds, { BackgroundTransparency = to }, Enum.EasingStyle.Sine)
end

local function letterbox(on)
	local h = if on then 70 else 0
	Kit.tween(barTop, 0.8, { Size = UDim2.new(1, 0, 0, h) })
	Kit.tween(barBottom, 0.8, { Size = UDim2.new(1, 0, 0, h) })
end

-- ===== props =====
local function kitPiece(name)
	local folder = ReplicatedStorage:FindFirstChild("IntroKit")
	local template = folder and folder:FindFirstChild(name)
	return template and template:Clone()
end

local function weldTo(model, part, offset)
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
			table.insert(parts, p)
		end
	end
	if #parts == 0 then
		return nil
	end
	local primary = parts[1]
	local pivot = model:GetPivot()
	for i = 2, #parts do
		local w = Instance.new("Weld")
		w.Part0, w.Part1 = primary, parts[i]
		w.C0 = primary.CFrame:ToObjectSpace(parts[i].CFrame)
		w.Parent = parts[i]
	end
	local hold = Instance.new("Weld")
	hold.Name = "Hold"
	hold.Part0, hold.Part1 = part, primary
	hold.C0 = offset
	hold.C1 = primary.CFrame:ToObjectSpace(pivot)
	hold.Parent = primary
	model.Parent = part.Parent
	return hold, primary
end

local function setHeldVisible(char, visible)
	local held = char:FindFirstChild("HeldWeapon")
	if held then
		for _, p in held:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
end

local function rackSlide(char)
	local held = char:FindFirstChild("HeldWeapon")
	if not held then
		return
	end
	for _, p in held:GetDescendants() do
		if p:IsA("BasePart") and p.Name:match("^Slide") then
			local weld = p:FindFirstChildOfClass("Weld")
			if weld and weld.Name ~= "Grip" then
				local home = weld.C0
				local back = home * CFrame.new(0, -0.3, 0) -- the barrel runs along the model's +Y
				Kit.tween(weld, 0.09, { C0 = back }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.16, function()
					Kit.tween(weld, 0.06, { C0 = home })
				end)
			end
		end
	end
end

-- The tunnel outside the windows: dark walls close to the glass and lamps going by.
local function buildTunnel(carCF)
	local folder = Instance.new("Folder")
	folder.Name = "IntroTunnel"
	folder.Parent = workspace
	local walls, streaks = {}, {}
	for _, side in { -1, 1 } do
		local wall = Instance.new("Part")
		wall.Anchored, wall.CanCollide, wall.CanQuery = true, false, false
		wall.Size = Vector3.new(0.4, 16, 110)
		wall.CFrame = carCF * CFrame.new(side * 6.3, 4, 0)
		wall.Color, wall.Material = Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic
		wall.Parent = folder
		table.insert(walls, wall)
		for i = 1, 4 do
			local s = Instance.new("Part")
			s.Anchored, s.CanCollide, s.CanQuery = true, false, false
			s.Size = Vector3.new(0.2, 0.5, 5)
			s.Material, s.Color = Enum.Material.Neon, Color3.fromRGB(255, 214, 150)
			s.Parent = folder
			local l = Instance.new("PointLight")
			l.Range, l.Brightness, l.Color = 22, 2.2, s.Color
			l.Parent = s
			table.insert(streaks, { part = s, side = side, z = -60 + i * 34 + (if side > 0 then 17 else 0) })
		end
	end
	return folder, walls, streaks
end

local function carLights(car, on)
	for _, d in car:GetDescendants() do
		if d:IsA("PointLight") and d.Parent.Name == "CarLight" then
			d.Enabled = on
			d.Parent.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		end
	end
end

-- ===== the ride =====
local function finish(char, standCF, fast)
	local cam = workspace.CurrentCamera
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and standCF then
		root.CFrame = standCF
	end
	if cam then
		if root then
			cam.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), root.Position + Vector3.new(0, 1.5, 0) + root.CFrame.LookVector * 10)
		end
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
	if setFirstPerson then
		setFirstPerson(true)
	end
	if hud then
		hud.Enabled = true
	end
	letterbox(false)
	if fast then
		fade(1, 0.8)
	end
	active = false
	Remotes.Intro:FireServer("Done")
end

local function play(car, seatCF, carCF)
	token += 1
	local mine = token
	active = true
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not (root and hum and typeof(seatCF) == "CFrame" and typeof(carCF) == "CFrame") then
		active = false
		Remotes.Intro:FireServer("Done")
		return
	end
	local cam = workspace.CurrentCamera
	if hud then
		hud.Enabled = false
	end
	cover.BackgroundTransparency = 0
	letterbox(true)
	showTitle(T.TitleOut - T.TitleIn)

	-- where the figure ends up: in the aisle, facing down the car toward the doors
	local standCF = carCF * CFrame.new(0, seatCF.Y - carCF.Y, 9) * CFrame.Angles(0, 0, 0) -- faces -Z (the doors are at z 0)
	local function L(x, y, z) -- a point in the car
		return carCF:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local seatLocal = carCF:PointToObjectSpace(seatCF.Position)
	local sx, sz = seatLocal.X, seatLocal.Z
	local headSeated = Vector3.new(sx - 1.2, 3.9, sz)
	local chest = Vector3.new(sx, 3.6, sz)

	-- props
	local cloak = kitPiece("Cloak")
	local torso = char:FindFirstChild("UpperTorso")
	local cloakHold
	if cloak and torso then
		cloakHold = weldTo(cloak, torso, CFrame.new())
	end
	local back = kitPiece("Back")
	if back and torso then
		weldTo(back, torso, CFrame.new(0, 0.1, 0.62) * CFrame.Angles(0, 0, math.rad(-28)) * CFrame.Angles(math.rad(90), 0, 0))
	end
	local holster = kitPiece("Sidearm")
	local thigh = char:FindFirstChild("RightUpperLeg")
	if holster and thigh then
		weldTo(holster, thigh, CFrame.new(0.55, 0.1, 0) * CFrame.Angles(math.rad(180), 0, 0))
	end
	setHeldVisible(char, false)
	local tunnel, walls, streaks = buildTunnel(carCF)
	local rumble = Sounds.Loop("TrainLoop", 0)
	Anims.Play(char, "Intro_Seated", { fade = 0 })

	local t0 = os.clock()
	local speed = 150 -- studs/s the tunnel goes by
	local fired = {}
	local function once(key, at, fn)
		if not fired[key] and os.clock() - t0 >= at then
			fired[key] = true
			fn()
		end
	end
	local skipHeld = 0
	local shake = 0.05
	local conn
	local function cleanup()
		if conn then
			conn:Disconnect()
		end
		tunnel:Destroy()
		if rumble then
			rumble.Volume = 0
		end
		carLights(car, true)
		for _, name in { "Intro_Seated", "Intro_Stand", "Intro_CloakToss", "Intro_Draw", "Intro_Rack" } do
			Anims.Stop(char, name, 0.2)
		end
		if cloak then
			cloak:Destroy()
		end
		if holster then
			holster:Destroy()
		end
		setHeldVisible(char, true)
		task.delay(6, function()
			if back then
				back:Destroy() -- by now the view is from inside the head
			end
		end)
	end

	conn = RunService.RenderStepped:Connect(function(dt)
		if mine ~= token or not char.Parent then
			cleanup()
			active = false
			return
		end
		local t = os.clock() - t0
		-- skip: hold Space
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			skipHeld += dt
		else
			skipHeld = 0
		end
		skipLine.Size = UDim2.fromOffset(math.clamp(skipHeld, 0, 1) * 160, 2)
		if skipHeld >= 1 or t >= T.End then
			skipLine.Size = UDim2.fromOffset(0, 2)
			cleanup()
			finish(char, standCF, skipHeld >= 1)
			return
		end

		-- the tunnel: slows to a stop with the brakes
		local brake = span(t, T.Brake, T.Stand)
		local v = speed * (1 - ease(brake))
		for _, s in streaks do
			s.z -= v * dt
			if s.z < -70 then
				s.z += 140
			end
			s.part.CFrame = carCF * CFrame.new(s.side * 5.7, 5.2, s.z)
			s.part.Transparency = brake
			s.part:FindFirstChildOfClass("PointLight").Brightness = 2.2 * (1 - brake)
		end
		for _, w in walls do
			w.Transparency = ease(span(t, T.Brake + 1.2, T.Stand + 0.6))
		end
		if rumble then
			rumble.Volume = 0.5 * span(t, 0.5, 3) * (1 - ease(brake))
			rumble.PlaybackSpeed = 1 - 0.35 * ease(brake)
		end
		shake = 0.05 * (1 - ease(brake)) + (if t > T.Brake and t < T.Stand then 0.07 * math.sin(brake * math.pi) else 0)

		once("open", T.Open, function()
			fade(1, 1.6)
		end)
		once("brake", T.Brake, function()
			Sounds.Play("TrainBrake", nil, { Volume = 0.7 })
			-- the car lights stutter as it comes in
			task.spawn(function()
				for _, gap in { 0.08, 0.3, 0.06, 0.5, 0.05 } do
					carLights(car, false)
					task.wait(gap)
					carLights(car, true)
					task.wait(0.12)
				end
			end)
		end)
		once("stand", T.Stand, function()
			Anims.Stop(char, "Intro_Seated", 0.25)
			Anims.Play(char, "Intro_Stand", { fade = 0.2 })
		end)
		once("cloak", T.Cloak, function()
			Anims.Play(char, "Intro_CloakToss", { fade = 0.12 })
		end)
		once("let", T.CloakLet, function()
			Sounds.Play("CloakWhoosh", nil, { Volume = 0.6 })
			if cloakHold and cloak then
				-- it leaves the shoulders: up, back along the car, turning
				local primary = cloakHold.Part1
				cloakHold:Destroy()
				for _, p in cloak:GetDescendants() do
					if p:IsA("BasePart") then
						p.Massless = false
					end
				end
				local away = (carCF * CFrame.new(0, 0, 1)).Position - carCF.Position
				primary.AssemblyLinearVelocity = away * 22 + Vector3.new(0, 16, 0) + carCF.RightVector * -4
				primary.AssemblyAngularVelocity = Vector3.new(3, 5, -4)
				task.delay(0.35, function()
					for _, p in cloak:GetDescendants() do
						if p:IsA("BasePart") then
							p.CanCollide = true
						end
					end
				end)
			end
		end)
		once("draw", T.Draw, function()
			Anims.Stop(char, "Intro_CloakToss", 0.15)
			Anims.Play(char, "Intro_Draw", { fade = 0.1 })
			task.delay(0.42, function()
				if holster then
					holster:Destroy()
					holster = nil
				end
				setHeldVisible(char, true)
			end)
		end)
		once("rack", T.Rack, function()
			Anims.Play(char, "Intro_Rack", { fade = 0.1 })
		end)
		once("click", T.RackClick, function()
			Sounds.Play("Rack", nil, { Volume = 0.9 })
			rackSlide(char)
		end)
		once("step", T.Step, function()
			Anims.Stop(char, "Intro_Stand", 0.25)
			local walk = Anims.Play(char, "Walk", { fade = 0.2 }) -- the root is carried, so the legs are ours to move
			task.delay(T.Behind - T.Step - 0.15, function()
				if walk then
					walk:Stop(0.25)
				end
			end)
		end)
		-- the step into the aisle (the root is ours to place: the server holds it anchored until "Done")
		if t >= T.Step then
			local u = ease(span(t, T.Step, T.Behind))
			root.CFrame = seatCF:Lerp(standCF, u)
		else
			root.CFrame = seatCF
		end

		-- the camera
		local from, at, fov
		if t < T.Close then
			local u = ease(span(t, T.Aisle, T.Close))
			from = Vector3.new(1.4, 5.4, sz - 34 + u * 9)
			at = Vector3.new(sx + 0.6, 3.4, sz)
			fov = 48
		elseif t < T.Stand then
			local u = span(t, T.Close, T.Stand)
			from = Vector3.new(sx + 4.6 - u * 0.9, 2.9, sz + 3.2 - u * 0.5)
			at = headSeated:Lerp(headSeated + Vector3.new(0.3, 0.25, 0), ease(span(t, T.Brake, T.Stand)))
			fov = 38
		elseif t < T.Draw then
			local u = ease(span(t, T.Stand, T.Draw))
			from = Vector3.new(sx + 5.8, 3.0 + u * 0.5, sz - 3.4 + u * 1.2)
			at = chest + Vector3.new(0, 0.4 + u * 0.3, 0)
			fov = 46
		elseif t < T.Step then
			local u = ease(span(t, T.Draw, T.Step))
			from = Vector3.new(sx + 3.4 - u * 0.6, 4.3, sz - 1.9)
			at = Vector3.new(sx + 0.7, 3.9, sz - 0.2)
			fov = 34
		else
			-- round behind to the shoulder the game is played over, then into the head
			local aim = Config.Aim.Ranged
			local rootCF = root.CFrame
			local shoulder = rootCF * CFrame.new(aim.ShoulderOffset + Vector3.new(0, 1.5, 0))
			local behind = (shoulder * CFrame.new(0, 0, aim.Distance)).Position
			local front = L(sx + 2.8, 4.3, sz - 1.9)
			local u = ease(span(t, T.Step, T.Push))
			-- swing out through the aisle side so the path does not cut the body
			local mid = (rootCF * CFrame.new(5.5, 3.2, 3)).Position
			local a = front:Lerp(mid, u)
			local b = mid:Lerp(behind, u)
			local pos = a:Lerp(b, u)
			local look = (rootCF.Position + Vector3.new(0, 1.6, 0)):Lerp(shoulder.Position + rootCF.LookVector * 30, u)
			local push = ease(span(t, T.Push, T.End))
			local head = rootCF.Position + Vector3.new(0, 1.5, 0)
			pos = pos:Lerp(head, push)
			cam.CFrame = CFrame.lookAt(pos, look:Lerp(head + rootCF.LookVector * 30, push))
			cam.FieldOfView = 46 + 24 * u
			from = nil
		end
		cam.CameraType = Enum.CameraType.Scriptable
		if from then
			local sway = Vector3.new(math.noise(t * 3.1, 0) * shake, math.noise(0, t * 2.7) * shake, 0)
			cam.CFrame = CFrame.lookAt(L(from.X, from.Y, from.Z) + sway, L(at.X, at.Y, at.Z))
			cam.FieldOfView = fov
		end
		if t > T.Step then
			letterbox(false)
		end
	end)
end

function Intro.Init(opts)
	hud, setFirstPerson = opts.Hud, opts.SetFirstPerson
	buildScreen()
	-- a returning conduit: the name, then the world
	local started = false
	showTitle(2.2)
	task.delay(3.4, function()
		if not started and not active then
			fade(1, 1.2)
		end
	end)
	Remotes.Intro.OnClientEvent:Connect(function(what, car, seatCF, carCF)
		if what == "Play" then
			started = true
			task.spawn(play, car, seatCF, carCF)
		elseif what == "Resume" then
			started = true
			cover.BackgroundTransparency = 0
			fade(1, 1.2)
			if setFirstPerson then
				setFirstPerson(true)
			end
		elseif what == "End" then
			-- the lift: dark, then the city
			fade(0, 0.5)
			task.delay(1.4, function()
				if setFirstPerson then
					setFirstPerson(false)
				end
				fade(1, 1.6)
			end)
		end
	end)
	_ = Lighting
end

return Intro
