-- The hideout computer: state, apps, contracts (shared/Terminal.lua for the defs). One console per
-- hideout with the Computer module; Remotes.Terminal(action, arg) while it is open. Knowledge lives in
-- profile.Knowledge = { Uploaded, Contacts = { id = true }, Contracts = { [id] = { Done } }, Completed = n }.
-- The lore (owner, 2026-10-31): a conduit uploads their consciousness stack through the hideout computer; that
-- is initialization, and it is why permadeath is a reboot and not an end. The computer runs on the stack (your
-- brain is its operating system), so everything it learns stays with it. Until the upload, nothing does.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local F = require(Shared.Frontier)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local T = require(Shared.Terminal)
local SC = require(Shared.Clues)
local Common = script.Parent.Common
local Net = require(Common.Net)
local PlayerData = require(Common.PlayerData)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local Raids = require(script.Parent.Raids)

local Terminal = {}
local board = {} -- [id] = { Id, Kind, Title, Target, Need, Reward, Danger }
local open = {} -- player -> true while the console is open

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function knowledge(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	data.Knowledge = data.Knowledge or { Contacts = {}, Contracts = {}, Completed = 0 }
	data.Knowledge.Contacts = data.Knowledge.Contacts or {}
	data.Knowledge.Contracts = data.Knowledge.Contracts or {}
	return data.Knowledge, data
end

-- ===== the board =====
-- Rolled once the frontier layout exists: a Clear per site, a Bounty per bounty cell, the raid.
function Terminal.BuildBoard()
	board = {}
	local L = F.L
	if not L then
		return board
	end
	for _, site in L.Sites do
		local need = 0
		for _, g in site.Guards do
			need += g[2]
		end
		local reward = T.Rewards.Clear[site.Danger] or T.Rewards.Clear.High
		board["Clear_" .. site.Key] = { Id = "Clear_" .. site.Key, Kind = "Clear", Title = ("Clear %s (%s)"):format(site.Name, site.Kind), Target = site.Key, Need = need, Reward = reward, Danger = site.Danger }
	end
	for r = 2, F.Rows - 1 do
		for c = 2, F.Cols - 1 do
			local e = L.Cells[r][c].Encounter
			if e and e.Kind == "Bounty" then
				board["Bounty_" .. e.Boss:gsub("%s", "")] = { Id = "Bounty_" .. e.Boss:gsub("%s", ""), Kind = "Bounty", Title = ("Bounty: %s, somewhere in the valley"):format(e.Boss), Target = e.Boss, Need = 1, Reward = T.Rewards.Bounty, Danger = "Severe" }
			end
		end
	end
	board.Raid = { Id = "Raid", Kind = "Raid", Title = "Clear the Blackout raid", Target = "Any", Need = 1, Reward = T.Rewards.Raid, Danger = "High" }
	return board
end

function Terminal.Board()
	return board
end

-- ===== state =====
function Terminal.State(player)
	local k, data = knowledge(player)
	if not k then
		return nil
	end
	local apps = {}
	for id, c in T.Contacts do
		apps[c.App] = k.Contacts[id] == true
	end
	local contracts = {}
	for id, def in board do
		local active = k.Contracts[id]
		table.insert(contracts, { Id = id, Title = def.Title, Kind = def.Kind, Need = def.Need, Danger = def.Danger, Credits = def.Reward.Credits,
			Active = active ~= nil, Done = active and active.Done or 0 })
	end
	table.sort(contracts, function(a, b)
		if a.Active ~= b.Active then
			return a.Active
		end
		return a.Id < b.Id
	end)
	local house, market = {}, {}
	for _, h in T.House do
		table.insert(house, { Id = h.Id, Name = h.Name, Price = h.Price })
	end
	for _, m in T.Market do
		local def = Items.Defs[m.Id]
		table.insert(market, { Id = m.Id, Name = (def and def.Name or m.Id) .. (if (m.Count or 1) > 1 then (" x%d"):format(m.Count) else ""), Price = m.Price })
	end
	-- ARCHIVE: what this conduit has read, in the order read
	local archive = {}
	for id, order in k.Fragments or {} do
		local def = SC.Fragments[id]
		if def then
			table.insert(archive, { Id = id, Name = def.Name, Text = def.Text, Order = order })
		end
	end
	table.sort(archive, function(a, b)
		return a.Order < b.Order
	end)
	return { Uploaded = k.Uploaded == true, Apps = apps, Contracts = contracts, House = house, Market = market, Archive = archive, Credits = data.War.Credits or 0, Completed = k.Completed or 0, MaxActive = T.MaxActive,
		Locked = { RAIDS = "find the Broker", HOUSE = "find the Fixer", MARKET = "find the Dealer" } }
end

function Terminal.Push(player)
	if open[player] then
		local state = Terminal.State(player)
		if state then
			Remotes.World:FireClient(player, "Terminal", state)
		end
	end
end

-- The first log-in is the stack upload: initialization. Before it the console shows nothing but the prompt
-- to upload; after it the computer runs on you, and permadeath only reboots what you uploaded.
function Terminal.Upload(player)
	local k = knowledge(player)
	if not k or k.Uploaded then
		return false
	end
	k.Uploaded = true
	-- the machine talks like a machine; what it means is for the player to work out
	announce(player, "> INIT 1/1 . . . STACK READ . . . RESIDENT", "Emergence")
	Terminal.Push(player)
	return true
end

function Terminal.Open(player)
	open[player] = true
	local k = knowledge(player)
	if k and not k.Uploaded then
		Terminal.Upload(player)
	end
	Terminal.Push(player)
end

function Terminal.Close(player)
	open[player] = nil
	Remotes.World:FireClient(player, "TerminalClose")
end

-- ===== contacts =====
function Terminal.Meet(player, contactId)
	local c = T.Contacts[contactId]
	local k = knowledge(player)
	if not c or not k then
		return
	end
	-- the line is the cycle's draw (server/Cycle.lua), the fixed one until the first draw
	local i = workspace:GetAttribute("CycleLine_" .. contactId)
	local line = (SC.Lines[contactId] and SC.Lines[contactId][i or 0] and SC.Lines[contactId][i][1]) or c.Line
	announce(player, ("%s: \"%s\""):format(c.Name, line), "Info")
	if not k.Contacts[contactId] then
		k.Contacts[contactId] = true
		task.delay(3, function()
			announce(player, ("> %s: ONLINE"):format(c.App), "Reward")
		end)
	end
	Terminal.Push(player)
end

-- ===== contracts =====
local function activeCount(k)
	local n = 0
	for _ in k.Contracts do
		n += 1
	end
	return n
end

function Terminal.Accept(player, id)
	local k = knowledge(player)
	local def = board[id]
	if not k or not def then
		return false, "No such contract"
	end
	if not k.Contacts.Broker then
		return false, "RAIDS is locked: find the Broker"
	end
	if k.Contracts[id] then
		return false, "Already on your board"
	end
	if activeCount(k) >= T.MaxActive then
		return false, ("You can hold %d contracts"):format(T.MaxActive)
	end
	k.Contracts[id] = { Done = 0 }
	announce(player, "Contract accepted: " .. def.Title, "Info")
	Terminal.Push(player)
	return true
end

function Terminal.Abandon(player, id)
	local k = knowledge(player)
	if k and k.Contracts[id] then
		k.Contracts[id] = nil
		announce(player, "Contract dropped.", "Info")
		Terminal.Push(player)
		return true
	end
	return false, "Not on your board"
end

-- Intel from a dead rival: a contract you do not hold lands on your board, app or no app.
function Terminal.Intel(player)
	local k = knowledge(player)
	if not k then
		return nil
	end
	local candidates = {}
	for id in board do
		if not k.Contracts[id] then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 or activeCount(k) >= T.MaxActive then
		return nil
	end
	local id = candidates[math.random(1, #candidates)]
	k.Contracts[id] = { Done = 0, Intel = true }
	announce(player, "Rival intel: " .. board[id].Title .. " is on your board.", "Reward")
	Terminal.Push(player)
	return id
end

local function complete(player, k, id)
	local def = board[id]
	k.Contracts[id] = nil
	k.Completed = (k.Completed or 0) + 1
	local data = PlayerData.Get(player)
	if data then
		data.War.Credits = (data.War.Credits or 0) + def.Reward.Credits
	end
	for itemId, n in def.Reward.Items or {} do
		Inventory.Add(player, itemId, n)
	end
	announce(player, ("Contract complete: %s. +%d credits."):format(def.Title, def.Reward.Credits), "Reward")
	Remotes.Announce:FireAllClients(("%s completed a contract: %s"):format(player.DisplayName or player.Name, def.Title), "Kill")
	Terminal.Push(player)
end

local function progress(player, kind, target, n)
	local k = knowledge(player)
	if not k then
		return
	end
	for id, state in k.Contracts do
		local def = board[id]
		if def and def.Kind == kind and (def.Target == target or def.Target == "Any") then
			state.Done = (state.Done or 0) + n
			if state.Done >= def.Need then
				complete(player, k, id)
			else
				announce(player, ("%s: %d/%d"):format(def.Title, state.Done, def.Need), "Info")
			end
		end
	end
end
Terminal.Progress = progress

-- ===== house and market =====
local function pay(player, price)
	local data = PlayerData.Get(player)
	if not data then
		return false, "No profile"
	end
	if (data.War.Credits or 0) < price then
		return false, ("Not enough credits (%d needed)"):format(price)
	end
	data.War.Credits -= price
	return true
end

function Terminal.Order(player, id)
	local k = knowledge(player)
	if not k or not k.Contacts.Fixer then
		return false, "HOUSE is locked: find the Fixer"
	end
	for _, h in T.House do
		if h.Id == id then
			local ok, why = pay(player, h.Price)
			if not ok then
				return false, why
			end
			for itemId, n in h.Items do
				Inventory.Add(player, itemId, n)
			end
			announce(player, ("Delivered: %s"):format(h.Name), "Reward")
			Terminal.Push(player)
			return true
		end
	end
	return false, "Not in the catalogue"
end

function Terminal.Buy(player, id)
	local k = knowledge(player)
	if not k or not k.Contacts.Dealer then
		return false, "MARKET is locked: find the Dealer"
	end
	for _, m in T.Market do
		if m.Id == id then
			local ok, why = pay(player, m.Price)
			if not ok then
				return false, why
			end
			Inventory.Add(player, id, m.Count or 1)
			announce(player, ("Bought %s for %d credits"):format(Items.Defs[id] and Items.Defs[id].Name or id, m.Price), "Reward")
			Terminal.Push(player)
			return true
		end
	end
	return false, "Not for sale"
end

function Terminal.Init()
	Net.On("Terminal", { rate = 5, burst = 8, args = { "string", "string?" } }, function(player, action, arg)
		if action == "Close" then
			return Terminal.Close(player)
		end
		if not open[player] then
			return announce(player, "You are not at a computer.", "Warning")
		end
		local fn = ({ Accept = Terminal.Accept, Abandon = Terminal.Abandon, Order = Terminal.Order, Buy = Terminal.Buy })[action]
		if fn then
			local ok, why = fn(player, tostring(arg))
			if not ok and why then
				announce(player, why, "Warning")
			end
		end
	end)
	-- kills at a site, bounties, rivals
	NPCs.Killed.Event:Connect(function(typeName, model, killer)
		if not killer then
			return
		end
		local site = model:GetAttribute("Site")
		if site then
			progress(killer, "Clear", site, 1)
		end
		if model:GetAttribute("Bounty") then
			progress(killer, "Bounty", model.Name, 1)
		end
		if typeName == "Rival" then
			Terminal.Intel(killer)
		end
	end)
	Raids.Completed.Event:Connect(function(members)
		for _, p in members do
			progress(p, "Raid", "Any", 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		open[player] = nil
	end)
end

return Terminal
