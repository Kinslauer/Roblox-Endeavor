-- The Front's gun handling, carried to Endeavor (owner, 2026-11-12: "Can anything be gleamed from this for
-- endeavor's side? ... the particle effects sounds and everything else should be portable"). Endeavor is played over
-- the shoulder, so this works on the gun in the hand of every body near the camera, the own and everyone else's,
-- not on a copy in a first-person view:
--   * the gun's own pieces move by code (shared/GunMotion.lua, the same timelines as the Front): the slide or the
--     carrier cycles on every shot and locks back on an empty magazine, the trigger is squeezed, a hand-racked gun
--     (the Whisper) holds its case until T draws the slide back, the magazine is stripped out, carried off, brought
--     back, stopped short, driven home and tugged;
--   * the off hand goes to the magazine and the charging handle (an IKControl on the left arm, weighted by the move);
--   * every contact jolts the gun on a spring, and so does each shot;
--   * cases fly from the port and bounce with a ring, the flash and its light start at the real muzzle, a breath of
--     smoke leaves it, and each step of the hands has its own sound.
-- Nothing is drawn or recorded: the moves are key poses joined by curves. Everything here is local to this client.
local GunFeel = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local GunMotion, Weapons, Sounds, GunParts
local G -- Config.GunFeel
local M -- Config.WarMovement.GunMotion (the Front's timelines and jolts)
local camera
local guns = {} -- [character] = state, see build()
local casings, drops = {}, {}
local clock, scanAt = 0, 0
local params

local I = CFrame.identity
-- the whole pistols are authored barrel +Y, grip down -Z; turned here to the rifles' frame (barrel +Z, up +Y, left +X)
local PISTOL_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local MOVING = { Slide = true, Carrier = true, Charging = true, Magazine = true, Trigger = true }

local function vmin(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
local function vmax(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

-- ===== springs (the gun jolting in the hand) =====
local function spring()
	return { p = Vector3.zero, v = Vector3.zero }
end
local function stepSpring(s, f, d, dt)
	local w = 2 * math.pi * f
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	for _ = 1, steps do
		s.v += (-s.p * (w * w) - s.v * (2 * d * w)) * h
		s.p += s.v * h
	end
end

local function defOf(char, held)
	return Weapons.Defs[char:GetAttribute("Weapon") or ""] or Weapons.Defs[held:GetAttribute("WeaponId") or ""]
end
local function keyOf(held)
	return ("%s|%s|%d"):format(tostring(held:GetAttribute("WeaponId")), tostring(held:GetAttribute("Build")), #held:GetChildren())
end

-- Everything about the held gun is measured from its own parts in the gun's frame. A part is placed through the
-- weld that holds it to the gun's first part (C0), and that part through the hand's Grip weld (C1); moving a piece
-- is rewriting those, locally.
local function build(char, held)
	local primary = held.PrimaryPart
	local grip = primary and primary:FindFirstChild("Grip")
	if not (grip and grip:IsA("Weld")) then
		return nil
	end
	local def = defOf(char, held)
	if not (def and Weapons.IsGun(def)) then
		return nil
	end
	local turn = if math.abs(grip.C0.UpVector.Y) < 0.5 then PISTOL_TURN else I
	local F = grip.C1:Inverse() * turn -- the gun's frame in the first part's space
	local Finv = F:Inverse()
	local entries = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local moving = {}
	for _, p in held:GetDescendants() do
		if p:IsA("BasePart") then
			local weld, q = nil, I
			if p ~= primary then
				for _, w in p:GetChildren() do
					if w:IsA("Weld") and w.Part0 == primary and w.Part1 == p then
						weld = w
						break
					end
				end
				if not weld then
					continue
				end
				q = weld.C0
			end
			local rel = Finv * q
			local at, half = rel.Position, p.Size / 2
			local rx, ry, rz = rel.RightVector, rel.UpVector, rel.LookVector
			local ext = Vector3.new(
				math.abs(rx.X) * half.X + math.abs(ry.X) * half.Y + math.abs(rz.X) * half.Z,
				math.abs(rx.Y) * half.X + math.abs(ry.Y) * half.Y + math.abs(rz.Y) * half.Z,
				math.abs(rx.Z) * half.X + math.abs(ry.Z) * half.Y + math.abs(rz.Z) * half.Z
			)
			local group = string.split(p.Name, "_")[1]
			local e = { Part = p, Weld = weld, Base = q, Group = if MOVING[group] then group else nil }
			table.insert(entries, e)
			if p:GetAttribute("Component") ~= "Optic" then
				lo, hi = vmin(lo, at - ext), vmax(hi, at + ext)
			end
			if e.Group then
				local m = moving[group]
				if not m then
					m = { Lo = at - ext, Hi = at + ext, Parts = {} }
					moving[group] = m
				end
				table.insert(m.Parts, p)
				m.Lo, m.Hi = vmin(m.Lo, at - ext), vmax(m.Hi, at + ext)
			end
		end
	end
	if #entries == 0 or lo.X == math.huge then
		return nil
	end
	local long = def.Family == "Rifle"
	local length, height = hi.Z - lo.Z, hi.Y - lo.Y
	local gunId = held:GetAttribute("WeaponId")
	local spec = GunParts and GunParts.Guns[gunId]
	local scale = (def.Model and def.Model.Scale) or 1
	local option = string.split(tostring(held:GetAttribute("Build") or ""), "|")[1]
	local barrel = spec and (spec.Barrels[option] or spec.Barrels.Standard)
	local bore = if barrel then barrel.End.Y * scale else hi.Y - height * (if long then 0.25 else 0.12)
	local gripAt = if long then Vector3.new(0, bore - height * 0.36, lo.Z + length * 0.33) else Vector3.new(0, hi.Y - height * 0.62, lo.Z + length * 0.22)
	local actionName = if moving.Slide then "Slide" elseif moving.Carrier then "Carrier" else nil
	local action = actionName and moving[actionName]
	local mag = moving.Magazine
	local shape = {
		Long = long, Action = actionName, Charging = moving.Charging ~= nil, GripAt = gripAt, LeftRest = gripAt, Lo = lo, Hi = hi,
		ActionLength = if action then action.Hi.Z - action.Lo.Z else 0,
		Mag = if mag then (mag.Lo + mag.Hi) / 2 else Vector3.new(0, lo.Y + height * 0.15, gripAt.Z),
		MagSize = if mag then mag.Hi - mag.Lo else Vector3.new(0.1, height * 0.3, 0.2),
		TopFed = mag ~= nil and (mag.Lo.Y + mag.Hi.Y) / 2 > gripAt.Y + height * 0.3,
		Manual = Weapons.ActionOf(def) == "Single",
	}
	if action then
		local mid = (action.Lo + action.Hi) / 2
		shape.Port = Vector3.new(action.Lo.X, mid.Y, mid.Z + shape.ActionLength * 0.15)
		if moving.Charging then
			local c = moving.Charging
			shape.Handle = Vector3.new(0, (c.Lo.Y + c.Hi.Y) / 2, c.Lo.Z)
		elseif long then
			shape.Handle = Vector3.new(action.Lo.X, mid.Y, mid.Z)
		else
			shape.Handle = Vector3.new(0, action.Hi.Y, action.Lo.Z + shape.ActionLength * 0.15)
		end
	else
		shape.Port = Vector3.new(lo.X, bore, gripAt.Z)
		shape.Handle = shape.Port
	end
	local g = {
		Char = char, Held = held, Key = keyOf(held), Primary = primary, Grip = grip, GripC1 = grip.C1, F = F, Finv = Finv,
		Entries = entries, Moving = moving, Shape = shape, Def = def, Long = long, Size = math.max(length, 0.5),
		Muzzle = Vector3.new(0, bore, hi.Z), PrimaryGroup = string.split(primary.Name, "_")[1],
		Motion = GunMotion.New(shape, M), Kick = spring(), Push = spring(), Idle = true, Hidden = {},
	}
	if not MOVING[g.PrimaryGroup] then
		g.PrimaryGroup = nil
	end
	g.Motion:Start("Draw")
	g.Motion.Seq.Draw = nil -- drawn already: the third-person body has its own draw
	return g
end

local function restore(g)
	if g.Grip.Parent then
		g.Grip.C1 = g.GripC1
	end
	for _, e in g.Entries do
		if e.Weld and e.Weld.Parent then
			e.Weld.C0 = e.Base
		end
		if e.Part.Parent then
			e.Part.LocalTransparencyModifier = 0
		end
	end
	if g.Ik then
		g.Ik:Destroy()
	end
	if g.Target then
		g.Target:Destroy()
	end
end

-- ===== the left arm on the magazine and the handle =====
local function leftArm(g)
	if g.Ik ~= nil then
		return g.Ik or nil
	end
	g.Ik = false
	local char = g.Char
	local hum = char:FindFirstChildOfClass("Humanoid")
	local upper, hand = char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("LeftHand")
	if not (hum and upper and hand) then
		return nil
	end
	pcall(function()
		local target = Instance.new("Attachment")
		target.Name = "GunFeelLeft"
		target.Parent = g.Primary
		local c = Instance.new("IKControl")
		c.Name = "GunFeelLeft"
		c.Type = Enum.IKControlType.Position
		c.ChainRoot, c.EndEffector, c.Target = upper, hand, target
		c.SmoothTime = 0.04
		c.Weight = 0
		c.Enabled = false
		c.Parent = hum
		g.Ik, g.Target = c, target
	end)
	return g.Ik or nil
end

-- ===== cases and magazines in the world =====
local function fx()
	return camera
end
local function throwCase(g, gunWorld)
	local B = G.Brass
	local part = Instance.new("Part")
	part.Name = "Case"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material, part.Color = Enum.Material.Metal, M.Brass.Color
	part.Size = M.Brass.Size * (if g.Long then B.RifleSize else B.PistolSize)
	part.CFrame = gunWorld * CFrame.new(g.Shape.Port)
	part.Parent = fx()
	local root = g.Char:FindFirstChild("HumanoidRootPart")
	local carry = if root then root.AssemblyLinearVelocity else Vector3.zero
	local out = gunWorld:VectorToWorldSpace(Vector3.new(-B.Speed * (0.8 + math.random() * 0.4), B.Up * (0.7 + math.random() * 0.6), -B.Back * math.random()))
	table.insert(casings, {
		Part = part, Velocity = out + carry, Until = clock + B.Seconds, Ring = math.random() * 0.3 + 0.85,
		Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * M.Brass.Spin,
	})
	if #casings > B.Max then
		table.remove(casings, 1).Part:Destroy()
	end
end
local function heard(at)
	return (camera.CFrame.Position - at).Magnitude < G.HearMech
end
local function stepFlying(list, dt, isModel)
	if #list == 0 then
		return
	end
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
	end
	local skip = { camera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	for i = #list, 1, -1 do
		local c = list[i]
		local obj = if isModel then c.Model else c.Part
		if clock > c.Until or not obj.Parent then
			obj:Destroy()
			table.remove(list, i)
		elseif not c.Rest then
			c.Velocity += Vector3.new(0, -workspace.Gravity * dt, 0)
			local cf = if isModel then obj:GetPivot() else obj.CFrame
			local step = c.Velocity * dt
			local hit = if c.Velocity.Y < 0 then workspace:Raycast(cf.Position, step * 1.2 - Vector3.new(0, if isModel then 0.15 else 0, 0), params) else nil
			if hit then
				if not c.Bounced and heard(hit.Position) then
					if isModel then
						Sounds.Play("MagDrop", hit.Position, { Volume = 0.7 })
					else
						Sounds.Play("BrassTink", hit.Position, { Volume = 0.45, Pitch = c.Ring })
					end
				end
				if c.Bounced then
					c.Rest = true
				else
					c.Bounced = true
					local bounce = if isModel then M.DropMag.Bounce else M.Brass.Bounce
					c.Velocity = Vector3.new(c.Velocity.X * 0.45, -c.Velocity.Y * bounce, c.Velocity.Z * 0.45)
					local at = CFrame.new(hit.Position + Vector3.new(0, 0.03, 0)) * cf.Rotation
					if isModel then
						obj:PivotTo(at)
					else
						obj.CFrame = at
					end
				end
			else
				local spin = c.Spin * dt
				local at = CFrame.new(cf.Position + step) * cf.Rotation * CFrame.Angles(spin.X, spin.Y, spin.Z)
				if isModel then
					obj:PivotTo(at)
				else
					obj.CFrame = at
				end
			end
		end
	end
end
local function dropMagazine(g)
	local m = g.Moving.Magazine
	if not m then
		return
	end
	local model = Instance.new("Model")
	model.Name = "DroppedMagazine"
	for _, p in m.Parts do
		local c = p:Clone()
		for _, d in c:GetChildren() do
			if d:IsA("JointInstance") or d:IsA("Attachment") then
				d:Destroy()
			end
		end
		c.LocalTransparencyModifier = 0
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
		c.CFrame = p.CFrame
		c.Parent = model
	end
	model.Parent = fx()
	local root = g.Char:FindFirstChild("HumanoidRootPart")
	table.insert(drops, { Model = model, Velocity = (if root then root.AssemblyLinearVelocity else Vector3.zero) + Vector3.new(0, -2, 0), Until = clock + M.DropMag.Seconds,
		Spin = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.3, math.random() - 0.5) * M.DropMag.Spin })
	if #drops > 4 then
		table.remove(drops, 1).Model:Destroy()
	end
end

-- ===== the muzzle =====
local function flash(g, gunWorld)
	local at = gunWorld * g.Muzzle
	local dir = gunWorld.LookVector
	local F = G.Flash
	local quiet = (g.Def.Noise or 100) <= 20
	local size = F.Size * (if g.Long then 1.4 else 1) * (if quiet then 0.45 else 1) * (0.75 + math.random() * 0.5)
	local ball = Instance.new("Part")
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
	ball.Shape = Enum.PartType.Ball
	ball.Material, ball.Color, ball.Transparency = Enum.Material.Neon, F.Color, if quiet then 0.55 else 0.2
	ball.Size = Vector3.new(size, size, size)
	ball.CFrame = CFrame.new(at + dir * size * 0.45)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = F.Color, F.Brightness * (if quiet then 0.35 else 1), F.Range * (if quiet then 0.5 else 1)
	light.Shadows = (camera.CFrame.Position - at).Magnitude < F.ShadowWithin
	light.Parent = ball
	ball.Parent = fx()
	task.delay(F.Seconds, function()
		ball:Destroy()
	end)
	-- a breath of smoke from the muzzle that drifts and thins
	local S = G.Smoke
	local puff = Instance.new("Part")
	puff.Anchored, puff.CanCollide, puff.CanQuery, puff.CanTouch, puff.Transparency = true, false, false, false, 1
	puff.Size = Vector3.new(0.1, 0.1, 0.1)
	puff.CFrame = CFrame.lookAt(at, at + dir)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(S.Color)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, S.Transparency), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S.Size * 0.4), NumberSequenceKeypoint.new(1, S.Size * (if g.Long then 1.6 else 1)) })
	e.Lifetime = NumberRange.new(S.Seconds * 0.6, S.Seconds)
	e.Speed = NumberRange.new(S.Speed * 0.5, S.Speed)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Front
	e.Acceleration = Vector3.new(0, S.Rise, 0)
	e.Drag = 3
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Rate = 0
	e.LightInfluence = 1
	e.Parent = puff
	puff.Parent = fx()
	e:Emit(if quiet then 1 else S.Count)
	task.delay(S.Seconds + 0.2, function()
		puff:Destroy()
	end)
	return at
