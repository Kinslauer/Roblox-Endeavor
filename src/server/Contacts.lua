-- Contacts: the three people who unlock the hideout computer's apps (shared/Terminal.lua). Standing
-- bodies with a Talk prompt; nothing announces them, you find them. They cannot be hurt (Combat refuses
-- the Contact attribute) and nothing hunts them (not NPC-tagged).
--   Broker: the Verdant Market (safe, far).  Fixer: under the Crossroads span (close, contested).
--   Dealer: the Scarp Overlook deck (the Gatekeeper's ground).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local F = require(Shared.Frontier)
local T = require(Shared.Terminal)
local Rigs = require(script.Parent.Rigs)
local Terminal = require(script.Parent.Terminal)

local Contacts = {}
local models = {}

local COLORS = { Broker = Color3.fromRGB(60, 110, 80), Fixer = Color3.fromRGB(120, 90, 50), Dealer = Color3.fromRGB(50, 50, 64) }

-- Each contact's authored spots; the cycle (server/Cycle.lua) draws which one they stand at.
local function spots(id)
	if id == "Broker" then
		local c, g = F.Reach.Center, F.Reach.GateAngle or math.pi
		return {
			Vector3.new(c.X - 14, F.Floor, c.Z - 10), -- by the trader
			c + Vector3.new(math.sin(g) * (F.Reach.Radius - 20), 0, math.cos(g) * (F.Reach.Radius - 20)), -- inside the gate
			c + Vector3.new(math.sin(g + 2.2) * 148, 0, math.cos(g + 2.2) * 148), -- by a dome
		}
	elseif id == "Fixer" then
		return {
			Vector3.new(-60, F.CityTop, 40), -- under the span
			Vector3.new(0, F.CityTop, -400), -- Transit Hub plaza
			Vector3.new(-400, F.CityTop, 20), -- Sprawl plaza
		}
	else
		local o = F.Scarp.Overlook
		return {
			Vector3.new(o.X + 14, F.CityTop + 0.9, o.Z + 8), -- the overlook deck
			F.Switchbacks[3] + Vector3.new(-30, 0, 10), -- the second hairpin
			Vector3.new(F.Switchbacks[5].X + 20, F.Floor, F.Switchbacks[5].Z + 10), -- the scarp foot
		}
	end
end

local function placeAt(model, id, i)
	local list = spots(id)
	local spot = list[math.clamp(i, 1, #list)]
	local y = if F.InCity(spot.X, spot.Z) then F.CityTop else F.Height(spot.X, spot.Z)
	if id == "Dealer" and i == 1 then
		y = spot.Y
	end
	model:PivotTo(CFrame.new(spot.X, y + 3.5, spot.Z) * CFrame.Angles(0, math.rad(180), 0))
	model:SetAttribute("Spot", i)
end

-- The cycle's draw: every contact moves to one of its spots. Returns id -> spot index.
function Contacts.Place(rng)
	local placed = {}
	for id, model in models do
		if model.Parent then
			local i = rng:NextInteger(1, #spots(id))
			placeAt(model, id, i)
			placed[id] = i
		end
	end
	return placed
end

function Contacts.Spots(id)
	return spots(id)
end

local function build(id, def)
	local model, hum, root = Rigs.Build(Assets.Rigs.Raider, "Contact_" .. id)
	if not model then
		-- a box body when the rig is not there
		model = Instance.new("Model")
		model.Name = "Contact_" .. id
		root = Instance.new("Part")
		root.Name, root.Size = "HumanoidRootPart", Vector3.new(2, 5, 1)
		root.Parent = model
		hum = Instance.new("Humanoid")
		hum.Parent = model
		model.PrimaryPart = root
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			if p.Name:find("Torso") or p.Name:find("Arm") or p.Name:find("Leg") then
				p.Color = COLORS[id]
			end
		end
	end
	hum.DisplayName = def.Name
	hum.MaxHealth, hum.Health = 1e6, 1e6
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model:SetAttribute("Contact", id)
	placeAt(model, id, 1)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = def.Name, "Talk", 0.5
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 9, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		Terminal.Meet(player, id)
	end)
	model.Parent = workspace
	if model:GetAttribute("Rigged") or model:FindFirstChild("Head") then
		pcall(Rigs.Animate, model, hum)
	end
	models[id] = model
	return model
end

function Contacts.Get(id)
	return models[id]
end

function Contacts.Init()
	local n = 0
	for id, def in T.Contacts do
		local ok, err = pcall(build, id, def)
		if ok then
			n += 1
		else
			warn("[Contacts] failed to place", id, err)
		end
	end
	print(("[Contacts] %d contacts standing"):format(n))
end

return Contacts
