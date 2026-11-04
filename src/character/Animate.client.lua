-- Animate: the character's everyday animations (idle, walk, run, jump, fall, climb, swim), Roblox's own R15
-- set. Named "Animate" so Roblox does not add its default script beside it. Works on the Conduit body
-- (Motor6D joints) and on any R15 avatar. client/Movement plays the action animations (roll, dash, double
-- jump) above these at Action priority; the client's swing poses offset the joints on top of both.
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local animator = hum:WaitForChild("Animator", 10) or Instance.new("Animator", hum)

local IDS = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
	Swim = "rbxassetid://507784897",
	SwimIdle = "rbxassetid://507785072",
}
local PRIORITY = { Idle = Enum.AnimationPriority.Idle }

local tracks = {}
for name, id in IDS do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Priority = PRIORITY[name] or Enum.AnimationPriority.Movement
		tracks[name] = track
	end
end

local current = nil
local function play(name, fade, speed)
	local track = tracks[name]
	if current ~= track then
		if current then
			current:Stop(fade or 0.2)
		end
		current = track
		if track then
			track:Play(fade or 0.2)
		end
	end
	if track and speed then
		track:AdjustSpeed(speed)
	end
end

local RUN_FROM = 18 -- studs/s: above this the run plays instead of the walk
local state = "Idle"
hum.Running:Connect(function(speed)
	if state ~= "Running" then
		return
	end
	if speed < 0.5 then
		play("Idle", 0.2)
	elseif speed < RUN_FROM then
		play("Walk", 0.15, math.clamp(speed / 14, 0.5, 1.6))
	else
		play("Run", 0.15, math.clamp(speed / 22, 0.7, 1.6))
	end
end)
hum.Climbing:Connect(function(speed)
	play("Climb", 0.1, math.clamp(speed / 5, 0.2, 2))
end)
hum.Swimming:Connect(function(speed)
	play(if speed > 1 then "Swim" else "SwimIdle", 0.3)
end)
hum.StateChanged:Connect(function(_, new)
	if new == Enum.HumanoidStateType.Jumping then
		state = "Air"
		play("Jump", 0.1)
	elseif new == Enum.HumanoidStateType.Freefall then
		state = "Air"
		play("Fall", 0.3)
	elseif new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.RunningNoPhysics then
		state = "Running"
		play("Idle", 0.15)
	elseif new == Enum.HumanoidStateType.Climbing then
		state = "Climbing"
	elseif new == Enum.HumanoidStateType.Swimming then
		state = "Swimming"
	elseif new == Enum.HumanoidStateType.Dead then
		play(nil)
	end
end)
state = "Running"
play("Idle", 0)
