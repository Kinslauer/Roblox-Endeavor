-- One character per player. Permadeath = this profile is deleted.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local store = DataStoreService:GetDataStore("ConduitCharacter_v1")
local profiles = {}
local loadFailed = {} -- never overwrite a save we failed to read

local PlayerData = {}

local function newProfile()
	local stats = {}
	for _, name in Config.Stats.Names do
		stats[name] = 0
	end
	return {
		Stats = stats,
		FreePoints = Config.Stats.StartingPoints,
		Level = 1,
		Xp = 0,
		Kills = 0,
		BornAt = os.time(),
		Awakened = false,
		Equipped = "Fists",
		Inventory = { PipeClub = 1, Scrap = 3, Ration = 1 },
		Quest = nil, -- { Id, Progress }
	}
end

local function reconcile(data)
	local template = newProfile()
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		end
	end
	for _, name in Config.Stats.Names do
		data.Stats[name] = data.Stats[name] or 0
	end
	return data
end

local function key(player)
	return "Char_" .. player.UserId
end

function PlayerData.Load(player)
	local ok, data = pcall(function()
		return store:GetAsync(key(player))
	end)
	if not ok then
		warn("[PlayerData] load failed for", player.Name, data)
		loadFailed[player] = true
		data = nil
	end
	profiles[player] = if data then reconcile(data) else newProfile()
	return profiles[player]
end

function PlayerData.Get(player)
	return profiles[player]
end

function PlayerData.Save(player)
	local profile = profiles[player]
	if not profile or loadFailed[player] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), profile)
	end)
	if not ok then
		warn("[PlayerData] save failed for", player.Name, err)
	end
end

-- Permadeath: delete the saved character and hand back a fresh one.
function PlayerData.Reset(player)
	profiles[player] = newProfile()
	if not loadFailed[player] then
		task.spawn(function()
			local ok, err = pcall(function()
				store:RemoveAsync(key(player))
			end)
			if not ok then
				warn("[PlayerData] wipe failed for", player.Name, err)
			end
		end)
	end
	return profiles[player]
end

-- Wipe without re-creating (used when the player already left).
function PlayerData.Delete(player)
	profiles[player] = nil
	pcall(function()
		store:RemoveAsync(key(player))
	end)
end

function PlayerData.Release(player)
	profiles[player] = nil
	loadFailed[player] = nil
end

function PlayerData.Init()
	task.spawn(function()
		while true do
			task.wait(60)
			for player in profiles do
				task.spawn(PlayerData.Save, player)
			end
		end
	end)
end

return PlayerData
