-- Neural Net terminals: the door to the Front. Using one runs the uplink sequence on the
-- client and then teleports the conduit to the war place with their profile already shared.
-- The recruit app (shop / locker / order) is reachable from the same terminal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local Recruit = require(script.Parent.Common.Recruit)
local Combat = require(script.Parent.Combat)
local City = require(script.Parent.City)
local WorldPhase = require(script.Parent.WorldPhase)

local W = Config.War
local NeuralNet = {}
local uplinking = {}

local function warOf(player)
	local data = PlayerData.Get(player)
	return data and Recruit.Init(data.War)
end

local function push(player)
	local war = warOf(player)
	if war then
		Remotes.RecruitApp:FireClient(player, Recruit.Snapshot(war))
	end
end

local function pickFaction(war)
	if war.Faction == "" then
		-- first deployment: balance the two sides across this server's conduits
		local counts = { Union = 0, Pact = 0 }
		for _, other in Players:GetPlayers() do
			local w = warOf(other)
			if w and counts[w.Faction] then
				counts[w.Faction] += 1
			end
		end
		war.Faction = if counts.Union <= counts.Pact then "Union" else "Pact"
	end
	return war.Faction
end

local function uplink(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local war = warOf(player)
	if not (hum and hum.Health > 0 and war) or uplinking[player] or not WorldPhase.IsOpen() then
		return
	end
	if Combat.InCombat(player) then
		Remotes.Announce:FireClient(player, "You can't tap in while someone is trying to kill you.", "Info")
		return
	end
	pickFaction(war)
	uplinking[player] = true
	Combat.Stun(char, W.UplinkSeconds + 1)
	Combat.GrantIFrames(char, W.UplinkSeconds + 2)
	Remotes.Uplink:FireClient(player, "Begin", W.UplinkSeconds, war.Faction)
	task.delay(W.UplinkSeconds, function()
		uplinking[player] = nil
		if not player.Parent then
			return
		end
		if W.PlaceId == 0 then
			Remotes.Uplink:FireClient(player, "NoPlace")
			Remotes.Announce:FireClient(player, "The Front isn't published yet (Config.War.PlaceId). Uplink aborted.", "Info")
			Combat.Stun(char, 0.1)
			return
		end
		local ok, err = pcall(function()
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ Faction = war.Faction, From = "Conduit" })
			TeleportService:TeleportAsync(W.PlaceId, { player }, options)
		end)
		if not ok then
			warn("[NeuralNet] teleport failed:", err)
			Remotes.Uplink:FireClient(player, "Failed")
			Combat.Stun(char, 0.1)
		end
	end)
end

local function buildTerminal(position, label)
	local model = Instance.new("Model")
	model.Name = "NeuralNetTerminal"
	local body = Instance.new("Part")
	body.Size, body.Anchored = Vector3.new(5, 7, 2.5), true
	body.Position = position + Vector3.new(0, 3.5, 0)
	body.Color, body.Material = Color3.fromRGB(18, 20, 30), Enum.Material.Metal
	body.Parent = model
	local screen = Instance.new("Part")
	screen.Size, screen.Anchored, screen.CanCollide = Vector3.new(4, 3, 0.3), true, false
	screen.Position = position + Vector3.new(0, 4.2, 1.3)
	screen.Material, screen.Color = Enum.Material.Neon, Color3.fromRGB(140, 60, 255)
	screen.Parent = model
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = screen.Color, 30, 2
	light.Parent = screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = screen
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "NEURAL NET\n" .. label
	text.TextColor3, text.Font, text.TextScaled = Color3.new(0, 0, 0), Enum.Font.Code, true
	text.Parent = gui

	local tap = Instance.new("ProximityPrompt")
	tap.ObjectText, tap.ActionText, tap.HoldDuration = "Neural Net", "Tap in", 1.5
	tap.MaxActivationDistance, tap.RequiresLineOfSight, tap.KeyboardKeyCode = 10, false, Enum.KeyCode.X
	tap.Parent = body
	tap.Triggered:Connect(uplink)

	local app = Instance.new("ProximityPrompt")
	app.ObjectText, app.ActionText, app.HoldDuration = "Neural Net", "Recruit app", 0.3
	app.MaxActivationDistance, app.RequiresLineOfSight, app.KeyboardKeyCode = 10, false, Enum.KeyCode.M
	app.UIOffset = Vector2.new(0, 60)
	app.Parent = body
	app.Triggered:Connect(function(player)
		local war = warOf(player)
		if war then
			pickFaction(war)
			push(player)
			Remotes.RecruitApp:FireClient(player, Recruit.Snapshot(war), true)
		end
	end)
	model.Parent = workspace
	return model
end

function NeuralNet.Init()
	-- one terminal per district plaza, plus one by the test armory
	for _, district in City.Districts do
		buildTerminal(district.Center + Vector3.new(0, 2, 30), district.Name)
	end
	if Config.Dev.Enabled then
		buildTerminal(Vector3.new(-50, 2, 132), "THE PIT")
	end

	Net.On("WarBuy", { rate = 4, burst = 6, args = { "string" } }, function(player, id)
		local war = warOf(player)
		if war then
			local ok, reason = Recruit.Buy(war, id)
			if not ok then
				Remotes.Announce:FireClient(player, "Shop: " .. reason, "Info")
			end
			push(player)
		end
	end)
	Net.On("WarRepair", { rate = 4, burst = 6, args = { "string" } }, function(player, id)
		local war = warOf(player)
		if war then
			local ok, reason = Recruit.Repair(war, id)
			if not ok then
				Remotes.Announce:FireClient(player, "Repair: " .. reason, "Info")
			end
			push(player)
		end
	end)
	Net.On("WarOrder", { rate = 4, burst = 6, args = { "table" } }, function(player, loadout)
		local war = warOf(player)
		if war then
			if not Recruit.Order(war, loadout) then
				Remotes.Announce:FireClient(player, "Order rejected: only locker items can be ordered.", "Info")
			end
			push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		uplinking[player] = nil
	end)
end

return NeuralNet
