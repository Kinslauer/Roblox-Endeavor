-- Effects scaled to the machine (Presentation.Quality). One level for this client, High / Medium / Low, from
-- two things, whichever is lower:
--   * the player's own Roblox graphics setting (Esc -> Settings -> Graphics Quality, 1-10) when it is manual
--   * the frame rate this client actually gets: sustained low fps steps the level down, a long run of good
--     fps steps it back up (so "Automatic" players are covered too, and a big fight doesn't tank a laptop)
-- What the level changes (presentation only, never gameplay or anything another player sees):
--   * particle counts (dust, sparks), guard-break shards, slam cracks, dodge after-images, the effect cap
--   * the district bloom
--   * world lamps: Medium keeps two in three of the street / region PointLights, Low one in three. The lamp
--     heads stay neon, so streets still read lit; only the light they cast is gone.
-- Effects ask Quality.Scale(key). Quality.Force(level) pins a level for testing (the dev panel).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local Q = Presentation.Quality

local Quality = {}

local ORDER = { "Low", "Medium", "High" }
local RANK = { Low = 1, Medium = 2, High = 3 }

local level = "High"
local forced = nil
local fpsLevel = "High"
local changed = Instance.new("BindableEvent")
Quality.Changed = changed.Event

function Quality.Level()
	return level
end

function Quality.Scale(key)
	local tier = Q.Tiers[level]
	return tier and tier[key] or 1
end

-- How many of `n` to make at this level (never below `min`, default 0).
function Quality.Count(key, n, min)
	return math.max(min or 0, math.floor(n * Quality.Scale(key) + 0.5))
end

-- The player's graphics setting as a level, or nil when it is Automatic (or unreadable).
local function settingLevel()
	local ok, saved = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	if not ok or saved == nil or saved == Enum.SavedQualitySetting.Automatic then
		return nil
	end
	local n = saved.Value
	return if n <= Q.Setting.LowAtOrBelow then "Low" elseif n <= Q.Setting.MediumAtOrBelow then "Medium" else "High"
end

-- ---------------------------------------------------------------------------------------------
-- The world: bloom and lamps follow the level
-- ---------------------------------------------------------------------------------------------
local function lightBucket(light)
	local p = light.Parent.Position
	return (math.floor(p.X / 4) * 7 + math.floor(p.Z / 4) * 13) % 3 -- stable per lamp, spread across the street
end

local function applyLight(light)
	if not (light:IsA("PointLight") or light:IsA("SpotLight")) or not light.Parent or not light.Parent:IsA("BasePart") then
		return
	end
	local keep = math.floor(Quality.Scale("Lights") * 3 + 0.5) -- thirds kept
	local cull = lightBucket(light) >= keep
	if cull and light.Enabled and not light:GetAttribute("QualityCulled") then
		light:SetAttribute("QualityCulled", true)
		light.Enabled = false
	elseif not cull and light:GetAttribute("QualityCulled") then
		light:SetAttribute("QualityCulled", nil)
		light.Enabled = true
	end
end

local function worldFolders()
	local out = {}
	for _, name in Q.LightFolders do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(out, f)
		end
	end
	return out
end

local function applyBloom()
	local bloom = Lighting:FindFirstChild("DistrictBloom")
	if bloom and bloom:IsA("BloomEffect") then
		if bloom:GetAttribute("BaseIntensity") == nil then
			bloom:SetAttribute("BaseIntensity", bloom.Intensity)
		end
		local s = Quality.Scale("Bloom")
		bloom.Enabled = s > 0
		bloom.Intensity = bloom:GetAttribute("BaseIntensity") * s
	end
end

-- Re-applies the level to the whole world (also after the cycle hands its failed lights back: WorldFX).
function Quality.Reapply()
	applyBloom()
	for _, f in worldFolders() do
		for _, d in f:GetDescendants() do
			applyLight(d)
		end
	end
end

local function decide()
	local want = forced or fpsLevel
	local set = settingLevel()
	if not forced and set and RANK[set] < RANK[want] then
		want = set
	end
	if want ~= level then
		level = want
		Quality.Reapply()
		changed:Fire(level)
	end
end

function Quality.Force(name)
	forced = if RANK[name] then name else nil
	decide()
	return level
end

-- ---------------------------------------------------------------------------------------------
-- Frame rate: step down after DownAfter seconds under a level's floor, up after UpAfter seconds well over it
-- ---------------------------------------------------------------------------------------------
local function watchFrameRate()
	local F = Q.Fps
	local frames, elapsed = 0, 0
	local below, above = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed < 1 then
			return
		end
		local fps = frames / elapsed
		frames, elapsed = 0, 0
		local floor = F.Floor[fpsLevel]
		if floor and fps < floor then
			below += 1
			above = 0
		elseif RANK[fpsLevel] < 3 and fps >= F.Floor[ORDER[RANK[fpsLevel] + 1]] + F.UpMargin then
			above += 1
			below = 0
		else
			below, above = 0, 0
		end
		if below >= F.DownAfter and RANK[fpsLevel] > 1 then
			fpsLevel, below = ORDER[RANK[fpsLevel] - 1], 0
			decide()
		elseif above >= F.UpAfter then
			fpsLevel, above = ORDER[RANK[fpsLevel] + 1], 0
			decide()
		end
	end)
end

function Quality.Init()
	fpsLevel = settingLevel() or "High"
	level = "High"
	decide()
	Quality.Reapply()
	-- lamps built or streamed in after we start
	local function watchFolder(f)
		f.DescendantAdded:Connect(function(d)
			if d:IsA("PointLight") or d:IsA("SpotLight") then
				task.defer(applyLight, d)
			end
		end)
	end
	for _, f in worldFolders() do
		watchFolder(f)
	end
	workspace.ChildAdded:Connect(function(child)
		if table.find(Q.LightFolders, child.Name) then
			watchFolder(child)
			task.defer(Quality.Reapply)
		end
	end)
	Lighting.ChildAdded:Connect(function(child)
		if child.Name == "DistrictBloom" then
			task.defer(applyBloom)
		end
	end)
	-- the player changing their graphics setting mid-game
	task.spawn(function()
		while true do
			task.wait(2)
			decide()
		end
	end)
	watchFrameRate()
end

return Quality
