-- Stealth: hiding by light level, noise, guards that notice by degrees, and takedowns.
--
-- A stealth level is a folder a player has been entered into (Stealth.Enter). Inside it:
--   * Exposure (character attribute, 0..1): the level's ambient + every lit "StealthLight" with a clear line to you.
--     Lights can be shot out (Combat.Shot) or cut at a "Breaker" (their Circuit attribute).
--   * Noise: sprinting and walking are heard, crouching is silent; shots, glass and a whistle (B) pull guards over.
--   * Guards (Stealth.SpawnGuard: an NPC whose fight only starts once it is Alert) patrol or stand a post. Each keeps
--     an awareness 0..1 of each intruder: it fills while it can see you (slower in the dark and far away), drains when
--     it cannot. Suspicious -> it looks, then walks over. Full -> Alert: it calls the others and the NPC fight starts.
--     Lose it for a while and it searches, then goes back to its round. A guard that sees a downed one raises the rest.
--   * Takedowns (Remote "Takedown", X): from behind, dropped on from above, or with the room (a TakedownSpot beside
--     the guard: fuse box, live rail, ledge). Rules in shared/Stealth.TakedownKind. A downed guard stays down.
-- Round 4 of docs/Reference-Picks-Plan.md (ideas from Metal Gear, nothing copied):
--   * The second before he shouts: a guard who makes you freezes "Spotted" for Config.Stealth.Reflex seconds; put
--     him down in it and nobody hears. Every real alarm in a level (attr Alarms) makes its guards see further and
--     sooner (Adapt); past CheckHiding they open lockers near where they search.
--   * Sleeping darts (.22 dart: Combat.Slept), a thrown bolt (ThrowBolt), lockers to hide in (HidingSpot/Hide),
--     clothes (character attrs Conceal, Disguise from server/Kit), questioning a guard in a neck hold (Question),
--     guards asleep at their posts (Shift / SetAsleep, state "Asleep").
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rules = require(Shared.Stealth)
local Weapons = require(Shared.Weapons)
local Combat = require(script.Parent.Combat)
local NPCs = require(script.Parent.NPCs)
local Loot = require(script.Parent.Loot)
local Items = require(Shared.Items)
local Net = require(script.Parent.Common.Net)
local Joints = require(Shared.Joints)

local S = Config.Stealth
local T = S.Takedown

local Stealth = {}
Stealth.TakenDown = Instance.new("BindableEvent") -- (player, guardModel, kind)
Stealth.Alerted = Instance.new("BindableEvent") -- (player, guardModel)
Stealth.LightBroken = Instance.new("BindableEvent") -- (part, player?)

local guards = {} -- model -> guard
local levels = {} -- player -> level folder
local lastWhistle = {}
local noiseNow = {} -- player -> radius of the noise they are making this tick
local holds = {} -- player -> the guard held by the neck
local carries = {} -- player -> the downed guard on the shoulder
local hiding = {} -- player -> the locker they are in
local Q = S.Cqc

-- ===== lights =====
local FACES = {
	[Enum.NormalId.Front] = function(cf) return cf.LookVector end,
	[Enum.NormalId.Back] = function(cf) return -cf.LookVector end,
	[Enum.NormalId.Top] = function(cf) return cf.UpVector end,
	[Enum.NormalId.Bottom] = function(cf) return -cf.UpVector end,
	[Enum.NormalId.Right] = function(cf) return cf.RightVector end,
	[Enum.NormalId.Left] = function(cf) return -cf.RightVector end,
}
local function lightFrame(light)
	local holder = light.Parent
	local cf = if holder:IsA("Attachment") then (holder.WorldCFrame or holder.Parent.CFrame) else holder.CFrame
	local look = cf.LookVector
	if light:IsA("SpotLight") or light:IsA("SurfaceLight") then
		local f = FACES[light.Face]
		if f then
			look = f(cf)
		end
	end
	return cf.Position, look
end

local function isLit(part)
	return not part:GetAttribute("Broken") and part:GetAttribute("Powered") ~= false
end

local function applyLight(part)
	local on = isLit(part)
	for _, d in part:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = on
		end
	end
	if part:GetAttribute("Glow") ~= false then
		part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		part.Transparency = if on then 0 else 0.35
	end
	part:SetAttribute("Lit", on)
end
Stealth.ApplyLight = applyLight

function Stealth.BreakLight(part, player)
	if part:GetAttribute("Broken") or part:GetAttribute("Unbreakable") then
		return false
	end
	part:SetAttribute("Broken", true)
	applyLight(part)
	Remotes.World:FireAllClients("LightBreak", part.Position)
	Stealth.Noise(part.Position, S.Noise.Glass, "Glass", player)
	Stealth.LightBroken:Fire(part, player)
	return true
end

-- Any other light in the world can be shot out too (Andy, 2026-11-14: "the shots should break light sources like
-- splinter cell"): a round that hits a small part holding a light, or the fixture round it (a part of the same model
-- within Config.Stealth.ShootOut.Reach of the hit), puts it out with glass and a pop. Landmarks people steer by (the
-- district pylons, the obelisk, building signs: bigger than MaxSize), bodies' own glow and anything Unbreakable stay lit. The
-- hour puts every one back (Stealth.RestoreFixtures from Cycle.Run).
local shotOut = {} -- part -> { material, transparency, lights = { light = enabled } }
local function holdsLight(part)
	for _, c in part:GetChildren() do
		if c:IsA("Light") and c.Enabled ~= false then
			return true
		end
	end
	return false
end
local function fixtureFor(inst, position)
	local SO = S.ShootOut
	local function ok(part)
		if not (part:IsA("BasePart") and holdsLight(part)) then
			return false
		end
		if part:GetAttribute("Unbreakable") or shotOut[part] or (part.Transparency or 0) > 0.9 then
			return false
		end
		local size = part.Size
		if math.max(size.X, size.Y, size.Z) > SO.MaxSize then
			return false -- the district pylons, the obelisk, the building signs: what people steer by
		end
		-- never a body's own glow (a visor, goggles, an implant), on the living, a corpse or a statue
		local a = part.Parent
		while a and a ~= workspace do
			if a:IsA("Model") and (a:FindFirstChildOfClass("Humanoid") or a:FindFirstChildOfClass("AnimationController") or CollectionService:HasTag(a, "Skin") or a:GetAttribute("Skinned")) then
				return false
			end
			a = a.Parent
		end
		return true
	end
	if inst:IsA("BasePart") and ok(inst) then
		return inst
	end
	-- the housing: a lit part of the same model right beside the hit
	local holder = inst:FindFirstAncestorOfClass("Model") or inst.Parent
	if not holder or holder == workspace then
		return nil
	end
	local best, bestD = nil, SO.Reach
	for _, d in holder:GetDescendants() do
		if d ~= inst and d:IsA("BasePart") and ok(d) then
			local rel = d.CFrame:PointToObjectSpace(position)
			local h = d.Size / 2
			local out = Vector3.new(math.max(math.abs(rel.X) - h.X, 0), math.max(math.abs(rel.Y) - h.Y, 0), math.max(math.abs(rel.Z) - h.Z, 0)).Magnitude
			if out < bestD then
				best, bestD = d, out
			end
		end
	end
	return best
end
function Stealth.ShootOut(inst, position, player)
	if typeof(inst) ~= "Instance" or typeof(position) ~= "Vector3" then
		return false
	end
	local part = fixtureFor(inst, position)
	if not part then
		return false
	end
	local keep = { material = part.Material, transparency = part.Transparency, color = part.Color, lights = {} }
	for _, c in part:GetChildren() do
		if c:IsA("Light") then
			keep.lights[c] = c.Enabled ~= false
			c.Enabled = false
		end
	end
	shotOut[part] = keep
	if part.Material == Enum.Material.Neon then
		part.Material, part.Transparency = Enum.Material.Glass, math.max(part.Transparency, 0.35)
		part.Color = part.Color:Lerp(Color3.fromRGB(40, 40, 44), 0.6)
	end
	part:SetAttribute("ShotOut", true)
	Remotes.World:FireAllClients("LightBreak", part.Position)
	Stealth.Noise(part.Position, S.Noise.Glass, "Glass", player)
	Stealth.LightBroken:Fire(part, player)
	return true
end
function Stealth.RestoreFixtures()
	for part, keep in shotOut do
		if part.Parent then
			part.Material, part.Transparency, part.Color = keep.material, keep.transparency, keep.color
			for light, enabled in keep.lights do
				if light.Parent then
					light.Enabled = enabled
				end
			end
			part:SetAttribute("ShotOut", nil)
		end
	end
	table.clear(shotOut)
end

-- Cuts or restores every light on a breaker's circuit. Returns the new state.
function Stealth.SetCircuit(level, circuit, powered)
	for _, part in CollectionService:GetTagged("StealthLight") do
		if part:GetAttribute("Circuit") == circuit and (not level or part:IsDescendantOf(level)) then
			part:SetAttribute("Powered", powered)
			applyLight(part)
		end
	end
	return powered
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearLine(from, to, ignore)
	rayParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(from, to - from, rayParams) == nil
end

