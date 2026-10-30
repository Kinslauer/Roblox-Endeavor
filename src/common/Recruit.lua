-- The recruit app: what a conduit owns and orders for the war world. Lives in the shared
-- profile (Data.War) so it works from both places. Pure data operations + validation; the
-- places wire the remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Firearms = require(Shared.Firearms)

local W = Config.War
local Recruit = {}

-- Everything the shop sells, with the faction that sells it (nil = both).
function Recruit.Catalog()
	local out = {}
	for id, def in Firearms.Defs do
		out[id] = { Kind = "Weapon", Name = def.Name, Price = def.Price, Faction = def.Faction, Class = def.Class }
	end
	for id, def in Firearms.Attachments do
		if def.Price > 0 then
			out[id] = { Kind = "Attachment", Name = def.Name, Price = def.Price, Faction = def.Faction, Slot = def.Slot }
		end
	end
	for id, def in Firearms.Armor do
		out[id] = { Kind = "Armor", Name = def.Name, Price = def.Price }
	end
	out.Ammo = { Kind = "Ammo", Name = "Ammunition (3 magazines)", Price = 60 }
	out.Grenade = { Kind = "Grenade", Name = "Frag grenade", Price = 90 }
	out.Medkit = { Kind = "Medkit", Name = "Field dressing", Price = 50 }
	out.Sandbags = { Kind = "Sandbags", Name = "Sandbags (3 low sections)", Price = 40 }
	return out
end
local CATALOG = Recruit.Catalog()

function Recruit.Init(war)
	if war.Credits == 0 and war.Deployments == 0 and next(war.Locker) == nil then
		war.Credits = W.StartingCredits
	end
	return war
end

local function lockerAdd(war, id, condition, count)
	local slot = war.Locker[id]
	if not slot then
		slot = { count = 0, condition = condition or 100 }
		war.Locker[id] = slot
	end
	-- stacked items keep the worse condition; repair brings the stack back up
	slot.count += count or 1
	slot.condition = math.min(slot.condition, condition or 100)
	return slot
end
Recruit.LockerAdd = lockerAdd

function Recruit.LockerTake(war, id, count)
	local slot = war.Locker[id]
	if not slot or slot.count < (count or 1) then
		return nil
	end
	slot.count -= count or 1
	local condition = slot.condition
	if slot.count <= 0 then
		war.Locker[id] = nil
	end
	return condition
end

-- Buy from the shop into the locker. Returns ok, reason.
function Recruit.Buy(war, id)
	local item = type(id) == "string" and CATALOG[id]
	if not item then
		return false, "no such item"
	end
	if item.Faction and item.Faction ~= war.Faction then
		return false, "sold by the other side"
	end
	if war.Credits < item.Price then
		return false, "not enough credits"
	end
	war.Credits -= item.Price
	lockerAdd(war, id, 100, if item.Kind == "Ammo" then 3 else 1)
	return true
end

-- Repair a locker stack to full condition. Returns ok, reason.
function Recruit.Repair(war, id)
	local slot = type(id) == "string" and war.Locker[id]
	if not slot then
		return false, "not in locker"
	end
	if slot.condition >= 100 then
		return false, "already serviced"
	end
	local item = CATALOG[id] or {}
	local cost = math.ceil((item.Price or 100) * 0.006 * (100 - slot.condition))
	if war.Credits < cost then
		return false, ("repair costs %d credits"):format(cost)
	end
	war.Credits -= cost
	slot.condition = 100
	return true
end

-- Set the next recruit's order. Only items in the locker count; the order is validated again
-- at deployment (the locker may have changed). loadout: { Primary, Sidearm, Armor, Helmet, Attachments = { Optic, Muzzle, Grip } }
function Recruit.Order(war, loadout)
	if type(loadout) ~= "table" then
		return false
	end
	-- each slot only takes its own kind of thing: a plate carrier is not a helmet
	local KIND = {
		Primary = function(id) return Firearms.Defs[id] ~= nil and Firearms.Defs[id].Class ~= "Pistol" end,
		Sidearm = function(id) return Firearms.Defs[id] ~= nil and Firearms.Defs[id].Class == "Pistol" end,
		Armor = function(id) return Firearms.Armor[id] ~= nil and not Firearms.Armor[id].Head end,
		Helmet = function(id) return Firearms.Armor[id] ~= nil and Firearms.Armor[id].Head == true end,
	}
	local order = { Attachments = {} }
	for _, slot in { "Primary", "Sidearm", "Armor", "Helmet" } do
		local id = loadout[slot]
		if id ~= nil then
			if type(id) ~= "string" or not war.Locker[id] or not KIND[slot](id) then
				return false
			end
			order[slot] = id
		end
	end
	if type(loadout.Attachments) == "table" and order.Primary then
		local slots = Firearms.Defs[order.Primary].Slots
		for _, slot in { "Optic", "Muzzle", "Grip" } do
			local id = loadout.Attachments[slot]
			if id ~= nil then
				if type(id) ~= "string" or not war.Locker[id] or not Firearms.Attachments[id] or Firearms.Attachments[id].Slot ~= slot or not table.find(slots, slot) then
					return false
				end
				order.Attachments[slot] = id
			end
		end
	end
	war.Loadout = order
	return true
end

-- Pull the ordered gear out of the locker for a deployment. Returns the kit the soldier spawns
-- with (conditions included) or nil + reason. Missing pieces are skipped, not fatal.
function Recruit.Deploy(war)
	local order = war.Loadout or {}
	local kit = { Attachments = {}, Grenades = 0, Medkits = 0, Magazines = 0 }
	for _, slot in { "Primary", "Sidearm", "Armor", "Helmet" } do
		local id = order[slot]
		if id then
			local condition = Recruit.LockerTake(war, id, 1)
			if condition then
				kit[slot] = { Id = id, Condition = condition }
			end
		end
	end
	if kit.Primary then
		for slot, id in order.Attachments or {} do
			local condition = Recruit.LockerTake(war, id, 1)
			if condition then
				kit.Attachments[slot] = { Id = id, Condition = condition }
			end
		end
	end
	-- consumables: take what is there, up to a carry limit (one Ammo unit = one magazine)
	local mags = math.min(3, (war.Locker.Ammo or { count = 0 }).count)
	kit.Magazines = if mags > 0 and Recruit.LockerTake(war, "Ammo", mags) then mags else 0
	for _ = 1, 2 do
		if Recruit.LockerTake(war, "Grenade", 1) then
			kit.Grenades += 1
		end
	end
	if Recruit.LockerTake(war, "Medkit", 1) then
		kit.Medkits = 1
	end
	kit.Sandbags = if Recruit.LockerTake(war, "Sandbags", 1) then 3 else 0
	war.Deployments += 1
	return kit
end

-- Everything the client needs to draw the app.
function Recruit.Snapshot(war)
	return { Faction = war.Faction, Credits = war.Credits, Locker = war.Locker, Loadout = war.Loadout, Catalog = CATALOG,
		Deployments = war.Deployments, Kills = war.RecruitKills, Deaths = war.RecruitDeaths }
end

return Recruit
