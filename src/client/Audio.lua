-- Audio (story 005, ADR-0004): one sound slot per CombatEvent kind, read from Presentation.Sounds.
-- An empty Id is silent (no warnings), so the game ships quiet and becomes audible by pasting
-- asset ids into Presentation.lua. Sounds play 3D from the emitting character's root; the local
-- player's own events also play 2D so the mix never drops out when the camera is far away.
-- Presentation only: creates and destroys Sound instances it owns, nothing else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presentation = require(Shared:WaitForChild("Presentation"))
local CombatFX = require(script.Parent.CombatFX)

local player = Players.LocalPlayer
local S = Presentation.Sounds

local Audio = {}

-- Sounds live per character so the cap is per character too (oldest is stopped when full).
local live = setmetatable({}, { __mode = "k" }) -- char -> { Sound, ... }

local function rootOf(char)
	return typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
end

local function makeSound(spec)
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume or 0.5
	local jitter = spec.PitchJitter or 0
	sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * jitter
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = S.MaxDistance
	return sound
end

local function trackAndPlay(sound, parent, char)
	local list = live[char]
	if not list then
		list = {}
		live[char] = list
	end
	while #list >= S.MaxPerChar do
		local oldest = table.remove(list, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	table.insert(list, sound)
	sound.Ended:Once(function()
		local i = table.find(list, sound)
		if i then
			table.remove(list, i)
		end
		sound:Destroy()
	end)
	sound.Parent = parent
	sound:Play()
end

-- Play the slot `kind` as coming from `char`. No-op when the slot is empty or missing.
function Audio.Play(kind, char)
	local spec = S[kind]
	if type(spec) ~= "table" or not spec.Id or spec.Id == "" then
		return
	end
	local root = rootOf(char)
	if root then
		trackAndPlay(makeSound(spec), root, char)
	end
	if char == player.Character then
		local local2d = makeSound(spec)
		local2d.Volume *= S.LocalMix
		trackAndPlay(local2d, SoundService, SoundService)
	end
end

-- CombatEvent kind -> slot name. Swing splits by label; everything else maps 1:1.
local function onSwing(char, info)
	Audio.Play(if type(info) == "table" and info.label == "Heavy" then "SwingHeavy" else "SwingLight", char)
end

function Audio.Init()
	CombatFX.On("Swing", onSwing)
	for kind in S do
		if kind ~= "SwingLight" and kind ~= "SwingHeavy" and type(S[kind]) == "table" then
			CombatFX.On(kind, function(a)
				Audio.Play(kind, a)
			end)
		end
	end
end

return Audio
