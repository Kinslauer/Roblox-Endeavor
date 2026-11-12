-- Kit (Endeavor, round 2 of docs/Reference-Picks-Plan.md): what the body carries and where.
-- A conduit holds one weapon and can carry a second: a long one across the back on a sling, a short one in a
-- holster the kit gives (a belt at the hip or thigh, a rig on the chest). Key 1 swaps them, even mid-chain
-- (Combat keeps the chain going into the other weapon). The rig and belt are drawn on the body from parts, the
-- carried weapon rides at its mount, magazine pouches speed reloads, med pouches let key 2 dress the worst wound
-- without opening the pack, and a plate carrier's plate stops rounds over the chest (the Vest attribute that
-- Combat.HitZone already reads on guards).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared.Armor)
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)
local HeldWeapons = require(script.Parent.Common.HeldWeapons)

local K = Config.Kit
local Kit = {}

-- where the second weapon would ride, or nil if the kit has no place for it
function Kit.MountFor(data, weaponId)
	local def = Weapons.Defs[weaponId]
	if not def or weaponId == "Fists" then
		return nil
	end
	if K.Long[def.Family] then
		return "Back"
	end
	local kit = Armor.Kit(data and data.Armor)
	for _, mount in { "Hip", "Thigh", "Chest" } do
		if kit.Holster[mount] then
			return mount
		end
	end
	return nil
end

-- Where each mount puts the weapon, in the carrying limb's space (the proxy limbs of a skinned body are the real
-- boxes): the point its middle should sit on, and the way its business end should point. The models do not share
-- one convention (melee, pistols and guns built from parts are authored differently), so the turn is found from
-- the model itself: the line from the grip to the model's middle is turned onto `want`.
local function mountSpot(mount, part, length)
	local h = part.Size / 2
	if mount == "Back" then
		return Vector3.new(0, 0, h.Z + 0.24), Vector3.new(-0.6, 0.8, 0) -- across the back, grip low on the right
	elseif mount == "Hip" then
		return Vector3.new(h.X + 0.22, h.Y * 0.4 - length * 0.5, 0.05), Vector3.new(0, -1, 0.12)
	elseif mount == "Thigh" then
		return Vector3.new(h.X + 0.2, h.Y * 0.3 - length * 0.4, 0), Vector3.new(0, -1, 0)
	end
	return Vector3.new(-h.X * 0.15, h.Y * 0.1, -h.Z - 0.3), Vector3.new(-0.6, -0.8, 0) -- Chest: cross-draw
end

local function seat(model, holder, mount)
	local primary = model.PrimaryPart
	local grip = primary and primary:FindFirstChild("Grip")
	if not grip then
		return
	end
	local centre = model:GetBoundingBox().Position
	-- grip to middle, in the frame C0 places (Part1 = Part0 * C0 * C1:Inverse())
	local u = grip.C1:PointToObjectSpace(primary.CFrame:PointToObjectSpace(centre))
	if u.Magnitude < 0.05 then
		return
	end
	local spot, want = mountSpot(mount, holder, u.Magnitude * 2)
	local turn = CFrame.fromRotationBetweenVectors(u.Unit, want.Unit)
	grip.C0 = CFrame.new(spot - turn:VectorToWorldSpace(u)) * turn
end
Kit.Seat = seat -- probes
local HOLDER = { Back = "UpperTorso", Hip = "LowerTorso", Thigh = "RightUpperLeg", Chest = "UpperTorso" }

