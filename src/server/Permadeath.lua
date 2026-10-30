-- Death is final: the character is deleted and everything carried drops as lootable remains.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)

local legacyStore = DataStoreService:GetDataStore("ConduitLegacy_v1")
local Permadeath = {}

local function dropRemains(player, profile, cframe)
	local bundle = table.clone(profile.Inventory)
	if next(bundle) == nil then
		bundle.Cloth = 1 -- a body is always worth devouring
	end
	Loot.Spawn(cframe, bundle, { Label = player.DisplayName .. "'s remains", Devour = { Level = profile.Level } })
end

-- Account-level stats that survive deaths (a "legacy" for leaderboards/cosmetics later).
local function recordLegacy(userId, profile)
	local survived = os.time() - profile.BornAt
	task.spawn(function()
		pcall(function()
			legacyStore:UpdateAsync("Legacy_" .. userId, function(old)
				old = old or { Deaths = 0, TotalKills = 0, BestSurvival = 0 }
				old.Deaths += 1
				old.TotalKills += profile.Kills
				old.BestSurvival = math.max(old.BestSurvival, survived)
				return old
			end)
		end)
	end)
	return survived
end

function Permadeath.Handle(player, char)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local cframe = if root then root.CFrame else CFrame.new(0, 10, 0)
	dropRemains(player, profile, cframe)

	local killerName, killer = Combat.GetKiller(char)
	if killer then
		local killerProfile = PlayerData.Get(killer)
		if killerProfile then
			killerProfile.Kills += 1
		end
		Stats.AddXp(killer, 50 + profile.Level * 25)
		Quests.Progress(killer, "kill", "Player", 1)
	end
	Remotes.Announce:FireAllClients(
		player.DisplayName .. (if killerName then " was eliminated by " .. killerName else " has fallen") .. ".", "Kill")

	local survived = recordLegacy(player.UserId, profile)
	Remotes.Died:FireClient(player, { Survived = survived, Kills = profile.Kills, Level = profile.Level, Killer = killerName })
	PlayerData.Reset(player)
end

-- Player quit mid-fight: they lose the character, but the body stays behind to be looted.
function Permadeath.CombatLog(player)
	local profile, char = PlayerData.Get(player), player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if profile and root then
		dropRemains(player, profile, root.CFrame)
		Remotes.Announce:FireAllClients(player.DisplayName .. " fled the fight and was lost.", "Kill")
		recordLegacy(player.UserId, profile)
	end
	PlayerData.Reset(player)
end

return Permadeath
