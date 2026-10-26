-- Executes slotted skills. Skills are gated and scaled by stats + worn armor (see shared/Skills),
-- not by the equipped weapon. Strike-type skills borrow the weapon's reach so they feel native.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Weapons = require(Shared.Weapons)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local SkillRunner = {}

local function burst(player, char, def, power)
	local root = char.HumanoidRootPart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	Combat.SetBusy(char, 0.4)
	Combat.FX("Burst", char, def.Radius)
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, def.Radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and model:FindFirstChildOfClass("Humanoid") then
			seen[model] = true
			Combat.Damage(char, model, def.Damage * power, {
				Posture = def.Posture * power, Type = def.Type, Unblockable = true,
				Knockback = def.Knockback * power, Stun = 0.7,
			})
		end
	end
end

local function strike(player, char, def, power)
	local weapon = Weapons.Defs[PlayerData.Get(player).Equipped] or Weapons.Defs.Fists
	local base = weapon.Heavy
	Combat.Swing(char, {
		Damage = def.Damage, Posture = def.Posture, Windup = def.Windup, Active = def.Active, End = def.End,
		Range = base.Range, Arc = base.Arc, Ranged = base.Ranged, Type = base.Type,
		Knockback = def.Knockback, Hyperarmor = def.Hyperarmor,
	}, { damageMult = power, postureMult = power, noStatScaling = true, label = def.Name })
end

local function dash(player, char, def, power)
	local root = char.HumanoidRootPart
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	Combat.GrantIFrames(char, def.Duration + 0.05)
	Combat.SetBusy(char, def.Duration + 0.3)
	Remotes.CombatEvent:FireClient(player, "DodgeMove", forward * def.Speed)
	Combat.FX("Dodge", char)
	task.delay(def.Duration, function()
		if char.Parent and char.Humanoid.Health > 0 then
			Combat.Swing(char, {
				Damage = def.Damage, Posture = def.Posture, Windup = 0, Active = 0.12, End = 0.25,
				Range = def.Range, Arc = -1, Knockback = 25,
			}, { damageMult = power, postureMult = power, noStatScaling = true, label = def.Name })
		end
	end)
end

local function buff(player, char, def, power)
	Combat.SetBusy(char, 0.3)
	if def.Hyperarmor then
		Combat.AddBuff(char, "Hyperarmor", 0, def.Duration)
	end
	if def.DamageTaken then
		Combat.AddBuff(char, "Taken", math.max(0.25, def.DamageTaken / power), def.Duration)
	end
	if def.ArcBonus then
		Combat.AddBuff(char, "Arc", def.ArcBonus * power, def.Duration)
	end
end

local function recover(player, char, def, power)
	Combat.SetBusy(char, 0.3)
	Combat.AddStamina(char, def.Stamina * power)
	Combat.AddPosture(char, -def.Posture * power)
	Combat.FX("Buff", char, "Recover")
end

local function flicker(player, char, def)
	Combat.SetBusy(char, 0.25)
	Combat.SetFlicker(char, def.Level, def.Hold)
end

-- Nearest Humanoid model inside a forward cone (dot >= arc) and range; nil when nothing qualifies.
local function nearestInCone(char, range, arc)
	local root = char.HumanoidRootPart
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local best, bestDist = nil, math.huge
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, range, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local hum = model and not seen[model] and model:FindFirstChildOfClass("Humanoid")
		local troot = hum and model:FindFirstChild("HumanoidRootPart")
		if troot and hum.Health > 0 then
			seen[model] = true
			local to = troot.Position - root.Position
			local flat = Vector3.new(to.X, 0, to.Z)
			if flat.Magnitude > 0.5 and flat.Unit:Dot(look) >= arc and flat.Magnitude < bestDist then
				best, bestDist = model, flat.Magnitude
			end
		end
	end
	return best, bestDist
end

