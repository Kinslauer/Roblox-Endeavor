-- Server-authoritative combat. Weapons supply the moveset (combos + heavy); armor and stats
-- supply defence and scaling (see Gear). Ideas ported from the combat-system reference:
-- frame-data attacks (windup/active/end), cone hit detection, hit stun that cancels swings,
-- posture meter with guard break, parry, i-frame dodge and wall-aware knockback.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Swings = require(Shared.Swings)
local Hideout = require(Shared.Hideout)
local Gear = require(script.Parent.Gear)
local Stats = require(script.Parent.Stats)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local WorldPhase = require(script.Parent.WorldPhase)

local C, F = Config.Combat, Config.Flicker
local BUFFER = 0.08 -- input buffer: an attack may start this early before the last one ends

local Combat = {}
Combat.World = nil -- set by Destruction: { Swing, Bolt, ImprovisedHit, Hit }
Combat.Clashed = Instance.new("BindableEvent") -- (charA, charB, point): two blades met
Combat.Resolved = Instance.new("BindableEvent") -- (attackerChar, victimChar, result)
Combat.Used = Instance.new("BindableEvent") -- (abilityName, player)

local state = setmetatable({}, { __mode = "k" })
local handsFull -- defined with weaponOf below

local function st(char)
	local s = state[char]
	if not s then
		s = {
			block = false, blockStart = 0, iframes = 0, stunned = 0, busyUntil = 0, token = 0,
			lastSpend = 0, lastPostureHit = 0, lastDodge = 0, lastHeavy = 0, lastBlockRelease = -10,
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

local function fx(kind, char, ...)
	Remotes.CombatEvent:FireAllClients(kind, char, ...)
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

-- ===== Wear (see shared/Hideout) =====
local wearDirty = {} -- players whose gear changed condition; recomputed at most a few times a second

local function markWear(player)
	if not wearDirty[player] then
		wearDirty[player] = true
		task.delay(0.5, function()
			wearDirty[player] = nil
			if player.Parent then
				Gear.Recompute(player)
			end
		end)
	end
end

function Combat.WearWeapon(player, weapon)
	local data = PlayerData.Get(player)
	if not data or data.Equipped == "Fists" or not Weapons.Defs[data.Equipped] then
		return
	end
	local id = data.Equipped
	data.Condition[id] = math.max(0, (data.Condition[id] or 100) - Hideout.Wear.WeaponPerHit)
	if data.Condition[id] <= Hideout.Wear.BrokenAt then
		Remotes.Announce:FireClient(player, Weapons.Defs[id].Name .. " is broken. Repair it at a bench.", "Info")
	end
	markWear(player)
end

function Combat.WearWorn(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for _, id in data.Armor do
		data.Condition[id] = math.max(0, (data.Condition[id] or 100) - Hideout.Wear.ArmorPerHitTaken)
	end
	for _, id in data.Cyber do
		data.Condition[id] = math.max(0, (data.Condition[id] or 100) - Hideout.Wear.CyberPerHitTaken)
	end
	markWear(player)
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
	s.windupUntil, s.swingArmorUntil, s.activeUntil = 0, 0, 0
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
	s.queued = nil -- a stagger drops a queued swing
	Combat.CancelFlicker(char)
	s.busyUntil = 0
	s.block = false
	char:SetAttribute("Blocking", false)
	if endsAt <= s.stunned then
		return
	end
	if os.clock() >= s.stunned then
		s.baseSpeed = hum.WalkSpeed
	end
	s.stunned = endsAt
	char:SetAttribute("Stunned", true)
	hum.WalkSpeed = 0
	task.delay(duration, function()
		if os.clock() >= s.stunned and hum.Parent and hum.Health > 0 then
			char:SetAttribute("Stunned", false)
			local player = Players:GetPlayerFromCharacter(char)
			if player then
				Stats.Apply(player, false) -- recomputes speed with any held-chunk penalty
			else
				hum.WalkSpeed = s.baseSpeed or Config.Stats.BaseWalkSpeed
			end
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

-- ===== Launcher + juggle (Config.Momentum, ported from combat-feel) =====
function Combat.IsJuggled(char)
	return os.clock() < (st(char).juggledUntil or 0)
end
function Combat.IsStunned(char)
	return os.clock() < st(char).stunned
end
-- What a fighter is doing, as an enemy reads it (NPCs spacing): phase "Windup" | "Active" | "Recovery" | "Idle"
-- (a feint drops straight to Recovery), the reach of the current or last swing (0 before any), guard up,
-- stunned, and an id that changes with every new swing.
function Combat.Threat(char)
	local s, t = st(char), os.clock()
	local phase = "Idle"
	if t < s.windupUntil then
		phase = "Windup"
	elseif t < (s.activeUntil or 0) then
		phase = "Active"
	elseif t < s.busyUntil then
		phase = "Recovery"
	end
	return phase, s.swingReach or 0, s.block == true, t < s.stunned, s.swingId or 0
end
-- Only non-player bodies get launched (players own their physics and permadeath makes a helpless state too strong).
local function launchable(victim)
	return Players:GetPlayerFromCharacter(victim) == nil and not victim:GetAttribute("NoLaunch") and not victim:GetAttribute("Display")
end
local function land(victim, vs)
	local now = os.clock()
	if now < (vs.juggledUntil or 0) then
		task.delay(vs.juggledUntil - now, land, victim, vs) -- a pop extended it; check again then
		return
	end
	vs.juggledUntil = nil
	if victim.Parent then
		victim:SetAttribute("Juggled", false)
	end
end
local function launch(attacker, victim, vs, t, direction)
	local M = Config.Momentum
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	vs.juggledUntil, vs.juggleHits = t + M.LaunchAirTime, 0
	Combat.Stun(victim, M.LaunchAirTime + M.LandStun)
	root.AssemblyLinearVelocity = Vector3.new(0, M.LaunchVelocity, 0) + direction * M.LaunchDrift
	victim:SetAttribute("Juggled", true)
	fx("Launch", victim, attacker)
	task.delay(M.LaunchAirTime, land, victim, vs)
end
-- A hit on a Juggled target keeps it up (until MaxJuggleHits) and keeps it stunned past the landing.
local function pop(victim, vs, t)
	local M = Config.Momentum
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root or (vs.juggleHits or 0) >= M.MaxJuggleHits then
		return
	end
	vs.juggleHits = (vs.juggleHits or 0) + 1
	vs.juggledUntil = math.max(vs.juggledUntil or t, t) + M.AirPopExtend
	Combat.Stun(victim, (vs.juggledUntil - t) + M.LandStun)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X * 0.5, M.AirPopVelocity, v.Z * 0.5)
	fx("Juggle", victim, vs.juggleHits)
end
-- Launcher hold: a melee heavy started on an open hostile in front of you keeps it staggered until the heavy
-- lands, so its own swing cannot cancel the launcher.
local function holdForLauncher(char, spec, t)
	local M = Config.Momentum
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (M.LaunchHold and root) then
		return
	end
	local look = root.CFrame.LookVector
	for _, model in CollectionService:GetTagged("NPC") do
		local vroot = model:FindFirstChild("HumanoidRootPart")
		if vroot and getHum(model) and launchable(model) and (vroot.Position - root.Position).Magnitude <= spec.Range + M.LaunchHoldReach then
			local vs = st(model)
			local flat = Vector3.new(vroot.Position.X - root.Position.X, 0, vroot.Position.Z - root.Position.Z)
			if t < vs.stunned + M.LaunchGrace and (flat.Magnitude < 3.5 or look:Dot(flat.Unit) >= (spec.Arc or 0.3)) then
				Combat.Stun(model, spec.Windup + spec.Active)
			end
		end
	end
end
-- The closest Juggled body within `range` of a position, or nil.
function Combat.NearestJuggled(position, range)
	local best, bestDist = nil, range
	for _, model in CollectionService:GetTagged("NPC") do
		local root = model:GetAttribute("Juggled") and model:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end


-- opts: Posture, Type ("Physical"|"Arc"|"Thrown"|"Explosive"), Unblockable, GuardBreak (blocks fail; parry still works), SelfHarm,
--       Knockback (studs/s), Stun (seconds)
-- Returns "hit" | "blocked" | "parried" | "dodged" | "guardbreak" | "none"
local function applyDamage(attacker, victim, amount, opts)
	local vhum = getHum(victim)
	if not vhum or vhum.Health <= 0 or (attacker == victim and not opts.SelfHarm) then
		return "none"
	end
	local ap, vp = Players:GetPlayerFromCharacter(attacker), Players:GetPlayerFromCharacter(victim)
	if ap and vp and not WorldPhase.IsOpen() then
		return "none" -- no PvP during the prologue (they should never meet anyway)
	end
	if victim:GetAttribute("Contact") then
		return "none" -- contacts cannot be hurt
	end
	if (vp and vp:GetAttribute("Safe")) or (ap and ap:GetAttribute("Safe")) then
		return "none" -- the Verdant Market is a safe zone: nobody is hurt in it, nobody strikes from it
	end

	local vs, t, vd = st(victim), os.clock(), Gear.OfChar(victim)
	if t < vs.iframes then
		fx("Dodged", victim)
		return "dodged"
	end
	local stunnedBefore, juggled = vs.stunned, Combat.IsJuggled(victim) -- for the launcher, judged before this hit's stun
	if juggled then
		amount *= Config.Momentum.AirDamageMult
	end

	local aroot, vroot = attacker:FindFirstChild("HumanoidRootPart"), victim:FindFirstChild("HumanoidRootPart")
	local away = if aroot and vroot then Vector3.new(vroot.Position.X - aroot.Position.X, 0, vroot.Position.Z - aroot.Position.Z) else Vector3.zero
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zero
	if opts.ContactDir and vroot then
		-- a traced blade pushes along its own path, from where it touched the body (shared/Swings)
		local from = opts.ContactPoint and Vector3.new(vroot.Position.X - opts.ContactPoint.X, 0, vroot.Position.Z - opts.ContactPoint.Z) or Vector3.zero
		local along = Vector3.new(opts.ContactDir.X, 0, opts.ContactDir.Z)
		local mix = (if along.Magnitude > 0.01 then along.Unit * 0.65 else Vector3.zero) + (if from.Magnitude > 0.01 then from.Unit * 0.35 else direction * 0.35)
		if mix.Magnitude > 0.05 then
			direction = mix.Unit
		end
	end

	local result = "hit"
	local facing = aroot and vroot and vroot.CFrame.LookVector:Dot(-direction) > C.BlockMinFacing
	if vs.block and facing and not opts.Unblockable then
		if t - vs.blockStart <= vd.ParryWindow then
			Combat.Stun(attacker, C.ParryStun)
			Combat.AddPosture(victim, -C.ParryPostureRelief)
			fx("Parry", victim)
			return "parried"
		end
		local posture = Combat.AddPosture(victim, opts.Posture or 0)
		if opts.GuardBreak or posture >= (victim:GetAttribute("MaxPosture") or 1) then
			victim:SetAttribute("Posture", 0)
			Combat.Stun(victim, C.GuardBreakStun)
			fx("GuardBreak", victim)
			result = "guardbreak"
		else
			amount *= 1 - vd.BlockReduction
			fx("Block", victim)
			result = "blocked"
		end
	end

	if t < vs.takenUntil then
		amount *= vs.takenMult
	end
	-- armor knows Physical and Arc; thrown and explosive damage count as Physical for resists
	amount *= 1 - math.min(C.MaxResist, vd.Resist[if opts.Type == "Arc" then "Arc" else "Physical"] or 0)

	vhum:TakeDamage(amount)
	victim:SetAttribute("LastHitType", opts.Type or "Physical")
	if ap and amount > 0 then
		-- the attacker's own feedback: a floating number (its colour says blocked / normal / arc)
		Remotes.CombatEvent:FireClient(ap, "Damage", victim, { amount, result, opts.Type or "Physical" })
	end
	if vp then
		Combat.WearWorn(vp)
	end
	if attacker ~= victim then
		tag(attacker, victim)
	end

	if result ~= "blocked" and t >= math.max(vs.hyperarmorUntil, vs.swingArmorUntil) then
		Combat.Stun(victim, opts.Stun or C.HitStunDefault)
		if opts.Knockback and opts.Knockback > 0 then
			knockback(victim, direction, opts.Knockback)
		end
	end
	local launchOk = opts.Launches and (opts.StartedAt or t) < stunnedBefore + Config.Momentum.LaunchGrace and launchable(victim)
	if result ~= "blocked" and vhum.Health > 0 then
		if juggled then
			pop(victim, vs, t) -- keep it up there
		elseif launchOk then
			launch(attacker, victim, vs, t, direction) -- a heavy on an open hostile sends it up
		end
	elseif result ~= "blocked" and launchOk and not juggled then
		-- the launcher killed it: the body still goes up, so the launch reads even on a kill
		local root = victim:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, Config.Momentum.LaunchVelocity, 0) + direction * Config.Momentum.LaunchDrift
			fx("Launch", victim, attacker)
		end
	end
	if result == "hit" then
		fx("Hit", victim, amount, opts.ContactPoint, opts.ContactDir, attacker)
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
local function pulse(char, spec, mods, seen, tracer)
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
	local opts = { Posture = posture, Type = if mods.hitType and spec.Type ~= "Arc" then mods.hitType else spec.Type, Knockback = spec.Knockback, Stun = spec.Stun, Unblockable = mods.unblockable, GuardBreak = mods.guardBreak,
		Launches = mods.label == "Heavy" and not spec.Ranged and not spec.NoLaunch, StartedAt = mods.startedAt }

	local function strike(model, contact)
		seen[model] = true
		if seen.__flick == nil then
			seen.__flick = judgeFlick(s, d) or false
		end
		local flick = seen.__flick
		local hitDamage, hitOpts = damage, opts
		if contact then
			hitOpts = table.clone(opts)
			hitOpts.ContactPoint, hitOpts.ContactDir = contact.Point, contact.Dir
		end
		if flick then
			hitOpts = table.clone(hitOpts)
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
			local player = Players:GetPlayerFromCharacter(char)
			if player and mods.weapon and not mods.improvised then
				Combat.WearWeapon(player, mods.weapon)
			end
		end
		if mods.onHit then
			mods.onHit(result, model)
		end
	end

	if tracer and not spec.Ranged then
		return tracer(strike, damage)
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
		elseif result and Combat.World then
			Combat.World.Bolt(char, result.Instance, damage, mods.weapon)
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
	if Combat.World then
		Combat.World.Swing(char, origin, look, spec, damage, mods.weapon, mods.label == "Heavy", seen)
	end
end

-- ===== The traced blade (shared/Swings; Mordhau-style) =====
-- During the live window the blade sweeps its arc every frame: whatever it passes through is hit at the
-- point of contact; a wall stops it (a glance); another live blade it meets cancels both swings (a clash).
local liveBlades = {} -- char -> { base, tip, token, s }
Combat.LiveBlades = function()
	return liveBlades
end

local function cancelSwing(char, recover)
	local s = st(char)
	s.token += 1
	s.windupUntil, s.activeUntil, s.swingArmorUntil = 0, 0, 0
	s.busyUntil = os.clock() + recover
	liveBlades[char] = nil
end

local function clash(a, b, point)
	cancelSwing(a, C.ClashRecover)
	cancelSwing(b, C.ClashRecover)
	for _, pair in { { a, b }, { b, a } } do
		local me, other = pair[1], pair[2]
		local r1, r2 = me:FindFirstChild("HumanoidRootPart"), other:FindFirstChild("HumanoidRootPart")
		if r1 and r2 then
			local away = Vector3.new(r1.Position.X - r2.Position.X, 0, r1.Position.Z - r2.Position.Z)
			if away.Magnitude > 0.1 then
				knockback(me, away.Unit, C.ClashPush)
			end
		end
	end
	fx("Clash", a, point, b)
	Combat.Clashed:Fire(a, b, point)
end

-- bodies a blade could reach this frame
local function nearbyBodies(char, origin, radius)
	local out = {}
	local function consider(model)
		if model ~= char and model.Parent and getHum(model) and getHum(model).Health > 0 then
			local r = model:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - origin).Magnitude <= radius then
				table.insert(out, model)
			end
		end
	end
	-- any humanoid body whose parts are near (dummies, mannequins, untagged rigs), then the tagged ones
	local seen = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(origin, radius, params)
	end)
	for _, part in (ok and parts) or {} do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not getHum(model) do
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			consider(model)
		end
	end
	for _, model in CollectionService:GetTagged("NPC") do
		if not seen[model] then
			seen[model] = true
			consider(model)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character and not seen[player.Character] then
			seen[player.Character] = true
			consider(player.Character)
		end
	end
	return out
