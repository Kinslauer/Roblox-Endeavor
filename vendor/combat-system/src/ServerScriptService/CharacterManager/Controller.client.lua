local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = game.Players.LocalPlayer

local events = game.ReplicatedStorage.Events
local animations = game.ReplicatedStorage.Animations
local class = player:GetAttribute("Class")

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local currentAnim = "BlockHit"
local anims = {}

for i,v in pairs(animations.Core:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end
for i,v in pairs(animations[class]:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end

repeat task.wait() until anims.Idle.Length > 0 
anims.Idle:Play()

local function displace(moveDir,path)
	local lookVector = humanoidRootPart.CFrame.LookVector.Unit
	local lookDir = Vector3.new(lookVector.X,0,lookVector.Z)
	
	local lastCFrame = humanoidRootPart.CFrame
	local timePassed = 0
	local event

	event = game:GetService("RunService").RenderStepped:Connect(function(dt)
		timePassed+=dt
		local velocity = path(timePassed)
		local nextPos = humanoidRootPart.Position + moveDir*(velocity*dt)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {workspace.Live,workspace.Training,workspace.TrainingNPCs}
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local nextDir = (nextPos-lastCFrame.Position)/ ((nextPos-lastCFrame.Position).Magnitude/2)
		local raycastResult = workspace:Raycast(lastCFrame.Position, nextDir , raycastParams)

		if raycastResult then
			local hitPart = raycastResult.Instance
			if hitPart then
				event:Disconnect()
				humanoidRootPart.CFrame = lastCFrame
				humanoid.AutoRotate = true
				return
			end
		end

		local rotVert = humanoidRootPart.CFrame.RightVector.Unit:Dot(moveDir)/(1.2+15*timePassed)
		local rotHori = humanoidRootPart.CFrame.LookVector.Unit:Dot(moveDir)/(1.2+15*timePassed)
		local newCFrame = CFrame.new(nextPos,nextPos+lookDir) * CFrame.Angles(-rotHori,0,-rotVert)--(forward)(-45 to 45) (side)(-45 to 45)
		humanoidRootPart.CFrame = newCFrame
		lastCFrame = newCFrame
	end)
	return event
end

local currentDirection = Vector2.new()
local lastWPress = 0
local isSprinting = false
local dodging = false
local skillActive = false

local function cantAttack()
	return character:GetAttribute("Attacking") or character:GetAttribute("SkillActive") or character:GetAttribute("Blocking")
end

local keyMapStart = {	
	["Block"] = function()
		if cantAttack() or character:GetAttribute("BlockCD") then return end
		isSprinting = false
		anims.Sprint:Stop()
		events.Block:FireServer()
		if character:GetAttribute("Attacking") then
			character:GetAttributeChangedSignal("Attacking"):Wait()
		end
	end,
	
	["Dodge"] = function()
		if character:GetAttribute("Attacking") or character:GetAttribute("DodgeCD") or dodging then return end
		dodging = true

		game.ReplicatedStorage.Events.Dodge:FireServer()
		
		anims.Sprint:Stop()
		
		local moveDirection = humanoid.MoveDirection
		local moveDir = Vector3.new(moveDirection.X,0,moveDirection.Z)

		if moveDir ~= Vector3.new(0,0,0) then
			local event = displace(moveDir,function(x)
				return (-(480*x)*(x-.5))
			end)
			task.wait(.5)
			event:Disconnect()
		end
		
		if isSprinting then
			anims.Sprint:Play()
		end

		dodging = false
	end,

	["W"] = function()
		if cantAttack() or character:GetAttribute("AttackStun") then return end
		if tick()-lastWPress < .2 then
			isSprinting = true
			anims.Sprint:Play(.1,1,1.5)
		end
		lastWPress = tick()
	end,
}

local keyMapEnd = {
	["Block"] = function()
		if not character:GetAttribute("Blocking") then return end
		events.Block:FireServer()
		anims["Block"]:Stop()
	end,
	["W"] = function()
		isSprinting = false
		anims.Sprint:Stop()
	end,
}

local mapStart = {
	[Enum.UserInputType.MouseButton1] = function()
		if cantAttack() or dodging or character:GetAttribute("AttackCD") then return end
		if anims["Attack"..character:GetAttribute("AttackCounter")].IsPlaying then return end
		anims[currentAnim]:Stop()
		isSprinting = false
		events.Attack:FireServer()
		anims.Sprint:Stop()
		currentAnim = "Attack"..character:GetAttribute("AttackCounter")
		anims[currentAnim]:Play()
	end,
	[Enum.UserInputType.MouseButton2] = function()
		if cantAttack() or dodging or character:GetAttribute("HeavyCD") then return end
		if anims["Heavy"].IsPlaying then return end
		anims[currentAnim]:Stop()
		isSprinting = false
		events.Heavy:FireServer()
		anims.Sprint:Stop()
		currentAnim = "Heavy"
		anims.Heavy:Play()
	end,
	[Enum.UserInputType.Keyboard] = function(key)
		if key.Name == "W" then
			keyMapStart["W"]()
		else
			local keybindMap = _G.Keybinds[key.Name]
			if keybindMap and keyMapStart[keybindMap] then 
				keyMapStart[keybindMap]()
			else
				if skillActive or cantAttack() or character:GetAttribute(keybindMap) then return end
				local currentSkill = _G.Skills[keybindMap]
				if not _G.SkillData[currentSkill].Compatible[player:GetAttribute("Class")] then return end
				skillActive = true
				currentAnim = currentSkill
				if not anims[currentAnim] then
					anims[currentAnim] = humanoid.Animator:LoadAnimation(animations.Skills[currentAnim])
				end
				anims[currentAnim]:Play()
				events.Skill:FireServer(currentAnim,keybindMap)
				wait(1)
				skillActive = false
			end
		end
	end,
}

local airState = {
	[Enum.HumanoidStateType.Jumping] = function()
		if isSprinting then
			anims.Sprint:AdjustSpeed(.6)
		end
	end,
	[Enum.HumanoidStateType.Landed] = function()
		if isSprinting then
			anims.Sprint:AdjustSpeed(1.5)
		end
	end,
}

humanoid.StateChanged:Connect(function(_oldState, newState)
	if airState[newState] then
		airState[newState]()
	end
end)

character:GetAttributeChangedSignal("Blocking"):Connect(function()
	if character:GetAttribute("Blocking") then
		anims.Block:Play()
	else
		anims.Block:Stop()
	end
end)

character:GetAttributeChangedSignal("RotationLocked"):Connect(function()
	if character:GetAttribute("RotationLocked") then
		humanoid.AutoRotate = false
	else
		if character:GetAttribute("Countered") then return end
		humanoid.AutoRotate = true
	end
end)

character:GetAttributeChangedSignal("HitStun"):Connect(function()
	if character:GetAttribute("HitStun") then
		humanoid.JumpHeight = 0
	else
		if character:GetAttribute("HitStun") then return end
		humanoid.JumpHeight = 7.2
	end
end)

character:GetAttributeChangedSignal("Countered"):Connect(function()
	if not character:GetAttribute("Countered") then return end
	local anim = anims[currentAnim]
	if not anim or not anim.isPlaying then return end
	task.wait(.8*anim:GetTimeOfKeyframe("HitEnd0")-anim.TimePosition)
	anim:AdjustSpeed(0)
	humanoid.AutoRotate = false
	task.wait(2)
	humanoid.AutoRotate = true
	anim:Stop()
end)

character:GetAttributeChangedSignal("BlockBroken"):Connect(function()
	if not character:GetAttribute("BlockBroken") then return end
	anims.Block:Stop()
	anims.BlockBroken:Play()
end)

events.OnHit.OnClientEvent:Connect(function(stunDuration)
	if stunDuration then
		local currentAttack = anims[currentAnim]
		if not currentAttack then return end
		currentAttack:AdjustSpeed(0)
		task.wait(stunDuration)
		currentAttack:AdjustSpeed(1)
	else
		if character:GetAttribute("Hyperarmor") then return end
		if character:GetAttribute("Blocking") then
			anims.BlockHit:Play(0)
		end
		anims["Hit"..math.random(1,2)]:Play()
		local anim = anims[currentAnim]
		if not anim or not anim.isPlaying then return end
		anim:Stop()
	end
end)

events.Knockback.OnClientEvent:Connect(function(moveDir)
	local event = displace(moveDir,function(x)
		return -800*(x^2)+80
	end)
	task.wait(.25)
	event:Disconnect()
end)

UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed or character:GetAttribute("HitStun") or character:GetAttribute("Countered") or character:GetAttribute("BlockBroken") then return end
	pcall(function()
		mapStart[input.UserInputType](input.KeyCode)
	end)
end)

UserInputService.InputEnded:Connect(function(input,gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode.Name == "W" then
			keyMapEnd["W"]()
		else
			if _G.Keybinds[input.KeyCode.Name] and keyMapEnd[_G.Keybinds[input.KeyCode.Name]] then 
				keyMapEnd[_G.Keybinds[input.KeyCode.Name]]()	
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if character:GetAttribute("BlockBroken") or character:GetAttribute("Countered") or dodging then
		humanoid.WalkSpeed = 0
		return
	end
	if character:GetAttribute("Attacking") or character:GetAttribute("AttackStun") or character:GetAttribute("SkillActive") then
		humanoid.WalkSpeed = 4
		return
	end
	if character:GetAttribute("Blocking") or character:GetAttribute("HitStun") then
		humanoid.WalkSpeed = 2
		return
	end
	if character:GetAttribute("Speed") then
		humanoid.WalkSpeed = 64
		return
	end
	if isSprinting then
		humanoid.WalkSpeed = 32
	else
		humanoid.WalkSpeed = 16
	end
end)
