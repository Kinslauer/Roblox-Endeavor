-- WoundService: each character's wounds (shared/Wounds rules), in both places.
-- Damage still comes off the Humanoid's health as before; this keeps where it landed and what that did:
-- a part at zero, bleeding, broken bones, pain, concussion. Head or chest at zero kills. Healing that reaches the
-- body (medkits, a medbay, a green pocket) spreads over the hurt parts that are not out.
--
-- Endeavor: Combat.applyDamage calls Hit for player victims, Inventory.Use calls Treat, Hideouts' medbay calls
-- HomeHeal, the Reach's doctor calls Mend. Front: Soldiers.Damage calls Hit, the dressing (H) calls Treat.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Wounds = require(Shared.Wounds)

local W = Config.Wounds
local WoundService = {}

local states = {} -- char -> { s, hum, lastHealth, push, hunger }
local rng = Random.new()

WoundService.Changed = nil -- function(char, effects): movement owners re-read WoundSpeed / WoundNoJump
WoundService.OnEvent = nil -- function(char, part, ev, info): scars, sounds, the hit's story
WoundService.Hunger = false -- Endeavor turns this on

local function push(c, char)
	local now = os.clock()
	local before = char:GetAttribute("WoundSpeed")
	local beforeJump = char:GetAttribute("WoundNoJump")
	for k, v in Wounds.Attributes(c.s, now) do
		if char:GetAttribute(k) ~= v then
			char:SetAttribute(k, v)
		end
	end
	if c.hunger then
		char:SetAttribute("Hunger", math.floor(c.hunger + 0.5))
	end
	if WoundService.Changed and (before ~= char:GetAttribute("WoundSpeed") or beforeJump ~= char:GetAttribute("WoundNoJump")) then
		WoundService.Changed(char)
	end
end

function WoundService.Attach(char, opts)
	opts = opts or {}
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local c = { s = Wounds.New(hum.MaxHealth), hum = hum, lastHealth = hum.Health, maxHealth = hum.MaxHealth,
		hunger = if WoundService.Hunger then (opts.Hunger or W.Hunger.Start) else nil, lastFallY = nil }
	states[char] = c
	hum.HealthChanged:Connect(function(h)
		if h > c.lastHealth + 0.01 then
			Wounds.Heal(c.s, h - c.lastHealth)
			if h >= hum.MaxHealth - 0.01 then
				-- a full pool is a whole body: every part but a dead limb is back (a head or chest is never left at
				-- zero under a full pool, which would kill on the next bleed tick)
				for _, part in Wounds.Parts do
					if (c.s.Hp[part] > 0 or Wounds.Vital[part]) and not c.s.Lost[part] then
						c.s.Hp[part] = c.s.Max[part]
					end
				end
			end
			c.dirty = true
		end
		c.lastHealth = h
	end)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		if math.abs(hum.MaxHealth - c.maxHealth) > 0.01 then
			c.maxHealth = hum.MaxHealth
			Wounds.Rescale(c.s, hum.MaxHealth)
			c.dirty = true
		end
	end)
	-- a hard landing can break a leg
	local landed = hum.StateChanged -- (the test mock has no state signal)
	if landed then landed:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Landed then
			local root = char:FindFirstChild("HumanoidRootPart")
			local speed = c.fallSpeed or 0
			c.fallSpeed = 0
			if root and speed > W.FallSpeed then
				local leg = Wounds.Fall(c.s, speed, rng)
				if leg then
					if WoundService.OnEvent then
						WoundService.OnEvent(char, leg, { Broke = true, Fall = true }, {})
					end
				end
				c.dirty = true
			end
		end
	end) end
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			states[char] = nil
		end
	end)
	push(c, char)
	return c.s
end

-- re-send the attributes after the state was changed from outside (tests, dev tools)
function WoundService.Push(char)
	local c = states[char]
	if c then
		push(c, char)
	end
end

function WoundService.Get(char)
	local c = states[char]
	return c and c.s
end

function WoundService.HungerOf(char)
	local c = states[char]
	return c and c.hunger
end

-- A hit already taken off the Humanoid. info: { Part, At (world point), Amount, Kind, Model (for At), CanLose }
function WoundService.Hit(char, info)
	local c = states[char]
	if not c or not info.Amount or info.Amount <= 0 then
		return nil
	end
	local part = info.Part
	if not part and info.At then
		part = Wounds.PartAt(info.Model or char, info.At)
	end
	if info.Kind == "Blast" and not part then
		-- a blast reaches the whole body: spread it over every part by its share
		local events = {}
		for _, p in Wounds.Parts do
			local ev = Wounds.Hit(c.s, p, info.Amount * W.Parts[p], "Blast", rng, { CanLose = info.CanLose })
			if next(ev) then
				events[p] = ev
			end
		end
		for p, ev in events do
			if ev.Killed then
				c.hum.Health = 0
			end
			if WoundService.OnEvent then
				WoundService.OnEvent(char, p, ev, info)
			end
		end
		push(c, char)
		return events
	end
	part = part or Wounds.RandomPart(rng)
	local ev = Wounds.Hit(c.s, part, info.Amount, info.Kind or "Blunt", rng, { CanLose = info.CanLose })
	if ev.Killed and c.hum.Health > 0 then
		c.hum.Health = 0
	end
	if WoundService.OnEvent then
		WoundService.OnEvent(char, part, ev, info)
	end
	push(c, char)
	return ev, part
