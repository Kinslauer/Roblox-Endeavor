-- Reprogrammed thralls on the Front (round 7 of docs/Reference-Picks-Plan.md; Andy, docs/LORE.md Truth: a trapped
-- enemy can be "reprogrammed and sent to the Front to fight for its conduit"). Endeavor's server/Thralls writes them
-- into the shared profile (data.War.Thralls = { { Type, Name } }). When the conduit's recruit is placed on the field
-- (Soldiers.Place), up to Config.Make.Thrall.Front.Max of them stand up at its base in its side's kit and push to the
-- hill: they walk, take cover nowhere, and shoot the other side's recruits in sight. A thrall that falls is gone from
-- the profile (it dies for good, like a recruit) and calcifies like any of the fallen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Assets = require(Shared.Assets)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)

local F = Config.Make.Thrall.Front
local Thralls = {}
local fielded = {} -- player -> { { Model, Hum, Root, Name, NextFire, NextMove } }
local rng = Random.new()

local function lazy(name)
	return require(script.Parent[name])
end

local function body(name, faction, cf)
	local ok, model, hum, root = pcall(function()
		local Rigs = require(script.Parent.Common.Rigs)
		local m, h, r = Rigs.Build(Assets.Rigs.Soldier, name, "Recruit")
		if m then
			Rigs.Layer(m, if faction == "Pact" then "PactKit" else "UnionKit")
			Rigs.Dress(m, { Attire = true, Kit = true, Helmet = true })
			m:PivotTo(cf + Vector3.new(0, h.HipHeight - 2, 0))
			m.Parent = workspace
			Rigs.Animate(m, h, true)
		end
		return m, h, r
	end)
	if ok and model then
		return model, hum, root
	end
	-- a plain figure when the rig fails
	model = Instance.new("Model")
	model.Name = name
	root = Instance.new("Part")
	root.Name, root.Size, root.CFrame = "HumanoidRootPart", Vector3.new(2, 2, 1), cf
	root.Color = if faction == "Pact" then Color3.fromRGB(150, 120, 80) else Color3.fromRGB(90, 100, 70)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name, head.Size, head.CFrame, head.Color = "Head", Vector3.new(1, 1, 1), cf * CFrame.new(0, 1.5, 0), root.Color
	head.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = root, head, head
	hum = Instance.new("Humanoid")
	hum.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	return model, hum, root
end

local function enemyOf(owner)
	return function(p)
		local Factions = lazy("Factions")
		return p ~= owner and Factions.Of(p) ~= nil and Factions.Of(p) ~= Factions.Of(owner)
	end
end

-- Stands the conduit's thralls up at its side's base (called from Soldiers.Place).
function Thralls.Field(player)
	local data = PlayerData.Get(player)
	local list = data and data.War.Thralls
	if not (list and #list > 0) then
		return 0
	end
	Thralls.Recall(player)
	local Factions, Battlefield = lazy("Factions"), lazy("Battlefield")
	local faction = Factions.Of(player)
	local base = Battlefield.BaseCFrame(faction)
	local mine = {}
	for i = 1, math.min(F.Max, #list) do
		local t = list[i]
		local cf = base * CFrame.new((i - 1.5) * 5, 0, 4)
		local model, hum, root = body(t.Name, faction, cf)
		model:SetAttribute("Owner", player.UserId)
		model:SetAttribute("Thrall", t.Name)
		model:SetAttribute("Faction", faction)
		hum.MaxHealth, hum.Health = F.Health, F.Health
		hum.WalkSpeed = 12
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local th = { Model = model, Hum = hum, Root = root, Name = t.Name, NextFire = os.clock() + 2, NextMove = 0 }
		table.insert(mine, th)
		hum.Died:Once(function()
			th.Dead = true
			local d = PlayerData.Get(player)
			for j, v in d and d.War.Thralls or {} do
				if v.Name == t.Name then
					table.remove(d.War.Thralls, j)
					break
				end
			end
			pcall(function()
				lazy("Battlefield").Fallen(root.Position)
			end)
			if player.Parent then
				Remotes.Announce:FireClient(player, "> " .. t.Name .. " . LOST", "Warning")
			end
			task.delay(8, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end)
	end
	fielded[player] = mine
	return #mine
end

function Thralls.Recall(player)
	for _, th in fielded[player] or {} do
		if th.Model.Parent then
			th.Model:Destroy()
		end
	end
	fielded[player] = nil
end

function Thralls.Fielded(player)
	return fielded[player] or {}
end

local function think(player, th)
	if th.Dead or not th.Root.Parent then
		return
	end
	local now = os.clock()
	local here = th.Root.Position
	local isEnemy = enemyOf(player)
	local target, best = nil, F.Range
	for _, p in Players:GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and isEnemy(p) and (r.Position - here).Magnitude < best then
			target, best = p, (r.Position - here).Magnitude
		end
	end
	if now >= th.NextMove then
		th.NextMove = now + rng:NextNumber(3, 5)
		local okH, crest = pcall(function()
			return lazy("Battlefield").Crest(lazy("Hill").Current())
		end)
		local goal = if okH and typeof(crest) == "Vector3" then crest else here
		local to = goal - here
		if to.Magnitude > F.Hold then
			local side = Vector3.new(-to.Z, 0, to.X).Unit
			local step = here + to.Unit * math.min(to.Magnitude, rng:NextNumber(14, 24)) + side * rng:NextNumber(-8, 8)
			th.Hum:MoveTo(step)
		end
	end
	if target and now >= th.NextFire then
		th.NextFire = now + F.FireSeconds * rng:NextNumber(0.8, 1.3)
		local char = target.Character
		local aim = char.HumanoidRootPart.Position + Vector3.new(0, 1.2, 0)
		local eye = here + Vector3.new(0, 1.6, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { th.Model }
		local hit = workspace:Raycast(eye, (aim - eye), params)
		if hit and not hit.Instance:IsDescendantOf(char) then
			return -- cover takes it
		end
		Remotes.Weapon:FireAllClients("Shot", th.Model, eye, (aim - eye).Unit, 0.7)
		if rng:NextNumber() < F.Accuracy * math.clamp(40 / math.max(best, 1), 0.3, 1.2) then
			local roll = rng:NextNumber()
			local zone = if roll < 0.08 then "Head" elseif roll < 0.75 then "Torso" else "Limb"
			lazy("Soldiers").Damage(char, F.Damage * (if zone == "Head" then 2 elseif zone == "Limb" then 0.6 else 1), player, zone, 0.4, "Bullet")
		end
	end
end

function Thralls.Init()
	Players.PlayerRemoving:Connect(Thralls.Recall)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, list in fielded do
				for _, th in list do
					local ok, err = pcall(think, player, th)
					if not ok then
						warn("[Thralls] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return Thralls
