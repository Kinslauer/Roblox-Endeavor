-- Procedural ruined megacity. Generated from code so the world exists before any art is made;
-- replace districts with hand-built ones by giving a folder the same attributes.
--
-- Layout (top-down): the arena/Pit sits at the origin. Districts are square blocks of streets
-- and ruined towers placed around it. Each district has a flavour, loot caches, and (for one of
-- them) the raid gate. Players get a banner when they cross into a new district.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Assets = require(Shared.Assets)
local Destruction = require(script.Parent.Destruction)
local ModelAssets = require(script.Parent.ModelAssets)
local Loot = require(script.Parent.Loot)
local Quests = require(script.Parent.Quests)

local City = {}
City.Entered = Instance.new("BindableEvent") -- (player, districtName)

local GROUND_TOP = 2
local rng = Random.new(1337) -- fixed seed: the city is the same every server

-- Center, size (studs), block grid, tower height range, palette, cache count, danger label.
City.Districts = {
	{ Name = "Transit Hub", Style = "Transit", Center = Vector3.new(0, 0, -420), Size = 420, Blocks = 4, Height = { 14, 40 }, Caches = 8, Danger = "Low",
		Color = Color3.fromRGB(60, 64, 78), Neon = Color3.fromRGB(0, 220, 255), Collapse = 0.25, Lockup = "Weak" },
	{ Name = "Corp Plaza", Style = "Corp", Center = Vector3.new(420, 0, 0), Size = 420, Blocks = 3, Height = { 40, 110 }, Caches = 6, Danger = "Medium",
		Color = Color3.fromRGB(70, 72, 90), Neon = Color3.fromRGB(255, 50, 160), Collapse = 0.15, Lockup = "Reinforced", Sealed = true },
	{ Name = "The Sprawl", Style = "Sprawl", Center = Vector3.new(-420, 0, 0), Size = 420, Blocks = 6, Height = { 8, 22 }, Caches = 12, Danger = "Medium",
		Color = Color3.fromRGB(78, 66, 56), Neon = Color3.fromRGB(255, 170, 40), Collapse = 0.4, Lockup = "Standard" },
	{ Name = "Blackout Zone", Style = "Blackout", Center = Vector3.new(0, 0, 420), Size = 420, Blocks = 4, Height = { 20, 70 }, Caches = 6, Danger = "High",
		Color = Color3.fromRGB(30, 30, 38), Neon = Color3.fromRGB(255, 30, 30), Collapse = 0.5, Raid = true, Lockup = "Reinforced" },
}

