-- The Front: entry point for the war world place.
local Server = script.Parent

local Net = require(Server.Common.Net)
local Battlefield = require(Server.Battlefield)
local Factions = require(Server.Factions)
local Hill = require(Server.Hill)
local Soldiers = require(Server.Soldiers)

workspace:SetAttribute("Phase", "Open")
Net.Init()
Battlefield.Init()
Factions.Init()
Hill.Init()
Soldiers.Init()
