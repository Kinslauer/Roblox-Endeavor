-- Input + HUD. The client only sends intent; the server decides what happens.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared:WaitForChild("Armor"))
local Cybernetics = require(Shared:WaitForChild("Cybernetics"))
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Skills = require(Shared:WaitForChild("Skills"))

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

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextSize = props.TextSize or 16
	return make("TextLabel", props, props.Parent)
end

local function bar(y, color)
	local back = make("Frame", { Size = UDim2.fromOffset(240, 12), Position = UDim2.new(0, 20, 1, y), BackgroundColor3 = Color3.fromRGB(20, 20, 24) })
	return make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, back)
end

local staminaFill = bar(-80, Color3.fromRGB(90, 200, 120))
local postureFill = bar(-60, Color3.fromRGB(240, 150, 60))
local chargeFill = bar(-40, Color3.fromRGB(80, 170, 255))
local levelLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0, 20, 1, -104), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local flickerLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0, 20, 1, -124), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(255, 80, 80) })
local banner = label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 60), TextSize = 26, Text = "", TextTransparency = 1 })
local questLabel = label({ Size = UDim2.fromOffset(360, 24), Position = UDim2.new(1, -380, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Text = "" })

-- ===== Panels =====
local function panel(size, position)
	local frame = make("ScrollingFrame", {
		Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(15, 15, 20), Visible = false,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	})
	make("UIListLayout", { Padding = UDim.new(0, 4) }, frame)
	return frame
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- buttons: { { text, fn, color? } }, laid out right-to-left
local function addRow(frame, text, buttons, textColor)
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1 }, frame)
	label({ Size = UDim2.new(1, -8 - 58 * #buttons, 1, 0), Position = UDim2.fromOffset(6, 0), Text = text, TextColor3 = textColor, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	for i, b in buttons do
		local btn = make("TextButton", {
			Size = UDim2.fromOffset(54, 24), Position = UDim2.new(1, -58 * (#buttons - i + 1), 0, 2), Text = b.text,
			BackgroundColor3 = b.color or Color3.fromRGB(60, 80, 120), TextColor3 = Color3.new(1, 1, 1), TextSize = 13,
		}, row)
		btn.Activated:Connect(b.fn)
	end
end

local statsPanel = panel(UDim2.fromOffset(260, 220), UDim2.fromOffset(20, 120))
local invPanel = panel(UDim2.fromOffset(380, 400), UDim2.new(0.5, -190, 0.5, -200))
local loadoutPanel = panel(UDim2.fromOffset(420, 400), UDim2.new(1, -440, 0.5, -200))

-- ===== Announcements =====
local KIND_COLORS = {
	Emergence = Color3.fromRGB(255, 90, 90), Event = Color3.fromRGB(255, 200, 60),
	Kill = Color3.fromRGB(230, 230, 230), Info = Color3.fromRGB(120, 220, 255), District = Color3.fromRGB(200, 200, 255),
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

-- ===== Attributes (K) =====
local statLabels = {}
local statsTitle = label({ Size = UDim2.new(1, 0, 0, 28), Text = "Attributes" })
statsTitle.Parent = statsPanel
for _, name in Config.Stats.Names do
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1 }, statsPanel)
	statLabels[name] = label({ Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(6, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	make("TextButton", { Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -34, 0, 2), Text = "+", BackgroundColor3 = Color3.fromRGB(60, 120, 80), TextColor3 = Color3.new(1, 1, 1) }, row).Activated:Connect(function()
		Remotes.Allocate:FireServer(name)
	end)
end
Remotes.StatsChanged.OnClientEvent:Connect(function(data)
	statsTitle.Text = ("Attributes - %d points"):format(data.FreePoints)
	for name, lbl in statLabels do
		lbl.Text = ("%s: %d"):format(name, data.Stats[name])
	end
	levelLabel.Text = ("Lv %d  (%d/%d xp)"):format(data.Level, data.Xp, data.XpNeeded)
end)

-- ===== Inventory / crafting (I) =====
local lastInventory, lastEquipped, lastArmor, lastCyber = {}, "Fists", {}, {}

local function renderInventory()
	clear(invPanel)
	local ids = {}
	for id in lastInventory do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local da, db = Items.Defs[a], Items.Defs[b]
		return if da.Type ~= db.Type then da.Type < db.Type else da.Name < db.Name
	end)
	for _, id in ids do
		local def, buttons = Items.Defs[id], {}
		if def.Type == "Consumable" then
			table.insert(buttons, { text = "Use", fn = function() Remotes.UseItem:FireServer(id) end })
		elseif def.Type == "Weapon" then
			local held = lastEquipped == id
			table.insert(buttons, { text = if held then "Unequip" else "Equip", color = if held then Color3.fromRGB(120, 70, 70) else nil, fn = function()
				if held then Remotes.Unequip:FireServer("Weapon") else Remotes.EquipItem:FireServer(id) end
			end })
		elseif def.Type == "Armor" or def.Type == "Cybernetic" then
			local worn = lastArmor[def.Slot] == id or lastCyber[def.Slot] == id
			table.insert(buttons, { text = if worn then "Remove" else "Wear", color = if worn then Color3.fromRGB(120, 70, 70) else nil, fn = function()
				if worn then Remotes.Unequip:FireServer(def.Slot) else Remotes.EquipItem:FireServer(id) end
			end })
		end
		local suffix = if def.Slot then (" [%s]"):format(def.Slot) else ""
		addRow(invPanel, ("%s x%d%s"):format(def.Name, lastInventory[id], suffix), buttons)
	end
	addRow(invPanel, "-- Crafting --", {})
	for recipeId, recipe in Items.Recipes do
		local parts = {}
		for id, n in recipe.Inputs do
			table.insert(parts, ("%dx %s"):format(n, Items.Defs[id].Name))
		end
		addRow(invPanel, Items.Defs[recipe.Output].Name .. ": " .. table.concat(parts, ", "), { { text = "Craft", fn = function() Remotes.Craft:FireServer(recipeId) end } })
	end
end
Remotes.InventoryChanged.OnClientEvent:Connect(function(inv, equipped, armor, cyber)
	lastInventory, lastEquipped, lastArmor, lastCyber = inv, equipped, armor, cyber
	renderInventory()
end)

-- ===== Loadout: derived stats, worn tags, skills (L) + hotbar =====
local loadout
local cooldowns = {} -- skillId -> os.clock() when ready
local hotbar = {}
local SLOT_KEYS = { "R", "Y", "V" }
for i = 1, Skills.SlotCount do
	local box = make("Frame", { Size = UDim2.fromOffset(110, 46), Position = UDim2.new(0.5, -170 + (i - 1) * 116, 1, -66), BackgroundColor3 = Color3.fromRGB(15, 15, 20) })
	hotbar[i] = label({ Size = UDim2.fromScale(1, 1), TextSize = 13, TextWrapped = true, Text = SLOT_KEYS[i], Parent = box })
end

local function renderHotbar()
	for i = 1, Skills.SlotCount do
		local id = loadout and loadout.Slots[tostring(i)]
		local def = id and Skills.Defs[id]
		if not def then
			hotbar[i].Text = ("[%s] -"):format(SLOT_KEYS[i])
		else
			local ok = Skills.Unlocked(def, loadout.Stats, loadout.Tags)
			local remaining = (cooldowns[id] or 0) - os.clock()
			hotbar[i].Text = ("[%s] %s%s"):format(SLOT_KEYS[i], def.Name, if not ok then "\n(locked)" elseif remaining > 0 then ("\n%.0fs"):format(remaining) else "")
			hotbar[i].TextColor3 = if ok and remaining <= 0 then Color3.new(1, 1, 1) else Color3.fromRGB(130, 130, 130)
		end
	end
end
RunService.Heartbeat:Connect(renderHotbar)

local function renderLoadout()
	clear(loadoutPanel)
	if not loadout then
		return
	end
	local tagParts = {}
	for tag, n in loadout.Tags do
		table.insert(tagParts, ("%s x%d"):format(tag, n))
	end
	addRow(loadoutPanel, "Weapon: " .. Items.Defs[loadout.Weapon].Name, {})
	for _, slot in Armor.Slots do
		local id = loadout.Armor[slot]
		addRow(loadoutPanel, ("%s: %s"):format(slot, if id then Items.Defs[id].Name else "-"), {})
	end
	for _, slot in Cybernetics.Slots do
		local id = loadout.Cyber[slot]
		addRow(loadoutPanel, ("%s implant: %s"):format(slot, if id then Items.Defs[id].Name else "-"), {})
	end
	addRow(loadoutPanel, ("Flick window x%.2f  |  Black Flash x%.1f"):format(loadout.FlickerRate, 2.5 + loadout.FlashBonus), {})
	addRow(loadoutPanel, ("Resist  Phys %d%%  Arc %d%%  |  Weight %d  |  Posture %d"):format(
		loadout.Resist.Physical * 100, loadout.Resist.Arc * 100, loadout.WeightScore, loadout.MaxPosture), {})
	addRow(loadoutPanel, "Tags: " .. (if #tagParts > 0 then table.concat(tagParts, ", ") else "none"), {})
	addRow(loadoutPanel, "-- Skills (unlocked by stats + gear) --", {})
	for _, id in Skills.Order do
		local def = Skills.Defs[id]
		local ok, reason = Skills.Unlocked(def, loadout.Stats, loadout.Tags)
		if ok then
			local buttons = {}
			for i = 1, Skills.SlotCount do
				table.insert(buttons, { text = tostring(i), color = if loadout.Slots[tostring(i)] == id then Color3.fromRGB(60, 140, 90) else nil, fn = function() Remotes.SetSkill:FireServer(i, id) end })
			end
			addRow(loadoutPanel, def.Name .. " - " .. def.Desc, buttons)
		else
			addRow(loadoutPanel, ("%s (needs %s)"):format(def.Name, reason), {}, Color3.fromRGB(140, 140, 140))
		end
	end
end
Remotes.LoadoutChanged.OnClientEvent:Connect(function(data)
	loadout = data
	renderLoadout()
end)

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

-- ===== Raid HUD =====
local raidLabel = label({ Size = UDim2.fromOffset(360, 44), Position = UDim2.new(1, -380, 0, 50), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 80, 80), Font = Enum.Font.GothamBold, TextSize = 18, Text = "" })
Remotes.Raid.OnClientEvent:Connect(function(info)
	if not info then
		raidLabel.Text = ""
	elseif info.Joining then
		raidLabel.Text = "BLACKOUT RAID\nwaiting for the gate..."
	elseif info.Done then
		raidLabel.Text = "RAID CLEARED\nclaim the vault"
	else
		raidLabel.Text = ("%s\nwave %d/%d  -  %d left"):format(if info.Boss then "THE WARDEN" else "BLACKOUT RAID", info.Wave, info.Waves, info.Remaining)
	end
end)

-- ===== Helmetcam (P): first person with your body visible =====
local helmetcam = false
local savedZoom = { min = 0.5, max = 128 }
local function setHelmetcam(on)
	helmetcam = on
	if on then
		savedZoom.min, savedZoom.max = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
		player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 0.5
	else
		player.CameraMinZoomDistance, player.CameraMaxZoomDistance = savedZoom.min, savedZoom.max
		local char = player.Character
		if char then
			for _, p in char:GetDescendants() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end
end
-- Roblox hides the whole body in first person; re-show everything except the head each frame.
RunService.RenderStepped:Connect(function()
	if not helmetcam then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Head" and p.Name ~= "HumanoidRootPart" then
			p.LocalTransparencyModifier = 0
		elseif p:IsA("Accessory") then
			local handle = p:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 1
			end
		end
	end
end)

-- ===== Tutorial panel =====
local tutorialPanel = make("Frame", { Size = UDim2.fromOffset(560, 112), Position = UDim2.new(0.5, -280, 0, 110), BackgroundColor3 = Color3.fromRGB(10, 14, 20), BackgroundTransparency = 0.15, Visible = false })
make("UIStroke", { Color = Color3.fromRGB(0, 220, 255), Thickness = 1.5 }, tutorialPanel)
local tutorialTitle = label({ Size = UDim2.new(1, -110, 0, 26), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(0, 220, 255), Font = Enum.Font.GothamBold, TextSize = 18, Text = "", Parent = tutorialPanel })
local tutorialText = label({ Size = UDim2.new(1, -24, 1, -40), Position = UDim2.fromOffset(12, 32), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 16, Text = "", Parent = tutorialPanel })
local tutorialStep = label({ Size = UDim2.fromOffset(60, 26), Position = UDim2.new(1, -140, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 150, 160), TextSize = 14, Text = "", Parent = tutorialPanel })
make("TextButton", { Size = UDim2.fromOffset(60, 22), Position = UDim2.new(1, -72, 0, 8), Text = "Skip", BackgroundColor3 = Color3.fromRGB(70, 70, 85), TextColor3 = Color3.new(1, 1, 1), TextSize = 13 }, tutorialPanel).Activated:Connect(function()
	Remotes.TutorialSkip:FireServer()
end)
Remotes.Tutorial.OnClientEvent:Connect(function(index, total, title, text)
	if not index then
		tutorialPanel.Visible = false
		return
	end
	tutorialPanel.Visible = true
	tutorialStep.Text = ("%d/%d"):format(index, total)
	tutorialTitle.Text, tutorialText.Text = title, text
end)

-- ===== Phase =====
Remotes.PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase == "Open" then
		tutorialPanel.Visible = false
	end
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
	Hit = Color3.fromRGB(255, 70, 70), Block = Color3.fromRGB(150, 150, 255), Parry = Color3.fromRGB(255, 255, 255), Devour = Color3.fromRGB(120, 0, 160),
	GuardBreak = Color3.fromRGB(255, 160, 0), Burst = Color3.fromRGB(80, 170, 255), Dodge = Color3.fromRGB(120, 255, 200),
	Buff = Color3.fromRGB(255, 220, 120), Flick = Color3.fromRGB(255, 60, 60), Feint = Color3.fromRGB(200, 200, 200),
}

-- Flickering cursed energy: the chain level (character attribute "Flicker") and the Zone
-- ("Zone") are drawn on every character as a flickering dark/red aura.
local auras = setmetatable({}, { __mode = "k" })
RunService.Heartbeat:Connect(function()
	local myChar = player.Character
	local myLevel = myChar and myChar:GetAttribute("Flicker") or 0
	local myZone = myChar and myChar:GetAttribute("Zone")
	flickerLabel.Text = if myZone then "ZONE" elseif myLevel > 0 then ("FLICKER x%d"):format(myLevel) else ""
	for _, other in Players:GetPlayers() do
		local char = other.Character
		if char then
			local level, zone = char:GetAttribute("Flicker") or 0, char:GetAttribute("Zone")
			local aura = auras[char]
			if level > 0 or zone then
				if not aura or not aura.Parent then
					aura = make("Highlight", { FillColor = Color3.new(0, 0, 0), OutlineColor = Color3.fromRGB(255, 30, 30), OutlineTransparency = 0 }, char)
					auras[char] = aura
				end
				local rate = 6 + level * 8
				local on = zone or math.floor(os.clock() * rate) % 2 == 0
				aura.FillTransparency = if on then 0.35 else 1
				aura.OutlineTransparency = if on then 0 else 0.7
			elseif aura then
				aura:Destroy()
				auras[char] = nil
			end
		end
	end
end)

local function blackFlashFx(attacker, victim)
	local vroot = typeof(victim) == "Instance" and victim:FindFirstChild("HumanoidRootPart")
	if vroot then
		local spark = make("Part", { Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 20, 20), Size = Vector3.new(2, 2, 2), Position = vroot.Position }, workspace)
		TweenService:Create(spark, TweenInfo.new(0.35), { Size = Vector3.new(12, 12, 12), Transparency = 1 }):Play()
		Debris:AddItem(spark, 0.4)
	end
	if attacker == player.Character or victim == player.Character then
		local cc = make("ColorCorrectionEffect", { Brightness = -0.35, Contrast = 0.6, Saturation = -1, TintColor = Color3.fromRGB(255, 120, 120) }, Lighting)
		TweenService:Create(cc, TweenInfo.new(0.4), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(cc, 0.5)
		bannerToken += 1
		local token = bannerToken
		banner.Text, banner.TextColor3, banner.TextTransparency = "BLACK FLASH", Color3.fromRGB(255, 40, 40), 0
		task.delay(1.2, function()
			if token == bannerToken then
				banner.TextTransparency = 1
			end
		end)
	end
end

Remotes.CombatEvent.OnClientEvent:Connect(function(kind, a, b)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "DodgeMove" or kind == "Knockback" then
		if root then
			root.AssemblyLinearVelocity = a -- we own our character's physics
		end
	elseif kind == "BlackFlash" then
		blackFlashFx(a, b)
	elseif kind == "SkillCD" then
		cooldowns[a] = os.clock() + b
	elseif kind == "Bolt" then
		local from = typeof(a) == "Instance" and a:FindFirstChild("HumanoidRootPart")
		if from then
			local length = (b - from.Position).Magnitude
			local beam = make("Part", {
				Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 200, 255),
				Size = Vector3.new(0.2, 0.2, length), CFrame = CFrame.lookAt(from.Position, b) * CFrame.new(0, 0, -length / 2),
			}, workspace)
			Debris:AddItem(beam, 0.1)
		end
	elseif FLASH[kind] then
		flash(a, FLASH[kind])
	end
	-- TODO: kind == "Swing" -> play the weapon's animation (a = char, b = combo index / "Heavy" / skill name)
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
	bindBar(postureFill, char, "Posture", "MaxPosture")
	bindBar(chargeFill, char, "Charge", "MaxCharge")
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

local SKILL_KEYS = { [Enum.KeyCode.R] = 1, [Enum.KeyCode.Y] = 2, [Enum.KeyCode.V] = 3 }
local TOGGLES = { [Enum.KeyCode.J] = statsPanel, [Enum.KeyCode.Tab] = invPanel, [Enum.KeyCode.L] = loadoutPanel }

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Attack:FireServer()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		Remotes.Heavy:FireServer()
	elseif key == Enum.KeyCode.F then
		Remotes.Block:FireServer(true)
	elseif key == Enum.KeyCode.E then
		Remotes.Flicker:FireServer() -- tap just before your swing connects
	elseif key == Enum.KeyCode.Z then
		Remotes.Feint:FireServer()
	elseif key == Enum.KeyCode.P then
		setHelmetcam(not helmetcam)
	elseif key == Enum.KeyCode.Q then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root then
			local dir = if hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection else -root.CFrame.LookVector -- backstep by default
			Remotes.Dodge:FireServer(dir)
		end
	elseif SKILL_KEYS[key] then
		Remotes.UseSkill:FireServer(SKILL_KEYS[key])
	elseif TOGGLES[key] then
		TOGGLES[key].Visible = not TOGGLES[key].Visible
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		Remotes.Block:FireServer(false)
	end
end)