-- How lit `point` is inside `level` (0..1). `ignore` = instances the light passes through (the character).
function Stealth.ExposureAt(level, point, ignore)
	local total = (level and level:GetAttribute("Ambient")) or S.Ambient
	for _, part in CollectionService:GetTagged("StealthLight") do
		if part:GetAttribute("Lit") ~= false and (not level or part:IsDescendantOf(level)) and isLit(part) then
			for _, light in part:GetDescendants() do
				if light:IsA("Light") then
					local origin, look = lightFrame(light)
					local gain = Rules.LightAt(light, origin, look, point)
					if gain > 0.01 then
						local skip = table.clone(ignore or {})
						table.insert(skip, part)
						if clearLine(origin, point, skip) then
							total += gain
						end
					end
				end
			end
		end
	end
	return math.clamp(total, 0, 1)
end

-- ===== levels =====
function Stealth.Enter(player, level)
	levels[player] = level
	player:SetAttribute("Stealth", true)
end

function Stealth.Leave(player)
	levels[player] = nil
	noiseNow[player] = nil
	player:SetAttribute("Stealth", nil)
	if hiding[player] then
		Stealth.Unhide(player)
	end
	if holds[player] then
		Stealth.Release(player, "Break")
	end
	if carries[player] then
		Stealth.DropBody(player)
	end
	local char = player.Character
	if char then
		char:SetAttribute("Exposure", nil)
		if char:GetAttribute("Crouched") then
			Stealth.SetCrouch(player, false)
		end
	end
	for _, g in guards do
		g.aware[player] = nil
		if g.target == player then
			g.target = nil
		end
	end
end

function Stealth.LevelOf(player)
	return levels[player]
end

-- ===== guards =====
local function setState(g, state)
	if g.state == state then
		return
	end
	if g.state == "Asleep" then
		pcall(Joints.Pose, g.model, "Neck", CFrame.new(), 0.4) -- his head comes up
	elseif state == "Asleep" then
		pcall(Joints.Pose, g.model, "Neck", CFrame.Angles(math.rad(-38), 0, math.rad(8)), 1.2)
	end
	if state == "Patrol" then
		g.reflexDone = nil -- back on his round: the next time he makes someone he freezes first again
	end
	g.state = state
	g.model:SetAttribute("StealthState", state)
	g.stateAt = os.clock()
end

-- How many times this level has gone to a real alarm (Config.Stealth.Adapt.Max at most).
local function alarms(level)
	return (level and level:GetAttribute("Alarms")) or 0
end
Stealth.Alarms = alarms

-- The nearest locker to `position` in `level` (within `reach`), nil if none.
local function lockerNear(level, position, reach)
	local best, bestD = nil, reach
	for _, spot in CollectionService:GetTagged("HidingSpot") do
		if spot.Parent and (not level or spot:IsDescendantOf(level)) then
			local d = (spot.Position - position).Magnitude
			if d < bestD then
				best, bestD = spot, d
			end
		end
	end
	return best
end

local function face(g, position, alpha)
	local root = g.root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude < 0.2 or root.Anchored then
		return
	end
	local want = CFrame.lookAt(root.Position, flat)
	root.CFrame = root.CFrame:Lerp(want, alpha or 0.35)
end

-- Guards walk a planned route (PathfindingService), not a straight line: a straight line to a cut fuse box runs
-- into the turnstiles, a wall or the stair well (Andy, 2026-11-12: "the guard got stuck on the way up"). The plan
-- is made off the brain's loop (ComputeAsync yields); until it arrives, and if none is found, he walks straight.
local function planRoute(g, goal)
	local nav = g.nav
	nav.goal, nav.at, nav.busy = goal, os.clock(), true
	task.spawn(function()
		local path
		local ok = pcall(function()
			path = PathfindingService:CreatePath({ AgentRadius = S.Path.Radius, AgentHeight = S.Path.Height, AgentCanJump = false, WaypointSpacing = S.Path.Spacing })
			path:ComputeAsync(g.root.Position, goal)
		end)
		nav.busy = false
		if nav.goal ~= goal then
			return
		end
		if ok and path and path.Status == Enum.PathStatus.Success then
			nav.points, nav.index = path:GetWaypoints(), 2
		else
			nav.points = nil
		end
	end)
end

local function walk(g, position, speed)
	g.hum.WalkSpeed = speed
	local nav, now, at = g.nav, os.clock(), g.root.Position
	if not nav.walking then
		nav.walking, nav.movedAt, nav.lastPos = true, now, at
	elseif (at - nav.lastPos).Magnitude > 0.6 then
		nav.movedAt, nav.lastPos = now, at
	end
	local stuck = now - nav.movedAt > S.Path.Stuck
	if not nav.busy and (not nav.goal or (nav.goal - position).Magnitude > S.Path.Replan or now - nav.at > S.Path.Refresh or (stuck and now - nav.at > S.Path.Stuck)) then
		if stuck then
			g.hum.Jump = true -- a lip or a body in the way
			nav.movedAt = now
		end
		planRoute(g, position)
	end
	local points = nav.points
	local wp = points and points[nav.index]
	while wp and ((wp.Position - at) * Vector3.new(1, 0, 1)).Magnitude < S.Path.Reach do
		nav.index += 1
		wp = points[nav.index]
	end
	if wp then
		g.hum:MoveTo(wp.Position)
	else
		g.hum:MoveTo(Vector3.new(position.X, at.Y, position.Z))
	end
end

local function halt(g)
	g.nav.walking = false
	g.hum:MoveTo(g.root.Position)
end

-- How far a guard would have to walk to `goal` (nil when no route is found). Yields.
local function routeLength(g, goal)
	local length
	pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = S.Path.Radius, AgentHeight = S.Path.Height, AgentCanJump = false })
		path:ComputeAsync(g.root.Position, goal)
		if path.Status == Enum.PathStatus.Success then
			local points = path:GetWaypoints()
			length = 0
			for i = 2, #points do
				length += (points[i].Position - points[i - 1].Position).Magnitude
			end
		end
	end)
	return length
end

local function investigate(g, position, seconds)
	if g.state == "Alert" or g.state == "Down" or g.state == "Spotted" then
		return
	end
	g.spot = position
	g.searchUntil = os.clock() + (seconds or S.SearchSeconds)
	g.lookAt = nil
	-- a level that has been on alarm before: he opens the locker near where he is looking
	g.checkSpot = if alarms(g.level) >= S.Adapt.CheckHiding then lockerNear(g.level, position, 16) else nil
	setState(g, "Search")
end

local function callOthers(g, position)
	-- by voice to the guards near, by radio to every guard in the level (Config.Guns.RadioRadius) while it works
	local reach = if g.model:GetAttribute("Radio") then math.max(S.CallRadius, Config.Guns.RadioRadius) else S.CallRadius
	for _, other in guards do
		if other ~= g and other.level == g.level and other.state ~= "Down" and other.state ~= "Alert" and other.state ~= "Spotted"
			and (other.root.Position - g.root.Position).Magnitude <= reach then
			investigate(other, position)
		end
	end
end

