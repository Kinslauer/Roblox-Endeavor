-- Movement: the character controller, ported from Roblox's Platformer template (Controller, BaseJump,
-- Jump, DoubleJump, BaseSpecial, Roll, Dash, LongJump, Stun, Recover, CharacterLeanScript) and fitted to
-- Endeavor's controls and combat:
--   * momentum: input is read from the humanoid each frame and the move direction eases toward it at an
--     acceleration per state (ground, air, mid-action), so the body has weight
--   * Space: jump on the ground (with coyote time just after leaving a ledge); in the air, a double jump
--     once per airtime; within a moment of a roll, a long jump that stuns you if you fly into a wall
--   * Q (the dodge): a roll on the ground that decays over its length; in the air, a dash, once per airtime.
--     It starts here at once; the server (Combat.Dodge) still spends the stamina and grants the i-frames
--   * every player character leans into its movement
-- Tuning is Config.Movement; Workspace gravity and jump height are set on the server (Main, Stats).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Joints = require(Shared.Joints)

local M = Config.Movement
local C = Config.Combat
local player = Players.LocalPlayer

local Movement = {}

-- Roblox's own animations from the template (owned by Roblox, so any experience can play them).
local ANIMS = { Roll = M.Anims.Roll, Dash = M.Anims.Dash, DoubleJump = M.Anims.Dash, LongJump = M.Anims.LongJump, Stun = M.Anims.Stun, Recover = M.Anims.Recover }

-- Per-action acceleration and whether landing ends it (the template's action modules, as data).
local ACTIONS = {
	Jump = { clearOnGrounded = true, minTime = 0.2 },
	DoubleJump = { clearOnGrounded = true },
	Dash = { clearOnGrounded = true, accel = 4 },
	Roll = { accel = 4 },
	LongJump = { clearOnGrounded = true, minTime = 0.2, accel = 1 },
	Stun = { clearOnGrounded = true, minTime = 0.2, accel = 0, nextAction = "Recover" },
	Recover = { accel = 1 },
}

local ctl = nil -- the local character's controller state
local lastPredictedDodge = -10

local function velocityForHeight(height)
	return math.sqrt(2 * workspace.Gravity * height)
end

local function setVerticalVelocity(root, vy)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
end

local function attachment(root, name)
	local a = root:FindFirstChild(name)
	if not a then
		a = Instance.new("Attachment")
		a.Name = name
		a.Parent = root
	end
	return a
end

-- A world-space planar push: the body keeps its own vertical motion (gravity, jumps).
local function planarVelocity(root, name, dir, speed, forceFactor)
	local v = Instance.new("LinearVelocity")
	v.Name = name
	v.Attachment0 = attachment(root, "MoveAttachment")
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	v.PrimaryTangentAxis = Vector3.xAxis
	v.SecondaryTangentAxis = Vector3.zAxis
	v.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	v.MaxForce = forceFactor * root.AssemblyMass
	v.Parent = root
	return v
end

-- speed lines behind the body for a moment
local function streaks(root, dir)
	local fx = workspace:FindFirstChild("FX") or workspace
	for _ = 1, 5 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, Color3.fromRGB(220, 235, 255), 0.4
		p.Size = Vector3.new(0.08, 0.08, 3.5)
		local offset = Vector3.new(math.random() * 2 - 1, math.random() * 3 - 1.5, math.random() * 2 - 1)
		local at = root.Position + offset - dir * 1.5
		p.CFrame = CFrame.lookAt(at, at + dir)
		p.Parent = fx
		TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1, CFrame = p.CFrame * CFrame.new(0, 0, 3) }):Play()
		task.delay(0.3, function()
			p:Destroy()
		end)
	end
end

-- ===== the controller =====
local function newController(character)
	local hum = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return nil
	end
	local self = {
		character = character, hum = hum, root = root,
		input = Vector3.zero, move = Vector3.zero,
		action = "None", actionAt = {}, lastGrounded = 0,
		canDoubleJump = true, canDash = true, wasJumping = false,
		tracks = {}, playing = nil, rollDir = nil,
	}
	local animator = hum:WaitForChild("Animator", 10)
	if animator then
		for name, id in ANIMS do
			if id and id ~= "" then
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local ok, track = pcall(function()
					return animator:LoadAnimation(anim)
				end)
				if ok and track then
					track.Priority = Enum.AnimationPriority.Action
					self.tracks[name] = track
				end
			end
		end
	end
	return self
end

local function grounded(self)
	return self.hum.FloorMaterial ~= Enum.Material.Air
end

local function swimmingOrClimbing(self)
	local s = self.hum:GetState()
	return s == Enum.HumanoidStateType.Swimming or s == Enum.HumanoidStateType.Climbing
