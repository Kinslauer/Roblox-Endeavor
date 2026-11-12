-- Wounds: the rules for a body that takes hits part by part (both places). Pure: no instances are changed here.
-- common/WoundService keeps each character's state and applies it; the clients read the character attributes it
-- sets (W_<part>, Bleed_<part>, Broken_<part>, Out_<part>, Lost_<part>, Pain, Concussed, Hunger) to draw the body
-- outline and the pain.
--
-- State: { Max = { part = hp }, Hp = { part = hp }, Bleed = { part = "Light"|"Heavy" }, Broken = { part = true },
--   Lost = { part = true }, Pain = 0..1, PainkillerUntil = t, ConcussedUntil = t, Cap = { part = share } }
local Config = require(script.Parent.Config)

local Wounds = {}

local W = Config.Wounds
Wounds.Parts = { "Head", "Chest", "Stomach", "ArmL", "ArmR", "LegL", "LegR" }
Wounds.Vital = { Head = true, Chest = true }
Wounds.Limb = { ArmL = true, ArmR = true, LegL = true, LegR = true }
Wounds.Legs = { "LegL", "LegR" }
Wounds.Arms = { "ArmL", "ArmR" }
-- the cybernetic slot that replaces a limb (Endeavor: an implant fitted there ends a lost limb)
Wounds.CyberSlot = { ArmL = "LeftArm", ArmR = "RightArm", LegL = "LeftLeg", LegR = "RightLeg" }

-- R15 limb name (or a skin piece named after one) -> wound part
function Wounds.PartOfLimb(name)
	if type(name) ~= "string" then
		return nil
	end
	if name:find("Head") then
		return "Head"
	elseif name:find("UpperTorso") or name == "Torso" then
		return "Chest"
	elseif name:find("LowerTorso") then
		return "Stomach"
	end
	local left = name:find("Left") ~= nil
	if name:find("Arm") or name:find("Hand") then
		return if left then "ArmL" else "ArmR"
	elseif name:find("Leg") or name:find("Foot") then
		return if left then "LegL" else "LegR"
	end
	return nil
end

-- The wound part nearest a world point on a body: the limb box the point is closest to (proxy limbs on skinned
-- bodies are still the real limb boxes).
function Wounds.PartAt(model, position)
	local best, bestD
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and Wounds.PartOfLimb(part.Name) then
			local p = part.CFrame:PointToObjectSpace(position)
			local h = part.Size / 2
			local d = (p - Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))).Magnitude
			if not bestD or d < bestD then
				best, bestD = part, d
			end
		end
	end
	return best and Wounds.PartOfLimb(best.Name), best
end

-- A part for a hit that came with no point: weighted like a body facing it (the chest most).
function Wounds.RandomPart(rng)
	local r = rng:NextNumber()
	for _, part in Wounds.Parts do
		r -= W.Parts[part]
		if r <= 0 then
			return part
		end
	end
	return "Chest"
end

function Wounds.New(maxHealth)
	local s = { Base = maxHealth, Max = {}, Hp = {}, Bleed = {}, Broken = {}, Lost = {}, Cap = {}, Pain = 0, PainkillerUntil = 0, ConcussedUntil = 0 }
	for _, part in Wounds.Parts do
		s.Max[part] = maxHealth * W.Parts[part] * W.PartScale
		s.Hp[part] = s.Max[part]
	end
	return s
end

function Wounds.Rescale(s, maxHealth)
	s.Base = maxHealth
	for _, part in Wounds.Parts do
		local share = s.Hp[part] / math.max(s.Max[part], 0.01)
		s.Max[part] = maxHealth * W.Parts[part] * W.PartScale * (s.Cap[part] or 1)
		s.Hp[part] = share * s.Max[part]
	end
end

function Wounds.Out(s, part)
	return s.Hp[part] <= 0 or s.Lost[part] == true
end

