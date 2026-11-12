-- Input + HUD. The client only sends intent; the server decides what happens.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
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
local Weapons = require(Shared:WaitForChild("Weapons"))
local Joints = require(Shared:WaitForChild("Joints"))
local Swings = require(Shared:WaitForChild("Swings"))
local Anims = require(Shared:WaitForChild("Anims")) -- the game's own keyframed animations (tools/anims)
local Movement = require(script.Parent:WaitForChild("Movement"))
require(Shared:WaitForChild("Skin")).Start() -- one-piece bodies follow their limbs (shared/Skin.lua)
Movement.Start()
require(script.Parent:WaitForChild("Air")).Start() -- smog, clean air in the green pockets, the toxic tint
-- Sounds for combat events, played at the character they happened to.
local SOUND = { Hit = "HitFlesh", Block = "BlockThud", Parry = "HitClang", GuardBreak = "GuardBreak", Devour = "Devour", Flick = "FlickerTick" }
-- Sounds for props breaking, by prop id; anything else is metal. Chunks hitting the ground thud.
local BREAK_SOUND = { WindowPane = "BreakGlass", Crate = "BreakWood", Slab = "Collapse", Chunk = "ImpactDirt" }
-- the city never stops humming; the wind carries through the ruins
Sounds.Loop("AmbCity", 0.35)
Sounds.Loop("AmbWind", 0.2)

local Skills = require(Shared:WaitForChild("Skills"))

local player = Players.LocalPlayer

local function cameraDirection()
	return workspace.CurrentCamera.CFrame.LookVector
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "ConduitHUD", false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== Theme =====
-- The look lives in client/UI.lua (the kit every client module draws with).
local Kit = require(script.Parent:WaitForChild("UI"))
Kit.Init(gui)
local UI, corner, stroke, make, label = Kit.Theme, Kit.corner, Kit.stroke, Kit.make, Kit.label
local Stealth = require(script.Parent:WaitForChild("Stealth")) -- light meter, guard marks, takedowns, crouch (client/Stealth.lua)
local Intro = require(script.Parent:WaitForChild("Intro")) -- the train ride (client/Intro.lua)
local Handling = require(script.Parent:WaitForChild("Handling")) -- stances, aiming, reload, the wall (client/Handling.lua)

-- A safety net for everything built outside panel/addRow: buttons get the theme's shape, font and a hover;
-- opaque boxes get rounded corners. Callers' colours are kept.
local OLD_FONTS = { [Enum.Font.Legacy] = true, [Enum.Font.SourceSans] = true, [Enum.Font.Arial] = true, [Enum.Font.GothamMedium] = true, [Enum.Font.Gotham] = true }
gui.DescendantAdded:Connect(function(d)
	if d:IsA("TextButton") then
		d.AutoButtonColor = false
		if OLD_FONTS[d.Font] then
			d.Font = UI.Bold
		end
		corner(d, UI.Radius)
		local base
		d.MouseEnter:Connect(function()
			base = d.BackgroundColor3
			d.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15)
		end)
		d.MouseLeave:Connect(function()
			if base then
				d.BackgroundColor3 = base
			end
		end)
	elseif d:IsA("TextLabel") or d:IsA("TextBox") then
		if OLD_FONTS[d.Font] then
			d.Font = UI.Body
		end
	elseif (d:IsA("Frame") or d:IsA("ScrollingFrame")) and d.BackgroundTransparency < 0.6 and (d.Size.X.Offset >= 60 or d.Size.X.Scale >= 0.1) and d.Size.Y.Offset ~= 1 then
		corner(d, UI.Radius)
	end
end)

local function flash(char, color)
	if typeof(char) ~= "Instance" then
		return
	end
	local h = make("Highlight", { FillColor = color, FillTransparency = 0.4, OutlineTransparency = 1 }, char)
	task.delay(0.15, function()
		h:Destroy()
	end)
end

-- HUD v2 (ported from combat-feel): one composite at the bottom centre - a charge strip above, HEALTH | STAMINA
-- with numbers, a posture strip below, the skill slots under it. A bar's value label is kept in barValue[fill].
local HUD = Config.Hud
local BAR_W = HUD.BarWidth
local barValue = {}
local function bar(pos, size, color, name)
	-- flat track with a hairline edge; the fill has a bright leading edge and leaves a pale trail when it drops
	local back = make("Frame", { Size = size, Position = pos, BackgroundColor3 = UI.Panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true })
	corner(back, 1)
	stroke(back, UI.Line, 0.4)
	local trail = make("Frame", { Name = "Trail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Text, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, back)
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	corner(fill, 1)
	make("Frame", { Name = "Edge", Size = UDim2.new(0, 2, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55), BorderSizePixel = 0 }, fill)
	local shown, token = 1, 0
	fill:GetPropertyChangedSignal("Size"):Connect(function()
		local now = fill.Size.X.Scale
		token += 1
		local mine = token
		if now >= shown then
			trail.Size = UDim2.fromScale(now, 1)
		else
			task.delay(0.3, function()
				if mine == token then
					Kit.tween(trail, 0.35, { Size = UDim2.fromScale(now, 1) })
				end
			end)
		end
		shown = now
	end)
	if name then
		for q = 1, 3 do -- quarter notches
			make("Frame", { Size = UDim2.new(0, 1, 0, 4), Position = UDim2.new(q / 4, 0, 1, -4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3 }, back)
		end
		label({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(6, 0), Text = name, TextSize = 8, Font = UI.Title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.25, ZIndex = 2, Parent = back })
		barValue[fill] = label({ Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Text = "", TextSize = 11, Font = UI.Mono, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Text, ZIndex = 2, Parent = back })
		make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1 }, barValue[fill])
	end
	return fill
end
local half = BAR_W / 2 - 2
local chargeFill = bar(UDim2.new(0.5, -BAR_W / 2, 1, -126), UDim2.fromOffset(BAR_W, 3), UI.Accent)
local healthFill = bar(UDim2.new(0.5, -BAR_W / 2, 1, -120), UDim2.fromOffset(half, 14), UI.Harm, "HEALTH")
local staminaFill = bar(UDim2.new(0.5, 2, 1, -120), UDim2.fromOffset(half, 14), Color3.fromRGB(206, 212, 222), "STAMINA")
local postureFill = bar(UDim2.new(0.5, -BAR_W / 2, 1, -104), UDim2.fromOffset(BAR_W, 4), UI.Warn)
local levelLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0.5, -BAR_W / 2, 1, -146), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, Font = UI.Mono, TextColor3 = UI.Dim, Text = "" })
-- The vitals keep out of the way (owner, 2026-11-11: "the UI is very cluttered"): the whole block fades out
-- unless a bar moved in the last Config.Hud.VitalsHold seconds or health is under Config.Hud.VitalsLow.
local vitals = { changed = os.clock(), shown = true }
do
	local group = make("CanvasGroup", { Name = "Vitals", Size = UDim2.fromOffset(BAR_W + 8, 150), Position = UDim2.new(0.5, -BAR_W / 2 - 4, 1, -150), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 0 })
	vitals.group = group
	for _, fill in { chargeFill, healthFill, staminaFill, postureFill } do
		fill.Parent.Parent = group
		fill:GetPropertyChangedSignal("Size"):Connect(function()
			vitals.changed = os.clock()
		end)
	end
	levelLabel.Parent = group
	task.spawn(function()
		while true do
			local low = healthFill.Size.X.Scale < (HUD.VitalsLow or 0.6)
			local show = low or os.clock() - vitals.changed < (HUD.VitalsHold or 4)
			if show ~= vitals.shown then
				vitals.shown = show
				Kit.tween(group, if show then 0.12 else 0.6, { GroupTransparency = if show then 0 else 1 })
			end
			task.wait(0.2)
		end
	end)
end
local flickerLabel = label({ Size = UDim2.fromOffset(240, 18), Position = UDim2.new(0.5, 0, 1, -146), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, Font = UI.Title, Text = "", TextColor3 = UI.Harm })
pcall(function() -- our own health bar replaces Roblox's; no player list (Tab is the inventory)
	local StarterGui = game:GetService("StarterGui")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)
local banner = label({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 62), TextSize = 17, Font = UI.Title, Text = "", TextTransparency = 1 })
local bannerFx = {}
bannerFx.stroke = make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 1, Thickness = 1.5 }, banner)
bannerFx.rule = make("Frame", { Size = UDim2.fromOffset(0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), BackgroundColor3 = UI.Accent, BackgroundTransparency = 1, BorderSizePixel = 0 })
local questLabel = label({ Size = UDim2.fromOffset(360, 22), Position = UDim2.new(1, -380, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextSize = 13, Font = UI.Mono, TextColor3 = UI.Text })
make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.45, Thickness = 1 }, questLabel)

