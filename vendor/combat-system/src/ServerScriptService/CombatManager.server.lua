local events = game.ReplicatedStorage.Events
local modules = game.ServerStorage.Modules
local Hitbox = require(modules.Hitbox)
local ClassData = require(modules.ClassData)
local ClassDescriptionScript = game.ReplicatedStorage.Modules.ClassDescription
local SkillData = require(modules.SkillData)

local MAX_PARTICLE_DURATION = 5
local ATTACK_CD = 1
local HEAVY_CD = 2
local BLOCK_CD = 1
local DODGE_CD = 2
local PB_CD = .2
local ATTACK_END_STUN = .5
local DODGE_IFRAMES = .5
local ATTACK_COUNT_RESET = 1

local ATTACK_HIT_EFFECT = .02
local HEAVY_HIT_EFFECT = .1

local PROJECTILE_EMIT_POSITION = {
	[0] = function()
		return "HumanoidRootPart"
	end,
	[1] = function()
		return "Left Arm"
	end,
	[2] = function()
		return "Right Arm"
	end,
}

local function inAction(character)
	return character:GetAttribute("Blocking") or 
		character:GetAttribute("Attacking") or 
		character:GetAttribute("HitStun") or 
		character:GetAttribute("Dodging") or 
		character:GetAttribute("SkillActive") or 
		character:GetAttribute("Countered") or
		character:GetAttribute("BlockBroken")
end

local function sendFX(data,parent,sfx,particles,vfx,...)
	if sfx then
		events.Client:FireAllClients("PlaySFX",sfx,parent,data,...)
	end
	if particles then
		events.Client:FireAllClients("EmitParticles",particles,parent,MAX_PARTICLE_DURATION,...)
	end
	if vfx then
		events.Client:FireAllClients(vfx,data,parent,MAX_PARTICLE_DURATION,...)
	end
end

local function getClientDelay(currentAttack,timeTaken)
	local activeDuration = currentAttack.HitEnd0-currentAttack.HitStart0
	if timeTaken < currentAttack.HitStart0 then
		task.wait(currentAttack.HitStart0-timeTaken)
	else
		--behind schedule
		activeDuration = currentAttack.HitEnd0-timeTaken
	end
	return activeDuration
end

