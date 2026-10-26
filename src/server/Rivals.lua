-- Rival crews (Phase 3, build order 6; design/gdd/raids.md): other conduits working the same contracts.
-- A crew (shared/Raids.lua Crews) walks its route between raid points, lingers at each, and moves on;
-- its members are Enemies.Defs.Rival with the crew's current point as Home, so they fight whoever
-- they see and go back to work. Nothing announces them. A wiped crew is replaced after
-- CrewRespawnSeconds. Their loot (Items.LootTables.Rival) carries the intel that puts contracts on your board.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local District = require(Shared.District)
local R = require(Shared.Raids)
local NPCs = require(script.Parent.NPCs)

local Rivals = {}

local crews = {} -- id -> { Def, Members = { model = true }, Alive, Waypoint, ArrivedAt, RespawnAt }

local function pointOf(crew)
	return R.Points[crew.Def.Route[crew.Waypoint]]
end

local function spawnCrew(crew)
	local point = pointOf(crew)
	crew.Members, crew.Alive = {}, 0
	for i = 1, crew.Def.Size do
		local offset = Vector3.new((i - 1) * 4 - 2, District.GroundTop + 3.5, 0)
		local model = NPCs.Spawn("Rival", point + offset, {
			Despawn = false,
			Name = "Rival Conduit",
			Home = function()
				return pointOf(crew) + Vector3.new((i - 1) * 4 - 2, 0, 0)
			end,
		})
		if model then
			model:SetAttribute("Crew", crew.Def.Id)
			crew.Members[model] = true
			crew.Alive += 1
			model.Humanoid.Died:Once(function()
				if crew.Members[model] then
					crew.Members[model] = nil
					crew.Alive -= 1
					if crew.Alive <= 0 then
						crew.RespawnAt = os.clock() + R.CrewRespawnSeconds
					end
				end
			end)
		end
	end
	crew.ArrivedAt = nil
end

-- Once a second: a crew that has reached its point works it for CrewLingerSeconds, then moves on.
local function tick(now)
	for _, crew in crews do
		if crew.Alive <= 0 then
			if crew.RespawnAt and now >= crew.RespawnAt then
				crew.RespawnAt = nil
				crew.Waypoint = 1
				spawnCrew(crew)
			end
			continue
		end
		local point = pointOf(crew)
		local allThere = true
		for model in crew.Members do
			local root = model:FindFirstChild("HumanoidRootPart")
			if not root or Vector3.new(root.Position.X - point.X, 0, root.Position.Z - point.Z).Magnitude > 12 then
				allThere = false
			end
		end
		if allThere then
			crew.ArrivedAt = crew.ArrivedAt or now
			if now - crew.ArrivedAt >= R.CrewLingerSeconds then
				crew.Waypoint = crew.Waypoint % #crew.Def.Route + 1
				crew.ArrivedAt = nil
			end
		end
	end
end

function Rivals.Crews()
	return crews
end

function Rivals.Init()
	for _, def in R.Crews do
		local crew = { Def = def, Members = {}, Alive = 0, Waypoint = 1 }
		crews[def.Id] = crew
		spawnCrew(crew)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			tick(os.clock())
		end
	end)
	Rivals.Built = { Crews = #R.Crews }
end

return Rivals