-- ===== Panels =====
-- A panel is a scrolling list inside a plate: the plate (hairline edge, corner ticks, a title strip) follows the
-- list wherever its owner puts it. While a panel is up the world behind it dims and softens.
local panel
do
local HEADER = 28
local dimmed = {}
local backdrop = make("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false })
local blur = make("BlurEffect", { Name = "MenuBlur", Size = 0 }, game:GetService("Lighting"))
local function refreshBackdrop()
	local on = false
	for frame in dimmed do
		if frame.Visible then
			on = true
		end
	end
	Kit.tween(backdrop, 0.18, { BackgroundTransparency = if on then 0.5 else 1 })
	Kit.tween(blur, 0.18, { Size = if on then 10 else 0 })
end
panel = function(size, position, title, plain)
	local chrome = Kit.plate({ Name = "Chrome", Visible = false })
	local head = label({ Size = UDim2.new(1, -24, 0, HEADER), Position = UDim2.fromOffset(12, 0), Text = Kit.spaced(title or "", 1), Font = UI.Title, TextSize = 10,
		TextColor3 = UI.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = chrome })
	head.Name = "Title"
	make("Frame", { Size = UDim2.new(1, -2, 0, 1), Position = UDim2.fromOffset(1, HEADER - 1), BackgroundColor3 = UI.Line, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, chrome)
	make("Frame", { Size = UDim2.fromOffset(3, 10), Position = UDim2.fromOffset(4, (HEADER - 10) / 2), BackgroundColor3 = UI.Accent, BorderSizePixel = 0 }, chrome)
	local frame = make("ScrollingFrame", {
		Size = size, Position = position, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = UI.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	local function follow()
		local at, extent, origin = frame.AbsolutePosition, frame.AbsoluteSize, gui.AbsolutePosition
		if typeof(at) == "Vector2" and typeof(extent) == "Vector2" and typeof(origin) == "Vector2" then
			chrome.Position = UDim2.fromOffset(at.X - origin.X, at.Y - origin.Y - HEADER)
			chrome.Size = UDim2.fromOffset(extent.X, extent.Y + HEADER)
		else
			chrome.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset - HEADER)
			chrome.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + HEADER)
		end
	end
	frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(follow)
	if not plain then
		dimmed[frame] = true
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		chrome.Visible = frame.Visible
		follow()
		if not plain then
			refreshBackdrop()
		end
	end)
	follow()
	return frame, head
end
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- buttons: { { text, fn, color? } }, laid out right-to-left. A row with no buttons whose text is all capitals
-- is a section header (title face, accent colour, a divider under it); everything else wraps instead of
-- being cut off.
local rowOrder = 0
local function addRow(frame, text, buttons, textColor)
	rowOrder += 1
	text = tostring(text or "")
	local letters = text:gsub("[^%a]", "")
	local header = #buttons == 0 and #letters >= 3 and letters == letters:upper()
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, if header then 24 else 28), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = rowOrder }, frame)
	local BW, GAP = 66, 6
	local width = #buttons * (BW + GAP)
	if header then
		local title = text:gsub("^%-%-%s*", ""):gsub("%s*%-%-$", "")
		label({ Size = UDim2.new(1, 0, 0, 20), Text = string.upper(title), Font = UI.Title, TextSize = 10, TextColor3 = textColor or UI.Dim,
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
		make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 2), BackgroundColor3 = UI.Line, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, row)
		make("Frame", { Size = UDim2.fromOffset(18, 1), Position = UDim2.new(0, 0, 1, 2), BackgroundColor3 = UI.Accent, BorderSizePixel = 0 }, row)
		return
	end
	label({ Size = UDim2.new(1, -width - 4, 0, 28), Text = text, TextColor3 = textColor or UI.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
	for i, b in buttons do
		local btn = make("TextButton", {
			Size = UDim2.fromOffset(BW, 24), Position = UDim2.new(1, -(BW + GAP) * (#buttons - i + 1) + GAP, 0, 2), Text = string.upper(b.text),
			BackgroundColor3 = b.color or UI.Button, TextColor3 = UI.Text, TextSize = 10, Font = UI.Bold,
		}, row)
		stroke(btn, if b.color then Color3.new(1, 1, 1) else UI.Accent, if b.color then 0.8 else 0.55)
		btn.Activated:Connect(b.fn)
	end
end

local statsPanel = panel(UDim2.fromOffset(280, 240), UDim2.fromOffset(20, 148), "Attributes")
local invPanel = panel(UDim2.fromOffset(380, 400), UDim2.new(0.5, -190, 0.5, -186), "Pack")
local loadoutPanel = panel(UDim2.fromOffset(420, 400), UDim2.new(1, -440, 0.5, -186), "Loadout")

-- ===== Announcements =====
local KIND_COLORS = {
	Emergence = UI.Harm, Event = UI.Warn,
	Kill = UI.Text, Info = UI.Accent, District = UI.Text,
}
local bannerToken = 0
local announce
do
local placeSeen = {} -- place name -> os.clock() its banner last showed (Config.Places.BannerCooldown)
announce = function(text, kind)
	if kind == "District" then
		-- a place names itself as you enter, then keeps quiet for a while: walking the border does not spam
		local place = tostring(text):match("^(.-)%s%s%-") or tostring(text)
		local last = placeSeen[place]
		if last and os.clock() - last < Config.Places.BannerCooldown then
			return
		end
		placeSeen[place] = os.clock()
	end
	bannerToken += 1
	local token = bannerToken
	-- the name comes up out of nothing over a rule that opens from the middle, and goes the same way
	local color = KIND_COLORS[kind] or UI.Text
	banner.Text, banner.TextColor3 = string.upper(tostring(text)), color
	bannerFx.rule.BackgroundColor3, bannerFx.rule.Size = color, UDim2.fromOffset(0, 1)
	Kit.tween(banner, 0.35, { TextTransparency = 0 })
	Kit.tween(bannerFx.stroke, 0.35, { Transparency = 0.35 })
	Kit.tween(bannerFx.rule, 0.5, { Size = UDim2.fromOffset(260, 1), BackgroundTransparency = 0.25 })
	task.delay(Config.Places.BannerSeconds, function()
		if token == bannerToken then
			Kit.tween(banner, 0.7, { TextTransparency = 1 })
			Kit.tween(bannerFx.stroke, 0.7, { Transparency = 1 })
			Kit.tween(bannerFx.rule, 0.7, { Size = UDim2.fromOffset(0, 1), BackgroundTransparency = 1 })
		end
	end)
end
end
Remotes.Announce.OnClientEvent:Connect(announce)

-- ===== Attributes (K) =====
do
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
	levelLabel.Text = ("LV %02d   %d / %d XP"):format(data.Level, data.Xp, data.XpNeeded)
end)
end

-- ===== Inventory / crafting (I) =====
local lastInventory, lastEquipped, lastArmor, lastCyber = {}, "Fists", {}, {}
local lastCondition, lastUpgrades = {}, {}

local lastGrid = { W = 5, H = 3, Items = {}, Pack = "", Weight = 0, Carry = 15 }
local CELL = 34
local TYPE_COLORS = {
	Material = Color3.fromRGB(46, 52, 62), Consumable = Color3.fromRGB(36, 74, 58), Ammo = Color3.fromRGB(30, 66, 86),
	Weapon = Color3.fromRGB(92, 58, 40), Armor = Color3.fromRGB(46, 54, 96), Cybernetic = Color3.fromRGB(80, 44, 100), Pack = Color3.fromRGB(78, 66, 40),
}
local gridHolder = make("Frame", { Size = UDim2.new(1, -8, 0, 10), BackgroundTransparency = 1, LayoutOrder = 1 }, invPanel)
local gridFrame = make("Frame", { Position = UDim2.fromOffset(4, 0), BackgroundColor3 = Color3.fromRGB(38, 44, 54), BorderSizePixel = 0 }, gridHolder)
local selected -- index of the stack whose actions are shown
local drag -- { index, rot, ghost, startPos, moved }
local iconFolder = ReplicatedStorage:FindFirstChild("Icons")
-- A 3D icon of the item in a ViewportFrame; stacks show up to three copies fanned out. nil if no model yet.
local function itemIcon(parent, itemId, count)
	iconFolder = iconFolder or ReplicatedStorage:FindFirstChild("Icons")
	local template = iconFolder and iconFolder:FindFirstChild(itemId)
	if not template then
		return nil
	end
	local view = make("ViewportFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Ambient = Color3.fromRGB(160, 160, 180), LightColor = Color3.fromRGB(255, 245, 230), LightDirection = Vector3.new(-1, -2, -1) }, parent)
	local world = Instance.new("WorldModel")
	world.Parent = view
	local copies = if count >= 10 then 3 elseif count >= 2 then 2 else 1
	local size
	for i = 1, copies do
		local model = template:Clone()
		model:PivotTo(CFrame.Angles(0, math.rad(-30), 0))
		local cf, bbox = model:GetBoundingBox()
		size = size or bbox
		local offset = Vector3.new((i - 1) * bbox.X * 0.25, (i - 1) * bbox.Y * 0.12, -(i - 1) * bbox.Z * 0.3)
		model:PivotTo(model:GetPivot() + (offset - cf.Position)) -- bounding-box centre on the offset
		model.Parent = world
	end
	local camera = Instance.new("Camera")
	local radius = math.max(size.X, size.Y, size.Z) * (0.9 + 0.15 * copies)
	camera.CFrame = CFrame.lookAt(Vector3.new(radius * 0.9, radius * 0.8, radius * 1.2), Vector3.new(size.X * 0.1 * (copies - 1), size.Y * 0.05, 0))
	camera.FieldOfView = 45
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end
local short = function(name)
	local words = name:split(" ")
	if #words == 1 then
		return name:sub(1, 6)
	end
	local s = ""
	for _, w in words do
		s ..= w:sub(1, 1)
	end
	return s
end
local renderInventory -- forward

local function cellAt(frame, screenPos)
	if not frame or not frame.Parent or not frame.Visible then
		return 0, 0, false
	end
	local rel = screenPos - frame.AbsolutePosition
	local x, y = math.floor(rel.X / CELL) + 1, math.floor(rel.Y / CELL) + 1
	return x, y, rel.X >= -CELL and rel.Y >= -CELL and rel.X <= frame.AbsoluteSize.X + CELL and rel.Y <= frame.AbsoluteSize.Y + CELL
end

-- Draws any grid ({ W, H, Items }) into `frame`. `source` tags the stacks for drag/drop ("pack" or "vault").
local vaultGridFrame -- the hideout panel's vault grid, when open
local containerGridFrame -- the open loot container's grid, when open
local container -- { key, grid, label }
local lastClick = { index = nil, source = nil, t = 0 }
local renderContainer -- defined with the container panel below
local marketPanel, renderMarket -- defined with the market panel below
local terminalPanel, renderTerminal -- the hideout computer
local hideout -- the last hideout snapshot (set by Remotes.Hideout)
-- Tooltip that follows the mouse over a block
local tooltip = make("TextLabel", { Size = UDim2.fromOffset(220, 44), BackgroundColor3 = UI.Panel, BackgroundTransparency = 0.06, TextColor3 = UI.Text, Font = UI.Body, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 60, BorderSizePixel = 0 }, gui)
make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, tooltip)
stroke(tooltip, UI.Accent, 0.55)
local function describe(item)
	local def = Items.Defs[item.Id]
	if not def then
		return item.Id
	end
	local shape = Items.Shape(item.Id)
	local line = ("%s  x%d\n%dx%d  %.1f kg each"):format(def.Name, item.Count, shape.Size[1], shape.Size[2], shape.Weight)
	if def.Type == "Weapon" or def.Type == "Armor" or def.Type == "Cybernetic" or def.Type == "Pack" then
		local cond, up = lastCondition[item.Id] or 100, lastUpgrades[item.Id] or 0
		line ..= ("  %d%%%s"):format(cond, if up > 0 then " +" .. up else "")
	end
	if def.Type == "Pack" and def.Grid then
		line ..= ("\ngrid %dx%d, carry %d"):format(def.Grid[1], def.Grid[2], def.Carry or 0)
	end
	local wdef = def.Type == "Weapon" and Weapons.Defs[item.Id]
	if wdef then
		-- frame data: the combo's first strike and the heavy (Weapons.frames)
		if wdef.Attacks and wdef.Attacks[1] then
			line ..= "\nlight  " .. Weapons.FrameLine(wdef.Attacks[1])
		end
		if wdef.Heavy then
			line ..= "\nheavy  " .. Weapons.FrameLine(wdef.Heavy)
		end
	end
	return line
end
-- cells of every drawn grid, so a drag can preview where it would land: [gridF] = { cells = {[y][x] = frame}, grid = grid }
local gridCells = setmetatable({}, { __mode = "k" })
local lastPreview = {}
local function clearPreview()
	for _, c in lastPreview do
		c.frame.BackgroundColor3 = c.color
	end
	table.clear(lastPreview)
end
local function preview(gridF, x, y, w, h, ok)
	clearPreview()
	local reg = gridCells[gridF]
	if not reg then
		return
	end
	for yy = y, y + h - 1 do
		for xx = x, x + w - 1 do
			local cell = reg.cells[yy] and reg.cells[yy][xx]
			if cell then
				table.insert(lastPreview, { frame = cell, color = cell.BackgroundColor3 })
				cell.BackgroundColor3 = if ok then Color3.fromRGB(50, 110, 70) else Color3.fromRGB(120, 50, 50)
			end
		end
	end
end
-- would a stack of footprint w x h fit at x, y in this grid, ignoring the dragged stack itself?
local function wouldFit(grid, skipIndex, skipSource, source, x, y, w, h)
	if x < 1 or y < 1 or x + w - 1 > grid.W or y + h - 1 > grid.H then
		return false
	end
	for i, other in grid.Items do
		if not (i == skipIndex and skipSource == source) then
			local ow, oh = Items.Footprint(other.Id, other.Rot)
			if x < other.X + ow and other.X < x + w and y < other.Y + oh and other.Y < y + h then
				-- merging onto the same item at its top-left is fine
				return other.Id == (drag and drag.item.Id) and other.X == x and other.Y == y
			end
		end
	end
	return true
end

local function drawGridInto(gridF, grid, source, holder)
	for _, c in gridF:GetChildren() do
		c:Destroy()
	end
	local W, H = grid.W, grid.H
	gridF.Size = UDim2.fromOffset(W * CELL, H * CELL)
	if holder then
		holder.Size = UDim2.new(1, -8, 0, H * CELL + 4)
	end
	local reg = { cells = {}, grid = grid, source = source }
	gridCells[gridF] = reg
	for y = 0, H - 1 do
		reg.cells[y + 1] = {}
		for x = 0, W - 1 do
			reg.cells[y + 1][x + 1] = make("Frame", { Size = UDim2.fromOffset(CELL - 2, CELL - 2), Position = UDim2.fromOffset(x * CELL + 1, y * CELL + 1), BackgroundColor3 = if source == "vault" then Color3.fromRGB(20, 18, 26) else Color3.fromRGB(13, 16, 21), BorderSizePixel = 0 }, gridF)
		end
	end
	for index, item in grid.Items do
		local def = Items.Defs[item.Id]
		local w, h = Items.Footprint(item.Id, item.Rot)
		if item.Hidden then
			-- not searched yet: a dark block with a question mark, nothing to drag
			local shade = make("Frame", { Size = UDim2.fromOffset(w * CELL - 4, h * CELL - 4), Position = UDim2.fromOffset((item.X - 1) * CELL + 2, (item.Y - 1) * CELL + 2), BackgroundColor3 = Color3.fromRGB(50, 46, 56), BorderSizePixel = 0 }, gridF)
			make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "?", TextColor3 = Color3.fromRGB(150, 140, 160), Font = Enum.Font.GothamBold, TextSize = 18 }, shade)
			continue
		end
		local cond = lastCondition[item.Id]
		local frame = make("TextButton", {
			Size = UDim2.fromOffset(w * CELL - 4, h * CELL - 4), Position = UDim2.fromOffset((item.X - 1) * CELL + 2, (item.Y - 1) * CELL + 2),
			BackgroundColor3 = TYPE_COLORS[def and def.Type] or Color3.fromRGB(90, 90, 90), BorderSizePixel = (source == "pack" and selected == index) and 2 or 0, BorderColor3 = UI.Accent,
			Text = "", AutoButtonColor = false,
		}, gridF)
		if not itemIcon(frame, item.Id, item.Count) then
			make("TextLabel", { Size = UDim2.new(1, -4, 1, -14), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Text = short(def and def.Name or item.Id), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, frame)
		end
		local tag = if item.Count > 1 then tostring(item.Count) elseif cond and cond < 100 then cond .. "%" else ""
		make("TextLabel", { Size = UDim2.new(1, -4, 0, 12), Position = UDim2.new(0, 2, 1, -14), BackgroundTransparency = 1, Text = tag, TextColor3 = if cond and cond <= 25 then Color3.fromRGB(255, 150, 120) else Color3.fromRGB(230, 230, 240), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right }, frame)
		if lastEquipped == item.Id or (def and def.Slot and (lastArmor[def.Slot] == item.Id or lastCyber[def.Slot] == item.Id)) then
			make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(120, 255, 200), BorderSizePixel = 0 }, frame)
		end
		frame.MouseEnter:Connect(function()
			if not drag then
				tooltip.Text = describe(item)
				tooltip.Visible = true
			end
		end)
		frame.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				-- double-click: quick-move to the obvious other grid
				if lastClick.index == index and lastClick.source == source and os.clock() - lastClick.t < 0.35 then
					lastClick.t = 0
					if source == "container" and container then
						Remotes.ContainerTake:FireServer(container.key, index)
					elseif source == "vault" then
						Remotes.VaultTake:FireServer(item.Id, item.Count)
					elseif source == "pack" and hideout and hideout.VaultGrid and hidePanel.Visible then
						Remotes.VaultPut:FireServer(item.Id, item.Count)
					end
					return
				end
				lastClick.index, lastClick.source, lastClick.t = index, source, os.clock()
				tooltip.Visible = false
				drag = { index = index, rot = item.Rot, startPos = input.Position, moved = false, size = Vector2.new(w, h), source = source, item = item }
				drag.ghost = make("Frame", { Size = UDim2.fromOffset(w * CELL - 4, h * CELL - 4), Position = UDim2.fromOffset(input.Position.X - 10, input.Position.Y - 10), BackgroundColor3 = frame.BackgroundColor3, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 50 }, gui)
				make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = short(def and def.Name or item.Id), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 51 }, drag.ghost)
			end
		end)
	end
end

local function endDrag(input)
	if not drag then
		return
	end
	local d = drag
	drag = nil
	clearPreview()
	if d.ghost then
		d.ghost:Destroy()
	end
	if not d.moved then
		if d.source == "pack" then
			selected = if selected == d.index then nil else d.index
			renderInventory()
		end
		return
	end
	local px, py, inPack = cellAt(gridFrame, input.Position)
	local vx, vy, inVault = cellAt(vaultGridFrame, input.Position)
	local item = d.item
	local w, h = Items.Footprint(item.Id, d.rot)
	if d.source == "pack" then
		if inPack then
			-- the ghost's top-left is what you drop; clamp into the grid so an edge drop still lands
			px, py = math.clamp(px, 1, math.max(1, lastGrid.W - w + 1)), math.clamp(py, 1, math.max(1, lastGrid.H - h + 1))
			Remotes.MoveItem:FireServer(d.index, px, py, d.rot)
		elseif inVault then
			Remotes.VaultPut:FireServer(item.Id, item.Count) -- into the vault: the server places it
		else
			Remotes.DropItem:FireServer(d.index)
		end
	elseif d.source == "container" then
		if inPack and container then
			Remotes.ContainerTake:FireServer(container.key, d.index)
		end
		-- anywhere else: it stays in the container
	else -- from the vault
		if inVault then
			local vg = hideout and hideout.VaultGrid
			if vg then
				vx, vy = math.clamp(vx, 1, math.max(1, vg.W - w + 1)), math.clamp(vy, 1, math.max(1, vg.H - h + 1))
			end
			Remotes.VaultMove:FireServer(d.index, vx, vy, d.rot)
		elseif inPack then
			Remotes.VaultTake:FireServer(item.Id, item.Count)
		end
		-- dropped anywhere else: nothing happens; the vault keeps it
	end
end
UserInputService.InputChanged:Connect(function(input)
	if drag and input.UserInputType == Enum.UserInputType.MouseMovement then
		if (input.Position - drag.startPos).Magnitude > 4 then
			drag.moved = true
		end
		local w, h = drag.size.X, drag.size.Y
		if drag.rot ~= drag.item.Rot then
			w, h = h, w
		end
		drag.ghost.Size = UDim2.fromOffset(w * CELL - 4, h * CELL - 4)
		drag.ghost.Position = UDim2.fromOffset(input.Position.X - CELL / 2, input.Position.Y - CELL / 2)
		-- preview: tint the cells under the ghost in the grid it is over
		local target, tx, ty
		for _, gf in { gridFrame, vaultGridFrame, containerGridFrame } do
			local x, y, inside = cellAt(gf, input.Position)
			if inside then
				target, tx, ty = gf, x, y
				break
			end
		end
		if target and gridCells[target] then
			local reg = gridCells[target]
			tx, ty = math.clamp(tx, 1, math.max(1, reg.grid.W - w + 1)), math.clamp(ty, 1, math.max(1, reg.grid.H - h + 1))
			local ok
			if reg.source == drag.source then
				ok = wouldFit(reg.grid, drag.index, drag.source, reg.source, tx, ty, w, h)
			else
				ok = not (drag.source == "container" and reg.source == "vault") and not (drag.source == "vault" and reg.source == "container") and reg.source ~= "container"
			end
			preview(target, tx, ty, w, h, ok)
		else
			clearPreview()
		end
	elseif not drag and input.UserInputType == Enum.UserInputType.MouseMovement and tooltip.Visible then
		tooltip.Position = UDim2.fromOffset(input.Position.X + 16, input.Position.Y + 12)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if drag and input.UserInputType == Enum.UserInputType.MouseButton1 then
		endDrag(input)
	end
end)

