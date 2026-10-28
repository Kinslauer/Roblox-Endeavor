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
local District = require(Shared.District)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Attachments = require(Shared.Attachments)
local Gear = require(script.Parent.Gear)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)
local WorldPhase = require(script.Parent.WorldPhase)

local C, F, L = Config.Combat, Config.Flicker, Config.RateLimit
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
			ammo = {}, reloadUntil = 0, ads = false, adsSince = 0, -- gunplay (Config.Gunplay)
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

-- Fresh characters in the open world get a ForceField; any offensive action forfeits it.
function Combat.Protect(char, seconds)
	Combat.ClearProtection(char)
	local ff = Instance.new("ForceField")
	ff.Name = "SpawnProtection"
	ff.Visible = true
	ff.Parent = char
	task.delay(seconds, function()
		if ff.Parent then
			ff:Destroy()
		end
	end)
end

function Combat.ClearProtection(char)
	local ff = char and char:FindFirstChild("SpawnProtection")
	if ff then
		ff:Destroy()
	end
end

function Combat.CanAct(char)
	local s = st(char)
	local t = os.clock()
	return isAlive(char) and t >= s.stunned and t >= s.busyUntil - BUFFER
end

-- Open for a grab finisher: stunned right now, or posture-broken within GrabStunWindow.
function Combat.IsOpen(char)
	local s, t = st(char), os.clock()
	return t < s.stunned or (s.brokenAt ~= nil and t - s.brokenAt < Config.Momentum.GrabStunWindow)
end

-- ===== Gunplay (Config.Gunplay, design/gdd/gunplay.md) =====
local G = Config.Gunplay

-- A character's weapon definition by id, with the bench build folded in for players
-- (shared/Attachments.lua; the build lives in profile.Builds). NPCs use the plain definition.
local function weaponDefOf(char, id)
	local def = id and Weapons.Defs[id]
	if not def then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(char)
	local data = player and PlayerData.Get(player)
	return Attachments.Apply(def, data and data.Builds and data.Builds[id])
end
Combat.WeaponDefOf = weaponDefOf

-- The equipped weapon's Gun block (with defaults), or nil for melee / fists.
local function gunOf(weapon)
	if not Weapons.IsGun(weapon) then
		return nil
	end
	return setmetatable(table.clone(weapon.Gun or {}), { __index = G.DefaultGun })
end

-- Rounds left in the equipped gun's magazine (a fresh gun starts full). Mirrors to the Ammo /
-- MaxAmmo attributes the HUD reads.
local function syncAmmo(char, s, weaponId, gun)
	if not gun then
		char:SetAttribute("Ammo", nil)
		char:SetAttribute("MaxAmmo", nil)
		return nil
	end
	if s.ammo[weaponId] == nil then
		s.ammo[weaponId] = gun.Magazine
	end
	s.ammo[weaponId] = math.min(s.ammo[weaponId], gun.Magazine) -- a smaller magazine fitted at the bench
	char:SetAttribute("Ammo", s.ammo[weaponId])
	char:SetAttribute("MaxAmmo", gun.Magazine)
	local owner = Players:GetPlayerFromCharacter(char)
	if owner then
		char:SetAttribute("Cells", Combat.Cells(owner))
	end
	return s.ammo[weaponId]
end

function Combat.SyncAmmo(char, weapon)
	local id = char:GetAttribute("Weapon")
	weapon = weapon or weaponDefOf(char, id)
	return syncAmmo(char, st(char), id, weapon and gunOf(weapon))
end

-- Reload the equipped gun: busy for Gun.Reload seconds, then the magazine is full. A stun cancels it.
-- Arc Cells carried (Config.Gunplay.CellItem), and spending them (false when short). The Cells attribute on
-- the character feeds the HUD's ammo line.
function Combat.Cells(player)
	local data = PlayerData.Get(player)
	return data and data.Inventory and data.Inventory[G.CellItem] or 0
end

function Combat.SpendCells(player, n)
	local data = PlayerData.Get(player)
	local have = Combat.Cells(player)
	if not data or have < n then
		return false
	end
	data.Inventory[G.CellItem] = if have - n > 0 then have - n else nil
	if player.Character then
		player.Character:SetAttribute("Cells", have - n)
	end
	Remotes.InventoryChanged:FireClient(player, data.Inventory, data.Equipped, data.Armor, data.Cyber)
	return true
end

