-- Recruits on the Front: deployment from the conduit's locker, the weapon in hand, damage
-- with armor and hit zones, death that drops everything damaged for anyone to loot, grenades,
-- field dressings, artillery calls, and credits for the conduit back home.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Firearms = require(Shared.Firearms)
local Remotes = require(Shared.Remotes)
local Joints = require(Shared.Joints)
local Net = require(script.Parent.Common.Net)
local HeldWeapons = require(script.Parent.Common.HeldWeapons)
local WornGear = require(script.Parent.Common.WornGear)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local Assets = require(Shared.Assets)
local PlayerData = require(script.Parent.Common.PlayerData)
local Recruit = require(script.Parent.Common.Recruit)
local WoundService = require(script.Parent.Common.WoundService)
local Wounds = require(Shared.Wounds)
local Battlefield = require(script.Parent.Battlefield)
local Bodies = require(script.Parent.Bodies)
local Factions = require(script.Parent.Factions)
local Guns = require(script.Parent.Guns)
local Hill = require(script.Parent.Hill)

local GunParts = require(Shared.GunParts)
local W = Config.War
local Soldiers = {}

local soldiers = {} -- [player] = { Kit, Weapons = { Primary, Sidearm }, Active = "Primary", Armor, Helmet, Grenades, Medkits, LastHit = { by, t } }
local artilleryReady = { Union = 0, Pact = 0 }
local bodies = {} -- ordered
local earthworks = {} -- [sectorIndex] = ordered list of foxholes/sandbags
local digging = {} -- [player] = finish time
local spawning = {} -- [player] = true while Spawn is yielding
local deathToken = {} -- [player] = n; a delayed respawn only fires for the death it belongs to

local rng = Random.new()

local function warOf(player)
	local data = PlayerData.Get(player)
	return data and Recruit.Init(data.War)
end

local function pushWeapon(player)
	local held = soldiers[player]
	if player.Character and held then
		local w = held.Weapons[held.Active]
		HeldWeapons.Attach(player.Character, w and w.Id, w and w.Attachments, if w and GunParts.Guns[w.Id] then { Scale = W.GunScale } else nil)
		local worn = {}
		if held.Armor then
			table.insert(worn, held.Armor.Id)
		end
		if held.Helmet then
			table.insert(worn, held.Helmet.Id)
		end
		-- on the recruit body the kit, helmet and vest are layers of the body; an avatar gets the welded ones
		WornGear.Apply(player.Character, if Bodies.Wear(player.Character, held) then {} else worn)
	end
	local s = soldiers[player]
	if s then
		Remotes.Weapon:FireClient(player, "State", Guns.Snapshot(s.Weapons[s.Active]), s.Active, { Grenades = s.Grenades, Medkits = s.Medkits, Sandbags = s.Sandbags,
			Armor = s.Armor and { Id = s.Armor.Id, Condition = s.Armor.Condition }, Helmet = s.Helmet and { Id = s.Helmet.Id, Condition = s.Helmet.Condition },
			Spares = s.Spares, Tags = s.Tags })
	end
end

-- rays that only see the world: no characters, no fallen
local function groundOnly()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(bodies)
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
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

-- The live state of a recruit. opts.Pending: the kit is laid out in the barracks and nothing is
-- carried yet (Soldiers.Give hands each piece over); opts.Intro: the recruit is still in its first
-- link (tank, barracks, simulation), which is not a deployment.
function Soldiers.Arm(player, kit, faction, opts)
	opts = opts or {}
	local s = {
		Kit = kit, Weapons = {}, Active = if kit.Primary then "Primary" else "Sidearm", Grenades = 0, Medkits = 0, Sandbags = 0,
		Faction = faction, Protected = os.clock() + Config.SpawnProtection, Intro = opts.Intro == true, Issued = kit.Issued or {},
		Spares = {},
	}
	for _, att in kit.Spares or {} do
		table.insert(s.Spares, { Id = att.Id, Condition = att.Condition })
	end
	-- cybernetic limbs are part of the body, not a piece picked up in the barracks
	if kit.Cyber then
		s.Cyber = {}
		for id, piece in kit.Cyber do
			s.Cyber[id] = { Id = id, Condition = piece.Condition }
		end
	end
	soldiers[player] = s
	if opts.Pending then
		s.Pending = {}
		for _, piece in Soldiers.Pieces(kit) do
			s.Pending[piece] = true
		end
	else
		for _, piece in Soldiers.Pieces(kit) do
			Soldiers.Give(player, piece)
		end
	end
	pushWeapon(player)
	return s
end

-- What a kit hands over, as pieces the barracks can lay out one by one.
function Soldiers.Pieces(kit)
	local out = {}
	for _, piece in { "Primary", "Sidearm", "Armor", "Helmet" } do
		if kit[piece] then
			table.insert(out, piece)
		end
	end
	if (kit.Grenades or 0) > 0 or (kit.Medkits or 0) > 0 or (kit.Sandbags or 0) > 0 or (kit.Magazines or 0) > 0 then
		table.insert(out, "Supplies")
	end
	return out
end

function Soldiers.Give(player, piece)
	local s = soldiers[player]
	if not s then
		return false
	end
	if s.Pending then
		if not s.Pending[piece] then
			return false
		end
		s.Pending[piece] = nil
	end
	local kit = s.Kit
	if piece == "Primary" or piece == "Sidearm" then
		local entry = kit[piece]
		local w = entry and Guns.Make(entry.Id, entry.Condition, if piece == "Primary" then kit.Attachments else nil)
		if w then
			s.Weapons[piece] = w
			if not s.Weapons[s.Active] or piece == "Primary" then
				s.Active = piece
			end
			-- the magazines come with the rifle (or the pistol, when there is no rifle)
			if piece == "Primary" or not kit.Primary then
				Guns.AddMagazines(w, kit.Magazines or 0)
				w.Load = kit.Load or "Ammo" -- the round type the order loaded (Firearms.Loads)
				w.Loose = (kit.Loose or 0) * w.Def.MagSize
			end
		end
	elseif piece == "Armor" or piece == "Helmet" then
		local entry = kit[piece]
		s[piece] = entry and { Id = entry.Id, Condition = entry.Condition }
	elseif piece == "Supplies" then
		s.Grenades, s.Medkits, s.Sandbags = kit.Grenades or 0, kit.Medkits or 0, kit.Sandbags or 0
	end
	pushWeapon(player)
	return true
