-- Character creator, client half. Buttons cycle through catalog indices; every change is
-- sent to the server, which validates it and re-skins your live character as the preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Appearance = require(Shared:WaitForChild("Appearance"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "ConduitCreator", false, 50, false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local ROW = 44
local frame = make("Frame", {
	Size = UDim2.fromOffset(340, 90 + #Appearance.FieldOrder * ROW), Position = UDim2.new(0, 30, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(10, 14, 20), BackgroundTransparency = 0.1,
}, gui)
make("UIStroke", { Color = Color3.fromRGB(0, 220, 255), Thickness = 1.5 }, frame)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "CREATE YOUR CHARACTER", TextColor3 = Color3.fromRGB(0, 220, 255),
	Font = Enum.Font.GothamBold, TextSize = 18,
}, frame)

local look = Appearance.Default()
local valueLabels = {}

local function push(confirm)
	Remotes.SetAppearance:FireServer(look, confirm)
end

local function refresh(field)
	valueLabels[field].Text = Appearance.Fields[field][look[field]].Name
end

local function button(text, position, parent)
	return make("TextButton", {
		Size = UDim2.fromOffset(36, 32), Position = position, Text = text, BackgroundColor3 = Color3.fromRGB(45, 55, 70),
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18,
	}, parent)
end

for i, field in Appearance.FieldOrder do
	local row = make("Frame", { Size = UDim2.new(1, -24, 0, 38), Position = UDim2.fromOffset(12, 40 + (i - 1) * ROW), BackgroundTransparency = 1 }, frame)
	make("TextLabel", {
		Size = UDim2.fromOffset(90, 38), BackgroundTransparency = 1, Text = field:gsub("(%l)(%u)", "%1 %2"), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(170, 175, 190), Font = Enum.Font.GothamMedium, TextSize = 14,
	}, row)
	local count = #Appearance.Fields[field]
	local function step(delta)
		look[field] = (look[field] - 1 + delta) % count + 1
		refresh(field)
		push(false)
	end
	button("<", UDim2.fromOffset(94, 3), row).Activated:Connect(function()
		step(-1)
	end)
	valueLabels[field] = make("TextLabel", {
		Size = UDim2.fromOffset(110, 38), Position = UDim2.fromOffset(134, 0), BackgroundTransparency = 1, Text = "",
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 16,
	}, row)
	button(">", UDim2.fromOffset(248, 3), row).Activated:Connect(function()
		step(1)
	end)
end

make("TextButton", {
	Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0, 12, 1, -46), Text = "CONFIRM", BackgroundColor3 = Color3.fromRGB(0, 150, 190),
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18,
}, frame).Activated:Connect(function()
	push(true)
	gui.Enabled = false
end)

Remotes.OpenCreator.OnClientEvent:Connect(function(current)
	if type(current) ~= "table" then
		gui.Enabled = false
		return
	end
	look = Appearance.Sanitize(current)
	for field in Appearance.Fields do
		refresh(field)
	end
	gui.Enabled = true
end)
