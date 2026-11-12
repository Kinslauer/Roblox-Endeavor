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
local Config = require(Shared.Config)
local BC = Config.Builds.Chips
local function builds()
	return require(script.Parent.Builds)
end
local function chipOf(player, id)
	return builds().ChipOn(player, id)
end

local function burst(player, char, def, power)
	local root = char.HumanoidRootPart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	Combat.SetBusy(char, 0.4)
	-- Focus chip: the ring becomes a long cone ahead
	local focus = chipOf(player, "Surge") == "FocusChip"
	local radius = if focus then def.Radius * BC.FocusReach else def.Radius
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	Combat.FX("Burst", char, radius)
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local away = part.Position - root.Position
		away = Vector3.new(away.X, 0, away.Z)
		local inside = not focus or (away.Magnitude > 0.01 and away.Unit:Dot(look) >= BC.FocusCone)
		if model and not seen[model] and inside and model:FindFirstChildOfClass("Humanoid") then
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
	-- Hook chip: the blow drags the body in and holds it there
	local hook = chipOf(player, "ShatterStrike") == "HookChip"
	Combat.Swing(char, {
		Damage = def.Damage, Posture = def.Posture, Windup = def.Windup, Active = def.Active, End = def.End,
		Range = base.Range, Arc = base.Arc, Ranged = base.Ranged, Type = base.Type,
		Knockback = if hook then 0 else def.Knockback, Hyperarmor = def.Hyperarmor,
	}, { damageMult = power, postureMult = power, noStatScaling = true, label = def.Name, onHit = if hook then function(result, model)
		if result ~= "hit" and result ~= "guardbreak" then
			return
		end
		SkillRunner.Hook(char, model)
	end else nil })
end

local function dash(player, char, def, power)
	local root = char.HumanoidRootPart
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local start = root.Position
	if chipOf(player, "PhaseStep") == "TrailChip" then
		task.delay(def.Duration, function()
			if root.Parent then
				SkillRunner.Trail(char, start, root.Position, power)
			end
		end)
	end
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
	local s = Combat.State(char)
	if chipOf(player, "IronBastion") == "MirrorChip" and def.DamageTaken then
		s.mirrorUntil = os.clock() + def.Duration -- Combat.applyDamage breaks the striker's posture
	end
	if chipOf(player, "Overload") == "ArcChip" and def.ArcBonus then
		s.arcJumpUntil = os.clock() + def.Duration -- Combat's strike jumps to the next body near
	end
end

local function recover(player, char, def, power)
	Combat.SetBusy(char, 0.3)
	Combat.AddStamina(char, def.Stamina * power)
	Combat.AddPosture(char, -def.Posture * power)
	Combat.FX("Buff", char, "Recover")
	if chipOf(player, "SecondWind") == "BreathChip" then
		-- Breath chip: the breath closes light bleeds and dulls the pain
		local WoundService = require(script.Parent.Common.WoundService)
		local w = WoundService.Get(char)
		if w then
			for name, b in w.Bleed or {} do
				if b == "Light" then
					w.Bleed[name] = nil
				end
			end
			w.Pain = (w.Pain or 0) * BC.BreathPain
			WoundService.Push(char)
		end
	end
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
	if d.Empty or not Skills.Unlocked(def, d.Stats, d.Tags) then
		return -- the empty body holds no skills
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
	-- Quicken halves the cooldown; a Spike spends itself on this skill (server/Builds)
	local cooldown = def.Cooldown * builds().CooldownMult(player)
	s.skillCD[id] = t + cooldown
	s.block = false
	char:SetAttribute("Blocking", false)
	Remotes.CombatEvent:FireClient(player, "SkillCD", id, cooldown)
	Combat.Used:Fire(id, player)
	KINDS[def.Kind](player, char, def, Skills.Power(def, d.Stats, d.Tags) * builds().TakeSpike(player))
end

-- Hook chip: pull the struck body to the striker and hold it there
function SkillRunner.Hook(char, model)
	local root, vroot = char:FindFirstChild("HumanoidRootPart"), model:FindFirstChild("HumanoidRootPart")
	if not (root and vroot) then
		return
	end
	local toward = Vector3.new(root.Position.X - vroot.Position.X, 0, root.Position.Z - vroot.Position.Z)
	if toward.Magnitude > 2.5 then
		vroot.AssemblyLinearVelocity = toward.Unit * BC.HookPull + Vector3.new(0, 6, 0)
	end
	Combat.Stun(model, BC.HookStun)
	model:SetAttribute("Hooked", true)
	task.delay(BC.HookStun, function()
		if model.Parent then
			model:SetAttribute("Hooked", nil)
		end
	end)
end

-- Trail chip: a live line on the ground from where the blink began to where it ended
function SkillRunner.Trail(char, from, to, power)
	local line = to - from
	local mid = (from + to) / 2
	local strip = Instance.new("Part")
	strip.Name = "PhaseTrail"
	strip.Anchored, strip.CanCollide, strip.CanQuery, strip.CastShadow = true, false, false, false
	strip.Material, strip.Color, strip.Transparency = Enum.Material.Neon, Color3.fromRGB(120, 220, 255), 0.35
	strip.Size = Vector3.new(BC.TrailWidth * 0.5, 0.2, math.max(1, line.Magnitude))
	strip.CFrame = if line.Magnitude > 0.1 then CFrame.lookAt(mid - Vector3.new(0, 2.6, 0), to - Vector3.new(0, 2.6, 0)) else CFrame.new(mid - Vector3.new(0, 2.6, 0))
	strip.Parent = workspace
	local hit = {}
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < BC.TrailSeconds and char.Parent do
			for _, model in workspace:GetChildren() do
				local hum = model:IsA("Model") and model ~= char and model:FindFirstChildOfClass("Humanoid")
				local r = hum and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart")
				if r and not hit[model] then
					local u = if line.Magnitude > 0.1 then math.clamp((r.Position - from):Dot(line) / line.Magnitude ^ 2, 0, 1) else 0
					local near = from + line * u
					if (Vector3.new(r.Position.X - near.X, 0, r.Position.Z - near.Z)).Magnitude <= BC.TrailWidth and math.abs(r.Position.Y - near.Y) < 6 then
						hit[model] = true
						Combat.Damage(char, model, BC.TrailDamage * power, { Type = "Arc", Posture = 4, Stun = 0.4, Unblockable = true })
					end
				end
			end
			task.wait(BC.TrailTick)
		end
		strip:Destroy()
	end)
	return strip
end

function SkillRunner.Init()
	Net.On("UseSkill", { rate = 5, burst = 8, args = { "int" } }, SkillRunner.Use)
end

return SkillRunner
