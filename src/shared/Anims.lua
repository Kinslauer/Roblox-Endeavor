-- Anims: plays the game's own animations (Assets.Anims, authored in tools/anims/anims.py) on any rig.
-- Tracks are loaded once per character's Animator and cached. Used by the Endeavor client (swings, hit
-- reactions, guard) and character/Animate (idle, walk, run).
--
-- Who plays what: a client plays on its own character (the Animator replicates it to everyone) and on
-- non-player rigs (NPCs: local only, every client plays its own copy from the same combat events). It does
-- not play on other players' characters, whose own clients already do.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Anims = {}

local cache = setmetatable({}, { __mode = "k" }) -- animator -> { name -> track }

function Anims.Has(name)
	local id = Assets.Anims and Assets.Anims[name]
	return id ~= nil and id ~= 0
end

-- True when this client should animate `char` (its own, or a rig no player owns).
function Anims.Mine(char)
	if typeof(char) ~= "Instance" then
		return false
	end
	local owner = Players:GetPlayerFromCharacter(char)
	return owner == nil or owner == Players.LocalPlayer
end

local function animatorOf(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	return hum:FindFirstChildOfClass("Animator")
end

-- The loaded track for `name` on `char`, or nil (no id, no animator, or the load failed).
function Anims.Track(char, name)
	if not (Anims.Has(name) and typeof(char) == "Instance") then
		return nil
	end
	local animator = animatorOf(char)
	if not animator then
		return nil
	end
	local tracks = cache[animator]
	if not tracks then
		tracks = {}
		cache[animator] = tracks
	end
	local track = tracks[name]
	if track == nil then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(Assets.Anims[name])
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		track = if ok and t then t else false
		tracks[name] = track
	end
	return track or nil
end

-- Plays `name` on `char` if this client should. opts: fade (s), speed, weight. Returns the track or nil.
function Anims.Play(char, name, opts)
	if not Anims.Mine(char) then
		return nil
	end
	local track = Anims.Track(char, name)
	if not track then
		return nil
	end
	opts = opts or {}
	track:Play(opts.fade or 0.08, opts.weight or 1, opts.speed or 1)
	return track
end

function Anims.Stop(char, name, fade)
	local track = typeof(char) == "Instance" and Anims.Mine(char) and Anims.Track(char, name)
	if track and track.IsPlaying then
		track:Stop(fade or 0.15)
	end
end

-- Stops every cached track on `char` whose name starts with `prefix` (e.g. "Swing_").
function Anims.StopPrefix(char, prefix, fade)
	local animator = typeof(char) == "Instance" and animatorOf(char)
	local tracks = animator and cache[animator]
	if not tracks then
		return
	end
	for name, track in tracks do
		if track and name:sub(1, #prefix) == prefix and track.IsPlaying then
			track:Stop(fade or 0.15)
		end
	end
end

return Anims
