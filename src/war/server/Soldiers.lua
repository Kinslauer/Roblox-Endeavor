-- Recruits on the Front: deployment from the conduit's locker, the weapon in hand, damage
-- with armor and hit zones, death that drops everything damaged for anyone to loot, grenades,
-- field dressings, artillery calls, and credits for the conduit back home.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Firearms = require(Shared.Firearms)
local Remotes = require(Shared.Remotes)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local Recruit = require(script.Parent.Common.Recruit)
local Battlefield = require(script.Parent.Battlefield)
local Factions = require(script.Parent.Factions)
local Guns = require(script.Parent.Guns)
local Hill = require(script.Parent.Hill)

local W = Config.War
local Soldiers = {}

local soldiers = {} -- [player] = { Kit, Weapons = { Primary, Sidearm }, Active = "Primary", Armor, Helmet, Grenades, Medkits, LastHit = { by, t } }
local artilleryReady = { Union = 0, Pact = 0 }
local bodies = {} -- ordered
local rng = Random.new()

local function warOf(player)
	local data = PlayerData.Get(player)
	return data and Recruit.Init(data.War)
end

local function pushWeapon(player)
	local s = soldiers[player]
	if s then
		Remotes.Weapon:FireClient(player, "State", Guns.Snapshot(s.Weapons[s.Active]), s.Active, { Grenades = s.Grenades, Medkits = s.Medkits,
			Armor = s.Armor and { Id = s.Armor.Id, Condition = s.Armor.Condition }, Helmet = s.Helmet and { Id = s.Helmet.Id, Condition = s.Helmet.Condition } })
	end
end

local function pushApp(player)
	local war = warOf(player)
	if war then
		Remotes.RecruitApp:FireClient(player, Recruit.Snapshot(war))
	end
end

-- A conduit with an empty locker still gets a body to fight with: the faction's conscript kit.
local function conscriptKit(faction)
	return { Sidearm = { Id = if faction == "Union" then "M1911" else "Makarov", Condition = 70 }, Attachments = {}, Magazines = 2, Grenades = 0, Medkits = 0, Conscript = true }
end

local function buildWeapons(kit)
	local weapons = {}
	for _, slot in { "Primary", "Sidearm" } do
		local entry = kit[slot]
		if entry then
			local w = Guns.Make(entry.Id, entry.Condition, if slot == "Primary" then kit.Attachments else nil)
			if w then
				Guns.AddMagazines(w, kit.Magazines or 0)
				weapons[slot] = w
			end
		end
	end
	return weapons
end

function Soldiers.Spawn(player)
	local war = warOf(player)
	if not war or not player.Parent then
		return
	end
	local faction = Factions.Assign(player)
	local kit = Recruit.Deploy(war)
	if not kit.Primary and not kit.Sidearm then
		kit = conscriptKit(faction)
	end
	player:LoadCharacter()
	local char = player.Character
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not (root and hum) then
		return
	end
	char:PivotTo(Battlefield.BaseCFrame(faction))
	char:SetAttribute("Faction", faction)
	hum.MaxHealth, hum.Health = 100, 100
	hum.WalkSpeed = 14
	local s = {
		Kit = kit, Weapons = buildWeapons(kit), Active = if kit.Primary then "Primary" else "Sidearm",
		Armor = kit.Armor and { Id = kit.Armor.Id, Condition = kit.Armor.Condition }, Helmet = kit.Helmet and { Id = kit.Helmet.Id, Condition = kit.Helmet.Condition },
		Grenades = kit.Grenades or 0, Medkits = kit.Medkits or 0, Faction = faction, Protected = os.clock() + Config.SpawnProtection,
	}
	soldiers[player] = s
	pushWeapon(player)
	pushApp(player)
	Remotes.Soldier:FireClient(player, "Deployed", faction, kit.Conscript == true)
	hum.Died:Once(function()
		Soldiers.OnDied(player, char)
	end)
end