-- `instant`: he felt it (a wound, a round on his plate, a blow, breaking a hold, a locker opened on you): no
-- second to freeze in. Otherwise the first time he makes you he stops dead for Config.Stealth.Reflex seconds
-- ("Spotted"; the intruder's screen gets World "Reflex"); think() raises the alarm when it runs out.
local function alert(g, player, instant)
	if g.state == "Down" then
		return
	end
	if not instant and S.Reflex > 0 and g.state ~= "Alert" and g.state ~= "Spotted" and not g.reflexDone then
		g.target = player
		g.reflexUntil = os.clock() + S.Reflex
		g.aware[player] = 1
		halt(g)
		setState(g, "Spotted")
		Remotes.World:FireClient(player, "Reflex", g.model, S.Reflex)
		return
	end
	if g.state == "Spotted" and not instant then
		return -- think() ends the second
	end
	local first = g.state ~= "Alert"
	g.target = player
	g.lastSeenAt = os.clock()
	g.hum.WalkSpeed = g.speed
	g.reflexDone = true
	setState(g, "Alert")
	if first then
		NPCs.Bark(g.model, "Alert")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			callOthers(g, root.Position)
		end
		if g.level then
			g.level:SetAttribute("Alarms", math.min(S.Adapt.Max, alarms(g.level) + 1)) -- the level learns
		end
		Stealth.Alerted:Fire(player, g.model)
	end
end

-- Something was heard at `position`. kind "Step" only feeds awareness of `player`; anything else sends the guards
-- that heard it over to look.
function Stealth.Noise(position, radius, kind, player)
	if radius <= 0 then
		return
	end
	local level = player and levels[player]
	radius *= require(script.Parent.Sky).NoiseMult(position) -- round 6: rain covers noise in the open
	pcall(function()
		require(script.Parent.Runs).Heard(position, kind) -- a copy run below pauses on any noise
	end)
	for _, g in guards do
		if g.state ~= "Down" and g.state ~= "Alert" and g.state ~= "Spotted" and (not level or g.level == level) then
			local d = (g.root.Position - position).Magnitude
			local reach = radius
			if g.state == "Asleep" then
				reach *= S.Shift.WakeNoise -- asleep at his post: only a loud thing close by wakes him
				if kind == "Step" then
					reach = 0
				end
			end
			if d <= reach and not clearLine(position + Vector3.new(0, 1, 0), g.root.Position + Vector3.new(0, 1, 0), { g.model, player and player.Character }) then
				reach *= 0.55 -- walls muffle it
			end
			if d <= reach and reach > 0 then
				if g.state == "Asleep" then
					g.wary = true -- he comes round with a start
					setState(g, "Patrol")
				end
				if kind == "Step" and player then
					g.aware[player] = math.min(0.95, (g.aware[player] or 0) + S.StepNoiseAwareness * S.Tick)
					g.seen[player] = position
				else
					investigate(g, position)
				end
			end
		end
	end
end

local function sees(g, char, exposure, crouched, prone)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return false, 0
	end
	local player = Players:GetPlayerFromCharacter(char)
	local spot = player and hiding[player]
	if spot then
		-- in a locker: only a guard who is searching, in a level that has learned to look, and comes right up to it
		if g.state == "Search" and alarms(g.level) >= S.Adapt.CheckHiding and (spot.Position - g.root.Position).Magnitude <= S.Hide.Find then
			return true, 1, spot
		end
		return false, 0
	end
	local eyes = g.root.Position + Vector3.new(0, 2, 0)
	-- what he would see of you: the chest standing, lower crouched, a shape on the floor prone (the root itself
	-- stays at standing height), so low cover really hides a low body
	local to = root.Position + Vector3.new(0, if prone then -1.9 elseif crouched then -0.4 else 0.8, 0)
	local offset = to - eyes
	local d = offset.Magnitude
	if d < S.Bump then
		return true, 1
	end
	if g.state == "Asleep" then
		return false, 0
	end
	local searching = g.state == "Search" or g.state == "Alert"
	local fov = if searching then S.SearchFOV else S.SightFOV
	if g.root.CFrame.LookVector:Dot(offset.Unit) < math.cos(math.rad(fov / 2)) then
		return false, 0
	end
	-- the torch: whatever stands in its beam is lit
	if g.torch and g.torch.Enabled then
		local origin, look = lightFrame(g.torch)
		if Rules.LightAt(g.torch, origin, look, to) > 0.05 then
			exposure = math.max(exposure, S.FlashlightExposure)
		end
	end
	local range = Rules.SightRange(exposure, crouched, searching, prone) * (1 + S.Adapt.Sight * alarms(g.level))
	if d > range then
		return false, 0
	end
	if not clearLine(eyes, to, { g.model, char }) then
		return false, 0
	end
	return true, math.sqrt(1 - d / range)
end

local function seesBody(g)
	for _, other in guards do
		if other.state == "Down" and not other.found and other.level == g.level then
			local offset = other.root.Position - g.root.Position
			local d = offset.Magnitude
			if d < S.SightRange * 0.5 and d > 0.1 and g.root.CFrame.LookVector:Dot(offset.Unit) > math.cos(math.rad(S.SightFOV / 2)) then
				local exposure = Stealth.ExposureAt(g.level, other.root.Position, { other.model, g.model })
				if d < Rules.SightRange(exposure, true, false) and clearLine(g.root.Position + Vector3.new(0, 2, 0), other.root.Position + Vector3.new(0, 0.5, 0), { g.model, other.model }) then
					return other
				end
			end
		end
	end
	return nil
end

-- Is `char` pointing a gun at this guard from close by? (The aim stance turns the body to the camera, so the
-- body's facing is the gun's.)
local function gunOn(g, char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local to = (g.root.Position - root.Position) * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if to.Magnitude > S.HoldUp.Range or to.Magnitude < 0.1 or look.Magnitude < 0.1 or math.abs(g.root.Position.Y - root.Position.Y) > 6 then
		return false
	end
	if look.Unit:Dot(to.Unit) < math.cos(math.rad(S.HoldUp.Cone)) then
		return false
	end
	return clearLine(root.Position + Vector3.new(0, 1.5, 0), g.root.Position + Vector3.new(0, 1.5, 0), { char, g.model })
end

local function patrol(g, now)
	local points = g.patrol
	if points and #points > 0 then
		if now < g.waitUntil then
			if g.lookAt then
				face(g, g.lookAt, 0.15)
			end
			return
		end
		local goal = points[g.index]
		local flat = (goal - g.root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 2 then
			g.index = g.index % #points + 1
			g.waitUntil = now + g.wait
			g.lookAt = g.looks and g.looks[g.index] or nil
			halt(g)
		else
			walk(g, goal, S.PatrolSpeed)
		end
	elseif g.post then
		local flat = (g.post.Position - g.root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 2.5 then
			walk(g, g.post.Position, S.PatrolSpeed)
		else
			halt(g)
			face(g, g.post.Position + g.post.LookVector * 10, S.PostTurn * 3)
		end
	end
end

local fallAsleep -- below

local function think(g, now, dt)
	if g.sleepAt and now >= g.sleepAt and g.state ~= "Down" and not g.busy and g.model.Parent and g.hum.Health > 0 then
		fallAsleep(g, now)
		return
	end
	if g.state == "Down" or g.busy or not g.model.Parent or g.hum.Health <= 0 then
		return
	end
	if g.torch then
		g.torch.Enabled = true
	end
	-- sight
	local best, bestA = nil, 0
	for player, level in levels do
		local char = player.Character
		if level == g.level and char then
			local visible, clarity, found = sees(g, char, char:GetAttribute("Exposure") or 1, char:GetAttribute("Crouched") == true, char:GetAttribute("Stance") == "Prone")
			if found then
				-- he opens the locker on you
				Stealth.Unhide(player, true)
				g.aware[player] = 1
				g.seen[player] = found.Position
				alert(g, player, true)
				return
			end
			local a = g.aware[player] or 0
			if visible then
				local rate = S.FillRate * clarity * (if g.state == "Search" or g.wary then S.SearchFill else 1) * (1 + S.Adapt.Fill * alarms(g.level))
				-- in their colours: from beyond Disguise.Close he takes you for one of his own, until he is on his toes
				if char:GetAttribute("Disguise") and g.state ~= "Search" and not g.wary
					and (char.HumanoidRootPart.Position - g.root.Position).Magnitude > S.Disguise.Close then
					rate *= S.Disguise.Fill
				end
				a = math.min(1, a + rate * dt)
				g.seen[player] = char.HumanoidRootPart.Position
				if g.state == "Alert" and g.target == player then
					g.lastSeenAt = now
				end
			elseif g.state ~= "Alert" then
				a = math.max(0, a - S.Decay * dt)
			end
			g.aware[player] = a
			if a > bestA then
				best, bestA = player, a
			end
		end
	end

	-- The second before he shouts: he stares at you; when it runs out the alarm goes up.
	if g.state == "Spotted" then
		local target = g.target
		local troot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		local thum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not (troot and thum and thum.Health > 0 and levels[target] == g.level) then
			g.target = nil
			setState(g, "Patrol")
			return
		end
		halt(g)
		face(g, troot.Position, 0.5)
		if now >= (g.reflexUntil or 0) then
			g.reflexDone = true
			alert(g, target, true)
		end
		return
	end
	-- Asleep at his post: he sees only what bumps into him; that wakes him, wary.
	if g.state == "Asleep" then
		halt(g)
		if best and bestA >= S.SuspectAt then
			g.wary = true
			setState(g, "Patrol")
		else
			return
		end
	end

	-- Held up: a gun on him, up close, before he has made anyone. He stops with his hands up and stays so for
	-- HoldUp.Keep seconds after the gun leaves him; then he goes looking for whoever it was.
	if g.state ~= "Alert" then
		local holder
		for player, level in levels do
			local char = player.Character
			if level == g.level and char and char:GetAttribute("Aiming") and (g.aware[player] or 0) < 1 and gunOn(g, char) then
				holder = player
				break
			end
		end
		if holder then
			g.gunOn = (g.gunOn or 0) + dt
			if g.state == "HeldUp" or g.gunOn >= S.HoldUp.Grace then
				g.heldUpBy, g.heldUntil = holder, now + S.HoldUp.Keep
				if g.state ~= "HeldUp" then
					halt(g)
					setState(g, "HeldUp")
				end
			end
		else
			g.gunOn = 0
		end
		if g.state == "HeldUp" then
			for player, a in g.aware do
				g.aware[player] = math.min(a, 0.9) -- frozen: he does not finish making you while the gun is on him
			end
			halt(g)
			if now > g.heldUntil then
				local by = g.heldUpBy
				local broot = by and by.Character and by.Character:FindFirstChild("HumanoidRootPart")
				g.heldUpBy, g.wary = nil, true
				investigate(g, if broot then broot.Position else g.root.Position)
			end
			return
		end
	end

	if g.state == "Alert" then
		local target = g.target
		local char = target and target.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (target and levels[target] == g.level and hum and hum.Health > 0) then
			g.target = nil
			setState(g, "Patrol")
		elseif now - g.lastSeenAt > S.AlertLose then
			g.aware[target] = 0.5
			g.target = nil
			g.wary = true
			investigate(g, g.seen[target] or g.root.Position)
		end
		return -- the NPC fight has the body
	end

	if best and bestA >= 1 then
		alert(g, best)
		return
	end
	if S.BodyAlarm then
		local body = seesBody(g)
		if body then
			body.found = true
			g.wary = true
			NPCs.Bark(g.model, "Alert")
			investigate(g, body.root.Position)
			callOthers(g, body.root.Position)
			return
		end
	end

	if g.state == "Search" then
		local flat = (g.spot - g.root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 3 and g.checkSpot then
			-- then the locker beside it
			local locker = g.checkSpot
			g.checkSpot = nil
			if locker.Parent then
				g.spot = (locker.CFrame * CFrame.new(0, 0, -2.4)).Position
				g.stateAt = now
				g.searchUntil = math.max(g.searchUntil, now + 6)
				flat = (g.spot - g.root.Position) * Vector3.new(1, 0, 1)
			end
		end
		if flat.Magnitude > 3 and now - g.stateAt < (if g.fix then S.Path.FixSeconds - S.FixDelay - 2 else 10) then
			walk(g, g.spot, S.SearchSpeed)
		else
			halt(g)
			-- look around where the sound was
			local a = (now - g.stateAt) * 1.3
			face(g, g.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 8, 0.12)
			if g.fix and g.fix.Parent and now - g.stateAt > S.FixDelay and (g.fix.Position - g.root.Position).Magnitude < 8 then
				Stealth.SetCircuit(g.level, g.fix:GetAttribute("Circuit"), true)
				g.fix:SetAttribute("Cut", false)
				g.fix = nil
				g.searchUntil = now + 2
			end
		end
		if now > g.searchUntil then
			g.fix = nil
			setState(g, "Patrol")
		end
		return
	end

	if best and bestA >= S.SuspectAt then
		setState(g, "Suspicious")
		local spot = g.seen[best]
		if spot then
			face(g, spot, 0.3)
			if bestA >= S.SuspectWalk and (spot - g.root.Position).Magnitude > 4 then
				walk(g, spot, S.SuspectSpeed)
			else
				halt(g)
			end
		end
		return
	end
	if g.state == "Suspicious" then
		setState(g, "Patrol")
	end
	patrol(g, now)
end

-- opts: Level (folder), Patrol = { Vector3 }, Looks = { [i] = Vector3 to face while waiting at point i }, Wait (s),
--       Post (CFrame to stand at and face along), Torch (bool), Type (NPC type, default "Sentry"), Parent
function Stealth.SpawnGuard(position, opts)
	opts = opts or {}
	local g = { loot = opts.Loot, aware = {}, seen = {}, state = "Patrol", stateAt = os.clock(), level = opts.Level, patrol = opts.Patrol, looks = opts.Looks,
		wait = opts.Wait or 3, post = opts.Post, index = 1, waitUntil = 0, searchUntil = 0, lastSeenAt = 0, nav = { at = 0, movedAt = 0 } }
	local model = NPCs.Spawn(opts.Type or "Sentry", position, {
		Parent = opts.Parent or opts.Level,
		Filter = function(player)
			return g.state == "Alert" and g.target == player and not hiding[player]
		end,
		Idle = function()
			return true -- this module walks the body while it is not fighting
		end,
		NoLeash = true,
		Quiet = true,
	})
	g.model = model
	g.root = model:WaitForChild("HumanoidRootPart")
	g.hum = model:FindFirstChildOfClass("Humanoid")
	g.speed = g.hum.WalkSpeed
	g.hum.WalkSpeed = S.PatrolSpeed
	if opts.Post then
		model:PivotTo(CFrame.lookAt(position, position + opts.Post.LookVector))
	end
	if opts.Torch then
		local holder = model:FindFirstChild("UpperTorso") or g.root
		local att = Instance.new("Attachment")
		att.Name = "Torch"
		att.Position = Vector3.new(0.6, 0.4, -0.6)
		att.Parent = holder
		local torch = Instance.new("SpotLight")
		torch.Name = "TorchLight"
		torch.Range, torch.Angle, torch.Brightness = 42, 46, 2.2
		torch.Color = Color3.fromRGB(255, 244, 214)
		torch.Shadows = true
		torch.Enabled = true
		torch.Parent = att
		g.torch = torch
	end
	model:SetAttribute("Guard", true)
	model:SetAttribute("StealthState", "Patrol")
	model:SetAttribute("Radio", opts.Radio ~= false) -- a radio on the shoulder: an alert reaches the whole level (an EMP round kills it)
	CollectionService:AddTag(model, "Guard")
	guards[model] = g
	model.Destroying:Connect(function()
		guards[model] = nil
	end)
	-- a wound he survives tells him exactly what is going on
	local lastHealth = g.hum.Health
	g.hum.HealthChanged:Connect(function(health)
		local hurt = health < lastHealth - 0.5
		lastHealth = health
		if hurt and health > 0 and g.state ~= "Down" and g.state ~= "Alert" and not g.busy then
			local _, by = Combat.GetKiller(model)
			if by and levels[by] == g.level then
				g.aware[by] = 1
				alert(g, by, true)
			end
		end
	end)
	g.hum.Died:Connect(function()
		g.state = "Dead"
		guards[model] = nil
	end)
	return model, g
end

-- Puts a guard straight on Alert against a player (round 6: the shelter runs send overseers in).
function Stealth.Alarm(model, player)
	local g = guards[model]
	if g and g.state ~= "Down" then
		alert(g, player, true)
		return true
	end
	return false
end

function Stealth.StateOf(model)
	local g = guards[model]
	return g and g.state, g
end

function Stealth.Guards(level)
	local list = {}
	for model, g in guards do
		if not level or g.level == level then
			table.insert(list, model)
		end
	end
	return list
end

-- Guards that are still up go back to their rounds and forget what they saw (a checkpoint restart).
function Stealth.Reset(level)
	if level then
		level:SetAttribute("Alarms", nil) -- a fresh start forgets the alarms too
	end
	for player, spot in hiding do
		if not level or levels[player] == level or spot:IsDescendantOf(level) then
			Stealth.Unhide(player)
		end
	end
	for _, g in guards do
		if g.level == level and g.state ~= "Down" then
			g.aware, g.seen, g.target, g.wary, g.fix = {}, {}, nil, false, nil
			g.sleepAt, g.reflexDone, g.checkSpot = nil, nil, nil
			g.hum.Health = g.hum.MaxHealth
			setState(g, "Patrol")
			local home = (g.patrol and g.patrol[1]) or (g.post and g.post.Position)
			if home then
				g.index, g.waitUntil = 1, 0
				g.model:PivotTo(CFrame.new(home.X, g.root.Position.Y, home.Z) * (if g.post then g.post.Rotation else CFrame.new()))
			end
		end
	end
end

local function layDown(g, at, yaw)
	local model, root = g.model, g.root
	g.hum.WalkSpeed = 0
	g.hum.AutoRotate = false
	g.hum.PlatformStand = true
	local ground = at
	local skip = { model }
	for _, other in guards do
		table.insert(skip, other.model) -- a body is laid on the floor, not on another body
	end
	for player in levels do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), rayParams)
	if hit then
		ground = hit.Position
	end
	if not root.Anchored or not g.standHeight then
		g.standHeight = g.standHeight or math.clamp(root.Position.Y - ground.Y, 1.5, 5) -- to stand him up again (a throw wears off)
	end
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	if not g.collide then
		g.collide = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				g.collide[p] = p.CanCollide
				p.CanCollide = false
			end
		end
	end
	if g.torch then
		g.torch.Enabled = false
	end
	model:SetAttribute("Downed", true)
	CollectionService:RemoveTag(model, "NPC") -- no nameplate, no group AI around a body
	CollectionService:AddTag(model, "DownedGuard")
end

-- A thrown guard comes round: on his feet where he lay, looking for whoever did it.
local function standUp(g)
	local model, root = g.model, g.root
	local at = root.Position
	local look = root.CFrame.UpVector * Vector3.new(1, 0, 1) -- lying face down, his head points the way he faced
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local stand = Vector3.new(at.X, at.Y - 0.7 + (g.standHeight or 3), at.Z)
	model:PivotTo(CFrame.lookAt(stand, stand + look))
	for p, was in g.collide or {} do
		if p.Parent then
			p.CanCollide = was
		end
	end
	g.collide = nil
	root.Anchored = false
	g.hum.PlatformStand = false
	g.hum.AutoRotate = true
	g.hum.WalkSpeed = S.SearchSpeed
	g.wakeAt, g.found, g.busy = nil, false, false
	model:SetAttribute("Downed", nil)
	model:SetAttribute("Asleep", nil)
	CollectionService:RemoveTag(model, "DownedGuard")
	CollectionService:AddTag(model, "NPC")
	g.aware = {}
	g.wary = true
	setState(g, "Patrol")
	investigate(g, at)
end

-- Puts a guard down without the ceremony (tests, scripted moments).
function Stealth.Down(model, at)
	local g = guards[model]
	if not g or g.state == "Down" then
		return false
	end
	setState(g, "Down")
	g.target = nil
	layDown(g, at or g.root.Position, 0)
	return true
end

-- ===== takedowns =====
-- `forced` = the choke that ends a neck hold: he is already in your arms, so it is the rear takedown whatever
-- the room or his state.
function Stealth.Takedown(player, model, forced)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and root and hum and hum.Health > 0) or char:GetAttribute("Takedown") then
		return false
	end
	local kind, spot
	if forced then
		kind = "Rear"
	else
		if g.busy or not Combat.CanAct(char) or char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or ((g.aware[player] or 0) >= 1 and g.state ~= "Spotted") then
			return false
		end
		kind, spot = Rules.TakedownKind(root.CFrame, g.root.CFrame, g.state)
		if not kind then
			return false
		end
		if kind ~= "Drop" and not clearLine(root.Position, g.root.Position, { char, g.model }) then
			return false -- through a wall
		end
	end
	g.busy = true
	g.target = nil
	halt(g)
	local seconds = T.Seconds[kind] or 1.6
	local groot = g.root
	local gpos = groot.Position
	-- Where the body ends up, and which way its head points. The victim animations end face down with the hips
	-- T.Fall studs ahead of where the guard stood (tools/anims `fallen`), so the root is laid flat exactly there
	-- and nothing jumps when the animation hands over.
	local glook = groot.CFrame.LookVector
	local fall = (T.Fall and T.Fall[kind]) or 0
	local endAt = gpos + Vector3.new(glook.X, 0, glook.Z) * fall
	local yaw = math.atan2(-glook.X, -glook.Z)
	Combat.GrantIFrames(char, seconds + T.IFrames)
	Combat.SetBusy(char, seconds)
	char:SetAttribute("Takedown", kind)
	if char:GetAttribute("Crouched") then
		Stealth.SetCrouch(player, false)
	end
	groot.Anchored = true
	if kind == "Rear" then
		-- step in behind it
		local behind = groot.CFrame * CFrame.new(0, 0, T.RearDistance or 1.5)
		root.Anchored = true
		char:PivotTo(CFrame.new(behind.Position.X, root.Position.Y, behind.Position.Z) * groot.CFrame.Rotation)
	elseif kind == "Drop" then
		-- land on it
		root.Anchored = true
		char:PivotTo(CFrame.new(gpos.X, gpos.Y + 0.5, gpos.Z) * root.CFrame.Rotation)
	else
		-- the room: the guard goes into the spot, you stand a step off it
		local to = (spot.Position - gpos) * Vector3.new(1, 0, 1)
		local dir = if to.Magnitude > 0.1 then to.Unit else groot.CFrame.LookVector
		local stand = spot:GetAttribute("Stand")
		local victimAt = if typeof(stand) == "Vector3" then stand else Vector3.new(spot.Position.X, gpos.Y, spot.Position.Z) - dir * 1.6
		groot.CFrame = CFrame.lookAt(Vector3.new(victimAt.X, gpos.Y, victimAt.Z), Vector3.new(victimAt.X, gpos.Y, victimAt.Z) + dir)
		local me = victimAt - dir * 2.2
		root.Anchored = true
		char:PivotTo(CFrame.lookAt(Vector3.new(me.X, root.Position.Y, me.Z), Vector3.new(victimAt.X, root.Position.Y, victimAt.Z)))
		local dropTo = spot:GetAttribute("DropTo")
		endAt = if typeof(dropTo) == "Vector3" then dropTo else Vector3.new(victimAt.X, gpos.Y, victimAt.Z) + dir * fall
		yaw = math.atan2(-dir.X, -dir.Z)
		if spot:GetAttribute("Once") then
			spot:SetAttribute("Used", true)
		end
	end
	Remotes.World:FireAllClients("Takedown", kind, char, g.model, spot, seconds)
	task.delay(seconds, function()
		if root.Parent then
			root.Anchored = false
		end
		if char.Parent then
			char:SetAttribute("Takedown", nil)
		end
		g.busy = false
		if g.model.Parent and g.hum.Health > 0 then
			setState(g, "Down")
			layDown(g, endAt, yaw)
			if kind == "Panel" or kind == "Rail" then
				Remotes.World:FireAllClients("Sparks", spot and spot.Position or endAt)
			end
			Stealth.Noise(gpos, T.Noise[kind] or 0, "Takedown", player)
			Stealth.TakenDown:Fire(player, g.model, kind)
		end
	end)
	return true, kind
end

-- ===== CQC: the throw, the neck hold, bodies =====
local function yawOf(dir)
	return math.atan2(-dir.X, -dir.Z)
end

local function handsFree(char)
	return not (char:GetAttribute("Takedown") or char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or char:GetAttribute("Holding"))
end

-- X tapped in front of or beside a guard (any state but down), or G with him in a neck hold (`fromHold`): he goes
-- over and down hard. Not a kill and not quiet: he is out for Cqc.Throw.Down seconds, then gets up and searches.
function Stealth.Throw(player, model, fromHold, aim)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and root and hum and hum.Health > 0) or g.state == "Down" or char:GetAttribute("Takedown") then
		return false
	end
	local groot = g.root
	local gpos = groot.Position
	local to = (root.Position - gpos) * Vector3.new(1, 0, 1)
	if not fromHold then
		if g.busy or not handsFree(char) or not Combat.CanAct(char) or to.Magnitude > Q.Throw.Reach or math.abs(root.Position.Y - gpos.Y) > 4
			or not clearLine(root.Position, gpos, { char, g.model }) then
			return false
		end
	end
	g.busy = true
	g.target = nil
	halt(g)
	local seconds = Q.Throw.Seconds
	local side = if fromHold then 0 else Q.Throw.Side -- thrown, he lands past your left (his right); shoved, straight ahead
	local dir -- the way he falls
	groot.Anchored = true
	root.Anchored = true
	if fromHold then
		-- shoved forward out of the hold: you stay where you are
		dir = groot.CFrame.LookVector * Vector3.new(1, 0, 1)
		dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	else
		-- face to face: he is turned to you and comes over your hip
		dir = if to.Magnitude > 0.1 then to.Unit else groot.CFrame.LookVector
		groot.CFrame = CFrame.lookAt(gpos, gpos + dir)
		local me = gpos + dir * Q.Throw.Stand
		char:PivotTo(CFrame.lookAt(Vector3.new(me.X, root.Position.Y, me.Z), Vector3.new(gpos.X, root.Position.Y, gpos.Z)))
	end
	Combat.GrantIFrames(char, seconds + T.IFrames)
	Combat.SetBusy(char, seconds)
	-- the way he flies once he is let go: where the thrower looks, else straight away from the thrower
	local fly = if fromHold then dir else -dir
	if typeof(aim) == "Vector3" then
		local flat = aim * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 and flat.Magnitude == flat.Magnitude then
			fly = flat.Unit
		end
	end
	local flight = { at = gpos, done = false }
	task.delay(seconds * Q.Throw.Release, function()
		local ok, err = pcall(function()
			local skip = { char, g.model }
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = skip
			local pos = groot.Position
			local vel = fly * Q.Throw.Speed + Vector3.new(0, Q.Throw.Lift, 0)
			local gravity = Vector3.new(0, -workspace.Gravity, 0)
			local under = workspace:Raycast(pos, Vector3.new(0, -30, 0), params)
			local floorY = if under then under.Position.Y else pos.Y - 3
			local t = 0
			while t < Q.Throw.MaxSeconds and g.model.Parent and groot.Parent do
				local dt = RunService.Heartbeat:Wait()
				dt = math.clamp(dt, 1 / 240, 1 / 20)
				t += dt
				local nextVel = vel + gravity * dt
				local move = (vel + nextVel) / 2 * dt
				local hit = workspace:Spherecast(pos, Q.Throw.Radius, move, params)
				if hit then
					pos += move.Unit * math.max(hit.Distance - 0.05, 0)
					local other
					for m, og in guards do
						if og ~= g and hit.Instance:IsDescendantOf(m) then
							other = og
							break
						end
					end
					local flatSpeed = (vel * Vector3.new(1, 0, 1)).Magnitude
					if other then
						-- into another guard: he goes down with him
						flight.hit = "Guard"
						if other.state ~= "Down" and not other.busy and other.hum.Health > 0 then
							halt(other)
							other.target = nil
							setState(other, "Down")
							layDown(other, other.root.Position, yawOf(fly))
							other.wakeAt = os.clock() + Q.Throw.Down
							Stealth.TakenDown:Fire(player, other.model, "Thrown")
						end
						Remotes.World:FireAllClients("Slam", pos, hit.Normal, other.model)
						break
					elseif hit.Normal.Y > 0.6 then
						break -- the floor
					else
						if flatSpeed >= Q.Throw.Slam.Speed then
							flight.hit = "Wall"
							flight.normal = hit.Normal
							Remotes.World:FireAllClients("Slam", hit.Position, hit.Normal, g.model)
						end
						break -- a wall: he drops at its foot
					end
				end
				pos += move
				vel = nextVel
				if pos.Y - Q.Throw.Radius <= floorY and vel.Y < 0 then
					break -- down to the level he was thrown from
				end
				groot.CFrame = groot.CFrame.Rotation + pos
			end
			flight.at = pos
		end)
		if not ok then
			warn("[Stealth] throw flight:", err)
		end
		flight.done = true
	end)
	local kind = if fromHold then "Shove" else "Throw"
	char:SetAttribute("Takedown", kind)
	if char:GetAttribute("Crouched") then
		Stealth.SetCrouch(player, false)
	end
	Remotes.World:FireAllClients("Takedown", kind, char, g.model, nil, seconds)
	task.delay(seconds, function()
		if root.Parent then
			root.Anchored = false
		end
		if char.Parent then
			char:SetAttribute("Takedown", nil)
		end
		-- he is still in the air: the thrower is free, he lands when the flight ends
		local waited = 0
		while not flight.done and waited < Q.Throw.MaxSeconds + 0.5 do
			waited += task.wait()
		end
		if g.model.Parent and g.hum.Health > 0 and flight.hit == "Wall" then
			g.hum:TakeDamage(Q.Throw.Slam.Damage) -- still busy: a wound here does not wake him
		end
		g.busy = false
		if g.model.Parent and g.hum.Health > 0 then
			setState(g, "Down")
			local slam = flight.hit == "Wall"
			local at = flight.at
			if slam and flight.normal then
				at += flight.normal * Vector3.new(1, 0, 1) * 1.2 -- at the wall's foot, not in it
			end
			layDown(g, at, yawOf(fly))
			g.wakeAt = os.clock() + Q.Throw.Down * (if slam then Q.Throw.Slam.DownMult else 1)
			Stealth.Noise(at, if slam then Q.Throw.Slam.Noise else Q.Throw.Noise, "Takedown", player)
			Stealth.TakenDown:Fire(player, g.model, kind)
		end
	end)
	return true, kind
end

local function setCollide(g, on)
	if on then
		for p, was in g.heldCollide or {} do
			if p.Parent then
				p.CanCollide = was
			end
		end
		g.heldCollide = nil
	elseif not g.heldCollide then
		g.heldCollide = {}
		for _, p in g.model:GetDescendants() do
			if p:IsA("BasePart") then
				g.heldCollide[p] = p.CanCollide
				p.CanCollide = false
			end
		end
	end
end

-- X held behind a guard that has not made you: your arm round his neck. He walks where you walk (slowly) for
-- Cqc.Hold.Seconds; X chokes him out, G throws him down, and if you run out of time he breaks free and has you.
function Stealth.Grab(player, model)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and root and hum and hum.Health > 0) or g.busy or g.state == "Down" or g.state == "Alert" or holds[player]
		or not handsFree(char) or not Combat.CanAct(char) or (g.aware[player] or 0) >= 1 then
		return false
	end
	if not Rules.Behind(root.CFrame, g.root.CFrame) or not clearLine(root.Position, g.root.Position, { char, g.model }) then
		return false
	end
	g.busy = true
	g.target = nil
	g.grabUntil = os.clock() + Q.Hold.Seconds
	halt(g)
	g.root.Anchored = true
	setCollide(g, false)
	setState(g, "Held")
	holds[player] = g
	if char:GetAttribute("Crouched") then
		Stealth.SetCrouch(player, false)
	end
	if char:GetAttribute("Sprinting") then
		Combat.SetSprint(player, false)
	end
	-- square behind him from the first frame
	local behind = g.root.CFrame * CFrame.new(0, 0, Q.Hold.Gap)
	char:PivotTo(CFrame.new(behind.Position.X, root.Position.Y, behind.Position.Z) * g.root.CFrame.Rotation)
	char:SetAttribute("NeckHold", true)
	require(script.Parent.Stats).Apply(player)
	Remotes.World:FireAllClients("Hold", char, g.model, true)
	return true
