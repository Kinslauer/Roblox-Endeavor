-- The grid inventory. Every item has a footprint, a weight and a stack size (Items.Shape); the grid's
-- size comes from the worn pack (pockets without one). profile.Grid.Items is the truth; profile.Inventory
-- (id -> count) is a cache rebuilt after every change so crafting, equipping, quests and the vault keep
-- reading plain counts. What doesn't fit drops at your feet (Inventory.Overflow, set by Loot).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)
local Gear = require(script.Parent.Gear)
local Net = require(script.Parent.Common.Net)

local I = Config.Inventory
local Inventory = {}
Inventory.Thrower = nil -- set by Destruction: { Grenade(player, dir) -> bool, Charge(player) -> bool }
Inventory.Overflow = nil -- set by Loot: (player, bundle) drops what did not fit
Inventory.Added = Instance.new("BindableEvent") -- (player, itemId, count)
Inventory.Crafted = Instance.new("BindableEvent") -- (player, itemId, count)

-- ===== grid geometry =====

-- A worn pack's bench upgrades (+1..+3) each add a row and some carry.
local function packLevel(profile)
	return if profile.Pack ~= "" then (profile.Upgrades and profile.Upgrades[profile.Pack]) or 0 else 0
end

function Inventory.GridSize(profile)
	local pack = profile.Pack ~= "" and Items.Defs[profile.Pack]
	if pack and pack.Grid then
		return pack.Grid[1], pack.Grid[2] + packLevel(profile)
	end
	return I.Pockets[1], I.Pockets[2]
end

function Inventory.Carry(profile)
	local pack = profile.Pack ~= "" and Items.Defs[profile.Pack]
	return if pack then pack.Carry + packLevel(profile) * I.CarryPerPackLevel else I.PocketCarry
end

local function cells(item)
	local w, h = Items.Footprint(item.Id, item.Rot)
	return w, h
end

-- A box is any grid: { Items = {...}, W = n, H = n }. The player's pack is one; a hideout vault is another.
function Inventory.Box(profile)
	local W, H = Inventory.GridSize(profile)
	return { Items = profile.Grid.Items, W = W, H = H }
end

-- true if `item` placed at x, y with rot overlaps nothing but itself and stays inside the grid
local function fits(box, item, x, y, rot, skip)
	local W, H = box.W, box.H
	local w, h = Items.Footprint(item.Id, rot)
	if x < 1 or y < 1 or x + w - 1 > W or y + h - 1 > H then
		return false
	end
	for _, other in box.Items do
		if other ~= skip then
			local ow, oh = cells(other)
			if x < other.X + ow and other.X < x + w and y < other.Y + oh and other.Y < y + h then
				return false
			end
		end
	end
	return true
end

local function firstFree(box, id)
	local W, H = box.W, box.H
	local probe = { Id = id }
	for y = 1, H do
		for x = 1, W do
			for _, rot in { 0, 1 } do
				if fits(box, probe, x, y, rot) then
					return x, y, rot
				end
			end
		end
	end
	return nil
end

local function recount(profile)
	local counts = {}
	for _, item in profile.Grid.Items do
		counts[item.Id] = (counts[item.Id] or 0) + item.Count
	end
	profile.Inventory = counts
end

function Inventory.Weight(profile)
	return Items.GridWeight(profile)
end

function Inventory.Overweight(profile)
	return Inventory.Weight(profile) > Inventory.Carry(profile)
end

-- Lays `items` (stacks) out from scratch, biggest footprints first. Returns the new list or nil if
-- something does not fit. Pure: does not touch the profile.
local function layout(box, items)
	local W, H = box.W, box.H
	local sorted = table.clone(items)
	table.sort(sorted, function(a, b)
		local sa, sb = Items.Shape(a.Id).Size, Items.Shape(b.Id).Size
		local aa, ab = sa[1] * sa[2], sb[1] * sb[2]
		return if aa ~= ab then aa > ab else a.Id < b.Id
	end)
	local placed = {}
	local scratch = { Items = placed, W = W, H = H }
	for _, item in sorted do
		local found = false
		for y = 1, H do
			for x = 1, W do
				for _, rot in { 0, 1 } do
					if not found and fits(scratch, item, x, y, rot) then
						table.insert(placed, { Id = item.Id, X = x, Y = y, Rot = rot, Count = item.Count })
						found = true
					end
				end
			end
		end
		if not found then
			return nil
		end
	end
	return placed
end

