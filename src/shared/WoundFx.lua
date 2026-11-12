-- WoundFx (both clients): what the wounds look like from inside the body. Reads only the character attributes
-- common/WoundService sets (W_<part>, Bleed_<part>, Broken_<part>, Lost_<part>, Pain, Concussed, Hunger).
-- A small body outline in the lower left that shows only while something is wrong (parts pale to red, dark when
-- out, a pulse on a bleed, a white bar across a break), pain as a soft blur, concussion as a swimming, greyed view,
-- and a thin amber line under the body when hunger runs low. No words: the body shows it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(script.Parent.Config)

local WoundFx = {}

local W = Config.Wounds
-- the outline: each part as a box in a 60 x 120 figure (x, y, w, h in pixels)
local SHAPE = {
	Head = { 22, 0, 16, 18 },
	Chest = { 16, 20, 28, 26 },
	Stomach = { 18, 47, 24, 18 },
	ArmL = { 4, 21, 10, 40 },
	ArmR = { 46, 21, 10, 40 },
	LegL = { 18, 67, 11, 52 },
	LegR = { 31, 67, 11, 52 },
}
local HEALTHY = Color3.fromRGB(150, 168, 160)
local HURT = Color3.fromRGB(214, 58, 48)
local OUT = Color3.fromRGB(28, 24, 26)
local BLOOD = Color3.fromRGB(255, 40, 40)

local started = false
local gui, frame, boxes, breaks, hungerBar, hungerFill, blur, grade
local shown = 0 -- 0..1 fade of the outline
local blurNow, satNow = 0, 0

local function wrongWith(char)
	if not char then
		return false
	end
	for part in SHAPE do
		local w = char:GetAttribute("W_" .. part)
		if (type(w) == "number" and w < 0.98) or (char:GetAttribute("Bleed_" .. part) or "") ~= ""
			or char:GetAttribute("Broken_" .. part) or char:GetAttribute("Lost_" .. part) then
			return true
		end
	end
	return (char:GetAttribute("Pain") or 0) > 0.05 or char:GetAttribute("Concussed") == true
end

local function build(playerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "WoundFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function rescale()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize
		local h = if typeof(size) == "Vector2" then size.Y else 680
		scale.Scale = math.clamp(h / 680, 1, 2.6)
	end
	rescale()
	local cam = workspace.CurrentCamera
	local resized = cam and cam.GetPropertyChangedSignal and cam:GetPropertyChangedSignal("ViewportSize")
	if resized then
		resized:Connect(rescale)
	end
	frame = Instance.new("CanvasGroup")
	frame.Name = "Body"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 18, 1, -64)
	frame.Size = UDim2.fromOffset(60, 128)
	frame.GroupTransparency = 1
	frame.Parent = gui
	boxes, breaks = {}, {}
	for part, r in SHAPE do
		local b = Instance.new("Frame")
		b.Name = part
		b.BorderSizePixel = 0
		b.BackgroundColor3 = HEALTHY
		b.BackgroundTransparency = 0.15
		b.Position = UDim2.fromOffset(r[1], r[2])
		b.Size = UDim2.fromOffset(r[3], r[4])
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, if part == "Head" then 8 else 3)
		corner.Parent = b
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(10, 12, 14)
		edge.Thickness = 1
		edge.Transparency = 0.3
		edge.Parent = b
		b.Parent = frame
		boxes[part] = b
		local bar = Instance.new("Frame")
		bar.Name = "Break"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1.4, 0, 0, 2)
		bar.Rotation = -30
		bar.Visible = false
		bar.Parent = b
		breaks[part] = bar
	end
	hungerBar = Instance.new("Frame")
	hungerBar.Name = "Hunger"
	hungerBar.BorderSizePixel = 0
	hungerBar.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
	hungerBar.BackgroundTransparency = 0.3
	hungerBar.AnchorPoint = Vector2.new(0, 1)
	hungerBar.Position = UDim2.new(0, 18, 1, -54)
	hungerBar.Size = UDim2.fromOffset(60, 3)
	hungerBar.Visible = false
	hungerBar.Parent = gui
	hungerFill = Instance.new("Frame")
	hungerFill.BorderSizePixel = 0
	hungerFill.BackgroundColor3 = Color3.fromRGB(226, 160, 52)
	hungerFill.Size = UDim2.fromScale(1, 1)
	hungerFill.Parent = hungerBar
	gui.Parent = playerGui
	blur = Instance.new("BlurEffect")
	blur.Name = "WoundBlur"
	blur.Size = 0
	blur.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WoundGrade"
	grade.Parent = Lighting
end

-- one frame: exported for tests
function WoundFx.Step(char, now, dt)
	if not frame then
		return
	end
	local wrong = wrongWith(char)
	shown += ((if wrong then 1 else 0) - shown) * math.min(1, dt * 3)
	frame.GroupTransparency = 1 - shown
	frame.Visible = shown > 0.02
	local pulse = 0.5 + 0.5 * math.sin(now * 7)
	for part, b in boxes do
		local w = char and char:GetAttribute("W_" .. part)
		w = if type(w) == "number" then w else 1
		local lost = char and char:GetAttribute("Lost_" .. part)
		local color = if lost or w <= 0 then OUT else HURT:Lerp(HEALTHY, math.clamp(w, 0, 1))
		local bleed = char and char:GetAttribute("Bleed_" .. part) or ""
		if bleed ~= "" and not lost then
			color = color:Lerp(BLOOD, (if bleed == "Heavy" then 0.75 else 0.4) * pulse)
		end
		b.BackgroundColor3 = color
		b.BackgroundTransparency = if lost then 0.6 else 0.15
		breaks[part].Visible = char ~= nil and char:GetAttribute("Broken_" .. part) == true and not lost
	end
	local hunger = char and char:GetAttribute("Hunger")
	if type(hunger) == "number" and hunger < W.Hunger.Low * 2 then
		hungerBar.Visible = true
		hungerFill.Size = UDim2.fromScale(math.clamp(hunger / W.Hunger.Start, 0, 1), 1)
		hungerFill.BackgroundTransparency = if hunger < W.Hunger.Low then 0.3 * pulse else 0
	else
		hungerBar.Visible = false
	end
	local pain = char and char:GetAttribute("Pain") or 0
	local concussed = char ~= nil and char:GetAttribute("Concussed") == true
	local wantBlur = pain * 6 + (if concussed then 5 + 3 * math.sin(now * 2.3) else 0)
	blurNow += (wantBlur - blurNow) * math.min(1, dt * 4)
	blur.Size = blurNow
	local wantSat = if concussed then -0.55 else -pain * 0.35
	satNow += (wantSat - satNow) * math.min(1, dt * 3)
	grade.Saturation = satNow
	-- a concussion swims the view a little (the camera's own owner moves it every frame; this only tilts it)
	if concussed then
		local cam = workspace.CurrentCamera
		if cam then
			cam.CFrame *= CFrame.Angles(0, 0, math.rad(math.sin(now * 1.7) * 1.2))
		end
	end
end

function WoundFx.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		return
	end
	build(playerGui)
	RunService:BindToRenderStep("WoundFx", 202, function(dt) -- just after the camera (RenderPriority.Camera = 200)
		WoundFx.Step(player.Character, os.clock(), dt)
	end)
end

function WoundFx.Elements()
	return { Gui = gui, Body = frame, Boxes = boxes, Hunger = hungerBar, Blur = blur }
end

return WoundFx