-- ===== damage =====
local function armorAbsorb(s, zone, damage, pen)
	local piece = if zone == "Head" then s.Helmet elseif zone == "Torso" then s.Armor else nil
	if not piece or piece.Condition <= 0 then
		return damage
	end
	local def = Firearms.Armor[piece.Id]
	if not def then
		return damage
	end
	local effective = def.Protection * (piece.Condition / def.Durability) * (1 - pen)
	local absorbed = damage * math.clamp(effective, 0, 0.9)
	piece.Condition = math.max(0, piece.Condition - absorbed * 0.5)
	return damage - absorbed
end

function Soldiers.Damage(victimModel, amount, attacker, zone, pen, kind)
	local victim = Players:GetPlayerFromCharacter(victimModel)
	local hum = victimModel:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return 0
	end
	local s = victim and soldiers[victim]
	if s and os.clock() < s.Protected then
		return 0
	end
	if attacker and attacker ~= victim and s and Factions.Of(attacker) == s.Faction then
		amount *= 0.25 -- friendly fire hurts, but not as much
	end
	if s then
		amount = armorAbsorb(s, zone or "Torso", amount, pen or 0)
		s.LastHit = { by = attacker, t = os.clock(), kind = kind }
	end
	hum:TakeDamage(amount)
	if victim then
		Remotes.Soldier:FireClient(victim, "Hurt", amount, zone)
	end
	if attacker and attacker.Parent then
		Remotes.Soldier:FireClient(attacker, "HitMarker", zone, hum.Health <= 0)
	end
	return amount
end

-- ===== death: everything on the body stays on the battlefield, damaged =====
local function dropBody(player, char, s)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local loot = {}
	for _, slot in { "Primary", "Sidearm" } do
		local w = s.Weapons[slot]
		if w then
			local worst = 100
			for _, name in Firearms.Parts do
				w.Parts[name] = math.max(0, w.Parts[name] - W.Death.PartDamage)
				worst = math.min(worst, w.Parts[name])
			end
			table.insert(loot, { Id = w.Id, Condition = worst })
			for _, att in w.Attachments do
				table.insert(loot, { Id = att.Id, Condition = math.max(0, att.Condition - W.Death.PartDamage) })
			end
		end
	end
	for _, piece in { s.Armor, s.Helmet } do
		if piece then
			table.insert(loot, { Id = piece.Id, Condition = math.max(0, piece.Condition - W.Death.ArmorDamage) })
		end
	end
	if #loot == 0 then
		return
	end
	local body = Instance.new("Part")
	body.Name, body.Size, body.Anchored = "RecruitRemains", Vector3.new(4, 1, 2), true
	body.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0))
	body.Color, body.Material = Color3.fromRGB(60, 55, 50), Enum.Material.Fabric
	body:SetAttribute("Label", player.DisplayName .. "'s recruit")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Fallen recruit", "Strip gear", W.LootHold
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 8, false, Enum.KeyCode.X
	prompt.Parent = body
	prompt.Triggered:Connect(function(looter)
		local war = warOf(looter)
		local hum = looter.Character and looter.Character:FindFirstChildOfClass("Humanoid")
		if not body.Parent or not war or not hum or hum.Health <= 0 then
			return
		end
		body.Parent = nil
		local names = {}
		for _, item in loot do
			Recruit.LockerAdd(war, item.Id, item.Condition, 1)
			table.insert(names, ("%s (%d%%)"):format(item.Id, item.Condition))
		end
		Remotes.Announce:FireClient(looter, "Recovered: " .. table.concat(names, ", ") .. ". It all needs repair.", "Info")
		pushApp(looter)
		body:Destroy()
	end)
	body.Parent = workspace
	table.insert(bodies, body)
	body.Destroying:Connect(function()
		local i = table.find(bodies, body)
		if i then
			table.remove(bodies, i)
		end
	end)
	game:GetService("Debris"):AddItem(body, Config.CorpseLifetime)
	while #bodies > W.BodyCapPerSector * (Config.War.Hill.Sectors ^ 2) do
		local oldest = table.remove(bodies, 1)
		if oldest.Parent then
			oldest:Destroy()
		end
	end
end