renderInventory = function()
	gridHolder.Parent = nil -- clear() would destroy it
	clear(invPanel)
	local wt = ("Weight %.1f / %d%s"):format(lastGrid.Weight or 0, lastGrid.Carry or 0, if (lastGrid.Weight or 0) > (lastGrid.Carry or 0) then "  OVERWEIGHT" else "")
	local packLevel = lastGrid.Pack ~= "" and (lastUpgrades[lastGrid.Pack] or 0) or 0
	local packName = if lastGrid.Pack ~= "" and Items.Defs[lastGrid.Pack] then Items.Defs[lastGrid.Pack].Name .. (if packLevel > 0 then " +" .. packLevel else "") else "pockets"
	local packButtons = { { text = "Sort", color = Color3.fromRGB(60, 100, 90), fn = function() Remotes.SortItems:FireServer() end } }
	if lastGrid.Pack ~= "" then
		table.insert(packButtons, { text = "Take off", color = Color3.fromRGB(120, 70, 70), fn = function() Remotes.Unequip:FireServer("Pack") end })
	end
	addRow(invPanel, ("%s  (%dx%d)  %s  -  drag to move, R rotates, drop outside to drop"):format(packName, lastGrid.W, lastGrid.H, wt), packButtons, if (lastGrid.Weight or 0) > (lastGrid.Carry or 0) then Color3.fromRGB(255, 150, 120) else nil)
	drawGridInto(gridFrame, lastGrid, "pack", gridHolder)
	gridHolder.Parent = invPanel
	local item = selected and lastGrid.Items[selected]
	if item then
		local id, def, buttons = item.Id, Items.Defs[item.Id], {}
		if def.Type == "Consumable" then
			table.insert(buttons, { text = if def.Throwable then "Throw" elseif def.Plantable then "Plant" else "Use", fn = function() Remotes.UseItem:FireServer(id, cameraDirection()) end })
		elseif def.Type == "Weapon" then
			local held = lastEquipped == id
			table.insert(buttons, { text = if held then "Unequip" else "Equip", color = if held then Color3.fromRGB(120, 70, 70) else nil, fn = function()
				if held then Remotes.Unequip:FireServer("Weapon") else Remotes.EquipItem:FireServer(id) end
			end })
		elseif def.Type == "Cybernetic" then
			-- ripped in or out at an Autonet only; arms and legs pick a side
			if player:GetAttribute("AtAutonet") then
				local slots = Cybernetics.SlotsFor(Cybernetics.Pieces[id])
				local paired = #slots > 1
				for _, slot in slots do
					local short = if paired then " " .. string.sub(Cybernetics.Label[slot], 1, 1) else ""
					if lastCyber[slot] == id then
						table.insert(buttons, { text = "Rip out" .. short, color = Color3.fromRGB(120, 40, 40), fn = function() Remotes.Autonet:FireServer("Out", slot) end })
					elseif Cybernetics.Fitted(lastCyber, id) < (lastInventory[id] or 0) then
						table.insert(buttons, { text = "Rip in" .. short, color = Color3.fromRGB(150, 50, 50), fn = function() Remotes.Autonet:FireServer("In", id, slot) end })
					end
				end
			end
		elseif def.Type == "Armor" then
			local worn = lastArmor[def.Slot] == id
			table.insert(buttons, { text = if worn then "Remove" else "Wear", color = if worn then Color3.fromRGB(120, 70, 70) else nil, fn = function()
				if worn then Remotes.Unequip:FireServer(def.Slot) else Remotes.EquipItem:FireServer(id) end
			end })
		elseif def.Type == "Pack" then
			table.insert(buttons, { text = "Wear", fn = function() Remotes.EquipItem:FireServer(id) end })
		end
		table.insert(buttons, { text = "Drop", color = Color3.fromRGB(120, 70, 70), fn = function() Remotes.DropItem:FireServer(selected) end })
		if item.Count > 1 then
			table.insert(buttons, { text = "Drop 1", color = Color3.fromRGB(100, 70, 70), fn = function() Remotes.DropItem:FireServer(selected, 1) end })
		end
		local shape = Items.Shape(id)
		local suffix = ("  %dx%d  %.1fkg each"):format(shape.Size[1], shape.Size[2], shape.Weight)
		if def.Type == "Cybernetic" then
			local where = {}
			for _, slot in Cybernetics.Slots do
				if lastCyber[slot] == id then
					table.insert(where, string.lower(Cybernetics.Label[slot]))
				end
			end
			suffix ..= if #where > 0 then "  in you (" .. table.concat(where, ", ") .. ")" elseif not player:GetAttribute("AtAutonet") then "  (ripped in at an Autonet)" else ""
		end
		if def.Type == "Weapon" or def.Type == "Armor" or def.Type == "Cybernetic" then
			local cond, up = lastCondition[id] or 100, lastUpgrades[id] or 0
			suffix ..= (" %d%%%s"):format(cond, if up > 0 then " +" .. up else "")
			if cond <= 0 then
				suffix ..= " BROKEN"
			end
		end
		addRow(invPanel, ("%s x%d%s"):format(def.Name, item.Count, suffix), buttons, if (lastCondition[id] or 100) <= 25 then Color3.fromRGB(255, 150, 120) else nil)
	else
		addRow(invPanel, "Click an item for actions.", {})
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
player:GetAttributeChangedSignal("AtAutonet"):Connect(function()
	renderInventory() -- the rip buttons appear at the table
	if player:GetAttribute("AtAutonet") then
		invPanel.Visible = true
	end
end)
Remotes.InventoryChanged.OnClientEvent:Connect(function(inv, equipped, armor, cyber, grid)
	lastInventory, lastEquipped, lastArmor, lastCyber = inv, equipped, armor, cyber
	if grid then
		lastGrid = grid
		if selected and not lastGrid.Items[selected] then
			selected = nil
		end
	end
	renderInventory()
end)

-- ===== The gun's count (bottom right, only with a gun out): rounds in the magazine, large; spare rounds, small =====
do
	local rounds = label({ Name = "Rounds", Size = UDim2.fromOffset(90, 34), Position = UDim2.new(1, -196, 1, -78), Text = "", Font = UI.Mono, TextSize = 30, TextColor3 = UI.Text, TextXAlignment = Enum.TextXAlignment.Right })
	local spare = label({ Name = "Spare", Size = UDim2.fromOffset(70, 18), Position = UDim2.new(1, -100, 1, -64), Text = "", Font = UI.Mono, TextSize = 13, TextColor3 = UI.Dim, TextXAlignment = Enum.TextXAlignment.Left })
	make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1 }, rounds)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1 }, spare)
	local function refresh()
		local char = player.Character
		local def = char and Weapons.Defs[char:GetAttribute("Weapon") or ""]
		local ammo = def and def.Ammo
		rounds.Visible, spare.Visible = ammo ~= nil, ammo ~= nil
		if ammo then
			local have = lastInventory and lastInventory[ammo] or 0
			local mag = char:GetAttribute("Mag")
			if type(mag) == "number" then
				rounds.Text, spare.Text = tostring(mag), "/ " .. math.max(have - mag, 0)
			else
				rounds.Text, spare.Text = tostring(have), ""
			end
			rounds.TextColor3 = if (if type(mag) == "number" then mag else have) <= 0 then UI.Harm else UI.Text
		end
	end
	local function bind(char)
		char:GetAttributeChangedSignal("Weapon"):Connect(refresh)
		char:GetAttributeChangedSignal("Mag"):Connect(refresh)
		refresh()
	end
	player.CharacterAdded:Connect(bind)
	if player.Character then
		bind(player.Character)
	end
	Remotes.InventoryChanged.OnClientEvent:Connect(function()
		task.defer(refresh)
	end)
end

-- ===== Loadout: derived stats, worn tags, skills (L) + hotbar =====
local loadout
local cooldowns = {} -- skillId -> os.clock() when ready
local hotbar = {}
local SLOT_KEYS = { "R", "Y", "V" }
for i = 1, Skills.SlotCount do
	-- a slot: the key in a cap, the skill's name, seconds left in mono; dim when it cannot be used
	local box = Kit.plate({ Size = UDim2.fromOffset(110, 34), Position = UDim2.new(0.5, -170 + (i - 1) * 116, 1, -90), BackgroundTransparency = 0.3 })
	local cap = make("TextLabel", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = UI.PanelAlt, BorderSizePixel = 0, Text = SLOT_KEYS[i], Font = UI.Bold, TextSize = 12, TextColor3 = UI.Text }, box)
	corner(cap, 2)
	local capStroke = make("UIStroke", { Color = UI.Accent, Transparency = 0.3, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cap)
	local name = label({ Size = UDim2.new(1, -62, 1, 0), Position = UDim2.fromOffset(34, 0), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = box })
	local time = label({ Size = UDim2.fromOffset(26, 34), Position = UDim2.new(1, -30, 0, 0), TextSize = 11, Font = UI.Mono, TextColor3 = UI.Warn, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = box })
	hotbar[i] = { name = name, time = time, cap = cap, stroke = capStroke, box = box }
end

local function renderHotbar()
	for i = 1, Skills.SlotCount do
		local slot = hotbar[i]
		local id = loadout and loadout.Slots[tostring(i)]
		local def = id and Skills.Defs[id]
		slot.box.Visible = def ~= nil -- an empty slot is not drawn
		if not def then
			slot.name.Text, slot.time.Text = "", ""
			slot.cap.TextColor3, slot.stroke.Color = UI.Faint, UI.Line
		else
			local ok = Skills.Unlocked(def, loadout.Stats, loadout.Tags)
			local remaining = (cooldowns[id] or 0) - os.clock()
			local ready = ok and remaining <= 0
			slot.name.Text = string.upper(def.Name)
			slot.time.Text = if not ok then "--" elseif remaining > 0 then ("%.0f"):format(remaining) else ""
			slot.name.TextColor3 = if ready then UI.Text else UI.Faint
			slot.cap.TextColor3 = if ready then UI.Text else UI.Dim
			slot.stroke.Color = if ready then UI.Accent else UI.Line
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
	addRow(loadoutPanel, ("-- Body: %d%% metal --"):format(math.floor((loadout.Conversion or 0) * 100 + 0.5)), {}, if (loadout.Conversion or 0) >= 1 then Color3.fromRGB(200, 220, 228) else nil)
	for _, slot in Cybernetics.Slots do
		local id = loadout.Cyber[slot]
		addRow(loadoutPanel, ("%s: %s"):format(Cybernetics.Label[slot], if id then Items.Defs[id].Name else "flesh"), {})
	end
	local senses = {}
	if (loadout.Hearing or 0) > 0 then table.insert(senses, ("hearing %d"):format(loadout.Hearing)) end
	if (loadout.Scent or 0) > 0 then table.insert(senses, ("scent %d%s"):format(loadout.Scent, if loadout.Track then " + tracks blood" else "")) end
	if (loadout.Lift or 0) > 0 then table.insert(senses, ("lift %d"):format(loadout.Lift)) end
	if (loadout.JumpMult or 1) ~= 1 then table.insert(senses, ("jump x%.2f"):format(loadout.JumpMult)) end
	if #senses > 0 then
		addRow(loadoutPanel, "Senses: " .. table.concat(senses, ", "), {})
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
	questLabel.Text = if title then ("> %s   %d/%d"):format(string.upper(title), progress, count) else ""
end)

-- ===== Death screen =====
local deathScreen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 10 })
do
local deathTitle = label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0.5, -90), Text = Kit.spaced("Flatline", 2), Font = UI.Title, TextSize = 34, TextColor3 = UI.Harm, ZIndex = 11, Parent = deathScreen })
local deathRule = make("Frame", { Size = UDim2.fromOffset(0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -30), BackgroundColor3 = UI.Harm, BorderSizePixel = 0, ZIndex = 11 }, deathScreen)
local deathText = label({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.5, -16), TextSize = 14, Font = UI.Mono, TextColor3 = UI.Dim, Text = "", ZIndex = 11, Parent = deathScreen })
local deathLine = label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.5, 62), TextSize = 15, Font = UI.Mono, TextColor3 = UI.Accent, Text = "", ZIndex = 11, Parent = deathScreen })
Remotes.Died.OnClientEvent:Connect(function(summary)
	local m, s = math.floor(summary.Survived / 60), summary.Survived % 60
	deathText.Text = ("%02d:%02d ALIVE     LV %d     %d KILLS%s"):format(m, s, summary.Level, summary.Kills, if summary.Killer then "\n\n" .. string.upper(tostring(summary.Killer)) else "")
	deathLine.Text = if summary.Uploaded then "> STACK RESIDENT . . . REBOOTING" else "> NO STACK . . . NO RECOVERY"
	deathScreen.BackgroundTransparency, deathRule.Size = 1, UDim2.fromOffset(0, 1)
	deathTitle.TextTransparency, deathText.TextTransparency, deathLine.TextTransparency = 1, 1, 1
	deathScreen.Visible = true
	Kit.tween(deathScreen, 0.6, { BackgroundTransparency = 0.12 })
	Kit.tween(deathTitle, 0.5, { TextTransparency = 0 })
	Kit.tween(deathRule, 0.8, { Size = UDim2.fromOffset(420, 1) })
	task.delay(0.5, function()
		Kit.tween(deathText, 0.5, { TextTransparency = 0 })
	end)
	task.delay(1.2, function()
		Kit.tween(deathLine, 0.5, { TextTransparency = 0 })
	end)
	task.delay(Config.RespawnDelay, function()
		deathScreen.Visible = false
	end)
end)
end

-- ===== Raid HUD =====
local raidLabel = label({ Size = UDim2.fromOffset(360, 44), Position = UDim2.new(1, -380, 0, 50), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Harm, Font = UI.Title, TextSize = 13, Text = "" })
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
local holdLabel = label({ Size = UDim2.fromOffset(360, 40), Position = UDim2.new(0.5, -180, 1, -120), TextSize = 12, Font = UI.Mono, TextColor3 = UI.Warn, Text = "" })
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

local floatWord, damageFlash, flashDamage, hitMarker, reticleActive
do
-- ===== Combat readout (ported from combat-feel's HudCombat): words over victims, reticle, damage vignette =====
local liveNumbers = 0
floatWord = function(char, text, color, big)
	local D = HUD.DamageNumbers
	local anchor = typeof(char) == "Instance" and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not anchor or liveNumbers >= D.MaxLive then
		return
	end
	local bb = make("BillboardGui", { Name = "DamageNumber", AlwaysOnTop = true, Size = UDim2.fromOffset(200, 50), MaxDistance = 80, Adornee = anchor,
		StudsOffsetWorldSpace = Vector3.new((math.random() * 2 - 1) * D.Spread, 1.5, (math.random() * 2 - 1) * D.Spread) }, anchor)
	local lbl = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = if big then D.HeavyTextSize else D.TextSize,
		TextColor3 = color, TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.new(0, 0, 0), Text = text }, bb)
	liveNumbers += 1
	Debris:AddItem(bb, D.Life)
	task.delay(D.Life, function()
		liveNumbers -= 1
	end)
	TweenService:Create(bb, TweenInfo.new(D.Life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, D.Rise, 0) }):Play()
	TweenService:Create(lbl, TweenInfo.new(D.Life * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, D.Life * 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end
-- red vignette when I take damage
damageFlash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HUD.DamageFlash.Color, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 })
make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0) }) }, damageFlash)
flashDamage = function(strength)
	local F = HUD.DamageFlash
	damageFlash.BackgroundTransparency = 1 - F.MaxTransparency * math.clamp(strength or 1, 0, 1)
	TweenService:Create(damageFlash, TweenInfo.new(F.Seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end
-- reticle: four ticks and a dot, shown while the stance steers the camera; it blinks when my hit lands
local reticle = make("Frame", { Name = "Reticle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false })
local reticleParts = {}
do
	local R = HUD.Reticle
	for _, d in { { Vector2.new(0, -1), UDim2.fromOffset(R.Thickness, R.Size) }, { Vector2.new(0, 1), UDim2.fromOffset(R.Thickness, R.Size) }, { Vector2.new(-1, 0), UDim2.fromOffset(R.Size, R.Thickness) }, { Vector2.new(1, 0), UDim2.fromOffset(R.Size, R.Thickness) } } do
		local tick = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = R.Color, Size = d[2] }, reticle)
		table.insert(reticleParts, { frame = tick, dir = d[1] })
	end
	table.insert(reticleParts, { frame = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(R.Thickness, R.Thickness), BorderSizePixel = 0, BackgroundColor3 = R.Color }, reticle) })
end
local reticleHitUntil = 0
hitMarker = function()
	reticleHitUntil = os.clock() + HUD.Reticle.HitSeconds
end
reticleActive = function() return false end -- rebound once the stance exists below
RunService.Heartbeat:Connect(function()
	reticle.Visible = reticleActive()
	if not reticle.Visible then
		return
	end
	local R = HUD.Reticle
	local left = reticleHitUntil - os.clock()
	local scale, color = 1, R.Color
	if left > 0 then
		local t = left / R.HitSeconds
		scale, color = 1 + (R.HitScale - 1) * t, R.HitColor:Lerp(R.Color, 1 - t)
	end
	local gap = ((if Handling.Aiming() then 1.5 else R.Gap) + R.Size / 2) * scale -- aiming draws it in tight
	for _, part in reticleParts do
		part.frame.BackgroundColor3 = color
		if part.dir then
			part.frame.Position = UDim2.fromOffset(part.dir.X * gap, part.dir.Y * gap)
		end
	end
end)

end
local shake, hitstop, impact, neon, fxSpawn, sparks, ring
local IMP = Config.Impacts
do
-- ===== Impact feel (ported from combat-feel): camera shake, FOV hitstop, sparks, rings, shards, ghosts =====
local trauma, shakeSeed = 0, math.random() * 100
local fovTween
shake = function(amount)
	if amount and amount > 0 then
		trauma = math.min(1, trauma + amount)
	end