end

local function since(self, action)
	return os.clock() - (self.actionAt[action] or 0)
end

-- a body that cannot move (stunned, rooted, dead) does nothing here
local function canAct(self)
	return self.hum.Health > 0 and self.hum.WalkSpeed > 0.5 and not self.character:GetAttribute("Stunned")
end

local function setAction(self, action)
	self.action = action
	self.actionAt[action] = os.clock()
	self.character:SetAttribute("MoveAction", action)
	if self.playing then
		self.playing:Stop(0.1)
		self.playing = nil
	end
	local track = self.tracks[action]
	if track then
		track:Play(M.AnimFade)
		self.playing = track
	end
end

local function acceleration(self)
	local a = ACTIONS[self.action]
	if a and a.accel then
		return a.accel
	end
	if swimmingOrClimbing(self) then
		return M.LadderAcceleration
	elseif not grounded(self) then
		return M.AirAcceleration
	end
	return M.GroundAcceleration
end

-- Stun: a long jump into a wall bounces you off it and puts you down for a moment.
local function stun(self, normal)
	setAction(self, "Stun")
	self.move = Vector3.zero
	local v = Vector3.new(normal.X, 0, normal.Z)
	if v.Magnitude > 0.01 then
		local push = planarVelocity(self.root, "StunVelocity", v.Unit, M.StunBounceSpeed, M.StunForceFactor)
		task.delay(0.25, function()
			push:Destroy()
		end)
	end
	setVerticalVelocity(self.root, velocityForHeight(M.StunBounceHeight))
end

local function longJump(self)
	if since(self, "LongJump") < M.JumpCooldown then
		return
	end
	local dir = self.rollDir or Vector3.new(self.root.CFrame.LookVector.X, 0, self.root.CFrame.LookVector.Z).Unit
	setAction(self, "LongJump")
	local push = planarVelocity(self.root, "LongJumpVelocity", dir, M.LongJumpSpeed, M.LongJumpForceFactor)
	setVerticalVelocity(self.root, velocityForHeight(M.LongJumpHeight))
	streaks(self.root, dir)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if self.action ~= "LongJump" or not self.character.Parent or swimmingOrClimbing(self) then
			conn:Disconnect()
			push:Destroy()
			return
		end
		local from = self.root.Position - dir * M.WallCheckRadius
		local hit = workspace:Spherecast(from, M.WallCheckRadius, dir * M.WallCheckRadius * 2, params)
		if hit then
			conn:Disconnect()
			push:Destroy()
			stun(self, hit.Normal)
		end
	end)
end

local function jump(self)
	if self.action == "Stun" or self.action == "Recover" or not canAct(self) then
		return
	end
	if self.action == "Roll" and since(self, "Roll") <= M.LongJumpWindow then
		return longJump(self)
	end
	local onGround = grounded(self) or swimmingOrClimbing(self)
	if onGround or os.clock() - self.lastGrounded <= M.CoyoteTime then
		if (self.action == "None" or self.action == "Jump") and since(self, "Jump") >= M.JumpCooldown and self.hum.JumpHeight > 0.5 then
			setAction(self, "Jump")
			self.hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	elseif self.canDoubleJump and since(self, "Dash") >= M.DashTime and self.hum.JumpHeight > 0.5 then
		self.canDoubleJump = false
		setAction(self, "DoubleJump")
		setVerticalVelocity(self.root, velocityForHeight(self.hum.JumpHeight * M.DoubleJumpScale))
		streaks(self.root, Vector3.new(0, -1, 0))
	end
end

local function update(self, dt)
	local onGround = grounded(self)
	if onGround or swimmingOrClimbing(self) then
		-- landing ends airborne actions (after their minimum time) and refills the double jump and dash
		local a = ACTIONS[self.action]
		if a and a.clearOnGrounded and since(self, self.action) >= (a.minTime or 0) then
			if a.nextAction == "Recover" then
				setAction(self, "Recover")
				self.move = Vector3.zero
				task.delay(M.RecoverTime, function()
					if self.action == "Recover" then
						setAction(self, "None")
					end
				end)
			else
				setAction(self, "None")
			end
		end
		self.canDoubleJump, self.canDash = true, true
	end
	if onGround then
		self.lastGrounded = os.clock()
	end
	-- ease the move direction toward the input at this state's acceleration: the weight
	if self.move ~= self.input then
		local offset = self.input - self.move
		local step = acceleration(self) * dt
		self.move = if offset.Magnitude <= step then self.input else self.move + offset.Unit * step
	end
	self.hum:Move(self.move)
end

