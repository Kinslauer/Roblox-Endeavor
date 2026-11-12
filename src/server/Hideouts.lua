-- Hideouts: claim a site, build it from a tinkerer's bench into a workshop and a foundry, keep
-- gear in a vault, bring a crew in, and defend it. Repair and upgrades happen at the bench and
-- cost salvage. A compound draws NPC raids in proportion to how much it is worth, and any player
-- who breaches the walls can strip the vault; stolen gear takes its upgrades with it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local HideoutDefs = require(Shared.Hideout)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local City = require(script.Parent.City)
local Combat = require(script.Parent.Combat)
local Destruction = require(script.Parent.Destruction)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local Assets = require(Shared.Assets)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local Autonet = require(script.Parent.Autonet)

local HC = Config.Hideouts
local GROUND_TOP = 2
local Hideouts = {}
Hideouts.Raided = Instance.new("BindableEvent") -- (ownerUserId, byPlayer)

local folder
local sites = {} -- [index] = { Position, Owner = userId or nil, Built = Model or nil, Breaches = {}, Turret, Vault }
local rng = Random.new()

-- ===== helpers =====
local function dataOf(player)
	return PlayerData.Get(player)
end

local vaultBox -- defined with the vault code below; push() needs it earlier

local function hideoutOf(player)
	local data = dataOf(player)
	return data and data.Hideout
end

local function itemKind(id)
	local def = Items.Defs[id]
	return def and def.Type
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Puts an uploaded module mesh inside its collider part (same footprint, bottom on the slab) and
-- hides the part; prompts and physics stay on the part, so nothing else has to know.
local function dress(p, assetId)
	if ModelAssets.Spawn(assetId, p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0), "Mesh", p) then
		p.Transparency = 1
	end
	return p
end

local function hasMaterials(player, cost)
	for id, n in cost do
		if Inventory.Count(player, id) < n then
			return false, ("need %d %s"):format(n, Items.Defs[id] and Items.Defs[id].Name or id)
		end
	end
	return true
end

local function spend(player, cost)
	for id, n in cost do
		Inventory.Remove(player, id, n)
	end
end

-- The owner's profile is the source of truth. Members find it through the site.
local function ownerPlayer(site)
	return site.Owner and Players:GetPlayerByUserId(site.Owner)
end

local function siteOfPlayer(player)
	local data = dataOf(player)
	if not data then
		return nil
	end
	for _, site in sites do
		if site.Owner == player.UserId then
			return site, true
		end
		if site.Owner and site.Built then
			local owner = ownerPlayer(site)
			local h = owner and hideoutOf(owner)
			if h and table.find(h.Members, player.UserId) then
				return site, false
			end
		end
	end
	return nil
end

local function isMember(site, player)
	if site.Owner == player.UserId then
		return true
	end
	local owner = ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	return h ~= nil and table.find(h.Members, player.UserId) ~= nil
end

local function push(player)
	local site, owned = siteOfPlayer(player)
	local data = dataOf(player)
	if not data then
		return
	end
	local h = if site then hideoutOf(ownerPlayer(site) or player) else nil
	Remotes.Hideout:FireClient(player, {
		Site = site and site.Index, Owned = owned == true, Tier = h and h.Tier, TierName = h and HideoutDefs.Tiers[h.Tier].Name, Modules = h and h.Modules,
		Vault = h and h.Vault, VaultGrid = h and h.Modules.Vault and vaultBox(h) or nil, VaultCondition = h and h.VaultCondition, VaultUpgrades = h and h.VaultUpgrades, Members = h and h.Members, Name = h and h.Name,
		Condition = data.Condition, Upgrades = data.Upgrades, Defs = { Tiers = HideoutDefs.Tiers, Modules = HideoutDefs.Modules },
	})
end

-- ===== building the compound in the world =====
local function clearBuilt(site)
	if site.AutonetAt then
		Autonet.Unregister(site.AutonetAt)
		site.AutonetAt = nil
	end
	if site.Built then
		site.Built:Destroy()
		site.Built = nil
	end
	site.Breaches, site.Turret, site.Vault, site.Gate = {}, nil, nil, nil
end

