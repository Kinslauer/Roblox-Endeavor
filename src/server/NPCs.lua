-- Hostile NPCs (Enemy v2). Variants live in shared/Enemies.lua. Each enemy:
--   * is a standardized R15 body from Rig.Build (same joints as players, so the client's
--     SwingAnimator / WeaponView / Impacts work on it unchanged; its Weapon attribute draws the weapon)
--   * attacks through Combat.Swing, so it telegraphs with a real windup, can be parried, dodged,
--     and has its swing cancelled by hit stun exactly like a player
--   * moves with PathfindingService (MoveTo fallback), leashes to its spawn, despawns when idle
-- State machine per enemy: Idle -> Chase -> Attack -> (Stunned) -> Return. Decisions every AI.Tick.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local District = require(Shared.District)
local Enemies = require(Shared.Enemies)
local Lore = require(Shared.Lore)
local Items = require(Shared.Items)
local Presentation = require(Shared.Presentation)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Rig = require(script.Parent.Rig)
local Stats = require(script.Parent.Stats)
local PlayerData = require(script.Parent.PlayerData)

local AI = Enemies.AI
local rng = Random.new()

local NPCs = {}
NPCs.Tag = "Combatant" -- CollectionService tag the client uses to find non-player fighters

-- ===== Rigs =====

-- Kept for the tutorial / arena dummies: a static capsule with a Humanoid.
function NPCs.BuildRig(name, typeDef)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name, root.Size, root.Color = "HumanoidRootPart", Vector3.new(2, 5, 1), Color3.fromRGB(110, 40, 40)
	local head = Instance.new("Part")
	head.Name, head.Size, head.Shape = "Head", Vector3.new(1.6, 1.6, 1.6), Enum.PartType.Ball
	head.Color = Color3.fromRGB(200, 160, 130)
	head.CFrame = root.CFrame * CFrame.new(0, 3.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, head
	weld.Parent = head
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health, hum.WalkSpeed = typeDef.Health, typeDef.Health, typeDef.Speed
	hum.HipHeight = 2
	root.Parent, head.Parent, hum.Parent = model, model, model
	model.PrimaryPart = root
	return model, hum, root
end

local CLOTH_PARTS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

-- Enemy body: standardized rig in the variant's look, tinted "clothing" parts, weapon attribute.
local function buildEnemyRig(typeName, def, opts)
	local model = Rig.Build(def.Look.Appearance)
	model.Name = (opts and opts.Name) or def.Name or typeName
	for _, partName in CLOTH_PARTS do
		local part = model:FindFirstChild(partName)
		if part then
			part.Color = (opts and opts.Cloth) or def.Look.Cloth
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth, hum.Health, hum.WalkSpeed = def.Health, def.Health, def.Speed
	hum.DisplayName = def.Name or typeName
	hum.HealthDisplayDistance = 60
	if def.MaxPosture then -- read by Combat.State on first contact
		model:SetAttribute("MaxPosture", def.MaxPosture)
		model:SetAttribute("Posture", 0)
	end
	model:SetAttribute("Weapon", def.Weapon)
	model:SetAttribute("EnemyType", typeName)
	if def.Poise then
		model:SetAttribute("PoiseHits", def.Poise.Hits)
		model:SetAttribute("PoiseReset", def.Poise.Reset)
	end
	CollectionService:AddTag(model, NPCs.Tag)
	return model, hum, model.HumanoidRootPart
end

-- Flying enemy body (Enemies.Defs[*].Flying): a machine, not a person. One root part flown by an
-- AlignPosition / AlignOrientation pair (so knockback, Snatch and hit-stun still move it and it
-- recovers on its own), a neon "eye" named Head (the client's bolt leaves the Head or root), four
-- rotor rings. No Weapon attribute: nothing to put in a hand. Humanoid for health/targeting only.
local function buildDroneRig(typeName, def)
	local L, F = def.Look, def.Flying
	local model = Instance.new("Model")
	model.Name = def.Name or typeName
	local root = Instance.new("Part")
	root.Name, root.Size, root.Color, root.Material = "HumanoidRootPart", Vector3.new(2.4, 1.2, 2.4), L.Body, Enum.Material.Metal
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.3) -- light, so the flight constraints are not fighting a block of steel
	root.Parent = model
	local function attach(p, offset)
		p.CFrame = root.CFrame * offset
		p.CanCollide, p.Massless = false, true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
		p.Parent = model
		return p
	end
	local eye = Instance.new("Part")
	eye.Name, eye.Shape, eye.Size, eye.Color, eye.Material = "Head", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), L.Accent, Enum.Material.Neon
	attach(eye, CFrame.new(0, -0.2, -1.1))
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = L.Accent, 10, 1.5
	light.Parent = eye
	for _, off in { Vector3.new(1.5, 0.4, 1.5), Vector3.new(-1.5, 0.4, 1.5), Vector3.new(1.5, 0.4, -1.5), Vector3.new(-1.5, 0.4, -1.5) } do
		local strut = Instance.new("Part")
		strut.Name, strut.Size, strut.Color, strut.Material = "Strut", Vector3.new(0.3, 0.3, off.Magnitude), L.Body, Enum.Material.Metal
		attach(strut, CFrame.lookAt(Vector3.zero, off) * CFrame.new(0, 0, -off.Magnitude / 2))
		local rotor = Instance.new("Part")
		rotor.Name, rotor.Shape, rotor.Size, rotor.Color, rotor.Material, rotor.Transparency = "Rotor", Enum.PartType.Cylinder, Vector3.new(0.15, 1.7, 1.7), L.Rotor, Enum.Material.Neon, 0.35
		attach(rotor, CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90)))
	end
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health = def.Health, def.Health
	hum.DisplayName = def.Name or typeName
	hum.HealthDisplayDistance = 60
	hum.PlatformStand = true -- the constraints fly the body; the Humanoid is health + a target
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("EnemyType", typeName)
	model:SetAttribute("Flying", true)
	if def.Poise then
		model:SetAttribute("PoiseHits", def.Poise.Hits)
		model:SetAttribute("PoiseReset", def.Poise.Reset)
	end
	-- flight: the AI moves the AlignPosition target; the body follows at Speed, fighting gravity itself
	local att = Instance.new("Attachment")
	att.Name = "Flight"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Name = "FlightPosition"
	ap.Mode, ap.Attachment0 = Enum.PositionAlignmentMode.OneAttachment, att
	ap.MaxForce, ap.MaxVelocity, ap.Responsiveness = 50000, def.Speed, F.Responsiveness
	ap.Position = root.Position
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "FlightOrientation"
	ao.Mode, ao.Attachment0 = Enum.OrientationAlignmentMode.OneAttachment, att
	ao.MaxTorque, ao.Responsiveness = 50000, 25
	ao.CFrame = root.CFrame
	ao.Parent = root
	CollectionService:AddTag(model, NPCs.Tag)
	return model, hum, root
