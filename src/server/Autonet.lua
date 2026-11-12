-- The Autonet (ported from combat-feel; owner: "the cybernetics are intended to be completely usable, you could make
-- someone 100% metal"): cybernetics are ripped in or out of the body here and nowhere else. A hideout builds one
-- as a module; the test arena has one by the Cybernetics Bay. It hurts: each rip costs a share of max health up
-- front (never below 1 HP) and holds the body in place for Config.Cyber.RipSeconds; a swap is two rips. Anything
-- that hurts you mid-rip leaves the body as it was, with the cost already paid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)

local Autonet = {}
local C = Config.Cyber
local tables = {} -- every Autonet in the world: positions (a hideout's bay, the arena's)
local ripping = {} -- player -> token

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function nearest(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for _, pos in tables do
		if (root.Position - pos).Magnitude <= C.Range then
			return pos
		end
	end
	return nil
end

-- A table exists at `position` (called by Hideouts when the module is built, by Arena at start).
function Autonet.Register(position)
	table.insert(tables, position)
end

function Autonet.Unregister(position)
	local i = table.find(tables, position)
	if i then
		table.remove(tables, i)
	end
end

-- The table's prompt: step up to it. "AtAutonet" is what unlocks the rip buttons on the client.
function Autonet.Use(player)
	if not nearest(player) then
		return
	end
	player:SetAttribute("AtAutonet", true)
	announce(player, "On the Autonet. Rip cybernetics in or out from your pack (Tab). Each rip costs a third of your health.")
end

-- action "In" itemId [slot] | "Out" slot. A paired piece (arm, leg) can name its side; otherwise it goes in the
-- first empty slot of its kind.
function Autonet.Rip(player, action, arg, side)
	local data = PlayerData.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and hum and root and hum.Health > 0) or ripping[player] then
		return false
	end
	if not (player:GetAttribute("AtAutonet") and nearest(player)) then
		announce(player, "Cybernetics are ripped in at an Autonet.")
		return false
	end
	if Combat.InCombat(player) then
		announce(player, "Not while you are fighting.")
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
	Remotes.CombatEvent:FireAllClients("Rip", char, seconds)
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
			if Autonet.Fitted then
				Autonet.Fitted(player, char, slot) -- metal where a limb was lost ends the loss (server/Medicine)
			end
			announce(player, ("Ripped in: %s (%s)."):format(Cybernetics.Pieces[itemId].Name, Cybernetics.Label[slot]))
		else
			local was = data.Cyber[slot]
			Gear.Unequip(player, slot)
			announce(player, ("Ripped out: %s."):format(was and Cybernetics.Pieces[was] and Cybernetics.Pieces[was].Name or slot))
		end
		-- the last flesh goes, and the voice goes with it (shared/Voice.lua)
		local isMachine = Gear.Get(player).Conversion >= 1
		if isMachine and not wasMachine then
			task.delay(1.5, function()
				announce(player, "There is nothing left in you that remembers how to speak. The words come out anyway, flat and exact.", "Lore")
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
	Net.On("Autonet", { rate = 2, burst = 4, args = { "string", "string?", "string?" } }, Autonet.Rip)
	-- stepping away from the table ends "at the Autonet"
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("AtAutonet") and not nearest(p) and not ripping[p] then
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
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return Autonet
