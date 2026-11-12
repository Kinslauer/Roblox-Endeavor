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
local WoundService = require(script.Parent.Common.WoundService)

local C, F = Config.Combat, Config.Flicker
local G = Config.Guns -- round 3: guns and ammo
local BUFFER = 0.08 -- input buffer: an attack may start this early before the last one ends

local Combat = {}
Combat.Deflected = Instance.new("BindableEvent") -- (shooter char, model, zone, position): a round stopped by plate
Combat.Shot = Instance.new("BindableEvent") -- (char, instanceHit?, position, weaponDef): every ranged shot (server/Stealth listens)
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
	return isAlive(char) and t >= s.stunned and t >= s.busyUntil - BUFFER and not char:GetAttribute("Knocked")
end

-- Two weapons (server/Kit): a swap may come mid-chain, between swings; never while stunned, knocked or reloading.
function Combat.CanSwap(char)
	local s = st(char)
	local t = os.clock()
	return isAlive(char) and t >= s.stunned and not s.reloading and not char:GetAttribute("Knocked")
		and not (s.activeUntil and t < s.activeUntil)
end
function Combat.Swapped(char, seconds)
	local s, t = st(char), os.clock()
	s.queued = nil
	s.busyUntil = math.max(s.busyUntil, t + seconds)
	s.swappedAt = t
	s.comboExpires = math.max(s.comboExpires, s.busyUntil + Config.Kit.Delay.After + Config.Kit.Delay.Window)
	Combat.Used:Fire("Swap", Players:GetPlayerFromCharacter(char))
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
	vs.shotPops = 0
	if victim.Parent then
		victim:SetAttribute("Juggled", false)
		local root = victim:FindFirstChild("HumanoidRootPart")
		local float = root and root:FindFirstChild("JuggleHang")
		if float then
			float:Destroy()
		end
	end
end
-- the float: once the launch has spent most of its rise, gravity mostly lets go so the body lingers
local function hang(victim, root)
	local M = Config.Momentum
	if root:FindFirstChild("JuggleHang") then
		return
	end
	local rise = math.max(0, root.AssemblyLinearVelocity.Y - M.HangBelow)
	task.delay(rise / math.max(workspace.Gravity, 1), function()
		if not (root.Parent and victim:GetAttribute("Juggled")) or root:FindFirstChild("JuggleHang") then
			return
		end
		local a = root:FindFirstChild("JuggleAttachment") or Instance.new("Attachment")
		a.Name = "JuggleAttachment"
		a.Parent = root
		local f = Instance.new("VectorForce")
		f.Name = "JuggleHang"
		f.Attachment0 = a
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - M.HangGravity), 0)
		f.Parent = root
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.4, math.min(v.Y, M.HangBelow), v.Z * 0.4) -- stay in front
	end)
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
	hang(victim, root)
	fx("Launch", victim, attacker)
	task.delay(M.LaunchAirTime, land, victim, vs)
end
-- A Medium/Heavy weapon's launcher throws up everything around the impact, not just the body it hit.
local function groupLaunch(attacker, victim, opts, t)
	local radius = opts.Mass and Config.Momentum.GroupLaunch[opts.Mass]
	local vroot = victim:FindFirstChild("HumanoidRootPart")
	if not (radius and vroot) then
		return 0
	end
	local center = opts.ContactPoint or vroot.Position
	local aroot = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local n = 0
	for _, model in CollectionService:GetTagged("NPC") do
		local root = model ~= victim and model ~= attacker and model:FindFirstChild("HumanoidRootPart")
		local hum = root and getHum(model)
		if hum and hum.Health > 0 and launchable(model) and not model:GetAttribute("Contact") and not Combat.IsJuggled(model)
			and (root.Position - center).Magnitude <= radius then
			local away = if aroot then root.Position - aroot.Position else root.Position - center
			away = Vector3.new(away.X, 0, away.Z)
			launch(attacker, model, st(model), t, if away.Magnitude > 0.01 then away.Unit else Vector3.zero)
			n += 1
		end
	end
	return n
