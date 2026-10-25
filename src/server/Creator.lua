-- Character creator, server half. The client sends catalog *indices*; we sanitize, store them
-- in the profile and re-skin the live character so the player previews on their real body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Rig = require(script.Parent.Rig)
local RateLimit = require(script.Parent.RateLimit)
local Config = require(ReplicatedStorage.Shared.Config)

local Creator = {}

local TIMEOUT = 180 -- an AFK player keeps whatever they had selected
local pending = {} -- [player] = true while the creator is open
local applying, queued = {}, {} -- latest-wins preview queue per player

local function preview(player)
	if applying[player] then
		return
	end
	applying[player] = true
	while queued[player] do
		local look = queued[player]
		queued[player] = nil
		Rig.Apply(player.Character, look)
	end
	applying[player] = nil
end

-- Opens the creator for a player who has not made a character yet. Yields until confirmed.
function Creator.Run(player)
	local data = PlayerData.Get(player)
	if not data or data.AppearanceSet then
		return
	end
	pending[player] = true
	Remotes.OpenCreator:FireClient(player, data.Appearance)
	local deadline = os.clock() + TIMEOUT
	while pending[player] and player.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	if pending[player] then -- timed out: keep whatever was selected
		pending[player] = nil
		data.AppearanceSet = true
	end
	if player.Parent then
		Remotes.OpenCreator:FireClient(player, nil) -- always close, whichever way it ended
	end
end

function Creator.Init()
	Remotes.SetAppearance.OnServerEvent:Connect(RateLimit.Wrap("SetAppearance", Config.RateLimit.SetAppearance, function(player, look, confirm)
		local data = PlayerData.Get(player)
		if not data or not pending[player] then
			return -- appearance is permanent once chosen (permadeath wipes it with the character)
		end
		data.Appearance = Appearance.Sanitize(look)
		queued[player] = data.Appearance
		task.spawn(preview, player)
		if confirm == true then
			data.AppearanceSet = true
			pending[player] = nil
		end
	end))
	Players.PlayerRemoving:Connect(function(player)
		pending[player], applying[player], queued[player] = nil, nil, nil
	end)
end

return Creator