end

function Soldiers.State(player)
	return soldiers[player]
end
Soldiers.Push = pushWeapon

-- Puts a recruit on the field at its base. opts.Fresh rebuilds the weapons and supplies from the
-- kit (after the simulation, which spends nothing real).
function Soldiers.Place(player, opts)
	local s = soldiers[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (s and root and hum) then
		return
	end
	if opts and opts.Fresh then
		s.Weapons, s.Pending = {}, nil
		for _, piece in Soldiers.Pieces(s.Kit) do
			Soldiers.Give(player, piece)
		end
	end
	s.Intro = false
	s.Lean = 0
	Soldiers.SetStance(player, "Stand", true)
	s.Protected = os.clock() + Config.SpawnProtection
	local spawnAt = Battlefield.BaseCFrame(s.Faction)
	char:PivotTo(spawnAt)
	root.Anchored = true -- held until the client has the battlefield (see Config.SpawnSettle)
	task.delay(Config.SpawnSettle, function()
		if root.Parent then
			char:PivotTo(spawnAt)
			root.Anchored = false
		end
	end)
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.WarMovement.WalkSpeed
	pushWeapon(player)
	pushApp(player)
	Remotes.Soldier:FireClient(player, "Deployed", s.Faction, s.Kit.Conscript == true)
end

function Soldiers.Spawn(player)
	local war = warOf(player)
	if not war or not player.Parent or soldiers[player] or spawning[player] then
		return
	end
	local faction = Factions.Assign(player)
	if Soldiers.Intro and Soldiers.Intro.Needed(player, war) then
		return Soldiers.Intro.Begin(player, faction, Recruit.Deploy(war))
	end
	spawning[player] = true
	local kit = Recruit.Deploy(war)
	if not kit.Primary and not kit.Sidearm then
		kit = conscriptKit(faction)
	end
	player:LoadCharacter()
	local char = player.Character
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	spawning[player] = nil
	if not (root and hum) then
		return
	end
	char:SetAttribute("Faction", faction)
	Bodies.Dress(char, faction)
	hum.MaxHealth, hum.Health = 100, 100
	WoundService.Attach(char) -- each recruit's body takes its hits part by part (shared/Wounds)
	Soldiers.Arm(player, kit, faction)
	Soldiers.Place(player)
	Soldiers.WatchDeath(player, char)
end

function Soldiers.WatchDeath(player, char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			Soldiers.OnDied(player, char)
		end)
	end
end

-- ===== damage =====
local function armorAbsorb(s, zone, damage, pen)
	if zone == "Limb" and s.Cyber then
		damage *= Firearms.CyberEffect(s.Cyber).Limb
	end
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

-- The zone a round found, as a wound part when there is no point to read (Torso = the chest, a limb at random).
local LIMBS = { "ArmL", "ArmR", "LegL", "LegR" }
local function woundPart(zone)
	if zone == "Head" then
		return "Head"
	elseif zone == "Limb" then
		return LIMBS[math.random(1, #LIMBS)]
	end
	return if math.random() < 0.6 then "Chest" else "Stomach"
end

function Soldiers.Damage(victimModel, amount, attacker, zone, pen, kind, at)
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
	local bruise = 0
	local stopped = 0
	if s then
		local before = amount
		amount = armorAbsorb(s, zone or "Torso", amount, pen or 0)
		stopped = if before > 0 then (before - amount) / before else 0
		if zone ~= "Limb" then
			bruise = before - amount -- what the plate took, the body still feels until the plate is gone
		end
		s.LastHit = { by = attacker, t = os.clock(), kind = kind }
		-- in the simulation nothing kills: a fatal blow desyncs the recruit back to the drill's start
		if s.Intro and hum.Health - amount <= 1 and Soldiers.Intro then
			Soldiers.Intro.Desync(victim)
			Remotes.Soldier:FireClient(victim, "Hurt", amount, zone)
			return amount, stopped
		end
		if digging[victim] then
			digging[victim] = nil -- a hit stops the shovel; you stand back up
			hum.WalkSpeed = Config.WarMovement.WalkSpeed
			Remotes.Soldier:FireClient(victim, "Entrenching", nil)
		end
	end
	hum:TakeDamage(amount)
	-- where it landed and what that did (common/WoundService): bleeds, breaks, a limb out, the bruise under plate
	if s and not s.Intro and (WoundService.Get(victimModel) or WoundService.Attach(victimModel)) then
		if bruise > 0.01 then
			WoundService.Bruise(victimModel, { Amount = bruise, Part = if zone == "Head" then "Head" else "Chest" })
		end
		if amount > 0 and hum.Health > 0 then
			if kind == "Explosive" then
				WoundService.Hit(victimModel, { Amount = amount, Kind = "Blast", CanLose = true })
			else
				local part = at and Wounds.PartAt(victimModel, at) or woundPart(zone)
				WoundService.Hit(victimModel, { Amount = amount, Part = part, Kind = "Bullet" })
			end
		end
	end
	if victim then
		Remotes.Soldier:FireClient(victim, "Hurt", amount, zone)
	end
	if attacker and attacker.Parent then
		Remotes.Soldier:FireClient(attacker, "HitMarker", zone, hum.Health <= 0)
	end
	return amount, stopped
end

-- ===== grabbing a dropped gun (round 3): a fallen recruit's rifle lies beside it, whole =====
-- X on it swaps it for the rifle in your hands, on the spot: its wear, its parts, the rounds left in it. Yours goes
-- down where it stood. It lies Config.Guns.DropSeconds.
local droppedGuns = setmetatable({}, { __mode = "k" }) -- model -> weapon state
local function dropGun(w, at)
	local folder = workspace:FindFirstChild("DroppedGuns") or Instance.new("Folder")
	folder.Name = "DroppedGuns"
	folder.Parent = workspace
	local ground = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -16, 0), groundOnly())
	local model = Instance.new("Model")
	model.Name = "DroppedGun"
	model:SetAttribute("WeaponId", w.Id)
	local holder = Instance.new("Part")
	holder.Name = "Holder"
	holder.Size = Vector3.new(1.6, 0.4, 1.6)
	holder.Transparency, holder.Anchored, holder.CanCollide, holder.CanTouch = 1, true, false, false
	holder.CFrame = CFrame.new(if ground then ground.Position + Vector3.new(0, 0.15, 0) else at) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	holder.Parent = model
	model.PrimaryPart = holder
	pcall(HeldWeapons.Attach, model, w.Id, w.Attachments, { Name = "Gun", Part = "Holder", Scale = if GunParts.Guns[w.Id] then W.GunScale else nil, C0 = CFrame.Angles(0, 0, math.rad(90)) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Grab"
	prompt.ObjectText, prompt.ActionText = w.Def.Name, "Take"
	prompt.KeyboardKeyCode, prompt.HoldDuration = Enum.KeyCode.X, 0.4
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 7, false
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player)
		Soldiers.Grab(player, model)
	end)
	droppedGuns[model] = w
	w.Aiming, w.Reloading = false, false
	model.Parent = folder
	game:GetService("Debris"):AddItem(model, Config.Guns.DropSeconds)
	return model
end
Soldiers.DropGun = dropGun

function Soldiers.Grab(player, model)
	local s = soldiers[player]
	local w = model and droppedGuns[model]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local holder = model and model:FindFirstChild("Holder")
	if not (s and w and root and holder and model.Parent) or s.Intro or s.Pending then
		return false
	end
	if (root.Position - holder.Position).Magnitude > 9 then
		return false
	end
	droppedGuns[model] = nil
	model:Destroy()
	local old = s.Weapons.Primary
	if old and not s.Issued.Primary then
		dropGun(old, root.Position + root.CFrame.LookVector * 1.5) -- yours goes down where you stood
	end
	s.Weapons.Primary = w
	s.Issued.Primary = nil -- picked up in the field: it is this recruit's now, and drops with it
	s.Active = "Primary"
	w.Busy = os.clock() + 0.6
	pushWeapon(player)
	return true
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
		if w and slot == "Primary" and not s.Issued[slot] then
			-- the rifle falls beside the body, whole, for the next pair of hands (its attachments stay on it)
			for _, name in Firearms.Parts do
				w.Parts[name] = math.max(0, w.Parts[name] - W.Death.PartDamage)
			end
			dropGun(w, root.Position + root.CFrame.RightVector * 1.8)
		elseif w and not s.Issued[slot] then
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
	if not s.Issued.Primary then
		for _, att in s.Spares or {} do
			table.insert(loot, { Id = att.Id, Condition = math.max(0, att.Condition - W.Death.PartDamage) })
		end
	end
	for _, slot in { "Armor", "Helmet" } do
		local piece = s[slot]
		if piece and not s.Issued[slot] then
			table.insert(loot, { Id = piece.Id, Condition = math.max(0, piece.Condition - W.Death.ArmorDamage) })
		end
	end
	for _, id in Firearms.CyberOrder do
		local piece = s.Cyber and s.Cyber[id]
		if piece then
			table.insert(loot, { Id = id, Condition = math.max(0, piece.Condition - W.Death.ArmorDamage) })
		end
	end
	if #loot == 0 then
		return -- nothing of its own on it (issued gear only): the body is not loot, like a conscript's
	end
	-- stack tags: the fallen's own, and any it took off others
	local tags = 1 + (s.Tags or 0)
	s.Tags = 0
	local body = Instance.new("Part")
	body.Name, body.Size, body.Anchored = "RecruitRemains", Vector3.new(4, 1, 2), true
	body.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0))
	body.Color, body.Material = Color3.fromRGB(60, 55, 50), Enum.Material.Fabric
	body.CanCollide = false
	-- the recruit lies where it fell, in its side's uniform; the plain block is only the fallback
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), groundOnly())
	local lieAt = if ground then ground.Position else root.Position - Vector3.new(0, 3, 0)
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local facing = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
	local fallen = Bodies.Fallen(s.Faction, CFrame.lookAt(lieAt, lieAt + facing), body, Bodies.Look(s))
	if fallen then
		body.Transparency = 1
		body.CFrame = CFrame.new(lieAt + Vector3.new(0, 0.5, 0))
	end
	body:SetAttribute("Label", player.DisplayName .. "'s recruit")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Fallen recruit", "Strip gear", W.LootHold
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 8, false, Enum.KeyCode.X
	prompt.Parent = body
	prompt.Triggered:Connect(function(looter)
		local war = warOf(looter)
		local hum = looter.Character and looter.Character:FindFirstChildOfClass("Humanoid")
		if not body.Parent or body:GetAttribute("Stripped") or not war or not hum or hum.Health <= 0 then
			return
		end
		body:SetAttribute("Stripped", true)
		local names = {}
		for _, item in loot do
			Recruit.LockerAdd(war, item.Id, item.Condition, 1)
			table.insert(names, ("%s (%d%%)"):format(item.Id, item.Condition))
		end
		local ls = soldiers[looter]
		if ls then
			ls.Tags = (ls.Tags or 0) + tags -- paid at the locker (standDown)
			table.insert(names, ("%d stack tag%s"):format(tags, if tags == 1 then "" else "s"))
		end
		Remotes.Announce:FireClient(looter, "Recovered: " .. (if #names > 0 then table.concat(names, ", ") else "nothing") .. ". It all needs repair.", "Info")
		pushApp(looter)
		if fallen then
			-- the body stays where it fell, down to its battle attire, until it calcifies
			prompt:Destroy()
			Bodies.Strip(fallen)
		else
			body:Destroy()
		end
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
	while #bodies > W.BodyCapPerSector * Config.War.Hill.Cols * Config.War.Hill.Rows do
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
	if s.Intro then
		-- something killed a recruit still in its first link (it should not happen): the gear goes back
		-- to the locker and the link starts over
		if Soldiers.Intro then
			Soldiers.Intro.Abort(player, s)
		end
		deathToken[player] = (deathToken[player] or 0) + 1
		local token = deathToken[player]
		task.delay(W.RespawnSeconds, function()
			if player.Parent and deathToken[player] == token then
				Soldiers.Spawn(player)
			end
		end)
		return
	end
	local war = warOf(player)
	if war then
		war.RecruitDeaths += 1
	end
	local killer = s.LastHit and os.clock() - s.LastHit.t < 15 and s.LastHit.by or nil
	local root = char:FindFirstChild("HumanoidRootPart")
	if killer and killer ~= player and Factions.Of(killer) ~= s.Faction then -- no credit for shooting your own side
		local kw = warOf(killer)
		if kw then
			kw.RecruitKills += 1
			kw.Credits += 25
			pushApp(killer)
		end
		Hill.OnKill(Factions.Of(killer), root and root.Position or Vector3.zero)
		Remotes.Announce:FireAllClients(("%s's recruit was killed by %s's recruit."):format(player.DisplayName, killer.DisplayName), "Kill")
	end
	if not s.Kit.Conscript then
		dropBody(player, char, s) -- a conscript's free pistol is not loot: no farming bodies for pistols
	end
	if root then
		Battlefield.Fallen(root.Position) -- every body calcifies where it fell, and feeds its sector's crest
	end
	Remotes.Soldier:FireClient(player, "Died", killer and killer.DisplayName)
	deathToken[player] = (deathToken[player] or 0) + 1
	local token = deathToken[player]
	task.delay(W.RespawnSeconds, function()
		if player.Parent and deathToken[player] == token then
			Soldiers.Spawn(player)
		end
	end)
end

-- ===== unlinking: the way back to the city =====
-- A conduit leaves the Front through its own base's locker (hold X), or between recruits (U while the last one is
-- dead). A recruit stood down at the locker hands its gear back in its current state; a dead one has already
-- dropped it. Then the stack goes home: TeleportService to Endeavor with From = "Front", where the conduit stands
-- at the terminal it tapped in from and reads what the link cost (server/NeuralNet.lua Returned).
local unlinking = {} -- [player] = true while the teleport is in flight

-- stack tags taken off the fallen are paid for at the locker
function Soldiers.PayTags(war, s)
	local n = s.Tags or 0
	if n > 0 then
		war.Credits += n * Config.Guns.TagCredits
		s.Tags = 0
	end
	return n
end

local function standDown(player, s)
	local war = warOf(player)
	if not war then
		return
	end
	local mags = 0
	for slot, w in s.Weapons do
		if not s.Issued[slot] then
			local worst = 100
			for _, name in Firearms.Parts do
				worst = math.min(worst, w.Parts[name] or 100)
			end
			Recruit.LockerAdd(war, w.Id, worst, 1)
			for _, att in w.Attachments do
				Recruit.LockerAdd(war, att.Id, att.Condition, 1)
			end
		end
		if slot == "Primary" then
			mags += #w.Spare
			s.ReturnLoad = w.Load
		end
	end
	if not s.Issued.Primary then
		for _, att in s.Spares or {} do
			Recruit.LockerAdd(war, att.Id, att.Condition, 1)
		end
		s.Spares = {}
	end
	for _, slot in { "Armor", "Helmet" } do
		local piece = s[slot]
		if piece and not s.Issued[slot] then
			Recruit.LockerAdd(war, piece.Id, piece.Condition, 1)
		end
	end
	for id, piece in s.Cyber or {} do
		Recruit.LockerAdd(war, id, piece.Condition, 1)
	end
	if mags > 0 then
		Recruit.LockerAdd(war, if s.ReturnLoad and Firearms.Loads[s.ReturnLoad] then s.ReturnLoad else "Ammo", 100, mags)
	end
	Soldiers.PayTags(war, s)
	if (s.Grenades or 0) > 0 then
		Recruit.LockerAdd(war, "Grenade", 100, s.Grenades)
	end
	if (s.Medkits or 0) > 0 then
		Recruit.LockerAdd(war, "Medkit", 100, s.Medkits)
	end
	if (s.Sandbags or 0) >= 3 then
		Recruit.LockerAdd(war, "Sandbags", 100, 1)
	end
end

local function nearOwnLocker(player, s)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, locker in Battlefield.Lockers do
		local target = if locker:IsA("Model") then locker.PrimaryPart else locker
		if target and locker:GetAttribute("Faction") == s.Faction and (target.Position - root.Position).Magnitude <= W.UnlinkReach then
			return true
		end
	end
	return false
end

local function atBarracks(player, s)
	if s.Intro then
		return true -- the first link's barracks benches
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, locker in Battlefield.Lockers do
		local target = if locker:IsA("Model") then locker.PrimaryPart else locker
		if target and locker:GetAttribute("Faction") == s.Faction and (target.Position - root.Position).Magnitude <= W.BarracksReach then
			return true
		end
	end
	return false
end

-- Change one part of the primary from the loose parts the recruit carries. `id` nil takes the part off.
-- In the field only what the gun's family allows (Firearms.CanField); at the barracks every slot.
-- Returns true, or false and why not ("Barracks", "Busy", "Missing", "Slot").
function Soldiers.FieldMod(player, slot, id)
	local s = soldiers[player]
	local w = s and s.Weapons.Primary
	if not w or s.Active ~= "Primary" or s.Pending then
		return false, "Slot"
	end
	if not table.find(w.Def.Slots, slot) then
		return false, "Slot"
	end
	if w.Reloading or os.clock() < w.Busy then
		return false, "Busy"
	end
	local barracks = atBarracks(player, s)
	if not barracks and not Firearms.CanField(w.Def, slot) then
		return false, "Barracks"
	end
	local index
	if id ~= nil then
		for i, att in s.Spares do
			local def = Firearms.Attachments[att.Id]
			if att.Id == id and def and def.Slot == slot then
				index = i
				break
			end
		end
		if not index then
			return false, "Missing"
		end
	elseif not w.Attachments[slot] then
		return false, "Missing"
	end
	local old = w.Attachments[slot]
	w.Attachments[slot] = if index then table.remove(s.Spares, index) else nil
	if old then
		table.insert(s.Spares, old)
	end
	w.Busy = os.clock() + (if barracks then Firearms.BarracksSeconds else Firearms.FieldSeconds[slot] or 3)
	pushWeapon(player)
	return true
end

-- Returns true when the link is closing, or false and why not.
function Soldiers.Unlink(player)
	if unlinking[player] or spawning[player] then
		return false, "busy"
	end
	if Soldiers.Intro and Soldiers.Intro.Active and Soldiers.Intro.Active(player) then
		return false, "intro"
	end
	local s = soldiers[player]
	if s then
		if s.Intro then
			return false, "intro"
		end
		if not nearOwnLocker(player, s) then
			return false, "locker"
		end
		if s.LastHit and os.clock() - s.LastHit.t < W.UnlinkCalm then
			Remotes.Announce:FireClient(player, "> LINK HELD . . . UNDER FIRE", "Info")
			return false, "fire"
		end
		standDown(player, s)
		soldiers[player] = nil
		if player.Character then
			player.Character:Destroy()
		end
	end
	unlinking[player] = true
	deathToken[player] = (deathToken[player] or 0) + 1 -- no next recruit
	local war = warOf(player)
	Remotes.Soldier:FireClient(player, "Unlinking", W.UnlinkSeconds)
	task.delay(W.UnlinkSeconds, function()
		if not player.Parent then
			return
		end
		local ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ From = "Front", Faction = war and war.Faction })
			game:GetService("TeleportService"):TeleportAsync(W.HomePlaceId, { player }, options)
		end)
		if not ok then
			warn("[Soldiers] unlink teleport failed:", err)
			unlinking[player] = nil
			Remotes.Soldier:FireClient(player, "UnlinkFailed")
			Soldiers.Spawn(player) -- the gear is in the locker: the next recruit takes it
		end
	end)
	return true