end
-- A hit on a Juggled target keeps it up (until MaxJuggleHits) and keeps it stunned past the landing.
local function pop(victim, vs, t, shot)
	local M = Config.Momentum
	local root = victim:FindFirstChild("HumanoidRootPart")
	if shot then
		-- rounds keep a floating body up with small pops of their own (Config.Kit.ShotPop), past the melee cap
		local P = Config.Kit.ShotPop
		if not root or (vs.shotPops or 0) >= P.Max then
			return
		end
		vs.shotPops = (vs.shotPops or 0) + 1
		vs.juggledUntil = math.max(vs.juggledUntil or t, t) + P.Extend
		Combat.Stun(victim, (vs.juggledUntil - t) + M.LandStun)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.5, math.max(v.Y, P.Velocity), v.Z * 0.5)
		hang(victim, root)
		fx("Juggle", victim, vs.juggleHits or 0)
		return
	end
	if not root or (vs.juggleHits or 0) >= M.MaxJuggleHits then
		return
	end
	vs.juggleHits = (vs.juggleHits or 0) + 1
	vs.juggledUntil = math.max(vs.juggledUntil or t, t) + M.AirPopExtend
	Combat.Stun(victim, (vs.juggledUntil - t) + M.LandStun)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, M.AirPopVelocity, v.Z * 0.3)
	hang(victim, root)
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
	-- A traced blade (opts.Guarded set) is blocked only if it met the guard on its way in (traceBlade); one that came
	-- around it, over it or from behind lands even on a raised guard. Everything else still blocks by facing.
	local covered
	if opts.Guarded ~= nil then
		covered = opts.Guarded == true
	else
		covered = aroot and vroot and vroot.CFrame.LookVector:Dot(-direction) > C.BlockMinFacing
	end
	if vs.block and covered and not opts.Unblockable then
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

	-- knocked down, not dead (server/Knock): a blow that would end a player drops them instead, once in a while
	if vp and amount >= vhum.Health and not victim:GetAttribute("Knocked") and require(script.Parent.Knock).Try(victim, attacker) then
		amount = math.max(0, vhum.Health - 1)
	end
	vhum:TakeDamage(amount)
	victim:SetAttribute("LastHitType", opts.Type or "Physical")
	if vp and amount > 0 then
		-- where it landed and what that did to the body (common/WoundService): bleeds, breaks, a part knocked out
		if not WoundService.Get(victim) then
			WoundService.Attach(victim)
		end
		WoundService.Hit(victim, { Amount = amount, At = opts.HitAt or opts.ContactPoint, CanLose = true,
			Kind = opts.WoundKind or WoundService.KindOf(nil, opts.Type, false) })
	end
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
			pop(victim, vs, t, opts.Shot == true) -- keep it up there
		elseif launchOk then
			launch(attacker, victim, vs, t, direction) -- a heavy on an open hostile sends it up
			groupLaunch(attacker, victim, opts, t) -- and a big enough weapon takes the crowd around it too
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
		-- the reaction plays for as long as the victim is stunned (0 when armour shrugged it off)
		local stunned = if t >= math.max(vs.hyperarmorUntil, vs.swingArmorUntil) then (opts.Stun or C.HitStunDefault) else 0
		fx("Hit", victim, amount, opts.ContactPoint, opts.ContactDir, attacker, stunned)
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
		Mass = mods.weapon and mods.weapon.Mass, Launches = (mods.label == "Heavy" or mods.launches == true) and not spec.Ranged and not spec.NoLaunch, StartedAt = mods.startedAt }
	opts.WoundKind = WoundService.KindOf(mods.weapon and mods.weapon.Family, opts.Type, spec.Ranged)
	if not spec.Ranged and Players:GetPlayerFromCharacter(char) then
		damage *= WoundService.Effects(char).Melee -- an arm out or broken swings weaker
	end

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
			hitOpts.Guarded = contact.Guarded == true
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
		return result
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
		-- the shot goes where the shooter looks (the Attack remote's aim, kept near the facing), from the shoulder
		if s.aim and os.clock() - s.aimAt < 1.5 then
			look = s.aim
			origin += Vector3.new(0, 1.2, 0)
		end
		local shake = char:GetAttribute("WoundShake")
		shake = if type(shake) == "number" then shake else 0
		-- a hot barrel and tired arms move the round too (round 3: Config.Guns)
		local hot = char:GetAttribute("Heat")
		if type(hot) == "number" and hot > G.Heat.Hot then
			shake += (hot - G.Heat.Hot) / (1 - G.Heat.Hot) * G.Heat.Spread
		end
		shake += (char:GetAttribute("ArmFatigue") or 0) * G.Fatigue.Drift
		if shake > 0 then
			-- pain, a broken or dead arm: the muzzle drifts (common/WoundService)
			local r = math.rad(shake)
			look = (CFrame.lookAt(Vector3.zero, look) * CFrame.Angles((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, 0)).LookVector
		end
		local result = workspace:Raycast(origin, look * spec.Range, ray)
		fx("Bolt", char, if result then result.Position else origin + look * spec.Range, mods.weapon and mods.weapon.Noise)
		Combat.Shot:Fire(char, result and result.Instance, if result then result.Position else origin + look * spec.Range, mods.weapon)
		local model = result and result.Instance:FindFirstAncestorOfClass("Model")
		while model and not getHum(model) and model.Parent and model.Parent:IsA("Model") do
			model = model.Parent -- a piece of a one-piece body (the Skin model inside the character)
		end
		if model and getHum(model) then
			-- where the round landed decides what it does (Weapons.Calibers): plate rated above the calibre stops
			-- it dead (a ping, no wound, and whoever wears it knows he is being shot at); flesh takes it, the
			-- head most of all
			local w = mods.weapon
			-- the round in the chamber: the calibre with its load (Weapons.Round); an NPC fires the standard load
			local cal = w and w.Caliber and Weapons.Calibers[w.Caliber]
			local round = cal and (if s.round and s.round.Caliber == w.Caliber then s.round else Weapons.Round(cal.Item))
			s.round = nil
			local zone, rating = Combat.HitZone(model, result.Position)
			local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
			if round then
				damage *= round.Damage
				if round.Emp and model:GetAttribute("Radio") then
					-- the light EMP .22 discharges into what it meets: the radio on him is dead either way
					model:SetAttribute("Radio", false)
					fx("Emp", model, result.Position)
				end
			end
			if round and rating > round.Pen then
				Combat.WearPlate(model, zone, rating, 0.5 * (1 + math.max(0, round.Pen)))
				if round.Emp then
					return -- a light round on plate: a tick he does not notice, no ping, no alert
				end
				fx("Ping", model, result.Position, zone)
				Combat.Deflected:Fire(char, model, zone, result.Position)
				if isPlayer then
					WoundService.Bruise(model, { Amount = damage, At = result.Position }) -- plate stops it, the body still feels it
				end
				-- a glance off the plate goes on, weaker
				local n = result.Normal
				if math.abs(look:Dot(n)) < G.Ricochet.Dot then
					local out = look - 2 * look:Dot(n) * n
					local ray2 = RaycastParams.new()
					ray2.FilterType = Enum.RaycastFilterType.Exclude
					ray2.FilterDescendantsInstances = { char, model }
					local again = workspace:Raycast(result.Position + n * 0.05, out * G.Ricochet.Range, ray2)
					fx("Ricochet", model, result.Position, if again then again.Position else result.Position + out * G.Ricochet.Range)
					local other = again and again.Instance:FindFirstAncestorOfClass("Model")
					while other and not getHum(other) and other.Parent and other.Parent:IsA("Model") do
						other = other.Parent
					end
					if other and getHum(other) then
						damage *= G.Ricochet.Damage
						opts.HitAt = again.Position
						opts.Shot = true
						strike(other)
					end
				end
				return
			end
			if zone == "Head" or zone == "Helmet" then
				damage *= if isPlayer then C.HeadshotPlayers elseif cal then cal.Head else C.Headshot
			elseif cal and (zone == "Limb" or zone == "Bracers" or zone == "Shins") then
				damage *= cal.Limb
			end
			if round and rating > 0 then
				damage *= cal.Through -- it went through plate first
				Combat.WearPlate(model, zone, rating, 0.5 * (1 + math.max(0, round.Pen)))
			elseif round then
				damage *= round.Flesh -- flesh takes the load's own way of opening it
			end
			opts.HitAt = result.Position
			opts.Shot = true
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

-- Where on a body a point is, and how much plate is there: zone "Helmet" | "Head" | "Vest" | "Body" | "Bracers" |
-- "Shins" | "Limb", rating 0 for flesh. The limb is the one whose box the point is nearest to; the plate comes
-- from the body's armour attributes (HelmetCover, Helmet, Vest, Bracers, Shins).
function Combat.HitZone(model, position)
	local best, bestD
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local p = part.CFrame:PointToObjectSpace(position)
			local h = part.Size / 2
			local d = (p - Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))).Magnitude
			if not bestD or d < bestD then
				best, bestD = part, d
			end
		end
	end
	if not best then
		return "Body", 0
	end
	local name = best.Name
	local function plate(zone, flesh)
		local rating = model:GetAttribute(zone)
		if type(rating) == "number" and rating > 0 then
			return zone, rating
		end
		return flesh, 0
	end
	if name == "Head" then
		local cover = model:GetAttribute("HelmetCover")
		local y = best.CFrame:PointToObjectSpace(position).Y
		if type(cover) == "number" and y > best.Size.Y * (0.5 - cover) then
			return plate("Helmet", "Head")
		end
		return "Head", 0
	elseif name == "UpperTorso" then
		return plate("Vest", "Body")
	elseif name == "LowerTorso" then
		return "Body", 0
	elseif name:find("LowerArm") then
		return plate("Bracers", "Limb")
	elseif name:find("LowerLeg") then
		return plate("Shins", "Limb")
	end
	return "Limb", 0
