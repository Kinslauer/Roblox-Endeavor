-- The first link, as the recruit sees it (server: war/server/Intro.lua + Simulation.lua). Nothing
-- explains itself: the view jolts awake in fluid, darts about, cuts to flashes of the war world it
-- remembers, then settles; the drain, the unlatch, the drop, the barracks and the simulation read
-- through light, colour and terse machine lines only.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local IntroFx = {}
IntroFx.Active = false -- true from the tank to the drop; Main reads it (sprint and mantle still work)

local env -- { Hud = ScreenGui }
local gui, cover, line, sub
local blur, grade
local saved -- Lighting as the Front left it
local fluid -- the tank's fluid part (server-tweened while it drains)
local frantic = 0 -- 1 = full panic, 0 = calm; drives the scripted wake camera
local scripted = false
local look = { yaw = 0, pitch = 0, tyaw = 0, tpitch = 0, next = 0 }
local cutCF -- while set, the camera shows a memory instead of the tank

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tween(inst, seconds, props, style)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function ensureGui()
	if gui then
		return
	end
	gui = make("ScreenGui", { Name = "IntroFx", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 }, player:WaitForChild("PlayerGui"))
	cover = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, gui)
	line = make("TextLabel", { Size = UDim2.new(1, -48, 0, 18), Position = UDim2.new(0, 24, 1, -112), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(150, 235, 225),
		Font = Enum.Font.RobotoMono, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 3 }, gui)
	sub = make("TextLabel", { Size = UDim2.new(1, -48, 0, 14), Position = UDim2.new(0, 24, 1, -92), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(110, 170, 165),
		Font = Enum.Font.RobotoMono, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 3 }, gui)
end

-- types a machine line, character by character
local typeToken = 0
local function say(text, keys, hold)
	ensureGui()
	typeToken += 1
	local token = typeToken
	line.TextTransparency, sub.TextTransparency = 0, if keys then 0.15 else 1
	sub.Text = keys and ("[ " .. keys .. " ]") or ""
	task.spawn(function()
		for i = 1, #text do
			if token ~= typeToken then
				return
			end
			line.Text = text:sub(1, i)
			task.wait(0.022)
		end
		if hold then
			task.wait(hold)
			if token == typeToken then
				tween(line, 0.6, { TextTransparency = 1 })
				tween(sub, 0.6, { TextTransparency = 1 })
			end
		end
	end)
end

local function flash(color, from, seconds)
	ensureGui()
	cover.BackgroundColor3 = color
	cover.BackgroundTransparency = from
	tween(cover, seconds, { BackgroundTransparency = 1 })
end

local function hud(on)
	if env and env.Hud then
		env.Hud.Enabled = on
	end
end

local function ash(on)
	local holder = workspace:FindFirstChild("AshFall")
	local emitter = holder and holder:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Enabled = on
	end
end

-- ===== lighting: the tank, the barracks, the simulation, each on this client only =====
local LIGHT_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogEnd", "FogStart", "FogColor", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local function saveLighting()
	if saved then
		return
	end
	saved = {}
	for _, k in LIGHT_KEYS do
		saved[k] = Lighting[k]
	end
	saved.Hidden = {}
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("Clouds") then
			table.insert(saved.Hidden, c)
			c.Parent = nil
		end
	end
	blur = make("BlurEffect", { Name = "IntroBlur", Size = 0 }, Lighting)
	grade = make("ColorCorrectionEffect", { Name = "IntroGrade" }, Lighting)
end

local function restoreLighting()
	if not saved then
		return
	end
	for _, k in LIGHT_KEYS do
		Lighting[k] = saved[k]
	end
	for _, c in saved.Hidden do
		c.Parent = Lighting
	end
	local sky = Lighting:FindFirstChild("IntroSky")
	if sky then
		sky:Destroy()
	end
	if blur then
		blur:Destroy()
	end
	if grade then
		grade:Destroy()
	end
	blur, grade, saved = nil, nil, nil
end

local function indoorLight()
	Lighting.ClockTime, Lighting.Brightness = 0, 0
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(46, 50, 54), Color3.fromRGB(30, 32, 36)
	Lighting.FogStart, Lighting.FogEnd = 0, 100000
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.2, 0.2
end

local function simLight()
	Lighting.ClockTime, Lighting.Brightness = 0, 0
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(40, 70, 90), Color3.fromRGB(30, 60, 80)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(2, 8, 16), 60, 420
	if not Lighting:FindFirstChild("IntroSky") then
		make("Sky", { Name = "IntroSky", StarCount = 0, CelestialBodiesShown = false }, Lighting)
	end
	if grade then
		grade.TintColor, grade.Contrast, grade.Saturation, grade.Brightness = Color3.fromRGB(200, 240, 255), 0.18, -0.2, 0
	end
	if blur then
		blur.Size = 0
	end
