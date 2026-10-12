-- Input + HUD. The client only sends intent; the server decides what happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "ConduitHUD", false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent or gui
	return inst
end

local function label(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextSize = props.TextSize or 16
	return make("TextLabel", props, props.Parent)
end

local function bar(y, color)
	local back = make("Frame", { Size = UDim2.fromOffset(240, 12), Position = UDim2.new(0, 20, 1, y), BackgroundColor3 = Color3.fromRGB(20, 20, 24) })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, back)
	return fill
end

local staminaFill = bar(-60, Color3.fromRGB(90, 200, 120))
local chargeFill = bar(-40, Color3.fromRGB(80, 170, 255))
local banner = label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 60), TextSize = 26, Text = "", TextTransparency = 1 })
local questLabel = label({ Size = UDim2.fromOffset(360, 24), Position = UDim2.new(1, -380, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
local levelLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0, 20, 1, -84), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

-- ===== Announcements =====
local KIND_COLORS = {
	Emergence = Color3.fromRGB(255, 90, 90), Event = Color3.fromRGB(255, 200, 60),
	Kill = Color3.fromRGB(230, 230, 230), Info = Color3.fromRGB(120, 220, 255),
}
local bannerToken = 0
Remotes.Announce.OnClientEvent:Connect(function(text, kind)
	bannerToken += 1
	local token = bannerToken
	banner.Text, banner.TextColor3, banner.TextTransparency = text, KIND_COLORS[kind] or Color3.new(1, 1, 1), 0
	task.delay(5, function()
		if token == bannerToken then
			banner.TextTransparency = 1
		end
	end)
end)

-- ===== Stats panel (K) =====
local statsPanel = make("Frame", { Size = UDim2.fromOffset(260, 220), Position = UDim2.fromOffset(20, 120), BackgroundColor3 = Color3.fromRGB(15, 15, 20), Visible = false })
local statsTitle = label({ Size = UDim2.new(1, 0, 0, 28), Text = "Attributes", Parent = statsPanel })
local statRows = {}
for i, name in Config.Stats.Names do
	local row = label({ Size = UDim2.new(1, -50, 0, 28), Position = UDim2.fromOffset(10, 28 * i + 4), TextXAlignment = Enum.TextXAlignment.Left, Text = name, Parent = statsPanel })
	local button = make("TextButton", { Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -38, 0, 28 * i + 6), Text = "+", BackgroundColor3 = Color3.fromRGB(60, 120, 80), TextColor3 = Color3.new(1, 1, 1) }, statsPanel)
	button.Activated:Connect(function()
		Remotes.Allocate:FireServer(name)
	end)
	statRows[name] = row
end
Remotes.StatsChanged.OnClientEvent:Connect(function(data)
	statsTitle.Text = ("Attributes - %d points"):format(data.FreePoints)
	for name, row in statRows do
		row.Text = ("%s: %d"):format(name, data.Stats[name])
	end
	levelLabel.Text = ("Lv %d  (%d/%d xp)"):format(data.Level, data.Xp, data.XpNeeded)
end)

-- ===== Inventory / crafting panel (I) =====
local invPanel = make("ScrollingFrame", { Size = UDim2.fromOffset(320, 360), Position = UDim2.new(0.5, -160, 0.5, -180), BackgroundColor3 = Color3.fromRGB(15, 15, 20), Visible = false, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
make("UIListLayout", { Padding = UDim.new(0, 4) }, invPanel)

local function row(text, buttons)
	local frame = make("Frame", { Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1 }, invPanel)
	label({ Size = UDim2.new(1, -120, 1, 0), Text = text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, Parent = frame })
	for i, b in buttons do
		local btn = make("TextButton", { Size = UDim2.fromOffset(56, 24), Position = UDim2.new(1, -60 * (#buttons - i + 1), 0, 2), Text = b.text, BackgroundColor3 = Color3.fromRGB(60, 80, 120), TextColor3 = Color3.new(1, 1, 1), TextSize = 13 }, frame)
		btn.Activated:Connect(b.fn)
	end
end

local function renderInventory(inv, equipped)
	for _, child in invPanel:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for id, count in inv do
		local def = Items.Defs[id]
		local buttons = {}
		if def.Type == "Consumable" then
			table.insert(buttons, { text = "Use", fn = function() Remotes.UseItem:FireServer(id) end })
		elseif def.Type == "Weapon" then
			table.insert(buttons, { text = if equipped == id then "Held" else "Equip", fn = function() Remotes.EquipItem:FireServer(id) end })
		end
		row(("%s x%d"):format(def.Name, count), buttons)
	end
	row("-- Crafting --", {})
	for recipeId, recipe in Items.Recipes do
		local parts = {}
		for id, n in recipe.Inputs do
			table.insert(parts, ("%dx %s"):format(n, Items.Defs[id].Name))
		end
		row(Items.Defs[recipe.Output].Name .. ": " .. table.concat(parts, ", "), { { text = "Craft", fn = function() Remotes.Craft:FireServer(recipeId) end } })
	end
end
Remotes.InventoryChanged.OnClientEvent:Connect(renderInventory)

Remotes.QuestChanged.OnClientEvent:Connect(function(title, progress, count)
	questLabel.Text = if title then ("%s  [%d/%d]"):format(title, progress, count) else ""
end)

-- ===== Death screen =====
local deathScreen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, Visible = false, ZIndex = 10 })
local deathText = label({ Size = UDim2.fromScale(1, 1), TextSize = 28, Text = "", ZIndex = 11, Parent = deathScreen })
Remotes.Died.OnClientEvent:Connect(function(summary)
	local m, s = math.floor(summary.Survived / 60), summary.Survived % 60
	deathText.Text = ("YOU DIED\n\nSurvived %dm %ds  |  Level %d  |  %d kills\n%s\n\nA new conduit awakens..."):format(
		m, s, summary.Level, summary.Kills, if summary.Killer then "Killed by " .. summary.Killer else "")
	deathScreen.Visible = true
	task.delay(Config.RespawnDelay, function()
		deathScreen.Visible = false
	end)
end)

-- ===== Phase =====
Remotes.PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase == "Emerging" then
		local cc = make("ColorCorrectionEffect", {}, game:GetService("Lighting"))
		game:GetService("TweenService"):Create(cc, TweenInfo.new(Config.EmergenceCinematic), { Brightness = -0.4, Saturation = -1 }):Play()
		task.delay(Config.EmergenceCinematic + 1, function()
			cc:Destroy()
		end)
	end
end)

-- ===== Combat feedback & movement =====
local function flash(char, color)
	if typeof(char) ~= "Instance" then
		return
	end
	local h = make("Highlight", { FillColor = color, FillTransparency = 0.4, OutlineTransparency = 1 }, char)
	task.delay(0.15, function()
		h:Destroy()
	end)
end

local FLASH = {
	Hit = Color3.fromRGB(255, 70, 70), Block = Color3.fromRGB(150, 150, 255), Parry = Color3.fromRGB(255, 255, 255),
	GuardBreak = Color3.fromRGB(255, 160, 0), Surge = Color3.fromRGB(80, 170, 255), Dodge = Color3.fromRGB(120, 255, 200),
}
Remotes.CombatEvent.OnClientEvent:Connect(function(kind, a)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "DodgeMove" or kind == "Knockback" then
		if root then
			root.AssemblyLinearVelocity = a -- we own our character's physics
		end
	elseif FLASH[kind] then
		flash(a, FLASH[kind])
	end
	-- TODO: kind == "Swing" -> play weapon animation (a = char, b = combo index)
end)

local function bindBar(fill, char, valueAttr, maxAttr)
	local function update()
		local v, m = char:GetAttribute(valueAttr) or 0, char:GetAttribute(maxAttr) or 1
		fill.Size = UDim2.fromScale(math.clamp(v / m, 0, 1), 1)
	end
	char:GetAttributeChangedSignal(valueAttr):Connect(update)
	char:GetAttributeChangedSignal(maxAttr):Connect(update)
	update()
end
local function onCharacter(char)
	bindBar(staminaFill, char, "Stamina", "MaxStamina")
	bindBar(chargeFill, char, "Charge", "MaxCharge")
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Attack:FireServer()
	elseif key == Enum.KeyCode.F then
		Remotes.Block:FireServer(true)
	elseif key == Enum.KeyCode.Q then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root then
			local dir = if hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection else -root.CFrame.LookVector -- backstep by default
			Remotes.Dodge:FireServer(dir)
		end
	elseif key == Enum.KeyCode.R then
		Remotes.Surge:FireServer()
	elseif key == Enum.KeyCode.K then
		statsPanel.Visible = not statsPanel.Visible
	elseif key == Enum.KeyCode.I then
		invPanel.Visible = not invPanel.Visible
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		Remotes.Block:FireServer(false)
	end
end)
