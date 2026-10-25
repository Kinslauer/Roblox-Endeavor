-- Server-authoritative combat. Weapons supply the moveset (combos + heavy); armor and stats
-- supply defence and scaling (see Gear). Ideas ported from the combat-system reference:
-- frame-data attacks (windup/active/end), cone hit detection, hit stun that cancels swings,
-- posture meter with guard break, parry, i-frame dodge and wall-aware knockback.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Gear = require(script.Parent.Gear)
local PlayerData = require(script.Parent.PlayerData)
local WorldPhase = require(script.Parent.WorldPhase)

local C, F = Config.Combat, Config.Flicker
local BUFFER = 0.08 -- input buffer: an attack may start this early before the last one ends

local Combat = {}
Combat.Resolved = Instance.new("BindableEvent") -- (attackerChar, victimChar, result)
Combat.Used = Instance.new("BindableEvent") -- (abilityName, player)

local state = setmetatable({}, { __mode = "k" })

local function st(char)
	local s = state[char]
	if not s then
		s = {
			block = false, blockStart = 0, iframes = 0, stunned = 0, busyUntil = 0, token = 0,
			lastSpend = 0, lastPostureHit = 0, lastDodge = 0, lastHeavy = 0,
			combo = 0, comboWeapon = nil, comboExpires = 0,
			hyperarmorUntil = 0, swingArmorUntil = 0, takenMult = 1, takenUntil = 0, arcBonus = 0, arcUntil = 0,
			windupUntil = 0, lastCost = 0,
			flickPress = 0, lastFlickPress = 0, flickerLevel = 0, flickerUntil = 0, zoneUntil = 0,
			skillCD = {},
		}
		state[char] = s
		if not char:GetAttribute("MaxPosture") then -- NPCs
			char:SetAttribute("MaxPosture", Gear.Default().MaxPosture)
			char:SetAttribute("Posture", 0)
		end
	end
	return s
end
Combat.State = st

