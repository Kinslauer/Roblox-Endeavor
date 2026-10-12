local character = script.Parent
local humanoid = character.Humanoid

local events = game.ReplicatedStorage.Events

local anims = {}

for i,v in pairs(game.ReplicatedStorage.Animations.Core:GetChildren()) do
	anims[v.Name] = humanoid:LoadAnimation(v)
end

anims.Block = humanoid:LoadAnimation(game.ReplicatedStorage.Animations.Brawler.Block)
anims.Block:Play()

local function playSFX(sound,parent)
	local swingSound = game.ReplicatedStorage.Audio[sound]:Clone()
	swingSound.Parent = parent
	swingSound:Destroy()
end

character:GetAttributeChangedSignal("BlockBroken"):Connect(function()
	if script.Parent:GetAttribute("BlockBroken") then
		anims.Block:Stop()
		anims.BlockBroken:Play()
	end
end)

character:GetAttributeChangedSignal("Blocking"):Connect(function()
	if script.Parent:GetAttribute("BlockBroken") then return end
	if character:GetAttribute("Blocking") then
		anims.Block:Play()
	else
		anims.Block:Stop()
		repeat wait() until not script.Parent:GetAttribute("BlockBroken") and not script.Parent:GetAttribute("HitStun")
		script.Parent:SetAttribute("Blocking",true)
		anims.Block:Play()
	end
end)

script.Parent.HumanoidRootPart.ChildAdded:Connect(function(child)
	anims["Hit"..math.random(1,2)]:Play()
end)

character:GetAttributeChangedSignal("Posture"):Connect(function()
	if character:GetAttribute("Posture") >= 10 then
		character:SetAttribute("Posture",1)
		character:SetAttribute("Blocking",false)
		character:SetAttribute("BlockBroken",true)
		task.delay(3,function()
			character:SetAttribute("BlockBroken",false)
			character:SetAttribute("BlockCD",false)
		end)
		playSFX("BlockBroken",character.PrimaryPart)
		events.Client:FireAllClients("BlockBroken",2,character.HumanoidRootPart)
		return
	end
end)
