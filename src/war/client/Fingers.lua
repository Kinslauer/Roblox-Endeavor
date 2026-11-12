-- Jointed fingers for the first-person hands (owner, 2026-11-12: "i think we need fingers", after a demo whose
-- hands are posed finger by finger in code). Nothing here is a drawn or recorded animation.
--
-- The soldier body's own hands are mittens on one bone. In the first-person view they are hidden and a hand made of
-- separate pieces (Assets.FrontBodies.Hands: palm, thumb mound, three joints a digit; shared/HandParts.lua has the
-- joints) is drawn on each wrist instead. Every frame each piece is placed from joint angles, and the angles come
-- from what the hand is doing:
--   * a hand holding something closes each finger, joint by joint, until it touches (rays against the gun's own
--     collision shape), so one rule fits every gun, magazine and handle;
--   * the trigger finger lies along the frame until the gun is aimed or fired, then reaches for the trigger itself
--     (a two-joint reach) and follows it when it moves;
--   * a hand holding nothing hangs half open.
-- Angles ease toward their goal, so fingers never snap.
--
-- The hand's frame: the wrist at the origin, fingers toward -Y, the thumb on the -Z side, the palm facing -X on a
-- right hand (side 1) and +X on a left (side -1). A pose is { Digit = { spread, a1, a2, a3 } } in degrees (the
-- thumb's first number is how far it is turned to face the fingers, 0 to 1).
local Fingers = {}

local T, H, camera, source, find
local hands = {} -- side name -> { Model, Parts = { piece = part }, Pose, Goal, Kind, SolveAt }
local hidden = {} -- the body's own hand pieces, kept out of the first-person view
local scanAt = 0
local clock = 0
local params

local rad = math.rad

-- ===== the pure part: where the joints are =====
-- The three joint frames of one digit and its tip. Each frame's -Y runs along that joint's bone.
function Fingers.Chain(wrist, side, name, a)
	local d = H.Digits[name]
	local root = Vector3.new(d.Root.X * side, d.Root.Y, d.Root.Z)
	local j1
	if name == "Thumb" then
		-- swung out to the side, turned to face the fingers, then bent
		j1 = wrist * CFrame.new(root) * CFrame.Angles(rad((a.Swing or T.ThumbSwing) - a[1] * T.ThumbTuck), 0, 0)
			* CFrame.Angles(0, side * rad(a[1] * T.ThumbRoll), 0) * CFrame.Angles(0, 0, -side * rad(a[2]))
	else
		j1 = wrist * CFrame.new(root) * CFrame.Angles(rad(a[1]), 0, 0) * CFrame.Angles(0, 0, -side * rad(a[2]))
	end
	local j2 = j1 * CFrame.new(0, -d.Lengths[1], 0) * CFrame.Angles(0, 0, -side * rad(a[3]))
	local j3 = j2 * CFrame.new(0, -d.Lengths[2], 0) * CFrame.Angles(0, 0, -side * rad(a[4]))
	return { j1, j2, j3 }, j3 * Vector3.new(0, -d.Lengths[3], 0)
end

-- Every piece's place for a pose: { piece = CFrame }.
function Fingers.Pieces(wrist, side, pose)
	local out = { Palm = wrist * CFrame.new(H.Centres.Palm) }
	out.Thenar = wrist * CFrame.new(H.Thenar.X * side, H.Thenar.Y, H.Thenar.Z)
	for _, name in H.Order do
		local d = H.Digits[name]
		local joints = Fingers.Chain(wrist, side, name, pose[name])
		for i = 1, 3 do
			out[d.Pieces[i]] = joints[i] * CFrame.new(H.Centres[d.Pieces[i]])
		end
	end
	return out
end

local function copyPose(p)
	local out = {}
	for name, a in p do
		out[name] = { a[1], a[2], a[3], a[4] }
	end
	return out
end
function Fingers.Relaxed()
	return copyPose(T.Relax)
end

-- Closes one digit on whatever `cast(a, b)` finds (true when the line from a to b is blocked): the first joint
-- turns until its bone touches or its limit, then the second, then the third. caps = the most each joint may bend.
-- Returns the angles and whether anything was touched.
function Fingers.Close(wrist, side, name, cast, caps, first, swing)
	local d = H.Digits[name]
	local a = { first, 0, 0, 0, Swing = swing }
	local touched = false
	for j = 1, 3 do
		local r = d.Radius[j]
		local function blocked()
			local joints, tip = Fingers.Chain(wrist, side, name, a)
			local f = joints[j]
			local pad = f.RightVector * (-side * r) -- the inside of the finger
			local from = f.Position + pad
			local to = (if j == 3 then tip else joints[j + 1].Position) + pad
			return cast(from, to)
		end
		local free = 0
		if blocked() then
			touched = true -- already against it with the joint straight
		else
			local angle = 0
			while angle < caps[j] do
				angle = math.min(caps[j], angle + T.Step)
				a[j + 1] = angle
				if blocked() then
					touched = true
					-- half a step back in, to sit closer to the surface
					a[j + 1] = angle - T.Step / 2
					if blocked() then
						a[j + 1] = free
					end
					break
				end
				free = angle
			end
		end
	end
	return a, touched
end

-- A two-joint reach: the angles that put the pad of a digit's last joint on a point (the trigger).
function Fingers.Reach(wrist, side, name, target)
	local d = H.Digits[name]
	local base = wrist * CFrame.new(d.Root.X * side, d.Root.Y, d.Root.Z)
	local t = base:PointToObjectSpace(target)
	local spread = math.clamp(math.deg(math.atan2(-t.Z, -t.Y)), -T.ReachSpread, T.ReachSpread)
	local along = math.sqrt(t.Y * t.Y + t.Z * t.Z)
	local inward = -side * t.X - d.Radius[3] * 0.6
	local l1, l2 = d.Lengths[1], d.Lengths[2] + d.Lengths[3] * 0.55
	local far = math.clamp(math.sqrt(along * along + inward * inward), math.abs(l1 - l2) + 0.004, l1 + l2 - 0.002)
	local toward = math.atan2(inward, along)
	local corner = math.acos(math.clamp((l1 * l1 + far * far - l2 * l2) / (2 * l1 * far), -1, 1))
	local bend = math.pi - math.acos(math.clamp((l1 * l1 + l2 * l2 - far * far) / (2 * l1 * l2), -1, 1))
	local a1 = math.clamp(math.deg(toward - corner), -12, 88)
	local a2 = math.clamp(math.deg(bend), 0, 105)
	return { spread, a1, a2, a2 * 0.3 }
end

-- The whole hand closed on what it holds. opts: { Trigger = point or nil (the index goes to it), Register = true
-- (the index stays along the frame), Open = true (holding nothing) }.
function Fingers.Grasp(wrist, side, cast, opts)
	opts = opts or {}
	local pose = {}
	for _, name in H.Order do
		local relax = T.Relax[name]
		if opts.Open then
			pose[name] = { relax[1], relax[2], relax[3], relax[4] }
		elseif name == "Index" and opts.Trigger then
			pose[name] = Fingers.Reach(wrist, side, name, opts.Trigger)
		else
			local caps = if name == "Thumb" then T.Limits.Thumb elseif name == "Index" and opts.Register then T.Register else T.Limits.Finger
			local thumb = name == "Thumb" and opts.Thumb or nil
			local first = if name == "Thumb" then (thumb and thumb.Opp or T.Opp) else T.Spread[name]
			local a, touched = Fingers.Close(wrist, side, name, cast, caps, first, thumb and thumb.Swing)
			if not touched then
				-- nothing in reach: hang as an idle finger does, no further than this digit may bend here
				a = { first, math.min(relax[2], caps[1]), math.min(relax[3], caps[2]), math.min(relax[4], caps[3]), Swing = a.Swing }
			end
			pose[name] = a
		end
	end
	return pose
end

-- ===== the pieces in the view =====
local SIDES = { Right = 1, Left = -1 }
local MATERIALS = { "Flesh", "HideLeather", "PlateSteel" }

local function clearHand(sideName)
	local h = hands[sideName]
	if h then
		h.Model:Destroy()
		hands[sideName] = nil
	end
end

-- What the body shows on this hand: the piece of its skin that is the hand (bare, gloved or steel).
local function shownHand(char, letter)
	local best
	for _, layer in char:GetChildren() do
		if layer:IsA("Model") and layer:GetAttribute("Kind") then
			for _, p in layer:GetChildren() do
				if p:IsA("BasePart") then
					local piece = string.split(p.Name, "_")[1]
					if piece == "Hand" .. letter or piece == "Glove" .. letter or piece == "CyArm" .. letter .. "Hand" then
						table.insert(hidden, p)
						if p.Transparency < 0.9 then
							local rank = if piece:sub(1, 2) == "Cy" then 3 elseif piece:sub(1, 5) == "Glove" then 2 else 1
							if not best or rank > best.Rank then
								best = { Part = p, Rank = rank }
							end
						end
					end
				end
			end
		end
	end
	return best and best.Part
end

local function buildHand(sideName, like)
	local material = like and string.match(like.Name, "_(%w+)$") or "Flesh"
	if not table.find(MATERIALS, material) then
		material = "Flesh"
	end
	local model = Instance.new("Model")
	model.Name = "ViewHand" .. sideName
	local parts = {}
	for _, p in source:GetChildren() do
		local piece, mat = string.match(p.Name, "^(%w+)_(%w+)$")
		if mat == material and p:IsA("BasePart") then
			local c = p:Clone()
			c.Anchored, c.CanCollide, c.CanTouch, c.CastShadow = true, false, false, false
			c.CanQuery = sideName == "Right" -- the off hand closes over the firing hand's fingers
			pcall(function()
				c.CollisionGroup = T.Group
			end)
			if like then
				c.Color = like.Color
				local mine, theirs = c:FindFirstChildOfClass("SurfaceAppearance"), like:FindFirstChildOfClass("SurfaceAppearance")
				if mine and theirs then
					pcall(function()
						mine.Color = theirs.Color
					end)
				end
			end
			c.Parent = model
			parts[piece] = c
		end
	end
	if not parts.Palm then
		model:Destroy()
		return nil
	end
	model.Parent = camera
	return { Model = model, Parts = parts, Kind = like and like.Name or "", Pose = Fingers.Relaxed(), Goal = Fingers.Relaxed(), SolveAt = 0 }
end

function Fingers.Hide()
	for name in SIDES do
		clearHand(name)
	end
	for _, p in hidden do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	scanAt = 0
end

-- The wrist's frame from the body's hand part (the part reaches from the wrist to the fingertips).
function Fingers.Wrist(handPart)
	return handPart.CFrame * CFrame.new(0, handPart.Size.Y / 2, 0)
end
-- The hand part's frame that puts the wrist at `wrist` (for the arm's reach target).
function Fingers.PartFor(wrist, sizeY)
	return wrist * CFrame.new(0, -sizeY / 2, 0)
