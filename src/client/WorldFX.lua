-- WorldFX (Phase 3): the moments the world sends that had no picture yet. Pure presentation.
--   * Barks - an enemy's first-sight line (NPCs sets the Bark attribute) as a speech bubble over its head,
--     only within hearing range: the "hear" half of unannounced encounters (design/gdd/raids.md §1)
--   * Dash - a warmonger's / rival's flicker-step: a streak from where it was to where it is, a shake if close
--   * Pod / Shipment - a re-entry pod or a crate coming down: a shake when it lands near you
--   * Downed / Revive / HillCaptured - colour pulses on the body / the ring
--   * Dust (WorldFX.Dust) - the ground answering a dodge, a landing, a heavy strike
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CombatFX = require(script.Parent.CombatFX)
local CameraShake = require(script.Parent.CameraShake)

local WorldFX = {}

local player = Players.LocalPlayer
local HEAR_RANGE = 90 -- studs: a bark farther than this is not heard
local BUBBLE_SECONDS = 3.2
local DUST_RANGE = 120 -- studs: a puff farther than this is not drawn

-- ---------------------------------------------------------------------------------------------
-- Dust: the ground answering a body - a dodge, a landing, a heavy strike. `scale` ~1 = a heavy's
-- puff; a dodge is 0.5. One short burst from an anchored emitter that cleans itself up.
-- ---------------------------------------------------------------------------------------------
local Presentation = require(Shared:WaitForChild("Presentation"))
function WorldFX.Dust(position, scale)
	scale = scale or 1
	if typeof(position) ~= "Vector3" or scale <= 0 then
		return
	end
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if me and (me.Position - position).Magnitude > DUST_RANGE then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Transparency = true, false, false, false, 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Presentation.Swings.DustColor or Color3.fromRGB(150, 135, 110))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 3 * scale) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(6 * scale, 10 * scale)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 4
	e.Rate = 0
	e.LightInfluence = 1
	e.Parent = part
	part.Parent = workspace
	e:Emit(math.clamp(math.floor(10 * scale + 0.5), 4, 30))
	Debris:AddItem(part, 1)
end

local function myPosition()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function distanceTo(position)
	local me = myPosition()
	return me and (me - position).Magnitude or math.huge
end

-- ---------------------------------------------------------------------------------------------
-- Barks
-- ---------------------------------------------------------------------------------------------
local function bubble(model, text)
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bark")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bark"
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = UDim2.fromOffset(240, 36), Vector3.new(0, 3.2, 0), false, HEAR_RANGE
	local frame = Instance.new("Frame")
	frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(10, 10, 14), 0.35, 0
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.TextColor3, label.Font, label.TextScaled = Color3.fromRGB(235, 235, 240), Enum.Font.SourceSansItalic, true
	label.Parent = frame
	gui.Parent = head
	Debris:AddItem(gui, BUBBLE_SECONDS)
end

local function watchBarks(model)
	model:GetAttributeChangedSignal("Bark"):Connect(function()
		local raw = model:GetAttribute("Bark")
		local root = model:FindFirstChild("HumanoidRootPart")
		if type(raw) ~= "string" or not root or distanceTo(root.Position) > HEAR_RANGE then
			return
		end
		bubble(model, (raw:gsub("|.*$", "")))
	end)
end

-- ---------------------------------------------------------------------------------------------
-- Moments
-- ---------------------------------------------------------------------------------------------
local function streak(from, to, color)
	local d = to - from
	if d.Magnitude < 1 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CastShadow = true, false, false, false
	part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.2
	part.Size = Vector3.new(0.6, 0.6, d.Magnitude)
	part.CFrame = CFrame.lookAt(from + d / 2 + Vector3.new(0, 1.5, 0), to + Vector3.new(0, 1.5, 0))
	if CombatFX.Spawn(part, 0.4) then
		TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(0.1, 0.1, d.Magnitude) }):Play()
	end
end

local function feetOf(model)
	local root = typeof(model) == "Instance" and model:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - Vector3.new(0, 2.8, 0)) or nil
end

function WorldFX.Init()
	-- the ground answers: a dodge, an enemy step, a launched body landing
	CombatFX.On("Dodge", function(model)
		WorldFX.Dust(feetOf(model), 0.5)
	end)
	CombatFX.On("EnemyStep", function(model)
		WorldFX.Dust(feetOf(model), 0.7)
	end)
	CombatFX.On("Land", function(model)
		WorldFX.Dust(feetOf(model), 1.1)
	end)
	CombatFX.On("Dash", function(model, info)
		if type(info) ~= "table" or typeof(info.from) ~= "Vector3" or typeof(info.to) ~= "Vector3" then
			return
		end
		local isRival = typeof(model) == "Instance" and model:GetAttribute("EnemyType") == "Rival"
		streak(info.from, info.to, if isRival then Color3.fromRGB(80, 220, 220) else Color3.fromRGB(255, 80, 80))
		if distanceTo(info.to) < 14 then
			CameraShake.Add(0.35)
		end
	end)
	CombatFX.On("Pod", function(pod)
		if typeof(pod) ~= "Instance" then
			return
		end
		task.delay(Config.War.PodFallSeconds, function()
			if pod.Parent and distanceTo(pod.Position) < 40 then
				CameraShake.Add(0.5)
			end
		end)
	end)
	CombatFX.On("Downed", function(victim)
		CombatFX.Flash(victim, Color3.fromRGB(255, 60, 60), 0.8)
		if victim == player.Character then
			CameraShake.Add(0.6)
		end
	end)
	CombatFX.On("Revive", function(victim)
		CombatFX.Flash(victim, Color3.fromRGB(120, 255, 160), 0.8)
	end)
	CombatFX.On("Shipment", function(char)
		CombatFX.Flash(char, Color3.fromRGB(255, 220, 120), 0.6)
	end)
	CombatFX.On("HillCaptured", function(ring, sideId)
		if typeof(ring) ~= "Instance" then
			return
		end
		local color
		for _, f in Config.War.Factions do
			if f.Id == sideId then
				color = f.Color
			end
		end
		local h = Instance.new("Highlight")
		h.FillColor, h.FillTransparency, h.OutlineColor = color or Color3.new(1, 1, 1), 0.2, color or Color3.new(1, 1, 1)
		h.Parent = ring
		Debris:AddItem(h, 1.5)
	end)
	-- barks on every fighter, present and future
	for _, model in CollectionService:GetTagged("Combatant") do
		watchBarks(model)
	end
	CollectionService:GetInstanceAddedSignal("Combatant"):Connect(watchBarks)
end

return WorldFX
