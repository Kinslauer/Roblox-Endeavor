-- The war (Phase 3, build order 2; design/gdd/war.md): Wardogs. A perpetual three-sided ticket battle
-- over a moving hill, fought in the Range's arena until the war world is its own place.
--
--   * three sides (Config.War.Factions), each with a base pad and a cloning facility
--   * the hill: a ring at one of Config.War.HillPoints; one side alone inside captures it over
--     CaptureSeconds; the holder bleeds the other sides' tickets; the hill moves on capture / a timer
--   * AI recruits (Enemies.Defs.Recruit, tinted by side) arrive in re-entry pods and trickle from the
--     facility; they hunt the other sides and walk to the hill otherwise (NPCs opts.Faction / Home)
--   * players deploy from the hideout to their side's base; a lethal hit downs them instead
--     (Combat.LethalHook); an ally holds X to revive; bleeding out = death = redeploy, never permadeath
--   * tickets: a death costs DeathTickets; at 0 the round ends, the side with the most wins, reset
--   * pay (Wallet): zone time, revives, takedowns, a round win
--   * supply (server/Supply.lua): recruits spawn with the kit their side's pool affords; a player's
--     shipment lands as a crate at their base - open it to fight with it, lose it where you fall
-- The HUD reads workspace attributes War_* ; CombatEvents Downed / Revive / HillCaptured carry the moments.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Lore = require(Shared.Lore)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.PlayerData)
local Loot = require(script.Parent.Loot)
local Range = require(script.Parent.Range)
local Supply = require(script.Parent.Supply)
local Travel = require(script.Parent.Travel)
local Wallet = require(script.Parent.Wallet)

local W = Config.War
local War = {}
War.Zone = Range.Zone -- the war is fought inside the Range zone until it is its own place

local folder
local center -- arena centre (Range.ArenaCenter)
local sides = {} -- id -> { Def, Tickets, Recruits = { model = true }, Alive = n, Base = Vector3, NextPod, NextClone }
local order = {} -- faction ids in Config order
local hill = { Index = 0, Position = nil, Owner = nil, Capturing = nil, Progress = 0, MovedAt = 0, Ring = nil, Beam = nil }
local deployed = {} -- player -> { Side = id, ZonePay = 0, FieldKit = { [id] = n } | nil, Crate = Part | nil }
local round = 1
local rng = Random.new()

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 24, brightness or 1.5
	l.Parent = p
end

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function announceWar(text, kind)
	for player in deployed do
		if player.Parent then
			announce(player, text, kind)
		end
	end
end

local function sideDef(id)
	for _, f in W.Factions do
		if f.Id == id then
			return f
		end
	end
	return nil
end

local function publish()
	for id, side in sides do
		workspace:SetAttribute("War_Tickets_" .. id, side.Tickets)
		workspace:SetAttribute("War_Recruits_" .. id, side.Alive)
	end
	workspace:SetAttribute("War_HillOwner", hill.Owner or "")
	workspace:SetAttribute("War_HillCapturing", hill.Capturing or "")
	workspace:SetAttribute("War_HillProgress", hill.Progress)
	workspace:SetAttribute("War_HillPos", hill.Position or Vector3.zero)
	workspace:SetAttribute("War_Round", round)
end