end

-- Plate wears through (round 3): every round that meets a plate adds `amount` (half of 1 + its Pen: a .22 0.5, a
-- 7.62x51 2) to `<zone>Wear`; at
-- Config.Guns.PlateHits[zone] x rating the plate is gone (rating 0, `<zone>Broken`), and rounds reach the body.
function Combat.WearPlate(model, zone, rating, amount)
	local limit = Config.Guns.PlateHits[zone]
	if not limit or rating <= 0 then
		return false
	end
	local wear = (model:GetAttribute(zone .. "Wear") or 0) + (amount or 1)
	model:SetAttribute(zone .. "Wear", wear)
	if wear >= limit * rating then
		model:SetAttribute(zone, 0)
		model:SetAttribute(zone .. "Broken", true) -- Kit.Apply leaves a broken plate broken for this body
		local root = model:FindFirstChild("HumanoidRootPart")
		fx("PlateBreak", model, root and root.Position, zone)
		return true
	end
	return false
end

-- ===== The traced blade (shared/Swings; Mordhau-style) =====
-- During the live window the blade sweeps its arc every frame: whatever it passes through is hit at the
-- point of contact; a wall stops it (a glance); another live blade it meets cancels both swings (a clash).
local liveBlades = {} -- char -> { base, tip, token, s }
Combat.LiveBlades = function()
	return liveBlades
end

-- ===== The guard (F), server side: the same shape the clients pose (shared/Swings.GuardPose/GuardSegment) =====
-- A raised guard follows the nearest incoming blade (winding up or live) at Config.Combat.GuardFollow, turning at
-- most Swings.GuardTurn off the body's facing. A traced blade is blocked only where it meets this segment before
-- it meets the body: a swing from behind, past the turn, or from a second attacker while the guard is turned to
-- the first comes around it and lands.
local swingers = {} -- char -> { id, t0, windup, active, reach, scale, token, s } for shaped swings in progress
local guards = {} -- char -> { hand, blade, yaw, high, length, armed }
Combat.Guards = function()
	return guards
end

local function guardThreat(char, root)
	local best, bestD = nil, C.GuardSight
	local now = os.clock()
	for other, w in swingers do
		if not other.Parent or w.s.token ~= w.token or now > w.t0 + w.windup + w.active + 0.05 then
			swingers[other] = nil
			continue
		end
		local oroot = other ~= char and other:FindFirstChild("HumanoidRootPart")
		if oroot then
			-- where its arc first reaches this body: the guard holds there through the whole swing, not chasing the blade
			local mid = Swings.ThreatPoint(oroot.CFrame, w.id, 0, w.reach, w.scale, root.Position)
			local d = (mid - root.Position).Magnitude
			if d < bestD then
				best, bestD = root.CFrame:PointToObjectSpace(mid), d
			end
		end
	end
	return best
end

local function raiseGuard(char)
	local player = Players:GetPlayerFromCharacter(char)
	local data = player and PlayerData.Get(player)
	local def = data and Weapons.Defs[data.Equipped]
	local range = def and def.Attacks and def.Attacks[1] and def.Attacks[1].Range
	local hand, blade, yaw, high = Swings.GuardPose(nil, Swings.ScaleOf(char))
	guards[char] = { hand = hand, blade = blade, yaw = yaw, high = high, length = Swings.GuardLength(range),
		armed = char:FindFirstChild("HeldWeapon") ~= nil and not (def and def.Ranged) }
end

local function followGuards(dt)
	local a = 1 - math.exp(-dt * C.GuardFollow)
	for char, g in guards do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		if not root or not st(char).block then
			guards[char] = nil
			continue
		end
		local hand, blade, yaw, high = Swings.GuardPose(guardThreat(char, root), Swings.ScaleOf(char))
		g.hand = g.hand:Lerp(hand, a)
		g.blade = g.blade:Lerp(blade, a).Unit
		g.yaw += (yaw - g.yaw) * a
		g.high = high
	end
