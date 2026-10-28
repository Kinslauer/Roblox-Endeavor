-- Derives a player's combat numbers from base stats + armor + cybernetics, and owns equipping
-- and skill slots. Everything else (Combat, Stats, SkillRunner) reads Gear.Get().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Weapons = require(Shared.Weapons)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local S, C, F = Config.Stats, Config.Combat, Config.Flicker

-- Wearable gear: each lives in its own profile table, keyed by slot.
local SOURCES = {
	Armor = { defs = Armor.Pieces, slots = Armor.Slots },
	Cyber = { defs = Cybernetics.Pieces, slots = Cybernetics.Slots },
}
local FIELD_OF_SLOT = {}
for field, source in SOURCES do
	for _, slot in source.slots do
		FIELD_OF_SLOT[slot] = field
	end
end

local Gear = {}
Gear.Changed = Instance.new("BindableEvent") -- (player)

local derived = {}

-- What NPCs (and anything without a profile) fight with.
local DEFAULT = {
	Stats = {}, Tags = {}, Resist = { Physical = 0, Arc = 0 }, MaxPosture = C.BasePosture, PostureRegen = C.PostureRegenPerSecond,
	StaminaCostMult = 1, BlockReduction = C.BlockReduction, DodgeIFrames = C.DodgeIFrames, DamageMult = 1,
	PostureDamageMult = 1, ChargeGain = 1, WeightScore = 0, FlickerRate = 1, FlashBonus = 0, ParryWindow = C.ParryWindow,
	JumpMult = 1, Hearing = 0, Scent = 0, Track = false, Lift = 0, Conversion = 0,
}
for _, name in S.Names do
	DEFAULT.Stats[name] = 0
end

