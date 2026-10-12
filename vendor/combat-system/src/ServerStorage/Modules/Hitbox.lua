local events = game.ReplicatedStorage.Events
local Hitbox = {}
Hitbox.__index = Hitbox

function Hitbox.new(blacklist,hitCooldown,blockable,parryable)
	local _blacklist = {}--first element is always own character
	local _,character = next(blacklist)
	_blacklist[character] = true
	return setmetatable({
		_isActive = false,
		_hitCooldown = hitCooldown,
		_extraDuration = 0,
		_hitTracker = {},
		_blacklist = _blacklist,
		Position = Vector3.new(0,0,0),
		Direction = Vector3.new(0,0,0),
		Blockable = blockable,
		Parryable = parryable,
	},Hitbox)
end

function Hitbox:Displace(position,direction)
	self.Position = position
	self.Direction = direction
end

function Hitbox:Update(handler)
	self._displaceEvent = game:GetService("RunService").Heartbeat:Connect(handler)
	--	local newPosition = path(dt)
	--	self.Direction = (self.Position-newPosition).Unit
	--	self.Position = newPosition
	--end)
end

function Hitbox.Project(v1,v2)	
	return (v2:Dot(v1)/v1.Magnitude)*v1
end

function Hitbox:Activate(activeDuration,condition)
	assert(not self._activeEvent,"Hitbox is already active")
	self._isActive = true
	self._activeEvent = game:GetService("RunService").Heartbeat:Connect(function()
		local folder = workspace.Live
		local character = next(self._blacklist)
		local player = game.Players:FindFirstChild(character.Name)
		if player then
			if player.Team == game.Teams.Lobby then
				folder = workspace.TrainingNPCs
			end
		else
			if character.Parent == workspace.TrainingNPCs then
				folder = workspace.Training
			end
		end
		for _,entity in pairs(folder:GetChildren()) do 
			if self._hitTracker[entity] or self._blacklist[entity] or entity.Humanoid.Health <= 0 then continue end
			
			local entityPosition = entity.HumanoidRootPart.Position
			--local projection = Hitbox.Project(self.Direction,entityPosition)
			--local positionOnCenterLine = projection+self.Position-entityPosition
			--local distFromCenterLine = positionOnCenterLine.Magnitude
			
			local rootToOther = entityPosition-self.Position
			local radius = self.Direction:Dot(rootToOther.Unit)
			
			if rootToOther.Magnitude < 3 or coroutine.wrap(condition)(entity,rootToOther.Magnitude,radius) then --check if it hits
				self._hitTracker[entity] = true
				if self._hitCooldown then--wait for cooldown to remove entity from tracker list
					task.delay(self._hitCooldown,function()
						self._hitTracker[entity] = nil
					end)
				end
				
				if entity:GetAttribute("Parry") then
					events.Client:FireAllClients("EmitParticles","Parry",entity.HumanoidRootPart,1)
					events.Client:FireAllClients("PlaySFX",{"Parry"},entity.HumanoidRootPart)
					character:SetAttribute("Countered",true)
					character:SetAttribute("Blocking",false)
					character:SetAttribute("Attacking",false)
					self:Destroy()
					task.wait(1.5)
					character:SetAttribute("Countered",false)
					return 
				end
				
				local entityPlayer = game.Players:FindFirstChild(entity.Name)
				if entityPlayer then
					events.OnHit:FireClient(entityPlayer)
				end
				
				if entity:GetAttribute("Blocking") then
					local beforePosture = entity:GetAttribute("Posture")
					if self.BlockCondition then
						if not coroutine.wrap(self.BlockCondition)(entity) then-- true = hit false = not hit
							events.Client:FireAllClients("HitBlock",beforePosture,entity.HumanoidRootPart,1)
							events.Client:FireAllClients("PlaySFX",{"Blocked"..math.random(1,2)},entity.HumanoidRootPart)
							return
						end
					end
				end
				
				if entity:GetAttribute("IFrames") then
					
					return
				end
				
				if entity:GetAttribute("Hyperarmor") then
					--local entityHitbox = require(entity.Data).CurrentHitbox
					--if entityHitbox then
					--	entityHitbox:AddDuration(.15)
					--end
					--self:AddDuration(.15)
					if game.Players:FindFirstChild(entity.Name) then
						events.OnHit:FireClient(game.Players[entity.Name],.1)
					end
					if player then
						events.OnHit:FireClient(player,.1)
					end
					events.Client:FireAllClients("HyperarmorHit",nil,entity,activeDuration+self._extraDuration)
				end

				if self.OnHit then
					coroutine.wrap(self.OnHit)(entity)
				end
			end
		end
	end)
	if activeDuration then
		coroutine.wrap(function()
			if activeDuration > 0 then
				task.wait(activeDuration)	
				if self._extraDuration > 0 then
					task.wait(self._extraDuration)
				end
			end
			self:Deactivate()
		end)()
	end
end

function Hitbox:Deactivate()
	if not self._isActive then return end
	self._isActive = false
	self._hitTracker = {}
	self._extraDuration = 0
	if self._activeEvent then 
		self._activeEvent:Disconnect()
		self._activeEvent = nil
	end
	if self._displaceEvent then
		self._displaceEvent:Disconnect()
		self._displaceEvent = nil
	end
	if self.OnDeactivate then
		coroutine.wrap(self.OnDeactivate)()
	end
end

function Hitbox:AddDuration(amount)
	self._extraDuration += amount
end

function Hitbox:IsActive()
	return self._isActive
end

function Hitbox:Destroy()
	--if next(self) == nil then return end
	self.Destroyed = true
	self:Deactivate()
	--setmetatable(self, nil)
	--table.clear(self)
	--table.freeze(self)
end

return Hitbox
