-- Slave tech in a conduit's hands (round 7 of docs/Reference-Picks-Plan.md; Andy, 2026-11-12, docs/LORE.md Truth:
-- "trap an enemy and enslave it ... released (and remembers), reprogrammed and sent to the Front to fight for its
-- conduit, or it breaks free and later finds the conduit out in the world as an invader"). Tuning: Config.Make.Thrall.
--   Capture    Use a Neural Shackle near a hostile that is beaten (under Below of its health), down, asleep or held:
--              it is taken to the bay's holding frame (data.Hideout.Thralls; needs the Holding module; MaxKept)
--   Release    from the computer: it walks free, and an hour later an unsigned crate stands in the bay's lift
--   Reprogram  from the computer: it goes to the Front (data.War.Thralls; the Front's Thralls fields it beside its
--              conduit's recruit)
--   Escape     each hour a kept one may break out (less while the bay's generator runs); it becomes an invader
--              (data.Hideout.Invaders) that comes for its conduit out in the city, harder than it was
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)

local T = Config.Make.Thrall
local Thralls = {}
local hunting = {} -- player -> the invader model out for them
local rng = Random.new()

local function lazy(name)
	return require(script.Parent[name])
end

local function say(player, text, kind)
	Remotes.Announce:FireClient(player, text, kind or "Info")
end

local function hideout(player)
	local data = PlayerData.Get(player)
	return data and data.Hideout, data
end

-- Can this body be shackled now?
function Thralls.Shackleable(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and model:GetAttribute("NPC")) or model:GetAttribute("Contact") or model:GetAttribute("Owner") then
		return false
	end
	local state = model:GetAttribute("StealthState")
	return hum.Health / math.max(1, hum.MaxHealth) <= T.Below or state == "Down" or state == "Held" or state == "Asleep" or state == "HeldUp"
		or model:GetAttribute("Asleep") == true
end

local function nearest(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestD = nil, T.Reach
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("NPC") then
			local r = m:FindFirstChild("HumanoidRootPart")
			local d = r and (r.Position - root.Position).Magnitude
			if d and d < bestD and Thralls.Shackleable(m) then
				best, bestD = m, d
			end
		end
	end
	return best
end

function Thralls.Capture(player)
	local h, data = hideout(player)
	local Inventory = lazy("Inventory")
	if not h or Inventory.Count(player, "Shackle") <= 0 then
		return false
	end
	local site = lazy("Hideouts").SiteOf(player)
	if not (site and h.Modules.Holding) then
		say(player, "> SHACKLE . NO HOLDING FRAME", "Warning")
		return false
	end
	h.Thralls = h.Thralls or {}
	if #h.Thralls >= T.MaxKept then
		say(player, "> HOLDING FRAME . FULL", "Warning")
		return false
	end
	local target = nearest(player)
	if not target then
		say(player, "> SHACKLE . NO SUBJECT", "Warning")
		return false
	end
	Inventory.Remove(player, "Shackle", 1)
	local name = ("UNIT %04d"):format(rng:NextInteger(1000, 9999))
	table.insert(h.Thralls, { Type = target:GetAttribute("NPC"), Name = name, At = os.time() })
	lazy("Combat").FX("Buff", target, "Shackle")
	target:Destroy() -- taken down the line to the frame
	say(player, "> SHACKLED . " .. name, "Reward")
	Thralls.Draw(site)
	data.Thralled = (data.Thralled or 0) + 1
	return true
end

local function take(player, index)
	local h = hideout(player)
	local i = tonumber(index)
	local t = h and h.Thralls and i and h.Thralls[i]
	if not t then
		return nil
	end
	table.remove(h.Thralls, i)
	pcall(Thralls.Draw, lazy("Hideouts").SiteOf(player))
	return t, h
end

function Thralls.Release(player, index)
	local t, h = take(player, index)
	if not t then
		return false
	end
	h.Debts = h.Debts or {}
	table.insert(h.Debts, { Name = t.Name, Hours = T.DebtDelay })
	say(player, "> RELEASED . " .. t.Name)
	return true
end

function Thralls.Reprogram(player, index)
	local data = PlayerData.Get(player)
	local t = take(player, index)
	if not t then
		return false
	end
	data.War.Thralls = data.War.Thralls or {}
	table.insert(data.War.Thralls, { Type = t.Type, Name = t.Name })
	say(player, "> " .. t.Name .. " . WRITTEN FOR THE FRONT", "Reward")
	return true
end

-- The kept figures stand in the holding frame, pale, wired from the head like the hall's.
function Thralls.Draw(site)
	local model = site and site.Built
	local frame = model and model:FindFirstChild("Holding")
	if not frame then
		return
	end
	local old = model:FindFirstChild("HeldFigures")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeldFigures"
	folder.Parent = model
	local h = (function()
		local owner = site.Owner and Players:GetPlayerByUserId(site.Owner)
		return owner and hideout(owner)
	end)()
	for i, t in h and h.Thralls or {} do
		local cf = frame.CFrame * CFrame.new((i - 2) * 2.6, -frame.Size.Y / 2 + 0.2, 0)
		local ok = pcall(function()
			require(script.Parent.Common.Rigs).Statue(t.Type, cf, folder, { Color = Color3.fromRGB(196, 192, 186), Name = t.Name })
		end)
		if not ok then
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.Size, p.CFrame = t.Name, true, Vector3.new(1.4, 5, 1), cf * CFrame.new(0, 2.5, 0)
			p.Color, p.Material = Color3.fromRGB(196, 192, 186), Enum.Material.SmoothPlastic
			p.Parent = folder
		end
	end
end

-- Each hour (Cycle.Run): kept ones may break out, released ones' debts come due.
function Thralls.Hour()
	local Economy, Hideouts = lazy("Economy"), lazy("Hideouts")
	for _, player in Players:GetPlayers() do
		local h = hideout(player)
		local site = h and Hideouts.SiteOf(player)
		if h and h.Thralls and #h.Thralls > 0 then
			local chance = if site and Economy.Powered(site) then T.EscapePowered else T.Escape
			for i = #h.Thralls, 1, -1 do
				if rng:NextNumber() < chance then
					local t = table.remove(h.Thralls, i)
					h.Invaders = h.Invaders or {}
					table.insert(h.Invaders, { Type = t.Type, Name = t.Name })
					say(player, "> HOLDING FRAME . OPEN . " .. t.Name, "Warning")
				end
			end
			pcall(Thralls.Draw, site)
		end
		for i = #(h and h.Debts or {}), 1, -1 do
			local d = h.Debts[i]
			d.Hours -= 1
			if d.Hours <= 0 and site and site.LiftCFrame then
				table.remove(h.Debts, i)
				local bundle = Items.Roll("Barrens")
				local crate = lazy("Loot").Spawn(site.LiftCFrame * CFrame.new(0, 1.2, 0), bundle, { Label = "Unsigned", Mesh = "CrateA", Lifetime = 3600, Size = Vector3.new(3, 2, 2) })
				if crate then
					crate.Anchored = true
				end
				say(player, ("> LINE 9 . BAY %02d . UNSIGNED"):format(site.Index or 0), "Reward")
			end
		end
	end
end

-- An invader out for its conduit: spawned at a distance, already walking to where they stand.
function Thralls.Invade(player, t)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(T.InvadeRange[1], T.InvadeRange[2])
	local at = root.Position + Vector3.new(math.cos(a) * r, 40, math.sin(a) * r)
	local hit = workspace:Raycast(at, Vector3.new(0, -120, 0))
	at = if hit then hit.Position + Vector3.new(0, 3, 0) else root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local ok, model = pcall(lazy("NPCs").Spawn, t.Type, at, {
		OnDied = function(_, killer)
			hunting[player] = nil
			local h = hideout(player)
			for i, v in h and h.Invaders or {} do
				if v.Name == t.Name then
					table.remove(h.Invaders, i)
					break
				end
			end
			if killer and killer.Parent then
				say(killer, "> " .. t.Name .. " . DOWN", "Reward")
			end
		end,
	})
	if not (ok and model) then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth *= T.InvaderHealth
		hum.Health = hum.MaxHealth
	end
	model:SetAttribute("Invader", t.Name)
	model:SetAttribute("Investigate", root.Position)
	hunting[player] = model
	return model
end

function Thralls.Hunting(player)
	return hunting[player]
end

function Thralls.Init()
	task.spawn(function()
		while true do
			task.wait(T.InvadeEvery)
			local okW, open = pcall(function()
				return lazy("WorldPhase").IsOpen()
			end)
			for _, player in Players:GetPlayers() do
				local h = hideout(player)
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local m = hunting[player]
				if m and not m.Parent then
					hunting[player] = nil
					m = nil
				end
				if okW and open and h and h.Invaders and #h.Invaders > 0 and not m and hum and hum.Health > 0 and not player:GetAttribute("Below")
					and not player:GetAttribute("Safe") and not player:GetAttribute("Stealth") and rng:NextNumber() < T.InvadeChance then
					Thralls.Invade(player, h.Invaders[1])
				elseif m then
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						m:SetAttribute("Investigate", root.Position) -- it keeps coming
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local m = hunting[player]
		hunting[player] = nil
		if m and m.Parent then
			m:Destroy() -- it waits for them another time
		end
	end)
end

return Thralls