end

function Soldiers.IsDeployed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return soldiers[player] ~= nil and not soldiers[player].Intro and hum ~= nil and hum.Health > 0
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
			-- the blast wave reaches further than the shrapnel: ringing ears, a swimming view
			local st = soldiers[p]
			if dist <= radius * Config.Wounds.Concussion.Radius and st and not st.Intro then
				WoundService.Concuss(char)
			end
		end
	end
	-- the simulation takes its own blasts (blocks, targets, hostiles) and leaves the battlefield alone
	if Soldiers.ExplodeHook and Soldiers.ExplodeHook(origin, radius, damage, attacker) then
		return
	end
	for _, model in Battlefield.StructuresNear(origin, radius) do
		Battlefield.DamageStructure(model, damage)
	end
	Battlefield.Crater(origin, radius * 0.5)
end

-- ===== entrenching: dig a foxhole, or stack a low sandbag section (open ground only) =====
local function openGround(position, selfPlayer)
	local E = W.Entrench
	for _, model in Battlefield.StructuresNear(position, E.MinClearance) do
		return false, "too close to a building"
	end
	local index = Battlefield.SectorAt(position)
	for _, work in earthworks[index or 0] or {} do
		if work.Parent and (work.Position - position).Magnitude < E.MinClearance then
			return false, "already dug in here"
		end
	end
	return true
