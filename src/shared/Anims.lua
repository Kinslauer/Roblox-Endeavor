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

local cache = setmetatable({}, { __mode = "k" }) -- animator -> { name -> track }
local used = setmetatable({}, { __mode = "k" }) -- animator -> { name -> os.clock() of the last ask }

-- Roblox refuses to play anything on an Animator that holds more than 64 loaded tracks (2026-11-14: a long run
-- through the station, the city and the shaft loaded over 64 on the player and every animation, idle and walk
-- included, stopped playing). This cache holds at most CAP of them per Animator: past it, the track asked for
-- least recently that is not playing is destroyed (and reloaded if it is wanted again). character/Animate and
-- client/Movement hold about 15 more of their own.
local CAP = 36
Anims.Cap = CAP

local function evict(animator, tracks)
	local count = 0
	for _, t in tracks do
		if t then
			count += 1
		end
	end
	local times = used[animator] or {}
	while count >= CAP do
		local oldest, at = nil, math.huge
		for name, t in tracks do
			if t and not t.IsPlaying and (times[name] or 0) < at then
				oldest, at = name, times[name] or 0
			end
		end
		if not oldest then
			return -- everything held is playing: load anyway rather than cut one off
		end
		pcall(function()
			tracks[oldest]:Destroy()
		end)
		tracks[oldest] = nil
		count -= 1
	end
end

-- The number of tracks this module holds on `char`'s Animator (tests).
function Anims.Loaded(char)
	local animator = typeof(char) == "Instance" and animatorOf(char)
	local tracks = animator and cache[animator]
	local n = 0
	for _, t in tracks or {} do
		if t then
			n += 1
		end
	end
	return n
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
		used[animator] = {}
	end
	used[animator][name] = os.clock()
	local track = tracks[name]
	if track == nil then
		evict(animator, tracks)
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
