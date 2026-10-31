-- Puts the equipped weapon's model (Blender-built, see tools/models/weapons.py) into a character's
-- right hand. Models are authored in Blender with the grip at the origin and the business end along
-- Blender +Y, which the FBX import turns into Roblox +Z (Blender +Z becomes Roblox +Y); a Weld maps
-- that onto the hand so the weapon points out of the fist. Works for players and for
-- any NPC rig that has a RightHand (the box rig has none and is left alone). Shared by both places:
-- Endeavor melee and the Front's firearms are all in Assets.Weapons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.ModelAssets)

local HeldWeapons = {}

local GRIPS = {
	-- weapon +Z -> hand forward (-Z), grip centre in the palm
	Melee = CFrame.new(0, -0.2, -0.3) * CFrame.Angles(0, math.pi, 0),
	-- barrel (+Y) -> forward, grip (-Z) -> down the hand
	Pistol = CFrame.new(0, -0.1, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
	-- firearms: barrel (+Z) -> forward, grip in the palm, held a little high so the sights sit near eye line
	Rifle = CFrame.new(0, -0.1, -0.3) * CFrame.Angles(0, math.pi, 0),
}

function HeldWeapons.Clear(char)
	local held = char and char:FindFirstChild("HeldWeapon")
	if held then
		held:Destroy()
	end
end

-- Attaches the model for weaponId (an Assets.Weapons key) and returns it, or nil (fists, no
-- asset, no hand). Replaces whatever was held before.
function HeldWeapons.Attach(char, weaponId)
	local held = char and char:FindFirstChild("HeldWeapon")
	if held and held:GetAttribute("WeaponId") == weaponId then
		return held
	end
	HeldWeapons.Clear(char)
	local entry = weaponId and Assets.Weapons[weaponId]
	local hand = char and char:FindFirstChild("RightHand")
	if not (entry and hand) then
		return nil
	end
	local template = ModelAssets.Template(entry.Id)
	if not template then
		return nil
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		model.Parent = holder
		model = holder
	end
	model.Name = "HeldWeapon"
	model:SetAttribute("WeaponId", weaponId)
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
	local origin = model:GetPivot()
	for i = 2, #parts do
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = primary, parts[i]
		weld.C0 = primary.CFrame:ToObjectSpace(parts[i].CFrame)
		weld.Parent = parts[i]
	end
	local grip = Instance.new("Weld")
	grip.Name = "Grip"
	grip.Part0, grip.Part1 = hand, primary
	grip.C0 = GRIPS[entry.Grip or "Melee"] or GRIPS.Melee
	grip.C1 = origin:ToObjectSpace(primary.CFrame)
	grip.Parent = primary
	model.Parent = char
	return model
end

return HeldWeapons
