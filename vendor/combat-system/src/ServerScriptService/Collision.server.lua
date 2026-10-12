local PhysicsService = game:GetService("PhysicsService")

PhysicsService:CreateCollisionGroup("Players")
PhysicsService:CreateCollisionGroup("NPCs")

PhysicsService:CollisionGroupSetCollidable("Players","Players",false)
PhysicsService:CollisionGroupSetCollidable("NPCs","Players",false)

function addToGroup(char)
	char:WaitForChild("Humanoid")

	for i,v in pairs(char:GetChildren()) do
		if v:IsA("BasePart") then--and v.Name ~= "HumanoidRootPart" and v.Name ~= "Head" then
			PhysicsService:SetPartCollisionGroup(v,"Players")
		end
	end
end

workspace.Live.ChildAdded:Connect(addToGroup)
workspace.Training.ChildAdded:Connect(addToGroup)
