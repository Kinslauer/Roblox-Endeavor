-- The Hideout (Phase 3, build order 1): the swap point between the two worlds. You reach it by
-- extracting from a district (hold X at a station); from here you deploy to the war (the Range
-- stands in for the war world until Wardogs lands), go back to the city, use the stash (safe from
-- permadeath), and pick your faction. Built in-place at Config.Hideout.Origin as a private room;
-- the whole room is a SafeZone, so nothing can be hurt here. Everything is anchored parts from code.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local D = require(Shared.District)
local Items = require(Shared.Items)
local Lore = require(Shared.Lore)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Gear = require(script.Parent.Gear)
local Inventory = require(script.Parent.Inventory)
local PlayerData = require(script.Parent.PlayerData)
local Range = require(script.Parent.Range)
local Wallet = require(script.Parent.Wallet)
local War = require(script.Parent.War)
local WorldPhase = require(script.Parent.WorldPhase)

local H = Config.Hideout
local Hideout = {}
Hideout.Zone = "Hideout"

local folder
local O = H.Origin
local TOP = D.GroundTop
local DARK, MID = Color3.fromRGB(26, 28, 34), Color3.fromRGB(48, 50, 60)
local WARM, CYAN, MAGENTA, GREEN = Color3.fromRGB(255, 200, 150), Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 50, 160), Color3.fromRGB(120, 255, 160)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or folder
	return p
end

local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range or 24, brightness or 1.5
	l.Parent = p
end

