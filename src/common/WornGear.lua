-- Worn gear: armor pieces and cybernetics welded onto a character's limbs. Models are authored with
-- the limb centre at the origin (tools/models/worn.py), so the weld is identity plus the model's own
-- part offsets. Assets.Worn[itemId] = { Id = assetId, Limb = "Head" | "UpperTorso" | "UpperLeg" |
-- "LeftLowerArm" }; "UpperLeg" puts a copy on both legs. Shared by Endeavor (armor + cyber) and the
-- Front (vest + helmet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.ModelAssets)

local WornGear = {}

local LIMBS = {
	Head = { "Head" },
	UpperTorso = { "UpperTorso" },
	UpperLeg = { "LeftUpperLeg", "RightUpperLeg" },
	LeftLowerArm = { "LeftLowerArm" },
}

local function attach(char, limbName, entry, itemId)
	local limb = char:FindFirstChild(limbName)
	local template = limb and ModelAssets.Template(entry.Id)
	if not template then
		return
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		model.Parent = holder
		model = holder
	end
	model.Name = "Worn_" .. itemId .. "_" .. limbName
	model:SetAttribute("Worn", itemId)
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
		return
	end
	local origin = model:GetPivot()
	for _, p in parts do
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = limb, p
		weld.C0 = CFrame.identity
		weld.C1 = origin:ToObjectSpace(p.CFrame)
		weld.Parent = p
	end
	model.PrimaryPart = parts[1]
	model.Parent = char
end

-- Replaces everything worn with the given item ids (any iterable of ids; unknown ids are skipped).
function WornGear.Apply(char, itemIds)
	if not char then
		return
	end
	local want = {}
	for _, id in itemIds do
		if Assets.Worn[id] then
			want[id] = true
		end
	end
	for _, child in char:GetChildren() do
		local worn = child:GetAttribute("Worn")
		if worn then
			if want[worn] then
				want[worn] = nil -- already on
			else
				child:Destroy()
			end
		end
	end
	for id in want do
		local entry = Assets.Worn[id]
		for _, limbName in LIMBS[entry.Limb] or {} do
			attach(char, limbName, entry, id)
		end
	end
end

function WornGear.Clear(char)
	WornGear.Apply(char, {})
end

return WornGear