-- Puts `count` of an item into a box: tops up stacks, opens new ones, and if the grid is too
-- fragmented for a new stack, repacks everything to make room. Returns what did not fit.
local function placeIn(box, id, count)
	local shape = Items.Shape(id)
	for _, item in box.Items do
		if count <= 0 then
			break
		end
		if item.Id == id and item.Count < shape.Stack then
			local add = math.min(shape.Stack - item.Count, count)
			item.Count += add
			count -= add
		end
	end
	while count > 0 do
		local add = math.min(shape.Stack, count)
		local x, y, rot = firstFree(box, id)
		if x then
			table.insert(box.Items, { Id = id, X = x, Y = y, Rot = rot, Count = add })
		else
			local wanted = table.clone(box.Items)
			table.insert(wanted, { Id = id, Count = add })
			local repacked = layout(box, wanted)
			if not repacked then
				break
			end
			table.clear(box.Items)
			for _, it in repacked do
				table.insert(box.Items, it)
			end
		end
		count -= add
	end
	return count
end
Inventory.PlaceIn = placeIn

local function place(profile, id, count)
	return placeIn(Inventory.Box(profile), id, count)
end

-- Takes `count` of an item out of a box, smallest stacks first. Returns how many were taken.
function Inventory.RemoveFrom(box, id, count)
	local stacks = {}
	for _, item in box.Items do
		if item.Id == id then
			table.insert(stacks, item)
		end
	end
	table.sort(stacks, function(a, b)
		return a.Count < b.Count
	end)
	local taken = 0
	for _, item in stacks do
		if count <= 0 then
			break
		end
		local take = math.min(item.Count, count)
		item.Count -= take
		count -= take
		taken += take
		if item.Count <= 0 then
			table.remove(box.Items, table.find(box.Items, item))
		end
	end
	return taken
end

-- Moves stack `index` within a box; onto a same-item stack merges. Returns true if anything changed.
function Inventory.MoveIn(box, index, x, y, rot)
	local item = box.Items[index]
	if not item or (rot ~= 0 and rot ~= 1) then
		return false
	end
	for i, other in box.Items do
		if i ~= index and other.Id == item.Id and other.X == x and other.Y == y then
			local stack = Items.Shape(item.Id).Stack
			local add = math.min(stack - other.Count, item.Count)
			if add > 0 then
				other.Count += add
				item.Count -= add
				if item.Count <= 0 then
					table.remove(box.Items, index)
				end
				return true
			end
			return false
		end
	end
	if fits(box, item, x, y, rot, item) then
		item.X, item.Y, item.Rot = x, y, rot
		return true
	end
	return false
end

-- Counts per id in a box.
function Inventory.CountsOf(box)
	local counts = {}
	for _, item in box.Items do
		counts[item.Id] = (counts[item.Id] or 0) + item.Count
	end
	return counts
end

-- Older profiles have counts but no grid: lay them out once. Anything that does not fit is gone,
-- said out loud (there is no pack to drop it from yet when this runs).
local function ensureGrid(player, profile)
	if profile.Grid == nil then
		profile.Grid = { Items = {} }
	end
	if profile.Pack == nil then
		profile.Pack = ""
	end
	if #profile.Grid.Items == 0 and next(profile.Inventory) then
		local lost = {}
		local counts = profile.Inventory
		profile.Inventory = {}
		for id, count in counts do
			if Items.Defs[id] and id ~= "Fists" then
				local left = place(profile, id, count)
				if left > 0 then
					table.insert(lost, ("%dx %s"):format(left, Items.Defs[id].Name))
				end
			end
		end
		recount(profile)
		if #lost > 0 then
			Remotes.Announce:FireClient(player, "Your pockets could not hold everything you had: " .. table.concat(lost, ", "), "Info")
		end
	end
end

-- ===== public API (same names as before, now capacity-aware) =====

function Inventory.Snapshot(profile)
	local W, H = Inventory.GridSize(profile)
	return { W = W, H = H, Items = profile.Grid.Items, Pack = profile.Pack, Weight = Inventory.Weight(profile), Carry = Inventory.Carry(profile) }
end

function Inventory.Push(player)
	local profile = PlayerData.Get(player)
	if profile then
		ensureGrid(player, profile)
		Remotes.InventoryChanged:FireClient(player, profile.Inventory, profile.Equipped, profile.Armor, profile.Cyber, Inventory.Snapshot(profile))
	end
end

function Inventory.Count(player, itemId)
	local profile = PlayerData.Get(player)
	return profile and profile.Inventory[itemId] or 0
end

local function overflow(player, id, left)
	if left > 0 and Inventory.Overflow then
		Inventory.Overflow(player, { [id] = left })
		Remotes.Announce:FireClient(player, ("No room for %dx %s. It is at your feet."):format(left, Items.Defs[id].Name), "Info")
	end
end

