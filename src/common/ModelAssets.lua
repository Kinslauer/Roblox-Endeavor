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

return ModelAssets