local function getHum(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(char)
	local hum = getHum(char)
	return hum ~= nil and hum.Health > 0
end

local function fx(kind, char, extra)
	Remotes.CombatEvent:FireAllClients(kind, char, extra)
end
Combat.FX = fx

function Combat.CanAct(char)
	local s = st(char)
	local t = os.clock()
	return isAlive(char) and t >= s.stunned and t >= s.busyUntil - BUFFER
end

function Combat.SetBusy(char, duration)
	st(char).busyUntil = os.clock() + duration
end

function Combat.GrantIFrames(char, duration)
	local s = st(char)
	s.iframes = math.max(s.iframes, os.clock() + duration)
end

-- kind: "Hyperarmor" | "Taken" (value = damage multiplier) | "Arc" (value = bonus damage)
function Combat.AddBuff(char, kind, value, duration)
	local s, untilT = st(char), os.clock() + duration
	if kind == "Hyperarmor" then
		s.hyperarmorUntil = math.max(s.hyperarmorUntil, untilT)
	elseif kind == "Taken" then
		s.takenMult, s.takenUntil = value, untilT
	elseif kind == "Arc" then
		s.arcBonus, s.arcUntil = value, untilT
	end
	fx("Buff", char, kind)
end

function Combat.SpendStamina(char, base)
	local cost = base * Gear.OfChar(char).StaminaCostMult
	local cur = char:GetAttribute("Stamina") or 0
	if cur < cost then
		return false
	end
	char:SetAttribute("Stamina", cur - cost)
	local s = st(char)
	s.lastSpend, s.lastCost = os.clock(), cost
	return true
end

function Combat.AddStamina(char, amount)
	char:SetAttribute("Stamina", math.clamp((char:GetAttribute("Stamina") or 0) + amount, 0, char:GetAttribute("MaxStamina") or 0))
end

-- Returns the new posture value.
function Combat.AddPosture(char, amount)
	local s = st(char)
	local value = math.clamp((char:GetAttribute("Posture") or 0) + amount, 0, char:GetAttribute("MaxPosture") or 1)
	char:SetAttribute("Posture", value)
	if amount > 0 then
		s.lastPostureHit = os.clock()
	end
	return value
end

function Combat.AddCharge(char, amount)
	local max = char:GetAttribute("MaxCharge")
	if max then
		char:SetAttribute("Charge", math.clamp((char:GetAttribute("Charge") or 0) + amount, 0, max))
	end
end

-- ===== Flickering cursed energy (Black Flash) =====
local function setFlickerLevel(char, s, level)
	s.flickerLevel = level
	char:SetAttribute("Flicker", level) -- replicated: clients render the flicker from this
end

-- Breaks the chain (the Zone, once earned, stays until it times out).
function Combat.CancelFlicker(char)
	local s = st(char)
	s.flickPress = 0
	if s.flickerLevel > 0 then
		setFlickerLevel(char, s, 0)
	end
end

-- Primes the chain directly (used by the Overclock skill).
function Combat.SetFlicker(char, level, holdSeconds)
	local s = st(char)
	s.flickerUntil = os.clock() + holdSeconds
	setFlickerLevel(char, s, level)
end

-- The flicker key. Just records a timestamp (and spends charge); the swing that connects
-- within the window judges it. Spamming is expensive and a mis-timed press does nothing.
function Combat.Flicker(player)
	local char = player.Character
	if not (char and isAlive(char)) then
		return
	end
	local s, t = st(char), os.clock()
	if t < s.stunned or t - s.lastFlickPress < F.Cooldown then
		return
	end
	local cost = F.Cost / Gear.Get(player).FlickerRate
	if (char:GetAttribute("Charge") or 0) < cost then
		return
	end
	Combat.AddCharge(char, -cost)
	s.lastFlickPress, s.flickPress = t, t
	fx("Flick", char)
end

-- Judged once per swing, at the first connection. Returns nil, or { level, flash }.
local function judgeFlick(s, d)
	local t = os.clock()
	local zone = t < s.zoneUntil
	if t - s.flickPress > F.Window * d.FlickerRate * (if zone then F.ZoneWindowMult else 1) then
		return nil
	end
	s.flickPress = 0
	local level = s.flickerLevel + 1
	return { level = level, flash = level >= F.MaxLevel - (if zone then 1 else 0) }
end

local function blackFlash(char, s, victim)
	setFlickerLevel(char, s, 0)
	s.zoneUntil = os.clock() + F.ZoneTime
	char:SetAttribute("Zone", true)
	Combat.AddCharge(char, F.FlashRefund)
	fx("BlackFlash", char, victim)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		Combat.Used:Fire("BlackFlash", player)
	end
end

-- Deepwoken-style feint: cancel a swing during its windup and get most of the stamina back.
-- Pure mind-game tool (your flick timing stays live), costs a short recovery.
function Combat.Feint(player)
	local char = player.Character
	if not (char and isAlive(char)) then
		return
	end
	local s, t = st(char), os.clock()
	if t >= s.windupUntil or t < s.stunned then
		return
	end
	s.token += 1
	s.windupUntil, s.swingArmorUntil = 0, 0
	s.busyUntil = t + C.FeintRecovery
	Combat.AddStamina(char, s.lastCost * C.FeintRefund)
	s.combo = math.max(0, s.combo - 1)
	fx("Feint", char)
	Combat.Used:Fire("Feint", player)
end

function Combat.InCombat(player)
	local t = player:GetAttribute("LastCombat")
	return t ~= nil and os.clock() - t < Config.CombatLogSeconds
end

local function tag(attacker, victim)
	local ap, vp = Players:GetPlayerFromCharacter(attacker), Players:GetPlayerFromCharacter(victim)
	if ap and vp then -- only PvP resets the combat-log timer
		ap:SetAttribute("LastCombat", os.clock())
		vp:SetAttribute("LastCombat", os.clock())
	end
	victim:SetAttribute("LastAttackerName", attacker.Name)
	victim:SetAttribute("LastAttackerUserId", ap and ap.UserId or 0)
	victim:SetAttribute("LastHitTime", os.clock())
end

-- Returns killer's display name and Player (if any) while the credit window is open.
function Combat.GetKiller(char)
	local t = char:GetAttribute("LastHitTime")
	if t and os.clock() - t <= C.KillCreditSeconds then
		local userId = char:GetAttribute("LastAttackerUserId") or 0
		return char:GetAttribute("LastAttackerName"), if userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
	end
	return nil, nil
end

-- Hit stun / stagger. Also cancels any swing the target had queued (token bump) and drops block.
function Combat.Stun(char, duration)
	local hum = getHum(char)
	if not hum then
		return
	end
	local s = st(char)
	local endsAt = os.clock() + duration
	s.token += 1
	Combat.CancelFlicker(char)
	s.busyUntil = 0
	s.block = false
	char:SetAttribute("Blocking", false)
	fx("Stun", char, duration) -- presentation: cancels the swing telegraph, plays a stagger
	if endsAt <= s.stunned then
		return
	end
	if os.clock() >= s.stunned then
		s.baseSpeed = hum.WalkSpeed
	end
	s.stunned = endsAt
	hum.WalkSpeed = 0
	task.delay(duration, function()
		if os.clock() >= s.stunned and hum.Parent and hum.Health > 0 then
			hum.WalkSpeed = s.baseSpeed or Config.Stats.BaseWalkSpeed
		end
	end)
end

local function knockback(char, direction, magnitude)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or magnitude <= 0 then
		return
	end
	-- Don't launch people through walls: shrink the push to the free distance ahead.
	local travel = magnitude * 0.3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local wall = workspace:Raycast(root.Position, direction * travel, params)
	if wall then
		magnitude *= math.clamp((wall.Distance - 2) / travel, 0, 1)
	end
	local push = direction * magnitude
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		Remotes.CombatEvent:FireClient(player, "Knockback", push) -- client owns its physics
	else
		root.AssemblyLinearVelocity = push
	end
end

-- opts: Posture, Type ("Physical"|"Arc"), Unblockable, GuardBreak (blocks fail; parry still works),
--       Knockback (studs/s), Stun (seconds)
-- Returns "hit" | "blocked" | "parried" | "dodged" | "guardbreak" | "none"
local function applyDamage(attacker, victim, amount, opts)
	local vhum = getHum(victim)
	if not vhum or vhum.Health <= 0 or attacker == victim then
		return "none"
	end
	local ap, vp = Players:GetPlayerFromCharacter(attacker), Players:GetPlayerFromCharacter(victim)
	if ap and vp and not WorldPhase.IsOpen() then
		return "none" -- no PvP during the prologue (they should never meet anyway)
	end

	local vs, t, vd = st(victim), os.clock(), Gear.OfChar(victim)
	if t < vs.iframes then
		fx("Dodged", victim, attacker)
		return "dodged"
	end

	local aroot, vroot = attacker:FindFirstChild("HumanoidRootPart"), victim:FindFirstChild("HumanoidRootPart")
	local away = if aroot and vroot then Vector3.new(vroot.Position.X - aroot.Position.X, 0, vroot.Position.Z - aroot.Position.Z) else Vector3.zero
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zero

	local result = "hit"
	local facing = aroot and vroot and vroot.CFrame.LookVector:Dot(-direction) > C.BlockMinFacing
	if vs.block and facing and not opts.Unblockable then
		if t - vs.blockStart <= vd.ParryWindow then
			Combat.Stun(attacker, C.ParryStun)
			Combat.AddPosture(victim, -C.ParryPostureRelief)
			fx("Parry", victim, attacker)
			return "parried"
		end
		local posture = Combat.AddPosture(victim, opts.Posture or 0)
		if opts.GuardBreak or posture >= (victim:GetAttribute("MaxPosture") or 1) then
			victim:SetAttribute("Posture", 0)
			Combat.Stun(victim, C.GuardBreakStun)
			fx("GuardBreak", victim, attacker)
			result = "guardbreak"
		else
			amount *= 1 - vd.BlockReduction
			fx("Block", victim, attacker)
			result = "blocked"
		end
	end

	if t < vs.takenUntil then
		amount *= vs.takenMult
	end
	amount *= 1 - math.min(C.MaxResist, vd.Resist[opts.Type or "Physical"] or 0)

	vhum:TakeDamage(amount)
	tag(attacker, victim)

	if result ~= "blocked" and t >= math.max(vs.hyperarmorUntil, vs.swingArmorUntil) then
		Combat.Stun(victim, opts.Stun or C.HitStunDefault)
		if opts.Knockback and opts.Knockback > 0 then
			knockback(victim, direction, opts.Knockback)
		end
	end
	if result == "hit" then
		fx("Hit", victim, { attacker = attacker, amount = amount })
	end
	return result
end

function Combat.Damage(attacker, victim, amount, opts)
	local result = applyDamage(attacker, victim, amount, opts or {})
	if result ~= "none" then
		Combat.Resolved:Fire(attacker, victim, result)
	end
	return result
end

-- One hitbox pulse for an attack spec. `seen` makes each target take at most one hit per swing.
local function pulse(char, spec, mods, seen)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local s, d = st(char), Gear.OfChar(char)
	local origin, look = root.Position, root.CFrame.LookVector

	local damage = spec.Damage * (mods.damageMult or 1)
	local posture = spec.Posture * (mods.postureMult or 1)
	if not mods.noStatScaling then
		damage *= d.DamageMult
		posture *= d.PostureDamageMult
	end
	local overloaded = os.clock() < s.arcUntil
	if overloaded then
		damage += s.arcBonus
	end
	local opts = { Posture = posture, Type = spec.Type, Knockback = spec.Knockback, Stun = spec.Stun, Unblockable = mods.unblockable, GuardBreak = mods.guardBreak }

	local function strike(model)
		seen[model] = true
		if seen.__flick == nil then
			seen.__flick = judgeFlick(s, d) or false
		end
		local flick = seen.__flick
		local hitDamage, hitOpts = damage, opts
		if flick then
			hitOpts = table.clone(opts)
			if flick.flash then
				hitDamage = damage * (F.BlackFlashMult + d.FlashBonus)
				hitOpts.Posture = (opts.Posture or 0) * F.BlackFlashPosture
				hitOpts.GuardBreak = true
				hitOpts.Stun = math.max(opts.Stun or 0, F.BlackFlashStun)
				hitOpts.Knockback = math.max(opts.Knockback or 0, F.BlackFlashKnockback)
			else
				hitDamage = damage * F.DamageMult[flick.level]
			end
		end
		local result = Combat.Damage(char, model, hitDamage, hitOpts)
		if flick and not flick.resolved then
			if result == "hit" or result == "guardbreak" then
				flick.resolved = true
				if flick.flash then
					blackFlash(char, s, model)
				else
					s.flickerUntil = os.clock() + F.ChainTime
					setFlickerLevel(char, s, flick.level)
					fx("Flick", model, flick.level)
				end
			elseif result == "dodged" or result == "parried" then
				flick.resolved = true
				Combat.CancelFlicker(char) -- whiffed flick: the chain is gone
			end
		end
		if result == "hit" or result == "guardbreak" then
			local gain = (C.ChargePerHit + (mods.chargeBonus or 0)) * d.ChargeGain * (if overloaded then 2 else 1)
			Combat.AddCharge(char, gain)
		end
		if mods.onHit then
			mods.onHit(result, model)
		end
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	if spec.Ranged then
		if seen.__fired then
			return
		end
		seen.__fired = true
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { char }
		local result = workspace:Raycast(origin, look * spec.Range, ray)
		fx("Bolt", char, if result then result.Position else origin + look * spec.Range)
		local model = result and result.Instance:FindFirstAncestorOfClass("Model")
		if model and getHum(model) then
			strike(model)
		end
		return
	end

	for _, part in workspace:GetPartBoundsInRadius(origin, spec.Range, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and getHum(model) then
			local vroot = model:FindFirstChild("HumanoidRootPart")
			if vroot then
				local offset = vroot.Position - origin
				local flat = Vector3.new(offset.X, 0, offset.Z)
				-- point-blank targets are always in the arc (matches the reference hitbox)
				if flat.Magnitude < 3.5 or look:Dot(flat.Unit) >= spec.Arc then
					strike(model)
				end
			end
		end
	end
end

-- Runs a full swing: marks the character busy, waits out the windup, then pulses the hitbox
-- for `Active` seconds. Being hit-stunned during the windup (token bump) cancels the swing.
-- mods: damageMult, postureMult, noStatScaling, unblockable, chargeBonus, onHit(result, model)
function Combat.Swing(char, spec, mods)
	mods = mods or {}
	local s, t0 = st(char), os.clock()
	local token = s.token
	s.busyUntil = t0 + spec.End
	s.windupUntil = t0 + spec.Windup
	s.swingArmorUntil = if spec.Hyperarmor then t0 + spec.Windup + spec.Active else 0
	-- The client telegraphs from these exact numbers (ADR-0004 / TR-004), so what players see
	-- lines up with the parry and flick windows the server judges.
	fx("Swing", char, {
		label = mods.label, windup = spec.Windup, active = spec.Active, finish = spec.End,
		weapon = char:GetAttribute("Weapon"), hyperarmor = spec.Hyperarmor == true,
	})

	task.delay(spec.Windup, function()
		if s.token ~= token or not isAlive(char) then
			return
		end
		local seen = {}
		local endAt = os.clock() + spec.Active
		repeat
			pulse(char, spec, mods, seen)
			RunService.Heartbeat:Wait()
		until os.clock() >= endAt or s.token ~= token or not isAlive(char)
	end)
end

local function weaponOf(player)
	local data = PlayerData.Get(player)
	return data and (Weapons.Defs[data.Equipped] or Weapons.Defs.Fists)
end

function Combat.Attack(player)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and Combat.CanAct(char)) then
		return
	end
	local s, t = st(char), os.clock()
	local combo = if s.comboWeapon == weapon and t <= s.comboExpires then s.combo % #weapon.Attacks + 1 else 1
	local spec = weapon.Attacks[combo]
	if not Combat.SpendStamina(char, spec.Stamina) then
		return
	end
	s.block = false
	char:SetAttribute("Blocking", false)
	s.combo, s.comboWeapon = combo, weapon
	local mods = { chargeBonus = weapon.ChargeBonus, label = combo }
	Combat.Swing(char, spec, mods)
	if combo == #weapon.Attacks then -- end of the chain: recovery
		s.busyUntil += weapon.ComboCooldown
	end
	s.comboExpires = s.busyUntil + weapon.ComboReset
end

function Combat.Heavy(player)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and Combat.CanAct(char)) then
		return
	end
	local s, t = st(char), os.clock()
	if t - s.lastHeavy < C.HeavyCooldown or not Combat.SpendStamina(char, weapon.Heavy.Stamina) then
		return
	end
	s.lastHeavy, s.block, s.combo = t, false, 0
	Combat.Used:Fire("Heavy", player)
	char:SetAttribute("Blocking", false)
	-- Heavies are criticals: they crush blocks (extra posture damage).
	local mods = { chargeBonus = weapon.ChargeBonus, label = "Heavy", postureMult = C.CriticalPostureMult }
	Combat.Swing(char, weapon.Heavy, mods)
