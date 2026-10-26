-- SwingAnimator (story 002, ADR-0004): makes every swing readable.
--   Swing(char, info)  -> windup pose over info.windup, strike over info.active, recover by info.finish
--   The flick cue (a glow on the striking hand) ramps during the windup and peaks exactly when the
--   flick window opens: windup - Config.Flicker.Window * rate (rate = the local player's FlickerRate,
--   1 for everyone else; x ZoneWindowMult while in the Zone).
--   Feint / Stun / Dodge on the same character cancel the telegraph immediately.
-- Timing comes from the server payload (the same Weapons.lua numbers it judges with). Poses and
-- colours come from Presentation.Swings; an AnimationId there replaces the procedural pose.
--
-- The procedural pose drives Motor6D.Transform every RunService.Stepped (the Animator writes
-- Transform earlier in the frame, so this overrides the walk/idle pose for the striking arm only).
-- Motor6D.C0 is not writable from the client, so Transform is the only joint channel available.
-- Presentation only: touches Transform and cosmetic instances it owns; never Humanoid or attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Presentation = require(Shared:WaitForChild("Presentation"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local CombatFX = require(script.Parent.CombatFX)

local player = Players.LocalPlayer
local F = Config.Flicker
local P = Presentation.Swings

local SwingAnimator = {}

local MIN_SEGMENT = 0.05 -- shortest phase we bother animating (seconds)
local CANCEL_TIME = 0.1 -- blend back to rest after a feint / stun / dodge
local CUE_PART_SIZE = Vector3.new(0.7, 0.7, 0.7)
local IDENTITY = CFrame.identity

local localFlickerRate = 1 -- from LoadoutChanged; other characters are drawn at rate 1

-- Per-character state (weak keys so despawned characters are collected).
-- s.pose = { motor, t0, windup, active, finish, wind, swing, from } drives the Stepped loop.
local states = setmetatable({}, { __mode = "k" })

local function stateOf(char)
	local s = states[char]
	if not s then
		s = { token = 0, tweens = {}, stance = { Right = {}, Left = {} } }
		states[char] = s
	end
	return s
end

-- The joint that drives the striking arm, or nil on rigs without one (placeholder NPCs).
-- Characters ship with either Motor6Ds or (newer avatars) AnimationConstraints; both expose the
-- Transform channel the Animator writes, which is what the pose timeline overrides.
local function isAnimJoint(inst)
	return inst ~= nil and (inst:IsA("Motor6D") or inst:IsA("AnimationConstraint"))
end

local function shoulderOf(char, side)
	side = side or "Right"
	local upperArm = char:FindFirstChild(side .. "UpperArm")
	local m = upperArm and upperArm:FindFirstChild(side .. "Shoulder")
	if isAnimJoint(m) then
		return m
	end
	local torso = char:FindFirstChild("Torso")
	m = torso and torso:FindFirstChild(side .. " Shoulder")
	if isAnimJoint(m) then
		return m
	end
	return nil
end

-- The left arm mirrors the right arm's pose: same pitch, opposite yaw and roll.
local function mirror(pose)
	return { pose[1], -pose[2], -pose[3] }
end

-- The torso joint, for the lean that sells thrusts and slams (R15 "Waist": UpperTorso <- LowerTorso).
local function waistOf(char)
	local upper = char:FindFirstChild("UpperTorso")
	local m = upper and upper:FindFirstChild("Waist")
	return if isAnimJoint(m) then m else nil
end

local function weaponSlot(char)
	return Presentation.Weapons[char:GetAttribute("Weapon") or ""]
end

local function handOf(char)
	return char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart")
end

local function anglesOf(pose)
	return CFrame.Angles(math.rad(pose[1]), math.rad(pose[2]), math.rad(pose[3]))
end

-- Easing used by the pose timeline (TweenService's curves, so Presentation.TweenStyle applies).
local function ease(alpha, style, direction)
	return TweenService:GetValue(math.clamp(alpha, 0, 1), style or P.TweenStyle, direction or Enum.EasingDirection.Out)
end

local function killTweens(s)
	for _, tw in s.tweens do
		tw:Cancel()
	end
	table.clear(s.tweens)
end

local function tweenTo(s, inst, props, seconds, style)
	local tw = TweenService:Create(inst, TweenInfo.new(math.max(seconds, MIN_SEGMENT), style or P.TweenStyle, Enum.EasingDirection.Out), props)
	table.insert(s.tweens, tw)
	tw:Play()
	return tw
end

local function removeCue(s)
	if s.cue then
		s.cue:Destroy()
		s.cue = nil
	end
end

-- Glow on the striking hand: a small neon sphere + light. Returns the sphere (light is its child).
local function makeCue(char, color)
	local hand = handOf(char)
	if not hand then
		return nil
	end
	local orb = Instance.new("Part")
	orb.Name = "SwingCue"
	orb.Shape = Enum.PartType.Ball
	orb.Size = CUE_PART_SIZE
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Transparency = 1
	orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.Massless = false, false, false, true
	orb.CFrame = hand.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, orb
	weld.Parent = orb
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0
	light.Range = 0
	light.Parent = orb
	orb.Parent = char
	return orb
end

-- Current Transform the pose timeline wants (for one arm), or nil when the pose has finished.
-- `rest` is where the arm returns to (the weapon's stance, or identity). A pose with `hold`
-- stays at the swing position until holdUntil, then lowers over HoldLower.
local function poseTransform(pose, arm, now, rest)
	local t = now - pose.t0
	if pose.from then -- cancel blend: from -> rest
		if t >= CANCEL_TIME then
			return nil
		end
		return arm.from:Lerp(rest, ease(t / CANCEL_TIME))
	end
	if t < pose.windup then
		return arm.start:Lerp(arm.wind, ease(t / pose.windup, Enum.EasingStyle.Sine))
	elseif t < pose.windup + pose.active then
		return arm.wind:Lerp(arm.swing, ease((t - pose.windup) / pose.active, Enum.EasingStyle.Quart))
	elseif pose.holdUntil then
		if now < pose.holdUntil then
			return arm.swing
		end
		local lower = P.HoldLower or 0.3
		if now < pose.holdUntil + lower then
			return arm.swing:Lerp(rest, ease((now - pose.holdUntil) / lower, Enum.EasingStyle.Sine))
		end
		return nil
	elseif t < pose.finish then
		local recover = math.max(pose.finish - pose.windup - pose.active, MIN_SEGMENT)
		return arm.swing:Lerp(rest, ease((t - pose.windup - pose.active) / recover, Enum.EasingStyle.Sine))
	end
	return nil
end

-- Resting transform for a shoulder: the equipped weapon's stance, eased in and out over StanceBlend.
local function restTransform(char, s, side, now)
	local slot = weaponSlot(char)
	local target = slot and slot.Stance and slot.Stance[side] and anglesOf(slot.Stance[side]) or IDENTITY
	local st = s.stance[side]
	if st.target ~= target then
		st.from, st.target, st.t0 = st.current or IDENTITY, target, now
	end
	local blend = Presentation.Weapons.StanceBlend or 0.25
	st.current = (st.from or IDENTITY):Lerp(target, ease((now - (st.t0 or now)) / blend, Enum.EasingStyle.Sine))
	return st.current, target == IDENTITY and st.current == IDENTITY
end

local function cancel(char)
	local s = states[char]
	if not s or not s.active then
		return
	end
	s.token += 1
	s.active = false
	killTweens(s)
	removeCue(s)
	if s.pose and s.pose.motor.Parent then
		-- blend from wherever the arms are now back to rest
		local arms = { Right = { from = s.pose.motor.Transform } }
		if s.pose.left and s.pose.left.Parent then
			arms.Left = { from = s.pose.left.Transform }
		end
		if s.pose.waist and s.pose.waist.Parent then
			arms.Waist = { from = s.pose.lastLean or IDENTITY } -- lean is relative to the Animator's pose
		end
		s.pose = { motor = s.pose.motor, left = s.pose.left, waist = s.pose.waist, t0 = os.clock(), from = true, arms = arms }
	else
		s.pose = nil
	end
	if s.track then
		s.track:Stop(CANCEL_TIME)
		s.track = nil
	end
end

local function playAnimationSlot(char, s, entry, finish)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = entry.AnimationId
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok or not track then
		return false
	end
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05)
	if track.Length > 0 and finish > 0 then
		track:AdjustSpeed(track.Length / finish) -- fit the clip to the swing's total time
	end
	s.track = track
	return true
end

-- info = { label, windup, active, finish, weapon, hyperarmor } from the server.
local function onSwing(char, info)
	if typeof(char) ~= "Instance" or type(info) ~= "table" then
		return
	end
	local windup, active, finish = tonumber(info.windup) or 0, tonumber(info.active) or 0, tonumber(info.finish) or 0
	local def = Weapons.Defs[info.weapon] or Weapons.Defs.Fists
	local isHeavy = info.label == "Heavy"
	local entry = Presentation.SwingFor(def.Family, info.label)

	cancel(char)
	local s = stateOf(char)
	s.token += 1
	s.active = true
	local token = s.token

	-- Flick cue timing. The window opens `Window * rate` before impact; the glow peaks right then.
	local rate = if char == player.Character then localFlickerRate else 1
	if char:GetAttribute("Zone") then
		rate *= F.ZoneWindowMult
	end
	local window = F.Window * rate
	local peakAt = math.max(windup - window, 0)
	local cueColor = if char:GetAttribute("Zone") then P.Cue.ZoneColor else P.Cue.Color
	local baseColor = if isHeavy then P.HeavyColor else P.LightColor

	local orb = makeCue(char, baseColor)
	s.cue = orb
	if orb then
		local light = orb:FindFirstChildOfClass("PointLight")
		-- ramp to a soft glow by the peak, then flip to the cue colour and hold until impact
		tweenTo(s, orb, { Transparency = 0.3 }, peakAt, Enum.EasingStyle.Linear)
		tweenTo(s, light, { Brightness = P.Cue.MaxBrightness * 0.4, Range = P.Cue.MaxRange * 0.5 }, peakAt, Enum.EasingStyle.Linear)
		task.delay(peakAt, function()
			if s.token ~= token or not orb.Parent then
				return
			end
			orb.Color, light.Color = cueColor, cueColor
			tweenTo(s, orb, { Transparency = 0 }, MIN_SEGMENT)
			tweenTo(s, light, { Brightness = P.Cue.MaxBrightness, Range = P.Cue.MaxRange }, MIN_SEGMENT)
		end)
		task.delay(windup + active, function()
			if s.token == token then
				removeCue(s)
			end
		end)
	end

	-- Uploaded animation wins; otherwise the procedural pose timeline.
	if entry.AnimationId and entry.AnimationId ~= "" and playAnimationSlot(char, s, entry, finish) then
		s.pose = nil
	else
		local motor = shoulderOf(char)
		if motor then
			local slot = weaponSlot(char)
			local left = if slot and slot.TwoHanded then shoulderOf(char, "Left") else nil
			local arms = { Right = { start = motor.Transform, wind = anglesOf(entry.Pose), swing = anglesOf(entry.Swing) } }
			if left then
				arms.Left = { start = left.Transform, wind = anglesOf(entry.PoseL or mirror(entry.Pose)), swing = anglesOf(entry.SwingL or mirror(entry.Swing)) }
			end
			-- torso lean: + = back (wind-up), - = forward (impact); degrees from entry.Lean or P.DefaultLean
			local waist = waistOf(char)
			local lean = entry.Lean or P.DefaultLean
			if waist and lean then
				arms.Waist = { start = IDENTITY, wind = CFrame.Angles(math.rad(lean[1]), 0, 0), swing = CFrame.Angles(math.rad(lean[2]), 0, 0) }
			end
			s.pose = {
				motor = motor, left = left, waist = waist, t0 = os.clock(), windup = math.max(windup, MIN_SEGMENT), active = math.max(active, MIN_SEGMENT),
				finish = math.max(finish, windup + active + MIN_SEGMENT), arms = arms,
				holdUntil = if entry.HoldAfter then os.clock() + math.max(finish, windup + active) + entry.HoldAfter else nil,
			}
		else
			-- No arm to swing (placeholder rigs): a body-wide pulse carries the telegraph instead.
			s.pose = nil
			CombatFX.Flash(char, baseColor, math.max(windup, MIN_SEGMENT))
		end
	end
	task.delay(finish, function()
		if s.token == token then
			s.active = false
		end
	end)
end

-- Drives every live pose and the weapon stances. Stepped runs after the Animator has written this
-- frame's Transforms, so what we write wins for the arms we touch.
local function step()
	local now = os.clock()
	for char, s in states do
		if not char.Parent then
			states[char] = nil
			continue
		end
		local pose = s.pose
		if pose and not pose.motor.Parent then
			s.pose = nil
			pose = nil
		end
		for side, joint in { Right = pose and pose.motor or shoulderOf(char), Left = pose and pose.left or shoulderOf(char, "Left") } do
			if joint then
				local rest, idle = restTransform(char, s, side, now)
				local transform = nil
				if pose and pose.arms[side] then
					transform = poseTransform(pose, pose.arms[side], now, rest)
					if not transform and side == "Right" then
						s.pose = nil
					end
				end
				if transform then
					joint.Transform = transform
				elseif not idle then
					joint.Transform = rest -- hold the weapon stance between swings
				end
			end
		end
		-- torso lean rides the same timeline; rest is the Animator's own pose (identity offset)
		if pose and pose.waist and pose.arms.Waist and pose.waist.Parent then
			local lean = poseTransform(pose, pose.arms.Waist, now, IDENTITY)
			if lean then
				pose.lastLean = lean
				pose.waist.Transform = pose.waist.Transform * lean
			end
		end
	end
end

-- Characters we should keep posing even before their first swing (so two-handed stances show).
local function track(char)
	if typeof(char) == "Instance" and char:IsA("Model") then
		stateOf(char)
	end
end

function SwingAnimator.Init()
	CombatFX.On("Swing", onSwing)
	CombatFX.On("Feint", cancel)
	CombatFX.On("Stun", cancel)
	CombatFX.On("Dodge", cancel)
	RunService.Stepped:Connect(step)
	-- stances need a state entry before any swing happens
	local CollectionService = game:GetService("CollectionService")
	for _, p in Players:GetPlayers() do
		if p.Character then
			track(p.Character)
		end
		p.CharacterAdded:Connect(track)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(track)
	end)
	for _, m in CollectionService:GetTagged("Combatant") do
		track(m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(track)
	Remotes.LoadoutChanged.OnClientEvent:Connect(function(data)
		if type(data) == "table" and tonumber(data.FlickerRate) then
			localFlickerRate = data.FlickerRate
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if p.Character then
			states[p.Character] = nil
		end
	end)
end

return SwingAnimator
