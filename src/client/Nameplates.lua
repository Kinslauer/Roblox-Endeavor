-- Nameplates (combat-feel polish item 4, design/references/magoi-look-and-feel.md): people read as
-- bodies first. Roblox's over-head name is switched off locally for every humanoid we draw a plate
-- for, and a small plate sits at hip height, lower-left of the body, fading out with distance.
-- Players (their DisplayName), enemy combatants (the Combatant tag; red-ish) and contacts (the Contact
-- attribute; cyan) get one; your own body does not. Health bars are untouched. Tuning: Presentation.Nameplates.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local N = Presentation.Nameplates

local Nameplates = {}

local player = Players.LocalPlayer
local plates = {} -- model -> { gui, label }

local function kindOf(model)
	if Players:GetPlayerFromCharacter(model) then
		return "Player"
	elseif model:GetAttribute("Contact") then
		return "Contact"
	end
	return "Npc"
end

local function nameOf(model, hum)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	return (hum and hum.DisplayName ~= "" and hum.DisplayName) or model.Name
end

local function attach(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or plates[model] or model == player.Character then
		return
	end
	task.spawn(function()
		local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
		local anchor = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart", 5)
		if not (hum and anchor) or plates[model] or not model.Parent then
			return
		end
		hum.NameDisplayDistance = 0 -- ours instead (local only)
		local kind = kindOf(model)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Nameplate"
		gui.Adornee = anchor
		gui.Size = N.Size
		gui.StudsOffset = N.Offset
		gui.AlwaysOnTop = false
		gui.MaxDistance = N.FadeEnd
		gui.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = nameOf(model, hum)
		label.TextColor3 = if kind == "Contact" then N.ContactColor elseif kind == "Npc" then N.NpcColor else N.Color
		label.Font, label.TextSize = N.Font, N.TextSize
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		plates[model] = { gui = gui, label = label, hum = hum }
		hum:GetPropertyChangedSignal("DisplayName"):Connect(function()
			label.Text = nameOf(model, hum)
		end)
	end)
end

local function detach(model)
	local plate = plates[model]
	if plate then
		plate.gui:Destroy()
		plates[model] = nil
	end
end

-- distance fade, a few times a second
local function fade()
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for model, plate in plates do
		local anchor = plate.gui.Adornee
		if not model.Parent or not anchor or not anchor.Parent then
			detach(model)
			continue
		end
		if me then
			local d = (anchor.Position - me.Position).Magnitude
			local a = math.clamp((d - N.FadeStart) / math.max(N.FadeEnd - N.FadeStart, 1), 0, 1)
			plate.label.TextTransparency = a
			plate.label.TextStrokeTransparency = 0.5 + a * 0.5
		end
		if plate.hum.Health <= 0 then
			plate.label.TextTransparency = 1
		end
	end
end

function Nameplates.Init()
	local function watchPlayer(p)
		if p == player then
			return
		end
		p.CharacterAdded:Connect(attach)
		p.CharacterRemoving:Connect(detach)
		if p.Character then
			attach(p.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, tag in { "Combatant" } do
		for _, m in CollectionService:GetTagged(tag) do
			attach(m)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(attach)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(detach)
	end
	-- contacts carry a Contact attribute (server/Contacts.lua) and no tag
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("Contact") then
			attach(m)
		end
	end
	workspace.ChildAdded:Connect(function(m)
		if m:IsA("Model") and m:GetAttribute("Contact") then
			attach(m)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			fade()
		end
	end)
end

return Nameplates
