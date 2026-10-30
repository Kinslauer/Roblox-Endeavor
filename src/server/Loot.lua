-- Anything lootable in the world: player remains, NPC drops, supply crates.
-- Holding the prompt takes time, so stealing from a fresh kill is a risk.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Stats = require(script.Parent.Stats)

local D = Config.Devour

local Loot = {}

-- opts: Label, Action, Hold, Lifetime, Color, Size, OwnerUserId (the dead player: locked out for OwnerLockout seconds), Devour ({ Level = n } for a conduit's remains, { Npc = true } for NPCs)
function Loot.Spawn(cframe, bundle, opts)
	opts = opts or {}
	if next(bundle) == nil then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "Lootable"
	part.Size = opts.Size or Vector3.new(3, 1.2, 3)
	part.Color = opts.Color or Color3.fromRGB(70, 60, 60)
	part.Material = Enum.Material.Metal
	part.Anchored = false
	part.CFrame = cframe
	part:SetAttribute("Label", opts.Label or "Remains")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = opts.Label or "Remains"
	prompt.ActionText = opts.Action or "Loot"
	prompt.HoldDuration = opts.Hold or Config.LootHold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.X -- E is flicker
	prompt.Parent = part

	local spawnedAt = os.clock()
	local function canTake(who)
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if not part.Parent or not hum or hum.Health <= 0 then
			return false -- gone, or the taker is dead (a corpse must not loot its own remains)
		end
		if opts.OwnerUserId == who.UserId and os.clock() - spawnedAt < Config.OwnerLockout then
			return false
		end
		return true
	end

	prompt.Triggered:Connect(function(looter)
		if not canTake(looter) then
			return
		end
		part.Parent = nil
		Inventory.AddAll(looter, bundle)
		part:Destroy()
	end)

	if opts.Devour then
		-- Devour (M): consume the remains for cursed energy instead of looting them. The loot is
		-- destroyed, so it is a real choice - and it takes longer, so it is a real risk.
		local devour = Instance.new("ProximityPrompt")
		devour.ObjectText, devour.ActionText = opts.Label or "Remains", "Devour"
		devour.HoldDuration, devour.MaxActivationDistance, devour.RequiresLineOfSight = D.Hold, 8, false
		devour.KeyboardKeyCode, devour.UIOffset = Enum.KeyCode.M, Vector2.new(0, 60)
		devour.Parent = part
		devour.Triggered:Connect(function(eater)
			if not canTake(eater) then
				return
			end
			local char, hum = eater.Character, eater.Character:FindFirstChildOfClass("Humanoid")
			part.Parent = nil
			local xp = if opts.Devour.Npc then D.NpcXp else D.XpBase + D.XpPerLevel * (opts.Devour.Level or 1)
			Stats.AddXp(eater, xp)
			char:SetAttribute("Charge", char:GetAttribute("MaxCharge"))
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * D.HealFraction)
			Remotes.CombatEvent:FireAllClients("Devour", char)
			Remotes.Announce:FireClient(eater, ("Devoured: +%d xp, charge restored."):format(xp), "Info")
			part:Destroy()
		end)
	end

	part.Parent = workspace
	part:SetNetworkOwner(nil) -- clients must not be able to drag loot around
	Debris:AddItem(part, opts.Lifetime or Config.CorpseLifetime)
	return part
end

return Loot