end

-- how: "Choke" (he stays down) | "Throw" (down for a while) | "Break" (he is loose and has you)
function Stealth.Release(player, how, aim)
	local g = holds[player]
	if not g then
		return false
	end
	holds[player] = nil
	local char = player.Character
	if char then
		char:SetAttribute("NeckHold", nil)
		if char.Parent then
			require(script.Parent.Stats).Apply(player)
		end
	end
	setCollide(g, true)
	g.busy = false
	Remotes.World:FireAllClients("Hold", char, g.model, false)
	if not g.model.Parent or g.hum.Health <= 0 then
		return true
	end
	setState(g, "Patrol")
	local done = false
	if how == "Choke" then
		done = Stealth.Takedown(player, g.model, true)
	elseif how == "Throw" then
		done = Stealth.Throw(player, g.model, true, aim)
	end
	if not done then
		g.root.Anchored = false
		alert(g, player, true)
	end
	return true
end

-- X held over a body: you crouch and take it by the collar (owner, 2026-11-13: "instead of a carry the player
-- should grab just like snake in metal gear, and loot them from there or drag them along"). It stays on the floor and
-- trails behind your hands as you move (slow, no sprint, no standing up); X goes through its pockets from the grab,
-- G lets go where it lies.
function Stealth.Carry(player, model)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and root and hum and hum.Health > 0) or g.state ~= "Down" or g.carriedBy or carries[player] or not handsFree(char)
		or (g.root.Position - root.Position).Magnitude > Q.Carry.Reach then
		return false
	end
	if char:GetAttribute("Sprinting") then
		Combat.SetSprint(player, false)
	end
	Stealth.SetStance(player, "Crouch")
	g.carriedBy = player
	carries[player] = g
	-- where his feet are now: the body trails from the hands toward them
	local up = g.root.CFrame.UpVector * Vector3.new(1, 0, 1)
	up = if up.Magnitude > 0.1 then up.Unit else Vector3.new(0, 0, -1)
	g.dragTail = g.root.Position - up * (Q.Carry.Length - Q.Carry.Collar)
	char:SetAttribute("Carrying", true)
	require(script.Parent.Stats).Apply(player)
	Remotes.World:FireAllClients("Carry", char, g.model, true)
	return true
