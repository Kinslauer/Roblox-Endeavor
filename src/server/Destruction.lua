-- Destruction & Salvage (docs/systems/destruction-and-salvage.md).
-- The environment is a weapon, a resource and a door: props break into salvage and grabbable
-- chunks, chunks can be thrown or swung, explosions damage people and world with line of sight,
-- breach points open locked buildings, and everything broken returns at dematerialization.
-- All state lives here on the server; clients only render effects from the "World" remote.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Props = require(Shared.Props)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Loot = require(script.Parent.Loot)
local Net = require(script.Parent.Common.Net)
local NPCs = require(script.Parent.NPCs)
local Stats = require(script.Parent.Stats)
local Gore = require(script.Parent.Gore)

local D = Config.Destruction
local Destruction = {}
Destruction.Broken = Instance.new("BindableEvent") -- (propModel, attackerChar?)
Destruction.Breached = Instance.new("BindableEvent") -- (breachModel, attackerChar?)

local folder -- everything the system spawns lives under here
local props = {} -- [model] = { def, id, intact = bool, cframe, health }
local breaches = {} -- [model] = { tier, door, health, open }
local chunks = {} -- ordered list of loose chunks { part, spawnedAt, settledAt }
local held = {} -- [player] = { part, chunkDef, weld }
local catchAttempt = {} -- [characterModel] = os.clock() of the last grab press at an incoming chunk
local rng = Random.new()

local function world(kind, ...)
	Remotes.World:FireAllClients(kind, ...)
end

local function getHum(model)
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- ===== Noise: breaches and explosions draw nearby NPCs =====
function Destruction.Noise(position, radius)
	NPCs.Alert(position, radius or D.NoiseRadius)
end

-- ===== Props =====
local function buildPart(spec, origin, parent)
	local p = Instance.new("Part")
	p.Size = spec.Size
	p.Color, p.Material = spec.Color, spec.Material or Enum.Material.Metal
	p.Transparency = spec.Transparency or 0
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if spec.Shape then
		p.Shape = spec.Shape
	end
	local cf = origin * CFrame.new(spec.Offset or Vector3.zero)
	if spec.Vertical then
		cf = cf * CFrame.Angles(0, 0, math.pi / 2)
	end
	p.CFrame = cf
	if spec.Light then
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 18, 1, spec.Color
		light.Parent = p
	end
	p.Parent = parent
	return p
end

-- Spawns an intact prop at `cframe`. Returns the model.
function Destruction.SpawnProp(propId, cframe)
	local def = Props.Defs[propId]
	assert(def, "unknown prop " .. tostring(propId))
	local model = Instance.new("Model")
	model.Name = propId
	for _, spec in def.Parts do
		buildPart(spec, cframe, model)
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	model:SetAttribute("Prop", propId)
	model:SetAttribute("Health", def.Health)
	CollectionService:AddTag(model, "Destructible")
	model.Parent = folder
	props[model] = { def = def, id = propId, intact = true, cframe = cframe, health = def.Health }
	return model
end

-- ===== Chunks (loose debris; the grabbable part of the system) =====
local function settle(entry)
	if entry.settledAt then
		return
	end
	entry.settledAt = os.clock()
	entry.part.Anchored = true
end

local function removeChunk(entry)
	local i = table.find(chunks, entry)
	if i then
		table.remove(chunks, i)
	end
	if entry.part.Parent then
		entry.part:Destroy()
	end
end

