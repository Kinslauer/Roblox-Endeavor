-- WorldFX (Phase 3): the moments the world sends that had no picture yet. Pure presentation.
--   * Barks - an enemy's first-sight line (NPCs sets the Bark attribute) as a speech bubble over its head,
--     only within hearing range: the "hear" half of unannounced encounters (design/gdd/raids.md §1)
--   * Dash - a warmonger's / rival's flicker-step: a streak from where it was to where it is, a shake if close
--   * Pod / Shipment - a re-entry pod or a crate coming down: a shake when it lands near you
--   * Downed / Revive / HillCaptured - colour pulses on the body / the ring
--   * Dust (WorldFX.Dust) - the ground answering a dodge, a landing, a heavy strike
--   * The cycle (workspace Cycle_Phase, server/Cycle.lua) - the hum and flickering lights of the warning,
--     the colour drain, the white-out; only for a body in the Conduit world (not the hideout, not the war)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CombatFX = require(script.Parent.CombatFX)
local CameraShake = require(script.Parent.CameraShake)

local WorldFX = {}

local player = Players.LocalPlayer
local HEAR_RANGE = 90 -- studs: a bark farther than this is not heard
local BUBBLE_SECONDS = 3.2
local DUST_RANGE = 120 -- studs: a puff farther than this is not drawn

-- ---------------------------------------------------------------------------------------------
-- Dust: the ground answering a body - a dodge, a landing, a heavy strike. `scale` ~1 = a heavy's
-- puff; a dodge is 0.5. One short burst from an anchored emitter that cleans itself up.
-- ---------------------------------------------------------------------------------------------
local Presentation = require(Shared:WaitForChild("Presentation"))
function WorldFX.Dust(position, scale)
	scale = scale or 1
	if typeof(position) ~= "Vector3" or scale <= 0 then
		return
	end
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if me and (me.Position - position).Magnitude > DUST_RANGE then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Transparency = true, false, false, false, 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Presentation.Swings.DustColor or Color3.fromRGB(150, 135, 110))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 3 * scale) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(6 * scale, 10 * scale)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 4
	e.Rate = 0
	e.LightInfluence = 1
	e.Parent = part
	part.Parent = workspace
	e:Emit(math.clamp(math.floor(10 * scale + 0.5), 4, 30))
	Debris:AddItem(part, 1)
end

local function myPosition()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function distanceTo(position)
	local me = myPosition()
	return me and (me - position).Magnitude or math.huge
end

-- ---------------------------------------------------------------------------------------------
-- Barks
-- ---------------------------------------------------------------------------------------------
local function bubble(model, text)
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bark")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bark"
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = UDim2.fromOffset(240, 36), Vector3.new(0, 3.2, 0), false, HEAR_RANGE
	local frame = Instance.new("Frame")
	frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(10, 10, 14), 0.35, 0
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.TextColor3, label.Font, label.TextScaled = Color3.fromRGB(235, 235, 240), Enum.Font.SourceSansItalic, true
	label.Parent = frame
	gui.Parent = head
	Debris:AddItem(gui, BUBBLE_SECONDS)
end

local function watchBarks(model)
	model:GetAttributeChangedSignal("Bark"):Connect(function()
		local raw = model:GetAttribute("Bark")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(raw) ~= "string" or not root or distanceTo(root.Position) > HEAR_RANGE then
			return
		end
		bubble(model, (raw:gsub("|.*$", "")))
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Moments
-- ---------------------------------------------------------------------------------------------
local function streak(from, to, color)
	local d = to - from
	if d.Magnitude < 1 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CastShadow = true, false, false, false
	part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.2
	part.Size = Vector3.new(0.6, 0.6, d.Magnitude)
	part.CFrame = CFrame.lookAt(from + d / 2 + Vector3.new(0, 1.5, 0), to + Vector3.new(0, 1.5, 0))
	if CombatFX.Spawn(part, 0.4) then
		TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(0.1, 0.1, d.Magnitude) }):Play()
	end
end

-- ---------------------------------------------------------------------------------------------
-- The cycle
-- ---------------------------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local PC = Presentation.Cycle
local cycle = { lights = {}, t0 = 0 }

local function inWorld()
	local zone = player:GetAttribute("Zone")
	return zone ~= "Hideout" and zone ~= "Range"
end

local function gatherLights()
	local me = myPosition()
	local list = {}
	if not me then
		return list
	end
	for _, folderName in { "District", "Regions" } do
		local f = workspace:FindFirstChild(folderName)
		if f then
			for _, d in f:GetDescendants() do
				if (d:IsA("PointLight") or d:IsA("SpotLight")) and d.Enabled and d.Parent:IsA("BasePart") and (d.Parent.Position - me).Magnitude <= PC.LightRadius then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

