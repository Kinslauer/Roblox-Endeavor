-- Keys and locked rooms (round 6 of docs/Reference-Picks-Plan.md; idea from Tarkov, nothing copied). Breach doors open by
-- force; a key is the quiet way in. Each locked room has a door with an X prompt; the right key in the pack opens it
-- (the key is used up), the room's crate inside rolls its own table, and the hour relocks the door and refills the
-- crate (Cycle.Run -> Keys.Reset).
--   Strongrooms (StrongroomKey): small concrete lockups in the four core districts, placed where the ground is clear.
--   The S4 store cage (ShelterKey): a wire cage in the corner of Barrens Hall 2.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Loot = require(script.Parent.Loot)

local Keys = {}
local rooms = {} -- { Name, Key, Door, Crate, CrateCF, Table, Extra, Model }

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function stencil(p, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.PixelsPerStud, gui.LightInfluence = face, 72, 1
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, true
	l.Text, l.Font, l.TextColor3 = text, Enum.Font.Michroma, Color3.fromRGB(220, 200, 150)
	l.Parent = gui
	gui.Parent = p
end

local function fill(room)
	if room.Crate and room.Crate.Parent then
		room.Crate:Destroy()
	end
	local bundle = Items.Roll(room.Table)
	for id, n in room.Extra or {} do
		bundle[id] = (bundle[id] or 0) + n
	end
	room.Crate = Loot.Spawn(room.CrateCF, bundle, { Label = room.Name, Mesh = "CrateB", Lifetime = 1e9, Size = Vector3.new(3, 2, 2), Color = Color3.fromRGB(70, 74, 66) })
	if room.Crate then
		room.Crate.Anchored = true
	end
end

local function lock(room, locked)
	room.Locked = locked
	room.Door.CanCollide = locked
	room.Door.Transparency = if locked then 0 else 0.85
	room.Door:SetAttribute("Locked", locked)
	if room.Prompt then
		room.Prompt.Enabled = locked
	end
end

function Keys.Unlock(player, room)
	if not room.Locked then
		return false
	end
	local Inventory = require(script.Parent.Inventory)
	if Inventory.Count(player, room.Key) <= 0 then
		Remotes.Announce:FireClient(player, "> LOCKED . " .. (Config.World.Keys[room.Key] or "KEY"), "Warning")
		return false
	end
	Inventory.Remove(player, room.Key, 1)
	lock(room, false)
	Remotes.World:FireClient(player, "Unlocked", room.Door)
	return true
end

-- A room: a box with one open side closed by a door. cf faces out through the door.
local function room(name, key, cf, size, lootTable, parent, opts)
	local model = Instance.new("Model")
	model.Name = name
	local w, h, d = size.X, size.Y, size.Z
	local wall = opts.Wall or { Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 68, 66), Transparency = 0 }
	local function slab(nm, offset, sz)
		return part(model, { Name = nm, CFrame = cf * CFrame.new(offset), Size = sz, Material = wall.Material, Color = wall.Color, Transparency = wall.Transparency or 0 })
	end
	slab("Roof", Vector3.new(0, h - 0.5, 0), Vector3.new(w, 1, d))
	slab("Back", Vector3.new(0, h / 2, d / 2 - 0.5), Vector3.new(w, h, 1))
	slab("SideL", Vector3.new(-w / 2 + 0.5, h / 2, 0), Vector3.new(1, h, d))
	slab("SideR", Vector3.new(w / 2 - 0.5, h / 2, 0), Vector3.new(1, h, d))
	slab("FrontL", Vector3.new(-w / 4 - 1, h / 2, -d / 2 + 0.5), Vector3.new(w / 2 - 2, h, 1))
	slab("FrontR", Vector3.new(w / 4 + 1, h / 2, -d / 2 + 0.5), Vector3.new(w / 2 - 2, h, 1))
	slab("Lintel", Vector3.new(0, h - 1.5, -d / 2 + 0.5), Vector3.new(4, 3 - 0, 1))
	local door = part(model, { Name = "LockedDoor", CFrame = cf * CFrame.new(0, (h - 3) / 2, -d / 2 + 0.5), Size = Vector3.new(4, h - 3, 0.6),
		Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(96, 92, 80) })
	stencil(door, Enum.NormalId.Front, opts.Stencil or name)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText, prompt.HoldDuration = "", "Unlock", 1
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.KeyboardKeyCode = 7, false, Enum.KeyCode.X
	prompt.Parent = door
	model.Parent = parent
	local r = { Name = name, Key = key, Door = door, Prompt = prompt, Model = model, Table = lootTable, Extra = opts.Extra,
		CrateCF = cf * CFrame.new(0, 1.2, d / 2 - 2.5) }
	prompt.Triggered:Connect(function(player)
		Keys.Unlock(player, r)
	end)
	lock(r, true)
	fill(r)
	table.insert(rooms, r)
	return r
end

-- Where a strongroom can stand: near a core district's centre, on open ground (no parts in its box but the ground).
local function clearSpot(center, size)
	for ring = 0, 6 do
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + ring * 0.4
			local r = 30 + ring * 22
			local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local cf = CFrame.lookAt(Vector3.new(pos.X, Config.Megacity and 2 or 2, pos.Z), Vector3.new(center.X, 2, center.Z))
			local ok, parts = pcall(function()
				return workspace:GetPartBoundsInBox(cf * CFrame.new(0, size.Y / 2 + 0.6, 0), size + Vector3.new(4, 0, 4))
			end)
			if ok and parts and #parts == 0 then
				return cf
			end
		end
	end
	return nil
end

function Keys.Build()
	local folder = Instance.new("Folder")
	folder.Name = "Strongrooms"
	folder.Parent = workspace
	local City = require(script.Parent.City)
	local size = Vector3.new(10, 8, 9)
	for _, d in City.Districts do
		if not d.Outer then
			local cf = clearSpot(d.Center, size)
			if cf then
				room("Strongroom", "StrongroomKey", cf, size, "Vault", folder, { Stencil = "STRONGROOM" })
			end
		end
	end
	-- the S4 store cage, in the hall's north-east corner below the Sumps
	local okB, Barrens = pcall(require, script.Parent.Barrens)
	local level = okB and Barrens.Level and Barrens.Level()
	if level and level.Model then
		local o = level.Origin
		room("S4 Store", "ShelterKey", CFrame.lookAt(o + Vector3.new(182, 0, 43), o + Vector3.new(182, 0, 30)), Vector3.new(12, 8, 10), "Barrens", level.Model,
			{ Stencil = "S4 . STORE", Extra = { DataShard = 1 }, Wall = { Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(80, 84, 88), Transparency = 0.55 } })
	end
	return rooms
end

function Keys.Reset()
	for _, r in rooms do
		lock(r, true)
		fill(r)
	end
end

function Keys.Rooms()
	return rooms
end

function Keys.Init()
	Keys.Build()
end

return Keys