end

-- ===== Locomotion animation (server-side; enemies have no Animate script) =====

local function loadLocomotion(hum)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for name, id in Presentation.Locomotion do
		if id ~= "" then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, anim)
			if ok and track then
				track.Looped = true
				track.Priority = if name == "idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
				tracks[name] = track
			end
		end
	end
	local current
	return function(moving)
		local want = tracks[if moving then "walk" else "idle"]
		if want and want ~= current then
			if current then
				current:Stop(0.15)
			end
			current = want
			want:Play(0.15)
		end
	end
end

-- ===== Helpers =====

-- Which side a body fights for: players carry it on the Player, NPCs on the model. nil = nobody's.
local function factionOf(char)
	local player = Players:GetPlayerFromCharacter(char)
	return if player then player:GetAttribute("Faction") else char:GetAttribute("Faction")
end
NPCs.FactionOf = factionOf

-- Nearest hostile. Plain enemies hunt players. A recruit with a Faction hunts players *and* other
-- recruits of the other sides (never its own), and ignores downed bodies.
local function nearestTarget(root, aggro, model)
	local target, best = nil, aggro
	local mine = model and model:GetAttribute("Faction")
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart")
		local thum = char and char:FindFirstChildOfClass("Humanoid")
		if troot and thum and thum.Health > 0 and not District.InSafeZone(troot.Position) and not char:GetAttribute("Downed") -- plaza is off-limits
			and not (mine and player:GetAttribute("Faction") == mine) then
			local dist = (troot.Position - root.Position).Magnitude
			if dist < best then
				target, best = char, dist
			end
		end
	end
	if mine then
		for _, other in CollectionService:GetTagged(NPCs.Tag) do
			local theirs = other:GetAttribute("Faction")
			local troot = theirs and theirs ~= mine and other ~= model and other:FindFirstChild("HumanoidRootPart")
			local thum = troot and other:FindFirstChildOfClass("Humanoid")
			if thum and thum.Health > 0 then
				local dist = (troot.Position - root.Position).Magnitude
				if dist < best then
					target, best = other, dist
				end
			end
		end
	end
	return target, best