local folder

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function tower(district, x, z, footprint)
	-- Blender kit first: a building whose height class fits the district, collapsed by the district's odds
	local entry = Assets.PickBuilding(district.Style, district.Height[1], district.Height[2], district.Collapse, rng)
	if entry then
		local yaw = rng:NextInteger(0, 3) * math.pi / 2
		local model, size = ModelAssets.Spawn(entry.Id, CFrame.new(x, GROUND_TOP, z) * CFrame.Angles(0, yaw, 0), "Building", folder)
		if model then
			model:SetAttribute("Style", district.Style)
			if not entry.Collapsed and entry.Height > 24 and rng:NextNumber() < 0.5 then
				-- a walkable ledge partway up for verticality (gameplay, so it stays generated)
				part({ Name = "Ledge", Size = Vector3.new(size.X + 6, 1, 4), Position = Vector3.new(x, GROUND_TOP + entry.Height * 0.5, z + size.Z / 2 + 2), Color = district.Color, Material = Enum.Material.Metal })
			end
			return model
		end
	end
	local h = rng:NextInteger(district.Height[1], district.Height[2])
	local collapsed = rng:NextNumber() < district.Collapse
	if collapsed then
		-- a broken stump plus rubble you can climb
		h = math.max(6, math.floor(h * rng:NextNumber(0.2, 0.5)))
		part({ Name = "Rubble", Size = Vector3.new(footprint * 0.8, 3, footprint * 0.6), Position = Vector3.new(x + footprint * 0.2, GROUND_TOP + 1.5, z - footprint * 0.3),
			Color = district.Color, Material = Enum.Material.Concrete, Orientation = Vector3.new(0, rng:NextNumber(0, 90), rng:NextNumber(5, 20)) })
	end
	local body = part({ Name = "Tower", Size = Vector3.new(footprint, h, footprint), Position = Vector3.new(x, GROUND_TOP + h / 2, z),
		Color = district.Color, Material = Enum.Material.Concrete })
	if not collapsed and rng:NextNumber() < 0.7 then
		-- neon signage strip, the only light in most streets
		local y = GROUND_TOP + rng:NextNumber(6, h - 3)
		local strip = part({ Size = Vector3.new(footprint * 0.6, 0.6, 0.4), Position = Vector3.new(x, y, z - footprint / 2 - 0.2),
			Material = Enum.Material.Neon, Color = district.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = district.Neon, 30, 1.2
		light.Parent = strip
	end
	if not collapsed then
		-- window panes on the street face: cheap, breakable, drop glass
		for k = 1, math.min(3, math.floor(h / 10)) do
			Destruction.SpawnProp("WindowPane", CFrame.new(x + (k - 2) * 8, GROUND_TOP + 4 + (k - 1) * 3, z - footprint / 2 - 0.3))
		end
	end
	if h > 24 and rng:NextNumber() < 0.5 then
		-- a walkable ledge partway up for verticality
		part({ Name = "Ledge", Size = Vector3.new(footprint + 6, 1, 4), Position = Vector3.new(x, GROUND_TOP + h * 0.5, z + footprint / 2 + 2), Color = district.Color, Material = Enum.Material.Metal })
	end
	return body
end

local function cache(district, position)
	local bundle = Items.Roll("Supply")
	local crate = Loot.Spawn(CFrame.new(position), bundle, { Label = "Cache", Action = "Open", Hold = 2, Lifetime = 1e9, Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(60, 70, 60) })
	if crate then
		crate.Anchored = true
		crate.Parent = folder
		CollectionService:AddTag(crate, "Cache")
		-- caches refill after a while so exploration stays rewarding
		crate.Destroying:Connect(function()
			task.delay(Config.City.CacheRespawn, function()
				if folder.Parent then
					cache(district, position)
				end
			end)
		end)
	end
end

-- A locked building: a box with a breach door of the district's tier and a vault cache inside.
local function lockup(district, position, tier)
	local w, h, dpth = 24, 12, 24
	local c = position
	part({ Name = "LockupFloor", Size = Vector3.new(w, 1, dpth), Position = c + Vector3.new(0, GROUND_TOP + 0.5, 0), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupRoof", Size = Vector3.new(w, 1, dpth), Position = c + Vector3.new(0, GROUND_TOP + h, 0), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupWall", Size = Vector3.new(w, h, 1), Position = c + Vector3.new(0, GROUND_TOP + h / 2, dpth / 2), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupWall", Size = Vector3.new(1, h, dpth), Position = c + Vector3.new(w / 2, GROUND_TOP + h / 2, 0), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupWall", Size = Vector3.new(1, h, dpth), Position = c + Vector3.new(-w / 2, GROUND_TOP + h / 2, 0), Color = district.Color, Material = Enum.Material.Concrete })
	-- front wall with an opening filled by the breach door
	local doorW, doorH = 8, 9
	part({ Name = "LockupWall", Size = Vector3.new((w - doorW) / 2, h, 1), Position = c + Vector3.new(-(doorW / 2 + (w - doorW) / 4), GROUND_TOP + h / 2, -dpth / 2), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupWall", Size = Vector3.new((w - doorW) / 2, h, 1), Position = c + Vector3.new(doorW / 2 + (w - doorW) / 4, GROUND_TOP + h / 2, -dpth / 2), Color = district.Color, Material = Enum.Material.Concrete })
	part({ Name = "LockupWall", Size = Vector3.new(doorW, h - doorH, 1), Position = c + Vector3.new(0, GROUND_TOP + doorH + (h - doorH) / 2, -dpth / 2), Color = district.Color, Material = Enum.Material.Concrete })
	local breach = Destruction.SpawnBreach(tier, CFrame.new(c + Vector3.new(0, GROUND_TOP + doorH / 2, -dpth / 2)), Vector3.new(doorW, doorH, 1))
	local sign = part({ Size = Vector3.new(doorW, 1, 0.3), Position = c + Vector3.new(0, GROUND_TOP + doorH + 1, -dpth / 2 - 0.6), Material = Enum.Material.Neon, Color = district.Neon, CanCollide = false })
	sign:SetAttribute("Label", breach:GetAttribute("Label"))
	-- the prize: a vault cache and a supply cache, refilling like any cache
	local function vault(pos, tableName)
		local crate = Loot.Spawn(CFrame.new(pos), Items.Roll(tableName), { Label = "Vault Cache", Action = "Open", Hold = 2.5, Lifetime = 1e9, Size = Vector3.new(3.5, 3.5, 3.5), Color = Color3.fromRGB(120, 100, 40) })
		if crate then
			crate.Anchored = true
			crate.Parent = folder
			CollectionService:AddTag(crate, "Cache")
			crate.Destroying:Connect(function()
				task.delay(Config.City.CacheRespawn * 2, function()
					if folder.Parent then
						vault(pos, tableName)
					end
				end)
			end)
		end
	end
	vault(c + Vector3.new(-5, GROUND_TOP + 2.8, 6), "Vault")
	vault(c + Vector3.new(5, GROUND_TOP + 2.8, 6), "Supply")
	return breach
end

local STREET_PROPS = { "Streetlight", "StreetSign", "Crate", "Barrel", "FencePanel", "VendingMachine", "Terminal", "CarWreck", "Slab" }

-- The four corner quadrants between districts: unnamed outskirts of low ruins, wrecks and
-- rubble so the city reads as one continuous place instead of four islands.
local OUTSKIRTS = { Style = "Outskirts", Color = Color3.fromRGB(52, 50, 56), Neon = Color3.fromRGB(120, 120, 140), Height = { 6, 16 }, Collapse = 0.6 }
local function buildOutskirts()
	local inner, outer = 150, 620 -- stay clear of the Pit/armory and the district squares
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for i = 1, 14 do
				local x = sx * rng:NextNumber(inner, outer)
				local z = sz * rng:NextNumber(inner, outer)
				-- skip anything that lands inside a district square
				if not City.DistrictAt(Vector3.new(x, 0, z)) then
					tower(OUTSKIRTS, x, z, rng:NextNumber(14, 26))
					local propId = STREET_PROPS[rng:NextInteger(1, #STREET_PROPS)]
					Destruction.SpawnProp(propId, CFrame.new(x + rng:NextNumber(-20, 20), GROUND_TOP, z + rng:NextNumber(-20, 20)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				end
			end
			-- a wrecked road between the quadrant's two districts
			for k = 1, 6 do
				local along = rng:NextNumber(inner, outer)
				Destruction.SpawnProp(if k % 2 == 0 then "CarWreck" else "Slab", CFrame.new(sx * along, GROUND_TOP, sz * rng:NextNumber(90, 130)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				Destruction.SpawnProp(if k % 2 == 0 then "Barrel" else "Streetlight", CFrame.new(sx * rng:NextNumber(90, 130), GROUND_TOP, sz * along))
			end
		end
	end
end

local function buildDistrict(district)
	local c, size, blocks = district.Center, district.Size, district.Blocks
	local pitch = size / blocks
	local footprint = pitch * 0.55
	local spots = {}
	for i = 0, blocks - 1 do
		for j = 0, blocks - 1 do
			local x = c.X - size / 2 + pitch * (i + 0.5)
			local z = c.Z - size / 2 + pitch * (j + 0.5)
			-- leave a plaza in the middle of each district
			local mid = (blocks - 1) / 2
			if math.abs(i - mid) < 0.6 and math.abs(j - mid) < 0.6 then
				continue
			end
			tower(district, x, z, footprint)
			table.insert(spots, Vector3.new(x + footprint / 2 + 3, GROUND_TOP + 1.5, z + footprint / 2 + 3))
			-- street furniture on the block corners: every one of these is breakable salvage
			local corner = Vector3.new(x - footprint / 2 - 4, GROUND_TOP, z - footprint / 2 - 4)
			Destruction.SpawnProp("Streetlight", CFrame.new(corner))
			for k = 1, 2 do
				local propId = STREET_PROPS[rng:NextInteger(1, #STREET_PROPS)]
				local pos = Vector3.new(x + rng:NextNumber(-pitch / 2 + 4, pitch / 2 - 4), GROUND_TOP, z + footprint / 2 + 4 + k * 4)
				Destruction.SpawnProp(propId, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			end
		end
	end
	-- locked buildings at the district edge (tier by danger); Corp Plaza also keeps a Sealed one
	lockup(district, Vector3.new(c.X - size / 2 + 20, 0, c.Z + size / 2 - 20), district.Lockup or "Weak")
	if district.Sealed then
		lockup(district, Vector3.new(c.X + size / 2 - 20, 0, c.Z + size / 2 - 20), "Sealed")
	end
	for _ = 1, math.min(district.Caches, #spots) do
		local idx = rng:NextInteger(1, #spots)
		cache(district, table.remove(spots, idx))
	end
	-- district marker: a tall neon pylon in the plaza so players can navigate by sight
	local pylon = part({ Name = "Pylon", Size = Vector3.new(2, 60, 2), Position = Vector3.new(c.X, GROUND_TOP + 30, c.Z), Material = Enum.Material.Neon, Color = district.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = district.Neon, 60, 2
	light.Parent = pylon
	pylon:SetAttribute("District", district.Name)
	-- open-world spawn pads near the plaza
	for k = 1, 2 do
		local pad = part({ Name = "SpawnPad", Size = Vector3.new(6, 0.4, 6), Position = Vector3.new(c.X + (k == 1 and -18 or 18), GROUND_TOP + 0.2, c.Z), Material = Enum.Material.Neon, Color = district.Neon, Transparency = 0.6 })
		CollectionService:AddTag(pad, "CitySpawn")
	end
end

function City.DistrictAt(position)
	for _, d in City.Districts do
		if math.abs(position.X - d.Center.X) <= d.Size / 2 and math.abs(position.Z - d.Center.Z) <= d.Size / 2 then
			return d
		end
	end
	return nil
end

function City.GetDistrict(name)
	for _, d in City.Districts do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local current = {} -- [player] = district name
local visited = {} -- [player] = { [name] = true }, reset on death by Lifecycle

function City.ResetVisits(player)
	visited[player] = nil
	current[player] = nil
end

function City.Init()
	folder = Instance.new("Folder")
	folder.Name = "City"
	folder.Parent = workspace
	-- ground large enough for all districts (the arena adds its own slab in the middle)
	part({ Name = "CityGround", Size = Vector3.new(1400, 4, 1400), Position = Vector3.new(0, 0, 0), Color = Color3.fromRGB(42, 44, 50), Material = Enum.Material.Asphalt })
	for _, district in City.Districts do
		buildDistrict(district)
	end
	buildOutskirts()

	-- district banners (1 Hz; cheap)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local d = City.DistrictAt(root.Position)
					local name = d and d.Name
					if name ~= current[player] then
						current[player] = name
						if d then
							Remotes.Announce:FireClient(player, ("%s  -  danger: %s"):format(d.Name, d.Danger), "District")
							visited[player] = visited[player] or {}
							if not visited[player][name] then
								visited[player][name] = true
								Quests.Progress(player, "explore", "District", 1)
							end
							City.Entered:Fire(player, name)
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		current[player], visited[player] = nil, nil
	end)
end

return City
