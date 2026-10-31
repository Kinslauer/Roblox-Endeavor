-- Character rigs from uploaded limb meshes. A rig asset is a Model of parts named
-- "<R15Part>_<Material>" (Head, UpperTorso, LowerTorso, Left/RightUpperArm, ...). This builds the
-- R15 Motor6D skeleton between them from their positions, adds a HumanoidRootPart and Humanoid,
-- welds any extra parts (goggles, pouches) to the nearest limb, and plays Roblox's standard R15
-- idle/walk animations so the character moves like a character. Falls back to nil if the asset
-- lacks the limbs, so callers keep their box rigs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local Rigs = {}
local warned = {} -- asset ids already reported as unusable

-- joint name -> parent part, child part, and where on the child the joint sits ("top" = child's top centre)
local JOINTS = {
	{ "Waist", "LowerTorso", "UpperTorso", "bottom" },
	{ "Neck", "UpperTorso", "Head", "bottom" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", "top" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", "top" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", "top" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", "top" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", "top" },
	{ "RightWrist", "RightLowerArm", "RightHand", "top" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", "top" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "top" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", "top" },
	{ "RightHip", "LowerTorso", "RightUpperLeg", "top" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", "top" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", "top" },
}
local LIMBS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

-- Roblox's own R15 animations (public, owned by Roblox).
Rigs.Animations = { Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826", Run = "rbxassetid://507767714" }

local function baseName(part)
	return part.Name:match("^(.-)_%w+$") or part.Name
end

local function motor(name, parent, child, jointPos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = parent, child
	m.C0 = parent.CFrame:Inverse() * CFrame.new(jointPos)
	m.C1 = child.CFrame:Inverse() * CFrame.new(jointPos)
	m.Parent = child
	return m
end

-- Builds a rigged character Model from an asset id. Returns model, humanoid, root or nil.
function Rigs.Build(assetId, name)
	local template = ModelAssets.Template(assetId)
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = name or "Rig"
	Assets.Dress(model)
	local limbs = {}
	local extras = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local base = baseName(p)
			if table.find(LIMBS, base) then
				p.Name = base
				limbs[base] = p
			else
				table.insert(extras, p)
			end
			p.Anchored = false
			p.CanCollide = false
		end
	end
	for _, limb in LIMBS do
		if not limbs[limb] then
			if not warned[assetId] then
				warned[assetId] = true
				warn("[Rigs] asset", assetId, "is missing limb", limb, "- using the box rig")
			end
			model:Destroy()
			return nil
		end
	end
	-- root: an invisible box at the lower torso; the Humanoid stands on it
	local lower = limbs.LowerTorso
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = lower.CFrame
	root.Parent = model
	motor("Root", root, lower, lower.Position)
	-- limbs: joint at the child's top (or bottom) centre, as the meshes were modelled upright
	for _, j in JOINTS do
		local jointName, parentName, childName, where = j[1], j[2], j[3], j[4]
		local parent, child = limbs[parentName], limbs[childName]
		local y = if where == "top" then child.Position.Y + child.Size.Y / 2 else child.Position.Y - child.Size.Y / 2
		motor(jointName, parent, child, Vector3.new(child.Position.X, y, child.Position.Z))
	end
	-- extras (goggles, pouch...) ride on whichever limb they overlap most
	for _, extra in extras do
		local best, bestDist = limbs.UpperTorso, math.huge
		for _, limb in limbs do
			local d = (limb.Position - extra.Position).Magnitude
			if d < bestDist then
				best, bestDist = limb, d
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = best, extra
		weld.Parent = extra
		extra.Massless = true
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	root.CanCollide = true
	limbs.Head.CanCollide = false
	-- humanoid: hip height is the distance from the root centre to the soles
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	local soles = limbs.LeftFoot.Position.Y - limbs.LeftFoot.Size.Y / 2
	hum.HipHeight = (root.Position.Y - root.Size.Y / 2) - soles
	-- The Animator must exist BEFORE the model replicates: one created on the server afterwards
	-- plays animations that clients never see (the character walks with stiff legs).
	Instance.new("Animator").Parent = hum
	hum.Parent = model
	model.PrimaryPart = root
	return model, hum, root
end

-- Idle/walk animation playback for an NPC humanoid (server-side Animator works for NPCs).
function Rigs.Animate(model, hum)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum) -- created in Build; this is a fallback
	local tracks = {}
	for name, id in Rigs.Animations do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok then
			tracks[name] = track
		end
	end
	if not tracks.Idle then
		return
	end
	tracks.Idle:Play()
	local walking = false
	hum.Running:Connect(function(speed)
		local moving = speed > 0.5
		if moving ~= walking then
			walking = moving
			if moving then
				if tracks.Walk then
					tracks.Walk:Play()
					tracks.Walk:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.6))
				end
			elseif tracks.Walk then
				tracks.Walk:Stop()
			end
		end
	end)
end

return Rigs
