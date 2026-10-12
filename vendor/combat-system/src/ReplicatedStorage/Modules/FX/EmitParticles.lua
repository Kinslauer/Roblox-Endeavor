local module = {}

function module.Effect(VFX,parent)
	local attach = Instance.new("Attachment")
	local vfxAssets = game.ReplicatedStorage.VFX:FindFirstChild(VFX)
	local offset = vfxAssets:GetAttribute("Offset")
	if offset then
		attach.Position = offset
	end
	for i,v in pairs(vfxAssets:GetChildren()) do
		local item = v:Clone()
		item.Parent = attach
	end

	attach.Parent = parent
	for i,v in pairs(attach:GetChildren()) do
		if not v:IsA("ParticleEmitter") then continue end
		v:Emit(v:GetAttribute("EmitCount"))
	end
end

return module
