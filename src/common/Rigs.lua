-- Character rigs from uploaded limb meshes. A rig asset is a Model of parts named
-- "<R15Part>_<Material>" (Head, UpperTorso, LowerTorso, Left/RightUpperArm, ...). This builds the
-- R15 Motor6D skeleton between them from their positions, adds a HumanoidRootPart and Humanoid,
-- welds any extra parts (goggles, pouches) to the nearest limb, and plays Roblox's standard R15
-- idle/walk animations so the character moves like a character. Falls back to nil if the asset
-- lacks the limbs, so callers keep their box rigs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.ModelAssets)

local CollectionService = game:GetService("CollectionService")

local Rigs = {}
local warned = {} -- asset ids already reported as unusable

-- The skin: the body people see (tools/models/figure.py -> Assets.Skins[kind]). An uploaded skin is a Model holding
-- "RootPart" with 15 Bones (one per limb, at the limb's centre) and skinned MeshParts jointed to it. It is lined up
-- with the rig, each bone is tied to the limb nearest to it (attributes Limb and Rest; shared/Skin.lua makes the
-- bone follow that limb on every client), and the rig's own limbs turn invisible: they stay as the joints, the
-- hitboxes and what gear welds to. Returns true when the skin is on.
local function attachSkin(model, limbs, kind, layerName, tints)
	local spec = Assets.Skins and Assets.Skins[kind]
	local template = spec and spec.Id and spec.Id ~= 0 and ModelAssets.Template(spec.Id)
	if not template then
		return false
	end
	local skin = template:Clone()
	local holder = skin:FindFirstChild("RootPart")
	local bones, meshes = {}, {}
	for _, d in skin:GetDescendants() do
		if d:IsA("Bone") then
			table.insert(bones, d)
		elseif d:IsA("MeshPart") then
			table.insert(meshes, d)
		elseif d:IsA("AnimationController") or d:IsA("CFrameValue") or (d:IsA("Folder") and d.Name == "InitialPoses") then
			d:Destroy()
		end
	end
	local function world(bone)
		local cf = bone.CFrame
		local up = bone.Parent
		while up and up:IsA("Bone") do
			cf = up.CFrame * cf
			up = up.Parent
		end
		return (if up and up:IsA("BasePart") then up.CFrame else CFrame.identity) * cf
	end
	local anchor
	for _, b in bones do
		if b.Name == "LowerTorso" then
			anchor = b
		end
	end
	if not (holder and anchor and #meshes > 0 and #bones >= 15) then
		if not warned[spec.Id] then
			warned[spec.Id] = true
			warn("[Rigs] skin", kind, "is not a skinned body (bones", #bones, "meshes", #meshes, ") - keeping the plain rig")
		end
		skin:Destroy()
		return false
	end
	Assets.Dress(skin)
	-- skin and rig were modelled in the same space, so one move puts the skin's hip bone on the rig's hip limb
	local move = limbs.LowerTorso.CFrame * world(anchor):Inverse()
	for _, p in skin:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = move * p.CFrame
		end
	end
	for _, b in bones do
		local at = world(b)
		local best, bestDist
		for _, limb in limbs do
			local d = (limb.Position - at.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = limb, d
			end
		end
		b:SetAttribute("Limb", best.Name)
		b:SetAttribute("Rest", best.CFrame:ToObjectSpace(at))
	end
	for _, p in skin:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
			p:SetAttribute("Skin", true)
			if p:IsA("MeshPart") then
				local suffix = p.Name:match("_(%w+)$")
				p:SetAttribute("Mat", (spec.Mats and spec.Mats[p.Name]) or suffix)
				local tint = (tints and tints[p.Name]) or (spec.Tints and spec.Tints[p.Name])
				if tint then
					Assets.Tint(p, tint)
				end
				-- what sits wholly on the head (helmet, mask, goggles): a first-person camera looks out from inside it
				local head = limbs.Head
				if p.Position.Y - p.Size.Y / 2 > head.Position.Y - head.Size.Y / 2 - 0.35 then
					p:SetAttribute("HeadPiece", true)
				end
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "SkinWeld"
	weld.Part0, weld.Part1 = limbs.LowerTorso, holder
	weld.Parent = holder
	for _, p in meshes do
		if p.Name:sub(1, 6) == "Anchor" then
			p:Destroy() -- a speck per bone that only made the upload keep every bone
		else
			p:SetAttribute("BaseT", p.Transparency)
		end
	end
	skin.Name = layerName or "Skin"
	skin:SetAttribute("Kind", kind)
	CollectionService:AddTag(skin, "Skin")
	skin.Parent = model
	if layerName then
		return true
	end
	for _, limb in limbs do
		limb.Transparency = 1
		limb:SetAttribute("Proxy", true)
	end
	return true
end

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

-- Builds a rigged character Model from an asset id. `kind` names the skin to dress it in (Assets.Skins); without one,
-- or if the skin does not load, the rig's own limbs are the body. Returns model, humanoid, root or nil.
function Rigs.Build(assetId, name, kind)
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
			-- remember the material suffix before limbs are renamed (server/Body.lua recolours by it)
			local suffix = p.Name:match("_(%w+)$")
			if suffix then
				p:SetAttribute("Mat", suffix)
			end
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
	-- The FBX import mirrors Blender's X axis, so a body modelled with its left limbs at -X arrives with
	-- them on its right (verified live 2026-11-03: every rig's LeftUpperArm sat on the right). Stock
	-- animations and the client's swing poses then turn the arms into the torso. Swap the names back.
	local function swapSides()
		local swapped = {}
		for name, part in limbs do
			local other = if name:sub(1, 4) == "Left" then "Right" .. name:sub(5) elseif name:sub(1, 5) == "Right" then "Left" .. name:sub(6) else name
			swapped[other] = part
			part.Name = other
		end
		limbs = swapped
	end
	local mirrored = false
	if limbs.LeftUpperArm and limbs.LowerTorso then
		local right = limbs.LowerTorso.CFrame.RightVector
		if (limbs.LeftUpperArm.Position - limbs.LowerTorso.Position):Dot(right) > 0 then
			swapSides()
			mirrored = true
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
	-- an extra named after a limb ("LowerTorsoCoat", "LeftUpperArmPad") rides on that limb (its side swapped
	-- with the limbs when the import mirrored); any other rides on whichever limb is nearest
	local function named(extra)
		local base = baseName(extra)
		if mirrored then
			base = if base:sub(1, 4) == "Left" then "Right" .. base:sub(5) elseif base:sub(1, 5) == "Right" then "Left" .. base:sub(6) else base
		end
		local pick
		for _, limb in LIMBS do
			if #base > #limb and base:sub(1, #limb) == limb and (not pick or #limb > #pick) then
				pick = limb
			end
		end
		return pick and limbs[pick]
	end
	for _, extra in extras do
		local best, bestDist = named(extra), math.huge
		if not best then
			best = limbs.UpperTorso
			for _, limb in limbs do
				local d = (limb.Position - extra.Position).Magnitude
				if d < bestDist then
					best, bestDist = limb, d
				end
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = best, extra
		weld.Parent = extra
		extra.Massless = true
	end
	if kind then
		model:SetAttribute("Skinned", attachSkin(model, limbs, kind))
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

local function limbsOf(model)
	local limbs = {}
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if not (limb and limb:IsA("BasePart")) then
			return nil
		end
		limbs[name] = limb
	end
	return limbs
end

-- Dresses an already built rig (a spawned character) in another skin: the Front's recruits all spawn as the same
-- rig and put on their side's colours. tints overrides Assets.Skins[kind].Tints piece by piece. Returns true when
-- the skin is on; if it is not, the plain limbs show.
function Rigs.Skin(model, kind, tints)
	local limbs = limbsOf(model)
	if not limbs then
		return false
	end
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Kind") then
			child:Destroy()
		end
	end
	local on = attachSkin(model, limbs, kind, nil, tints)
	if not on then
		for _, limb in limbs do
			limb.Transparency = 0
			limb:SetAttribute("Proxy", nil)
		end
	end
	model:SetAttribute("Skinned", on)
	return on
end

-- A layered body. A skin is a set of named pieces on the rig's 15 bones; more skins can be laid over the same rig
-- (a side's kit, cybernetic limbs, a large armour set), each its own upload:
--   Assets.Skins[kind].Groups = { <Group> = { piece names } }   pieces that show only while their group is on
--   Assets.Skins[kind].Covers = { <Piece> = { piece names } }   what a showing piece hides, in any layer (clothing
--                                                               hides the body under it; a cybernetic arm takes the
--                                                               place of the flesh arm, its glove and its sleeve end)
-- Rigs.Layer adds a layer, Rigs.Dress(model, { Group = true }) says which groups are on.
function Rigs.Layer(model, kind)
	local name = "Layer_" .. kind
	if model:FindFirstChild(name) then
		return true
	end
	local limbs = model:GetAttribute("Skinned") and limbsOf(model)
	return limbs ~= nil and attachSkin(model, limbs, kind, name)
end

function Rigs.Unlayer(model, kind)
	local layer = model:FindFirstChild("Layer_" .. kind)
	if layer then
		layer:Destroy()
	end
end

local function pieceOf(part)
	return part.Name:match("^(%w-)_") or part.Name
end

-- parts: MeshParts named "<Piece>_<Material>"; kinds: the skins they come from; on: { Group = true }.
function Rigs.DressParts(parts, kinds, on)
	local groupOf, covers = {}, {}
	for _, kind in kinds do
		local spec = Assets.Skins[kind]
		for group, pieces in (spec and spec.Groups) or {} do
			for _, piece in pieces do
				groupOf[piece] = group
			end
		end
		for piece, hides in (spec and spec.Covers) or {} do
			covers[piece] = hides
		end
	end
	local showing, hidden = {}, {}
	for _, p in parts do
		local piece = pieceOf(p)
		local group = groupOf[piece]
		if group == nil or on[group] then
			showing[piece] = true
		end
	end
	for piece in showing do
		for _, under in covers[piece] or {} do
			hidden[under] = true
		end
	end
	for _, p in parts do
		local piece = pieceOf(p)
		local base = p:GetAttribute("BaseT") or 0
		p.Transparency = if showing[piece] and not hidden[piece] then base else 1
	end
end

function Rigs.Dress(model, on)
	local parts, kinds = {}, {}
	for _, layer in model:GetChildren() do
		local kind = layer:IsA("Model") and layer:GetAttribute("Kind")
		if kind then
			table.insert(kinds, kind)
			for _, p in layer:GetChildren() do
				if p:IsA("MeshPart") then
					table.insert(parts, p)
				end
			end
		end
	end
	if #parts == 0 then
		return false
	end
	Rigs.DressParts(parts, kinds, on)
	return true
end

-- Turns a skinned body into a figure of light (the Front's simulation): no textures, one glowing colour.
function Rigs.Holo(model, color)
	local any = false
	for _, layer in model:GetChildren() do
		if layer:IsA("Model") and layer:GetAttribute("Kind") then
			any = true
			for _, p in layer:GetDescendants() do
				if p:IsA("SurfaceAppearance") or p:IsA("PointLight") then
					p:Destroy()
				elseif p:IsA("MeshPart") then
					p.Material, p.Color, p.CastShadow = Enum.Material.ForceField, color, false
				end
			end
		end
	end
	return any
end

-- A body that never moves (a clone in its tank): the skin alone, standing at `cf` (its hips there), anchored.
-- opts.Groups = the groups that are on; opts.Color paints it one flat colour; opts.Tints overrides tints.
-- Returns the Model or nil.
function Rigs.Statue(kind, cf, parent, opts)
	opts = opts or {}
	local spec = Assets.Skins and Assets.Skins[kind]
	local template = spec and ModelAssets.Template(spec.Id)
	if not template then
		return nil
	end
	local skin = template:Clone()
	local hips
	for _, d in skin:GetDescendants() do
		if d:IsA("AnimationController") or d:IsA("CFrameValue") or (d:IsA("Folder") and d.Name == "InitialPoses") then
			d:Destroy()
		elseif d:IsA("Bone") and d.Name == "LowerTorso" then
			hips = d
		end
	end
	Assets.Dress(skin)
	local at = if hips then (if hips.Parent:IsA("BasePart") then hips.Parent.CFrame else CFrame.identity) * hips.CFrame else skin:GetPivot()
	local move = cf * at:Inverse()
	local parts = {}
	for _, p in skin:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = move * p.CFrame
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			if p:IsA("MeshPart") and p.Name:sub(1, 6) == "Anchor" then
				p:Destroy()
			elseif p:IsA("MeshPart") then
				if opts.Color then
					local surface = p:FindFirstChildOfClass("SurfaceAppearance")
					if surface then
						surface:Destroy()
					end
					p.Material, p.Color = Enum.Material.SmoothPlastic, opts.Color
				else
					local tint = (opts.Tints and opts.Tints[p.Name]) or (spec.Tints and spec.Tints[p.Name])
					if tint then
						Assets.Tint(p, tint)
					end
				end
				p:SetAttribute("BaseT", opts.Transparency or p.Transparency)
				table.insert(parts, p)
			end
		end
	end
	Rigs.DressParts(parts, { kind }, opts.Groups or {})
	skin.Name = opts.Name or "Statue"
	skin.Parent = parent
	return skin
end

-- Idle/walk animation playback for an NPC humanoid (server-side Animator works for NPCs).
function Rigs.Animate(model, hum, stock)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum) -- created in Build; this is a fallback
	local tracks = {}
	-- the game's own stance and gaits (tools/anims, made on the one-piece body's proportions) when uploaded;
	-- Roblox's stock cycles otherwise
	local own = Assets.Anims or {}
	local ids = { Idle = own.Idle, Walk = own.Walk, Jog = own.Jog }
	local ownGait = not stock and ids.Idle and ids.Walk and ids.Jog and ids.Jog ~= 0
	for name, id in (if ownGait then ids else Rigs.Animations) do
		local anim = Instance.new("Animation")
		anim.AnimationId = if typeof(id) == "number" then "rbxassetid://" .. id else id
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
	tracks.Idle.Priority = Enum.AnimationPriority.Idle
	tracks.Idle:Play()
	local current
	hum.Running:Connect(function(speed)
		local want, pace
		if speed > 0.5 then
			if ownGait and speed >= 8 then
				want, pace = tracks.Jog, math.clamp(speed / 15.1, 0.6, 1.5)
			elseif ownGait then
				want, pace = tracks.Walk, math.clamp(speed / 4.7, 0.5, 1.8)
			else
				want, pace = tracks.Walk, math.clamp(speed / 16, 0.6, 1.6)
			end
		end
		if want ~= current then
			if current then
				current:Stop(0.2)
			end
			current = want
			if want then
				want.Priority = Enum.AnimationPriority.Movement
				want:Play(0.2)
			end
		end
		if want then
			want:AdjustSpeed(pace)
		end
	end)
end

return Rigs
