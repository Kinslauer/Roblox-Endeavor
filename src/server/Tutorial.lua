-- The arrival: every new conduit rides a train into a dead station and has to get to the control room at the
-- bottom of it without the people stationed there noticing (server/Subway.lua is the place, server/Stealth.lua the
-- rules). It is each player's own level, off the map, whatever the rest of the server is doing; nothing in it is
-- explained. The ride itself is a cutscene the client plays (client/Intro.lua): the server seats the character,
-- waits for Remotes.Intro "Done", opens the doors and lets the guards notice.
--
-- profile.Intro = { Done, Kit, Intel } outlives permadeath: the train is ridden once (Dev "Intro" rides it again).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local Loot = require(script.Parent.Loot)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local Stats = require(script.Parent.Stats)
local Stealth = require(script.Parent.Stealth)
local Subway = require(script.Parent.Subway)
local WorldPhase = require(script.Parent.WorldPhase)

local T = Config.Tutorial

local Tutorial = {}
Tutorial.Finished = Instance.new("BindableEvent") -- (player): out of the station, ready for the city
Tutorial.Spawn = nil -- set by Lifecycle: respawns a player (Dev "Intro")

local contexts = {}

local function introOf(data)
	data.Intro = data.Intro or { Done = false, Kit = false, Intel = false }
	return data.Intro
end

local function needed(player)
	local data = PlayerData.Get(player)
	return T.Enabled and data ~= nil and not introOf(data).Done
end

-- True while the player is (or is about to be) in the station.
function Tutorial.Active(player)
	local ctx = contexts[player]
	if ctx then
		return not ctx.finished
	end
	return needed(player)
end

function Tutorial.Level(player)
	local ctx = contexts[player]
	return ctx and ctx.level
end

local function build(player)
	local used = {}
	for _, c in contexts do
		used[c.slot] = true
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	local level = Subway.Build(T.Origin + Vector3.new(slot * T.Spacing, 0, 0))
	level.Model.Name = "Subway_" .. slot
	level.Model.Parent = workspace
	local ctx = { player = player, slot = slot, level = level, checkpoint = 1, alive = true }
	contexts[player] = ctx

	for _, spec in level.Guards do
		local model = Stealth.SpawnGuard(spec.At, { Level = level.Model, Patrol = spec.Patrol, Post = spec.Post, Wait = spec.Wait, Torch = spec.Torch })
		model:SetAttribute("NoRespawn", true)
	end
	local locker = Loot.Spawn(level.LockerCFrame, T.Locker, {
		Label = "Supply Locker", Action = "Open", Hold = 1, Lifetime = 7200, Size = Vector3.new(4, 5, 3), Color = Color3.fromRGB(230, 170, 40),
	})
	if locker then
		locker.Anchored = true
		locker.Parent = level.Model
		ctx.locker = locker
	end
	level.Breaker:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(who)
		if who == player then
			Stealth.Breaker(player, level.Breaker)
		end
	end)
	level.ConsolePrompt.Triggered:Connect(function(who)
		if who ~= player or ctx.intel then
			return
		end
		ctx.intel = true
		local data = PlayerData.Get(player)
		if data then
			introOf(data).Intel = true
		end
		Tutorial.Consign(player)
		level.ConsolePrompt.Enabled = false
		level.ConsoleText.Text = "> MANIFEST . . . COPIED"
		level.LiftGlow.Color = Color3.fromRGB(80, 230, 140)
		level.LiftPrompt.Enabled = true
		Remotes.World:FireClient(player, "Fragment", "Manifest", T.Manifest.Name, T.Manifest.Text)
	end)
	level.LiftPrompt.Triggered:Connect(function(who)
		if who == player and ctx.intel then
			Tutorial.Finish(player)
		end
	end)
	return ctx
end

-- A copy of the Line 9 manifest in the pack: signing it at a freight-lift bay claims that site and unpacks the
-- consignment into a computer (server/Hideouts.lua). One per life (data.Consigned is wiped with the body), and only
-- for a conduit with no site to go home to.
function Tutorial.Consign(player)
	local data = PlayerData.Get(player)
	if not data or data.Consigned or (data.Hideout and data.Hideout.Plot ~= 0) then
		return false
	end
	data.Consigned = true
	if Inventory.Count(player, "Manifest") == 0 then
		Inventory.Add(player, "Manifest", 1) -- a full pack: it lands at your feet, never lost
		Inventory.Push(player)
	end
	return true
end

-- Where this player spawns while the station has them (nil once it does not).
function Tutorial.SpawnCFrame(player)
	if not Tutorial.Active(player) then
		return nil
	end
	local ctx = contexts[player] or build(player)
	if not ctx.introDone then
		return ctx.level.Seat
	end
	return ctx.level.Checkpoints[ctx.checkpoint]
