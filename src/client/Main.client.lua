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
local Firearms = require(Shared:WaitForChild("Firearms"))
local HideoutDefs = require(Shared:WaitForChild("Hideout"))
local Items = require(Shared:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
-- Sounds for combat events, played at the character they happened to.
local SOUND = { Hit = "HitFlesh", Block = "BlockThud", Parry = "HitClang", GuardBreak = "GuardBreak", Devour = "Devour", Flick = "FlickerTick" }
-- Sounds for props breaking, by prop id; anything else is metal. Chunks hitting the ground thud.
local BREAK_SOUND = { WindowPane = "BreakGlass", Crate = "BreakWood", Slab = "Collapse", Chunk = "ImpactDirt" }

local Skills = require(Shared:WaitForChild("Skills"))

local player = Players.LocalPlayer

local function cameraDirection()
	return workspace.CurrentCamera.CFrame.LookVector
end

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

local function flash(char, color)
	if typeof(char) ~= "Instance" then
		return
	end
	local h = make("Highlight", { FillColor = color, FillTransparency = 0.4, OutlineTransparency = 1 }, char)
	task.delay(0.15, function()
		h:Destroy()
	end)
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
local lastCondition, lastUpgrades = {}, {}

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
			table.insert(buttons, { text = if def.Throwable then "Throw" elseif def.Plantable then "Plant" else "Use", fn = function() Remotes.UseItem:FireServer(id, cameraDirection()) end })
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
		if def.Type == "Weapon" or def.Type == "Armor" or def.Type == "Cybernetic" then
			local cond, up = lastCondition[id] or 100, lastUpgrades[id] or 0
			suffix ..= (" %d%%%s"):format(cond, if up > 0 then " +" .. up else "")
			if cond <= 0 then
				suffix ..= " BROKEN"
			end
		end
		addRow(invPanel, ("%s x%d%s"):format(def.Name, lastInventory[id], suffix), buttons, if (lastCondition[id] or 100) <= 25 then Color3.fromRGB(255, 150, 120) else nil)
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
	lastCondition, lastUpgrades = data.Condition or {}, data.Upgrades or {}
	renderLoadout()
	renderInventory()
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

-- ===== Grab / throw (G hold-to-charge, H drop) and world effects =====
local CollectionService = game:GetService("CollectionService")
local holdLabel = label({ Size = UDim2.fromOffset(360, 40), Position = UDim2.new(0.5, -180, 1, -120), TextSize = 14, TextColor3 = Color3.fromRGB(255, 220, 120), Text = "" })
local chargeStart = nil
local function nearestGrabbable()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	-- resting chunks within grab range; a chunk flying at you can be targeted from further out
	local best, bestDist = nil, Config.Destruction.CatchRange
	for _, part in CollectionService:GetTagged("Grabbable") do
		if part:IsA("BasePart") and part.Parent then
			local dist = (part.Position - root.Position).Magnitude
			local flying = part.AssemblyLinearVelocity.Magnitude > 10
			if dist < bestDist and (flying or dist <= Config.Destruction.GrabRange) then
				best, bestDist = part, dist
			end
		end
	end
	return best
end
local holdAccum = 0
RunService.Heartbeat:Connect(function(dt)
	holdAccum += dt
	if holdAccum < 0.1 then
		return
	end
	holdAccum = 0
	local char = player.Character
	local holding = char and char:GetAttribute("Holding")
	if holding then
		local charge = if chargeStart then math.clamp((os.clock() - chargeStart) / Config.Destruction.MaxChargeTime, 0, 1) else 0
		holdLabel.Text = ("Holding %s (%s)  -  G throw%s  -  H drop"):format(holding, char:GetAttribute("HoldClass") or "", if chargeStart then (("  [%d%%]"):format(charge * 100)) else " (hold to charge)")
	else
		local target = nearestGrabbable()
		holdLabel.Text = if not target then "" elseif target.AssemblyLinearVelocity.Magnitude > 10 then "G CATCH (time it)" else "G grab"
	end
end)

local worldDebris = 0
local function debris(position, color, count, size)
	for _ = 1, count do
		if worldDebris >= 300 then
			break
		end
		worldDebris += 1
		local p = make("Part", { Size = Vector3.new(size, size, size), Color = color, Material = Enum.Material.Concrete, CanCollide = false, CanQuery = false,
			Position = position + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5) * 2 }, workspace)
		p.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5) * 25
		task.delay(1.5, function()
			worldDebris -= 1
			p:Destroy()
		end)
	end