local function spawnChunk(chunkDef, cframe, impulse)
	local p = Instance.new("Part")
	p.Name = chunkDef.Name
	p.Size, p.Color, p.Material = chunkDef.Size, chunkDef.Color, chunkDef.Material or Enum.Material.Metal
	p.CFrame = cframe
	p.Anchored = false
	p:SetAttribute("Chunk", true)
	p:SetAttribute("Weight", chunkDef.Weight)
	p:SetAttribute("Label", chunkDef.Name)
	if chunkDef.Improvised then
		p:SetAttribute("Improvised", true)
		p:SetAttribute("Durability", chunkDef.Durability or 5)
	end
	CollectionService:AddTag(p, "Grabbable")
	p.Parent = folder
	p:SetNetworkOwner(nil)
	p.AssemblyLinearVelocity = impulse
	local entry = { part = p, chunkDef = chunkDef, spawnedAt = os.clock(), settledAt = nil, restAt = nil }
	table.insert(chunks, entry)
	p.Destroying:Connect(function()
		local i = table.find(chunks, entry)
		if i then
			table.remove(chunks, i)
		end
	end)
	-- budget: past the cap, the oldest settled chunk goes first; failing that, the oldest
	-- chunk nobody is holding or throwing. The cap must hold even if nothing ever settles.
	while #chunks > D.LooseChunkCap do
		local victim
		for _, e in chunks do
			if e.settledAt and not e.heldBy then
				victim = e
				break
			end
		end
		if not victim then
			for _, e in chunks do
				if not e.heldBy and not e.inFlight then
					victim = e
					break
				end
			end
		end
		if not victim then
			break
		end
		removeChunk(victim)
	end
	return p, entry
end

local function entryOf(part)
	for _, e in chunks do
		if e.part == part then
			return e
		end
	end
	return nil
end

-- ===== Breaking =====
local function salvage(def, cframe)
	local bundle = Items.Roll(def.Salvage)
	if next(bundle) == nil then
		return
	end
	local remains = Loot.Spawn(cframe + Vector3.new(0, 1, 0), bundle, { Label = "Salvage", Action = "Salvage", Hold = Config.LootHold, Lifetime = D.ChunkLifetime, Color = Color3.fromRGB(80, 80, 70), Size = Vector3.new(2, 1, 2) })
	if remains then
		CollectionService:AddTag(remains, "Salvage")
		remains.Parent = folder
		-- salvage nobody picks up is capped too, oldest first
		local all = CollectionService:GetTagged("Salvage")
		while #all > D.SalvageCap do
			local oldest = table.remove(all, 1)
			if oldest and oldest.Parent then
				oldest:Destroy()
			end
		end
	end
end