function Combat.Reload(player)
	local char = player.Character
	local id = char and char:GetAttribute("Weapon")
	local weapon = char and weaponDefOf(char, id)
	local gun = weapon and gunOf(weapon)
	if not (gun and isAlive(char)) then
		return false
	end
	local s, t = st(char), os.clock()
	local ammo = syncAmmo(char, s, id, gun)
	if t < s.reloadUntil or ammo >= gun.Magazine or t < s.stunned then
		return false
	end
	if Combat.Cells(player) < G.CellsPerReload then
		if t >= (s.noCellsSaidAt or 0) + 2 then
			s.noCellsSaidAt = t
			Remotes.Announce:FireClient(player, "No cells.", "Event")
		end
		return false
	end
	s.reloadUntil = t + gun.Reload
	s.busyUntil = math.max(s.busyUntil, s.reloadUntil)
	local token = s.token
	char:SetAttribute("Reloading", true)
	fx("Reload", char, gun.Reload)
	task.delay(gun.Reload, function()
		char:SetAttribute("Reloading", false)
		if s.token == token and isAlive(char) and char:GetAttribute("Weapon") == id and Combat.SpendCells(player, G.CellsPerReload) then
			s.ammo[id] = gun.Magazine
			syncAmmo(char, s, id, gun)
		else
			s.reloadUntil = 0 -- interrupted: try again
		end
	end)
	return true
end

-- Sights up/down. ADS is a claimed state like block: it only counts for spread after ADSSettle
-- seconds, never while sprinting, and is visible to everyone as the ADS attribute.
function Combat.SetADS(player, on)
	local char = player.Character
	if not char or type(on) ~= "boolean" then
		return
	end
	local s = st(char)
	if on and s.sprint then
		s.sprint = false
		char:SetAttribute("Sprinting", false)
	end
	if on ~= s.ads then
		s.ads, s.adsSince = on, os.clock()
		char:SetAttribute("ADS", on)
	end
end

-- Spread for a shot right now (degrees of cone half-angle), from the gun and the shooter's state.
local function spreadFor(char, s, gun, t)
	local hum = getHum(char)
	local ads = s.ads and t - s.adsSince >= G.Spread.ADSSettle * (gun.SettleMult or 1) -- optics change how fast the sights settle
	local spread = if ads then gun.Spread.ADS else gun.Spread.Hip
	if char:GetAttribute("Sprinting") then
		spread += G.Spread.Sprinting
	elseif hum and hum.MoveDirection and hum.MoveDirection.Magnitude > 0.1 then
		spread += G.Spread.Moving
	end
	if hum and hum.FloorMaterial == Enum.Material.Air then
		spread += G.Spread.Airborne
	end
	return spread, ads
end

