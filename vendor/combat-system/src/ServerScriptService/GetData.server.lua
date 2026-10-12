local classData = require(game.ServerStorage.Modules.ClassData)
local skillData = require(game.ServerStorage.Modules.SkillData)

local skillDataLocal = {}
for i,v in pairs(skillData) do
	skillDataLocal[i] = {
		["Level"] = v.Level,
		["Compatible"] = v.Compatible
	}
end

game.ReplicatedStorage.Events.GetData.OnServerInvoke = function(player,data)
	if data == "SkillData" then
		return skillDataLocal
	end
	return _G.Profiles[player.Name][data]
end

game.ReplicatedStorage.Events.UpdateData.OnServerInvoke = function(player,dataType,data)
	if dataType == "Skills" then
		local playerData = _G.Profiles[player.Name]
		for i,v in pairs(playerData[dataType]) do
			if v == data then
				playerData[dataType][i] = nil
				return playerData[dataType]
			end
		end
		playerData[dataType][#playerData[dataType]+1] = data
		return playerData[dataType]
	end
end
