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
	g.state = state
	g.model:SetAttribute("StealthState", state)
	g.stateAt = os.clock()
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
	if g.state == "Alert" or g.state == "Down" then
		return
	end
	g.spot = position
	g.searchUntil = os.clock() + (seconds or S.SearchSeconds)
	g.lookAt = nil
	setState(g, "Search")
end

local function callOthers(g, position)
	for _, other in guards do
		if other ~= g and other.level == g.level and other.state ~= "Down" and other.state ~= "Alert"
			and (other.root.Position - g.root.Position).Magnitude <= S.CallRadius then
			investigate(other, position)
		end
	end
end

local function alert(g, player)
	if g.state == "Down" then
		return
	end
	local first = g.state ~= "Alert"
	g.target = player
	g.lastSeenAt = os.clock()
	g.hum.WalkSpeed = g.speed
	setState(g, "Alert")
	if first then
		NPCs.Bark(g.model, "Alert")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			callOthers(g, root.Position)
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
	for _, g in guards do
		if g.state ~= "Down" and g.state ~= "Alert" and (not level or g.level == level) then
			local d = (g.root.Position - position).Magnitude
			local reach = radius
			if d <= reach and not clearLine(position + Vector3.new(0, 1, 0), g.root.Position + Vector3.new(0, 1, 0), { g.model, player and player.Character }) then
				reach *= 0.55 -- walls muffle it
			end
			if d <= reach then
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
	local eyes = g.root.Position + Vector3.new(0, 2, 0)
	-- what he would see of you: the chest standing, lower crouched, a shape on the floor prone (the root itself
	-- stays at standing height), so low cover really hides a low body
	local to = root.Position + Vector3.new(0, if prone then -1.9 elseif crouched then -0.4 else 0.8, 0)
	local offset = to - eyes
	local d = offset.Magnitude
	if d < S.Bump then
		return true, 1
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
	local range = Rules.SightRange(exposure, crouched, searching, prone)
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

local function think(g, now, dt)
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
			local visible, clarity = sees(g, char, char:GetAttribute("Exposure") or 1, char:GetAttribute("Crouched") == true, char:GetAttribute("Stance") == "Prone")
			local a = g.aware[player] or 0
			if visible then
				local rate = S.FillRate * clarity * (if g.state == "Search" or g.wary then S.SearchFill else 1)
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
	local g = { aware = {}, seen = {}, state = "Patrol", stateAt = os.clock(), level = opts.Level, patrol = opts.Patrol, looks = opts.Looks,
		wait = opts.Wait or 3, post = opts.Post, index = 1, waitUntil = 0, searchUntil = 0, lastSeenAt = 0, nav = { at = 0, movedAt = 0 } }
	local model = NPCs.Spawn(opts.Type or "Sentry", position, {
		Parent = opts.Parent or opts.Level,
		Filter = function(player)
			return g.state == "Alert" and g.target == player
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
	CollectionService:AddTag(model, "Guard")
	guards[model] = g
	model.Destroying:Connect(function()
		guards[model] = nil
	end)
	g.hum.Died:Connect(function()
		g.state = "Dead"
		guards[model] = nil
	end)
	return model, g
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
	for _, g in guards do
		if g.level == level and g.state ~= "Down" then
			g.aware, g.seen, g.target, g.wary, g.fix = {}, {}, nil, false, nil
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
		if g.busy or not Combat.CanAct(char) or char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or (g.aware[player] or 0) >= 1 then
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
function Stealth.Throw(player, model, fromHold)
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
		g.busy = false
		if g.model.Parent and g.hum.Health > 0 then
			setState(g, "Down")
			local right = Vector3.new(-dir.Z, 0, dir.X) -- his right when he faces `dir`
			layDown(g, gpos + dir * Q.Throw.Fall + right * side, yawOf(dir))
			g.wakeAt = os.clock() + Q.Throw.Down
			Stealth.Noise(gpos, Q.Throw.Noise, "Takedown", player)
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
function Stealth.Release(player, how)
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
		done = Stealth.Throw(player, g.model, true)
	end
	if not done then
		g.root.Anchored = false
		alert(g, player)
	end
	return true
end

-- X held over a body: it goes on your shoulder (slow, no sprint). X or G puts it down in front of you.
function Stealth.Carry(player, model)
	local g = typeof(model) == "Instance" and guards[model]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (g and root and hum and hum.Health > 0) or g.state ~= "Down" or g.carriedBy or carries[player] or not handsFree(char)
		or (g.root.Position - root.Position).Magnitude > Q.Carry.Reach then
		return false
	end
	g.carriedBy = player
	carries[player] = g
	if char:GetAttribute("Crouched") then
		Stealth.SetCrouch(player, false)
	end
	if char:GetAttribute("Sprinting") then
		Combat.SetSprint(player, false)
	end
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
	if not (g and root) or g.state ~= "Down" or g.carriedBy or not handsFree(char) or (g.root.Position - root.Position).Magnitude > Q.Carry.Reach + 1 then
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
	if g.model.Parent then
		local look = if root then root.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.new(0, 0, -1)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		local at = if root then root.Position + look * 1.8 else g.root.Position
		layDown(g, at, yawOf(look))
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
			g.root.CFrame = root.CFrame * Q.Carry.Offset * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		end
	end
	for _, g in guards do
		if g.state == "Down" and g.wakeAt and now >= g.wakeAt and not g.carriedBy and not g.busy and g.hum.Health > 0 then
			standUp(g)
		end
	end
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
	on = on == true and def ~= nil and def.Family == "Sidearm" and not char:GetAttribute("NeckHold") and not char:GetAttribute("Carrying")
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
	Net.On("Cqc", { rate = 4, burst = 6, args = { "string", "instance?" } }, function(player, what, model)
		if model ~= nil and typeof(model) ~= "Instance" then
			return
		end
		if what == "Throw" then
			if holds[player] then
				Stealth.Release(player, "Throw")
			else
				Stealth.Throw(player, model)
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
		end
	end)
	Net.On("Whistle", { rate = 1, burst = 2 }, Stealth.Whistle)

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
				alert(g, player)
			end
		end
	end)

	local acc, expAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		followHands(os.clock())
		acc += dt
		expAcc += dt
		if expAcc >= S.ExposureTick then
			expAcc = 0
			for player, level in levels do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local e = Stealth.ExposureAt(level, root.Position + Vector3.new(0, 0.8, 0), { char })
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