end

-- A round stopped by plate still lands as a bruise: a little blunt damage on that part and pain.
function WoundService.Bruise(char, info)
	local c = states[char]
	if not c then
		return
	end
	local amount = (info.Amount or 0) * W.Bruise
	local part = info.Part or (info.At and Wounds.PartAt(info.Model or char, info.At)) or "Chest"
	c.s.Pain = math.min(1, c.s.Pain + W.BruisePain)
	if amount > 0 and c.hum.Health > 0 then
		c.hum.Health = math.max(0, c.hum.Health - amount)
		c.lastHealth = c.hum.Health
		local ev = Wounds.Hit(c.s, part, amount, "Blunt", rng)
		if ev.Killed then
			c.hum.Health = 0
		end
	end
	push(c, char)
end

function WoundService.Concuss(char, seconds)
	local c = states[char]
	if c then
		c.s.ConcussedUntil = math.max(c.s.ConcussedUntil, os.clock() + (seconds or W.Concussion.Seconds))
		c.s.Pain = math.min(1, c.s.Pain + 0.3)
		push(c, char)
	end
end

-- Use a treatment (Wounds.Treatments). Returns the part treated, true for a whole-body item, nil if nothing to do.
function WoundService.Treat(char, item)
	local c = states[char]
	local fn = Wounds.Treatments[item]
	if not (c and fn) then
		return nil
	end
	local did = fn(c.s, os.clock())
	if did then
		push(c, char)
	end
	return did
end

-- What a single dressing does on the Front: the worst thing first (a bleed, then a break), else nothing.
function WoundService.Dress(char)
	return WoundService.Treat(char, "Hemostat") or WoundService.Treat(char, "Splint")
end

function WoundService.Feed(char, amount)
	local c = states[char]
	if c and c.hunger then
		c.hunger = math.clamp(c.hunger + amount, 0, W.Hunger.Start)
		push(c, char)
	end
end

function WoundService.Mend(char)
	local c = states[char]
	if c then
		Wounds.Mend(c.s, c.hum.MaxHealth)
		c.hum.Health = c.hum.MaxHealth
		c.lastHealth = c.hum.Health
		push(c, char)
	end
end

-- An implant fitted where a limb was lost ends the loss (Autonet).
function WoundService.Replace(char, part)
	local c = states[char]
	if c and c.s.Lost[part] then
		c.s.Lost[part] = nil
		c.s.Bleed[part] = nil
		c.s.Broken[part] = nil
		c.s.Hp[part] = c.s.Max[part]
		push(c, char)
	end
end

-- Home with a medbay: the parts heal and broken bones mend after a while (dead limbs still need surgery).
function WoundService.HomeHeal(char, dt)
	local c = states[char]
	if not c then
		return
	end
	local s = c.s
	for _, part in Wounds.Parts do
		if s.Hp[part] > 0 and not s.Lost[part] then
			s.Hp[part] = math.min(s.Max[part], s.Hp[part] + s.Max[part] * W.HomeHeal.PartPerSecond * dt)
		end
	end
	for part in s.Bleed do
		if s.Bleed[part] == "Light" then
			s.Bleed[part] = nil
		end
	end
	c.mend = (c.mend or 0) + dt
	if c.mend >= W.HomeHeal.MendSeconds then
		c.mend = 0
		for part in s.Broken do
			s.Broken[part] = nil
			break
		end
	end
	c.dirty = true
end

function WoundService.Effects(char)
	local c = states[char]
	if not c then
		return { Speed = 1, NoSprint = false, NoJump = false, Shake = 0, Melee = 1 }
	end
	return Wounds.Effects(c.s, os.clock())
end

-- Bleeding, pain fading, hunger, landing speed; attributes pushed a few times a second.
function WoundService.Step(dt)
	for char, c in states do
		local hum = c.hum
		if not char.Parent or hum.Parent ~= char then
			states[char] = nil -- a body that was removed (respawned) never bleeds on: its death would respawn the new one
		elseif hum.Health > 0 then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				local vy = -root.AssemblyLinearVelocity.Y
				if vy > (c.fallSpeed or 0) then
					c.fallSpeed = vy
				end
			end
			local lost = Wounds.BleedTick(c.s, dt)
			if c.hunger then
				c.hunger = math.max(0, c.hunger - W.Hunger.PerMinute / 60 * dt)
				if c.hunger <= 0 then
					lost += W.Hunger.StarveDamage * dt
				end
			end
			if lost > 0 then
				hum.Health = math.max(0, hum.Health - lost)
				c.lastHealth = hum.Health
				for _, part in Wounds.Parts do
					if Wounds.Vital[part] and c.s.Hp[part] <= 0 then
						hum.Health = 0
					end
				end
			end
			c.acc = (c.acc or 0) + dt
			if c.acc >= 0.25 or c.dirty then
				c.acc, c.dirty = 0, false
				push(c, char)
			end
		end
	end
end

local started = false
function WoundService.Start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(WoundService.Step)
end

-- Wound kind from a melee weapon family (Endeavor's Weapons) and a damage type.
function WoundService.KindOf(family, damageType, ranged)
	if damageType == "Explosive" then
		return "Blast"
	elseif damageType == "Arc" then
		return "Arc"
	elseif ranged then
		return "Bullet"
	elseif family == "Blade" or family == "Spear" then
		return "Cut"
	end
	return "Blunt"
end

return WoundService