end

-- a body as a capsule: its root's vertical axis, radius from the rig's width
local function capsule(model, cache)
	local c = cache[model]
	if not c then
		local hum = getHum(model)
		local half = math.max(2.2, ((hum and hum.HipHeight) or 2) + 0.6)
		local r = model:FindFirstChild("HumanoidRootPart")
		c = { half = half, radius = math.max(C.BodyRadius, (r and r.Size.X or 2) * 0.55) }
		cache[model] = c
	end
	return c
end

local SAMPLES = 5
local function traceBlade(char, spec, mods, seen, strike, damage)
	local s = st(char)
	local token = s.token
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local id, scale = mods.shape, Swings.ScaleOf(char)
	local reach = spec.Range * scale
	local elapsed, last, pauseUntil = 0, os.clock(), 0
	local prevBase, prevTip = Swings.Blade(root.CFrame, id, 0, reach, scale)
	local cache = {}
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { char }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { char }
	ray.RespectCanCollide = false
	while elapsed < spec.Active and s.token == token and isAlive(char) do
		RunService.Heartbeat:Wait()
		local now = os.clock()
		local dt = now - last
		last = now
		if s.token ~= token or not root.Parent then
			break
		end
		if now >= pauseUntil then
			elapsed += dt
		end
		local u = math.min(elapsed / spec.Active, 1)
		local base, tip = Swings.Blade(root.CFrame, id, u, reach, scale)
		liveBlades[char] = { base = base, tip = tip, prevBase = prevBase, prevTip = prevTip, token = token, s = s }
		-- 1. blade meets blade mid-air: both swings are gone. Both blades are swept from where they were last
		-- frame to where they are now, so two fast arcs cannot pass through each other between frames.
		for other, b in liveBlades do
			if other ~= char and other.Parent and b.s.token == b.token then
				for k = 0, SAMPLES - 1 do
					local f = k / (SAMPLES - 1)
					local dist, pa, pb = Swings.SegmentDistance(prevBase:Lerp(base, f), prevTip:Lerp(tip, f), b.prevBase:Lerp(b.base, f), b.prevTip:Lerp(b.tip, f))
					if dist <= C.ClashRadius then
						clash(char, other, (pa + pb) / 2)
						return
					end
				end
			end
		end
		-- 2. bodies the blade passed through since last frame, hit where it touched
		for _, model in nearbyBodies(char, root.Position, reach + 6) do
			if not seen[model] then
				local vr = model:FindFirstChild("HumanoidRootPart")
				local cap = capsule(model, cache)
				local axisA, axisB = vr.Position - Vector3.new(0, cap.half, 0), vr.Position + Vector3.new(0, cap.half * 0.75, 0)
				local hitAt, hitDir
				for k = 1, SAMPLES do
					local f = (k - 1) / (SAMPLES - 1)
					local p0, p1 = prevBase:Lerp(prevTip, f), base:Lerp(tip, f)
					local dist, onBlade = Swings.SegmentDistance(p0, p1, axisA, axisB)
					if dist <= cap.radius then
						hitAt, hitDir = onBlade, (if (p1 - p0).Magnitude > 0.01 then (p1 - p0).Unit else (tip - base).Unit)
						break
					end
				end
				if not hitAt then
					local dist, onBlade = Swings.SegmentDistance(base, tip, axisA, axisB) -- a thrust's tip driving in
					if dist <= cap.radius then
						hitAt, hitDir = onBlade, (tip - base).Unit
					end
				end
				if hitAt then
					strike(model, { Point = hitAt, Dir = hitDir })
					pauseUntil = now + C.HitStop -- the blade bites and holds for a beat
				end
			end
		end
		-- 3. the world: props break where struck; a wall stops the swing
		for k = 2, SAMPLES do
			local f = (k - 1) / (SAMPLES - 1)
			local p0, p1 = prevBase:Lerp(prevTip, f), base:Lerp(tip, f)
			local d = p1 - p0
			if d.Magnitude > 0.05 then
				local res = workspace:Raycast(p0, d, ray)
				local inst = res and res.Instance
				local body = inst and inst:FindFirstAncestorOfClass("Model")
				if inst and not (body and getHum(body)) then
					local struck = Combat.World and Combat.World.Hit and Combat.World.Hit(char, inst, damage, mods.weapon, mods.label == "Heavy", seen)
					if not struck and inst.CanCollide and inst.Anchored and math.abs(res.Normal.Y) < 0.5 and inst.Transparency < 0.9 then
						cancelSwing(char, C.GlanceRecover)
						fx("Glance", char, res.Position)
						return
					end
				end
			end
		end
		-- thin rays slip past posts and crates: the blade's middle and tip also sweep a small sphere for props
		if Combat.World and Combat.World.Hit then
			for _, at in { base:Lerp(tip, 0.55), tip } do
				for _, part in workspace:GetPartBoundsInRadius(at, C.BladeProbe, overlap) do
					local body = part:FindFirstAncestorOfClass("Model")
					if not (body and getHum(body)) then
						Combat.World.Hit(char, part, damage, mods.weapon, mods.label == "Heavy", seen)
					end
				end
			end
		end
		prevBase, prevTip = base, tip
	end
	liveBlades[char] = nil
