local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Clues = require(Shared.Clues)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)
local Gear = require(script.Parent.Gear)

local Inventory = {}
Inventory.Added = Instance.new("BindableEvent") -- (player, itemId, count)
Inventory.Crafted = Instance.new("BindableEvent") -- (player, itemId, count)
Inventory.Used = Instance.new("BindableEvent") -- (player, itemId): a consumable was used (Raids reads intel)

function Inventory.Push(player)
	local profile = PlayerData.Get(player)
	if profile then
		Remotes.InventoryChanged:FireClient(player, profile.Inventory, profile.Equipped, profile.Armor, profile.Cyber)
		if player.Character then -- the HUD's ammo line shows the cells you carry
			player.Character:SetAttribute("Cells", profile.Inventory[Config.Gunplay.CellItem] or 0)
		end
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
	Gear.Validate(player) -- unequips anything no longer owned
	Inventory.Push(player)
	return true
end

function Inventory.AddAll(player, bundle)
	for itemId, count in bundle do
		Inventory.Add(player, itemId, count)
	end
end

function Inventory.Use(player, itemId)
	local def = type(itemId) == "string" and Items.Defs[itemId]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (def and (def.Type == "Consumable" or def.Type == "Fragment") and hum and hum.Health > 0) then
		return -- (a Fragment is read: server/Clues.lua turns it into knowledge on Used)
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
	Inventory.Used:Fire(player, itemId)
end

function Inventory.Equip(player, itemId)
	local def = type(itemId) == "string" and Items.Defs[itemId]
	if def and def.Type == "Cybernetic" then
		Remotes.Announce:FireClient(player, "Cybernetics are ripped in at an Autonet.", "Info")
		return -- (server/Autonet.lua)
	end
	if def and def.Type == "Weapon" then
		Gear.EquipWeapon(player, itemId)
	elseif def and def.Type == "Armor" then
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
	if recipe.Needs then -- knowledge-gated (shared/Clues.lua Teaches)
		local profile = PlayerData.Get(player)
		if not (profile and Clues.Knows(profile.Knowledge, recipe.Needs)) then
			return
		end
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
	Remotes.UseItem.OnServerEvent:Connect(RateLimit.Wrap("UseItem", Config.RateLimit.UseItem, Inventory.Use))
	Remotes.EquipItem.OnServerEvent:Connect(RateLimit.Wrap("EquipItem", Config.RateLimit.EquipItem, Inventory.Equip))
	Remotes.Craft.OnServerEvent:Connect(RateLimit.Wrap("Craft", Config.RateLimit.Craft, Inventory.Craft))
end

return Inventory