end

function Combat.SetBlock(player, down)
	local char = player.Character
	if not char or type(down) ~= "boolean" then
		return
	end
	local s = st(char)
	if down then
		if Combat.CanAct(char) and not s.block and os.clock() >= s.busyUntil then
			s.block, s.blockStart = true, os.clock()
			char:SetAttribute("Blocking", true)
		end
	else
		s.block = false
		char:SetAttribute("Blocking", false)
	end
end

function Combat.Dodge(player, direction)
	local char = player.Character
	if not (char and isAlive(char) and typeof(direction) == "Vector3") then
		return
	end
	local s, t = st(char), os.clock()
	if t < s.stunned or t - s.lastDodge < C.DodgeCooldown then
		return
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 or not Combat.SpendStamina(char, C.DodgeCost) then
		return
	end
	s.token += 1 -- dodging cancels a swing that hasn't landed yet
	s.lastDodge, s.iframes, s.block = t, t + Gear.Get(player).DodgeIFrames, false
	s.busyUntil = t + 0.2
	char:SetAttribute("Blocking", false)
	Remotes.CombatEvent:FireClient(player, "DodgeMove", direction.Unit * C.DodgeSpeed)
	fx("Dodge", char)
end

function Combat.Init()
	Remotes.Attack.OnServerEvent:Connect(Combat.Attack)
	Remotes.Heavy.OnServerEvent:Connect(Combat.Heavy)
	Remotes.Feint.OnServerEvent:Connect(Combat.Feint)
	Remotes.Flicker.OnServerEvent:Connect(Combat.Flicker)
	Remotes.Block.OnServerEvent:Connect(Combat.SetBlock)
	Remotes.Dodge.OnServerEvent:Connect(Combat.Dodge)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		local t = os.clock()
		for char, s in state do
			if char.Parent and isAlive(char) then
				local d = Gear.OfChar(char)
				if s.flickerLevel > 0 and t > s.flickerUntil then
					setFlickerLevel(char, s, 0)
				end
				if char:GetAttribute("Zone") and t > s.zoneUntil then
					char:SetAttribute("Zone", false)
				end
				local maxStamina = char:GetAttribute("MaxStamina")
				if maxStamina and not s.block and t - s.lastSpend > C.StaminaRegenDelay then
					Combat.AddStamina(char, C.StaminaRegenPerSecond * step)
				end
				if (char:GetAttribute("Posture") or 0) > 0 and t - s.lastPostureHit > C.PostureRegenDelay then
					Combat.AddPosture(char, -d.PostureRegen * step)
				end
			end
		end
	end)
end

return Combat
