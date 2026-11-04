-- Body: the Conduit's body. Players spawn as StarterPlayer.StarterCharacter, built here at startup from the
-- Blender rig (tools/models/conduit.py -> Assets.Rigs.Conduit) through Rigs.Build, so they wear the game's
-- look instead of their Roblox avatar and keep Motor6D joints (the client's swing/block/flinch poses).
-- Each life gets its own colours (profile.Look, rolled when missing; permadeath wipes it), so a reboot
-- comes back recognisably different. Its walk/idle/jump animations come from character/Animate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local PlayerData = require(script.Parent.Common.PlayerData)
local Rigs = require(script.Parent.Rigs)

local Body = {}
local B = Config.Body

-- Builds the StarterCharacter. Returns true when players will spawn as the Conduit body.
function Body.Init()
	local id = Assets.Rigs.Conduit
	if not id or id == 0 then
		return false
	end
	local model, hum, root = Rigs.Build(id, "StarterCharacter")
	if not model then
		warn("[Body] the Conduit body did not build; players keep their avatars")
		return false
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- the client's nameplates draw names
	root.Anchored = false
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	model.Parent = StarterPlayer
	print("[Body] players spawn as the Conduit body")
	return true
end

-- This life's colours: jacket, trim (seams, armband, stack port) and visor.
function Body.Look(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	if not data.Look then
		local rng = Random.new()
		data.Look = { Jacket = rng:NextInteger(1, #B.Jackets), Trim = rng:NextInteger(1, #B.Trims) }
	end
	return data.Look
end

-- Paints a freshly loaded character with this life's colours.
function Body.Apply(player, char)
	local look = Body.Look(player)
	if not (look and char) then
		return
	end
	local jacket = B.Jackets[look.Jacket] or B.Jackets[1]
	local trim = B.Trims[look.Trim] or B.Trims[1]
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			local mat = p:GetAttribute("Mat")
			if mat == "ConduitJacket" then
				p.Color = jacket
			elseif mat == "ConduitTrim" or mat == "ConduitVisor" then
				p.Color = trim
				local light = p:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = trim
				end
			end
		end
	end
	char:SetAttribute("Look", ("%d/%d"):format(look.Jacket, look.Trim))
end

return Body