end

-- X tapped over a body: go through its pockets (the same search-and-take grid as any container). Every guard
-- carries something (Items.LootTables.Sentry), in the station too, so the loop is learned on the first one.
function Stealth.Search(player, model)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local mine = g and g.carriedBy == player -- from the grab: the hands are on him already
	if not (g and root) or g.state ~= "Down" or (g.carriedBy and not mine) or not (mine or handsFree(char)) or (g.root.Position - root.Position).Magnitude > Q.Carry.Reach + 1 then
		return false
	end
	if not g.pockets then
		g.pockets = true
		Loot.Attach(g.root, Items.Roll(g.loot or "Sentry"), { Label = "Sentry", CanTake = function()
			return g.state == "Down"
		end })
	end
	if g.root:GetAttribute("Looted") then
		g.model:SetAttribute("Looted", true)
		return false
	end
	return Loot.Open(player, g.root)
end

function Stealth.DropBody(player)
	local g = carries[player]
	if not g then
		return false
	end
	carries[player] = nil
	g.carriedBy = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if char then
		char:SetAttribute("Carrying", nil)
		if char.Parent then
			require(script.Parent.Stats).Apply(player)
		end
	end
	g.dragTail = nil
	if g.model.Parent then
		-- let go: he stays where he was dragged to
		local up = g.root.CFrame.UpVector * Vector3.new(1, 0, 1)
		layDown(g, g.root.Position - Vector3.new(0, 0.7, 0), yawOf(if up.Magnitude > 0.1 then up.Unit else Vector3.new(0, 0, -1)))
		if g.wakeAt then
			g.wakeAt = math.max(g.wakeAt, os.clock() + 4)
		end
	end
	Remotes.World:FireAllClients("Carry", char, g.model, false)
	return true
