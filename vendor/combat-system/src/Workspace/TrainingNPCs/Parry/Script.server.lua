local humanoid = script.Parent.Humanoid

local anims = {}

for i,v in pairs(game.ReplicatedStorage.Animations.Core:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end

humanoid.HealthChanged:Connect(function()
	anims["Hit"..math.random(1,2)]:Play()
end)