end

local function registerWork(part)
	local index = Battlefield.SectorAt(part.Position) or 0
	earthworks[index] = earthworks[index] or {}
	table.insert(earthworks[index], part)
	part.Destroying:Connect(function()
		local list = earthworks[index]
		local i = list and table.find(list, part)
		if i then
			table.remove(list, i)
		end
	end)
	while #earthworks[index] > W.Entrench.MaxPerSector do
		local oldest = table.remove(earthworks[index], 1)
		if oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function foxhole(player, position)
	local E = W.Entrench
	-- dig through whatever is there: fallen recruits in the hole are buried
	for _, body in table.clone(bodies) do
		if body.Parent and (body.Position - position).Magnitude < E.FoxholeRadius + 1 then
			body:Destroy()
		end
	end
	local ground = Battlefield.GroundAt(position.X, position.Z)
	local hole = Instance.new("Part")
	hole.Name, hole.Shape = "Foxhole", Enum.PartType.Cylinder
	hole.Size = Vector3.new(E.FoxholeDepth, E.FoxholeRadius * 2, E.FoxholeRadius * 2)
	hole.CFrame = CFrame.new(position.X, ground - E.FoxholeDepth / 2 + 0.05, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	hole.Color, hole.Material, hole.Anchored, hole.CanCollide = Color3.fromRGB(45, 38, 28), Enum.Material.Mud, true, false
	hole.Parent = workspace
	-- the floor you stand on, and the lip of spoil that is the actual cover
	local floor = Instance.new("Part")
	floor.Name, floor.Shape, floor.Size = "FoxholeFloor", Enum.PartType.Cylinder, Vector3.new(0.5, E.FoxholeRadius * 2, E.FoxholeRadius * 2)
	floor.CFrame = CFrame.new(position.X, ground - E.FoxholeDepth, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Color, floor.Material, floor.Anchored = Color3.fromRGB(45, 38, 28), Enum.Material.Mud, true
	floor.Parent = hole
	local lip = Instance.new("Part")
	lip.Name, lip.Shape, lip.Size = "Spoil", Enum.PartType.Cylinder, Vector3.new(1.2, E.FoxholeRadius * 2 + 2.5, E.FoxholeRadius * 2 + 2.5)
	lip.CFrame = CFrame.new(position.X, ground + 0.6, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	lip.Color, lip.Material, lip.Anchored = Color3.fromRGB(70, 60, 45), Enum.Material.Ground, true
	lip.Parent = hole
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and terrain.FillBall then
		pcall(function()
			terrain:FillBall(Vector3.new(position.X, ground - 1, position.Z), E.FoxholeRadius, Enum.Material.Air)
		end)
	end
	registerWork(hole)
	Remotes.World:FireAllClients("Dig", position)
	return hole
end

local function sandbag(player, position, look)
	local bag = Instance.new("Part")
	bag.Name, bag.Size = "LowSandbags", Vector3.new(5, 1.6, 1.4)
	local ground = Battlefield.GroundAt(position.X, position.Z)
	bag.CFrame = CFrame.lookAt(Vector3.new(position.X, ground + 0.8, position.Z), Vector3.new(position.X + look.X, ground + 0.8, position.Z + look.Z))
	bag.Color, bag.Material, bag.Anchored = Color3.fromRGB(140, 125, 90), Enum.Material.Fabric, true
	bag.Parent = workspace
	-- the uploaded sandbag model rides inside the collider; the plain part stays as the fallback look
	if ModelAssets.Spawn(Assets.Front.LowSandbags, bag.CFrame * CFrame.new(0, -0.8, 0), "Mesh", bag) then
		bag.Transparency = 1
	end
	registerWork(bag)
	return bag
end

local function onEntrench(player, mode)
	local s = soldiers[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (s and root and hum and hum.Health > 0) or digging[player] or s.Intro then
		return
	end
	local E = W.Entrench
	local look = root.CFrame.LookVector
	local spot = root.Position + Vector3.new(look.X, 0, look.Z).Unit * (if mode == "Dig" then 0 else 4)
	local ok, why = openGround(Vector3.new(spot.X, Battlefield.GroundAt(spot.X, spot.Z), spot.Z), player)
	if not ok then
		Remotes.Announce:FireClient(player, "Can't entrench: " .. why, "Info")
		return
	end
	if mode == "Sandbag" and s.Sandbags <= 0 then
		Remotes.Announce:FireClient(player, "No sandbags left. The shop sells them.", "Info")
		return
	end
	local seconds = if mode == "Dig" then E.DigSeconds else E.SandbagSeconds
	digging[player] = os.clock() + seconds
	hum.WalkSpeed = 0
	Remotes.Soldier:FireClient(player, "Entrenching", mode, seconds)
	task.delay(seconds, function()
		digging[player] = nil
		if not (player.Parent and player.Character == char and hum.Health > 0) then
			return
		end
		hum.WalkSpeed = Config.WarMovement.WalkSpeed
		if mode == "Dig" then
			foxhole(player, Vector3.new(spot.X, 2, spot.Z))
		else
			s.Sandbags -= 1
			sandbag(player, spot, look)
			pushWeapon(player)
		end
	end)
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

-- ===== stance and lean: the server owns the body's shape, so hits land on what everyone sees =====
local MV = Config.WarMovement
local RANK = { Prone = 1, Crouch = 2, Stand = 3 }
local function deg(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end
-- joint offsets per stance (hips forward = +X, knees fold = -X, the same convention as the rifle hold)
local STANCE_POSE = {
	Stand = {},
	Crouch = { LeftHip = deg(64), RightHip = deg(78), LeftKnee = deg(-112), RightKnee = deg(-118), LeftAnkle = deg(44), RightAnkle = deg(38), Neck = deg(8) },
	Prone = { Root = CFrame.new(0, 0.6, 0) * deg(-90), Neck = deg(62), LeftHip = deg(-4, 0, -9), RightHip = deg(-4, 0, 9), LeftAnkle = deg(-50), RightAnkle = deg(-50) },
}
local POSED = { "Root", "Neck", "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftAnkle", "RightAnkle" }
local STANCE_WAIST = { Stand = 0, Crouch = 16, Prone = 0 }
local IDENTITY = CFrame.new()

local function applyPose(char, s, seconds)
	local stance = s.Stance or "Stand"
	local pose = STANCE_POSE[stance]
	for _, name in POSED do
		Joints.Pose(char, name, pose[name] or IDENTITY, seconds)
	end
	Joints.Pose(char, "Waist", deg(STANCE_WAIST[stance], 0, -(s.Lean or 0) * MV.LeanRoll * 1.6), seconds)
end

-- Stand / Crouch / Prone. Rising needs headroom; `force` skips the checks (a fresh placement).
function Soldiers.SetStance(player, stance, force)
	local s = soldiers[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local def = MV.Stance[stance]
	if not (s and hum and root and def) or hum.Health <= 0 then
		return false
	end
	local now = s.Stance or "Stand"
	if stance == now then
		return true
	end
	if not force then
		if digging[player] then
			return false
		end
		if RANK[stance] > RANK[now] then
			local feet = root.Position.Y - hum.HipHeight - root.Size.Y / 2
			local need = if stance == "Stand" then 4.8 else 3.4
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { char }
			if workspace:Raycast(Vector3.new(root.Position.X, feet + 1, root.Position.Z), Vector3.new(0, need - 1, 0), ray) then
				return false -- something overhead
			end
		end
	end
	s.BaseHip = s.BaseHip or hum.HipHeight
	s.Stance = stance
	if stance == "Prone" then
		s.Lean = 0
	end
	char:SetAttribute("Stance", stance)
	hum.HipHeight = if stance == "Prone" then 0 else s.BaseHip - (def.Drop or 0)
	applyPose(char, s, if stance == "Prone" or now == "Prone" then MV.ProneSeconds else MV.StanceSeconds)
	return true
end

-- Where the recruit's eye is: lower when prone, out to the side on a lean (further next to cover).
function Soldiers.Eye(player, ray)
	local s = soldiers[player]
	local root = player.Character.HumanoidRootPart
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	if s and s.Stance == "Prone" then
		eye += root.CFrame:VectorToWorldSpace(MV.ProneCamera)
	end
	local lean = s and s.Lean or 0
	if lean ~= 0 then
		local look = root.CFrame.LookVector
		local cover = workspace:Raycast(eye, Vector3.new(look.X, 0, look.Z) * MV.PeekReach, ray)
		local reach = if cover then MV.Peek else MV.Lean
		local side = root.CFrame.RightVector * lean
		local wall = workspace:Raycast(eye, side * (reach + 0.4), ray)
		if wall then
			reach = math.max(0, (wall.Position - eye).Magnitude - 0.4)
		end
		eye += side * reach
	end
	return eye
end

local function onFire(player, dir)
	local s, w = active(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (s and w and root) then
		return
	end
	-- the client aims; the server refuses directions a body facing that way could not shoot
	if dir.Magnitude < 0.5 or root.CFrame.LookVector:Dot(dir.Unit) < 0.2 then
		return
	end
	local result = Guns.Trigger(w)
	if result == "fired" then
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { player.Character }
		local eye = Soldiers.Eye(player, ray)
		local muzzle = eye + dir.Unit * 2
		local stance = MV.Stance[s.Stance or "Stand"]
		w.Steady = stance.Spread * Firearms.CyberEffect(s.Cyber).Spread
			* (1 + (player.Character:GetAttribute("WoundShake") or 0) * Config.Wounds.SpreadPerShake) -- pain, a bad arm
			* (1 + (w.Fatigue or 0)) -- tired arms (round 3: the gun's weight held up)
		local wall = workspace:Raycast(eye, muzzle - eye, ray)
		if wall then
			muzzle = wall.Position - dir.Unit * 0.3 -- muzzle against a wall: the round starts on your side of it
		end
		Guns.Shoot(player, w, muzzle, dir.Unit, function(model, zone, damage, pen, at)
			local dealt, stopped = Soldiers.Damage(model, damage, player, zone, pen, "Bullet", at)
			Remotes.Weapon:FireAllClients("Impact", at, Vector3.yAxis, dealt > 0)
			return (stopped or 0) >= 0.6 -- mostly stopped by plate: it may glance on (Guns.Shoot)
		end)
		Remotes.Weapon:FireClient(player, "Recoil", w.Def.Recoil[1] * Firearms.RecoilMult(w.Parts) * MV.Stance[s.Stance or "Stand"].Recoil * Guns.AttMult(w, "Recoil"), w.Def.Recoil[2] * MV.Stance[s.Stance or "Stand"].Recoil)
	elseif result ~= "busy" then
		Remotes.Weapon:FireClient(player, "Click", result)
	end
	if result ~= "busy" then
		pushWeapon(player)
	end
end

-- Tired arms (round 3): the gun held up tires them by its weight (Firearms Defs Weight, against a 3.2 kg rifle's
-- Config.Guns.Fatigue.Weight.Rifle), rest brings them back. w.Fatigue widens the spread and sways the view.
function Soldiers.FatigueTick(dt)
	local F = Config.Guns.Fatigue
	for _, s in soldiers do
		for slot, w in s.Weapons do
			local f = w.Fatigue or 0
			if slot == s.Active and w.Aiming then
				f = math.min(1, f + dt * F.Rate * (w.Def.Weight or F.Weight.Rifle))
			else
				f = math.max(0, f - dt * F.Recover)
			end
			w.Fatigue = if f > 0 then f else nil
		end
	end
end

function Soldiers.Init()
	-- the locker terminal at each base opens the recruit app (M does too, anywhere)
	for _, locker in Battlefield.Lockers do
		local target = if locker:IsA("Model") then locker.PrimaryPart else locker
		if target then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Locker", "Open recruit app", 0.3
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
			prompt.Parent = target
			prompt.Triggered:Connect(function(player)
				local war = warOf(player)
				if war then
					Remotes.RecruitApp:FireClient(player, Recruit.Snapshot(war), true)
				end
			end)
		end
	end
	-- and the same lockers are the way home: hold X to unlink
	for _, locker in Battlefield.Lockers do
		local target = if locker:IsA("Model") then locker.PrimaryPart else locker
		if target then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Neural Net", "Unlink", W.UnlinkHold
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 10, false, Enum.KeyCode.X
			prompt.UIOffset = Vector2.new(0, 60)
			prompt.Parent = target
			prompt.Triggered:Connect(function(player)
				Soldiers.Unlink(player)
			end)
		end
	end
	-- between recruits (the last one dead, the next not yet out) the conduit may leave from anywhere
	Net.On("Unlink", { rate = 1, burst = 2 }, function(player)
		if soldiers[player] == nil then
			Soldiers.Unlink(player)
		end
	end)
	Players.CharacterAutoLoads = false
	Factions.IsDeployed = Soldiers.IsDeployed
	Net.On("Fire", { rate = 20, burst = 30, args = { "vector" } }, onFire)
	Net.On("Reload", { rate = 2, burst = 3, args = { "boolean?" } }, function(player, keep)
		local s, w = active(player)
		if w then
			-- the simulation keeps the pouches full: magazines are only data there
			if s.Intro and #w.Spare < W.Intro.Sim.ResupplyBelow then
				Guns.AddMagazines(w, 4 - #w.Spare)
			end
			Guns.Reload(w, keep == true, MV.QuickReload, MV.CarefulReload)
			pushWeapon(player)
			task.delay(0.5, function() pushWeapon(player) end)
			task.delay(2.5, function() pushWeapon(player) end)
			task.delay(4.0, function() pushWeapon(player) end)
		end
	end)
	Net.On("FieldMod", { rate = 3, burst = 4, args = { "string", "string?" } }, function(player, slot, id)
		local ok, why = Soldiers.FieldMod(player, slot, id)
		if not ok and why then
			Remotes.Weapon:FireClient(player, "Refused", why)
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
			local cur = s.Weapons[s.Active]
			if s.Weapons[other] and not (cur and os.clock() < cur.Busy) then
				s.Active = other
				pushWeapon(player)
			end
		end
	end)
	Net.On("Aim", { rate = 6, burst = 10, args = { "boolean" } }, function(player, aiming)
		local _, w = active(player)
		if w then
			w.Aiming = aiming
			pushWeapon(player)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.5)
			local now = os.clock()
			Soldiers.FatigueTick(now - last)
			last = now
			-- the screen hears about tired arms and a hot barrel while they change
			for player, s in soldiers do
				local w = s.Weapons[s.Active]
				if w and (w.Fatigue or Guns.Heat(w) > 0) then
					pushWeapon(player)
				end
			end
		end
	end)
	Net.On("Stance", { rate = 6, burst = 10, args = { "string" } }, function(player, stance)
		Soldiers.SetStance(player, stance)
	end)
	Net.On("Lean", { rate = 10, burst = 16, args = { "int" } }, function(player, side)
		local s = active(player)
		if s then
			s.Lean = if s.Stance == "Prone" then 0 else math.clamp(side, -1, 1)
			applyPose(player.Character, s, 0.15)
		end
	end)
	-- binoculars: an enemy held in the glass is marked for the spotter's side for a few seconds
	Net.On("Mark", { rate = 3, burst = 5, args = { "instance" } }, function(player, model)
		local s = active(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local B = MV.Binoculars
		if not (s and root) or not model:IsA("Model") or model == player.Character then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local target = model:FindFirstChild("HumanoidRootPart")
		if not (hum and target) or hum.Health <= 0 then
			return
		end
		local owner = Players:GetPlayerFromCharacter(model)
		if owner and Factions.Of(owner) == s.Faction then
			return
		end
		local to = target.Position - root.Position
		if to.Magnitude > B.Range or to.Magnitude < 1 or root.CFrame.LookVector:Dot(to.Unit) < 0.2 then
			return
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { player.Character }
		local eye = Soldiers.Eye(player, ray)
		local hit = workspace:Raycast(eye, target.Position - eye, ray)
		if hit and not hit.Instance:IsDescendantOf(model) then
			return -- not in sight
		end
		model:SetAttribute("MarkedBy" .. s.Faction, os.clock() + B.Seconds)
		if s.Intro then
			Remotes.Soldier:FireClient(player, "Marked", model, B.Seconds)
		else
			for other, os2 in soldiers do
				if os2.Faction == s.Faction and not os2.Intro then
					Remotes.Soldier:FireClient(other, "Marked", model, B.Seconds)
				end
			end
		end
	end)
	Net.On("Grenade", { rate = 1, burst = 2, args = { "vector" } }, function(player, dir)
		local s = active(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (s and root) or s.Grenades <= 0 or dir.Magnitude < 0.5 then
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
		if not (s and hum and s.Medkits > 0) then
			return
		end
		-- a dressing goes on the worst thing first: a bleed, then a break; else it patches health
		if not s.Intro and WoundService.Dress(player.Character) then
			s.Medkits -= 1
			pushWeapon(player)
		elseif hum.Health < hum.MaxHealth then
			s.Medkits -= 1
			hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
			pushWeapon(player)
		end
	end)
	-- Artillery: each faction can call a strike on a point inside the hill, once per cooldown.
	Net.On("Artillery", { rate = 1, burst = 2, args = { "vector" } }, function(player, target)
		local s = active(player)
		if s and s.Intro and Soldiers.Intro then
			Soldiers.Intro.Artillery(player, target)
			return
		end
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
					Soldiers.Explode(Vector3.new(at.X, Battlefield.GroundAt(at.X, at.Z) + 0.5, at.Z), A.Radius, A.Damage, player)
				end)
			end
		end)
	end)
	Net.On("Entrench", { rate = 1, burst = 2, args = { "string" } }, function(player, mode)
		if mode == "Dig" or mode == "Sandbag" then
			onEntrench(player, mode)
		end
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
		local s = soldiers[player]
		if s and s.Intro and Soldiers.Intro then
			Soldiers.Intro.Abort(player, s) -- left during the first link: the gear goes back to the locker
		elseif s and player.Character and not s.Kit.Conscript and not unlinking[player] then
			dropBody(player, player.Character, s) -- quitting mid-fight leaves your gear on the field like dying would
		end
		soldiers[player] = nil
		digging[player] = nil
		spawning[player] = nil
		deathToken[player] = nil
		unlinking[player] = nil
		PlayerData.Release(player)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
end

return Soldiers
