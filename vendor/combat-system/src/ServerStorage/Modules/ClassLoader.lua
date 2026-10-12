local assets = game.ServerStorage.Assets
local function weld(rArm,handle,name)
	local RightGrip	= Instance.new("Motor6D")
	RightGrip.Name = rArm.Name == "Left Arm" and "LeftGrip" or "RightGrip"
	RightGrip.Parent = rArm
	RightGrip.Part0 = rArm
	RightGrip.Part1 = handle
	RightGrip.C1 = CFrame.new() * CFrame.Angles(math.rad(90),0,0)
	RightGrip.C0 = CFrame.new(0,-1,0)
	handle.Parent = rArm.Parent
end

return {
	["Brawler"] = function(character)
		--weld(character:WaitForChild("Right Arm"),assets.Brawler.Handle:Clone(),"RightGrip")
		--weld(character:WaitForChild("Left Arm"),assets.Brawler.Handle2:Clone(),"LeftGrip")
	end,
	["Sword"] = function(character)
		weld(character:WaitForChild("Right Arm"),assets.Sword.Handle:Clone(),"RightGrip")
	end,
	["Hammer"] = function(character)
		weld(character:WaitForChild("Right Arm"),assets.Hammer.Handle:Clone(),"RightGrip")
	end,
	["Blasters"] = function(character)
		weld(character:WaitForChild("Right Arm"),assets.Blasters.Handle:Clone(),"RightGrip")
		weld(character:WaitForChild("Left Arm"),assets.Blasters.Handle1:Clone(),"LeftGrip")
	end,
	["Spear"] = function(character)
		weld(character:WaitForChild("Right Arm"),assets.Spear.Handle:Clone(),"RightGrip")
	end,
	["Knight"] = function(character)
		weld(character:WaitForChild("Right Arm"),assets.Knight.Handle:Clone(),"RightGrip")
		weld(character:WaitForChild("Left Arm"),assets.Knight.Handle1:Clone(),"LeftGrip")
	end,
}
