-- Contacts (Phase 3, build order 6; design/gdd/raids.md): the three people who open the hideout
-- computer's apps - the broker (RAIDS) in Verdant Market, the fixer (HOUSE) in Ferrite Court, the
-- dealer (MARKET) out on the road by the wrecks. Each is a standing body with a Talk prompt; nothing
-- announces them, you find them. They cannot be hurt and nothing hunts them (not Combatants). Each
-- cycle they may stand somewhere else (Contacts.Place; Raids.Contacts[id].Spots).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local District = require(Shared.District)
local R = require(Shared.Raids)
local Rig = require(script.Parent.Rig)
local Terminal = require(script.Parent.Terminal)

local Contacts = {}

local models = {} -- id -> the standing body

local LOOKS = {
	Broker = { BodyType = 2, SkinTone = 3, Face = 1, Hair = 3, HairColor = 1, Cloth = Color3.fromRGB(60, 90, 70) },
	Fixer = { BodyType = 1, SkinTone = 5, Face = 1, Hair = 2, HairColor = 4, Cloth = Color3.fromRGB(90, 70, 50) },
	Dealer = { BodyType = 3, SkinTone = 2, Face = 1, Hair = 1, HairColor = 2, Cloth = Color3.fromRGB(40, 40, 48) },
}
local CLOTH_PARTS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }

local function build(id, def)
	local look = LOOKS[id]
	local model = Rig.Build({ BodyType = look.BodyType, SkinTone = look.SkinTone, Face = look.Face, Hair = look.Hair, HairColor = look.HairColor })
	model.Name = "Contact_" .. id
	for _, partName in CLOTH_PARTS do
		local part = model:FindFirstChild(partName)
		if part then
			part.Color = look.Cloth
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = def.Name
	hum.HealthDisplayDistance = 0
	hum.NameDisplayDistance = 40
	local root = model.HumanoidRootPart
	model:PivotTo(CFrame.new(def.Position + Vector3.new(0, District.GroundTop + 3.5, 0)))
	root.Anchored = true -- stands where they stand
	local ff = Instance.new("ForceField") -- Combat refuses to hurt a ForceField
	ff.Visible = false
	ff.Parent = model
	model:SetAttribute("Contact", id)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = def.Name, "Talk", 0.5
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 9, false
	prompt.KeyboardKeyCode = Enum.KeyCode.X
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		Terminal.Meet(player, id)
	end)
	model:SetAttribute("Spot", 1)
	model.Parent = workspace
	models[id] = model
	return model
end

-- The cycle (server/Cycle.lua) re-draws where each contact stands: one of its authored Spots.
function Contacts.Place(rng)
	local placed = {}
	for id, model in models do
		local def = R.Contacts[id]
		if model.Parent and def and def.Spots then
			local i = rng:NextInteger(1, #def.Spots)
			model:PivotTo(CFrame.new(def.Spots[i] + Vector3.new(0, District.GroundTop + 3.5, 0)))
			model:SetAttribute("Spot", i)
			placed[id] = i
		end
	end
	return placed
end

function Contacts.Get(id)
	return models[id]
end

function Contacts.Init()
	local n = 0
	for id, def in R.Contacts do
		local ok, err = pcall(build, id, def)
		if ok then
			n += 1
		else
			warn("[Contacts] failed to place", id, err)
		end
	end
	Contacts.Built = { Count = n }
end

return Contacts
