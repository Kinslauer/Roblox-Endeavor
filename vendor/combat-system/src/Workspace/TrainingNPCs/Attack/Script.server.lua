local classLoader = require(game.ServerStorage.Modules.ClassLoader)
local animations = game.ReplicatedStorage.Animations

local character = script.Parent
local humanoid = character.Humanoid

local class = character:GetAttribute("Class")
classLoader[class](character)

local anims = {}

for i,v in pairs(animations.Core:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end
for i,v in pairs(animations[class]:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end

repeat task.wait() until anims.Idle.Length > 0 
anims.Idle:Play()

wait(8)

local currentAnim = "Attack"..character:GetAttribute("AttackCounter")

character:GetAttributeChangedSignal("Countered"):Connect(function()
	if not character:GetAttribute("Countered") then return end
	local anim = anims[currentAnim]
	task.wait(.8*anim:GetTimeOfKeyframe("HitEnd0")-anim.TimePosition)
	anim:AdjustSpeed(0)
	humanoid.AutoRotate = false
	task.wait(2)
	anim:Stop()
	humanoid.AutoRotate = true
end)


while true do
	currentAnim = "Attack"..character:GetAttribute("AttackCounter")
	anims[currentAnim]:Play()
	game.ServerScriptService.CombatManager.Attack:Fire({
		["Character"] = character,
		["IsNPC"] = true,
		["GetNetworkPing"] = function()
			return 0
		end,
		["GetAttribute"] = function()
			return class
		end,
	})
	wait(1)
	repeat wait() until not character:GetAttribute("Attacking") and not character:GetAttribute("AttackCD") and not character:GetAttribute("Countered")
end
