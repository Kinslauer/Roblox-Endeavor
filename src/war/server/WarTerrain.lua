-- Writes the Front's ground as smooth terrain from shared/FrontMap (one Sample per 4-stud column), in
-- 128-stud chunks with WriteVoxels, and sets the terrain's colours, water and clouds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrontMap = require(ReplicatedStorage.Shared.FrontMap)

local WarTerrain = {}

local M = Enum.Material
-- the war world's palette: ash-brown ground, black mud, bone-pale calcite where the dead have fused
local COLORS = {
	[M.Ground] = Color3.fromRGB(88, 76, 62),
	[M.Mud] = Color3.fromRGB(54, 45, 36),
	[M.Limestone] = Color3.fromRGB(170, 162, 146),
	[M.Rock] = Color3.fromRGB(80, 76, 72),
	[M.Asphalt] = Color3.fromRGB(56, 54, 52),
	[M.Slate] = Color3.fromRGB(74, 70, 66),
	[M.Concrete] = Color3.fromRGB(110, 106, 98),
}

local function materialFor(tag, h, slope, x, z)
	if tag == "Barrow" or tag == "Edge" then
		return if slope > 50 then M.Rock else M.Limestone
	elseif tag == "Trench" or tag == "Crater" or tag == "Canal" then
		return M.Mud
	elseif tag == "Road" then
		return M.Asphalt
	elseif tag == "Glade" then
		return if math.noise(x / 9, z / 9, 1.7) > 0.2 then M.Grass else M.LeafyGrass
	elseif tag == "Pad" then
		return if math.noise(x / 12, z / 12, 2.3) > 0.1 then M.Slate else M.Ground
	end
	if slope > 40 then
		return M.Rock
	end
	return if math.noise(x / 38, z / 38, 7.1) > 0.22 then M.Mud else M.Ground
end

function WarTerrain.Write()
	local terrain = workspace.Terrain
	local L = FrontMap.Layout()
	local B = L.Bounds
	local RES, CHUNK = 4, 128
	local n = CHUNK / RES
	local chunks, voxels = 0, 0
	for cx = B.X0, B.X1 - 1, CHUNK do
		for cz = B.Z0, B.Z1 - 1, CHUNK do
			-- sample one extra column each side so slopes at the chunk edge are right
			local heights, tags, waters = {}, {}, {}
			local hmin, hmax = math.huge, -math.huge
			for i = 0, n + 1 do
				heights[i], tags[i], waters[i] = {}, {}, {}
				local x = cx + (i - 0.5) * RES
				for k = 0, n + 1 do
					local z = cz + (k - 0.5) * RES
					local h, tag, water = FrontMap.Sample(x, z)
					heights[i][k], tags[i][k], waters[i][k] = h, tag, water
					if i >= 1 and i <= n and k >= 1 and k <= n then
						hmin = math.min(hmin, h)
						hmax = math.max(hmax, water or h, h)
					end
				end
			end
			local y0 = math.floor((hmin - 12) / RES) * RES
			local y1 = math.ceil((hmax + 2) / RES) * RES + RES
			local ny = (y1 - y0) / RES
			local mats = {}
			for i = 1, n do
				mats[i] = {}
				local x = cx + (i - 0.5) * RES
				for k = 1, n do
					local z = cz + (k - 0.5) * RES
					local dx = heights[i + 1][k] - heights[i - 1][k]
					local dz = heights[i][k + 1] - heights[i][k - 1]
					local slope = math.deg(math.atan(math.sqrt(dx * dx + dz * dz) / (2 * RES)))
					mats[i][k] = materialFor(tags[i][k], heights[i][k], slope, x, z)
				end
			end
			local materials, occupancy = table.create(n), table.create(n)
			for i = 1, n do
				local mc, oc = table.create(ny), table.create(ny)
				for j = 1, ny do
					local bottom = y0 + (j - 1) * RES
					local mr, orow = table.create(n), table.create(n)
					for k = 1, n do
						local h = heights[i][k]
						-- the rendered surface sits a half voxel above a column filled to h (measured live on Endeavor)
						local occ = math.clamp((h - 2 - bottom) / RES, 0, 1)
						if occ > 0 then
							orow[k], mr[k] = occ, mats[i][k]
						else
							local water = waters[i][k]
							local wocc = if water then math.clamp((water - 2 - bottom) / RES, 0, 1) else 0
							if wocc > 0 then
								orow[k], mr[k] = wocc, M.Water
							else
								orow[k], mr[k] = 0, M.Air
							end
						end
					end
					mc[j], oc[j] = mr, orow
				end
				materials[i], occupancy[i] = mc, oc
			end
			local region = Region3.new(Vector3.new(cx, y0, cz), Vector3.new(cx + CHUNK, y1, cz + CHUNK))
			terrain:WriteVoxels(region, RES, materials, occupancy)
			chunks += 1
			voxels += n * n * ny
		end
	end
	pcall(function()
		for material, color in COLORS do
			terrain:SetMaterialColor(material, color)
		end
		terrain.WaterColor = Color3.fromRGB(58, 54, 40)
		terrain.WaterTransparency = 0.15
		terrain.WaterReflectance = 0.25
		terrain.WaterWaveSize = 0.04
		terrain.WaterWaveSpeed = 3
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover, clouds.Density, clouds.Color = 0.82, 0.7, Color3.fromRGB(120, 112, 104)
		clouds.Parent = terrain
	end)
	return chunks, voxels
end

return WarTerrain
