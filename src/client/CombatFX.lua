-- CombatFX: the single subscriber to Remotes.CombatEvent. Dispatches by kind to handlers that other
-- presentation modules register (SwingAnimator, WeaponView, Audio ...). Presentation only: the
-- one piece of state it touches is the local character's own root velocity, which the client owns.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Presentation = require(Shared:WaitForChild("Presentation"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local CombatFX = {}
-- kind -> { fn(a, b), ... }. Several modules may listen to the same kind.
CombatFX.Handlers = {}

function CombatFX.On(kind, fn)
	local list = CombatFX.Handlers[kind]
	if not list then
		list = {}
		CombatFX.Handlers[kind] = list
	end
	table.insert(list, fn)
end

-- Folder for short-lived placeholder parts so they can be counted and capped.
local fxFolder
function CombatFX.Folder()
	if not fxFolder or not fxFolder.Parent then
		fxFolder = workspace:FindFirstChild("FX") or Instance.new("Folder")
		fxFolder.Name = "FX"
		fxFolder.Parent = workspace
	end
	return fxFolder
end

function CombatFX.Spawn(part, lifetime)
	local folder = CombatFX.Folder()
	if #folder:GetChildren() >= Presentation.Impacts.MaxInstances then
		part:Destroy()
		return nil
	end
	part.Parent = folder
	Debris:AddItem(part, lifetime)
	return part
end

local function rootOf(char)
	return typeof(char) == "Instance" and char:FindFirstChild("HumanoidRootPart")
end

-- Short Highlight pulse on a character.
function CombatFX.Flash(char, color, seconds)
	if typeof(char) ~= "Instance" then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor, h.FillTransparency, h.OutlineTransparency = color, 0.4, 1
	h.Parent = char
	Debris:AddItem(h, seconds)
end

local function blackFlash(attacker, victim)
	local spec = Presentation.Impacts.BlackFlash
	local vroot = rootOf(victim)
	if vroot then
		local spark = Instance.new("Part")
		spark.Shape, spark.Anchored, spark.CanCollide, spark.CanQuery = Enum.PartType.Ball, true, false, false
		spark.Material, spark.Color, spark.Size, spark.Position = Enum.Material.Neon, spec.Color, Vector3.new(2, 2, 2), vroot.Position
		if CombatFX.Spawn(spark, spec.Flash + 0.05) then
			TweenService:Create(spark, TweenInfo.new(spec.Flash), { Size = Vector3.new(12, 12, 12), Transparency = 1 }):Play()
		end
	end
	if attacker == player.Character or victim == player.Character then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = -0.35, 0.6, -1, Color3.fromRGB(255, 120, 120)
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(0.4), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(cc, 0.5)
		Hud.Banner(("BLACK FLASH  x%.1f"):format(Config.Flicker.BlackFlashMult), spec.Color, spec.BannerSeconds)
	end
end

local function bolt(char, hitPos)
	local from = rootOf(char)
	if not from or typeof(hitPos) ~= "Vector3" then
		return
	end
	local length = (hitPos - from.Position).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.Material = true, false, false, Enum.Material.Neon
	beam.Color, beam.Size = Presentation.Impacts.Bolt.Color, Vector3.new(0.2, 0.2, length)
	beam.CFrame = CFrame.lookAt(from.Position, hitPos) * CFrame.new(0, 0, -length / 2)
	CombatFX.Spawn(beam, Presentation.Impacts.Bolt.Flash)
end

function CombatFX.Init()
	-- Built-in handlers (the pre-split behaviour). Stories 002-005 add more via CombatFX.On.
	local function ownVelocity(v)
		local root = rootOf(player.Character)
		if root and typeof(v) == "Vector3" then
			root.AssemblyLinearVelocity = v -- we own our character's physics
		end
	end
	CombatFX.On("DodgeMove", ownVelocity)
	CombatFX.On("Knockback", ownVelocity)
	CombatFX.On("BlackFlash", blackFlash)
	CombatFX.On("Bolt", bolt)
	CombatFX.On("SkillCD", function(skillId, seconds)
		Hud.SetCooldown(skillId, seconds)
	end)
	for kind, spec in Presentation.Impacts do
		if type(spec) == "table" and spec.Flash and kind ~= "BlackFlash" and kind ~= "Bolt" then
			CombatFX.On(kind, function(char)
				CombatFX.Flash(char, spec.Color, spec.Flash)
			end)
		end
	end

	Remotes.CombatEvent.OnClientEvent:Connect(function(kind, a, b)
		local list = CombatFX.Handlers[kind]
		if not list then
			return
		end
		for _, fn in list do
			local ok, err = pcall(fn, a, b)
			if not ok then
				warn(("[CombatFX] %s handler failed: %s"):format(tostring(kind), tostring(err)))
			end
		end
	end)
end

return CombatFX