local function onRenderStep(dt)
	local self = ctl
	if not self or not self.character.Parent then
		return
	end
	local hum = self.hum
	-- read what the default controls asked for, then take it over (the template's trick)
	local input = Vector3.zero
	if hum.WalkSpeed > 0 then
		input = hum:GetMoveVelocity() / hum.WalkSpeed
	end
	if input.Magnitude > 1 then
		input = input.Unit
	end
	self.input = input
	local wantsJump = hum.Jump
	hum.Jump = false
	local pressed = wantsJump and not self.wasJumping
	self.wasJumping = wantsJump
	update(self, dt)
	if pressed then
		jump(self)
	end
end

-- ===== the dodge (Q) =====
-- Starts the roll (ground) or dash (air) at once and tells the server, which spends stamina and grants
-- the i-frames. Returns false when nothing happened (cooldown, no stamina, no air dash left).
function Movement.Dodge(dir)
	local self = ctl
	if not self or not canAct(self) or self.action == "Stun" or self.action == "Recover" or swimmingOrClimbing(self) then
		return false
	end
	if os.clock() - lastPredictedDodge < C.DodgeCooldown then
		return false
	end
	if (self.character:GetAttribute("Stamina") or 0) < C.DodgeCost then
		return false
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		return false
	end
	dir = dir.Unit
	if grounded(self) then
		if self.action ~= "None" and self.action ~= "Jump" then
			return false
		end
		lastPredictedDodge = os.clock()
		self.rollDir = dir
		setAction(self, "Roll")
		local push = planarVelocity(self.root, "RollVelocity", dir, M.RollSpeed, M.RollForceFactor)
		local tween = TweenService:Create(push, TweenInfo.new(M.RollTime, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { PlaneVelocity = Vector2.zero })
		tween.Completed:Once(function()
			push:Destroy()
			if self.action == "Roll" then
				setAction(self, "None")
			end
		end)
		tween:Play()
		task.delay(M.RollTime + 0.5, function() -- whatever happened meanwhile, the push never outlives the roll
			if push.Parent then
				push:Destroy()
			end
		end)
	else
		if not self.canDash then
			return false
		end
		lastPredictedDodge = os.clock()
		self.canDash = false
		setAction(self, "Dash")
		-- the air dash holds its height for its length (all three axes driven), as the template's does
		local push = Instance.new("LinearVelocity")
		push.Name = "DashVelocity"
		push.Attachment0 = attachment(self.root, "MoveAttachment")
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VectorVelocity = dir * M.DashSpeed
		push.MaxForce = M.DashForceFactor * self.root.AssemblyMass
		push.Parent = self.root
		task.delay(M.DashTime, function()
			push:Destroy()
		end)
	end
	streaks(self.root, dir)
	Remotes.Dodge:FireServer(dir)
	return true
end

-- The server's answer to a dodge (Combat.Dodge -> "DodgeMove"). The motion already happened here, so only
-- what the server adds is applied: Enemy Step's hop.
function Movement.ServerDodge(velocity)
	local self = ctl
	if not self then
		return false
	end
	if os.clock() - lastPredictedDodge < 0.6 then
		if velocity.Y > 1 then
			setVerticalVelocity(self.root, velocity.Y)
			self.canDoubleJump, self.canDash = true, true -- springing off an enemy gives the air back
		end
		return true
	end
	return false
end

function Movement.Action()
	return ctl and ctl.action or "None"
end

-- ===== lean: every player character tips into its movement (CharacterLeanScript) =====
local leans = setmetatable({}, { __mode = "k" })
local function onStepped(_, dt)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local lower = char and char:FindFirstChild("LowerTorso")
		local joint = lower and lower:FindFirstChild("Root")
		if hum and root and Joints.IsJoint(joint) then
			local rel = root.CFrame:VectorToObjectSpace(hum:GetMoveVelocity())
			local pitch, roll = 0, 0
			if hum.WalkSpeed > 0 then
				pitch = math.clamp(rel.Z / hum.WalkSpeed, -1, 1) * math.rad(M.LeanPitch)
				roll = -math.clamp(rel.X / hum.WalkSpeed, -1, 1) * math.rad(M.LeanRoll)
			end
			local cur = (leans[joint] or CFrame.identity):Lerp(CFrame.Angles(pitch, 0, roll), math.min(dt * M.LeanSpeed, 1))
			leans[joint] = cur
			joint.Transform = cur * joint.Transform
		end
	end
end

function Movement.Start()
	local function onCharacter(char)
		task.spawn(function()
			ctl = newController(char)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	-- after the default controls, so their move and jump can be read and replaced
	RunService:BindToRenderStep("EndeavorMovement", Enum.RenderPriority.Last.Value, onRenderStep)
	RunService.Stepped:Connect(onStepped)
end

return Movement
