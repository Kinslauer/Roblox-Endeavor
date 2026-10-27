-- Ears and nose (shared/Cybernetics.lua; design/gdd/dematerialization.md §6). The server says how far this
-- body hears and smells (player attributes Hearing / Scent / Track, server/Gear.lua); this draws it.
--   Hearing: every moving body inside the radius that you can't see - off screen, or behind a wall - puts a
--            pip on a ring around the screen centre, pointing at it, brighter the closer it is.
--   Scent:   loot and fragments inside the radius (the "Scent" tag: server/Loot.lua, server/Clues.lua) get
--            a soft marker through walls; with Track, wounded bodies do too.
-- Only shows what this client already has replicated; the radius is the gate. Tuning: Presentation.Senses.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local P = Presentation.Senses

local Senses = {}

local player = Players.LocalPlayer
local gui, ring
local pips = {} -- pooled Frames
local markers = {} -- pooled BillboardGuis

local function bodies()
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			table.insert(out, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("Combatant") do
		table.insert(out, m)
	end
	return out
end

local function pip(i)
	local f = pips[i]
	if not f then
		f = Instance.new("Frame")
		f.Name = "Heard"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = P.PipSize
		f.BorderSizePixel = 0
		f.BackgroundColor3 = P.HearColor
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		f.Parent = ring
		pips[i] = f
	end
	return f
end

local function marker(i)
	local m = markers[i]
	if not m then
		m = Instance.new("BillboardGui")
		m.Name = "Scent"
		m.AlwaysOnTop = true
		m.Size = P.MarkerSize
		m.LightInfluence = 0
		m.ResetOnSpawn = false
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromScale(1, 1)
		dot.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		dot.Parent = m
		m.Parent = gui
		markers[i] = m
	end
	return m
end

local function seen(cam, from, target, model)
	local _, onScreen = cam:WorldToViewportPoint(target)
	if not onScreen then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, model }
	return workspace:Raycast(from, target - from, params) == nil
end

local function hear()
	local radius = player:GetAttribute("Hearing") or 0
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local n = 0
	if radius > 0 and me and cam then
		local look = cam.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then
			flatLook = flatLook.Unit
			local right = flatLook:Cross(Vector3.yAxis)
			local size = cam.ViewportSize
			local r = math.min(size.X, size.Y) * P.RingScale
			for _, model in bodies() do
				local root = model:FindFirstChild("HumanoidRootPart")
				local hum = model:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local offset = root.Position - me.Position
					local d = offset.Magnitude
					local v = root.AssemblyLinearVelocity
					if d <= radius and d > 1 and Vector3.new(v.X, 0, v.Z).Magnitude >= P.MoveSpeed and not seen(cam, cam.CFrame.Position, root.Position, model) then
						n += 1
						local flat = Vector3.new(offset.X, 0, offset.Z).Unit
						local angle = math.atan2(flat:Dot(right), flat:Dot(flatLook)) -- 0 = ahead, + = right
						local f = pip(n)
						f.Position = UDim2.new(0.5, math.sin(angle) * r, 0.5, -math.cos(angle) * r)
						f.Rotation = math.deg(angle) + 90
						f.BackgroundTransparency = 0.15 + 0.7 * (d / radius)
						f.Visible = true
					end
				end
			end
		end
	end
	for i = n + 1, #pips do
		pips[i].Visible = false
	end
end

local function smell()
	local radius = player:GetAttribute("Scent") or 0
	local track = player:GetAttribute("Track") == true
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local n = 0
	local function mark(part, color)
		n += 1
		local m = marker(n)
		m.Adornee = part
		m.Frame.BackgroundColor3 = color
		m.Frame.BackgroundTransparency = 0.35
		m.Enabled = true
	end
	if radius > 0 and me then
		for _, part in CollectionService:GetTagged("Scent") do
			if part:IsA("BasePart") and part:IsDescendantOf(workspace) and part.LocalTransparencyModifier < 1
				and (part.Position - me.Position).Magnitude <= radius then
				mark(part, P.ScentColor)
			end
		end
		if track then
			for _, model in bodies() do
				local root = model:FindFirstChild("HumanoidRootPart")
				local hum = model:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and hum.Health / math.max(hum.MaxHealth, 1) < P.WoundedBelow
					and (root.Position - me.Position).Magnitude <= radius then
					mark(root, P.BloodColor)
				end
			end
		end
	end
	for i = n + 1, #markers do
		markers[i].Enabled = false
		markers[i].Adornee = nil
	end
end

function Senses.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Senses"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local a, b = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		a += dt
		b += dt
		if a >= P.Tick then
			a = 0
			hear()
		end
		if b >= P.ScentTick then
			b = 0
			smell()
		end
	end)
end

return Senses