local function build(site, h)
	clearBuilt(site)
	local model = Instance.new("Model")
	model.Name = "Hideout_" .. site.Index
	model:SetAttribute("Owner", site.Owner)
	local c, r = site.Position, HC.Radius
	-- floor slab and the bench: the bench is the interaction point for everything
	part(model, { Name = "Slab", Size = Vector3.new(r * 2, 1, r * 2), Position = c + Vector3.new(0, GROUND_TOP + 0.5, 0), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Concrete })
	local bench = dress(part(model, { Name = "Bench", Size = Vector3.new(6, 3, 2.5), Position = c + Vector3.new(0, GROUND_TOP + 2.5, 0), Color = Color3.fromRGB(110, 90, 60), Material = Enum.Material.WoodPlanks }), Assets.Hideout.Bench[h.Tier] or Assets.Hideout.Bench[1])
	local sign = part(model, { Size = Vector3.new(6, 1, 0.3), Position = c + Vector3.new(0, GROUND_TOP + 5, -1.5), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 170, 40), CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
	text.Text, text.TextColor3, text.Font = (h.Name ~= "" and h.Name or "Hideout") .. "  -  " .. HideoutDefs.Tiers[h.Tier].Name, Color3.new(0, 0, 0), Enum.Font.GothamBold
	text.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = HideoutDefs.Tiers[h.Tier].Name, "Workbench", 0.3
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 10, false, Enum.KeyCode.X
	prompt.Parent = bench
	prompt.Triggered:Connect(function(player)
		if isMember(site, player) then
			push(player)
			Remotes.Hideout:FireClient(player, nil, true) -- open the panel
		else
			Remotes.Announce:FireClient(player, "Not your bench. Breach the walls and strip the vault if you want what's here.", "Info")
		end
	end)

	if h.Modules.Walls then
		local gateTier = HideoutDefs.GateTier[h.Tier]
		local hgt = 9
		for _, side in { { Vector3.new(0, 0, r), Vector3.new(r * 2, hgt, 1.5) }, { Vector3.new(r, 0, 0), Vector3.new(1.5, hgt, r * 2) }, { Vector3.new(-r, 0, 0), Vector3.new(1.5, hgt, r * 2) } } do
			local wall = part(model, { Name = "Wall", Size = side[2], Position = c + side[1] + Vector3.new(0, GROUND_TOP + hgt / 2, 0), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Concrete })
			ModelAssets.Shell(Assets.Compound.WallPanel, wall, 10, model)
		end
		-- front wall with a gate opening
		local gw = 8
		for _, sign in { -1, 1 } do
			local wall = part(model, { Name = "Wall", Size = Vector3.new(r - gw / 2, hgt, 1.5), Position = c + Vector3.new(sign * (gw / 2 + (r - gw / 2) / 2), GROUND_TOP + hgt / 2, -r), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Concrete })
			ModelAssets.Shell(Assets.Compound.WallPanel, wall, 10, model)
		end
		ModelAssets.Spawn(Assets.Compound.GateFrame, CFrame.new(c + Vector3.new(0, GROUND_TOP, -r)), "GateFrame", model)
		site.Gate = Destruction.SpawnBreach(gateTier, CFrame.new(c + Vector3.new(0, GROUND_TOP + hgt / 2, -r)), Vector3.new(gw, hgt, 1.5))
		site.Gate:SetAttribute("Hideout", site.Index)
	end
	if h.Modules.Vault then
		local vault = dress(part(model, { Name = "Vault", Size = Vector3.new(5, 5, 4), Position = c + Vector3.new(12, GROUND_TOP + 3.5, 10), Color = Color3.fromRGB(40, 44, 60), Material = Enum.Material.DiamondPlate }), Assets.Hideout.Vault)
		local vp = Instance.new("ProximityPrompt")
		vp.ObjectText, vp.ActionText, vp.HoldDuration = "Vault", "Strip the vault", Config.LootHold * 3
		vp.MaxActivationDistance, vp.RequiresLineOfSight, vp.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		vp.Parent = vault
		vp.Triggered:Connect(function(player)
			Hideouts.StripVault(site, player)
		end)
		site.Vault = vault
	end
	if h.Modules.Bunks then
		dress(part(model, { Name = "Bunks", Size = Vector3.new(8, 3, 4), Position = c + Vector3.new(-12, GROUND_TOP + 2.5, 10), Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Fabric }), Assets.Hideout.Bunks)
	end
	if h.Modules.Generator then
		local gen = dress(part(model, { Name = "Generator", Size = Vector3.new(4, 3, 3), Position = c + Vector3.new(-12, GROUND_TOP + 2.5, -8), Color = Color3.fromRGB(120, 110, 40), Material = Enum.Material.Metal }), Assets.Hideout.Generator)
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 20, 1, Color3.fromRGB(255, 220, 120)
		light.Parent = gen
		-- round 6: it runs on fuel (server/Economy)
		local fp = Instance.new("ProximityPrompt")
		fp.ObjectText, fp.ActionText, fp.HoldDuration = "Generator", "Load fuel", 0.8
		fp.MaxActivationDistance, fp.RequiresLineOfSight, fp.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		fp.Parent = gen
		fp.Triggered:Connect(function(player)
			if isMember(site, player) then
				require(script.Parent.Economy).Refuel(player, site)
			end
		end)
	end
	if h.Modules.ProxyFrame then
		-- round 7: the humanoid drone on its rack (server/Proxy)
		local rack = part(model, { Name = "ProxyFrame", Size = Vector3.new(4, 7, 1), Position = c + Vector3.new(-6, GROUND_TOP + 4.5, 13), Color = Color3.fromRGB(54, 58, 64), Material = Enum.Material.DiamondPlate })
		local rp = Instance.new("ProximityPrompt")
		rp.ObjectText, rp.ActionText, rp.HoldDuration = "Proxy frame", "Link / unlink", 1.2
		rp.MaxActivationDistance, rp.RequiresLineOfSight, rp.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		rp.Parent = rack
		rp.Triggered:Connect(function(player)
			if isMember(site, player) then
				require(script.Parent.Proxy).Link(player)
			end
		end)
	end
	if h.Modules.Holding then
		-- round 7: where shackled bodies are kept (server/Thralls)
		part(model, { Name = "Holding", Size = Vector3.new(8, 7, 2), Position = c + Vector3.new(14, GROUND_TOP + 4.5, 12), Color = Color3.fromRGB(70, 66, 60), Material = Enum.Material.Metal, Transparency = 0.6 })
		task.defer(function()
			pcall(require(script.Parent.Thralls).Draw, site)
		end)
	end
	if h.Modules.Condenser then
		-- round 6: a still that pulls water and protein out of the air, real time, while you are away too
		local still = part(model, { Name = "Condenser", Size = Vector3.new(3, 5, 3), Position = c + Vector3.new(6, GROUND_TOP + 3.5, 12), Color = Color3.fromRGB(110, 130, 120), Material = Enum.Material.Metal })
		local glass = part(model, { Name = "CondenserGlass", Size = Vector3.new(2.2, 2.6, 0.2), Position = c + Vector3.new(6, GROUND_TOP + 4, 10.4), Color = Color3.fromRGB(150, 220, 200), Material = Enum.Material.Glass, Transparency = 0.4, CanCollide = false })
		local cp = Instance.new("ProximityPrompt")
		cp.ObjectText, cp.ActionText, cp.HoldDuration = "Condenser", "Drain", 0.6
		cp.MaxActivationDistance, cp.RequiresLineOfSight, cp.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		cp.Parent = still
		cp.Triggered:Connect(function(player)
			if isMember(site, player) then
				require(script.Parent.Economy).Drain(player, site)
			end
		end)
		local _ = glass
	end
	if h.Modules.Turret and h.Modules.Generator then
		local turret = dress(part(model, { Name = "Turret", Size = Vector3.new(2, 4, 2), Position = c + Vector3.new(12, GROUND_TOP + 3, -8), Color = Color3.fromRGB(40, 90, 140), Material = Enum.Material.Metal }), Assets.Hideout.Turret)
		local glow = Instance.new("PointLight")
		glow.Range, glow.Brightness, glow.Color = 14, 1.5, Color3.fromRGB(0, 220, 255)
		glow.Parent = turret
		site.Turret = turret
	end
	if h.Modules.Forge then
		dress(part(model, { Name = "Forge", Size = Vector3.new(5, 4, 5), Position = c + Vector3.new(0, GROUND_TOP + 3, 12), Color = Color3.fromRGB(90, 40, 30), Material = Enum.Material.Slate }), Assets.Hideout.Forge)
	end
	if h.Modules.Autonet then
		local bay = dress(part(model, { Name = "Autonet", Size = Vector3.new(6, 3, 3), Position = c + Vector3.new(12, GROUND_TOP + 2.5, 0), Color = Color3.fromRGB(60, 30, 36), Material = Enum.Material.Metal }), Assets.Hideout.Autonet)
		local lamp = Instance.new("PointLight")
		lamp.Range, lamp.Brightness, lamp.Color = 14, 1.2, Color3.fromRGB(255, 40, 60)
		lamp.Parent = bay
		local ap = Instance.new("ProximityPrompt")
		ap.ObjectText, ap.ActionText, ap.HoldDuration = "Autonet", "Get on the table", 0.5
		ap.MaxActivationDistance, ap.RequiresLineOfSight, ap.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		ap.Parent = bay
		ap.Triggered:Connect(function(player)
			if isMember(site, player) then
				Autonet.Use(player)
			else
				Remotes.Announce:FireClient(player, "Not your table.", "Info")
			end
		end)
		Autonet.Register(bay.Position)
		site.AutonetAt = bay.Position
	end
	if h.Modules.Computer then
		local console = dress(part(model, { Name = "Computer", Size = Vector3.new(5, 7, 2.5), Position = c + Vector3.new(-12, GROUND_TOP + 3.5, -10), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.Metal }), Assets.Loot.Terminal)
		local screen = part(model, { Name = "ComputerScreen", Size = Vector3.new(4, 3, 0.3), Position = c + Vector3.new(-12, GROUND_TOP + 4.2, -8.7), Color = Color3.fromRGB(40, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
		local lamp = Instance.new("PointLight")
		lamp.Range, lamp.Brightness, lamp.Color = 12, 1, Color3.fromRGB(60, 220, 140)
		lamp.Parent = screen
		local cp = Instance.new("ProximityPrompt")
		cp.ObjectText, cp.ActionText, cp.HoldDuration = "Computer", "Upload stack / log in", 0.4
		cp.MaxActivationDistance, cp.RequiresLineOfSight, cp.KeyboardKeyCode = 8, false, Enum.KeyCode.X
		cp.Parent = console
		cp.Triggered:Connect(function(player)
			if isMember(site, player) then
				require(script.Parent.Terminal).Open(player)
			else
				Remotes.Announce:FireClient(player, "Not your computer.", "Info")
			end
		end)
	end
	if h.Modules.Medbay then
		dress(part(model, { Name = "Medbay", Size = Vector3.new(5, 3, 3), Position = c + Vector3.new(-12, GROUND_TOP + 2.5, 0), Color = Color3.fromRGB(200, 210, 220), Material = Enum.Material.SmoothPlastic }), Assets.Hideout.Medbay)
	end
	model.Parent = folder
	site.Built = model
end

function Hideouts.Inside(site, position)
	local d = position - site.Position
	return math.abs(d.X) <= HC.Radius and math.abs(d.Z) <= HC.Radius
end

function Hideouts.SpawnCFrame(player)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if site and h and h.Modules.Bunks then
		return CFrame.new(site.Position + Vector3.new(-12 + rng:NextNumber(-3, 3), GROUND_TOP + 6, 14))
	end
	return nil
end

-- ===== the vault =====
-- The vault is a grid like the pack: tier sets its size, each level of shelving adds rows.
vaultBox = function(h)
	if h.VaultGrid == nil then
		h.VaultGrid = { Items = {} }
	end
	local tier = HideoutDefs.Tiers[h.Tier]
	local shelves = tonumber(h.Modules.Shelves) or 0
	local W, H = tier.VaultGrid[1], tier.VaultGrid[2] + shelves * (HideoutDefs.Modules.Shelves.RowsPerLevel or 0)
	-- older profiles kept counts only: lay them out once
	if #h.VaultGrid.Items == 0 and next(h.Vault or {}) then
		local box = { Items = h.VaultGrid.Items, W = W, H = H }
		for id, count in h.Vault do
			Inventory.PlaceIn(box, id, count)
		end
		h.Vault = Inventory.CountsOf(box)
	end
	return { Items = h.VaultGrid.Items, W = W, H = H }
end
Hideouts.VaultBox = vaultBox
local VAULT_CAP = function(h)
	local box = vaultBox(h)
	return box.W * box.H
end
Hideouts.VaultCap = VAULT_CAP

local function vaultCount(h)
	local n = 0
	for _, c in h.Vault do
		n += c
	end
	return n
end

-- Stripping is the brutal part: anyone (members included) can empty it; stolen gear carries its
-- condition and upgrades to the thief's inventory. The owner is told, and loses it all.
function Hideouts.StripVault(site, player)
	local owner = ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	local looterData = dataOf(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (h and looterData and hum and hum.Health > 0) or not site.Vault or not site.Vault.Parent then
		return
	end
	if site.Gate and site.Gate:FindFirstChild("Door") and not isMember(site, player) then
		Remotes.Announce:FireClient(player, "The gate is still standing. Breach it first.", "Info")
		return
	end
	if next(h.Vault) == nil then
		Remotes.Announce:FireClient(player, "The vault is empty.", "Info")
		return
	end
	local taken = {}
	for id, count in h.Vault do
		Inventory.Add(player, id, count)
		local c, u = h.VaultCondition[id], h.VaultUpgrades[id]
		if c then
			looterData.Condition[id] = math.min(looterData.Condition[id] or 100, c)
		end
		if u then
			looterData.Upgrades[id] = math.max(looterData.Upgrades[id] or 0, u)
		end
		table.insert(taken, ("%dx %s"):format(count, Items.Defs[id] and Items.Defs[id].Name or id))
	end
	h.Vault, h.VaultCondition, h.VaultUpgrades = {}, {}, {}
	h.VaultGrid = { Items = {} }
	Gear.Recompute(player)
	if not isMember(site, player) then
		Remotes.Announce:FireAllClients(("%s stripped %s's vault."):format(player.DisplayName, owner.DisplayName), "Kill")
		Hideouts.Raided:Fire(site.Owner, player)
	end
	Remotes.Announce:FireClient(player, "Took: " .. table.concat(taken, ", "), "Info")
	for _, p in Players:GetPlayers() do
		if isMember(site, p) then
			push(p)
		end
	end
end

local function vaultPut(player, id, count)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	local data = dataOf(player)
	if not (h and h.Modules.Vault and data and Items.Defs[id]) then
		return
	end
	count = math.clamp(count, 1, Inventory.Count(player, id))
	if count < 1 then
		return
	end
	-- place into the vault grid first; only what fits leaves the pack
	local box = vaultBox(h)
	local left = Inventory.PlaceIn(box, id, count)
	local moved = count - left
	if moved <= 0 then
		Remotes.Announce:FireClient(player, "No room in the vault for that.", "Info")
		return
	elseif left > 0 then
		Remotes.Announce:FireClient(player, ("Only %d fit in the vault."):format(moved), "Info")
	end
	count = moved
	-- the stack's condition/upgrade travels with it (kept at the worse condition if merging);
	-- read them before the removal, which clears them when the last one leaves
	local cond, up = data.Condition[id], data.Upgrades[id] or 0
	Inventory.Remove(player, id, count)
	h.Vault = Inventory.CountsOf(box)
	if cond then
		h.VaultCondition[id] = math.min(h.VaultCondition[id] or 100, cond)
	end
	if up > 0 then
		h.VaultUpgrades[id] = math.max(h.VaultUpgrades[id] or 0, up)
	end
	Gear.Recompute(player)
	push(player)
end

local function vaultTake(player, id, count)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	local data = dataOf(player)
	if not (h and data and h.Vault[id]) then
		return
	end
	count = math.clamp(count, 1, h.Vault[id])
	-- only what the pack takes leaves the vault
	local box = vaultBox(h)
	local _, left = Inventory.Add(player, id, count, true)
	count -= (left or 0)
	if count <= 0 then
		Remotes.Announce:FireClient(player, "No room in your pack for that.", "Info")
		return
	end
	Inventory.RemoveFrom(box, id, count)
	if h.VaultCondition[id] then
		data.Condition[id] = math.min(data.Condition[id] or 100, h.VaultCondition[id])
	end
	if h.VaultUpgrades[id] then
		data.Upgrades[id] = math.max(data.Upgrades[id] or 0, h.VaultUpgrades[id])
	end
	h.Vault = Inventory.CountsOf(box)
	if not h.Vault[id] then
		h.VaultCondition[id], h.VaultUpgrades[id] = nil, nil
	end
	Gear.Recompute(player)
	push(player)
end

-- Rearranging the vault grid (members only): the same rules as the pack.
local function vaultMove(player, index, x, y, rot)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if not (h and isMember(site, player)) then
		return
	end
	Inventory.MoveIn(vaultBox(h), index, x, y, rot)
	push(player)
end

-- ===== bench: repair and upgrade =====
local function repairCost(id, condition)
	local kind = itemKind(id)
	local table_ = HideoutDefs.RepairCost[kind]
	if not table_ then
		return nil
	end
	return HideoutDefs.ScaleCost(table_, (100 - condition) / 10)
end

local function repair(player, id)
	local site = siteOfPlayer(player)
	local data = dataOf(player)
	if not (site and data and Inventory.Count(player, id) > 0) then
		return
	end
	local condition = data.Condition[id] or 100
	if condition >= 100 then
		return
	end
	local cost = repairCost(id, condition)
	if not cost then
		return
	end
	local ok, why = hasMaterials(player, cost)
	if not ok then
		Remotes.Announce:FireClient(player, "Repair: " .. why, "Info")
		return
	end
	spend(player, cost)
	data.Condition[id] = 100
	Gear.Recompute(player)
	Remotes.Announce:FireClient(player, (Items.Defs[id].Name or id) .. " repaired.", "Info")
	push(player)
end

local function upgrade(player, id)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	local data = dataOf(player)
	local kind = itemKind(id)
	-- the worn pack is not in the grid but can be upgraded at the bench like anything else you own
	local owned = Inventory.Count(player, id) > 0 or data.Pack == id
	if not (h and data and kind and HideoutDefs.UpgradeCost[kind] and owned) then
		return
	end
	local level = (data.Upgrades[id] or 0) + 1
	local tier = HideoutDefs.Tiers[h.Tier]
	if level > tier.MaxUpgrade then
		Remotes.Announce:FireClient(player, ("A %s can only upgrade to +%d."):format(tier.Name, tier.MaxUpgrade), "Info")
		return
	end
	if level >= 2 and not h.Modules.Forge then
		Remotes.Announce:FireClient(player, "+2 and beyond need a Forge.", "Info")
		return
	end
	local cost = HideoutDefs.UpgradeCost[kind][level]
	local ok, why = hasMaterials(player, cost)
	if not ok then
		Remotes.Announce:FireClient(player, "Upgrade: " .. why, "Info")
		return
	end
	spend(player, cost)
	data.Upgrades[id] = level
	Gear.Recompute(player)
	if data.Pack == id then
		Inventory.Push(player) -- the grid just grew a row
	end
	Remotes.Announce:FireClient(player, ("%s is now +%d."):format(Items.Defs[id].Name or id, level), "Info")
	push(player)
end

-- ===== claiming, building, crew =====
local function claim(player, index)
	local data = dataOf(player)
	local site = sites[index]
	if not (data and site) or site.Owner then
		return
	end
	if data.Hideout.Plot ~= 0 then
		Remotes.Announce:FireClient(player, "You already have a hideout. Leave it first.", "Info")
		return
	end
	-- the Line 9 Manifest signs for the bay's consignment: no scrap, and the crates unpack into the computer
	local signed = Inventory.Count(player, "Manifest") > 0
	if signed then
		Inventory.Remove(player, "Manifest", 1)
	else
		local ok, why = hasMaterials(player, HideoutDefs.ClaimCost)
		if not ok then
			Remotes.Announce:FireClient(player, "Claim: " .. why, "Info")
			return
		end
		spend(player, HideoutDefs.ClaimCost)
	end
	data.Hideout.Plot, data.Hideout.Tier, data.Hideout.Modules = index, 1, if signed then { Computer = true } else {}
	data.Hideout.Consigned = signed or nil
	data.Hideout.Name = player.DisplayName .. "'s bench"
	site.Owner = player.UserId
	build(site, data.Hideout)
	Remotes.Announce:FireAllClients(("%s claimed a site in %s."):format(player.DisplayName, (City.DistrictAt(site.Position) or { Name = "the outskirts" }).Name), "Event")
	if site.Crates then
		site.Crates.Parent = nil
	end
	if signed then
		Remotes.Announce:FireClient(player, ("> LINE 9 . BAY %02d . . . CONSIGNMENT SIGNED"):format(site.Index), "Emergence")
		Remotes.World:FireClient(player, "Consigned", site.Position)
	end
	push(player)
end

local function buildModule(player, moduleId)
	local site, owned = siteOfPlayer(player)
	local h = hideoutOf(player)
	local def = type(moduleId) == "string" and HideoutDefs.Modules[moduleId]
	if not (site and owned and h and def) then
		return
	end
	local leveled = def.Levels ~= nil
	if h.Modules[moduleId] and not leveled then
		return
	end
	if leveled and (tonumber(h.Modules[moduleId]) or 0) >= def.Levels then
		Remotes.Announce:FireClient(player, def.Name .. " is at its top level.", "Info")
		return
	end
	local tier = HideoutDefs.Tiers[h.Tier]
	if def.Tier > h.Tier then
		Remotes.Announce:FireClient(player, ("%s needs a %s."):format(def.Name, HideoutDefs.Tiers[def.Tier].Name), "Info")
		return
	end
	local built = 0
	for id in h.Modules do
		if not (id == "Computer" and h.Consigned) then -- the consignment's computer came in the crates, not out of a slot
			built += 1
		end
	end
	if built >= tier.Modules and not (leveled and h.Modules[moduleId]) then
		Remotes.Announce:FireClient(player, ("A %s holds %d modules. Upgrade the workshop."):format(tier.Name, tier.Modules), "Info")
		return
	end
	local ok, why = hasMaterials(player, def.Cost)
	if not ok then
		Remotes.Announce:FireClient(player, "Build: " .. why, "Info")
		return
	end
	spend(player, def.Cost)
	h.Modules[moduleId] = if leveled then (tonumber(h.Modules[moduleId]) or 0) + 1 else true
	build(site, h)
	push(player)
end

local function upgradeTier(player)
	local site, owned = siteOfPlayer(player)
	local h = hideoutOf(player)
	if not (site and owned and h) then
		return
	end
	local nextTier = HideoutDefs.Tiers[h.Tier + 1]
	if not nextTier then
		return
	end
	local ok, why = hasMaterials(player, nextTier.Cost)
	if not ok then
		Remotes.Announce:FireClient(player, "Workshop: " .. why, "Info")
		return
	end
	spend(player, nextTier.Cost)
	h.Tier += 1
	build(site, h)
	Remotes.Announce:FireAllClients(("%s's hideout is now a %s."):format(player.DisplayName, nextTier.Name), "Event")
	push(player)
end

local function invite(player, name)
	local site, owned = siteOfPlayer(player)
	local h = hideoutOf(player)
	local target = Players:FindFirstChild(name)
	if not (site and owned and h and target and target ~= player) then
		return
	end
	local theirs = hideoutOf(target)
	if theirs and theirs.Plot ~= 0 then
		Remotes.Announce:FireClient(player, name .. " already has a hideout.", "Info")
		return
	end
	if not table.find(h.Members, target.UserId) then
		table.insert(h.Members, target.UserId)
	end
	Remotes.Announce:FireClient(target, player.DisplayName .. " made you part of their crew. Their bench and vault are yours to use.", "Info")
	push(player)
	push(target)
end

local function kick(player, userId)
	local site, owned = siteOfPlayer(player)
	local h = hideoutOf(player)
	if not (site and owned and h) then
		return
	end
	local i = table.find(h.Members, userId)
	if i then
		table.remove(h.Members, i)
		push(player)
		local target = Players:GetPlayerByUserId(userId)
		if target then
			push(target)
		end
	end
end

local function leave(player)
	local site, owned = siteOfPlayer(player)
	if not site then
		return
	end
	if owned then
		local h = hideoutOf(player)
		-- walking away abandons it; what is in the vault stays for whoever breaches it
		site.Owner = nil
		h.Plot, h.Modules, h.Members, h.Tier = 0, {}, {}, 1
		clearBuilt(site)
	else
		local owner = ownerPlayer(site)
		local h = owner and hideoutOf(owner)
		local i = h and table.find(h.Members, player.UserId)
		if i then
			table.remove(h.Members, i)
		end
	end
	push(player)
end

-- ===== raids on compounds =====
local function hostile(site, model)
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return not isMember(site, player)
	end
	return HC.TurretHostileNPC and model:GetAttribute("NPC") ~= nil
end

local function turretTick(site)
	local turret = site.Turret
	if not turret or not turret.Parent or (Hideouts.Powered and not Hideouts.Powered(site)) then
		return -- round 6: no fuel, no turret
	end
	local def = HideoutDefs.Modules.Turret
	local best, bestDist = nil, def.Range
	local candidates = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(candidates, p.Character)
		end
	end
	for _, npc in CollectionService:GetTagged("NPC") do
		table.insert(candidates, npc)
	end
	for _, model in candidates do
		local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
		local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and hostile(site, model) then
			local dist = (root.Position - turret.Position).Magnitude
			if dist < bestDist then
				best, bestDist = model, dist
			end
		end
	end
	if best then
		Combat.Damage(turret:FindFirstAncestorOfClass("Model") or best, best, def.Damage, { Posture = 6, Type = "Arc", Stun = 0.2 })
		Remotes.CombatEvent:FireAllClients("Bolt", turret, best.HumanoidRootPart.Position)
	end
end

local function alarmTick(site)
	local owner = ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if not (h and h.Modules.Alarm and h.Modules.Generator) or (Hideouts.Powered and not Hideouts.Powered(site)) then
		return
	end
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not isMember(site, p) and Hideouts.Inside(site, root.Position) then
			if os.clock() - (site.LastAlarm or 0) > 20 then
				site.LastAlarm = os.clock()
				for _, m in Players:GetPlayers() do
					if isMember(site, m) then
						Remotes.Announce:FireClient(m, ("ALARM: %s is inside your compound."):format(p.DisplayName), "Emergence")
					end
				end
			end
			return
		end
	end
end

local function medbayTick(site, dt)
	local owner = ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if not (h and h.Modules.Medbay) then
		return
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and isMember(site, p) and Hideouts.Inside(site, root.Position) then
			hum.Health = math.min(hum.MaxHealth, hum.Health + HC.MedbayHealPerSecond * dt)
			if Hideouts.HomeHeal then
				Hideouts.HomeHeal(char, dt) -- parts heal and broken bones mend at home (server/Medicine)
			end
		end
	end
end

-- NPC raid on a compound: raiders spawn at the gate, sized by tier and crew.
function Hideouts.NpcRaid(site)
	local owner = ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if not h then
		return
	end
	local crew = 1 + #h.Members
	local count = math.min(10, 2 + crew * HC.RaidersPerMember + h.Tier)
	for _, p in Players:GetPlayers() do
		if isMember(site, p) then
			Remotes.Announce:FireClient(p, "Raiders are hitting your compound.", "Emergence")
		end
	end
	local pack = { "Raider", "Raider", "Shocker", "Brute" }
	for i = 1, count do
		local a = rng:NextNumber(-0.6, 0.6)
		local pos = site.Position + Vector3.new(math.sin(a) * 50, GROUND_TOP + 3, -math.cos(a) * 50)
		NPCs.Spawn(pack[rng:NextInteger(1, if i <= 2 then 2 else #pack)], pos, { Scale = 1 + 0.15 * h.Tier })
	end
	-- raiders also work the gate: a few explosive hits so a tier-1 compound is not safe just because it has a wall
	if site.Gate then
		task.delay(20, function()
			if site.Gate and site.Gate:FindFirstChild("Door") then
				Destruction.HitBreach(site.Gate, 40 * count, "Explosive", nil)
			end
		end)
	end
end

-- ===== restore on join / release on leave =====
local function restore(player)
	local h = hideoutOf(player)
	if not h or h.Plot == 0 then
		return
	end
	local site = sites[h.Plot]
	if site and site.Owner == player.UserId and site.Built then
		return -- already standing (Lifecycle restores before the first spawn, the old hook runs again after it)
	end
	if not site or (site.Owner and site.Owner ~= player.UserId) then
		-- someone else holds the site in this server: the claim is lost (the vault contents stay in the profile)
		h.Plot = 0
		Remotes.Announce:FireClient(player, "Your site was taken while you were gone. Claim another.", "Info")
		return
	end
	site.Owner = player.UserId
	build(site, h)
end

local function release(player)
	for _, site in sites do
		if site.Owner == player.UserId then
			site.Owner = nil
			clearBuilt(site) -- the compound only stands while its owner is on this server
		end
	end
end

-- ===== the freight lifts (Line 9) =====
-- Every site is a consignment bay: a freight lift up from Line 9 in its back corner, its shaft standing over the
-- roofs, and a stack of crates stencilled STACK HARDWARE beside it while nobody holds the site. New bodies come
-- up these lifts (Hideouts.ArrivalCFrame); signing the Line 9 Manifest at a bay claims it and the crates unpack
-- into the computer (claim below). Nothing here says so: the crates, the stencil and the lift do.
local LIFT_AMBER, LIFT_DARK = Color3.fromRGB(255, 170, 40), Color3.fromRGB(46, 48, 54)

local function stencil(p, face, text, color, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.LightInfluence = face, 0.3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextScaled = UDim2.fromScale(1, 1), 1, true
	label.Text, label.TextColor3, label.Font = text, color, font or Enum.Font.Code
	label.Parent = gui
	return label
end

local function buildLift(site)
	local L = site.Position + HC.LiftOffset
	local model = Instance.new("Model")
	model.Name = "FreightLift_" .. site.Index
	local g = GROUND_TOP
	local h = HC.LiftHeight
	part(model, { Name = "LiftFloor", Size = Vector3.new(8, 0.6, 8), Position = L + Vector3.new(0, g + 0.3, 0), Color = Color3.fromRGB(70, 66, 58), Material = Enum.Material.DiamondPlate })
	part(model, { Name = "LiftWall", Size = Vector3.new(8.6, h, 0.6), Position = L + Vector3.new(0, g + h / 2, 4), Color = LIFT_DARK, Material = Enum.Material.CorrodedMetal })
	for _, sx in { -1, 1 } do
		part(model, { Name = "LiftWall", Size = Vector3.new(0.6, h, 8), Position = L + Vector3.new(sx * 4, g + h / 2, 0), Color = LIFT_DARK, Material = Enum.Material.CorrodedMetal })
	end
	part(model, { Name = "LiftRoof", Size = Vector3.new(8.6, 0.6, 8.6), Position = L + Vector3.new(0, g + h + 0.3, 0), Color = LIFT_DARK, Material = Enum.Material.Metal })
	local header = part(model, { Name = "LiftHeader", Size = Vector3.new(8.6, 2, 0.6), Position = L + Vector3.new(0, g + h - 1, -4), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Metal })
	stencil(header, Enum.NormalId.Front, ("LINE 9 . BAY %02d"):format(site.Index), LIFT_AMBER)
	-- hazard strip on the sill and a caged lamp inside
	part(model, { Name = "LiftSill", Size = Vector3.new(8, 0.2, 0.8), Position = L + Vector3.new(0, g + 0.65, -3.6), Color = Color3.fromRGB(230, 180, 40), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	local lamp = part(model, { Name = "LiftLamp", Size = Vector3.new(2, 0.3, 2), Position = L + Vector3.new(0, g + h - 0.3, 0), Color = LIFT_AMBER, Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = LIFT_AMBER, 14, 0.9
	light.Parent = lamp
	-- the shaft over the roofs, with a red light on top: the bays can be found by looking up
	local shaft = HC.LiftShaft
	part(model, { Name = "LiftShaft", Size = Vector3.new(5, shaft, 5), Position = L + Vector3.new(0, g + h + shaft / 2, 1), Color = LIFT_DARK, Material = Enum.Material.CorrodedMetal })
	local beacon = part(model, { Name = "LiftBeacon", Size = Vector3.new(1.2, 1.2, 1.2), Position = L + Vector3.new(0, g + h + shaft + 0.6, 1), Color = Color3.fromRGB(255, 40, 30), Material = Enum.Material.Neon, CanCollide = false })
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = beacon.Color, 10, 1
	glow.Parent = beacon
	-- the consignment, while the bay is unsigned
	local crates = Instance.new("Model")
	crates.Name = "Consignment"
	local n = 0
	for _, spot in { Vector3.new(-8.5, 1.5, 1.5), Vector3.new(-8.5, 1.5, -2), Vector3.new(-8.5, 4.5, 0) } do
		n += 1
		local crate = part(crates, { Name = "StackCrate", Size = Vector3.new(3, 3, 3), Position = L + spot + Vector3.new(0, g, 0), Color = Color3.fromRGB(60, 66, 60), Material = Enum.Material.Metal })
		if ModelAssets.Spawn(Assets.Loot.CrateA, crate.CFrame * CFrame.new(0, -1.5, 0), "Mesh", crate) then
			crate.Transparency = 1
		end
		stencil(crate, Enum.NormalId.Front, ("STACK HARDWARE\nLINE 9 . %02d/40"):format((site.Index * 3 + n) % 40 + 1), Color3.fromRGB(235, 225, 200))
	end
	crates.Parent = model
	model.Parent = folder
	site.Lift, site.Crates = model, crates
	site.LiftCFrame = CFrame.lookAt(L + Vector3.new(0, g + 3.6, 1), L + Vector3.new(0, g + 3.6, -10))
	return model
end

-- Where a body comes up: its own (or its crew's) bay, else a free bay, else nil.
function Hideouts.ArrivalCFrame(player)
	local site = siteOfPlayer(player)
	if site and site.LiftCFrame then
		return site.LiftCFrame, site
	end
	local free = {}
	for _, s in sites do
		if not s.Owner and s.LiftCFrame then
			table.insert(free, s)
		end
	end
	if #free == 0 then
		return nil
	end
	local pick = free[rng:NextInteger(1, #free)]
	return pick.LiftCFrame, pick
end

-- Where an uploaded stack reboots: in front of the computer of the hideout it belongs to.
function Hideouts.RebootCFrame(player)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if not (site and site.Built and h and h.Modules.Computer) then
		return nil
	end
	local c = site.Position
	return CFrame.lookAt(c + Vector3.new(-12, GROUND_TOP + 3, -4), c + Vector3.new(-12, GROUND_TOP + 3, -12))
end

local function makeSiteMarker(site)
	local post = part(folder, { Name = "SitePost", Size = Vector3.new(1, 6, 1), Position = site.Position + Vector3.new(0, GROUND_TOP + 3, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 170, 40), CanCollide = false })
	post:SetAttribute("Site", site.Index)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Open site", "Claim (10 scrap)", 2
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 10, false, Enum.KeyCode.X
	prompt.Parent = post
	prompt.Triggered:Connect(function(player)
		claim(player, site.Index)
	end)
	site.Marker = post
	buildLift(site)
	-- hide the marker (and the unsigned consignment) while the site is owned
	task.spawn(function()
		while post.Parent do
			post.Transparency = if site.Owner then 1 else 0
			prompt.Enabled = site.Owner == nil
			if site.Crates then
				site.Crates.Parent = if site.Owner then nil else site.Lift
			end
			task.wait(2)
		end
	end)
end

function Hideouts.Init()
	folder = Instance.new("Folder")
	folder.Name = "Hideouts"
	folder.Parent = workspace
	-- sites: the corners of each district plus the outskirts
	local spots = {}
	for _, d in City.Districts do
		if d.Outer then
			continue -- the core's sites keep their old numbers (saved hideouts point at them)
		end
		local s = d.Size / 2 - 40
		table.insert(spots, d.Center + Vector3.new(s, 0, -s))
		table.insert(spots, d.Center + Vector3.new(-s, 0, s))
	end
	for _, q in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		table.insert(spots, Vector3.new(q[1] * 380, 0, q[2] * 380))
	end
	for i = 1, math.min(HC.Sites, #spots) do
		sites[i] = { Index = i, Position = spots[i], Breaches = {} }
		makeSiteMarker(sites[i])
	end

	Net.On("HideoutClaim", { rate = 1, burst = 2, args = { "int" } }, claim)
	Net.On("HideoutBuild", { rate = 2, burst = 4, args = { "string" } }, buildModule)
	Net.On("HideoutUpgrade", { rate = 1, burst = 2 }, upgradeTier)
	Net.On("HideoutRepair", { rate = 3, burst = 6, args = { "string" } }, repair)
	Net.On("ItemUpgrade", { rate = 2, burst = 4, args = { "string" } }, upgrade)
	Net.On("VaultPut", { rate = 4, burst = 8, args = { "string", "int" } }, vaultPut)
	Net.On("VaultTake", { rate = 4, burst = 8, args = { "string", "int" } }, vaultTake)
	Net.On("VaultMove", { rate = 10, burst = 20, args = { "int", "int", "int", "int" } }, vaultMove)
	Net.On("HideoutInvite", { rate = 1, burst = 2, args = { "string" } }, invite)
	Net.On("HideoutKick", { rate = 1, burst = 2, args = { "int" } }, kick)
	Net.On("HideoutLeave", { rate = 1, burst = 2 }, leave)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Once(function()
			task.wait(1)
			restore(player)
			push(player)
		end)
	end)
	Players.PlayerRemoving:Connect(release)

	-- defenses and comfort tick
	task.spawn(function()
		while true do
			task.wait(1.1)
			for _, site in sites do
				if site.Owner then
					turretTick(site)
					alarmTick(site)
					medbayTick(site, 1.1)
				end
			end
		end
	end)
	-- NPC raid pressure: each owned compound rolls on its own clock, faster at higher tiers
	task.spawn(function()
		while true do
			task.wait(30)
			for _, site in sites do
				local owner = ownerPlayer(site)
				local h = owner and hideoutOf(owner)
				if h and h.Modules.Vault then
					local interval = HC.RaidBaseInterval / HideoutDefs.Tiers[h.Tier].RaidWeight
					if rng:NextNumber() < 30 / interval then
						Hideouts.NpcRaid(site)
					end
				end
			end
		end
	end)
end

-- Round 5 (server/Builds): where earnings are banked and chips are fitted.
-- AtBay: inside your own (or your crew's) built bay, or, while you have no bay, at the freight lift of any free one.
function Hideouts.AtBay(player, position)
	local site = siteOfPlayer(player)
	if site then
		return site.Built ~= nil and Hideouts.Inside(site, position)
	end
	for _, s in sites do
		if not s.Owner and s.LiftCFrame and (s.LiftCFrame.Position - position).Magnitude <= Config.Builds.Bank.LiftReach then
			return true
		end
	end
	return false
end

-- AtBench: close to the bench of your own (or your crew's) built bay.
function Hideouts.AtBench(player, position)
	local site = siteOfPlayer(player)
	local bench = site and site.Built and site.Built:FindFirstChild("Bench")
	return bench ~= nil and (bench.Position - position).Magnitude <= 12
end
Hideouts.SiteOf = siteOfPlayer

-- Builds the bay's model again from its modules (tools and tests; build() clears the old one).
function Hideouts.Rebuild(player)
	local site = siteOfPlayer(player)
	local owner = site and ownerPlayer(site)
	local h = owner and hideoutOf(owner)
	if h then
		build(site, h)
	end
	return site
end

Hideouts.Sites = sites
Hideouts.Restore = restore
Hideouts.Push = push
return Hideouts
