-- HudCombat (brief build-order 4, HUD v2): the part of the HUD that explains combat as it happens.
-- Floating numbers over whoever got hit ("12", "BLOCKED", "PARRIED", "GUARD BREAK", "DODGED"),
-- a centre reticle while the aim stance is on that blinks when one of your attacks lands, and a
-- red edge flash when you take damage. Pure presentation: every number comes from the server's
-- CombatEvent, so what you read is what was applied. Slots live in Presentation.Hud.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local CombatFX = require(script.Parent.CombatFX)
local Aim = require(script.Parent.Aim)
local H = Presentation.Hud

local player = Players.LocalPlayer
local HudCombat = {}

local gui, reticleParts, flash
local reticleHitUntil = 0
local live = 0 -- floating numbers currently on screen

local function isMine(char)
	return char ~= nil and char == player.Character
end

local function rootOf(char)
	return typeof(char) == "Instance" and char:FindFirstChild("Head") or (typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart"))
end

-- -------------------------------------------------------------------------------------------
-- Floating numbers
-- -------------------------------------------------------------------------------------------
function HudCombat.Number(char, text, color, big)
	local D = H.DamageNumbers
	local anchor = rootOf(char)
	if not anchor or live >= D.MaxLive then
		return nil
	end
	local rng = Random.new()
	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageNumber"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-D.Spread, D.Spread), 1.5, rng:NextNumber(-D.Spread, D.Spread))
	bb.Adornee = anchor
	bb.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if big then D.HeavyTextSize else D.TextSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = text
	label.Parent = bb
	bb.Parent = anchor
	live += 1
	Debris:AddItem(bb, D.Life)
	task.delay(D.Life, function()
		live -= 1
	end)
	TweenService:Create(bb, TweenInfo.new(D.Life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, D.Rise, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(D.Life * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, D.Life * 0.6), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	return bb
end

-- -------------------------------------------------------------------------------------------
-- Reticle + hit marker
-- -------------------------------------------------------------------------------------------
local function buildReticle()
	local R = H.Reticle
	local holder = Instance.new("Frame")
	holder.Name = "Reticle"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(0, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	reticleParts = {}
	-- four ticks around the centre; a dot in the middle
	local defs = {
		{ Vector2.new(0, -1), UDim2.fromOffset(R.Thickness, R.Size) },
		{ Vector2.new(0, 1), UDim2.fromOffset(R.Thickness, R.Size) },
		{ Vector2.new(-1, 0), UDim2.fromOffset(R.Size, R.Thickness) },
		{ Vector2.new(1, 0), UDim2.fromOffset(R.Size, R.Thickness) },
	}
	for _, d in defs do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = R.Color
		tick.Size = d[2]
		tick.Parent = holder
		tick:SetAttribute("Dir", d[1])
		table.insert(reticleParts, tick)
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(R.Thickness, R.Thickness)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = R.Color
	dot.Parent = holder
	table.insert(reticleParts, dot)
	HudCombat.Reticle = holder
end

local function layoutReticle(scale, color)
	local R = H.Reticle
	local gap = (R.Gap + R.Size / 2) * scale
	for _, part in reticleParts do
		part.BackgroundColor3 = color
		local dir = part:GetAttribute("Dir")
		if dir then
			part.Position = UDim2.fromOffset(dir.X * gap, dir.Y * gap)
		end
	end
end

function HudCombat.HitMarker()
	reticleHitUntil = os.clock() + H.Reticle.HitSeconds
end

local function stepReticle()
	if not HudCombat.Reticle then
		return
	end
	HudCombat.Reticle.Visible = Aim.Enabled
	if not Aim.Enabled then
		return
	end
	local R = H.Reticle
	local left = reticleHitUntil - os.clock()
	if left > 0 then
		local t = left / R.HitSeconds -- 1 -> 0
		layoutReticle(1 + (R.HitScale - 1) * t, R.HitColor:Lerp(R.Color, 1 - t))
	else
		layoutReticle(1, R.Color)
	end
end

-- -------------------------------------------------------------------------------------------
-- Damage-taken flash
-- -------------------------------------------------------------------------------------------
local function buildFlash()
	local F = H.DamageFlash
	flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = F.Color
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 0
	local grad = Instance.new("UIGradient")
	-- opaque at the edges, clear in the middle: reads as a vignette
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0),
	})
	grad.Parent = flash
	flash.Parent = gui
	HudCombat.Flash = flash
end

function HudCombat.DamageFlash(strength)
	local F = H.DamageFlash
	strength = math.clamp(strength or 1, 0, 1)
	flash.BackgroundTransparency = 1 - F.MaxTransparency * strength
	TweenService:Create(flash, TweenInfo.new(F.Seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- -------------------------------------------------------------------------------------------
-- Handlers
-- -------------------------------------------------------------------------------------------
local function register()
	local C = H.DamageNumbers.Colors
	CombatFX.On("Hit", function(victim, data)
		local amount = typeof(data) == "table" and data.amount or 0
		local attacker = typeof(data) == "table" and data.attacker or nil
		local big = amount >= H.DamageNumbers.HeavyAmount
		if isMine(victim) then
			HudCombat.Number(victim, ("-%d"):format(math.floor(amount + 0.5)), C.Taken, big)
			local hum = victim:FindFirstChildOfClass("Humanoid")
			HudCombat.DamageFlash(if hum then math.clamp(amount / math.max(hum.MaxHealth, 1) * 3, 0.35, 1) else 0.6)
		else
			HudCombat.Number(victim, ("%d"):format(math.floor(amount + 0.5)), if big then C.Heavy else C.Hit, big)
		end
		if isMine(attacker) then
			HudCombat.HitMarker()
		end
	end)
	local function word(kind, text)
		CombatFX.On(kind, function(victim, attacker)
			HudCombat.Number(victim, text, C[kind], false)
			if kind == "GuardBreak" and isMine(victim) then
				HudCombat.DamageFlash(0.5)
			end
			if isMine(attacker) and kind == "GuardBreak" then
				HudCombat.HitMarker()
			end
		end)
	end
	word("Block", "BLOCKED")
	word("Parry", "PARRIED")
	word("GuardBreak", "GUARD BREAK")
	word("Dodged", "DODGED")
	CombatFX.On("BlackFlash", function(attacker, victim)
		-- The server sends Hit (with the multiplied amount) and then BlackFlash. The banner (Impacts)
		-- says BLACK FLASH; here we recolour the number that Hit just put over the victim.
		local anchor = rootOf(victim)
		local latest
		if anchor then
			for _, child in anchor:GetChildren() do
				if child.Name == "DamageNumber" then
					latest = child
				end
			end
		end
		local label = latest and latest:FindFirstChildOfClass("TextLabel")
		if label then
			label.TextColor3 = C.BlackFlash
			label.TextSize = H.DamageNumbers.HeavyTextSize
			label.Text = label.Text .. "!"
		end
		if isMine(attacker) then
			HudCombat.HitMarker()
		end
	end)
end

function HudCombat.Init()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "ConduitCombat", false, true
	gui.DisplayOrder = -1 -- under the main HUD so the flash never covers the bars
	gui.Parent = player:WaitForChild("PlayerGui")
	HudCombat.Gui = gui
	buildFlash()
	buildReticle()
	register()
	RunService.Heartbeat:Connect(stepReticle)
end

return HudCombat
