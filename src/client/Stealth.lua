-- Stealth on the client (rules: shared/Stealth, server: server/Stealth).
--   * the light meter: how lit you are (the Exposure attribute the server sets), bottom left, only in a place
--     that is watched (the player's "Stealth" attribute);
--   * guards: a mark over each one that is starting to make you, and a wedge round the screen centre pointing at it;
--   * takedowns: when one is on offer the guard wears the key (X) and the word for it; X asks the server;
--   * crouch (C) and whistle (B);
--   * what a takedown, a broken lamp, sparks and a whistle look and sound like.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Rules = require(Shared:WaitForChild("Stealth"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Anims = require(Shared:WaitForChild("Anims"))
local Kit = require(script.Parent:WaitForChild("UI"))

local UI = Kit.Theme
local S = Config.Stealth
local player = Players.LocalPlayer

local Stealth = {}

local WORDS = { Rear = "TAKEDOWN", Drop = "DROP", Panel = "FUSE BOX", Rail = "LIVE RAIL", Ledge = "LEDGE" }
local SEGMENTS = 10

local gui
local meter, segments, noiseFill
local awareness = {} -- guard model -> { a, state }
local marks = {} -- guard model -> { gui, fill, frame }
local wedges = {}
local offer -- { guard, kind }
local prompt, promptWord
local crouched = false
local cinematic = false -- the camera is ours for a takedown

local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

function Stealth.Crouched()
	return crouched
end

function Stealth.SetCrouch(on)
	local _, char = myRoot()
	if not char or crouched == on then
		return
	end
	crouched = on
	Remotes.Crouch:FireServer(on)
end

-- ===== the light meter =====
local function buildMeter()
	meter = Kit.make("Frame", { Name = "LightMeter", Size = UDim2.fromOffset(150, 20), Position = UDim2.new(0, 28, 1, -150), BackgroundTransparency = 1, Visible = false }, gui)
	-- a small sun-and-shade glyph: a ring that fills
	local glyph = Kit.make("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = UI.Text, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, meter)
	Kit.corner(glyph, 6)
	segments = {}
	for i = 1, SEGMENTS do
		local seg = Kit.make("Frame", { Size = UDim2.fromOffset(9, 10), Position = UDim2.fromOffset(20 + (i - 1) * 12, 5), BackgroundColor3 = UI.Text, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, meter)
		segments[i] = seg
	end
	-- under it: how far your steps carry
	local track
	noiseFill, track = Kit.gauge(meter, UDim2.fromOffset(20, 18), UDim2.fromOffset(SEGMENTS * 12 - 3, 2), UI.Warn)
	track.BackgroundTransparency = 0.7
	noiseFill.Size = UDim2.fromScale(0, 1)
	meter:SetAttribute("Glyph", true)
	return glyph
end

local glyph
local function drawMeter(exposure, noise)
	local lit = math.clamp(exposure, 0, 1) * SEGMENTS
	for i, seg in segments do
		local on = math.clamp(lit - (i - 1), 0, 1)
		seg.BackgroundTransparency = 0.85 - on * 0.8
		seg.BackgroundColor3 = if i > SEGMENTS * 0.7 then UI.Warn:Lerp(UI.Text, 0.3) else UI.Text
	end
	if glyph then
		glyph.BackgroundTransparency = 0.75 - math.clamp(exposure, 0, 1) * 0.7
	end
	noiseFill.Size = UDim2.fromScale(math.clamp(noise / S.Noise.Sprint, 0, 1), 1)
end

-- ===== guard marks =====
local function colorFor(a, state)
	if state == "Alert" then
		return UI.Harm
	elseif state == "Search" or state == "Suspicious" or a >= S.SuspectAt then
		return UI.Warn
	end
	return UI.Text
end

local function markFor(model)
	local m = marks[model]
	if m then
		return m
	end
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then
		return nil
	end
	local bb = Kit.make("BillboardGui", { Name = "Awareness", Size = UDim2.fromOffset(26, 26), StudsOffset = Vector3.new(0, 2.6, 0), AlwaysOnTop = true, MaxDistance = 140, Adornee = head }, gui)
	-- a diamond that fills from the bottom
	local frame = Kit.make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, ClipsDescendants = true }, bb)
	Kit.make("UIStroke", { Color = UI.Text, Thickness = 1.5 }, frame)
	local fill = Kit.make("Frame", { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Text, BorderSizePixel = 0 }, frame)
	m = { gui = bb, frame = frame, fill = fill, stroke = frame:FindFirstChildOfClass("UIStroke") }
	marks[model] = m
	return m
end

local function clearMark(model)
	local m = marks[model]
	if m then
		m.gui:Destroy()
		marks[model] = nil
	end
end

local function wedge(i)
	local w = wedges[i]
	if not w then
		w = Kit.make("Frame", { Name = "Wedge", Size = UDim2.fromOffset(4, 30), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = UI.Text, BorderSizePixel = 0, Visible = false }, gui)
		Kit.corner(w, 2)
		wedges[i] = w
	end
	return w
end

local function drawGuards()
	local cam = workspace.CurrentCamera
	local root = myRoot()
	local n = 0
	for model, info in awareness do
		if not model.Parent or info.state == "Down" then
			clearMark(model)
			awareness[model] = nil
			continue
		end
		local a, state = info.a, info.state
		local show = a > 0.03 or state == "Search" or state == "Suspicious" or state == "Alert"
		if not show then
			clearMark(model)
			continue
		end
		local m = markFor(model)
		if m then
			local c = colorFor(a, state)
			local level = if state == "Alert" then 1 else a
			m.fill.Size = UDim2.fromScale(level, level)
			m.fill.BackgroundColor3, m.stroke.Color = c, c
		end
		-- the wedge: where it is, how sure it is
		local groot = model:FindFirstChild("HumanoidRootPart")
		if cam and root and groot and state ~= "Alert" and a > 0.03 then
			n += 1
			local w = wedge(n)
			local rel = cam.CFrame:VectorToObjectSpace(groot.Position - root.Position)
			local angle = math.atan2(rel.X, -rel.Z)
			local r = 90
			w.Position = UDim2.new(0.5, math.sin(angle) * r, 0.5, -math.cos(angle) * r)
			w.Rotation = math.deg(angle)
			w.Size = UDim2.fromOffset(4, 10 + a * 34)
			w.BackgroundColor3 = colorFor(a, state)
			w.BackgroundTransparency = 0.15
			w.Visible = true
		end
	end
	for i = n + 1, #wedges do
		wedges[i].Visible = false
	end
end

-- ===== the takedown on offer =====
local function buildPrompt()
	prompt = Kit.make("BillboardGui", { Name = "TakedownPrompt", Size = UDim2.fromOffset(170, 28), StudsOffset = Vector3.new(0, 0.6, 0), AlwaysOnTop = true, MaxDistance = 40, Enabled = false }, gui)
	local _, _, word = Kit.keyHint(prompt, "X", "TAKEDOWN", UDim2.fromOffset(0, 1))
	promptWord = word
end

local function findOffer()
	local root, char = myRoot()
	if not root or not player:GetAttribute("Stealth") or char:GetAttribute("Takedown") or char:GetAttribute("Cutscene") then
		return nil
	end
	local best, bestKind, bestD
	for _, model in CollectionService:GetTagged("Guard") do
		local groot = model:FindFirstChild("HumanoidRootPart")
		local info = awareness[model]
		if groot and model.Parent and not model:GetAttribute("Downed") and (not info or info.a < 1) then
			local d = (groot.Position - root.Position).Magnitude
			if d < 26 then
				local kind = Rules.TakedownKind(root.CFrame, groot.CFrame, model:GetAttribute("StealthState") or "Patrol")
				if kind and (not bestD or d < bestD) then
					best, bestKind, bestD = model, kind, d
				end
			end
		end
	end
	if best then
		return { guard = best, kind = bestKind }
	end
	return nil
end

local function drawOffer()
	offer = findOffer()
	if offer then
		prompt.Adornee = offer.guard:FindFirstChild("UpperTorso") or offer.guard:FindFirstChild("HumanoidRootPart")
		promptWord.Text = WORDS[offer.kind] or "TAKEDOWN"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

-- ===== effects =====
local function burst(position, color, count, speed)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.new(0.4, 0.4, 0.4)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.25, 0.7)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(count)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 14, 3
	light.Parent = anchor
	task.delay(0.12, function()
		light.Enabled = false
	end)
	Debris:AddItem(anchor, 1.5)
end

local function takedownCamera(char, guard, seconds)
	local cam = workspace.CurrentCamera
	local root = char:FindFirstChild("HumanoidRootPart")
	local groot = guard:FindFirstChild("HumanoidRootPart")
	if not (cam and root and groot) or cinematic then
		return
	end
	cinematic = true
	local oldType = cam.CameraType
	local mid = (root.Position + groot.Position) / 2 + Vector3.new(0, 1.2, 0)
	local side = (groot.Position - root.Position):Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.1 then side.Unit else root.CFrame.RightVector
	-- whichever side has room
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, guard }
	local dist = 9
	local function eye(sign)
		local to = side * sign * dist + Vector3.new(0, 2.5, 0)
		local hit = workspace:Raycast(mid, to, params)
		return if hit then mid + to.Unit * math.max(hit.Distance - 0.6, 2) else mid + to, hit and hit.Distance or 99
	end
	local a, da = eye(1)
	local b, db = eye(-1)
	local from = if da >= db then a else b
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(from, mid)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / seconds, 0, 1)
		cam.CFrame = CFrame.lookAt(from:Lerp(mid, u * 0.18), mid)
	end)
	task.delay(seconds, function()
		conn:Disconnect()
		cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
		cinematic = false
	end)
