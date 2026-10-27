local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gear = require(script.Parent.Gear)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local S = Config.Stats
local Stats = {}

-- Applies derived numbers (health, speed, stamina, posture caps) to the live character.
function Stats.Apply(player, fill)
	local d, char = Gear.Get(player), player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not PlayerData.Get(player) then
		return
	end
	hum.MaxHealth = d.MaxHealth
	hum.Health = if fill then d.MaxHealth else math.min(hum.Health, d.MaxHealth)
	hum.WalkSpeed = d.WalkSpeed
	hum.JumpPower = S.BaseJumpPower * d.JumpMult -- piston legs (shared/Cybernetics.lua)
	hum.JumpHeight = S.BaseJumpHeight * d.JumpMult

	char:SetAttribute("MaxStamina", d.MaxStamina)
	char:SetAttribute("MaxPosture", d.MaxPosture)
	char:SetAttribute("MaxCharge", S.MaxCharge)
	if fill then
		char:SetAttribute("Stamina", d.MaxStamina)
		char:SetAttribute("Posture", 0)
		char:SetAttribute("Charge", 0)
	end
end

function Stats.XpNeeded(level)
	return 100 * level
end

function Stats.Push(player)
	local data = PlayerData.Get(player)
	if data then
		Remotes.StatsChanged:FireClient(player, {
			Stats = data.Stats,
			FreePoints = data.FreePoints,
			Level = data.Level,
			Xp = data.Xp,
			XpNeeded = Stats.XpNeeded(data.Level),
			Max = S.MaxPerStat,
		})
	end
end

function Stats.AddXp(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.Xp += amount
	while data.Xp >= Stats.XpNeeded(data.Level) do
		data.Xp -= Stats.XpNeeded(data.Level)
		data.Level += 1
		data.FreePoints += S.PointsPerLevel
		Remotes.Announce:FireClient(player, "Level " .. data.Level .. " - allocate your points (J)", "Info")
	end
	Stats.Push(player)
end

function Stats.Allocate(player, statName)
	local data = PlayerData.Get(player)
	if not data or type(statName) ~= "string" or data.Stats[statName] == nil then
		return
	end
	if data.FreePoints <= 0 or data.Stats[statName] >= S.MaxPerStat then
		return
	end
	data.FreePoints -= 1
	data.Stats[statName] += 1
	Gear.Recompute(player) -- fires Gear.Changed -> Apply + Push below
end

function Stats.Init()
	Remotes.Allocate.OnServerEvent:Connect(RateLimit.Wrap("Allocate", Config.RateLimit.Allocate, Stats.Allocate))
	Gear.Changed.Event:Connect(function(player)
		Stats.Apply(player, false)
		Stats.Push(player)
	end)
end

return Stats
