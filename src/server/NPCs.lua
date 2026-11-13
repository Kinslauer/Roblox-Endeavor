-- Hostile NPCs. Data-driven types with telegraphed attacks so parry/dodge timing is readable.
-- Rigs are placeholder blocks until real models exist (swap NPCs.BuildRig).
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Swings = require(Shared.Swings)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local Gore = require(script.Parent.Gore)
local Rigs = require(script.Parent.Common.Rigs)
local HeldWeapons = require(script.Parent.Common.HeldWeapons)
local Assets = require(Shared.Assets)

local NPCs = {}
NPCs.Killed = Instance.new("BindableEvent") -- (typeName, model, killerPlayer?)

-- Breaches and explosions are loud: idle NPCs within `radius` walk over to look.
function NPCs.Alert(position, radius)
	for _, model in CollectionService:GetTagged("NPC") do
		local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= radius then
			model:SetAttribute("Investigate", position)
			model:SetAttribute("InvestigateUntil", os.clock() + 15)
		end
	end
end

-- Frame data for every strike: Telegraph = startup in seconds (the red flash: the dodge/parry window), Active and
-- Recovery in frames at 60/s (Weapons.FPS); a Move may set its own Active/Recovery, else the type's.
-- Moves: optional list of special attacks { Name, Chance, Telegraph, Damage, Posture, Radius?, Knockback, Stun?, Unblockable? }
NPCs.Types = {
	Raider = { Health = 70, Speed = 13, Damage = 9, Posture = 10, Range = 6, Cooldown = 1.4, Telegraph = 0.45, Active = 12, Recovery = 18, Aggro = 90, Xp = 35, Loot = "Raider",
		Color = Color3.fromRGB(110, 40, 40), Size = Vector3.new(2, 5, 1), Weapon = "PipeClub" },
	Brute = { Health = 220, Speed = 10, Damage = 22, Posture = 30, Range = 7, Cooldown = 2.4, Telegraph = 0.8, Active = 14, Recovery = 30, Aggro = 80, Xp = 90, Loot = "Raider",
		Armor = { HelmetCover = 0.8, Helmet = 1, Vest = 2, Bracers = 1 }, -- slit helmet, scrap plate over the chest and arms
		Color = Color3.fromRGB(90, 60, 30), Size = Vector3.new(3, 6.5, 1.6), Knockback = 40, Hyperarmor = true, Weapon = "Sledge" },
	Shocker = { Health = 90, Speed = 15, Damage = 12, Posture = 8, Range = 9, Cooldown = 1.6, Telegraph = 0.5, Active = 10, Recovery = 16, Aggro = 110, Xp = 60, Loot = "Raider",
		Color = Color3.fromRGB(40, 90, 140), Size = Vector3.new(2, 5, 1), Type = "Arc", Stun = 0.6, Weapon = "ShockBaton" },
	-- rival conduits: a crew working the frontier's contracts; faster and meaner than raiders, and worth it
	Rival = { Health = 170, Speed = 15, Damage = 15, Posture = 22, Range = 6.5, Cooldown = 1.25, Telegraph = 0.4, Active = 10, Recovery = 14, Aggro = 100, Xp = 140, Loot = "Rival",
		Color = Color3.fromRGB(70, 60, 90), Size = Vector3.new(2, 5, 1), Weapon = "RebarBlade" },
	-- station security (server/Stealth.SpawnGuard): it only fights once it has made you
	Sentry = { Health = 85, Speed = 14, Damage = 11, Posture = 10, Range = 6.5, Cooldown = 1.4, Telegraph = 0.45, Active = 12, Recovery = 18, Aggro = 120, Xp = 45, Loot = "Sentry",
		Armor = { HelmetCover = 0.45, Helmet = 1, Vest = 2, Bracers = 1, Shins = 1 }, -- brimmed steel helmet, plate vest, bracers, shin guards
		Color = Color3.fromRGB(52, 60, 74), Size = Vector3.new(2, 5, 1), Type = "Arc", Stun = 0.4, Weapon = "ShockBaton" },
	Warden = { Health = 900, Speed = 11, Damage = 26, Posture = 35, Range = 8, Cooldown = 2.0, Telegraph = 0.7, Active = 14, Recovery = 26, Aggro = 140, Xp = 600, Loot = "Supply",
		Armor = { HelmetCover = 0.95, Helmet = 2, Vest = 2 },
		Color = Color3.fromRGB(150, 30, 60), Size = Vector3.new(3.5, 8, 2), Knockback = 45, Hyperarmor = true, Boss = true, Weapon = "RebarBlade",
		Moves = {
			{ Name = "Slam", Chance = 0.35, Telegraph = 1.1, Damage = 40, Posture = 60, Radius = 14, Knockback = 70, Unblockable = true, Stun = 1.0 },
			{ Name = "Lunge", Chance = 0.25, Telegraph = 0.6, Damage = 30, Posture = 40, Dash = 60, Knockback = 50 },
		},
	},
}