end
hitstop = function(seconds)
	if not seconds or seconds <= 0 then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if fovTween then
		fovTween:Cancel()
	end
	local base = 70
	cam.FieldOfView = base + IMP.Camera.HitstopFov
	fovTween = TweenService:Create(cam, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
	fovTween:Play()
end
RunService:BindToRenderStep("EndeavorCameraShake", 201, function(dt) -- RenderPriority.Camera (200) + 1
	if trauma <= 0 then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t = os.clock() * IMP.Camera.ShakeFrequency
	local amp = trauma * trauma * IMP.Camera.ShakeMagnitude
	local offset = Vector3.new(math.noise(shakeSeed, t, 0) * 2 * amp, math.noise(shakeSeed + 10, t, 0) * 2 * amp, 0)
	cam.CFrame = cam.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.noise(shakeSeed + 20, t, 0) * 2 * amp * 0.05)
	trauma = math.max(0, trauma - dt / IMP.Camera.ShakeDecay)
end)
local fxFolder
fxSpawn = function(part, lifetime)
	if not fxFolder or not fxFolder.Parent then
		fxFolder = workspace:FindFirstChild("FX") or Instance.new("Folder")
		fxFolder.Name = "FX"
		fxFolder.Parent = workspace
	end
	if #fxFolder:GetChildren() >= IMP.MaxInstances then
		part:Destroy()
		return nil
	end
	part.Parent = fxFolder
	Debris:AddItem(part, lifetime)
	return part
end
neon = function(shape, size, color, cframe)
	local part = Instance.new("Part")
	part.Shape, part.Size, part.Color, part.Material, part.CFrame = shape, size, color, Enum.Material.Neon, cframe
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	return part
end
sparks = function(position, spec)
	if not spec then
		return
	end
	local anchor = neon(Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), spec.Color, CFrame.new(position))
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(spec.Life * 0.6, spec.Life)
	emitter.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag, emitter.Rate, emitter.Enabled = 4, 0, false
	emitter.Parent = anchor
	if fxSpawn(anchor, spec.Life + 0.1) then
		emitter:Emit(spec.Count)
	end
end
ring = function(position, spec)
	local part = neon(Enum.PartType.Cylinder, Vector3.new(0.15, 1, 1), spec.Color, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
	if fxSpawn(part, spec.Life + 0.05) then
		TweenService:Create(part, TweenInfo.new(spec.Life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, spec.Size, spec.Size), Transparency = 1 }):Play()
	end
end
local function shards(position, spec)
	for _ = 1, spec.Count do
		local shard = neon(Enum.PartType.Block, Vector3.new(spec.Size, spec.Size * 0.4, spec.Size * 0.6), spec.Color, CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0))
		shard.Anchored, shard.Massless = false, true
		if fxSpawn(shard, spec.Life) then
			shard.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit * spec.Speed
			TweenService:Create(shard, TweenInfo.new(spec.Life), { Transparency = 1 }):Play()
		end
	end
end
local function ghost(char, seconds, color)
	if typeof(char) ~= "Instance" then
		return
	end
	for _, part in char:GetChildren() do
		-- a skinned body's limbs are invisible stand-ins (attribute Proxy): they still give the ghost its shape
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and (part.Transparency < 1 or part:GetAttribute("Proxy")) then
			local copy = Instance.new("Part")
			copy.Size, copy.CFrame, copy.Color, copy.Material, copy.Transparency = part.Size, part.CFrame, color, Enum.Material.ForceField, 0.4
			copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch = true, false, false, false
			if fxSpawn(copy, seconds) then
				TweenService:Create(copy, TweenInfo.new(seconds), { Transparency = 1 }):Play()
			end
		end
	end
end
local function torsoOf(char)
	return typeof(char) == "Instance" and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
end
local function involvesMe(a, b)
	local me = player.Character
	return me ~= nil and (a == me or b == me)
end
-- the feel for an event on `victim`: effects for everyone, shake and hitstop only when I am in it
impact = function(kind, victim, attacker, heavy)
	local spec = IMP[kind]
	if not spec then
		return
	end
	local torso = torsoOf(victim)
	if torso then
		local front = torso.Position + torso.CFrame.LookVector * 1.5
		if kind == "Hit" then
			sparks(torso.Position, spec.Sparks)
		elseif kind == "Block" then
			sparks(front, spec.Sparks)
		elseif kind == "Parry" then
			sparks(front, spec.Sparks)
			ring(front, spec.Ring)
		elseif kind == "GuardBreak" then
			shards(torso.Position + torso.CFrame.LookVector * 1.2, spec.Shards)
		elseif kind == "Dodged" then
			ghost(victim, spec.Ghost, spec.Color)
		end
	end
	if involvesMe(victim, attacker) then
		shake((spec.Shake or 0) * (if heavy then IMP.HeavyShakeMult else 1))
		hitstop((spec.Hitstop or 0) * (if heavy then IMP.HeavyHitstopMult else 1))
	end
end

end
local function explosionFx(origin, radius)
	Sounds.Play("Explosion", origin)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local d = (root.Position - origin).Magnitude
		if d < IMP.Explosion.Radius then
			shake(IMP.Explosion.Shake * (1 - d / IMP.Explosion.Radius))
		end
	end
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
-- Marked places (director drops, landmarks, route, sites): see setMarker.
local markers = {}
-- ===== clues: anomalies flicker, fragments you cannot read yet are hidden =====
local visibleClues = nil -- nil = nothing known yet (show everything); set by World "Clues"
local function applyClueVisibility()
	local folder = workspace:FindFirstChild("Clues")
	if not folder then
		return
	end
	for _, part in folder:GetChildren() do
		local id = part:GetAttribute("FragmentId")
		local hidden = visibleClues ~= nil and id ~= nil and not visibleClues[id]
		part.LocalTransparencyModifier = if hidden then 1 else 0
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not hidden
		end
	end
end
task.spawn(function()
	-- a glitching cube, a flickering silhouette, a sign that reads wrong: all of them stutter in and out
	local rng = Random.new()
	while true do
		task.wait(0.12)
		for _, part in CollectionService:GetTagged("Anomaly") do
			if part.Parent and part.LocalTransparencyModifier < 1 then
				local kind = part:GetAttribute("Kind")
				local base = if kind == "Echo" then 0.35 elseif kind == "Wrong" then 0.2 else 0.5
				part.Transparency = math.clamp(base + rng:NextNumber(-0.3, 0.4), 0, 0.95)
				if kind == "Static" and rng:NextNumber() < 0.2 then
					part.CFrame = part.CFrame * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.4, 0.4), 0)
				end
			end
		end
	end
end)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Clues" then
		child.ChildAdded:Connect(function()
			task.defer(applyClueVisibility)
		end)
	end
end)

-- Markers are places, not beacons: nothing is drawn through the world. A marked place names itself in the
-- top banner when you come within Config.Places.EnterRadius, at most once per BannerCooldown per name.
local function setMarker(key, position, label, seconds, color)
	if not position then
		markers[key] = nil
		return
	end
	local m = { label = label or key, position = position }
	markers[key] = m
	if seconds then
		task.delay(seconds, function()
			if markers[key] == m then
				markers[key] = nil
			end
		end)
	end
end
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, m in markers do
				local near = (m.position - root.Position).Magnitude <= Config.Places.EnterRadius
				if near and not m.inside then
					announce(m.label, "District")
				end
				m.inside = near
			end
		end
	end
end)

