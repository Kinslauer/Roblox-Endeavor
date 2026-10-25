-- Flickering cursed energy: the chain level (character attribute "Flicker") and the Zone ("Zone")
-- are drawn on every character as a flickering dark/red aura. Attribute-driven, so it needs no
-- remote and works for every character the client can see.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hud = require(script.Parent.Hud)

local FlickerAura = {}

local AURA_FILL = Color3.new(0, 0, 0)
local AURA_OUTLINE = Color3.fromRGB(255, 30, 30)
local BASE_RATE, RATE_PER_LEVEL = 6, 8 -- flicker frequency (Hz) = BASE + level * PER_LEVEL

function FlickerAura.Init()
	local player = Players.LocalPlayer
	local auras = setmetatable({}, { __mode = "k" })

	RunService.Heartbeat:Connect(function()
		local myChar = player.Character
		local myLevel = myChar and myChar:GetAttribute("Flicker") or 0
		local myZone = myChar and myChar:GetAttribute("Zone")
		Hud.SetFlickerText(if myZone then "ZONE" elseif myLevel > 0 then ("FLICKER x%d"):format(myLevel) else "")

		for _, other in Players:GetPlayers() do
			local char = other.Character
			if char then
				local level, zone = char:GetAttribute("Flicker") or 0, char:GetAttribute("Zone")
				local aura = auras[char]
				if level > 0 or zone then
					if not aura or not aura.Parent then
						aura = Instance.new("Highlight")
						aura.FillColor, aura.OutlineColor, aura.OutlineTransparency = AURA_FILL, AURA_OUTLINE, 0
						aura.Parent = char
						auras[char] = aura
					end
					local rate = BASE_RATE + level * RATE_PER_LEVEL
					local on = zone or math.floor(os.clock() * rate) % 2 == 0
					aura.FillTransparency = if on then 0.35 else 1
					aura.OutlineTransparency = if on then 0 else 0.7
				elseif aura then
					aura:Destroy()
					auras[char] = nil
				end
			end
		end
	end)
end

return FlickerAura
