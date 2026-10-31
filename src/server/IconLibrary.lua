-- Clones every inventory icon model into ReplicatedStorage.Icons so the client can show items in
-- ViewportFrames. Runs in the background after startup; the grid falls back to labels until then.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Items = require(ReplicatedStorage.Shared.Items)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local IconLibrary = {}

function IconLibrary.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Icons"
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		for itemId in Items.Defs do
			local assetId = Assets.IconFor(itemId)
			local template = assetId and ModelAssets.Template(assetId)
			if template then
				local model = template:Clone()
				if model:IsA("BasePart") then
					local holder = Instance.new("Model")
					model.Parent = holder
					model = holder
				end
				Assets.Dress(model)
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					elseif p:IsA("PointLight") then
						p:Destroy()
					end
				end
				model.Name = itemId
				model.Parent = folder
			end
			task.wait() -- spread the loads over frames
		end
	end)
end

return IconLibrary