local function compute(data)
	local stats = table.clone(data.Stats)
	local resist = { Physical = 0, Arc = 0 }
	local tags = {}
	local sum = {
		Posture = 0, Speed = 0, ChargeGain = 0, FlickerRate = 0, FlashBonus = 0, ParryBonus = 0, HealthPenalty = 0, Weight = 0,
		Jump = 0, DodgeBonus = 0, Hearing = 0, Scent = 0, Lift = 0,
	}
	local track, fitted = false, 0

	for field, source in SOURCES do
		local used = {} -- copies counted so far: two Servo Arms need two in the inventory
		for slot, id in data[field] do
			local piece = source.defs[id]
			local fits = piece and (if field == "Cyber" then Cybernetics.Fits(piece, slot) else piece.Slot == slot)
			if fits and (data.Inventory[id] or 0) > (used[id] or 0) then
				used[id] = (used[id] or 0) + 1
				if field == "Cyber" then
					fitted += 1
					track = track or piece.Track == true
				end
				for stat, bonus in piece.Stats or {} do
					stats[stat] = (stats[stat] or 0) + bonus
				end
				for kind, amount in piece.Resist or {} do
					resist[kind] += amount
				end
				for _, tag in piece.Tags or {} do
					tags[tag] = (tags[tag] or 0) + 1
				end
				for key in sum do
					if key ~= "Weight" then
						sum[key] += piece[key] or 0
					end
				end
				sum.Weight += Armor.WeightScore[piece.Weight] or 0
			end
		end
	end

	resist.Physical += stats.Fortitude * S.PhysicalResistPerFortitude
	for kind, value in resist do
		resist[kind] = math.min(value, C.MaxResist)
	end

	local weight = sum.Weight
	local speedMult = 1 + sum.Speed - 0.01 * weight
	return {
		Stats = stats,
		Tags = tags,
		Resist = resist,
		WeightScore = weight,
		MaxHealth = math.max(40, S.BaseHealth + stats.Fortitude * S.HealthPerFortitude - sum.HealthPenalty),
		MaxStamina = S.BaseStamina + stats.Willpower * S.StaminaPerWillpower,
		WalkSpeed = (S.BaseWalkSpeed + stats.Agility * S.WalkSpeedPerAgility) * speedMult,
		MaxPosture = C.BasePosture + stats.Willpower * C.PosturePerWillpower + sum.Posture,
		PostureRegen = C.PostureRegenPerSecond * (1 + stats.Willpower * 0.01),
		StaminaCostMult = 1 + 0.04 * weight,
		BlockReduction = math.min(0.9, C.BlockReduction + 0.02 * weight),
		DodgeIFrames = math.max(0.2, C.DodgeIFrames - 0.012 * weight + stats.Agility * 0.002) + sum.DodgeBonus,
		DamageMult = 1 + stats.Strength * S.DamagePerStrength,
		PostureDamageMult = 1 + stats.Strength * S.PostureDamagePerStrength,
		ChargeGain = 1 + sum.ChargeGain + stats.Intelligence * S.ChargePerIntelligence,
		FlickerRate = 1 + sum.FlickerRate + stats.Intelligence * F.RatePerIntelligence,
		FlashBonus = sum.FlashBonus,
		ParryWindow = C.ParryWindow + sum.ParryBonus,
		JumpMult = 1 + sum.Jump,
		Hearing = sum.Hearing, -- studs (client/Senses.lua)
		Scent = sum.Scent,
		Track = track,
		Lift = sum.Lift, -- arms that can take heavier debris (server/Grab.lua)
		Conversion = fitted / #Cybernetics.Slots, -- 1 = all metal
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
	local player = Players:GetPlayerFromCharacter(char)
	return if player then Gear.Get(player) else DEFAULT
end

function Gear.Push(player)
	local data, d = PlayerData.Get(player), derived[player]
	if data and d then
		-- Replicated so every client can draw the weapon in this character's hand (ADR-0004).
		local char = player.Character
		if char then
			char:SetAttribute("Weapon", data.Equipped)
			-- and every implant, so every client can draw the metal on this body (client/Implants.lua)
			for _, slot in Cybernetics.Slots do
				char:SetAttribute("Cyber_" .. slot, data.Cyber[slot])
			end
		end
		-- what this body's ears and nose pick up (client/Senses.lua)
		player:SetAttribute("Hearing", d.Hearing)
		player:SetAttribute("Scent", d.Scent)
		player:SetAttribute("Track", d.Track)
		-- all metal: no longer speaks the way it did (client/Speech.lua, shared/Voice.lua)
		player:SetAttribute("Machine", d.Conversion >= 1)
		Remotes.LoadoutChanged:FireClient(player, {
			Stats = d.Stats, Tags = d.Tags, Resist = d.Resist, MaxPosture = d.MaxPosture, WeightScore = d.WeightScore,
			FlickerRate = d.FlickerRate, FlashBonus = d.FlashBonus, ParryWindow = d.ParryWindow, JumpMult = d.JumpMult,
			Hearing = d.Hearing, Scent = d.Scent, Track = d.Track, Lift = d.Lift, Conversion = d.Conversion, DodgeIFrames = d.DodgeIFrames,
			Weapon = data.Equipped, Armor = data.Armor, Cyber = data.Cyber, Slots = data.SkillSlots,
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

-- Where a cybernetic goes: the slot asked for if it fits, else the first empty slot of its kind, else the
-- first of its kind (a swap). nil if it fits nowhere, or every copy you own is already in you elsewhere.
function Gear.CyberSlot(data, itemId, want)
	local piece = Cybernetics.Pieces[itemId]
	if not piece then
		return nil
	end
	local slots = Cybernetics.SlotsFor(piece)
	local slot
	if want ~= nil then
		slot = if type(want) == "string" and table.find(slots, want) then want else nil
	else
		for _, s in slots do
			if not data.Cyber[s] then
				slot = s
				break
			end
		end
		slot = slot or slots[1]
	end
	if not slot or data.Cyber[slot] == itemId then
		return nil
	end
	if Cybernetics.Fitted(data.Cyber, itemId) >= (data.Inventory[itemId] or 0) then
		return nil -- no spare copy to put in
	end
	return slot
end

-- Armor or cybernetic piece (the item's own slot decides where it goes; a cybernetic may name its slot).
function Gear.EquipGear(player, itemId, slot)
	local data = PlayerData.Get(player)
	if not data or type(itemId) ~= "string" or (data.Inventory[itemId] or 0) <= 0 then
		return false
	end
	if Cybernetics.Pieces[itemId] then
		local at = Gear.CyberSlot(data, itemId, slot)
		if not at then
			return false
		end
		data.Cyber[at] = itemId
		Gear.Recompute(player)
		return true
	end
	local piece = Armor.Pieces[itemId]
	if piece then
		data.Armor[piece.Slot] = itemId
		Gear.Recompute(player)
		return true
	end
	return false
end

-- what: "Weapon" or any armor/cybernetic slot name
function Gear.Unequip(player, what)
	local data = PlayerData.Get(player)
	if not data or type(what) ~= "string" then
		return
	end
	if what == "Weapon" then
		data.Equipped = "Fists"
	elseif FIELD_OF_SLOT[what] then
		data[FIELD_OF_SLOT[what]][what] = nil
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
	for field, source in SOURCES do
		local used = {}
		for _, slot in source.slots do -- in slot order: when a copy is lost, the left side keeps the one that is left
			local id = data[field][slot]
			if id then
				used[id] = (used[id] or 0) + 1
				if used[id] > (data.Inventory[id] or 0) then
					data[field][slot] = nil
				end
			end
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
	Remotes.Unequip.OnServerEvent:Connect(RateLimit.Wrap("Unequip", Config.RateLimit.Unequip, function(player, what)
		if type(what) == "string" and SOURCES.Cyber.slots and table.find(SOURCES.Cyber.slots, what) then
			Remotes.Announce:FireClient(player, "Cybernetics are ripped out at an Autonet.", "Info")
			return -- (server/Autonet.lua)
		end
		Gear.Unequip(player, what)
	end))
	Remotes.SetSkill.OnServerEvent:Connect(RateLimit.Wrap("SetSkill", Config.RateLimit.SetSkill, Gear.SetSkill))
end

return Gear
