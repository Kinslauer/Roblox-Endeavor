local Server = script.Parent

local District = require(Server.District)
local Arena = require(Server.Arena)
local Range = require(Server.Range)
local Hideout = require(Server.Hideout)
local War = require(Server.War)
local Regions = require(Server.Regions)
local Transport = require(Server.Transport)
local Raids = require(Server.Raids)
local Terminal = require(Server.Terminal)
local Contacts = require(Server.Contacts)
local Rivals = require(Server.Rivals)
local Travel = require(Server.Travel)
local Gear = require(Server.Gear)
local WorldPhase = require(Server.WorldPhase)
local Stats = require(Server.Stats)
local Inventory = require(Server.Inventory)
local Bench = require(Server.Bench)
local Quests = require(Server.Quests)
local Combat = require(Server.Combat)
local SkillRunner = require(Server.SkillRunner)
local Events = require(Server.Events)
local Cycle = require(Server.Cycle)
local Clues = require(Server.Clues)
local Autonet = require(Server.Autonet)
local Destruction = require(Server.Destruction)
local Grab = require(Server.Grab)
local Tutorial = require(Server.Tutorial)
local Creator = require(Server.Creator)
local Lifecycle = require(Server.Lifecycle)
local DevPanel = require(Server.DevPanel)

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
ok, err = pcall(Regions.Init)
if not ok then
	warn("[Regions] failed to build:", err)
end
ok, err = pcall(Transport.Init)
if not ok then
	warn("[Transport] failed to build:", err)
end
ok, err = pcall(Hideout.Init)
if not ok then
	warn("[Hideout] failed to build:", err)
end
ok, err = pcall(Contacts.Init)
if not ok then
	warn("[Contacts] failed to build:", err)
end
ok, err = pcall(Rivals.Init)
if not ok then
	warn("[Rivals] failed to build:", err)
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
Raids.Init()
Terminal.Init()
Travel.Init()
Quests.Init()
Combat.Init()
SkillRunner.Init()
Events.Init()
Cycle.Init()
Clues.Init()
Autonet.Init()
ok, err = pcall(Destruction.Init)
if not ok then
	warn("[Destruction] failed to build:", err)
end
Grab.Init()
Tutorial.Init()
Creator.Init()
Lifecycle.Init()
DevPanel.Init() -- Studio only: teleports and gives for testing (client/DevPanel.lua)
