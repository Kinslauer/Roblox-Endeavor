-- Join / spawn / death / leave flow.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local City = require(script.Parent.City)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Body = require(script.Parent.Body)
local Hideouts = require(script.Parent.Hideouts)
local Inventory = require(script.Parent.Inventory)
local Permadeath = require(script.Parent.Permadeath)
local PlayerData = require(script.Parent.Common.PlayerData)
local Quests = require(script.Parent.Quests)
local Stats = require(script.Parent.Stats)
local Tutorial = require(script.Parent.Tutorial)
local WorldPhase = require(script.Parent.WorldPhase)

local Lifecycle = {}

local function onDied(player)
	if Tutorial.Active(player) then
		task.wait(2) -- caught in the station: back to the last checkpoint, nothing lost
	elseif WorldPhase.IsOpen() then
		Permadeath.Handle(player, player.Character)
		task.wait(Config.RespawnDelay)
	else
		task.wait(3) -- prologue deaths are free
	end
	Lifecycle.Spawn(player)
end

-- A character's first moments in the open city.
local function arrive(player, char)
	local profile = PlayerData.Get(player)
	if profile then
		profile.Awakened = true
	end
	Combat.GrantIFrames(char, Config.SpawnProtection) -- fresh characters are not free kills
	City.ResetVisits(player)
	Quests.Assign(player)
end

function Lifecycle.Spawn(player)
	if not player.Parent then
		return
	end
	-- Decide where first, so the ground exists (and has replicated) before the character does.
	local arriving = Tutorial.Active(player)
	local spawnAt = Tutorial.SpawnCFrame(player) or Hideouts.SpawnCFrame(player) or WorldPhase.GetSpawnCFrame(player)
	player:LoadCharacter()
	local char = player.Character
	if char then
		Body.Apply(player, char) -- this life's colours on the Conduit body
	end
	local root = char and char:WaitForChild("HumanoidRootPart", 10)
	local hum = char and char:WaitForChild("Humanoid", 10)
	if not (root and hum) then
		return
	end
	char:PivotTo(spawnAt)
	-- The client owns its character's physics and may not have the floor yet: hold the character
	-- on the server for a moment so it cannot fall through ground it hasn't received.
	root.Anchored = true
	task.delay(Config.SpawnSettle, function()
		if root.Parent and not char:GetAttribute("Cutscene") then
			char:PivotTo(spawnAt)
			root.Anchored = false
		end
	end)
	Gear.Recompute(player) -- fresh derived stats (important after a permadeath wipe)
	Stats.Apply(player, true)
	Stats.Push(player)
	Inventory.Push(player)
	if arriving then
		Tutorial.Start(player)
	elseif WorldPhase.IsOpen() then
		arrive(player, char)
	else
		Remotes.Announce:FireClient(player, "> STACK RESIDENT . . . LINKING", "Info")
		WorldPhase.MarkReady(player, "returning") -- nothing to learn; the city opens as soon as everyone here is ready
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
	Tutorial.Release(player)
	PlayerData.Release(player)
	Gear.Release(player)
	WorldPhase.ReleasePlot(player)
	WorldPhase.CheckReady() -- the leaver may have been the last one holding the world closed
end

function Lifecycle.Init()
	Players.CharacterAutoLoads = false
	WorldPhase.Busy = Tutorial.Active
	Tutorial.Spawn = Lifecycle.Spawn
	-- up through the lift: into the city if it is open, else the world opens for them (WorldPhase.Emerge moves them)
	Tutorial.Finished.Event:Connect(function(player)
		local char = player.Character
		if char and WorldPhase.IsOpen() then
			char:PivotTo(Hideouts.SpawnCFrame(player) or WorldPhase.GetSpawnCFrame(player))
			arrive(player, char)
			Quests.Push(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Lifecycle