end

-- ===== every frame =====
local function gunWorldOf(g)
	return g.Primary.CFrame * g.Wrote:Inverse() * g.F -- the gun's frame with no move on it
end

local function step(g, dt)
	local char = g.Char
	local reloading = char:GetAttribute("Reloading") == true
	local mag = char:GetAttribute("Mag")
	local action = Weapons.ActionOf(g.Def)
	-- the slide or bolt held back on an empty magazine (not a hand-racked gun: its slide is locked shut for quiet)
	-- (through a reload it stays back until the hand or the thumb lets it go)
	local r0 = g.Reload
	local open = type(mag) == "number" and mag <= 0 and not g.Shape.Manual and action ~= nil and (not reloading or (r0 ~= nil and not r0.RackStarted))
	local motion = g.Motion:Step(dt, { BoltOpen = open, Checking = false, NoMag = r0 ~= nil and not r0.InStarted,
		Aim = if char:GetAttribute("Aiming") then 1 else 0 })
	-- the reload as its steps: out, in, and the action if the gun was empty (the server times only the whole)
	local r = g.Reload
	if r then
		if not r.InStarted and clock >= r.InAt then
			r.InStarted = true
			g.Motion:Start("MagIn", { Seconds = r.InSeconds })
		elseif r.InStarted and not r.RackStarted and r.Rack and clock >= r.RackAt then
			r.RackStarted = true
			if r.Release then
				g.Motion:Start("Release")
			else
				g.Motion:Start("Rack", { Seconds = r.RackSeconds })
			end
		end
		if clock > r.Ends then
			g.Reload = nil
		end
	end
	stepSpring(g.Kick, G.Spring.Frequency, G.Spring.Damping, dt)
	stepSpring(g.Push, G.Spring.Frequency, G.Spring.Damping, dt)
	if motion.Kick then
		g.Kick.v += motion.Kick.Rot * G.JoltShare
		g.Push.v += motion.Kick.Pos * G.JoltShare
	end
	-- sounds on the marks of the hands' timelines, near enough to hear the metal
	local marks = motion.Marks
	if next(marks) and heard(g.Primary.Position) then
		local at = g.Primary
		if marks.Strip then
			Sounds.Play("MagOut", at, { Volume = 0.6 })
		end
		if marks.Seat then
			Sounds.Play("MagIn", at, { Volume = 0.75 })
		end
		if marks.Back then
			Sounds.Play("SlideBack", at, { Volume = 0.6, Pitch = if g.Long then 0.85 else 1.05 })
		end
		if marks.Home then
			Sounds.Play("SlideHome", at, { Volume = 0.7, Pitch = if g.Long then 0.85 else 1.05 })
		end
	end

	-- what to write: each moving group's offset and the whole gun's turn and shift about the grip
	local rot = motion.Rot * G.WholeShare + g.Kick.p
	local pos = motion.Pos * G.WholeShare + g.Push.p
	local quiet = rot.Magnitude < 1e-3 and pos.Magnitude < 1e-4 and next(motion.Parts) == nil and next(motion.Hide) == nil
	if quiet and g.Idle then
		return motion
	end
	g.Idle = quiet
	local at = g.Shape.GripAt
	local whole = CFrame.new(pos) * CFrame.new(at) * CFrame.Angles(math.rad(-rot.X), math.rad(rot.Y), math.rad(rot.Z)) * CFrame.new(-at)
	local moves = {}
	for name, v in motion.Parts do
		moves[name] = CFrame.new(v)
	end
	local F, Finv = g.F, g.Finv
	local mP = (g.PrimaryGroup and moves[g.PrimaryGroup]) or I
	local D = F * whole * mP * Finv
	local Dinv = D:Inverse()
	g.Wrote = D -- how far the first part is from where it would sit (so the gun's own frame can be found again)
	g.Grip.C1 = Dinv * g.GripC1
	for _, e in g.Entries do
		if e.Weld then
			local m = (e.Group and moves[e.Group]) or I
			e.Weld.C0 = Dinv * F * whole * m * Finv * e.Base
		end
		local hide = e.Group ~= nil and motion.Hide[e.Group] == true
		if hide ~= (g.Hidden[e.Part] == true) then
			g.Hidden[e.Part] = hide or nil
			e.Part.LocalTransparencyModifier = if hide then 1 else 0
		end
	end
	-- the off hand
	local ik = (motion.LeftWeight > 0.01 and motion.Left) and leftArm(g) or (g.Ik or nil)
	if ik then
		if motion.Left and motion.LeftWeight > 0.01 then
			g.Target.CFrame = Dinv * F * whole * CFrame.new(motion.Left)
			ik.Weight = math.clamp(motion.LeftWeight, 0, 1)
			ik.Enabled = true
		else
			ik.Enabled = false
		end
	end
	return motion
end

local function scan()
	local seen = {}
	local function consider(char)
		if seen[char] then
			return
		end
		seen[char] = true
		local held = char:FindFirstChild("HeldWeapon")
		local g = guns[char]
		if g and (g.Held ~= held or not held or g.Key ~= keyOf(held)) then
			restore(g)
			guns[char] = nil
			g = nil
		end
		if held and not g then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - camera.CFrame.Position).Magnitude < G.Range then
				local ok, made = pcall(build, char, held)
				if ok and made then
					made.Wrote = I
					guns[char] = made
				elseif not ok then
					warn("GunFeel: " .. tostring(made))
				end
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			consider(p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("NPC") do
		if m:IsA("Model") then
			consider(m)
		end
	end
	for char, g in guns do
		local root = char:FindFirstChild("HumanoidRootPart")
		if not seen[char] or not char.Parent or not root or (root.Position - camera.CFrame.Position).Magnitude > G.Range * 1.2 then
			restore(g)
			guns[char] = nil
		end
	end
end

function GunFeel.Step(dt)
	if not (G and G.Enabled) then
		return
	end
	dt = math.min(dt, 0.1)
	clock += dt
	if clock >= scanAt then
		scanAt = clock + G.ScanEvery
		scan()
	end
	for char, g in guns do
		if not g.Primary.Parent or not g.Grip.Parent then
			guns[char] = nil
		else
			local ok, motion = pcall(step, g, dt)
			if not ok then
				warn("GunFeel: " .. tostring(motion))
				restore(g)
				guns[char] = nil
			elseif motion then
				g.LeftGrip = if motion.LeftWeight > 0.3 then motion.Grip else nil
				if motion.Brass then
					throwCase(g, gunWorldOf(g))
				end
				if motion.DropMag then
					dropMagazine(g)
				end
			end
		end
	end
	stepFlying(casings, dt, false)
	stepFlying(drops, dt, true)
end

local function gunFor(char)
	if not (G and G.Enabled and typeof(char) == "Instance") then
		return nil
	end
	local g = guns[char]
	if not g or g.Held.Parent ~= char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (root and (root.Position - camera.CFrame.Position).Magnitude < G.Range) then
			return nil
		end
		scan()
		g = guns[char]
	end
	return g
end

-- A round left the gun in this hand. Returns the muzzle in the world (where the tracer starts), or nil when this
-- body's gun is not followed (the caller keeps its own guess).
function GunFeel.Shot(char)
	local g = gunFor(char)
	if not g then
		return nil
	end
	g.Motion:Shot()
	g.Idle = false
	local K = G.Kick
	local heavy = if g.Long then K.Rifle else K.Pistol
	local side = (math.random() - 0.5) * 2
	g.Kick.v += Vector3.new(heavy.Rise, side * heavy.Twist, side * heavy.Roll)
	g.Push.v += Vector3.new(0, heavy.Hop, -heavy.Back)
	local world = gunWorldOf(g)
	if heard(world.Position) and not g.Shape.Manual then
		Sounds.Play("ActionCycle", g.Primary, { Volume = 0.35, Pitch = (if g.Long then 0.9 else 1.15) * (0.95 + math.random() * 0.1) })
	end
	return flash(g, world)
end

-- The magazine change (CombatEvent "Reload", the server's whole time). Returns true when the hands are shown doing
-- it here (the caller then leaves the sounds to this module).
function GunFeel.Reload(char, seconds)
	local g = gunFor(char)
	if not g then
		return false
	end
	local R = G.Reload
	local empty = (char:GetAttribute("Mag") or 1) <= 0
	local out = seconds * R.Out
	local into = seconds * R.In
	local rack = g.Shape.Manual or empty
	g.Motion:Start("MagOut", { Seconds = out, Keep = true })
	g.Reload = {
		InAt = clock + out + seconds * R.Gap, InSeconds = into, Rack = rack and g.Shape.Action ~= nil,
		RackAt = clock + out + seconds * R.Gap + into, RackSeconds = math.max(0.25, seconds * R.Rack),
		Release = empty and not g.Long and not g.Shape.Manual, Ends = clock + seconds + 0.5,
	}
	g.Idle = false
	return true
end
-- The hand draws the action back (T on a hand-racked gun, clearing a jam).
function GunFeel.Rack(char, seconds)
	local g = gunFor(char)
	if not g then
		return false
	end
	g.Motion:Start("Rack", { Seconds = math.max(0.25, seconds or 0.5) })
	g.Idle = false
	return true
end
-- A dry trigger: the finger squeezes, nothing happens.
function GunFeel.Click(char)
	local g = gunFor(char)
	if g then
		g.Motion:Click()
		g.Idle = false
	end
end

-- What the off hand is doing on this body's gun ("Mag", "Handle", "Pouch") or nil (its rest): client/Hands closes
-- the fingers to match.
function GunFeel.LeftGrip(char)
	local g = guns[char]
	return g and g.LeftGrip
end

function GunFeel.State() -- for tests
	return { Guns = guns, Casings = casings, Drops = drops }
end

function GunFeel.Init(opts)
	GunMotion, Weapons, Sounds, GunParts = opts.GunMotion, opts.Weapons, opts.Sounds, opts.GunParts
	G, M, camera = opts.Config, opts.Motion, opts.Camera
	if not (G and M) then
		return
	end
	RunService.Heartbeat:Connect(GunFeel.Step)
end

return GunFeel