end

-- Runs a full swing: marks the character busy, waits out the windup, then pulses the hitbox
-- for `Active` seconds. Being hit-stunned during the windup (token bump) cancels the swing.
-- mods.shape (a Swings shape id) traces a blade along that arc instead of pulsing a cone.
-- mods: damageMult, postureMult, noStatScaling, unblockable, chargeBonus, onHit(result, model)
function Combat.Swing(char, spec, mods)
	mods = mods or {}
	local s, t0 = st(char), os.clock()
	local token = s.token
	s.busyUntil = t0 + spec.End
	s.windupUntil = t0 + spec.Windup
	s.activeUntil = t0 + spec.Windup + spec.Active
	s.swingReach = spec.Range
	s.swingId = (s.swingId or 0) + 1
	s.swingArmorUntil = if spec.Hyperarmor then t0 + spec.Windup + spec.Active else 0
	fx("Swing", char, mods.label, mods.shape, spec.Windup, spec.Active, spec.End, spec.Range)

	task.delay(spec.Windup, function()
		if s.token ~= token or not isAlive(char) then
			return
		end
		local seen = {}
		if mods.shape and not spec.Ranged then
			pulse(char, spec, mods, seen, function(strike, damage)
				traceBlade(char, spec, mods, seen, strike, damage)
			end)
			return
		end
		local endAt = os.clock() + spec.Active
		repeat
			pulse(char, spec, mods, seen)
			RunService.Heartbeat:Wait()
		until os.clock() >= endAt or s.token ~= token or not isAlive(char)
	end)
