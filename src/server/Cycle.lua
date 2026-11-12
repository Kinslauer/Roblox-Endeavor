-- The cycle: every Config.Destruction.CycleSeconds the world dematerializes and comes back exactly as it was.
-- Restored: every broken prop, breach and structure (Destruction.Reset). Cleared: loose remains and drops
-- nobody looted (except inside a green pocket), hands emptied, every woken frontier encounter and sprung ambush. Redrawn: where each contact
-- stands, each contact's line, which fragments lie where (Clues.Draw). Players stay where they stand with
-- what they carry; the hideout is untouched. The clock starts when the world opens.
--   T-Warning: banner + World "DematerializeWarning" (debris flickers)
--   T-Flicker: World "Flicker" (colour drains on the client)
--   T:         World "Dematerialize" (a second of white), the reset, the redraw
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Clues = require(Shared.Clues)
local Megacity = require(Shared.Megacity)
local CluesServer = require(script.Parent.CluesServer)
local Contacts = require(script.Parent.Contacts)
local Destruction = require(script.Parent.Destruction)
local Frontier = require(script.Parent.Frontier)
local Barrens = require(script.Parent.Barrens)
local WorldPhase = require(script.Parent.WorldPhase)

local Cycle = {}
local C = Config.Cycle
local D = Config.Destruction
local index = 0
local nextAt = nil
local running = false
local LOOSE = { ["Remains"] = true, ["Dropped gear"] = true, ["Spoils"] = true, ["Salvage"] = true, ["Shocker Nest"] = true, ["Blast Remains"] = true }

local function seconds()
	return if Config.Dev.Enabled then Config.Dev.CycleSeconds else D.CycleSeconds
end

local function clearLoose()
	local n = 0
	for _, part in workspace:GetDescendants() do
		-- the green pockets stand outside the hour: what lies in one is still there after the reset
		if part.Name == "Lootable" and LOOSE[part:GetAttribute("Label")] and not (part:IsA("BasePart") and Megacity.PocketAt(part.Position)) then
			part:Destroy()
			n += 1
		end
	end
	return n
end

-- The reset and the redraw, in one go. Returns what the draw did (for the log and the tests).
function Cycle.Run()
	index += 1
	local rng = Random.new(index * 7919 + (tonumber(workspace:FindFirstChild("Frontier") and workspace.Frontier:GetAttribute("Seed")) or 0))
	Remotes.World:FireAllClients("Dematerialize", C.WhiteoutSeconds)
	Destruction.Reset()
	-- round 6: the hour picks the sky, and relocks the strongrooms (server/Sky, server/Keys)
	pcall(function()
		require(script.Parent.Sky).Roll(Random.new(index * 104729 + os.time() % 1000))
	end)
	pcall(function()
		require(script.Parent.Keys).Reset()
	end)
	local loose = clearLoose()
	local stood = Frontier.StandDownAll()
	local okB, errB = pcall(Barrens.Reset) -- the hour reaches the barrens too
	if not okB then
		warn("[Cycle] barrens reset failed:", errB)
	end
	local placed = Contacts.Place(rng)
	local lines = {}
	for id in Clues.Lines do
		local i = Clues.DrawLine(id, rng)
		lines[id] = i
		workspace:SetAttribute("CycleLine_" .. id, i)
	end
	local fragments = CluesServer.Draw(index, rng)
	local nf = 0
	for _ in fragments do
		nf += 1
	end
	workspace:SetAttribute("Cycle", index)
	print(("[Cycle] %d: %d loose lootables cleared, %d encounters stood down, contacts at %s, %d fragments out"):format(index, loose, stood,
		(function()
			local t = {}
			for id, spot in placed do
				table.insert(t, id .. "=" .. spot)
			end
			table.sort(t)
			return table.concat(t, " ")
		end)(), nf))
	Cycle.Last = { Index = index, Loose = loose, StoodDown = stood, Contacts = placed, Lines = lines, Fragments = fragments }
	return Cycle.Last
end

-- The full sequence with its warnings (what the clock does); Trigger runs it now.
function Cycle.Trigger()
	if running then
		return nil
	end
	running = true
	local result = Cycle.Run()
	running = false
	return result
end

local function loop()
	while true do
		local total = seconds()
		nextAt = os.clock() + total
		task.wait(math.max(1, total - D.CycleWarning))
		Remotes.World:FireAllClients("DematerializeWarning", D.CycleWarning) -- debris flickers; nothing says why
		task.wait(math.max(0, D.CycleWarning - C.FlickerSeconds))
		Remotes.World:FireAllClients("Flicker", C.FlickerSeconds)
		task.wait(C.FlickerSeconds)
		Cycle.Trigger()
	end
end

function Cycle.Index()
	return index
end

function Cycle.State()
	return { Index = index, NextIn = nextAt and math.max(0, nextAt - os.clock()) or nil }
end

function Cycle.Init()
	local started = false
	local function start()
		if not started then
			started = true
			-- the first materialization is the world opening: the first draw happens now
			Cycle.Run()
			task.spawn(loop)
		end
	end
	if WorldPhase.IsOpen() then
		start()
	end
	WorldPhase.Changed.Event:Connect(function()
		if WorldPhase.IsOpen() then
			start()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5)
			CluesServer.SendVisible(player)
		end)
	end)
end

return Cycle
