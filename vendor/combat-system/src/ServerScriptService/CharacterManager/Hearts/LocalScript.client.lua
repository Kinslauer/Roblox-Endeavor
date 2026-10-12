local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local frame = script.Parent.Frame
local hearts = #frame:GetChildren()-1

local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local events = {}

script.Parent.Adornee = humanoidRootPart

table.insert(events,humanoid.HealthChanged:Connect(function(health)
	local healthPercent = health/humanoid.MaxHealth
	local lowerBound = math.floor(healthPercent / .25) * .25
	local nearestHeart = lowerBound/.25
	
	if nearestHeart < 0 then	return end

	if frame:FindFirstChild(nearestHeart+1) then
		frame[nearestHeart+1].Frame.Visible = false
	end
	
	local heart = frame[nearestHeart]
	local heartPercent = (healthPercent-lowerBound)/.25
	
	print(healthPercent,healthPercent-lowerBound,heartPercent)
	
	heart.Frame.Position = UDim2.new(-(1-heartPercent),0,0,0)
	heart.Frame.Filled.Position = UDim2.new(1-heartPercent,0,0,0)
end))
table.insert(events,humanoid.Died:Connect(function()
	for i,v in pairs(events) do
		v:Disconnect()
	end
end))