end

function Stealth.Holding(player)
	return holds[player] and holds[player].model
end

function Stealth.Carrying(player)
	return carries[player] and carries[player].model
end

-- Each frame: the held guard walks with you, the carried one rides your shoulder; a throw wears off.
local function followHands(now)
	for player, g in holds do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum and hum.Health > 0 and g.model.Parent and g.hum.Health > 0) or now > g.grabUntil then
			Stealth.Release(player, "Break")
		elseif not char:GetAttribute("Takedown") then
			local front = root.CFrame * CFrame.new(0, 0, -Q.Hold.Gap)
			g.root.CFrame = CFrame.new(front.Position.X, g.root.Position.Y, front.Position.Z) * root.CFrame.Rotation
		end
	end
	for player, g in carries do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum and hum.Health > 0 and g.model.Parent) then
			Stealth.DropBody(player)
		else
			-- the collar is at your hands, on the floor in front of you; the feet trail where they were, pulled along
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
			local hands = root.Position + look * Q.Carry.Ahead
			local tail = g.dragTail or (hands + look * Q.Carry.Length)
			local toHands = (hands - tail) * Vector3.new(1, 0, 1)
			toHands = if toHands.Magnitude > 0.05 then toHands.Unit else -look
			tail = hands - toHands * Q.Carry.Length
			local at = hands - toHands * Q.Carry.Collar
			rayParams.FilterDescendantsInstances = { g.model, char }
			local hit = workspace:Raycast(Vector3.new(at.X, root.Position.Y + 1, at.Z), Vector3.new(0, -12, 0), rayParams)
			local floor = if hit then hit.Position.Y else g.root.Position.Y - 0.7
			g.dragTail = Vector3.new(tail.X, floor, tail.Z)
			g.model:PivotTo(CFrame.new(at.X, floor + 0.7, at.Z) * CFrame.Angles(0, yawOf(toHands), 0) * CFrame.Angles(-math.pi / 2, 0, 0))
		end
	end
	for _, g in guards do
		if g.state == "Down" and g.wakeAt and now >= g.wakeAt and not g.carriedBy and not g.busy and g.hum.Health > 0 then
			standUp(g)
		end
	end
end

-- ===== round 4: sleep, lockers, a thrown bolt, questions, shifts =====
-- A sleeping dart has worked: he goes down where he stands and sleeps Config.Stealth.Sleep.Seconds, then gets up
-- and searches like a thrown guard.
fallAsleep = function(g, now)
	g.sleepAt = nil
	g.target = nil
	halt(g)
	setState(g, "Down")
	local look = g.root.CFrame.LookVector
	layDown(g, g.root.Position + Vector3.new(look.X, 0, look.Z) * 1.2, yawOf(Vector3.new(look.X, 0, look.Z)))
	g.wakeAt = now + S.Sleep.Seconds
	g.model:SetAttribute("Asleep", true)
	Stealth.Noise(g.root.Position, 8, "Takedown")
