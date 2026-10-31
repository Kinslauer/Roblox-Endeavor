-- Anything lootable in the world: player remains, NPC drops, supply crates.
-- Holding the prompt takes time, so stealing from a fresh kill is a risk.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Net = require(script.Parent.Common.Net)
local Items = require(ReplicatedStorage.Shared.Items)
local PlayerData = require(script.Parent.Common.PlayerData)
local Stats = require(script.Parent.Stats)

local D = Config.Devour

local Assets = require(ReplicatedStorage.Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)

local Loot = {}

-- Every lootable is a container: a small grid the looter searches and drags from. Keyed by a
-- counter; the part carries the key as an attribute.
local containers = {} -- [key] = { Part, Box, Meta, Opts }
local nextKey = 0

local function containerFor(bundle)
	local cellsNeeded = 0
	for id, count in bundle do
		local shape = Items.Shape(id)
		cellsNeeded += math.ceil(count / shape.Stack) * shape.Size[1] * shape.Size[2]
	end
	local W = 6
	local H = math.max(2, math.ceil(cellsNeeded / W) + 1)
	for _ = 1, 6 do
		local box = { Items = {}, W = W, H = H }
		local ok = true
		for id, count in bundle do
			if Inventory.PlaceIn(box, id, count) > 0 then
				ok = false
			end
		end
		if ok then
			return box
		end
		H += 2
	end
	return { Items = {}, W = W, H = H }
end

local function snapshot(box)
	return { W = box.W, H = box.H, Items = box.Items }
end

-- Takes stack `index` (0 = everything) from container `key` into the player's pack, what fits.
function Loot.Take(player, key, index)
	local c = containers[key]
	if not c or not c.Part.Parent then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - c.Part.Position).Magnitude > 14 or not c.CanTake(player) then
		return
	end
	local profile = PlayerData.Get(player)
	local function applyMeta(id)
		if c.Meta and c.Meta.Condition and profile and profile.Inventory[id] then
			profile.Condition[id] = math.min(profile.Condition[id] or 100, c.Meta.Condition)
			if c.Meta.Upgrades then
				profile.Upgrades[id] = math.max(profile.Upgrades[id] or 0, c.Meta.Upgrades)
			end
		end
	end
	local indices = {}
	if index == 0 then
		for i = #c.Box.Items, 1, -1 do
			table.insert(indices, i)
		end
	elseif c.Box.Items[index] then
		table.insert(indices, index)
	end
	local blocked = false
	for _, i in indices do
		local item = c.Box.Items[i]
		if item then
			local _, left = Inventory.Add(player, item.Id, item.Count, true)
			local taken = item.Count - (left or 0)
			if taken > 0 then
				applyMeta(item.Id)
				item.Count -= taken
				if item.Count <= 0 then
					table.remove(c.Box.Items, i)
				end
			else
				blocked = true
			end
		end
	end
	if blocked then
		Remotes.Announce:FireClient(player, "No room in your pack for the rest.", "Info")
	end
	if #c.Box.Items == 0 then
		containers[key] = nil
		Remotes.World:FireClient(player, "ContainerClose", key)
		c.Part:Destroy()
	else
		Remotes.World:FireClient(player, "Container", key, snapshot(c.Box), c.Opts.Label or "Remains")
	end
end

-- What is left in a container, as counts (the tutorial and tests read this).
function Loot.Contents(part)
	local c = containers[part:GetAttribute("ContainerKey")]
	return c and Inventory.CountsOf(c.Box) or {}
end

-- What the grid cannot hold lands at the player's feet as a small stash.
Inventory.Overflow = function(player, bundle, meta)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cf = CFrame.new(root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2, 0))
	Loot.Spawn(cf, bundle, { Label = "Dropped gear", Action = "Pick up", Hold = 0.5, Lifetime = 600, Size = Vector3.new(2, 1, 2), Meta = meta })
end

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
	-- the look: crates for caches and drops, a stash bag for remains, spoils and salvage
	local label = opts.Label or "Remains"
	local meshId = if opts.Mesh then Assets.Loot[opts.Mesh] elseif label:find("Vault") then Assets.Loot.CrateB elseif label:find("Cache") or label:find("Crate") or label:find("Drop") or label:find("Locker") then Assets.Loot.CrateA else Assets.Loot.Stash
	if meshId and ModelAssets.Spawn(meshId, part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0), "Mesh", part) then
		part.Transparency = 1
	end

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

	-- the container: searching opens its grid on the looter's screen; they drag out what they want
	nextKey += 1
	local key = tostring(nextKey)
	part:SetAttribute("ContainerKey", key)
	containers[key] = { Part = part, Box = containerFor(bundle), Meta = opts.Meta, Opts = opts, CanTake = canTake }
	part.Destroying:Connect(function()
		containers[key] = nil
	end)
	prompt.Triggered:Connect(function(looter)
		if not canTake(looter) then
			return
		end
		local c = containers[key]
		if c then
			Remotes.World:FireClient(looter, "Container", key, snapshot(c.Box), opts.Label or "Remains")
		end
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

function Loot.Init()
	Net.On("ContainerTake", { rate = 10, burst = 20, args = { "string", "int" } }, Loot.Take)
end

return Loot
