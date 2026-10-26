-- The hideout computer (Phase 3, build order 6; design/gdd/raids.md): one console, three apps.
--   RAIDS  - the board (server/Raids.lua): take a contract, drop the one you are on
--   HOUSE  - furnishings for the hideout, for money; rendered for their owner by the client (House attr)
--   MARKET - the black market: gear the enclave's trader does not carry, for money
-- An app is locked until its contact has been met in the world (server/Contacts.lua → Terminal.Meet).
-- The client shows a panel while the Terminal attribute is set (Hideout's console sets it, walking
-- out or Close clears it); every change re-pushes one state table (Remotes.TerminalChanged).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Lore = require(Shared.Lore)
local R = require(Shared.Raids)
local SC = require(Shared.Clues)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local PlayerData = require(script.Parent.PlayerData)
local Raids = require(script.Parent.Raids)
local RateLimit = require(script.Parent.RateLimit)
local Wallet = require(script.Parent.Wallet)

local Terminal = {}

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function houseDef(id)
	for _, h in R.House do
		if h.Id == id then
			return h
		end
	end
	return nil
end

local function marketPrice(id)
	for _, m in R.Market do
		if m.Id == id then
			return m.Price
		end
	end
	return nil
end

-- One table the panel renders from.
function Terminal.State(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local board = {}
	for i, entry in Raids.Board(player) do
		local t = R.ById[entry.Id]
		if t then
			local reward = t.Reward
			table.insert(board, { Index = i, Name = t.Name, Text = t.Text, Money = reward.Money or 0, Xp = reward.Xp or 0, Steps = #t.Steps, FromIntel = entry.FromIntel == true, Locked = not (entry.FromIntel or (data.Contacts and data.Contacts[t.Contact or "Broker"])) })
		end
	end
	local raid = data.Raid
	local raidState = nil
	if raid then
		local step = raid.Steps[raid.Step]
		raidState = { Name = R.ById[raid.Id].Name, Line = player:GetAttribute("RaidLine") or "", Step = raid.Step, Steps = #raid.Steps, Chain = #raid.Chain, Lead = step and step.Lead and R.ById[step.Lead].Name or nil }
	end
	local house = {}
	for _, h in R.House do
		table.insert(house, { Id = h.Id, Name = h.Name, Price = h.Price, Owned = data.House and data.House[h.Id] == true })
	end
	local market = {}
	for _, m in R.Market do
		local def = Items.Defs[m.Id]
		if def then
			table.insert(market, { Id = m.Id, Name = def.Name, Price = m.Price })
		end
	end
	-- ARCHIVE: what the conduit has read, in the order found (shared/Clues.lua; server/Clues.lua)
	local archive = {}
	for id, order in data.Knowledge or {} do
		local f = SC.Fragments[id]
		if f then
			table.insert(archive, { Order = order, Name = f.Name, Text = f.Text })
		end
	end
	table.sort(archive, function(a, b)
		return a.Order < b.Order
	end)
	return {
		Contacts = { Broker = data.Contacts.Broker == true, Fixer = data.Contacts.Fixer == true, Dealer = data.Contacts.Dealer == true },
		Board = board, Raid = raidState, House = house, Market = market, Money = Wallet.Get(player), Archive = archive,
	}
end

function Terminal.Push(player)
	local state = Terminal.State(player)
	if state then
		Remotes.TerminalChanged:FireClient(player, state)
	end
end

local function publishHouse(player, data)
	player:SetAttribute("House", HttpService:JSONEncode(data.House or {}))
end

function Terminal.Sync(player)
	local data = PlayerData.Get(player)
	if data then
		publishHouse(player, data)
		player:SetAttribute("Computer", data.Computer == true) -- the client draws the desk empty or lit (HouseView)
	end
end

-- A contact met in the world: the app opens.
function Terminal.Meet(player, contactId)
	local data = PlayerData.Get(player)
	local c = R.Contacts[contactId]
	if not (data and c) then
		return false
	end
	data.Contacts = data.Contacts or {}
	-- what they say this cycle (server/Clues.lua draws it); the first meeting is always their introduction
	local pool, idx = SC.Lines[contactId], workspace:GetAttribute("CycleLine_" .. contactId)
	local line = if data.Contacts[contactId] and pool and idx and pool[idx] then pool[idx][1] else c.Line
	if data.Contacts[contactId] then
		announce(player, ("%s: \"%s\""):format(c.Name, line), "Info")
		return false
	end
	local first = next(data.Contacts) == nil
	data.Contacts[contactId] = true
	announce(player, ("%s: \"%s\""):format(c.Name, line), "Info")
	task.delay(2, function()
		announce(player, if data.Computer then ("%s unlocked on your computer."):format(c.App)
			else ("You'll need a computer of your own for %s. Until then you only remember the way."):format(c.App), "Info")
		if first then
			task.delay(2, function()
				announce(player, Lore.Get("FirstContact"), "Lore")
			end)
		end
	end)
	Terminal.Push(player)
	return true
end

-- Install a Home Computer at the empty desk: the upload (design/gdd/dematerialization.md §6). From here the
-- mind is backed up - contacts met, knowledge, the board and the house survive a permadeath.
function Terminal.Install(player)
	local data = PlayerData.Get(player)
	if not data or data.Computer or not Inventory.Remove(player, "HomeComputer", 1) then
		return false
	end
	data.Computer = true
	Terminal.Sync(player)
	announce(player, Lore.Get("Upload"), "Lore")
	local apps = {}
	for id in data.Contacts or {} do
		local c = R.Contacts[id]
		if c then
			table.insert(apps, c.App)
		end
	end
	if #apps > 0 then
		task.delay(2, function()
			announce(player, ("%s on your computer."):format(table.concat(apps, ", ")), "Info")
		end)
	end
	return true
end

function Terminal.Open(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if not data.Computer then
		if Inventory.Count(player, "HomeComputer") > 0 then
			Terminal.Install(player)
		else
			if not data.EmptyDeskSeen then
				data.EmptyDeskSeen = true
				announce(player, Lore.Get("EmptyDesk"), "Lore")
			end
			announce(player, "The desk is empty. Find a working computer out there, or build one (Tab).", "Info")
			return
		end
	end
	player:SetAttribute("Terminal", true)
	Terminal.Push(player)
end

function Terminal.Close(player)
	player:SetAttribute("Terminal", nil)
end

-- HOUSE: buy a furnishing once.
function Terminal.Order(player, id)
	local data = PlayerData.Get(player)
	local h = houseDef(id)
	if not (data and h) then
		return false
	end
	if not data.Contacts.Fixer then
		announce(player, "You have not met anyone who sells for the house.")
		return false
	end
	data.House = data.House or {}
	if data.House[id] then
		return false
	end
	if not Wallet.Spend(player, h.Price) then
		announce(player, ("Not enough money (%d)."):format(h.Price))
		return false
	end
	data.House[id] = true
	publishHouse(player, data)
	announce(player, ("Ordered: %s. It is in your hideout."):format(h.Name), "Info")
	Terminal.Push(player)
	return true
end

-- MARKET: the black market.
function Terminal.Buy(player, id)
	local data = PlayerData.Get(player)
	local price = marketPrice(id)
	if not (data and price and Items.Defs[id]) then
		return false
	end
	if not data.Contacts.Dealer then
		announce(player, "You have not met the dealer.")
		return false
	end
	if not Wallet.Spend(player, price) then
		announce(player, ("Not enough money (%d)."):format(price))
		return false
	end
	Inventory.Add(player, id, 1)
	announce(player, ("Black market: %s for %d."):format(Items.Defs[id].Name, price), "Info")
	Terminal.Push(player)
	return true
end

-- Remotes.Terminal(action, arg): only while the terminal is open (the console set the attribute).
local function onTerminal(player, action, arg)
	if action == "Close" then
		Terminal.Close(player)
		return
	end
	if not player:GetAttribute("Terminal") then
		return
	end
	if action == "Accept" and type(arg) == "number" then
		if Raids.Accept(player, arg) then
			local data = PlayerData.Get(player)
			if data and not data.RaidSeen then
				data.RaidSeen = true
				announce(player, Lore.Get("FirstRaid"), "Lore")
			end
		end
	elseif action == "Abandon" then
		Raids.Abandon(player)
	elseif action == "Order" and type(arg) == "string" then
		Terminal.Order(player, arg)
	elseif action == "Buy" and type(arg) == "string" then
		Terminal.Buy(player, arg)
	elseif action == "Refresh" then
		Terminal.Push(player)
	end
end

function Terminal.Init()
	Remotes.Terminal.OnServerEvent:Connect(RateLimit.Wrap("Terminal", Config.RateLimit.Terminal, onTerminal))
	Raids.Changed.Event:Connect(function(player)
		if player:GetAttribute("Terminal") then
			Terminal.Push(player)
		end
	end)
end

return Terminal
