-- Builds (round 5 of docs/Reference-Picks-Plan.md; rules in shared/Builds.lua, tuning in Config.Builds). Gear reads
-- the lineage, vow, practice and implant load in its compute; this module owns everything that changes them:
--   Earn / Bank   xp and credits earned out in the city are carried (data.Carried) until the body is home at its bay
--                 (Hideouts.AtBay); a death loses them (PlayerData.wipe drops the table)
--   Practice      points per kind (data.Practice); levels from shared/Builds.PracticeLevel
--   Chips         data.Chips[skillId] = chipId, fitted and taken out at the bench (Hideouts.AtBench)
--   Vow           data.Vow, sworn and broken at the hideout computer (server/Terminal)
--   Actives       K: the fitted core's Active (Quicken, Spike)
--   Stack         profile.Knowledge.Stack = { { Id, Count } }: the slot the stack keeps through a reboot
--   Grade         profile.Knowledge.Grade (4 .. 0); trials on the Broker's board raise it (server/Terminal)
--   Respec        the basin in the Rootwork, opened by touching its four stones in the riddle's order
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Builds)
local Cybernetics = require(Shared.Cybernetics)
local Items = require(Shared.Items)
local Megacity = require(Shared.Megacity)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Gear = require(script.Parent.Gear)
local Stats = require(script.Parent.Stats)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)

local B = Config.Builds
local Builds = {}
local state = setmetatable({}, { __mode = "k" }) -- player -> { quickUntil, spikeUntil, activeReady, solved = { step, until } }

local function lazy(name)
	return require(script.Parent[name])
end

local function st(player)
	local s = state[player]
	if not s then
		s = { quickUntil = 0, spikeUntil = 0, activeReady = 0, step = 0, solvedUntil = 0 }
		state[player] = s
	end
	return s
end

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function knowledge(data)
	data.Knowledge = data.Knowledge or {}
	data.Knowledge.Stack = data.Knowledge.Stack or {}
	data.Knowledge.Grade = data.Knowledge.Grade or B.Grades.Start
	return data.Knowledge
end

-- ===== lineage =====
function Builds.Ensure(data)
	if type(data.Lineage) ~= "table" then
		local rng = Random.new()
		data.Lineage = Rules.RollLineage(rng:NextNumber(), function(n)
			return rng:NextInteger(1, n)
		end)
	end
	return data.Lineage
end

function Builds.IsEmpty(player)
	local data = PlayerData.Get(player)
	return data ~= nil and type(data.Lineage) == "table" and data.Lineage.Empty == true
end

-- ===== carried earnings =====
function Builds.AtHome(player)
	local root = rootOf(player)
	if not root then
		return false
	end
	local ok, at = pcall(function()
		return lazy("Hideouts").AtBay(player, root.Position)
	end)
	return ok and at == true
end

function Builds.Carried(player)
	local data = PlayerData.Get(player)
	local c = data and data.Carried
	return c and c.Xp or 0, c and c.Credits or 0
end

function Builds.Bank(player)
	local data = PlayerData.Get(player)
	local c = data and data.Carried
	if not c or ((c.Xp or 0) <= 0 and (c.Credits or 0) <= 0) then
		return false
	end
	data.Carried = nil
	if (c.Credits or 0) > 0 then
		data.War.Credits = (data.War.Credits or 0) + c.Credits
	end
	say(player, ("> BANKED . . . %d XP . %d CR"):format(c.Xp or 0, c.Credits or 0), "Reward")
	if (c.Xp or 0) > 0 then
		Stats.AddXp(player, c.Xp) -- pushes the stats
	else
		Stats.Push(player)
	end
	pcall(function()
		lazy("Terminal").Push(player)
	end)
	return true
end

