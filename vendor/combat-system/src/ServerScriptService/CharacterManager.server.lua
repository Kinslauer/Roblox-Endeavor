local TweenService = game:GetService("TweenService")
local events = game.ReplicatedStorage.Events
local classLoader = require(game.ServerStorage.Modules.ClassLoader)

local function playSFX(sound,parent)
	local swingSound = game.ReplicatedStorage.Audio[sound]:Clone()
	swingSound.Parent = parent
	swingSound:Destroy()
end

local function createHeartGui(character)
	local heartGui = script.Hearts:Clone()
	local frame = heartGui.Frame
	local hearts = #frame:GetChildren()-1

	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")
	local events = {}

	heartGui.Parent = humanoidRootPart
	
	table.insert(events,humanoid.HealthChanged:Connect(function(health)
		local healthPercent = health/humanoid.MaxHealth
		local lowerBound = math.floor(healthPercent / .2) * .2
		local nearestHeart = lowerBound/.2

		if nearestHeart < 0 then	return end
		
		local count = 1
		while true do
			if frame:FindFirstChild(nearestHeart+count) then
				frame[nearestHeart+count].Frame.Visible = false
				frame[nearestHeart+count].Effect.Visible = false
				count+=1
			else
				break
			end
		end
		local heartNum = string.format("%0.0f",nearestHeart)
		local heart = frame[heartNum]
		local heartPercent = (healthPercent-lowerBound)/.2
		
		local framePos = UDim2.new(-(1-heartPercent),0,0,0)
		local filledPos = UDim2.new(1-heartPercent,0,0,0)
		
		heart.Frame.Position = framePos
		heart.Frame.Filled.Position = filledPos
		
		local effectDuration = .2
		heart.Effect.Filled.ImageTransparency = 0
		heart.Effect:TweenPosition(framePos,Enum.EasingDirection.Out,Enum.EasingStyle.Linear,effectDuration)
		heart.Effect.Filled:TweenPosition(filledPos,Enum.EasingDirection.Out,Enum.EasingStyle.Linear,effectDuration)
		TweenService:Create(heart.Effect.Filled,TweenInfo.new(effectDuration),{ImageTransparency = .4}):Play()
	end))
	table.insert(events,humanoid.Died:Connect(function()
		for i,v in pairs(events) do
			v:Disconnect()
		end
	end))

end

local function spawnClass(player)
	local character = player.Character
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	if player.Team == game.Teams.Lobby then
		if not player:GetAttribute("Training") then return end
		character.Parent = workspace.Training
		humanoidRootPart.CFrame = workspace.TrainingSpawn.CFrame
	else
		--if player:GetAttribute("GameAccess") then
		character.Parent = workspace.Live
		--end
	end
end

events.Select.OnServerEvent:Connect(function(player,class)
	if player.Team == game.Teams.Lobby then
		player:SetAttribute("Class",class)
		wait(.2)
		player:LoadCharacter()
	else
		if not player:GetAttribute("Class") then
			player:SetAttribute("Class",class)
			player:LoadCharacter()
		else
			player:SetAttribute("NextClass",class)
		end
	end
end)

events.Reset.OnServerEvent:Connect(function(player)
	player:SetAttribute("Class",nil)
	player.Character:Destroy()
	game.ServerScriptService.CharacterManager.ScreenGui:Clone().Parent = player.PlayerGui
end)

events.Training.OnServerEvent:Connect(function(player,isTraining)
	player:SetAttribute("GameAccess",true)
	player:SetAttribute("Training",isTraining)
	local character = player.Character
	if isTraining then
		player.Team = game.Teams.Lobby
		character.Parent = workspace.Training
		character.HumanoidRootPart.CFrame = workspace.TrainingSpawn.CFrame
	else
		player.Team = game.Teams.Playing
		character.Parent = workspace.Live
		task.wait(.2)
		player:LoadCharacter()
	end
end)

