-- Dev tools (Config.Dev.Enabled only): the F2 panel's server side. Teleports to landmarks, districts and
-- hideout sites, spawns hostiles, fires director events, heals, hands out materials, opens the world.
-- Every action is refused when Dev is off, so a release build cannot be driven from here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Net = require(script.Parent.Common.Net)
local City = require(script.Parent.City)
local Events = require(script.Parent.Events)
local Hideouts = require(script.Parent.Hideouts)
local Inventory = require(script.Parent.Inventory)
local Landmarks = require(script.Parent.Landmarks)
local NPCs = require(script.Parent.NPCs)
local WorldPhase = require(script.Parent.WorldPhase)

local DevTools = {}

local function root(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function teleport(player, position)
	local r = root(player)
	if r then
		player.Character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
		Remotes.Announce:FireClient(player, "Teleported.", "Info")
	end
end

local actions = {}

-- "Armory", "RaidGate", "Terminal_<name>", "District_<name>", "Site_<n>"
function actions.Teleport(player, arg)
	arg = tostring(arg)
	for _, l in Landmarks.List() do
		if l.key == arg then
			return teleport(player, l.position - Vector3.new(0, 6, 0))
		end
	end
	local district = arg:match("^District_(.+)$")
	if district then
		local d = City.GetDistrict(district)
		if d then
			return teleport(player, d.Center + Vector3.new(0, 4, 30))
		end
	end
	local site = tonumber(arg:match("^Site_(%d+)$"))
	if site and Hideouts.Sites[site] then
		return teleport(player, Hideouts.Sites[site].Position + Vector3.new(0, 4, 0))
	end
end

function actions.Spawn(player, arg)
	local r = root(player)
	if r and NPCs.Types[tostring(arg)] then
		local angle = math.random() * math.pi * 2
		NPCs.Spawn(tostring(arg), r.Position + Vector3.new(math.cos(angle) * 18, 3, math.sin(angle) * 18))
	end
end

function actions.Event(player, arg)
	local fire = Events.Fire[tostring(arg)]
	if fire then
		task.spawn(fire)
	end
end

function actions.Heal(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
		char:SetAttribute("Stamina", char:GetAttribute("MaxStamina"))
		char:SetAttribute("Posture", 0)
		char:SetAttribute("Charge", char:GetAttribute("MaxCharge") or 100)
	end
end

function actions.Materials(player)
	Inventory.AddAll(player, { Scrap = 30, Wire = 15, Cloth = 15, SheetMetal = 6, Pipe = 3, Battery = 4, Powder = 6, Glass = 4 })
end

function actions.Open(player)
	if not WorldPhase.IsOpen() then
		task.spawn(WorldPhase.Emerge)
	end
end

function actions.Kill(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
end

function DevTools.Init()
	Net.On("Dev", { rate = 3, burst = 6, args = { "string", "string?" } }, function(player, action, arg)
		if not Config.Dev.Enabled then
			return
		end
		local fn = actions[action]
		if fn then
			fn(player, arg)
		end
	end)
end

return DevTools
