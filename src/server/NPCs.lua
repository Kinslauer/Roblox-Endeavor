-- Minimal hostile NPCs ("Raiders"). Placeholder rig + simple chase/attack AI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)

local NPCs = {}

local TYPES = {
	Raider = { Health = 70, Speed = 13, Damage = 9, Range = 6, Cooldown = 1.1, Aggro = 90, Xp = 35, Loot = "Raider" },
}

local function buildRig(name, typeDef)
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

function NPCs.Spawn(typeName, position)
	local def = TYPES[typeName]
	local model, hum, root = buildRig(typeName, def)
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace

	hum.Died:Connect(function()
		local _, killer = Combat.GetKiller(model)
		if killer then
			Stats.AddXp(killer, def.Xp)
			Quests.Progress(killer, "kill", typeName, 1)
		end
		Loot.Spawn(root.CFrame, Items.Roll(def.Loot), { Label = typeName .. " spoils", Lifetime = 120 })
		task.wait(0.2)
		model:Destroy()
	end)

	task.spawn(function()
		local lastAttack = 0
		while model.Parent and hum.Health > 0 do
			local target, best = nil, def.Aggro
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local troot = char and char:FindFirstChild("HumanoidRootPart")
				local thum = char and char:FindFirstChildOfClass("Humanoid")
				if troot and thum and thum.Health > 0 then
					local dist = (troot.Position - root.Position).Magnitude
					if dist < best then
						target, best = char, dist
					end
				end
			end
			if target then
				local troot = target.HumanoidRootPart
				if best > def.Range * 0.8 then
					hum:MoveTo(troot.Position)
				elseif os.clock() - lastAttack > def.Cooldown then
					lastAttack = os.clock()
					model:PivotTo(CFrame.lookAt(root.Position, Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z)))
					Combat.Damage(model, target, def.Damage, { knockback = root.CFrame.LookVector * 15 })
				end
			end
			task.wait(0.2)
		end
	end)
	return model
end

return NPCs
