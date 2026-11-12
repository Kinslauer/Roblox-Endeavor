-- The bay's economy (round 6 of docs/Reference-Picks-Plan.md; ideas from Tarkov's hideout and flea market, nothing
-- copied). Tuning: Config.World.{Craft, Fuel, Condenser, Loyalty, Exchange, Drop}.
--   Fuel       a built generator runs on h.Fuel (seconds). The turret and alarm burn Fuel.Idle a second and work
--              only while it runs; at zero the bay's lights flicker (the bay model's attribute Dark, client/Bay).
--              A fuel can is loaded at the generator (X).
--   Crafting   weapons, armour and cybernetics are made at the bench over time (Craft.Seconds x the tier's
--              TierMult); a running generator doubles the pace and burns FuelPerSecond. One job per bay, done
--              into the vault (else the crafter's pack). Packs, ammo and consumables stay instant (Inventory.Craft).
--   Condenser  a module that makes a ration every Condenser.Period of real time, up to Cap, while you are away too.
--   Loyalty    every credit spent with a contact and every contract closed raises Knowledge.Loyalty[contact];
--              some goods and the swaps need a level.
--   Exchange   other conduits' listings, on the computer. Only items found in a run can be listed: loot taken
--              from containers is counted in data.FoundRun and becomes sellable (h.Found) once banked at home.
--              A listing shows only while its seller is online; the seller pays Fee up front; each sale is a
--              point of reputation and more slots.
--   Drop       the Fixer sends a Line 9 consignment to your bay's freight lift for a price, once a cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local TerminalDefs = require(Shared.Terminal)
local PlayerData = require(script.Parent.Common.PlayerData)

local W = Config.World
local Economy = {}

local function lazy(name)
	return require(script.Parent[name])
end

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function ownerOf(site)
	return site and site.Owner and Players:GetPlayerByUserId(site.Owner)
end

local function hideoutOf(site)
	local owner = ownerOf(site)
	local data = owner and PlayerData.Get(owner)
	return data and data.Hideout, owner
end

local function nameOf(id)
	local def = Items.Defs[id]
	return string.upper(def and def.Name or id)
end

-- ===== fuel =====
function Economy.Powered(site)
	local h = hideoutOf(site)
	return h ~= nil and h.Modules.Generator ~= nil and (h.Fuel or W.Fuel.Start) > 0
end

function Economy.Refuel(player, site)
	local h = hideoutOf(site)
	if not (h and h.Modules.Generator) then
		return false
	end
	local Inventory = lazy("Inventory")
	if Inventory.Count(player, "FuelCan") <= 0 then
		say(player, "> GENERATOR . NO FUEL", "Warning")
		return false
	end
	local fuel = h.Fuel or W.Fuel.Start
	if fuel >= W.Fuel.Max then
		say(player, "> GENERATOR . FULL")
		return false
	end
	Inventory.Remove(player, "FuelCan", 1)
	h.Fuel = math.min(W.Fuel.Max, fuel + W.Fuel.PerCan)
	say(player, ("> GENERATOR . %d MIN"):format(math.floor(h.Fuel / 60)), "Reward")
	Economy.Mark(site)
	return true
end

-- the bay model carries what the client needs to draw: Dark (lights flicker), Fuel, Craft, CraftLeft
function Economy.Mark(site)
	local h = hideoutOf(site)
	local model = site.Built
	if not (h and model) then
		return
	end
	local fuel = h.Fuel or W.Fuel.Start
	model:SetAttribute("Fuel", if h.Modules.Generator then fuel else nil)
	model:SetAttribute("Dark", h.Modules.Generator ~= nil and fuel <= 0)
	model:SetAttribute("Craft", h.Craft and h.Craft.Output or nil)
	model:SetAttribute("CraftLeft", h.Craft and math.ceil(h.Craft.Left) or nil)
	model:SetAttribute("Condensed", if h.Modules.Condenser then Economy.Condensed(h) else nil)
end

-- ===== timed crafting =====
function Economy.Timed(recipe)
	local def = recipe and Items.Defs[recipe.Output]
	return def ~= nil and W.Craft.Seconds[def.Type] ~= nil
end

function Economy.Queue(player, recipeId)
	local recipe = Items.Recipes[recipeId]
	if not recipe then
		return false
	end
	local Hideouts = lazy("Hideouts")
	local Inventory = lazy("Inventory")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local site = Hideouts.SiteOf(player)
	local h = hideoutOf(site)
	if not (root and h and Hideouts.AtBench(player, root.Position)) then
		say(player, "> BENCH . NEEDED", "Warning")
		return false
	end
	if h.Craft then
		say(player, ("> BENCH . BUSY . %s . %d S"):format(nameOf(h.Craft.Output), math.ceil(h.Craft.Left)), "Warning")
		return false
	end
	for itemId, count in recipe.Inputs do
		if Inventory.Count(player, itemId) < count then
			return false
		end
	end
	for itemId, count in recipe.Inputs do
		Inventory.Remove(player, itemId, count)
	end
	local def = Items.Defs[recipe.Output]
	local seconds = W.Craft.Seconds[def.Type] * (W.Craft.TierMult[h.Tier] or 1)
	h.Craft = { Recipe = recipeId, Output = recipe.Output, Count = recipe.Count, Left = seconds, Total = seconds, By = player.UserId }
	say(player, ("> BENCH . %s . %d S"):format(nameOf(recipe.Output), math.ceil(seconds)))
	Economy.Mark(site)
	Inventory.Push(player)
	return true
end

local function craftDone(site, h, owner)
	local job = h.Craft
	h.Craft = nil
	local Inventory = lazy("Inventory")
	local crafter = Players:GetPlayerByUserId(job.By) or owner
	local left = job.Count
	if h.Modules.Vault then
		left = Inventory.PlaceIn(lazy("Hideouts").VaultBox(h), job.Output, job.Count)
		h.Vault = Inventory.CountsOf(lazy("Hideouts").VaultBox(h))
	end
	if left > 0 and crafter then
		Inventory.Add(crafter, job.Output, left)
	end
	if crafter then
		say(crafter, "> BENCH . DONE . " .. nameOf(job.Output), "Reward")
		Inventory.Crafted:Fire(crafter, job.Output, job.Count)
		pcall(lazy("Hideouts").Push, crafter)
	end
end

-- ===== the condenser =====
function Economy.Condensed(h)
	if not h.Modules.Condenser then
		return 0
	end
	h.CondenserAt = h.CondenserAt or os.time()
	return math.clamp(math.floor((os.time() - h.CondenserAt) / W.Condenser.Period), 0, W.Condenser.Cap)
end

function Economy.Drain(player, site)
	local h = hideoutOf(site)
	if not (h and h.Modules.Condenser) then
		return 0
	end
	local n = Economy.Condensed(h)
	if n <= 0 then
		say(player, "> CONDENSER . DRY")
		return 0
	end
	if n >= W.Condenser.Cap then
		h.CondenserAt = os.time() -- it stopped when the tank filled
	else
		h.CondenserAt += n * W.Condenser.Period
	end
	lazy("Inventory").Add(player, W.Condenser.Output, n)
	say(player, ("> CONDENSER . %d %s"):format(n, nameOf(W.Condenser.Output)), "Reward")
	Economy.Mark(site)
	return n
end

-- ===== contact loyalty =====
local function knowledge(player)
	local data = PlayerData.Get(player)
	return data and data.Knowledge
end

function Economy.LoyaltyPoints(player, contact)
	local k = knowledge(player)
	return k and k.Loyalty and k.Loyalty[contact] or 0
end

function Economy.Loyalty(player, contact)
	local points, level = Economy.LoyaltyPoints(player, contact), 1
	for i, need in W.Loyalty.Levels do
		if points >= need then
			level = i
		end
	end
	return level
end

function Economy.AddLoyalty(player, contact, points)
	local k = knowledge(player)
	if not k or points <= 0 then
		return
	end
	k.Loyalty = k.Loyalty or {}
	local before = Economy.Loyalty(player, contact)
	k.Loyalty[contact] = (k.Loyalty[contact] or 0) + points
	local after = Economy.Loyalty(player, contact)
	if after > before then
		say(player, ("> %s . TRUST %d"):format(string.upper(TerminalDefs.Contacts[contact] and TerminalDefs.Contacts[contact].Name or contact), after), "Reward")
	end
end

function Economy.Swap(player, id)
	local Inventory = lazy("Inventory")
	for _, s in TerminalDefs.Swaps do
		if s.Id == id then
			local k = knowledge(player)
			if not (k and k.Contacts[s.Contact]) then
				return false, "Not your contact"
			end
			if Economy.Loyalty(player, s.Contact) < (s.Loyalty or 1) then
				return false, ("> TRUST %d NEEDED"):format(s.Loyalty)
			end
			for itemId, n in s.Give do
				if Inventory.Count(player, itemId) < n then
					return false, "> NOT CARRIED"
				end
			end
			for itemId, n in s.Give do
				Inventory.Remove(player, itemId, n)
			end
			for itemId, n in s.Get do
				Inventory.Add(player, itemId, n)
			end
			Economy.AddLoyalty(player, s.Contact, s.Points or 10)
			say(player, "> SWAP . DONE", "Reward")
			return true
		end
	end
	return false, "No such swap"
end

-- ===== found in a run, and the exchange =====
function Economy.Found(player, id, n)
	local data = PlayerData.Get(player)
	if not data or n <= 0 then
		return
	end
	data.FoundRun = data.FoundRun or {}
	data.FoundRun[id] = (data.FoundRun[id] or 0) + n
end

function Economy.BankFound(player)
	local data = PlayerData.Get(player)
	if not (data and data.FoundRun) then
		return false
	end
	local h = data.Hideout
	h.Found = h.Found or {}
	for id, n in data.FoundRun do
		h.Found[id] = (h.Found[id] or 0) + n
	end
	data.FoundRun = nil
	return true
end

-- how many of an item this conduit may list: found, banked and still carried
function Economy.Sellable(player, id)
	local data = PlayerData.Get(player)
	local found = data and data.Hideout.Found and data.Hideout.Found[id] or 0
	return math.min(found, lazy("Inventory").Count(player, id))
end

function Economy.Value(id)
	local def = Items.Defs[id]
	return def and W.Exchange.Values[def.Type] or 4
end

function Economy.Slots(player)
	local data = PlayerData.Get(player)
	local rep = data and data.Hideout.Rep or 0
	local X = W.Exchange
	return math.min(X.MaxSlots, X.Slots + math.floor(rep / X.SlotsPerRep))
end

-- arg "itemId:count:step" (step = 1..#Mults: the price is the item's value x Mults[step])
function Economy.List(player, arg)
	local id, count, step = string.match(tostring(arg), "^([%w_]+):(%d+):(%d+)$")
	count, step = tonumber(count), tonumber(step)
	local data = PlayerData.Get(player)
	local X = W.Exchange
	if not (data and id and Items.Defs[id] and count and count >= 1 and step and X.Mults[step]) then
		return false, "Bad listing"
	end
	local h = data.Hideout
	h.Listings = h.Listings or {}
	if #h.Listings >= Economy.Slots(player) then
		return false, "> EXCHANGE . NO SLOT"
	end
	if Economy.Sellable(player, id) < count then
		return false, "> EXCHANGE . NOT FOUND IN A RUN"
	end
	local price = math.ceil(Economy.Value(id) * X.Mults[step]) * count
	local fee = math.ceil(price * X.Fee)
	if (data.War.Credits or 0) < fee then
		return false, ("> EXCHANGE . FEE %d CR"):format(fee)
	end
	data.War.Credits -= fee
	lazy("Inventory").Remove(player, id, count)
	h.Found[id] -= count
	if h.Found[id] <= 0 then
		h.Found[id] = nil
	end
	table.insert(h.Listings, { Id = id, Count = count, Price = price })
	say(player, ("> LISTED . %d %s . %d CR"):format(count, nameOf(id), price), "Reward")
	return true
end

function Economy.Unlist(player, arg)
	local data = PlayerData.Get(player)
	local i = tonumber(arg)
	local h = data and data.Hideout
	local l = h and h.Listings and i and h.Listings[i]
	if not l then
		return false
	end
	table.remove(h.Listings, i)
	lazy("Inventory").Add(player, l.Id, l.Count)
	h.Found = h.Found or {}
	h.Found[l.Id] = (h.Found[l.Id] or 0) + l.Count -- still found in a run: it can go back up
	return true
end

-- arg "sellerUserId:index"
function Economy.Take(player, arg)
	local sid, i = string.match(tostring(arg), "^(%d+):(%d+)$")
	local seller = sid and Players:GetPlayerByUserId(tonumber(sid))
	i = tonumber(i)
	if not seller or seller == player then
		return false, "> EXCHANGE . SELLER OFFLINE"
	end
	local sdata, data = PlayerData.Get(seller), PlayerData.Get(player)
	local l = sdata and sdata.Hideout.Listings and sdata.Hideout.Listings[i]
	if not (l and data) then
		return false, "> EXCHANGE . GONE"
	end
	if (data.War.Credits or 0) < l.Price then
		return false, ("Not enough credits (%d needed)"):format(l.Price)
	end
	data.War.Credits -= l.Price
	sdata.War.Credits = (sdata.War.Credits or 0) + l.Price
	sdata.Hideout.Rep = (sdata.Hideout.Rep or 0) + 1
	table.remove(sdata.Hideout.Listings, i)
	lazy("Inventory").Add(player, l.Id, l.Count) -- bought, not found: it cannot be listed again
	say(player, ("> BOUGHT . %d %s . %d CR"):format(l.Count, nameOf(l.Id), l.Price), "Reward")
	say(seller, ("> SOLD . %d %s . +%d CR"):format(l.Count, nameOf(l.Id), l.Price), "Reward")
	pcall(function()
		lazy("Terminal").Push(seller)
	end)
	return true
end

-- ===== the drop =====
local drops = {} -- player -> true while one is on its way

function Economy.Drop(player)
	local data = PlayerData.Get(player)
	local k = data and data.Knowledge
	if not (k and k.Contacts.Fixer) then
		return false, "HOUSE is locked: find the Fixer"
	end
	local site = lazy("Hideouts").SiteOf(player)
	if not (site and site.Built and site.LiftCFrame) then
		return false, "> DROP . NO BAY"
	end
	local D = W.Drop
	local wait = (data.Hideout.DropAt or 0) + D.Cooldown - os.time()
	if drops[player] or wait > 0 then
		return false, ("> DROP . LINE BUSY . %d S"):format(math.max(wait, 1))
	end
	if (data.War.Credits or 0) < D.Price then
		return false, ("Not enough credits (%d needed)"):format(D.Price)
	end
	data.War.Credits -= D.Price
	data.Hideout.DropAt = os.time()
	drops[player] = true
	Economy.AddLoyalty(player, "Fixer", D.Price * W.Loyalty.PerCredit)
	say(player, "> LINE 9 . CONSIGNMENT . " .. D.Delay .. " S", "Info")
	task.delay(D.Delay, function()
		drops[player] = nil
		if not (site.Built and site.LiftCFrame) then
			return
		end
		local bundle = Items.Roll("Supply")
		bundle.FuelCan = (bundle.FuelCan or 0) + 1
		local crate = lazy("Loot").Spawn(site.LiftCFrame * CFrame.new(0, 1.2, 0), bundle, { Label = "Consignment", Mesh = "CrateA", Lifetime = 1800, Size = Vector3.new(3, 2, 2), Color = Color3.fromRGB(70, 74, 66) })
		if crate then
			crate.Anchored = true
		end
		if player.Parent then
			say(player, ("> LINE 9 . BAY %02d . ARRIVED"):format(site.Index or 0), "Reward")
		end
	end)
	return true
end

-- ===== what the computer shows =====
function Economy.State(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local loyalty = {}
	for id in TerminalDefs.Contacts do
		loyalty[id] = Economy.Loyalty(player, id)
	end
	local swaps = {}
	for _, s in TerminalDefs.Swaps do
		local give, get = {}, {}
		for id, n in s.Give do
			table.insert(give, n .. " " .. (Items.Defs[id] and Items.Defs[id].Name or id))
		end
		for id, n in s.Get do
			table.insert(get, n .. " " .. (Items.Defs[id] and Items.Defs[id].Name or id))
		end
		table.insert(swaps, { Id = s.Id, Contact = s.Contact, Text = table.concat(give, ", ") .. " for " .. table.concat(get, ", "),
			Lock = if loyalty[s.Contact] < (s.Loyalty or 1) then s.Loyalty else nil })
	end
	local board = {}
	for _, p in Players:GetPlayers() do
		local pd = p ~= player and PlayerData.Get(p)
		for i, l in pd and pd.Hideout.Listings or {} do
			table.insert(board, { Key = p.UserId .. ":" .. i, Seller = p.DisplayName, Id = l.Id, Name = Items.Defs[l.Id] and Items.Defs[l.Id].Name or l.Id, Count = l.Count, Price = l.Price })
		end
	end
	local mine = {}
	for i, l in data.Hideout.Listings or {} do
		table.insert(mine, { Index = i, Name = Items.Defs[l.Id] and Items.Defs[l.Id].Name or l.Id, Count = l.Count, Price = l.Price })
	end
	local found = {}
	for id in data.Hideout.Found or {} do
		local n = Economy.Sellable(player, id)
		if n > 0 then
			table.insert(found, { Id = id, Name = Items.Defs[id] and Items.Defs[id].Name or id, Count = n, Value = Economy.Value(id) })
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	local wait = math.max(0, (data.Hideout.DropAt or 0) + W.Drop.Cooldown - os.time())
	return { Loyalty = loyalty, Swaps = swaps, Board = board, Mine = mine, Found = found, Slots = Economy.Slots(player), Rep = data.Hideout.Rep or 0,
		Mults = W.Exchange.Mults, Fee = W.Exchange.Fee, Drop = { Price = W.Drop.Price, Wait = if drops[player] then -1 else wait } }
end

function Economy.Init()
	local Hideouts = lazy("Hideouts")
	Hideouts.Powered = Economy.Powered
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, site in Hideouts.Sites do
				local h, owner = hideoutOf(site)
				if h then
					local powered = Economy.Powered(site)
					if powered then
						local burn = if h.Modules.Turret or h.Modules.Alarm then W.Fuel.Idle * dt else 0
						if h.Craft then
							burn += W.Craft.FuelPerSecond * dt
						end
						h.Fuel = math.max(0, (h.Fuel or W.Fuel.Start) - burn)
					end
					if h.Craft then
						h.Craft.Left -= dt * (if powered then 2 else 1)
						if h.Craft.Left <= 0 then
							craftDone(site, h, owner)
						end
					end
					Economy.Mark(site)
				end
			end
		end
	end)
end

return Economy
