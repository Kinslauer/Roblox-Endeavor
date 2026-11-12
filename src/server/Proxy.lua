-- The conduit's humanoid drone (round 7 of docs/Reference-Picks-Plan.md; Andy: "the conduit's humanoid drone sent on a
-- run in its place ... less health, needs armour, weak in melee, good with guns", "it carries a lot of weight").
-- Tuning: Config.Make.Proxy. A bay module "ProxyFrame" holds one drone on a rack.
--   Link    hold X at the frame (not in a fight): the conduit's body rests in the frame (a statue) and the player
--           wakes in the drone beside it, with the same pack (player attribute Proxy, character attribute Proxy,
--           data.ProxyLinked: health x Health, melee x Melee, rounds x Gun, drift x Spread, carry x Carry)
--   Unlink  hold X at the frame again: back in the conduit's own body
--   Lost    the drone dies: what it carried drops where it fell (remains, no tag), the drone is wrecked (h.ProxyLost,
--           rebuilt at the frame for Config.Make.Proxy.Rebuild), and the conduit wakes in the frame. No permadeath:
--           the stack never left the bay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Assets = require(Shared.Assets)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)

local P = Config.Make.Proxy
local Proxy = {}
local pending = {} -- player -> CFrame the next spawn uses

local function lazy(name)
	return require(script.Parent[name])
end

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function frameOf(site)
	return site and site.Built and site.Built:FindFirstChild("ProxyFrame")
end

local function resting(site, on, player)
	local frame = frameOf(site)
	if not frame then
		return
	end
	local old = site.Built:FindFirstChild("Resting")
	if old then
		old:Destroy()
	end
	if on then
		local ok = pcall(function()
			require(script.Parent.Common.Rigs).Statue("Conduit", frame.CFrame * CFrame.new(0, -frame.Size.Y / 2 + 0.2, 0.6), site.Built, { Name = "Resting" })
		end)
		if not ok then
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.Size, p.CFrame = "Resting", true, Vector3.new(1.6, 5, 1), frame.CFrame * CFrame.new(0, 0, 0.6)
			p.Color = Color3.fromRGB(60, 62, 70)
			p.Parent = site.Built
		end
	end
	local _ = player
end

local function swap(player, at, linked)
	local data = PlayerData.Get(player)
	-- Lifecycle ignores the old body's end: it is no longer the player's character
	player:SetAttribute("Proxy", linked or nil)
	data.ProxyLinked = linked or nil
	pending[player] = at
	lazy("Lifecycle").Spawn(player)
	local char = player.Character
	if char and linked then
		char:SetAttribute("Proxy", true)
		for _, p in char:GetDescendants() do
			if p:IsA("MeshPart") or (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart") then
				pcall(Assets.Tint, p, P.Tint)
				if p:IsA("BasePart") then
					p.Color = P.Tint
				end
			end
		end
		lazy("Stats").Apply(player, true)
	end
end

function Proxy.Linked(player)
	return player:GetAttribute("Proxy") == true
end

function Proxy.Link(player)
	local site = lazy("Hideouts").SiteOf(player)
	local frame = frameOf(site)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local data = PlayerData.Get(player)
	if not (frame and root and data) or (root.Position - frame.Position).Magnitude > 12 then
		return false
	end
	if Proxy.Linked(player) then
		return Proxy.Unlink(player)
	end
	if lazy("Combat").InCombat(player) then
		say(player, "> FRAME . NOT UNDER FIRE", "Warning")
		return false
	end
	local h = data.Hideout
	if h.ProxyLost then
		local Inventory = lazy("Inventory")
		for id, n in P.Rebuild do
			if Inventory.Count(player, id) < n then
				say(player, "> FRAME . DRONE WRECKED . PARTS NEEDED", "Warning")
				return false
			end
		end
		for id, n in P.Rebuild do
			Inventory.Remove(player, id, n)
		end
		h.ProxyLost = nil
		say(player, "> FRAME . DRONE REBUILT", "Reward")
	end
	resting(site, true, player)
	swap(player, frame.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0), true)
	say(player, "> PROXY . LINKED", "Emergence")
	return true
end

function Proxy.Unlink(player)
	local site = lazy("Hideouts").SiteOf(player)
	local frame = frameOf(site)
	if not Proxy.Linked(player) then
		return false
	end
	local at = if frame then frame.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0) else nil
	resting(site, false, player)
	swap(player, at, false)
	say(player, "> PROXY . UNLINKED", "Emergence")
	return true
end

-- Lifecycle's onDied asks this first: a drone's death is not the conduit's.
function Proxy.Lost(player, char)
	local data = PlayerData.Get(player)
	if not (data and Proxy.Linked(player)) then
		return false
	end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local bundle = table.clone(data.Inventory)
	if root and next(bundle) then
		lazy("Loot").Spawn(root.CFrame, bundle, { Label = "Wrecked drone" })
	end
	-- what it carried is gone from the pack; the conduit keeps its body, stack and bay
	for id, n in data.Inventory do
		lazy("Inventory").Remove(player, id, n)
	end
	data.Hideout.ProxyLost = true
	local site = lazy("Hideouts").SiteOf(player)
	resting(site, false, player)
	local frame = frameOf(site)
	say(player, "> PROXY . SIGNAL LOST", "Warning")
	task.wait(2)
	swap(player, if frame then frame.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0) else nil, false)
	return true
end

-- A linked player left in a fight: the drone falls where it stood with what it carried.
function Proxy.CombatLog(player)
	local data = PlayerData.Get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (data and root and lazy("Combat").InCombat(player)) then
		return
	end
	local bundle = table.clone(data.Inventory)
	if next(bundle) then
		lazy("Loot").Spawn(root.CFrame, bundle, { Label = "Wrecked drone" })
	end
	for id, n in data.Inventory do
		lazy("Inventory").Remove(player, id, n)
	end
	data.Hideout.ProxyLost = true
end

function Proxy.Init()
	local Lifecycle = lazy("Lifecycle")
	Lifecycle.Override = function(player)
		local at = pending[player]
		pending[player] = nil
		return at
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		local data = PlayerData.Get(player)
		if data and data.ProxyLinked then
			data.ProxyLinked = nil -- a link does not outlast the session: the conduit wakes in its own body
		end
	end)
end

return Proxy
