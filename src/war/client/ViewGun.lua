-- The gun in the first-person view (owner, 2026-11-12: "The realistic gun handling, recoil, and visuals are the
-- primary goals for weapons in the game", after a helmet-camera tactical shooter he wants the Front to feel like;
-- ideas only). The weapon in the character's hand is hidden for its owner and a local copy is flown in front of the
-- camera instead:
--   * it floats: it trails behind a turn, drifts with the breath and the step, and is not glued to the centre;
--   * a shot kicks it with a spring (back into the shoulder, muzzle up, a twist) and it overshoots and settles;
--   * the round leaves along the bore, not along the camera (ViewGun.Direction goes to the server with Fire);
--   * the real arms reach for it (IKControl on the own character: right hand on the grip, left on the handguard);
--   * with a scope up at the eye its housing fades (both eyes open).
-- Everything here is local to the owner. Other players see the hand-held model and the server-side pose.
local ViewGun = {}

local T -- Config.WarMovement.ViewGun
local player, camera, GunParts
local gun -- { Model, Key, Source, Rel, Sight, MuzzleEnd, Optics = {parts}, Right, Left, LeftRest }
local ik = {} -- Right, Left (IKControl), Char
local failed -- the key of a gun whose copy could not be built
local view -- the bore frame this frame (looks down -Z), nil while no gun is shown
local lastLook
local clock = 0
local bobPhase = 0
local aimBlend, sprintBlend, busyBlend, lowBlend = 0, 0, 0, 0

-- ===== springs: position p chases a target; a kick is added speed =====
local function spring(frequency, damping)
	return { p = Vector3.zero, v = Vector3.zero, f = frequency, d = damping }
end
local function stepSpring(s, target, dt)
	local w = 2 * math.pi * s.f
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	for _ = 1, steps do
		s.v += ((target - s.p) * (w * w) - s.v * (2 * s.d * w)) * h
		s.p += s.v * h
	end
end
ViewGun.Spring, ViewGun.StepSpring = spring, stepSpring

local lag, kickRot, kickPos, camPunch
local punchApplied = Vector3.zero

local function reset()
	lag = spring(T.Lag.Frequency, T.Lag.Damping) -- x pitch, y yaw (degrees): the gun trailing the view
	kickRot = spring(T.Recoil.Frequency, T.Recoil.Damping) -- x pitch, y yaw, z roll (degrees)
	kickPos = spring(T.Recoil.Frequency, T.Recoil.Damping) -- studs; z back into the shoulder
	camPunch = spring(T.Camera.Frequency, T.Camera.Damping) -- x pitch, y yaw, z roll (degrees)
	punchApplied = Vector3.zero
	lastLook = nil
end

-- ===== the copy =====
local function clearGun()
	if gun then
		gun.Model:Destroy()
		gun = nil
	end
	view = nil
end
local function clearArms()
	for _, name in { "Right", "Left" } do
		if ik[name] then
			ik[name]:Destroy()
			ik[name] = nil
		end
	end
	ik.Char = nil
end

