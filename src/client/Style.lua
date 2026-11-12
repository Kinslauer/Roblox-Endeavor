-- Style (Endeavor client, round 2 of docs/Reference-Picks-Plan.md): the combat around the chain.
--   Middle mouse locks on to the hostile you face (a small mark on it, never through walls; lost out of sight);
--   while locked, an attack pressed toward it lunges in and one pressed away cuts upward (Intent, sent with the
--   Attack remote). 1 swaps to the carried weapon (server/Kit), 2 dresses the worst wound from the kit's pouches.
--   A quiet hit count in the upper right corner (Andy: "not visible in the same way, just a combo count in the
--   corner"). Knocked down: the body goes prone and crawls until someone picks it up.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Anims = require(Shared:WaitForChild("Anims"))
local Joints = require(Shared:WaitForChild("Joints"))

local K = Config.Kit
local player = Players.LocalPlayer
local Style = {}

local target -- the locked model
local lostFor = 0
local mark -- BillboardGui on the target
local count, lastHit = 0, 0
local countGui, countLabel
local rangeLabel -- round 3: range marks under the reticle while aiming a gun
local G = Config.Guns

local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c
end

local function alive(model)
	local hum = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function canSee(from, model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, model }
	return workspace:Raycast(from, root.Position - from, params) == nil
end

-- the hostile closest to the middle of the view, within reach and in sight
function Style.Pick()
	local root, char = myRoot()
	local cam = workspace.CurrentCamera
	if not (root and cam) then
		return nil
	end
	local look = cam.CFrame.LookVector
	local best, bestScore
	local seen = {}
	local function consider(model)
		if seen[model] or model == char or not alive(model) or model:GetAttribute("Contact") then
			return
		end
		seen[model] = true
		local r = model:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local to = r.Position - root.Position
		local d = to.Magnitude
		if d > K.Lock.Range or d < 0.5 then
			return
		end
		local facing = look:Dot(to.Unit)
		if facing < K.Lock.Cone or not canSee(cam.CFrame.Position, model) then
			return
		end
		local score = facing * 2 - d / K.Lock.Range
		if not bestScore or score > bestScore then
			best, bestScore = model, score
		end
	end
	for _, m in CollectionService:GetTagged("NPC") do
		consider(m)
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			consider(p.Character)
		end
	end
	return best
end

local function clearMark()
	if mark then
		mark:Destroy()
		mark = nil
	end
end

function Style.Lock(model)
	target = model
	lostFor = 0
	clearMark()
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		mark = Instance.new("BillboardGui")
		mark.Name = "LockMark"
		mark.AlwaysOnTop = false -- never through a wall
		mark.Size = UDim2.fromOffset(18, 18)
		mark.StudsOffset = Vector3.new(0, 0.6, 0)
		mark.LightInfluence = 0
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(0.5, 0.5)
		d.Size = UDim2.fromScale(0.62, 0.62)
		d.Rotation = 45
		d.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(120, 230, 255)
		s.Thickness = 1.5
		s.Parent = d
		d.Parent = mark
		mark.Adornee = root
		mark.Parent = root
	end
end

function Style.Target()
	return target
end

-- "Forward" | "Back" | nil: the direction of the stick against the locked target
function Style.Intent()
	local root, char = myRoot()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	if not (root and hum and troot) then
		return nil
	end
	local move = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	local to = Vector3.new(troot.Position.X - root.Position.X, 0, troot.Position.Z - root.Position.Z)
	if move.Magnitude < 0.3 or to.Magnitude < 0.1 then
		return nil
	end
	local dot = move.Unit:Dot(to.Unit)
	if dot >= K.Lock.Forward then
		return "Forward"
	elseif dot <= K.Lock.Back then
		return "Back"
	end
	return nil
end

function Style.Began(input, key)
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		if target then
			Style.Lock(nil)
		else
			Style.Lock(Style.Pick())
		end
		return true
	elseif key == Enum.KeyCode.One then
		Remotes.Swap:FireServer()
		return true
	elseif key == Enum.KeyCode.Two then
		Remotes.QuickMed:FireServer()
		return true
	end
	return false
end

-- one frame of the lock: the view turns to keep the target ahead; lost if dead, far, or out of sight a moment
function Style.Step(dt)
	if not target then
		return
	end
	local root = myRoot()
	local cam = workspace.CurrentCamera
	local troot = target:FindFirstChild("HumanoidRootPart")
	if not (root and cam and troot and alive(target)) or (troot.Position - root.Position).Magnitude > K.Lock.Range * 1.2 then
		Style.Lock(nil)
		return
	end
	if canSee(cam.CFrame.Position, target) then
		lostFor = 0
	else
		lostFor += dt
		if lostFor > 1 then
			Style.Lock(nil)
			return
		end
	end
	local eye = cam.CFrame.Position
	local want = CFrame.lookAt(eye, troot.Position + Vector3.new(0, 1, 0))
	cam.CFrame = cam.CFrame:Lerp(want, math.min(1, dt * 10))
end

local function bump()
	count += 1
	lastHit = os.clock()
	if countLabel then
		countLabel.Text = tostring(count)
		countLabel.TextTransparency = if count >= 2 then 0.15 else 1
	end
end

-- shared with the tests: what a CombatEvent does here
function Style.Event(kind, a, b, c, d, e)
	local root, char = myRoot()
	if kind == "Hit" and e ~= nil and e == char then
		bump()
	elseif kind == "Lunge" and root and typeof(a) == "Vector3" then
		local att = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if att then
			local lv = Instance.new("LinearVelocity")
			lv.Name = "LungeVelocity"
			lv.Attachment0 = att
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			lv.PrimaryTangentAxis, lv.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
			lv.PlaneVelocity = Vector2.new(a.X, a.Z)
			lv.MaxForce = 1e6
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Parent = root
			task.delay(tonumber(b) or 0.18, function()
				lv:Destroy()
			end)
		end
	elseif kind == "Swap" and a == char then
		-- the hand goes to the mount and back (the server swaps the models halfway)
		local reach = if b == "Back" then CFrame.Angles(math.rad(150), 0, math.rad(-20))
			elseif b == "Chest" then CFrame.Angles(math.rad(60), 0, math.rad(50))
			else CFrame.Angles(math.rad(20), 0, math.rad(-25))
		pcall(Joints.Pose, char, "RightShoulder", reach, K.SwapSeconds * 0.5)
		task.delay(K.SwapSeconds * 0.5, function()
			pcall(Joints.Pose, char, "RightShoulder", CFrame.new(), K.SwapSeconds * 0.5)
		end)
	elseif kind == "Grab" and a == char then
		-- a gun off the floor: the hand goes down to it and back
		pcall(Joints.Pose, char, "RightShoulder", CFrame.Angles(math.rad(-50), 0, math.rad(-10)), 0.15)
		task.delay(0.15, function()
			pcall(Joints.Pose, char, "RightShoulder", CFrame.new(), 0.2)
		end)
	elseif kind == "Knocked" and a == char then
		if b then
			Anims.Play(char, "Prone_Idle", { fade = 0.2 })
		else
			Anims.Stop(char, "Prone_Idle", 0.3)
			Anims.Stop(char, "Prone_Crawl", 0.3)
		end
	end
end

function Style.Count()
	return count
end

-- Round 3 (guns and ammo), each frame with a gun out: the range to what the reticle is on while aiming (in metres,
-- Config.Guns.MetresPerStud), tired arms sway the view (ArmFatigue), a hot barrel smokes (Heat).
local swayT = 0
function Style.Gun(dt)
	local _, char = myRoot()
	local cam = workspace.CurrentCamera
	local aiming = char ~= nil and char:GetAttribute("Aiming") == true and char:GetAttribute("Mag") ~= nil
	if rangeLabel then
		local text = ""
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if aiming and cam and root then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000, params)
			text = if hit then ("%d m"):format(math.floor((hit.Position - root.Position).Magnitude * G.MetresPerStud + 0.5)) else "---"
		end
		rangeLabel.Text = text
		rangeLabel.Visible = text ~= ""
	end
	local tired = if aiming then (char:GetAttribute("ArmFatigue") or 0) else 0
	if tired > 0.05 and cam then
		swayT += dt
		local amp = math.rad(G.Fatigue.Sway * tired)
		cam.CFrame = cam.CFrame * CFrame.Angles(math.sin(swayT * 1.3) * amp * 0.6, math.sin(swayT * 0.9 + 1) * amp, 0)
	end
	local held = char and char:FindFirstChild("HeldWeapon")
	local part = held and held.PrimaryPart
	if part then
		local smoke = part:FindFirstChild("HeatSmoke")
		local hot = (char:GetAttribute("Heat") or 0) > G.Heat.Hot
		if hot and not smoke then
			smoke = Instance.new("ParticleEmitter")
			smoke.Name = "HeatSmoke"
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
			smoke.Transparency = NumberSequence.new(0.8, 1)
			smoke.Size = NumberSequence.new(0.15, 0.6)
			smoke.Lifetime = NumberRange.new(0.6, 1.1)
			smoke.Speed = NumberRange.new(0.5, 1.2)
			smoke.Acceleration = Vector3.new(0, 2, 0)
			smoke.Rate = 6
			smoke.LightInfluence = 0.6
			smoke.Parent = part
		elseif smoke then
			smoke.Enabled = hot
		end
	end
