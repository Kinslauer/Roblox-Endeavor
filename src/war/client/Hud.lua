-- The Front's screen: as little as a rifleman needs. Rounds, fire mode and spare magazines bottom
-- right; health, stance and three counted items bottom left; the scales as one thin bar on top.
-- The gun's parts only show while the weapon is checked (hold Y) or just after it jams.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Firearms = require(Shared:WaitForChild("Firearms"))

local Hud = {}

local WHITE = Color3.fromRGB(232, 236, 240)
local DIM = Color3.fromRGB(150, 158, 166)
local AMBER = Color3.fromRGB(255, 190, 70)
local RED = Color3.fromRGB(255, 80, 70)
local MONO = Enum.Font.RobotoMono
local KIND_COLORS = { Event = AMBER, Kill = WHITE, Info = Color3.fromRGB(140, 215, 240), Emergence = RED }

local gui
local el = {} -- named elements
local pips, partRows = {}, {}
local lastWeaponKey
local nameToken, bannerToken, flashToken, checkToken = 0, 0, 0, 0
local checkHeld = false
local feedLines = {}
local marks = {} -- [model] = { Gui, Token }

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent or gui
	return inst
end
local function text(props, parent)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	props.Font = props.Font or MONO
	props.TextSize = props.TextSize or 12
	props.Text = props.Text or ""
	return make("TextLabel", props, parent)
end
local function bar(props, parent)
	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or WHITE
	return make("Frame", props, parent)
end

Hud.FitSlots = { "Barrel", "Optic", "Muzzle", "Grip" }
local fitRows, fitAny = {}, false

