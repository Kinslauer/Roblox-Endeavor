local Server = script.Parent

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

-- Must run before WorldPhase.Init so its CitySpawn pads are found. A bug in the test arena
-- must never stop the game from starting, so it is isolated.
Gore.Init()
Destruction.Init() -- before City, which places props and breach points
City.Init()
local ok, err = pcall(Arena.Init)
if not ok then
	warn("[Arena] failed to build:", err)
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
Raids.Init()
NeuralNet.Init()
Hideouts.Init()
Tutorial.Init()
Lifecycle.Init()