game.Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local Kills = Instance.new("IntValue")
	Kills.Name = "Kills"
	Kills.Parent = leaderstats
	
	local Deaths = Instance.new("IntValue")
	Deaths.Name = "Deaths"
	Deaths.Parent = leaderstats
	
	local liveData = Instance.new("Folder",workspace.Interactive)
	liveData.Name = player.Name
	
	player.CharacterAdded:Connect(function(character)
		local humanoidRootPart
		repeat task.wait() 
			humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		until humanoidRootPart
		local humanoid = character:WaitForChild("Humanoid")
		
		if character.Name == "2sgo" or character.Name == "Friend1" then
			local title = script.Title:Clone()
			title.Label.Text = "Developer"
			title.Label.TextColor3 = Color3.new(1)
			title.Parent = character:WaitForChild("Torso")
		elseif character.Name == "Tester1" or character.Name == "Tester2" then
			local title = script.Title:Clone()
			title.Label.Text = "Tester"
			title.Label.TextColor3 = Color3.new(.2,.2,1)
			title.Parent = character:WaitForChild("Torso")
		end
		
		if player.Team == game.Teams.Lobby then
			if not player:GetAttribute("Training") then return end
			character.Parent = workspace.Training
			humanoidRootPart.CFrame = workspace.TrainingSpawn.CFrame
		else
			--if player:GetAttribute("GameAccess") then
			character.Parent = workspace.Live
			--end
		end
		
		createHeartGui(character)
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		
		local diedEvent
		diedEvent = humanoid.Died:Connect(function()
			for i,v in pairs(liveData:GetChildren()) do
				v:Destroy()
			end
			local nextClass = player:GetAttribute("NextClass")
			if nextClass then
				player:SetAttribute("Class",nextClass)
				player:SetAttribute("NextClass",nil)
			end
			Deaths.Value += 1
			diedEvent:Disconnect()
		end)

		local class = player:GetAttribute("Class")
		if not class then return end
		
		script.Controller:Clone().Parent = character
		classLoader[class](character)
		
		character:SetAttribute("AttackCounter",1)
		character:SetAttribute("Posture",1)
		character:SetAttribute("HitStun",false)
		character:SetAttribute("HitQueue",false)
		
		local postureQueue = false
		character:GetAttributeChangedSignal("Blocking"):Connect(function()
			if not character:GetAttribute("Blocking") then
				if postureQueue then return end
				repeat task.wait() until not character:GetAttribute("PostureRegenDisable")
				postureQueue = true
				while true do
					task.wait(1)
					if character:GetAttribute("Blocking") or character:GetAttribute("HitStun") or character:GetAttribute("Posture") <= 1 then 
						postureQueue = false
						return 
					end
					character:SetAttribute("Posture",character:GetAttribute("Posture")-.5)
				end
			end
		end)
		
		character:GetAttributeChangedSignal("Attacking"):Connect(function()
			if not character:GetAttribute("Attacking") then
				
			end
		end)
		
		character:GetAttributeChangedSignal("HitStun"):Connect(function()
			if not character:GetAttribute("HitStun") then
				task.wait(1)
				while true do
					if character:GetAttribute("Blocking") or character:GetAttribute("HitStun") or character:GetAttribute("Posture") <= 1 then return end
					character:SetAttribute("Posture",character:GetAttribute("Posture")-1)
					task.wait(1)
				end
			end
		end)
		
		character:GetAttributeChangedSignal("Posture"):Connect(function()
			if character:GetAttribute("Posture") >= 10 then
				character:SetAttribute("Blocking",false)
				character:SetAttribute("BlockBroken",true)
				character:SetAttribute("Posture",1)
				task.delay(3,function()
					character:SetAttribute("BlockBroken",false)
					character:SetAttribute("BlockCD",false)
				end)
				events.Client:FireAllClients("PlaySFX",{"BlockBroken"},humanoidRootPart)
				events.Client:FireAllClients("EmitParticles","BlockBroken",2,humanoidRootPart)
				return
			end
		end)
		
	end)
end)