function Soldiers.OnDied(player, char)
	local s = soldiers[player]
	if not s then
		return
	end
	soldiers[player] = nil
	local war = warOf(player)
	if war then
		war.RecruitDeaths += 1
	end
	local killer = s.LastHit and os.clock() - s.LastHit.t < 15 and s.LastHit.by or nil
	local root = char:FindFirstChild("HumanoidRootPart")
	if killer and killer ~= player then
		local kw = warOf(killer)
		if kw then
			kw.RecruitKills += 1
			kw.Credits += 25
			pushApp(killer)
		end
		Hill.OnKill(Factions.Of(killer), root and root.Position or Vector3.zero)
		Remotes.Announce:FireAllClients(("%s's recruit was killed by %s's recruit."):format(player.DisplayName, killer.DisplayName), "Kill")
	end
	dropBody(player, char, s)
	Remotes.Soldier:FireClient(player, "Died", killer and killer.DisplayName)
	task.delay(W.RespawnSeconds, function()
		if player.Parent then
			Soldiers.Spawn(player)
		end
	end)
end

-- ===== explosions on the Front (grenades, artillery) =====
function Soldiers.Explode(origin, radius, damage, attacker)
	Remotes.World:FireAllClients("Explosion", origin, radius)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local dist = (root.Position - origin).Magnitude
			if dist <= radius then
				local ray = RaycastParams.new()
				ray.FilterType = Enum.RaycastFilterType.Exclude
				ray.FilterDescendantsInstances = { char }
				local hit = workspace:Raycast(origin, root.Position - origin, ray)
				if not hit or (hit.Position - root.Position).Magnitude < 3 then
					Soldiers.Damage(char, damage * (1 - (dist / radius) ^ 1.5), attacker, "Torso", 0.3, "Explosive")
				end
			end
		end
	end
	for _, model in Battlefield.StructuresNear(origin, radius) do
		Battlefield.DamageStructure(model, damage)
	end
	Battlefield.Crater(origin, radius * 0.5)
end

