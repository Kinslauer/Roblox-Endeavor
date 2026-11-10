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
local NeuralNet = require(script.Parent.NeuralNet)
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

-- Where a body comes into the open world, and why (the story's order of things):
--   "Front"  back through the Neural Net: at the terminal it tapped in from (first spawn after a Front teleport)
--   "Reboot" an uploaded stack wakes at its hideout's computer
--   "Bunks"  the crew's bunks
--   "Lift"   every other body comes up Line 9: its own bay's freight lift, else a free bay's (with a manifest
--            to sign for it, once per life)
--   "City"   no bay free (or the prologue): the old street spawns
local fromFront = {} -- player -> true until the first spawn after arriving from the Front has used it

local function placeFor(player)
	if not WorldPhase.IsOpen() then
		return WorldPhase.GetSpawnCFrame(player), "City" -- the prologue's plots; Emerge places them again
	end
	if fromFront[player] then
		fromFront[player] = nil
		local cf = NeuralNet.ReturnCFrame(player)
		if cf then
			return cf, "Front"
		end
	end
	local data = PlayerData.Get(player)
	if data and data.Knowledge and data.Knowledge.Uploaded then
		local cf = Hideouts.RebootCFrame(player)
		if cf then
			return cf, "Reboot"
		end
	end
	local bunks = Hideouts.SpawnCFrame(player)
	if bunks then
		return bunks, "Bunks"
	end
	local lift, site = Hideouts.ArrivalCFrame(player)
	if lift then
		if not site.Owner then
			Tutorial.Consign(player)
		end
		return lift, "Lift"
	end
	return WorldPhase.GetSpawnCFrame(player), "City"
end
Lifecycle.PlaceFor = placeFor

-- The machine's line for how a body arrived (none for a lift or a street: the place says it).
local function announceArrival(player, how)
	if how == "Front" then
		NeuralNet.Returned(player)
	elseif how == "Reboot" then
		Remotes.Announce:FireClient(player, "> STACK RESIDENT . . . REBOOTED", "Emergence")
	end
end

function Lifecycle.Spawn(player)
	if not player.Parent then
		return
	end
	-- Decide where first, so the ground exists (and has replicated) before the character does.
	local arriving = Tutorial.Active(player)
	local spawnAt, how = Tutorial.SpawnCFrame(player), "Station"
	if not spawnAt then
		spawnAt, how = placeFor(player)
	end
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
		announceArrival(player, how)
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
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and type(join) == "table" and join.TeleportData
	fromFront[player] = type(td) == "table" and td.From == "Front" or nil
	Hideouts.Restore(player) -- the hideout stands before the body arrives, so it can wake there
	WorldPhase.StartTimer()
	Lifecycle.Spawn(player)
end

local function onPlayerRemoving(player)
	if WorldPhase.IsOpen() and Config.CombatLogPunish and Combat.InCombat(player) then
		Permadeath.CombatLog(player) -- wipes the data before ProfileService saves it on release
	end
	Tutorial.Release(player)
	fromFront[player] = nil
	PlayerData.Release(player)
	Gear.Release(player)
	WorldPhase.ReleasePlot(player)
	WorldPhase.CheckReady() -- the leaver may have been the last one holding the world closed
end

function Lifecycle.Init()
	Players.CharacterAutoLoads = false
	WorldPhase.Busy = Tutorial.Active
	Tutorial.Spawn = Lifecycle.Spawn
	WorldPhase.Place = function(player)
		local cf, how = placeFor(player)
		announceArrival(player, how)
		return cf
	end
	-- up through the lift: into the city if it is open, else the world opens for them (WorldPhase.Emerge moves them)
	Tutorial.Finished.Event:Connect(function(player)
		local char = player.Character
		if char and WorldPhase.IsOpen() then
			local cf, how = placeFor(player)
			char:PivotTo(cf)
			arrive(player, char)
			announceArrival(player, how)
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