local function displace(moveDir,equation,humanoidRootPart)
	local lookVector = humanoidRootPart.CFrame.LookVector.Unit
	local lookDir = Vector3.new(lookVector.X,0,lookVector.Z)

	local lastCFrame = humanoidRootPart.CFrame
	local timePassed = 0
	local event

	event = game:GetService("RunService").Heartbeat:Connect(function(dt)
		timePassed+=dt
		local velocity = equation(timePassed)
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

local function knockback(humanoidRootPart,entity)
	local adjustedEntityPos = entity.PrimaryPart.Position + humanoidRootPart.CFrame.LookVector * 5
	local lookDir = (adjustedEntityPos-humanoidRootPart.Position).Unit
	local moveDir = Vector3.new(lookDir.X,0,lookDir.Z)
	if entity:GetAttribute("NPC") then
		if entity.PrimaryPart.Anchored == false then
			task.delay(.1,function()
				local event = displace(moveDir,function(x)
					return -800*(x^2)+80
				end,entity.PrimaryPart)
				task.wait(.25)
				event:Disconnect()
			end)
		end
	else
		events.Knockback:FireClient(game.Players[entity.Name],moveDir)
	end
	entity:SetAttribute("HitStun",true)
	task.delay(ATTACK_END_STUN,function()
		entity:SetAttribute("HitStun",false)
	end)
end

local function onBlock(entity,character,postureDamage)
	local entityRoot = entity.HumanoidRootPart
	local rootToOther = character.HumanoidRootPart.Position-entityRoot.Position
	if entityRoot.CFrame.LookVector.Unit:Dot(rootToOther.Unit) < .1 then--hit behind back
		entity:SetAttribute("Blocking",false)
		task.delay(BLOCK_CD,function()
			entity:SetAttribute("BlockCD",false)
		end)
		return true
	end
	local currentPosture = entity:GetAttribute("Posture")
	local afterPosture = currentPosture+postureDamage
	entity:SetAttribute("Posture",afterPosture)
end

function disableHitboxes(player)
	local liveData = workspace.Interactive:FindFirstChild(player)
	for i,v in pairs(liveData:GetChildren()) do
		print(i,v)
		v:Destroy()
	end
end

function attack(player)
	local character = player.Character

	if character:GetAttribute("AttackCD") or inAction(character) then return end
	character:SetAttribute("Attacking",true)
	if character:GetAttribute("AttackStun") then
		character:SetAttribute("AttackQueue",true)
	else
		character:SetAttribute("AttackStun",true)
	end

	local class = player:GetAttribute("Class")

	local humanoidRootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid
	local currentHealth = humanoid.Health
	
	local attackCount = character:GetAttribute("AttackCounter")
	local currentClass = ClassData[class]
	local attackAmount = #currentClass.Attacks
	local currentAttack = currentClass.Attacks[attackCount]
	local stunDuration = currentAttack.CooldownEnd*1.5
	
	local hitbox = Hitbox.new({character})
	local liveData = workspace.Interactive:FindFirstChild(player.Name or "Dummy")
	local hitboxData = Instance.new("Folder",liveData)
	hitboxData:SetAttribute("Active",true)
	
	if currentAttack.RotationLocked then
		character:SetAttribute("RotationLocked",true)
	end
	
	local activeDuration = getClientDelay(currentAttack,player:GetNetworkPing())
	
	if character:GetAttribute("HitStun") then 
		character:SetAttribute("Attacking",false)
		return 
	end

	character:SetAttribute("AttackCounter",attackCount+1)

	hitbox.OnDeactivate = function()
		hitboxData:Destroy()
		if character.Parent == workspace.Training then
			character.Torso.Color = Color3.new(1)
		end
		character:SetAttribute("RotationLocked",false)
		if character:GetAttribute("AttackCounter") > attackAmount then--maximum m1s
			character:SetAttribute("AttackCD",true)
			character:SetAttribute("AttackCounter",1)
			task.delay(ATTACK_CD,function()
				character:SetAttribute("AttackCD",false)
			end)
		end
		task.wait(currentAttack.CooldownEnd-currentAttack.HitEnd0)
		task.wait(ATTACK_COUNT_RESET)
		if attackCount+1 == character:GetAttribute("AttackCounter") then
			character:SetAttribute("AttackCounter",1)
		end
	end
	hitbox.BlockCondition = function(entity)
		return onBlock(entity,character,currentClass.Attacks.PostureDamage)
	end
	hitbox.OnHit = function(entity)
		if not entity:GetAttribute("Hyperarmor") then
			if entity:GetAttribute("HitStun") then
				entity:SetAttribute("HitQueue",true)
			else
				entity:SetAttribute("HitStun",true)
			end
			task.delay(stunDuration,function()
				if not entity:GetAttribute("HitQueue") then
					entity:SetAttribute("HitStun",false)
				else
					entity:SetAttribute("HitQueue",false)
				end
			end)
			entity:SetAttribute("AttackStun",false)
			entity:SetAttribute("RotationLocked",false)
			if (attackCount >= attackAmount or currentAttack.Knockback) then
				knockback(humanoidRootPart,entity)
			end
			disableHitboxes(entity.Name)
			hitbox:AddDuration(ATTACK_HIT_EFFECT)
		end
		local humanoid = entity:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:TakeDamage(currentClass.Attacks.Damage)
			if not humanoid.Parent:FindFirstChild("Script") and humanoid.Health <= 0 then
				player.leaderstats.Kills.Value += 1
			end
		end
		if player.Parent then
			events.OnHit:FireClient(player,ATTACK_HIT_EFFECT)
		end
		events.Client:FireAllClients("PlaySFX",{"Hit"..math.random(1,3)},entity.PrimaryPart)
		events.Client:FireAllClients("EmitParticles","HitBlunt",entity.PrimaryPart,MAX_PARTICLE_DURATION)
	end
	hitbox:Update(function(dt)
		hitbox.Position = humanoidRootPart.Position
		hitbox.Direction = humanoidRootPart.CFrame.LookVector
	end)
	hitbox:Activate(activeDuration,currentAttack.HitCondition or function(entity,distance,radius)
		if distance < (currentAttack.Range or currentClass.Range) and radius > (currentAttack.Radius or currentClass.Radius or .3) then
			return true
		end
		return false
	end)

	local destroyEvent
	destroyEvent = liveData.Destroying:Connect(function()
		hitbox:Destroy()
		destroyEvent:Disconnect()
	end)
	
	events.Client:FireAllClients("PlaySFX",{"Swish"..math.random(1,2)},humanoidRootPart)
	sendFX(hitboxData,humanoidRootPart,currentAttack.SFX,currentAttack.Particles,currentAttack.VFX)
	if character.Parent == workspace.Training then
		character.Torso.Color = Color3.new(0,1)
	end

	task.wait(currentAttack.CooldownEnd-currentAttack.HitEnd0)
	character:SetAttribute("Attacking",false)	
	if not character:GetAttribute("AttackQueue") then
		character:SetAttribute("AttackStun",false)
	else
		character:SetAttribute("AttackQueue",false)
	end
	task.wait(HEAVY_CD)
	character:SetAttribute("HeavyCD",false)
end

function heavy(player)
	local character = player.Character

	if character:GetAttribute("HeavyCD") or inAction(character) then return end
	character:SetAttribute("HeavyCD",true)
	character:SetAttribute("Attacking",true)
	if character:GetAttribute("AttackStun") then
		character:SetAttribute("AttackQueue",true)
	else
		character:SetAttribute("AttackStun",true)
	end

	local humanoidRootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid
	local class = player:GetAttribute("Class")
	
	local currentClass = ClassData[class]
	local currentAttack = currentClass.Heavy
	
	local hitbox = Hitbox.new({character})
	local liveData = workspace.Interactive:FindFirstChild(player.Name or "Dummy")
	local hitboxData = Instance.new("Folder",liveData)
	hitboxData.Name = currentAttack.Projectile and "Projectile" or "Hitbox"
	hitboxData:SetAttribute("Active",true)
	
	if currentAttack.RotationLocked then
		character:SetAttribute("RotationLocked",true)
	end
	if currentAttack.Hyperarmor then
		character:SetAttribute("Hyperarmor",true)
		events.Client:FireAllClients("Hyperarmor",nil,character,currentAttack.CooldownEnd*2.5)
	end
	
	local activeDuration = getClientDelay(currentAttack,player:GetNetworkPing())
	
	if character:GetAttribute("HitStun") then 
		character:SetAttribute("Attacking",false)
		task.wait(HEAVY_CD)
		character:SetAttribute("HeavyCD",false)
		return 
	end

	hitbox.Position = character[currentAttack.Emit and PROJECTILE_EMIT_POSITION[currentAttack.Emit]() or "HumanoidRootPart"].Position
	hitbox.Direction = character.HumanoidRootPart.CFrame.LookVector
	hitboxData:SetAttribute("Position",hitbox.Position)
	hitboxData:SetAttribute("Direction",hitbox.Direction)
	
	hitbox.OnDeactivate = function(test)
		hitboxData:Destroy()
		if character.Parent == workspace.Training then
			character.Torso.Color = Color3.new(1)
		end
		if currentAttack.Hyperarmor then
			character:SetAttribute("Hyperarmor",false)
		end
		character:SetAttribute("RotationLocked",false)
	end
	hitbox.BlockCondition = function(entity)
		return onBlock(entity,character,currentAttack.PostureDamage)
	end
	hitbox.OnHit = function(entity)
		if not entity:GetAttribute("Hyperarmor") then
			entity:SetAttribute("AttackStun",false)
			entity:SetAttribute("RotationLocked",false)
			knockback(humanoidRootPart,entity)
			disableHitboxes(entity.Name)
			if not currentAttack.Projectile then
				hitbox:AddDuration(HEAVY_HIT_EFFECT)
			end
		end
		local humanoid = entity:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:TakeDamage(currentAttack.Damage)
			if not humanoid.Parent:FindFirstChild("Script") and humanoid.Health <= 0 then
				player.leaderstats.Kills.Value += 1
			end
		end
		if player.Parent and not currentAttack.Projectile then
			events.OnHit:FireClient(player,HEAVY_HIT_EFFECT)
		end
		events.Client:FireAllClients("PlaySFX",{"Hit"..math.random(1,3)},entity.PrimaryPart)
		events.Client:FireAllClients("EmitParticles","HitHeavy",entity.PrimaryPart,MAX_PARTICLE_DURATION)
	end
	hitbox:Update(currentAttack.Projectile and function(dt)
		local distance = currentAttack.Velocity*dt
		local displacement = hitbox.Direction*currentAttack.Velocity*dt
		local newPosition = hitbox.Position+displacement
		hitbox.Direction = (newPosition-hitbox.Position).Unit
		hitbox.Position = newPosition
		hitboxData:SetAttribute("Position",hitbox.Position)
		hitboxData:SetAttribute("Direction",hitbox.Direction)
	end or function(dt)
		hitbox.Position = humanoidRootPart.Position
		hitbox.Direction = humanoidRootPart.CFrame.LookVector
	end)
	hitbox:Activate(currentAttack.Duration or activeDuration,currentAttack.HitCondition or function(entity,distance,radius)
		if distance < (currentAttack.Range or currentClass.Range) and radius > (currentAttack.Radius or .3) then
			return true
		end
		return false
	end)
	
	local destroyEvent
	destroyEvent = liveData.Destroying:Connect(function()
		hitbox:Destroy()
		destroyEvent:Disconnect()
	end)
	
	sendFX(hitboxData,humanoidRootPart,currentAttack.SFX,currentAttack.Particles,currentAttack.VFX)
	
	if character.Parent == workspace.Training then
		character.Torso.Color = Color3.new(0,1)
	end

	task.wait(currentAttack.CooldownEnd-activeDuration)
	character:SetAttribute("Attacking",false)	
	if not character:GetAttribute("AttackQueue") then
		character:SetAttribute("AttackStun",false)
	else
		character:SetAttribute("AttackQueue",false)
	end
	task.wait(HEAVY_CD)
	character:SetAttribute("HeavyCD",false)
end

function skill(player,skillName,key)
	local character = player.Character
	
	if inAction(character) or character:GetAttribute(key) then return end
	local passed = false
	local playerData = _G.Profiles[player.Name]
	for i,v in pairs(playerData.Skills) do
		if v == skillName then
			passed = true
		end
	end
	if not passed then return end
	local class = player:GetAttribute("Class")
	local skill = SkillData[skillName]
	
	if not skill.Compatible[class] then return end

	character:SetAttribute("SkillActive",true)
	
	local humanoidRootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid
	
	local hitbox = Hitbox.new({character})
	local liveData = workspace.Interactive:FindFirstChild(player.Name or "Dummy")
	local hitboxData = Instance.new("Folder",liveData)
	hitboxData.Name = skill.Projectile and "Projectile" or "Hitbox"
	
	if skill.VFX then
		events.Client:FireAllClients("EmitParticles",skill.VFX,character.Handle,skill.CooldownEnd)
	end

	character:SetAttribute(key,skill.Cooldown)

	local activeDuration = getClientDelay(skill,player:GetNetworkPing())
	
	local count = 0
	while true do

		hitboxData:SetAttribute("Active",true)
		local skillFrameData = skill[count]
		local stunDuration = activeDuration*(skillFrameData and skillFrameData["StunScale"] or 2.5)
		hitbox.OnDeactivate = function()
			if character.Parent == workspace.Training then
				character.Torso.Color = Color3.new(1)
			end
			hitboxData:SetAttribute("Active",false)
		end
		hitbox.BlockCondition = function(entity)
			return onBlock(entity,character,skillFrameData and skillFrameData.PostureDamage or skill.ComboPostureDamage)
		end
		hitbox.OnHit = function(entity)
			if entity:GetAttribute("HitStun") then
				entity:SetAttribute("HitQueue",true)
			else
				entity:SetAttribute("HitStun",true)
			end
			task.delay(stunDuration,function()--stun duration
				if not entity:GetAttribute("HitQueue") then
					entity:SetAttribute("HitStun",false)
				else
					entity:SetAttribute("HitQueue",false)
				end
			end)
			if skill.SFX then
				events.Client:FireAllClients("PlaySFX",skill.SFX,entity.PrimaryPart)
			end
			events.Client:FireAllClients("PlaySFX",{"Hit"..math.random(1,3)},entity.PrimaryPart)
			local humanoid = entity:FindFirstChild("Humanoid")
			if humanoid then
				humanoid:TakeDamage(skillFrameData and skillFrameData.Damage or skill.ComboDamage)
				if not humanoid.Parent:FindFirstChild("Script") and humanoid.Health <= 0 then
					player.leaderstats.Kills.Value += 1
				end
			end
			if not entity:GetAttribute("Hyperarmor") then
				disableHitboxes(entity.Name)
			end
			if skillFrameData and skillFrameData.Knockback then
				events.Client:FireAllClients("EmitParticles","HitHeavy",entity.PrimaryPart,MAX_PARTICLE_DURATION)
				knockback(humanoidRootPart,entity)
			else
				events.Client:FireAllClients("EmitParticles","HitBlunt",entity.PrimaryPart,MAX_PARTICLE_DURATION)
			end
		end
		hitbox:Update(function(dt)
			hitbox.Position = humanoidRootPart.Position
			hitbox.Direction = humanoidRootPart.CFrame.LookVector
		end)
		hitbox:Activate(activeDuration,skill.HitCondition or function(entity,distance,radius)
			if character.Parent == workspace.Training then
				character.Torso.Color = Color3.new(0,1)
			end
			if distance < skill.Range  and radius > (skill.Radius or .3) then
				return true
			end
			return false
		end)
		
		task.wait(activeDuration)
		count+=1
		print(hitboxData)
		if not hitboxData.Parent then
			break
		end
		if hitbox.Destroyed or not skill["HitStart"..count] then
			hitboxData:Destroy()
			break 
		end
		task.wait(skill["HitStart"..(count)] - skill["HitEnd"..count-1])
		activeDuration = skill["HitEnd"..count] - skill["HitStart"..count]

	end

	hitbox:Destroy()
	character:SetAttribute("SkillActive",false)
	task.wait(skill.Cooldown)
	character:SetAttribute(key,nil)
	
end

function block(player)
	local character = player.Character
	local humanoid = character.Humanoid
	
	if character:GetAttribute("Blocking") then--unblock
		character:SetAttribute("Blocking",false)
		character:SetAttribute("Parry",true)
		task.delay(PB_CD,function()
			character:SetAttribute("Parry",false)
			task.wait(BLOCK_CD-PB_CD)
			character:SetAttribute("BlockCD",false)
		end)	
		return
	end
	if character:GetAttribute("HitStun") or character:GetAttribute("BlockCD") 
		or character:GetAttribute("Countered") or character:GetAttribute("BlockBroken") then return end
	
	if character:GetAttribute("Attacking") then
		character:GetAttributeChangedSignal("Attacking"):Wait()
	end

	character:SetAttribute("Blocking",true)
	character:SetAttribute("BlockCD",true)
end

function dodge(player)
	local character = player.Character
	if character:GetAttribute("DodgeCD") or inAction(character) then return end
	character:SetAttribute("IFrames",true)
	character:SetAttribute("DodgeCD",true)
	character:SetAttribute("Dodging",true)
	character:SetAttribute("RotationLocked",true)
	events.Client:FireAllClients("PlaySFX",{"Dodge"},character.HumanoidRootPart)
	events.Client:FireAllClients("Dodge",nil,character,1)
	task.delay(DODGE_IFRAMES,function()
		character:SetAttribute("IFrames",false)
		character:SetAttribute("Dodging",false)
		character:SetAttribute("RotationLocked",false)
		task.wait(DODGE_CD-DODGE_IFRAMES)
		character:SetAttribute("DodgeCD",false)
	end)
end

events.Attack.OnServerEvent:Connect(attack)
events.Heavy.OnServerEvent:Connect(heavy)
events.Skill.OnServerEvent:Connect(skill)
events.Block.OnServerEvent:Connect(block)
events.Dodge.OnServerEvent:Connect(dodge)

script.Attack.Event:Connect(attack)
script.Heavy.Event:Connect(heavy)
script.Skill.Event:Connect(skill)
script.Block.Event:Connect(block)
