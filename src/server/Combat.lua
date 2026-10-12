-- Server-authoritative combat: M1 combo, block/parry, dodge i-frames, stamina,
-- and "Surge" (the conduit's charged burst). Clients only send intent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local WorldPhase = require(script.Parent.WorldPhase)

local C = Config.Combat
local Combat = {}

local state = setmetatable({}, { __mode = "k" })

local function st(char)
	local s = state[char]
	if not s then
		s = { block = false, blockStart = 0, iframes = 0, stunned = 0, lastAttack = 0, lastDodge = 0, lastSpend = 0, combo = 0 }
		state[char] = s
	end
	return s
end

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

function Combat.SpendStamina(char, cost)
	local cur = char:GetAttribute("Stamina") or 0
	if cur < cost then
		return false
	end
	char:SetAttribute("Stamina", cur - cost)
	st(char).lastSpend = os.clock()
	return true
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

function Combat.Stun(char, duration)
	local hum = getHum(char)
	if not hum then
		return
	end
	local s = st(char)
	local endsAt = os.clock() + duration
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

local function knockback(char, vector)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		Remotes.CombatEvent:FireClient(player, "Knockback", vector) -- client owns its physics
	else
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = vector
		end
	end
end

-- Core damage pipeline. attacker/victim are character models (players or NPCs).
-- Returns "hit" | "blocked" | "parried" | "dodged" | "guardbreak" | "none"
function Combat.Damage(attacker, victim, amount, opts)
	opts = opts or {}
	local vhum = getHum(victim)
	if not vhum or vhum.Health <= 0 or attacker == victim then
		return "none"
	end
	local ap, vp = Players:GetPlayerFromCharacter(attacker), Players:GetPlayerFromCharacter(victim)
	if ap and vp and not WorldPhase.IsOpen() then
		return "none" -- no PvP during the prologue (they should never meet anyway)
	end

	local vs, t = st(victim), os.clock()
	if t < vs.iframes then
		fx("Dodged", victim)
		return "dodged"
	end

	local result = "hit"
	if vs.block and not opts.unblockable then
		if t - vs.blockStart <= C.ParryWindow then
			Combat.Stun(attacker, C.ParryStun)
			victim:SetAttribute("Stamina", math.min(victim:GetAttribute("MaxStamina") or 0, (victim:GetAttribute("Stamina") or 0) + 15))
			fx("Parry", victim)
			return "parried"
		end
		local cost = amount * C.BlockStaminaPerDamage
		local cur = victim:GetAttribute("Stamina") or 0
		if cur >= cost then
			victim:SetAttribute("Stamina", cur - cost)
			vs.lastSpend = t
			amount *= 1 - C.BlockReduction
			result = "blocked"
			fx("Block", victim)
		else
			vs.block = false
			victim:SetAttribute("Blocking", false)
			Combat.Stun(victim, C.GuardBreakStun)
			fx("GuardBreak", victim)
			result = "guardbreak"
		end
	end

	vhum:TakeDamage(amount)
	tag(attacker, victim)
	if opts.knockback and opts.knockback.Magnitude > 0 and result ~= "blocked" then
		knockback(victim, opts.knockback)
	end
	if result == "hit" then
		fx("Hit", victim)
	end
	return result
end

local function hitbox(char, range, width)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return {}
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -range / 2), Vector3.new(width, 5, range), params)
	local found, seen = {}, {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and getHum(model) then
			seen[model] = true
			table.insert(found, model)
		end
	end
	return found
end

local function canAct(char)
	return isAlive(char) and os.clock() >= st(char).stunned
end

function Combat.Attack(player)
	local char, profile = player.Character, PlayerData.Get(player)
	if not (char and profile and canAct(char)) then
		return
	end
	local s, weapon, t = st(char), Items.Defs[profile.Equipped] or Items.Defs.Fists, os.clock()
	if s.block or t - s.lastAttack < weapon.Cooldown then
		return
	end
	if not Combat.SpendStamina(char, weapon.StaminaCost) then
		return
	end
	s.combo = if t - s.lastAttack <= weapon.Cooldown + C.ComboResetTime then s.combo % 4 + 1 else 1
	s.lastAttack = t
	local combo = s.combo
	fx("Swing", char, combo)

	task.delay(weapon.Windup, function()
		if not canAct(char) then
			return
		end
		local finisher = combo == 4
		local damage = weapon.Damage * Stats.DamageMultiplier(profile) * (if finisher then C.ComboFinisherMultiplier else 1)
		local root = char:FindFirstChild("HumanoidRootPart")
		for _, victim in hitbox(char, weapon.Range, weapon.Width) do
			local push = root and root.CFrame.LookVector * weapon.Knockback * (if finisher then 1.8 else 0.6) or Vector3.zero
			local result = Combat.Damage(char, victim, damage, { knockback = push })
			if result == "hit" then
				local charge = (char:GetAttribute("Charge") or 0) + C.ChargePerHit + (weapon.ChargeBonus or 0)
				char:SetAttribute("Charge", math.min(charge, Config.Stats.MaxCharge))
			end
		end
	end)
end

function Combat.SetBlock(player, down)
	local char = player.Character
	if not char or type(down) ~= "boolean" then
		return
	end
	local s = st(char)
	if down then
		if canAct(char) and not s.block and (char:GetAttribute("Stamina") or 0) > 5 then
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
	if not (char and canAct(char) and typeof(direction) == "Vector3") then
		return
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	local s, t = st(char), os.clock()
	if t - s.lastDodge < C.DodgeCooldown or not Combat.SpendStamina(char, C.DodgeCost) then
		return
	end
	s.lastDodge, s.iframes, s.block = t, t + C.DodgeIFrames, false
	char:SetAttribute("Blocking", false)
	Remotes.CombatEvent:FireClient(player, "DodgeMove", direction.Unit * C.DodgeSpeed)
	fx("Dodge", char)
end

-- Conduit burst: spends Charge, hits everyone nearby, ignores blocks.
function Combat.Surge(player)
	local char, profile = player.Character, PlayerData.Get(player)
	if not (char and profile and canAct(char)) then
		return
	end
	local charge = char:GetAttribute("Charge") or 0
	local root = char:FindFirstChild("HumanoidRootPart")
	if charge < C.SurgeCost or not root then
		return
	end
	char:SetAttribute("Charge", charge - C.SurgeCost)
	fx("Surge", char)
	local power = Stats.SurgeMultiplier(profile)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, C.SurgeRadius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local vroot = model and model:FindFirstChild("HumanoidRootPart")
		if vroot and not seen[model] and getHum(model) then
			seen[model] = true
			local away = (vroot.Position - root.Position) * Vector3.new(1, 0, 1)
			local push = (if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector) * C.SurgeKnockback * power + Vector3.new(0, 25, 0)
			Combat.Damage(char, model, C.SurgeDamage * power, { unblockable = true, knockback = push })
		end
	end
end

function Combat.Init()
	Remotes.Attack.OnServerEvent:Connect(Combat.Attack)
	Remotes.Block.OnServerEvent:Connect(Combat.SetBlock)
	Remotes.Dodge.OnServerEvent:Connect(Combat.Dodge)
	Remotes.Surge.OnServerEvent:Connect(Combat.Surge)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local max = char and char:GetAttribute("MaxStamina")
			if max and isAlive(char) then
				local s = st(char)
				local cur = char:GetAttribute("Stamina") or 0
				if cur < max and not s.block and os.clock() - s.lastSpend > C.StaminaRegenDelay then
					char:SetAttribute("Stamina", math.min(max, cur + C.StaminaRegenPerSecond * step))
				end
			end
		end
	end)
end

return Combat