function NPCs.BuildRig(name, typeDef)
	-- a Blender rig if one is uploaded for this type; the box rig otherwise
	local rigId = Assets.Rigs[name]
	if rigId and rigId ~= 0 then
		local model, hum, root = Rigs.Build(rigId, name, name)
		if model then
			hum.MaxHealth, hum.Health, hum.WalkSpeed = typeDef.Health or 100, typeDef.Health or 100, typeDef.Speed or 0
			model:SetAttribute("Rigged", true)
			return model, hum, root
		end
	end
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name, root.Size, root.Color = "HumanoidRootPart", typeDef.Size or Vector3.new(2, 5, 1), typeDef.Color or Color3.fromRGB(110, 40, 40)
	local head = Instance.new("Part")
	head.Name, head.Size, head.Shape = "Head", Vector3.new(1.6, 1.6, 1.6), Enum.PartType.Ball
	head.Color = Color3.fromRGB(200, 160, 130)
	head.CFrame = root.CFrame * CFrame.new(0, root.Size.Y / 2 + 0.7, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, head
	weld.Parent = head
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health, hum.WalkSpeed = typeDef.Health or 100, typeDef.Health or 100, typeDef.Speed or 0
	hum.HipHeight = root.Size.Y / 2 - 0.5
	root.Parent, head.Parent, hum.Parent = model, model, model
	model.PrimaryPart = root
	return model, hum, root
end

local AI = Config.City.AI

-- Taking turns (ported from combat-feel; owner: "every time I swing I get hit", "make them spread around you").
-- Only AI.MeleeAttackers bodies may be winding up or striking at one target at a time; the rest hold a ring
-- around it (AI.HoldGap outside their reach), spread apart, circling, and step in when the slot frees.
local claims = setmetatable({}, { __mode = "k" }) -- target -> { [attacker] = claim ends }

local function othersSwinging(target, attacker, now)
	local c, n = claims[target], 0
	for m, untilT in c or {} do
		if untilT <= now or not m.Parent then
			c[m] = nil
		elseif m ~= attacker then
			n += 1
		end
	end
	return n
end

local function claimSwing(target, attacker, now, seconds)
	if othersSwinging(target, attacker, now) >= AI.MeleeAttackers then
		return false
	end
	claims[target] = claims[target] or {}
	claims[target][attacker] = now + seconds
	return true
end
NPCs.Swinging = function(target)
	return othersSwinging(target, nil, os.clock())
end

-- Where a waiting body stands: on the ring at its current bearing, drifting `side`, pushed away from any
-- other body close by so a group fans out around you instead of stacking in front.
local function holdSpot(model, root, troot, radius, side)
	local rel = (root.Position - troot.Position) * Vector3.new(1, 0, 1)
	local a = if rel.Magnitude > 0.1 then math.atan2(rel.Z, rel.X) else math.random() * math.pi * 2
	for _, other in CollectionService:GetTagged("NPC") do
		local oroot = other ~= model and other:FindFirstChild("HumanoidRootPart")
		if oroot and (oroot.Position - root.Position).Magnitude < AI.Spread then
			local orel = (oroot.Position - troot.Position) * Vector3.new(1, 0, 1)
			if orel.Magnitude > 0.1 then
				local diff = (a - math.atan2(orel.Z, orel.X) + math.pi) % (2 * math.pi) - math.pi
				a += if diff >= 0 then AI.SpreadPush else -AI.SpreadPush
			end
		end
	end
	a += side * AI.CircleSpeed * AI.Tick
	return troot.Position + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

-- Path follower: a waypoint list, recomputed on a cadence, when the goal moves, or when stuck (then it jumps).
local function newNavigator(model, hum, root)
	local nav = { waypoints = nil, index = 1, goal = nil, lastCompute = 0, lastProgressAt = 0, lastPos = root.Position }
	local path
	pcall(function()
		path = PathfindingService:CreatePath({ AgentRadius = AI.AgentRadius, AgentHeight = AI.AgentHeight, AgentCanJump = true })
	end)
	local function compute(goal)
		nav.goal, nav.lastCompute = goal, os.clock()
		local ok = path and pcall(path.ComputeAsync, path, root.Position, goal)
		if ok and path.Status == Enum.PathStatus.Success then
			nav.waypoints, nav.index = path:GetWaypoints(), 2
		else
			nav.waypoints = nil -- straight MoveTo
		end
		nav.lastProgressAt, nav.lastPos = os.clock(), root.Position
	end
	function nav.moveTo(goal)
		local now = os.clock()
		if (root.Position - nav.lastPos).Magnitude > 0.5 then
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

local function nearestTarget(root, aggro, filter)
	local target, best = nil, aggro
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local troot = char and char:FindFirstChild("HumanoidRootPart")
		local thum = char and char:FindFirstChildOfClass("Humanoid")
		if troot and thum and thum.Health > 0 and (not filter or filter(player)) then
			local dist = (troot.Position - root.Position).Magnitude
			if dist < best then
				target, best = char, dist
			end
		end
	end
	return target, best
end

-- a bark everyone nearby hears: kind is "Alert", "Attack" or "Death"; the client picks the sound by type
local function bark(model, kind)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		Remotes.World:FireAllClients("Bark", root, model:GetAttribute("NPC"), kind)
	end
end
NPCs.Bark = bark

-- quiet: a traced swing already tells the clients its wind-up (Combat.Swing's "Swing"), so only the flash shows
local function telegraph(model, seconds, color, quiet)
	bark(model, "Attack")
	if not quiet then
		Combat.FX("Windup", model, seconds)
	end
	local warn = Instance.new("Highlight")
	warn.FillColor, warn.OutlineColor = color, color
	warn.FillTransparency = 0.3
	warn.Parent = model
	task.wait(seconds)
	warn:Destroy()
end

local function facing(root, troot)
	return CFrame.lookAt(root.Position, Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z))
end

-- opts: Parent (folder), Filter (player -> bool), Scale (health/damage multiplier), OnDied
function NPCs.Spawn(typeName, position, opts)
	opts = opts or {}
	local def = NPCs.Types[typeName]
	local scale = opts.Scale or 1
	local model, hum, root = NPCs.BuildRig(typeName, def)
	hum.MaxHealth = def.Health * scale
	hum.Health = hum.MaxHealth
	model:SetAttribute("NPC", typeName)
	for zone, rating in def.Armor or {} do
		model:SetAttribute(zone, rating) -- where plate is, for rounds (Combat hit zones; Weapons.Calibers)
	end
	CollectionService:AddTag(model, "NPC")
	if def.Boss then
		model:SetAttribute("Boss", true)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = opts.Parent or workspace
	root:SetNetworkOwner(nil)
	if model:GetAttribute("Rigged") then
		Rigs.Animate(model, hum)
		model:SetAttribute("Weapon", def.Weapon)
		HeldWeapons.Attach(model, Weapons.Held(def.Weapon))
	end

	local alive = true
	hum.Died:Connect(function()
		alive = false
		bark(model, "Death")
		Gore.OnDied(model)
		local _, killer = Combat.GetKiller(model)
		if killer then
			require(script.Parent.Builds).Earn(killer, def.Xp * scale)
			Quests.Progress(killer, "kill", typeName, 1)
		end
		-- every body can be looted, always: what it carried lies where it fell. A body whose pockets were already
		-- opened while it was down (Stealth.Search) leaves what is still in them, or nothing if they were emptied.
		local spoils
		if root:GetAttribute("Looted") then
			spoils = {}
		elseif root:GetAttribute("ContainerKey") then
			spoils = Loot.Contents(root)
		else
			spoils = Items.Roll(def.Loot)
			if next(spoils) == nil then
				spoils.Scrap = 1
			end
		end
		-- a gun in the spoils falls beside the body on its own, to be grabbed into the hand (server/Kit round 3)
		for id, n in spoils do
			local wdef = Weapons.Defs[id]
			if wdef and Weapons.IsGun(wdef) and n > 0 then
				local okDrop, dropped = pcall(require(script.Parent.Kit).DropGun, root.CFrame * CFrame.new(1.6, 0, -1), id)
				if okDrop and dropped then
					spoils[id] = if n > 1 then n - 1 else nil
				end
			end
		end
		Loot.Spawn(root.CFrame, spoils, { Label = typeName .. " spoils", Lifetime = 300, Devour = { Npc = true } })
		NPCs.Killed:Fire(typeName, model, killer)
		if opts.OnDied then
			opts.OnDied(model, killer)
		end
		task.wait(0.2)
		model:Destroy()
	end)
	model.Destroying:Connect(function()
		alive = false
	end)

	local family = (Weapons.Defs[def.Weapon or ""] or {}).Family or "Blunt"
	local step = 0
	local function strike(target, spec)
		local troot = target:FindFirstChild("HumanoidRootPart")
		if not troot then
			return
		end
		model:PivotTo(facing(root, troot))
		local color = if spec.Unblockable then Color3.fromRGB(255, 120, 0) else Color3.fromRGB(255, 40, 40)
		if not spec.Radius and not spec.Dash then
			-- a traced swing (shared/Swings): the telegraph is its wind-up; the blade is only dangerous along its
			-- arc while live, and it can be dodged, parried, or clashed by a blade meeting it
			step += 1
			task.spawn(telegraph, model, spec.Telegraph, color, true)
			local active = (spec.Active or def.Active or 12) / 60
			local recovery = (spec.Recovery or def.Recovery or 15) / 60
			Combat.Swing(model, {
				Damage = spec.Damage * scale, Posture = spec.Posture * scale, Windup = spec.Telegraph, Active = active, End = spec.Telegraph + active + recovery,
				Range = (spec.Range or def.Range) + 1, Knockback = spec.Knockback or def.Knockback or 15, Stun = spec.Stun or def.Stun, Type = def.Type,
				Unblockable = spec.Unblockable,
			}, { noStatScaling = true, label = "NPC", shape = Swings.ShapeFor(family, step, spec ~= nil and spec.Name ~= nil) })
			task.wait(spec.Telegraph + active + recovery)
			return
		end
		telegraph(model, spec.Telegraph, color)
		if not alive or hum.Health <= 0 or (Combat.IsStunned(model) and not def.Hyperarmor) then
			return -- staggered (or launched) during the wind-up: the strike is lost
		end
		if spec.Dash then
			local dir = (troot.Position - root.Position) * Vector3.new(1, 0, 1)
			if dir.Magnitude > 1 then
				root.AssemblyLinearVelocity = dir.Unit * spec.Dash + Vector3.new(0, 10, 0)
			end
			task.wait(0.25)
		end
		local hitOpts = { Posture = spec.Posture * scale, Knockback = spec.Knockback or def.Knockback or 15, Stun = spec.Stun or def.Stun, Type = def.Type, Unblockable = spec.Unblockable }
		if spec.Radius then
			Remotes.CombatEvent:FireAllClients("Burst", model, spec.Radius)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local proot = char and char:FindFirstChild("HumanoidRootPart")
				if proot and (proot.Position - root.Position).Magnitude <= spec.Radius then
					Combat.Damage(model, char, spec.Damage * scale, hitOpts)
				end
			end
		else
			local reach = (spec.Range or def.Range) + 1.5
			if (troot.Position - root.Position).Magnitude <= reach then
				Combat.Damage(model, target, spec.Damage * scale, hitOpts)
			end
		end
	end

	task.spawn(function()
		local lastAttack = 0
		local basic = { Telegraph = def.Telegraph, Damage = def.Damage, Posture = def.Posture, Range = def.Range }
		local hadTarget = false
		local nav = newNavigator(model, hum, root)
		local home = root.Position
		local side = if math.random() < 0.5 then 1 else -1 -- which way this body circles while it waits

		-- ===== spacing (Config.City.AI.Spacing) =====
		local SP = AI.Spacing
		local sp = SP and SP.Types[typeName]
		local mem = { swingId = -1, dodge = false, reactAt = 0, blockSeen = false, blockWaitUntil = 0, flipAt = 0 }
		local wallParams = RaycastParams.new()
		wallParams.FilterType = Enum.RaycastFilterType.Exclude
		wallParams.FilterDescendantsInstances = { model }
		-- face the target smoothly while spacing (the humanoid would otherwise face where it walks)
		local turner
		if sp then
			local att = Instance.new("Attachment")
			att.Name = "SpacingAttachment"
			att.Parent = root
			turner = Instance.new("AlignOrientation")
			turner.Name = "SpacingTurn"
			turner.Mode = Enum.OrientationAlignmentMode.OneAttachment
			turner.Attachment0 = att
			turner.Responsiveness = SP.TurnResponsiveness
			turner.MaxTorque = math.huge
			turner.Enabled = false
			turner.Parent = root
		end
		local function faceWhileSpacing(on, troot)
			if not turner then
				return
			end
			turner.Enabled = on
			hum.AutoRotate = not on
			if on and troot then
				local flat = Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z)
				if (flat - root.Position).Magnitude > 0.1 then
					turner.CFrame = CFrame.lookAt(root.Position, flat).Rotation
				end
			end
		end
		local function reachOf(target, swingReach)
			if swingReach and swingReach > 0 then
				return swingReach
			end
			local w = Weapons.Defs[target:GetAttribute("Weapon") or ""]
			local a = w and w.Attacks and w.Attacks[1]
			return (a and a.Range) or SP.DefaultReach
		end
		-- a short direct move (no pathfinding: a sidestep can't wait for a re-plan); a wall that way flips the circling side
		local function stepTo(goal)
			local d = (goal - root.Position) * Vector3.new(1, 0, 1)
			if d.Magnitude < 0.5 then
				return
			end
			if workspace:Raycast(root.Position, d.Unit * math.min(d.Magnitude, 8), wallParams) then
				side = -side
			end
			hum:MoveTo(Vector3.new(goal.X, root.Position.Y, goal.Z))
		end
		-- true when spacing has the body this tick
		local function spacing(target, troot, dist, canAttack, now)
			if not sp then
				return false
			end
			local phase, swingReach, blocking, stunned, swingId = Combat.Threat(target)
			local reach = reachOf(target, swingReach)
			local away = (root.Position - troot.Position) * Vector3.new(1, 0, 1)
			away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
			local function ring(radius, turn) -- a point on a ring round the target, `turn` radians this body's way
				local a = math.atan2(away.Z, away.X) + side * turn
				return troot.Position + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			end
			-- 1. your swing: read it after a reaction time and, if it decides to, slip out of reach to the side
			if phase == "Windup" or phase == "Active" then
				if not sp.Backoff then
					return false
				end
				if swingId ~= mem.swingId then
					mem.swingId, mem.dodge, mem.reactAt = swingId, math.random() < sp.Chance, now + sp.React
				end
				if mem.dodge and now >= mem.reactAt and dist <= reach + SP.BackoffMargin then
					stepTo(ring(reach + SP.BackoffMargin + 1, SP.StrafeTurn))
					return true
				end
				return false
			end
			-- 2. your recovery or a stagger: the opening. nothing holds it back
			if phase == "Recovery" or stunned then
				return false
			end
			-- 3. wounded: stay outside your reach and circle; it comes in on the openings above
			if sp.Wary and hum.Health / hum.MaxHealth < sp.Wary then
				local r = reach + SP.BackoffMargin + 2
				if dist > r + 4 then
					nav.moveTo(ring(r, 0))
				else
					stepTo(ring(r, SP.StrafeTurn))
				end
				return true
			end
			-- 4. your guard up: sometimes it circles a moment rather than swing into it
			if blocking and sp.WaitOutBlock and canAttack then
				if not mem.blockSeen then
					mem.blockSeen = true
					mem.blockWaitUntil = if math.random() < sp.WaitOutBlock then now + SP.BlockWait else 0
				end
				if now < mem.blockWaitUntil then
					stepTo(ring(math.max(def.Range, reach) + 1, SP.StrafeTurn))
					return true
				end
				return false
			end
			if not blocking then
				mem.blockSeen = false
			end
			-- 5. you charge it: give ground as a sidestep
			local thum = target:FindFirstChildOfClass("Humanoid")
			if sp.RushGive and not canAttack and thum and thum.MoveDirection.Magnitude > 0.5 and thum.MoveDirection:Dot(away) > 0.7 and dist < reach + 3 then
				stepTo(ring(dist + sp.RushGive, SP.StrafeTurn))
				return true
			end
			-- 6. its own cooldown, close in: circle you instead of standing still (and change direction now and then)
			if sp.Strafe and not canAttack and dist <= def.Range + AI.HoldGap + 3 then
				if now >= mem.flipAt then
					mem.flipAt = now + 1.5 + math.random() * 2.5
					if math.random() < 0.35 then
						side = -side
					end
				end
				stepTo(ring(math.max(def.Range, reach) + 0.5, SP.StrafeTurn))
				return true
			end
			return false
		end
		while alive and model.Parent and hum.Health > 0 do
			local now = os.clock()
			local target, dist = nearestTarget(root, def.Aggro * (if root.Position.Y > -100 then require(script.Parent.Sky).SightMult() else 1), opts.Filter) -- round 6: night, rain and fog
			if target and not opts.NoLeash and (root.Position - home).Magnitude > AI.Leash then
				target = nil -- leashed: give up and walk back
			end
			if target and not hadTarget then
				bark(model, "Alert") -- first sight of prey
			end
			hadTarget = target ~= nil
			if target then
				local troot = target.HumanoidRootPart
				local canAttack = now - lastAttack > def.Cooldown and Combat.CanAct(model)
				local move
				if canAttack and def.Moves then
					local roll = math.random()
					for _, m in def.Moves do
						roll -= m.Chance
						if roll <= 0 then
							move = m
							break
						end
					end
				end
				local holdRadius = def.Range + AI.HoldGap
				local hold = false
				local spaced = not move and spacing(target, troot, dist, canAttack, now)
				faceWhileSpacing(spaced, troot)
				if spaced then
					-- spacing has the body this tick (see spacing above)
				elseif move and (move.Dash or dist <= (move.Radius or def.Range) + 2) then
					-- a special move is this body's own turn: it does not wait for the ring
					lastAttack = now
					if def.Hyperarmor then
						Combat.AddBuff(model, "Hyperarmor", 0, move.Telegraph + 0.3)
					end
					nav.stop()
					strike(target, move)
					lastAttack = os.clock()
				elseif dist <= def.Range * 0.85 then
					if canAttack and claimSwing(target, model, now, def.Telegraph + 0.3 + AI.SwingGap) then
						lastAttack = now
						if def.Hyperarmor then
							Combat.AddBuff(model, "Hyperarmor", 0, def.Telegraph + 0.2)
						end
						nav.stop()
						basic.Damage = def.Damage * (model:GetAttribute("LimbDamage") or 1) -- an arm broken or lost (server/Dismember)
						strike(target, basic)
						lastAttack = os.clock()
					elseif canAttack then
						hold = true -- someone else is swinging: back out to the ring
					else
						nav.stop()
						model:PivotTo(facing(root, troot)) -- track the target through recovery
					end
				elseif dist <= holdRadius + 3 and othersSwinging(target, model, now) >= AI.MeleeAttackers then
					hold = true -- not your turn: don't crowd in
				else
					nav.moveTo(troot.Position)
				end
				if hold then
					nav.moveTo(holdSpot(model, root, troot, holdRadius, side))
				end
			else
				faceWhileSpacing(false)
				local spot = model:GetAttribute("Investigate")
				if opts.Idle and opts.Idle() then
					-- someone else walks this body while it has nobody to fight (server/Stealth)
				elseif spot and os.clock() < (model:GetAttribute("InvestigateUntil") or 0) and (spot - root.Position).Magnitude > 6 then
					nav.moveTo(spot)
				elseif spot then
					model:SetAttribute("Investigate", nil)
				elseif (root.Position - home).Magnitude > 8 then
					nav.moveTo(home) -- back to the post after a chase
				end
			end
			task.wait(AI.Tick)
		end
	end)
	return model
end

return NPCs