end

local ATTACK_ANIM = { Rear = "Takedown_Rear", Drop = "Takedown_Drop", Panel = "Takedown_Slam", Rail = "Takedown_Slam", Ledge = "Takedown_Slam" }
local VICTIM_ANIM = { Rear = "Takedown_RearVictim", Drop = "Takedown_DropVictim", Panel = "Takedown_SlamVictim", Rail = "Takedown_SlamVictim", Ledge = "Takedown_SlamVictim" }

local function onTakedown(kind, char, guard, spot, seconds)
	if typeof(char) ~= "Instance" or typeof(guard) ~= "Instance" then
		return
	end
	seconds = seconds or 1.6
	local a = Anims.Play(char, ATTACK_ANIM[kind] or "Takedown_Rear", { fade = 0.1 })
	if a then
		a:AdjustSpeed(1.6 / seconds) -- authored as 1.6 s of action (tools/anims)
	end
	local v = Anims.Play(guard, VICTIM_ANIM[kind] or "Takedown_RearVictim", { fade = 0.1 })
	if v then
		v:AdjustSpeed(1.6 / seconds)
	end
	local groot = guard:FindFirstChild("HumanoidRootPart")
	if char == player.Character then
		takedownCamera(char, guard, seconds)
	end
	if groot then
		task.delay(seconds * 0.55, function()
			Sounds.Play("Takedown", groot, { Volume = if kind == "Rear" then 0.35 else 0.8 })
			if not Sounds.Ids.Takedown then
				Sounds.Play("ImpactFlesh", groot, { Volume = if kind == "Rear" then 0.3 else 0.7 })
			end
		end)
	end