-- Every xp and credit earned in Endeavor comes through here.
function Builds.Earn(player, xp, credits)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	xp, credits = math.floor((xp or 0) + 0.5), math.floor((credits or 0) + 0.5)
	if data.Vow == "LightHand" then
		xp = math.floor(xp * B.Vows.LightXp + 0.5)
	end
	if xp <= 0 and credits <= 0 then
		return
	end
	data.Carried = data.Carried or { Xp = 0, Credits = 0 }
	data.Carried.Xp = (data.Carried.Xp or 0) + xp
	data.Carried.Credits = (data.Carried.Credits or 0) + credits
	if Builds.AtHome(player) then
		Builds.Bank(player)
	else
		Stats.Push(player)
	end
end

-- ===== practice =====
function Builds.Level(player, kind)
	local data = PlayerData.Get(player)
	return Rules.PracticeLevel(kind, data and data.Practice and data.Practice[kind] or 0)
end

function Builds.Practice(player, kind, n)
	local data = PlayerData.Get(player)
	if not (data and B.Practice[kind]) then
		return
	end
	data.Practice = data.Practice or {}
	local before = Rules.PracticeLevel(kind, data.Practice[kind])
	data.Practice[kind] = (data.Practice[kind] or 0) + (n or 1)
	local after = Rules.PracticeLevel(kind, data.Practice[kind])
	if after > before then
		say(player, ("> %s %d"):format(string.upper(kind), after), "Info")
		Gear.Recompute(player)
	end
end

function Builds.ReloadMult(player)
	return math.max(0.5, 1 - Builds.Level(player, "Reload") * B.Practice.Reload.Faster)
end

function Builds.SearchMult(player)
	return math.max(0.4, 1 - Builds.Level(player, "Search") * B.Practice.Search.Faster)
end

-- ===== chips =====
function Builds.ChipOn(player, skillId)
	local data = PlayerData.Get(player)
	local id = data and data.Chips and data.Chips[skillId]
	local chip = id and Rules.Chips[id]
	return if chip and chip.Skill == skillId then id else nil
end

local function atBench(player)
	local root = rootOf(player)
	if not root then
		return false
	end
	local ok, at = pcall(function()
		return lazy("Hideouts").AtBench(player, root.Position)
	end)
	return ok and at == true
end

function Builds.Fit(player, chipId)
	local data = PlayerData.Get(player)
	local chip = Rules.Chips[chipId]
	local Inventory = lazy("Inventory")
	if not (data and chip) or Inventory.Count(player, chipId) <= 0 then
		return false
	end
	if not atBench(player) then
		say(player, "> BENCH", "Warning")
		return false
	end
	data.Chips = data.Chips or {}
	local old = data.Chips[chip.Skill]
	Inventory.Remove(player, chipId, 1)
	data.Chips[chip.Skill] = chipId
	if old and old ~= chipId then
		Inventory.Add(player, old, 1)
	end
	say(player, ("> %s . %s"):format(string.upper(chip.Name), string.upper(Skills.Defs[chip.Skill].Name)), "Reward")
	Gear.Push(player)
	return true
end

function Builds.Unfit(player, skillId)
	local data = PlayerData.Get(player)
	local id = data and data.Chips and data.Chips[skillId]
	if not id then
		return false
	end
	if not atBench(player) then
		say(player, "> BENCH", "Warning")
		return false
	end
	data.Chips[skillId] = nil
	lazy("Inventory").Add(player, id, 1)
	Gear.Push(player)
	return true
end

-- ===== vows =====
function Builds.Swear(player, vowId)
	local data = PlayerData.Get(player)
	if not (data and Rules.Vows[vowId]) or data.Vow == vowId then
		return false, nil
	end
	data.Vow = vowId
	say(player, "> VOW . " .. Rules.Vows[vowId].Name, "Emergence")
	Gear.Recompute(player)
	return true
end

function Builds.Break(player)
	local data = PlayerData.Get(player)
	if not (data and data.Vow) then
		return false, nil
	end
	data.Vow = nil
	say(player, "> VOW . BROKEN", "Warning")
	Gear.Recompute(player)
	return true
end

-- ===== actives (K) =====
function Builds.ActiveOf(player)
	local data = PlayerData.Get(player)
	local core = data and data.Cyber and data.Cyber.Core
	local piece = core and Cybernetics.Pieces[core]
	if not (piece and piece.Active) then
		return nil
	end
	local d = Gear.Get(player)
	if d.Overloaded and d.Overloaded.Core then
		return nil -- past the load limit the core does nothing
	end
	return piece.Active
