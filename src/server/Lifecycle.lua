-- Join / spawn / death / leave flow.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local Permadeath = require(script.Parent.Permadeath)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local WorldPhase = require(script.Parent.WorldPhase)

local Lifecycle = {}

local function onDied(player)
	if WorldPhase.IsOpen() then
		Permadeath.Handle(player, player.Character)
		task.wait(Config.RespawnDelay)
	else
		task.wait(3) -- prologue deaths are free
	end
	Lifecycle.Spawn(player)
end

function Lifecycle.Spawn(player)
	if not player.Parent then
		return
	end
	player:LoadCharacter()
	local char = player.Character
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not (root and hum) then
		return
	end
	char:PivotTo(WorldPhase.GetSpawnCFrame(player))
	Gear.Recompute(player) -- fresh derived stats (important after a permadeath wipe)
	Stats.Apply(player, true)
	Stats.Push(player)
	Inventory.Push(player)
	if WorldPhase.IsOpen() then
		local profile = PlayerData.Get(player)
		if profile then
			profile.Awakened = true
		end
		Quests.Assign(player)
	end
	Quests.Push(player)
	hum.Died:Once(function()
		onDied(player)
	end)
end

local function onPlayerAdded(player)
	if not PlayerData.Load(player) then
		return
	end
	WorldPhase.StartTimer()
	Lifecycle.Spawn(player)
end

local function onPlayerRemoving(player)
	if WorldPhase.IsOpen() and Config.CombatLogPunish and Combat.InCombat(player) then
		Permadeath.CombatLog(player) -- wipes the data before ProfileService saves it on release
	end
	PlayerData.Release(player)
	Gear.Release(player)
	WorldPhase.ReleasePlot(player)
end

function Lifecycle.Init()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Lifecycle