end

local function flatLook(root, position)
	return CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
end

local function hasLineOfSight(model, root, targetRoot)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, targetRoot.Parent }
	local hit = workspace:Raycast(root.Position, targetRoot.Position - root.Position, params)
	return hit == nil
end

-- Path follower: keeps a waypoint list, recomputes on a cadence / when the goal moves / when stuck.
local function newNavigator(model, hum, root)
	local nav = { waypoints = nil, index = 1, goal = nil, lastCompute = 0, lastProgressAt = 0, lastPos = root.Position }
	local path = PathfindingService:CreatePath({ AgentRadius = AI.AgentRadius, AgentHeight = AI.AgentHeight, AgentCanJump = true })

	local function compute(goal)
		nav.goal, nav.lastCompute = goal, os.clock()
		local ok = pcall(path.ComputeAsync, path, root.Position, goal)
		if ok and path.Status == Enum.PathStatus.Success then
			nav.waypoints, nav.index = path:GetWaypoints(), 2
		else
			nav.waypoints = nil -- fall back to a straight MoveTo
		end
		nav.lastProgressAt, nav.lastPos = os.clock(), root.Position
	end

	function nav.moveTo(goal)
		local now = os.clock()
		local moved = (root.Position - nav.lastPos).Magnitude
		if moved > 0.5 then
			nav.lastProgressAt, nav.lastPos = now, root.Position
		end
		local stuck = now - nav.lastProgressAt > AI.StuckSeconds
		if not nav.goal or now - nav.lastCompute > AI.Repath or (goal - nav.goal).Magnitude > AI.RepathMove or stuck then
			if stuck then
				hum.Jump = true
			end
			compute(goal)
		end
		local wps = nav.waypoints
		if wps and wps[nav.index] then
			local wp = wps[nav.index]
			if (wp.Position - root.Position).Magnitude < AI.WaypointReach then
				nav.index += 1
				wp = wps[nav.index]
			end
			if wp then
				if wp.Action == Enum.PathWaypointAction.Jump then
					hum.Jump = true
				end
				hum:MoveTo(wp.Position)
				return
			end
		end
		hum:MoveTo(goal)
	end

	function nav.stop()
		hum:MoveTo(root.Position)
	end

	return nav
end

local function onDeath(model, root, typeName, def)
	local _, killer = Combat.GetKiller(model)
	if killer then
		local profile = PlayerData.Get(killer)
		if profile and not model:GetAttribute("Target") then -- range targets do not count
			profile.Kills = (profile.Kills or 0) + 1
			if profile.Kills == 1 then
				Remotes.Announce:FireClient(killer, Lore.Get("FirstKill"), "Lore")
			end
		end
		Stats.AddXp(killer, def.Xp)
		Quests.Progress(killer, "kill", def.QuestTag or typeName, 1)
		Quests.Progress(killer, "kill", typeName, 1)
		NPCs.Killed:Fire(killer, model, typeName)
	end
	local at = root.CFrame
	if def.Flying then -- a drone dies in the air: its spoils land under it
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -80, 0), params)
		if hit then
			at = CFrame.new(hit.Position + Vector3.new(0, 2, 0))
		end
	end
	Loot.Spawn(at, Items.Roll(def.Loot), { Label = (def.Name or typeName) .. " spoils", Lifetime = 120 })
	task.wait(0.2)
	model:Destroy()
end

-- ===== Spawning / AI =====

-- Fired when a player kills an NPC: (killerPlayer, model, typeName). The war scores takedowns here.
NPCs.Killed = Instance.new("BindableEvent")