local function announce(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Event")
end

-- A hold-X console (same look as the arena's / the Range's).
local function console(position, title, action, color, onUse, parent, hold)
	local body = part({ Name = title, Size = Vector3.new(6, 5, 2.5), Position = position + Vector3.new(0, 2.5, 0), Color = DARK, Material = Enum.Material.Metal }, parent)
	local screen = part({ Name = "Screen", Size = Vector3.new(4.8, 2.2, 0.3), Position = position + Vector3.new(0, 3.2, 1.3), Material = Enum.Material.Neon, Color = color, CanCollide = false }, parent)
	glow(screen, color, 18, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(220, 40), Vector3.new(0, 4.6, 0), true
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, title
	text.TextColor3, text.Font, text.TextScaled = color, Enum.Font.GothamBold, true
	text.Parent = billboard
	billboard.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = title, action, hold or 0.4
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 10, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = body
	prompt.Triggered:Connect(onUse)
	return body
end

-- ---------------------------------------------------------------------------------------------
-- The room
-- ---------------------------------------------------------------------------------------------
local spawnCFrame

local function buildRoom()
	local S = H.Size
	part({ Name = "HideoutFloor", Size = Vector3.new(S, 4, S), Position = O + Vector3.new(0, TOP - 2, 0), Color = Color3.fromRGB(58, 56, 62), Material = Enum.Material.WoodPlanks })
	for _, d in { { Vector3.new(0, 0, S / 2), Vector3.new(S + 4, 24, 4) }, { Vector3.new(0, 0, -S / 2), Vector3.new(S + 4, 24, 4) }, { Vector3.new(S / 2, 0, 0), Vector3.new(4, 24, S + 4) }, { Vector3.new(-S / 2, 0, 0), Vector3.new(4, 24, S + 4) } } do
		part({ Name = "HideoutWall", Size = d[2], Position = O + d[1] + Vector3.new(0, TOP + 12, 0), Color = DARK, Material = Enum.Material.Concrete })
	end
	part({ Name = "HideoutCeiling", Size = Vector3.new(S + 4, 2, S + 4), Position = O + Vector3.new(0, TOP + 25, 0), Color = DARK, Material = Enum.Material.Concrete })
	-- warm lamps, and a strip of neon along the back wall
	for _, dx in { -S / 3, 0, S / 3 } do
		for _, dz in { -S / 3, S / 3 } do
			local lamp = part({ Name = "Lamp", Size = Vector3.new(2, 0.4, 2), Position = O + Vector3.new(dx, TOP + 23.6, dz), Color = WARM, Material = Enum.Material.Neon, CanCollide = false })
			glow(lamp, WARM, 60, 1.2)
		end
	end
	local strip = part({ Name = "Strip", Size = Vector3.new(S - 6, 0.5, 0.4), Position = O + Vector3.new(0, TOP + 9, -S / 2 + 2.3), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false })
	glow(strip, CYAN, 40, 1)
	-- the room is safe
	local zone = part({ Name = "SafeZone", Size = Vector3.new(1, 1, 1), Position = O + Vector3.new(0, TOP + 0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	zone:SetAttribute("Radius", S)
	zone:SetAttribute("ZoneName", "Hideout")
	CollectionService:AddTag(zone, "SafeZone")
	-- a cot and a workbench (the weapon bench lands here in build order 4)
	part({ Name = "Cot", Size = Vector3.new(8, 1.5, 3.5), Position = O + Vector3.new(S / 2 - 8, TOP + 0.75, S / 2 - 8), Color = Color3.fromRGB(70, 60, 50), Material = Enum.Material.Fabric })
	local bench = part({ Name = "Workbench", Size = Vector3.new(10, 3, 4), Position = O + Vector3.new(-S / 2 + 10, TOP + 1.5, S / 2 - 8), Color = MID, Material = Enum.Material.Metal })
	local benchLamp = part({ Name = "BenchLamp", Size = Vector3.new(6, 0.3, 1), Position = bench.Position + Vector3.new(0, 6, 0), Color = WARM, Material = Enum.Material.Neon, CanCollide = false })
	glow(benchLamp, WARM, 20, 1.5)
	spawnCFrame = CFrame.lookAt(O + Vector3.new(0, TOP + 4, 10), O + Vector3.new(0, TOP + 4, -10))
end

-- ---------------------------------------------------------------------------------------------
-- Travel
-- ---------------------------------------------------------------------------------------------
function Hideout.Enter(player, opts)
	local char = player.Character
	local data = PlayerData.Get(player)
	if not (char and char:FindFirstChild("HumanoidRootPart") and data) then
		return false
	end
	data.Location = "Hideout"
	player:SetAttribute("Zone", Hideout.Zone)
	player:SetAttribute("ForceFirstPerson", nil)
	char:PivotTo(spawnCFrame)
	Combat.Protect(char, H.TravelProtection)
	Wallet.Sync(player)
	player:SetAttribute("Faction", data.Faction or nil)
	if not data.HideoutSeen then
		data.HideoutSeen = true
		announce(player, Lore.Get("FirstExtract"), "Lore")
	end
	if not (opts and opts.Quiet) then
		announce(player, "The hideout. Deploy to the war, return to the city, use the stash, choose your side.")
	end
	return true
end

-- Back to the city: a fresh profile wakes in District 1, an Awakened one in District 2 (WorldPhase).
function Hideout.Leave(player)
	local char = player.Character
	local data = PlayerData.Get(player)
	if not (char and char:FindFirstChild("HumanoidRootPart") and data) then
		return false
	end
	data.Location = "City"
	player:SetAttribute("Zone", nil)
	player:SetAttribute("ForceFirstPerson", nil)
	char:PivotTo(WorldPhase.GetSpawnCFrame(player))
	Combat.Protect(char, H.TravelProtection)
	announce(player, "Back in the city.")
	return true
end

-- Extraction (a station prompt): refused mid-fight.
function Hideout.Extract(player)
	if Combat.InCombat(player) then
		announce(player, "The train will not take you while you are fighting.")
		return false
	end
	return Hideout.Enter(player)
end

-- Deploy to the war (server/War.lua): your side's base on the battlefield.
function Hideout.Deploy(player)
	local data = PlayerData.Get(player)
	if data and not data.Faction then
		announce(player, "Choose a side first - the consoles on the left.")
		return false
	end
	if not Range.Unlocked(player) then
		announce(player, ("The war does not want you yet. Awaken and take %d life first."):format(Config.Range.UnlockKills))
		return false
	end
	return War.Deploy(player)
end

-- ---------------------------------------------------------------------------------------------
-- Stash: items left here survive permadeath. v1: deposit everything you are not wearing / holding,
-- or withdraw everything. (Per-item moves come with the stash UI.)
-- ---------------------------------------------------------------------------------------------
local function worn(data)
	local keep = { [data.Equipped or ""] = true }
	for _, id in data.Armor do
		keep[id] = true
	end
	for _, id in data.Cyber do
		keep[id] = true
	end
	return keep
end

function Hideout.DepositAll(player)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	local keep, moved = worn(data), 0
	for id, count in table.clone(data.Inventory) do
		local n = if keep[id] then count - 1 else count -- one copy of anything worn stays on you
		if n > 0 then
			data.Stash[id] = (data.Stash[id] or 0) + n
			moved += n
			Inventory.Remove(player, id, n)
		end
	end
	player:SetAttribute("StashCount", Hideout.StashCount(data))
	announce(player, if moved > 0 then ("Stashed %d items. They stay here if you die."):format(moved) else "Nothing to stash.")
	return moved
end

function Hideout.WithdrawAll(player)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	local moved = 0
	for id, count in table.clone(data.Stash) do
		if Items.Defs[id] then
			Inventory.Add(player, id, count)
			moved += count
		end
		data.Stash[id] = nil
	end
	player:SetAttribute("StashCount", 0)
	announce(player, if moved > 0 then ("Took %d items from the stash."):format(moved) else "The stash is empty.")
	return moved
end

function Hideout.StashCount(data)
	local n = 0
	for _, count in data.Stash or {} do
		n += count
	end
	return n
end

-- ---------------------------------------------------------------------------------------------
-- Faction
-- ---------------------------------------------------------------------------------------------
function Hideout.SetFaction(player, id)
	local data = PlayerData.Get(player)
	local def
	for _, f in Config.War.Factions do
		if f.Id == id then
			def = f
		end
	end
	if not (data and def) then
		return false
	end
	if data.Faction == id then
		announce(player, ("You already stand with the %s."):format(def.Name))
		return false
	end
	if data.Faction and not Wallet.Spend(player, Config.War.SwitchCost) then
		announce(player, ("Changing sides costs %d money. You have %d."):format(Config.War.SwitchCost, Wallet.Get(player)))
		return false
	end
	data.Faction = id
	player:SetAttribute("Faction", id)
	announce(player, ("%s. \"%s\""):format(def.Name, def.Motto), "Event")
	return true
end

-- ---------------------------------------------------------------------------------------------
-- Extraction hubs: one station per district, on the south edge
-- ---------------------------------------------------------------------------------------------
local function station(district)
	local half = D.Extent() / 2
	local pos = district.Origin + Vector3.new(D.StreetLine(H.Hubs.Line), TOP, -half + H.Hubs.FromEdge)
	local platform = part({ Name = "Station", Size = Vector3.new(14, 1, 10), Position = pos + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(80, 78, 84), Material = Enum.Material.Concrete })
	platform:SetAttribute("District", district.Name)
	CollectionService:AddTag(platform, "ExtractHub")
	for _, dx in { -6, 6 } do
		part({ Name = "StationPost", Size = Vector3.new(0.6, 9, 0.6), Position = pos + Vector3.new(dx, 5.5, -4), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Metal })
	end
	local roof = part({ Name = "StationRoof", Size = Vector3.new(14, 0.5, 6), Position = pos + Vector3.new(0, 10, -3), Color = DARK, Material = Enum.Material.Metal })
	local sign = part({ Name = "StationSign", Size = Vector3.new(10, 1.2, 0.3), Position = pos + Vector3.new(0, 8.5, -0.5), Color = GREEN, Material = Enum.Material.Neon, CanCollide = false })
	glow(sign, GREEN, 30, 1.2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, "STATION  ·  EXTRACT"
	label.TextColor3, label.Font, label.TextScaled = Color3.new(0, 0, 0), Enum.Font.GothamBlack, true
	label.Parent = gui
	-- rails
	for _, dz in { -1.2, 1.2 } do
		part({ Name = "Rail", Size = Vector3.new(60, 0.3, 0.4), Position = pos + Vector3.new(0, 0.15, 7 + dz), Color = Color3.fromRGB(90, 90, 96), Material = Enum.Material.Metal, CanCollide = false })
	end
	roof.Name = "StationRoof"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "Station", "Extract to the hideout", H.ExtractSeconds
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = platform
	prompt.Triggered:Connect(Hideout.Extract)
	return platform
end

function Hideout.Init()
	if workspace:FindFirstChild("Hideout") then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Hideout"
	folder.Parent = workspace
	buildRoom()
	local S = H.Size
	-- consoles: travel on the right, stash at the back, factions on the left
	console(O + Vector3.new(S / 2 - 10, TOP, -8), "Deploy to the War", "Deploy", MAGENTA, Hideout.Deploy)
	console(O + Vector3.new(S / 2 - 10, TOP, 8), "Return to the City", "Take the train back", CYAN, Hideout.Leave)
	console(O + Vector3.new(-6, TOP, -S / 2 + 8), "Stash: Deposit", "Stash everything you are not wearing", GREEN, Hideout.DepositAll)
	console(O + Vector3.new(6, TOP, -S / 2 + 8), "Stash: Withdraw", "Take everything out", GREEN, Hideout.WithdrawAll)
	for i, f in Config.War.Factions do
		console(O + Vector3.new(-S / 2 + 10, TOP, -12 + (i - 1) * 12), f.Name, "Stand with them", f.Color, function(player)
			Hideout.SetFaction(player, f.Id)
		end)
	end
	-- stations in every district
	local hubs = 0
	for _, district in D.Districts do
		station(district)
		hubs += 1
	end
	-- leaving the war brings you home
	Range.OnLeave = function(player)
		Hideout.Enter(player, { Quiet = true })
	end
	Hideout.Built = { Hubs = hubs }
end

-- Where a (re)joining character wakes: the hideout, if that is where they left off.
function Hideout.SpawnCFrame(player)
	local data = PlayerData.Get(player)
	if data and data.Location == "Hideout" and spawnCFrame then
		return spawnCFrame
	end
	return nil
end

return Hideout