local function breakProp(model, attacker, damageType)
	local entry = props[model]
	if not entry or not entry.intact then
		return
	end
	entry.intact = false
	local origin = entry.cframe
	model:SetAttribute("Health", 0)
	model.Parent = nil -- kept in `props` so dematerialization can bring it back
	world("Break", origin.Position, entry.id)
	for i, chunkDef in entry.def.Chunks do
		local a = (i / #entry.def.Chunks) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0.6, math.sin(a))
		spawnChunk(chunkDef, origin * CFrame.new(dir * 2 + Vector3.new(0, 2 + i, 0)), dir * rng:NextNumber(8, 16))
	end
	salvage(entry.def, origin)
	Destruction.Broken:Fire(model, attacker)
	if entry.def.Volatile and (damageType == "Explosive" or damageType == "Arc") then
		task.delay(0.4, function()
			Destruction.Explode(origin.Position, D.Explosion.Barrel, attacker)
		end)
	end
end

-- Applies world damage to a destructible prop model. Returns true if it broke.
function Destruction.HitProp(model, amount, damageType, attacker)
	local entry = props[model]
	if not entry or not entry.intact then
		return false
	end
	local resist = entry.def.Resist[damageType] or 0
	amount *= 1 - resist
	if amount <= 0 then
		return false
	end
	entry.health -= amount
	model:SetAttribute("Health", math.max(0, entry.health))
	world("PropHit", entry.cframe.Position)
	if entry.health <= 0 then
		breakProp(model, attacker, damageType)
		return true
	end
	return false
end

-- ===== Breach points =====
-- A breach point is a model with a `door` part filling an authored opening. On breach, the door
-- is removed and a frame of the same opening stays, so the hole is always the size designed.
function Destruction.SpawnBreach(tier, cframe, size)
	local tdef = Props.BreachTiers[tier]
	assert(tdef, "unknown breach tier " .. tostring(tier))
	local model = Instance.new("Model")
	model.Name = "Breach_" .. tier
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size, door.CFrame, door.Anchored = size, cframe, true
	door.Color, door.Material = tdef.Color, tdef.Material
	door.Parent = model
	model.PrimaryPart = door
	model:SetAttribute("Tier", tier)
	model:SetAttribute("Label", tdef.Label)
	model:SetAttribute("Health", tdef.Health)
	CollectionService:AddTag(model, "Breachable")
	model.Parent = folder
	breaches[model] = { model = model, tier = tier, tdef = tdef, door = door, health = tdef.Health, open = false, cframe = cframe, size = size }
	return model
end

function Destruction.HitBreach(model, amount, damageType, attacker)
	local entry = breaches[model]
	if not entry or entry.open then
		return false
	end
	if not entry.tdef.Allowed[damageType] then
		world("BreachResist", entry.cframe.Position) -- a clang and a hint, not damage
		return false
	end
	entry.health -= amount
	model:SetAttribute("Health", math.max(0, entry.health))
	world("PropHit", entry.cframe.Position)
	if entry.health <= 0 then
		entry.open = true
		entry.door.Parent = nil
		world("Breach", entry.cframe.Position)
		Destruction.Noise(entry.cframe.Position)
		Destruction.Breached:Fire(model, attacker)
		return true
	end
	return false
end

-- ===== Damage routing from Combat =====
local FAMILY_TYPE = { Fists = "Blunt", Blunt = "Blunt", Blade = "Blade", Baton = "Arc", Spear = "Blade", Hammer = "Blunt", Sidearm = "Arc" }

local function worldTarget(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model and props[model] then
		return "prop", model
	elseif model and breaches[model] then
		return "breach", model
	end
	return nil
end

function Destruction.HitInstance(part, amount, damageType, attacker)
	local kind, model = worldTarget(part)
	if kind == "prop" then
		return Destruction.HitProp(model, amount, damageType, attacker)
	elseif kind == "breach" then
		return Destruction.HitBreach(model, amount, damageType, attacker)
	end
	return false
end

-- Called by Combat.pulse for every melee swing: hits props/breach points in the swing arc.
local function onSwing(char, origin, look, spec, damage, weapon, isHeavy, seen)
	local damageType = if spec.Type == "Arc" then "Arc" else (FAMILY_TYPE[weapon and weapon.Family] or "Blunt")
	if weapon and weapon.Family == "Hammer" and isHeavy then
		damageType = "Sledge"
	end
	if spec.Ranged then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	for _, part in workspace:GetPartBoundsInRadius(origin, spec.Range + 1, params) do
		local kind, model = worldTarget(part)
		if kind and not seen[model] then
			local flat = (part.Position - origin) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 4 or look:Dot(flat.Unit) >= spec.Arc then
				seen[model] = true
				Destruction.HitInstance(part, damage, damageType, char)
			end
		end
	end
end

local function onBolt(char, hitInstance, damage, weapon)
	Destruction.HitInstance(hitInstance, damage, "Arc", char)
end

-- Improvised weapon durability: each landed hit wears the held chunk.
local function onImprovisedHit(player)
	local h = held[player]
	if not h or not h.part:GetAttribute("Improvised") then
		return
	end
	local left = (h.part:GetAttribute("Durability") or 1) - 1
	h.part:SetAttribute("Durability", left)
	if left <= 0 then
		world("Break", h.part.Position, "Chunk")
		Destruction.Drop(player, true)
	end
end

-- ===== Explosions =====
-- spec: { Radius, Damage, World }. One shared function for grenades, charges, barrels, artillery.
function Destruction.Explode(origin, spec, attacker)
	world("Explosion", origin, spec.Radius)
	Destruction.Noise(origin)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local function visible(target, exclude)
		ray.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(origin, target - origin, ray)
		return result == nil or (result.Position - target).Magnitude < 2.5
	end
	-- characters (players and NPCs): falloff with distance, blocked by cover
	local candidates = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(candidates, player.Character)
		end
	end
	for _, npc in CollectionService:GetTagged("NPC") do
		if npc.Parent then
			table.insert(candidates, npc)
		end
	end
	for _, model in candidates do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and getHum(model) then
			local dist = (root.Position - origin).Magnitude
			if dist <= spec.Radius and visible(root.Position, { model }) then
				local falloff = 1 - (dist / spec.Radius) ^ 1.5
				-- SelfHarm: your own grenade hurts you too (armor and posture still apply)
				Combat.Damage(attacker or model, model, spec.Damage * falloff, {
					Posture = spec.Damage * falloff, Type = "Explosive", Unblockable = true, SelfHarm = true,
					Knockback = 50 * falloff + 20, Stun = 0.8,
				})
			end
		end
	end
	-- world: props, breach points, loose chunks
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local hitModels = {}
	for _, part in workspace:GetPartBoundsInRadius(origin, spec.Radius, params) do
		local kind, model = worldTarget(part)
		if kind and not hitModels[model] then
			hitModels[model] = true
			if visible(part.Position, { model, folder }) then
				local dist = (part.Position - origin).Magnitude
				Destruction.HitInstance(part, spec.World * (1 - (dist / spec.Radius) ^ 1.5), "Explosive", attacker)
			end
		elseif part:GetAttribute("Chunk") and not part.Anchored and not (entryOf(part) and entryOf(part).heldBy) then
			local away = part.Position - origin
			part.AssemblyLinearVelocity = (if away.Magnitude > 0.5 then away.Unit else Vector3.yAxis) * 40 + Vector3.new(0, 25, 0)
		elseif part:GetAttribute("Chunk") then
			part.Anchored = false -- explosions wake settled debris
			local e = entryOf(part)
			if e then
				e.settledAt, e.restAt = nil, nil
			end
		end
	end
end

-- ===== Grenades and charges (used via Inventory.Use) =====
local function handsFull(char)
	local class = char:GetAttribute("HoldClass")
	return class == "Medium" or class == "Heavy"
end

-- Where a thrown object may appear: never on the far side of a wall the thrower is pressed against.
local function launchPoint(char, root, direction, distance)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { char }
	local target = root.Position + direction * distance + Vector3.new(0, 1.5, 0)
	local hit = workspace:Raycast(root.Position, target - root.Position, ray)
	return if hit then hit.Position - direction * 0.6 else target
end

function Destruction.ThrowGrenade(player, direction)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not Combat.CanAct(char) or handsFull(char) then
		return false
	end
	Combat.SetBusy(char, 0.3)
	local spec = D.Explosion.Grenade
	direction = if typeof(direction) == "Vector3" and direction.Magnitude > 0.1 then direction.Unit else root.CFrame.LookVector
	local nade = Instance.new("Part")
	nade.Name, nade.Shape, nade.Size = "PipeGrenade", Enum.PartType.Cylinder, Vector3.new(1.2, 0.5, 0.5)
	nade.Color, nade.Material = Color3.fromRGB(70, 72, 80), Enum.Material.Metal
	nade.CFrame = CFrame.new(launchPoint(char, root, direction, 2))
	nade.Parent = folder
	nade:SetNetworkOwner(nil)
	nade.AssemblyLinearVelocity = direction * spec.Speed + Vector3.new(0, 18, 0)
	world("Fuse", nade)
	task.delay(spec.Fuse, function()
		local at = nade.Position
		nade:Destroy()
		Destruction.Explode(at, spec, char)
	end)
	return true
end

function Destruction.PlantCharge(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not Combat.CanAct(char) or handsFull(char) then
		return false
	end
	Combat.SetBusy(char, 0.3)
	local spec = D.Explosion.Charge
	local best, bestDist = nil, spec.PlantRange
	for model, entry in breaches do
		if not entry.open then
			local dist = (entry.cframe.Position - root.Position).Magnitude
			if dist < bestDist then
				best, bestDist = entry, dist
			end
		end
	end
	if not best then
		Remotes.Announce:FireClient(player, "No breach point within reach to plant on.", "Info")
		return false
	end
	local charge = Instance.new("Part")
	charge.Name, charge.Size, charge.Anchored = "BreachingCharge", Vector3.new(1.5, 1.5, 0.6), true
	charge.Color, charge.Material = Color3.fromRGB(200, 60, 40), Enum.Material.Neon
	charge.CFrame = best.cframe * CFrame.new(0, 0, -best.size.Z / 2 - 0.4)
	charge.Parent = folder
	world("Fuse", charge)
	Remotes.Announce:FireClient(player, ("Charge planted: %ds."):format(spec.Fuse), "Event")
	task.delay(spec.Fuse, function()
		local at = charge.Position
		charge:Destroy()
		Destruction.Explode(at, spec, char)
		if best.tdef.Health == math.huge then
			world("BreachResist", best.cframe.Position)
			if player.Parent then
				Remotes.Announce:FireClient(player, "The seal doesn't even scratch. This one needs a key.", "Info")
			end
		end
	end)
	return true
end

-- ===== Grab / throw =====
local function weightOf(part)
	return Props.Weights[part:GetAttribute("Weight") or "Light"], part:GetAttribute("Weight") or "Light"
end

-- Walk speed is owned by Stats.Apply, which reads the HoldClass attribute (and stun).
local function applyHoldSpeed(player)
	Stats.Apply(player, false)
end

function Destruction.Grab(player, part)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) or held[player] then
		return
	end
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:GetAttribute("Chunk") or not part.Parent then
		return
	end
	local entry = entryOf(part)
	if not entry or entry.heldBy then
		return
	end
	local dist = (part.Position - root.Position).Magnitude
	if entry.inFlight then
		-- Catch attempt: timing-based. The flight resolves it (see fly) if the chunk would hit
		-- within CatchWindow of this press. Missing costs stamina and a lockout.
		if dist > D.CatchRange or not Combat.CanAct(char) or not Combat.SpendStamina(char, D.CatchStamina) then
			return
		end
		catchAttempt[char] = os.clock()
		Combat.SetBusy(char, D.CatchLockout)
		world("CatchAttempt", char)
		return
	end
	if dist > D.GrabRange then
		return
	end
	local w, class = weightOf(part)
	if w.StrengthReq and Gear.Get(player).Stats.Strength < w.StrengthReq then
		Remotes.Announce:FireClient(player, ("Too heavy. Needs Strength %d."):format(w.StrengthReq), "Info")
		return
	end
	if not Combat.CanAct(char) then
		return
	end
	Combat.SetBusy(char, D.GrabTime)
	Destruction.Attach(player, part, entry, class, w)
end

-- Welds a chunk into a player's hands. Validation happens in Grab / the catch path.
function Destruction.Attach(player, part, entry, class, w)
	local char = player.Character
	local root = char.HumanoidRootPart
	entry.heldBy = player
	entry.settledAt, entry.restAt = nil, nil
	part.Anchored, part.CanCollide, part.Massless = false, false, true
	local offset = if class == "Light" then CFrame.new(1.2, 0.5, -1.5) else CFrame.new(0, 1, -2.5 - part.Size.Z / 4)
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, part
	weld.Parent = part
	held[player] = { part = part, entry = entry, weld = weld, class = class, at = os.clock() }
	char:SetAttribute("Holding", part.Name)
	char:SetAttribute("HoldClass", class)
	char:SetAttribute("Improvised", part:GetAttribute("Improvised") == true)
	if not w.CanBlock then
		Combat.SetBlock(player, false)
	end
	applyHoldSpeed(player)
	world("Grab", char, part)
end

local function release(player, keepVelocity)
	local h = held[player]
	if not h then
		return nil
	end
	held[player] = nil
	h.weld:Destroy()
	h.entry.heldBy = nil
	h.part.CanCollide, h.part.Massless = true, false
	h.part:SetNetworkOwner(nil)
	local char = player.Character
	if char then
		char:SetAttribute("Holding", nil)
		char:SetAttribute("HoldClass", nil)
		char:SetAttribute("Improvised", false)
	end
	applyHoldSpeed(player)
	if not keepVelocity then
		h.part.AssemblyLinearVelocity = Vector3.new(0, 2, 0)
	end
	return h
end

function Destruction.Drop(player, destroy)
	local h = release(player, false)
	if h and destroy then
		removeChunk(h.entry)
	end
end

-- Server-side flight: the chunk damages the first thing it reaches after MinFlight studs.
local function fly(part, entry, thrower, w, speed)
	entry.inFlight = true
	local start = part.Position
	local seen = {} -- targets already resolved this flight (a dodge is not re-rolled every frame)
	local last = start
	local deadline = os.clock() + D.FlightTime
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function hitCharacter(model)
		local dmg = w.Damage * (speed / w.Speed) ^ 1.2
		local result = Combat.Damage(thrower, model, dmg, { Posture = w.Posture, Knockback = w.Knockback, Type = "Thrown", Stun = 0.5 })
		if result == "parried" then
			-- deflected: it flies back at whoever threw it, and the parrier owns the hit
			local troot = thrower:FindFirstChild("HumanoidRootPart")
			local back = if troot then (troot.Position - part.Position) else -part.AssemblyLinearVelocity
			part.AssemblyLinearVelocity = (if back.Magnitude > 0.5 then back.Unit else Vector3.yAxis) * speed + Vector3.new(0, 5, 0)
			world("Deflect", part)
			return "deflected", model
		end
		return result
	end
	local live = true
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not live or not part.Parent or entry.heldBy or os.clock() > deadline then
			entry.inFlight = false
			conn:Disconnect()
			return
		end
		local pos = part.Position
		local travelled = (pos - start).Magnitude
		if travelled >= D.MinFlight then
			-- Characters along the segment the chunk covered this frame. A fast throw moves
			-- several studs per frame, so a single point test would tunnel past targets.
			local seg = pos - last
			local segLen = seg.Magnitude
			local mid = (pos + last) / 2
			local reach = math.max(2.5, part.Size.Magnitude / 2) + 1.5
			params.FilterDescendantsInstances = { thrower, part, folder }
			for _, p in workspace:GetPartBoundsInRadius(mid, segLen / 2 + reach, params) do
				local model = p:FindFirstAncestorOfClass("Model")
				local root = model and model:FindFirstChild("HumanoidRootPart")
				local near = false
				if root then
					local toRoot = root.Position - last
					local along = if segLen > 0.01 then math.clamp(toRoot:Dot(seg) / (segLen * segLen), 0, 1) else 0
					near = (toRoot - seg * along).Magnitude <= reach
				end
				if near and not seen[model] and getHum(model) and model ~= thrower then
					seen[model] = true
					-- a well-timed grab press catches it: no damage, and it is theirs now
					local catcher = Players:GetPlayerFromCharacter(model)
					local pressed = catchAttempt[model]
					if catcher and pressed and os.clock() - pressed <= D.CatchWindow and not held[catcher] then
						catchAttempt[model] = nil
						live = false
						entry.inFlight = false
						part.AssemblyLinearVelocity = Vector3.zero
						local wDef, class = weightOf(part)
						if not (wDef.StrengthReq and Gear.Get(catcher).Stats.Strength < wDef.StrengthReq) then
							Destruction.Attach(catcher, part, entry, class, wDef)
							Combat.AddCharge(model, 10)
							world("Catch", model, part)
							Combat.Used:Fire("Catch", catcher)
						end
						break
					end
					local result, newThrower = hitCharacter(model)
					if result == "deflected" then
						thrower = newThrower
						start = pos
					elseif result ~= "dodged" and result ~= "none" then
						live = false
					end
					break
				end
			end
			-- world along the path
			if live then
				ray.FilterDescendantsInstances = { thrower, part }
				local result = workspace:Raycast(last, pos - last, ray)
				if result and result.Instance and worldTarget(result.Instance) then
					Destruction.HitInstance(result.Instance, w.Damage * (speed / w.Speed) ^ 1.2, "Thrown", thrower)
					live = false
				end
			end
		end
		last = pos
		if not live then
			entry.inFlight = false
			conn:Disconnect()
		end
	end)
end

function Destruction.Throw(player, direction, charge)
	local h = held[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (h and root) then
		return
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	-- The client reports how long it held the key; the server caps that by how long it has
	-- actually held the chunk, so a charged throw always has a readable windup.
	charge = math.clamp(if type(charge) == "number" and charge == charge then charge else 0, 0, 1)
	charge = math.min(charge, math.max(0, (os.clock() - h.at - D.GrabTime) / D.MaxChargeTime))
	local w = weightOf(h.part)
	local stats = Gear.Get(player).Stats
	local stamina = w.Stamina * (1 + charge) * (1 - 0.005 * stats.Willpower)
	if not Combat.CanAct(char) or not Combat.SpendStamina(char, stamina) then
		return
	end
	-- the formula sets the speed; the client never gets to choose it
	local speed = w.Speed * (1 + 0.6 * charge) * (1 + 0.01 * stats.Strength)
	local dir = direction.Unit
	local entry, part = h.entry, h.part
	release(player, true)
	Combat.SetBusy(char, 0.3)
	part.CFrame = CFrame.new(launchPoint(char, root, dir, 3))
	part.AssemblyLinearVelocity = dir * speed + Vector3.new(0, 4, 0)
	world("Throw", char, part)
	fly(part, entry, char, w, speed)
end

-- ===== Dematerialization =====
function Destruction.Reset()
	-- hands first, so nobody keeps a chunk through the reset
	for player in held do
		Destruction.Drop(player, false)
	end
	for _, e in table.clone(chunks) do
		removeChunk(e)
	end
	for _, remains in CollectionService:GetTagged("Salvage") do
		remains:Destroy()
	end
	for model, entry in props do
		if not entry.intact then
			entry.intact, entry.health = true, entry.def.Health
			model:SetAttribute("Health", entry.def.Health)
			model.Parent = folder
		end
	end
	local pending = {}
	for model, entry in breaches do
		if entry.open then
			table.insert(pending, entry)
		end
	end
	-- a door won't close on someone standing in it; it retries until the space is clear
	task.spawn(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder }
		local tries = 0
		while #pending > 0 and tries < 60 do
			tries += 1
			for i = #pending, 1, -1 do
				local entry = pending[i]
				local blocked = false
				for _, p in workspace:GetPartBoundsInBox(entry.cframe, entry.size + Vector3.new(1, 1, 1), params) do
					if p:FindFirstAncestorOfClass("Model") and getHum(p:FindFirstAncestorOfClass("Model")) then
						blocked = true
						break
					end
				end
				if not blocked then
					entry.open, entry.health = false, entry.tdef.Health
					entry.door.Parent = entry.model
					entry.model:SetAttribute("Health", entry.tdef.Health)
					table.remove(pending, i)
				end
			end
			if #pending > 0 then
				task.wait(3)
			end
		end
	end)
	Gore.Clear()
	world("Rematerialize")
end

-- ===== Budgets: settle resting chunks, fade old ones =====
local function tick()
	local now = os.clock()
	for i = #chunks, 1, -1 do
		local e = chunks[i]
		local part = e.part
		if not part.Parent then
			table.remove(chunks, i)
		elseif e.heldBy then
			-- held: nothing to do
		elseif now - e.spawnedAt > D.ChunkLifetime then
			removeChunk(e)
		elseif not e.settledAt then
			if part.AssemblyLinearVelocity.Magnitude < 1 then
				e.restAt = e.restAt or now
				if now - e.restAt > D.SettleTime then
					settle(e)
				end
			else
				e.restAt = nil
			end
		end
	end
end

function Destruction.Init()
	folder = Instance.new("Folder")
	folder.Name = "Destruction"
	folder.Parent = workspace

	Combat.World = { Swing = onSwing, Bolt = onBolt, ImprovisedHit = onImprovisedHit }
	require(script.Parent.Inventory).Thrower = { Grenade = Destruction.ThrowGrenade, Charge = Destruction.PlantCharge }

	Net.On("Grab", { rate = 3, burst = 4, args = { "instance" } }, Destruction.Grab)
	Net.On("Throw", { rate = 3, burst = 4, args = { "vector", "number" } }, Destruction.Throw)
	Net.On("Drop", { rate = 3, burst = 4 }, function(player)
		local char = player.Character
		if char and os.clock() >= Combat.State(char).stunned then
			Destruction.Drop(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		Destruction.Drop(player, false)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			Destruction.Drop(player, false)
		end)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					local root = char:FindFirstChild("HumanoidRootPart")
					local v = root and root.AssemblyLinearVelocity or Vector3.zero
					local h = release(player, true)
					if h then
						h.part.AssemblyLinearVelocity = v + Vector3.new(0, 6, 0) -- drops with their last movement
					end
				end)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)

	-- dematerialization cycle
	task.spawn(function()
		local cycle = if Config.Dev.Enabled then Config.Dev.CycleSeconds else D.CycleSeconds
		while true do
			task.wait(cycle - D.CycleWarning)
			Remotes.Announce:FireAllClients(("The city is dematerializing in %ds."):format(D.CycleWarning), "Emergence")
			world("DematerializeWarning", D.CycleWarning)
			task.wait(D.CycleWarning)
			Destruction.Reset()
			Remotes.Announce:FireAllClients("The ruins rematerialize.", "Info")
		end
	end)
end

return Destruction