Remotes.World.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if Stealth.World(kind, a, b, c, d, e) then
		return
	end
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
	elseif kind == "Container" and typeof(a) == "string" and type(b) == "table" then
		container = { key = a, grid = b, label = tostring(c) }
		renderContainer()
	elseif kind == "ContainerClose" and container and container.key == a then
		container = nil
		renderContainer()
	elseif kind == "Market" and type(a) == "table" then
		renderMarket(a)
		marketPanel.Visible = true
	elseif kind == "MarketClose" then
		marketPanel.Visible = false
	elseif kind == "Terminal" and type(a) == "table" then
		renderTerminal(a)
		terminalPanel.Visible = true
	elseif kind == "TerminalClose" then
		terminalPanel.Visible = false
	elseif kind == "Marker" and typeof(a) == "string" then
		setMarker(a, b, c, d, e)
	elseif kind == "MarkerClear" and typeof(a) == "string" then
		setMarker(a, nil)
	elseif kind == "Bark" and typeof(a) == "Instance" then
		local name = "Bark" .. tostring(b) .. tostring(c)
		Sounds.Play(if Sounds.Ids[name] then name else "BarkRaider" .. tostring(c), a) -- anyone without a voice of their own borrows the raider's
	elseif kind == "Blackout" then
		-- the grid is down: the sky goes near-black, neon is all that's left; restored after `a` seconds
		local seconds = tonumber(a) or 60
		local before = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
		TweenService:Create(Lighting, TweenInfo.new(2), { Brightness = 0.05, Ambient = Color3.fromRGB(8, 6, 14), OutdoorAmbient = Color3.fromRGB(10, 8, 18) }):Play()
		task.delay(seconds, function()
			TweenService:Create(Lighting, TweenInfo.new(4), before):Play()
		end)
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
	elseif kind == "Flicker" then
		-- the last seconds before the reset: colour drains, the world hums. Inside a green pocket nothing drains:
		-- the pockets stand outside the hour (the reset passes them by; server/Cycle.lua spares what lies there)
		local inPocket = player.Character and player.Character:GetAttribute("Pocket") ~= nil
		local cc = make("ColorCorrectionEffect", { Saturation = 0, Contrast = 0 }, Lighting)
		TweenService:Create(cc, TweenInfo.new(tonumber(a) or 5), if inPocket then { Saturation = 0.15, Contrast = 0.05 } else { Saturation = -0.9, Contrast = 0.3 }):Play()
		task.delay((tonumber(a) or 5) + 1.5, function()
			cc:Destroy()
		end)
	elseif kind == "Dematerialize" then
		-- a second of white, then the world is back as it was. In a green pocket the white only grazes the edges
		local inPocket = player.Character and player.Character:GetAttribute("Pocket") ~= nil
		local white = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 50 }, gui)
		TweenService:Create(white, TweenInfo.new(0.15), { BackgroundTransparency = if inPocket then 0.85 else 0 }):Play()
		task.delay(tonumber(a) or 1, function()
			TweenService:Create(white, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			task.delay(1, function()
				white:Destroy()
			end)
		end)
	elseif kind == "Consigned" and typeof(a) == "Vector3" then
		Sounds.Play("Unlatch", a) -- the crates open; the computer stands where they were
	elseif kind == "Clues" and type(a) == "table" then
		-- which fragments this conduit may see; the rest are hidden locally until the prerequisites are read
		visibleClues = {}
		for _, id in a do
			visibleClues[id] = true
		end
		applyClueVisibility()
	elseif kind == "Fragment" and typeof(a) == "string" then
		-- read: the text lingers on screen longer than a banner would
		local card = make("TextLabel", { Size = UDim2.new(0, 520, 0, 90), Position = UDim2.new(0.5, -260, 0.72, 0), BackgroundColor3 = Color3.fromRGB(10, 12, 20), BackgroundTransparency = 0.2,
			Text = tostring(b) .. "\n" .. tostring(c), TextColor3 = Color3.fromRGB(210, 220, 255), TextWrapped = true, TextSize = 15, Font = Enum.Font.Code, ZIndex = 20 }, gui)
		task.delay(12, function()
			card:Destroy()
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

-- ===== Helmetcam (P): first person, forearms and weapon in view =====
local helmetcam = false
local savedZoom = { min = 0.5, max = 128 }
local function setHelmetcam(on)
	if helmetcam == on then
		return
	end
	helmetcam = on
	task.defer(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = if on or not Config.Aim.DefaultOn then Vector3.zero else hum.CameraOffset
		end
	end)
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
-- Roblox hides the whole body in first person; only the forearms, hands and what they hold come back, so the view
-- stays clear (the full body used to fill it).
RunService.RenderStepped:Connect(function()
	if not helmetcam then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.LocalTransparencyModifier = if p.Name:find("LowerArm") or p.Name:find("Hand") then 0 else 1
		elseif p:IsA("Accessory") then
			local handle = p:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 1
			end
		elseif p.Name == "Skin" then
			-- the one-piece body: its forearm and hand pieces are separate meshes for exactly this
			for _, m in p:GetChildren() do
				if m:IsA("BasePart") then
					m.LocalTransparencyModifier = if m.Name:find("LowerArm") or m.Name:find("Hand") then 0 else 1
				end
			end
		end
	end
end)

Stealth.Init(gui)
Intro.Init({ Hud = gui, SetFirstPerson = setHelmetcam })
Handling.Init({ SetFirstPerson = setHelmetcam, FirstPerson = function() return helmetcam end })

-- ===== Neural Net uplink (tapping into the Front) =====
local uplinkFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20 })
local uplinkText = label({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 30, Font = Enum.Font.Code, TextColor3 = Color3.fromRGB(170, 90, 255), ZIndex = 21, Parent = uplinkFrame })
Remotes.Uplink.OnClientEvent:Connect(function(phase, seconds, faction)
	if phase == "Begin" then
		announce("> LINK: RECRUIT STACK . . . OK", "Info")
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
local app = panel(UDim2.fromOffset(520, 440), UDim2.new(0.5, -260, 0.5, -206), "Neural Net")
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
local hidePanel = panel(UDim2.fromOffset(560, 460), UDim2.new(0.5, -280, 0.5, -216), "Hideout")

-- Loot containers: searching a crate, stash or corpse opens its grid here; drag out or Take all.
local containerPanel = panel(UDim2.fromOffset(280, 300), UDim2.new(0.5, -480, 0.5, -136), "Container")

-- ===== Verdant Market (the Reach's trader; World "Market" / "MarketClose", Remotes.Buy) =====
marketPanel = panel(UDim2.fromOffset(340, 360), UDim2.new(1, -360, 0.5, -166), "Market")
renderMarket = function(m)
	clear(marketPanel)
	addRow(marketPanel, ("VERDANT MARKET  -  %d credits"):format(m.Credits or 0), {}, Color3.fromRGB(170, 255, 170))
	addRow(marketPanel, "Paid in war credits: the Front's pay buys the Reach's wares", {}, Color3.fromRGB(150, 150, 160))
	for _, item in m.Stock or {} do
		local name = if (item.Count or 1) > 1 then ("%s x%d"):format(item.Name, item.Count) else item.Name
		addRow(marketPanel, ("%s - %d cr"):format(name, item.Price), { { text = "Buy", color = Color3.fromRGB(50, 110, 70), fn = function() Remotes.Buy:FireServer(item.Id) end } }, if item.Price > (m.Credits or 0) then Color3.fromRGB(150, 150, 160) else nil)
	end
	addRow(marketPanel, "", { { text = "Close", color = Color3.fromRGB(90, 50, 50), fn = function() marketPanel.Visible = false end } })
end

-- ===== the hideout computer (World "Terminal" / "TerminalClose", Remotes.Terminal) =====
terminalPanel = panel(UDim2.fromOffset(560, 470), UDim2.new(0.5, -280, 0.5, -221), "Terminal")
local GREEN = Color3.fromRGB(80, 230, 140)
local DIM = Color3.fromRGB(150, 150, 160)
renderTerminal = function(t)
	clear(terminalPanel)
	local function send(action, arg)
		return function() Remotes.Terminal:FireServer(action, arg) end
	end
	addRow(terminalPanel, ("HIDEOUT COMPUTER  -  %d credits  -  %d contracts done"):format(t.Credits or 0, t.Completed or 0), { { text = "Log out", color = Color3.fromRGB(90, 50, 50), fn = send("Close") } }, GREEN)
	addRow(terminalPanel, if t.Uploaded then "> STACK: RESIDENT" else "> STACK: NONE", {}, DIM)
	-- RAIDS
	if not t.Apps.RAIDS then
		addRow(terminalPanel, "RAIDS  -  locked: " .. (t.Locked.RAIDS or ""), {}, DIM)
	else
		local active = 0
		for _, c in t.Contracts do if c.Active then active += 1 end end
		addRow(terminalPanel, ("RAIDS  -  contracts on the board (%d/%d held)"):format(active, t.MaxActive or 2), {}, GREEN)
		for _, c in t.Contracts do
			if c.Active then
				addRow(terminalPanel, ("  %s  -  %d/%d  -  %d cr"):format(c.Title, c.Done, c.Need, c.Credits), { { text = "Drop", color = Color3.fromRGB(110, 60, 40), fn = send("Abandon", c.Id) } }, Color3.fromRGB(255, 210, 120))
			else
				addRow(terminalPanel, ("  %s  -  %s  -  %d cr"):format(c.Title, c.Danger, c.Credits), { { text = "Accept", color = Color3.fromRGB(50, 110, 70), fn = send("Accept", c.Id) } })
			end
		end
	end
	-- HOUSE
	if not t.Apps.HOUSE then
		addRow(terminalPanel, "HOUSE  -  locked: " .. (t.Locked.HOUSE or ""), {}, DIM)
	else
		addRow(terminalPanel, "HOUSE  -  materials for the hideout, delivered to your pack", {}, GREEN)
		for _, h in t.House do
			addRow(terminalPanel, ("  %s  -  %d cr"):format(h.Name, h.Price), { { text = "Order", color = Color3.fromRGB(50, 110, 70), fn = send("Order", h.Id) } }, if h.Price > (t.Credits or 0) then DIM else nil)
		end
	end
	-- ARCHIVE: what you have read; it needs no contact, only eyes
	addRow(terminalPanel, ("ARCHIVE  -  %d fragments read"):format(#(t.Archive or {})), {}, GREEN)
	for _, f in t.Archive or {} do
		addRow(terminalPanel, ("  %s: %s"):format(f.Name, f.Text), {}, Color3.fromRGB(210, 220, 255))
	end
	-- MARKET
	if not t.Apps.MARKET then
		addRow(terminalPanel, "MARKET  -  locked: " .. (t.Locked.MARKET or ""), {}, DIM)
	else
		addRow(terminalPanel, "MARKET  -  the black market", {}, GREEN)
		for _, m in t.Market do
			addRow(terminalPanel, ("  %s  -  %d cr"):format(m.Name, m.Price), { { text = "Buy", color = Color3.fromRGB(50, 110, 70), fn = send("Buy", m.Id) } }, if m.Price > (t.Credits or 0) then DIM else nil)
		end
	end
end
renderContainer = function()
	clear(containerPanel)
	containerGridFrame = nil
	if not container then
		containerPanel.Visible = false
		return
	end
	local g = container.grid
	local status = if g.Searching then ("searching %d/%d"):format(g.Revealed or 0, g.Total or 0) elseif (g.Revealed or 0) < (g.Total or 0) then ("%d/%d found - stay close to keep searching"):format(g.Revealed or 0, g.Total or 0) else ("%.1f kg"):format(g.Weight or 0)
	addRow(containerPanel, ("%s  (%s)"):format(container.label, status), { { text = "Take all", fn = function() Remotes.ContainerTake:FireServer(container.key, 0) end },
		{ text = "Close", color = Color3.fromRGB(90, 90, 100), fn = function() container = nil; renderContainer() end } })
	local holder = make("Frame", { Size = UDim2.new(1, -8, 0, container.grid.H * CELL + 4), BackgroundTransparency = 1 }, containerPanel)
	containerGridFrame = make("Frame", { Position = UDim2.fromOffset(4, 0), BackgroundColor3 = Color3.fromRGB(30, 26, 22), BorderSizePixel = 0 }, holder)
	drawGridInto(containerGridFrame, container.grid, "container", holder)
	addRow(containerPanel, "Drag into your pack (Tab), or double-click.", {})
	containerPanel.Visible = true
	invPanel.Visible = true -- you need to see where it goes
end

-- F2: dev tools (only when Config.Dev.Enabled; the server refuses everything otherwise)
-- It fills the screen height below its top (20 px margin, at most 560 tall) and scrolls, so the last rows stay reachable
-- on a short window; the wider scroll bar shows there is more below.
local devPanel = panel(UDim2.new(0, 420, 1, -168), UDim2.new(1, -440, 0, 148), "Dev", true)
devPanel.ScrollBarThickness = 6
make("UISizeConstraint", { MaxSize = Vector2.new(420, 560) }, devPanel)
local function buildDevPanel()
	clear(devPanel)
	local function dev(action, arg)
		return function()
			Remotes.Dev:FireServer(action, arg)
		end
	end
	addRow(devPanel, "DEV TOOLS (F2)", {}, Color3.fromRGB(255, 80, 220))
	addRow(devPanel, "Me", { { text = "Heal", fn = dev("Heal") }, { text = "Mats", fn = dev("Materials") }, { text = "Die", fn = dev("Kill"), color = Color3.fromRGB(140, 40, 40) } })
	addRow(devPanel, "World", { { text = "Open", fn = dev("Open") } })
	addRow(devPanel, "Train intro", { { text = "Replay", fn = dev("Intro") }, { text = "Leave", fn = dev("Intro", "Skip") } })
	addRow(devPanel, "Go to", { { text = "Armory", fn = dev("Teleport", "Armory") }, { text = "Gate", fn = dev("Teleport", "RaidGate") } })
	for _, d in { "Transit Hub", "Corp Plaza", "The Sprawl", "Blackout Zone" } do
		addRow(devPanel, d, { { text = "Go", fn = dev("Teleport", "District_" .. d) }, { text = "Net", fn = dev("Teleport", "Terminal_" .. d) } })
	end
	addRow(devPanel, "North", { { text = "Scarp", fn = dev("Teleport", "Scarp") }, { text = "Hairpin", fn = dev("Teleport", "Frontier_Hairpin") }, { text = "Reach", fn = dev("Teleport", "Reach") } })
	addRow(devPanel, "Sites", { { text = "Ridge", fn = dev("Teleport", "Frontier_RidgeWatch") }, { text = "Mast", fn = dev("Teleport", "Frontier_SignalMast") }, { text = "Mine", fn = dev("Teleport", "Frontier_OldMine") }, { text = "Ship", fn = dev("Teleport", "Frontier_Dropship") } })
	addRow(devPanel, "Hideout sites", { { text = "1", fn = dev("Teleport", "Site_1") }, { text = "2", fn = dev("Teleport", "Site_2") }, { text = "3", fn = dev("Teleport", "Site_3") } })
	addRow(devPanel, "Spawn", { { text = "Raider", fn = dev("Spawn", "Raider") }, { text = "Brute", fn = dev("Spawn", "Brute") }, { text = "Shock", fn = dev("Spawn", "Shocker") }, { text = "Warden", fn = dev("Spawn", "Warden") } })
	addRow(devPanel, "Event", { { text = "Drop", fn = dev("Event", "SupplyDrop") }, { text = "Ambush", fn = dev("Event", "RaiderAmbush") }, { text = "Dark", fn = dev("Event", "Blackout") } })
	addRow(devPanel, "Event", { { text = "Warden", fn = dev("Event", "WardenPatrol") }, { text = "Salvage", fn = dev("Event", "SalvageCache") }, { text = "Drop2", fn = dev("Event", "DeadDrop") } })
	addRow(devPanel, "Cycle", { { text = "Run now", fn = dev("Cycle") } })
end
if Config.Dev.Enabled then
	buildDevPanel()
end
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
		if h.Modules and h.Modules[id] and def.Levels and tonumber(h.Modules[id]) and tonumber(h.Modules[id]) < def.Levels then
			-- leveled module: show the level and let the owner build the next one
			local lvl = tonumber(h.Modules[id])
			addRow(hidePanel, ("%s  level %d/%d - %s  [%s]"):format(def.Name, lvl, def.Levels, def.Desc, costText(def.Cost)), if h.Owned then { { text = "Level up", fn = function() Remotes.HideoutBuild:FireServer(id) end } } else {}, Color3.fromRGB(140, 220, 160))
		elseif h.Modules and h.Modules[id] then
			addRow(hidePanel, def.Name .. (if def.Levels then ("  (level %d, max)"):format(tonumber(h.Modules[id]) or def.Levels) else "  (built)"), {}, Color3.fromRGB(140, 220, 160))
		elseif h.Owned then
			addRow(hidePanel, ("%s - %s  [%s, tier %d]"):format(def.Name, def.Desc, costText(def.Cost), def.Tier), { { text = "Build", fn = function() Remotes.HideoutBuild:FireServer(id) end } }, if def.Tier > (h.Tier or 1) then Color3.fromRGB(140, 140, 140) else nil)
		end
	end
	addRow(hidePanel, "-- BENCH: repair and upgrade what you carry --", {})
	if lastGrid.Pack ~= "" and Items.Defs[lastGrid.Pack] then
		-- the worn pack: upgrade it at the bench for an extra row and carry per level
		local up = lastUpgrades[lastGrid.Pack] or 0
		addRow(hidePanel, ("%s (worn)  +%d  -  each level adds a row and 5 carry"):format(Items.Defs[lastGrid.Pack].Name, up), if up < 3 then { { text = ("+%d"):format(up + 1), color = Color3.fromRGB(60, 110, 80), fn = function() Remotes.ItemUpgrade:FireServer(lastGrid.Pack) end } } else {})
	end
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
		addRow(hidePanel, ("-- VAULT --  %dx%d grid  (drag between your pack and the vault; R rotates)"):format(h.VaultGrid and h.VaultGrid.W or 0, h.VaultGrid and h.VaultGrid.H or 0), {})
		if h.VaultGrid then
			local holder = make("Frame", { Size = UDim2.new(1, -8, 0, h.VaultGrid.H * CELL + 4), BackgroundTransparency = 1 }, hidePanel)
			vaultGridFrame = make("Frame", { Position = UDim2.fromOffset(4, 0), BackgroundColor3 = Color3.fromRGB(28, 22, 34), BorderSizePixel = 0 }, holder)
			drawGridInto(vaultGridFrame, h.VaultGrid, "vault", holder)
		end
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

-- ===== Controls card (F1 toggles; shown for the first two minutes) =====
local controls = Kit.plate({ Name = "Controls", Size = UDim2.fromOffset(336, 252), Position = UDim2.new(1, -356, 1, -282), BackgroundTransparency = 0.2 })
do
	label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(12, 2), Text = Kit.spaced("Controls", 1), Font = UI.Title, TextSize = 10, TextColor3 = UI.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = controls })
	label({ Size = UDim2.fromOffset(60, 24), Position = UDim2.new(1, -70, 0, 2), Text = "F1", Font = UI.Mono, TextSize = 11, TextColor3 = UI.Faint, TextXAlignment = Enum.TextXAlignment.Right, Parent = controls })
	make("Frame", { Size = UDim2.new(1, -2, 0, 1), Position = UDim2.fromOffset(1, 26), BackgroundColor3 = UI.Line, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, controls)
	local KEYS = {
		{ "LMB", "attack" }, { "RMB", "heavy" }, { "F", "guard" }, { "E", "flicker" }, { "Q", "dodge" }, { "Z", "feint" },
		{ "SHIFT", "sprint" }, { "C", "crouch / prone" }, { "X", "use / hands" }, { "B", "whistle" }, { "R Y V", "skills" }, { "G", "grab, throw" },
		{ "H", "drop" }, { "M", "devour" }, { "TAB", "pack" }, { "L", "loadout" }, { "J", "attributes" }, { "O", "hideout" },
		{ "N", "net" }, { "P", "helmetcam" },
		{ "GUN RMB", "aim" }, { "GUN V", "sights" }, { "GUN R", "reload" }, { "GUN Q", "wall" },
	}
	for i, pair in KEYS do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local x, y = 12 + col * 162, 32 + row * 18
		label({ Size = UDim2.fromOffset(66, 18), Position = UDim2.fromOffset(x, y), Text = pair[1], Font = UI.Mono, TextSize = 11, TextColor3 = UI.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = controls })
		label({ Size = UDim2.fromOffset(94, 18), Position = UDim2.fromOffset(x + 66, y), Text = pair[2], TextSize = 13, TextColor3 = UI.Dim, TextXAlignment = Enum.TextXAlignment.Left, Parent = controls })
	end
end
-- Not in the station (nothing is explained there), and the quest line waits with it.
controls.Visible = false
task.spawn(function()
	local shownAt
	while true do
		local station = player:GetAttribute("Stealth") == true or Intro.Active()
		questLabel.Visible = not station
		if station then
			if shownAt and os.clock() - shownAt < 60 then
				controls.Visible = false
			end
		elseif not shownAt and player.Character then
			task.wait(4) -- a spawn into the station sets the attribute a moment after the character appears
			if player:GetAttribute("Stealth") ~= true and not Intro.Active() then
				shownAt = os.clock()
				controls.Visible = true
				task.delay(60, function()
					controls.Visible = false
				end)
			end
		end
		task.wait(1)
	end
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
		shake(IMP.BlackFlash.Shake)
		hitstop(IMP.BlackFlash.Hitstop)
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

-- Procedural animation: joint offsets tweened on top of whatever the Animator is doing (it writes
-- Transform, so idle/walk keep playing underneath). shared/Joints handles both joint systems: Motor6D
-- (our rigs, the Conduit body) and AnimationConstraint (Roblox's newer avatar joints).
local function pose(char, name, offset, seconds, style)
	Joints.Pose(char, name, offset, seconds, style)
end
local function relax(char, seconds)
	for _, name in { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "Waist", "Neck" } do
		pose(char, name, CFrame.identity, seconds or 0.3)
	end
end
-- Each weapon family swings its own way. Angles in degrees: shoulder (lift, twist), elbow bend,
-- waist (bend, turn). Windup is where the arm waits during the telegraph; slash is where it ends.
local r = math.rad
local FAMILY_POSE = {
	-- default: a horizontal cut from over the shoulder
	Blade = { windup = { 150, 20, 40, 0, 20 }, slash = { 55, -10, 0, 0, -20 } },
	Fists = { windup = { -25, 10, 90, 0, 10 }, slash = { 95, 0, 0, 5, -12 } }, -- jab: straight out
	Hammer = { windup = { 195, 30, 30, -10, 15 }, slash = { 70, 0, 0, 25, -10 } }, -- overhead: down and through
	Spear = { windup = { -45, 15, 100, 0, 25 }, slash = { 90, 0, 0, 10, -25 } }, -- thrust: pulled back, driven forward
	Sidearm = { windup = { 85, 0, 10, 0, 10 }, slash = { 100, 0, 0, -4, 8 } }, -- aim then recoil
}
FAMILY_POSE.Baton, FAMILY_POSE.Blunt = FAMILY_POSE.Blade, FAMILY_POSE.Blade
local function familyOf(char)
	local id = typeof(char) == "Instance" and char:GetAttribute("Weapon")
	local def = id and Weapons.Defs[id]
	return FAMILY_POSE[def and def.Family] or FAMILY_POSE.Blade
end
local function applyPose(char, p, seconds, style, heavyScale)
	local k = heavyScale or 1
	pose(char, "RightShoulder", CFrame.Angles(r(p[1] * k), 0, r(p[2])), seconds, style)
	pose(char, "RightElbow", CFrame.Angles(r(p[3]), 0, 0), seconds, style)
	pose(char, "Waist", CFrame.Angles(r(p[4]), r(p[5] * k), 0), seconds, style)
	pose(char, "LeftShoulder", CFrame.Angles(r(if p[1] > 90 then 40 else 15), 0, r(-15)), seconds, style)
end
-- the arm waits in the family's windup for `seconds` (the telegraph), torso twisted
local function windupAnim(char, seconds, heavy)
	applyPose(char, familyOf(char).windup, math.max(0.08, seconds * 0.8), nil, if heavy then 1.15 else 1)
end
-- the strike: snap to the family's end pose, then settle
local function slashAnim(char, heavy)
	applyPose(char, familyOf(char).slash, if heavy then 0.12 else 0.08, Enum.EasingStyle.Quart, if heavy then 1.1 else 1)
	task.delay(if heavy then 0.3 else 0.18, function()
		relax(char, if heavy then 0.45 else 0.3)
	end)
end
local function swingAnim(char, heavy)
	local windup = if heavy then 0.3 else 0.1
	windupAnim(char, windup, heavy)
	task.delay(windup, function()
		slashAnim(char, heavy)
	end)
end
-- flinch: head and torso snap back, arms come up, then recover
local guardSet, guardJolt -- the visible guard (defined with the traced swings below)
local function staggerAnim(char, hard, contact, amount, stun)
	-- the body gives where it was struck: a blow from the right twists and tips it left, and the reverse
	local side, high = 1, false
	local torso = typeof(char) == "Instance" and char:FindFirstChild("UpperTorso")
	if contact and torso then
		local rel = torso.CFrame:PointToObjectSpace(contact)
		side = if rel.X >= 0 then 1 else -1
		high = rel.Y > 0.6
	end
	-- the keyframed reactions (tools/anims): which side was struck, or a guard break's stumble
	local heavyHit = (tonumber(amount) or 0) >= IMP.Hit.HeavyAmount
	local reaction = if hard then "Stagger" elseif heavyHit and Anims.Has("Hit_Heavy") then "Hit_Heavy" elseif high then "Hit_High"
		elseif contact and torso and math.abs(torso.CFrame:PointToObjectSpace(contact).X) > 0.35 then (if side > 0 then "Hit_Right" else "Hit_Left")
		else "Hit_Front"
	if Anims.Has(reaction) then
		local track = Anims.Play(char, reaction, { fade = 0.03, weight = 6 }) -- over a swing or guard still fading out
		stun = tonumber(stun)
		if track and stun and stun > 0 and reaction ~= "Stagger" and reaction ~= "Hit_Heavy" then
			-- held through the hit-stun the server applied: a long stun is a long reaction
			local length = if track.Length > 0 then track.Length else 0.7
			track:AdjustSpeed(length / math.clamp(stun + 0.3, 0.45, 1.4))
		end
		return
	end
	local k = if hard then 1.6 else 1
	pose(char, "Waist", CFrame.Angles(math.rad(-10 * k), math.rad(side * 16 * k), math.rad(side * 9 * k)), 0.05, Enum.EasingStyle.Quart)
	if high then
		pose(char, "Neck", CFrame.Angles(math.rad(-26 * k), math.rad(side * 20), math.rad(side * 10)), 0.05, Enum.EasingStyle.Quart)
	end
	pose(char, "Neck", CFrame.Angles(math.rad(if hard then -30 else -18), 0, 0), 0.06, Enum.EasingStyle.Quart)
	pose(char, "RightShoulder", CFrame.Angles(math.rad(30), 0, math.rad(20)), 0.08)
	pose(char, "LeftShoulder", CFrame.Angles(math.rad(30), 0, math.rad(-20)), 0.08)
	task.delay(if hard then 0.35 else 0.15, function()
		relax(char, if hard then 0.5 else 0.3)
	end)
end
-- guard: both arms up and across, elbows bent, weight back
local function blockPose(char, on)
	if Anims.Has("Block") then
		if on then
			Anims.Play(char, "Block", { fade = 0.12 })
		else
			Anims.Stop(char, "Block", 0.18)
		end
		if guardSet then
			guardSet(char, on)
		end
		return
	end
	if on then
		pose(char, "RightShoulder", CFrame.Angles(math.rad(70), 0, math.rad(-25)), 0.12)
		pose(char, "LeftShoulder", CFrame.Angles(math.rad(70), 0, math.rad(25)), 0.12)
		pose(char, "RightElbow", CFrame.Angles(math.rad(70), 0, 0), 0.12)
		pose(char, "LeftElbow", CFrame.Angles(math.rad(70), 0, 0), 0.12)
		pose(char, "Waist", CFrame.Angles(math.rad(-6), 0, 0), 0.12)
	else
		relax(char, 0.2)
	end
end
-- parry / block impact: the guard jolts and comes back
local function guardHitAnim(char, kind)
	if Anims.Has("Parry") then
		local parry = kind == "Parry"
		Anims.Play(char, if parry or not Anims.Has("Block_Hit") then "Parry" else "Block_Hit", { fade = 0.03, weight = 8 })
		if guardJolt then
			guardJolt(char, parry) -- a parry sweeps the blade away; a block is driven back
		end
		return
	end
	pose(char, "RightShoulder", CFrame.Angles(math.rad(95), 0, math.rad(-35)), 0.05, Enum.EasingStyle.Quart)
	pose(char, "LeftShoulder", CFrame.Angles(math.rad(95), 0, math.rad(35)), 0.05, Enum.EasingStyle.Quart)
	task.delay(0.1, function()
		if char:GetAttribute("Blocking") then
			blockPose(char, true)
		else
			relax(char, 0.25)
		end
	end)
end

-- A swing: pose the rig, draw a quick arc in front of whoever swung and punch our camera.
-- ===== Traced swings (shared/Swings): the arm follows the same arc the server traces for hits =====
-- Wind-up coils past the start of the arc, the strike sweeps it fast with the torso uncoiling, the
-- follow-through carries past the end and settles. A hit freezes the swing for a beat (hitstop); a clash or
-- a wall throws the arm back. The trail is drawn where the blade actually went.
local swinging = setmetatable({}, { __mode = "k" }) -- char -> state
local swingFx, endSwing
do
local DOWN = Vector3.new(0, -1, 0)
local function armTo(dirTorso)
	local d = dirTorso.Unit
	local axis = DOWN:Cross(d)
	local dot = math.clamp(DOWN:Dot(d), -1, 1)
	if axis.Magnitude < 1e-4 then
		return if dot > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end
local REST_YAW, REST_PITCH = 12, -75
local function lerpN(a, b, f)
	return a + (b - a) * f
end
local function swingPose(char, yaw, pitch, twist, lean, bodyAnimated)
	local twistRad = math.rad(-twist)
	local dirRoot = Vector3.new(math.sin(math.rad(yaw)) * math.cos(math.rad(pitch)), math.sin(math.rad(pitch)), -math.cos(math.rad(yaw)) * math.cos(math.rad(pitch)))
	local dirTorso = CFrame.Angles(0, -twistRad, 0):VectorToWorldSpace(dirRoot)
	Joints.Set(char, "RightShoulder", armTo(dirTorso))
	Joints.Set(char, "RightElbow", CFrame.identity)
	Joints.Set(char, "RightWrist", CFrame.Angles(math.rad(-90), 0, 0)) -- the weapon in line with the arm
	if bodyAnimated then
		return -- the Swing_<shape> animation turns the torso, steps the legs and swings the off arm
	end
	Joints.Set(char, "Waist", CFrame.Angles(math.rad(lean), twistRad, 0))
	Joints.Set(char, "LeftShoulder", CFrame.Angles(math.rad(25 + twist * 0.3), 0, math.rad(-12)))
end
local function trailSegment(from, to, heavy)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local seg = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon,
		Color = if heavy then Color3.fromRGB(255, 180, 80) else Color3.fromRGB(225, 235, 255), Transparency = 0.25,
		Size = Vector3.new(0.12, 0.12, length), CFrame = CFrame.lookAt((from + to) / 2, to) }, workspace)
	TweenService:Create(seg, TweenInfo.new(0.14), { Transparency = 1, Size = Vector3.new(0.02, 0.02, length) }):Play()
	Debris:AddItem(seg, 0.16)
end
endSwing = function(char, recoil)
	local st = swinging[char]
	swinging[char] = nil
	if st and st.track then
		st.track:Stop(if recoil then 0.06 else 0.2)
	end
	if st and recoil then
		Joints.Pose(char, "RightShoulder", CFrame.Angles(math.rad(-40), 0, math.rad(25)), 0.08, Enum.EasingStyle.Quart)
		if Anims.Has("Recoil") then
			Anims.Play(char, "Recoil", { fade = 0.04, weight = 4 })
		else
			Joints.Pose(char, "Waist", CFrame.Angles(math.rad(-10), 0, 0), 0.08, Enum.EasingStyle.Quart)
		end
		task.delay(0.12, function()
			if not swinging[char] then
				relax(char, 0.3)
			end
		end)
	else
		relax(char, 0.25)
	end
end
-- ===== The guard (F): the weapon held across the front, braced by the off hand, turned toward the blade coming in =====
-- Body from the Block animation; both arms from here (Joints.Set), every frame, for every guarding body (Blocking
-- replicates). The guard reads the nearest live or winding-up swing and puts the weapon between it and the body:
-- across the head for a high blow, upright on the side it comes from. A parry sweeps the blade out and away; a
-- blocked hit drives the guard back into the chest. Fists cover up with both forearms instead.
do
local guarding = setmetatable({}, { __mode = "k" }) -- char -> { hand, blade, jolt, joltSide, joltAt }
local FWD = Vector3.new(0, 0, -1)
local function rotFromTo(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-4 then
		return if dot > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end
guardSet = function(char, on)
	if on then
		guarding[char] = guarding[char] or { hand = Vector3.new(0.4, 1.3, -1.5), blade = Vector3.new(-0.9, 0.45, -0.1).Unit }
	elseif guarding[char] then
		guarding[char] = nil
		relax(char, 0.2)
	end
end
guardJolt = function(char, parry)
	local g = guarding[char]
	if g then
		g.jolt, g.joltAt = if parry then "Parry" else "Block", os.clock()
	end
end
-- the incoming blade nearest this body, as a point in its root space (nil: nothing coming)
local function threatFor(char, root)
	local best, bestD = nil, Config.Combat.GuardSight
	local now = os.clock()
	for other, st in swinging do
		local oroot = other ~= char and other.Parent and other:FindFirstChild("HumanoidRootPart")
		if oroot then
			local e = now - st.t0 - st.frozen
			if e < st.windup + st.active then
				local mid = Swings.ThreatPoint(oroot.CFrame, st.shape, 0, st.range * st.scale, st.scale, root.Position)
				local d = (mid - root.Position).Magnitude
				if d < bestD then
					best, bestD = root.CFrame:PointToObjectSpace(mid), d
				end
			end
		end
	end
	return best
end
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for char, g in guarding do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		if not root or not char:GetAttribute("Blocking") then
			guardSet(char, false)
			continue
		end
		if swinging[char] then
			continue
		end
		local scale = Swings.ScaleOf(char)
		-- where the right hand holds it, and which way the blade runs from the hand (root space): the same shape
		-- the server blocks with (Swings.GuardPose), so a blade that gets past what you see gets past the guard
		local hand, blade, yaw, high = Swings.GuardPose(threatFor(char, root), scale)
		local side = if yaw >= 0 then 1 else -1
		-- a parry sweeps hand and blade out past the threat side; a blocked hit pushes the guard into the chest
		if g.jolt then
			local k = (now - g.joltAt) / (if g.jolt == "Parry" then 0.22 else 0.14)
			if k >= 1 then
				g.jolt = nil
			else
				local f = math.sin(k * math.pi)
				if g.jolt == "Parry" then
					hand += Vector3.new(0.9 * side, 0.3, -0.4) * f
					blade = (blade + Vector3.new(0.8 * side, -0.4, -0.6) * f).Unit
				else
					hand += Vector3.new(0, -0.1, 0.5) * f
				end
			end
		end
		local a = 1 - math.exp(-dt * Config.Combat.GuardFollow)
		g.hand = g.hand:Lerp(hand, a)
		g.blade = g.blade:Lerp(blade, a).Unit
		local shoulderR = Swings.ShoulderOffset * scale
		local shoulderL = Vector3.new(-shoulderR.X, shoulderR.Y, shoulderR.Z)
		if char:FindFirstChild("HeldWeapon") then
			local arm = armTo(g.hand - shoulderR)
			Joints.Set(char, "RightShoulder", arm)
			Joints.Set(char, "RightElbow", CFrame.identity)
			-- the weapon leaves the fist along hand -Z: turn the wrist so it runs along the guard line
			Joints.Set(char, "RightWrist", rotFromTo(FWD, arm:VectorToObjectSpace(g.blade)))
			-- the off hand braces the blade a little way up from the grip
			local brace = g.hand + g.blade * (0.9 * scale)
			Joints.Set(char, "LeftShoulder", armTo(brace - shoulderL))
			Joints.Set(char, "LeftElbow", CFrame.identity)
		else
			-- fists: forearms up in front of the face, leaning toward the threat
			local lean = CFrame.Angles(0, math.rad(-yaw * 0.4), 0)
			Joints.Set(char, "RightShoulder", lean * CFrame.Angles(math.rad(if high then 95 else 70), 0, math.rad(-25)))
			Joints.Set(char, "LeftShoulder", lean * CFrame.Angles(math.rad(if high then 95 else 70), 0, math.rad(25)))
			Joints.Set(char, "RightElbow", CFrame.Angles(math.rad(75), 0, 0))
			Joints.Set(char, "LeftElbow", CFrame.Angles(math.rad(75), 0, 0))
		end
	end
end)
end -- the guard
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for char, st in swinging do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		if not root then
			swinging[char] = nil
			continue
		end
		local e = now - st.t0 - st.frozen
		if now < st.frozenUntil then
			e = st.frozenAt -- hitstop: the swing holds where it bit
		end
		if st.track then
			-- the body animation's fixed timeline (wind-up 0.4, strike 0.2, recovery 0.4) stretched to this swing
			local speed = if now < st.frozenUntil then 0
				elseif e < st.windup then 0.4 / math.max(st.windup, 0.05)
				elseif e < st.windup + st.active then 0.2 / math.max(st.active, 0.05)
				else 0.4 / math.max(st.finish - st.windup - st.active, 0.05)
			if speed ~= st.speed then
				st.speed = speed
				st.track:AdjustSpeed(speed)
			end
		end
		local sy, sp = Swings.Angles(st.shape, 0)
		local my, mp = Swings.Angles(st.shape, 0.5)
		local ey, ep = Swings.Angles(st.shape, 1)
		if e < st.windup then
			-- wind-up: from rest to past the start of the arc (the coil), torso turned with it
			local w = 1 - (1 - e / math.max(st.windup, 1e-3)) ^ 3
			local cy, cp = sy + (sy - my) * 0.25, sp + (sp - mp) * 0.25
			swingPose(char, lerpN(REST_YAW, cy, w), lerpN(REST_PITCH, cp, w), cy * 0.4 * w, -6 * w, st.body)
		elseif e < st.windup + st.active then
			-- the strike: the arc itself, the torso uncoiling through it, weight forward
			local u = (e - st.windup) / st.active
			if not st.released then
				st.released = true
				Sounds.Play(if st.heavy then "SwingHeavy" else "SwingLight", root)
				if char == player.Character then
					local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
					if look.Magnitude > 0.01 then
						root.AssemblyLinearVelocity += look.Unit * (if st.heavy then 14 else 7) -- step into it
					end
					local cam = workspace.CurrentCamera
					cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(if st.heavy then -1.4 else -0.6), 0, 0)
				end
			end
			local y, p = Swings.Angles(st.shape, u)
			swingPose(char, y, p, lerpN(sy * 0.4, ey * 0.4, u), lerpN(-6, 10, u), st.body)
			local _, tip = Swings.Blade(root.CFrame, st.shape, u, st.range * st.scale, st.scale)
			if st.lastTip then
				trailSegment(st.lastTip, tip, st.heavy)
			end
			st.lastTip = tip
		elseif e < st.finish then
			-- follow-through: carries past the end of the arc, then settles back to rest
			local r = (e - st.windup - st.active) / math.max(st.finish - st.windup - st.active, 1e-3)
			local over = math.sin(math.min(r * 2, 1) * math.pi / 2) * 0.18
			local fy, fp = ey + (ey - my) * over, ep + (ep - mp) * over
			local back = math.clamp((r - 0.35) / 0.65, 0, 1)
			back = back * back * (3 - 2 * back)
			swingPose(char, lerpN(fy, REST_YAW, back), lerpN(fp, REST_PITCH, back), lerpN(ey * 0.4, 0, back), lerpN(10, 0, back), st.body)
		else
			endSwing(char, false)
		end
	end
end)

-- safety net: a guard or swing body animation never outlives what it shows (a missed event can't leave the
-- arms up): the guard stops when Blocking is off, a swing body stops when no swing is running
task.spawn(function()
	while true do
		task.wait(0.5)
		local char = player.Character
		if char then
			if not char:GetAttribute("Blocking") then
				Anims.Stop(char, "Block", 0.2)
			end
			if not swinging[char] then
				Anims.StopPrefix(char, "Swing_", 0.2)
			end
		end
	end
end)

swingFx = function(char, label, shape, windup, active, finish, range)
	local root = typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local heavy = label == "Heavy"
	if typeof(shape) == "string" and tonumber(active) then
		swinging[char] = { shape = shape, t0 = os.clock(), frozen = 0, frozenUntil = 0, frozenAt = 0, windup = tonumber(windup) or 0.2,
			active = tonumber(active) or 0.15, finish = math.max(tonumber(finish) or 0.6, (tonumber(windup) or 0.2) + (tonumber(active) or 0.15) + 0.15),
			range = tonumber(range) or 7, scale = Swings.ScaleOf(char), heavy = heavy }
		local st = swinging[char]
		st.body = Anims.Has("Swing_" .. shape) -- the body is animated (here or, for other players, by their client)
		Anims.StopPrefix(char, "Swing_", 0.05)
		Anims.Stop(char, "Recoil", 0.05)
		st.track = Anims.Play(char, "Swing_" .. shape, { fade = 0.06, speed = 0.4 / math.max(st.windup, 0.05) })
		st.speed = 0.4 / math.max(st.windup, 0.05)
		return
	end
	swingAnim(char, heavy)
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
end -- traced swings

Remotes.CombatEvent.OnClientEvent:Connect(function(kind, a, b, c, d, e, f)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "Swing" then
		swingFx(a, b, c, d, e, f)
	elseif kind == "Clash" and typeof(b) == "Vector3" then
		-- two blades met: both swings are thrown back
		sparks(b, IMP.Parry.Sparks)
		ring(b, IMP.Parry.Ring)
		Sounds.Play("HitClang", b, { Volume = 1 })
		endSwing(a, true)
		if typeof(c) == "Instance" then
			endSwing(c, true)
		end
		if a == player.Character or c == player.Character then
			shake(IMP.Block.Shake * 1.5)
			hitstop(0.08)
		end
		floatWord(a, "CLASH", Color3.fromRGB(255, 230, 140), true)
	elseif kind == "Glance" and typeof(b) == "Vector3" then
		sparks(b, IMP.Block.Sparks)
		Sounds.Play("HitClang", b)
		endSwing(a, true)
	elseif kind == "DodgeMove" or kind == "Knockback" then
		-- a dodge already moved us (client/Movement); the server only adds Enemy Step's hop
		if root and not (kind == "DodgeMove" and Movement.ServerDodge(a, b, c)) then
			root.AssemblyLinearVelocity = a -- we own our character's physics
		end
	elseif kind == "BlackFlash" then
		blackFlashFx(a, b)
	elseif kind == "SkillCD" then
		cooldowns[a] = os.clock() + b
	elseif kind == "Bolt" then
		local from = typeof(a) == "Instance" and a:FindFirstChild("HumanoidRootPart")
		if from then
			-- c = the weapon's Noise when it fires a round and not an arc: a faint streak and a cough, no beam
			local quiet = type(c) == "number"
			local muzzle = from.Position + Vector3.new(0, if quiet then 1.2 else 0, 0)
			local length = (b - muzzle).Magnitude
			local beam = make("Part", {
				Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon,
				Color = if quiet then Color3.fromRGB(255, 236, 200) else Color3.fromRGB(120, 200, 255), Transparency = if quiet then 0.6 else 0,
				Size = Vector3.new(if quiet then 0.05 else 0.2, if quiet then 0.05 else 0.2, length), CFrame = CFrame.lookAt(muzzle, b) * CFrame.new(0, 0, -length / 2),
			}, workspace)
			Debris:AddItem(beam, if quiet then 0.05 else 0.1)
			if quiet then
				Sounds.Play("ShotQuiet", from)
			end
		end
	elseif kind == "Damage" and typeof(a) == "Instance" and type(b) == "table" then
		-- our hit landed: float the number off the victim and nudge the camera
		local root = a:FindFirstChild("Head") or a:FindFirstChild("HumanoidRootPart")
		if root then
			local amount, result, dtype = b[1], b[2], b[3]
			local billboard = make("BillboardGui", { Size = UDim2.fromOffset(120, 36), StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5, 0), AlwaysOnTop = true }, root)
			local color = if result == "blocked" then Color3.fromRGB(170, 170, 190) elseif dtype == "Arc" then Color3.fromRGB(90, 220, 255) elseif amount >= 30 then Color3.fromRGB(255, 150, 50) else Color3.fromRGB(255, 225, 90)
			local text = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ("%d"):format(math.round(amount)), TextColor3 = color, Font = Enum.Font.GothamBold, TextScaled = true, TextStrokeTransparency = 0.3 }, billboard)
			Debris:AddItem(billboard, 1.0)
			TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0) }):Play()
			TweenService:Create(text, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			local heavy = amount >= IMP.Hit.HeavyAmount
			hitMarker()
			shake((if result == "blocked" then IMP.Block.Shake else IMP.Hit.Shake) * (if heavy then IMP.HeavyShakeMult else 1))
			hitstop((if result == "blocked" then 0 else IMP.Hit.Hitstop) * (if heavy then IMP.HeavyHitstopMult else 1))
		end
	elseif kind == "Windup" then
		windupAnim(a, tonumber(b) or 0.5, (tonumber(b) or 0) >= 0.7)
		task.delay(tonumber(b) or 0.5, function()
			slashAnim(a, (tonumber(b) or 0) >= 0.7)
		end)
	elseif FLASH[kind] then
		flash(a, FLASH[kind])
	end
	local WORDS = { Block = "BLOCKED", Parry = "PARRIED", GuardBreak = "GUARD BREAK", Dodged = "DODGED" }
	if kind == "Hit" then
		local contact = if typeof(c) == "Vector3" then c else nil
		staggerAnim(a, false, contact, b, f)
		impact("Hit", a, nil, false)
		if contact then
			sparks(contact, IMP.Hit.Sparks) -- where the blade bit
		end
		-- the attacker's swing holds for a beat where it connected
		local st = typeof(e) == "Instance" and swinging[e]
		if st and os.clock() >= st.frozenUntil then
			st.frozenAt = os.clock() - st.t0 - st.frozen
			st.frozenUntil = os.clock() + 0.07
			st.frozen += 0.07
		end
		if a == player.Character then
			local amount = tonumber(b) or 0
			floatWord(a, ("-%d"):format(math.floor(amount + 0.5)), HUD.DamageNumbers.Colors.Taken, amount >= HUD.DamageNumbers.HeavyAmount)
			local hum = a:FindFirstChildOfClass("Humanoid")
			flashDamage(if hum then math.clamp(amount / math.max(hum.MaxHealth, 1) * 3, 0.35, 1) else 0.6)
		end
	elseif kind == "GuardBreak" then
		staggerAnim(a, true)
		impact("GuardBreak", a, nil, true)
		if a == player.Character then
			flashDamage(0.5)
		end
	elseif kind == "Parry" or kind == "Block" then
		guardHitAnim(a, kind)
		impact(kind, a, nil, false)
	elseif kind == "Dodged" then
		impact("Dodged", a, nil, false)
	end
	if WORDS[kind] and typeof(a) == "Instance" then
		floatWord(a, WORDS[kind], HUD.DamageNumbers.Colors[kind], false)
	elseif kind == "Launch" and typeof(a) == "Instance" then
		floatWord(a, "LAUNCHED", Color3.fromRGB(255, 230, 120), true)
		local root = a:FindFirstChild("HumanoidRootPart")
		if root then
			local streak = neon(Enum.PartType.Block, Vector3.new(0.6, 10, 0.6), Color3.fromRGB(255, 230, 120), root.CFrame * CFrame.new(0, -6, 0))
			if fxSpawn(streak, 0.3) then
				TweenService:Create(streak, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.12, 16, 0.12) }):Play()
			end
		end
		if b == player.Character then
			shake(0.5)
			hitstop(0.06)
		end
	elseif kind == "Juggle" and typeof(a) == "Instance" then
		floatWord(a, ("AIR x%d"):format(tonumber(b) or 1), Color3.fromRGB(255, 230, 120), false)
		shake(0.2)
		hitstop(0.03)
	elseif kind == "EnemyStep" and typeof(a) == "Instance" then
		floatWord(a, "ENEMY STEP", HUD.DamageNumbers.Colors.Dodged, false)
	elseif kind == "Rip" and typeof(a) == "Instance" then
		floatWord(a, "RIPPING", Color3.fromRGB(255, 80, 80), true)
		if a == player.Character then
			local seconds = tonumber(b) or 4
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < seconds and player.Character == a do
					damageFlash.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
					flashDamage(0.6)
					shake(0.25)
					task.wait(0.35)
				end
				damageFlash.BackgroundColor3 = HUD.DamageFlash.Color
			end)
		end
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
		blockPose(char, blocking and true or false)
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
		if barValue[fill] then
			barValue[fill].Text = ("%d / %d"):format(math.floor(v + 0.5), math.floor(m + 0.5))
		end
	end
	char:GetAttributeChangedSignal(valueAttr):Connect(update)
	char:GetAttributeChangedSignal(maxAttr):Connect(update)
	update()
