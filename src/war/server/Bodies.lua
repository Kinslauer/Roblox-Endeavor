-- Bodies: the recruits' bodies on the Front (Andy, 2026-11-12: "can you give the front models the same treatment?").
-- Every recruit is a clone from the same tank line, so both sides share one rig (Assets.Rigs.Soldier, the
-- StarterCharacter built here) and put on their side's one-piece body when they spawn (Assets.Skins.Union / Pact,
-- tools/models/figures.py). Helmet, flak vest and plates are pieces of that body, shown when the recruit owns them
-- (Rigs.Wear). The fallen leave a body of the same build (Assets.FrontBodies.Fallen) and calcify into one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Rigs = require(script.Parent.Common.Rigs)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local SurfaceLibrary = require(script.Parent.Common.SurfaceLibrary)

local Bodies = {}
Bodies.Ready = false

-- Builds the StarterCharacter. When it fails players keep their Roblox avatars and the old welded gear.
function Bodies.Init()
	SurfaceLibrary.Init() -- the fabrics and steel the bodies wear
	local id = Assets.Rigs.Soldier
	local model, hum, root = nil, nil, nil
	if id and id ~= 0 then
		model, hum, root = Rigs.Build(id, "StarterCharacter", "Union")
	end
	if not (model and model:GetAttribute("Skinned")) then
		if model then
			model:Destroy()
		end
		warn("[Bodies] the soldier body did not build; recruits keep their avatars")
		return false
	end
	model.Skin:Destroy() -- each recruit puts on its own side's body at spawn; the limbs stay invisible
	model:SetAttribute("Skinned", false)
	model:SetAttribute("StockAnimations", true) -- character/Animate: Roblox's walk and idle; the Front poses stances itself
	root.Anchored = false
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	model.Parent = StarterPlayer
	-- load both sides' bodies and the fallen now, not under the first spawn
	for _, kind in { "Union", "Pact" } do
		ModelAssets.Template(Assets.Skins[kind].Id)
		ModelAssets.Template(Assets.FrontBodies.Fallen[kind])
	end
	Bodies.Ready = true
	print("[Bodies] recruits spawn in the soldier body")
	return true
end

-- Puts a faction's body on a freshly loaded character.
function Bodies.Dress(char, faction)
	if not (Bodies.Ready and char) then
		return false
	end
	return Rigs.Skin(char, if Assets.Skins[faction] then faction else "Union")
end

-- Shows the helmet, vest and plates the recruit owns. False when the character has no such body (an avatar).
function Bodies.Wear(char, itemIds)
	return char ~= nil and char:GetAttribute("Skinned") == true and Rigs.Wear(char, itemIds)
end

-- A fallen recruit lying on the ground at `cf` (yaw kept), in its side's colours. Returns the Model or nil.
function Bodies.Fallen(faction, cf, parent)
	local kind = if Assets.Skins[faction] then faction else "Union"
	local model = ModelAssets.Spawn(Assets.FrontBodies.Fallen[kind], cf, "Fallen", parent)
	if not model then
		return nil
	end
	local tints = (Assets.Skins[kind] and Assets.Skins[kind].Tints) or {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			if tints[p.Name] then
				Assets.Tint(p, tints[p.Name])
			end
		end
	end
	return model
end

return Bodies
