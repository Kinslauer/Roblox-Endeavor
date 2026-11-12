-- Bodies: the recruits' bodies on the Front, in layers (Andy, 2026-11-12: "They need to be able to be stripped of all
-- gear, so the base clothing layer should look more bare ... basic battle attire acquired after leaving the tank and
-- entering the barracks. They also need rigging for cybernetics and large armor sets").
--
-- Every recruit is a clone from the same tank line: one rig (Assets.Rigs.Soldier, the StarterCharacter built here) and
-- one bare body (Assets.Skins.Recruit, tools/models/figures.py). What shows on it is decided by groups (Rigs.Dress):
--   Under    the tank wrap: all a clone has until it reaches the barracks
--   Attire   the basic battle attire: undershirt, trousers, boots, the side's armband (cloth tinted by side)
--   Kit      the side's field kit, a layer of its own (Assets.Skins.UnionKit / PactKit): coat, face wear, webbing.
--            A recruit wears it while it carries a primary weapon, and loses it when its body is stripped.
--   Helmet, Vest, Plates   the armour it owns
-- Further layers go over the same body: Bodies.Augment(char, "CyberLimbs", { CyArmL = true }) swaps a limb for a
-- cybernetic one, Bodies.Augment(char, "HeavyArmor", { Heavy = true }) puts on a large armour set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Firearms = require(ReplicatedStorage.Shared.Firearms)
local Rigs = require(script.Parent.Common.Rigs)
local ModelAssets = require(script.Parent.Common.ModelAssets)
local SurfaceLibrary = require(script.Parent.Common.SurfaceLibrary)

local Bodies = {}
Bodies.Ready = false

local function sideOf(faction)
	return if Assets.Skins[tostring(faction) .. "Kit"] then faction else "Union"
end

local function sideTints(faction)
	local spec = Assets.Skins.Recruit
	return spec and spec.Factions and spec.Factions[sideOf(faction)]
end

-- Builds the StarterCharacter. When it fails players keep their Roblox avatars and the old welded gear.
function Bodies.Init()
	SurfaceLibrary.Init() -- the skin, fabrics and steel the bodies wear
	local id = Assets.Rigs.Soldier
	local model, hum, root = nil, nil, nil
	if id and id ~= 0 then
		model, hum, root = Rigs.Build(id, "StarterCharacter", "Recruit")
	end
	if not (model and model:GetAttribute("Skinned")) then
		if model then
			model:Destroy()
		end
		warn("[Bodies] the recruit body did not build; recruits keep their avatars")
		return false
	end
	model.Skin:Destroy() -- each recruit gets its own body at spawn (its side's colours); the limbs stay invisible
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
	-- load every layer now, not under the first spawn
	for _, kind in { "UnionKit", "PactKit", "CyberLimbs", "HeavyArmor" } do
		if Assets.Skins[kind] then
			ModelAssets.Template(Assets.Skins[kind].Id)
		end
	end
	for _, id2 in Assets.FrontBodies.Fallen do
		ModelAssets.Template(id2)
	end
	-- the first-person hands (war/client/Fingers.lua): the pieces wait in ReplicatedStorage for each client to copy.
	-- The gun in the view and these hands are in a collision group of their own, so the fingers' rays find them
	-- and nothing else in the game does.
	pcall(function()
		local PhysicsService = game:GetService("PhysicsService")
		PhysicsService:RegisterCollisionGroup("ViewGun")
		PhysicsService:CollisionGroupSetCollidable("ViewGun", "Default", false)
	end)
	local okHands, hands = pcall(ModelAssets.Template, Assets.FrontBodies.Hands)
	if okHands and hands then
		local folder = Instance.new("Folder")
		folder.Name = "ViewHands"
		for _, p in hands:GetDescendants() do
			if p:IsA("MeshPart") then
				local c = p:Clone()
				c.Anchored, c.CanCollide, c.CanTouch = true, false, false
				c.Parent = folder
			end
		end
		Assets.Dress(folder)
		folder.Parent = game:GetService("ReplicatedStorage")
	else
		warn("[Bodies] the first-person hands did not load; hands stay as they are")
	end
	Bodies.Ready = true
	print("[Bodies] recruits spawn in the layered recruit body")
	return true
end

-- Puts the body and its side's kit layer on a freshly loaded character, in its battle attire.
function Bodies.Dress(char, faction)
	if not (Bodies.Ready and char) then
		return false
	end
	if not Rigs.Skin(char, "Recruit", sideTints(faction)) then
		return false
	end
	Rigs.Layer(char, sideOf(faction) .. "Kit")
	Rigs.Dress(char, { Attire = true })
	return true
end

-- The groups a recruit's state shows (s = Soldiers' live state).
function Bodies.Look(s)
	local bare = s.Bare == true
	local armor = s.Armor and s.Armor.Id
	return {
		Under = bare,
		Attire = not bare,
		Kit = not bare and s.Weapons ~= nil and s.Weapons.Primary ~= nil,
		Helmet = s.Helmet ~= nil,
		Vest = armor ~= nil,
		Plates = armor == "SteelPlate",
	}
