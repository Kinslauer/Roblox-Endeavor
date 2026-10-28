-- The prologue tutorial. Runs in each player's private room (see WorldPhase) while the game
-- still feels single-player. A scripted sequence teaches the real systems by making the
-- player use them against a training dummy that fights back, then marks the player "ready";
-- once everyone is ready the world opens (WorldPhase.CheckReady).
--
-- Steps are data: Setup() runs when the step starts, Done() is polled, Text can be a function
-- of the context so progress counters stay live. Combat/inventory events bump ctx.counts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Lore = require(ReplicatedStorage.Shared.Lore)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Combat = require(script.Parent.Combat)
local Inventory = require(script.Parent.Inventory)
local Loot = require(script.Parent.Loot)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.PlayerData)
local RateLimit = require(script.Parent.RateLimit)
local WorldPhase = require(script.Parent.WorldPhase)

local T = Config.Tutorial
local POLL = 0.25

local Tutorial = {}
local contexts = {}

local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function count(ctx, key)
	return ctx.counts[key] or 0
end

local function bump(ctx, key)
	ctx.counts[key] = count(ctx, key) + 1
end

local function highlight(ctx, target)
	if ctx.highlight then
		ctx.highlight:Destroy()
		ctx.highlight = nil
	end
	if target then
		local h = Instance.new("Highlight")
		h.FillColor, h.FillTransparency = Color3.fromRGB(0, 220, 255), 0.55
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = target
		ctx.highlight = h
	end
end

local function restore(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
		char:SetAttribute("Stamina", char:GetAttribute("MaxStamina"))
		char:SetAttribute("Posture", 0)
	end
end

local function topUpCharge(player, minimum)
	local char = player.Character
	if char and (char:GetAttribute("Charge") or 0) < minimum then
		char:SetAttribute("Charge", minimum + 20) -- the tutorial pays for your flicks
	end
end

-- ===== Room props =====
local function prop(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function buildProps(ctx)
	local plot, origin = WorldPhase.GetPlot(ctx.player), WorldPhase.GetOrigin(ctx.player)
	ctx.plot = plot

	ctx.console = prop(plot, {
		Name = "Console", Size = Vector3.new(4, 5, 2), Position = origin + Vector3.new(20, 3.5, -20),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(0, 220, 255),
	})

	ctx.locker = Loot.Spawn(CFrame.new(origin + Vector3.new(-20, 3.5, 12)), { Cloth = 2, Scrap = 1, ScrapVest = 1 }, {
		Label = "Supply Locker", Action = "Open", Hold = 1, Lifetime = 7200,
		Size = Vector3.new(4, 5, 3), Color = Color3.fromRGB(230, 170, 40),
	})
	ctx.locker.Anchored = true
	ctx.locker.Parent = plot

	local model, hum, root = NPCs.BuildRig("Training Dummy", { Health = 1000, Speed = 0 })
	root.Anchored = true
	local pos = origin + Vector3.new(0, 3.5, -14)
	model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10))) -- faces the player's spawn
	model.Parent = plot
	ctx.dummy, ctx.dummyHum = model, hum
end

-- The dummy regenerates and, in defence steps, strikes with a red telegraph.
local function runDummy(ctx)
	task.spawn(function()
		while ctx.alive and ctx.dummy.Parent do
			task.wait(T.DummyInterval)
			if ctx.dummyHum.Health < ctx.dummyHum.MaxHealth * 0.5 then
				ctx.dummyHum.Health = ctx.dummyHum.MaxHealth
			end
			local hum = ctx.player.Character and ctx.player.Character:FindFirstChildOfClass("Humanoid")
			if ctx.strike and hum and hum.Health > 0 then
				if hum.Health < hum.MaxHealth * 0.4 then
					hum.Health = hum.MaxHealth * 0.7 -- never let the tutorial kill anyone
				end
				local warn = Instance.new("Highlight")
				warn.FillColor, warn.OutlineColor = Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 40, 40)
				warn.FillTransparency = 0.3
				warn.Parent = ctx.dummy
				task.wait(T.DummyTelegraph)
				warn:Destroy()
				local char = ctx.player.Character
				if ctx.strike and ctx.alive and char then
					Combat.Damage(ctx.dummy, char, T.DummyDamage, { Posture = T.DummyPosture })
				end
			end
		end
	end)
end

-- ===== Steps =====
local function dataOf(ctx)
	return PlayerData.Get(ctx.player)
end

