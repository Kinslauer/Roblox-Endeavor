-- Loads uploaded models (Blender-built, see tools/models) once, caches them, and spawns dressed,
-- anchored copies set down on a point. Shared by both places (Endeavor props, buildings, weapons;
-- the Front's battlefield props).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

local ModelAssets = {}
local cache = {}

-- Returns the template Model for an asset id (nil if 0 or failed). Templates are never parented.
function ModelAssets.Template(id)
	if not id or id == 0 then
		return nil
	end
	if cache[id] == nil then
		local ok, result = pcall(function()
			local container = InsertService:LoadAsset(id)
			local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
			if model then
				model.Parent = nil
			end
			container:Destroy()
			return model
		end)
		if not ok or not result then
			warn("[ModelAssets] could not load asset", id, result)
		end
		cache[id] = (ok and result) or false
	end
	return cache[id] or nil
end

-- Clones a template as a Model, applies materials from part names, anchors it, and places it
-- with its bounding-box bottom at `cframe`. Returns the Model or nil.
function ModelAssets.Spawn(id, cframe, name, parent)
	local template = ModelAssets.Template(id)
	if not template then
		return nil
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		model.Parent = holder
		model = holder
	end
	Assets.Dress(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanQuery = true
		end
	end
	model.Name = name or model.Name
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	local bboxCF, bboxSize = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(bboxCF.Position - Vector3.new(0, bboxSize.Y / 2, 0))
	model:PivotTo(cframe)
	model.Parent = parent
	return model, bboxSize
end

-- Tiles `pitch`-wide panel models along the long horizontal axis of a wall part (bottom on the
-- part's bottom), parented to `parent`, and hides the part when at least one panel loaded. The
-- part keeps doing the physics. Returns how many panels were placed.
function ModelAssets.Shell(id, part, pitch, parent)
	local alongX = part.Size.X >= part.Size.Z
	local length = if alongX then part.Size.X else part.Size.Z
	local n = math.max(1, math.floor(length / pitch + 0.5))
	local placed = 0
	for i = 1, n do
		local along = (i - 0.5) * (length / n) - length / 2
		local cf = part.CFrame * CFrame.new(if alongX then along else 0, -part.Size.Y / 2, if alongX then 0 else along) * CFrame.Angles(0, if alongX then 0 else math.pi / 2, 0)
		if ModelAssets.Spawn(id, cf, "Shell", parent or part) then
			placed += 1
		end
	end
	if placed > 0 then
		part.Transparency = 1
	end
	return placed
end

return ModelAssets