-- ---------------------------------------------------------------------------------------------
-- Geometry: bases, facilities, the hill marker
-- ---------------------------------------------------------------------------------------------
local function buildBase(i, def)
	local pos = center + W.Bases[i]
	local pad = part({ Name = "Base_" .. def.Id, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 18, 18), CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = def.Color, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false })
	glow(pad, def.Color, 40, 1.2)
	pad:SetAttribute("Faction", def.Id)
	CollectionService:AddTag(pad, "WarBase")
	-- the cloning facility: a squat vat building behind the pad, lit in the side's colour
	local toCentre = (Vector3.new(center.X, pos.Y, center.Z) - pos).Unit
	local fpos = pos - toCentre * 16
	part({ Name = "Facility_" .. def.Id, Size = Vector3.new(14, 10, 10), Position = fpos + Vector3.new(0, 5, 0), Color = Color3.fromRGB(34, 36, 44), Material = Enum.Material.Metal })
	local vat = part({ Name = "Vat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 5, 5), CFrame = CFrame.new(fpos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = def.Color, Material = Enum.Material.Neon, Transparency = 0.3 })
	glow(vat, def.Color, 30, 1)
	local flag = part({ Name = "Flag", Size = Vector3.new(0.4, 14, 0.4), Position = pos + Vector3.new(6, 7, 6), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal })
	local banner = part({ Name = "Banner", Size = Vector3.new(0.2, 3, 5), Position = flag.Position + Vector3.new(0, 5, 2.6), Color = def.Color, Material = Enum.Material.Neon, CanCollide = false })
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop, billboard.MaxDistance = UDim2.fromOffset(240, 40), Vector3.new(0, 3, 0), true, 400
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, def.Name
	text.TextColor3, text.Font, text.TextScaled = def.Color, Enum.Font.GothamBlack, true
	text.Parent = billboard
	billboard.Parent = banner
	return pos, fpos
end

local function buildHill()
	local R = W.HillRadius
	hill.Ring = part({ Name = "Hill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, R * 2, R * 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	hill.Beam = part({ Name = "HillBeam", Size = Vector3.new(2, 120, 2), Position = center + Vector3.new(0, 60, 0), Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false })
	glow(hill.Ring, Color3.fromRGB(235, 235, 240), 60, 1.5)
	CollectionService:AddTag(hill.Ring, "WarHill")
end

local function colourHill()
	local def = hill.Owner and sideDef(hill.Owner)
	local color = if def then def.Color else Color3.fromRGB(235, 235, 240)
	hill.Ring.Color, hill.Beam.Color = color, color
	local light = hill.Ring:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
	end
end

local function moveHill(reason)
	local n = #W.HillPoints
	local index = hill.Index
	if n > 1 then
		repeat
			index = rng:NextInteger(1, n)
		until index ~= hill.Index
	else
		index = 1
	end
	hill.Index = index
	hill.Position = center + W.HillPoints[index]
	hill.Owner, hill.Capturing, hill.Progress, hill.MovedAt = nil, nil, 0, os.clock()
	hill.Ring.CFrame = CFrame.new(hill.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	hill.Beam.Position = hill.Position + Vector3.new(0, 60, 0)
	colourHill()
	publish()
	if reason then
		announceWar(("The hill has moved (%s)."):format(reason), "Event")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Recruits: pods and the facility
-- ---------------------------------------------------------------------------------------------
local function hillPosition()
	return hill.Position
end

local function spawnRecruit(side, position)
	local kit = Supply.Draw(side.Def.Id) -- the pool pays for every recruit fielded and decides its kit
	local model = NPCs.Spawn("Recruit", position, { Faction = side.Def.Id, Cloth = side.Def.Color, Name = side.Def.Name .. " Recruit", Home = hillPosition, Despawn = false, Kit = kit })
	if not model then
		return nil
	end
	side.Recruits[model] = true
	side.Alive += 1
	model.Humanoid.Died:Once(function()
		if side.Recruits[model] then
			side.Recruits[model] = nil
			side.Alive -= 1
			side.Tickets = math.max(0, side.Tickets - W.DeathTickets)
			publish()
		end
	end)
	return model
end

-- A re-entry pod: appears PodHeight above the base, falls over PodFallSeconds, opens into a squad.
local function dropPod(side)
	local def = side.Def
	local land = side.Base + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	local pod = part({ Name = "Pod_" .. def.Id, Size = Vector3.new(5, 8, 5), Position = land + Vector3.new(0, W.PodHeight, 0), Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Metal, CanCollide = false })
	local flame = part({ Name = "PodFlame", Size = Vector3.new(3, 6, 3), Position = pod.Position + Vector3.new(0, -7, 0), Color = def.Color, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false })
	glow(flame, def.Color, 40, 2)
	local tween = TweenService:Create(pod, TweenInfo.new(W.PodFallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = land + Vector3.new(0, 4, 0) })
	local tween2 = TweenService:Create(flame, TweenInfo.new(W.PodFallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = land + Vector3.new(0, -3, 0) })
	tween:Play()
	tween2:Play()
	Remotes.CombatEvent:FireAllClients("Pod", pod, def.Id)
	task.delay(W.PodFallSeconds, function()
		flame:Destroy()
		local n = math.min(W.Squad, W.MaxRecruitsPerSide - side.Alive)
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			spawnRecruit(side, land + Vector3.new(math.cos(a) * 4, 3, math.sin(a) * 4))
		end
		pod.Transparency = 0.5
		task.delay(6, function()
			pod:Destroy()
		end)
	end)
end

local function tickRecruits(now)
	for _, side in sides do
		if side.Alive < W.MaxRecruitsPerSide then
			if now >= side.NextPod then
				side.NextPod = now + W.PodIntervalSeconds
				dropPod(side)
			elseif now >= side.NextClone then
				side.NextClone = now + W.CloneIntervalSeconds
				spawnRecruit(side, side.Facility + Vector3.new(0, 3, 0) + (Vector3.new(center.X, 0, center.Z) - Vector3.new(side.Facility.X, 0, side.Facility.Z)).Unit * 9)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Shipments: a ready shipment lands as a crate at your base while you are deployed (Supply.lua owns
-- the queue). Open it (hold X) and the items are your FIELD KIT: equipped if they can be, forfeited
-- where you fall, returned to the stash when you leave alive.
-- ---------------------------------------------------------------------------------------------
local SUP = Config.Supply

local function equipFieldKit(player, items)
	local Weapons = require(Shared.Weapons)
	local Items = require(Shared.Items)
	local bestGun, bestMelee
	for id in items do
		local wdef = Weapons.Defs[id]
		if wdef then
			if Weapons.IsGun(wdef) then
				bestGun = bestGun or id
			else
				bestMelee = bestMelee or id
			end
		end
		local idef = Items.Defs[id]
		if idef and (idef.Type == "Armor" or idef.Type == "Cybernetic") then
			Gear.EquipGear(player, id)
		end
	end
	if bestGun or bestMelee then
		Gear.EquipWeapon(player, bestGun or bestMelee) -- a gun first: this is a shooting war
	end
end

local function openCrate(player, crate)
	local entry = deployed[player]
	if not (entry and entry.Crate == crate) then
		return
	end
	entry.Crate = nil
	crate:Destroy()
	local items = Supply.TakeShipment(player)
	if not items then
		return
	end
	entry.FieldKit = entry.FieldKit or {}
	local n = 0
	for id, count in items do
		entry.FieldKit[id] = (entry.FieldKit[id] or 0) + count
		n += count
	end
	equipFieldKit(player, items)
	Combat.SyncAmmo(player.Character)
	Combat.FX("Shipment", player.Character, player)
	announce(player, ("Shipment opened: %d items in hand. Lose them here, or carry them home."):format(n))
end

local function dropCrate(player, entry)
	local side = sides[entry.Side]
	local char = player.Character
	if not (side and char and char:FindFirstChild("HumanoidRootPart")) or entry.Crate then
		return
	end
	local land = side.Base + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(6, 12))
	local crate = part({ Name = "Crate_" .. player.Name, Size = Vector3.new(4, 3, 4), Position = land + Vector3.new(0, SUP.CrateHeight, 0), Color = side.Def.Color, Material = Enum.Material.DiamondPlate, CanCollide = true })
	crate:SetAttribute("Owner", player.UserId)
	entry.Crate = crate
	TweenService:Create(crate, TweenInfo.new(SUP.CrateFallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = land + Vector3.new(0, 1.5, 0) }):Play()
	Remotes.CombatEvent:FireAllClients("Pod", crate, side.Def.Id)
	announce(player, "Your shipment is coming down at the base.")
	task.delay(SUP.CrateFallSeconds, function()
		if not crate.Parent or entry.Crate ~= crate then
			return
		end
		glow(crate, side.Def.Color, 20, 2)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Your shipment", "Open", SUP.CrateOpenSeconds
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
		prompt.KeyboardKeyCode = Enum.KeyCode.X
		prompt.Parent = crate
		prompt.Triggered:Connect(function(who)
			if who == player then
				openCrate(player, crate)
			end
		end)
	end)
end
War.DropCrate = function(player)
	local entry = deployed[player]
	if entry then
		dropCrate(player, entry)
	end
end
War.OpenCrate = function(player)
	local entry = deployed[player]
	if entry and entry.Crate then
		openCrate(player, entry.Crate)
		return true
	end
	return false
end

local function clearCrate(entry)
	if entry.Crate then
		entry.Crate:Destroy()
		entry.Crate = nil
	end
end

-- Field kit on the way out: lost where you fell (as loot for whoever finds it) or carried home.
local function forfeitFieldKit(player, entry, at)
	if not entry.FieldKit then
		return
	end
	local lost = Supply.Forfeit(player, entry.FieldKit)
	entry.FieldKit = nil
	if next(lost) and at then
		Loot.Spawn(at, lost, { Label = player.DisplayName .. "'s field kit", Lifetime = 180 })
		announce(player, "Your field kit stays where you fell.")
	end
end

local function returnFieldKit(player, entry)
	if not entry.FieldKit then
		return
	end
	Supply.ReturnToStash(player, entry.FieldKit)
	entry.FieldKit = nil
	announce(player, "Your field kit is back in the stash.")
end

-- ---------------------------------------------------------------------------------------------
-- Players: deploy, down, revive, death, redeploy
-- ---------------------------------------------------------------------------------------------
function War.IsDeployed(player)
	return deployed[player] ~= nil
end

function War.Deploy(player)
	local char = player.Character
	local data = PlayerData.Get(player)
	if not (char and char:FindFirstChild("HumanoidRootPart") and data) then
		return false
	end
	local side = data.Faction and sides[data.Faction]
	if not side then
		announce(player, "Choose a side first - the consoles on the left.")
		return false
	end
	if Travel.To(player, "War", "War") then
		return true -- the war is its own place: its server deploys you on arrival (Location == "War")
	end
	for _, id in Config.Range.Loadout do -- the basic kit (the faction pool comes with shipments)
		if Inventory.Count(player, id) == 0 then
			Inventory.Add(player, id, 1)
		end
	end
	Gear.EquipWeapon(player, Config.Range.Loadout[1])
	player:SetAttribute("Zone", War.Zone)
	player:SetAttribute("ForceFirstPerson", true)
	char:SetAttribute("Deployed", true)
	char:SetAttribute("Downed", false)
	deployed[player] = deployed[player] or { Side = side.Def.Id, ZonePay = 0 }
	deployed[player].Side = side.Def.Id
	local base = side.Base
	char:PivotTo(CFrame.lookAt(base + Vector3.new(0, 4, 0), Vector3.new(hill.Position.X, base.Y + 4, hill.Position.Z)))
	Combat.Protect(char, Config.Range.EntryProtection)
	if not data.RiftSeen then
		data.RiftSeen = true
		announce(player, Lore.Get("FirstRift"), "Lore")
	end
	announce(player, ("Deployed with the %s. Hold the hill, keep your recruits alive, bring the money home."):format(side.Def.Name))
	Supply.Sync(player)
	if Supply.ShipmentEta(player) == 0 then
		dropCrate(player, deployed[player])
	end
	publish()
	return true
end

local function undeploy(player)
	local entry = deployed[player]
	local char = player.Character
	if char then
		char:SetAttribute("Deployed", nil)
		char:SetAttribute("Downed", nil)
	end
	if entry then
		clearCrate(entry)
		returnFieldKit(player, entry) -- walked out alive: the kit comes home
	end
	deployed[player] = nil
end

function War.Leave(player)
	undeploy(player)
	Range.Leave(player)
end

local function revive(victim, reviver)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not victim:GetAttribute("Downed") then
		return false
	end
	victim:SetAttribute("Downed", false)
	hum.PlatformStand = false
	hum.Health = math.max(1, hum.MaxHealth * W.ReviveHealthFraction)
	local s = Combat.State(victim)
	s.stunned = 0
	hum.WalkSpeed = Gear.OfChar(victim).WalkSpeed
	local prompt = victim.HumanoidRootPart:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
	Combat.FX("Revive", victim, reviver)
	local reviverPlayer = Players:GetPlayerFromCharacter(reviver)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if reviverPlayer then
		Wallet.Add(reviverPlayer, W.MoneyPerRevive)
		announce(reviverPlayer, ("Revived %s. +%d money."):format(victimPlayer and victimPlayer.DisplayName or "a recruit", W.MoneyPerRevive))
	end
	if victimPlayer then
		announce(victimPlayer, "You are back up.")
	end
	return true
end
War.Revive = revive

-- A lethal hit on a deployed player: down them instead. Returns true when handled.
local function down(victim, attacker)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	hum.Health = 1
	victim:SetAttribute("Downed", true)
	victim:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + W.DownedSeconds)
	hum.PlatformStand = true
	Combat.Stun(victim, W.DownedSeconds + 1)
	Combat.FX("Downed", victim, attacker)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Downed recruit", "Revive", W.ReviveSeconds
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 8, false
		prompt.KeyboardKeyCode = Enum.KeyCode.X
		prompt.Parent = root
		prompt.Triggered:Connect(function(reviver)
			local rchar = reviver.Character
			if rchar and rchar ~= victim and Combat.FactionOf(rchar) == Combat.FactionOf(victim) and not rchar:GetAttribute("Downed") then
				revive(victim, rchar)
			end
		end)
	end
	local player = Players:GetPlayerFromCharacter(victim)
	if player then
		announce(player, ("Downed. An ally can revive you; you bleed out in %d s."):format(W.DownedSeconds))
	end
	task.delay(W.DownedSeconds, function()
		if victim.Parent and victim:GetAttribute("Downed") and hum.Health > 0 then
			hum.Health = 0 -- bled out: a real death, handled by War.HandleDeath via Lifecycle
		end
	end)
	return true
end

Combat.LethalHook = function(victim, attacker, amount)
	if victim:GetAttribute("Deployed") and not victim:GetAttribute("Downed") then
		return down(victim, attacker)
	end
	return false
end

-- Lifecycle calls this first on any death; true = the war handled it (no permadeath).
War.Respawn = nil -- Lifecycle.Spawn, installed by Lifecycle (avoids a require cycle)
function War.HandleDeath(player)
	local entry = deployed[player]
	if not entry then
		return false
	end
	local char = player.Character
	local side = sides[entry.Side]
	if side then
		side.Tickets = math.max(0, side.Tickets - W.DeathTickets)
	end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	forfeitFieldKit(player, entry, root and root.CFrame + Vector3.new(0, 1, 0) or nil)
	local _, killer = Combat.GetKiller(char)
	if killer and killer ~= player and deployed[killer] then
		Wallet.Add(killer, W.MoneyPerPlayerTakedown)
		announce(killer, ("Takedown: %s. +%d money."):format(player.DisplayName, W.MoneyPerPlayerTakedown))
	end
	announce(player, ("You died. Redeploying from your base in %d s. (Nothing permanent happens here - this is hell, and you have accepted it.)"):format(W.RedeploySeconds))
	publish()
	task.delay(W.RedeploySeconds, function()
		if not (player.Parent and deployed[player] and War.Respawn) then
			return
		end
		-- Lifecycle.Spawn may yield (creator, tutorial); wait for the new body rather than its return
		local old = player.Character
		task.spawn(War.Respawn, player)
		local t0 = os.clock()
		repeat
			task.wait(0.1)
		until (player.Character ~= old and player.Character and player.Character:FindFirstChild("HumanoidRootPart")) or os.clock() - t0 > 10 or not player.Parent
		if player.Parent and deployed[player] and player.Character and player.Character ~= old then
			War.Deploy(player)
		end
	end)
	return true
end

-- ---------------------------------------------------------------------------------------------
-- The hill and the round
-- ---------------------------------------------------------------------------------------------
local function insideHill(position)
	local d = Vector3.new(position.X - hill.Position.X, 0, position.Z - hill.Position.Z)
	return d.Magnitude <= W.HillRadius
end

local function endRound()
	local winner, best = nil, -1
	for id, side in sides do
		if side.Tickets > best then
			winner, best = id, side.Tickets
		end
	end
	local def = sideDef(winner)
	announceWar(("Round %d: the %s hold the field."):format(round, def and def.Name or winner), "Emergence")
	for player, entry in deployed do
		if entry.Side == winner then
			Wallet.Add(player, W.MoneyRoundWin)
			announce(player, ("Your side took the round. +%d money."):format(W.MoneyRoundWin))
		end
	end
	round += 1
	for _, side in sides do
		side.Tickets = W.Tickets
		for model in side.Recruits do
			model:Destroy()
		end
		side.Recruits, side.Alive = {}, 0
		side.NextPod, side.NextClone = os.clock() + 2, os.clock() + W.CloneIntervalSeconds
	end
	moveHill("new round")
end
War.EndRound = endRound

local lastDrain = 0
local function tickHill(dt, now)
	-- who is on the hill
	local present = {}
	for player, entry in deployed do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not char:GetAttribute("Downed") and insideHill(root.Position) then
			present[entry.Side] = (present[entry.Side] or 0) + 1
			entry.ZonePay += W.MoneyPerZoneSecond * dt
			if entry.ZonePay >= 1 then
				local whole = math.floor(entry.ZonePay)
				entry.ZonePay -= whole
				Wallet.Add(player, whole)
			end
		end
	end
	for id, side in sides do
		for model in side.Recruits do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and insideHill(root.Position) then
				present[id] = (present[id] or 0) + 1
			end
		end
	end
	local only, count = nil, 0
	for id in present do
		only, count = id, count + 1
	end
	if count == 1 and only ~= hill.Owner then
		if hill.Capturing ~= only then
			hill.Capturing, hill.Progress = only, 0
		end
		hill.Progress = math.min(1, hill.Progress + dt / W.CaptureSeconds)
		if hill.Progress >= 1 then
			hill.Owner, hill.Capturing, hill.Progress = only, nil, 0
			local def = sideDef(only)
			colourHill()
			Remotes.CombatEvent:FireAllClients("HillCaptured", hill.Ring, only)
			announceWar(("The %s hold the hill."):format(def and def.Name or only), "Event")
			if W.HillMoveOnCapture then
				task.delay(3, function()
					if hill.Owner == only then
						moveHill("captured")
					end
				end)
			end
		end
	elseif count ~= 1 then
		-- contested or empty: progress freezes (an empty hill keeps its owner)
	end
	-- the holder bleeds the others
	if hill.Owner and now - lastDrain >= W.HillDrainSeconds then
		lastDrain = now
		for id, side in sides do
			if id ~= hill.Owner then
				side.Tickets = math.max(0, side.Tickets - 1)
			end
		end
	end
	-- the hill moves on its own
	if now - hill.MovedAt >= W.HillMoveSeconds then
		moveHill("time")
	end
	-- round over?
	for _, side in sides do
		if side.Tickets <= 0 then
			endRound()
			break
		end
	end
	publish()
end

-- ---------------------------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------------------------
function War.Init()
	if workspace:FindFirstChild("War") then
		return
	end
	center = Range.ArenaCenter
	folder = Instance.new("Folder")
	folder.Name = "War"
	folder.Parent = workspace
	for i, def in W.Factions do
		local base, facility = buildBase(i, def)
		sides[def.Id] = { Def = def, Tickets = W.Tickets, Recruits = {}, Alive = 0, Base = base, Facility = facility, NextPod = os.clock() + 2 + i, NextClone = os.clock() + W.CloneIntervalSeconds }
		table.insert(order, def.Id)
	end
	buildHill()
	moveHill(nil)
	-- leaving the zone by any door (the Return rift, War.Leave) ends the deployment
	local prevLeave = Range.OnLeave
	Range.OnLeave = function(player)
		undeploy(player)
		if prevLeave then
			prevLeave(player)
		end
	end
	Supply.Init()
	-- takedowns of AI recruits pay the killer
	NPCs.Killed.Event:Connect(function(killer, model)
		if model:GetAttribute("Faction") and deployed[killer] then
			Wallet.Add(killer, W.MoneyPerTakedown)
		end
	end)
	-- the loop
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		tickRecruits(now)
		tickHill(step, now)
		for player, entry in deployed do -- shipments land while you are on the field
			if not entry.Crate and Supply.ShipmentEta(player) == 0 and not (player.Character and player.Character:GetAttribute("Downed")) then
				dropCrate(player, entry)
			end
		end
	end)
	-- leaving players
	Players.PlayerRemoving:Connect(function(player)
		local entry = deployed[player]
		if entry then
			clearCrate(entry)
			returnFieldKit(player, entry) -- a leaver keeps the kit (combat-logging has no stake here)
		end
		deployed[player] = nil
	end)
	War.Built = { Sides = #order }
	publish()
end

-- for tests and consoles
function War.Sides()
	return sides
end
function War.Hill()
	return hill
end
function War.MoveHill(reason)
	moveHill(reason)
end

return War
