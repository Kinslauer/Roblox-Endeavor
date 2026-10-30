local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)
local Gear = require(script.Parent.Gear)
local Net = require(script.Parent.Common.Net)

local Inventory = {}
Inventory.Thrower = nil -- set by Destruction: { Grenade(player, dir) -> bool, Charge(player) -> bool }
Inventory.Added = Instance.new("BindableEvent") -- (player, itemId, count)
Inventory.Crafted = Instance.new("BindableEvent") -- (player, itemId, count)

function Inventory.Push(player)
	local profile = PlayerData.Get(player)
	if profile then
		Remotes.InventoryChanged:FireClient(player, profile.Inventory, profile.Equipped, profile.Armor, profile.Cyber)
	end
end

function Inventory.Count(player, itemId)
	local profile = PlayerData.Get(player)
	return profile and profile.Inventory[itemId] or 0
end

function Inventory.Add(player, itemId, count)
	local profile = PlayerData.Get(player)
	if not profile or not Items.Defs[itemId] or count <= 0 then
		return false
	end
	profile.Inventory[itemId] = (profile.Inventory[itemId] or 0) + count
	Inventory.Added:Fire(player, itemId, count)
	Inventory.Push(player)
	return true
end

function Inventory.Remove(player, itemId, count)
	local profile = PlayerData.Get(player)
	if not profile or Inventory.Count(player, itemId) < count then
		return false
	end
	local left = profile.Inventory[itemId] - count
	profile.Inventory[itemId] = if left > 0 then left else nil
	if left <= 0 then
		profile.Condition[itemId], profile.Upgrades[itemId] = nil, nil
	end
	Gear.Validate(player) -- unequips anything no longer owned
	Inventory.Push(player)
	return true
end

function Inventory.AddAll(player, bundle)
	for itemId, count in bundle do
		Inventory.Add(player, itemId, count)
	end
end

function Inventory.Use(player, itemId, direction)
	local def = type(itemId) == "string" and Items.Defs[itemId]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (def and def.Type == "Consumable" and hum and hum.Health > 0) then
		return
	end
	if def.Throwable or def.Plantable then
		if Inventory.Count(player, itemId) <= 0 or not Inventory.Thrower then
			return
		end
		local used = if def.Throwable then Inventory.Thrower.Grenade(player, direction) else Inventory.Thrower.Charge(player)
		if used then
			Inventory.Remove(player, itemId, 1)
		end
		return
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
	elseif def and (def.Type == "Armor" or def.Type == "Cybernetic") then
		Gear.EquipGear(player, itemId)
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
	Net.On("UseItem", { rate = 3, burst = 4, args = { "string", "vector?" } }, Inventory.Use)
	Net.On("EquipItem", { rate = 4, burst = 8, args = { "string" } }, Inventory.Equip)
	Net.On("Craft", { rate = 3, burst = 4, args = { "string" } }, Inventory.Craft)
end

return Inventory