end

function Builds.Active(player)
	local char = player.Character
	local kind = Builds.ActiveOf(player)
	if not (char and kind) then
		return false
	end
	local s, t, def = st(player), os.clock(), B.Actives[kind]
	if t < s.activeReady then
		return false
	end
	s.activeReady = t + def.Cooldown
	if kind == "Quicken" then
		s.quickUntil = t + def.Seconds
	elseif kind == "Spike" then
		s.spikeUntil = t + def.Window
	end
	char:SetAttribute("Active", kind)
	task.delay(def.Seconds or def.Window, function()
		if char.Parent and char:GetAttribute("Active") == kind then
			char:SetAttribute("Active", nil)
		end
	end)
	lazy("Combat").FX("Buff", char, kind)
	Remotes.CombatEvent:FireClient(player, "SkillCD", "Active", def.Cooldown)
	return true
end

function Builds.CooldownMult(player)
	return if os.clock() < st(player).quickUntil then B.Actives.Quicken.CooldownMult else 1
end

-- A skill used inside the Spike window spends it: x Power once.
function Builds.TakeSpike(player)
	local s = st(player)
	if os.clock() < s.spikeUntil then
		s.spikeUntil = 0
		local char = player.Character
		if char and char:GetAttribute("Active") == "Spike" then
			char:SetAttribute("Active", nil)
		end
		return B.Actives.Spike.Power
	end
	return 1
end

-- ===== the stack slot =====
function Builds.Stack(player)
	local data = PlayerData.Get(player)
	return data and knowledge(data).Stack or {}
end

function Builds.Store(player, itemId)
	local data = PlayerData.Get(player)
	local def = Items.Defs[itemId]
	local Inventory = lazy("Inventory")
	if not (data and Rules.StackOk(def)) or Inventory.Count(player, itemId) <= 0 then
		if data and def and not Rules.StackOk(def) then
			say(player, "> STACK . DATA ONLY", "Warning")
		end
		return false
	end
	local stack = knowledge(data).Stack
	local cap = Items.Shape(itemId).Stack
	for _, e in stack do
		if e.Id == itemId and e.Count < cap then
			e.Count += 1
			Inventory.Remove(player, itemId, 1)
			Gear.Push(player)
			return true
		end
	end
	if #stack >= B.Stack.Slots then
		say(player, "> STACK . FULL", "Warning")
		return false
	end
	table.insert(stack, { Id = itemId, Count = 1 })
	Inventory.Remove(player, itemId, 1)
	Gear.Push(player)
	return true
end

function Builds.Unstore(player, index)
	local data = PlayerData.Get(player)
	local stack = data and knowledge(data).Stack
	local e = stack and stack[index]
	if not e then
		return false
	end
	e.Count -= 1
	if e.Count <= 0 then
		table.remove(stack, index)
	end
	lazy("Inventory").Add(player, e.Id, 1)
	Gear.Push(player)
	return true
end

-- A data shard read at home is xp banked at once; out in the city it is just a shard.
function Builds.ReadShard(player)
	if not Builds.AtHome(player) then
		say(player, "> NO TERMINAL", "Warning")
		return false
	end
	Stats.AddXp(player, B.DataShardXp)
	say(player, ("> SHARD READ . %d XP"):format(B.DataShardXp), "Reward")
	return true
end

-- ===== grades =====
function Builds.Grade(player)
	local data = PlayerData.Get(player)
	return if data then knowledge(data).Grade else B.Grades.Start
end

function Builds.SetGrade(player, g)
	local data = PlayerData.Get(player)
	if data then
		knowledge(data).Grade = math.clamp(g, 0, B.Grades.Start)
		Gear.Push(player)
	end
end

function Builds.CanRaid(player)
	return Builds.Grade(player) <= B.Grades.Raid
end

