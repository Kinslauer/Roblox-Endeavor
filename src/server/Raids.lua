-- Raids (Phase 3, build order 6; design/gdd/raids.md, shared/Raids.lua): the contracts on the hideout
-- computer's board, the one you are running, and how it ends.
--   * BOARD (profile.Board, persists): BoardSize contracts drawn from the templates; refilled as you take
--     them. Intel (an item rival crews drop) puts a named contract on the board directly.
--   * RAID (profile.Raid, dies with the body): the accepted contract as a chain of steps + "extract".
--     Kill steps come from NPCs.Killed; reach / hold steps from a 1 Hz position watch with a beacon at
--     the point. When the objectives are done a LEAD may be offered: extract now for the reward, or do
--     the lead's first objective and the raid continues into it (Bonus on the money at the end).
--   * EXTRACTION: a station (Hideout.Extract) or a train (Transport.Ride) while on the extract step pays
--     every contract in the chain. Terminal.lua owns the UI; this module owns the rules.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Enemies)
local Items = require(Shared.Items)
local R = require(Shared.Raids)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.PlayerData)
local Stats = require(script.Parent.Stats)
local Wallet = require(script.Parent.Wallet)

local Raids = {}
Raids.Changed = Instance.new("BindableEvent") -- (player) after any board / raid change; Terminal re-pushes

local rng = Random.new()
local markers = {} -- player -> Part

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

local function fire(player)
	Raids.Changed:Fire(player)
end

-- ---------------------------------------------------------------------------------------------
-- The board
-- ---------------------------------------------------------------------------------------------
local function onBoard(data, id)
	for _, entry in data.Board do
		if entry.Id == id then
			return true
		end
	end
	return false
end