-- One hit on one part. kind: "Cut" | "Blunt" | "Bullet" | "Blast" | "Arc". Returns what happened:
-- { Killed, Bled = "Light"|"Heavy", Broke, Out, Lost }
function Wounds.Hit(s, part, amount, kind, rng, opts)
	opts = opts or {}
	local ev = {}
	if amount <= 0 or not s.Hp[part] then
		return ev
	end
	if part == "Head" and kind ~= "Bullet" then
		amount *= W.HeadBlow -- a skull turns a blow that a round goes through: melee rarely ends a life at the head
	end
	local was = s.Hp[part]
	local share = amount / math.max(s.Max[part], 1)
	s.Hp[part] = math.max(0, was - amount)
	s.Pain = math.min(1, s.Pain + share * W.PainPerShare)
	if Wounds.Vital[part] and s.Hp[part] <= 0 then
		ev.Killed = true
		return ev
	end
	if was > 0 and s.Hp[part] <= 0 then
		ev.Out = true
	end
	local bleed = W.Bleed[kind] or 0
	if bleed > 0 and rng:NextNumber() < bleed then
		local heavy = share >= W.HeavyShare or s.Bleed[part] == "Light" and share >= W.HeavyShare * 0.5
		local level = if heavy then "Heavy" else "Light"
		if s.Bleed[part] ~= "Heavy" then
			s.Bleed[part] = level
			ev.Bled = level
		end
	end
	if Wounds.Limb[part] then
		local fr = W.Fracture[kind] or 0
		if not s.Broken[part] and (ev.Out and (kind == "Blunt" or kind == "Blast") or share >= W.FractureMinShare and rng:NextNumber() < fr) then
			s.Broken[part] = true
			ev.Broke = true
		end
		if opts.CanLose and was <= 0 and not s.Lost[part] then
			local lose = W.Lost[kind] or 0
			if lose > 0 and rng:NextNumber() < lose then
				s.Lost[part] = true
				s.Bleed[part] = "Heavy"
				ev.Lost = true
			end
		end
	end
	return ev
end

-- A hard landing: the leg that took it can break.
function Wounds.Fall(s, speed, rng)
	if speed < W.FallSpeed then
		return nil
	end
	local leg = Wounds.Legs[rng:NextInteger(1, 2)]
	local amount = (speed - W.FallSpeed) * 0.6
	s.Hp[leg] = math.max(0, s.Hp[leg] - amount)
	if not s.Broken[leg] then
		s.Broken[leg] = true
		return leg
	end
	return nil
end

-- Health lost to bleeding over dt, taken from the parts that bleed (the total pool loses the same).
function Wounds.BleedTick(s, dt)
	local lost = 0
	for part, level in s.Bleed do
		local a = W.BleedPerSecond[level] * dt
		lost += a
		-- a bleed kills through the body's pool, never by emptying a head or chest on its own
		s.Hp[part] = math.max(if Wounds.Vital[part] then math.min(1, s.Hp[part]) else 0, s.Hp[part] - a)
	end
	s.Pain = math.max(0, s.Pain - W.PainDecay * dt)
	return lost
end

-- Healing that reached the body's pool spreads over the hurt parts that are not out (a dead limb needs surgery).
function Wounds.Heal(s, amount)
	local hurt = {}
	local missing = 0
	for _, part in Wounds.Parts do
		if s.Hp[part] > 0 and not s.Lost[part] and s.Hp[part] < s.Max[part] then
			table.insert(hurt, part)
			missing += s.Max[part] - s.Hp[part]
		end
	end
	if missing <= 0 then
		return
	end
	amount *= W.PartScale -- the parts hold PartScale times the pool, so they heal that much faster
	for _, part in hurt do
		local gap = s.Max[part] - s.Hp[part]
		s.Hp[part] = math.min(s.Max[part], s.Hp[part] + amount * gap / missing)
	end
end