end

-- Combat.Slept: a dart in him. In the face he drops at once; elsewhere he feels the sting, goes to look where it
-- came from and drops after Sleep.Delay seconds.
function Stealth.Dart(char, model, zone)
	local g = guards[model]
	if not g or g.state == "Down" or g.sleepAt then
		return false
	end
	local now = os.clock()
	if zone == "Head" then
		if g.busy then
			g.sleepAt = now
		else
			fallAsleep(g, now)
		end
		return true
	end
	g.sleepAt = now + S.Sleep.Delay
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and g.state ~= "Alert" and g.state ~= "Spotted" then
		g.wary = true
		investigate(g, root.Position, S.Sleep.Delay + 2)
	end
	return true
end

-- A locker (or anything with this shape): a body you can stand inside with its door facing cf.LookVector.
-- `cf` sits on the floor. Returns the body part (tag "HidingSpot").
function Stealth.HidingSpot(cf, parent, name)
	local model = Instance.new("Model")
	model.Name = name or "Locker"
	local steel, dark = Color3.fromRGB(78, 84, 88), Color3.fromRGB(24, 26, 28)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.8, 7.2, 2.4)
	body.CFrame = cf * CFrame.new(0, 3.6, 0)
	body.Anchored, body.CanCollide = true, false -- you stand inside it; the walls below keep others out
	body.Transparency = 1
	body.Parent = model
	local function slab(nm, size, at, color)
		local p = Instance.new("Part")
		p.Name = nm
		p.Size = size
		p.CFrame = body.CFrame * at
		p.Anchored = true
		p.Material = Enum.Material.DiamondPlate
		p.Color = color or steel
		p.Parent = model
		return p
	end
	slab("Back", Vector3.new(2.8, 7.2, 0.15), CFrame.new(0, 0, 1.13))
	slab("SideL", Vector3.new(0.15, 7.2, 2.4), CFrame.new(-1.33, 0, 0))
	slab("SideR", Vector3.new(0.15, 7.2, 2.4), CFrame.new(1.33, 0, 0))
	slab("Top", Vector3.new(2.8, 0.15, 2.4), CFrame.new(0, 3.53, 0))
	local door = slab("Door", Vector3.new(2.5, 6.9, 0.1), CFrame.new(0, 0, -1.15), steel:Lerp(Color3.new(1, 1, 1), 0.06))
	door.Material = Enum.Material.Metal
	for i = 1, 5 do -- the slats you look out through
		local slat = slab("Slat", Vector3.new(1.6, 0.12, 0.05), CFrame.new(0, 2.6 - i * 0.22, -1.22), dark)
		slat.CanCollide = false
	end
	CollectionService:AddTag(body, "HidingSpot")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText, prompt.ObjectText = "Hide", ""
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = S.Hide.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		if hiding[player] == body then
			Stealth.Unhide(player)
		else
			Stealth.Hide(player, body)
		end
	end)
	model.PrimaryPart = body
	model.Parent = parent or workspace
	return body
end

function Stealth.Hide(player, spot)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0 and spot and spot.Parent) or hiding[player] or spot:GetAttribute("Occupant")
		or not handsFree(char) or not Combat.CanAct(char) or (spot.Position - root.Position).Magnitude > S.Hide.Reach + 2 then
		return false
	end
	hiding[player] = spot
	spot:SetAttribute("Occupant", player.UserId)
	if char:GetAttribute("Stance") and char:GetAttribute("Stance") ~= "Stand" then
		Stealth.SetStance(player, "Stand")
	end
	if char:GetAttribute("Sprinting") then
		Combat.SetSprint(player, false)
	end
	if char:GetAttribute("Aiming") then
		Stealth.SetAim(player, false)
	end
	local floor = spot.Position.Y - spot.Size.Y / 2
	local at = Vector3.new(spot.Position.X, floor + hum.HipHeight + root.Size.Y / 2, spot.Position.Z)
	root.Anchored = true
	char:PivotTo(CFrame.lookAt(at, at + spot.CFrame.LookVector))
	char:SetAttribute("Hidden", true)
	char:SetAttribute("Exposure", 0)
	local prompt = spot:FindFirstChild("HidePrompt")
	if prompt then
		prompt.ActionText = "Leave"
	end
	Remotes.World:FireAllClients("Hide", char, spot, true)
	return true
end

-- Out of the locker, onto the floor in front of its door. `found` = a guard pulled the door open.
function Stealth.Unhide(player, found)
	local spot = hiding[player]
	if not spot then
		return false
	end
	hiding[player] = nil
	spot:SetAttribute("Occupant", nil)
	local prompt = spot:FindFirstChild("HidePrompt")
	if prompt then
		prompt.ActionText = "Hide"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if char and root and char.Parent then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local floor = spot.Position.Y - spot.Size.Y / 2
		local out = (spot.CFrame * CFrame.new(0, 0, -2.6)).Position
		local at = Vector3.new(out.X, floor + (if hum then hum.HipHeight else 2) + root.Size.Y / 2, out.Z)
		char:PivotTo(CFrame.lookAt(at, at + spot.CFrame.LookVector))
		root.Anchored = false
		char:SetAttribute("Hidden", nil)
		Remotes.World:FireAllClients("Hide", char, spot, false, found == true)
	end
	return true
end

function Stealth.Hidden(player)
	return hiding[player]
end

-- Key 3 (Inventory.Use of a "Bolt"): thrown along `dir`; where it comes down it clatters and every guard who
-- hears it goes to look. The arc is flown by raycasts, so it stops on what it meets.
function Stealth.ThrowBolt(player, dir)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) or hiding[player] or not handsFree(char) or not Combat.CanAct(char) then
		return false
	end
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 or dir.Magnitude ~= dir.Magnitude then
		dir = root.CFrame.LookVector
	end
	dir = dir.Unit
	local pos = root.Position + Vector3.new(0, 1.5, 0) + dir * 1.2
	local vel = (dir + Vector3.new(0, 0.3, 0)).Unit * S.Bolt.Speed
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local step, t, landing = 1 / 30, 0, nil
	while t < S.Bolt.Seconds do
		local nextVel = vel + gravity * step
		local move = (vel + nextVel) / 2 * step
		local hit = workspace:Raycast(pos, move, params)
		if hit then
			landing = hit.Position + hit.Normal * 0.15
			break
		end
		pos += move
		vel = nextVel
		t += step
	end
	landing = landing or pos
	local bolt = Instance.new("Part")
	bolt.Name = "ThrownBolt"
	bolt.Size = Vector3.new(0.25, 0.25, 0.6)
	bolt.Material = Enum.Material.Metal
	bolt.Color = Color3.fromRGB(96, 92, 86)
	bolt.Anchored, bolt.CanCollide, bolt.CanQuery = true, false, false
	bolt.CFrame = CFrame.new(landing) * CFrame.Angles(0, math.random() * 6.28, math.pi / 2)
	bolt.Parent = workspace
	game:GetService("Debris"):AddItem(bolt, S.Bolt.Lifetime)
	Remotes.World:FireAllClients("Clatter", landing, root.Position + Vector3.new(0, 1.5, 0), math.min(t, S.Bolt.Seconds))
	Stealth.Noise(landing, S.Bolt.Noise, "Clatter", player)
	return true, landing
end

