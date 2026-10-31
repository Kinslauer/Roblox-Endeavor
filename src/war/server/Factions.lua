-- Factions and the scales. Tickets are global (a DataStore shared by every Front server) and
-- decay a little every tick, so the balance keeps tipping and no side ever "wins" for good.
-- Each faction's share of the scales sets how fast its conduits earn credits.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)
local Recruit = require(script.Parent.Common.Recruit)

local W = Config.War
local Factions = {}
Factions.IsDeployed = function(player) return true end -- replaced by Soldiers.Init
Factions.Changed = Instance.new("BindableEvent") -- (scales)

-- The global scales live in a DataStore. In an unpublished or API-disabled place the store is
-- unavailable; the scales then stay local to this server instead of taking the game down.
local store
local function getStore()
	if store == nil then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, W.Scales.StoreName)
		store = if ok then result else false
		if not ok then
			warn("[Factions] no DataStore (unpublished place or API access off): scales are local only")
		end
	end
	return store or nil
end
local scales = { Union = 1000, Pact = 1000 } -- local view; synced with the global store
local pending = { Union = 0, Pact = 0 } -- tickets earned here since the last sync

function Factions.Of(player)
	local data = PlayerData.Get(player)
	return data and data.War.Faction ~= "" and data.War.Faction or nil
end

function Factions.Assign(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local war = Recruit.Init(data.War)
	if war.Faction == "" then
		local join = player:GetJoinData()
		local td = join and join.TeleportData
		if type(td) == "table" and table.find(W.Factions, td.Faction) then
			war.Faction = td.Faction
		else
			local counts = { Union = 0, Pact = 0 }
			for _, other in Players:GetPlayers() do
				local f = Factions.Of(other)
				if f then
					counts[f] += 1
				end
			end
			war.Faction = if counts.Union <= counts.Pact then "Union" else "Pact"
		end
	end
	return war.Faction
end

function Factions.Members(faction)
	local out = {}
	for _, p in Players:GetPlayers() do
		if Factions.Of(p) == faction then
			table.insert(out, p)
		end
	end
	return out
end

function Factions.AddTickets(faction, amount)
	if scales[faction] then
		scales[faction] += amount
		pending[faction] += amount
	end
end

-- 0..1 share of the scales held by `faction`
function Factions.Share(faction)
	local total = scales.Union + scales.Pact
	return if total > 0 then scales[faction] / total else 0.5
end

function Factions.Scales()
	return { Union = scales.Union, Pact = scales.Pact, UnionShare = Factions.Share("Union") }
end

local function broadcast()
	Remotes.Scales:FireAllClients(Factions.Scales())
	Factions.Changed:Fire(Factions.Scales())
end

-- Credits per minute for a conduit of `faction`: the winning side's conduits get richer.
function Factions.IncomePerMinute(faction)
	local share = Factions.Share(faction)
	local mult = math.clamp(0.5 + W.Income.ShareWeight * (share - 0.5), 0.25, 1.75)
	return W.Income.BasePerMinute * mult
end

local function sync()
	local ds = getStore()
	if not ds then
		broadcast()
		return
	end
	local mine = { Union = pending.Union, Pact = pending.Pact }
	pending.Union, pending.Pact = 0, 0
	local ok, err = pcall(function()
		local result = ds:UpdateAsync("scales", function(old)
			old = old or { Union = 1000, Pact = 1000 }
			for f in old do
				old[f] = math.max(100, (old[f] + (mine[f] or 0)) * (1 - W.Scales.Decay))
			end
			return old
		end)
		if type(result) == "table" then
			scales.Union, scales.Pact = result.Union or scales.Union, result.Pact or scales.Pact
		end
	end)
	if not ok then
		warn("[Factions] scales sync failed:", err)
		pending.Union += mine.Union -- nothing earned is lost; it goes with the next sync
		pending.Pact += mine.Pact
	end
	broadcast()
end

function Factions.Init()
	task.spawn(function()
		while true do
			sync()
			task.wait(30 + math.random() * 15) -- jitter: every server syncing on the same beat would throttle the key
		end
	end)
	-- credit income: every 15s, each conduit earns a slice of their faction's per-minute rate
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local data, faction = PlayerData.Get(player), Factions.Of(player)
				if data and faction and Factions.IsDeployed(player) then -- income needs a recruit on the field, not a lobby
					data.War.Credits += math.floor(Factions.IncomePerMinute(faction) / 4)
					Remotes.RecruitApp:FireClient(player, Recruit.Snapshot(data.War))
				end
			end
		end
	end)
end

return Factions
