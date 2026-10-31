-- Population: the city's standing hostiles. Each district gets packs sized by its Danger; they wander
-- near their anchor (through the NPC "Investigate" behaviour), and a dead one comes back after a while.
-- A global cap keeps the server honest. Events, raids and hideout defenders are on top of this.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local City = require(script.Parent.City)
local NPCs = require(script.Parent.NPCs)
local WorldPhase = require(script.Parent.WorldPhase)

local P = Config.City.Population
local Population = {}
local rng = Random.new()
local folder
local alive = 0
local populated = false

local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0))
	return if hit then hit.Position.Y + 3 else 5
end

-- living hostiles only: corpses keep the tag until gore clears them
local function count()
	local n = 0
	for _, model in CollectionService:GetTagged("NPC") do
		local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			n += 1
		end
	end
	return n
end

local spawnOne -- forward

local function wander(model, anchor, radius)
	task.spawn(function()
		while model.Parent do
			task.wait(rng:NextNumber(6, 14))
			if model.Parent and not model:GetAttribute("Investigate") then
				local angle, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, radius)
				model:SetAttribute("Investigate", anchor + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
				model:SetAttribute("InvestigateUntil", os.clock() + 10)
			end
		end
	end)
end

spawnOne = function(typeName, anchor, radius, scale)
	if count() >= P.Cap then
		return nil
	end
	local angle, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
	local x, z = anchor.X + math.cos(angle) * r, anchor.Z + math.sin(angle) * r
	local model = NPCs.Spawn(typeName, Vector3.new(x, groundAt(x, z), z), {
		Parent = folder,
		Scale = scale,
		OnDied = function()
			alive -= 1
			task.delay(P.Respawn, function()
				if WorldPhase.IsOpen() then
					spawnOne(typeName, anchor, radius, scale)
				end
			end)
		end,
	})
	if model then
		alive += 1
		model:SetAttribute("Population", true)
		wander(model, anchor, radius)
	end
	return model
end

-- Spawns every district's packs. Safe to call once; later calls are ignored.
function Population.Populate()
	if populated then
		return 0
	end
	populated = true
	folder = Instance.new("Folder")
	folder.Name = "Population"
	folder.Parent = workspace
	local spawned = 0
	for _, district in City.Districts do
		local tier = P.Tiers[district.Danger]
		if tier then
			for _ = 1, tier.Packs do
				local angle, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(district.Size * 0.12, district.Size * 0.42)
				local anchor = Vector3.new(district.Center.X + math.cos(angle) * r, 0, district.Center.Z + math.sin(angle) * r)
				anchor = Vector3.new(anchor.X, groundAt(anchor.X, anchor.Z), anchor.Z)
				for _ = 1, rng:NextInteger(tier.Size[1], tier.Size[2]) do
					if spawnOne(tier.Types[rng:NextInteger(1, #tier.Types)], anchor, P.PackRadius, tier.Scale or 1) then
						spawned += 1
					end
				end
			end
			if tier.Boss and rng:NextNumber() < tier.Boss then
				local anchor = Vector3.new(district.Center.X, groundAt(district.Center.X, district.Center.Z), district.Center.Z)
				if spawnOne("Warden", anchor, P.PackRadius * 2, 1) then
					spawned += 1
				end
			end
		end
	end
	return spawned
end

function Population.Alive()
	return alive
end

function Population.Init()
	if WorldPhase.IsOpen() then
		Population.Populate()
	end
	WorldPhase.Changed.Event:Connect(function()
		if WorldPhase.IsOpen() then
			Population.Populate()
		end
	end)
end

return Population