local function piece(parent, holder, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Fabric
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, true
	p.CFrame = holder.CFrame * cf
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = holder, p
	weld.Parent = p
	p.Parent = parent
	return p
end

local OLIVE, TAN, BLACK = Color3.fromRGB(70, 74, 56), Color3.fromRGB(122, 108, 82), Color3.fromRGB(30, 31, 33)

-- the look of the worn rig and belt (rebuilt on every Stats.Apply)
local function drawKit(char, worn)
	local old = char:FindFirstChild("KitWorn")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "KitWorn"
	local torso, hips = char:FindFirstChild("UpperTorso"), char:FindFirstChild("LowerTorso")
	local rig, belt = worn and worn.Rig, worn and worn.Belt
	if torso and rig then
		local t = torso.Size / 2
		local color = if rig == "PlateCarrier" then OLIVE else TAN
		if rig == "PlateCarrier" then
			piece(folder, torso, "PlateFront", Vector3.new(t.X * 1.5, t.Y * 1.5, 0.18), CFrame.new(0, -t.Y * 0.05, -t.Z - 0.09), color)
			piece(folder, torso, "PlateBack", Vector3.new(t.X * 1.5, t.Y * 1.6, 0.18), CFrame.new(0, -t.Y * 0.05, t.Z + 0.09), color)
		else
			piece(folder, torso, "VestFront", Vector3.new(t.X * 1.7, t.Y * 1.4, 0.1), CFrame.new(0, -t.Y * 0.1, -t.Z - 0.05), color)
		end
		for i = -1, 1 do -- magazine pouches across the front
			piece(folder, torso, "MagPouch", Vector3.new(t.X * 0.36, t.Y * 0.5, 0.2), CFrame.new(i * t.X * 0.42, -t.Y * 0.5, -t.Z - 0.28), color:Lerp(BLACK, 0.2))
		end
		piece(folder, torso, "StrapL", Vector3.new(0.22, 0.08, t.Z * 2.2), CFrame.new(-t.X * 0.45, t.Y + 0.04, 0), color)
		piece(folder, torso, "StrapR", Vector3.new(0.22, 0.08, t.Z * 2.2), CFrame.new(t.X * 0.45, t.Y + 0.04, 0), color)
	end
	if hips and belt then
		local h = hips.Size / 2
		piece(folder, hips, "BeltBand", Vector3.new(h.X * 2 + 0.1, 0.22, h.Z * 2 + 0.1), CFrame.new(0, h.Y * 0.3, 0), BLACK)
		piece(folder, hips, "MedPouch", Vector3.new(0.34, 0.34, 0.26), CFrame.new(-h.X * 0.5, h.Y * 0.1, h.Z + 0.16), TAN)
		if belt == "DropLegRig" then
			local leg = char:FindFirstChild("RightUpperLeg")
			if leg then
				local l = leg.Size / 2
				piece(folder, leg, "LegPlatform", Vector3.new(0.12, l.Y * 1.1, l.Z * 1.3), CFrame.new(l.X + 0.07, l.Y * 0.2, 0), BLACK)
			end
		end
	end
	folder.Parent = char
end

-- Stats.Apply: draws the kit, stows the second weapon, sets the body's attributes for the clients and Combat.
function Kit.Apply(player, char)
	local data = PlayerData.Get(player)
	if not (data and char) then
		return
	end
	local kit = Armor.Kit(data.Armor)
	pcall(drawKit, char, data.Armor)
	char:SetAttribute("Vest", if kit.Plate > 0 then kit.Plate else nil) -- Combat.HitZone: the chest plate
	char:SetAttribute("KitMags", kit.Mags)
	char:SetAttribute("KitMeds", kit.Meds)
	local second = data.Second
	if second and second ~= "" and ((data.Inventory[second] or 0) <= 0 or second == data.Equipped or not Kit.MountFor(data, second)) then
		data.Second = nil -- lost, now in hand, or the kit that carried it came off: it goes back in the pack
		second = nil
	end
	char:SetAttribute("Second", second)
	local mount = second and Kit.MountFor(data, second)
	local holder = mount and char:FindFirstChild(HOLDER[mount])
	local stowed = char:FindFirstChild("StowedWeapon")
	if not holder then
		if stowed then
			stowed:Destroy()
		end
		return
	end
	if stowed and stowed:GetAttribute("WeaponId") == second and stowed:GetAttribute("Mount") == mount then
		return
	end
	local id, attachments, opts = Weapons.Held(second)
	opts = table.clone(opts or {})
	opts.Name, opts.Part, opts.C0 = "StowedWeapon", HOLDER[mount], CFrame.new()
	local model = HeldWeapons.Attach(char, id, attachments, opts)
	if model then
		model:SetAttribute("Mount", mount)
		seat(model, holder, mount)
	end
end

-- Equipping a weapon while another is in hand: the old one goes to its mount if the kit has a place for it.
function Kit.OnEquip(data, newId, oldId)
	if newId == data.Second then
		data.Second = if oldId ~= "Fists" and Kit.MountFor(data, oldId) then oldId else nil
	elseif oldId and oldId ~= "Fists" and oldId ~= newId and Kit.MountFor(data, oldId) then
		data.Second = oldId
	end
end

-- Key 1: the carried weapon to the hand, the held one to its mount.
function Kit.Swap(player)
	local data = PlayerData.Get(player)
	local char = player.Character
	local Combat = require(script.Parent.Combat)
	if not (data and char and data.Second and data.Second ~= "") then
		return false
	end
	if not Combat.CanSwap(char) then
		return false
	end
	local held, carried = data.Equipped, data.Second
	if held ~= "Fists" and not Kit.MountFor(data, held) then
		return false -- nowhere to put the one in your hand
	end
	data.Equipped, data.Second = carried, (if held ~= "Fists" then held else nil)
	Combat.Swapped(char, K.SwapSeconds)
	Remotes.CombatEvent:FireAllClients("Swap", char, Kit.MountFor(data, carried))
	local Gear = require(script.Parent.Gear)
	Gear.Recompute(player)
	return true
end

-- Key 2: dress the worst wound from the med pouches. Needs a pouch and a treatment in the pack.
local ORDER = {
	{ "Heavy", { "Tourniquet", "Hemostat" } },
	{ "Light", { "Bandage", "Hemostat", "Medkit" } },
	{ "Broken", { "Splint" } },
	{ "Pain", { "Painkillers" } },
}
function Kit.QuickMed(player)
	local char = player.Character
	local data = PlayerData.Get(player)
	local Combat = require(script.Parent.Combat)
	if not (char and data and (char:GetAttribute("KitMeds") or 0) > 0 and Combat.CanAct(char)) then
		return nil
	end
	local Inventory = require(script.Parent.Inventory)
	local Medicine = require(script.Parent.Medicine)
	local need = {}
	for _, part in { "Head", "Chest", "Stomach", "ArmL", "ArmR", "LegL", "LegR" } do
		local b = char:GetAttribute("Bleed_" .. part)
		if b == "Heavy" or b == "Light" then
			need[b] = true
		end
		if char:GetAttribute("Broken_" .. part) then
			need.Broken = true
		end
	end
	need.Pain = (char:GetAttribute("Pain") or 0) > 0.3
	for _, row in ORDER do
		if need[row[1]] then
			for _, id in row[2] do
				local def = Items.Defs[id]
				if Inventory.Count(player, id) > 0 and def and Medicine.Use(player, def) then
					Inventory.Remove(player, id, 1)
					Combat.SetBusy(char, K.MedSeconds)
					Remotes.CombatEvent:FireAllClients("QuickMed", char, id)
					return id
				end
			end
		end
	end
	return nil
end

function Kit.Init()
	Net.On("Swap", { rate = 4, burst = 4 }, Kit.Swap)
	Net.On("QuickMed", { rate = 2, burst = 2 }, Kit.QuickMed)
end

return Kit