end


function Style.Start(gui)
	countGui = gui
	countLabel = Instance.new("TextLabel")
	countLabel.Name = "ComboCount"
	countLabel.BackgroundTransparency = 1
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.Position = UDim2.new(1, -24, 0, 70)
	countLabel.Size = UDim2.fromOffset(80, 30)
	countLabel.Font = Enum.Font.Michroma
	countLabel.TextSize = 22
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.TextColor3 = Color3.fromRGB(200, 236, 246)
	countLabel.TextStrokeTransparency = 0.6
	countLabel.TextTransparency = 1
	countLabel.Text = ""
	if countGui then
		countLabel.Parent = countGui
	end
	rangeLabel = Instance.new("TextLabel")
	rangeLabel.Name = "RangeMark"
	rangeLabel.BackgroundTransparency = 1
	rangeLabel.AnchorPoint = Vector2.new(0.5, 0)
	rangeLabel.Position = UDim2.new(0.5, 0, 0.5, 26)
	rangeLabel.Size = UDim2.fromOffset(80, 16)
	rangeLabel.Font = Enum.Font.RobotoMono
	rangeLabel.TextSize = 12
	rangeLabel.TextColor3 = Color3.fromRGB(200, 236, 246)
	rangeLabel.TextTransparency = 0.25
	rangeLabel.TextStrokeTransparency = 0.7
	rangeLabel.Text = ""
	rangeLabel.Visible = false
	if countGui then
		rangeLabel.Parent = countGui
	end
	Remotes.CombatEvent.OnClientEvent:Connect(Style.Event)
	RunService:BindToRenderStep("StyleLock", 201, function(dt) -- just after the camera (RenderPriority.Camera = 200)
		Style.Step(dt)
		Style.Gun(dt)
		if count > 0 and os.clock() - lastHit > K.ComboReset then
			count = 0
			if countLabel then
				countLabel.TextTransparency = 1
			end
		end
		-- knocked: crawl while moving, lie still otherwise
		local _, char = myRoot()
		if char and char:GetAttribute("Knocked") then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local moving = hum and hum.MoveDirection.Magnitude > 0.1
			local crawl = Anims.Track(char, "Prone_Crawl")
			if moving and crawl and not crawl.IsPlaying then
				Anims.Play(char, "Prone_Crawl", { fade = 0.2 })
			elseif not moving and crawl and crawl.IsPlaying then
				Anims.Stop(char, "Prone_Crawl", 0.2)
			end
		end
	end)
end

return Style