local function stopCycleFX()
	if cycle.conn then
		cycle.conn:Disconnect()
		cycle.conn = nil
	end
	for _, l in cycle.lights do
		if l.Parent then
			l.Enabled = true
		end
	end
	table.clear(cycle.lights)
	if cycle.hum then
		cycle.hum:Destroy()
		cycle.hum = nil
	end
	if cycle.cc then
		local cc = cycle.cc
		cycle.cc = nil
		TweenService:Create(cc, TweenInfo.new(0.6), { Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
		Debris:AddItem(cc, 0.7)
	end
end

local function whiteFrame()
	if cycle.white and cycle.white.Parent then
		return cycle.white
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CycleWhiteout"
	gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 100
	local f = Instance.new("Frame")
	f.Size, f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = UDim2.fromScale(1, 1), PC.Whiteout.Color, 1, 0
	f.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	cycle.white = f
	return f
end

-- Warning: the hum rises and the lights around you start to fail, more and more of them.
local function startWarning()
	stopCycleFX()
	if not inWorld() then
		return
	end
	cycle.t0 = os.clock()
	cycle.lights = gatherLights()
	local hum = Instance.new("Sound")
	hum.SoundId, hum.Looped = PC.Hum.SoundId, PC.Hum.Looped
	hum.Volume, hum.PlaybackSpeed = PC.Hum.StartVolume, PC.Hum.StartSpeed
	hum.Parent = workspace.CurrentCamera or workspace
	hum:Play()
	cycle.hum = hum
	TweenService:Create(hum, TweenInfo.new(Config.Cycle.WarningSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = PC.Hum.PeakVolume, PlaybackSpeed = PC.Hum.PeakSpeed }):Play()
	local acc = 0
	cycle.conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < PC.FlickerEvery then
			return
		end
		acc = 0
		local a = math.clamp((os.clock() - cycle.t0) / Config.Cycle.WarningSeconds, 0, 1)
		local share = PC.FlickerShare.Start + (PC.FlickerShare.Peak - PC.FlickerShare.Start) * a * a
		for _, l in cycle.lights do
			if l.Parent and l.Enabled and math.random() < share then
				l.Enabled = false
				task.delay(PC.FlickerOff * (0.5 + math.random()), function()
					if l.Parent then
						l.Enabled = true
					end
				end)
			end
		end
	end)
end

-- The last seconds: colour drains, the camera trembles.
local function startDrain()
	if not inWorld() then
		return
	end
	if not cycle.conn then
		startWarning() -- joined late, or the server skipped straight here
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CycleDrain"
	cc.Parent = Lighting
	cycle.cc = cc
	local secs = Config.Cycle.FlickerSeconds
	TweenService:Create(cc, TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.In), PC.Drain):Play()
	task.spawn(function()
		local t = 0
		while t < secs and cycle.cc == cc do
			CameraShake.Add(PC.Shake)
			task.wait(1)
			t += 1
		end
	end)
end

local function whiteout()
	if not inWorld() then
		return
	end
	local f = whiteFrame()
	TweenService:Create(f, TweenInfo.new(PC.Whiteout.In), { BackgroundTransparency = 0 }):Play()
end

