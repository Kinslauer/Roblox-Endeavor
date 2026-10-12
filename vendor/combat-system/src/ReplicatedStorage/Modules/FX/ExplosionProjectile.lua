local module = {}

function module.Effect(hitboxData,parent)
	print(parent,hitboxData)
	if hitboxData then
		local particle = script.Bullet:Clone()
		particle.Parent = workspace.VFX
		module.Particle = particle
		module.Event = hitboxData:GetAttributeChangedSignal("Position"):Connect(function()
			local pos = hitboxData:GetAttribute("Position")
			local dir = hitboxData:GetAttribute("Direction")
			particle.CFrame = CFrame.new(pos,pos+dir)
		end)
		local event
		event = hitboxData.Destroying:Connect(function()
			module:Destroy()
			event:Disconnect()
		end)
	end
end

function module:Destroy()
	module.Event:Disconnect()
	module.Particle:Destroy()
end

return module
