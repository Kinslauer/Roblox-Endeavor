-- The material library's surfaces (tools/textures): each library material was uploaded as a small swatch model
-- whose maps Roblox turned into a SurfaceAppearance. Scripts cannot set a SurfaceAppearance's maps, but they can
-- clone one, so Assets.Dress asks here for the material in a part's name ("Seat_Moquette") and clones it onto
-- the MeshPart. Swatches load on first use and are cached; the loaded ones also sit in ReplicatedStorage.Surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.ModelAssets)

local SurfaceLibrary = {}
local cache = {} -- name -> SurfaceAppearance template, or false when it failed
local folder

function SurfaceLibrary.Get(name)
	local entry = Assets.Surfaces[name]
	if not entry then
		return nil
	end
	if cache[name] == nil then
		local swatch = ModelAssets.Template(entry.Id)
		local surface = swatch and swatch:FindFirstChildWhichIsA("SurfaceAppearance", true)
		if surface then
			surface = surface:Clone()
			surface.Name = name
			surface.Parent = folder
		end
		cache[name] = surface or false
	end
	return cache[name] or nil
end

-- Loads every swatch in parallel (startup), so the first models dressed do not wait one by one.
function SurfaceLibrary.Preload()
	local pending = 0
	for name in Assets.Surfaces do
		pending += 1
		task.spawn(function()
			SurfaceLibrary.Get(name)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 15 do
		task.wait()
	end
end

function SurfaceLibrary.Init()
	folder = ReplicatedStorage:FindFirstChild("Surfaces") or Instance.new("Folder")
	folder.Name = "Surfaces"
	folder.Parent = ReplicatedStorage
	Assets.SurfaceFor = SurfaceLibrary.Get
	SurfaceLibrary.Preload()
end

return SurfaceLibrary
