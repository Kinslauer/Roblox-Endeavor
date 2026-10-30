-- One character per player, persisted with ProfileService (session-locked, auto-saved).
-- Permadeath = the profile's data is reset in place; the account keeps nothing but a new character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileService = require(script.Parent.ProfileService)

-- NOTE: ProfileService:Reconcile() re-adds any missing key from this template, so anything a
-- player can legitimately remove (inventory items, armor slots, skill slots) must NOT have
-- defaults here. Starting gear is granted once by newCharacter() instead.
local TEMPLATE = {
	Created = false,
	Stats = {},
	FreePoints = Config.Stats.StartingPoints,
	Level = 1,
	Xp = 0,
	Kills = 0,
	BornAt = 0,
	Awakened = false,
	TutorialDone = false,
	Equipped = "Fists",
	Armor = {}, -- [slot] = itemId
	Cyber = {}, -- [slot] = itemId
	SkillSlots = {}, -- ["1"] = skillId (string keys so the table stays a dictionary)
	Inventory = {},
	-- The war world (a separate place, same universe) reads and writes this part of the profile.
	-- A conduit is not reset by the recruit dying; the recruit's gear is.
	War = {
		Faction = "", -- "Union" | "Pact", chosen on first deployment
		Credits = 0, -- faction money; income scales with the faction's share of the scales
		Locker = {}, -- [itemId] = { count = n, condition = 0-100 } gear owned for recruits
		Loadout = {}, -- the next recruit's order: { Primary, Sidearm, Armor, Cyber, Attachments = {} }
		Deployments = 0,
		RecruitKills = 0,
		RecruitDeaths = 0,
	},
}
for _, name in Config.Stats.Names do
	TEMPLATE.Stats[name] = 0
end

local store = ProfileService.GetProfileStore("ConduitCharacter_v2", TEMPLATE)
local profiles = {}

local PlayerData = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function newCharacter(data)
	data.Created = true
	data.BornAt = os.time()
	data.Inventory = { PipeClub = 1, Scrap = 3, Ration = 1 }
	data.Equipped = "PipeClub"
end

-- Permadeath wipes the conduit; the war-world account (faction, credits, locker) survives it,
-- because a recruit is a thing the conduit owns, not the conduit itself.
local function wipe(data)
	local war = data.War
	for key in data do
		data[key] = nil
	end
	for key, value in TEMPLATE do
		data[key] = deepCopy(value)
	end
	data.War = war or deepCopy(TEMPLATE.War)
	newCharacter(data)
end

-- Yields. Returns the profile data table, or nil if the player was kicked / left.
function PlayerData.Load(player)
	local profile = store:LoadProfileAsync("Char_" .. player.UserId, "ForceLoad")
	if not profile then
		player:Kick("Could not load your character. Please rejoin.")
		return nil
	end
	profile:Reconcile()
	profile:ListenToRelease(function()
		profiles[player] = nil
		player:Kick("Your character was loaded in another session.")
	end)
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return nil
	end
	profiles[player] = profile
	if not profile.Data.Created then
		newCharacter(profile.Data)
	end
	return profile.Data
end

function PlayerData.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Permadeath: same table, fresh character.
function PlayerData.Reset(player)
	local profile = profiles[player]
	if profile then
		wipe(profile.Data)
		return profile.Data
	end
	return nil
end

function PlayerData.Release(player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:Release()
	end
end

return PlayerData
