-- ArmIK: puts a hand where it has to be. The melee swing and the guard are traced by the server in the body's
-- root space (shared/Swings), whatever the body's animation does, so the arms are solved here every frame from the
-- real shoulder: upper arm, a bent elbow and the wrist, with the weapon turned along the traced blade. The answer
-- is written into the joints' Transform after the animation step (Stepped), so no animation underneath can bend
-- it, and it fades back to the animation when nobody asks any more.
--
--   ArmIK.Hold(char, "Right"|"Left", grip, aim, opts)   call every frame while the hand is wanted
--     grip: where the palm goes, in the body's root space. aim: the way the weapon runs from the hand (root space),
--     nil = the hand stays in line with the forearm. opts.Pole: where the elbow points (root space vector),
--     opts.Optional: let go (fade out) when the point is out of the arm's reach, opts.Weight 0..1.
--   ArmIK.Solve(S, G, a, b, pole) -> elbow point (pure; tools/anims/preview.py mirrors it)
local RunService = game:GetService("RunService")

local ArmIK = {}

local FADE = 0.16 -- seconds a hand takes to go back to its animation
local STALE = 0.06 -- seconds without a Hold call before the fade starts
local POLE = { Right = Vector3.new(0.55, -0.7, 0.45), Left = Vector3.new(-0.55, -0.7, 0.45) }

local rigs = setmetatable({}, { __mode = "k" }) -- char -> { Right = arm, Left = arm }

-- the frame a joint turns in (world) and the child's side of it
local function parentFrame(j)
	if j:IsA("Motor6D") then
		return j.Part0 and j.Part0.CFrame * j.C0
	end
	return j.Attachment0 and j.Attachment0.WorldCFrame
end
local function c0(j)
	return if j:IsA("Motor6D") then j.C0 else j.Attachment0.CFrame
end
local function c1(j)
	return if j:IsA("Motor6D") then j.C1 else j.Attachment1.CFrame
end

local function find(char, name)
	local j = char:FindFirstChild(name, true)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return j
	end
	return nil
end

local function armOf(char, side)
	local set = rigs[char]
	if not set then
		set = {}
		rigs[char] = set
	end
	local arm = set[side]
	if arm == false and os.clock() - (set.missedAt or 0) > 1 then
		arm = nil -- the joints were not there yet (a body still loading): look again
	end
	if arm == nil then
		local s, e, w = find(char, side .. "Shoulder"), find(char, side .. "Elbow"), find(char, side .. "Wrist")
		if s and e and w then
			arm = { shoulder = s, elbow = e, wrist = w, weight = 0, at = 0, side = side }
		else
			arm = false
		end
		set[side] = arm
	end
	return arm or nil
end

-- The elbow of a two-bone arm from shoulder S to grip G (lengths a, b), bent toward `pole`. Also returns the grip
-- actually reached (G pulled in when it is too far or too near).
function ArmIK.Solve(S, G, a, b, pole)
	local to = G - S
	local d = to.Magnitude
	local dir = if d > 1e-4 then to / d else Vector3.new(0, -1, 0)
	d = math.clamp(d, math.abs(a - b) + 0.03, (a + b) * 0.985)
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local side = pole - dir * pole:Dot(dir)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(0, -1, 0) - dir * Vector3.new(0, -1, 0):Dot(dir)
		if side.Magnitude < 1e-3 then
			side = Vector3.new(1, 0, 0)
		end
	end
	side = side.Unit
	return S + dir * (a * cosA) + side * (a * math.sqrt(1 - cosA * cosA)), S + dir * d
end

local function frame(origin, y, z)
	-- a joint frame whose limb hangs along -y, bending toward -z
	z = (z - y * z:Dot(y))
	if z.Magnitude < 1e-4 then
		z = Vector3.new(0, 0, 1) - y * y.Z
	end
	z = z.Unit
	return CFrame.fromMatrix(origin, y:Cross(z), y, z)
end

-- where the weapon's line passes the wrist joint, in the hand joint's frame (x, y), from the held weapon's weld
local function gripOffset(char, arm)
	local held = arm.side == "Right" and char:FindFirstChild("HeldWeapon")
	local primary = held and held.PrimaryPart
	local weld = primary and primary:FindFirstChild("Grip")
	if weld and weld:IsA("JointInstance") then
		local p = (c1(arm.wrist):Inverse() * weld.C0).Position
		return Vector3.new(p.X, p.Y, 0)
	end
	return Vector3.new(0, -0.22, 0)
end

