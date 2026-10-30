-- Gore (design doc section 9). Everything here is gated by Config.Destruction.GoreLevel:
--   Moderate   - light, distant blood on hits; bodies vanish on respawn.
--   Restricted - blood spray and pooling, dismemberment on heavy/explosive kills, bodies that
--                stay as persistent corpses (looted via their remains, frozen after settling).
-- The level is a server decision; clients only draw what the "World" remote tells them.
-- NOTE: the Restricted content label itself is applied in the Roblox Creator Dashboard
-- questionnaire; this module only makes the game match that label.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)

local Gore = {}

local LIMBS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Head" }

local folder
local corpses = {} -- ordered; oldest first

local function restricted()
	return Config.Destruction.GoreLevel == "Restricted"
end

local function world(kind, ...)
	Remotes.World:FireAllClients(kind, ...)
end

-- ===== Blood on hits =====
local function onResolved(attacker, victim, result)
	if result ~= "hit" and result ~= "guardbreak" then
		return
	end
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local aroot = attacker:FindFirstChild("HumanoidRootPart")
	local dir = if aroot then (root.Position - aroot.Position) * Vector3.new(1, 0, 1) else Vector3.zero
	-- Moderate: a small distant spray. Restricted: spray + a pool on the ground.
	world("Blood", root.Position, if dir.Magnitude > 0.1 then dir.Unit else Vector3.zAxis, restricted())
end

-- ===== Death: dismemberment + persistent corpse =====
local function freezeCorpse(corpse)
	for _, p in corpse:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
		end
	end
end

local function makeCorpse(model, violent)
	local corpse = Instance.new("Model")
	corpse.Name = "Corpse"
	local parts = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local c = p:Clone()
			for _, child in c:GetChildren() do
				if child:IsA("JointInstance") or child:IsA("Attachment") or child:IsA("ProximityPrompt") then
					child:Destroy()
				end
			end
			c.Anchored, c.CanCollide = false, true
			c:SetAttribute("Corpse", true)
			c.Parent = corpse
			table.insert(parts, c)
		elseif p:IsA("Accessory") then
			local handle = p:FindFirstChild("Handle")
			if handle then
				local c = handle:Clone()
				c.Anchored, c.CanCollide = false, false
				c.Parent = corpse
			end
		end
	end
	if #parts == 0 then
		corpse:Destroy()
		return nil
	end
	-- a violent death (explosive / heavy) scatters limbs; otherwise the body holds together loosely
	if violent then
		for _, c in parts do
			if table.find(LIMBS, c.Name) then
				c.AssemblyLinearVelocity = (c.Position - corpse:GetPivot().Position + Vector3.new(0, 1, 0)) * 6 + Vector3.new(0, 20, 0)
			end
		end
		world("Dismember", corpse:GetPivot().Position)
	else
		local torso = corpse:FindFirstChild("Torso") or corpse:FindFirstChild("UpperTorso") or parts[1]
		for _, c in parts do
			if c ~= torso then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = torso, c
				weld.Parent = c
			end
		end
	end
	CollectionService:AddTag(corpse, "Corpse")
	corpse.Parent = folder
	for _, c in parts do
		c:SetNetworkOwner(nil)
	end
	table.insert(corpses, corpse)
	-- settle, then freeze so bodies stop costing physics and become cover
	task.delay(4, function()
		if corpse.Parent then
			freezeCorpse(corpse)
		end
	end)
	Debris:AddItem(corpse, Config.CorpseLifetime)
	corpse.Destroying:Connect(function()
		local i = table.find(corpses, corpse)
		if i then
			table.remove(corpses, i)
		end
	end)
	while #corpses > Config.Gore.BodyCap do
		local oldest = table.remove(corpses, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
	world("Pool", corpse:GetPivot().Position, 1.5)
	return corpse
end

-- Call when any character dies. `violent` = killed by explosive or a heavy/flash hit.
function Gore.OnDied(model)
	if not restricted() then
		return
	end
	local hitType = model:GetAttribute("LastHitType")
	local violent = hitType == "Explosive" or hitType == "Heavy"
	makeCorpse(model, violent)
end

function Gore.Init()
	folder = Instance.new("Folder")
	folder.Name = "Gore"
	folder.Parent = workspace
	Combat.Resolved.Event:Connect(onResolved)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					Gore.OnDied(char)
				end)
			end
		end)
	end)
end

-- Rematerialization hook (called by Destruction.Reset)
function Gore.Clear()
	for _, corpse in table.clone(corpses) do
		corpse:Destroy()
	end
	world("ClearGore")
end

return Gore