end

local function weaponOf(player)
	local data, char = PlayerData.Get(player), player.Character
	if char and char:GetAttribute("Improvised") then
		return Weapons.Defs.PipeClub, true -- a pipe or sign plate swung like a club
	end
	if data and Gear.Get(player).WeaponBroken then
		return Weapons.Defs.Fists, false -- a broken weapon is dead weight; you fight with your hands
	end
	return data and (Weapons.Defs[data.Equipped] or Weapons.Defs.Fists), false
end

-- Two-handed loads (Medium/Heavy chunks) stop you swinging and blocking.
function handsFull(char)
	local class = char:GetAttribute("HoldClass")
	return class == "Medium" or class == "Heavy"
end

-- Cell-fed weapons spend ammo per shot; returns false (and tells the player) when dry.
local function spendAmmo(player, weapon)
	if not weapon.Ammo then
		return true
	end
	local Inventory = require(script.Parent.Inventory)
	if Inventory.Count(player, weapon.Ammo) <= 0 then
		Remotes.Announce:FireClient(player, "Out of " .. weapon.Ammo .. "s. Craft more from Batteries and Wire.", "Info")
		return false
	end
	return Inventory.Remove(player, weapon.Ammo, 1)
end

-- Input queue (Config.Combat.InputQueue, ported from combat-feel): an attack or heavy pressed while your last
-- swing is still finishing is held and plays the moment you're free instead of being thrown away, so a
-- natural light, light, heavy never drops a press. One slot: the latest press wins. Getting staggered,
-- dodging or raising your guard clears it.
local function enqueue(player, char, action)
	local s, t = st(char), os.clock()
	if not isAlive(char) or t < s.stunned then
		return
	end
	local wait = s.busyUntil - BUFFER - t
	if wait <= 0 or wait > C.InputQueue then
		return
	end
	local ticket, token = {}, s.token
	s.queued = ticket
	task.delay(wait, function()
		if s.queued ~= ticket then
			return -- replaced by a later press, or cleared
		end
		s.queued = nil
		if s.token == token and player.Character == char then
			action(player)
		end
	end)
