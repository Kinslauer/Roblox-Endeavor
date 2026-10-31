-- Asset registry for models built in Blender (tools/models) and uploaded through Open Cloud.
-- Props come in conditions: A intact, B worn, C wrecked. A spawn (and every rematerialization)
-- picks one at random, so the city never comes back quite the same. 0 / missing = not uploaded:
-- the game falls back to generated geometry.
local Assets = {}

Assets.Props = {
	Barrel = { A = 138973181515358, B = 79636233128816, C = 125842135926276 },
	CarWreck = { A = 135300185326024, B = 124730379936688, C = 93646164483240 },
	Crate = { A = 109129830991009, B = 138128084039228, C = 134823881595914 },
	FencePanel = { A = 135294127218303, B = 137469842853638, C = 88889940788521 },
	Slab = { A = 93218341089544, B = 85304351471716, C = 74338036722155 },
	StreetSign = { A = 81980116475569, B = 133194607355983, C = 135676038796551 },
	Streetlight = { A = 113165102986052 },
	Terminal = { A = 94139217691513, B = 79807106490326, C = 132427649381419 },
	VendingMachine = { A = 138968722251708, B = 93355970908453, C = 132176714647904 },
	WindowPane = { A = 93084252250236, B = 86227491449117, C = 107425218490351 },
}

Assets.Chunks = {
	LampHead = 102315743005097,
	PipeLong = 97783263877959,
	PipeShort = 136810514088811,
}

-- Roblox drops Blender material colours on import, so every part is named "<Part>_<Material>"
-- and the material is applied from this table when the model is loaded.
Assets.Materials = {
	Steel = { Color = Color3.fromRGB(80, 82, 88), Material = Enum.Material.Metal },
	DarkMetal = { Color = Color3.fromRGB(42, 42, 46), Material = Enum.Material.Metal },
	Rust = { Color = Color3.fromRGB(96, 54, 32), Material = Enum.Material.CorrodedMetal },
	Housing = { Color = Color3.fromRGB(46, 46, 50), Material = Enum.Material.Metal },
	Lens = { Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 220, 150) },
	Wood = { Color = Color3.fromRGB(110, 78, 44), Material = Enum.Material.WoodPlanks },
	OldWood = { Color = Color3.fromRGB(78, 62, 42), Material = Enum.Material.WoodPlanks },
	Paint = { Color = Color3.fromRGB(140, 42, 36), Material = Enum.Material.Metal },
	SignGreen = { Color = Color3.fromRGB(26, 108, 56), Material = Enum.Material.Metal },
	SignWhite = { Color = Color3.fromRGB(218, 218, 205), Material = Enum.Material.SmoothPlastic },
	Glass = { Color = Color3.fromRGB(120, 170, 205), Material = Enum.Material.Glass, Transparency = 0.45 },
	Neon = { Color = Color3.fromRGB(0, 200, 245), Material = Enum.Material.Neon, Light = Color3.fromRGB(0, 200, 255) },
	NeonPink = { Color = Color3.fromRGB(245, 50, 155), Material = Enum.Material.Neon, Light = Color3.fromRGB(255, 60, 160) },
	Concrete = { Color = Color3.fromRGB(102, 102, 108), Material = Enum.Material.Concrete },
	Tyre = { Color = Color3.fromRGB(22, 22, 22), Material = Enum.Material.Rubber },
	Chainlink = { Color = Color3.fromRGB(102, 108, 115), Material = Enum.Material.DiamondPlate, Transparency = 0.35 },
	Burnt = { Color = Color3.fromRGB(32, 26, 24), Material = Enum.Material.Slate },
	Screen = { Color = Color3.fromRGB(14, 80, 115), Material = Enum.Material.Neon, Light = Color3.fromRGB(30, 150, 230) },
}

-- Applies the named material to every part of a loaded model.
function Assets.Dress(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local matName = part.Name:match("_(%w+)$")
			local spec = matName and Assets.Materials[matName]
			if spec then
				part.Color = spec.Color
				part.Material = spec.Material
				part.Transparency = spec.Transparency or 0
				if spec.Light and not part:FindFirstChildOfClass("PointLight") then
					local light = Instance.new("PointLight")
					light.Color, light.Range, light.Brightness = spec.Light, 16, 1
					light.Parent = part
				end
			end
		end
	end
end

-- Picks a random condition's asset id for a prop, or nil.
function Assets.PickProp(propId, rng)
	local set = Assets.Props[propId]
	if not set then
		return nil
	end
	local ids = {}
	for _, cond in { "A", "B", "C" } do
		if set[cond] and set[cond] ~= 0 then
			table.insert(ids, set[cond])
		end
	end
	if #ids == 0 then
		return nil
	end
	return ids[(rng and rng:NextInteger(1, #ids)) or math.random(#ids)]
end

return Assets