-- E with a guard in a neck hold: he talks, once. How many of his crew are still on their feet here (their
-- outlines show for Question.Seconds on the asker's screen) and where the nearest stores are.
local COUNT = { [0] = "Nobody else. Just me.", "One more on shift.", "Two more on shift.", "Three more on shift.", "Four more on shift." }
function Stealth.Question(player)
	local g = holds[player]
	if not g or g.questioned then
		return false
	end
	g.questioned = true
	g.grabUntil += 1.5 -- he takes his time
	local crew = {}
	for model, other in guards do
		if other ~= g and other.level == g.level and other.state ~= "Down" and other.state ~= "Dead" and other.hum.Health > 0 then
			table.insert(crew, model)
		end
	end
	local crate, best = nil, S.Question.Reach
	if g.level then
		for _, d in g.level:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("ContainerKey") and not d:GetAttribute("Looted") and d.Name ~= "HumanoidRootPart" then
				local dist = (d.Position - g.root.Position).Magnitude
				if dist < best then
					crate, best = d, dist
				end
			end
		end
	end
	local line = COUNT[#crew] or (#crew .. " more on shift.")
	if crate then
		line ..= " The stores are that way."
	end
	Remotes.World:FireClient(player, "Question", g.model, line, crew, crate, S.Question.Seconds)
	return true, #crew, crate
end

-- A guard nodding off at his post (or woken). Only one standing about: not a body, not mid-fight.
function Stealth.SetAsleep(model, on)
	local g = guards[model]
	if not g or g.busy or g.state == "Down" or g.state == "Alert" or g.state == "Spotted" then
		return false
	end
	if on then
		halt(g)
		setState(g, "Asleep")
	elseif g.state == "Asleep" then
		setState(g, "Patrol")
	end
	return true
end

-- A new shift in `level`: each guard on his round is asleep with chance `share` (default Shift.SleepShare).
function Stealth.Shift(level, share, rng)
	rng = rng or Random.new()
	share = share or S.Shift.SleepShare
	local asleep = 0
	for model, g in guards do
		if g.level == level and (g.state == "Patrol" or g.state == "Asleep") then
			local on = rng:NextNumber() < share
			Stealth.SetAsleep(model, on)
			if on then
				asleep += 1
			end
		end
	end
	return asleep
end

-- ===== stance, aim, whistle =====
-- "Stand" | "Crouch" | "Prone". The character carries `Stance` and `Crouched` (true for both low ones: slower,
-- quieter, no jump); Stats sets the speed, the guards read Prone for how little of you there is to see.
local STANCES = { Stand = true, Crouch = true, Prone = true }
function Stealth.SetStance(player, stance)
	local char = player.Character
	if not char or not STANCES[stance] then
		return
	end
	if stance ~= "Stand" and (char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or char:GetAttribute("Takedown")) then
		return
	end
	if stance ~= "Crouch" and char:GetAttribute("Carrying") then
		return -- a body is dragged from a crouch: let go of it first
	end
	if (char:GetAttribute("Stance") or "Stand") ~= stance then
		char:SetAttribute("Stance", stance)
		char:SetAttribute("Crouched", stance ~= "Stand")
		if stance ~= "Stand" and char:GetAttribute("Sprinting") then
			Combat.SetSprint(player, false)
		end
		require(script.Parent.Stats).Apply(player)
	end
end

function Stealth.SetCrouch(player, on)
	Stealth.SetStance(player, if on == true then "Crouch" else "Stand")
end

-- Holding RMB with a gun out: slower, and a guard who finds it on him freezes (think, "Held up").
function Stealth.SetAim(player, on)
	local char = player.Character
	if not char then
		return
	end
	local def = Weapons.Defs[char:GetAttribute("Weapon") or ""]
	on = on == true and Weapons.IsGun(def) and not char:GetAttribute("NeckHold") and not char:GetAttribute("Carrying")
	if (char:GetAttribute("Aiming") == true) ~= on then
		char:SetAttribute("Aiming", if on then true else nil)
		if on and char:GetAttribute("Sprinting") then
			Combat.SetSprint(player, false)
		end
		require(script.Parent.Stats).Apply(player)
	end
end

function Stealth.Whistle(player)
	local now = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or now - (lastWhistle[player] or 0) < S.WhistleCooldown then
		return false
	end
	lastWhistle[player] = now
	Remotes.World:FireAllClients("Whistle", root.Position)
	Stealth.Noise(root.Position, S.Noise.Whistle, "Whistle", player)
	return true
end

-- A breaker: cuts its circuit; the nearest guard walks over and puts the lights back unless something stops it.
function Stealth.Breaker(player, part)
	local level = levels[player]
	if not level or part:GetAttribute("Cut") then
		return false
	end
	part:SetAttribute("Cut", true)
	Stealth.SetCircuit(level, part:GetAttribute("Circuit"), false)
	Remotes.World:FireAllClients("Sparks", part.Position)
	-- whoever has the shortest walk to it comes to fix it (not the nearest through a wall or a floor)
	local stand = part:GetAttribute("Stand")
	local goal = if typeof(stand) == "Vector3" then stand else part.Position
	task.spawn(function()
		local nearest, best, straight, bestStraight = nil, S.Path.FixWalk, nil, 90
		for _, g in guards do
			if g.level == level and g.state ~= "Down" and g.state ~= "Alert" and g.state ~= "Held" then
				local d = (g.root.Position - goal).Magnitude
				if d < bestStraight then
					straight, bestStraight = g, d
				end
				if d < S.Path.FixWalk then
					local length = routeLength(g, goal)
					if length and length < best then
						nearest, best = g, length
					end
				end
			end
		end
		nearest = nearest or straight
		if nearest and part.Parent and part:GetAttribute("Cut") and nearest.state ~= "Down" and nearest.state ~= "Alert" then
			investigate(nearest, goal, S.Path.FixSeconds)
			nearest.fix = part
		end
	end)
	return true
end

local function movementNoise(player, char)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or hum.Health <= 0 then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < 2 and hum.MoveDirection.Magnitude < 0.1 then
		return 0
	end
	if char:GetAttribute("Crouched") then
		return S.Noise.Crouch
	end
	return if char:GetAttribute("Sprinting") then S.Noise.Sprint else S.Noise.Walk
end

function Stealth.Init()
	Net.On("Takedown", { rate = 2, burst = 3, args = { "instance" } }, function(player, model)
		Stealth.Takedown(player, model)
	end)
	Net.On("Crouch", { rate = 4, burst = 6, args = { "boolean" } }, Stealth.SetCrouch)
	Net.On("Stance", { rate = 6, burst = 8, args = { "string" } }, Stealth.SetStance)
	Net.On("Aim", { rate = 8, burst = 10, args = { "boolean" } }, Stealth.SetAim)
	Net.On("Cqc", { rate = 4, burst = 6, args = { "string", "instance?", "vector?" } }, function(player, what, model, aim)
		if model ~= nil and typeof(model) ~= "Instance" then
			return
		end
		if what == "Throw" then
			if holds[player] then
				Stealth.Release(player, "Throw", aim)
			else
				Stealth.Throw(player, model, false, aim)
			end
		elseif what == "Grab" then
			Stealth.Grab(player, model)
		elseif what == "Choke" then
			Stealth.Release(player, "Choke")
		elseif what == "Search" then
			Stealth.Search(player, model)
		elseif what == "Carry" then
			Stealth.Carry(player, model)
		elseif what == "Drop" then
			Stealth.DropBody(player)
		elseif what == "Question" then
			Stealth.Question(player)
		end
	end)
	Net.On("Whistle", { rate = 1, burst = 2 }, Stealth.Whistle)

	-- a round that rings off his helmet or thuds into his plate: he is unhurt, and he knows he is being shot at
	Combat.Deflected.Event:Connect(function(char, model)
		local g = guards[model]
		local player = Players:GetPlayerFromCharacter(char)
		if g and player and g.state ~= "Down" and not g.busy and levels[player] == g.level then
			g.aware[player] = 1
			g.seen[player] = char:GetPivot().Position
			alert(g, player, true)
		end
	end)

	-- a sleeping dart in a guard
	Combat.Slept.Event:Connect(function(char, model, zone)
		Stealth.Dart(char, model, zone)
	end)

	-- shots: heard, and they put lights out
	Combat.Shot.Event:Connect(function(char, inst, position, weapon)
		local player = Players:GetPlayerFromCharacter(char)
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			Stealth.Noise(root.Position, (weapon and weapon.Noise) or 55, "Shot", player)
		end
		local part = inst
		while part and part ~= workspace and not CollectionService:HasTag(part, "StealthLight") do
			part = part.Parent
		end
		if part and part ~= workspace and typeof(part) == "Instance" and CollectionService:HasTag(part, "StealthLight") then
			Stealth.BreakLight(part, player)
		elseif inst then
			Stealth.ShootOut(inst, position, player) -- a street lamp, a sign, a desk light: anything small that glows
		end
	end)
	Combat.Resolved.Event:Connect(function(attacker, victim, result)
		local player = Players:GetPlayerFromCharacter(attacker)
		if player and levels[player] and result ~= "none" then
			local root = attacker:FindFirstChild("HumanoidRootPart")
			if root then
				Stealth.Noise(root.Position, S.Noise.Melee, "Melee", player)
			end
			-- hit a guard that had not made you: it has now
			local g = guards[victim]
			if g and g.state ~= "Down" then
				alert(g, player, true)
			end
		end
	end)

	local acc, expAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		followHands(os.clock())
		for player, spot in hiding do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (char and char.Parent and hum and hum.Health > 0 and char:GetAttribute("Hidden")) or not spot.Parent then
				hiding[player] = nil -- a new body, a death, a locker gone
				if spot.Parent then
					spot:SetAttribute("Occupant", nil)
					local prompt = spot:FindFirstChild("HidePrompt")
					if prompt then
						prompt.ActionText = "Hide"
					end
				end
			end
		end
		acc += dt
		expAcc += dt
		if expAcc >= S.ExposureTick then
			expAcc = 0
			for player, level in levels do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local e = Stealth.ExposureAt(level, root.Position + Vector3.new(0, 0.8, 0), { char })
					e *= 1 - math.clamp(char:GetAttribute("Conceal") or 0, 0, 0.9) -- the soot poncho
					if hiding[player] then
						e = 0
					end
					char:SetAttribute("Exposure", math.floor(e * 25 + 0.5) / 25)
				end
			end
		end
		if acc < S.Tick then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for player in levels do
			local char = player.Character
			if char then
				local radius = movementNoise(player, char)
				noiseNow[player] = radius
				if radius > 0 then
					Stealth.Noise(char.HumanoidRootPart.Position, radius, "Step", player)
				end
			end
		end
		for _, g in guards do
			local ok, err = pcall(think, g, now, step)
			if not ok then
				warn("[Stealth] guard:", err)
			end
		end
		-- what each intruder's HUD shows: how close each guard is to making them
		for player, level in levels do
			local list = {}
			for model, g in guards do
				if g.level == level then
					table.insert(list, { model, math.floor((g.aware[player] or 0) * 100 + 0.5) / 100, g.state })
				end
			end
			Remotes.Stealth:FireClient(player, list, noiseNow[player] or 0)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Stealth.Leave(player)
		lastWhistle[player] = nil
	end)
end

return Stealth
