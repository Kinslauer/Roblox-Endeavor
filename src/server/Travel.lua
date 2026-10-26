-- Travel (Phase 3, build order 7 groundwork): one door between the worlds. Today the hideout, the
-- Conduit world and the war all live in this place, so a trip is a pivot. When the game is split into
-- places (Config.Places.Enabled with real ids), the same call becomes a teleport: the profile's
-- Location is set first (the far place reads it on spawn: Lifecycle wakes you where you left off),
-- ProfileService releases the session so the next server can claim it, then TeleportAsync. Every
-- caller (Hideout.Enter / Leave, War.Deploy / Leave) asks Travel first and returns if it took over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Travel = {}

local P = Config.Places
local pending = {} -- player -> true while a teleport is in flight

-- Which place key this server is (nil = the single place everything shares today).
function Travel.Here()
	if not (P and P.Enabled) then
		return nil
	end
	for key, id in P.Ids do
		if id ~= 0 and id == game.PlaceId then
			return key
		end
	end
	return nil
end

-- True when `placeKey` is somewhere else and a teleport was issued (the caller must stop; the far
-- server spawns the player from the profile). False = same place or places not enabled: carry on.
function Travel.To(player, placeKey, location)
	local here = Travel.Here()
	local id = P and P.Enabled and P.Ids[placeKey] or 0
	if id == 0 or here == placeKey or pending[player] then
		return false
	end
	local data = PlayerData.Get(player)
	if data and location then
		data.Location = location
	end
	pending[player] = true
	Remotes.Announce:FireClient(player, "Travelling...", "Info")
	task.spawn(function()
		PlayerData.Release(player) -- hand the session to the next server before leaving
		local ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			options.ShouldReserveServer = placeKey == "Hideout" -- the hideout is private: a reserved server per visitor
			TeleportService:TeleportAsync(id, { player }, options)
		end)
		if not ok then
			warn("[Travel] teleport failed:", err)
			pending[player] = nil
		end
	end)
	return true
end

function Travel.Init()
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return Travel
