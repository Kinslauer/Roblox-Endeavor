local classDescriptionScript = script.ClassDescription
local classDescription = require(classDescriptionScript)
local skillData = require(game.ServerStorage.Modules.SkillData)

for skillName,v in pairs(skillData) do
	local skillClass = v.Class

	local skillData
	for i,v in pairs(classDescriptionScript:GetChildren()) do
		if v:FindFirstChild(skillClass) then
			skillData = require(v[skillClass]).Skills[skillName]
			break
		end
	end
	
	skillData["Compatible"] = {[skillClass] = true}
	skillData["Level"] = v.Level
	for i,v in pairs(v.Compatible) do
		skillData.Compatible[i] = true
	end
end

classDescriptionScript.Parent = game.ReplicatedStorage.Modules

print(require(classDescriptionScript))
