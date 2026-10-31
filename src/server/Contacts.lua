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

local function spotFor(id)
	if id == "Broker" then
		local c = F.Reach.Center
		return Vector3.new(c.X - 14, F.Floor, c.Z - 10)
	elseif id == "Fixer" then
		return Vector3.new(-60, F.CityTop, 40)
	else
		local o = F.Scarp.Overlook
		return Vector3.new(o.X + 14, F.CityTop + 0.9, o.Z + 8)
	end
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
	local spot = spotFor(id)
	model:PivotTo(CFrame.new(spot + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(180), 0))
	model:SetAttribute("Contact", id)
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
