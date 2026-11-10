-- Animate: the character's everyday animations: the game's own idle/walk/run (tools/anims) and Roblox's R15
-- jump, fall, climb and swim. Named "Animate" so Roblox does not add its default script beside it. Works on the Conduit body
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
-- the Conduit's own fighting-stance idle, walk and run (tools/anims, Assets.Anims) replace Roblox's when uploaded
local ok, Assets = pcall(function()
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Assets"))
end)
local OWN = ok and Assets.Anims or {}
for _, name in { "Idle", "Walk", "Run" } do
	if OWN[name] and OWN[name] ~= 0 then
		IDS[name] = "rbxassetid://" .. tostring(OWN[name])
	end
end
-- crouched (the Crouched attribute, C): a low stance and a low walk
for name, own in { CrouchIdle = "Crouch_Idle", CrouchWalk = "Crouch_Walk" } do
	if OWN[own] and OWN[own] ~= 0 then
		IDS[name] = "rbxassetid://" .. tostring(OWN[own])
	end
end
local PRIORITY = { Idle = Enum.AnimationPriority.Idle, CrouchIdle = Enum.AnimationPriority.Idle }

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
local lastSpeed = 0
local function ground(speed)
	lastSpeed = speed
	if state ~= "Running" then
		return
	end
	if char:GetAttribute("Crouched") and tracks.CrouchIdle then
		if speed < 0.5 then
			play("CrouchIdle", 0.2)
		else
			play("CrouchWalk", 0.15, math.clamp(speed / 6, 0.5, 2))
		end
	elseif speed < 0.5 then
		play("Idle", 0.2)
	elseif speed < RUN_FROM then
		play("Walk", 0.15, math.clamp(speed / 7, 0.5, 2.2)) -- the cycle covers ~4.5 studs/s at speed 1
	else
		play("Run", 0.15, math.clamp(speed / 11.5, 0.8, 2.2)) -- ~11.5 studs/s at speed 1
	end
end
hum.Running:Connect(ground)
char:GetAttributeChangedSignal("Crouched"):Connect(function()
	ground(lastSpeed)
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
