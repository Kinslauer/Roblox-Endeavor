-- Endeavor (the conduit city): entry point. Everything runs inside one guard so a startup
-- failure is a single loud line in Output instead of a silent sky.
local Server = script.Parent

local ok, err = pcall(function()
	local Arena = require(Server.Arena)
	local City = require(Server.City)
	local Raids = require(Server.Raids)
	local Destruction = require(Server.Destruction)
	local Gore = require(Server.Gore)
	local NeuralNet = require(Server.NeuralNet)
	local Hideouts = require(Server.Hideouts)
	local Gear = require(Server.Gear)
	local Net = require(Server.Common.Net)
	local WorldPhase = require(Server.WorldPhase)
	local Stats = require(Server.Stats)
	local Inventory = require(Server.Inventory)
	local Quests = require(Server.Quests)
	local Combat = require(Server.Combat)
	local SkillRunner = require(Server.SkillRunner)
	local Events = require(Server.Events)
	local Tutorial = require(Server.Tutorial)
	local Lifecycle = require(Server.Lifecycle)

	Gore.Init()
	Destruction.Init() -- before City, which places props and breach points
	City.Init()
	-- Must run before WorldPhase.Init so its CitySpawn pads are found. A bug in the test arena
	-- must never stop the game from starting, so it is isolated.
	local arenaOk, arenaErr = pcall(Arena.Init)
	if not arenaOk then
		warn("[Arena] failed to build:", arenaErr)
	end
	WorldPhase.Init()
	Net.Init()
	Gear.Init()
	Stats.Init()
	Inventory.Init()
	Quests.Init()
	Combat.Init()
	SkillRunner.Init()
	Events.Init()
	Tutorial.Init()
	Raids.Init()
	NeuralNet.Init()
	Hideouts.Init()
	Lifecycle.Init()
end)
if not ok then
	warn(("=============================\nENDEAVOR STARTUP FAILED: %s\n============================="):format(tostring(err)))
end
