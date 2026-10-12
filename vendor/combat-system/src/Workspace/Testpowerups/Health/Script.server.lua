local event
local function effect(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player then
		hit.Parent.Humanoid.Health += 10
		event:Disconnect()
		script.Parent.Float.Transparency = 1
		script.Parent.MeshPart.Transparency = 1
		task.wait(1)
		script.Parent.Float.Transparency = .3
		script.Parent.MeshPart.Transparency = .3
		event = script.Parent.Float.Touched:Connect(effect)
	end
end
event = script.Parent.Float.Touched:Connect(effect)
