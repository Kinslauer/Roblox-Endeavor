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
	Pistol = CFrame.new(0, -0.1, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
	-- firearms: barrel (+Z) -> forward, grip in the palm, held a little high so the sights sit near eye line
	Rifle = CFrame.new(0, -0.1, -0.3) * CFrame.Angles(0, math.pi, 0),
	-- Endeavor's long guns: the grip sits in the hand the way a pistol grip does, turned so that the arm pose of
	-- the Aim_Rifle animation (tools/anims/anims.py, solved together with this matrix) puts the bore level and
	-- dead ahead with the butt in the right shoulder. The Rifle grip above leaves the barrel square to the forearm.
	Shoulder = CFrame.new(0, -0.1, 0, -0.918, 0.2537, 0.3048, -0.3956, -0.6391, -0.6596, 0.0275, -0.7261, 0.6871),
}

function HeldWeapons.Clear(char)
	local held = char and char:FindFirstChild("HeldWeapon")
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

-- opts (optional): Grip = a GRIPS name instead of the model's own, Scale = the size in the hand (1 = as modelled).
function HeldWeapons.Attach(char, weaponId, attachments, opts)
	local held = char and char:FindFirstChild("HeldWeapon")
	local build = if weaponId and GunParts.Guns[weaponId] then GunParts.Key(weaponId, attachments) else ""
	if held and held:GetAttribute("WeaponId") == weaponId and (held:GetAttribute("Build") or "") == build then
		return held
	end
	HeldWeapons.Clear(char)
	local entry = weaponId and Assets.Weapons[weaponId]
	local spec = weaponId and GunParts.Guns[weaponId]
	local hand = char and char:FindFirstChild("RightHand")
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
	model.Name = "HeldWeapon"
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
	grip.C0 = GRIPS[(opts and opts.Grip) or (if assembled then spec.Grip else entry.Grip) or "Melee"] or GRIPS.Melee
	grip.C1 = origin:ToObjectSpace(primary.CFrame)
	grip.Parent = primary
	model.Parent = char
	return model
end

return HeldWeapons
