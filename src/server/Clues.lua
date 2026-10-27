-- Clues (design/gdd/dematerialization.md §5; data in shared/Clues.lua): each cycle's draw decides the
-- contacts' lines, which fragments are out in the world and where, each marked by an anomaly. Reading a
-- fragment adds it to the conduit's Knowledge (profile.Knowledge; kept across permadeath once a computer is
-- installed) and to the ARCHIVE app on the computer. Fragments that Need others are drawn for everyone but
-- only a conduit who has read the prerequisites can see or take one (the client hides the rest).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local District = require(Shared.District)
local Items = require(Shared.Items)
local R = require(Shared.Raids)
local Remotes = require(Shared.Remotes)
local SC = require(Shared.Clues)
local Contacts = require(script.Parent.Contacts)
local Cycle = require(script.Parent.Cycle)
local Inventory = require(script.Parent.Inventory)
local NPCs = require(script.Parent.NPCs)
local PlayerData = require(script.Parent.PlayerData)
local Rivals = require(script.Parent.Rivals)
local Terminal = require(script.Parent.Terminal)

local Clues = {}

Clues.Tag = "Anomaly" -- client/WorldFX.lua animates these
local TOP = District.GroundTop
local live = {} -- fragmentId -> { Pickup = part?, Anomaly = part?, Rival = model? }
local folder

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function clearLive()
	for _, l in live do
		for _, key in { "Pickup", "Anomaly" } do
			if l[key] and l[key].Parent then
				l[key]:Destroy()
			end
		end
	end
	table.clear(live)
end

local function needsList(def)
	return table.concat((def.Rule and def.Rule.Needs) or {}, ",")
end

local function place(id, def, position)
	local base = position + Vector3.new(0, TOP, 0)
	local pickup = Instance.new("Part")
	pickup.Name = "Fragment"
	pickup.Anchored, pickup.CanCollide, pickup.CanQuery = true, false, true
	pickup.Size = Vector3.new(1, 0.1, 1.3)
	pickup.Material, pickup.Color = Enum.Material.Neon, Color3.fromRGB(210, 220, 255)
	pickup.Transparency = 0.25
	pickup.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(37), math.rad(8))
	pickup:SetAttribute("FragmentId", id)
	pickup:SetAttribute("Needs", needsList(def))
	CollectionService:AddTag(pickup, "Scent") -- a cybernetic nose finds it (client/Senses.lua)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = def.Name, "Pick up", 0.6
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 8, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = pickup
	prompt.Triggered:Connect(function(player)
		Clues.Take(player, id)
	end)
	pickup.Parent = folder
	local anomaly = Instance.new("Part")
	anomaly.Name = "Anomaly"
	anomaly.Anchored, anomaly.CanCollide, anomaly.CanQuery, anomaly.CanTouch = true, false, false, false
	anomaly.Size = if def.Anomaly == "Echo" then Vector3.new(1.6, 5, 0.8) elseif def.Anomaly == "Wrong" then Vector3.new(5, 2.5, 0.3) else Vector3.new(2.5, 2.5, 2.5)
	anomaly.Material, anomaly.Color, anomaly.Transparency = Enum.Material.Glass, Color3.fromRGB(150, 160, 190), 0.6
	anomaly.CFrame = CFrame.new(base + Vector3.new(1.5, anomaly.Size.Y / 2 + 0.4, 1.5))
	anomaly:SetAttribute("Kind", def.Anomaly or "Static")
	anomaly:SetAttribute("FragmentId", id)
	anomaly:SetAttribute("Needs", needsList(def))
	CollectionService:AddTag(anomaly, Clues.Tag)
	anomaly.Parent = folder
	live[id] = { Pickup = pickup, Anomaly = anomaly }
end

local function rivalMember(rng)
	local members = {}
	for _, crew in Rivals.Crews() do
		for model in crew.Members do
			if model.Parent then
				table.insert(members, model)
			end
		end
	end
	return if #members > 0 then members[rng:NextInteger(1, #members)] else nil
