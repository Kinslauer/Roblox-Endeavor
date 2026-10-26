-- Transport (Phase 3, build order 5; design/gdd/world.md): the lines between regions. Every hub
-- (shared/Regions.lua Hubs) is a platform with a sign and one console per line out of it. Standing
-- on a hub UNLOCKS it (profile.Hubs, kept through permadeath - the hideout's knowledge, not the
-- body's); a ride needs both ends unlocked and no recent fight, then a short boarding wait, travel
-- protection and the far platform. Transport is a ride, not a vehicle: the train is implied.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local D = require(Shared.District)
local R = require(Shared.Regions)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Raids = require(script.Parent.Raids)

local T = Config.Transport
local Transport = {}

local folder
local TOP = D.GroundTop
local COLOR = Color3.fromRGB(120, 220, 255)
local hubParts = {} -- id -> platform part

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

local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 24, brightness or 1.5
	l.Parent = p
end

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function billboard(parent, text, color, offset, width)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = UDim2.fromOffset(width or 260, 40), offset or Vector3.new(0, 3, 0), true, 160
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.TextColor3, label.Font, label.TextScaled = color, Enum.Font.GothamBold, true
	label.Parent = gui
	gui.Parent = parent
	return label
end

function Transport.Unlocked(player, hubId)
	local data = PlayerData.Get(player)
	return data ~= nil and data.Hubs ~= nil and data.Hubs[hubId] == true
end

function Transport.Unlock(player, hubId)
	local data = PlayerData.Get(player)
	local hub = R.Hubs[hubId]
	if not (data and hub) then
		return false
	end
	data.Hubs = data.Hubs or {}
	if data.Hubs[hubId] then
		return false
	end
	data.Hubs[hubId] = true
	local n = 0
	for _ in data.Hubs do
		n += 1
	end
	player:SetAttribute("HubsKnown", n)
	announce(player, ("%s unlocked. You can ride here from any station you know."):format(hub.Name), "Info")
	return true
end

-- Where a rider lands: the platform, facing away from the console row.
function Transport.ArrivalCFrame(hubId)
	local hub = R.Hubs[hubId]
	return CFrame.new(hub.Position + Vector3.new(0, TOP + 4, 0))
end

function Transport.Ride(player, fromId, toId)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local to = R.Hubs[toId]
	if not (root and to) then
		return false
	end
	if not Transport.Unlocked(player, fromId) then
		Transport.Unlock(player, fromId) -- standing here counts
	end
	if not Transport.Unlocked(player, toId) then
		announce(player, ("You have never been to %s. Reach it once on foot, then the line is yours."):format(to.Name))
		return false
	end
	if Combat.InCombat(player) then
		announce(player, "The train will not take you while you are fighting.")
		return false
	end
	if player:GetAttribute("Boarding") then
		return false
	end
	player:SetAttribute("Boarding", true)
	announce(player, ("Boarding for %s..."):format(to.Name), "Info")
	Combat.Protect(char, T.BoardSeconds + T.Protection)
	task.delay(T.BoardSeconds, function()
		player:SetAttribute("Boarding", nil)
		local c = player.Character
		if c and c:FindFirstChild("HumanoidRootPart") and c == char then
			c:PivotTo(Transport.ArrivalCFrame(toId))
			Combat.Protect(c, T.Protection)
			announce(player, ("Arrived: %s."):format(to.Name), "Info")
			Raids.OnExtract(player) -- a train out counts as extraction for a raid on its last step
		end
	end)
	return true
end

local function buildHub(id, hub)
	local p = hub.Position
	local platform = part({ Name = "Platform_" .. id, Size = Vector3.new(26, 1.5, 14), Position = p + Vector3.new(0, TOP + 0.75, 0), Color = Color3.fromRGB(80, 84, 94), Material = Enum.Material.Concrete })
	platform:SetAttribute("Hub", id)
	CollectionService:AddTag(platform, "TransportHub")
	hubParts[id] = platform
	-- rails along the far side
	for _, dz in { 8.5, 10.5 } do
		part({ Name = "Rail", Size = Vector3.new(60, 0.4, 0.5), Position = p + Vector3.new(0, TOP + 0.2, dz), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Metal })
	end
	for i = -5, 5 do
		part({ Name = "Sleeper", Size = Vector3.new(1.2, 0.3, 4), Position = p + Vector3.new(i * 5.5, TOP + 0.1, 9.5), Color = Color3.fromRGB(70, 56, 44), Material = Enum.Material.Wood })
	end
	-- roof and posts
	for _, dx in { -11, 11 } do
		part({ Name = "Post", Size = Vector3.new(1, 10, 1), Position = p + Vector3.new(dx, TOP + 6.5, -3), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Metal })
	end
	part({ Name = "Roof", Size = Vector3.new(26, 0.6, 12), Position = p + Vector3.new(0, TOP + 11.6, 0), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Metal })
	local sign = part({ Name = "Sign", Size = Vector3.new(16, 1.4, 0.4), Position = p + Vector3.new(0, TOP + 13, -6), Color = COLOR, Material = Enum.Material.Neon, CanCollide = false })
	glow(sign, COLOR, 40, 1.5)
	billboard(sign, ("STATION  ·  %s"):format(hub.Name), COLOR, Vector3.new(0, 2.2, 0), 320)
	-- one console per line: hold X to ride
	for i, destId in hub.Lines do
		local dest = R.Hubs[destId]
		local cp = p + Vector3.new(-8 + (i - 1) * 8, 0, -5)
		local body = part({ Name = "Line_" .. destId, Size = Vector3.new(5, 4.5, 2), Position = cp + Vector3.new(0, TOP + 2.25 + 1.5, 0), Color = Color3.fromRGB(26, 28, 34), Material = Enum.Material.Metal })
		local screen = part({ Name = "Screen", Size = Vector3.new(4, 2, 0.3), Position = cp + Vector3.new(0, TOP + 4.6, -1.1), Color = COLOR, Material = Enum.Material.Neon, CanCollide = false })
		glow(screen, COLOR, 16, 1)
		billboard(body, ("Train to %s"):format(dest.Name), COLOR, Vector3.new(0, 3.6, 0))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = dest.Name, "Ride", 0.6
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
		prompt.KeyboardKeyCode = Enum.KeyCode.X
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			Transport.Ride(player, id, destId)
		end)
	end
end

-- Every second: anyone standing near a hub has found it.
local function watch()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				for id, hub in R.Hubs do
					local d = Vector3.new(root.Position.X - hub.Position.X, 0, root.Position.Z - hub.Position.Z)
					if d.Magnitude <= T.UnlockRadius and not Transport.Unlocked(player, id) then
						Transport.Unlock(player, id)
					end
				end
			end
		end
	end)
end

function Transport.Sync(player)
	local data = PlayerData.Get(player)
	local n = 0
	for _ in (data and data.Hubs) or {} do
		n += 1
	end
	player:SetAttribute("HubsKnown", n)
end

function Transport.Init()
	if workspace:FindFirstChild("Transport") then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Transport"
	folder.Parent = workspace
	local n = 0
	for id, hub in R.Hubs do
		buildHub(id, hub)
		n += 1
	end
	watch()
	Transport.Built = { Hubs = n }
end

return Transport