local function vmin(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
local function vmax(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
local function keyOf(held)
	return ("%s|%s|%d"):format(tostring(held:GetAttribute("WeaponId")), tostring(held:GetAttribute("Build")), #held:GetDescendants())
end

-- The hand-held model's Grip weld gives the gun's authored frame: HeldWeapons sets C1 to the primary part in that
-- frame, so the frame is primary * C1^-1. Rifles are authored barrel +Z, up +Y; the whole pistols barrel +Y, grip
-- down -Z (their weld turns them a quarter round), so those get turned to the same convention. Everything about the
-- copy is then measured from its own parts, so any gun works, parts-built or whole. Measured on a real server: the
-- weld point is not the pistol grip (it sits near the top of the receiver), so the hands go by the gun's shape.
local PISTOL_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local function build(held)
	local primary = held.PrimaryPart
	local grip = primary and primary:FindFirstChild("Grip")
	if not (grip and grip:IsA("Weld")) then
		return nil
	end
	local origin = primary.CFrame * grip.C1:Inverse()
	if math.abs(grip.C0.UpVector.Y) < 0.5 then
		origin *= PISTOL_TURN
	end
	local id = held:GetAttribute("WeaponId")
	local spec = GunParts and GunParts.Guns[id]
	local shrink = if spec then 1 else T.GunScale -- whole models are still twice body scale: the copy is not
	local model = held:Clone()
	model.Name = "ViewGun"
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local opticLo, opticHi
	local optics, parts = {}, 0
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			parts += 1
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			d.LocalTransparencyModifier = 0
			local rel = origin:ToObjectSpace(d.CFrame)
			if shrink ~= 1 then
				d.Size *= shrink
				rel = rel.Rotation + rel.Position * shrink
				d.CFrame = origin * rel
			end
			local at = rel.Position
			local half = d.Size / 2
			-- a part's box turned into the gun's frame: its true reach, so a long barrel does not count as tall
			local rx, ry, rz = rel.RightVector, rel.UpVector, rel.LookVector
			local ext = Vector3.new(
				math.abs(rx.X) * half.X + math.abs(ry.X) * half.Y + math.abs(rz.X) * half.Z,
				math.abs(rx.Y) * half.X + math.abs(ry.Y) * half.Y + math.abs(rz.Y) * half.Z,
				math.abs(rx.Z) * half.X + math.abs(ry.Z) * half.Y + math.abs(rz.Z) * half.Z
			)
			if d:GetAttribute("Component") == "Optic" then
				table.insert(optics, d)
				d:SetAttribute("ShownT", d.Transparency)
				opticLo = if opticLo then vmin(opticLo, at - ext) else at - ext
				opticHi = if opticHi then vmax(opticHi, at + ext) else at + ext
			else
				lo, hi = vmin(lo, at - ext), vmax(hi, at + ext)
			end
		end
	end
	if parts == 0 then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = model:FindFirstChild(primary.Name, true) or model:FindFirstChildWhichIsA("BasePart", true)
	local length, height = hi.Z - lo.Z, hi.Y - lo.Y
	local long = length > T.LongGun -- a rifle: butt in the shoulder, the off hand forward
	local pose = if long then T.Rifle else T.Pistol
	-- the line of sight: through the middle of a scope, else along the top of the gun (the tip of the front post)
	local sight = if opticLo then Vector3.new(0, (opticLo.Y + opticHi.Y) / 2, 0) else Vector3.new(0, hi.Y, 0)
	local option = string.split(tostring(held:GetAttribute("Build") or ""), "|")[1]
	local barrel = spec and (spec.Barrels[option] or spec.Barrels.Standard)
	local bore = if barrel then barrel.End.Y * T.GunScale else hi.Y - height * pose.BoreDrop
	local muzzle = Vector3.new(0, bore, hi.Z)
	-- the firing hand: a rifle's grip is a fixed length ahead of the butt, a pistol's is its rear end
	local gripAt
	if long then
		gripAt = Vector3.new(0, bore - pose.GripDrop, lo.Z + (if spec then pose.Pull else length * pose.PullShare))
	else
		gripAt = Vector3.new(0, hi.Y - height * pose.GripDrop, lo.Z + length * pose.PullShare)
	end
	-- the hand's own frame on the grip (R15 right hand: +Y to the wrist, -X the palm, -Z the thumb side): the palm
	-- against the right of the grip, the wrist behind and below it
	local lean = math.rad(pose.Wrist)
	local wrist = Vector3.new(0, -math.cos(lean), -math.sin(lean))
	local palmOut = Vector3.new(-1, 0, 0) -- the gun's left is +X, so the palm (-X) faces it
	local hand = CFrame.fromMatrix(gripAt + Vector3.new(-pose.Palm, 0, 0), palmOut, wrist, palmOut:Cross(wrist))
	local leftRest
	if barrel then
		leftRest = Vector3.new(0, barrel.Under.Y * T.GunScale, math.min(barrel.Under.Z * T.GunScale, gripAt.Z + T.Reach))
	elseif long then
		leftRest = Vector3.new(0, bore - height * 0.2, gripAt.Z + T.Reach)
	else
		leftRest = gripAt + Vector3.new(0.14, -0.06, 0.04) -- a pistol: the off hand cups the firing hand
	end
	local g = {
		Model = model, Key = keyOf(held), Source = held, Long = long, Optics = optics, Pose = pose,
		Rel = origin:ToObjectSpace(model:GetPivot()), Sight = sight, GripAt = gripAt, Lo = lo, Hi = hi,
		MuzzleEnd = muzzle, LeftRest = leftRest, Hand = hand,
		Magazine = Vector3.new(0, lo.Y + height * 0.15, gripAt.Z + (if long then length * 0.12 else 0)),
	}
	local anchor = model.PrimaryPart
	g.Right = Instance.new("Attachment")
	g.Right.Name = "RightGrip"
	g.Right.Parent = anchor
	g.Left = Instance.new("Attachment")
	g.Left.Name = "LeftGrip"
	g.Left.Parent = anchor
	g.AnchorRel = origin:ToObjectSpace(anchor.CFrame) -- the anchor part in the gun's frame
	g.Right.CFrame = g.AnchorRel:Inverse() * hand
	g.Left.CFrame = g.AnchorRel:Inverse() * CFrame.new(leftRest)
	model.Parent = camera
	return g
end

local function arms(char)
	if ik.Char == char and ik.Right and ik.Right.Parent then
		return
	end
	clearArms()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and char:FindFirstChild("RightHand") and char:FindFirstChild("LeftHand")) then
		return
	end
	pcall(function()
		for _, side in { "Right", "Left" } do
			local pole = root:FindFirstChild("ViewGunPole" .. side) or Instance.new("Attachment")
			pole.Name = "ViewGunPole" .. side
			pole.Position = Vector3.new(if side == "Right" then T.Elbow.X else -T.Elbow.X, T.Elbow.Y, T.Elbow.Z)
			pole.Parent = root
			local c = Instance.new("IKControl")
			c.Name = "ViewGun" .. side
			c.Type = if side == "Right" then Enum.IKControlType.Transform else Enum.IKControlType.Position
			c.ChainRoot = char:FindFirstChild(side .. "UpperArm")
			c.EndEffector = char:FindFirstChild(side .. "Hand")
			c.Pole = pole
			c.SmoothTime = 0
			c.Enabled = false
			c.Parent = hum
			ik[side] = c
		end
		ik.Char = char
	end)
end

local function setArms(on)
	for _, side in { "Right", "Left" } do
		local c = ik[side]
		if c then
			c.Enabled = on and gun ~= nil
			if on and gun then
				c.Target = gun[side]
			end
		end
	end
end

-- ===== every frame =====
local function ease(now, target, dt, rate)
	return now + (target - now) * math.min(1, dt * rate)
end

-- state: { Aiming, Sprinting, Busy (reloading or changing a part), Lowered (binoculars, mantling), Stance,
-- Hidden (a scripted camera), Steady (0..1 extra steadiness) }
function ViewGun.Step(dt, state)
	if not T or not T.Enabled then
		return
	end
	dt = math.min(dt, 0.1)
	clock += dt
	local char = player.Character
	local held = char and char:FindFirstChild("HeldWeapon")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (held and hum and hum.Health > 0) or state.Hidden then
		if gun then
			clearGun()
			setArms(false)
		end
		-- the camera still gives back whatever punch it holds
		stepSpring(camPunch, Vector3.zero, dt)
		return
	end
	for _, p in held:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1 -- the owner sees the copy, never the one in the fist
		end
	end
	if not gun or gun.Source ~= held or gun.Key ~= keyOf(held) then
		clearGun()
		local key = keyOf(held)
		if failed == key then
			return -- this gun could not be copied: the plain view stays
		end
		local ok, made = pcall(build, held)
		gun = if ok then made else nil
		if not gun then
			failed = key
			if not ok then
				warn("ViewGun: " .. tostring(made))
			end
			return
		end
		failed = nil
		arms(char)
		setArms(true)
	elseif ik.Char ~= char then
		arms(char)
		setArms(true)
	end

	-- how the view turned this frame: the gun is left behind by it
	local look = camera.CFrame.LookVector
	if lastLook then
		local yawNow, yawThen = math.atan2(-look.X, -look.Z), math.atan2(-lastLook.X, -lastLook.Z)
		local dYaw = math.deg((yawNow - yawThen + math.pi) % (2 * math.pi) - math.pi)
		local dPitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)) - math.asin(math.clamp(lastLook.Y, -1, 1)))
		lag.p -= Vector3.new(dPitch, dYaw, 0) * T.Lag.Gain
	end
	lastLook = look
	aimBlend = ease(aimBlend, if state.Aiming then 1 else 0, dt, T.AimRate)
	sprintBlend = ease(sprintBlend, if state.Sprinting then 1 else 0, dt, T.PoseRate)
	busyBlend = ease(busyBlend, if state.Busy then 1 else 0, dt, T.PoseRate)
	lowBlend = ease(lowBlend, if state.Lowered then 1 else 0, dt, T.PoseRate)
	local limit = T.Lag.Hip + (T.Lag.Aim - T.Lag.Hip) * aimBlend
	if lag.p.Magnitude > limit then
		lag.p = lag.p.Unit * limit
	end
	stepSpring(lag, Vector3.zero, dt)
	stepSpring(kickRot, Vector3.zero, dt)
	stepSpring(kickPos, Vector3.zero, dt)

	-- breath and step
	local stanceSteady = T.Steady[state.Stance or "Stand"] or 1
	local calm = stanceSteady * (1 + (T.Sway.Aim - 1) * aimBlend)
	local swayP = math.sin(clock * T.Sway.Rate) * T.Sway.Degrees * calm
	local swayY = math.sin(clock * T.Sway.Rate * 0.53 + 1.3) * T.Sway.Degrees * 1.4 * calm
	local root = char:FindFirstChild("HumanoidRootPart")
	local speed = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
	bobPhase += dt * speed * T.Bob.Rate
	local walk = math.min(1, speed / 14) * (1 - 0.6 * aimBlend)
	local bob = Vector3.new(math.sin(bobPhase) * T.Bob.Side, -math.abs(math.cos(bobPhase)) * T.Bob.Drop, 0) * walk

	-- where the gun sits: at the hip, up at the eye, across the chest at a run, tipped over for a reload
	-- (the gun's frame is turned half round in the view: its +Z is the view's -Z, its +X the view's -X)
	-- aimed: the line of sight through the eye, the firing hand pose.Grip ahead of it
	local pose = gun.Pose
	local aimPos = Vector3.new(gun.Sight.X, -gun.Sight.Y, gun.GripAt.Z - pose.Grip)
	local pos = (aimPos + pose.Hip):Lerp(aimPos, aimBlend)
	local rot = Vector3.new(0, 0, T.HipRoll * (1 - aimBlend))
	local away = math.max(sprintBlend, lowBlend)
	pos = pos:Lerp(pos + T.Carry.Offset, away)
	rot = rot:Lerp(T.Carry.Rotation, away)
	pos = pos:Lerp(pos + T.Busy.Position, busyBlend)
	rot = rot:Lerp(rot + T.Busy.Rotation, busyBlend)

	local turn = Vector3.new(lag.p.X + swayP + kickRot.p.X, lag.p.Y + swayY + kickRot.p.Y, kickRot.p.Z + rot.Z)
	view = camera.CFrame
		* CFrame.new(pos + bob + kickPos.p)
		* CFrame.Angles(0, math.rad(rot.Y + turn.Y), 0)
		* CFrame.Angles(math.rad(rot.X + turn.X), 0, math.rad(turn.Z))
	local origin = view * CFrame.Angles(0, math.pi, 0) -- the gun's own frame: barrel along its +Z
	gun.Model:PivotTo(origin * gun.Rel)

	-- the off hand leaves the handguard for the magazine while the gun is being worked
	if busyBlend > 0.01 then
		local cycle = (math.sin(clock * T.Busy.Rate) + 1) / 2
		local mag = gun.Magazine + Vector3.new(0, -T.Busy.Pull * cycle, 0)
		gun.Left.CFrame = gun.AnchorRel:Inverse() * CFrame.new(gun.LeftRest:Lerp(mag, busyBlend))
	else
		gun.Left.CFrame = gun.AnchorRel:Inverse() * CFrame.new(gun.LeftRest)
	end

	-- both eyes open: a scope's housing fades while it is at the eye
	for _, p in gun.Optics do
		local shown = p:GetAttribute("ShownT") or 0
		p.Transparency = shown + (T.OpticFade - shown) * math.max(0, aimBlend * 2 - 1)
	end
end

-- The camera's share of a shot: a punch that comes back by itself. Returns this frame's change (degrees) for the
-- caller to turn the camera by; over time the changes sum to zero, so the climb of the muzzle stays the player's.
function ViewGun.CameraStep(dt)
	if not T then
		return Vector3.zero
	end
	stepSpring(camPunch, Vector3.zero, math.min(dt, 0.1))
	local change = camPunch.p - punchApplied
	punchApplied = camPunch.p
	return change
end

-- A shot. pitch and yaw are the server's recoil for this round (degrees).
function ViewGun.Kick(pitch, yaw, aiming)
	if not T then
		return
	end
	local R = T.Recoil
	local soft = if aiming then R.AimShare else 1
	local side = (math.random() - 0.5) * 2
	kickRot.v += Vector3.new(pitch * R.Rise, side * yaw * R.Twist, side * pitch * R.Roll) * soft
	kickPos.v += Vector3.new(side * R.Shift, pitch * R.Hop, pitch * R.Back) * soft
	camPunch.v += Vector3.new(pitch * T.Camera.Rise, side * yaw * T.Camera.Twist, -side * pitch * T.Camera.Roll)
end

-- Where the bore points, for the trigger; nil while no gun is shown (the caller falls back to the camera).
function ViewGun.Direction()
	return if view then view.LookVector else nil
end
-- The bore's mark on the screen, in pixels from the middle; nil with no gun.
function ViewGun.ScreenPoint()
	if not view then
		return nil
	end
	-- the bore in the camera's frame, through the lens by hand (the same on every screen size)
	local d = camera.CFrame:VectorToObjectSpace(view.LookVector)
	if d.Z > -0.05 then
		return nil
	end
	local half = camera.ViewportSize.Y / 2 / math.tan(math.rad(camera.FieldOfView) / 2)
	return d.X / -d.Z * half, -d.Y / -d.Z * half
end
-- The end of the barrel in the world: tracers and the flash start here.
function ViewGun.Muzzle()
	if not (view and gun) then
		return nil
	end
	return (view * CFrame.Angles(0, math.pi, 0)):PointToWorldSpace(gun.MuzzleEnd)
end
function ViewGun.Flash()
	local at = ViewGun.Muzzle()
	if not at then
		return
	end
	local flash = Instance.new("Part")
	flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch, flash.CastShadow = true, false, false, false, false
	flash.Shape = Enum.PartType.Ball
	flash.Material, flash.Color = Enum.Material.Neon, T.Flash.Color
	local size = T.Flash.Size * (0.7 + math.random() * 0.6)
	flash.Size = Vector3.new(size, size, size)
	flash.Transparency = 0.25
	flash.CFrame = CFrame.new(at + view.LookVector * size * 0.5)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = T.Flash.Color, T.Flash.Brightness, T.Flash.Range, true
	light.Parent = flash
	flash.Parent = camera
	task.delay(T.Flash.Seconds, function()
		flash:Destroy()
	end)
end

function ViewGun.Shown()
	return gun ~= nil and view ~= nil
end
function ViewGun.State() -- for tests
	return { Gun = gun, View = view, Aim = aimBlend, Lag = lag and lag.p, Kick = kickRot and kickRot.p, Punch = camPunch and camPunch.p, Arms = ik }
end

function ViewGun.Init(opts)
	player, camera, GunParts = opts.Player, opts.Camera, opts.GunParts
	T = opts.Config
	reset()
	player.CharacterAdded:Connect(function()
		clearGun()
		clearArms()
		reset()
	end)
end

return ViewGun
