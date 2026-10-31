-- Landmarks: persistent world markers (Neural Net terminals, the Blackout Gate, the test armory) sent to
-- every client once the world is open, and to anyone who spawns later. Systems register as they build.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldPhase = require(script.Parent.WorldPhase)

local Landmarks = {}
local list = {} -- { key, position, label, color }

local function send(player)
	for _, l in list do
		Remotes.World:FireClient(player, "Marker", l.key, l.position, l.label, nil, l.color)
	end
end

function Landmarks.Register(key, position, label, color)
	table.insert(list, { key = key, position = position, label = label, color = color })
	if WorldPhase.IsOpen() then
		Remotes.World:FireAllClients("Marker", key, position, label, nil, color)
	end
end

function Landmarks.List()
	return list
end

function Landmarks.Init()
	WorldPhase.Changed.Event:Connect(function()
		if WorldPhase.IsOpen() then
			for _, player in Players:GetPlayers() do
				send(player)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if WorldPhase.IsOpen() then
				task.wait(1)
				send(player)
			end
		end)
	end)
end

return Landmarks