end

-- the guard as a world segment, or nil when it is down (or `from`, the swinger, is too far round to be covered:
-- past Config.Combat.GuardCover degrees off the guarding body's facing)
local function guardSegment(model, from)
	local g = guards[model]
	local root = g and model:FindFirstChild("HumanoidRootPart")
	if not root or not st(model).block then
		return nil
	end
	if from then
		local to = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
		local look = root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if to.Magnitude > 0.1 and look.Magnitude > 0.1 and to.Unit:Dot(look.Unit) < math.cos(math.rad(C.GuardCover)) then
			return nil
		end
	end
	return Swings.GuardSegment(root.CFrame, g.hand, g.blade, Swings.ScaleOf(model), g.length, g.armed, g.yaw)
end
Combat.GuardSegment = guardSegment

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
local ARC_STEPS, ALONG = 6, 8
-- Where a blade swept this frame first comes within `radius` of segment a-b. `bladeAt(f)` gives the blade (base,
-- tip) at fraction f of this frame (0 = last frame, 1 = now), following the real arc rather than a straight chord.
-- Returns the point on the blade, the way it was moving there, when (the time step it touched; ARC_STEPS + 1 =
-- only found by the coarse sweep) and how far along the blade from the hand (0..1). The guard and the body are
-- told apart by these: whichever the blade reached first in time, or nearer its hand in the same step.
local function bladeContact(bladeAt, prevBase, prevTip, base, tip, a, b, radius)
	local lastB, lastT
	for j = 0, ARC_STEPS do
		local bb, bt = bladeAt(j / ARC_STEPS)
		for i = 0, ALONG do
			local k = i / ALONG
			local p = bb:Lerp(bt, k)
			if Swings.SegmentDistance(p, p, a, b) <= radius then
				local move = if lastB then p - lastB:Lerp(lastT, k) else Vector3.zero
				return p, (if move.Magnitude > 0.01 then move.Unit else (bt - bb).Unit), j, k
			end
		end
		lastB, lastT = bb, bt
	end
	-- a fast blade can pass clean through between steps: sweep each point along it from last frame to now
	for i = 0, ALONG do
		local k = i / ALONG
		local p0, p1 = prevBase:Lerp(prevTip, k), base:Lerp(tip, k)
		local dist, onBlade = Swings.SegmentDistance(p0, p1, a, b)
		if dist <= radius then
			return onBlade, (if (p1 - p0).Magnitude > 0.01 then (p1 - p0).Unit else (tip - base).Unit), ARC_STEPS + 1, k
		end
	end
	return nil
end

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
	local prevU = 0
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
		local uFrom, fromBase, fromTip, rootCF = prevU, prevBase, prevTip, root.CFrame
		local function bladeAt(f)
			if f <= 0 then
				return fromBase, fromTip
			end
			return Swings.Blade(rootCF, id, uFrom + (u - uFrom) * f, reach, scale)
		end
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
				local hitAt, hitDir, when, along = bladeContact(bladeAt, prevBase, prevTip, base, tip, axisA, axisB, cap.radius)
				-- a raised guard in the blade's way takes it if the blade gets there first
				local guarded = false
				local ga, gb = guardSegment(model, root.Position)
				if ga then
					local gAt, gDir, gWhen, gAlong = bladeContact(bladeAt, prevBase, prevTip, base, tip, ga, gb, C.GuardRadius)
					if gAt and (not hitAt or gWhen < when or (gWhen == when and gAlong <= along)) then
						hitAt, hitDir, guarded = gAt, gDir, true
					end
				end
				if hitAt then
					local result = strike(model, { Point = hitAt, Dir = hitDir, Guarded = guarded })
					if guarded and (result == "blocked" or result == "parried") then
						-- the blade stops on the guard: the rest of the arc is gone (a parry also stunned the swinger)
						local keep = s.busyUntil
						cancelSwing(char, C.BlockRecoil)
						s.busyUntil = math.max(keep, s.busyUntil)
						return
					end
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
		prevBase, prevTip, prevU = base, tip, u
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
	if spec.Ranged then
		mods.shape = nil -- a shot has no blade arc to trace or to pose the arm along
	end
	if not spec.Ranged then
		-- a shot is not a swing: the client draws it from "Bolt" when the round leaves (Andy, 2026-11-12: the pistol
		-- "operated like a melee weapon" because every client played the swing for it)
		fx("Swing", char, mods.label, mods.shape, spec.Windup, spec.Active, spec.End, spec.Range)
	end
	if mods.shape then
		-- a guard can see it coming (guardThreat) from the first frame of the windup
		local scale = Swings.ScaleOf(char)
		swingers[char] = { id = mods.shape, t0 = t0, windup = spec.Windup, active = spec.Active, reach = spec.Range * scale, scale = scale, token = token, s = s }
	end

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
	-- ...and so do a guard held by the neck and a body on the shoulder (server/Stealth)
	return class == "Medium" or class == "Heavy" or char:GetAttribute("NeckHold") == true or char:GetAttribute("Carrying") == true
end

-- Cell-fed weapons spend ammo per shot; returns false (and tells the player) when dry.
-- Magazines (owner, 2026-11-11: "the modern gunplay of MGSV"): a weapon with MagSize fires from its magazine and
-- R changes it (Combat.Reload). The rounds in the magazine are still the pack's rounds (the count is the truth:
-- a shot takes one from both), so nothing about the inventory changes; the character's `Mag` attribute is what
-- the screen shows, and spare = pack count - Mag.
local mags = setmetatable({}, { __mode = "k" }) -- player -> { [weapon name] = rounds in the magazine }
-- Single-action guns (owner, 2026-11-12: "you need to rack it every round"): player -> { [weapon name] = true }
-- while the chamber is empty after a shot. Combat.Rack (T) or a magazine change chambers the next round.
local unracked = setmetatable({}, { __mode = "k" })
-- Round 3 (guns and ammo, docs/Reference-Picks-Plan.md): what is in each gun and how it is doing.
--   loaded[player][weapon] = the cartridge item in the magazine (a load inside the calibre: Weapons.Loads)
--   spares[player][weapon] = loaded spare magazines (Config.Guns.Spares + the rig's pouches); with none, R thumbs
--     rounds in by hand; R on a full magazine loads a spare by hand
--   heat[player][weapon] = { v, t }: the barrel (Config.Guns.Heat)
--   char attributes: Jam (Feed | Stovepipe | DoubleFeed), Heat, ArmFatigue, MagSpares, Load (the load's name)
local loaded = setmetatable({}, { __mode = "k" })
local spares = setmetatable({}, { __mode = "k" })
local heat = setmetatable({}, { __mode = "k" })
local function bucket(t, player)
	local mine = t[player]
	if not mine then
		mine = {}
		t[player] = mine
	end
	return mine
end
-- the load the next magazine takes: the one chosen for the calibre (Use a cartridge in the pack), else the
-- standard one, else any load of the calibre in the pack
local function wantLoad(player, weapon)
	local Inventory = require(script.Parent.Inventory)
	if not weapon.Caliber then
		return weapon.Ammo
	end
	local data = PlayerData.Get(player)
	local chosen = data and type(data.Load) == "table" and data.Load[weapon.Caliber]
	if type(chosen) == "string" and Inventory.Count(player, chosen) > 0 then
		return chosen
	end
	for _, id in Weapons.LoadsOf(weapon.Caliber) do
		if Inventory.Count(player, id) > 0 then
			return id
		end
	end
	return weapon.Ammo
end
local function ammoOf(player, weapon)
	local Inventory = require(script.Parent.Inventory)
	local mine = bucket(loaded, player)
	local id = mine[weapon.Name]
	if not id or Inventory.Count(player, id) <= 0 then
		id = wantLoad(player, weapon)
		mine[weapon.Name] = id
	end
	return id
end
Combat.AmmoOf = ammoOf
local function spareMax(player)
	local char = player.Character
	return G.Spares + (char and char:GetAttribute("KitMags") or 0)
end
local function magOf(player, weapon)
	local Inventory = require(script.Parent.Inventory)
	local have = Inventory.Count(player, ammoOf(player, weapon))
	local mine = bucket(mags, player)
	local m = mine[weapon.Name]
	m = math.min(if m == nil then weapon.MagSize else m, have, weapon.MagSize)
	mine[weapon.Name] = m
	-- loaded spares are rounds in the pack too: never more of them than the rounds behind the magazine fill
	local sp = bucket(spares, player)
	local n = sp[weapon.Name]
	sp[weapon.Name] = math.clamp(if n == nil then spareMax(player) else n, 0, math.min(spareMax(player), math.floor((have - m) / weapon.MagSize)))
	return m, have
end
local function heatOf(player, weapon)
	local h = bucket(heat, player)[weapon.Name]
	if not h then
		return 0
	end
	return math.max(0, h.v - (os.clock() - h.t) * G.Heat.Cool)
end
Combat.HeatOf = heatOf
function Combat.SetHeat(player, weapon, v) -- tests
	bucket(heat, player)[weapon.Name] = { v = v, t = os.clock(), locked = v >= 1 or nil }
end
function Combat.SyncMag(player)
	local char, weapon = player.Character, weaponOf(player)
	if not char then
		return
	end
	if weapon and weapon.MagSize and weapon.Ammo then
		local m = magOf(player, weapon)
		char:SetAttribute("Mag", m)
		char:SetAttribute("MagSize", weapon.MagSize)
		char:SetAttribute("MagSpares", spares[player][weapon.Name])
		local round = Weapons.Round(ammoOf(player, weapon))
		char:SetAttribute("AmmoItem", ammoOf(player, weapon))
		char:SetAttribute("Load", round and round.ItemId ~= (Weapons.Calibers[round.Caliber] or {}).Item and round.Name or nil)
		char:SetAttribute("Heat", math.floor(heatOf(player, weapon) * 100 + 0.5) / 100)
		-- a hand-racked gun shows whether a round is chambered (false = rack it: T)
		char:SetAttribute("Chambered", if weapon.Action == "Single" then not (unracked[player] and unracked[player][weapon.Name]) else nil)
		return m
	end
	for _, name in { "Mag", "MagSize", "MagSpares", "Load", "AmmoItem", "Heat", "Chambered", "Jam" } do
		char:SetAttribute(name, nil)
	end
	return nil
end
-- Every magazine full again (a fresh kit).
function Combat.ResetMags(player)
	mags[player] = nil
	unracked[player] = nil
	spares[player] = nil
	heat[player] = nil
	if player.Character then
		player.Character:SetAttribute("Jam", nil)
	end
	Combat.SyncMag(player)
end
-- A jam (round 3): the gun stops until it is cleared. Feed and Stovepipe clear with T; a double feed needs the
-- magazine out (R).
function Combat.Jam(player, kind)
	local char = player.Character
	if char then
		char:SetAttribute("Jam", kind)
		fx("Jam", char, kind)
	end
end
local function rollJam(player, weapon)
	local h = heatOf(player, weapon)
	local data = PlayerData.Get(player)
	local cond = data and data.Condition and data.Condition[data.Equipped]
	local wear = if type(cond) == "number" then 1 - math.clamp(cond / 100, 0, 1) else 0
	if math.random() >= G.Jam.Base + G.Jam.Heat * h * h + 0.03 * wear then
		return nil
	end
	local total = 0
	for _, w in G.Jam.Kinds do
		total += w
	end
	local at = math.random() * total
	for _, kind in { "Feed", "Stovepipe", "DoubleFeed" } do
		at -= G.Jam.Kinds[kind]
		if at <= 0 then
			return kind
		end
	end
	return "Feed"
end
Combat.RollJam = rollJam
function Combat.Reload(player)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and weapon.MagSize and weapon.Ammo) or handsFull(char) then
		return false
	end
	local s = st(char)
	local Inventory = require(script.Parent.Inventory)
	local m, have = magOf(player, weapon)
	local want = wantLoad(player, weapon)
	local swapLoad = want ~= ammoOf(player, weapon) and Inventory.Count(player, want) > 0
	local jam = char:GetAttribute("Jam")
	local sp = spares[player]
	if s.reloading or s.racking or not Combat.CanAct(char) then
		return false
	end
	local full = m >= math.min(weapon.MagSize, have)
	local seconds, kind
	if full and not swapLoad and jam ~= "DoubleFeed" then
		-- the magazine is full: thumb rounds into a spare instead (if there are rounds for one)
		if sp[weapon.Name] >= spareMax(player) or have - m - sp[weapon.Name] * weapon.MagSize < weapon.MagSize then
			return false
		end
		kind = "Spare"
		seconds = G.PerRound * weapon.MagSize
	elseif sp[weapon.Name] > 0 and not swapLoad then
		kind = "Swap" -- a loaded spare from the pouch
		seconds = (weapon.ReloadSeconds or 1.5) * (if (char:GetAttribute("KitMags") or 0) > 0 then Config.Kit.MagReload else 1)
	else
		kind = "Hand" -- nothing loaded ahead (or another load): the rounds go in one by one
		local count = math.min(weapon.MagSize, Inventory.Count(player, if swapLoad then want else ammoOf(player, weapon)))
		seconds = (weapon.ReloadSeconds or 1.5) * G.HandBase + G.PerRound * count
	end
	if jam == "DoubleFeed" then
		seconds += G.Jam.Clear.DoubleFeed
	end
	s.reloading = true
	s.queued = nil
	char:SetAttribute("Reloading", true)
	Combat.SetBusy(char, seconds)
	fx("Reload", char, seconds, kind)
	task.delay(seconds, function()
		s.reloading = nil
		if not char.Parent then
			return
		end
		char:SetAttribute("Reloading", nil)
		if isAlive(char) and weaponOf(player) == weapon then
			if kind == "Spare" then
				spares[player][weapon.Name] += 1
			else
				if kind == "Swap" then
					spares[player][weapon.Name] -= 1
				end
				if swapLoad then
					loaded[player][weapon.Name] = want
				end
				mags[player][weapon.Name] = math.min(weapon.MagSize, Inventory.Count(player, ammoOf(player, weapon)))
				if unracked[player] then
					unracked[player][weapon.Name] = nil -- the change ends with the slide run forward on a round
				end
				char:SetAttribute("Jam", nil) -- the magazine out clears any jam
			end
		end
		Combat.SyncMag(player)
	end)
	return true
end
-- T: work the slide by hand. A Single-action gun with an empty chamber needs it every round; any gun with a feed
-- jam or a stovepipe is cleared by it.
function Combat.Rack(player)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and weapon.MagSize and weapon.Ammo) or handsFull(char) then
		return false
	end
	local s = st(char)
	local jam = char:GetAttribute("Jam")
	if s.reloading or s.racking or not Combat.CanAct(char) then
		return false
	end
	if jam == "DoubleFeed" then
		Remotes.Announce:FireClient(player, "> DOUBLE FEED . . . MAGAZINE OUT (R)", "Info")
		return false
	end
	local needs = weapon.Action == "Single" and unracked[player] and unracked[player][weapon.Name]
	if not jam and not (needs and magOf(player, weapon) > 0) then
		return false
	end
	local seconds = if jam then G.Jam.Clear[jam] or 0.8 else weapon.RackSeconds or 0.5
	s.racking = true
	s.queued = nil
	Combat.SetBusy(char, seconds)
	fx("Rack", char, seconds, jam)
	task.delay(seconds, function()
		s.racking = nil
		if char.Parent and isAlive(char) and weaponOf(player) == weapon then
			char:SetAttribute("Jam", nil)
			if unracked[player] and (needs or weapon.Action == "Single") and magOf(player, weapon) > 0 then
				unracked[player][weapon.Name] = nil
			end
		end
		if char.Parent then
			Combat.SyncMag(player)
		end
	end)
	return true