-- opts: Despawn (true/false: ambush enemies despawn when idle; placed ones stay), Faction (id: the
-- side it fights for; it then hunts the other sides' players and recruits), Cloth (Color3 tint),
-- Name, Home (Vector3 or function -> Vector3: where it goes with nobody in sight; the war passes the hill)
function NPCs.Spawn(typeName, position, opts)
	local def = Enemies.Defs[typeName]
	if not def then
		warn("[NPCs] unknown enemy type", typeName)
		return nil
	end
	opts = opts or {}
	local F = def.Flying
	local model, hum, root
	if F then
		model, hum, root = buildDroneRig(typeName, def)
		position += Vector3.new(0, F.Hover, 0) -- flyers spawn in the air
	else
		model, hum, root = buildEnemyRig(typeName, def, opts)
	end
	if opts.Faction then
		model:SetAttribute("Faction", opts.Faction)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- server drives this body

	hum.Died:Once(function()
		onDeath(model, root, typeName, def)
	end)

	local setMoving = loadLocomotion(hum)
	local nav = newNavigator(model, hum, root)
	local home = position
	local function homeNow()
		if type(opts.Home) == "function" then
			return opts.Home(model) or home
		end
		return opts.Home or home
	end
	local nextAttackAt = 0
	local idleSince = os.clock()
	local state = "Idle"

	-- Flight (def.Flying): the AI steers the AlignPosition / AlignOrientation targets; physics does
	-- the rest. Orbit direction flips on a timer so the strafe is not a fixed circle.
	local flight = F and { ap = root:FindFirstChild("FlightPosition"), ao = root:FindFirstChild("FlightOrientation"), dir = 1, flipAt = 0 }
	local function flyTo(pos)
		if flight and flight.ap then
			flight.ap.Position = pos
		end
	end
	local function faceAt(pos)
		if flight and flight.ao then
			flight.ao.CFrame = CFrame.lookAt(root.Position, pos)
		end
	end

	local function attack(target)
		local troot = target.HumanoidRootPart
		if F then
			faceAt(troot.Position) -- the body pitches at the target; Combat.Swing fires along its look
		else
			model:PivotTo(flatLook(root, troot.Position))
		end
		Combat.Swing(model, def.Attack, { label = def.Label })
		local rec = def.Recovery
		nextAttackAt = os.clock() + def.Attack.End + rng:NextNumber(rec[1], rec[2])
	end

	task.spawn(function()
		while model.Parent and hum.Health > 0 do
			local now = os.clock()
			local cs = Combat.State(model)
			local stunnedOrBusy = now < cs.stunned or now < cs.busyUntil

			if stunnedOrBusy then
				nav.stop() -- a stunned or swinging enemy stands still (swings are cancelled by Combat on stun)
				setMoving(false)
				if F then
					flyTo(root.Position) -- a hit knocks it off its line; it holds wherever it ends up
				end
			else
				local target, dist = nearestTarget(root, def.Aggro, model)
				local goal = homeNow()
				local fromHome = (root.Position - goal).Magnitude
				if target and fromHome > def.Leash then
					target = nil -- leashed: give up and walk back
				end

				if target then
					idleSince = now
					local troot = target.HumanoidRootPart
					local canAttack = now >= nextAttackAt and Combat.CanAct(model)
					if F then
						-- Drone: orbit the target inside the KeepDistance band at Hover height, fire with LOS.
						if now > flight.flipAt then
							flight.dir = -flight.dir
							flight.flipAt = now + rng:NextNumber(F.FlipEvery[1], F.FlipEvery[2])
						end
						local rel = (root.Position - troot.Position) * Vector3.new(1, 0, 1)
						local flat = rel.Magnitude
						local a = (if flat > 0.1 then math.atan2(rel.Z, rel.X) else rng:NextNumber(0, math.pi * 2)) + flight.dir * F.Strafe * AI.Tick * 2
						local r = math.clamp(flat, def.KeepDistance[1], def.KeepDistance[2])
						local bob = math.sin(now * 2.2) * F.Bob
						flyTo(troot.Position + Vector3.new(math.cos(a) * r, F.Hover + bob, math.sin(a) * r))
						faceAt(troot.Position)
						state = "Chase"
						if canAttack and dist <= def.Range and hasLineOfSight(model, root, troot) then
							state = "Attack"
							attack(target)
						end
					elseif def.KeepDistance then
						-- Gunner: hold a distance band and only fire with line of sight.
						local lo, hi = def.KeepDistance[1], def.KeepDistance[2]
						if dist < lo then
							state = "Chase"
							local away = (root.Position - troot.Position) * Vector3.new(1, 0, 1)
							nav.moveTo(root.Position + (if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector) * 10)
							setMoving(true)
						elseif dist > hi or not hasLineOfSight(model, root, troot) then
							state = "Chase"
							nav.moveTo(troot.Position)
							setMoving(true)
						elseif canAttack then
							state = "Attack"
							nav.stop()
							setMoving(false)
							attack(target)
						else
							nav.stop()
							model:PivotTo(flatLook(root, troot.Position))
							setMoving(false)
						end
					else
						if dist <= def.Range * 0.85 then
							nav.stop()
							setMoving(false)
							if canAttack then
								state = "Attack"
								attack(target)
							else
								model:PivotTo(flatLook(root, troot.Position)) -- track the target through recovery
							end
						else
							state = "Chase"
							nav.moveTo(troot.Position)
							setMoving(true)
						end
					end
				else
					if F then
						flyTo(goal)
						local level = root.CFrame.LookVector * Vector3.new(1, 0, 1)
						if level.Magnitude > 0.1 then
							faceAt(root.Position + level.Unit * 10) -- level off
						end
					end
					if fromHome > 6 then
						state = "Return"
						if not F then
							nav.moveTo(goal)
						end
						setMoving(true)
					else
						state = "Idle"
						nav.stop()
						setMoving(false)
						if opts.Despawn and now - idleSince > def.DespawnAfter then
							model:Destroy()
							break
						end
					end
				end
			end
			model:SetAttribute("AIState", state)
			task.wait(AI.Tick)
		end
	end)
	return model
end

-- Finds solid ground inside the playable area under/near a point. Returns a position or nil.
-- Playable area = parts tagged "PlayableArea" (or any ground when nothing is tagged yet).
function NPCs.FindGround(position, maxDrop)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged(NPCs.Tag) do
		table.insert(ignore, m)
	end
	params.FilterDescendantsInstances = ignore
	local origin = position + Vector3.new(0, 20, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -(maxDrop or 60), 0), params)
	if not hit or hit.Instance:IsA("Terrain") and hit.Material == Enum.Material.Water then
		return nil
	end
	local playable = CollectionService:GetTagged("PlayableArea")
	if #playable > 0 then
		local ok = false
		for _, area in playable do
			if hit.Instance == area or hit.Instance:IsDescendantOf(area) then
				ok = true
				break
			end
		end
		if not ok then
			return nil
		end
	end
	return hit.Position + Vector3.new(0, 3.5, 0)