-- ===== the snapshot the client draws (in LoadoutChanged) =====
function Builds.Snapshot(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local d = Gear.Get(player)
	local practice = {}
	for kind in B.Practice do
		practice[kind] = Rules.PracticeLevel(kind, data.Practice and data.Practice[kind] or 0)
	end
	local k = knowledge(data)
	local carriedXp, carriedCr = Builds.Carried(player)
	return {
		Lineage = data.Lineage, Batch = Rules.BatchName(data.Lineage), Grade = Rules.GradeName(k.Grade), Vow = data.Vow and Rules.Vows[data.Vow] and Rules.Vows[data.Vow].Name,
		Load = d.Load, LoadMax = d.LoadMax, Active = Builds.ActiveOf(player), Chips = data.Chips or {}, Practice = practice,
		Carried = { Xp = carriedXp, Credits = carriedCr }, Stack = k.Stack, StackSlots = B.Stack.Slots,
	}
end

-- ===== death =====
-- Before the wipe: a trial in progress fails (the Broker grades the living).
function Builds.OnDeath(player, data)
	local k = data and data.Knowledge
	if k and k.Contracts then
		for id in k.Contracts do
			if id:sub(1, 6) == "Trial_" then
				k.Contracts[id] = nil
			end
		end
	end
end

-- ===== the respec basin in the Rootwork =====
local RIDDLE = { "RAIN", "ROOT", "VINE", "SEED" } -- what falls, what drinks, what climbs, what sleeps
local basin

function Builds.Touch(player, word)
	local s, t = st(player), os.clock()
	if RIDDLE[s.step + 1] == word then
		s.step += 1
		if s.step == #RIDDLE then
			s.step = 0
			s.solvedUntil = t + B.Respec.Window
			if basin then
				basin.Raise()
			end
			return "solved"
		end
		return "step"
	end
	s.step = if word == RIDDLE[1] then 1 else 0
	return "reset"
end

function Builds.Respec(player)
	local data = PlayerData.Get(player)
	if not data or os.clock() > st(player).solvedUntil then
		return false
	end
	if data.Respecced then
		say(player, "> NOTHING LEFT TO RELEASE", "Info")
		return false
	end
	local points = 0
	for name, v in data.Stats do
		points += v
		data.Stats[name] = 0
	end
	data.FreePoints += points
	data.Respecced = true
	st(player).solvedUntil = 0
	say(player, "> ATTRIBUTES . . . RELEASED", "Emergence")
	Gear.Recompute(player)
	return true
end

local function buildBasin()
	local pk
	for _, p in Megacity.Pockets do
		if p.Key == "Rootwork" then
			pk = p
		end
	end
	if not pk then
		return
	end
	local top = Megacity.Top
	local c = pk.Center + Vector3.new(34, 0, -30)
	local model = Instance.new("Model")
	model.Name = "StillBasin"
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do
			p[k] = v
		end
		p.Parent = model
		return p
	end
	local function carve(p, face, text, size)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.PixelsPerStud, gui.LightInfluence = face, 60, 1
		local l = Instance.new("TextLabel")
		l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, size == nil
		l.Text, l.Font, l.TextColor3 = text, Enum.Font.Michroma, Color3.fromRGB(196, 232, 214)
		if size then
			l.TextSize, l.TextWrapped = size, true
		end
		l.Parent = gui
		gui.Parent = p
	end
	-- the stones, in a ring, out of the riddle's order
	local order = { "SEED", "RAIN", "VINE", "ROOT" }
	for i, word in order do
		local a = (i - 1) / #order * math.pi * 2 + 0.3
		local pos = c + Vector3.new(math.cos(a) * 9, top + 2.2, math.sin(a) * 9)
		local stone = part({ Name = "Stone_" .. word, Size = Vector3.new(2.2, 4.4, 1.2), CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)) * CFrame.Angles(0, 0, (i % 2 - 0.5) * 0.08),
			Color = Color3.fromRGB(86, 92, 84), Material = Enum.Material.Slate })
		stone:SetAttribute("Word", word)
		carve(stone, Enum.NormalId.Front, word)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "", "Touch", 0.4
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 7, false, Enum.KeyCode.X
		prompt.Parent = stone
		prompt.Triggered:Connect(function(player)
			local result = Builds.Touch(player, word)
			Remotes.World:FireClient(player, "Stone", stone, result)
		end)
	end
	-- the riddle, cut into a root slab between two of the stones
	local slab = part({ Name = "RiddleSlab", Size = Vector3.new(5, 2.4, 0.8), CFrame = CFrame.lookAt(c + Vector3.new(0, top + 1.2, -13), c + Vector3.new(0, top + 1.2, 0)) * CFrame.Angles(-0.25, 0, 0),
		Color = Color3.fromRGB(70, 60, 48), Material = Enum.Material.Wood })
	carve(slab, Enum.NormalId.Front, "FIRST WHAT FALLS\nTHEN WHAT DRINKS IT\nTHEN WHAT CLIMBS ON IT\nLAST WHAT SLEEPS IN IT", 26)
	-- the basin: under the moss until the stones are answered
	local low, high = c + Vector3.new(0, top - 1.6, 0), c + Vector3.new(0, top + 0.5, 0)
	local bowl = part({ Name = "Basin", Size = Vector3.new(5, 1.2, 5), Position = low, Color = Color3.fromRGB(80, 86, 80), Material = Enum.Material.Slate, Shape = Enum.PartType.Cylinder })
	bowl.CFrame = CFrame.new(low) * CFrame.Angles(0, 0, math.pi / 2)
	local water = part({ Name = "StillWater", Size = Vector3.new(0.2, 4.2, 4.2), CFrame = bowl.CFrame * CFrame.new(0.55, 0, 0), Color = Color3.fromRGB(120, 210, 200), Material = Enum.Material.Glass,
		Transparency = 0.35, CanCollide = false, Shape = Enum.PartType.Cylinder })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "", "Kneel", 2.5
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode, prompt.Enabled = 7, false, Enum.KeyCode.X, false
	prompt.Parent = bowl
	prompt.Triggered:Connect(function(player)
		Builds.Respec(player)
	end)
	local raisedUntil = 0
	basin = { Model = model, Bowl = bowl, Prompt = prompt }
	function basin.Raise()
		raisedUntil = os.clock() + B.Respec.Window
		bowl.CFrame = CFrame.new(high) * CFrame.Angles(0, 0, math.pi / 2)
		water.CFrame = bowl.CFrame * CFrame.new(0.55, 0, 0)
		prompt.Enabled = true
		task.delay(B.Respec.Window + 0.1, function()
			if os.clock() >= raisedUntil then
				bowl.CFrame = CFrame.new(low) * CFrame.Angles(0, 0, math.pi / 2)
				water.CFrame = bowl.CFrame * CFrame.new(0.55, 0, 0)
				prompt.Enabled = false
			end
		end)
	end
	model.Parent = workspace
	return basin
end
Builds.Basin = function()
	return basin
end

-- ===== init =====
function Builds.Init()
	Net.On("Active", { rate = 2, burst = 3 }, Builds.Active)
	Net.On("Build", { rate = 6, burst = 10, args = { "string", "string?" } }, function(player, action, arg)
		if action == "Fit" then
			Builds.Fit(player, arg)
		elseif action == "Unfit" then
			Builds.Unfit(player, arg)
		elseif action == "Store" then
			Builds.Store(player, arg)
		elseif action == "Unstore" then
			Builds.Unstore(player, tonumber(arg) or 0)
		end
	end)
	local ok, err = pcall(buildBasin)
	if not ok then
		warn("[Builds] basin:", err)
	end
	-- practice from running, and banking at home
	task.spawn(function()
		while true do
			task.wait(B.Bank.Every)
			for _, player in Players:GetPlayers() do
				local char, data = player.Character, PlayerData.Get(player)
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if data and root then
					if char:GetAttribute("Sprinting") and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 8 then
						Builds.Practice(player, "Endurance", B.Bank.Every)
					end
					if data.Carried and Builds.AtHome(player) then
						Builds.Bank(player)
					end
				end
			end
		end
	end)
end

return Builds