local function pointsSpent(ctx)
	local data = dataOf(ctx)
	return data and math.clamp(Config.Stats.StartingPoints - data.FreePoints, 0, 99) or 0
end

local function finish(ctx)
	local data = dataOf(ctx)
	if data then
		data.TutorialDone = true
	end
	WorldPhase.MarkReady(ctx.player)
end

local STEPS = {
	{
		Title = "Wake up",
		Lore = "WakeUp",
		Text = "Use WASD to walk to the glowing console.",
		Setup = function(ctx) highlight(ctx, ctx.console) end,
		Done = function(ctx)
			local root = rootOf(ctx.player)
			return root ~= nil and (root.Position - ctx.console.Position).Magnitude < 8
		end,
	},
	{
		Title = "Attributes",
		Text = function(ctx)
			return ("Press J and spend at least 5 attribute points with the + buttons (%d/5). Stats and gear decide your skills."):format(math.min(5, pointsSpent(ctx)))
		end,
		Done = function(ctx) return pointsSpent(ctx) >= 5 end,
	},
	{
		Title = "Loot",
		Text = "Hold X on the supply locker to open it. Interact is X because E is for flicking.",
		Setup = function(ctx) highlight(ctx, ctx.locker) end,
		Done = function(ctx) return ctx.locker.Parent == nil end,
	},
	{
		Title = "Crafting",
		Text = "Press Tab and Craft a Medkit (2 Torn Cloth + 1 Scrap).",
		Done = function(ctx) return count(ctx, "craft_Medkit") >= 1 end,
	},
	{
		Title = "Armor",
		Text = "In the Tab menu, Wear the Scrap Vest. Armor sets resistances and its tags unlock skills (L shows your loadout).",
		Done = function(ctx)
			local data = dataOf(ctx)
			return data ~= nil and next(data.Armor) ~= nil
		end,
	},
	{
		Title = "Attack",
		Lore = "FirstSwing",
		Text = function(ctx) return ("Left-click to strike the dummy: chain 4 hits (%d/4). Your weapon decides the combo."):format(math.min(4, count(ctx, "dummyHit"))) end,
		Setup = function(ctx) highlight(ctx, ctx.dummy) end,
		Done = function(ctx) return count(ctx, "dummyHit") >= 4 end,
	},
	{
		Title = "Heavy",
		Text = "Right-click for a heavy attack. Heavies are criticals: they crush blocks.",
		Setup = function(ctx) highlight(ctx, ctx.dummy) end,
		Done = function(ctx) return count(ctx, "heavyHit") >= 1 end,
	},
	{
		Title = "Flicker",
		Lore = "Flicker",
		Text = function(ctx)
			local level = ctx.player.Character and ctx.player.Character:GetAttribute("Flicker") or 0
			return ("Swing, and watch your hand: when the glow turns red, tap E so the flick lands WITH the hit. Three flicked hits in a row = BLACK FLASH. Chain: %d/3"):format(level)
		end,
		Setup = function(ctx)
			highlight(ctx, ctx.dummy)
			topUpCharge(ctx.player, 40)
		end,
		Tick = function(ctx) topUpCharge(ctx.player, 20) end,
		Done = function(ctx) return count(ctx, "BlackFlash") >= 1 end,
	},
	{
		Title = "Dodge",
		Text = function(ctx) return ("The dummy strikes after a red flash. Press Q as it flashes to dodge (%d/2)."):format(math.min(2, count(ctx, "dodged"))) end,
		Strike = true,
		Done = function(ctx) return count(ctx, "dodged") >= 2 end,
	},
	{
		Title = "Parry",
		Text = function(ctx) return ("Face the dummy and tap F right before the red flash ends to PARRY (%d/2). Parries stagger it - and beat a Black Flash."):format(math.min(2, count(ctx, "parried"))) end,
		Strike = true,
		Done = function(ctx) return count(ctx, "parried") >= 2 end,
	},
	{
		Title = "Block",
		Text = function(ctx) return ("Face the dummy and HOLD F to block its strikes (%d/2). Blocking fills your posture bar - when it fills, your guard breaks."):format(math.min(2, count(ctx, "blocked"))) end,
		Strike = true,
		Done = function(ctx) return count(ctx, "blocked") >= 2 end,
	},
	{
		Title = "Feint",
		Text = function(ctx) return ("Start a swing, then press Z during the windup to cancel it and refund stamina (%d/2). Make them flinch."):format(math.min(2, count(ctx, "Feint"))) end,
		Setup = function(ctx) highlight(ctx, ctx.dummy) end,
		Done = function(ctx) return count(ctx, "Feint") >= 2 end,
	},
	{
		Title = "Skills",
		Text = "Use your skill: press T. Skills unlock from your stats and armor tags and scale with both.",
		Skip = function(ctx)
			local data = dataOf(ctx)
			return data == nil or next(data.SkillSlots) == nil -- nothing unlocked yet
		end,
		Setup = function(ctx)
			highlight(ctx, ctx.dummy)
			topUpCharge(ctx.player, 60)
		end,
		Done = function(ctx) return count(ctx, "skill") >= 1 end,
	},
	{
		Title = "Ready",
		Text = "That's everything. Something is stirring beyond these walls...",
		Setup = finish,
		Done = function() return false end,
	},
}