local spreadRng = Random.new()
local function scatter(look, degrees)
	if degrees <= 0 then
		return look
	end
	local angle = math.rad(spreadRng:NextNumber(0, degrees))
	local roll = spreadRng:NextNumber(0, math.pi * 2)
	return (CFrame.lookAt(Vector3.zero, look) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Take one shot's worth of ammo for a gun attack; false (and an automatic reload) when empty.
local function spendAmmo(player, char, s, id, gun, rounds)
	local t = os.clock()
	if t < s.reloadUntil then
		return false
	end
	local ammo = syncAmmo(char, s, id, gun)
	if ammo < rounds then
		Combat.Reload(player)
		return false
	end
	s.ammo[id] = ammo - rounds
	syncAmmo(char, s, id, gun)
	return true
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
-- Enemy poise (Enemies.Defs[x].Poise, replicated as PoiseHits / PoiseReset attributes): a light hit
-- interrupts only every Nth hit; heavies, guard breaks and flicked hits (opts.Staggers) always do.
-- Players have no poise attribute, so every hit staggers them as before.
local function poiseBroken(victim, vs, t, opts)
	local hits = victim:GetAttribute("PoiseHits")
	if not hits or hits <= 1 or opts.Staggers or opts.GuardBreak then
		return true
	end
	local reset = victim:GetAttribute("PoiseReset") or 2
	if t - (vs.poiseLast or 0) > reset then
		vs.poiseCount = 0
	end
	vs.poiseLast = t
	vs.poiseCount = (vs.poiseCount or 0) + 1
	if vs.poiseCount >= hits then
		vs.poiseCount = 0
		return true
	end
	return false
end

-- Which side a body fights for: players carry it on the Player, NPCs on the model. nil = nobody's.
function Combat.FactionOf(char)
	local player = Players:GetPlayerFromCharacter(char)
	return if player then player:GetAttribute("Faction") else char:GetAttribute("Faction")
end

-- The war installs this: (victim, attacker, amount) -> true when it handled a lethal hit itself.
Combat.LethalHook = nil

-- ===== Launcher + juggle (Config.Momentum, momentum.md 2.5) =====

function Combat.IsJuggled(char)
	local s = st(char)
	return os.clock() < (s.juggledUntil or 0)
end

-- Only non-player, non-flying bodies get launched (players own their physics and permadeath makes a
-- helpless state too strong in PvP; drones already fly; range targets are anchored).
local function launchable(victim)
	return Players:GetPlayerFromCharacter(victim) == nil and not victim:GetAttribute("Flying") and not victim:GetAttribute("Target") and not victim:GetAttribute("NoLaunch")
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
		fx("Land", victim)
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

local function applyDamage(attacker, victim, amount, opts)
	local vhum = getHum(victim)
	if not vhum or vhum.Health <= 0 or attacker == victim then
		return "none"
	end
	local ap, vp = Players:GetPlayerFromCharacter(attacker), Players:GetPlayerFromCharacter(victim)
	if ap and vp and not WorldPhase.IsOpen() then
		return "none" -- no PvP during the prologue (they should never meet anyway)
	end
	if victim:GetAttribute("DevGod") then
		return "none" -- Studio dev panel god mode (server/DevPanel.lua)
	end
	if victim:FindFirstChildOfClass("ForceField") then
		return "none" -- spawn protection (Config.SpawnProtectionSeconds); ends early when they attack
	end
	do -- safe zone (District 1 plaza): no damage in or out, for players and enemies alike
		local aroot, vroot = attacker:FindFirstChild("HumanoidRootPart"), victim:FindFirstChild("HumanoidRootPart")
		if (vroot and District.InSafeZone(vroot.Position)) or (aroot and District.InSafeZone(aroot.Position)) then
			fx("Safe", victim, attacker)
			return "none"
		end
	end
	do -- the war (Config.War): no friendly fire between recruits of the same side, players or AI.
		-- Only in the war zone: in the city, conduits owe each other nothing.
		local af, vf = Combat.FactionOf(attacker), Combat.FactionOf(victim)
		if af and vf and af == vf then
			local function atWar(char)
				local p = Players:GetPlayerFromCharacter(char)
				return if p then p:GetAttribute("Zone") == "Range" else char:GetAttribute("Faction") ~= nil
			end
			if atWar(attacker) or atWar(victim) then
				return "none"
			end
		end
	end

	local vs, t, vd = st(victim), os.clock(), Gear.OfChar(victim)
	if t < vs.iframes then
		if vs.dodgeIframes and t < vs.dodgeIframes then
			vs.dodgeIframes = nil -- one refund per dodge
			Combat.AddStamina(victim, Config.Momentum.HopRefund)
			if vs.comboWeapon and vs.combo > 0 then
				vs.comboExpires = t + vs.comboWeapon.ComboReset
			end
		end
		fx("Dodged", victim, attacker)
		return "dodged"
	end

	local aroot, vroot = attacker:FindFirstChild("HumanoidRootPart"), victim:FindFirstChild("HumanoidRootPart")
	local away = if aroot and vroot then Vector3.new(vroot.Position.X - aroot.Position.X, 0, vroot.Position.Z - aroot.Position.Z) else Vector3.zero
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zero
	-- read "open" and "airborne" before this hit's own stun lands
	local wasOpen = Combat.IsOpen(victim)
	local stunnedBefore = vs.stunned -- when the last stagger ended (this hit's own stun lands below)
	local juggled = t < (vs.juggledUntil or 0)
	if juggled then
		amount *= Config.Momentum.AirDamageMult -- helpless in the air
	end

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
			vs.brokenAt = t -- Buster reads this (Config.Momentum.GrabStunWindow)
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
	amount *= 1 - math.min(C.MaxResist, (vd.Resist[opts.Type or "Physical"] or 0) + (victim:GetAttribute("KitResist") or 0)) -- KitResist: a supplied recruit's armour (Config.Supply)

	-- a lethal hit on a deployed player goes through the war's hook (downed instead of dead)
	if amount >= vhum.Health and Combat.LethalHook and Combat.LethalHook(victim, attacker, amount) then
		tag(attacker, victim)
		fx("Hit", victim, { attacker = attacker, amount = amount })
		return "hit"
	end
	tag(attacker, victim) -- before the damage: Died may fire synchronously and the kill must already be credited
	vhum:TakeDamage(amount)

	if result ~= "blocked" and t >= math.max(vs.hyperarmorUntil, vs.swingArmorUntil) and poiseBroken(victim, vs, t, opts) then
		Combat.Stun(victim, opts.Stun or C.HitStunDefault)
		if opts.Knockback and opts.Knockback > 0 then
			knockback(victim, direction, opts.Knockback)
		end
	end
	if result ~= "blocked" and vhum.Health > 0 then
		if juggled then
			pop(victim, vs, t) -- keep it up there
		elseif opts.Launches and (wasOpen or t < stunnedBefore + Config.Momentum.LaunchGrace) and launchable(victim) then
			launch(attacker, victim, vs, t, direction) -- a heavy on an open enemy sends it up
		end
	end
	if result == "hit" and amount > 0.5 then
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
	if spec.Ranged and mods.aim then
		-- aimed shot: from eye height, along the (validated) camera direction
		local head = char:FindFirstChild("Head")
		origin, look = (head and head.Position or origin + Vector3.new(0, 1.5, 0)), mods.aim
	end

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
	local opts = { Posture = posture, Type = spec.Type, Knockback = spec.Knockback, Stun = spec.Stun, Unblockable = mods.unblockable, GuardBreak = mods.guardBreak,
		Staggers = mods.label == "Heavy", -- heavies always break enemy poise
		Launches = mods.label == "Heavy" and not spec.Ranged and not spec.NoLaunch } -- ...and launch an open enemy (Config.Momentum)

	-- zone: the body part a ranged shot landed on (Config.Gunplay.Zones multiplier; a headshot staggers)
	local function strike(model, zone)
		seen[model] = true
		if seen.__flick == nil then
			seen.__flick = judgeFlick(s, d) or false
		end
		local flick = seen.__flick
		local hitDamage, hitOpts = damage, opts
		if zone then
			hitDamage *= G.Zones[zone] or G.Zones.Default
			if zone == "Head" and G.HeadshotStaggers then
				hitOpts = table.clone(hitOpts)
				hitOpts.Staggers = true
			end
		end
		if flick then
			hitOpts = table.clone(hitOpts)
			hitOpts.Staggers = true -- a flicked hit always interrupts
			if flick.flash then
				hitDamage *= (F.BlackFlashMult + d.FlashBonus)
				hitOpts.Posture = (opts.Posture or 0) * F.BlackFlashPosture
				hitOpts.GuardBreak = true
				hitOpts.Stun = math.max(opts.Stun or 0, F.BlackFlashStun)
				hitOpts.Knockback = math.max(opts.Knockback or 0, F.BlackFlashKnockback)
			else
				hitDamage *= F.DamageMult[flick.level]
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
		return result
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	if spec.Ranged then
		if seen.__fired then
			return
		end
		seen.__fired = true
		if mods.gun then -- a player's gun: spread from the gun and the shooter's state (NPC shots are exact)
			local spread = spreadFor(char, s, mods.gun, os.clock())
			look = scatter(look, spread)
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { char }
		local result = workspace:Raycast(origin, look * spec.Range, ray)
		fx("Bolt", char, if result then result.Position else origin + look * spec.Range)
		local model = result and result.Instance:FindFirstAncestorOfClass("Model")
		if model and getHum(model) then
			local zone = result.Instance.Name
			local outcome = strike(model, zone)
			if zone == "Head" and (outcome == "hit" or outcome == "guardbreak") then
				fx("Headshot", model, char)
			end
		elseif model and model:GetAttribute("Kind") and Combat.PropHit then -- a prop (server/Destruction.lua)
			Combat.PropHit(char, model, damage, spec, Weapons.Defs[char:GetAttribute("Weapon") or ""], mods.label == "Heavy", result.Position)
		end
		return
	end

	for _, part in workspace:GetPartBoundsInRadius(origin, spec.Range, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and Combat.PropHit and model:GetAttribute("Kind") and not getHum(model) then
			-- a prop in the arc (server/Destruction.lua): once per swing, like a body
			local offset = part.Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 3.5 or look:Dot(flat.Unit) >= spec.Arc then
				seen[model] = true
				Combat.PropHit(char, model, damage, spec, Weapons.Defs[char:GetAttribute("Weapon") or ""], mods.label == "Heavy", part.Position)
			end
		elseif model and not seen[model] and getHum(model) then
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
	local def = data and (Weapons.Defs[data.Equipped] or Weapons.Defs.Fists)
	return def and Attachments.Apply(def, data.Builds and data.Builds[data.Equipped])
end

-- A ranged shot may carry the client's camera direction so it follows the camera's pitch (the
-- sight picture). It is only trusted inside Config.Combat.AimCone of the body's facing and
-- AimMaxPitch up/down; anything else falls back to the body's facing. Melee ignores it.
local function sanitizeAim(char, aim)
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	aim = aim.Unit
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.05 then
		return nil
	end
	local yaw = math.deg(math.acos(math.clamp(flat.Unit:Dot(root.CFrame.LookVector), -1, 1)))
	local pitch = math.deg(math.asin(math.clamp(aim.Y, -1, 1)))
	if yaw > C.AimCone or math.abs(pitch) > C.AimMaxPitch then
		return nil
	end
	return aim
end

function Combat.Attack(player, aim)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and Combat.CanAct(char)) then
		return
	end
	Combat.ClearProtection(char)
	local s, t = st(char), os.clock()
	local combo = if s.comboWeapon == weapon and t <= s.comboExpires then s.combo % #weapon.Attacks + 1 else 1
	local spec = weapon.Attacks[combo]
	if player:GetAttribute("Zone") == "Range" and not spec.Ranged then
		Remotes.Announce:FireClient(player, "Ranged weapons only in the Range.", "Event")
		return
	end
	local gun = gunOf(weapon)
	if gun and not spendAmmo(player, char, s, char:GetAttribute("Weapon"), gun, 1) then
		return -- empty or reloading (an empty click starts the reload)
	end
	if not Combat.SpendStamina(char, spec.Stamina) then
		return
	end
	s.block = false
	char:SetAttribute("Blocking", false)
	s.combo, s.comboWeapon = combo, weapon
	local mods = { chargeBonus = weapon.ChargeBonus, label = combo, aim = if spec.Ranged then sanitizeAim(char, aim) else nil, gun = gun }
	Combat.Swing(char, spec, mods)
	if combo == #weapon.Attacks then -- end of the chain: recovery
		s.busyUntil += weapon.ComboCooldown
	end
	s.comboExpires = s.busyUntil + weapon.ComboReset
end

function Combat.Heavy(player, aim)
	local char, weapon = player.Character, weaponOf(player)
	if not (char and weapon and Combat.CanAct(char)) then
		return
	end
	Combat.ClearProtection(char)
	local s, t = st(char), os.clock()
	if player:GetAttribute("Zone") == "Range" and not weapon.Heavy.Ranged then
		return
	end
	if t - s.lastHeavy < C.HeavyCooldown then
		return
	end
	local gun = gunOf(weapon)
	if gun and not spendAmmo(player, char, s, char:GetAttribute("Weapon"), gun, gun.HeavyRounds or 3) then
		return -- the charged shot burns three rounds
	end
	if not Combat.SpendStamina(char, weapon.Heavy.Stamina) then
		return
	end
	s.lastHeavy, s.block, s.combo = t, false, 0
	Combat.Used:Fire("Heavy", player)
	char:SetAttribute("Blocking", false)
	-- Heavies are criticals: they crush blocks (extra posture damage).
	local mods = { chargeBonus = weapon.ChargeBonus, label = "Heavy", postureMult = C.CriticalPostureMult, aim = if weapon.Heavy.Ranged then sanitizeAim(char, aim) else nil, gun = gun }
	Combat.Swing(char, weapon.Heavy, mods)
end

-- Sprint (Config.Sprint): a held intent. The regen loop applies the speed and drains stamina.
function Combat.SetSprint(player, on)
	local char = player.Character
	if not char or type(on) ~= "boolean" then
		return
	end
	local s = st(char)
	s.sprint = on and (char:GetAttribute("Stamina") or 0) > Config.Sprint.MinStamina
	char:SetAttribute("Sprinting", s.sprint)
	if s.sprint and s.ads then
		s.ads = false -- you cannot run with the sights up
		char:SetAttribute("ADS", false)
	end
end

local function applySpeed(char, s, d)
	local hum = getHum(char)
	if not hum or not d.WalkSpeed or not Players:GetPlayerFromCharacter(char) then
		return -- enemies drive their own speed (NPCs); only player bodies sprint
	end
	local want = d.WalkSpeed * (if s.sprint then Config.Sprint.Mult else 1)
	if math.abs(hum.WalkSpeed - want) > 0.01 then
		hum.WalkSpeed = want
	end
end

function Combat.SetBlock(player, down)
	local char = player.Character
	if not char or type(down) ~= "boolean" then
		return
	end
	local s = st(char)
	s.blockHeld = down -- a held intent: the regen loop raises the guard the moment you're free again
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
	-- momentum.md 2.1: a dodge is a cancel. Side dodges (Table Hopper) get longer i-frames; the combo
	-- survives the dodge; the recovery of a landed swing is cut short.
	local root = char:FindFirstChild("HumanoidRootPart")
	local look = root and Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local side = look and look.Magnitude > 0 and math.abs(direction.Unit:Dot(look.Unit)) < 0.5
	local iframes = Gear.Get(player).DodgeIFrames * (if side then Config.Momentum.SideIFrameMult else 1)
	s.lastDodge, s.iframes, s.block = t, t + iframes, false
	s.dodgeIframes = s.iframes -- Hop: a hit absorbed before this time refunds stamina
	s.busyUntil = t + 0.2
	if s.comboWeapon and s.combo > 0 then
		s.comboExpires = t + 0.2 + s.comboWeapon.ComboReset -- the chain is a rhythm, not a wall
	end
	char:SetAttribute("Blocking", false)
	-- Enemy Step (momentum.md 2.5): a dodge next to a Juggled enemy springs off it - stamina back
	-- and a hop, so the juggle can continue from the air.
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

-- The closest Juggled body within `range` of a position, or nil.
function Combat.NearestJuggled(position, range)
	local best, bestDist = nil, range
	for _, model in CollectionService:GetTagged("Combatant") do
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

function Combat.Init()
	Remotes.Attack.OnServerEvent:Connect(RateLimit.Wrap("Attack", L.Attack, Combat.Attack))
	Remotes.Heavy.OnServerEvent:Connect(RateLimit.Wrap("Heavy", L.Heavy, Combat.Heavy))
	Remotes.Feint.OnServerEvent:Connect(RateLimit.Wrap("Feint", L.Feint, Combat.Feint))
	Remotes.Flicker.OnServerEvent:Connect(RateLimit.Wrap("Flicker", L.Flicker, Combat.Flicker))
	Remotes.Block.OnServerEvent:Connect(RateLimit.Wrap("Block", L.Block, Combat.SetBlock))
	Remotes.Dodge.OnServerEvent:Connect(RateLimit.Wrap("Dodge", L.Dodge, Combat.Dodge))
	Remotes.Sprint.OnServerEvent:Connect(RateLimit.Wrap("Sprint", L.Sprint, Combat.SetSprint))
	Remotes.Reload.OnServerEvent:Connect(RateLimit.Wrap("Reload", L.Reload, Combat.Reload))
	Remotes.ADS.OnServerEvent:Connect(RateLimit.Wrap("ADS", L.ADS, Combat.SetADS))

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
				local weaponId = char:GetAttribute("Weapon")
				if weaponId ~= s.weaponSeen and Players:GetPlayerFromCharacter(char) then
					s.weaponSeen = weaponId
					Combat.SyncAmmo(char) -- the HUD's Ammo / MaxAmmo follow the equipped weapon
				end
				if s.sprint then
					if s.block or (char:GetAttribute("Stamina") or 0) <= Config.Sprint.MinStamina then
						s.sprint = false
						char:SetAttribute("Sprinting", false)
					else
						Combat.AddStamina(char, -Config.Sprint.StaminaPerSecond * step)
						s.lastSpend = t
					end
				end
				applySpeed(char, s, d)
				-- F still held after a swing, a stagger or a guard break: the guard comes back up on its own.
				-- Only a fresh press parries (blockStart is set outside the window).
				if s.blockHeld and not s.block and t >= s.busyUntil and Combat.CanAct(char) and Players:GetPlayerFromCharacter(char) then
					s.block, s.blockStart = true, t - C.ParryWindow - 1
					char:SetAttribute("Blocking", true)
				end
				local maxStamina = char:GetAttribute("MaxStamina")
				if maxStamina and not s.block and not s.sprint and t - s.lastSpend > C.StaminaRegenDelay then
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