end

function Combat.Attack(player)
	local char = player.Character
	local weapon, improvised = weaponOf(player)
	if not (char and weapon) or handsFull(char) then
		return
	end
	if not Combat.CanAct(char) then
		enqueue(player, char, Combat.Attack)
		return
	end
	st(char).queued = nil
	local s, t = st(char), os.clock()
	local combo = if s.comboWeapon == weapon and t <= s.comboExpires then s.combo % #weapon.Attacks + 1 else 1
	local spec = weapon.Attacks[combo]
	if not Combat.SpendStamina(char, spec.Stamina) or not spendAmmo(player, weapon) then
		return
	end
	s.block = false
	char:SetAttribute("Blocking", false)
	s.combo, s.comboWeapon = combo, weapon
	local mods = { chargeBonus = weapon.ChargeBonus, label = combo, weapon = weapon, improvised = improvised, shape = Swings.ShapeFor(weapon.Family, combo, false) }
	if improvised then
		mods.onHit = function(result)
			if (result == "hit" or result == "blocked" or result == "guardbreak") and Combat.World then
				Combat.World.ImprovisedHit(player)
			end
		end
	end
	Combat.Swing(char, spec, mods)
	if combo == #weapon.Attacks then -- end of the chain: recovery
		s.busyUntil += weapon.ComboCooldown
	end
	s.comboExpires = s.busyUntil + weapon.ComboReset