function Hud.Init(screenGui)
	gui = screenGui

	-- centre: a small dot from the hip, a finer one on the sights
	el.Cross = bar({ Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundTransparency = 0.25 })
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, el.Cross)
	el.Flash = text({ Size = UDim2.fromOffset(120, 14), Position = UDim2.new(0.5, -60, 0.5, 16), TextSize = 11, TextColor3 = AMBER, TextTransparency = 1 })
	el.Hit = text({ Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, -15, 0.5, -16), Text = "x", TextSize = 20, TextColor3 = RED, TextTransparency = 1 })
	el.Hurt = bar({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(180, 0, 0), BackgroundTransparency = 1, ZIndex = 5 })

	-- bottom right: the weapon
	local w = make("Frame", { Size = UDim2.fromOffset(220, 84), Position = UDim2.new(1, -244, 1, -104), BackgroundTransparency = 1 })
	el.WeaponBox = w
	el.Name = text({ Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 0), TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1 }, w)
	el.Status = text({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 14), TextSize = 12, TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Right }, w)
	el.Rounds = text({ Size = UDim2.fromOffset(120, 36), Position = UDim2.new(1, -166, 0, 30), Font = Enum.Font.Michroma, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Right }, w)
	el.Size = text({ Size = UDim2.fromOffset(40, 14), Position = UDim2.new(1, -42, 0, 48), TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, w)
	el.Chamber = bar({ Size = UDim2.fromOffset(4, 4), Position = UDim2.new(1, -40, 0, 38) }, w) -- lit: a round is chambered
	el.Mode = text({ Size = UDim2.fromOffset(48, 12), Position = UDim2.new(1, -48, 0, 70), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right }, w)
	el.Pips = make("Frame", { Size = UDim2.fromOffset(110, 10), Position = UDim2.new(1, -166, 0, 71), BackgroundTransparency = 1 }, w)
	-- round 3: the load in the magazines and the loose rounds behind them; the range under the dot while aiming
	el.Load = text({ Size = UDim2.fromOffset(110, 12), Position = UDim2.new(1, -166, 0, 58), TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right }, w)
	el.Range = text({ Size = UDim2.fromOffset(80, 12), Position = UDim2.new(0.5, -40, 0.5, 30), TextSize = 11, TextColor3 = DIM, Text = "" })

	-- the checked weapon: parts, vest, helmet
	local c = make("Frame", { Size = UDim2.fromOffset(170, 112), Position = UDim2.new(1, -194, 1, -226), BackgroundColor3 = Color3.fromRGB(8, 10, 12), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false })
	el.Check = c
	local names = table.clone(Firearms.Parts)
	table.insert(names, "Vest")
	table.insert(names, "Helmet")
	for i, name in names do
		local y = 8 + (i - 1) * 14
		local row = { Name = name }
		row.Label = text({ Size = UDim2.fromOffset(40, 12), Position = UDim2.fromOffset(10, y), TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = name:sub(1, 4):upper() }, c)
		bar({ Size = UDim2.fromOffset(76, 2), Position = UDim2.fromOffset(52, y + 5), BackgroundTransparency = 0.8 }, c)
		row.Fill = bar({ Size = UDim2.fromOffset(76, 2), Position = UDim2.fromOffset(52, y + 5) }, c)
		row.Value = text({ Size = UDim2.fromOffset(28, 12), Position = UDim2.fromOffset(134, y), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right }, c)
		partRows[name] = row
	end

	-- above it, while the weapon is checked: what is fitted in each slot, and the key that changes it
	local f = make("Frame", { Size = UDim2.fromOffset(170, 64), Position = UDim2.new(1, -194, 1, -294), BackgroundColor3 = Color3.fromRGB(8, 10, 12), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false })
	el.Fit = f
	for i, slot in Hud.FitSlots do
		local y = 6 + (i - 1) * 13
		fitRows[slot] = {
			Key = text({ Size = UDim2.fromOffset(60, 12), Position = UDim2.fromOffset(10, y), TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, f),
			Value = text({ Size = UDim2.fromOffset(92, 12), Position = UDim2.fromOffset(68, y), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right }, f),
		}
	end

	-- bottom left: health, stance, three items
	local l = make("Frame", { Size = UDim2.fromOffset(220, 40), Position = UDim2.new(0, 24, 1, -60), BackgroundTransparency = 1 })
	bar({ Size = UDim2.fromOffset(150, 3), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 0.75 }, l)
	el.Health = bar({ Size = UDim2.fromOffset(150, 3), Position = UDim2.fromOffset(0, 34) }, l)
	el.StanceMark = bar({ Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(160, 23), AnchorPoint = Vector2.new(0, 0) }, l)
	-- grenade: a round body; dressing: a cross; sandbag: a soft slab
	local g = bar({ Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = DIM }, l)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, g)
	el.Grenades = text({ Size = UDim2.fromOffset(20, 12), Position = UDim2.fromOffset(13, 8), TextXAlignment = Enum.TextXAlignment.Left }, l)
	bar({ Size = UDim2.fromOffset(9, 3), Position = UDim2.fromOffset(44, 13), BackgroundColor3 = DIM }, l)
	bar({ Size = UDim2.fromOffset(3, 9), Position = UDim2.fromOffset(47, 10), BackgroundColor3 = DIM }, l)
	el.Medkits = text({ Size = UDim2.fromOffset(20, 12), Position = UDim2.fromOffset(57, 8), TextXAlignment = Enum.TextXAlignment.Left }, l)
	local sb = bar({ Size = UDim2.fromOffset(12, 6), Position = UDim2.fromOffset(88, 12), BackgroundColor3 = DIM }, l)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, sb)
	el.Sandbags = text({ Size = UDim2.fromOffset(20, 12), Position = UDim2.fromOffset(104, 8), TextXAlignment = Enum.TextXAlignment.Left }, l)

	-- top: the scales as one thin bar, the hill's hold under it, one dim line
	el.ScaleBack = bar({ Size = UDim2.fromOffset(260, 3), Position = UDim2.new(0.5, -130, 0, 14), BackgroundColor3 = Config.War.FactionColors.Pact, BackgroundTransparency = 0.2 })
	el.ScaleFill = bar({ Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Config.War.FactionColors.Union }, el.ScaleBack)
	el.HoldBack = bar({ Size = UDim2.fromOffset(260, 1), Position = UDim2.new(0.5, -130, 0, 19), BackgroundTransparency = 0.85 })
	el.HoldFill = bar({ Size = UDim2.fromScale(0, 1) }, el.HoldBack)
	el.HillLine = text({ Size = UDim2.fromOffset(260, 12), Position = UDim2.new(0.5, -130, 0, 23), TextSize = 10, TextColor3 = DIM, TextTransparency = 0.25 })
	el.Banner = text({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 44), TextSize = 14, TextTransparency = 1 })

	-- binoculars: the glass closes in from the sides, a thin graticule, a bar that fills while a figure is held
	local b = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 4 })
	el.Binos = b
	bar({ Size = UDim2.fromScale(0.16, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 4 }, b)
	bar({ Size = UDim2.fromScale(0.16, 1), Position = UDim2.fromScale(0.84, 0), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 4 }, b)
	bar({ Size = UDim2.new(0, 120, 0, 1), Position = UDim2.new(0.5, -60, 0.5, 0), BackgroundTransparency = 0.5, ZIndex = 4 }, b)
	bar({ Size = UDim2.new(0, 1, 0, 60), Position = UDim2.new(0.5, 0, 0.5, -30), BackgroundTransparency = 0.5, ZIndex = 4 }, b)
	for i = -3, 3 do
		if i ~= 0 then
			bar({ Size = UDim2.fromOffset(1, 7), Position = UDim2.new(0.5, i * 18, 0.5, -3), BackgroundTransparency = 0.5, ZIndex = 4 }, b)
		end
	end
	local back = bar({ Size = UDim2.fromOffset(60, 2), Position = UDim2.new(0.5, -30, 0.5, 40), BackgroundTransparency = 0.8, ZIndex = 4 }, b)
	el.Dwell = bar({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED, ZIndex = 4 }, back)
end

-- ===== weapon =====
local function setCheck()
	el.Check.Visible = checkHeld or os.clock() < (el.CheckUntil or 0)
	el.Fit.Visible = el.Check.Visible and fitAny
end

-- The fitted parts of the primary: one line per slot the gun has. White = can be changed here and now
-- (the key in front), dim = a barracks job. "+n" = loose parts carried for that slot.
function Hud.Fit(weapon, kit, isPrimary)
	fitAny = false
	local def = weapon and Firearms.Defs[weapon.Id]
	for i, slot in Hud.FitSlots do
		local row = fitRows[slot]
		local has = def ~= nil and isPrimary and table.find(def.Slots, slot) ~= nil
		row.Key.Visible, row.Value.Visible = has, has
		if has then
			fitAny = true
			local att = weapon.Attachments and weapon.Attachments[slot]
			local name = att and Firearms.Attachments[att.Id] and Firearms.Attachments[att.Id].Name or (if slot == "Barrel" then "Standard" else "-")
			local spare = 0
			for _, s in (kit and kit.Spares) or {} do
				local a = Firearms.Attachments[s.Id]
				if a and a.Slot == slot then
					spare += 1
				end
			end
			row.Key.Text = ("%d %s%s"):format(i, slot:sub(1, 4):upper(), if spare > 0 then " +" .. spare else "")
			row.Value.Text = name:upper():sub(1, 12)
			row.Value.TextColor3 = if Firearms.CanField(def, slot) then WHITE else DIM
		end
	end
	setCheck()
end

function Hud.Weapon(weapon, slotName, kit)
	kit = kit or {}
	el.Grenades.Text = tostring(kit.Grenades or 0)
	el.Medkits.Text = tostring(kit.Medkits or 0)
	el.Sandbags.Text = tostring(kit.Sandbags or 0)
	for _, pair in { { "Vest", kit.Armor }, { "Helmet", kit.Helmet } } do
		local row, piece = partRows[pair[1]], pair[2]
		local v = piece and piece.Condition
		row.Fill.Size = UDim2.fromOffset(76 * (v or 0) / 100, 2)
		row.Value.Text = if v then ("%d"):format(v) else "-"
	end
	el.WeaponBox.Visible = weapon ~= nil
	if not weapon then
		lastWeaponKey = nil
		return
	end
	el.Rounds.Text = if weapon.Mag == nil then "--" else tostring(weapon.Mag)
	el.Rounds.TextColor3 = if weapon.Mag == nil or weapon.Mag <= weapon.MagSize * 0.2 then AMBER else WHITE
	el.Size.Text = "/" .. weapon.MagSize
	el.Chamber.BackgroundTransparency = if weapon.Chamber then 0 else 0.8
	el.Mode.Text = weapon.Mode:upper()
	el.Mode.TextColor3 = if weapon.Mode == "Safe" then AMBER else DIM
	local JAMS = { Stovepipe = "STOVEPIPE  [T]", Feed = "FAILURE TO FEED  [T]", DoubleFeed = "DOUBLE FEED  [T]" }
	el.Status.Text = if weapon.Jammed then (JAMS[weapon.JamKind or ""] or "JAM  [T]") elseif (weapon.Heat or 0) >= 0.95 then "HOT" elseif weapon.Reloading then "" elseif weapon.Mag == nil then "NO MAGAZINE  [R]" elseif weapon.Mag == 0 and not weapon.Chamber then "MAGAZINE EMPTY  [R]" elseif weapon.BoltOpen then "BOLT OPEN  [T]" elseif not weapon.Chamber then "CHAMBER EMPTY  [T]" else ""
	el.Status.TextColor3 = if weapon.Jammed then RED else AMBER
	local loose = weapon.Loose or 0
	el.Load.Text = (if weapon.Load and weapon.Load ~= "Ball" then weapon.Load:upper() .. "  " else "") .. (if loose > 0 then "+" .. loose else "")
	-- spare magazines: one pip each
	for i = 1, math.max(#pips, math.min(weapon.Spare, 10)) do
		if not pips[i] then
			pips[i] = bar({ Size = UDim2.fromOffset(4, 10), Position = UDim2.new(1, -4 - (i - 1) * 7, 0, 0), BackgroundColor3 = DIM }, el.Pips)
		end
		pips[i].Visible = i <= weapon.Spare
	end
	for _, name in Firearms.Parts do
		local v = weapon.Parts[name] or 100
		local row = partRows[name]
		row.Fill.Size = UDim2.fromOffset(76 * v / 100, 2)
		row.Fill.BackgroundColor3 = if v < 35 then RED elseif v < 65 then AMBER else WHITE
		row.Value.Text = ("%d"):format(v)
	end
	-- the name shows for a moment when the weapon in hand changes
	local key = weapon.Id .. ":" .. tostring(slotName)
	if key ~= lastWeaponKey then
		lastWeaponKey = key
		nameToken += 1
		local token = nameToken
		el.Name.Text = weapon.Name:upper()
		el.Name.TextTransparency = 0
		task.delay(2.5, function()
			if token == nameToken then
				TweenService:Create(el.Name, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
		end)
	end
	if weapon.Jammed and not el.WasJammed then
		Hud.Check(nil, 3) -- a jam shows the mechanism for a moment
	end
	el.WasJammed = weapon.Jammed
end

-- Hold to look the weapon over; `seconds` shows it for a while without a key.
function Hud.Check(held, seconds)
	if held ~= nil then
		checkHeld = held
	end
	if seconds then
		el.CheckUntil = os.clock() + seconds
		checkToken += 1
		local token = checkToken
		task.delay(seconds + 0.05, function()
			if token == checkToken then
				setCheck()
			end
		end)
	end
	setCheck()
end

function Hud.Checking()
	return el.Check.Visible
end

-- ===== body =====
function Hud.Health(share)
	share = math.clamp(share, 0, 1)
	el.Health.Size = UDim2.fromOffset(150 * share, 3)
	el.Health.BackgroundColor3 = if share < 0.35 then RED elseif share < 0.65 then AMBER else WHITE
end

function Hud.Stance(stance)
	-- one stroke: upright, half height, or lying flat
	if stance == "Prone" then
		el.StanceMark.Size, el.StanceMark.Position = UDim2.fromOffset(14, 3), UDim2.fromOffset(160, 34)
	elseif stance == "Crouch" then
		el.StanceMark.Size, el.StanceMark.Position = UDim2.fromOffset(3, 8), UDim2.fromOffset(160, 29)
	else
		el.StanceMark.Size, el.StanceMark.Position = UDim2.fromOffset(3, 14), UDim2.fromOffset(160, 23)
	end
	el.StanceName = stance
end

-- ===== centre =====
local crossAt = Vector2.zero
local function placeCross()
	local half = if el.Aiming then 1 else 2
	el.Cross.Position = UDim2.new(0.5, crossAt.X - half, 0.5, crossAt.Y - half)
end
function Hud.Aim(on)
	el.Cross.Size = if on then UDim2.fromOffset(2, 2) else UDim2.fromOffset(4, 4)
	el.Cross.BackgroundTransparency = if on then 0 else 0.25
	el.Aiming = on
	placeCross()
end
-- The dot marks where the bore points, in pixels from the middle of the screen (the gun floats in the view).
function Hud.AimAt(x, y)
	crossAt = Vector2.new(x or 0, y or 0)
	placeCross()
end

function Hud.Flash(word)
	flashToken += 1
	local token = flashToken
	el.Flash.Text, el.Flash.TextTransparency = word, 0
	task.delay(0.45, function()
		if token == flashToken then
			el.Flash.TextTransparency = 1
		end
	end)
end

function Hud.HitMarker(zone, killed)
	el.Hit.TextColor3 = if killed then RED elseif zone == "Head" then AMBER else WHITE
	el.Hit.TextTransparency = 0
	task.delay(0.15, function()
		el.Hit.TextTransparency = 1
	end)
end

function Hud.Hurt()
	el.Hurt.BackgroundTransparency = 0.6
	TweenService:Create(el.Hurt, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

-- ===== top =====
function Hud.Hill(h)
	local share = if h.Holder and h.Need and h.Need > 0 then math.clamp(h.Held / h.Need, 0, 1) else 0
	el.HoldFill.Size = UDim2.fromScale(share, 1)
	el.HoldFill.BackgroundColor3 = (h.Holder and Config.War.FactionColors[h.Holder]) or WHITE
	el.HillLine.Text = ("SECTOR %d . %d v %d . %d:%02d"):format(h.Sector, h.Counts.Union, h.Counts.Pact, h.MovesIn // 60, h.MovesIn % 60)
end

function Hud.Scales(s)
	el.ScaleFill.Size = UDim2.fromScale(math.clamp(s.UnionShare, 0.02, 0.98), 1)
end

function Hud.Banner(words, kind, seconds)
	bannerToken += 1
	local token = bannerToken
	el.Banner.Text, el.Banner.TextColor3, el.Banner.TextTransparency = words, KIND_COLORS[kind] or WHITE, 0
	task.delay(seconds or 5, function()
		if token == bannerToken then
			TweenService:Create(el.Banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- the last few kills stack top right and fade
function Hud.Feed(words)
	local line = text({ Size = UDim2.fromOffset(360, 14), AnchorPoint = Vector2.new(1, 0), Text = words, TextColor3 = DIM, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right })
	table.insert(feedLines, 1, line)
	while #feedLines > 4 do
		table.remove(feedLines):Destroy()
	end
	for i, l in feedLines do
		l.Position = UDim2.new(1, -24, 0, 14 + (i - 1) * 16)
	end
	task.delay(6, function()
		local i = table.find(feedLines, line)
		if i then
			table.remove(feedLines, i)
		end
		TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		Debris:AddItem(line, 0.6)
	end)
end

-- ===== binoculars and marks =====
-- The range to what the dot is on, in metres (empty hides it).
function Hud.Range(metres)
	el.Range.Text = if metres then ("%d m"):format(metres) else ""
end

function Hud.Binoculars(on)
	el.Binos.Visible = on
	el.Cross.Visible = not on
	el.Dwell.Size = UDim2.fromScale(0, 1)
end

function Hud.Dwell(share)
	el.Dwell.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
end

-- A marked figure wears a small red diamond for a few seconds.
function Hud.Mark(model, seconds)
	local anchor = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not anchor then
		return
	end
	local m = marks[model]
	if not m or not m.Gui.Parent then
		local board = make("BillboardGui", { Name = "Mark", Size = UDim2.fromOffset(12, 12), StudsOffset = Vector3.new(0, 2.2, 0), AlwaysOnTop = Config.WarMovement.Binoculars.ThroughWalls, Adornee = anchor, ResetOnSpawn = false }, gui.Parent) -- beside the HUD: a billboard does not draw inside a ScreenGui
		local d = bar({ Size = UDim2.fromOffset(7, 7), Position = UDim2.fromOffset(3, 3), Rotation = 45, BackgroundColor3 = RED }, board)
		d.Name = "Diamond"
		m = { Gui = board, Token = 0 }
		marks[model] = m
	end
	m.Token += 1
	local token = m.Token
	task.delay(seconds, function()
		if m.Token == token then
			m.Gui:Destroy()
			marks[model] = nil
		end
	end)
	return m.Gui
end

function Hud.Marked(model)
	return marks[model] ~= nil
end

Hud.Elements = el
return Hud
