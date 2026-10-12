
for i,v in pairs(workspace.TrainingNPCs:GetChildren()) do
	if v.Name ~= "Dummy" then continue end
	v:GetAttributeChangedSignal("HitStun"):Connect(function()
		if v:GetAttribute("HitStun") then
			v.Torso.Color = Color3.new(0,1)
		else
			v.Torso.Color = Color3.new(1)
		end
	end)
end