end

local function explosionFx(origin, radius)
	Sounds.Play("Explosion", origin)
	local sphere = make("Part", { Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 160, 60), Size = Vector3.new(2, 2, 2), Position = origin, Transparency = 0.1 }, workspace)
	TweenService:Create(sphere, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(sphere, 0.4)
	debris(origin, Color3.fromRGB(60, 50, 40), 14, 0.6)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dist = root and (root.Position - origin).Magnitude or math.huge
	if dist < radius * 3 then
		local cam = workspace.CurrentCamera
		local strength = (1 - math.clamp(dist / (radius * 3), 0, 1)) * 1.2
		task.spawn(function()
			for i = 1, 8 do
				local falloff = strength * (1 - i / 8)
				cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * 0.04 * falloff, (math.random() - 0.5) * 0.04 * falloff, 0)
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

-- ===== Gore effects (what the server allows; see Config.Destruction.GoreLevel) =====
local pools = {}
local function bloodSpray(position, direction, heavy)
	local count = if heavy then 10 else 4
	for _ = 1, count do
		if worldDebris >= 300 then
			break
		end
		worldDebris += 1
		local p = make("Part", { Size = Vector3.new(0.25, 0.25, 0.25), Color = Color3.fromRGB(120, 10, 15), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false,
			Position = position + Vector3.new(0, 1, 0) }, workspace)
		p.AssemblyLinearVelocity = (direction + Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)) * (if heavy then 22 else 12)
		task.delay(0.8, function()
			worldDebris -= 1
			p:Destroy()
		end)
	end
end
local function bloodPool(position, size)
	if #pools >= Config.Gore.PoolCap then
		local oldest = table.remove(pools, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local pool = make("Part", { Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(90, 5, 10), Size = Vector3.new(0.05, 0.5, 0.5), CFrame = CFrame.new(position - Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.1 }, workspace)
	TweenService:Create(pool, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, size * 3, size * 3) }):Play()
	table.insert(pools, pool)
	Debris:AddItem(pool, Config.Gore.PoolLifetime)
end

local dematerializing = false
Remotes.World.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Blood" then
		bloodSpray(a, b, c)
		if c then
			bloodPool(a, 0.6)
		end
	elseif kind == "Dismember" then
		bloodSpray(a, Vector3.yAxis, true)
		bloodSpray(a, Vector3.yAxis, true)
		bloodPool(a, 2)
	elseif kind == "Pool" then
		bloodPool(a, b)
	elseif kind == "ClearGore" then
		for _, pool in pools do
			pool:Destroy()
		end
		table.clear(pools)
	elseif kind == "CatchAttempt" then
		if a == player.Character then
			holdLabel.Text = "catch!"
		end
	elseif kind == "Catch" then
		flash(a, Color3.fromRGB(255, 255, 255))
		Sounds.Play("Catch", typeof(a) == "Instance" and (a:FindFirstChild("HumanoidRootPart") or a) or nil)
		if a == player.Character then
			bannerToken += 1
			local token = bannerToken
			banner.Text, banner.TextColor3, banner.TextTransparency = "CAUGHT", Color3.fromRGB(120, 255, 200), 0
			task.delay(1, function()
				if token == bannerToken then
					banner.TextTransparency = 1
				end
			end)
		end
	elseif kind == "Explosion" then
		explosionFx(a, b)
	elseif kind == "Break" then
		debris(a, Color3.fromRGB(90, 90, 100), 8, 0.5)
		Sounds.Play(BREAK_SOUND[b] or "BreakMetal", a)
	elseif kind == "PropHit" then
		debris(a, Color3.fromRGB(120, 120, 130), 2, 0.3)
	elseif kind == "Breach" then
		debris(a, Color3.fromRGB(60, 60, 70), 16, 0.7)
		Sounds.Play("Collapse", a)
	elseif kind == "BreachResist" then
		debris(a, Color3.fromRGB(255, 220, 120), 3, 0.2)
	elseif kind == "Fuse" and typeof(a) == "Instance" then
		make("PointLight", { Color = Color3.fromRGB(255, 80, 40), Range = 8, Brightness = 2 }, a)
	elseif kind == "DematerializeWarning" then
		dematerializing = true
		task.delay(a, function()
			dematerializing = false
		end)
	end
