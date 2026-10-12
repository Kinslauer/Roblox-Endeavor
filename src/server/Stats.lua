local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local S = Config.Stats
local Stats = {}

function Stats.MaxStamina(profile)
	return S.BaseStamina + profile.Stats.Willpower * S.StaminaPerWillpower
end

function Stats.DamageMultiplier(profile)
	return 1 + profile.Stats.Strength * S.DamagePerStrength
end

function Stats.SurgeMultiplier(profile)
	return 1 + profile.Stats.Intelligence * S.SurgePerIntelligence
end

function Stats.Apply(player, fill)
	local profile, char = PlayerData.Get(player), player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (profile and hum) then
		return
	end
	local maxHealth = S.BaseHealth + profile.Stats.Fortitude * S.HealthPerFortitude
	hum.MaxHealth = maxHealth
	hum.Health = if fill then maxHealth else math.min(hum.Health, maxHealth)
	hum.WalkSpeed = S.BaseWalkSpeed + profile.Stats.Agility * S.WalkSpeedPerAgility

	local maxStamina = Stats.MaxStamina(profile)
	char:SetAttribute("MaxStamina", maxStamina)
	char:SetAttribute("MaxCharge", S.MaxCharge)
	if fill then
		char:SetAttribute("Stamina", maxStamina)
		char:SetAttribute("Charge", 0)
	end
end

function Stats.XpNeeded(level)
	return 100 * level
end

function Stats.Push(player)
	local profile = PlayerData.Get(player)
	if profile then
		Remotes.StatsChanged:FireClient(player, {
			Stats = profile.Stats,
			FreePoints = profile.FreePoints,
			Level = profile.Level,
			Xp = profile.Xp,
			XpNeeded = Stats.XpNeeded(profile.Level),
			Max = S.MaxPerStat,
		})
	end
end

function Stats.AddXp(player, amount)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	profile.Xp += amount
	while profile.Xp >= Stats.XpNeeded(profile.Level) do
		profile.Xp -= Stats.XpNeeded(profile.Level)
		profile.Level += 1
		profile.FreePoints += S.PointsPerLevel
		Remotes.Announce:FireClient(player, "Level " .. profile.Level .. " - allocate your points (K)", "Info")
	end
	Stats.Push(player)
end

function Stats.Allocate(player, statName)
	local profile = PlayerData.Get(player)
	if not profile or type(statName) ~= "string" or profile.Stats[statName] == nil then
		return
	end
	if profile.FreePoints <= 0 or profile.Stats[statName] >= S.MaxPerStat then
		return
	end
	profile.FreePoints -= 1
	profile.Stats[statName] += 1
	Stats.Apply(player, false)
	Stats.Push(player)
end

function Stats.Init()
	Remotes.Allocate.OnServerEvent:Connect(Stats.Allocate)
end

return Stats
