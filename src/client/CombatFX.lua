-- CombatFX: the single subscriber to Remotes.CombatEvent. Dispatches by kind to handlers that other
-- presentation modules register (Impacts, SwingAnimator, WeaponView, Audio ...). Presentation only: the
-- one piece of state it touches is the local character's own root velocity, which the client owns.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

function CombatFX.Init()
	-- Built-in handlers: own-character physics, skill cooldowns, and a Highlight pulse for every
	-- impact kind. Impacts / SwingAnimator / Audio add the richer effects via CombatFX.On.
	local function ownVelocity(v)
		local root = rootOf(player.Character)
		if root and typeof(v) == "Vector3" then
			root.AssemblyLinearVelocity = v -- we own our character's physics
		end
	end
	CombatFX.On("DodgeMove", ownVelocity)
	CombatFX.On("Knockback", ownVelocity)
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
