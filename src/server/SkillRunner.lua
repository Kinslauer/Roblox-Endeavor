-- Executes slotted skills. Skills are gated and scaled by stats + worn armor (see shared/Skills),
-- not by the equipped weapon. Strike-type skills borrow the weapon's reach so they feel native.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Weapons = require(Shared.Weapons)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)

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

local KINDS = { Burst = burst, Strike = strike, Dash = dash, Buff = buff, Recover = recover, Flicker = flicker }

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
	Net.On("UseSkill", { rate = 5, burst = 8, args = { "int" } }, SkillRunner.Use)
end

return SkillRunner