end

-- Use a cartridge from the pack: that load goes in next (the magazine changes now if the gun in hand takes it).
function Combat.SelectLoad(player, itemId)
	local round = Weapons.Round(itemId)
	local data = PlayerData.Get(player)
	if not (round and data) then
		return false
	end
	data.Load = if type(data.Load) == "table" then data.Load else {}
	data.Load[round.Caliber] = itemId
	Remotes.Announce:FireClient(player, "> LOAD . . . " .. string.upper(round.Name), "Info")
	local weapon = weaponOf(player)
	if weapon and weapon.Caliber == round.Caliber and weapon.MagSize then
		Combat.Reload(player)
	end
	return true
end

local function spendAmmo(player, weapon)
	if not weapon.Ammo then
		return true
	end
	local Inventory = require(script.Parent.Inventory)
	local char = player.Character
	if weapon.MagSize then
		local m, have = magOf(player, weapon)
		if char and char:GetAttribute("Jam") then
			fx("DryFire", char) -- jammed: nothing moves until it is cleared (T, or R for a double feed)
			return false
		end
		if m <= 0 then
			-- an empty magazine changes itself when there is another; with none the gun only clicks
			if have > 0 then
				Combat.Reload(player)
			else
				Remotes.Announce:FireClient(player, "> " .. string.upper(weapon.Name) .. " . . . EMPTY", "Info")
			end
			if char then
				fx("DryFire", char)
			end
			return false
		end
		if weapon.Action == "Single" and unracked[player] and unracked[player][weapon.Name] then
			if char then
				fx("DryFire", char) -- nothing in the chamber: the hammer falls on air until it is racked
			end
			return false
		end
		local h = heatOf(player, weapon)
		local hrec = heat[player] and heat[player][weapon.Name]
		if hrec and hrec.locked and h <= G.Heat.Hot then
			hrec.locked = nil
		end
		if h >= 1 or (hrec and hrec.locked) then
			-- cooked: it will not fire again until it has cooled under Hot
			if hrec then
				hrec.locked = true
			end
			Remotes.Announce:FireClient(player, "> " .. string.upper(weapon.Name) .. " . . . TOO HOT", "Info")
			return false
		end
		local id = ammoOf(player, weapon)
		if not Inventory.Remove(player, id, 1) then
			return false
		end
		mags[player][weapon.Name] = m - 1
		local add = if weapon.Action == "Auto" then G.Heat.Auto elseif weapon.Family == "Rifle" then G.Heat.Rifle else G.Heat.Pistol
		heat[player][weapon.Name] = { v = math.min(1, h + add), t = os.clock(), locked = h + add >= 1 or nil }
		if weapon.Action == "Single" then
			unracked[player] = unracked[player] or {}
			unracked[player][weapon.Name] = true
		end
		local jam = rollJam(player, weapon)
		if jam then
			Combat.Jam(player, jam) -- the round is lost, the action is fouled
			Combat.SyncMag(player)
			return false
		end
		if char then
			st(char).round = Weapons.Round(id)
		end
		Combat.SyncMag(player)
		return true
	end
	if Inventory.Count(player, weapon.Ammo) <= 0 then
		Remotes.Announce:FireClient(player, "> " .. string.upper(weapon.Name) .. " . . . EMPTY", "Info")
		return false
	end
	return Inventory.Remove(player, weapon.Ammo, 1)
