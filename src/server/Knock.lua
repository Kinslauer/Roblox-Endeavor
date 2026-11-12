-- Knock (Endeavor, round 2 of docs/Reference-Picks-Plan.md): knocked down, not dead.
-- A conduit's blow that would end a player instead drops them for Config.Kit.Knock.Seconds: they crawl, cannot
-- fight, and keep bleeding. Another player can hold X on them to pick them up (back on their feet with a share of
-- their health) or to finish them. Nobody helps in time, a second fatal hit, or a head or chest at zero: dead.
-- Only once per Knock.Again seconds; NPC blows still knock (the city's crews take no prisoners: they finish you).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local KN = Config.Kit.Knock
local Knock = {}

local lastKnock = {} -- [player] = os.clock()

local function clearPrompts(root)
	for _, name in { "PickUp", "Finish" } do
		local p = root and root:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
end

local function stand(char, hum)
	if not char.Parent then
		return
	end
	char:SetAttribute("Knocked", nil)
	clearPrompts(char:FindFirstChild("HumanoidRootPart"))
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		require(script.Parent.Stats).Apply(player)
	end
	Remotes.CombatEvent:FireAllClients("Knocked", char, false)
end

-- Combat.applyDamage, before the blow comes off: true when the blow knocks instead of killing.
function Knock.Try(victim, attacker)
	local player = Players:GetPlayerFromCharacter(victim)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not (player and hum and hum.Health > 0) or victim:GetAttribute("Knocked") then
		return false
	end
	local t = os.clock()
	if lastKnock[player] and t - lastKnock[player] < KN.Again then
		return false
	end
	lastKnock[player] = t
	victim:SetAttribute("Knocked", true)
	local root = victim:FindFirstChild("HumanoidRootPart")
	Remotes.CombatEvent:FireAllClients("Knocked", victim, true)
	require(script.Parent.Stats).Apply(player)
	if root then
		local pick = Instance.new("ProximityPrompt")
		pick.Name = "PickUp"
		pick.ActionText, pick.ObjectText = "Pick up", player.DisplayName
		pick.KeyboardKeyCode = Enum.KeyCode.X
		pick.HoldDuration = KN.Revive
		pick.MaxActivationDistance = 7
		pick.RequiresLineOfSight = false
		pick.Parent = root
		local finish = Instance.new("ProximityPrompt")
		finish.Name = "Finish"
		finish.ActionText, finish.ObjectText = "Finish", player.DisplayName
		finish.KeyboardKeyCode = Enum.KeyCode.F
		finish.HoldDuration = KN.Finish
		finish.MaxActivationDistance = 6
		finish.RequiresLineOfSight = false
		finish.UIOffset = Vector2.new(0, 60)
		finish.Parent = root
		pick.Triggered:Connect(function(by)
			Knock.PickUp(victim, by)
		end)
		finish.Triggered:Connect(function(by)
			Knock.Finish(victim, by)
		end)
	end
	local token = t
	victim:SetAttribute("KnockedAt", token)
	task.delay(KN.Seconds, function()
		if victim.Parent and victim:GetAttribute("Knocked") and victim:GetAttribute("KnockedAt") == token and hum.Health > 0 then
			hum.Health = 0 -- nobody came
		end
	end)
	return true
end

function Knock.PickUp(victim, by)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and victim:GetAttribute("Knocked")) or by.Character == victim then
		return false
	end
	hum.Health = math.max(hum.Health, hum.MaxHealth * KN.ReviveShare)
	stand(victim, hum)
	return true
end

function Knock.Finish(victim, by)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and victim:GetAttribute("Knocked")) or by.Character == victim then
		return false
	end
	local Combat = require(script.Parent.Combat)
	if by.Character and Combat.Tag then
		Combat.Tag(by.Character, victim)
	end
	hum.Health = 0
	return true
end

function Knock.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastKnock[player] = nil
	end)
end

return Knock
