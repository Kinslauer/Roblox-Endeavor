local Hud = script.Parent
local Menu = Hud.Menu
local Hotbar = Hud.Hotbar
local Meter = Hud.Meter
local Timer = Hud.Timer

local ClassesMenu = Menu.ClassesMenu.Frame
local ClassesFrame = ClassesMenu.Classes
local ClassesView = ClassesFrame.View
local SkillsFrame = ClassesMenu.Skills
local SkillsView = SkillsFrame.View

wait(.1)
local UserInputService = game:GetService("UserInputService")
local events = game.ReplicatedStorage.Events
_G.Keybinds = events.GetData:InvokeServer("Keybinds")
_G.Skills = events.GetData:InvokeServer("Skills")
_G.SkillData = events.GetData:InvokeServer("SkillData")
local classDescriptionScript = game.ReplicatedStorage.Modules:WaitForChild("ClassDescription")
local classDescription = require(classDescriptionScript)

wait(1)

local range = {
	Color3.new(0,.2,1),
	Color3.new(0,.7,1),
	Color3.new(0,.9,1),
	Color3.new(1,1,0),
	Color3.new(1,.6,0),
	Color3.new(1,.5,0),
	Color3.new(1,.3,0),
	Color3.new(1,.2,0),
	Color3.new(1,.1,0),
	Color3.new(1,0,0),
}

local wordToNumber = {
	["One"] = 1,
	["Two"] = 2,
	["Three"] = 3,
	["Four"] = 4,
	["Five"] = 5,
	["Six"] = 6,
	["Seven"] = 7,
	["Eight"] = 8,
	["Nine"] = 9,
	["Zero"] = 0,
}

local player = game.Players.LocalPlayer

Hud.MenuButton.MouseButton1Click:Connect(function()
	Menu.Visible = not Menu.Visible
end)

player:GetAttributeChangedSignal("Class"):Connect(function()
	Hud.Class.Text = "Class: "..(player:GetAttribute("Class") or "None")
end)

player:GetAttributeChangedSignal("NextClass"):Connect(function()
	if player:GetAttribute("NextClass") then
		Hud.ClassChange.Visible = true
		task.wait(4)
		Hud.ClassChange.Visible = false
	end
end)

workspace.Live:GetAttributeChangedSignal("Status"):Connect(function()
	Timer.TextLabel.Text = workspace.Live:GetAttribute("Status")
end)

local isTraining = false
local trainingDelay = false
Hud.Training.MouseButton1Click:Connect(function()
	if not player.Character:FindFirstChild("HumanoidRootPart") or trainingDelay then return end
	isTraining = not isTraining
	if isTraining then
		Hud.Training.TextColor3 = Color3.new(0,1)
	else
		Hud.Training.TextColor3 = Color3.new(1)
	end
	events.Training:FireServer(isTraining)
	trainingDelay = true
	task.wait(1)
	trainingDelay = false
end)

local data = events.GetData:InvokeServer("Classes")

Menu.Modifiers.Button.MouseButton1Click:Connect(function()
	Menu.ModifiersMenu.Visible = not Menu.ModifiersMenu.Visible
end)

Menu.Classes.Button.MouseButton1Click:Connect(function()
	Menu.ClassesMenu.Visible = not Menu.ClassesMenu.Visible
end)

ClassesView.Select.MouseButton1Click:Connect(function()
	events.Select:FireServer(ClassesView.Title.Text)
	ClassesFrame.Visible = true
	SkillsFrame.Visible = false
	Menu.ClassesMenu.Visible = false
end)

SkillsFrame.Back.MouseButton1Click:Connect(function()
	ClassesFrame.Visible = true
	SkillsFrame.Visible = false
end)