end

-- Tired arms (round 3): every Config.Guns tick, aiming a gun tires the arms by its weight, rest brings them back.
local tiredness = setmetatable({}, { __mode = "k" }) -- player -> 0..1 (the attribute is rounded)
local function fatigueTick(dt)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char then
			local f = tiredness[player] or 0
			local weapon = weaponOf(player)
			if char:GetAttribute("Aiming") and weapon and Weapons.IsGun(weapon) then
				local weight = weapon.Weight or G.Fatigue.Weight[weapon.Family] or 1
				f = math.min(1, f + dt * G.Fatigue.Rate * weight)
			else
				f = math.max(0, f - dt * G.Fatigue.Recover)
			end
			tiredness[player] = f
			local shown = math.floor(f * 100 + 0.5) / 100
			if shown ~= (char:GetAttribute("ArmFatigue") or 0) then
				char:SetAttribute("ArmFatigue", if shown > 0 then shown else nil)
			end
			if weapon and weapon.MagSize and char:GetAttribute("Heat") and char:GetAttribute("Heat") > 0 then
				local h = math.floor(heatOf(player, weapon) * 100 + 0.5) / 100
				char:SetAttribute("Heat", h)
			end
		end
	end
end
Combat.FatigueTick = fatigueTick

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

-- Where a shot may go: the client's camera direction, accepted only within a cone of the body's facing.
local function setAim(char, aim)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local s = char and st(char)
	if not (root and s) then
		return
	end
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
		aim = aim.Unit
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if math.abs(aim.Y) < 0.94 and flat.Magnitude > 0.05 and root.CFrame.LookVector:Dot(flat.Unit) > 0.5 then
			s.aim, s.aimAt = aim, os.clock()
			return
		end
		s.aim = nil
	end
