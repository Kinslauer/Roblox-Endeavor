-- The interface kit: one look for every screen, shared by the client's modules (Main, Stealth, Intro).
-- Flat near-black plates with a hairline edge and corner ticks, wide caps for titles, a condensed face for
-- text, mono for machine text and numbers. One accent (the conduit cyan), amber for warnings, red for harm.
-- Nothing here explains anything: it only draws.
local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Theme = {
	Panel = Color3.fromRGB(9, 11, 15), PanelAlt = Color3.fromRGB(17, 21, 28), Line = Color3.fromRGB(52, 60, 72),
	Text = Color3.fromRGB(228, 232, 238), Dim = Color3.fromRGB(128, 138, 152), Faint = Color3.fromRGB(72, 80, 92),
	Accent = Color3.fromRGB(0, 214, 255), Warn = Color3.fromRGB(255, 178, 56), Harm = Color3.fromRGB(235, 64, 58), Good = Color3.fromRGB(96, 226, 150),
	Button = Color3.fromRGB(26, 32, 42),
	Title = Enum.Font.Michroma, Body = Enum.Font.TitilliumWeb, Mono = Enum.Font.RobotoMono, Bold = Enum.Font.GothamBold,
	PanelAlpha = 0.1, Radius = 3,
}
local UI = Kit.Theme

local root -- the ScreenGui things parent to by default

function Kit.Init(gui)
	root = gui
end

function Kit.corner(inst, r)
	if not inst:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or UI.Radius)
		c.Parent = inst
	end
end

function Kit.stroke(inst, color, transparency, thickness)
	if not inst:FindFirstChildOfClass("UIStroke") then
		local st = Instance.new("UIStroke")
		st.Color, st.Transparency, st.Thickness = color or UI.Line, transparency or 0, thickness or 1
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = inst
	end
end

function Kit.make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent or root
	return inst
end

function Kit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or UI.Text
	props.Font = props.Font or UI.Body
	props.TextSize = props.TextSize or 16
	local parent = props.Parent
	props.Parent = nil
	return Kit.make("TextLabel", props, parent)
end

-- Four small corner ticks on a plate (the kit's signature).
function Kit.ticks(frame, color, length)
	length = length or 10
	color = color or UI.Accent
	local z = (frame.ZIndex or 1) + 1
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local ax, ay = c[1], c[2]
		Kit.make("Frame", { Name = "Tick", Size = UDim2.fromOffset(length, 1), AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, 0, ay, 0), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, frame)
		Kit.make("Frame", { Name = "Tick", Size = UDim2.fromOffset(1, length), AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, 0, ay, 0), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, frame)
	end
end

-- A flat plate: dark, hairline edge, corner ticks.
function Kit.plate(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or UI.PanelAlpha
	props.BorderSizePixel = 0
	local frame = Kit.make("Frame", props, parent)
	Kit.stroke(frame, UI.Line, 0.35)
	Kit.ticks(frame)
	return frame
end

-- A thin gauge: returns the fill (size it with Kit.fill).
function Kit.gauge(parent, position, size, color, back)
	local track = Kit.make("Frame", { Size = size, Position = position, BackgroundColor3 = back or Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ClipsDescendants = true }, parent)
	local fill = Kit.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
	return fill, track
end

function Kit.tween(inst, seconds, props, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Wide-spaced capitals ("E N D E A V O R"): the kit's way of saying a name.
function Kit.spaced(text, gap)
	local out = {}
	for ch in string.gmatch(string.upper(text), ".") do
		table.insert(out, ch)
	end
	return table.concat(out, string.rep(" ", gap or 1))
end

-- A key cap with a word beside it ("[X] TAKEDOWN" without the brackets).
function Kit.keyHint(parent, key, word, position)
	local holder = Kit.make("Frame", { Size = UDim2.fromOffset(200, 26), Position = position or UDim2.new(), BackgroundTransparency = 1 }, parent)
	local cap = Kit.make("TextLabel", { Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UI.Panel, BackgroundTransparency = 0.1, Text = key, Font = UI.Bold, TextSize = 13, TextColor3 = UI.Text, BorderSizePixel = 0 }, holder)
	Kit.corner(cap, 3)
	Kit.stroke(cap, UI.Accent, 0.2)
	local text = Kit.label({ Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(32, 0), Text = word, Font = UI.Title, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
	Kit.make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }, text)
	return holder, cap, text
end

return Kit
