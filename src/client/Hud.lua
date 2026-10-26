-- HUD: bars, panels, hotbar, announcements, tutorial, death screen. Pure presentation: it reads
-- replicated attributes and server->client remotes and only ever sends intent remotes from buttons.
-- (Moved out of Main.client.lua in story 001; HUD v2 redesign is a later epic.)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared:WaitForChild("Armor"))
local Config = require(Shared:WaitForChild("Config"))
local Cybernetics = require(Shared:WaitForChild("Cybernetics"))
local Items = require(Shared:WaitForChild("Items"))
local Attachments = require(Shared:WaitForChild("Attachments"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local HttpService = game:GetService("HttpService")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Skills = require(Shared:WaitForChild("Skills"))

local player = Players.LocalPlayer

local Hud = {}
Hud.Panels = {} -- name -> Frame (Input toggles these)

local gui, banner, flickerLabel, levelLabel, questLabel, zoneLabel, ammoLabel, moneyLabel
local bannerToken = 0
local cooldowns = {} -- skillId -> os.clock() when ready

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

-- A labelled resource bar: name on the left, numbers on the right, fill underneath.
local function bar(y, color, name)
	local back = make("Frame", { Size = UDim2.fromOffset(240, 14), Position = UDim2.new(0, 20, 1, y), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0 })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	label({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(4, 0), Text = name, TextSize = 11, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(235, 235, 240), ZIndex = 2, Parent = back })
	local value = label({ Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Text = "", TextSize = 11, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(235, 235, 240), ZIndex = 2, Parent = back })
	return fill, value
end

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

-- ===== Public API used by other client modules =====

-- True while something on screen needs the mouse: the character creator, or any HUD panel.
-- Aim frees the cursor and Input drops mouse-button combat while this is true.
function Hud.MenuOpen()
	if player:GetAttribute("CreatorOpen") then
		return true
	end
	for _, frame in Hud.Panels do
		if frame.Visible then
			return true
		end
	end
	return false
end

-- Hide every panel (the creator closes itself). Used by Aim's toggle key as an escape hatch.
function Hud.CloseAll()
	for _, frame in Hud.Panels do
		frame.Visible = false
	end
end

function Hud.Banner(text, color, seconds)
	bannerToken += 1
	local token = bannerToken
	banner.Text, banner.TextColor3, banner.TextTransparency = text, color or Color3.new(1, 1, 1), 0
	task.delay(seconds or 5, function()
		if token == bannerToken then
			banner.TextTransparency = 1
		end
	end)
end

function Hud.SetCooldown(skillId, seconds)
	cooldowns[skillId] = os.clock() + seconds
end

function Hud.SetFlickerText(text)
	flickerLabel.Text = text
end

-- ===== Sections =====

local function buildAnnouncements()
	local Lore = require(ReplicatedStorage.Shared:WaitForChild("Lore"))
	local KIND_COLORS = {
		Emergence = Color3.fromRGB(255, 90, 90), Event = Color3.fromRGB(255, 200, 60),
		Kill = Color3.fromRGB(230, 230, 230), Info = Color3.fromRGB(120, 220, 255), Lore = Lore.Color,
	}
	Remotes.Announce.OnClientEvent:Connect(function(text, kind)
		-- lore lines sit longer and read as a voice, not a notification
		banner.Font = if kind == "Lore" then Enum.Font.SourceSansItalic else Enum.Font.GothamMedium
		Hud.Banner(text, KIND_COLORS[kind], if kind == "Lore" then Lore.Seconds else nil)
	end)
end

local function buildStats(statsPanel)
	local statLabels = {}
	local statsTitle = label({ Size = UDim2.new(1, 0, 0, 28), Text = "Attributes", Parent = statsPanel })
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
end

local function buildInventory(invPanel)
	local lastInventory, lastEquipped, lastArmor, lastCyber = {}, "Fists", {}, {}
	local builds = {} -- server/Bench.lua: one JSON player attribute
	local function readBuilds()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Builds") or "{}")
		builds = if ok and type(decoded) == "table" then decoded else {}
	end
	local function atBench()
		return player:GetAttribute("Zone") == Config.Bench.Zone
	end

	local function render()
		clear(invPanel)
		-- the workbench (hideout only): the held gun's slots, with Strip buttons
		local heldDef = Weapons.Defs[lastEquipped]
		if atBench() and Weapons.IsGun(heldDef) then
			local build = builds[lastEquipped] or {}
			local eff = Attachments.Apply(heldDef, build)
			local g = eff.Gun or {}
			addRow(invPanel, ("-- Workbench: %s  (mag %d, spread %.1f/%.1f, kick %.1f) --"):format(heldDef.Name, g.Magazine or 0, g.Spread and g.Spread.Hip or 0, g.Spread and g.Spread.ADS or 0, g.Recoil and g.Recoil.Pitch or 0), if next(build) then { { text = "Frame", color = Color3.fromRGB(120, 70, 70), fn = function() Remotes.Bench:FireServer("StripAll", lastEquipped) end } } else {}, Color3.fromRGB(255, 170, 230))
			for _, slot in Attachments.Slots do
				local partId = build[slot]
				local part = partId and Attachments.Parts[partId]
				addRow(invPanel, ("   %s: %s"):format(slot, part and part.Name or "-"), if part then { { text = "Strip", color = Color3.fromRGB(120, 70, 70), fn = function() Remotes.Bench:FireServer("Strip", lastEquipped, slot) end } } else {})
			end
		elseif atBench() then
			addRow(invPanel, "-- Workbench: hold a gun to work on it --", {}, Color3.fromRGB(255, 170, 230))
		end
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
			elseif def.Type == "Part" and atBench() and Attachments.Fits(id, heldDef) then
				table.insert(buttons, { text = "Fit", color = Color3.fromRGB(140, 60, 120), fn = function() Remotes.Bench:FireServer("Fit", lastEquipped, id) end })
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
		render()
	end)
	player:GetAttributeChangedSignal("Builds"):Connect(function()
		readBuilds()
		render()
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(render)
	readBuilds()
end

local function buildLoadout(loadoutPanel)
	local loadout
	local hotbar = {}
	local SLOT_KEYS = { "R", "Y", "V" }
	for i = 1, Skills.SlotCount do
		local box = make("Frame", { Size = UDim2.fromOffset(110, 46), Position = UDim2.new(0.5, -170 + (i - 1) * 116, 1, -66), BackgroundColor3 = Color3.fromRGB(15, 15, 20) })
		hotbar[i] = label({ Size = UDim2.fromScale(1, 1), TextSize = 13, TextWrapped = true, Text = SLOT_KEYS[i], Parent = box })
	end

	RunService.Heartbeat:Connect(function()
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
	end)

	local function render()
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
		addRow(loadoutPanel, ("Flick window x%.2f  |  Black Flash x%.1f"):format(loadout.FlickerRate, Config.Flicker.BlackFlashMult + loadout.FlashBonus), {})
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
		render()
	end)
end

local function buildDeathScreen()
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
end

local function buildTutorial()
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
	-- Waiting screen: once you are ready (tutorial done or skipped) the prologue still has to run
	-- down for everyone; show that as a countdown instead of leaving you to idle in the room.
	local waitScreen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 9 })
	local waitTitle = label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.42, 0), TextSize = 30, Font = Enum.Font.GothamBlack, Text = "AWAITING EMERGENCE", TextColor3 = Color3.fromRGB(255, 90, 90), ZIndex = 10, Parent = waitScreen })
	local waitText = label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.42, 44), TextSize = 18, Text = "", ZIndex = 10, Parent = waitScreen })
	local waiting = false
	local function waitLoop()
		while waiting do
			local at = workspace:GetAttribute("EmergenceAt")
			if at then
				local left = math.max(0, at - workspace:GetServerTimeNow())
				waitText.Text = if left > 0 then ("The city wakes in %d s. Everyone is ready."):format(math.ceil(left)) else "The city is waking..."
			else
				waitText.Text = "You are ready. Waiting for the others to finish..."
			end
			task.wait(0.25)
		end
	end
	Remotes.PhaseChanged.OnClientEvent:Connect(function(phase)
		if phase == "Ready" then
			waitScreen.Visible = true
			if not waiting then
				waiting = true
				task.spawn(waitLoop)
			end
		elseif phase == "Open" then
			tutorialPanel.Visible = false
			waiting = false
			TweenService:Create(waitScreen, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
			task.delay(1.3, function()
				waitScreen.Visible = false
				waitScreen.BackgroundTransparency = 0.45
			end)
		elseif phase == "Emerging" then
			waitTitle.Text, waitText.Text = "EMERGENCE", ""
			waitScreen.Visible = true
			TweenService:Create(waitScreen, TweenInfo.new(Config.EmergenceCinematic), { BackgroundTransparency = 0 }):Play()
			local cc = make("ColorCorrectionEffect", {}, Lighting)
			TweenService:Create(cc, TweenInfo.new(Config.EmergenceCinematic), { Brightness = -0.4, Saturation = -1 }):Play()
			task.delay(Config.EmergenceCinematic + 1, function()
				cc:Destroy()
			end)
		end
	end)
end

local function bindBar(fill, valueLabel, char, valueAttr, maxAttr)
	local function update()
		local v, m = char:GetAttribute(valueAttr) or 0, char:GetAttribute(maxAttr) or 1
		fill.Size = UDim2.fromScale(math.clamp(v / m, 0, 1), 1)
		valueLabel.Text = ("%d / %d"):format(math.floor(v + 0.5), math.floor(m + 0.5))
	end
	char:GetAttributeChangedSignal(valueAttr):Connect(update)
	char:GetAttributeChangedSignal(maxAttr):Connect(update)
	update()
end

local function bindHealth(fill, valueLabel, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local function update()
		fill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
		valueLabel.Text = ("%d / %d"):format(math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
	end
	hum.HealthChanged:Connect(update)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

function Hud.Init()
	-- Tab is our inventory key, and the prologue is meant to feel single-player: no player list.
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "ConduitHUD", false
	gui.Parent = player:WaitForChild("PlayerGui")
	Hud.Gui = gui

	local healthFill, healthValue = bar(-102, Color3.fromRGB(220, 70, 70), "HEALTH")
	local staminaFill, staminaValue = bar(-84, Color3.fromRGB(90, 200, 120), "STAMINA")
	local postureFill, postureValue = bar(-66, Color3.fromRGB(240, 150, 60), "POSTURE")
	local chargeFill, chargeValue = bar(-48, Color3.fromRGB(80, 170, 255), "CHARGE")
	levelLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0, 20, 1, -126), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	flickerLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0, 20, 1, -146), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(255, 80, 80) })
	pcall(function() -- our own health bar replaces Roblox's
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	banner = label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 60), TextSize = 26, Text = "", TextTransparency = 1 })
	questLabel = label({ Size = UDim2.fromOffset(360, 24), Position = UDim2.new(1, -380, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	-- wallet + side (Money / Faction player attributes; Phase 3): under the quest line, top right
	moneyLabel = label({ Size = UDim2.fromOffset(360, 20), Position = UDim2.new(1, -380, 0, 46), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 15, Font = Enum.Font.GothamBold, Text = "", TextColor3 = Color3.fromRGB(255, 220, 120) })
	local function updateMoney()
		local money, faction = player:GetAttribute("Money"), player:GetAttribute("Faction")
		local side = ""
		if faction then
			for _, f in Config.War.Factions do
				if f.Id == faction then
					side = f.Name .. "  ·  "
				end
			end
		end
		moneyLabel.Text = if money ~= nil then ("%sMONEY %d"):format(side, money) else ""
	end
	player:GetAttributeChangedSignal("Money"):Connect(updateMoney)
	player:GetAttributeChangedSignal("Faction"):Connect(updateMoney)
	updateMoney()
	-- the war board (server/War.lua publishes War_* workspace attributes): tickets per side and the
	-- hill, shown while deployed; plus the DOWNED overlay for your own body
	local warBoard = make("Frame", { Size = UDim2.fromOffset(320, 112), Position = UDim2.new(0.5, -160, 0, 100), BackgroundColor3 = Color3.fromRGB(15, 15, 20), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false })
	local hillLine = label({ Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 2), TextSize = 14, Font = Enum.Font.GothamBold, Text = "", Parent = warBoard })
	local rows = {}
	for i, f in Config.War.Factions do
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 24 + (i - 1) * 22), BackgroundColor3 = Color3.fromRGB(28, 28, 34), BorderSizePixel = 0 }, warBoard)
		local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = f.Color, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, row)
		label({ Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(4, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Font = Enum.Font.GothamBold, Text = f.Name, ZIndex = 2, Parent = row })
		local value = label({ Size = UDim2.new(0.6, -4, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, Text = "", ZIndex = 2, Parent = row })
		rows[f.Id] = { fill = fill, value = value, def = f }
	end
	-- your shipment (Supply.lua: ShipmentReadyAt / ShipmentCount player attributes, wall clock)
	local shipLine = label({ Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 92), TextSize = 12, Font = Enum.Font.GothamBold, Text = "", TextColor3 = Color3.fromRGB(255, 170, 230), Parent = warBoard })
	local downedLabel = label({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.6, 0), TextSize = 30, Font = Enum.Font.GothamBlack, Text = "", TextColor3 = Color3.fromRGB(255, 90, 90), Visible = false })
	task.spawn(function()
		while true do
			task.wait(0.25)
			local inWar = player:GetAttribute("Zone") == "Range" and workspace:GetAttribute("War_Round") ~= nil
			warBoard.Visible = inWar
			if inWar then
				local owner, capturing, progress = workspace:GetAttribute("War_HillOwner") or "", workspace:GetAttribute("War_HillCapturing") or "", workspace:GetAttribute("War_HillProgress") or 0
				local function nameOf(id)
					for _, f in Config.War.Factions do
						if f.Id == id then
							return f.Name
						end
					end
					return "nobody"
				end
				local text = ("HILL: %s"):format(if owner ~= "" then nameOf(owner) else "unclaimed")
				if capturing ~= "" then
					text ..= ("  ·  %s taking it %d%%"):format(nameOf(capturing), math.floor(progress * 100 + 0.5))
				end
				hillLine.Text = text
				local readyAt, count = player:GetAttribute("ShipmentReadyAt"), player:GetAttribute("ShipmentCount")
				if readyAt then
					local eta = readyAt - os.time()
					shipLine.Text = if eta > 0 then ("SHIPMENT  ·  %d items land at your base in %d s"):format(count or 0, eta) else ("SHIPMENT  ·  %d items waiting at your base - hold X on the crate"):format(count or 0)
				else
					shipLine.Text = ""
				end
				for id, row in rows do
					local tickets = workspace:GetAttribute("War_Tickets_" .. id) or 0
					local recruits = workspace:GetAttribute("War_Recruits_" .. id) or 0
					row.fill.Size = UDim2.fromScale(math.clamp(tickets / math.max(Config.War.Tickets, 1), 0, 1), 1)
					local tier = workspace:GetAttribute("War_Tier_" .. id)
					row.value.Text = ("%d tickets  ·  %d recruits  ·  %s"):format(tickets, recruits, tier or "Basic")
					row.fill.BackgroundTransparency = if id == player:GetAttribute("Faction") then 0.1 else 0.45
				end
			end
			local char = player.Character
			local downed = char and char:GetAttribute("Downed")
			downedLabel.Visible = downed == true
			if downed then
				local left = math.max(0, (char:GetAttribute("DownedUntil") or 0) - workspace:GetServerTimeNow())
				downedLabel.Text = ("DOWNED\nan ally can revive you (hold X)  ·  bleeding out in %d s"):format(math.ceil(left))
			end
		end
	end)
	-- ammo counter (Ammo / MaxAmmo attributes, set by the server for guns; hidden for melee)
	ammoLabel = label({ Size = UDim2.fromOffset(200, 34), Position = UDim2.new(1, -220, 1, -70), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 28, Font = Enum.Font.GothamBlack, Text = "", TextColor3 = Color3.fromRGB(235, 235, 240) })
	-- shown while standing inside a safe zone (District.InSafeZone reads the tagged zone parts)
	zoneLabel = label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 28), TextSize = 14, Font = Enum.Font.GothamBold, Text = "", TextColor3 = Color3.fromRGB(120, 255, 200) })
	task.spawn(function()
		local District = require(ReplicatedStorage.Shared:WaitForChild("District"))
		local inside = false
		while true do
			task.wait(0.25)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local now, zone = false, nil
			if root then
				now, zone = District.InSafeZone(root.Position)
			end
			if now ~= inside then
				inside = now
				zoneLabel.Text = if now then ("SAFE ZONE  ·  %s"):format(zone and zone:GetAttribute("ZoneName") or "") else ""
				if now then
					Hud.Banner("You are safe here. Nothing can hurt you - and you cannot hurt anyone.", Color3.fromRGB(120, 255, 200), 3)
				else
					Hud.Banner("Leaving the safe zone.", Color3.fromRGB(255, 190, 40), 2)
				end
			end
		end
	end)

	Hud.Panels.Stats = panel(UDim2.fromOffset(260, 220), UDim2.fromOffset(20, 120))
	Hud.Panels.Inventory = panel(UDim2.fromOffset(380, 400), UDim2.new(0.5, -190, 0.5, -200))
	Hud.Panels.Loadout = panel(UDim2.fromOffset(420, 400), UDim2.new(1, -440, 0.5, -200))

	buildAnnouncements()
	buildStats(Hud.Panels.Stats)
	buildInventory(Hud.Panels.Inventory)
	buildLoadout(Hud.Panels.Loadout)
	buildDeathScreen()
	buildTutorial()

	Remotes.QuestChanged.OnClientEvent:Connect(function(title, progress, count)
		questLabel.Text = if title then ("%s  [%d/%d]"):format(title, progress, count) else ""
	end)

	local function bindAmmo(char)
		local function update()
			local ammo, max = char:GetAttribute("Ammo"), char:GetAttribute("MaxAmmo")
			if ammo == nil or max == nil then
				ammoLabel.Text = ""
				return
			end
			local reloading = char:GetAttribute("Reloading")
			ammoLabel.Text = if reloading then "RELOADING" else ("%d / %d"):format(ammo, max)
			ammoLabel.TextColor3 = if reloading then Color3.fromRGB(255, 190, 40) elseif ammo == 0 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(235, 235, 240)
		end
		for _, attr in { "Ammo", "MaxAmmo", "Reloading" } do
			char:GetAttributeChangedSignal(attr):Connect(update)
		end
		update()
	end

	local function onCharacter(char)
		task.spawn(bindHealth, healthFill, healthValue, char)
		bindBar(staminaFill, staminaValue, char, "Stamina", "MaxStamina")
		bindBar(postureFill, postureValue, char, "Posture", "MaxPosture")
		bindBar(chargeFill, chargeValue, char, "Charge", "MaxCharge")
		bindAmmo(char)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return Hud