end

-- A move made from a weapon's chain step: the step's own frames, scaled (Config.Kit: Delay, Roll, Lunge, Rising).
local function variant(spec, damage, reach, stamina, posture)
	local v = table.clone(spec)
	v.Damage = spec.Damage * damage
	v.Range = (spec.Range or 6) + (reach or 0)
	v.Stamina = (spec.Stamina or 0) * (stamina or 1)
	if posture and v.Posture then
		v.Posture = spec.Posture * posture
	end
	return v
end

function Combat.Attack(player, aim, intent)
	local char = player.Character
	setAim(char, aim)
	local weapon, improvised = weaponOf(player)
	if not (char and weapon) or handsFull(char) then
		return
	end
	if not Combat.CanAct(char) then
		enqueue(player, char, function(p)
			Combat.Attack(p, nil, intent)
		end)
		return
	end
	st(char).queued = nil
	local s, t = st(char), os.clock()
	local KD = Config.Kit.Delay
	local same = s.comboWeapon == weapon
	local swapped = (s.swappedAt or 0) >= (s.lastSwingAt or 0) and (s.lastSwingAt or 0) > 0
	local cont = (same or swapped) and t <= math.max(s.comboExpires, s.busyUntil + KD.After + KD.Window)
	local combo = if cont then s.combo % #weapon.Attacks + 1 else 1
	local spec = weapon.Attacks[combo]
	local melee = not spec.Ranged
	local label, shape, launches = combo, Swings.ShapeFor(weapon.Family, combo, false), false
	local idle = t - s.busyUntil
	if melee and (intent == "Forward" or intent == "Back") then
		-- locked on (client/Style): forward lunges in, back cuts upward and lifts an open body
		if intent == "Forward" then
			local L = Config.Kit.Lunge
			spec, label, shape = variant(weapon.Attacks[1], L.Damage, L.Reach, L.Stamina), "Lunge", "Thrust"
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				Remotes.CombatEvent:FireClient(player, "Lunge", root.CFrame.LookVector * L.Speed, L.Seconds)
			end
		else
			local R = Config.Kit.Rising
			spec, label, shape, launches = variant(weapon.Attacks[1], R.Damage, 0, R.Stamina), "Rising", "Uppercut", true
		end
		combo = 1
	elseif melee and t - s.lastDodge <= Config.Kit.Roll.Window and s.lastDodge > 0 then
		-- out of a roll: a thrust that carries the roll's reach
		local R = Config.Kit.Roll
		spec, label, shape = variant(spec, R.Damage, R.Reach), "Roll", "Thrust"
	elseif melee and same and cont and combo >= 2 and idle >= KD.After and idle <= KD.After + KD.Window then
		-- a held beat before the next press: the chain branches into a heavier blow
		spec, label = variant(spec, KD.Damage, 0, 1, KD.Posture), "Delay"
	end
	if not Combat.SpendStamina(char, spec.Stamina) or not spendAmmo(player, weapon) then
		return
	end
	s.block = false
	char:SetAttribute("Blocking", false)
	s.combo, s.comboWeapon, s.lastSwingAt = combo, weapon, t
	if label ~= combo then
		Combat.Used:Fire(label, player)
	end
	if launches then
		holdForLauncher(char, spec, t)
	end
	local mods = { chargeBonus = weapon.ChargeBonus, label = label, weapon = weapon, improvised = improvised, shape = shape, launches = launches, startedAt = t }
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

