-- Handling: how a conduit with a gun moves (owner, 2026-11-11: "the game should control like Metal gear 4 ... and
-- incorporate the modern gunplay and mechanics of MGSV"). Ideas only; everything here is ours.
--   * stances: C tap = crouch, hold C = prone, sprint + C = dive, Space = up one, Shift from low = up and run.
--     The server owns the stance (the `Stance` attribute; this never predicts it), Stats owns the speed,
--     character/Animate plays the body, and this drops the camera and does the dive and the prone roll (Q).
--   * the gun (a Sidearm out): hold RMB = aim over the shoulder (closer, narrower, slower); V while aiming = down
--     the sights (first person) and back; R = change the magazine; LMB fires as before.
--   * the wall (Q with a gun out, a wall within reach): back to it; walk along it; hold RMB at its end to step
--     out and aim, let go to come back; Q again, or pushing away from it, leaves.
--   * the arms: one looping pose at a time for what the hands are doing (ready, aim, wall, neck hold, carry).
-- CQC (X) is in client/Stealth.lua with the guards it is done to.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Anims = require(Shared:WaitForChild("Anims"))

local S = Config.Stealth
local ST, AIM, COVER = S.Stance, S.Aim, S.Cover
local player = Players.LocalPlayer

local Handling = {}
Handling.Changed = nil -- set by the main script: called with "Stance" | "Aim" | "Cover" when the camera should be re-placed

local opts = {}
local aiming = false
local sights = false -- first person only because V asked for it (P's own first person is left alone)
local cover -- { normal, at (CFrame), side, out (0..1), wantOut }
local cHeld -- { at, done }
local lastRoll = 0
local push -- { velocity, until, from } a short shove (dive, prone roll)
local arms -- the looping arm pose playing now
local leaveSince

local function parts()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function changed(what)
	if Handling.Changed then
		Handling.Changed(what)
	end
end

function Handling.Stance()
	local char = player.Character
	return char and char:GetAttribute("Stance") or "Stand"
end

function Handling.GunOut()
	local char = player.Character
	local def = char and Weapons.Defs[char:GetAttribute("Weapon") or ""]
	return Weapons.IsGun(def), def
end

function Handling.Aiming()
	return aiming
end

function Handling.Sights()
	return sights
end

function Handling.InCover()
	return cover ~= nil
end

-- The body is placed by the wall, not by the camera, until you lean out of it.
function Handling.HoldsFacing()
	return cover ~= nil and not (aiming and cover.out > 0.5)
end

-- The over-the-shoulder camera while aiming (nil = the weapon's own preset).
function Handling.AimPreset()
	return if aiming and not sights then AIM else nil
end

-- How far the camera comes down for the stance.
function Handling.Drop()
	local stance = Handling.Stance()
	return Vector3.new(0, ST.CameraDrop[stance] or 0, 0)
end

local function busyHands(char)
	return char:GetAttribute("Takedown") or char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or char:GetAttribute("Cutscene")
end

-- ===== stances =====
local function setStance(stance)
	local char = parts()
	if char and Handling.Stance() ~= stance and not busyHands(char) then
		Remotes.Stance:FireServer(stance)
	end
end
Handling.SetStance = setStance

local function shove(root, velocity, seconds)
	push = { velocity = velocity, from = os.clock(), ends = os.clock() + seconds, root = root }
end

local function dive()
	local char, hum, root = parts()
	if not char then
		return
	end
	local dir = hum.MoveDirection
	dir = if dir.Magnitude > 0.1 then dir.Unit else root.CFrame.LookVector
	setStance("Prone")
	shove(root, dir * ST.Dive.Speed, ST.Dive.Seconds)
end

local function proneRoll()
	local char, hum, root = parts()
	if not char or os.clock() - lastRoll < ST.RollCooldown then
		return
	end
	lastRoll = os.clock()
	local right = root.CFrame.RightVector
	local side = if hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection:Dot(right) > 0.3 then 1 else -1
	Anims.Play(char, if side > 0 then "Prone_RollR" else "Prone_RollL", { fade = 0.05 })
	shove(root, right * side * ST.RollSpeed, ST.RollSeconds)
end

-- ===== the gun =====
local function setAim(on)
	local char = parts()
	on = on and char ~= nil and Handling.GunOut() and not busyHands(char)
	if aiming == on then
		return
	end
	aiming = on
	Remotes.Aim:FireServer(on)
	if cover then
		cover.wantOut = on
	end
	if not on and sights then
		sights = false
		if opts.SetFirstPerson then
			opts.SetFirstPerson(false)
		end
	end
	changed("Aim")
end

local function toggleSights()
	if not aiming or not opts.SetFirstPerson then
		return
	end
	if sights then
		sights = false
		opts.SetFirstPerson(false)
	elseif not (opts.FirstPerson and opts.FirstPerson()) then
		sights = true
		opts.SetFirstPerson(true)
	end
	changed("Aim")
end

-- ===== the wall =====
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function wallRay(from, dir, length)
	rayParams.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(from, dir * length, rayParams)
	if not hit or math.abs(hit.Normal.Y) >= 0.3 or not hit.Instance.CanCollide then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return nil -- a guard or a body is not a wall
	end
	return hit
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function leaveCover()
	if not cover then
		return
	end
	cover = nil
	changed("Cover") -- the main script's stance turns the body again
end

local function enterCover()
	local char, hum, root = parts()
	if not char or busyHands(char) or Handling.Stance() == "Prone" then
		return false
	end
	local best
	for i = 0, 7 do
		local a = i * math.pi / 4
		local dir = (root.CFrame * CFrame.Angles(0, a, 0)).LookVector
		local hit = wallRay(root.Position, flat(dir), COVER.Reach)
		if hit and (not best or hit.Distance < best.Distance) then
			best = hit
		end
	end
	if not best then
		return false
	end
	local normal = flat(best.Normal)
	local at = Vector3.new(best.Position.X, root.Position.Y, best.Position.Z) + normal * COVER.Stand
	cover = { normal = normal, at = CFrame.lookAt(at, at + normal), out = 0, wantOut = aiming, side = 1 }
	hum.AutoRotate = false
	root.CFrame = cover.at
	leaveSince = nil
	changed("Cover")
	return true
end

-- Which end of the wall is open within reach of where you stand (1 = your left as you face out, -1 = right, nil).
local function openSide(c)
	local tangent = c.normal:Cross(Vector3.yAxis)
	local cam = workspace.CurrentCamera
	local prefer = if cam and cam.CFrame.RightVector:Dot(tangent) >= 0 then 1 else -1
	for _, side in { prefer, -prefer } do
		local from = c.at.Position + tangent * side * COVER.EdgeProbe
		if not wallRay(from, -c.normal, COVER.Stand + 1.4) and not wallRay(c.at.Position, tangent * side, COVER.EdgeProbe) then
			return side
		end
	end
	return nil
end

local function stepCover(dt)
	local char, hum, root = parts()
	if not char or busyHands(char) or Handling.Stance() == "Prone" or not Handling.GunOut() then
		leaveCover()
		return
	end
	local c = cover
	local tangent = c.normal:Cross(Vector3.yAxis)
	-- leaning out to aim and coming back
	local goal = if c.wantOut then 1 else 0
	if goal == 1 and c.out == 0 then
		c.side = openSide(c) or 0
	end
	if c.out ~= goal then
		c.out = math.clamp(c.out + (if goal > c.out then 1 else -1) * dt / 0.16, 0, 1)
		local pos = c.at.Position + tangent * c.side * COVER.Step * c.out + c.normal * 0.25 * c.out
		pos = Vector3.new(pos.X, root.Position.Y, pos.Z)
		if c.out < 0.5 then
			root.CFrame = CFrame.lookAt(pos, pos + c.normal)
		else
			root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
		end
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		if c.out == 0 or c.out == 1 then
			changed("Cover")
		end
		return
	end
	if c.out == 1 then
		-- out and aiming: held at the corner
		local pos = c.at.Position + tangent * c.side * COVER.Step + c.normal * 0.25
		root.CFrame = CFrame.new(pos.X, root.Position.Y, pos.Z) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		return
	end
	-- on the wall: slide along it, stop at its end, leave by pushing away from it
	local move = hum.MoveDirection
	if move.Magnitude > 0.1 and move:Dot(c.normal) > 0.75 then
		leaveSince = leaveSince or os.clock()
		if os.clock() - leaveSince > 0.25 then
			leaveCover()
			return
		end
	else
		leaveSince = nil
	end
	local hit = wallRay(root.Position, -c.normal, COVER.Stand + 1.4)
	if hit then
		local normal = flat(hit.Normal)
		local at = Vector3.new(hit.Position.X, root.Position.Y, hit.Position.Z) + normal * COVER.Stand
		c.normal = normal
		c.at = CFrame.lookAt(at, at + normal)
		root.CFrame = c.at
	else
		-- past the end: back to the last place the wall was behind you
		root.CFrame = CFrame.lookAt(Vector3.new(c.at.Position.X, root.Position.Y, c.at.Position.Z), Vector3.new(c.at.Position.X, root.Position.Y, c.at.Position.Z) + c.normal)
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
end

-- ===== the arms =====
local function wantArms(char)
	if char:GetAttribute("Takedown") or char:GetAttribute("Cutscene") or char:GetAttribute("Reloading") then
		return nil
	elseif char:GetAttribute("Carrying") then
		return "Carry"
	elseif char:GetAttribute("NeckHold") then
		return "Hold"
	elseif Handling.Stance() == "Prone" or not Handling.GunOut() then
		return nil
	elseif cover and cover.out < 0.5 then
		return "Cover_Idle"
	end
	local _, def = Handling.GunOut()
	local long = def.Family == "Rifle" -- two hands on it
	if aiming then
		return if long then "Aim_Rifle" else "Aim_Pistol"
	end
	return if long then "Rifle_Ready" else "Pistol_Ready"
end

local function driveArms()
	local char = parts()
	local want = char and wantArms(char) or nil
	if want ~= arms then
		local was = arms
		arms = want
		if was and player.Character then
			Anims.Stop(player.Character, was, 0.18)
		end
		if want and char then
			Anims.Play(char, want, { fade = 0.15 })
		end
	end
end

-- The trigger (LMB went down and the first round is away): a gun with Auto keeps firing while it is held.
local trigger = 0
function Handling.Trigger(fire)
	trigger += 1
	local mine = trigger
	local gun, def = Handling.GunOut()
	if not (gun and def.Auto) then
		return
	end
	local every = math.max(0.08, (def.Attacks[1].End or 0.15) + (def.ComboCooldown or 0) + 0.02)
	task.spawn(function()
		while true do
			task.wait(every)
			local still, now = Handling.GunOut()
			if mine ~= trigger or not still or now ~= def or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				return
			end
			fire()
		end
	end)
end

-- ===== keys (the main script forwards them; true = used) =====
function Handling.Began(input, key)
	local char, hum = parts()
	if not char then
		return false
	end
	local gun = Handling.GunOut()
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if gun and not busyHands(char) then
			setAim(true)
			return true -- with a gun out the right button aims; the heavy attack is a melee thing
		end
		return false
	elseif key == Enum.KeyCode.C then
		if busyHands(char) then
			return true
		end
		local running = char:GetAttribute("Sprinting") == true and hum.MoveDirection.Magnitude > 0.1
		if running and Handling.Stance() ~= "Prone" then
			leaveCover()
			dive()
		else
			cHeld = { at = os.clock(), was = Handling.Stance() }
		end
		return true
	elseif key == Enum.KeyCode.Space then
		local stance = Handling.Stance()
		if stance ~= "Stand" then
			setStance(if stance == "Prone" then "Crouch" else "Stand")
			return true
		end
		return false
	elseif key == Enum.KeyCode.LeftShift then
		if Handling.Stance() ~= "Stand" then
			setStance("Stand") -- ...and the main script starts the sprint
		end
		leaveCover()
		return false
	elseif key == Enum.KeyCode.R and gun then
		Remotes.Reload:FireServer()
		return true
	elseif key == Enum.KeyCode.V and gun then
		toggleSights()
		return true
	elseif key == Enum.KeyCode.Q then
		if Handling.Stance() == "Prone" then
			proneRoll()
			return true
		elseif cover then
			leaveCover()
			return true
		elseif gun and enterCover() then
			return true
		end
		return false
	end
	return false
end

function Handling.Ended(input, key)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if aiming then
			setAim(false)
			return true
		end
	elseif key == Enum.KeyCode.C and cHeld then
		local held = cHeld
		cHeld = nil
		if not held.done then
			-- a tap: stand <-> crouch; from prone, up to a crouch
			setStance(if held.was == "Stand" then "Crouch" elseif held.was == "Crouch" then "Stand" else "Crouch")
		end
		return true
	end
	return false
end

function Handling.Init(options)
	opts = options or {}
	RunService.Heartbeat:Connect(function(dt)
		-- C held: prone
		if cHeld and not cHeld.done and os.clock() - cHeld.at >= ST.ProneHold then
			cHeld.done = true
			if cHeld.was ~= "Prone" then
				leaveCover()
				setStance("Prone")
			end
		end
		-- a shove dies away over its time
		if push then
			local now = os.clock()
			local root = push.root
			if now >= push.ends or not root.Parent then
				push = nil
			else
				local k = 1 - (now - push.from) / (push.ends - push.from)
				local v = push.velocity * (0.35 + 0.65 * k)
				root.AssemblyLinearVelocity = Vector3.new(v.X, root.AssemblyLinearVelocity.Y, v.Z)
			end
		end
		local char = parts()
		if aiming and (not char or not Handling.GunOut() or busyHands(char)) then
			setAim(false)
		end
		if cover then
			stepCover(dt)
		end
		driveArms()
	end)
	local lastStance = "Stand"
	local function bind(char)
		aiming, sights, cover, cHeld, push, arms = false, false, nil, nil, nil, nil
		lastStance = "Stand"
		char:GetAttributeChangedSignal("Stance"):Connect(function()
			local stance = Handling.Stance()
			if stance ~= lastStance then
				lastStance = stance
				changed("Stance")
			end
		end)
		char:GetAttributeChangedSignal("Weapon"):Connect(function()
			if not Handling.GunOut() then
				setAim(false)
				leaveCover()
			end
		end)
	end
	player.CharacterAdded:Connect(bind)
	if player.Character then
		bind(player.Character)
	end
	-- the magazine change and the empty click, on anyone
	Remotes.CombatEvent.OnClientEvent:Connect(function(kind, char, seconds)
		if typeof(char) ~= "Instance" then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		if kind == "Reload" then
			seconds = if type(seconds) == "number" and seconds > 0.1 then seconds else 1.5
			local def = Weapons.Defs[char:GetAttribute("Weapon") or ""]
			if def and def.Family == "Rifle" then
				Anims.Play(char, "Reload_Rifle", { fade = 0.1, speed = 2.2 / seconds })
			else
				Anims.Play(char, "Reload_Pistol", { fade = 0.1, speed = 1.5 / seconds })
			end
			Sounds.Play("DryClick", root, { Volume = 0.5, Pitch = 0.8 })
			task.delay(seconds * 0.66, function()
				if root and root.Parent then
					Sounds.Play("Rack", root, { Volume = 0.7 })
				end
			end)
		elseif kind == "DryFire" then
			Sounds.Play("DryClick", root)
		end
	end)
	_ = UserInputService
end

return Handling
