-- The "director": throws random world events at players once the world is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local City = require(script.Parent.City)
local Destruction = require(script.Parent.Destruction)
local Hideouts = require(script.Parent.Hideouts)
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
	Remotes.World:FireAllClients("Marker", "SupplyDrop", pos, "Supply drop", 240, Color3.fromRGB(255, 200, 60))
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
	local pack = { "Raider", "Raider", "Raider", "Shocker", "Brute" }
	for i = 1, rng:NextInteger(2, 4) do
		local angle = rng:NextNumber(0, math.pi * 2)
		NPCs.Spawn(pack[rng:NextInteger(1, if i == 1 then 3 else #pack)], pick.root.Position + Vector3.new(math.cos(angle) * 55, 4, math.sin(angle) * 55))
	end
end

-- The grid fails: the whole city goes dark for a while and Shockers come out of the substations.
local function blackout()
	local seconds = rng:NextInteger(60, 110)
	Remotes.Announce:FireAllClients("Grid failure. The city is dark. Shockers are out.", "Event")
	Remotes.World:FireAllClients("Blackout", seconds)
	for _, pick in { randomPlayerRoot(), randomPlayerRoot() } do
		if pick then
			for _ = 1, 2 do
				local angle = rng:NextNumber(0, math.pi * 2)
				NPCs.Spawn("Shocker", pick.root.Position + Vector3.new(math.cos(angle) * 70, 4, math.sin(angle) * 70))
			end
		end
	end
end

-- A Warden walks a district. Its loot table is the good one; everyone is told where it is.
local function wardenPatrol()
	local district = City.Districts[rng:NextInteger(1, #City.Districts)]
	local c = district.Center
	local pos = Vector3.new(c.X + rng:NextNumber(-80, 80), 6, c.Z + rng:NextNumber(-80, 80))
	Remotes.Announce:FireAllClients(("A Warden is patrolling %s."):format(district.Name), "Event")
	Remotes.World:FireAllClients("Marker", "Warden", pos, "Warden", 150, Color3.fromRGB(255, 60, 80))
	NPCs.Spawn("Warden", pos)
end

-- Fresh salvage: a cluster of intact props drops in near someone, for whoever breaks them first.
local SALVAGE = { "Barrel", "Crate", "Crate", "VendingMachine", "Terminal", "Barrel" }
local function salvageCache()
	local pick = randomPlayerRoot()
	if not pick then
		return
	end
	local base = pick.root.Position + Vector3.new(rng:NextNumber(-90, 90), 0, rng:NextNumber(-90, 90))
	local ground = workspace:Raycast(base + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0))
	local y = if ground then ground.Position.Y else base.Y - 3
	local count = 0
	for i = 1, rng:NextInteger(5, 8) do
		local angle, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, 9)
		local cf = CFrame.new(base.X + math.cos(angle) * r, y, base.Z + math.sin(angle) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if Destruction.SpawnProp(SALVAGE[rng:NextInteger(1, #SALVAGE)], cf) then
			count += 1
		end
	end
	if count > 0 then
		Remotes.Announce:FireClient(pick.player, "Salvage nearby: a cache of intact gear fell off a convoy.", "Event")
		Remotes.World:FireClient(pick.player, "Marker", "Salvage", Vector3.new(base.X, y + 4, base.Z), "Salvage", 120, Color3.fromRGB(120, 230, 160))
	end
end

-- A dead conduit's stash at one of the hideout sites. Pulls people to the plots.
local function deadDrop()
	local sites = Hideouts.Sites
	if not sites or #sites == 0 then
		return
	end
	local site = sites[rng:NextInteger(1, #sites)]
	local cf = CFrame.new(site.Position + Vector3.new(rng:NextNumber(-20, 20), 3, rng:NextNumber(-20, 20)))
	Remotes.Announce:FireAllClients(("A dead conduit's drop was spotted at hideout site %d."):format(site.Index), "Event")
	Remotes.World:FireAllClients("Marker", "DeadDrop", cf.Position, "Dead drop", 180, Color3.fromRGB(190, 90, 255))
	Loot.Spawn(cf, Items.Roll("Supply"), { Label = "Dead Drop", Action = "Claim", Hold = 2, Lifetime = 180, Color = Color3.fromRGB(120, 40, 160), Size = Vector3.new(3, 2, 3) })
end

Events.Fire = { SupplyDrop = supplyDrop, RaiderAmbush = raiderAmbush, Blackout = blackout, WardenPatrol = wardenPatrol, SalvageCache = salvageCache, DeadDrop = deadDrop }

-- weight, runner
local POOL = { { 3, supplyDrop }, { 4, raiderAmbush }, { 2, blackout }, { 1, wardenPatrol }, { 3, salvageCache }, { 2, deadDrop } }

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
