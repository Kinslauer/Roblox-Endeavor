-- The weapon bench (Phase 3, build order 4; design/gdd/gunplay.md §4). At the hideout's workbench a
-- gun comes apart: fit a part into one of its slots (shared/Attachments.lua), strip a slot, or strip
-- the whole thing back to the frame. Parts move between the inventory and the weapon's BUILD
-- (profile.Builds[weaponId]); Combat and the client read the effective weapon through
-- Attachments.Apply, so a fitted part is a real change to spread, recoil, magazine, reach.
-- Server-authoritative: the client only asks (Remotes.Bench), and only from inside Config.Bench.Zone.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Attachments = require(Shared.Attachments)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Bench = {}

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

-- Builds travel to the client as one JSON attribute (Aim's recoil, the HUD's bench section).
function Bench.Publish(player)
	local data = PlayerData.Get(player)
	if data then
		player:SetAttribute("Builds", HttpService:JSONEncode(data.Builds or {}))
	end
end

-- The effective definition of a weapon the player owns (Combat uses this for the equipped one).
function Bench.WeaponDef(data, weaponId)
	local def = Weapons.Defs[weaponId]
	return Attachments.Apply(def, data and data.Builds and data.Builds[weaponId])
end

local function after(player, data, weaponId)
	Gear.Recompute(player)
	local char = player.Character
	if char and char:GetAttribute("Weapon") == weaponId then
		Combat.SyncAmmo(char, Bench.WeaponDef(data, weaponId)) -- magazine may have changed
	end
	Bench.Publish(player)
	Inventory.Push(player)
end

local function atBench(player)
	if player:GetAttribute("Zone") ~= Config.Bench.Zone then
		announce(player, "The bench is in the hideout.")
		return false
	end
	return true
end

function Bench.Fit(player, weaponId, partId)
	local data = PlayerData.Get(player)
	if not (data and atBench(player)) then
		return false
	end
	local def, part = Weapons.Defs[weaponId], Attachments.Parts[partId]
	if not (def and part) or (data.Inventory[weaponId] or 0) <= 0 or Inventory.Count(player, partId) <= 0 then
		return false
	end
	if not Attachments.Fits(partId, def) then
		announce(player, ("%s does not fit a %s."):format(part.Name, def.Name))
		return false
	end
	data.Builds[weaponId] = data.Builds[weaponId] or {}
	local build = data.Builds[weaponId]
	local previous = build[part.Slot]
	Inventory.Remove(player, partId, 1)
	build[part.Slot] = partId
	if previous then
		Inventory.Add(player, previous, 1) -- the old part comes off into your hands
	end
	after(player, data, weaponId)
	announce(player, ("%s: %s fitted (%s)."):format(def.Name, part.Name, part.Slot))
	return true
end

function Bench.Strip(player, weaponId, slot)
	local data = PlayerData.Get(player)
	if not (data and atBench(player)) then
		return false
	end
	local build = data.Builds[weaponId]
	local partId = build and build[slot]
	if not partId then
		return false
	end
	build[slot] = nil
	if next(build) == nil then
		data.Builds[weaponId] = nil
	end
	Inventory.Add(player, partId, 1)
	after(player, data, weaponId)
	announce(player, ("%s: %s removed."):format(Weapons.Defs[weaponId].Name, Attachments.Parts[partId].Name))
	return true
end

-- Down to the frame: every part back into the inventory.
function Bench.StripAll(player, weaponId)
	local data = PlayerData.Get(player)
	if not (data and atBench(player)) then
		return false
	end
	local build = data.Builds[weaponId]
	if not build then
		return false
	end
	local n = 0
	for _, partId in build do
		Inventory.Add(player, partId, 1)
		n += 1
	end
	data.Builds[weaponId] = nil
	after(player, data, weaponId)
	announce(player, ("%s stripped to the frame: %d parts off."):format(Weapons.Defs[weaponId].Name, n))
	return true
end

-- Remotes.Bench(action, weaponId, arg): "Fit" (arg = partId), "Strip" (arg = slot), "StripAll"
local function onBench(player, action, weaponId, arg)
	if type(weaponId) ~= "string" or not Weapons.Defs[weaponId] then
		return
	end
	if action == "Fit" and type(arg) == "string" then
		Bench.Fit(player, weaponId, arg)
	elseif action == "Strip" and type(arg) == "string" then
		Bench.Strip(player, weaponId, arg)
	elseif action == "StripAll" then
		Bench.StripAll(player, weaponId)
	end
end

function Bench.Init()
	Remotes.Bench.OnServerEvent:Connect(RateLimit.Wrap("Bench", Config.RateLimit.Bench, onBench))
end

return Bench
