-- Prompts (combat-feel polish item 4, design/references/magoi-look-and-feel.md): every ProximityPrompt
-- in the world is drawn by us instead of Roblox's billboard - a small dark badge with the key letter
-- at the thing, the action and object text beside it, faint until the key is held. Pure presentation:
-- the prompts themselves (server-made: consoles, loot, contacts, hubs) are untouched except for their
-- Style, which is a local property. Touch and gamepad still work: the badge is a button that begins
-- and ends the hold. Tuning: Presentation.Prompts.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local PR = Presentation.Prompts

local Prompts = {}

local player = Players.LocalPlayer
local live = {} -- prompt -> BillboardGui

local function adopt(inst)
	if inst:IsA("ProximityPrompt") then
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if s ~= "" then s else prompt.KeyboardKeyCode.Name
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = PR.LabelColor
	l.Font = PR.LabelFont
	l.TextSize = PR.LabelTextSize
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.6
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function show(prompt, inputType)
	local part = prompt.Parent
	if not (part and part:IsA("BasePart")) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ConduitPrompt"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(PR.BadgeSize + 180, PR.BadgeSize + 8)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.ResetOnSpawn = false

	local badge = Instance.new("TextButton")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(PR.BadgeSize, PR.BadgeSize)
	badge.Position = UDim2.fromOffset(0, 4)
	badge.BackgroundColor3, badge.BackgroundTransparency = PR.BadgeColor, PR.BadgeTransparency
	badge.Text = keyText(prompt, inputType)
	badge.TextColor3, badge.Font, badge.TextSize = PR.KeyColor, PR.Font, PR.KeyTextSize
	badge.AutoButtonColor = false
	badge.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = PR.KeyColor, 1.5, 0.5
	stroke.Parent = badge

	local action = label(gui, { Size = UDim2.fromOffset(176, 16), Position = UDim2.fromOffset(PR.BadgeSize + 8, 2),
		Text = prompt.ActionText, Font = PR.Font, TextTransparency = PR.LabelIdleTransparency })
	local object = label(gui, { Size = UDim2.fromOffset(176, 14), Position = UDim2.fromOffset(PR.BadgeSize + 8, 19),
		Text = prompt.ObjectText, TextSize = PR.LabelTextSize - 1, TextTransparency = PR.LabelIdleTransparency + 0.15 })

	-- the hold: the ring fills with the hold colour over HoldDuration, the labels come up to full
	local fill
	local function holdBegan()
		stroke.Color, stroke.Transparency = PR.HoldColor, 0
		action.TextTransparency, object.TextTransparency = 0, 0.2
		if prompt.HoldDuration > 0 then
			fill = TweenService:Create(badge, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { BackgroundColor3 = PR.HoldColor })
			fill:Play()
		end
	end
	local function holdEnded()
		if fill then
			fill:Cancel()
			fill = nil
		end
		badge.BackgroundColor3 = PR.BadgeColor
		stroke.Color, stroke.Transparency = PR.KeyColor, 0.5
		action.TextTransparency, object.TextTransparency = PR.LabelIdleTransparency, PR.LabelIdleTransparency + 0.15
	end
	prompt.PromptButtonHoldBegan:Connect(holdBegan)
	prompt.PromptButtonHoldEnded:Connect(holdEnded)
	prompt.Triggered:Connect(holdEnded)
	-- touch / mouse on the badge drives the prompt
	badge.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	badge.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	live[prompt] = gui
end

local function hide(prompt)
	local gui = live[prompt]
	if gui then
		gui:Destroy()
		live[prompt] = nil
	end
end

function Prompts.Init()
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return Prompts