end)
-- while the warning runs, broken-world debris flickers so no one is caught inside a resealing wall
RunService.Heartbeat:Connect(function()
	if not dematerializing then
		return
	end
	local on = math.floor(os.clock() * 6) % 2 == 0
	for _, part in CollectionService:GetTagged("Grabbable") do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if on then 0 else 0.6
		end
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

-- ===== Neural Net uplink (tapping into the Front) =====
local uplinkFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20 })
local uplinkText = label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 30, Font = Enum.Font.Code, TextColor3 = Color3.fromRGB(170, 90, 255), ZIndex = 21, Parent = uplinkFrame })
Remotes.Uplink.OnClientEvent:Connect(function(phase, seconds, faction)
	if phase == "Begin" then
		uplinkFrame.Visible, uplinkFrame.BackgroundTransparency = true, 1
		TweenService:Create(uplinkFrame, TweenInfo.new(seconds * 0.6), { BackgroundTransparency = 0 }):Play()
		local cc = make("ColorCorrectionEffect", { Saturation = 0, Contrast = 0 }, Lighting)
		TweenService:Create(cc, TweenInfo.new(seconds), { Saturation = -1, Contrast = 1.5, TintColor = Color3.fromRGB(200, 150, 255) }):Play()
		local cam = workspace.CurrentCamera
		local start = cam.CFrame
		task.spawn(function()
			local t0 = os.clock()
			local lines = { "TAPPING INTO THE NEURAL NET", "handshake . . .", "locating a recruit . . .", ("%s FRONT  -  LINK ESTABLISHED"):format(string.upper(faction or "")) }
			while os.clock() - t0 < seconds do
				local f = (os.clock() - t0) / seconds
				uplinkText.Text = lines[math.min(#lines, math.floor(f * #lines) + 1)] .. (if math.floor(os.clock() * 4) % 2 == 0 then "_" else "")
				cam.CFrame = start * CFrame.new(0, 0, -f * 6) * CFrame.Angles((math.random() - 0.5) * 0.02 * f, (math.random() - 0.5) * 0.02 * f, 0)
				RunService.RenderStepped:Wait()
			end
			cc:Destroy()
		end)
	elseif phase == "NoPlace" or phase == "Failed" then
		uplinkText.Text = if phase == "NoPlace" then "FRONT OFFLINE  -  place not published" else "LINK LOST"
		task.delay(2, function()
			uplinkFrame.Visible = false
		end)
	end
end)

-- ===== Recruit app (M at a Neural Net terminal): order a loadout, buy, repair =====
local app = panel(UDim2.fromOffset(520, 440), UDim2.new(0.5, -260, 0.5, -220))
local snapshot
local function renderApp()
	clear(app)
	if not snapshot then
		return
	end
	local s = snapshot
	addRow(app, ("RECRUIT APP  -  %s  -  %d credits  -  %d deployments, %d kills, %d deaths"):format(s.Faction, s.Credits, s.Deployments, s.Kills, s.Deaths), {}, Config.War.FactionColors[s.Faction])
	local lo, atts = s.Loadout or {}, (s.Loadout or {}).Attachments or {}
	addRow(app, ("NEXT ORDER  Primary: %s  Sidearm: %s  Armor: %s  Helmet: %s"):format(lo.Primary or "-", lo.Sidearm or "-", lo.Armor or "-", lo.Helmet or "-"), {})
	addRow(app, ("Optic: %s  Muzzle: %s  Grip: %s"):format(atts.Optic or "-", atts.Muzzle or "-", atts.Grip or "-"), {})
	addRow(app, "-- LOCKER --", {})
	local ids = {}
	for id in s.Locker do table.insert(ids, id) end
	table.sort(ids)
	local function order(changes, attChanges)
		local o = { Primary = lo.Primary, Sidearm = lo.Sidearm, Armor = lo.Armor, Helmet = lo.Helmet, Attachments = table.clone(atts) }
		for k, v in changes do o[k] = v end
		for k, v in attChanges or {} do o.Attachments[k] = v end
		Remotes.WarOrder:FireServer(o)
	end
	for _, id in ids do
		local slot, item = s.Locker[id], s.Catalog[id] or { Kind = "?", Name = id }
		local buttons = {}
		if item.Kind == "Weapon" then
			local pistol = item.Class == "Pistol"
			table.insert(buttons, { text = if pistol then "Sidearm" else "Primary", fn = function() order({ [if pistol then "Sidearm" else "Primary"] = id }) end })
		elseif item.Kind == "Attachment" then
			table.insert(buttons, { text = "Mount", fn = function() order({}, { [item.Slot] = id }) end })
		elseif item.Kind == "Armor" then
			local helmet = Firearms.Armor[id] and Firearms.Armor[id].Head
			table.insert(buttons, { text = "Wear", fn = function() order({ [if helmet then "Helmet" else "Armor"] = id }) end })
		end
		if slot.condition < 100 then
			table.insert(buttons, { text = "Fix", color = Color3.fromRGB(120, 90, 40), fn = function() Remotes.WarRepair:FireServer(id) end })
		end
		addRow(app, ("%s x%d (%d%%)"):format(item.Name, slot.count, slot.condition), buttons, if slot.condition < 50 then Color3.fromRGB(255, 150, 120) else nil)
	end
	addRow(app, "-- SHOP --", {})
	local cids = {}
	for id, item in s.Catalog do if not item.Faction or item.Faction == s.Faction then table.insert(cids, id) end end
	table.sort(cids, function(a, b) return s.Catalog[a].Price < s.Catalog[b].Price end)
	for _, id in cids do
		local item = s.Catalog[id]
		addRow(app, ("%s - %d cr"):format(item.Name, item.Price), { { text = "Buy", color = Color3.fromRGB(50, 110, 70), fn = function() Remotes.WarBuy:FireServer(id) end } }, if item.Price > s.Credits then Color3.fromRGB(140, 140, 140) else nil)
	end
end
Remotes.RecruitApp.OnClientEvent:Connect(function(snap, open)
	snapshot = snap
	if open then
		app.Visible = true
	end
	renderApp()
end)

-- ===== Hideout panel (X at your workbench, or O) =====
local hidePanel = panel(UDim2.fromOffset(560, 460), UDim2.new(0.5, -280, 0.5, -230))
local hideout
local function costText(cost)
	local parts = {}
	for id, n in cost do
		table.insert(parts, ("%d %s"):format(n, Items.Defs[id] and Items.Defs[id].Name or id))
	end
	return if #parts > 0 then table.concat(parts, ", ") else "free"
end
local function renderHideout()
	clear(hidePanel)
	if not hideout then
		return
	end
	local h = hideout
	if not h.Site then
		addRow(hidePanel, "No hideout. Find an orange site post in the city and claim it (10 scrap).", {})
		addRow(hidePanel, "A hideout is where you repair, upgrade and store gear. Build walls: others can breach them and strip your vault.", {})
		return
	end
	addRow(hidePanel, ("%s  -  %s  -  %s"):format(h.Name or "Hideout", h.TierName or "", if h.Owned then "yours" else "crew member"), {}, Color3.fromRGB(255, 170, 40))
	local nextTier = HideoutDefs.Tiers[(h.Tier or 1) + 1]
	if h.Owned and nextTier then
		addRow(hidePanel, ("Upgrade workshop to %s: %s"):format(nextTier.Name, costText(nextTier.Cost)), { { text = "Upgrade", fn = function() Remotes.HideoutUpgrade:FireServer() end } })
	end
	addRow(hidePanel, "-- MODULES --", {})
	for id, def in HideoutDefs.Modules do
		if h.Modules and h.Modules[id] then
			addRow(hidePanel, def.Name .. "  (built)", {}, Color3.fromRGB(140, 220, 160))
		elseif h.Owned then
			addRow(hidePanel, ("%s - %s  [%s, tier %d]"):format(def.Name, def.Desc, costText(def.Cost), def.Tier), { { text = "Build", fn = function() Remotes.HideoutBuild:FireServer(id) end } }, if def.Tier > (h.Tier or 1) then Color3.fromRGB(140, 140, 140) else nil)
		end
	end
	addRow(hidePanel, "-- BENCH: repair and upgrade what you carry --", {})
	for id, count in lastInventory do
		local def = Items.Defs[id]
		if def and (def.Type == "Weapon" or def.Type == "Armor" or def.Type == "Cybernetic") then
			local cond, up = (h.Condition or {})[id] or 100, (h.Upgrades or {})[id] or 0
			local buttons = {}
			if cond < 100 then
				table.insert(buttons, { text = "Repair", color = Color3.fromRGB(120, 90, 40), fn = function() Remotes.HideoutRepair:FireServer(id) end })
			end
			if up < 3 then
				table.insert(buttons, { text = ("+%d"):format(up + 1), color = Color3.fromRGB(60, 110, 80), fn = function() Remotes.ItemUpgrade:FireServer(id) end })
			end
			if h.Modules and h.Modules.Vault then
				table.insert(buttons, { text = "Store", fn = function() Remotes.VaultPut:FireServer(id, 1) end })
			end
			addRow(hidePanel, ("%s x%d  %d%%  +%d"):format(def.Name, count, cond, up), buttons, if cond <= 0 then Color3.fromRGB(255, 120, 120) else nil)
		elseif def and def.Type == "Material" and h.Modules and h.Modules.Vault then
			addRow(hidePanel, ("%s x%d"):format(def.Name, count), { { text = "Store all", fn = function() Remotes.VaultPut:FireServer(id, count) end } })
		end
	end
	if h.Modules and h.Modules.Vault then
		addRow(hidePanel, "-- VAULT --", {})
		for id, count in h.Vault or {} do
			local def = Items.Defs[id] or { Name = id }
			local c, u = (h.VaultCondition or {})[id], (h.VaultUpgrades or {})[id]
			addRow(hidePanel, ("%s x%d%s%s"):format(def.Name, count, if c then (" %d%%"):format(c) else "", if u then " +" .. u else ""), { { text = "Take", fn = function() Remotes.VaultTake:FireServer(id, 1) end }, { text = "Take all", fn = function() Remotes.VaultTake:FireServer(id, count) end } })
		end
	end
	addRow(hidePanel, "-- CREW --", {})
	for _, userId in h.Members or {} do
		local name = tostring(userId)
		for _, p in Players:GetPlayers() do
			if p.UserId == userId then name = p.DisplayName end
		end
		addRow(hidePanel, name, if h.Owned then { { text = "Kick", color = Color3.fromRGB(120, 60, 60), fn = function() Remotes.HideoutKick:FireServer(userId) end } } else {})
	end
	if h.Owned then
		for _, p in Players:GetPlayers() do
			if p ~= player and not table.find(h.Members or {}, p.UserId) then
				addRow(hidePanel, "Invite " .. p.DisplayName, { { text = "Invite", fn = function() Remotes.HideoutInvite:FireServer(p.Name) end } })
			end
		end
	end
	addRow(hidePanel, if h.Owned then "Abandon the hideout (the vault stays for whoever breaches it)" else "Leave the crew", { { text = "Leave", color = Color3.fromRGB(120, 60, 60), fn = function() Remotes.HideoutLeave:FireServer() end } })
end
Remotes.Hideout.OnClientEvent:Connect(function(state, open)
	if state then
		hideout = state
	end
	if open then
		hidePanel.Visible = true
	end
	renderHideout()
end)

-- ===== Controls card (F1 toggles; shown for the first minute) =====
local controls = label({ Size = UDim2.fromOffset(330, 230), Position = UDim2.new(1, -350, 1, -260), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.new(0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 14, Font = Enum.Font.Code,
	Text = table.concat({ "CONTROLS  (F1 hides)", "LMB attack   RMB heavy   F block/parry", "Q dodge   Shift sprint   E flicker   Z feint",
		"R / Y / V skills   G grab, hold to throw   H drop", "X interact / loot   M devour remains", "Tab inventory   L loadout   J attributes",
		"O hideout   N recruit app   P helmetcam" }, "\n") })
task.delay(60, function()
	controls.Visible = false
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
	Sounds.Play("BlackFlash", vroot or nil)
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

-- A swing has no animation yet: draw a quick arc in front of whoever swung and punch our camera.
local function swingFx(char, label)
	local root = typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local heavy = label == "Heavy"
	Sounds.Play(if heavy then "SwingHeavy" else "SwingLight", root)
	local arc = make("Part", { Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
		Color = if heavy then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(220, 230, 255), Transparency = 0.35,
		Size = Vector3.new(0.15, if heavy then 9 else 7, if heavy then 9 else 7), CFrame = root.CFrame * CFrame.new(0, 0.5, -3) * CFrame.Angles(0, 0, math.pi / 2) }, workspace)
	TweenService:Create(arc, TweenInfo.new(0.18), { Transparency = 1, Size = arc.Size + Vector3.new(0, 2, 2) }):Play()
	Debris:AddItem(arc, 0.2)
	if char == player.Character then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(if heavy then -1.2 else -0.5), 0, 0)
	end
end

Remotes.CombatEvent.OnClientEvent:Connect(function(kind, a, b)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "Swing" then
		swingFx(a, b)
	elseif kind == "DodgeMove" or kind == "Knockback" then
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
	if SOUND[kind] and typeof(a) == "Instance" then
		Sounds.Play(SOUND[kind], a:FindFirstChild("HumanoidRootPart") or a)
	end
end)

-- Blocking shows as a steady blue outline on the character; sprinting dims the stamina bar label.
local function bindStance(char)
	local stance
	local function update()
		local blocking = char:GetAttribute("Blocking")
		if blocking and not stance then
			stance = make("Highlight", { FillTransparency = 1, OutlineColor = Color3.fromRGB(120, 160, 255), OutlineTransparency = 0 }, char)
		elseif not blocking and stance then
			stance:Destroy()
			stance = nil
		end
	end
	char:GetAttributeChangedSignal("Blocking"):Connect(update)
	update()
end

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
	bindStance(char)
	bindBar(staminaFill, char, "Stamina", "MaxStamina")
	bindBar(postureFill, char, "Posture", "MaxPosture")
	bindBar(chargeFill, char, "Charge", "MaxCharge")
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

local SKILL_KEYS = { [Enum.KeyCode.R] = 1, [Enum.KeyCode.Y] = 2, [Enum.KeyCode.V] = 3 }
local TOGGLES = { [Enum.KeyCode.J] = statsPanel, [Enum.KeyCode.Tab] = invPanel, [Enum.KeyCode.L] = loadoutPanel, [Enum.KeyCode.N] = app, [Enum.KeyCode.O] = hidePanel }

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
	elseif key == Enum.KeyCode.F1 then
		controls.Visible = not controls.Visible
	elseif key == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(true)
	elseif key == Enum.KeyCode.G then
		local char = player.Character
		if char and char:GetAttribute("Holding") then
			chargeStart = os.clock()
		else
			local target = nearestGrabbable()
			if target then
				Remotes.Grab:FireServer(target)
			end
		end
	elseif key == Enum.KeyCode.H then
		Remotes.Drop:FireServer()
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
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(false)
	elseif input.KeyCode == Enum.KeyCode.G and chargeStart then
		local charge = math.clamp((os.clock() - chargeStart) / Config.Destruction.MaxChargeTime, 0, 1)
		chargeStart = nil
		Remotes.Throw:FireServer(cameraDirection(), charge)
	end
end)
