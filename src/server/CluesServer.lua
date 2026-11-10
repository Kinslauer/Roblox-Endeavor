-- Clues in the world (shared/Clues.lua for the data): each cycle's draw places the fragments whose rules hold
-- at a rolled spot of their Where, each marked by an anomaly part (tag "Anomaly"; the client animates it).
-- Reading one (the prompt) adds it to profile.Knowledge.Fragments (the ARCHIVE app) and tells the reader what it
-- says. A fragment that Needs others is placed for everyone but only a conduit who has read them can take it;
-- the client hides what you cannot see yet (World "Clues" carries the ids you may see).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local F = require(Shared.Frontier)
local Megacity = require(Shared.Megacity)
local Remotes = require(Shared.Remotes)
local SC = require(Shared.Clues)
local PlayerData = require(script.Parent.Common.PlayerData)
local City = require(script.Parent.City)
local Terminal = require(script.Parent.Terminal)

local Clues = {}
local live = {} -- id -> { Pickup, Anomaly }
local folder

local function known(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	data.Knowledge = data.Knowledge or { Contacts = {}, Contracts = {}, Completed = 0 }
	data.Knowledge.Fragments = data.Knowledge.Fragments or {}
	return data.Knowledge.Fragments
end

local function ground(x, z)
	return if F.InCity(x, z) then F.CityTop else F.Height(x, z)
end

-- A rolled spot for a Where, from the city and this server's frontier layout.
local function spotFor(where, rng)
	if where == "City" then
		local d = City.Districts[rng:NextInteger(1, #City.Districts)]
		local a = rng:NextNumber(0, math.pi * 2)
		return d.Center + Vector3.new(math.cos(a) * 40, 0, math.sin(a) * 40)
	elseif where == "Crossroads" then
		local a = rng:NextNumber(0, math.pi * 2)
		return Vector3.new(math.cos(a) * 70, 0, math.sin(a) * 70)
	elseif where == "Scarp" then
		local p = F.Switchbacks[rng:NextInteger(2, #F.Switchbacks - 1)]
		return p + Vector3.new(rng:NextNumber(-6, 6), 0, 11)
	elseif where == "Trail" then
		local p = F.Trail[rng:NextInteger(2, #F.Trail - 1)]
		return p + Vector3.new(9, 0, rng:NextNumber(-8, 8))
	elseif where == "Site" then
		local s = F.Sites[rng:NextInteger(1, #F.Sites)]
		local a = rng:NextNumber(0, math.pi * 2)
		return s.Position + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16)
	elseif where == "Pocket" then
		local pk = Megacity.Pockets[rng:NextInteger(1, #Megacity.Pockets)]
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.2, 0.55) * pk.Radius
		return pk.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	else -- Reach
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(70, 140)
		return F.Reach.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
end

local function needsList(def)
	return table.concat((def.Rule and def.Rule.Needs) or {}, ",")
end

local function place(id, def, position)
	local y = ground(position.X, position.Z)
	local base = Vector3.new(position.X, y, position.Z)
	local pickup = Instance.new("Part")
	pickup.Name = "Fragment"
	pickup.Anchored, pickup.CanCollide, pickup.CanQuery = true, false, true
	pickup.Size = Vector3.new(1, 0.1, 1.3)
	pickup.Material, pickup.Color = Enum.Material.Neon, Color3.fromRGB(210, 220, 255)
	pickup.Transparency = 0.25
	pickup.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(37), math.rad(8))
	pickup:SetAttribute("FragmentId", id)
	pickup:SetAttribute("Needs", needsList(def))
	CollectionService:AddTag(pickup, "Scent")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = def.Name, "Read", 0.6
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
	CollectionService:AddTag(anomaly, "Anomaly")
	anomaly.Parent = folder
	live[id] = { Pickup = pickup, Anomaly = anomaly }
end

-- What this player may see of what is out: the ids whose Needs they have read.
function Clues.SendVisible(player)
	local k = known(player)
	if not k then
		return
	end
	local ids = {}
	for id in live do
		if SC.CanSee(SC.Fragments[id], k) then
			table.insert(ids, id)
		end
	end
	Remotes.World:FireClient(player, "Clues", ids)
end

-- The cycle's draw: clear the last cycle's fragments, place the ones whose rules hold.
function Clues.Draw(index, rng)
	for _, l in live do
		for _, key in { "Pickup", "Anomaly" } do
			if l[key] and l[key].Parent then
				l[key]:Destroy()
			end
		end
	end
	table.clear(live)
	local placed = {}
	for id, def in SC.Fragments do
		if SC.Allowed(def, index) and F.L then
			local ok, err = pcall(place, id, def, spotFor(def.Where, rng))
			if ok then
				placed[id] = def.Where
			else
				warn("[Clues] could not place", id, err)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		Clues.SendVisible(player)
	end
	return placed
end

function Clues.Live()
	return live
end

-- Reading a fragment: once per conduit, only with its prerequisites read; it stays for others.
function Clues.Take(player, id)
	local l, def = live[id], SC.Fragments[id]
	local k = known(player)
	if not (l and l.Pickup and l.Pickup.Parent and def and k) then
		return false
	end
	if not SC.CanSee(def, k) then
		Remotes.Announce:FireClient(player, "It means nothing to you. Not yet.", "Info")
		return false
	end
	if k[id] then
		Remotes.Announce:FireClient(player, "You have this one in your archive.", "Info")
		return false
	end
	local n = 0
	for _ in k do
		n += 1
	end
	k[id] = n + 1
	Remotes.Announce:FireClient(player, def.Name .. ": " .. def.Text, "Info")
	Remotes.World:FireClient(player, "Fragment", id, def.Name, def.Text)
	Terminal.Push(player)
	Clues.SendVisible(player)
	return true
end

function Clues.Init()
	folder = Instance.new("Folder")
	folder.Name = "Clues"
	folder.Parent = workspace
end

return Clues