-- ===== remotes =====
local function active(player)
	local s = soldiers[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if s and hum and hum.Health > 0 then
		return s, s.Weapons[s.Active]
	end
	return nil
end

local function onFire(player, dir)
	local s, w = active(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (s and w and root) then
		return
	end
	-- the client aims; the server refuses directions a body facing that way could not shoot
	if root.CFrame.LookVector:Dot(dir.Unit) < 0.2 then
		return
	end
	local result = Guns.Trigger(w)
	if result == "fired" then
		local muzzle = root.Position + Vector3.new(0, 1.5, 0) + dir.Unit * 2
		Guns.Shoot(player, w, muzzle, dir.Unit, function(model, zone, damage, pen, at)
			local dealt = Soldiers.Damage(model, damage, player, zone, pen, "Bullet")
			Remotes.Weapon:FireAllClients("Impact", at, Vector3.yAxis, dealt > 0)
		end)
		Remotes.Weapon:FireClient(player, "Recoil", w.Def.Recoil[1] * Firearms.RecoilMult(w.Parts) * (s.Weapons[s.Active] and 1), w.Def.Recoil[2])
	elseif result ~= "busy" then
		Remotes.Weapon:FireClient(player, "Click", result)
	end
	pushWeapon(player)
end

function Soldiers.Init()
	Players.CharacterAutoLoads = false
	Net.On("Fire", { rate = 20, burst = 30, args = { "vector" } }, onFire)
	Net.On("Reload", { rate = 2, burst = 3 }, function(player)
		local _, w = active(player)
		if w then
			Guns.Reload(w)
			pushWeapon(player)
			task.delay(0.5, function() pushWeapon(player) end)
			task.delay(2.5, function() pushWeapon(player) end)
		end
	end)
	Net.On("Rack", { rate = 3, burst = 4 }, function(player)
		local _, w = active(player)
		if w then
			Guns.Rack(w)
			pushWeapon(player)
		end
	end)
	Net.On("Unjam", { rate = 2, burst = 3 }, function(player)
		local _, w = active(player)
		if w then
			Guns.Unjam(w)
			pushWeapon(player)
			task.delay(3, function() pushWeapon(player) end)
		end
	end)
	Net.On("Mode", { rate = 3, burst = 4 }, function(player)
		local _, w = active(player)
		if w then
			Guns.CycleMode(w)
			pushWeapon(player)
		end
	end)
	Net.On("Switch", { rate = 2, burst = 3 }, function(player)
		local s = active(player)
		if s then
			local other = if s.Active == "Primary" then "Sidearm" else "Primary"
			if s.Weapons[other] then
				s.Active = other
				pushWeapon(player)
			end
		end
	end)
	Net.On("Aim", { rate = 6, burst = 10, args = { "boolean" } }, function(player, aiming)
		local _, w = active(player)
		if w then
			w.Aiming = aiming
		end
	end)
	Net.On("Grenade", { rate = 1, burst = 2, args = { "vector" } }, function(player, dir)
		local s = active(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (s and root) or s.Grenades <= 0 then
			return
		end
		s.Grenades -= 1
		pushWeapon(player)
		local nade = Instance.new("Part")
		nade.Name, nade.Shape, nade.Size = "FragGrenade", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7)
		nade.Color, nade.CFrame = Color3.fromRGB(60, 70, 50), CFrame.new(root.Position + dir.Unit * 2 + Vector3.new(0, 1.5, 0))
		nade.Parent = workspace
		nade:SetNetworkOwner(nil)
		nade.AssemblyLinearVelocity = dir.Unit * 60 + Vector3.new(0, 20, 0)
		task.delay(3.5, function()
			local at = nade.Position
			nade:Destroy()
			Soldiers.Explode(at, 12, 90, player)
		end)
	end)
	Net.On("Heal", { rate = 1, burst = 2 }, function(player)
		local s = active(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if s and hum and s.Medkits > 0 and hum.Health < hum.MaxHealth then
			s.Medkits -= 1
			hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
			pushWeapon(player)
		end
	end)
	-- Artillery: each faction can call a strike on a point inside the hill, once per cooldown.
	Net.On("Artillery", { rate = 1, burst = 2, args = { "vector" } }, function(player, target)
		local s = active(player)
		if not s or not Hill.Inside(target) then
			return
		end
		local A = W.Artillery
		if os.clock() < artilleryReady[s.Faction] then
			Remotes.Announce:FireClient(player, ("Guns reloading: %ds."):format(artilleryReady[s.Faction] - os.clock()), "Info")
			return
		end
		artilleryReady[s.Faction] = os.clock() + A.Cooldown
		Remotes.Announce:FireAllClients(("%s artillery incoming on sector %d."):format(s.Faction, Hill.Current()), "Event")
		Remotes.World:FireAllClients("ArtilleryWarning", target, A.Delay)
		task.delay(A.Delay, function()
			for i = 1, A.Shells do
				task.delay(i * 0.6, function()
					local at = target + Vector3.new(rng:NextNumber(-A.Spread, A.Spread), 0, rng:NextNumber(-A.Spread, A.Spread))
					Soldiers.Explode(Vector3.new(at.X, 2, at.Z), A.Radius, A.Damage, player)
				end)
			end
		end)
	end)
	Net.On("Deploy", { rate = 1, burst = 2 }, function(player)
		if not soldiers[player] and PlayerData.Get(player) then
			Soldiers.Spawn(player)
		end
	end)
	Net.On("WarOrder", { rate = 4, burst = 6, args = { "table" } }, function(player, loadout)
		local war = warOf(player)
		if war then
			Recruit.Order(war, loadout)
			pushApp(player)
		end
	end)
	Net.On("WarBuy", { rate = 4, burst = 6, args = { "string" } }, function(player, id)
		local war = warOf(player)
		if war then
			local ok, reason = Recruit.Buy(war, id)
			if not ok then
				Remotes.Announce:FireClient(player, "Shop: " .. reason, "Info")
			end
			pushApp(player)
		end
	end)
	Net.On("WarRepair", { rate = 4, burst = 6, args = { "string" } }, function(player, id)
		local war = warOf(player)
		if war then
			local ok, reason = Recruit.Repair(war, id)
			if not ok then
				Remotes.Announce:FireClient(player, "Repair: " .. reason, "Info")
			end
			pushApp(player)
		end
	end)

	local function onPlayerAdded(player)
		if not PlayerData.Load(player) then
			return
		end
		Factions.Assign(player)
		pushApp(player)
		Remotes.Scales:FireClient(player, Factions.Scales())
		Soldiers.Spawn(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		soldiers[player] = nil
		PlayerData.Release(player)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
end

return Soldiers