local function solve(char, arm, rootCF, dt)
	local s, e, w = arm.shoulder, arm.elbow, arm.wrist
	local ps = parentFrame(s)
	if not ps then
		return
	end
	local upper = c1(s):Inverse() * c0(e) -- shoulder joint to elbow joint, in the upper arm's joint frame
	local lower = c1(e):Inverse() * c0(w)
	local a, b = upper.Position.Magnitude, lower.Position.Magnitude
	local S = ps.Position
	local G = rootCF:PointToWorldSpace(arm.grip)
	local aim = arm.aim and rootCF:VectorToWorldSpace(arm.aim).Unit
	local pole = rootCF:VectorToWorldSpace(arm.pole or POLE[arm.side])
	local off = gripOffset(char, arm)
	-- the wrist sits a little off the grip: solve twice, the second time with the hand's own frame
	local W = G
	local E, upperCF, lowerCF, handCF
	for _ = 1, 2 do
		local reached
		E, reached = ArmIK.Solve(S, W, a, b, pole)
		local fore = (reached - E).Unit
		local up = -(E - S).Unit
		upperCF = frame(S, up, -(fore - up * fore:Dot(up)))
		lowerCF = CFrame.fromMatrix(E, upperCF.XVector, -fore, upperCF.XVector:Cross(-fore))
		local wristAt = reached
		if aim then
			local x = lowerCF.XVector - aim * lowerCF.XVector:Dot(aim)
			if x.Magnitude < 1e-3 then
				x = lowerCF.YVector - aim * lowerCF.YVector:Dot(aim)
			end
			x = x.Unit
			handCF = CFrame.fromMatrix(wristAt, x, (-aim):Cross(x), -aim)
		else
			handCF = lowerCF.Rotation + wristAt
		end
		W = G - handCF:VectorToWorldSpace(off)
	end
	arm.out = (G - S).Magnitude > (a + b) * 1.04
	local ts = ps:ToObjectSpace(upperCF)
	local pe = upperCF * upper
	local te = pe:ToObjectSpace(lowerCF)
	local pw = lowerCF * lower
	local tw = pw:ToObjectSpace(handCF)
	return ts.Rotation, te.Rotation, tw.Rotation
end

local function write(j, last, target, weight)
	local base = j.Transform
	if last and base == last then
		base = CFrame.identity -- nothing has written since we did: no animation drives this joint
	end
	local out = base:Lerp(target, weight)
	j.Transform = out
	return out
end

function ArmIK.Hold(char, side, grip, aim, opts)
	local arm = armOf(char, side)
	if not arm then
		return false
	end
	arm.grip, arm.aim = grip, aim
	arm.pole = opts and opts.Pole
	arm.optional = opts and opts.Optional
	arm.want = (opts and opts.Weight) or 1
	arm.at = os.clock()
	return true
end

-- True while the arm is being driven (a test and the fingers can ask).
function ArmIK.Active(char, side)
	local set = rigs[char]
	local arm = set and set[side]
	return arm ~= nil and arm ~= false and arm.weight > 0.01
end

function ArmIK.Step(dt)
	local now = os.clock()
	for char, set in rigs do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		if not root then
			rigs[char] = nil
			continue
		end
		for _, arm in set do
			if not arm or not arm.grip then
				continue
			end
			local live = now - arm.at < STALE
			local ts, te, tw
			if live or arm.weight > 0 then
				ts, te, tw = solve(char, arm, root.CFrame, dt)
			end
			local want = if live and ts and not (arm.optional and arm.out) then arm.want else 0
			local rate = dt / (if want > arm.weight then FADE * 0.6 else FADE)
			arm.weight = if want > arm.weight then math.min(want, arm.weight + rate) else math.max(want, arm.weight - rate)
			if ts and arm.weight > 0 then
				arm.ls = write(arm.shoulder, arm.ls, ts, arm.weight)
				arm.le = write(arm.elbow, arm.le, te, arm.weight)
				arm.lw = write(arm.wrist, arm.lw, tw, arm.weight)
			elseif arm.ls then
				-- handed back: a joint no animation drives would keep our last answer
				for _, pair in { { arm.shoulder, arm.ls }, { arm.elbow, arm.le }, { arm.wrist, arm.lw } } do
					if pair[1].Transform == pair[2] then
						pair[1].Transform = CFrame.identity
					end
				end
				arm.ls, arm.le, arm.lw = nil, nil, nil
				arm.grip = nil
			end
		end
	end
end

function ArmIK.Start()
	RunService.Stepped:Connect(function(_, dt)
		ArmIK.Step(dt)
	end)
end

return ArmIK
