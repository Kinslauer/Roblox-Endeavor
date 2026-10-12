local module = {}
module.CleanUp = {}
module.BodyParts = {}

local bodyParts = {
	["Head"] = true,
	["Torso"] = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

function module.Effect(_,character)
	local TweenService = game:GetService("TweenService")
	local duration = .6
	module.character = character
	for i,v in pairs(character:GetDescendants()) do
		if not v:IsA("BasePart") or v.Transparency == 1 then continue end
		v.Transparency = .4
		local outline = v:Clone()
		outline.Transparency = .9
		outline.Material = Enum.Material.Neon
		outline.Color = Color3.new(1,1,1)

		local weld = Instance.new("WeldConstraint",outline)
		weld.Part0 = v
		weld.Part1 = outline
		
		outline.Parent = v

		coroutine.wrap(function()
			local tween = TweenService:Create(v,TweenInfo.new(duration),{Transparency = 0})
			local tween2 = TweenService:Create(outline,TweenInfo.new(duration),{Transparency = 1})
			table.insert(module.CleanUp,{tween,tween2,outline})
			tween:Play()
			tween2:Play()
			task.wait(duration)
			outline:Destroy()
		end)()
	end
end

function module:Destroy()
	for i,v in pairs(module.CleanUp) do
		v[1]:Cancel()
		v[2]:Cancel()
		v[3]:Destroy()
	end
	for i,v in pairs(module.BodyParts) do
		v.Transparency = 0
	end
end

return module
