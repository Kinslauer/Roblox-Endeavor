local module = {}
module.Parts = {}
module.Tweens = {}
module.Connections = {}

local bodyParts = {
	["Head"] = true,
	["Torso"] = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

function module.Effect(_,character)
	table.insert(module.Connections,character.Humanoid.HealthChanged:Connect(module.OnHit))
	for i,v in pairs(bodyParts) do
		local part = character[i]
		local outline = part:Clone()
		outline.Transparency = .9
		outline.Material = Enum.Material.Neon
		outline.Color = Color3.new(1,.8)
		outline.Size *= Vector3.new(1.1,1.1,1.1)
		outline.Name = "Outline"

		local weld = Instance.new("WeldConstraint",outline)
		weld.Part0 = part
		weld.Part1 = outline

		outline.Parent = part
		table.insert(module.Parts,outline)
	end
	repeat wait() until not character:GetAttribute("Attacking")
	module:Destroy()
end

function module.OnHit()
	local TweenService = game:GetService("TweenService")
	for i,v in pairs(module.Parts) do
		coroutine.wrap(function()
			v.Transparency = .6
			local tween = TweenService:Create(v,TweenInfo.new(.1),{Transparency = .9})
			table.insert(module.Tweens,tween)
			tween:Play()
		end)()
	end
end

function module:Destroy()
	for i,v in pairs(module.Parts) do
		v:Destroy()
	end
	for i,v in pairs(module.Tweens) do
		v:Cancel()
	end
	for i,v in pairs(module.Connections) do
		v:Disconnect()
	end
end

return module