end

-- The cycle's draw: contact lines, then the fragments whose rules hold this cycle.
function Clues.Draw(index, rng)
	clearLive()
	for id in SC.Lines do
		workspace:SetAttribute("CycleLine_" .. id, SC.DrawLine(id, rng))
	end
	local spots = {}
	for id in R.Contacts do
		local model = Contacts.Get(id)
		spots[id] = model and model:GetAttribute("Spot") or 1
	end
	local placed = {}
	for id, def in SC.Fragments do
		if SC.Allowed(def, index, spots) then
			local rival = def.OnRival and rng:NextNumber() < 0.5 and rivalMember(rng) or nil
			if rival then
				local bag = NPCs.Carrying(rival)
				if bag then
					bag[id] = (bag[id] or 0) + 1
					live[id] = { Rival = rival }
					placed[id] = "Rival"
				end
			else
				place(id, def, def.Spots[rng:NextInteger(1, #def.Spots)])
				placed[id] = "Spot"
			end
		end
	end
	Clues.Last = { Index = index, Placed = placed }
	return placed
end

function Clues.Live()
	return live
end

-- Picking a fragment up off the ground (the prompt): only one conduit gets it each cycle.
function Clues.Take(player, id)
	local l, def = live[id], SC.Fragments[id]
	local data = PlayerData.Get(player)
	if not (l and l.Pickup and l.Pickup.Parent and def and data) then
		return false
	end
	if not SC.CanSee(def, data.Knowledge) then
		return false
	end
	l.Pickup:Destroy()
	if l.Anomaly then
		l.Anomaly:Destroy()
	end
	live[id] = nil
	Inventory.Add(player, id, 1)
	announce(player, ("%s. Read it (Tab)."):format(def.Name))
	return true
end

local function publish(player, data)
	local ids = {}
	for id in data.Knowledge or {} do
		table.insert(ids, id)
	end
	player:SetAttribute("Knowledge", HttpService:JSONEncode(ids)) -- the client hides fragments you can't see yet
end

-- Reading a fragment (Tab -> Read; Inventory consumes it): it becomes knowledge.
function Clues.Read(player, id)
	local def = SC.Fragments[id]
	local data = PlayerData.Get(player)
	if not (def and data) then
		return false
	end
	data.Knowledge = data.Knowledge or {}
	local first = next(data.Knowledge) == nil
	if not data.Knowledge[id] then
		local n = 0
		for _ in data.Knowledge do
			n += 1
		end
		data.Knowledge[id] = n + 1
	end
	publish(player, data)
	announce(player, def.Text, "Lore")
	if first then
		task.delay(3, function()
			announce(player, if data.Computer then "ARCHIVE unlocked on your computer." else "Without a computer to hold it, this dies with you.", "Info")
		end)
	end
	if def.Teaches then
		task.delay(first and 5 or 2, function()
			announce(player, ("You know how to build an %s now (Tab -> crafting)."):format(def.Teaches), "Info")
		end)
	end
	Inventory.Push(player) -- recipes that needed this knowledge appear
	Terminal.Push(player)
	return true
end

function Clues.Init()
	folder = Instance.new("Folder")
	folder.Name = "Clues"
	folder.Parent = workspace
	Inventory.Used.Event:Connect(function(player, itemId)
		local def = Items.Defs[itemId]
		if def and def.Type == "Fragment" then
			Clues.Read(player, itemId)
		end
	end)
	Cycle.Dematerialized.Event:Connect(clearLive)
	Cycle.Rematerialized.Event:Connect(Clues.Draw)
	local function watch(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				local data = PlayerData.Get(player)
				if data then
					publish(player, data)
				end
			end)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
		local data = PlayerData.Get(p)
		if data then
			publish(p, data)
		end
	end
	Players.PlayerAdded:Connect(watch)
	Clues.Draw(0, Random.new(Cycle.State().Index + 7)) -- the world before the first cycle carries clues too
end

return Clues
