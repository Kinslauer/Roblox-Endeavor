-- The props the train intro shows on the rider (client/Intro.lua clones them locally): the cloak (a skinned mesh that
-- client/Cloth.lua simulates), the pistol in its holster and the weapon across the back. Put in ReplicatedStorage.IntroKit at startup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local IntroKit = {}

local function piece(folder, name, assetId, origin)
	local template = assetId and ModelAssets.Template(assetId)
	if not template then
		return
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		model.Parent = holder
		model = holder
	end
	Assets.Dress(model)
	if origin then
		-- a skinned upload keeps its FBX node turned a quarter round in the pivot; the mesh itself is upright and
		-- built around the origin (the torso's frame), so the pivot goes back to the origin, unturned
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.PivotOffset = p.CFrame:Inverse()
			end
		end
		model.WorldPivot = CFrame.new()
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		elseif p:IsA("PointLight") then
			p:Destroy()
		end
	end
	model.Name = name
	model.Parent = folder
end

function IntroKit.Init()
	local folder = Instance.new("Folder")
	folder.Name = "IntroKit"
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		piece(folder, "Cloak", Assets.Intro and Assets.Intro.Cloak, true)
		piece(folder, "Sidearm", Assets.Weapons.Whisper and Assets.Weapons.Whisper.Id)
		piece(folder, "Back", Assets.Weapons.PipeClub and Assets.Weapons.PipeClub.Id)
	end)
end

return IntroKit