end

function Combat.Heavy(player)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon) or handsFull(char) then
		return
	end
	if not Combat.CanAct(char) then
		enqueue(player, char, Combat.Heavy)
		return
	end
	st(char).queued = nil
	local s, t = st(char), os.clock()
	if t - s.lastHeavy < C.HeavyCooldown or not Combat.SpendStamina(char, weapon.Heavy.Stamina) or not spendAmmo(player, weapon) then
		return
	end
	s.lastHeavy, s.block, s.combo = t, false, 0
	Combat.Used:Fire("Heavy", player)
	char:SetAttribute("Blocking", false)
	-- Heavies are criticals: they crush blocks (extra posture damage).
	local mods = { chargeBonus = weapon.ChargeBonus, label = "Heavy", postureMult = C.CriticalPostureMult, weapon = weapon, hitType = "Heavy", startedAt = t, shape = Swings.ShapeFor(weapon.Family, 1, true) }
	if not weapon.Heavy.Ranged and not weapon.Heavy.NoLaunch then
		holdForLauncher(char, weapon.Heavy, t)
	end
	Combat.Swing(char, weapon.Heavy, mods)
end

-- Sprint: faster while stamina lasts. Blocking, two-handed loads and stun end it.
function Combat.SetSprint(player, on)
	local char = player.Character
	if not char or type(on) ~= "boolean" then
		return
	end
	local s = st(char)
	if on then
		if not isAlive(char) or os.clock() < s.stunned or s.block or handsFull(char) or (char:GetAttribute("Stamina") or 0) < C.SprintMinStamina then
			return
		end
	end
	if (char:GetAttribute("Sprinting") == true) ~= on then
		char:SetAttribute("Sprinting", on)
		Stats.Apply(player, false)
	end
