-- The "director": throws random world events at players once the world is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
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
	local offset = Vector3.new(rng:NextNumber(-250, 250), 150, rng:NextNumber(-250, 250))
	local pos = pick.root.Position + offset
	Remotes.Announce:FireAllClients("A supply drop is falling near the old transit hub.", "Event")
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
	Remotes.Announce:FireClient(pick.player, "Raiders have found you.", "Event")
	for _ = 1, rng:NextInteger(2, 4) do
		local angle = rng:NextNumber(0, math.pi * 2)
		NPCs.Spawn("Raider", pick.root.Position + Vector3.new(math.cos(angle) * 55, 4, math.sin(angle) * 55))
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
