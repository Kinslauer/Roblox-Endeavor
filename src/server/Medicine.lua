-- Medicine (Endeavor): wounds on conduits (common/WoundService, shared/Wounds) joined to the city's systems.
-- Every player body carries its wounds from spawn; movement re-reads them (Stats); treatments are items
-- (Inventory.Use: Bandage, Tourniquet, Hemostat, Splint, Painkillers, SurgeryKit; Medkit also binds a light bleed;
-- food feeds the hunger); a medbay heals parts and mends bones at home (Hideouts); the doctor at Verdant Reach mends
-- everything for war credits (Frontier); an implant fitted where a limb was lost ends the loss (Autonet); a deep cut
-- leaves a scar for the rest of the life (profile.Scars, wiped with the body).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Wounds = require(Shared.Wounds)
local Sounds = require(Shared.Sounds)
local WoundService = require(script.Parent.Common.WoundService)
local PlayerData = require(script.Parent.Common.PlayerData)

local W = Config.Wounds
local Medicine = {}

local function scarPart(limb, offset, roll)
	local p = Instance.new("Part")
	p.Name = "Scar"
	p.Size = Vector3.new(0.06, 0.08, 0.5)
	p.Color = Color3.fromRGB(96, 34, 36)
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = false
	-- on the limb's surface: push the point out to the nearest face of the limb box
	local h = limb.Size / 2
	local o = Vector3.new(math.clamp(offset.X, -h.X, h.X), math.clamp(offset.Y, -h.Y, h.Y), math.clamp(offset.Z, -h.Z, h.Z))
	local gaps = { h.X - math.abs(o.X), h.Y - math.abs(o.Y), h.Z - math.abs(o.Z) }
	local axis = 1
	for i = 2, 3 do
		if gaps[i] < gaps[axis] then
			axis = i
		end
	end
	local normal
	if axis == 1 then
		o = Vector3.new((if o.X >= 0 then 1 else -1) * (h.X + 0.02), o.Y, o.Z)
		normal = Vector3.new(if o.X >= 0 then 1 else -1, 0, 0)
	elseif axis == 2 then
		o = Vector3.new(o.X, (if o.Y >= 0 then 1 else -1) * (h.Y + 0.02), o.Z)
		normal = Vector3.new(0, if o.Y >= 0 then 1 else -1, 0)
	else
		o = Vector3.new(o.X, o.Y, (if o.Z >= 0 then 1 else -1) * (h.Z + 0.02))
		normal = Vector3.new(0, 0, if o.Z >= 0 then 1 else -1)
	end
	local up = if math.abs(normal.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local rel = CFrame.lookAt(o, o + normal, up) * CFrame.Angles(0, 0, roll) * CFrame.Angles(0, math.pi / 2, 0)
	p.CFrame = limb.CFrame * rel
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = limb, p
	weld.Parent = p
	p.Parent = limb
	return p
end

local function drawScars(player, char)
	local data = PlayerData.Get(player)
	for _, sc in (data and data.Scars) or {} do
		local limb = char:FindFirstChild(sc.Limb)
		if limb and limb:IsA("BasePart") then
			scarPart(limb, Vector3.new(sc.X, sc.Y, sc.Z), sc.R or 0)
		end
	end
end

local function onEvent(char, part, ev, info)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		return
	end
	if ev.Broke then
		Sounds.Play("GuardBreak", char:FindFirstChild("HumanoidRootPart"))
	end
	if ev.Lost then
		Remotes.World:FireAllClients("Flicker", char) -- the limb goes dead in a flash; the body keeps it hanging for now
	end
	-- a deep cut leaves a scar for the rest of this life
	if info.Kind == "Cut" and info.At and (info.Amount or 0) >= W.ScarMin then
		local data = PlayerData.Get(player)
		local _, limb = Wounds.PartAt(char, info.At)
		if data and limb then
			data.Scars = data.Scars or {}
			if #data.Scars < W.MaxScars then
				local o = limb.CFrame:PointToObjectSpace(info.At)
				local roll = math.random() * math.pi
				table.insert(data.Scars, { Limb = limb.Name, X = o.X, Y = o.Y, Z = o.Z, R = roll })
				scarPart(limb, o, roll)
			end
		end
	end
end

-- Inventory.Use: true when the item did something (so it is spent), false when there was nothing to treat
function Medicine.Use(player, def)
	local char = player.Character
	if not char then
		return false
	end
	if not WoundService.Get(char) then
		WoundService.Attach(char)
	end
	local did = false
	if def.Treat then
		did = WoundService.Treat(char, def.Treat) ~= nil
	end
	if def.Food then
		WoundService.Feed(char, def.Food)
		did = true
	end
	return did
end

function Medicine.Doctor(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.Get(player)
	if not (hum and hum.Health > 0 and data) then
		return
	end
	local price = W.Doctor.Price
	if (data.War.Credits or 0) < price then
		Remotes.Announce:FireClient(player, ("The doctor wants %d credits."):format(price), "Info")
		return
	end
	data.War.Credits -= price
	char:SetAttribute("Mending", true)
	task.delay(W.Doctor.Seconds, function()
		if char.Parent then
			char:SetAttribute("Mending", nil)
			WoundService.Mend(char)
		end
	end)
end

function Medicine.Init()
	WoundService.Hunger = true
	WoundService.OnEvent = onEvent
	WoundService.Changed = function(char)
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			require(script.Parent.Stats).Apply(player)
		end
	end
	WoundService.Start()
	require(script.Parent.Destruction).Concuss = function(char)
		WoundService.Concuss(char)
	end
	require(script.Parent.Hideouts).HomeHeal = WoundService.HomeHeal
	require(script.Parent.Frontier).Doctor = Medicine.Doctor
	require(script.Parent.Autonet).Fitted = function(_, char, slot)
		for part, cyber in Wounds.CyberSlot do
			if cyber == slot then
				WoundService.Replace(char, part)
			end
		end
	end
	local function watch(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid", 10)
			if char.Parent then
				WoundService.Attach(char)
				task.delay(1, function()
					if char.Parent then
						drawScars(player, char)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Medicine