end

local function endIntro(ctx)
	if ctx.introDone or not ctx.alive then
		return
	end
	ctx.introDone = true
	local char = ctx.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if char then
		char:SetAttribute("Cutscene", nil)
	end
	if root then
		char:PivotTo(ctx.level.Stand)
		root.Anchored = false
	end
	Subway.SetDoors(ctx.level, true)
	ctx.level.CarSign.Text = "> TERMINUS"
	Stealth.Enter(ctx.player, ctx.level.Model)
end

local function watch(ctx)
	while ctx.alive and ctx.player.Parent and not ctx.finished do
		local root = ctx.player.Character and ctx.player.Character:FindFirstChild("HumanoidRootPart")
		if root and ctx.introDone then
			for i = ctx.checkpoint + 1, #ctx.level.Checkpoints do
				if (ctx.level.Checkpoints[i].Position - root.Position).Magnitude < T.CheckpointRadius then
					ctx.checkpoint = i
				end
			end
		end
		task.wait(0.5)
	end
end

-- Called after every (re)spawn while the station has the player.
function Tutorial.Start(player)
	local ctx = contexts[player]
	local data = PlayerData.Get(player)
	if not (ctx and data) or ctx.finished then
		return
	end
	local intro = introOf(data)
	-- The ride always ends with the Whisper in hand: the kit is topped up to T.Kit whenever the train is ridden
	-- (first time, a replay, a new life in the station before the doors have opened), never beyond it.
	if not intro.Kit or not ctx.introDone then
		intro.Kit = true
		for id, count in pairs(T.Kit) do
			local short = count - Inventory.Count(player, id)
			if short > 0 then
				Inventory.Add(player, id, short, true)
			end
		end
		Gear.EquipWeapon(player, T.KitWeapon)
		require(script.Parent.Combat).ResetMags(player) -- a full magazine in it
		Stats.Apply(player)
		Inventory.Push(player)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not ctx.watching then
		ctx.watching = true
		task.spawn(watch, ctx)
	end
	if not ctx.introDone then
		if char and root then
			char:SetAttribute("Cutscene", true)
			root.Anchored = true
			char:PivotTo(ctx.level.Seat)
		end
		Subway.SetDoors(ctx.level, false)
		Remotes.Intro:FireClient(player, "Play", ctx.level.Car, ctx.level.Seat, ctx.level.CarCFrame)
		task.delay(T.IntroTimeout, endIntro, ctx)
	else
		-- back at the last checkpoint: whoever is still standing has gone back to their round
		Stealth.Reset(ctx.level.Model)
		Stealth.Enter(player, ctx.level.Model)
		Remotes.Intro:FireClient(player, "Resume")
	end
end

-- Out through the lift: the station is done, the city is next.
function Tutorial.Finish(player)
	local ctx = contexts[player]
	if not ctx or ctx.finished then
		return
	end
	ctx.finished = true
	local data = PlayerData.Get(player)
	if data then
		introOf(data).Done = true
		data.TutorialDone = true
	end
	Stealth.Leave(player)
	Remotes.Intro:FireClient(player, "End")
	local level = ctx.level
	task.delay(T.CleanupSeconds, function()
		level.Model:Destroy()
		if contexts[player] == ctx then
			contexts[player] = nil
		end
	end)
	WorldPhase.MarkReady(player)
	Tutorial.Finished:Fire(player)
end

-- Rides the train again (Dev panel).
function Tutorial.Replay(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	Tutorial.Release(player)
	local intro = introOf(data)
	intro.Done, intro.Intel = false, false
	if Tutorial.Spawn then
		Tutorial.Spawn(player)
	end
end

function Tutorial.Release(player)
	local ctx = contexts[player]
	if ctx then
		ctx.alive = false
		contexts[player] = nil
		Stealth.Leave(player)
		ctx.level.Model:Destroy()
	end
end

function Tutorial.Init()
	Net.On("Intro", { rate = 2, burst = 4, args = { "string" } }, function(player, what)
		local ctx = contexts[player]
		if ctx and what == "Done" then
			endIntro(ctx)
		end
	end)
	-- the old skip button: straight to the lift
	Net.On("TutorialSkip", { rate = 1, burst = 2 }, function(player)
		local ctx = contexts[player]
		if ctx and Config.Dev.Enabled then
			endIntro(ctx)
			ctx.intel = true
			Tutorial.Consign(player)
			Tutorial.Finish(player)
		end
	end)
end

return Tutorial
