-- The Studio dev panel (server/DevPanel.lua). Shows only when the server says DevPanel (Studio +
-- Config.Dev.Enabled). P or the DEV button toggles it; it frees the mouse like any HUD panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Hud = require(script.Parent.Hud)

local DevPanel = {}

local player = Players.LocalPlayer

local SECTIONS = {
	{ "Go to", {
		{ "Relay Plaza", "Teleport", "Plaza1" }, { "Ferrite Court", "Teleport", "Plaza2" },
		{ "Road: start", "Teleport", "RoadStart" }, { "Road: brute post", "Teleport", "RoadBrute" },
		{ "Road: warmonger", "Teleport", "RoadWarmonger" }, { "Dealer", "Teleport", "Dealer" },
		{ "Verdant Reach", "Teleport", "Verdant" }, { "Arena", "Teleport", "Arena" }, { "Hideout", "Hideout" },
	} },
	{ "Give", {
		{ "All weapons", "Give", "Weapons" }, { "All implants", "Give", "Implants" },
		{ "Materials + cells", "Give", "Materials" }, { "+500 money", "Give", "Money" },
		{ "Unlock computer, contacts, Autonet", "Unlock" },
	} },
	{ "Do", {
		{ "Heal", "Heal" }, { "God mode on/off", "God" }, { "Kill enemies nearby", "Clear" }, { "Cycle in 70 s", "Cycle" },
	} },
}

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -12, 0, 52)
	toggle.BackgroundColor3 = Color3.fromRGB(120, 30, 90)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.Code
	toggle.TextSize = 14
	toggle.Text = "DEV (P)"
	toggle.Size = UDim2.fromOffset(70, 24)
	toggle.Parent = gui
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0, 82)
	frame.Size = UDim2.fromOffset(260, 470)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Visible = false
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local order = 0
	local function row(inst)
		order += 1
		inst.LayoutOrder = order
		inst.Parent = frame
	end
	for _, section in SECTIONS do
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(1, 0, 0, 20)
		head.BackgroundTransparency = 1
		head.Font = Enum.Font.Code
		head.TextSize = 13
		head.TextColor3 = Color3.fromRGB(230, 120, 200)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Text = string.upper(section[1])
		row(head)
		for _, b in section[2] do
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 0, 26)
			button.BackgroundColor3 = Color3.fromRGB(42, 46, 56)
			button.BorderSizePixel = 0
			button.Font = Enum.Font.Gotham
			button.TextSize = 13
			button.TextColor3 = Color3.fromRGB(225, 230, 238)
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = "  " .. b[1]
			button.AutoButtonColor = true
			button.Activated:Connect(function()
				Remotes.Dev:FireServer(b[2], b[3])
			end)
			row(button)
		end
	end
	Hud.Panels.Dev = frame -- counts as an open menu: the mouse is free while it shows
	toggle.Activated:Connect(function()
		frame.Visible = not frame.Visible
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P then
			frame.Visible = not frame.Visible
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function DevPanel.Init()
	local function check()
		if ReplicatedStorage:GetAttribute("DevPanel") == true and not player.PlayerGui:FindFirstChild("DevPanel") then
			build()
		end
	end
	player:WaitForChild("PlayerGui")
	check()
	ReplicatedStorage:GetAttributeChangedSignal("DevPanel"):Connect(check)
end

return DevPanel
