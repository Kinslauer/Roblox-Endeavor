-- The Autonet (design/gdd/dematerialization.md §6; owner 2026-10-26): cybernetics are "ripped in", and only
-- here. A conduit learns the schematic (a fragment, shared/Clues.lua AutonetSchematic, Teaches = "Autonet"),
-- crafts the kit (Items.Recipes.AutonetKit, Needs = "Autonet") and installs it in the hideout's empty bay;
-- it stays with the hideout through every death (PlayerData HIDEOUT_KEPT). At the Autonet, cybernetics are
-- ripped in or out from the inventory (Remotes.Autonet). It hurts: each rip costs a share of max health up
-- front (never below 1 HP) and is a channel of Config.Cyber.RipSeconds with the body held in place; a swap is
-- two rips. Anything that interrupts it leaves the body as it was, with the cost already paid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local Remotes = require(Shared.Remotes)
local SC = require(Shared.Clues)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local Lore = require(Shared.Lore)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)

local Autonet = {}

local C = Config.Cyber
Autonet.Position = nil -- set by Hideout when it builds the bay
local ripping = {} -- player -> token

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function near(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root ~= nil and Autonet.Position ~= nil and (root.Position - Autonet.Position).Magnitude <= C.Range
end

function Autonet.Sync(player)
	local data = PlayerData.Get(player)
	if data then
		player:SetAttribute("Autonet", data.Autonet == true) -- the client draws the bay empty or built (HouseView)
	end
end

function Autonet.Install(player)
	local data = PlayerData.Get(player)
	if not data or data.Autonet or not near(player) or not Inventory.Remove(player, "AutonetKit", 1) then
		return false
	end
	data.Autonet = true
	Autonet.Sync(player)
	announce(player, "The Autonet is in. Whatever you rip into this body, it will take - and it will hurt.", "Lore")
	return true
end

-- The bay's prompt: install a kit, explain, or step up to the table.
function Autonet.Use(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if not data.Autonet then
		if Inventory.Count(player, "AutonetKit") > 0 then
			Autonet.Install(player)
		elseif SC.Knows(data.Knowledge, "Autonet") then
			announce(player, "An empty bay. You know how to build the Autonet now (Tab -> crafting).")
		else
			announce(player, "An empty bay. Something goes here, but you don't know what yet.")
		end
		return
	end
	player:SetAttribute("AtAutonet", true)
	announce(player, "On the Autonet. Rip cybernetics in or out from your inventory (Tab). Each rip hurts.")
end

-- action "In" itemId [slot] | "Out" slot. A paired piece (arm, leg) can name its side; otherwise it goes in
-- the first empty slot of its kind.
function Autonet.Rip(player, action, arg, side)
	local data = PlayerData.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and data.Autonet and hum and root and hum.Health > 0) or ripping[player] then
		return false
	end
	if not (player:GetAttribute("AtAutonet") and near(player)) then
		announce(player, "Cybernetics are ripped in at an Autonet.")
		return false
	end
	if Combat.InCombat(player) then
		return false
	end
	local rips, slot, itemId
	if action == "In" then
		local piece = type(arg) == "string" and Cybernetics.Pieces[arg]
		slot = piece and Gear.CyberSlot(data, arg, side)
		if not slot then
			return false
		end
		itemId = arg
		rips = if data.Cyber[slot] then 2 else 1 -- a swap: out, then in
	elseif action == "Out" then
		if type(arg) ~= "string" or not data.Cyber[arg] then
			return false
		end
		slot, rips = arg, 1
	else
		return false
	end
	-- the cost, up front
	local cost = hum.MaxHealth * C.RipHealthCost * rips
	hum.Health = math.max(1, hum.Health - cost)
	local after = hum.Health
	local seconds = C.RipSeconds * rips
	local token = {}
	ripping[player] = token
	root.Anchored = true
	Combat.SetBusy(char, seconds)
	char:SetAttribute("Ripping", seconds)
	Combat.FX("Rip", char, seconds)
	local interrupted = false
	local conn = hum.HealthChanged:Connect(function(h)
		if h < after - 0.5 then
			interrupted = true -- something else hurt you mid-rip
		end
		after = math.min(after, h)
	end)
	task.delay(seconds, function()
		conn:Disconnect()
		if ripping[player] ~= token then
			return
		end
		ripping[player] = nil
		if root.Parent then
			root.Anchored = false
		end
		if char.Parent then
			char:SetAttribute("Ripping", nil)
		end
		if interrupted or not char.Parent or hum.Health <= 0 or player.Character ~= char then
			announce(player, "The rip was cut short. Nothing changed - except how you feel.")
			return
		end
		local wasMachine = Gear.Get(player).Conversion >= 1
		if action == "In" then
			Gear.EquipGear(player, itemId, slot)
			announce(player, ("Ripped in: %s (%s)."):format(Cybernetics.Pieces[itemId].Name, Cybernetics.Label[slot]))
		else
			local was = data.Cyber[slot]
			Gear.Unequip(player, slot)
			announce(player, ("Ripped out: %s."):format(was and Cybernetics.Pieces[was] and Cybernetics.Pieces[was].Name or slot))
		end
		-- the last flesh goes, and the voice goes with it (shared/Voice.lua; cybernetics.md §6)
		local isMachine = Gear.Get(player).Conversion >= 1
		if isMachine and not wasMachine then
			task.delay(1.5, function()
				announce(player, Lore.Get("FullConversion"), "Lore")
			end)
		elseif wasMachine and not isMachine then
			announce(player, "Flesh again, somewhere. Your voice comes back rough, but it is yours.")
		end
		Inventory.Push(player)
	end)
	return true
end

function Autonet.Ripping(player)
	return ripping[player] ~= nil
end

function Autonet.Init()
	Remotes.Autonet.OnServerEvent:Connect(RateLimit.Wrap("Autonet", Config.RateLimit.Autonet, Autonet.Rip))
	-- stepping away from the table ends "at the Autonet"
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("AtAutonet") and not near(p) and not ripping[p] then
				p:SetAttribute("AtAutonet", nil)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		ripping[p] = nil
	end)
	local function watch(p)
		p.CharacterAdded:Connect(function()
			ripping[p] = nil
			p:SetAttribute("AtAutonet", nil)
			task.defer(Autonet.Sync, p)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
		Autonet.Sync(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return Autonet
