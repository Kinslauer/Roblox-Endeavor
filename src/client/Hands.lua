-- Jointed fingers on every body (owner, 2026-11-12: "I do think they should also get fingers, therefore theyd also
-- need them in third person. Your call, i really want the melee to shine"). The Front draws them only in its
-- first-person view; Endeavor is played over the shoulder, so here every body near the camera gets them: the own,
-- other conduits', every hostile's.
--
-- The body's hands are mittens on one bone. Their mesh (the skin piece "Hands_<material>") is hidden on this client
-- and a hand of separate pieces (Assets.FrontBodies.Hands, cloned by the server into ReplicatedStorage.ViewHands) is
-- placed on each wrist every frame, scaled to the body's hand. The fingers come from shared/Fingers.lua, the Front's
-- own rules: each finger closes joint by joint until it touches. What it closes on is a handle of the right
-- thickness in the palm (a sword's grip, a sledge's haft, a pistol grip, a rifle's handguard, a magazine, a fist's
-- own palm), so a hold is worked out once per kind and side and then only placed: no ray is cast per body.
--   * a melee weapon: the hand closes round its grip; the off hand closes on the haft when the guard or a two-handed
--     blow brings it there, and opens again when it leaves;
--   * fists: closed;
--   * a gun: the firing hand round the grip, its first finger along the frame until the body aims, then on the
--     trigger; the off hand on a rifle's handguard, and on the magazine or the handle while the hands work the gun;
--   * nothing held: half open, as an idle hand hangs.
local Hands = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Fingers, HP, Weapons, GunFeel
local C -- Config.Hands
local FT -- Config.WarMovement.Fingers
local camera, find, source
local bodies = {} -- [character] = { Sides = { Right = hand, Left = hand }, Hidden = { parts }, Scale }
local holds = {} -- [key] = a pose (solved once)
local clock, scanAt, frame = 0, 0, 0

local SIDES = { Right = 1, Left = -1 }
local MATERIALS = { Flesh = true, HideLeather = true, PlateSteel = true }

-- ===== the holds =====
-- A handle of radius r in the palm, its axis across the hand from the heel by the little finger to the root of the
-- first finger (tilted by `tilt` degrees from straight across): true when the line from a to b meets it.
local function handleCast(side, r, tilt)
	local palm = FT.Palm
	local centre = Vector3.new(-side * (HP.PalmHalf + FT.PalmGap + r), palm.Y, palm.Z)
	local t = math.rad(tilt)
	local axis = Vector3.new(0, math.sin(t), math.cos(t))
	return function(a, b)
		local pa, pb = a - centre, b - centre
		pa -= axis * pa:Dot(axis)
		pb -= axis * pb:Dot(axis)
		local d = pb - pa
		local len2 = d:Dot(d)
		local u = if len2 > 1e-9 then math.clamp(-pa:Dot(d) / len2, 0, 1) else 0
		return (pa + d * u).Magnitude < r
	end
end

-- The pose for a hold kind on one side; aim = the firing finger goes to the trigger; radius = the real handle's
-- thickness in this hand's own size (a melee weapon's GripRadius over the hand's scale: HeldWeapons lays that handle
-- straight across the palm, so its hold has no tilt).
function Hands.Hold(kind, side, aim, radius)
	if radius then
		radius = math.clamp(math.round(radius * 200) / 200, 0.02, 0.2)
	end
	local key = ("%s|%d|%s|%s"):format(kind, side, tostring(aim == true), tostring(radius))
	local pose = holds[key]
	if pose then
		return pose
	end
	local h = C.Holds[kind]
	if not h then
		pose = Fingers.Relaxed()
	else
		local cast = handleCast(side, radius or h.Radius, if radius then 0 else h.Tilt or 0)
		local gun = h.Trigger == true
		pose = Fingers.Grasp(CFrame.identity, side, cast, { Register = gun and not aim, Thumb = if gun then FT.FiringThumb else nil })
		if gun and aim then
			-- on the trigger: the first finger bends in to it and no further
			local a = Fingers.Close(CFrame.identity, side, "Index", cast, C.TriggerCaps, FT.Spread.Index)
			pose.Index = a
		end
	end
	holds[key] = pose
	return pose
end

-- ===== the pieces =====
local function clearBody(char, b)
	for _, h in b.Sides do
		h.Model:Destroy()
	end
	for _, p in b.Hidden do
		if p.Parent then
			p.LocalTransparencyModifier = 0
			p:SetAttribute("JointedHands", nil)
		end
	end
	bodies[char] = nil
end

