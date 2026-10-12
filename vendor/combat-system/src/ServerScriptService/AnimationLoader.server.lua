local animator = script.Humanoid
local animations = game.ReplicatedStorage.Animations
local ClassData = require(game.ServerStorage.Modules.ClassData)
local SkillData = require(game.ServerStorage.Modules.SkillData)

local function loadData(anim,data)
	local anim = animator:LoadAnimation(anim)
	repeat task.wait() until anim.Length > 0
	wait(1)
	pcall(function()
		data["CooldownEnd"] = anim:GetTimeOfKeyframe("CooldownEnd")
		local count = 0
		while task.wait() do
			data["HitStart"..count] = anim:GetTimeOfKeyframe("HitStart"..count)
			data["HitEnd"..count] = anim:GetTimeOfKeyframe("HitEnd"..count)
			count+=1
		end
	end)
end

for name,class in pairs(ClassData) do
	local classAnimations = animations[name]
	local attacks = class.Attacks
	for i = 1,#attacks do
		coroutine.wrap(loadData)(classAnimations["Attack"..i],attacks[i])	
	end	
	coroutine.wrap(loadData)(classAnimations["Heavy"],class.Heavy)
end

for name,skill in pairs(SkillData) do
	coroutine.wrap(loadData)(animations.Skills[name],skill)
end