end

-- Shows what the recruit has now. False when the character has no such body (an avatar).
function Bodies.Wear(char, s)
	if not (char and char:GetAttribute("Skinned") == true) then
		return false
	end
	local on = Bodies.Look(s)
	for id, piece in s.Cyber or {} do -- the limbs the conduit shipped
		local def = Firearms.Cyber[id]
		if def and piece and Rigs.Layer(char, "CyberLimbs") then
			on[def.Group] = true
		end
	end
	for name, value in char:GetAttributes() do -- groups switched on by Bodies.Augment
		local group = name:match("^Group_(.+)$")
		if group and value == true then
			on[group] = true
		end
	end
	return Rigs.Dress(char, on)
end

-- Lays another layer over a recruit's body and switches groups of it on or off: cybernetic limbs
-- ("CyberLimbs": CyArmL, CyArmR, CyLegL, CyLegR), a large armour set ("HeavyArmor": Heavy). The next Bodies.Wear
-- (any change of gear) keeps them. Returns true when the layer is on the body.
function Bodies.Augment(char, layer, groups)
	if not (char and char:GetAttribute("Skinned") == true and Rigs.Layer(char, layer)) then
		return false
	end
	for group, on in groups do
		char:SetAttribute("Group_" .. group, on == true or nil)
	end
	return true
end

-- A fallen recruit lying on the ground at `cf` (yaw kept), in its side's colours, wearing what `on` says
-- (Bodies.Look of the recruit as it died). Returns the Model or nil.
function Bodies.Fallen(faction, cf, parent, on)
	local side = sideOf(faction)
	local model = ModelAssets.Spawn(Assets.FrontBodies.Fallen[side], cf, "Fallen", parent)
	if not model then
		return nil
	end
	local base, kit, over = Assets.Skins.Recruit, Assets.Skins[side .. "Kit"], sideTints(faction)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			local tint = (over and over[p.Name]) or (kit and kit.Tints[p.Name]) or (base and base.Tints[p.Name])
			if tint then
				Assets.Tint(p, tint)
			end
			p:SetAttribute("BaseT", p.Transparency)
		end
	end
	model:SetAttribute("Side", side)
	Bodies.Strip(model, on or { Attire = true })
	return model
end

-- What a fallen body still wears. With no `on`: stripped to its battle attire (somebody took the gear).
function Bodies.Strip(fallen, on)
	local parts = {}
	for _, p in fallen:GetDescendants() do
		if p:IsA("MeshPart") then
			table.insert(parts, p)
		end
	end
	Rigs.DressParts(parts, { "Recruit", tostring(fallen:GetAttribute("Side")) .. "Kit" }, on or { Attire = true })
end

return Bodies
