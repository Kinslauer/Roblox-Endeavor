-- Derives a player's combat numbers from base stats + worn armor + equipped weapon, and owns
-- equipping and skill slots. Everything else (Combat, Stats, SkillRunner) reads Gear.Get().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Weapons = require(Shared.Weapons)
local PlayerData = require(script.Parent.PlayerData)

local S, C = Config.Stats, Config.Combat

local Gear = {}
Gear.Changed = Instance.new("BindableEvent") -- (player)

local derived = {}

-- What NPCs (and anything without a profile) fight with.
local DEFAULT = {
	Stats = {}, Tags = {}, Resist = { Physical = 0, Arc = 0 }, MaxPosture = C.BasePosture, PostureRegen = C.PostureRegenPerSecond,
	StaminaCostMult = 1, BlockReduction = C.BlockReduction, DodgeIFrames = C.DodgeIFrames, DamageMult = 1,
	PostureDamageMult = 1, ChargeGain = 1, WeightScore = 0,
}
for _, name in S.Names do
	DEFAULT.Stats[name] = 0
end

local function compute(data)
	local stats = table.clone(data.Stats)
	local resist = { Physical = 0, Arc = 0 }
	local tags, posture, weight, speed, chargeGain = {}, 0, 0, 0, 0

	for slot, id in data.Armor do
		local piece = Armor.Pieces[id]
		if piece and piece.Slot == slot and (data.Inventory[id] or 0) > 0 then
			for stat, bonus in piece.Stats or {} do
				stats[stat] = (stats[stat] or 0) + bonus
			end
			for kind, amount in piece.Resist or {} do
				resist[kind] += amount
			end
			for _, tag in piece.Tags or {} do
				tags[tag] = (tags[tag] or 0) + 1
			end
			posture += piece.Posture or 0
			speed += piece.Speed or 0
			chargeGain += piece.ChargeGain or 0
			weight += Armor.WeightScore[piece.Weight] or 0
		end
	end

	resist.Physical += stats.Fortitude * S.PhysicalResistPerFortitude
	for kind, value in resist do
		resist[kind] = math.min(value, C.MaxResist)
	end

	local speedMult = 1 + speed - 0.01 * weight
	return {
		Stats = stats,
		Tags = tags,
		Resist = resist,
		WeightScore = weight,
		MaxHealth = S.BaseHealth + stats.Fortitude * S.HealthPerFortitude,
		MaxStamina = S.BaseStamina + stats.Willpower * S.StaminaPerWillpower,
		WalkSpeed = (S.BaseWalkSpeed + stats.Agility * S.WalkSpeedPerAgility) * speedMult,
		MaxPosture = C.BasePosture + stats.Willpower * C.PosturePerWillpower + posture,
		PostureRegen = C.PostureRegenPerSecond * (1 + stats.Willpower * 0.01),
		StaminaCostMult = 1 + 0.04 * weight,
		BlockReduction = math.min(0.9, C.BlockReduction + 0.02 * weight),
		DodgeIFrames = math.max(0.2, C.DodgeIFrames - 0.012 * weight + stats.Agility * 0.002),
		DamageMult = 1 + stats.Strength * S.DamagePerStrength,
		PostureDamageMult = 1 + stats.Strength * S.PostureDamagePerStrength,
		ChargeGain = 1 + chargeGain + stats.Intelligence * S.ChargePerIntelligence,
	}
end

function Gear.Default()
	return DEFAULT
end

function Gear.Get(player)
	if not derived[player] then
		local data = PlayerData.Get(player)
		if not data then
			return DEFAULT
		end
		derived[player] = compute(data)
	end
	return derived[player]
end

-- Works for any character model: player characters use their profile, everything else the default.
function Gear.OfChar(char)
	local player = game:GetService("Players"):GetPlayerFromCharacter(char)
	return if player then Gear.Get(player) else DEFAULT
end

function Gear.Push(player)
	local data, d = PlayerData.Get(player), derived[player]
	if data and d then
		Remotes.LoadoutChanged:FireClient(player, {
			Stats = d.Stats, Tags = d.Tags, Resist = d.Resist, MaxPosture = d.MaxPosture,
			WeightScore = d.WeightScore, Weapon = data.Equipped, Armor = data.Armor, Slots = data.SkillSlots,
		})
	end
end

local function slotKey(i)
	return tostring(i)
end

local function autoSlot(data, d)
	-- Newly unlocked skills drop into the first free slot so players never miss them.
	local slotted = {}
	for _, id in data.SkillSlots do
		slotted[id] = true
	end
	for _, id in Skills.Order do
		if not slotted[id] and Skills.Unlocked(Skills.Defs[id], d.Stats, d.Tags) then
			for i = 1, Skills.SlotCount do
				if not data.SkillSlots[slotKey(i)] then
					data.SkillSlots[slotKey(i)] = id
					break
				end
			end
		end
	end
end

function Gear.Recompute(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	derived[player] = compute(data)
	autoSlot(data, derived[player])
	Gear.Push(player)
	Gear.Changed:Fire(player)
end

function Gear.Release(player)
	derived[player] = nil
end

function Gear.EquipWeapon(player, itemId)
	local data = PlayerData.Get(player)
	if data and Weapons.Defs[itemId] and (itemId == "Fists" or (data.Inventory[itemId] or 0) > 0) then
		data.Equipped = itemId
		Gear.Recompute(player)
		return true
	end
	return false
end

function Gear.EquipArmor(player, itemId)
	local data, piece = PlayerData.Get(player), Armor.Pieces[itemId]
	if data and piece and (data.Inventory[itemId] or 0) > 0 then
		data.Armor[piece.Slot] = itemId
		Gear.Recompute(player)
		return true
	end
	return false
end

-- what: "Weapon" or an armor slot name
function Gear.Unequip(player, what)
	local data = PlayerData.Get(player)
	if not data or type(what) ~= "string" then
		return
	end
	if what == "Weapon" then
		data.Equipped = "Fists"
	elseif table.find(Armor.Slots, what) then
		data.Armor[what] = nil
	else
		return
	end
	Gear.Recompute(player)
end

-- Call after items leave the inventory (crafting, dropping, theft).
function Gear.Validate(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if data.Equipped ~= "Fists" and (data.Inventory[data.Equipped] or 0) <= 0 then
		data.Equipped = "Fists"
	end
	for slot, id in data.Armor do
		if (data.Inventory[id] or 0) <= 0 then
			data.Armor[slot] = nil
		end
	end
	Gear.Recompute(player)
end

function Gear.SetSkill(player, slot, skillId)
	local data = PlayerData.Get(player)
	if not data or type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Skills.SlotCount then
		return
	end
	if skillId ~= nil then
		local def = type(skillId) == "string" and Skills.Defs[skillId]
		local d = Gear.Get(player)
		if not def or not Skills.Unlocked(def, d.Stats, d.Tags) then
			return
		end
		for key, id in data.SkillSlots do
			if id == skillId then
				data.SkillSlots[key] = nil
			end
		end
	end
	data.SkillSlots[slotKey(slot)] = skillId
	Gear.Push(player)
end

function Gear.Init()
	Remotes.Unequip.OnServerEvent:Connect(Gear.Unequip)
	Remotes.SetSkill.OnServerEvent:Connect(Gear.SetSkill)
end

return Gear