function Combat.Heavy(player, aim)
	local char, weapon = player.Character, weaponOf(player)
	setAim(char, aim)
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
			Combat.SetSprint(player, false)
			Combat.Guard(char, true)
		end
	else
		Combat.Guard(char, false)
	end
end

-- Raises or drops a body's guard (players through SetBlock; any rig may use it directly).
function Combat.Guard(char, down)
	local s = st(char)
	if down then
		if s.block then
			return
		end
		local t = os.clock()
		s.block = true
		raiseGuard(char)
		-- Tapping block repeatedly must not re-arm the parry window every press.
		s.blockStart = if t - s.lastBlockRelease >= C.ParryRearm then t else -10
		char:SetAttribute("Blocking", true)
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
	-- armour: anything but a forward roll is a heavy step with fewer i-frames (client/Movement, Config.Movement.Step)
	local weight = (char:GetAttribute("GearWeight") or 0) + (if char:GetAttribute("Overweight") then 2 else 0)
	local forward = look and look.Magnitude > 0 and direction.Unit:Dot(look.Unit) > Config.Movement.ForwardDot
	local stepMult = 1
	if weight > 0 and not forward then
		local S = Config.Movement.Step
		stepMult = math.max(S.MinIFrameMult, 1 - S.IFrameLossPerWeight * weight)
	end
	s.lastDodge, s.iframes, s.block = t, t + Gear.Get(player).DodgeIFrames * (if side then Config.Momentum.SideIFrameMult else 1) * stepMult, false
	s.busyUntil = t + 0.2
	char:SetAttribute("Blocking", false)
	-- Enemy Step: a dodge next to a Juggled enemy springs off it - stamina back and a hop
	local velocity = direction.Unit * C.DodgeSpeed
	local step = root and Combat.NearestJuggled(root.Position, Config.Momentum.EnemyStepRange)
	local hover = 0
	if step then
		-- spring up to its height, landing StepFront in front of it, and keep it up a little longer
		local M = Config.Momentum
		Combat.AddStamina(char, M.EnemyStepRefund)
		local eroot = step:FindFirstChild("HumanoidRootPart")
		local toMe = Vector3.new(root.Position.X - eroot.Position.X, 0, root.Position.Z - eroot.Position.Z)
		local spot = eroot.Position + (if toMe.Magnitude > 0.1 then toMe.Unit else -eroot.CFrame.LookVector) * M.StepFront
		local g = math.max(workspace.Gravity, 1)
		local rise = math.clamp(spot.Y - root.Position.Y + 1, 2, M.StepMaxRise)
		local vy = math.max(M.EnemyStepHop, math.sqrt(2 * g * rise))
		local tUp = vy / g
		local flat = Vector3.new(spot.X - root.Position.X, 0, spot.Z - root.Position.Z)
		velocity = flat / math.max(tUp, 0.15) + Vector3.new(0, vy, 0)
		local es = st(step)
		es.juggledUntil = math.max(es.juggledUntil or t, t) + M.StepExtend
		Combat.Stun(step, (es.juggledUntil - t) + M.LandStun)
		hover = M.StepHover
		fx("EnemyStep", char, step)
	end
	Remotes.CombatEvent:FireClient(player, "DodgeMove", velocity, hover, step)
	fx("Dodge", char)
end

function Combat.Init()
	Net.On("Attack", { rate = 8, burst = 12, args = { "vector?", "string?" } }, function(player, aim, intent)
		Combat.Attack(player, aim, if intent == "Forward" or intent == "Back" then intent else nil)
	end)
	Net.On("Heavy", { rate = 4, burst = 6, args = { "vector?" } }, Combat.Heavy)
	Net.On("Reload", { rate = 2, burst = 3 }, Combat.Reload)
	Net.On("Rack", { rate = 4, burst = 5 }, Combat.Rack)
	Net.On("Feint", { rate = 6, burst = 8 }, Combat.Feint)
	Net.On("Flicker", { rate = 8, burst = 12 }, Combat.Flicker)
	Net.On("Block", { rate = 4, burst = 8, args = { "boolean" } }, Combat.SetBlock)
	Net.On("Sprint", { rate = 4, burst = 8, args = { "boolean" } }, Combat.SetSprint)
	Net.On("Dodge", { rate = 4, burst = 6, args = { "vector" } }, Combat.Dodge)

	RunService.Heartbeat:Connect(followGuards)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		local t = os.clock()
		fatigueTick(step)
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
					local hunger = char:GetAttribute("Hunger")
					local fed = if type(hunger) == "number" and hunger < Config.Wounds.Hunger.Low then Config.Wounds.Hunger.StaminaRegenLow else 1
					Combat.AddStamina(char, C.StaminaRegenPerSecond * step * fed)
				end
				if (char:GetAttribute("Posture") or 0) > 0 and t - s.lastPostureHit > C.PostureRegenDelay then
					Combat.AddPosture(char, -d.PostureRegen * step)
				end
			end
		end
	end)
end

Combat.Tag = tag -- server/Knock credits a finisher

return Combat