end

-- ===== the wake: a scripted head camera that darts, then settles =====
local function headCF()
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if head and root then
		local flat = root.CFrame.LookVector
		return CFrame.lookAt(head.Position + Vector3.new(0, 0.2, 0), head.Position + Vector3.new(0, 0.2, 0) + flat)
	end
	return camera.CFrame
end

local function wakeCamera(dt)
	if not scripted then
		return
	end
	if cutCF then
		camera.CFrame = cutCF
		return
	end
	local now = os.clock()
	if now >= look.next then
		-- darting: a new place to look, sooner and wider the more panicked
		look.next = now + rng:NextNumber(0.1, 0.32) / math.max(0.25, frantic)
		look.tyaw = rng:NextNumber(-75, 75) * frantic
		look.tpitch = rng:NextNumber(-25, 40) * frantic
	end
	local k = math.min(1, dt * (6 + 16 * frantic))
	look.yaw += (look.tyaw - look.yaw) * k
	look.pitch += (look.tpitch - look.pitch) * k
	local shake = 2.2 * frantic
	local breathe = math.sin(now * 1.6) * 1.2
	camera.CFrame = headCF() * CFrame.Angles(math.rad(look.pitch + breathe + rng:NextNumber(-shake, shake)), math.rad(look.yaw + rng:NextNumber(-shake, shake)), math.rad(rng:NextNumber(-shake, shake) * 0.6))
	camera.FieldOfView = 70 + 24 * frantic + math.sin(now * 9) * 4 * frantic
end

-- fluid: tinted and blurred while the eyes are under it; bubbles rise past the face
local lastBubble = 0
local function underFluid()
	if not (fluid and fluid.Parent) then
		return false
	end
	local top = fluid.Position.Y + fluid.Size.X / 2
	return camera.CFrame.Position.Y < top and fluid.Size.X > 0.5
end

local function fluidFx()
	if not (IntroFx.Active and grade and fluid) then
		return
	end
	local under = underFluid()
	if cutCF then
		return
	end
	if under then
		grade.TintColor = Color3.fromRGB(150, 235, 225)
		grade.Saturation, grade.Contrast = -0.25, 0.1
		blur.Size = math.max(blur.Size, 6)
		if os.clock() - lastBubble > 0.06 then
			lastBubble = os.clock()
			local at = camera.CFrame.Position + camera.CFrame.LookVector * rng:NextNumber(1, 3) + Vector3.new(rng:NextNumber(-1.2, 1.2), -1.5, rng:NextNumber(-1.2, 1.2))
			local b = make("Part", { Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.06, 0.22), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
				Material = Enum.Material.Glass, Color = Color3.fromRGB(220, 255, 250), Transparency = 0.4, CastShadow = false, Position = at }, workspace)
			tween(b, 1.2, { Position = at + Vector3.new(rng:NextNumber(-0.3, 0.3), 3.5, rng:NextNumber(-0.3, 0.3)), Transparency = 1 }, Enum.EasingStyle.Linear)
			Debris:AddItem(b, 1.3)
		end
	else
		grade.TintColor = Color3.new(1, 1, 1)
		grade.Saturation, grade.Contrast = 0, 0.05
	end
end

-- flashes of what the clone always knew: the war world itself, seen from where it stands
local function memoryViews(n)
	local views = {}
	local front = workspace:FindFirstChild("Front")
	local pool = {}
	if front then
		for _, d in front:GetDescendants() do
			if d:IsA("BasePart") and d.Size.Magnitude > 8 and d.Transparency < 0.9 and d.Position.Y < 600 then
				table.insert(pool, d)
				if #pool > 400 then
					break
				end
			end
		end
	end
	for _ = 1, n do
		local subject = #pool > 0 and pool[rng:NextInteger(1, #pool)]
		local at = if subject then subject.Position else Vector3.new(rng:NextNumber(-500, 500), 20, rng:NextNumber(-400, 400))
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(12, 40)
		local from = at + Vector3.new(math.cos(a) * dist, rng:NextNumber(3, 9), math.sin(a) * dist)
		table.insert(views, CFrame.lookAt(from, at + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2, 3), rng:NextNumber(-4, 4))) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))))
	end
	return views
end