-- Adds what fits; the rest drops at the player's feet. Returns true if anything was added.
function Inventory.Add(player, itemId, count, keepLeftover)
	local profile = PlayerData.Get(player)
	if not profile or not Items.Defs[itemId] or itemId == "Fists" or count <= 0 then
		return false, count
	end
	ensureGrid(player, profile)
	local left = place(profile, itemId, count)
	recount(profile)
	local added = count - left
	if added > 0 then
		Inventory.Added:Fire(player, itemId, added)
		Inventory.Push(player)
	end
	if not keepLeftover then
		overflow(player, itemId, left)
	end
	return added > 0, left
end

-- Removes from the smallest stacks first. Returns false if the player does not own that many.
function Inventory.Remove(player, itemId, count)
	local profile = PlayerData.Get(player)
	if not profile or Inventory.Count(player, itemId) < count then
		return false
	end
	Inventory.RemoveFrom(Inventory.Box(profile), itemId, count)
	recount(profile)
	if not profile.Inventory[itemId] and profile.Pack ~= itemId then
		profile.Condition[itemId], profile.Upgrades[itemId] = nil, nil
	end
	Gear.Validate(player) -- unequips anything no longer owned
	Inventory.Push(player)
	return true
end

-- Adds a bundle. With keepLeftover, returns the part that did not fit instead of dropping it.
function Inventory.AddAll(player, bundle, keepLeftover)
	local leftover = {}
	for itemId, count in bundle do
		local _, left = Inventory.Add(player, itemId, count, keepLeftover)
		if left and left > 0 then
			leftover[itemId] = left
		end
	end
	return leftover
end

-- ===== the game of it: moving, rotating, dropping, packs =====

-- Moves stack `index` to x, y with rotation rot. Dropping onto a same-item stack merges into it.
function Inventory.Move(player, index, x, y, rot)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	Inventory.MoveIn(Inventory.Box(profile), index, x, y, rot)
	Inventory.Push(player) -- also snaps the client's ghost back on a refused move
end

-- Drops a stack (or part of one) at the player's feet.
function Inventory.Drop(player, index, count)
	local profile = PlayerData.Get(player)
	local item = profile and profile.Grid.Items[index]
	if not item or not Inventory.Overflow then
		return
	end
	count = math.clamp(count or item.Count, 1, item.Count)
	local id = item.Id
	local cond, up = profile.Condition[id], profile.Upgrades[id]
	item.Count -= count
	if item.Count <= 0 then
		table.remove(profile.Grid.Items, index)
	end
	recount(profile)
	if not profile.Inventory[id] then
		profile.Condition[id], profile.Upgrades[id] = nil, nil
	end
	Gear.Validate(player)
	Inventory.Overflow(player, { [id] = count }, { Condition = cond, Upgrades = up })
	Inventory.Push(player)
end

-- Re-lays every stack out in the current grid (after a pack change); what no longer fits drops.
local function relayout(player, profile)
	local old = profile.Grid.Items
	local repacked = layout(Inventory.Box(profile), old)
	if repacked then
		profile.Grid.Items = repacked
		recount(profile)
		return
	end
	-- not everything fits: place biggest first, spill the rest
	profile.Grid.Items = {}
	table.sort(old, function(a, b)
		local sa, sb = Items.Shape(a.Id).Size, Items.Shape(b.Id).Size
		return sa[1] * sa[2] > sb[1] * sb[2]
	end)
	local lost = {}
	for _, item in old do
		local left = place(profile, item.Id, item.Count)
		if left > 0 then
			lost[item.Id] = (lost[item.Id] or 0) + left
		end
	end
	recount(profile)
	for id, n in lost do
		overflow(player, id, n)
	end
end

-- Wear a pack you own: it leaves the grid and sets the grid's size. Wearing a pack over another
-- swaps them (the old one goes back into the grid, or to the ground if it does not fit).
function Inventory.EquipPack(player, itemId)
	local profile = PlayerData.Get(player)
	local def = Items.Defs[itemId]
	if not (profile and def and def.Type == "Pack" and Inventory.Count(player, itemId) > 0) then
		return false
	end
	-- take one out of the grid without dropping anything
	for i, item in profile.Grid.Items do
		if item.Id == itemId then
			item.Count -= 1
			if item.Count <= 0 then
				table.remove(profile.Grid.Items, i)
			end
			break
		end
	end
	local old = profile.Pack
	profile.Pack = itemId
	relayout(player, profile)
	if old ~= "" then
		local left = place(profile, old, 1)
		recount(profile)
		overflow(player, old, left)
	end
	Inventory.Push(player)
	return true
end

