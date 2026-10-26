local Server = script.Parent

local District = require(Server.District)
local Arena = require(Server.Arena)
local Range = require(Server.Range)
local Hideout = require(Server.Hideout)
local War = require(Server.War)
local Gear = require(Server.Gear)
local WorldPhase = require(Server.WorldPhase)
local Stats = require(Server.Stats)
local Inventory = require(Server.Inventory)
local Bench = require(Server.Bench)
local Quests = require(Server.Quests)
local Combat = require(Server.Combat)
local SkillRunner = require(Server.SkillRunner)
local Events = require(Server.Events)
local Tutorial = require(Server.Tutorial)
local Creator = require(Server.Creator)
local Lifecycle = require(Server.Lifecycle)

-- World geometry must exist before WorldPhase.Init so the CitySpawn pads are found. A bug in a
-- generator must never stop the game from starting, so each is isolated.
local ok, err = pcall(District.Init)
if not ok then
	warn("[District] failed to build:", err)
end
ok, err = pcall(Arena.Init)
if not ok then
	warn("[Arena] failed to build:", err)
end
ok, err = pcall(Range.Init)
if not ok then
	warn("[Range] failed to build:", err)
end
ok, err = pcall(Hideout.Init)
if not ok then
	warn("[Hideout] failed to build:", err)
end
ok, err = pcall(War.Init)
if not ok then
	warn("[War] failed to build:", err)
end
WorldPhase.Init()
Gear.Init()
Stats.Init()
Inventory.Init()
Bench.Init()
Quests.Init()
Combat.Init()
SkillRunner.Init()
Events.Init()
Tutorial.Init()
Creator.Init()
Lifecycle.Init()
