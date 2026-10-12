local live = workspace.Live
local votingPads = workspace.VotingPads
local events = game.ReplicatedStorage.Events
local maps = game.ReplicatedStorage.Maps

local gameModes = {
	["FFA"] = true,
	--["Team Deathmatch"] = true,
	--["Team FFA"] = true,
	["Last one standing"] = true,
}

wait(5)

while true do
	
	--local pickedGamemodes = {}
	--for i,v in pairs(gameModes) do
	--	table.insert(pickedGamemodes,i)
	--end
	
	--for i = 1,3 do
	--	local picked = math.random(1,#pickedGamemodes)
	--	votingPads[i]:SetAttribute("Element",pickedGamemodes[picked])
	--	table.remove(pickedGamemodes,picked)
	--end
	
	--events.Vote:FireAllClients("Gamemode")
	
	local pickedMaps = {}
	for i,v in pairs(maps:GetChildren()) do
		table.insert(pickedMaps,v.Name)
	end

	for i = 1,3 do
		local picked = math.random(1,#pickedMaps)
		votingPads[i]:SetAttribute("Element",pickedMaps[picked])
		table.remove(pickedMaps,picked)
	end
	
	votingPads:SetAttribute("Voting",true)
	events.Vote:FireAllClients(pickedMaps)
	
	local votes = {}
	local voteEvents = {}
	table.insert(voteEvents,events.Vote.OnServerEvent:Connect(function(player,vote)
		votes[player.Name] = vote
		votingPads[vote]:SetAttribute("Votes",votingPads[vote]:GetAttribute("Votes")+1)
	end))
	table.insert(voteEvents,events.Unvote.OnServerEvent:Connect(function(player)
		local vote = votes[player.Name]
		if vote then
			votingPads[vote]:SetAttribute("Votes",votingPads[vote]:GetAttribute("Votes")-1)
		end
		votes[player.Name] = nil
	end))
	
	for i = 10,1,-1 do
		live:SetAttribute("Status","Intermission: "..i)
		task.wait(1)
	end
	
	voteEvents[1]:Disconnect()
	voteEvents[2]:Disconnect()
	events.Unvote:FireAllClients()
	votingPads:SetAttribute("Voting",false)
	
	local counter = {0,0,0}
	for _,v in pairs(votes) do
		counter[v] += 1
	end
	local winner = 1
	for i,v in pairs(counter) do
		if v > counter[winner] then
			winner = i
		end
	end

	local map = maps:FindFirstChild(votingPads[winner]:GetAttribute("Element")):Clone()
	map:MoveTo(Vector3.new(2000,0,2000))
	map.Parent = workspace
	
	for i,v in pairs(game.Players:GetPlayers()) do
		if v:GetAttribute("Training") then continue end
		v.Team = game.Teams.Playing
		v:LoadCharacter()
	end
	
	for i = 300,1,-1 do
		live:SetAttribute("Status","Game: FFA\n"..i)
		task.wait(1)
	end
	
	for i,v in pairs(votingPads:GetChildren()) do
		v:SetAttribute("Element","None")
		v:SetAttribute("Votes",0)
	end
	
	map:Destroy()
	
	for i,v in pairs(game.Players:GetPlayers()) do
		if v:GetAttribute("Training") then continue end
		v.Team = game.Teams.Lobby
		v:LoadCharacter()
	end
	
end
