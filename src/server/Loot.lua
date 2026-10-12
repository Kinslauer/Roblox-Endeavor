-- Anything lootable in the world: player remains, NPC drops, supply crates.
-- Holding the prompt takes time, so stealing from a fresh kill is a risk.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)

local Loot = {}

-- opts: Label, Action, Hold, Lifetime, Color, Size
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

	prompt.Triggered:Connect(function(looter)
		if not part.Parent then
			return -- someone else got there first
		end
		part.Parent = nil
		Inventory.AddAll(looter, bundle)
		part:Destroy()
	end)

	part.Parent = workspace
	Debris:AddItem(part, opts.Lifetime or Config.CorpseLifetime)
	return part
end

return Loot
