-- Arms built for one thing (round 7 of docs/Reference-Picks-Plan.md; Andy: "the arm cybernetic built to be spent in
-- one blow", "the cable arm"). Tuning: Config.Make.Breaker / Cable. K held (client/Make) sends Remote "Arm"(aim).
--   Breaker  the next melee blow within Window lands Mult times as hard, through any guard (Combat's strike reads
--            Combat.State(char).spendUntil); the arm breaks with it (condition 0: it gives nothing until repaired
--            at the bench, Hideouts repair)
--   Cable    a line along the aim: a body it reaches is dragged to you and stunned; a wall or floor pulls you to it
--            (World "Cable"(point) to your own client, which moves the body it owns)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Cybernetics = require(Shared.Cybernetics)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Common.PlayerData)
local Net = require(script.Parent.Common.Net)

local MK = Config.Make
local Arms = {}
local ready = setmetatable({}, { __mode = "k" }) -- player -> os.clock() when the arm can fire again

local function lazy(name)
	return require(script.Parent[name])
end

-- The first working arm with an active: the right one first.
function Arms.ActiveOf(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local d = lazy("Gear").Get(player)
	for _, slot in { "RightArm", "LeftArm" } do
		local id = data.Cyber[slot]
		local piece = id and Cybernetics.Pieces[id]
		if piece and piece.ArmActive and not (d and d.Overloaded and d.Overloaded[slot]) and ((data.Condition or {})[id] or 100) > 0 then
			return piece.ArmActive, id, slot
		end
	end
	return nil
end

local function bodyOf(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

function Arms.Fire(player, aim)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local Combat = lazy("Combat")
	if not (root and Combat.CanAct(char)) then
		return false
	end
	local kind, id = Arms.ActiveOf(player)
	if not kind then
		return false
	end
	local t = os.clock()
	if t < (ready[player] or 0) then
		return false
	end
	if kind == "Breaker" then
		ready[player] = t + MK.Breaker.Cooldown
		Combat.State(char).spendUntil = t + MK.Breaker.Window
		Combat.State(char).spendArm = id
		char:SetAttribute("Active", "Breaker")
		task.delay(MK.Breaker.Window, function()
			if char.Parent and char:GetAttribute("Active") == "Breaker" then
				char:SetAttribute("Active", nil)
			end
		end)
		Combat.FX("Buff", char, "Breaker")
		return true
	end
	-- the cable
	local C = MK.Cable
	ready[player] = t + C.Cooldown
	local dir = if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 then aim.Unit else root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local from = root.Position + Vector3.new(0, 1.2, 0)
	local hit = workspace:Raycast(from, dir * C.Range, params)
	Remotes.CombatEvent:FireAllClients("Cable", char, if hit then hit.Position else from + dir * C.Range)
	Remotes.CombatEvent:FireClient(player, "SkillCD", "Arm", C.Cooldown)
	if not hit then
		return true -- it reached nothing
	end
	local body = bodyOf(hit.Instance)
	local hum = body and body:FindFirstChildOfClass("Humanoid")
	local broot = body and body:FindFirstChild("HumanoidRootPart")
	if hum and broot and hum.Health > 0 then
		local other = Players:GetPlayerFromCharacter(body)
		if body:GetAttribute("Contact") or (other and lazy("Party").Allies(player, other)) or body:GetAttribute("Owner") == player.UserId then
			return true -- the line will not take a friend
		end
		Combat.Stun(body, C.Stun)
		local to = root.Position + root.CFrame.LookVector * 3
		if other then
			Remotes.World:FireClient(other, "Cable", to) -- its own client moves the body it owns
		else
			local flat = to - broot.Position
			broot.AssemblyLinearVelocity = flat.Unit * C.Speed + Vector3.new(0, 14, 0)
		end
		Combat.FX("Hook", body)
		return true
	end
	-- a wall: the line pulls you to it
	Remotes.World:FireClient(player, "Cable", hit.Position + hit.Normal * 2.5)
	return true
end

-- Combat's strike calls this when a Breaker blow lands: the arm is spent.
function Arms.Spent(player, id)
	local data = PlayerData.Get(player)
	if not (data and id) then
		return
	end
	data.Condition = data.Condition or {}
	data.Condition[id] = 0
	local char = player.Character
	if char and char:GetAttribute("Active") == "Breaker" then
		char:SetAttribute("Active", nil)
	end
	Remotes.Announce:FireClient(player, "> " .. string.upper(Cybernetics.Pieces[id] and Cybernetics.Pieces[id].Name or id) .. " . SPENT", "Warning")
	pcall(function()
		lazy("Gear").Recompute(player)
		lazy("Stats").Apply(player, false)
		lazy("Stats").Push(player)
	end)
end

function Arms.Init()
	Net.On("Arm", { rate = 2, burst = 3, args = { "vector?" } }, Arms.Fire)
end

return Arms
