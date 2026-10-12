local module = {}
module.CleanUp = {}

local range = {
	Color3.new(0,.2,1),
	Color3.new(0,.7,1),
	Color3.new(0,.9,1),
	Color3.new(1,1,0),
	Color3.new(1,.6,0),
	Color3.new(1,.5,0),
	Color3.new(1,.3,0),
	Color3.new(1,.2,0),
	Color3.new(1,.1,0),
	Color3.new(1,0,0),
}

function module.Effect(beforePosture,root)
	local Posture = root.Parent:GetAttribute("Posture")
	local attach = Instance.new("Attachment",root)
	attach.Position = Vector3.new(0,0,-1)
	table.insert(module.CleanUp,attach)
	for i,v in pairs(script:GetChildren()) do
		coroutine.wrap(function()
			local particle = v:Clone()
			particle.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0,range[math.clamp(math.floor(Posture-1),1,10)]),
				ColorSequenceKeypoint.new(1,range[math.clamp(math.floor(Posture),1,10)]),
			}
			particle.Parent = attach
			particle:Emit(particle:GetAttribute("EmitCount"))
		end)()
	end
end

function module:Destroy()
	for i,v in pairs(module.CleanUp) do
		if typeof(v) == "TweenBase" then
			v:Cancel()
			continue
		end
		if typeof(v) == "Instance" then
			v:Destroy()
		end
	end
end

return module