function Raids.Board(player)
	local data = PlayerData.Get(player)
	if not data then
		return {}
	end
	data.Board = data.Board or {}
	local pool = {}
	for _, t in R.Templates do
		if not onBoard(data, t.Id) and not (data.Raid and data.Raid.Id == t.Id) then
			table.insert(pool, t)
		end
	end
	while #data.Board < R.BoardSize and #pool > 0 do
		local i = rng:NextInteger(1, #pool)
		table.insert(data.Board, { Id = pool[i].Id })
		table.remove(pool, i)
	end
	return data.Board
end

-- Intel read: a specific contract lands on the board, contact or no contact.
function Raids.AddIntel(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	Raids.Board(player)
	local pool = {}
	for _, t in R.Templates do
		if not onBoard(data, t.Id) and not (data.Raid and data.Raid.Id == t.Id) then
			table.insert(pool, t)
		end
	end
	local t = if #pool > 0 then pool[rng:NextInteger(1, #pool)] else R.Templates[rng:NextInteger(1, #R.Templates)]
	table.insert(data.Board, 1, { Id = t.Id, FromIntel = true })
	announce(player, ("Intel read: \"%s\" is on your board."):format(t.Name), "Info")
	fire(player)
	return t
end

-- ---------------------------------------------------------------------------------------------
-- The raid
-- ---------------------------------------------------------------------------------------------
local function clone(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then clone(v) else v
	end
	return out
end

local function current(data)
	local raid = data and data.Raid
	return raid, raid and raid.Steps[raid.Step]
end

local function line(raid)
	local step = raid.Steps[raid.Step]
	local text = R.StepText(step)
	if step.Kind == "kill" then
		text ..= (" (%d/%d)"):format(raid.Progress, step.Count)
	elseif step.Kind == "hold" then
		text ..= (" (%d/%d s)%s"):format(math.floor(raid.Hold or 0), step.Seconds, if raid.Contested then "  ·  contested" else "")
	end
	return ("%s  ·  %s"):format(R.ById[raid.Id].Name, text)
end

local function clearMarker(player)
	if markers[player] then
		markers[player]:Destroy()
		markers[player] = nil
	end
end

local function marker(player, step)
	clearMarker(player)
	local point = step and step.Point and R.Points[step.Point]
	if not point then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "RaidMarker_" .. player.Name
	beam.Anchored, beam.CanCollide, beam.CanQuery = true, false, false
	beam.Size = Vector3.new(1.2, 60, 1.2)
	beam.Position = point + Vector3.new(0, 32, 0)
	beam.Material, beam.Color, beam.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 220, 120), 0.35
	beam:SetAttribute("Owner", player.UserId)
	beam.Parent = workspace
	markers[player] = beam
end

function Raids.Sync(player)
	local data = PlayerData.Get(player)
	local raid, step = current(data)
	player:SetAttribute("RaidLine", if raid then line(raid) else nil)
	if raid and step then
		marker(player, step)
	else
		clearMarker(player)
	end
end

function Raids.Accept(player, index)
	local data = PlayerData.Get(player)
	if not data or data.Raid then
		if data and data.Raid then
			announce(player, "Finish or abandon the raid you are on first.")
		end
		return false
	end
	local board = Raids.Board(player)
	local entry = board[index]
	local t = entry and R.ById[entry.Id]
	if not t then
		return false
	end
	if not (entry.FromIntel or (data.Contacts and data.Contacts[t.Contact or "Broker"])) then
		announce(player, "You do not know anyone who could vouch for that contract yet.")
		return false
	end
	table.remove(board, index)
	local steps = clone(t.Steps)
	table.insert(steps, { Kind = "extract" })
	data.Raid = { Id = t.Id, Steps = steps, Step = 1, Progress = 0, Hold = 0, Chain = { t.Id }, Bonus = 1 }
	Raids.Board(player)
	announce(player, ("Raid taken: %s. %s"):format(t.Name, t.Text), "Info")
	Raids.Sync(player)
	fire(player)
	return true
end

function Raids.Abandon(player)
	local data = PlayerData.Get(player)
	if not (data and data.Raid) then
		return false
	end
	announce(player, ("Raid dropped: %s."):format(R.ById[data.Raid.Id].Name))
	data.Raid = false
	Raids.Sync(player)
	fire(player)
	return true
end

local function matches(step, kind, target)
	if not step or step.Kind ~= kind then
		return false
	end
	if kind == "kill" then
		local def = Enemies.Defs[target]
		return step.Target == target or (def ~= nil and def.QuestTag == step.Target)
	end
	return true
end

-- The objectives are done: offer a lead (continuation) or a plain extraction.
local function offerLead(player, data, raid)
	local extract = raid.Steps[#raid.Steps]
	if rng:NextNumber() < R.LeadChance then
		local pool = {}
		for _, t in R.Templates do
			if not table.find(raid.Chain, t.Id) then
				table.insert(pool, t)
			end
		end
		if #pool > 0 then
			local t = pool[rng:NextInteger(1, #pool)]
			extract.Lead = t.Id
			announce(player, ("Objectives done. A lead turned up: \"%s\" - %s Follow it, or extract and get paid."):format(t.Name, t.Text), "Info")
			return
		end
	end
	announce(player, "Objectives done. Get to a station and extract.", "Info")
end

-- Following a lead: the raid continues into the lead's steps, with the bonus.
local function follow(player, data, raid)
	local extract = raid.Steps[#raid.Steps]
	local t = R.ById[extract.Lead]
	extract.Lead = nil
	table.remove(raid.Steps, #raid.Steps)
	for _, s in clone(t.Steps) do
		table.insert(raid.Steps, s)
	end
	table.insert(raid.Steps, { Kind = "extract" })
	raid.Step = #raid.Steps - #t.Steps
	raid.Progress, raid.Hold = 0, 0
	raid.Bonus *= R.LeadBonus
	table.insert(raid.Chain, t.Id)
	announce(player, ("Following the lead: %s. The pay stacks."):format(t.Name), "Info")
end

local function advance(player, data, raid)
	raid.Step += 1
	raid.Progress, raid.Hold = 0, 0
	if raid.Steps[raid.Step].Kind == "extract" then
		offerLead(player, data, raid)
	else
		announce(player, R.StepText(raid.Steps[raid.Step]), "Info")
	end
	Raids.Sync(player)
	fire(player)
end

-- A kill / reach / hold event for this player. `amount` = kills or seconds.
function Raids.Progress(player, kind, target, amount)
	local data = PlayerData.Get(player)
	local raid, step = current(data)
	if not raid then
		return
	end
	-- on the extract step with a lead: the lead's first step can pull you on
	if step.Kind == "extract" and step.Lead then
		local first = R.ById[step.Lead].Steps[1]
		if matches(first, kind, target) then
			follow(player, data, raid)
			step = raid.Steps[raid.Step]
		else
			return
		end
	end
	if not matches(step, kind, target) then
		return
	end
	if kind == "kill" then
		raid.Progress += amount or 1
		if raid.Progress >= step.Count then
			advance(player, data, raid)
		else
			Raids.Sync(player)
			fire(player)
		end
	elseif kind == "reach" then
		advance(player, data, raid)
	elseif kind == "hold" then
		raid.Hold = (raid.Hold or 0) + (amount or 1)
		if raid.Hold >= step.Seconds then
			advance(player, data, raid)
		else
			Raids.Sync(player)
		end
	end
end

-- Called by the stations and the trains: a raid on its extract step pays out.
function Raids.OnExtract(player)
	local data = PlayerData.Get(player)
	local raid, step = current(data)
	if not (raid and step and step.Kind == "extract") then
		return false
	end
	local money, xp, items = 0, 0, {}
	for _, id in raid.Chain do
		local reward = R.ById[id].Reward
		money += reward.Money or 0
		xp += reward.Xp or 0
		for item, n in reward.Items or {} do
			items[item] = (items[item] or 0) + n
		end
	end
	money = math.floor(money * raid.Bonus + 0.5)
	Wallet.Add(player, money)
	Stats.AddXp(player, xp)
	Inventory.AddAll(player, items)
	announce(player, ("Raid complete: %s. +%d money, +%d xp%s."):format(table.concat(raid.Chain, " → "), money, xp, if #raid.Chain > 1 then (" (x%.1f for the lead)"):format(raid.Bonus) else ""), "Info")
	data.Raid = false
	Raids.Sync(player)
	fire(player)
	return true
end

-- A rival crew working the same point: a hold does not count while one of them stands inside it.
-- (Rivals.lua walks crews between the raid points, so this happens on its own.)
local function contested(point, radius)
	for _, model in CollectionService:GetTagged(NPCs.Tag) do
		if model:GetAttribute("EnemyType") == "Rival" then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum = model:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and Vector3.new(root.Position.X - point.X, 0, root.Position.Z - point.Z).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end
Raids.Contested = contested

-- reach / hold steps and the lead's first step, once a second
local function watch()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		local step_dt = acc
		acc = 0
		for _, player in Players:GetPlayers() do
			local data = PlayerData.Get(player)
			local raid, step = current(data)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if raid and step and root then
				local target = step
				if step.Kind == "extract" and step.Lead then
					target = R.ById[step.Lead].Steps[1]
				end
				if target and (target.Kind == "reach" or target.Kind == "hold") then
					local point = R.Points[target.Point]
					local d = point and Vector3.new(root.Position.X - point.X, 0, root.Position.Z - point.Z).Magnitude
					if d and d <= target.Radius then
						local wasContested = raid.Contested
						raid.Contested = target.Kind == "hold" and contested(point, target.Radius)
						if raid.Contested then
							if not wasContested then
								announce(player, "A rival crew is on the point. The hold does not count until they are gone.")
							end
							Raids.Sync(player)
						else
							Raids.Progress(player, target.Kind, target.Point, step_dt)
						end
					elseif raid.Contested then
						raid.Contested = false
						Raids.Sync(player)
					end
				end
			end
		end
	end)
end

function Raids.Init()
	NPCs.Killed.Event:Connect(function(killer, model, typeName)
		if typeof(killer) == "Instance" and killer:IsA("Player") then
			Raids.Progress(killer, "kill", typeName, 1)
		end
	end)
	Inventory.Used.Event:Connect(function(player, itemId)
		local def = Items.Defs[itemId]
		if def and def.Intel then
			Raids.AddIntel(player)
		end
	end)
	Players.PlayerRemoving:Connect(clearMarker)
	watch()
end

return Raids
