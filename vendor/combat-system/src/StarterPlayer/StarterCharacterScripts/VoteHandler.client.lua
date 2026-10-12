local events = game.ReplicatedStorage.Events
local votingPads = workspace.VotingPads

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local votingActive = false
local currentVote 

for i,v in pairs(votingPads:GetChildren()) do
	v:GetAttributeChangedSignal("Element"):Connect(function()
		v.Element.Gui.Label.Text = v:GetAttribute("Element")
	end)
	v:GetAttributeChangedSignal("Votes"):Connect(function()
		v.Vote.Gui.Label.Text = v:GetAttribute("Votes")
	end)
end

local function voter(update)
	while true do
		if not votingPads:GetAttribute("Voting") then return end
		local ray = Ray.new(humanoidRootPart.Position,humanoidRootPart.CFrame.UpVector*-10)
		local hit,pos,norm = workspace:FindPartOnRay(ray,character)

		if hit then
			local voteStation = hit.Parent
			if voteStation.Parent == votingPads then
				if currentVote ~= tonumber(voteStation.Name) then
					currentVote = tonumber(voteStation.Name)
					events.Vote:FireServer(currentVote)
				end
			else
				currentVote = nil
				events.Unvote:FireServer(currentVote)
			end
		end
		task.wait(.2)
	end
end

voter()
events.Vote.OnClientEvent:Connect(voter)
