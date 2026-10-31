-- The Front: entry point for the war world place. Everything runs inside one guard so a
-- startup failure is a single loud line in Output instead of a silent blue sky.
local Server = script.Parent

workspace:SetAttribute("Phase", "Open")
local ok, err = pcall(function()
	local Net = require(Server.Common.Net)
	local Battlefield = require(Server.Battlefield)
	local Factions = require(Server.Factions)
	local Hill = require(Server.Hill)
	local Soldiers = require(Server.Soldiers)
	Net.Init()
	Battlefield.Init()
	Factions.Init()
	Hill.Init()
	Soldiers.Init()
end)
if not ok then
	warn(("=============================\nFRONT STARTUP FAILED: %s\n============================="):format(tostring(err)))
end