-- ===== Runner =====
local function send(ctx, step, text)
	Remotes.Tutorial:FireClient(ctx.player, ctx.index, #STEPS, step.Title, text)
	ctx.lastSent = text
end

local function run(ctx)
	while ctx.alive and ctx.player.Parent and ctx.plot.Parent and not WorldPhase.IsOpen() do
		local step = STEPS[ctx.index]
		if step.Skip and step.Skip(ctx) then
			ctx.index += 1
			continue
		end
		if ctx.begun ~= ctx.index then
			ctx.begun = ctx.index
			ctx.counts = {}
			ctx.strike = step.Strike == true
			highlight(ctx, nil)
			if ctx.strike then
				restore(ctx.player)
			end
			if step.Setup then
				step.Setup(ctx)
			end
			if step.Lore then
				Remotes.Announce:FireClient(ctx.player, Lore.Get(step.Lore), "Lore")
			end
			ctx.lastSent = nil
		end
		if step.Tick then
			step.Tick(ctx)
		end
		local text = if type(step.Text) == "function" then step.Text(ctx) else step.Text
		if text ~= ctx.lastSent then
			send(ctx, step, text)
		end
		if step.Done(ctx) then
			ctx.index += 1
		end
		task.wait(POLL)
	end
	-- phase opened, player left, or the plot is gone
	ctx.alive = false
	highlight(ctx, nil)
	if ctx.player.Parent then
		Remotes.Tutorial:FireClient(ctx.player, nil)
	end
end

-- Called after every (re)spawn in the prologue. Safe to call repeatedly.
function Tutorial.Start(player)
	local existing = contexts[player]
	if existing then
		existing.lastSent = nil -- resend the current step to the fresh character
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if data.TutorialDone and not Config.Tutorial.ReplayAlways then
		WorldPhase.MarkReady(player) -- returning player: nothing to teach
		return
	end
	local ctx = { player = player, alive = true, index = 1, counts = {}, heavyUntil = 0 }
	contexts[player] = ctx
	buildProps(ctx)
	runDummy(ctx)
	task.spawn(run, ctx)
end

function Tutorial.Release(player)
	local ctx = contexts[player]
	if ctx then
		ctx.alive = false
		contexts[player] = nil
	end
end

function Tutorial.Init()
	Remotes.TutorialSkip.OnServerEvent:Connect(RateLimit.Wrap("TutorialSkip", Config.RateLimit.TutorialSkip, function(player)
		local ctx = contexts[player]
		if ctx then
			ctx.index = #STEPS
		end
	end))

	Combat.Resolved.Event:Connect(function(attacker, victim, result)
		for player, ctx in contexts do
			local char = player.Character
			if char and ctx.alive then
				if victim == char and attacker == ctx.dummy then
					bump(ctx, result) -- dodged / parried / blocked / guardbreak / hit
				elseif attacker == char and victim == ctx.dummy and (result == "hit" or result == "guardbreak") then
					bump(ctx, "dummyHit")
					if os.clock() < ctx.heavyUntil then
						bump(ctx, "heavyHit")
					end
				end
			end
		end
	end)

	Combat.Used.Event:Connect(function(name, player)
		local ctx = contexts[player]
		if not ctx then
			return
		end
		if name == "Heavy" then
			ctx.heavyUntil = os.clock() + 1.5
		elseif name == "Feint" or name == "BlackFlash" then
			bump(ctx, name)
		elseif Skills.Defs[name] then
			bump(ctx, "skill")
		end
	end)

	Inventory.Crafted.Event:Connect(function(player, itemId)
		local ctx = contexts[player]
		if ctx then
			bump(ctx, "craft_" .. itemId)
		end
	end)
end

return Tutorial