end
-- The wrist's frame that lays the middle of the palm on `point`, the palm facing along `normal` (into what it
-- holds), the forearm leaving along `toWrist`.
function Fingers.WristAt(side, point, normal, toWrist)
	local y = toWrist.Unit
	local n = normal - y * normal:Dot(y)
	n = if n.Magnitude > 1e-4 then n.Unit else y:Cross(Vector3.new(0, 0, 1)).Unit
	local x = n * -side -- the palm faces -X on a right hand
	local rot = CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
	local palm = Vector3.new(-side * (H.PalmHalf + T.PalmGap), T.Palm.Y, T.Palm.Z)
	return rot + (point - rot * palm)
end

-- state: { Char, Solids = { instances the fingers may close on }, Trigger = point in the world or nil, OnTrigger =
-- the firing finger is on it, LeftOpen = the off hand holds nothing }
function Fingers.Step(dt, state)
	if not (T and T.Enabled) then
		return false
	end
	if not source then
		source = find and find() -- the pieces come from the server; until they arrive the hands stay as they are
		if not source or #source:GetChildren() == 0 then
			source = nil
			return false
		end
	end
	clock += dt
	local char = state.Char
	local rescan = clock >= scanAt
	if rescan then
		scanAt = clock + 0.5
		table.clear(hidden)
	end
	for sideName, side in SIDES do
		local part = char:FindFirstChild(sideName .. "Hand")
		local h = hands[sideName]
		if rescan and part then
			local like = shownHand(char, sideName:sub(1, 1))
			local kind = like and like.Name or ""
			if not h or h.Kind ~= kind then
				clearHand(sideName)
				h = buildHand(sideName, like)
				hands[sideName] = h
			end
			if h and like then
				h.Tint = like.Color
			end
		end
		if h and part then
			local wrist = Fingers.Wrist(part)
			if clock >= h.SolveAt then
				h.SolveAt = clock + T.SolveEvery
				if not params then
					params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					pcall(function()
						params.CollisionGroup = T.Group
					end)
				end
				local solids = table.clone(state.Solids or {})
				if sideName == "Left" and hands.Right then
					table.insert(solids, hands.Right.Model)
				end
				params.FilterDescendantsInstances = solids
				local function cast(a, b)
					return workspace:Raycast(a, b - a, params) ~= nil
				end
				if sideName == "Right" then
					h.Goal = Fingers.Grasp(wrist, side, cast, { Trigger = if state.OnTrigger then state.Trigger else nil, Register = true, Thumb = T.FiringThumb })
				else
					h.Goal = Fingers.Grasp(wrist, side, cast, { Open = state.LeftOpen == true })
				end
			end
			local k = math.min(1, dt * T.Rate)
			for name, goal in h.Goal do
				local now = h.Pose[name]
				for i = 1, 4 do
					now[i] += (goal[i] - now[i]) * k
				end
				if name == "Thumb" then
					now.Swing = (now.Swing or T.ThumbSwing) + ((goal.Swing or T.ThumbSwing) - (now.Swing or T.ThumbSwing)) * k
				end
			end
			for piece, cf in Fingers.Pieces(wrist, side, h.Pose) do
				local p = h.Parts[piece]
				if p then
					p.CFrame = cf
				end
			end
		end
	end
	for _, p in hidden do
		p.LocalTransparencyModifier = 1
	end
	return true
end

function Fingers.State() -- for tests
	return hands
end

-- opts: { Camera, Config = Config.WarMovement.Fingers, HandParts, Find = function returning the folder of hand
-- pieces (ReplicatedStorage.ViewHands) or nil while it is not there yet }
function Fingers.Init(opts)
	T, H, camera, find = opts.Config, opts.HandParts, opts.Camera, opts.Find
	source, hands, hidden, scanAt, clock, params = nil, {}, {}, 0, 0, nil
end

return Fingers
