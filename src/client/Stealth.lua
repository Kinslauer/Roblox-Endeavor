-- Stealth on the client (rules: shared/Stealth, server: server/Stealth).
--   * the light gem: how lit you are (the Exposure attribute the server sets), bottom right, only in a place
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

local WORDS = { Rear = "TAKEDOWN", Drop = "DROP", Panel = "FUSE BOX", Rail = "LIVE RAIL", Ledge = "LEDGE", Throw = "THROW", Search = "SEARCH" }
local Q = S.Cqc

local gui
local meter, noiseFill
local awareness = {} -- guard model -> { a, state }
local marks = {} -- guard model -> { gui, fill, frame }
local wedges = {}
local offer -- { guard, kind }
local prompt, promptWord
local crouched = false
local asked = {} -- guard model -> true once he has talked (weak keys)
setmetatable(asked, { __mode = "k" })
local cinematic = false -- the camera is ours for a takedown

local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

function Stealth.Crouched()
	return crouched
end

-- ===== the light gem =====
-- One small diamond, bottom right above the gun's count: dark when you are hidden, bright when you are lit. The
-- hairline under it is how far your steps carry. (It was a ten-segment bar on the left; owner, 2026-11-11: cluttered.)
local function buildMeter()
	meter = Kit.make("Frame", { Name = "LightMeter", Size = UDim2.fromOffset(28, 34), Position = UDim2.new(1, -62, 1, -118), BackgroundTransparency = 1, Visible = false }, gui)
	local gem = Kit.make("Frame", { Name = "Gem", Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(7, 5), Rotation = 45, BackgroundColor3 = UI.Text, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, meter)
	Kit.make("UIStroke", { Name = "Edge", Color = UI.Text, Transparency = 0.45, Thickness = 1 }, gem)
	local track
	noiseFill, track = Kit.gauge(meter, UDim2.fromOffset(2, 30), UDim2.fromOffset(24, 2), UI.Warn)
	track.BackgroundTransparency = 0.8
	noiseFill.Size = UDim2.fromScale(0, 1)
	return gem
end

local glyph
local function drawMeter(exposure, noise)
	local lit = math.clamp(exposure, 0, 1)
	if glyph then
		glyph.BackgroundTransparency = 0.92 - lit * 0.9
		glyph.BackgroundColor3 = if lit > 0.7 then UI.Warn:Lerp(UI.Text, 0.3) else UI.Text
	end
	meter:SetAttribute("Lit", lit)
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
	Kit.Board(bb)
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
	prompt = Kit.make("BillboardGui", { Name = "TakedownPrompt", Size = UDim2.fromOffset(250, 28), StudsOffset = Vector3.new(0, 0.6, 0), AlwaysOnTop = true, MaxDistance = 40, Enabled = false }, gui)
	local _, _, word = Kit.keyHint(prompt, "X", "TAKEDOWN", UDim2.fromOffset(0, 1))
	promptWord = word
	Kit.Board(prompt)
end

-- What X would do now: { guard, tap, hold } (words from Rules.Cqc; a body offers only hold = "Carry"),
-- or { mode = "Hold" | "Carry" } while your hands are already full.
local function findOffer()
	local root, char = myRoot()
	if not root or char:GetAttribute("Takedown") or char:GetAttribute("Cutscene") then
		return nil
	end
	if char:GetAttribute("NeckHold") then
		return { mode = "Hold", asked = asked[Stealth.HeldGuard or false] == true }
	elseif char:GetAttribute("Carrying") then
		local dragged = Stealth.DraggedGuard
		local droot = dragged and dragged:FindFirstChild("HumanoidRootPart")
		return { mode = "Carry", emptied = droot ~= nil and droot:GetAttribute("Looted") == true }
	end
	if not player:GetAttribute("Stealth") then
		return nil
	end
	local best, bestD
	for _, model in CollectionService:GetTagged("Guard") do
		local groot = model:FindFirstChild("HumanoidRootPart")
		if groot and model.Parent then
			local d = (groot.Position - root.Position).Magnitude
			if d < 26 and (not bestD or d < bestD) then
				if model:GetAttribute("Downed") then
					if d <= Q.Carry.Reach then
						-- a body: tap goes through its pockets (until they are empty), hold shoulders it
						local emptied = groot:GetAttribute("Looted") == true
						best, bestD = { guard = model, tap = if emptied then nil else "Search", hold = "Carry" }, d + 3 -- a standing guard in reach comes first
					end
				else
					local info = awareness[model]
					local tap, hold = Rules.Cqc(root.CFrame, groot.CFrame, model:GetAttribute("StealthState") or "Patrol")
					if info and info.a >= 1 and tap ~= "Throw" then
						tap, hold = nil, nil -- he has made you: only the throw is left
					end
					if tap or hold then
						best, bestD = { guard = model, tap = tap, hold = hold }, d
					end
				end
			end
		end
	end
	return best
end

local function drawOffer()
	offer = findOffer()
	if not offer then
		prompt.Enabled = false
		return
	end
	local _, char = myRoot()
	if offer.mode then
		prompt.Adornee = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
		promptWord.Text = if offer.mode == "Hold" then (if offer.asked then "CHOKE  .  G THROW" else "CHOKE  .  G THROW  .  E TALK") else (if offer.emptied then "G LET GO" else "SEARCH  .  G LET GO")
	else
		prompt.Adornee = offer.guard:FindFirstChild("UpperTorso") or offer.guard:FindFirstChild("HumanoidRootPart")
		local tap = offer.tap and (WORDS[offer.tap] or "TAKEDOWN")
		local hold = offer.hold and (if offer.hold == "Carry" then "DRAG" else "GRAB")
		promptWord.Text = if tap and hold then tap .. "  .  HOLD: " .. hold elseif tap then tap else "HOLD: " .. hold
	end
	prompt.Enabled = true
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

local ATTACK_ANIM = { Rear = "Takedown_Rear", Drop = "Takedown_Drop", Panel = "Takedown_Slam", Rail = "Takedown_Slam", Ledge = "Takedown_Slam", Throw = "Takedown_Throw", Shove = "Takedown_Shove" }
local VICTIM_ANIM = { Rear = "Takedown_RearVictim", Drop = "Takedown_DropVictim", Panel = "Takedown_SlamVictim", Rail = "Takedown_SlamVictim", Ledge = "Takedown_SlamVictim",
	Throw = "Takedown_ThrowVictim", Shove = "Takedown_ShoveVictim" }

local function onTakedown(kind, char, guard, spot, seconds)
	if typeof(char) ~= "Instance" or typeof(guard) ~= "Instance" then
		return
	end
	seconds = seconds or 1.6
	Anims.Stop(guard, "Held", 0.1)
	Anims.Stop(guard, "HandsUp", 0.1)
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
		-- the same place the server stands you (square behind it), set here too so the hold never starts off line
		local root = char:FindFirstChild("HumanoidRootPart")
		if kind == "Rear" and root and groot then
			local behind = groot.CFrame * CFrame.new(0, 0, S.Takedown.RearDistance or 1.5)
			root.CFrame = CFrame.new(behind.Position.X, root.Position.Y, behind.Position.Z) * groot.CFrame.Rotation
		elseif kind == "Throw" and root and groot then
			local to = (root.Position - groot.Position) * Vector3.new(1, 0, 1)
			if to.Magnitude > 0.1 then
				local me = groot.Position + to.Unit * Q.Throw.Stand
				root.CFrame = CFrame.lookAt(Vector3.new(me.X, root.Position.Y, me.Z), Vector3.new(groot.Position.X, root.Position.Y, groot.Position.Z))
			end
		end
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
				-- no fade: the takedown's last pose is this one, and the server turned the root in the same step
				for _, tr in animator:GetPlayingAnimationTracks() do
					tr:Stop(0)
				end
			end
			Anims.Play(model, "Downed", { fade = 0 })
		else
			Anims.Stop(model, "Downed", 0.3) -- thrown, not choked: he gets up
		end
	end
	model:GetAttributeChangedSignal("Downed"):Connect(apply)
	apply()
	-- a gun on him: hands up for as long as the server holds him there
	local function hands()
		if model:GetAttribute("StealthState") == "HeldUp" then
			Anims.Play(model, "HandsUp", { fade = 0.2 })
		else
			Anims.Stop(model, "HandsUp", 0.25)
		end
	end
	model:GetAttributeChangedSignal("StealthState"):Connect(hands)
	hands()
end

-- The second before he shouts (round 4): the colour drains to his outline, the world holds its breath.
local reflexFx
function Stealth.Reflex(guard, seconds)
	seconds = seconds or S.Reflex
	local Lighting = game:GetService("Lighting")
	if not reflexFx then
		reflexFx = Instance.new("ColorCorrectionEffect")
		reflexFx.Name = "ReflexGrade"
		reflexFx.Parent = Lighting
	end
	reflexFx.Saturation, reflexFx.Contrast, reflexFx.TintColor = -0.75, 0.25, Color3.fromRGB(255, 226, 214)
	Kit.tween(reflexFx, seconds, { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local cam = workspace.CurrentCamera
	if cam then
		local fov = cam.FieldOfView
		cam.FieldOfView = fov - 6
		Kit.tween(cam, seconds * 0.8, { FieldOfView = fov }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	if typeof(guard) == "Instance" then
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillTransparency, h.OutlineColor, h.FillColor = 0.85, Color3.fromRGB(255, 90, 70), Color3.fromRGB(255, 90, 70)
		h.Adornee = guard
		h.Parent = guard
		Debris:AddItem(h, seconds)
		Sounds.Play("Heartbeat", guard:FindFirstChild("HumanoidRootPart"), { Volume = 0.6 })
	end
end

-- He talks (round 4, E in a neck hold): his words under the screen; his crew and the stores show where you can
-- see them (never through walls) for a while.
function Stealth.Answer(guard, line, crew, crate, seconds)
	if typeof(guard) == "Instance" then
		asked[guard] = true
	end
	seconds = seconds or S.Question.Seconds
	local text = Kit.label({ Name = "Answer", Text = "\"" .. tostring(line or "") .. "\"", Font = UI.Body, TextSize = 18, TextColor3 = UI.Text,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.fromOffset(560, 28), Parent = gui, TextTransparency = 1 })
	Kit.tween(text, 0.3, { TextTransparency = 0 })
	task.delay(5, function()
		if text.Parent then
			Kit.tween(text, 0.6, { TextTransparency = 1 })
			Debris:AddItem(text, 0.7)
		end
	end)
	local function outline(model, color)
		if typeof(model) ~= "Instance" or not model.Parent then
			return
		end
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillTransparency, h.OutlineTransparency, h.OutlineColor = 1, 0.2, color
		h.Adornee = model
		h.Parent = gui
		Debris:AddItem(h, seconds)
	end
	for _, m in crew or {} do
		outline(m, Color3.fromRGB(255, 170, 90))
	end
	outline(crate, Color3.fromRGB(140, 220, 255))
end

-- World events the main script forwards here. Returns true when it was one of ours.
function Stealth.World(kind, a, b, c, d, e)
	if kind == "Takedown" then
		onTakedown(a, b, c, d, e)
	elseif kind == "Hold" then
		-- (char, guard, on): he is in someone's arms; the holder's own arms are client/Handling's
		if typeof(b) == "Instance" then
			local groot = b:FindFirstChild("HumanoidRootPart")
			local root, mine = myRoot()
			if c and a == mine and root and groot then
				-- square behind him as the hold starts (the server stands you there too)
				local behind = groot.CFrame * CFrame.new(0, 0, Q.Hold.Gap)
				root.CFrame = CFrame.new(behind.Position.X, root.Position.Y, behind.Position.Z) * groot.CFrame.Rotation
			end
			if a == mine then
				Stealth.HeldGuard = if c then b else nil
			end
			if c then
				Anims.Stop(b, "HandsUp", 0.1)
				Anims.Play(b, "Held", { fade = 0.15 })
				Sounds.Play("Takedown", b:FindFirstChild("HumanoidRootPart"), { Volume = 0.25 })
			else
				Anims.Stop(b, "Held", 0.15)
			end
		end
	elseif kind == "Carry" then
		if a == mine then
			Stealth.DraggedGuard = if c then b else nil
		end
		if typeof(b) == "Instance" then
			Sounds.Play("ImpactFlesh", b:FindFirstChild("HumanoidRootPart"), { Volume = 0.25 })
		end
	elseif kind == "LightBreak" then
		Sounds.Play("BreakGlass", a, { Volume = 0.5, Pitch = 1.3 })
		burst(a, Color3.fromRGB(255, 240, 200), 24, 18)
	elseif kind == "Sparks" then
		Sounds.Play(if Sounds.Ids.Sparks then "Sparks" else "FlickerTick", a, { Volume = 0.9 })
		burst(a, Color3.fromRGB(150, 210, 255), 40, 26)
	elseif kind == "Whistle" then
		Sounds.Play("Whistle", a, { Volume = 0.7 })
	elseif kind == "Slam" then
		-- (position, normal, body): a thrown guard meets a wall or another guard
		Sounds.Play("ImpactFlesh", a, { Volume = 1, Pitch = 0.75 })
		Sounds.Play("BreakMetal", a, { Volume = 0.35, Pitch = 0.6 })
		burst(a, Color3.fromRGB(200, 196, 188), 10, 10)
	elseif kind == "Reflex" then
		Stealth.Reflex(a, b)
	elseif kind == "Clatter" then
		-- (landing, from, seconds): the bolt arcs out of your hand and rings where it lands
		local landing, seconds = a, c or 0.4
		task.delay(math.clamp(seconds, 0, 2.5), function()
			Sounds.Play("BreakMetal", landing, { Volume = 0.45, Pitch = 1.6 })
			burst(landing, Color3.fromRGB(255, 214, 150), 6, 8)
		end)
	elseif kind == "Hide" then
		-- (char, locker, on, found)
		local _, mine = myRoot()
		if typeof(b) == "Instance" then
			Sounds.Play(if d then "BreakMetal" else "Takedown", b, { Volume = if d then 0.7 else 0.25, Pitch = if d then 0.8 else 1.4 })
		end
		if a == mine and Stealth.Locker then
			Stealth.Locker(c == true)
		end
	elseif kind == "Question" then
		Stealth.Answer(a, b, c, d, e)
	else
		return false
	end
	return true
end

-- Keys the main script forwards (returns true when used).
--   X: a tap does the offer's tap (a takedown, or a throw); held for Cqc.Hold.Press it does the offer's hold (the
--      neck grab, or a body onto the shoulder). With a guard in your arms X chokes him out; with a body up, X puts it down.
--   G: with a guard in your arms, throws him down; with a body up, puts it down.
local xDown -- { offer, at, used }
local function tapX(o)
	if o.tap == "Search" then
		Remotes.Cqc:FireServer("Search", o.guard)
	elseif o.tap == "Throw" then
		Remotes.Cqc:FireServer("Throw", o.guard, workspace.CurrentCamera.CFrame.LookVector)
	elseif o.tap then
		Remotes.Takedown:FireServer(o.guard)
	end
end

function Stealth.Key(key)
	if key == Enum.KeyCode.B then
		if player:GetAttribute("Stealth") then
			Remotes.Whistle:FireServer()
		end
		return true
	elseif key == Enum.KeyCode.X and offer then
		if offer.mode == "Hold" then
			Remotes.Cqc:FireServer("Choke")
		elseif offer.mode == "Carry" then
			-- from the grab: X goes through his pockets (G lets go; X does too once they are empty)
			if offer.emptied or not Stealth.DraggedGuard then
				Remotes.Cqc:FireServer("Drop")
			else
				Remotes.Cqc:FireServer("Search", Stealth.DraggedGuard)
			end
		elseif not offer.hold then
			tapX(offer) -- nothing to hold for: act on the press
		else
			local mine = { offer = offer, at = os.clock() }
			xDown = mine
			task.delay(Q.Hold.Press, function()
				if xDown == mine and not mine.used then
					mine.used = true
					Remotes.Cqc:FireServer(if mine.offer.hold == "Carry" then "Carry" else "Grab", mine.offer.guard)
				end
			end)
		end
		return true
	elseif key == Enum.KeyCode.G and offer and offer.mode then
		Remotes.Cqc:FireServer(if offer.mode == "Hold" then "Throw" else "Drop", nil, workspace.CurrentCamera.CFrame.LookVector)
		return true
	elseif key == Enum.KeyCode.E and offer and offer.mode == "Hold" and not offer.asked then
		Remotes.Cqc:FireServer("Question") -- he talks (once)
		return true
	end
	return false
end

function Stealth.KeyUp(key)
	if key == Enum.KeyCode.X and xDown then
		local mine = xDown
		xDown = nil
		if not mine.used then
			mine.used = true
			tapX(mine.offer)
		end
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
		local _, mine = myRoot()
		if not watched and mine and (mine:GetAttribute("NeckHold") or mine:GetAttribute("Carrying")) then
			drawOffer() -- hands still full on the way out of a watched place
			return
		end
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