local function remember(seconds)
	-- the jolt holds, then the memories sync: cuts of the war world between white frames
	local views = memoryViews(8)
	local saturation = grade and grade.Saturation
	Sounds.Play("SyncRise", nil, { Volume = 0.7 })
	for i, cf in views do
		if not IntroFx.Active then
			break
		end
		flash(Color3.new(1, 1, 1), 0.1, 0.12)
		cutCF = cf
		if grade then
			grade.TintColor, grade.Saturation, grade.Contrast = Color3.fromRGB(255, 236, 210), -0.6, 0.35
		end
		if blur then
			blur.Size = 2
		end
		camera.FieldOfView = rng:NextNumber(55, 85)
		Lighting.ClockTime, Lighting.Brightness = saved and saved.ClockTime or 7.5, saved and saved.Brightness or 1.5
		Lighting.FogEnd = saved and saved.FogEnd or 900
		task.wait(seconds / #views * (0.6 + i / #views * 0.6))
	end
	cutCF = nil
	indoorLight()
	if grade then
		grade.Saturation = saturation or 0
	end
	flash(Color3.new(1, 1, 1), 0, 0.9)
	Sounds.Play("SyncSettle", nil, { Volume = 0.6 })
end

-- ===== stages =====
local recruitNo = 0
local STAGES = {}

function STAGES.Wake(data)
	IntroFx.Active = true
	fluid = data.Fluid
	recruitNo = tonumber(data.Recruit) or 1
	ensureGui()
	saveLighting()
	indoorLight()
	hud(false)
	ash(false)
	-- black, then the jolt: eyes open into fluid, panicked
	cover.BackgroundColor3, cover.BackgroundTransparency = Color3.new(0, 0, 0), 0
	scripted, frantic = true, 0
	camera.CameraType = Enum.CameraType.Scriptable
	blur.Size = 24
	local seconds = tonumber(data.Seconds) or 10
	task.spawn(function()
		task.wait(0.6)
		Sounds.Play("TankGasp", nil, { Volume = 1 })
		frantic = 1
		cover.BackgroundTransparency = 0.25
		tween(cover, 0.35, { BackgroundTransparency = 1 })
		tween(blur, seconds * 0.35, { Size = 8 })
		-- heartbeat: each thud dims the edges a little
		task.spawn(function()
			local beat = 0.32
			while IntroFx.Active and scripted do
				Sounds.Play("Heartbeat", nil, { Volume = 0.35 + 0.5 * frantic })
				cover.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
				cover.BackgroundTransparency = 1 - 0.25 * frantic
				tween(cover, 0.25, { BackgroundTransparency = 1 })
				task.wait(beat + (1 - frantic) * 0.7)
			end
		end)
		task.wait(seconds * 0.38)
		if not IntroFx.Active then
			return
		end
		remember(seconds * 0.28)
		-- then the calm of any other day
		local calmFrom = os.clock()
		while IntroFx.Active and os.clock() - calmFrom < seconds * 0.2 do
			frantic = math.max(0.08, 1 - (os.clock() - calmFrom) / (seconds * 0.15))
			task.wait()
		end
		frantic = 0.06
		tween(blur, 1.5, { Size = 2 })
		say("> STACK SYNC . . . 100%", nil, 2.5)
		task.wait(1.8)
		say(("> RECRUIT %03d . . . RESIDENT"):format(recruitNo % 1000), nil, 2.5)
		task.wait(0.4)
		-- hand the eyes back: free look inside the tank
		scripted = false
		camera.CameraType = Enum.CameraType.Custom
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		tween(camera, 1, { FieldOfView = 70 })
	end)
end

function STAGES.Drain()
	Sounds.Play("TankDrain", nil, { Volume = 0.8 })
	say("> FLUID PURGE", nil, 2)
end

function STAGES.Unlatch()
	Sounds.Play("Unlatch", nil, { Volume = 0.9 })
	-- a shove in the spine as the cables let go
	local cf = camera.CFrame
	camera.CFrame = cf * CFrame.Angles(math.rad(-6), 0, math.rad(rng:NextNumber(-4, 4)))
	if blur then
		blur.Size = 0
	end
end

function STAGES.Chute()
	Sounds.Play("ChuteDrop", nil, { Volume = 0.9 })
	fluid = nil
	if grade then
		grade.TintColor, grade.Saturation, grade.Contrast = Color3.new(1, 1, 1), 0, 0.05
	end
end

local fitTotal = 0
function STAGES.Barracks(data)
	fitTotal = tonumber(data.Total) or 0
	hud(true)
	camera.FieldOfView = 70
	say(("> SUPPLY . . . 0/%d"):format(fitTotal), "X", nil)
end

function STAGES.Equip(data)
	Sounds.Play("Rack", nil, { Volume = 0.5 })
	say(("> SUPPLY . . . %d/%d"):format(tonumber(data.Taken) or 0, tonumber(data.Total) or fitTotal), "X", nil)
end

function STAGES.Equipped()
	say("> SUPPLY . . . COMPLETE", nil, 2)
end

function STAGES.Link(data)
	local seconds = tonumber(data.Seconds) or 3
	say("> SIM LINK . . .", nil, seconds)
	Sounds.Play("SimLink", nil, { Volume = 0.8 })
	ensureGui()
	task.spawn(function()
		-- static: the room stutters out, then white
		local untilT = os.clock() + seconds * 0.7
		while os.clock() < untilT and IntroFx.Active do
			cover.BackgroundColor3 = if rng:NextNumber() < 0.5 then Color3.fromRGB(120, 230, 255) else Color3.new(0, 0, 0)
			cover.BackgroundTransparency = rng:NextNumber(0.3, 0.9)
			if blur then
				blur.Size = rng:NextNumber(0, 14)
			end
			task.wait(0.05)
		end
		cover.BackgroundColor3 = Color3.new(1, 1, 1)
		tween(cover, seconds * 0.3, { BackgroundTransparency = 0 })
	end)
end

function STAGES.Sim()
	simLight()
	ensureGui()
	cover.BackgroundColor3 = Color3.new(1, 1, 1)
	cover.BackgroundTransparency = 0
	tween(cover, 1.4, { BackgroundTransparency = 1 })
end

function STAGES.Drill(data)
	local text = ("> DRILL %d/%d . %s . %d/%d"):format(tonumber(data.Index) or 0, tonumber(data.Total) or 0, tostring(data.Name), tonumber(data.Done) or 0, tonumber(data.Need) or 0)
	say(text, tostring(data.Keys or ""), nil)
end

function STAGES.DrillDone(data)
	Sounds.Play("SimClear", nil, { Volume = 0.7 })
	say(("> %s . . . CLEAR"):format(tostring(data.Name)), nil, nil)
	flash(Color3.fromRGB(120, 235, 255), 0.7, 0.5)
end

function STAGES.Desync()
	Sounds.Play("SimLink", nil, { Volume = 0.6, Pitch = 1.4 })
	flash(Color3.fromRGB(255, 60, 60), 0.2, 0.8)
	if grade then
		grade.Saturation = -1
		tween(grade, 0.9, { Saturation = -0.2 })
	end
	if blur then
		blur.Size = 18
		tween(blur, 0.8, { Size = 0 })
	end
	say("> DESYNC . . . RELOAD", nil, 1.5)
end

function STAGES.SimDone()
	say("> SIMULATION . . . COMPLETE", nil, 2)
end

function STAGES.Done(data)
	local seconds = tonumber(data.Seconds) or 4
	Sounds.Play("SimLink", nil, { Volume = 0.8, Pitch = 0.8 })
	ensureGui()
	cover.BackgroundColor3 = Color3.new(1, 1, 1)
	tween(cover, seconds * 0.8, { BackgroundTransparency = 0 })
	say("> LINK 1/1 . . . FRONT", nil, seconds)
end

function STAGES.Landed()
	IntroFx.Active = false
	scripted, cutCF, fluid = false, nil, nil
	restoreLighting()
	hud(true)
	ash(true)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	ensureGui()
	cover.BackgroundColor3 = Color3.new(1, 1, 1)
	cover.BackgroundTransparency = 0
	tween(cover, 2.2, { BackgroundTransparency = 1 })
end

-- ===== the simulation's breakage, drawn here =====
local function shatter(position, size, quiet)
	local n = if quiet then 3 else 6
	for _ = 1, n do
		local s = size * rng:NextNumber(0.18, 0.4)
		local frag = make("Part", { Name = "SimShard", Size = Vector3.new(s, s, s), CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * size * 0.3) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(110, 220, 255), Transparency = 0.2, CastShadow = false }, workspace)
		frag.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(6, 22), rng:NextNumber(-14, 14))
		frag.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		tween(frag, 1.1, { Transparency = 1, Size = Vector3.new(s, s, s) * 0.3 }, Enum.EasingStyle.Linear)
		Debris:AddItem(frag, 1.2)
	end
	Sounds.Play(if quiet then "SimBreakSoft" else "SimBreak", position, { Volume = if quiet then 0.4 else 0.8 })
end

function IntroFx.Init(options)
	env = options or {}
	RunService:BindToRenderStep("IntroWakeCamera", (Enum.RenderPriority.Camera.Value or 200) + 2, wakeCamera)
	RunService.RenderStepped:Connect(function()
		fluidFx()
	end)
	Remotes.Tutorial.OnClientEvent:Connect(function(place, stage, data)
		if place ~= "Front" then
			return
		end
		local fn = STAGES[stage]
		if fn then
			fn(type(data) == "table" and data or {})
		end
	end)
	Remotes.World.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "SimBreak" and typeof(a) == "Vector3" then
			shatter(a, tonumber(b) or 4, c == true)
		elseif kind == "SimCollapse" then
			Sounds.Play("Collapse", typeof(a) == "Vector3" and a or nil, { Volume = 1, Pitch = 1.3 })
		end
	end)
end

return IntroFx
