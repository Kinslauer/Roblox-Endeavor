-- Puts the equipped weapon's model (Blender-built, see tools/models/weapons.py) into a character's
-- right hand. Models are authored in Blender with the grip at the origin and the business end along
-- Blender +Y, which the FBX import turns into Roblox +Z (Blender +Z becomes Roblox +Y); a Weld maps
-- that onto the hand so the weapon points out of the fist. Works for players and for
-- any NPC rig that has a RightHand (the box rig has none and is left alone). Shared by both places:
-- Endeavor melee and the Front's firearms are all in Assets.Weapons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local GunParts = require(ReplicatedStorage.Shared.GunParts)
local ModelAssets = require(script.Parent.ModelAssets)

local HeldWeapons = {}

local GRIPS = {
	-- weapon +Z -> hand forward (-Z), grip centre in the palm
	Melee = CFrame.new(0, -0.2, -0.3) * CFrame.Angles(0, math.pi, 0),
	-- barrel (+Y) -> forward, grip (-Z) -> down the hand
	-- (the Front's whole pistols; Endeavor's are laid in the palm by HandgunGrip, opts Grip "Handgun")
	Pistol = CFrame.new(0, -0.1, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
	-- firearms: barrel (+Z) -> forward, grip in the palm, held a little high so the sights sit near eye line
	Rifle = CFrame.new(0, -0.1, -0.3) * CFrame.Angles(0, math.pi, 0),
	-- Endeavor's long guns: the grip sits in the hand the way a pistol grip does, turned so that the arm pose of
	-- the Aim_Rifle animation (tools/anims/anims.py, solved together with this matrix) puts the bore level and
	-- dead ahead with the butt in the right shoulder. The Rifle grip above leaves the barrel square to the forearm.
	Shoulder = CFrame.new(0, -0.1, 0, -0.918, 0.2537, 0.3048, -0.3956, -0.6391, -0.6596, 0.0275, -0.7261, 0.6871),
}

function HeldWeapons.Clear(char, name)
	local held = char and char:FindFirstChild(name or "HeldWeapon")
	if held then
		held:Destroy()
	end
end

-- Attaches the model for weaponId (an Assets.Weapons key) and returns it, or nil (fists, no
-- asset, no hand). Replaces whatever was held before.
-- Puts a gun together from its components (shared/GunParts): the receiver and the chosen barrel share the gun's
-- origin, the muzzle device and the accessories go on the barrel's and the receiver's anchors. Every component
-- carries a speck named Ref at its own origin. Returns a Model whose origin is the world origin, or nil if a
-- component did not load.
function HeldWeapons.Assemble(weaponId, attachments)
	local pieces = GunParts.Pieces(weaponId, attachments)
	if not pieces then
		return nil
	end
	local holder = Instance.new("Model")
	for _, piece in pieces do
		local template = ModelAssets.Template(piece.Asset)
		if not template then
			holder:Destroy()
			return nil
		end
		local clone = template:Clone()
		local ref = if clone:IsA("BasePart") then nil else clone:FindFirstChild("Ref_Gunmetal", true)
		local from = if ref then ref.Position elseif clone:IsA("Model") then clone:GetPivot().Position else clone.Position
		local shift = (piece.At or Vector3.zero) - from
		local parts = if clone:IsA("BasePart") then { clone } else clone:GetDescendants()
		for _, p in parts do
			if p:IsA("BasePart") and p ~= ref then
				p.CFrame += shift
				p:SetAttribute("Component", piece.Name)
				p.Parent = holder
			end
		end
		if clone.Parent == nil and not clone:IsA("BasePart") then
			clone:Destroy()
		end
	end
	return holder
end

-- A melee weapon's grip laid in the palm, where jointed fingers (client/Hands.lua) close round it: its axis runs
-- across the hand, the handle's own thickness out from the palm side (-X of a right hand), at the height of the
-- middle of the palm (Config.WarMovement.Fingers.Palm from the wrist), scaled to the hand. Along the hand it stays
-- where it was (-0.3: the hand on the back half of the handle), so the blade reaches as far as before. nil when the
-- model has no part named Grip_<material> (the old grip is used).
local PALM_HALF, PALM_Y, REF_Y, REF_X = 0.046, -0.17, 0.564, 0.2867
function HeldWeapons.MeleeGrip(model, origin, hand)
	local radius
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and string.split(p.Name, "_")[1] == "Grip" then
			local rel = origin:ToObjectSpace(p.CFrame)
			local half = p.Size / 2
			local function ext(axis)
				return math.abs(rel.RightVector:Dot(axis)) * half.X + math.abs(rel.UpVector:Dot(axis)) * half.Y + math.abs(rel.LookVector:Dot(axis)) * half.Z
			end
			radius = (ext(Vector3.xAxis) + ext(Vector3.yAxis)) / 2
			break
		end
	end
	if not radius then
		return nil
	end
	local s = math.clamp((hand.Size.Y / REF_Y + hand.Size.X / REF_X) / 2, 0.6, 2.2)
	return CFrame.new(-(PALM_HALF * s + 0.004 + radius), hand.Size.Y / 2 + PALM_Y * s, -0.3) * CFrame.Angles(0, math.pi, 0), radius
end

-- A whole pistol (authored barrel +Y, top +Z) laid in the palm the way a hand holds one (owner, 2026-11-12: "fix
-- this please", of pistols held from the top of the slide): the grip's axis runs across the palm from the heel by the
-- little finger to the root of the first finger (HANDGUN_TILT from straight across, the same handle client/Hands
-- closes the fingers round), the grip raked HANDGUN_RAKE back from square to the bore, so the bore runs along the
-- fingers' line with a straight wrist and sits above the hand. The grip's centre = the part named Grip_/Grips_ (else
-- the magazine) goes on the palm cylinder's centre. The arm poses Aim_Pistol / Pistol_Ready / Reload_Pistol /
-- Cover_Idle / Intro_Draw / Intro_Rack (tools/anims) were solved by inverse kinematics on the real body for this
-- matrix: change them together. nil when the model has no grip part.
local HANDGUN_TILT, HANDGUN_RAKE = math.rad(16), math.rad(18)
function HeldWeapons.HandgunGrip(model, origin, hand)
	local grip, mag, top
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local group = string.split(p.Name, "_")[1]
			if group == "Grip" or group == "Grips" then
				grip = grip or p
			elseif group == "Magazine" or group == "Cell" then
				mag = mag or p
			elseif group == "Slide" or group == "Barrel" then
				top = top or p
			end
		end
	end
	grip = grip or mag
	if not grip then
		return nil
	end
	local rel = origin:ToObjectSpace(grip.CFrame)
	local half = grip.Size / 2
	local function ext(axis)
		return math.abs(rel.RightVector:Dot(axis)) * half.X + math.abs(rel.UpVector:Dot(axis)) * half.Y + math.abs(rel.LookVector:Dot(axis)) * half.Z
	end
	local radius = (ext(Vector3.xAxis) + ext(Vector3.yAxis)) / 2
	-- which way is up on this model: from the grip to the slide or barrel (+Z on every pistol so far)
	local upSign = 1
	if top and origin:ToObjectSpace(top.CFrame).Position.Z < rel.Position.Z then
		upSign = -1
	end
	local t, a = HANDGUN_TILT, HANDGUN_RAKE
	local g = Vector3.new(0, -math.sin(t), -math.cos(t)) -- the grip's axis, bottom to top, in the hand
	local f = Vector3.new(0, -math.cos(a - t), -math.sin(a - t)) -- the bore
	local u = ((g - f * math.sin(a)) / math.cos(a)).Unit
	local right = f:Cross(u)
	-- model X -> right, model Y (bore) -> f, model Z (top) -> u
	local turn = CFrame.fromMatrix(Vector3.zero, right * upSign, f, u * upSign)
	local s = math.clamp((hand.Size.Y / REF_Y + hand.Size.X / REF_X) / 2, 0.6, 2.2)
	local palm = Vector3.new(-(PALM_HALF * s + 0.004 + radius), hand.Size.Y / 2 + PALM_Y * s, 0)
	-- Attach's Grip weld puts the first part at hand * C0 * C1:Inverse() with C1 = that part in the origin's frame,
	-- which lays the origin at C0 * C1^-2 rather than at C0 (every older grip was tuned on the real body around that);
	-- the two C1s here undo it, so the origin really is where this places it (client/GunFeel measures the gun's frame
	-- as primary * C1:Inverse(), the same place)
	local c1 = if model.PrimaryPart then origin:ToObjectSpace(model.PrimaryPart.CFrame) else CFrame.new()
	return CFrame.new(palm) * turn * CFrame.new(-rel.Position) * c1 * c1, radius
end

-- opts (optional): Grip = a GRIPS name instead of the model's own, Scale = the size in the hand (1 = as modelled),
-- Name / Part / C0 = carry it somewhere else (Endeavor's Kit: "StowedWeapon" on a torso or leg, C0 the mount).
function HeldWeapons.Attach(char, weaponId, attachments, opts)
	local name = (opts and opts.Name) or "HeldWeapon"
	local held = char and char:FindFirstChild(name)
	local build = if weaponId and GunParts.Guns[weaponId] then GunParts.Key(weaponId, attachments) else ""
	if held and held:GetAttribute("WeaponId") == weaponId and (held:GetAttribute("Build") or "") == build then
		return held
	end
	HeldWeapons.Clear(char, name)
	local entry = weaponId and Assets.Weapons[weaponId]
	local spec = weaponId and GunParts.Guns[weaponId]
	local hand = char and char:FindFirstChild((opts and opts.Part) or "RightHand")
	if not ((entry or spec) and hand) then
		return nil
	end
	local model = spec and HeldWeapons.Assemble(weaponId, attachments)
	local assembled = model ~= nil
	if not model then
		local template = entry and ModelAssets.Template(entry.Id)
		if not template then
			return nil
		end
		model = template:Clone()
		if model:IsA("BasePart") then
			local holder = Instance.new("Model")
			model.Parent = holder
			model = holder
		end
	end
	model.Name = name
	model:SetAttribute("WeaponId", weaponId)
	model:SetAttribute("Build", build)
	Assets.Dress(model)
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
			table.insert(parts, p)
		end
	end
	if #parts == 0 then
		model:Destroy()
		return nil
	end
	-- the template's origin is the grip: one part carries the hand weld, the others stay rigid
	-- to it with their authored offsets
	local primary = parts[1]
	model.PrimaryPart = primary
	local origin = if assembled then CFrame.new() else model:GetPivot()
	local scale = opts and opts.Scale
	if scale and scale ~= 1 then
		for _, p in parts do -- shrink every part toward the grip
			p.Size *= scale
			p.CFrame += (p.Position - origin.Position) * (scale - 1)
		end
	end
	for i = 2, #parts do
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = primary, parts[i]
		weld.C0 = primary.CFrame:ToObjectSpace(parts[i].CFrame)
		weld.Parent = parts[i]
	end
	local grip = Instance.new("Weld")
	grip.Name = "Grip"
	grip.Part0, grip.Part1 = hand, primary
	local gripName = (opts and opts.Grip) or (if assembled then spec.Grip else entry.Grip) or "Melee"
	grip.C0 = (opts and opts.C0)
		or (gripName == "Melee" and HeldWeapons.MeleeGrip(model, origin, hand))
		or (gripName == "Handgun" and HeldWeapons.HandgunGrip(model, origin, hand))
		or GRIPS[gripName]
		or GRIPS.Melee
	grip.C1 = origin:ToObjectSpace(primary.CFrame)
	if gripName == "Handgun" or gripName == "Pistol" then
		model:SetAttribute("BarrelY", true) -- authored barrel +Y, top +Z (client/GunFeel turns its frame by this)
	end
	if gripName == "Handgun" and not (opts and opts.C0) then
		local _, radius = HeldWeapons.HandgunGrip(model, origin, hand)
		model:SetAttribute("GripRadius", radius)
	end
	if gripName == "Melee" and not (opts and opts.C0) then
		local _, radius = HeldWeapons.MeleeGrip(model, origin, hand)
		model:SetAttribute("GripRadius", radius) -- how thick the handle is: the fingers close round this
	end
	grip.Parent = primary
	model.Parent = char
	return model
end

return HeldWeapons