end

function Combat.SetBlock(player, down)
	local char = player.Character
	if not char or type(down) ~= "boolean" then
		return
	end
	local s = st(char)
	if down then
		s.queued = nil -- guarding drops a queued swing
		if Combat.CanAct(char) and not s.block and os.clock() >= s.busyUntil and not handsFull(char) then
			local t = os.clock()
			Combat.SetSprint(player, false)
			s.block = true
			-- Tapping block repeatedly must not re-arm the parry window every press.
			s.blockStart = if t - s.lastBlockRelease >= C.ParryRearm then t else -10
			char:SetAttribute("Blocking", true)
		end
	else
		if s.block then
			s.lastBlockRelease = os.clock()
		end
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
	s.queued = nil -- a dodge drops a queued swing
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 or not Combat.SpendStamina(char, C.DodgeCost) then
		return
	end
	s.token += 1 -- dodging cancels a swing that hasn't landed yet
	local root = char:FindFirstChild("HumanoidRootPart")
	local look = root and Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local side = look and look.Magnitude > 0 and math.abs(direction.Unit:Dot(look.Unit)) < 0.5
	s.lastDodge, s.iframes, s.block = t, t + Gear.Get(player).DodgeIFrames * (if side then Config.Momentum.SideIFrameMult else 1), false
	s.busyUntil = t + 0.2
	char:SetAttribute("Blocking", false)
	-- Enemy Step: a dodge next to a Juggled enemy springs off it - stamina back and a hop
	local velocity = direction.Unit * C.DodgeSpeed
	local step = root and Combat.NearestJuggled(root.Position, Config.Momentum.EnemyStepRange)
	if step then
		Combat.AddStamina(char, Config.Momentum.EnemyStepRefund)
		velocity += Vector3.new(0, Config.Momentum.EnemyStepHop, 0)
		fx("EnemyStep", char, step)
	end
	Remotes.CombatEvent:FireClient(player, "DodgeMove", velocity)
	fx("Dodge", char)