end

-- Spawns an ambush group around `center`: weighted variants, ground-checked ring placement
-- that shrinks when a ring has no valid spots. Returns the models spawned.
function NPCs.SpawnAmbush(center, size)
	local A = Enemies.Ambush
	-- district overrides (Enemies.Ambush.ByDistrict) layered over the defaults
	local index = District.At(center)
	local over = index and A.ByDistrict and A.ByDistrict[index]
	if over then
		A = setmetatable(table.clone(over), { __index = A })
	end
	size = size or rng:NextInteger(A.GroupSize[1], A.GroupSize[2])
	local spawned, brutes = {}, 0
	local radius = A.Ring
	for _ = 1, size do
		-- pick a variant
		local total = 0
		for name, w in A.Weights do
			if not (name == "Brute" and brutes >= A.MaxBrutes) then
				total += w
			end
		end
		local roll, typeName = rng:NextNumber(0, total), "Grunt"
		for name, w in A.Weights do
			if not (name == "Brute" and brutes >= A.MaxBrutes) then
				roll -= w
				if roll <= 0 then
					typeName = name
					break
				end
			end
		end
		-- find a spot
		local spot
		for try = 1, A.PlacementTries do
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = radius * (0.8 + 0.2 * rng:NextNumber())
			spot = NPCs.FindGround(center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
			if spot then
				break
			end
			if try % 2 == 0 then
				radius *= A.RingShrink
			end
		end
		if spot then
			local model = NPCs.Spawn(typeName, spot, { Despawn = true })
			if model then
				table.insert(spawned, model)
				if typeName == "Brute" then
					brutes += 1
				end
			end
		end
	end
	return spawned
end

return NPCs
