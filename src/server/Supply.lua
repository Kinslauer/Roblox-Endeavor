-- Supply (Phase 3, build order 3; design/gdd/war.md §6): how the Conduit world feeds the war.
--   * The faction POOL: stash donated at the hideout becomes points for your side. The pool decides
--     the kit every AI recruit of that side spawns with (Config.Supply.Tiers), and fielding recruits
--     spends it, so a side nobody supplies fights with the basic kit.
--   * SHIPMENTS: your own stash gear, sent ahead. It lands at your base in a crate ShipmentSeconds
--     later (War.lua drops and opens it); open it and you fight with it. Die and it stays on the
--     field; walk out and it goes back to the stash. (War.lua owns the crate and the field kit; this
--     module owns the data: the pool, the queue and the stash moves.)
-- The pool is server-wide and in memory for now (a DataStore-backed pool is a follow-up).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local PlayerData = require(script.Parent.PlayerData)

local S = Config.Supply
local Supply = {}

local pool = {} -- [factionId] = points

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function publish()
	for _, f in Config.War.Factions do
		workspace:SetAttribute("War_Supply_" .. f.Id, math.floor(pool[f.Id] or 0))
		workspace:SetAttribute("War_Tier_" .. f.Id, Supply.Tier(f.Id).Name)
	end
end
Supply.Publish = publish

-- ---------------------------------------------------------------------------------------------
-- The pool
-- ---------------------------------------------------------------------------------------------
function Supply.Points(factionId)
	return pool[factionId] or 0
end

function Supply.Value(itemId, count)
	local def = Items.Defs[itemId]
	return (def and S.Value[def.Type] or 0) * (count or 1)
end

-- The highest tier the side's points reach.
function Supply.Tier(factionId)
	local points, best = pool[factionId] or 0, S.Tiers[1]
	for _, tier in S.Tiers do
		if points >= tier.Points then
			best = tier
		end
	end
	return best
end

-- Called once per recruit fielded: spends CostPerRecruit and returns the kit it spawns with.
function Supply.Draw(factionId)
	local tier = Supply.Tier(factionId)
	pool[factionId] = math.max(0, (pool[factionId] or 0) - S.CostPerRecruit)
	publish()
	return tier
end

function Supply.AddPoints(factionId, points)
	pool[factionId] = math.max(0, (pool[factionId] or 0) + points)
	publish()
end

-- Donate everything in the stash to your side's pool.
function Supply.Donate(player)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	if not data.Faction then
		announce(player, "Choose a side first - the consoles on the left.")
		return 0
	end
	local points = 0
	for id, count in table.clone(data.Stash) do
		points += Supply.Value(id, count)
		data.Stash[id] = nil
	end
	player:SetAttribute("StashCount", 0)
	if points <= 0 then
		announce(player, "Nothing in the stash to send. Stash items first, then donate.")
		return 0
	end
	local before = Supply.Tier(data.Faction)
	Supply.AddPoints(data.Faction, points)
	local after = Supply.Tier(data.Faction)
	local def
	for _, f in Config.War.Factions do
		if f.Id == data.Faction then
			def = f
		end
	end
	announce(player, ("Donated %d supply to the %s (pool %d, recruits draw the %s kit)."):format(points, def and def.Name or data.Faction, Supply.Points(data.Faction), after.Name))
	if after ~= before then
		Remotes.Announce:FireAllClients(("The %s re-arm: their recruits now field the %s kit."):format(def and def.Name or data.Faction, after.Name), "Event")
	end
	return points
end

-- ---------------------------------------------------------------------------------------------
-- Shipments (data). War.lua turns a ready shipment into a crate at the base.
-- ---------------------------------------------------------------------------------------------
local SHIPPABLE = { Weapon = true, Armor = true, Cybernetic = true, Consumable = true, Part = true }

function Supply.Shipment(player)
	local data = PlayerData.Get(player)
	return data and data.Shipment or nil
end

-- Seconds until the shipment lands (0 = ready), or nil without one.
function Supply.ShipmentEta(player)
	local shipment = Supply.Shipment(player)
	if not shipment then
		return nil
	end
	return math.max(0, shipment.ReadyAt - os.time())
end

local function syncShipment(player, data)
	local shipment = data.Shipment
	player:SetAttribute("ShipmentReadyAt", shipment and shipment.ReadyAt or nil)
	local n = 0
	for _, count in shipment and shipment.Items or {} do
		n += count
	end
	player:SetAttribute("ShipmentCount", if shipment then n else nil)
end
Supply.Sync = function(player)
	local data = PlayerData.Get(player)
	if data then
		syncShipment(player, data)
	end
end

-- Send up to ShipmentMax pieces of stash gear to the front. One shipment at a time.
function Supply.Ship(player)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	if data.Shipment then
		local eta = Supply.ShipmentEta(player)
		announce(player, if eta > 0 then ("A shipment is already on its way (%d s)."):format(eta) else "Your shipment is waiting at your base. Deploy and open it.")
		return 0
	end
	local items, n = {}, 0
	for id, count in table.clone(data.Stash) do
		local def = Items.Defs[id]
		if def and SHIPPABLE[def.Type] then
			local take = math.min(count, S.ShipmentMax - n)
			if take > 0 then
				items[id] = take
				n += take
				local left = count - take
				data.Stash[id] = if left > 0 then left else nil
			end
		end
		if n >= S.ShipmentMax then
			break
		end
	end
	if n == 0 then
		announce(player, "Nothing shippable in the stash (weapons, armor, cybernetics, consumables).")
		return 0
	end
	data.Shipment = { Items = items, ReadyAt = os.time() + S.ShipmentSeconds }
	local count = 0
	for _, c in data.Stash do
		count += c
	end
	player:SetAttribute("StashCount", count)
	syncShipment(player, data)
	announce(player, ("Shipment of %d sent to the front. It lands at your base in %d s - be there to open it."):format(n, S.ShipmentSeconds))
	return n
end

-- The crate was opened: hand the items over and clear the queue. Returns the item bundle.
function Supply.TakeShipment(player)
	local data = PlayerData.Get(player)
	if not (data and data.Shipment) then
		return nil
	end
	local items = data.Shipment.Items
	data.Shipment = false
	syncShipment(player, data)
	Inventory.AddAll(player, items)
	return items
end

-- Field gear comes home: out of the inventory, back into the stash (used when you leave alive).
function Supply.ReturnToStash(player, items)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for id, count in items do
		local have = math.min(count, Inventory.Count(player, id))
		if have > 0 then
			Inventory.Remove(player, id, have)
			data.Stash[id] = (data.Stash[id] or 0) + have
		end
	end
	local n = 0
	for _, c in data.Stash do
		n += c
	end
	player:SetAttribute("StashCount", n)
end

-- Field gear lost: out of the inventory (War.lua drops it as loot where you fell).
function Supply.Forfeit(player, items)
	local lost = {}
	for id, count in items do
		local have = math.min(count, Inventory.Count(player, id))
		if have > 0 then
			Inventory.Remove(player, id, have)
			lost[id] = have
		end
	end
	return lost
end

function Supply.Init()
	for _, f in Config.War.Factions do
		pool[f.Id] = pool[f.Id] or 0
	end
	publish()
end

return Supply
