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
		Vault = h and h.Vault, VaultCondition = h and h.VaultCondition, VaultUpgrades = h and h.VaultUpgrades, Members = h and h.Members, Name = h and h.Name,
		Condition = data.Condition, Upgrades = data.Upgrades, Defs = { Tiers = HideoutDefs.Tiers, Modules = HideoutDefs.Modules },
	})
end

-- ===== building the compound in the world =====
local function clearBuilt(site)
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
local VAULT_CAP = function(h)
	return HideoutDefs.Tiers[h.Tier].Vault
end

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
	if count < 1 or vaultCount(h) + count > VAULT_CAP(h) then
		Remotes.Announce:FireClient(player, "The vault is full.", "Info")
		return
	end
	-- the stack's condition/upgrade travels with it (kept at the worse condition if merging);
	-- read them before the removal, which clears them when the last one leaves
	local cond, up = data.Condition[id], data.Upgrades[id] or 0
	Inventory.Remove(player, id, count)
	h.Vault[id] = (h.Vault[id] or 0) + count
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
	Inventory.Add(player, id, count)
	if h.VaultCondition[id] then
		data.Condition[id] = math.min(data.Condition[id] or 100, h.VaultCondition[id])
	end
	if h.VaultUpgrades[id] then
		data.Upgrades[id] = math.max(data.Upgrades[id] or 0, h.VaultUpgrades[id])
	end
	h.Vault[id] -= count
	if h.Vault[id] <= 0 then
		h.Vault[id], h.VaultCondition[id], h.VaultUpgrades[id] = nil, nil, nil
	end
	Gear.Recompute(player)
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
	if not (h and data and kind and HideoutDefs.UpgradeCost[kind] and Inventory.Count(player, id) > 0) then
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
	local ok, why = hasMaterials(player, HideoutDefs.ClaimCost)
	if not ok then
		Remotes.Announce:FireClient(player, "Claim: " .. why, "Info")
		return
	end
	spend(player, HideoutDefs.ClaimCost)
	data.Hideout.Plot, data.Hideout.Tier, data.Hideout.Modules = index, 1, {}
	data.Hideout.Name = player.DisplayName .. "'s bench"
	site.Owner = player.UserId
	build(site, data.Hideout)
	Remotes.Announce:FireAllClients(("%s claimed a site in %s."):format(player.DisplayName, (City.DistrictAt(site.Position) or { Name = "the outskirts" }).Name), "Event")
	push(player)
end

local function buildModule(player, moduleId)
	local site, owned = siteOfPlayer(player)
	local h = hideoutOf(player)
	local def = type(moduleId) == "string" and HideoutDefs.Modules[moduleId]
	if not (site and owned and h and def) or h.Modules[moduleId] then
		return
	end
	local tier = HideoutDefs.Tiers[h.Tier]
	if def.Tier > h.Tier then
		Remotes.Announce:FireClient(player, ("%s needs a %s."):format(def.Name, HideoutDefs.Tiers[def.Tier].Name), "Info")
		return
	end
	local built = 0
	for _ in h.Modules do
		built += 1
	end
	if built >= tier.Modules then
		Remotes.Announce:FireClient(player, ("A %s holds %d modules. Upgrade the workshop."):format(tier.Name, tier.Modules), "Info")
		return
	end
	local ok, why = hasMaterials(player, def.Cost)
	if not ok then
		Remotes.Announce:FireClient(player, "Build: " .. why, "Info")
		return
	end
	spend(player, def.Cost)
	h.Modules[moduleId] = true
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
	if not turret or not turret.Parent then
		return
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
	if not (h and h.Modules.Alarm and h.Modules.Generator) then
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
	-- hide the marker while the site is owned
	task.spawn(function()
		while post.Parent do
			post.Transparency = if site.Owner then 1 else 0
			prompt.Enabled = site.Owner == nil
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

Hideouts.Sites = sites
Hideouts.Push = push
return Hideouts
