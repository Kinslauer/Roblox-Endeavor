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
	local Landmarks = require(Server.Landmarks)
	local Population = require(Server.Population)
	local DevTools = require(Server.DevTools)
	local IconLibrary = require(Server.IconLibrary)
	local Autonet = require(Server.Autonet)
	local Frontier = require(Server.Frontier)
	local Terminal = require(Server.Terminal)
	local Contacts = require(Server.Contacts)
	local CluesServer = require(Server.CluesServer)
	local Cycle = require(Server.Cycle)
	local ImplantLibrary = require(Server.ImplantLibrary)

	workspace.Gravity = require(game:GetService("ReplicatedStorage").Shared.Config).Movement.Gravity -- the template's weight (client/Movement.lua)
	-- the Conduit body: players spawn as it (before anyone loads a character)
	local bodyOk, bodyErr = pcall(require(Server.Body).Init)
	if not bodyOk then
		warn("[Body] failed:", bodyErr)
	end
	Gore.Init()
	require(Server.Common.SurfaceLibrary).Init() -- before anything spawns models: Assets.Dress puts the library surfaces on them
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
	require(Server.Loot).Init()
	Quests.Init()
	Combat.Init()
	SkillRunner.Init()
	Events.Init()
	require(Server.Stealth).Init()
	Tutorial.Init()
	Raids.Init()
	NeuralNet.Init()
	Hideouts.Init()
	Lifecycle.Init()
	Landmarks.Init()
	Population.Init()
	-- the way down: the Sumps shaft and the barrens hall (isolated: the underground must not stop the city)
	local barrensOk, barrensErr = pcall(require(Server.Barrens).Init)
	if not barrensOk then
		warn("[Barrens] failed to build:", barrensErr)
	end
	-- the world north of the wall: terrain, the route, the Reach and the ring sites. Isolated like
	-- the arena: a bad voxel write must not keep the city from starting.
	local frontierOk, frontierErr = pcall(Frontier.Init)
	if not frontierOk then
		warn("[Frontier] failed to build:", frontierErr)
	end
	Terminal.Init()
	Terminal.BuildBoard() -- from the frontier layout
	local contactsOk, contactsErr = pcall(Contacts.Init)
	if not contactsOk then
		warn("[Contacts] failed:", contactsErr)
	end
	CluesServer.Init()
	Cycle.Init()
	DevTools.Init()
	IconLibrary.Init()
	require(Server.IntroKit).Init()
	Autonet.Init()
	ImplantLibrary.Init()
	require(Server.Kit).Init() -- two weapons, the rig and belt, quick dressings
	require(Server.Knock).Init() -- knocked down, not dead
	-- builds (round 5): chips, actives, the stack slot, practice, carried earnings, the Rootwork basin
	local buildsOk, buildsErr = pcall(require(Server.Builds).Init)
	if not buildsOk then
		warn("[Builds] failed:", buildsErr)
	end
	-- world and money (round 6): parties, keys and locked rooms, party runs below the Sumps, the bay economy
	for _, name in { "Party", "Keys", "Runs", "Economy" } do
		local okW, errW = pcall(function()
			require(Server[name]).Init()
		end)
		if not okW then
			warn("[" .. name .. "] failed:", errW)
		end
	end
	-- wounds on every player body (isolated: a fault here must not stop the city)
	local medOk, medErr = pcall(require(Server.Medicine).Init)
	if not medOk then
		warn("[Medicine] failed:", medErr)
	end
end)
if not ok then
	warn(("=============================\nENDEAVOR STARTUP FAILED: %s\n============================="):format(tostring(err)))
end
