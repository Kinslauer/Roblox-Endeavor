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
local Items = require(Shared.Items)
local Presentation = require(Shared.Presentation)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Rig = require(script.Parent.Rig)
local Stats = require(script.Parent.Stats)

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
local function buildEnemyRig(typeName, def)
	local model = Rig.Build(def.Look.Appearance)
	model.Name = def.Name or typeName
	for _, partName in CLOTH_PARTS do
		local part = model:FindFirstChild(partName)
		if part then
			part.Color = def.Look.Cloth
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
	CollectionService:AddTag(model, NPCs.Tag)
	return model, hum, model.HumanoidRootPart
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

local function nearestTarget(root, aggro)
	local target, best = nil, aggro
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart")
		local thum = char and char:FindFirstChildOfClass("Humanoid")
		if troot and thum and thum.Health > 0 and not District.InSafeZone(troot.Position) then -- plaza is off-limits
			local dist = (troot.Position - root.Position).Magnitude
			if dist < best then
				target, best = char, dist
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
		Stats.AddXp(killer, def.Xp)
		Quests.Progress(killer, "kill", def.QuestTag or typeName, 1)
		Quests.Progress(killer, "kill", typeName, 1)
	end
	Loot.Spawn(root.CFrame, Items.Roll(def.Loot), { Label = (def.Name or typeName) .. " spoils", Lifetime = 120 })
	task.wait(0.2)
	model:Destroy()
end

-- ===== Spawning / AI =====

-- opts: { Despawn = true/false } (ambush enemies despawn when idle; placed ones stay)
function NPCs.Spawn(typeName, position, opts)
	local def = Enemies.Defs[typeName]
	if not def then
		warn("[NPCs] unknown enemy type", typeName)
		return nil
	end
	opts = opts or {}
	local model, hum, root = buildEnemyRig(typeName, def)
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- server drives this body

	hum.Died:Once(function()
		onDeath(model, root, typeName, def)
	end)

	local setMoving = loadLocomotion(hum)
	local nav = newNavigator(model, hum, root)
	local home = position
	local nextAttackAt = 0
	local idleSince = os.clock()
	local state = "Idle"

	local function attack(target)
		local troot = target.HumanoidRootPart
		model:PivotTo(flatLook(root, troot.Position))
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
			else
				local target, dist = nearestTarget(root, def.Aggro)
				local fromHome = (root.Position - home).Magnitude
				if target and fromHome > def.Leash then
					target = nil -- leashed: give up and walk back
				end

				if target then
					idleSince = now
					local troot = target.HumanoidRootPart
					local canAttack = now >= nextAttackAt and Combat.CanAct(model)
					if def.KeepDistance then
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
					if fromHome > 6 then
						state = "Return"
						nav.moveTo(home)
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