end

local function watchDowned(model)
	local function apply()
		if model:GetAttribute("Downed") then
			clearMark(model)
			awareness[model] = nil
			local hum = model:FindFirstChildOfClass("Humanoid")
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, tr in animator:GetPlayingAnimationTracks() do
					tr:Stop(0.2)
				end
			end
			Anims.Play(model, "Downed", { fade = 0.25 })
		end
	end
	model:GetAttributeChangedSignal("Downed"):Connect(apply)
	apply()
end

-- World events the main script forwards here. Returns true when it was one of ours.
function Stealth.World(kind, a, b, c, d, e)
	if kind == "Takedown" then
		onTakedown(a, b, c, d, e)
	elseif kind == "LightBreak" then
		Sounds.Play("BreakGlass", a, { Volume = 0.5, Pitch = 1.3 })
		burst(a, Color3.fromRGB(255, 240, 200), 24, 18)
	elseif kind == "Sparks" then
		Sounds.Play(if Sounds.Ids.Sparks then "Sparks" else "FlickerTick", a, { Volume = 0.9 })
		burst(a, Color3.fromRGB(150, 210, 255), 40, 26)
	elseif kind == "Whistle" then
		Sounds.Play("Whistle", a, { Volume = 0.7 })
	else
		return false
	end
	return true
end

-- Keys the main script forwards (returns true when used).
function Stealth.Key(key)
	if key == Enum.KeyCode.C then
		Stealth.SetCrouch(not crouched)
		return true
	elseif key == Enum.KeyCode.B then
		if player:GetAttribute("Stealth") then
			Remotes.Whistle:FireServer()
		end
		return true
	elseif key == Enum.KeyCode.X and offer then
		Remotes.Takedown:FireServer(offer.guard)
		return true
	end
	return false
end

function Stealth.Init(screenGui)
	gui = screenGui
	glyph = buildMeter()
	buildPrompt()
	Remotes.Stealth.OnClientEvent:Connect(function(list, noise)
		local seen = {}
		for _, row in list do
			local model = row[1]
			if typeof(model) == "Instance" then
				awareness[model] = { a = row[2] or 0, state = row[3] or "Patrol" }
				seen[model] = true
			end
		end
		for model in awareness do
			if not seen[model] then
				clearMark(model)
				awareness[model] = nil
			end
		end
		meter:SetAttribute("Noise", noise or 0)
	end)
	for _, model in CollectionService:GetTagged("Guard") do
		watchDowned(model)
	end
	CollectionService:GetInstanceAddedSignal("Guard"):Connect(watchDowned)

	local function onCharacter(char)
		crouched = false
		char:GetAttributeChangedSignal("Crouched"):Connect(function()
			crouched = char:GetAttribute("Crouched") == true
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local watched = player:GetAttribute("Stealth") == true
		meter.Visible = watched
		if not watched then
			if next(marks) then
				for model in marks do
					clearMark(model)
				end
				awareness = {}
			end
			for _, w in wedges do
				w.Visible = false
			end
			prompt.Enabled = false
			offer = nil
			return
		end
		local _, char = myRoot()
		drawMeter(char and char:GetAttribute("Exposure") or 0, meter:GetAttribute("Noise") or 0)
		drawGuards()
		acc += dt
		if acc >= 0.1 then
			acc = 0
			drawOffer()
		end
	end)
	_ = UserInputService
end

return Stealth