local hotbarEvents = {}
local function loadSkills()
	for i,v in pairs(hotbarEvents) do
		v:Disconnect()
	end
	for i,v in pairs(Hotbar:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
	for i,v in pairs(_G.Skills) do
		local template = script.HotbarTemplate:Clone()
		template.Name = i
		template.Frame.Slot.Text = i
		template.Frame.Label.Text = v
		template.Parent = Hotbar

		table.insert(hotbarEvents,player.Character:GetAttributeChangedSignal(i):Connect(function()
			template.Frame.Cooldown.Visible = true
			template.Frame.Cooldown.Size = UDim2.new(1,0,1,0)
			template.Frame.Size = UDim2.new(1.1,0,1.1,0)
			template.Frame:TweenSize(UDim2.new(1,0,1,0),Enum.EasingDirection.Out,Enum.EasingStyle.Linear,.2)
			local skillCd = player.Character:GetAttribute(i)
			template.Frame.Cooldown:TweenSize(UDim2.new(1,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Linear,skillCd)
			task.wait(skillCd)
			template.Frame.Cooldown.Visible = false
		end))
	end
end

local selectedClass
for _,category in pairs(classDescription) do
	local categoryTemplate = script.CategoryTemplate:Clone()
	categoryTemplate.Parent = ClassesFrame.Items
	categoryTemplate.Title.Text = category.Name
	categoryTemplate.Name = category.Name
	
	for i,class in pairs(category) do
		if i == "Name" then continue end
		
		local classTemplate = script.ClassTemplate:Clone()
		classTemplate.Name = class.Name
		classTemplate.Title.Text = class.Name
		classTemplate.Parent = categoryTemplate.Classes

		if data[class.Name] then
			classTemplate.Button.Transparency = 1
			classTemplate.Button.MouseButton1Click:Connect(function()
				if class == selectedClass then return end
				selectedClass = class
				for i,v in pairs(ClassesView.Stats:GetChildren()) do
					if not class[v.Name] then continue end
					v.Text = v.Name..": "
					for i = 1,class[v.Name] do
						v.Text = v.Text.."★"
					end
				end
				ClassesView.Title.Text = class.Name
			end)
			
		end
	end

	ClassesView.Skills.MouseButton1Click:Connect(function()
		local skills = SkillsFrame.Items
		for i,v in pairs(skills:GetChildren()) do
			if not v:IsA("ViewportFrame") then continue end
			v:Destroy()
		end
		for _,skillName in pairs(selectedClass.Skills) do
			local skillTemplate = script.SkillTemplate:Clone()
			skillTemplate.Title.Text = skillName
			skillTemplate.Parent = skills

			local function updateEquipped()
				skillTemplate.BorderColor3 = Color3.new()
				for i,v in pairs(_G.Skills) do
					if v == skillName then
						skillTemplate.BorderColor3 = Color3.new(1,1)
						break
					end
				end
			end
			
			updateEquipped()
			local equippedClass = player:GetAttribute("Class")
			if equippedClass then
				skillTemplate.Button.Transparency = 1
				if not _G.SkillData[skillName].Compatible["Universal"] and not _G.SkillData[skillName].Compatible[equippedClass] then
					skillTemplate.Label.Text = "INCOMPATIBLE"
				else
					skillTemplate.Label.Text = ""
				end
				skillTemplate.Button.MouseButton1Click:Connect(function()
					local newSkills = events.UpdateData:InvokeServer("Skills",skillName)
					_G.Skills = {}
					for i,v in pairs(newSkills) do
						_G.Skills[i] = v
					end
					loadSkills()
					updateEquipped()
				end)
			end
			
		end
		
		ClassesFrame.Visible = false
		SkillsFrame.Visible = true
	end)
end

player.CharacterAdded:Connect(function(character)
	local events = {}
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")
	
	local class = player:GetAttribute("Class")
	if not class or (player.Team == game.Teams.Lobby and not player:GetAttribute("Training")) then return end

	table.insert(events,humanoid.Died:Connect(function()
		for i,v in pairs(events) do
			v:Disconnect()
		end
	end))

	loadSkills()
	
	local hearts = humanoidRootPart:WaitForChild("Hearts")
	Meter.Adornee = humanoidRootPart
	table.insert(events,character:GetAttributeChangedSignal("HitStun"):Connect(function()--shake
		if character:GetAttribute("HitStun") then
			for i = 1,10 do
				local offset = (Random.new():NextNumber()-.5)*(1/(i-11)+1)
				Meter.StudsOffset = Vector3.new(3+offset,offset,offset)
				hearts.StudsOffset = Vector3.new(offset,offset-4,offset)
				task.wait()
			end
			Meter.StudsOffset = Vector3.new(3,0,0)
			hearts.StudsOffset = Vector3.new(0,-4,0)
		end
	end))
	
	table.insert(events,character:GetAttributeChangedSignal("Posture"):Connect(function()
		Meter.Posture.Size = UDim2.new(.4,0,1-((character:GetAttribute("Posture")-1)/10),0)
		Meter.Posture.BackgroundColor3 = range[math.floor(character:GetAttribute("Posture"))]
	end))	
	
end)
