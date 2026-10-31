-- Hostile NPCs. Data-driven types with telegraphed attacks so parry/dodge timing is readable.
-- Rigs are placeholder blocks until real models exist (swap NPCs.BuildRig).
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local Gore = require(script.Parent.Gore)
local Rigs = require(script.Parent.Rigs)
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

-- Telegraph: seconds of red flash before the hit lands (dodge/parry window).
-- Moves: optional list of special attacks { Name, Chance, Telegraph, Damage, Posture, Radius?, Knockback, Stun?, Unblockable? }
NPCs.Types = {
	Raider = { Health = 70, Speed = 13, Damage = 9, Posture = 10, Range = 6, Cooldown = 1.4, Telegraph = 0.45, Aggro = 90, Xp = 35, Loot = "Raider",
		Color = Color3.fromRGB(110, 40, 40), Size = Vector3.new(2, 5, 1), Weapon = "PipeClub" },
	Brute = { Health = 220, Speed = 10, Damage = 22, Posture = 30, Range = 7, Cooldown = 2.4, Telegraph = 0.8, Aggro = 80, Xp = 90, Loot = "Raider",
		Color = Color3.fromRGB(90, 60, 30), Size = Vector3.new(3, 6.5, 1.6), Knockback = 40, Hyperarmor = true, Weapon = "Sledge" },
	Shocker = { Health = 90, Speed = 15, Damage = 12, Posture = 8, Range = 9, Cooldown = 1.6, Telegraph = 0.5, Aggro = 110, Xp = 60, Loot = "Raider",
		Color = Color3.fromRGB(40, 90, 140), Size = Vector3.new(2, 5, 1), Type = "Arc", Stun = 0.6, Weapon = "ShockBaton" },
	Warden = { Health = 900, Speed = 11, Damage = 26, Posture = 35, Range = 8, Cooldown = 2.0, Telegraph = 0.7, Aggro = 140, Xp = 600, Loot = "Supply",
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
		local model, hum, root = Rigs.Build(rigId, name)
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

local function telegraph(model, seconds, color)
	bark(model, "Attack")
	Combat.FX("Windup", model, seconds)
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
		HeldWeapons.Attach(model, def.Weapon)
	end

	local alive = true
	hum.Died:Connect(function()
		alive = false
		bark(model, "Death")
		Gore.OnDied(model)
		local _, killer = Combat.GetKiller(model)
		if killer then
			Stats.AddXp(killer, math.floor(def.Xp * scale + 0.5))
			Quests.Progress(killer, "kill", typeName, 1)
		end
		local spoils = Items.Roll(def.Loot)
		if next(spoils) == nil then
			spoils.Scrap = 1
		end
		Loot.Spawn(root.CFrame, spoils, { Label = typeName .. " spoils", Lifetime = 120, Devour = { Npc = true } })
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

	local function strike(target, spec)
		local troot = target:FindFirstChild("HumanoidRootPart")
		if not troot then
			return
		end
		model:PivotTo(facing(root, troot))
		telegraph(model, spec.Telegraph, if spec.Unblockable then Color3.fromRGB(255, 120, 0) else Color3.fromRGB(255, 40, 40))
		if not alive or hum.Health <= 0 then
			return
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
		while alive and model.Parent and hum.Health > 0 do
			local now = os.clock()
			local target, dist = nearestTarget(root, def.Aggro, opts.Filter)
			if target and (root.Position - home).Magnitude > AI.Leash then
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
				if move and (move.Dash or dist <= (move.Radius or def.Range) + 2) then
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
				local spot = model:GetAttribute("Investigate")
				if spot and os.clock() < (model:GetAttribute("InvestigateUntil") or 0) and (spot - root.Position).Magnitude > 6 then
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