local function stable()
	stopCycleFX()
	local f = cycle.white
	if f and f.Parent and f.BackgroundTransparency < 1 then
		TweenService:Create(f, TweenInfo.new(PC.Whiteout.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end
end

local function onCyclePhase()
	local phase = workspace:GetAttribute("Cycle_Phase")
	if phase == "Warning" then
		startWarning()
	elseif phase == "Flicker" then
		startDrain()
	elseif phase == "Whiteout" then
		whiteout()
	else
		stable()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Anomalies (server/Clues.lua): something that came back wrong this cycle, marking a fragment. Drawn
-- glitching; hidden, with its fragment, from a conduit who doesn't know enough yet (the Needs attribute).
-- ---------------------------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local anomalies = {}
local function known()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Knowledge") or "[]")
	local set = {}
	for _, id in (ok and type(list) == "table") and list or {} do
		set[id] = true
	end
	return set
end
local function canSee(inst, set)
	local needs = inst:GetAttribute("Needs")
	if type(needs) ~= "string" or needs == "" then
		return true
	end
	for id in needs:gmatch("[^,]+") do
		if not set[id] then
			return false
		end
	end
	return true
end
local function refreshClues()
	local set = known()
	local folder = workspace:FindFirstChild("Clues")
	for _, d in folder and folder:GetChildren() or {} do
		if d:IsA("BasePart") then
			local visible = canSee(d, set)
			d.LocalTransparencyModifier = if visible then 0 else 1
			local prompt = d:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = visible
			end
		end
	end
end
local function animateAnomalies()
	for part, base in anomalies do
		if not part.Parent then
			anomalies[part] = nil
		elseif part.LocalTransparencyModifier < 1 then
			local kind = part:GetAttribute("Kind")
			local jitter = if kind == "Static" then 0.25 elseif kind == "Echo" then 0.12 else 0.05
			part.CFrame = base * CFrame.new(math.random() * jitter - jitter / 2, math.random() * jitter - jitter / 2, 0)
			part.Transparency = if math.random() < 0.15 then 0.95 else 0.45 + math.random() * 0.35
			if kind == "Echo" then
				part.Color = Color3.fromRGB(110 + math.random(0, 40), 120, 160)
			end
		end
	end
end
local function trackAnomaly(part)
	if part:IsA("BasePart") then
		anomalies[part] = part.CFrame
		task.defer(refreshClues)
	end
end

function WorldFX.CycleState()
	return { lights = #cycle.lights, humming = cycle.hum ~= nil, drained = cycle.cc ~= nil, white = cycle.white and cycle.white.BackgroundTransparency or 1 }
end

local function feetOf(model)
	local root = typeof(model) == "Instance" and model:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - Vector3.new(0, 2.8, 0)) or nil
end

function WorldFX.Init()
	-- the ground answers: a dodge, an enemy step, a launched body landing
	CombatFX.On("Dodge", function(model)
		WorldFX.Dust(feetOf(model), 0.5)
	end)
	CombatFX.On("EnemyStep", function(model)
		WorldFX.Dust(feetOf(model), 0.7)
	end)
	CombatFX.On("Land", function(model)
		WorldFX.Dust(feetOf(model), 1.1)
	end)
	CombatFX.On("Dash", function(model, info)
		if type(info) ~= "table" or typeof(info.from) ~= "Vector3" or typeof(info.to) ~= "Vector3" then
			return
		end
		local isRival = typeof(model) == "Instance" and model:GetAttribute("EnemyType") == "Rival"
		streak(info.from, info.to, if isRival then Color3.fromRGB(80, 220, 220) else Color3.fromRGB(255, 80, 80))
		if distanceTo(info.to) < 14 then
			CameraShake.Add(0.35)
		end
	end)
	CombatFX.On("Pod", function(pod)
		if typeof(pod) ~= "Instance" then
			return
		end
		task.delay(Config.War.PodFallSeconds, function()
			if pod.Parent and distanceTo(pod.Position) < 40 then
				CameraShake.Add(0.5)
			end
		end)
	end)
	CombatFX.On("Downed", function(victim)
		CombatFX.Flash(victim, Color3.fromRGB(255, 60, 60), 0.8)
		if victim == player.Character then
			CameraShake.Add(0.6)
		end
	end)
	CombatFX.On("Revive", function(victim)
		CombatFX.Flash(victim, Color3.fromRGB(120, 255, 160), 0.8)
	end)
	CombatFX.On("Shipment", function(char)
		CombatFX.Flash(char, Color3.fromRGB(255, 220, 120), 0.6)
	end)
	CombatFX.On("HillCaptured", function(ring, sideId)
		if typeof(ring) ~= "Instance" then
			return
		end
		local color
		for _, f in Config.War.Factions do
			if f.Id == sideId then
				color = f.Color
			end
		end
		local h = Instance.new("Highlight")
		h.FillColor, h.FillTransparency, h.OutlineColor = color or Color3.new(1, 1, 1), 0.2, color or Color3.new(1, 1, 1)
		h.Parent = ring
		Debris:AddItem(h, 1.5)
	end)
	workspace:GetAttributeChangedSignal("Cycle_Phase"):Connect(onCyclePhase)
	-- anomalies and the fragments they mark
	for _, p in CollectionService:GetTagged("Anomaly") do
		trackAnomaly(p)
	end
	CollectionService:GetInstanceAddedSignal("Anomaly"):Connect(trackAnomaly)
	player:GetAttributeChangedSignal("Knowledge"):Connect(refreshClues)
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "Clues" then
			c.ChildAdded:Connect(function()
				task.defer(refreshClues)
			end)
		end
	end)
	local cluesFolder = workspace:FindFirstChild("Clues")
	if cluesFolder then
		cluesFolder.ChildAdded:Connect(function()
			task.defer(refreshClues)
		end)
	end
	local glitchAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		glitchAcc += dt
		if glitchAcc >= 0.08 then
			glitchAcc = 0
			animateAnomalies()
		end
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if not inWorld() then
			stable() -- walked into the hideout or deployed: the world's ending isn't yours
		end
	end)
	-- barks on every fighter, present and future
	for _, model in CollectionService:GetTagged("Combatant") do
		watchBarks(model)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(watchBarks)
end

return WorldFX
