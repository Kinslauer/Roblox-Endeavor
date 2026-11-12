-- Companions (round 7 of docs/Reference-Picks-Plan.md; Andy's row: "natural dog, cyberdog, drone, hybrid").
-- Tuning: Config.Make.Companion. One per conduit, kept with the bay (data.Hideout.Companion = { Kind, Name, Health }):
-- it outlives the conduit's death and comes back with the next body, but a companion that dies is gone.
--   Dog       a stray in the green pockets (natural life lives only there); feed it a ration (X) and it follows you
--   Cyberdog  the Dealer's frame, Used from the pack: tougher, its bite shocks
--   Drone     a shell made at the bench, Used from the pack: flies at your shoulder and shoots
--   Hybrid    a dog with a Cyber Graft (Used near your bay's Autonet): bites and shoots
-- Dogs (and the hybrid) sniff out containers near you (World "Sniff"). A companion goes for the nearest hostile near
-- you; it never hurts you (the model's attribute Owner, Combat.applyDamage). Remote "Companion"("Dismiss").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Megacity = require(Shared.Megacity)
local PlayerData = require(script.Parent.Common.PlayerData)
local Net = require(script.Parent.Common.Net)

local CC = Config.Make.Companion
local Companions = {}
local out = {} -- player -> { Model, Hum, Root, Def, Kind, NextBite, NextShot, NextSniff }
local strays = {} -- pocket key -> model
local rng = Random.new()
local NAMES = { "ASH", "RUST", "BOLT", "SOOT", "PIKE", "MOTH", "TALLOW", "CINDER", "WICK", "BURR" }

local function lazy(name)
	return require(script.Parent[name])
end

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function part(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- The bodies, made of parts (no uploaded model yet).
local function buildDog(cf, kind)
	local model = Instance.new("Model")
	model.Name = kind
	local metal = kind == "Cyberdog"
	local coat = if metal then Color3.fromRGB(88, 92, 98) else Color3.fromRGB(122, 98, 72)
	local mat = if metal then Enum.Material.Metal else Enum.Material.Fabric
	local root = part(model, "HumanoidRootPart", Vector3.new(1.4, 1.2, 2.8), cf, coat, mat)
	root.Transparency, root.CanCollide = 1, true
	local body = part(model, "Body", Vector3.new(1.3, 1.1, 2.6), cf, coat, mat)
	local head = part(model, "Head", Vector3.new(0.9, 0.9, 1), cf * CFrame.new(0, 0.55, -1.6), coat, mat)
	local snout = part(model, "Snout", Vector3.new(0.5, 0.45, 0.6), cf * CFrame.new(0, 0.4, -2.3), coat:Lerp(Color3.new(0, 0, 0), 0.3), mat)
	local earL = part(model, "EarL", Vector3.new(0.2, 0.45, 0.3), cf * CFrame.new(-0.3, 1.1, -1.5), coat, mat)
	local earR = part(model, "EarR", Vector3.new(0.2, 0.45, 0.3), cf * CFrame.new(0.3, 1.1, -1.5), coat, mat)
	local tail = part(model, "Tail", Vector3.new(0.2, 0.2, 1), cf * CFrame.new(0, 0.5, 1.6) * CFrame.Angles(math.rad(30), 0, 0), coat, mat)
	for _, p in { body, head, snout, earL, earR, tail } do
		weld(root, p)
	end
	for _, at in { Vector3.new(-0.45, -1, -0.9), Vector3.new(0.45, -1, -0.9), Vector3.new(-0.45, -1, 0.9), Vector3.new(0.45, -1, 0.9) } do
		weld(root, part(model, "Leg", Vector3.new(0.3, 1.1, 0.3), cf * CFrame.new(at), coat, mat))
	end
	if metal or kind == "Hybrid" then
		local eye = part(model, "Eye", Vector3.new(0.6, 0.12, 0.1), cf * CFrame.new(0, 0.7, -2.12), Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
		weld(root, eye)
	end
	if kind == "Hybrid" then
		local pod = part(model, "Pod", Vector3.new(0.6, 0.4, 0.9), cf * CFrame.new(0, 0.85, 0.2), Color3.fromRGB(70, 74, 80), Enum.Material.Metal)
		local barrel = part(model, "Barrel", Vector3.new(0.12, 0.12, 0.8), cf * CFrame.new(0, 0.95, -0.5), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		weld(root, pod)
		weld(root, barrel)
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 1.05
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = root
	return model, hum, root
end

local function buildDrone(cf)
	local model = Instance.new("Model")
	model.Name = "Drone"
	local root = part(model, "HumanoidRootPart", Vector3.new(1.6, 0.5, 1.6), cf, Color3.fromRGB(60, 64, 70), Enum.Material.Metal)
	root.Anchored = true
	for _, at in { Vector3.new(-1, 0.1, -1), Vector3.new(1, 0.1, -1), Vector3.new(-1, 0.1, 1), Vector3.new(1, 0.1, 1) } do
		local rotor = part(model, "Rotor", Vector3.new(0.9, 0.06, 0.9), cf * CFrame.new(at), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		rotor.Anchored = true
	end
	local lamp = part(model, "Eye", Vector3.new(0.35, 0.2, 0.2), cf * CFrame.new(0, -0.2, -0.75), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	lamp.Anchored = true
	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = root
	return model, hum, root
end

local function companionOf(player)
	local data = PlayerData.Get(player)
	return data and data.Hideout.Companion, data
end

function Companions.Get(player)
	return out[player]
end

local function despawn(player)
	local c = out[player]
	out[player] = nil
	if c and c.Model.Parent then
		c.Model:Destroy()
	end
end

-- Put the kept companion beside its conduit's body.
function Companions.Summon(player)
	despawn(player)
	local keep = companionOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (keep and root) then
		return nil
	end
	local def = CC.Kinds[keep.Kind]
	if not def then
		return nil
	end
	local cf = root.CFrame * CFrame.new(2.5, 0, 2)
	local model, hum, croot
	if keep.Kind == "Drone" then
		model, hum, croot = buildDrone(cf + Vector3.new(0, def.Fly, 0))
	else
		model, hum, croot = buildDog(cf, keep.Kind)
	end
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Companion", keep.Kind)
	model:SetAttribute("CompanionName", keep.Name)
	hum.MaxHealth = def.Health
	hum.Health = math.clamp(keep.Health or def.Health, 1, def.Health)
	hum.WalkSpeed = def.Speed
	model.Parent = workspace
	pcall(function()
		if not croot.Anchored then
			croot:SetNetworkOwner(nil)
		end
	end)
	local c = { Model = model, Hum = hum, Root = croot, Def = def, Kind = keep.Kind, NextBite = 0, NextShot = 0, NextSniff = 0 }
	out[player] = c
	hum.HealthChanged:Connect(function(h)
		local k = companionOf(player)
		if k and out[player] == c then
			k.Health = h
		end
	end)
	hum.Died:Once(function()
		if out[player] ~= c then
			return
		end
		local data = PlayerData.Get(player)
		if data then
			data.Hideout.Companion = nil
		end
		out[player] = nil
		say(player, "> " .. (keep.Name or keep.Kind) .. " . GONE", "Warning")
		task.delay(6, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end)
	return model
end

function Companions.Keep(player, kind, name)
	local data = PlayerData.Get(player)
	if not data or data.Hideout.Companion then
		return false
	end
	data.Hideout.Companion = { Kind = kind, Name = name or NAMES[rng:NextInteger(1, #NAMES)], Health = CC.Kinds[kind].Health }
	Companions.Summon(player)
	say(player, ("> %s . %s"):format(string.upper(CC.Kinds[kind].Name), data.Hideout.Companion.Name), "Reward")
	return true
end

function Companions.Dismiss(player)
	local data = PlayerData.Get(player)
	if not (data and data.Hideout.Companion) then
		return false
	end
	data.Hideout.Companion = nil
	despawn(player)
	return true
end

-- Inventory.Use: a Cyberdog frame or drone shell wakes up; a graft makes a dog a hybrid (at the bay's Autonet).
function Companions.UseItem(player, itemId, def)
	local Inventory = lazy("Inventory")
	local keep = companionOf(player)
	if def.Graft then
		local site = lazy("Hideouts").SiteOf(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (keep and keep.Kind == "Dog") then
			say(player, "> GRAFT . NO DOG", "Warning")
			return false
		end
		if not (site and site.AutonetAt and root and (root.Position - site.AutonetAt).Magnitude <= 14) then
			say(player, "> GRAFT . AUTONET NEEDED", "Warning")
			return false
		end
		Inventory.Remove(player, itemId, 1)
		keep.Kind, keep.Health = "Hybrid", CC.Kinds.Hybrid.Health
		Companions.Summon(player)
		say(player, "> " .. keep.Name .. " . GRAFTED", "Reward")
		return true
	end
	if keep then
		say(player, "> " .. keep.Name .. " . ALREADY WITH YOU", "Warning")
		return false
	end
	Inventory.Remove(player, itemId, 1)
	return Companions.Keep(player, def.Companion)
end

-- ===== strays in the green pockets =====
local function placeStray(pocket)
	local old = strays[pocket.Key]
	if old and old.Parent then
		return old
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local at = pocket.Center + Vector3.new(math.cos(a) * pocket.Radius * 0.4, 40, math.sin(a) * pocket.Radius * 0.4)
	local hit = workspace:Raycast(at, Vector3.new(0, -80, 0))
	local y = if hit then hit.Position.Y + 1.6 else 3
	local model, hum, root = buildDog(CFrame.new(at.X, y, at.Z) * CFrame.Angles(0, a, 0), "Dog")
	model.Name = "Stray"
	model:SetAttribute("Stray", pocket.Key)
	hum.MaxHealth, hum.Health = CC.Kinds.Dog.Health, CC.Kinds.Dog.Health
	hum.WalkSpeed = 8
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "", "Feed", 1
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 7, false, Enum.KeyCode.X
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		Companions.Tame(player, model)
	end)
	model.Parent = workspace
	strays[pocket.Key] = model
	return model
end

function Companions.Tame(player, stray)
	local Inventory = lazy("Inventory")
	if not (stray and stray.Parent and stray:GetAttribute("Stray")) then
		return false
	end
	if companionOf(player) then
		say(player, "> IT WILL NOT COME . YOU HAVE ONE", "Warning")
		return false
	end
	if Inventory.Count(player, "Ration") <= 0 then
		say(player, "> IT WANTS FOOD", "Info")
		return false
	end
	Inventory.Remove(player, "Ration", 1)
	strays[stray:GetAttribute("Stray")] = nil
	stray:Destroy()
	return Companions.Keep(player, "Dog")
end

function Companions.Strays()
	return strays
end

-- ===== behaviour =====
local function hostileNear(c, owner, position)
	local best, bestD = nil, CC.Aggro
	for _, m in CollectionService:GetTagged("NPC") do
		local r = m:FindFirstChild("HumanoidRootPart")
		local h = m:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and not m:GetAttribute("Contact") and not m:GetAttribute("Owner") and m ~= c.Model then
			local d = (r.Position - position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function think(player, c, dt)
	local char = player.Character
	local proot = char and char:FindFirstChild("HumanoidRootPart")
	if not (proot and c.Hum.Health > 0 and c.Model.Parent) then
		return
	end
	local Combat = lazy("Combat")
	local now = os.clock()
	local here = c.Root.Position
	if (here - proot.Position).Magnitude > CC.Leash then
		c.Model:PivotTo(proot.CFrame * CFrame.new(2.5, if c.Kind == "Drone" then c.Def.Fly else 0, 2)) -- it catches up
		return
	end
	local target = hostileNear(c, player, proot.Position)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	if c.Kind == "Drone" then
		-- hover at the shoulder, turn to what it shoots
		local want = proot.Position + proot.CFrame.RightVector * 2.5 + Vector3.new(0, c.Def.Fly, 0)
		local look = if troot then troot.Position else want + proot.CFrame.LookVector
		local cf = CFrame.lookAt(here:Lerp(want, math.min(1, dt * 4)), look)
		local delta = cf * c.Root.CFrame:Inverse()
		for _, p in c.Model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = delta * p.CFrame
			end
		end
	else
		if troot then
			c.Hum:MoveTo(troot.Position)
		elseif (here - proot.Position).Magnitude > CC.Follow then
			c.Hum:MoveTo(proot.Position + proot.CFrame.RightVector * 2)
		end
	end
	if troot then
		local d = (troot.Position - here).Magnitude
		if c.Def.Bite and d < 4.5 and now >= c.NextBite then
			c.NextBite = now + c.Def.Bite
			Combat.Damage(c.Model, target, c.Def.Damage, { Type = if c.Def.Shock then "Arc" else "Physical", Posture = 6, Stun = c.Def.Shock or 0.3 })
		end
		if c.Def.Shoot and d < c.Def.Range and now >= c.NextShot then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { c.Model, char }
			local from = here + Vector3.new(0, 0.6, 0)
			local hit = workspace:Raycast(from, (troot.Position - from).Unit * c.Def.Range, params)
			if hit and hit.Instance:IsDescendantOf(target) then
				c.NextShot = now + c.Def.Shoot
				Combat.Damage(c.Model, target, c.Def.Damage, { Type = "Arc", Posture = 3, Stun = 0.15 })
				Remotes.CombatEvent:FireAllClients("Bolt", c.Model, hit.Position)
			end
		end
	end
	-- a dog's nose: containers near its conduit
	if c.Def.Sniff and now >= c.NextSniff then
		c.NextSniff = now + CC.SniffEvery
		local found = {}
		for _, p in CollectionService:GetTagged("Scent") do
			if p:IsA("BasePart") and p.Name == "Lootable" and (p.Position - here).Magnitude < CC.Sniff then
				table.insert(found, p)
			end
		end
		if #found > 0 then
			Remotes.World:FireClient(player, "Sniff", found)
		end
	end
end

function Companions.Init()
	for _, pocket in Megacity.Pockets do
		pcall(placeStray, pocket)
	end
	Net.On("Companion", { rate = 2, burst = 3, args = { "string" } }, function(player, action)
		if action == "Dismiss" then
			Companions.Dismiss(player)
		end
	end)
	-- every new body brings its companion along (the bay kept it)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			task.delay(2, function()
				if companionOf(player) and player.Character then
					Companions.Summon(player)
				end
			end)
		end)
	end
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(despawn)
	task.spawn(function()
		local last, strayAt = os.clock(), os.clock()
		while true do
			task.wait(CC.Think)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, c in out do
				local ok, err = pcall(think, player, c, dt)
				if not ok then
					warn("[Companions] " .. tostring(err))
				end
			end
			if now - strayAt > CC.StrayRespawn then
				strayAt = now
				for _, pocket in Megacity.Pockets do
					pcall(placeStray, pocket)
				end
			end
		end
	end)
end

return Companions