-- the body's own hand mesh: hidden here, and what the new hand is made of and coloured like
local function bodyHands(char)
	local found = {}
	for _, layer in char:GetChildren() do
		if layer:IsA("Model") and (layer.Name == "Skin" or layer:GetAttribute("Kind") or CollectionService:HasTag(layer, "Skin")) then
			for _, p in layer:GetChildren() do
				if p:IsA("BasePart") then
					local piece = string.split(p.Name, "_")[1]
					if piece == "Hands" or piece == "HandL" or piece == "HandR" or piece == "GloveL" or piece == "GloveR" then
						table.insert(found, p)
					end
				end
			end
		end
	end
	return found
end

local function buildHand(sideName, like, scale)
	local material = like and string.match(like.Name, "_(%w+)$") or "Flesh"
	if not MATERIALS[material] then
		material = "Flesh"
	end
	local model = Instance.new("Model")
	model.Name = "Hand" .. sideName
	local parts, list = {}, {}
	for _, p in source:GetChildren() do
		local piece, mat = string.match(p.Name, "^(%w+)_(%w+)$")
		if mat == material and p:IsA("BasePart") then
			local c = p:Clone()
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			c.Size = p.Size * scale
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
			table.insert(list, { Piece = piece, Part = c })
		end
	end
	if not parts.Palm then
		model:Destroy()
		return nil
	end
	model.Parent = camera
	return { Model = model, Parts = parts, List = list, Pose = Fingers.Relaxed(), Goal = nil, Kind = "Open" }
end

-- the thickness of the hand: the body's own hand part against the soldier's that the pieces were made for
local function scaleOf(char)
	local hand = char:FindFirstChild("RightHand")
	if not hand then
		return 1
	end
	return math.clamp((hand.Size.Y / C.Reference.Y + hand.Size.X / C.Reference.X) / 2, 0.6, 2.2)
end

local function makeBody(char)
	local shown = bodyHands(char)
	if #shown == 0 then
		return nil -- a body with no skin (a box rig, an avatar fallback): left as it is
	end
	local like = shown[1]
	for _, p in shown do
		if p.Transparency < 0.9 then
			like = p
		end
	end
	local scale = scaleOf(char)
	local b = { Sides = {}, Hidden = shown, Scale = scale, HoldAt = 0 }
	for sideName in SIDES do
		if not char:GetAttribute("Cyber_" .. sideName .. "Arm") then -- a metal arm draws its own hand
			local h = buildHand(sideName, like, scale)
			if h then
				b.Sides[sideName] = h
			end
		end
	end
	for _, p in shown do
		p:SetAttribute("JointedHands", true)
	end
	return b
end

-- ===== what each hand is doing =====
local function weaponAxis(char)
	local held = char:FindFirstChild("HeldWeapon")
	local primary = held and held.PrimaryPart
	local grip = primary and primary:FindFirstChild("Grip")
	if not (grip and grip:IsA("Weld")) then
		return nil
	end
	return primary.CFrame * grip.C1:Inverse() -- the weapon's frame: its business end along +Z
end

local function choose(char, b)
	local id = char:GetAttribute("Weapon")
	local def = id and Weapons.Defs[id]
	local held = char:FindFirstChild("HeldWeapon")
	local aim = char:GetAttribute("Aiming") == true
	local right, left = "Open", "Open"
	local radius -- a melee handle's own thickness
	if char:GetAttribute("Carrying") or char:GetAttribute("NeckHold") then
		return "Grab", "Grab", false
	end
	if def and Weapons.IsGun(def) and held then
		right = if def.Family == "Rifle" then "Rifle" else "Pistol"
		-- both hands on every gun now: a pistol's off hand wraps the firing hand at the ready and aimed alike
		left = if def.Family == "Rifle" then "Support" else "Cup"
		local busy = GunFeel and GunFeel.LeftGrip(char)
		if busy == "Mag" then
			left = "Mag"
		elseif busy == "Handle" then
			left = "Pinch"
		elseif busy == "Pouch" then
			left = "Open"
		end
	elseif held then
		right = C.Families[def and def.Family or ""] or "Grip"
		local r = held:GetAttribute("GripRadius")
		radius = if type(r) == "number" then r / b.Scale else nil
		-- the off hand on the haft when the guard or a two-handed blow brings it there
		local axis = weaponAxis(char)
		local hand = char:FindFirstChild("LeftHand")
		if axis and hand then
			local palm = Fingers.Wrist(hand) * (FT.Palm * b.Scale)
			local rel = axis:PointToObjectSpace(palm)
			local off = math.sqrt(rel.X * rel.X + rel.Y * rel.Y)
			if off < C.OffHandReach * b.Scale and rel.Z > -0.4 * b.Scale and rel.Z < C.OffHandAlong * b.Scale then
				left = right
			end
		end
	elseif def and def.Family == "Fists" then
		right, left = "Fist", "Fist"
	end
	return right, left, aim, radius
