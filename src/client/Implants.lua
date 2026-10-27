-- Visible implants (design/gdd/dematerialization.md §6; shared/Cybernetics.lua). What has been ripped into a
-- body shows on that body, for everyone: the server sets Cyber_<slot> = itemId on each character
-- (server/Gear.lua Gear.Push) and every client draws it here, locally. Limbs get a metal shell (a copy of the
-- body part a hair larger, so it covers clothing) plus a lit seam; eyes, ears, nose and core get small parts
-- on the head and chest. All of it is placeholder art until a piece has a Mesh in Presentation.Implants.
-- Nothing here collides, has mass or can be hit by a ray.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cybernetics = require(Shared:WaitForChild("Cybernetics"))
local Presentation = require(Shared:WaitForChild("Presentation"))
local P = Presentation.Implants

local Implants = {}

local drawn = {} -- model -> { [slot] = { itemId, parts } }
local watching = {} -- model -> connections

local function inert(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

local function scaled(v, size)
	return Vector3.new(v.X * size.X, v.Y * size.Y, v.Z * size.Z)
end

local function shell(bodyPart)
	local copy = bodyPart:Clone()
	if not copy then
		return nil -- not archivable
	end
	for _, child in copy:GetChildren() do
		child:Destroy() -- joints, attachments, scripts: only the shape comes along
	end
	copy.Name = "Implant_" .. bodyPart.Name
	copy.Size = bodyPart.Size * P.Metal.Grow
	copy.Color = P.Metal.Color
	copy.Material = P.Metal.Material
	copy.Transparency = 0
	if copy:IsA("MeshPart") then
		pcall(function()
			copy.TextureID = "" -- the skin texture would show through
		end)
	end
	inert(copy)
	copy.CFrame = bodyPart.CFrame
	return copy
end

local function bit(bodyPart, spec, accent)
	local part = Instance.new("Part")
	part.Name = "ImplantBit"
	part.Size = spec.Size
	if spec.Neon then
		part.Material = Enum.Material.Neon
		part.Color = accent
	else
		part.Material = P.Metal.Material
		part.Color = P.Metal.Color
	end
	inert(part)
	part.CFrame = bodyPart.CFrame * CFrame.new(scaled(spec.Offset, bodyPart.Size))
	return part
end

local function mesh(bodyPart, art)
	local part = Instance.new("Part")
	part.Name = "ImplantMesh"
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 0
	inert(part)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = art.MeshId
	m.TextureId = art.TextureId or ""
	m.Scale = art.Scale or Vector3.new(1, 1, 1)
	m.Parent = part
	part.CFrame = bodyPart.CFrame * CFrame.new(art.Offset or Vector3.zero)
	return part
end

local function clear(model, slot)
	local d = drawn[model] and drawn[model][slot]
	if d then
		for _, part in d.parts do
			part:Destroy()
		end
		drawn[model][slot] = nil
	end
end

local function draw(model, slot)
	local itemId = model:GetAttribute("Cyber_" .. slot)
	local have = drawn[model] and drawn[model][slot]
	if have and have.itemId == itemId then
		return
	end
	clear(model, slot)
	local spec = P.Slots[slot]
	if type(itemId) ~= "string" or not spec or not Cybernetics.Pieces[itemId] then
		return
	end
	local look = P.Pieces[itemId] or {}
	local accent = look.Accent or P.DefaultAccent
	local parts = {}
	local function add(part, onto)
		weld(onto, part)
		part.Parent = model
		table.insert(parts, part)
	end
	local art = (string.sub(slot, 1, 4) == "Left" and look.MeshLeft) or look.Mesh -- a left-hand version, if there is one
	if art and type(art.MeshId) == "string" and art.MeshId ~= "" then
		local first = (spec.Shell and spec.Shell[1]) or (spec.Bits and spec.Bits[1] and spec.Bits[1].Part)
		local onto = first and model:FindFirstChild(first)
		if onto then
			add(mesh(onto, art), onto)
		end
	else
		for _, name in spec.Shell or {} do
			local onto = model:FindFirstChild(name)
			local copy = onto and onto:IsA("BasePart") and shell(onto)
			if copy then
				add(copy, onto)
			end
		end
		for _, b in spec.Bits or {} do
			local onto = model:FindFirstChild(b.Part)
			if onto and onto:IsA("BasePart") then
				add(bit(onto, b, accent), onto)
			end
		end
	end
	drawn[model] = drawn[model] or {}
	drawn[model][slot] = { itemId = itemId, parts = parts }
end

local function unwatch(model)
	for _, c in watching[model] or {} do
		c:Disconnect()
	end
	watching[model] = nil
	for slot in drawn[model] or {} do
		clear(model, slot)
	end
	drawn[model] = nil
end

local function watch(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or watching[model] then
		return
	end
	local conns = {}
	watching[model] = conns
	task.spawn(function()
		-- R15 bodies only: the parts this draws on
		if not (model:FindFirstChild("UpperTorso") or model:WaitForChild("UpperTorso", 5)) or watching[model] ~= conns then
			return
		end
		for _, slot in Cybernetics.Slots do
			table.insert(conns, model:GetAttributeChangedSignal("Cyber_" .. slot):Connect(function()
				draw(model, slot)
			end))
			draw(model, slot)
		end
		table.insert(conns, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				unwatch(model)
			end
		end))
	end)
end

function Implants.Drawn(model)
	return drawn[model]
end

function Implants.Init()
	local function watchPlayer(p)
		p.CharacterAdded:Connect(watch)
		if p.Character then
			watch(p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	-- enemy bodies can carry metal too (Combatant tag; client/Nameplates.lua uses the same set)
	for _, m in CollectionService:GetTagged("Combatant") do
		watch(m)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(watch)
end

return Implants