-- Auto-sort: repack everything biggest-first (nothing is lost; the grid is the same size).
function Inventory.Sort(player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	relayout(player, profile)
	Inventory.Push(player)
end

function Inventory.UnequipPack(player)
	local profile = PlayerData.Get(player)
	if not profile or profile.Pack == "" then
		return
	end
	local old = profile.Pack
	profile.Pack = ""
	relayout(player, profile)
	local left = place(profile, old, 1)
	recount(profile)
	overflow(player, old, left)
	Inventory.Push(player)
end

-- ===== the old API surface =====

function Inventory.Use(player, itemId, direction)
	local def = type(itemId) == "string" and Items.Defs[itemId]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if def and def.Type == "Ammo" and def.Caliber and hum and hum.Health > 0 and Inventory.Count(player, itemId) > 0 then
		-- a cartridge: that load goes in next (server/Combat round 3)
		require(script.Parent.Combat).SelectLoad(player, itemId)
		return
	end
	-- round 5 (server/Builds): a chip is fitted at the bench; a data shard is read at home
	if def and def.Type == "Chip" and hum and hum.Health > 0 then
		require(script.Parent.Builds).Fit(player, itemId)
		return
	end
	if def and def.Type == "Data" and hum and hum.Health > 0 and Inventory.Count(player, itemId) > 0 then
		if require(script.Parent.Builds).ReadShard(player) then
			Inventory.Remove(player, itemId, 1)
		end
		return
	end
	if not (def and def.Type == "Consumable" and hum and hum.Health > 0) then
		return
	end
	if def.Throwable or def.Plantable then
		if Inventory.Count(player, itemId) <= 0 or (not Inventory.Thrower and def.Throwable ~= "Bolt") then
			return
		end
		local used
		if def.Throwable == "Bolt" then
			used = require(script.Parent.Stealth).ThrowBolt(player, direction) -- round 4: a noise somewhere else
		elseif def.Throwable then
			used = Inventory.Thrower.Grenade(player, direction)
		else
			used = Inventory.Thrower.Charge(player)
		end
		if used then
			Inventory.Remove(player, itemId, 1)
		end
		return
	end
	if Inventory.Count(player, itemId) <= 0 then
		return
	end
	-- treatments and food go through the wounds (Medicine); a pure treatment with nothing to treat is kept
	local treated = false
	if def.Treat or def.Food then
		local okMed, Medicine = pcall(require, script.Parent.Medicine)
		if okMed then
			treated = Medicine.Use(player, def)
		end
		if not treated and not (def.Heal or def.Stamina) then
			Remotes.Announce:FireClient(player, "Nothing to treat.", "Info")
			return
		end
	end
	if not Inventory.Remove(player, itemId, 1) then
		return
	end
	if def.Heal then
		hum.Health = math.min(hum.MaxHealth, hum.Health + def.Heal)
	end
	if def.Stamina then
		char:SetAttribute("Stamina", math.min(char:GetAttribute("MaxStamina"), (char:GetAttribute("Stamina") or 0) + def.Stamina))
	end
end

function Inventory.Equip(player, itemId)
	local def = type(itemId) == "string" and Items.Defs[itemId]
	if def and def.Type == "Weapon" then
		Gear.EquipWeapon(player, itemId)
	elseif def and def.Type == "Cybernetic" then
		Remotes.Announce:FireClient(player, "Cybernetics are ripped in at an Autonet (build one in your hideout, or use the arena's).", "Info")
		return
	elseif def and def.Type == "Armor" then
		Gear.EquipGear(player, itemId)
	elseif def and def.Type == "Pack" then
		Inventory.EquipPack(player, itemId)
		return
	else
		return
	end
	Inventory.Push(player)
end

function Inventory.Craft(player, recipeId)
	local recipe = type(recipeId) == "string" and Items.Recipes[recipeId]
	if not recipe then
		return
	end
	for itemId, count in recipe.Inputs do
		if Inventory.Count(player, itemId) < count then
			return
		end
	end
	for itemId, count in recipe.Inputs do
		Inventory.Remove(player, itemId, count)
	end
	Inventory.Add(player, recipe.Output, recipe.Count)
	Inventory.Crafted:Fire(player, recipe.Output, recipe.Count)
end

function Inventory.Init()
	Gear.UnequipPack = Inventory.UnequipPack
	Net.On("UseItem", { rate = 3, burst = 4, args = { "string", "vector?" } }, Inventory.Use)
	Net.On("EquipItem", { rate = 4, burst = 8, args = { "string" } }, Inventory.Equip)
	Net.On("Craft", { rate = 3, burst = 4, args = { "string" } }, Inventory.Craft)
	Net.On("MoveItem", { rate = 10, burst = 20, args = { "int", "int", "int", "int" } }, Inventory.Move)
	Net.On("DropItem", { rate = 4, burst = 8, args = { "int", "int?" } }, Inventory.Drop)
	Net.On("SortItems", { rate = 2, burst = 3 }, Inventory.Sort)
end

return Inventory
