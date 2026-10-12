local event
local function effect(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and not hit.Parent:GetAttribute("Speed") then
		hit.Parent:SetAttribute("Speed",true)
		event:Disconnect()
		script.Parent.Transparency = 1
		local parts = {}
		for i,v in pairs(hit.Parent:GetChildren()) do
			if v:IsA("BasePart") then
				parts[v.Name] = v.Color
				v.Color = Color3.fromRGB(86, 66, 54)
			end
		end
		local swingSound = game.ReplicatedStorage.Audio["Lets go!"]:Clone()
		swingSound.Parent = hit.Parent.PrimaryPart
		swingSound:Destroy()
		hit.Parent.Head.face.Texture = "http://www.roblox.com/asset/?id=27134272"
		task.wait(1)
		script.Parent.Transparency = 0
		event = script.Parent.Touched:Connect(effect)
		task.delay(10,function()
			hit.Parent:SetAttribute("Speed",false)
			for i,v in pairs(parts) do
				hit.Parent[i].Color = v
			end
		end)
	end
end
event = script.Parent.Touched:Connect(effect)
