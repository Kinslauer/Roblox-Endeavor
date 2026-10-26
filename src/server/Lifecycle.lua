-- Join / spawn / death / leave flow.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)
local Creator = require(script.Parent.Creator)
local Rig = require(script.Parent.Rig)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local Permadeath = require(script.Parent.Permadeath)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local Tutorial = require(script.Parent.Tutorial)
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
	local char = Rig.Spawn(player) -- standardized body (server/Rig.lua), never the Roblox avatar
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not (root and hum) then
		return
	end
	player:SetAttribute("Zone", nil) -- a fresh body always starts in the city (Range sets these)
	player:SetAttribute("ForceFirstPerson", nil)
	char:PivotTo(WorldPhase.GetSpawnCFrame(player))
	Gear.Recompute(player) -- fresh derived stats (important after a permadeath wipe)
	Stats.Apply(player, true)
	Stats.Push(player)
	Inventory.Push(player)
	hum.Died:Once(function()
		onDied(player)
	end)
	Creator.Run(player) -- first spawn of a (new) character: pick a look before anything else
	if WorldPhase.IsOpen() then
		local profile = PlayerData.Get(player)
		if profile then
			profile.Awakened = true
		end
		Combat.Protect(char, Config.SpawnProtectionSeconds) -- fair arrival: nobody gets spawn-killed
		Quests.Assign(player)
	elseif Config.Tutorial.Enabled then
		Tutorial.Start(player)
	end
	Quests.Push(player)
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
	Tutorial.Release(player)
	PlayerData.Release(player)
	Gear.Release(player)
	WorldPhase.ReleasePlot(player)
	WorldPhase.CheckReady() -- the leaver may have been the last one holding the world closed
end

function Lifecycle.Init()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- Emergence drops everyone into the shared city at once: the same protection as a fresh spawn.
	WorldPhase.Changed.Event:Connect(function(phase)
		if phase == Config.Phases.Open then
			for _, player in Players:GetPlayers() do
				if player.Character then
					Combat.Protect(player.Character, Config.SpawnProtectionSeconds)
				end
			end
		end
	end)
end

return Lifecycle
