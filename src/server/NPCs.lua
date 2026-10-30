-- Hostile NPCs. Data-driven types with telegraphed attacks so parry/dodge timing is readable.
-- Rigs are placeholder blocks until real models exist (swap NPCs.BuildRig).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)

local NPCs = {}
NPCs.Killed = Instance.new("BindableEvent") -- (typeName, model, killerPlayer?)

-- Breaches and explosions are loud: idle NPCs within `radius` walk over to look.
function NPCs.Alert(position, radius)
	for _, model in workspace:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("NPC") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= radius then
				model:SetAttribute("Investigate", position)
				model:SetAttribute("InvestigateUntil", os.clock() + 15)
			end
		end
	end
end

-- Telegraph: seconds of red flash before the hit lands (dodge/parry window).
-- Moves: optional list of special attacks { Name, Chance, Telegraph, Damage, Posture, Radius?, Knockback, Stun?, Unblockable? }
NPCs.Types = {
	Raider = { Health = 70, Speed = 13, Damage = 9, Posture = 10, Range = 6, Cooldown = 1.4, Telegraph = 0.45, Aggro = 90, Xp = 35, Loot = "Raider",
		Color = Color3.fromRGB(110, 40, 40), Size = Vector3.new(2, 5, 1) },
	Brute = { Health = 220, Speed = 10, Damage = 22, Posture = 30, Range = 7, Cooldown = 2.4, Telegraph = 0.8, Aggro = 80, Xp = 90, Loot = "Raider",
		Color = Color3.fromRGB(90, 60, 30), Size = Vector3.new(3, 6.5, 1.6), Knockback = 40, Hyperarmor = true },
	Shocker = { Health = 90, Speed = 15, Damage = 12, Posture = 8, Range = 9, Cooldown = 1.6, Telegraph = 0.5, Aggro = 110, Xp = 60, Loot = "Raider",
		Color = Color3.fromRGB(40, 90, 140), Size = Vector3.new(2, 5, 1), Type = "Arc", Stun = 0.6 },
	Warden = { Health = 900, Speed = 11, Damage = 26, Posture = 35, Range = 8, Cooldown = 2.0, Telegraph = 0.7, Aggro = 140, Xp = 600, Loot = "Supply",
		Color = Color3.fromRGB(150, 30, 60), Size = Vector3.new(3.5, 8, 2), Knockback = 45, Hyperarmor = true, Boss = true,
		Moves = {
			{ Name = "Slam", Chance = 0.35, Telegraph = 1.1, Damage = 40, Posture = 60, Radius = 14, Knockback = 70, Unblockable = true, Stun = 1.0 },
			{ Name = "Lunge", Chance = 0.25, Telegraph = 0.6, Damage = 30, Posture = 40, Dash = 60, Knockback = 50 },
		},
	},
}

function NPCs.BuildRig(name, typeDef)
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

local function telegraph(model, seconds, color)
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
	if def.Boss then
		model:SetAttribute("Boss", true)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = opts.Parent or workspace
	root:SetNetworkOwner(nil)

	local alive = true
	hum.Died:Connect(function()
		alive = false
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
		while alive and model.Parent and hum.Health > 0 do
			local target, dist = nearestTarget(root, def.Aggro, opts.Filter)
			if target then
				local troot = target.HumanoidRootPart
				local t = os.clock()
				if t - lastAttack > def.Cooldown then
					local move
					if def.Moves then
						local roll = math.random()
						for _, m in def.Moves do
							roll -= m.Chance
							if roll <= 0 then
								move = m
								break
							end
						end
					end
					if move and (move.Dash or dist <= (move.Radius or def.Range) + 2) then
						lastAttack = t
						if def.Hyperarmor then
							Combat.AddBuff(model, "Hyperarmor", 0, move.Telegraph + 0.3)
						end
						strike(target, move)
						lastAttack = os.clock()
					elseif dist <= def.Range then
						lastAttack = t
						if def.Hyperarmor then
							Combat.AddBuff(model, "Hyperarmor", 0, def.Telegraph + 0.2)
						end
						strike(target, basic)
						lastAttack = os.clock()
					else
						hum:MoveTo(troot.Position)
					end
				elseif dist > def.Range * 0.8 then
					hum:MoveTo(troot.Position)
				end
			else
				local spot = model:GetAttribute("Investigate")
				if spot and os.clock() < (model:GetAttribute("InvestigateUntil") or 0) and (spot - root.Position).Magnitude > 6 then
					hum:MoveTo(spot)
				elseif spot then
					model:SetAttribute("Investigate", nil)
				end
			end
			task.wait(0.2)
		end
	end)
	return model
end

return NPCs