-- Snatch (momentum.md 2.2): pull the target to PullStop studs and stun it briefly. No damage.
local function pull(player, char, def, power)
	local M = Config.Momentum
	local target = nearestInCone(char, def.Range, def.Arc)
	Combat.SetBusy(char, 0.35)
	if not target then
		Combat.FX("Snatch", char, nil)
		return
	end
	-- Combat refuses damage across the safe zone; refuse the pull the same way
	if Combat.Damage(char, target, 0, { Posture = def.Posture * power, Unblockable = true, Stun = M.PullStun, Staggers = true }) == "none" then
		return
	end
	local root, troot = char.HumanoidRootPart, target.HumanoidRootPart
	local to = root.Position - troot.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	local dist = math.max(flat.Magnitude - M.PullStop, 0)
	local velocity = flat.Unit * (dist / M.PullTime) + Vector3.new(0, 8, 0)
	local victim = game:GetService("Players"):GetPlayerFromCharacter(target)
	if victim then
		Remotes.CombatEvent:FireClient(victim, "Knockback", velocity) -- players own their physics
	else
		troot.AssemblyLinearVelocity = velocity
	end
	if char:GetAttribute("Weapon") then -- the chain survives a Snatch
		local s = Combat.State(char)
		if s.comboWeapon and s.combo > 0 then
			s.comboExpires = os.clock() + 0.35 + s.comboWeapon.ComboReset
		end
	end
	Combat.FX("Snatch", char, target)
end

-- Buster (momentum.md 2.3): throw an open target, shove a standing one.
local function grab(player, char, def, power)
	local target = nearestInCone(char, def.Range, def.Arc)
	Combat.SetBusy(char, 0.5)
	if not target then
		return
	end
	local open = Combat.IsOpen(target)
	if open then
		local result = Combat.Damage(char, target, def.Damage * power, { Posture = 0, Unblockable = true, Knockback = def.Knockback, Stun = def.Stun, Staggers = true })
		if result ~= "none" then
			target:SetAttribute("Posture", 0)
			Combat.FX("Buster", char, { target = target, throw = true })
		end
	else
		local result = Combat.Damage(char, target, def.ShoveDamage * power, { Posture = 4, Unblockable = true, Knockback = def.ShoveKnockback })
		if result ~= "none" then
			Combat.FX("Buster", char, { target = target, throw = false })
		end
	end
end

local KINDS = { Burst = burst, Strike = strike, Dash = dash, Buff = buff, Recover = recover, Flicker = flicker, Pull = pull, Grab = grab }

function SkillRunner.Use(player, slot)
	local char, data = player.Character, PlayerData.Get(player)
	if not (char and data and type(slot) == "number" and slot % 1 == 0) then
		return
	end
	local id = data.SkillSlots[tostring(slot)]
	local def = id and Skills.Defs[id]
	if not def or not Combat.CanAct(char) then
		return
	end
	Combat.ClearProtection(char) -- using a skill is an offensive act: spawn protection ends
	local d = Gear.Get(player)
	if not Skills.Unlocked(def, d.Stats, d.Tags) then
		return
	end
	local s, t = Combat.State(char), os.clock()
	if t < (s.skillCD[id] or 0) then
		return
	end
	if def.ChargeCost and (char:GetAttribute("Charge") or 0) < def.ChargeCost then
		return
	end
	if def.Stamina and def.Kind ~= "Recover" and not Combat.SpendStamina(char, def.Stamina) then
		return
	end

	if def.ChargeCost then
		Combat.AddCharge(char, -def.ChargeCost)
	end
	s.skillCD[id] = t + def.Cooldown
	s.block = false
	char:SetAttribute("Blocking", false)
	Remotes.CombatEvent:FireClient(player, "SkillCD", id, def.Cooldown)
	Combat.Used:Fire(id, player)
	KINDS[def.Kind](player, char, def, Skills.Power(def, d.Stats, d.Tags))
end

function SkillRunner.Init()
	Remotes.UseSkill.OnServerEvent:Connect(RateLimit.Wrap("UseSkill", Config.RateLimit.UseSkill, SkillRunner.Use))
end

return SkillRunner