end

-- ===== every frame =====
local bulk = {}
local bulkCF = {}
local function place(char, b, dt)
	local k = math.min(1, dt * C.Rate)
	for sideName, h in b.Sides do
		local part = char:FindFirstChild(sideName .. "Hand")
		if part then
			local side = SIDES[sideName]
			local goal = h.Goal or Fingers.Relaxed()
			for name, g in goal do
				local now = h.Pose[name]
				for i = 1, 4 do
					now[i] += (g[i] - now[i]) * k
				end
				if name == "Thumb" then
					now.Swing = (now.Swing or FT.ThumbSwing) + ((g.Swing or FT.ThumbSwing) - (now.Swing or FT.ThumbSwing)) * k
				end
			end
			local wrist = Fingers.Wrist(part)
			local s = b.Scale
			for piece, cf in Fingers.Pieces(CFrame.identity, side, h.Pose) do
				local p = h.Parts[piece]
				if p then
					table.insert(bulk, p)
					table.insert(bulkCF, wrist * (cf.Rotation + cf.Position * s))
				end
			end
		end
	end
end

local function cyberKey(char)
	return tostring(char:GetAttribute("Cyber_RightArm") ~= nil) .. tostring(char:GetAttribute("Cyber_LeftArm") ~= nil)
end

local function scan()
	if not source then
		source = find and find()
		if not source or #source:GetChildren() == 0 then
			source = nil
			return
		end
	end
	local eye = camera.CFrame.Position
	local near = {}
	local function consider(char)
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not char:GetAttribute("Hidden") then
			local d = (root.Position - eye).Magnitude
			if d < C.Range then
				table.insert(near, { Char = char, D = d })
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
	table.sort(near, function(a, b)
		return a.D < b.D
	end)
	local keep = {}
	for i = 1, math.min(#near, C.Max) do
		keep[near[i].Char] = near[i].D
	end
	for char, b in bodies do
		local cyberNow = cyberKey(char)
		if not keep[char] or not char.Parent or b.Cyber ~= cyberNow or (b.Hidden[1] and not b.Hidden[1]:IsDescendantOf(char)) then
			clearBody(char, b)
		end
	end
	for char, d in keep do
		local b = bodies[char]
		if not b then
			b = makeBody(char)
			if b then
				b.Cyber = cyberKey(char)
				bodies[char] = b
			end
		end
		if b then
			b.Far = d > C.Far
		end
	end
end

function Hands.Step(dt)
	if not (C and C.Enabled) then
		return
	end
	dt = math.min(dt, 0.1)
	clock += dt
	frame += 1
	if clock >= scanAt then
		scanAt = clock + C.ScanEvery
		local ok, err = pcall(scan)
		if not ok then
			warn("Hands: " .. tostring(err))
		end
	end
	table.clear(bulk)
	table.clear(bulkCF)
	for char, b in bodies do
		if clock >= b.HoldAt then
			b.HoldAt = clock + C.HoldEvery
			local ok, right, left, aim, radius = pcall(choose, char, b)
			if ok then
				if b.Sides.Right then
					b.Sides.Right.Goal = Hands.Hold(right, 1, aim, radius)
				end
				if b.Sides.Left then
					-- the off hand on the same haft closes round the same thickness
					b.Sides.Left.Goal = Hands.Hold(left, -1, false, if left == right then radius else nil)
				end
			end
		end
		if not b.Far or frame % 2 == 0 then
			place(char, b, if b.Far then dt * 2 else dt)
		end
		for _, p in b.Hidden do
			p.LocalTransparencyModifier = 1
		end
	end
	if #bulk > 0 then
		local ok = pcall(function()
			workspace:BulkMoveTo(bulk, bulkCF, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			for i, p in bulk do
				p.CFrame = bulkCF[i]
			end
		end
	end
end

function Hands.State() -- for tests
	return { Bodies = bodies, Holds = holds }
end

-- opts: { Camera, Config = Config.Hands, Fingers = Config.WarMovement.Fingers, HandParts, Weapons, GunFeel, Find =
-- function returning ReplicatedStorage.ViewHands or nil while it is not there yet }
function Hands.Init(opts)
	C, FT, HP, Weapons, GunFeel = opts.Config, opts.Fingers, opts.HandParts, opts.Weapons, opts.GunFeel
	camera, find = opts.Camera, opts.Find
	Fingers = opts.FingersModule
	if not (C and C.Enabled and FT and HP and Fingers) then
		return
	end
	Fingers.Init({ Camera = camera, Config = FT, HandParts = HP, Find = find })
	-- after the skin follows its limbs (shared/Skin.lua binds at 2005)
	RunService:BindToRenderStep("JointedHands", 2006, Hands.Step)
end

return Hands