end

function Combat.Init()
	Net.On("Attack", { rate = 8, burst = 12 }, Combat.Attack)
	Net.On("Heavy", { rate = 4, burst = 6 }, Combat.Heavy)
	Net.On("Feint", { rate = 6, burst = 8 }, Combat.Feint)
	Net.On("Flicker", { rate = 8, burst = 12 }, Combat.Flicker)
	Net.On("Block", { rate = 4, burst = 8, args = { "boolean" } }, Combat.SetBlock)
	Net.On("Sprint", { rate = 4, burst = 8, args = { "boolean" } }, Combat.SetSprint)
	Net.On("Dodge", { rate = 4, burst = 6, args = { "vector" } }, Combat.Dodge)

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
				if char:GetAttribute("Sprinting") then
					local hum = getHum(char)
					if hum and hum.MoveDirection.Magnitude > 0.1 then
						Combat.AddStamina(char, -C.SprintStaminaPerSecond * step)
						s.lastSpend = t
					end
					if (char:GetAttribute("Stamina") or 0) <= 0 or t < s.stunned then
						local player = Players:GetPlayerFromCharacter(char)
						if player then
							Combat.SetSprint(player, false)
						end
					end
				elseif maxStamina and not s.block and t - s.lastSpend > C.StaminaRegenDelay then
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
