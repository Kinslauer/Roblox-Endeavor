local Server = script.Parent

local PlayerData = require(Server.PlayerData)
local WorldPhase = require(Server.WorldPhase)
local Stats = require(Server.Stats)
local Inventory = require(Server.Inventory)
local Quests = require(Server.Quests)
local Combat = require(Server.Combat)
local Events = require(Server.Events)
local Lifecycle = require(Server.Lifecycle)

WorldPhase.Init()
PlayerData.Init()
Stats.Init()
Inventory.Init()
Quests.Init()
Combat.Init()
Events.Init()
Lifecycle.Init()