-- What the wounds do to the body. Returns { Speed, NoSprint, NoJump, Shake (degrees), Melee, PainShows }
function Wounds.Effects(s, now)
	local fx = { Speed = 1, NoSprint = false, NoJump = false, Shake = 0, Melee = 1 }
	local masked = now < s.PainkillerUntil
	for _, leg in Wounds.Legs do
		if Wounds.Out(s, leg) or s.Broken[leg] then
			fx.Speed *= if masked and not s.Lost[leg] then math.max(W.LegOutSpeed, 0.9) else W.LegOutSpeed
			fx.NoSprint = fx.NoSprint or not masked or s.Lost[leg] == true
			fx.NoJump = true
		end
	end
	for _, arm in Wounds.Arms do
		if Wounds.Out(s, arm) or s.Broken[arm] then
			fx.Shake += W.ArmShake
			fx.Melee *= W.ArmMelee
		end
	end
	fx.PainShows = not masked and s.Pain > 0.05
	if fx.PainShows then
		fx.Shake += W.PainShake * s.Pain
	end
	if now < s.ConcussedUntil then
		fx.Shake += W.PainShake
	end
	return fx
end

-- Treatment: what an item does, picked against the worst matching wound. Returns the part it was used on (or
-- true for a whole-body item) when it did something, nil when there was nothing for it to treat.
Wounds.Treatments = {
	Bandage = function(s)
		for _, part in Wounds.Parts do
			if s.Bleed[part] == "Light" then
				s.Bleed[part] = nil
				return part
			end
		end
	end,
	Tourniquet = function(s)
		-- only a limb can be tied off; it stops a heavy bleed and costs the limb a little
		for _, part in Wounds.Parts do
			if s.Bleed[part] == "Heavy" and Wounds.Limb[part] then
				s.Bleed[part] = nil
				s.Hp[part] = math.max(0, s.Hp[part] - s.Max[part] * 0.1)
				return part
			end
		end
	end,
	Hemostat = function(s)
		for _, level in { "Heavy", "Light" } do
			for _, part in Wounds.Parts do
				if s.Bleed[part] == level then
					s.Bleed[part] = nil
					return part
				end
			end
		end
	end,
	Splint = function(s)
		for _, part in { "LegL", "LegR", "ArmR", "ArmL" } do
			if s.Broken[part] and not s.Lost[part] then
				s.Broken[part] = nil
				return part
			end
		end
	end,
	Painkillers = function(s, now)
		s.PainkillerUntil = now + W.Painkiller
		return true
	end,
	SurgeryKit = function(s)
		for _, part in { "LegL", "LegR", "ArmR", "ArmL", "Stomach" } do
			if s.Hp[part] <= 0 and not s.Lost[part] then
				s.Cap[part] = W.Surgery.MaxShare
				s.Max[part] = s.Base * W.Parts[part] * W.PartScale * W.Surgery.MaxShare
				s.Hp[part] = W.Surgery.Floor
				return part
			end
		end
	end,
}

-- The doctor (and a full mend at home): everything back, lost limbs and surgery scars included.
function Wounds.Mend(s, maxHealth)
	local fresh = Wounds.New(maxHealth)
	for k, v in fresh do
		s[k] = v
	end
end

-- Attributes a character carries for the clients: W_<part> = share left (0..1), plus flags.
function Wounds.Attributes(s, now)
	local a = {}
	for _, part in Wounds.Parts do
		a["W_" .. part] = if s.Lost[part] then 0 else math.clamp(s.Hp[part] / math.max(s.Max[part], 0.01), 0, 1) * (s.Cap[part] or 1)
		a["Bleed_" .. part] = s.Bleed[part] or ""
		a["Broken_" .. part] = s.Broken[part] == true
		a["Lost_" .. part] = s.Lost[part] == true
	end
	local fx = Wounds.Effects(s, now)
	a.Pain = if fx.PainShows then math.floor(s.Pain * 100 + 0.5) / 100 else 0
	a.WoundSpeed = fx.Speed
	a.WoundNoSprint = fx.NoSprint
	a.WoundNoJump = fx.NoJump
	a.WoundShake = fx.Shake
	a.Concussed = now < s.ConcussedUntil
	return a
end

return Wounds
