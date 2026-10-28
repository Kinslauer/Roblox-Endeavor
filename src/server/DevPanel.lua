-- The Studio dev panel (owner 2026-10-28: "alot of the things cant be reached because of the known issues").
-- Only in Studio, only with Config.Dev.Enabled: the server marks ReplicatedStorage DevPanel = true and the
-- client (client/DevPanel.lua, key P or the DEV button) shows teleports, gives and switches so every
-- checklist round can be reached without fighting the road first. In a live server the remote does nothing.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local District = require(Shared.District)
local R = require(Shared.Raids)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Autonet = require(script.Parent.Autonet)
local Clues = require(script.Parent.Clues)
local Cycle = require(script.Parent.Cycle)
local Hideout = require(script.Parent.Hideout)
local Inventory = require(script.Parent.Inventory)
local PlayerData = require(script.Parent.PlayerData)
local Terminal = require(script.Parent.Terminal)
local Wallet = require(script.Parent.Wallet)

local DevPanel = {}

DevPanel.Enabled = RunService:IsStudio() and Config.Dev.Enabled == true

local TOP = District.GroundTop + 4
local road = Regions.Road
local function onRoad(frac)
	return Vector3.new(road.X, TOP, road.Z0 + road.Length * frac)
end

-- Where each teleport lands (facing north, +Z, unless the spot says otherwise).
DevPanel.Spots = {
	Plaza1 = District.Districts[1].Origin + Vector3.new(0, TOP, 14),
	Plaza2 = District.Districts[2].Origin + Vector3.new(0, TOP, 14),
	RoadStart = onRoad(0.05),
	RoadBrute = onRoad(0.5),
	RoadWarmonger = onRoad(0.78),
	Verdant = Regions.Enclave.Origin + Vector3.new(0, TOP, -20),
	Dealer = R.Contacts.Dealer.Position + Vector3.new(0, TOP, -6),
	Arena = Config.Dev.ArenaOffset + Vector3.new(0, TOP, 120),
}

local function say(player, text)
	Remotes.Announce:FireClient(player, "DEV: " .. text, "Info")
end

local function teleport(player, spot)
	local char = player.Character
	local pos = DevPanel.Spots[spot]
	if not (char and pos) then
		return
	end
	if player:GetAttribute("Zone") then
		Hideout.Leave(player) -- out of the hideout / war first, so zone state is right
		char = player.Character
	end
	if char then
		char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10)))
		say(player, spot)
	end
end

local function give(player, what)
	if what == "Weapons" then
		for id in Weapons.Defs do
			if id ~= "Fists" and Inventory.Count(player, id) == 0 then
				Inventory.Add(player, id, 1)
			end
		end
	elseif what == "Implants" then
		for id, piece in Cybernetics.Pieces do
			local want = #Cybernetics.SlotsFor(piece)
			local have = Inventory.Count(player, id)
			if have < want then
				Inventory.Add(player, id, want - have)
			end
		end
	elseif what == "Materials" then
		for _, id in { "Scrap", "Wire", "Cloth", "Glass", "SheetMetal", "Pipe", "Battery", "Powder" } do
			Inventory.Add(player, id, 15)
		end
		Inventory.Add(player, "Medkit", 3)
		Inventory.Add(player, "ArcCell", 12)
	elseif what == "Money" then
		Wallet.Add(player, 500)
	else
		return
	end
	Inventory.Push(player)
	say(player, "gave " .. what)
end

-- Everything progression gates: a computer, every contact met, the Autonet schematic read and the bay built.
local function unlock(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.Computer = true
	data.Contacts = data.Contacts or {}
	for id in R.Contacts do
		data.Contacts[id] = true
	end
	if not (data.Knowledge and data.Knowledge.AutonetSchematic) then
		Clues.Read(player, "AutonetSchematic")
	end
	data.Autonet = true
	Autonet.Sync(player)
	Terminal.Sync(player)
	Terminal.Push(player)
	Inventory.Push(player)
	say(player, "computer, contacts, Autonet unlocked")
end

local function heal(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
		char:SetAttribute("Stamina", char:GetAttribute("MaxStamina") or 100)
		char:SetAttribute("Posture", 0)
	end
end

local function clearNearby(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local n = 0
	for _, model in CollectionService:GetTagged("Combatant") do
		local r = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if r and hum and not model:GetAttribute("Contact") and (r.Position - root.Position).Magnitude < 90 then
			hum.Health = 0
			n += 1
		end
	end
	say(player, ("cleared %d enemies"):format(n))
end

function DevPanel.Handle(player, action, arg)
	if not DevPanel.Enabled or type(action) ~= "string" then
		return
	end
	if action == "Teleport" and type(arg) == "string" then
		teleport(player, arg)
	elseif action == "Hideout" then
		Hideout.Enter(player)
	elseif action == "Give" and type(arg) == "string" then
		give(player, arg)
	elseif action == "Unlock" then
		unlock(player)
	elseif action == "Heal" then
		heal(player)
	elseif action == "God" then
		local char = player.Character
		if char then
			local on = not char:GetAttribute("DevGod")
			char:SetAttribute("DevGod", on or nil) -- server/Combat.lua refuses damage to a DevGod body
			say(player, "god mode " .. (if on then "on" else "off"))
		end
	elseif action == "Cycle" then
		Cycle.Schedule(70)
		say(player, "cycle in 70 s")
	elseif action == "Clear" then
		clearNearby(player)
	end
end

function DevPanel.Init()
	ReplicatedStorage:SetAttribute("DevPanel", DevPanel.Enabled)
	Remotes.Dev.OnServerEvent:Connect(DevPanel.Handle)
end

return DevPanel
