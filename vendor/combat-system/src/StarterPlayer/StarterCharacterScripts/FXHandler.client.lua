local events = game.ReplicatedStorage.Events
local FX = game.ReplicatedStorage.Modules.FX

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

events.Client.OnClientEvent:Connect(function(effect,data,parent,duration,...)
	if parent:IsA("BasePart") then
		if (parent.Position-humanoidRootPart.Position).Magnitude > 200 then return end
	else
		if (parent.PrimaryPart.Position-humanoidRootPart.Position).Magnitude > 200 then return end
	end
	local vfx = FX:FindFirstChild(effect)
	if not vfx then return end
	local module = require(vfx)
	if module[data] then
		module[data](parent,...)
	else
		print(...)
		module.Effect(data,parent,...)
	end
	module = nil
	vfx = nil
end)
