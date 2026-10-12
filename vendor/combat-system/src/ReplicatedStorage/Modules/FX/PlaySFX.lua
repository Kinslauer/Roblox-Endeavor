local module = {}

function module.Effect(audio,parent)
	for i,v in pairs(audio) do
		local sfx = game.ReplicatedStorage.Audio[v]:Clone()
		sfx.Parent = parent
		sfx:Play()
		local event
		event = sfx.Ended:Connect(function()
			event:Disconnect()
			sfx:Destroy()
		end)
	end
end

return module
