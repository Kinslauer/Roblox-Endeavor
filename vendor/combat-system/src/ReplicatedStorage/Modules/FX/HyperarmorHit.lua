local module = {}
module.Tweens = {}

local bodyParts = {
	["Head"] = true,
	["Torso"] = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

function module.Effect(_,_,character)
	local TweenService = game:GetService("TweenService")
	for i,v in pairs(character:GetChildren()) do
		if v.Name ~= "Outline" then continue end
		coroutine.wrap(function()
			v.Transparency = .6
			task.wait(.1)
			local tween = TweenService:Create(v,TweenInfo.new(.1),{Transparency = .9})
			table.insert(module.Tweens,tween)
			tween:Play()
		end)()
	end
end

function module:Destroy()
	for i,v in pairs(module.Tweens) do
		v:Cancel()
	end
end

return module