end
local function bindHealth(char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	local function update()
		healthFill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
		barValue[healthFill].Text = ("%d / %d"):format(math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
	end
	hum.HealthChanged:Connect(update)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end
-- other conduits' guards are posed too (their Blocking attribute replicates)
local function bindOtherBlock(char)
	char:GetAttributeChangedSignal("Blocking"):Connect(function()
		blockPose(char, char:GetAttribute("Blocking") and true or false)
	end)
end
for _, other in Players:GetPlayers() do
	if other ~= player then
		if other.Character then
			bindOtherBlock(other.Character)
		end
		other.CharacterAdded:Connect(bindOtherBlock)
	end
end
Players.PlayerAdded:Connect(function(other)
	other.CharacterAdded:Connect(bindOtherBlock)
end)

local function onCharacter(char)
	bindStance(char)
	bindHealth(char)
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

local AIM, MENUS, menuOpen, aimActive, applyAim, toggleAim
do
-- ===== Combat stance (ported from combat-feel's Aim) =====
-- While on, the body turns to the camera's yaw, the camera rides over the right shoulder and the mouse is
-- locked to the centre, so melee cones and the arc pistol (both fire along the facing on the server) go where
-- you look. It pauses, freeing the cursor, while any panel needs the mouse or LeftAlt is held.
AIM = Config.Aim
local GameSettings = UserSettings():GetService("UserGameSettings")
local aimOn = AIM.DefaultOn
MENUS = { statsPanel, invPanel, loadoutPanel, app, hidePanel, containerPanel, marketPanel, terminalPanel, devPanel, deathScreen }
menuOpen = function()
	for _, m in MENUS do
		if m.Visible then
			return true
		end
	end
	return false
end
aimActive = function()
	-- (First person counts: the body has to face where you look there too, or shots leave along the old facing.
	-- Leaving it out is what made the pistol miss after the ride ended in first person in v79.)
	if not aimOn or Intro.Active() or menuOpen() or UserInputService:IsKeyDown(AIM.FreeCursorKey) then
		return false
	end
	if Handling.HoldsFacing() then
		return false -- back to a wall: the wall places the body
	end
	-- A takedown or a cutscene places the body: turning it to the camera here is what put the attacker at the
	-- guard's side instead of square behind it (owner, 2026-11-11).
	local char = player.Character
	return not (char and (char:GetAttribute("Takedown") or char:GetAttribute("Cutscene")))
end
local function aimPreset()
	local char = player.Character
	local def = char and Weapons.Defs[char:GetAttribute("Weapon") or ""]
	return if def and def.Family == "Sidearm" then AIM.Ranged else AIM.Melee
end
applyAim = function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local drop = Handling.Drop() -- crouched and prone the camera comes down
		local shoulder = (Handling.AimPreset() or aimPreset()).ShoulderOffset
		hum.CameraOffset = (if aimOn and not helmetcam then shoulder else Vector3.zero) + drop
		hum.AutoRotate = not aimOn and not Handling.InCover()
	end
	GameSettings.RotationType = if aimOn then Enum.RotationType.CameraRelative else Enum.RotationType.MovementRelative
	if not aimOn then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end
-- pin the third-person distance for a frame when the weapon kind changes, then let the player scroll again
local pinToken = 0
local function setDistance(distance)
	if helmetcam then
		return
	end
	pinToken += 1
	local token = pinToken
	local minZ, maxZ = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = distance, distance
	task.delay(0.1, function()
		if token == pinToken then
			player.CameraMinZoomDistance, player.CameraMaxZoomDistance = math.min(minZ, distance), math.max(maxZ, distance)
		end
	end)
end
RunService.Heartbeat:Connect(function()
	if not aimActive() then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 or hum.Sit or hum.PlatformStand then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit) -- yaw only; physics keeps the position
	end
end)
RunService:BindToRenderStep("EndeavorAim", 202, function() -- after the camera scripts, which reset MouseBehavior
	if Intro.Active() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	elseif helmetcam then
		-- first person: the view is the mouse, unless a panel needs the cursor
		UserInputService.MouseBehavior = if menuOpen() or UserInputService:IsKeyDown(AIM.FreeCursorKey) then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	elseif aimOn then
		UserInputService.MouseBehavior = if aimActive() then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	end
end)
toggleAim = function()
	aimOn = not aimOn
	applyAim()
end
-- stance, aim and the wall move the camera: lower, or in over the shoulder and narrower while RMB is held
local baseFov
Handling.Changed = function(what)
	applyAim()
	if what == "Aim" then
		local cam = workspace.CurrentCamera
		local on = Handling.Aiming()
		if cam then
			baseFov = baseFov or cam.FieldOfView
			Kit.tween(cam, 0.14, { FieldOfView = if not on then baseFov elseif Handling.Sights() then Config.Stealth.Aim.SightFov else Config.Stealth.Aim.Fov })
		end
		if not Handling.Sights() then
			setDistance(if on then Config.Stealth.Aim.Distance else aimPreset().Distance)
		end
	end
end
local function bindAim(char)
	task.defer(applyAim)
	local lastKind
	local function refresh(force)
		local preset = aimPreset()
		applyAim()
		if force or preset ~= lastKind then
			lastKind = preset
			setDistance(preset.Distance)
		end
	end
	char:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	char:GetAttributeChangedSignal("Stance"):Connect(function()
		task.defer(applyAim)
	end)
	task.delay(0.5, refresh, true)
end
player.CharacterAdded:Connect(bindAim)
if player.Character then
	bindAim(player.Character)
end
end
reticleActive = aimActive

local implantWatchModel -- defined in the block below; the nameplate tag loop uses it
do
-- ===== Visible implants (ported from combat-feel): what is in a body shows on it =====
local IM = Config.Implants
local implantDrawn = {} -- model -> { [slot] = { itemId, parts, hidden } }
local implantWatch = {}
local function inert(part)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Massless, part.CastShadow = false, false, false, false, true, false
end
local function weldTo(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end
local function scaledV(v, size)
	return Vector3.new(v.X * size.X, v.Y * size.Y, v.Z * size.Z)
end
-- the generated implant model (ReplicatedStorage.Implants, server/ImplantLibrary.lua), else the icon model
local implantFolder
local function implantArt(itemId)
	implantFolder = implantFolder or ReplicatedStorage:FindFirstChild("Implants")
	local a = implantFolder and implantFolder:FindFirstChild(itemId)
	if a then
		return a, true
	end
	iconFolder = iconFolder or ReplicatedStorage:FindFirstChild("Icons")
	return iconFolder and iconFolder:FindFirstChild(itemId), false
end
-- which limb part (1 upper, 2 lower, 3 hand/foot) a generated model part belongs on, from its name
local SEGMENTS = { upperarm = 1, forearm = 2, lowerarm = 2, hand = 3, thigh = 1, upperleg = 1, shin = 2, lowerleg = 2, foot = 3 }
local function segmentOf(name)
	local key = string.gsub(string.lower(name), "[^%a]", "")
	local best, bestLen = nil, 0
	for k, i in SEGMENTS do
		if string.find(key, k, 1, true) and #k > bestLen then
			best, bestLen = i, #k
		end
	end
	return best
end
-- fit a clone's parts into a box (cf at the centre, size in studs)
local function fitInto(clone, cf, size)
	local parts = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if clone:IsA("BasePart") then
		table.insert(parts, clone)
	end
	if #parts == 1 then
		parts[1].Size = size
		parts[1].CFrame = cf
	elseif #parts > 1 and clone:IsA("Model") then
		local _, extent = clone:GetBoundingBox()
		local r = math.min(size.X / math.max(extent.X, 0.01), size.Y / math.max(extent.Y, 0.01), size.Z / math.max(extent.Z, 0.01))
		pcall(function()
			clone:ScaleTo(clone:GetScale() * r)
		end)
		local bcf = clone:GetBoundingBox()
		clone:PivotTo(clone:GetPivot() * (bcf:Inverse() * cf))
	end
	return parts
end
local function implantClear(model, slot)
	local d = implantDrawn[model] and implantDrawn[model][slot]
	if d then
		for _, part in d.parts do
			part:Destroy()
		end
		for bp, t in d.hidden or {} do
			if bp.Parent then
				bp.Transparency = t
			end
		end
		implantDrawn[model][slot] = nil
	end
end
local function implantDraw(model, slot)
	local itemId = model:GetAttribute("Cyber_" .. slot)
	local have = implantDrawn[model] and implantDrawn[model][slot]
	if have and have.itemId == itemId then
		return
	end
	implantClear(model, slot)
	local spec = IM.Slots[slot]
	if type(itemId) ~= "string" or not spec or not Cybernetics.Pieces[itemId] then
		return
	end
	local accent = IM.Accent[itemId] or IM.DefaultAccent
	local parts, hidden = {}, nil
	local function add(part, onto)
		inert(part)
		weldTo(onto, part)
		part.Parent = model
		table.insert(parts, part)
	end
	local art, generated = implantArt(itemId)
	if spec.Shell and art and generated then
		-- a limb with a generated model: each named segment sized onto its body part, the flesh hidden
		local limb, bySeg = {}, {}
		for i, name in spec.Shell do
			limb[i] = model:FindFirstChild(name)
		end
		for _, part in art:GetChildren() do
			local seg = part:IsA("BasePart") and segmentOf(part.Name)
			if seg and limb[seg] and not bySeg[seg] then
				bySeg[seg] = part
			end
		end
		local left = string.sub(slot, 1, 4) == "Left"
		local turn = if left then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		if bySeg[1] and bySeg[2] and bySeg[3] then
			hidden = {}
			for i, src in bySeg do
				local copy = src:Clone()
				copy.Size = limb[i].Size * IM.ArtGrow
				copy.CFrame = limb[i].CFrame * turn
				copy.Name = "ImplantArt"
				add(copy, limb[i])
				hidden[limb[i]] = limb[i].Transparency
				limb[i].Transparency = 1
			end
		else
			art, generated = nil, false
		end
	end
	if spec.Shell and not (art and generated) then
		-- a limb: metal shells over the body parts plus a lit seam at the joint
		for _, name in spec.Shell do
			local bp = model:FindFirstChild(name)
			if bp and bp:IsA("BasePart") then
				local copy = Instance.new("Part")
				copy.Name = "Implant_" .. name
				copy.Size = bp.Size * IM.Metal.Grow
				copy.Color, copy.Material = IM.Metal.Color, IM.Metal.Material
				copy.CFrame = bp.CFrame
				add(copy, bp)
			end
		end
	elseif art and spec.Fit then
		-- a small piece with a model: fitted into its box on the head or chest
		for _, f in spec.Fit do
			local bp = model:FindFirstChild(f.Part)
			if bp and bp:IsA("BasePart") then
				local clone = art:Clone()
				local cf = bp.CFrame * CFrame.new(scaledV(f.Offset, bp.Size)) * CFrame.Angles(0, math.rad(f.Turn or 0), 0)
				for _, part in fitInto(clone, cf, scaledV(f.Size, bp.Size) * IM.ArtGrow) do
					add(part, bp)
				end
			end
		end
	end
	for _, b in spec.Bits or {} do
		if (spec.Shell and not (art and generated)) or not art then
			local onto = model:FindFirstChild(b.Part)
			if onto and onto:IsA("BasePart") then
				local part = Instance.new("Part")
				part.Name = "ImplantBit"
				part.Size = b.Size
				if b.Neon then
					part.Material, part.Color = Enum.Material.Neon, accent
				else
					part.Material, part.Color = IM.Metal.Material, IM.Metal.Color
				end
				part.CFrame = onto.CFrame * CFrame.new(scaledV(b.Offset, onto.Size))
				add(part, onto)
			end
		end
	end
	implantDrawn[model] = implantDrawn[model] or {}
	implantDrawn[model][slot] = { itemId = itemId, parts = parts, hidden = hidden }
end
local function implantUnwatch(model)
	for _, c in implantWatch[model] or {} do
		c:Disconnect()
	end
	implantWatch[model] = nil
	for slot in implantDrawn[model] or {} do
		implantClear(model, slot)
	end
	implantDrawn[model] = nil
end
implantWatchModel = function(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or implantWatch[model] then
		return
	end
	local conns = {}
	implantWatch[model] = conns
	task.spawn(function()
		if not (model:FindFirstChild("UpperTorso") or model:WaitForChild("UpperTorso", 5)) or implantWatch[model] ~= conns then
			return
		end
		for _, slot in Cybernetics.Slots do
			table.insert(conns, model:GetAttributeChangedSignal("Cyber_" .. slot):Connect(function()
				implantDraw(model, slot)
			end))
			implantDraw(model, slot)
		end
		table.insert(conns, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				implantUnwatch(model)
			end
		end))
	end)
end
for _, other in Players:GetPlayers() do
	if other.Character then
		implantWatchModel(other.Character)
	end
	other.CharacterAdded:Connect(implantWatchModel)
end
Players.PlayerAdded:Connect(function(other)
	other.CharacterAdded:Connect(implantWatchModel)
end)

end

do
-- ===== Senses (ported from combat-feel): ears and nose =====
local SN = Config.Senses
local sensesRing = make("Frame", { Name = "Senses", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
local pips, scentMarkers = {}, {}
local function pipAt(i)
	local f = pips[i]
	if not f then
		f = make("Frame", { Name = "Heard", AnchorPoint = Vector2.new(0.5, 0.5), Size = SN.PipSize, BorderSizePixel = 0, BackgroundColor3 = SN.HearColor }, sensesRing)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		pips[i] = f
	end
	return f
end
local function scentMarker(i)
	local m = scentMarkers[i]
	if not m then
		m = make("BillboardGui", { Name = "Scent", AlwaysOnTop = true, Size = SN.MarkerSize, LightInfluence = 0, ResetOnSpawn = false }, gui)
		local dot = make("Frame", { Name = "Dot", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, m)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		scentMarkers[i] = m
	end
	return m
end
local function senseBodies()
	local out = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(out, other.Character)
		end
	end
	for _, m in CollectionService:GetTagged("NPC") do
		table.insert(out, m)
	end
	return out
end
local function seenFrom(cam, target, model)
	local _, onScreen = cam:WorldToViewportPoint(target)
	if not onScreen then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, model }
	return workspace:Raycast(cam.CFrame.Position, target - cam.CFrame.Position, params) == nil
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
			local r = math.min(size.X, size.Y) * SN.RingScale
			for _, model in senseBodies() do
				local root = model:FindFirstChild("HumanoidRootPart")
				local hum = model:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local offset = root.Position - me.Position
					local d = offset.Magnitude
					local v = root.AssemblyLinearVelocity
					if d <= radius and d > 1 and Vector3.new(v.X, 0, v.Z).Magnitude >= SN.MoveSpeed and not seenFrom(cam, root.Position, model) then
						n += 1
						local flat = Vector3.new(offset.X, 0, offset.Z).Unit
						local angle = math.atan2(flat:Dot(right), flat:Dot(flatLook))
						local f = pipAt(n)
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
		local m = scentMarker(n)
		m.Adornee = part
		m.Dot.BackgroundColor3 = color
		m.Dot.BackgroundTransparency = 0.35
		m.Enabled = true
	end
	if radius > 0 and me then
		for _, part in CollectionService:GetTagged("Scent") do
			if part:IsA("BasePart") and part:IsDescendantOf(workspace) and (part.Position - me.Position).Magnitude <= radius then
				mark(part, SN.ScentColor)
			end
		end
		if track then
			for _, model in senseBodies() do
				local root = model:FindFirstChild("HumanoidRootPart")
				local hum = model:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and hum.Health / math.max(hum.MaxHealth, 1) < SN.WoundedBelow and (root.Position - me.Position).Magnitude <= radius then
					mark(root, SN.BloodColor)
				end
			end
		end
	end
	for i = n + 1, #scentMarkers do
		scentMarkers[i].Enabled = false
		scentMarkers[i].Adornee = nil
	end
end
do
	local a, b = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		a += dt
		b += dt
		if a >= SN.Tick then
			a = 0
			hear()
		end
		if b >= SN.ScentTick then
			b = 0
			smell()
		end
	end)
end

end

-- ===== The machine voice (ported from combat-feel): a 100% metal conduit's chat comes out flat =====
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	local Voice = require(Shared:WaitForChild("Voice"))
	local V = Config.Voice
	local function machineSpeaker(message)
		local source = message.TextSource
		local p = source and Players:GetPlayerByUserId(source.UserId)
		return p ~= nil and p:GetAttribute("Machine") == true
	end
	TextChatService.OnIncomingMessage = function(message)
		if message.Status ~= Enum.TextChatMessageStatus.Success or not machineSpeaker(message) then
			return nil
		end
		local props = Instance.new("TextChatMessageProperties")
		props.Text = ('<font color="%s">%s</font>'):format(V.TextColor, Voice.Machine(message.Text))
		props.PrefixText = ('<font color="%s">%s</font>'):format(V.NameColor, message.PrefixText)
		return props
	end
	TextChatService.OnBubbleAdded = function(message)
		if not machineSpeaker(message) then
			return nil
		end
		local props = Instance.new("BubbleChatMessageProperties")
		props.TextColor3 = V.BubbleText
		props.BackgroundColor3 = V.BubbleBackground
		props.FontFace = Font.fromEnum(Enum.Font.Code)
		return props
	end
end)

do
-- ===== Nameplates (ported from combat-feel): bodies read first =====
-- Roblox's over-head name and health bar are switched off locally for every humanoid we plate; a small
-- plate sits at hip height, lower-left, fading with distance. Players white, hostiles red; never my own.
local NP = HUD.Nameplates
local plates = {}
local function plate(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or plates[model] or model == player.Character then
		return
	end
	task.spawn(function()
		local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
		local anchor = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart", 5)
		if not (hum and anchor) or plates[model] or not model.Parent then
			return
		end
		hum.NameDisplayDistance = 0
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local who = Players:GetPlayerFromCharacter(model)
		local bb = make("BillboardGui", { Name = "Nameplate", Adornee = anchor, Size = NP.Size, StudsOffset = NP.Offset, AlwaysOnTop = false, MaxDistance = NP.FadeEnd, ResetOnSpawn = false }, gui)
		local lbl = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = if who then who.DisplayName else (hum.DisplayName ~= "" and hum.DisplayName or model.Name),
			TextColor3 = if who then NP.Color else NP.NpcColor, Font = Enum.Font.GothamMedium, TextSize = NP.TextSize, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 }, bb)
		plates[model] = { gui = bb, label = lbl, hum = hum, anchor = anchor }
	end)
end
local function unplate(model)
	local p = plates[model]
	if p then
		p.gui:Destroy()
		plates[model] = nil
	end
end
for _, other in Players:GetPlayers() do
	if other ~= player then
		if other.Character then
			plate(other.Character)
		end
		other.CharacterAdded:Connect(plate)
		other.CharacterRemoving:Connect(unplate)
	end
end
Players.PlayerAdded:Connect(function(other)
	other.CharacterAdded:Connect(plate)
	other.CharacterRemoving:Connect(unplate)
end)
for _, m in CollectionService:GetTagged("NPC") do
	plate(m)
	implantWatchModel(m)
end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(plate)
CollectionService:GetInstanceAddedSignal("NPC"):Connect(implantWatchModel)
CollectionService:GetInstanceRemovedSignal("NPC"):Connect(unplate)
local plateAcc = 0
RunService.Heartbeat:Connect(function(dt)
	plateAcc += dt
	if plateAcc < 0.1 then
		return
	end
	plateAcc = 0
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for model, p in plates do
		if not model.Parent or not p.anchor.Parent then
			unplate(model)
		else
			if me then
				local a = math.clamp(((p.anchor.Position - me.Position).Magnitude - NP.FadeStart) / math.max(NP.FadeEnd - NP.FadeStart, 1), 0, 1)
				p.label.TextTransparency = a
				p.label.TextStrokeTransparency = 0.5 + a * 0.5
			end
			if p.hum.Health <= 0 then
				p.label.TextTransparency = 1
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if Intro.Active() then
		return -- the ride is watched, not played
	end
	if drag and key == Enum.KeyCode.R then
		drag.rot = 1 - drag.rot -- rotate the stack you are carrying
		clearPreview()
		return
	end
	if Handling.Began(input, key) then
		return -- stances (C, Space, Shift), and with a gun out: RMB aim, V sights, R reload, Q the wall or the prone roll
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Remotes.Attack:FireServer(cameraDirection()) -- a shot goes where you look; a swing ignores it
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		Remotes.Heavy:FireServer(cameraDirection())
	elseif Stealth.Key(key) then
		-- B whistle, X close quarters (tap or hold), G with a guard in your arms or a body on your shoulder
	elseif key == Enum.KeyCode.F then
		Remotes.Block:FireServer(true)
	elseif key == Enum.KeyCode.E then
		Remotes.Flicker:FireServer() -- tap just before your swing connects
	elseif key == Enum.KeyCode.Z then
		Remotes.Feint:FireServer()
	elseif key == Enum.KeyCode.P then
		setHelmetcam(not helmetcam)
	elseif key == AIM.ToggleKey then
		if menuOpen() then
			for _, m in MENUS do -- "lock my camera" with a panel up means: put the panels away
				if m ~= deathScreen then
					m.Visible = false
				end
			end
		else
			toggleAim()
		end
	elseif key == Enum.KeyCode.F1 then
		controls.Visible = not controls.Visible
	elseif key == Enum.KeyCode.F2 and Config.Dev.Enabled then
		devPanel.Visible = not devPanel.Visible
	elseif key == Enum.KeyCode.F3 and Config.Dev.Enabled then
		-- rig report: what this client sees of the rigs around it (joints, transforms, limb positions)
		local lines = {}
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local function report(model)
			local ut = model:FindFirstChild("UpperTorso")
			if not ut then
				return
			end
			table.insert(lines, "== " .. model.Name .. " anchoredRoot=" .. tostring(model:FindFirstChild("HumanoidRootPart") and model.HumanoidRootPart.Anchored))
			for _, n in { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "Head", "LowerTorso" } do
				local p = model:FindFirstChild(n)
				if p then
					local rel = ut.CFrame:PointToObjectSpace(p.Position)
					table.insert(lines, ("  %s rel(%.2f,%.2f,%.2f) size(%.2f,%.2f,%.2f)"):format(n, rel.X, rel.Y, rel.Z, p.Size.X, p.Size.Y, p.Size.Z))
				end
			end
			for _, m in model:GetDescendants() do
				if m:IsA("Motor6D") then
					local rx, ry, rz = m.Transform:ToEulerAnglesXYZ()
					local cx, cy, cz = m.C0:ToEulerAnglesXYZ()
					table.insert(lines, ("  M6D %s %s->%s C0(%.2f,%.2f,%.2f r%.0f,%.0f,%.0f) C1(%.2f,%.2f,%.2f) T(%.2f,%.2f,%.2f r%.0f,%.0f,%.0f)"):format(m.Name, m.Part0 and m.Part0.Name or "?", m.Part1 and m.Part1.Name or "?",
						m.C0.Position.X, m.C0.Position.Y, m.C0.Position.Z, math.deg(cx), math.deg(cy), math.deg(cz), m.C1.Position.X, m.C1.Position.Y, m.C1.Position.Z,
						m.Transform.Position.X, m.Transform.Position.Y, m.Transform.Position.Z, math.deg(rx), math.deg(ry), math.deg(rz)))
				elseif m:IsA("Weld") then
					table.insert(lines, ("  WELD %s %s->%s C0(%.2f,%.2f,%.2f) C1(%.2f,%.2f,%.2f)"):format(m.Name, m.Part0 and m.Part0.Name or "?", m.Part1 and m.Part1.Name or "?", m.C0.Position.X, m.C0.Position.Y, m.C0.Position.Z, m.C1.Position.X, m.C1.Position.Y, m.C1.Position.Z))
				end
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, tr in animator:GetPlayingAnimationTracks() do
					table.insert(lines, ("  TRACK %s t=%.2f w=%.2f"):format(tr.Animation and tr.Animation.AnimationId or "?", tr.TimePosition, tr.WeightCurrent))
				end
			end
		end
		local n = 0
		for _, m in workspace:GetDescendants() do
			if m:IsA("Model") and (m:GetAttribute("Display") or m:GetAttribute("NPC")) and myRoot and m:FindFirstChild("HumanoidRootPart") and (m.HumanoidRootPart.Position - myRoot.Position).Magnitude < 80 and n < 4 then
				n += 1
				report(m)
			end
		end
		if player.Character then
			report(player.Character)
		end
		Remotes.Dev:FireServer("Report", table.concat(lines, "\n"))
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
			Movement.Dodge(dir) -- light gear: roll / air dash any way; armour: forward rolls, else a heavy step (client/Movement)
		end
	elseif SKILL_KEYS[key] then
		Remotes.UseSkill:FireServer(SKILL_KEYS[key])
	elseif TOGGLES[key] then
		TOGGLES[key].Visible = not TOGGLES[key].Visible
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if Handling.Ended(input, input.KeyCode) or Stealth.KeyUp(input.KeyCode) then
		return
	end
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

end
