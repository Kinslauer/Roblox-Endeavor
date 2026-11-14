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
local okAnims, Anims = pcall(function()
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Anims"))
end)
-- the Front's soldier body (attribute StockAnimations): Roblox's own idle, walk and run, and no stance animations,
-- because its arm holds were tuned over those and the server poses its crouch and prone
local STOCK = char:GetAttribute("StockAnimations") == true
local OWN = (ok and not STOCK) and Assets.Anims or {}
-- the game's own cycles (tools/anims) by the name shared/Anims knows them by: crouched (the Crouched attribute, C)
-- a low stance and walk, prone (the Stance attribute; hold C) flat on the floor and a crawl
local SHARED = { Idle = "Idle", Walk = "Walk", Jog = "Jog", Run = "Run", CrouchIdle = "Crouch_Idle", CrouchWalk = "Crouch_Walk", ProneIdle = "Prone_Idle", ProneCrawl = "Prone_Crawl" }
for name, own in SHARED do
	if not (OWN[own] and OWN[own] ~= 0 and okAnims) then
		SHARED[name] = nil
	end
end
local PRIORITY = { Idle = Enum.AnimationPriority.Idle, CrouchIdle = Enum.AnimationPriority.Idle, ProneIdle = Enum.AnimationPriority.Idle }

-- Tracks are fetched when played, never all at once. The game's own come from shared/Anims, so the same Walk or
-- Idle is one track for this script, the intro and everything else (Roblox stops playing anything on an Animator
-- past 64 loaded tracks: 2026-11-14, the crash after the shaft); Roblox's stock ones are loaded here on first use.
local stock = {}
local function trackFor(name)
	if name == nil then
		return nil
	end
	local track
	if SHARED[name] then
		track = Anims.Track(char, SHARED[name])
	else
		if stock[name] == nil then
			stock[name] = false
			local id = IDS[name]
			if id then
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local okLoad, t = pcall(function()
					return animator:LoadAnimation(anim)
				end)
				if okLoad and t then
					stock[name] = t
				end
			end
		end
		track = stock[name] or nil
	end
	if track then
		track.Priority = PRIORITY[name] or Enum.AnimationPriority.Movement
	end
	return track
end
local function has(name)
	return SHARED[name] ~= nil or IDS[name] ~= nil
end

local current = nil
local function play(name, fade, speed)
	local track = trackFor(name)
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

-- Studs a second each cycle's planted foot covers at playback speed 1 (`python3 tools/anims/anims.py --speeds`),
-- so the feet keep pace with the ground at any speed; and where one gait hands over to the next.
local PACE = { Walk = 4.7, Jog = 15.1, Run = 25.5, CrouchWalk = 3.0 }
local JOG_FROM, RUN_FROM = 8, 19
local OWN_GAIT = SHARED.Jog ~= nil
local state = "Idle"
local lastSpeed = 0
local backward = false
local function ground(speed)
	lastSpeed = speed
	if state ~= "Running" then
		return
	end
	local dir = if backward then -1 else 1 -- moving backward plays the same cycle in reverse
	if char:GetAttribute("Stance") == "Prone" and has("ProneIdle") then
		if speed < 0.3 then
			play("ProneIdle", 0.25)
		else
			play("ProneCrawl", 0.2, math.clamp(speed / 3, 0.5, 2))
		end
	elseif char:GetAttribute("Crouched") and has("CrouchIdle") then
		if speed < 0.5 then
			play("CrouchIdle", 0.2)
		else
			play("CrouchWalk", 0.15, dir * math.clamp(speed / PACE.CrouchWalk, 0.5, 2.4))
		end
	elseif speed < 0.5 then
		play("Idle", 0.2)
	elseif not OWN_GAIT then
		-- Roblox's own cycles (the Front's soldier, or before the game's are uploaded)
		if speed < 18 then
			play("Walk", 0.15, math.clamp(speed / 7, 0.5, 2.2))
		else
			play("Run", 0.15, math.clamp(speed / 11.5, 0.8, 2.2))
		end
	elseif speed < JOG_FROM then
		play("Walk", 0.2, dir * math.clamp(speed / PACE.Walk, 0.5, 1.8))
	elseif speed < RUN_FROM or backward then
		play("Jog", 0.2, dir * math.clamp(speed / PACE.Jog, 0.6, 1.5))
	else
		play("Run", 0.2, math.clamp(speed / PACE.Run, 0.7, 1.3))
	end
end
-- which way the feet go: backward when the body moves against its facing (aiming or locked on); the hips turn
-- into a sideways move in client/Movement
task.spawn(function()
	local root = char:WaitForChild("HumanoidRootPart", 10)
	while root and char.Parent do
		local move = hum.MoveDirection
		local back = move.Magnitude > 0.1 and root.CFrame.LookVector:Dot(move) < -0.35
		if back ~= backward then
			backward = back
			ground(lastSpeed)
		end
		task.wait(0.1)
	end
end)
hum.Running:Connect(ground)
char:GetAttributeChangedSignal("Crouched"):Connect(function()
	ground(lastSpeed)
end)
char:GetAttributeChangedSignal("Stance"):Connect(function()
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
		-- Back on the ground: pick the track for how it is moving now. (This used to play the standing idle every
		-- time, so landing mid-run slid along in the idle pose and a crouch popped upright until the speed changed.)
		state = "Running"
		local moving = hum.MoveDirection.Magnitude > 0.1
		ground(if moving then math.max(hum.WalkSpeed, 1) else 0)
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
