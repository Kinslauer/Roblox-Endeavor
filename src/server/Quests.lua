local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)
local Stats = require(script.Parent.Stats)
local Inventory = require(script.Parent.Inventory)

local Quests = {}

-- Kind: collect (item id) | kill (NPC type, or "Player") | craft (item id)
Quests.Defs = {
	{ Id = "scrap_run", Title = "Scrap Run: gather 8 Scrap Metal", Kind = "collect", Target = "Scrap", Count = 8, Reward = { Xp = 60, Items = { Cloth = 2 } } },
	{ Id = "raider_cull", Title = "Thin the Raiders: defeat 3", Kind = "kill", Target = "Raider", Count = 3, Reward = { Xp = 120, Items = { Medkit = 1 } } },
	{ Id = "field_medic", Title = "Field Medic: craft a Medkit", Kind = "craft", Target = "Medkit", Count = 1, Reward = { Xp = 50, Items = { Ration = 2 } } },
	{ Id = "bounty", Title = "Bounty: eliminate another conduit", Kind = "kill", Target = "Player", Count = 1, Reward = { Xp = 250, Items = { ShockBaton = 1 } } },
	{ Id = "survey", Title = "Survey: enter 3 districts", Kind = "explore", Target = "District", Count = 3, Reward = { Xp = 90, Items = { Ration = 2, Wire = 2 } } },
	{ Id = "brute", Title = "Heavy Metal: bring down a Brute", Kind = "kill", Target = "Brute", Count = 1, Reward = { Xp = 150, Items = { Scrap = 8 } } },
	{ Id = "raid", Title = "Breach: clear a Blackout raid", Kind = "raid", Target = "Any", Count = 1, Reward = { Xp = 300, Items = { Medkit = 2 } } },
}

local byId = {}
for _, def in Quests.Defs do
	byId[def.Id] = def
end

function Quests.Push(player)
	local profile = PlayerData.Get(player)
	local quest = profile and profile.Quest
	if quest then
		local def = byId[quest.Id]
		Remotes.QuestChanged:FireClient(player, def.Title, quest.Progress, def.Count)
	else
		Remotes.QuestChanged:FireClient(player, nil)
	end
end

function Quests.Assign(player, avoidId)
	local profile = PlayerData.Get(player)
	if not profile or profile.Quest then
		return
	end
	local pool = {}
	for _, def in Quests.Defs do
		if def.Id ~= avoidId then
			table.insert(pool, def)
		end
	end
	local def = pool[math.random(#pool)]
	profile.Quest = { Id = def.Id, Progress = 0 }
	Quests.Push(player)
end

function Quests.Progress(player, kind, target, amount)
	local profile = PlayerData.Get(player)
	local quest = profile and profile.Quest
	if not quest then
		return
	end
	local def = byId[quest.Id]
	if def.Kind ~= kind or def.Target ~= target then
		return
	end
	quest.Progress = math.min(def.Count, quest.Progress + amount)
	if quest.Progress >= def.Count then
		profile.Quest = nil
		Stats.AddXp(player, def.Reward.Xp)
		Inventory.AddAll(player, def.Reward.Items)
		Remotes.Announce:FireClient(player, "Quest complete: " .. def.Title, "Info")
		Quests.Assign(player, def.Id)
	else
		Quests.Push(player)
	end
end

function Quests.Init()
	Inventory.Added.Event:Connect(function(player, itemId, count)
		Quests.Progress(player, "collect", itemId, count)
	end)
	Inventory.Crafted.Event:Connect(function(player, itemId, count)
		Quests.Progress(player, "craft", itemId, count)
	end)
end

return Quests
