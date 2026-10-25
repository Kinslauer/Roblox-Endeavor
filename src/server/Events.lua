-- The "director": throws random world events at players once the world is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Loot = require(script.Parent.Loot)
local NPCs = require(script.Parent.NPCs)
local WorldPhase = require(script.Parent.WorldPhase)

local Events = {}
local rng = Random.new()

local function randomPlayerRoot()
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(candidates, { player = player, root = root })
		end
	end
	return if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else nil
end

-- Contested loot: announced to everyone, so it pulls players into PvP.
local function supplyDrop()
	local pick = randomPlayerRoot()
	if not pick then
		return
	end
	-- Land it on real ground inside the playable area; try a few spots, shrinking toward the player.
	local pos
	local radius = Config.Events.SupplyRadius
	for try = 1, Config.Events.PlacementTries do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(radius * 0.3, radius)
		local ground = NPCs.FindGround(pick.root.Position + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
		if ground then
			pos = ground + Vector3.new(0, Config.Events.SupplyDropHeight, 0)
			break
		end
		if try % 2 == 0 then
			radius *= 0.7
		end
	end
	if not pos then
		return
	end
	Remotes.Announce:FireAllClients("A supply drop is falling nearby. Others heard it too.", "Event")
	local crate = Loot.Spawn(CFrame.new(pos), Items.Roll("Supply"), {
		Label = "Supply Crate", Action = "Open", Hold = 3, Lifetime = 240,
		Color = Color3.fromRGB(230, 170, 40), Size = Vector3.new(4, 4, 4),
	})
	if crate then
		local beacon = Instance.new("Highlight")
		beacon.FillColor, beacon.DepthMode = Color3.fromRGB(255, 200, 60), Enum.HighlightDepthMode.AlwaysOnTop
		beacon.Parent = crate
	end
end

local function raiderAmbush()
	local pick = randomPlayerRoot()
	if not pick then
		return
	end
	local spawned = NPCs.SpawnAmbush(pick.root.Position)
	if #spawned > 0 then
		Remotes.Announce:FireClient(pick.player, "Raiders have found you.", "Event")
	end
end

-- weight, runner. Add blackout zones, rogue drones, faction wars, etc. here.
local POOL = { { 3, supplyDrop }, { 4, raiderAmbush } }

function Events.Init()
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(60, 150))
			if WorldPhase.IsOpen() and #Players:GetPlayers() > 0 then
				local total = 0
				for _, e in POOL do
					total += e[1]
				end
				local roll = rng:NextNumber(0, total)
				for _, e in POOL do
					roll -= e[1]
					if roll <= 0 then
						task.spawn(e[2])
						break
					end
				end
			end
		end
	end)
end

return Events
