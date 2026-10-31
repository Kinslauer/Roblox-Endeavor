-- The moving hill. One sector is hot. Every 5s each faction earns tickets for soldiers inside;
-- kills inside earn more; holding the majority for CaptureHoldSeconds captures it (big ticket
-- bonus) and the hill walks to a neighbouring sector. It also moves on a timer so it never
-- stalls. No rounds: the scales just keep tipping, forever.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Battlefield = require(script.Parent.Battlefield)
local Factions = require(script.Parent.Factions)

local H = Config.War.Hill
local Hill = {}
Hill.Moved = Instance.new("BindableEvent") -- (oldIndex, newIndex)

local current = 1
local since = 0
local holder, heldSince = nil, 0
local rng = Random.new()
local marker

function Hill.Current()
	return current
end

function Hill.Inside(position)
	return Battlefield.SectorAt(position) == current
end

local function countInside()
	local counts = { Union = 0, Pact = 0 }
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local f = Factions.Of(p)
		if root and hum and hum.Health > 0 and f and Hill.Inside(root.Position) then
			counts[f] += 1
		end
	end
	return counts
end

local function status(counts)
	Remotes.Hill:FireAllClients({ Sector = current, Center = Battlefield.SectorCenter(current), Counts = counts, Holder = holder,
		Held = if holder then os.clock() - heldSince else 0, Need = H.CaptureHoldSeconds, MovesIn = math.max(0, H.MoveAfterSeconds - (os.clock() - since)) })
end

local function move(reason)
	local old = current
	local n = H.Sectors
	local i, j = (current - 1) % n, math.floor((current - 1) / n)
	local options = {}
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ni, nj = i + d[1], j + d[2]
		if ni >= 0 and nj >= 0 and ni < n and nj < n then
			table.insert(options, nj * n + ni + 1)
		end
	end
	current = options[rng:NextInteger(1, #options)]
	since, holder, heldSince = os.clock(), nil, 0
	if marker then
		marker.Position = Battlefield.SectorCenter(current) + Vector3.new(0, 60, 0)
	end
	Remotes.Announce:FireAllClients(("The hill moves to sector %d (%s)."):format(current, reason), "Event")
	Hill.Moved:Fire(old, current)
	-- the sector it left rebuilds once it has been quiet for a while
	task.delay(Config.War.SectorRebuildSeconds, function()
		if current ~= old then
			Battlefield.RebuildSector(old)
		end
	end)
end

-- Called by Soldiers when someone dies.
function Hill.OnKill(killerFaction, position)
	if killerFaction and Hill.Inside(position) then
		Factions.AddTickets(killerFaction, H.TicketsPerKill)
	end
end

function Hill.Init()
	since = os.clock()
	-- a column of light from the ground to the sky with the beacon on top: visible from anywhere on the front
	marker = Instance.new("Part")
	marker.Name, marker.Anchored, marker.CanCollide, marker.CanQuery = "HillMarker", true, false, false
	marker.Shape, marker.Size = Enum.PartType.Ball, Vector3.new(14, 14, 14)
	marker.Material, marker.Color, marker.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 220, 80), 0.3
	marker.Position = Battlefield.SectorCenter(current) + Vector3.new(0, 60, 0)
	local column = Instance.new("Part")
	column.Name, column.Anchored, column.CanCollide, column.CanQuery = "HillColumn", true, false, false
	column.Shape, column.Size = Enum.PartType.Cylinder, Vector3.new(120, 3, 3)
	column.Material, column.Color, column.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 220, 80), 0.6
	column.CFrame = CFrame.new(marker.Position - Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = marker, column
	weld.Parent = column
	column.Parent = marker
	marker.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(5)
			local counts = countInside()
			for f, n in counts do
				Factions.AddTickets(f, n * H.TicketsPerPlayerPer5s)
			end
			local lead = if counts.Union > counts.Pact then "Union" elseif counts.Pact > counts.Union then "Pact" else nil
			if lead ~= holder then
				holder, heldSince = lead, os.clock()
			end
			if holder and os.clock() - heldSince >= H.CaptureHoldSeconds then
				Factions.AddTickets(holder, H.CaptureTickets)
				Remotes.Announce:FireAllClients(("%s captured sector %d."):format(holder, current), "Emergence")
				move("captured")
			elseif os.clock() - since >= H.MoveAfterSeconds then
				move("the front shifts")
			end
			status(counts)
		end
	end)
end

return Hill
