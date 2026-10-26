-- HouseView (Phase 3, build order 6): the furnishings you ordered from the hideout computer's HOUSE
-- app, drawn in the hideout room for you alone. The room is shared geometry for now, so the server
-- only publishes what you own (the House player attribute, JSON); this client builds the props
-- locally, which keeps the hideout feeling like yours. Pure presentation.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local District = require(Shared:WaitForChild("District"))

local HouseView = {}

local player = Players.LocalPlayer
local O = Config.Hideout.Origin
local S = Config.Hideout.Size
local TOP = District.GroundTop
local folder

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

-- One builder per furnishing id (shared/Raids.lua House). Positions are in the room, away from the consoles.
local BUILDERS = {
	Rug = function()
		part({ Name = "Rug", Size = Vector3.new(22, 0.2, 14), Position = O + Vector3.new(0, TOP + 0.11, 0), Color = Color3.fromRGB(140, 60, 60), Material = Enum.Material.Fabric })
		part({ Name = "RugBorder", Size = Vector3.new(18, 0.22, 10), Position = O + Vector3.new(0, TOP + 0.12, 0), Color = Color3.fromRGB(200, 170, 110), Material = Enum.Material.Fabric })
	end,
	Lamp = function()
		part({ Name = "LampPost", Size = Vector3.new(0.4, 7, 0.4), Position = O + Vector3.new(14, TOP + 3.5, -S / 2 + 20), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal })
		local shade = part({ Name = "LampShade", Size = Vector3.new(2.4, 1.6, 2.4), Position = O + Vector3.new(14, TOP + 7.5, -S / 2 + 20), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 220, 160), 26, 1.4
		light.Parent = shade
	end,
	Shelf = function()
		for i = 0, 2 do
			part({ Name = "Shelf", Size = Vector3.new(8, 0.3, 1.6), Position = O + Vector3.new(S / 2 - 4, TOP + 2 + i * 2.2, -8), Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Wood })
			part({ Name = "ShelfThing", Size = Vector3.new(1.2 + i * 0.4, 1.2, 1), Position = O + Vector3.new(S / 2 - 4 - 2 + i * 1.5, TOP + 2.8 + i * 2.2, -8), Color = Color3.fromRGB(70 + i * 40, 90, 110), Material = Enum.Material.Plastic })
		end
	end,
	Plant = function()
		part({ Name = "Pot", Size = Vector3.new(2, 1.8, 2), Position = O + Vector3.new(-S / 2 + 6, TOP + 0.9, -S / 2 + 6), Color = Color3.fromRGB(160, 110, 80), Material = Enum.Material.SmoothPlastic })
		part({ Name = "Fern", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3, 4), Position = O + Vector3.new(-S / 2 + 6, TOP + 3, -S / 2 + 6), Color = Color3.fromRGB(80, 160, 80), Material = Enum.Material.Grass })
	end,
	Poster = function()
		local poster = part({ Name = "Poster", Size = Vector3.new(6, 8, 0.1), Position = O + Vector3.new(0, TOP + 9, S / 2 - 1.9), Color = Color3.fromRGB(230, 200, 150), Material = Enum.Material.SmoothPlastic })
		part({ Name = "PosterArt", Size = Vector3.new(5, 4, 0.12), Position = O + Vector3.new(0, TOP + 10.5, S / 2 - 1.95), Color = Color3.fromRGB(60, 120, 200), Material = Enum.Material.SmoothPlastic })
		part({ Name = "PosterLine", Size = Vector3.new(4.4, 0.5, 0.12), Position = O + Vector3.new(0, TOP + 6.6, S / 2 - 1.95), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.SmoothPlastic })
		poster.Name = "Poster"
	end,
	Couch = function()
		part({ Name = "CouchSeat", Size = Vector3.new(10, 1.6, 4), Position = O + Vector3.new(0, TOP + 0.8, 14), Color = Color3.fromRGB(70, 80, 110), Material = Enum.Material.Fabric })
		part({ Name = "CouchBack", Size = Vector3.new(10, 3, 1), Position = O + Vector3.new(0, TOP + 2.3, 15.8), Color = Color3.fromRGB(70, 80, 110), Material = Enum.Material.Fabric })
		for _, dx in { -4.8, 4.8 } do
			part({ Name = "CouchArm", Size = Vector3.new(0.6, 2.4, 4), Position = O + Vector3.new(dx, TOP + 1.6, 14), Color = Color3.fromRGB(60, 70, 95), Material = Enum.Material.Fabric })
		end
	end,
}

local function rebuild()
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "HouseView"
	folder.Parent = workspace
	local ok, owned = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("House") or "{}")
	if not (ok and type(owned) == "table") then
		return
	end
	for id, has in owned do
		local builder = has and BUILDERS[id]
		if builder then
			builder()
		end
	end
end

function HouseView.Init()
	player:GetAttributeChangedSignal("House"):Connect(rebuild)
	rebuild()
end

return HouseView
