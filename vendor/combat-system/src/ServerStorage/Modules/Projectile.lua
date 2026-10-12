local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(startPos)
	return setmetatable({
		_startPosition = startPos,
		Position = startPos,
	},Projectile)
end

function Projectile:Move(equation)
	self._isMoving = true
	self._timePassed = 0
	self._movingEvent = game:GetService("RunService").Heartbeat:Connect(function(dt)
		self._timePassed += dt
		self.Position = equation(self._timePassed)
	end)
end

function Projectile:Activate(condition)
	self._isActive = true
	
end

function Projectile:Deactivate()
	if self._movingEvent then
		self._movingEvent:Disconnect()
	end
end

function Projectile:Destroy()
	
end

return Projectile
