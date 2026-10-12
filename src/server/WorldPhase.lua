-- The core hook: it feels like a solo game (private plots, nobody else visible)
-- until Emergence, when the walls come down and everyone is dropped into the city.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local WorldPhase = {}
WorldPhase.Changed = Instance.new("BindableEvent")

local phase = Config.Phases.Prologue
local slots, plots = {}, {}
local timerStarted = false
local rng = Random.new()

local function plotCFrame(slot)
	return CFrame.new(Config.PlotOrigin + Vector3.new(slot * Config.PlotSpacing, 0, 0))
end

local function wall(parent, size, position)
	local p = Instance.new("Part")
	p.Size, p.Position, p.Anchored = size, position, true
	p.Color, p.Material = Color3.fromRGB(35, 38, 45), Enum.Material.Concrete
	p.Parent = parent
end

-- Placeholder "apartment". Replace with a real tutorial interior later.
local function buildPlot(slot)
	local model = Instance.new("Model")
	model.Name = "Prologue_" .. slot
	local o = plotCFrame(slot).Position
	wall(model, Vector3.new(60, 2, 60), o) -- floor
	wall(model, Vector3.new(60, 2, 60), o + Vector3.new(0, 24, 0)) -- ceiling
	wall(model, Vector3.new(60, 24, 2), o + Vector3.new(0, 12, 30))
	wall(model, Vector3.new(60, 24, 2), o + Vector3.new(0, 12, -30))
	wall(model, Vector3.new(2, 24, 60), o + Vector3.new(30, 12, 0))
	wall(model, Vector3.new(2, 24, 60), o + Vector3.new(-30, 12, 0))
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 40, 2, Color3.fromRGB(120, 200, 255)
	light.Parent = model:FindFirstChildWhichIsA("Part")
	model.Parent = workspace
	return model
end

function WorldPhase.AssignPlot(player)
	if slots[player] then
		return
	end
	local used = {}
	for _, s in slots do
		used[s] = true
	end
	local i = 1
	while used[i] do
		i += 1
	end
	slots[player] = i
	plots[player] = buildPlot(i)
end

function WorldPhase.ReleasePlot(player)
	if plots[player] then
		plots[player]:Destroy()
	end
	plots[player], slots[player] = nil, nil
end

function WorldPhase.IsOpen()
	return phase == Config.Phases.Open
end

function WorldPhase.GetSpawnCFrame(player)
	if phase == Config.Phases.Open then
		local spawns = CollectionService:GetTagged("CitySpawn")
		if #spawns > 0 then
			return spawns[rng:NextInteger(1, #spawns)].CFrame + Vector3.new(0, 4, 0)
		end
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(20, Config.CityFallbackRadius)
		return CFrame.new(math.cos(a) * r, Config.CityFallbackHeight, math.sin(a) * r)
	end
	WorldPhase.AssignPlot(player)
	return plotCFrame(slots[player]) + Vector3.new(0, 4, 0)
end

function WorldPhase.Emerge()
	if phase == Config.Phases.Open then
		return
	end
	Remotes.PhaseChanged:FireAllClients("Emerging")
	Remotes.Announce:FireAllClients("The walls fall away. You were never alone.", "Emergence")
	task.wait(Config.EmergenceCinematic)

	phase = Config.Phases.Open
	workspace:SetAttribute("Phase", phase)
	for _, player in Players:GetPlayers() do
		local profile, char = PlayerData.Get(player), player.Character
		if profile then
			profile.Awakened = true
		end
		if char then
			char:PivotTo(WorldPhase.GetSpawnCFrame(player))
		end
		WorldPhase.ReleasePlot(player)
	end
	Remotes.PhaseChanged:FireAllClients("Open")
	WorldPhase.Changed:Fire(phase)
end

function WorldPhase.StartTimer()
	if timerStarted or phase == Config.Phases.Open then
		return
	end
	timerStarted = true
	task.delay(if Config.Dev.Enabled then Config.Dev.PrologueSeconds else Config.PrologueSeconds, WorldPhase.Emerge)
end

function WorldPhase.Init()
	workspace:SetAttribute("Phase", phase)
	if #CollectionService:GetTagged("CitySpawn") == 0 then
		-- No city built yet: lay down a placeholder slab so the game is testable.
		local ground = Instance.new("Part")
		ground.Name, ground.Anchored = "PlaceholderCity", true
		ground.Size, ground.Position = Vector3.new(1200, 4, 1200), Vector3.new(0, 0, 0)
		ground.Color, ground.Material = Color3.fromRGB(50, 50, 55), Enum.Material.Asphalt
		ground.Parent = workspace
	end
end

return WorldPhase
