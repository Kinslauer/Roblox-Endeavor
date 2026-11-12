local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cybernetics = require(ReplicatedStorage.Shared.Cybernetics)
local Props = require(ReplicatedStorage.Shared.Props)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Gear = require(script.Parent.Gear)
local HeldWeapons = require(script.Parent.Common.HeldWeapons)
local WornGear = require(script.Parent.Common.WornGear)
local Net = require(script.Parent.Common.Net)
local PlayerData = require(script.Parent.Common.PlayerData)

local S = Config.Stats
local Stats = {}

-- Applies derived numbers (health, speed, stamina, posture caps) to the live character.
function Stats.Apply(player, fill)
	local d, char = Gear.Get(player), player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not PlayerData.Get(player) then
		return
	end
	hum.MaxHealth = d.MaxHealth
	hum.Health = if fill then d.MaxHealth else math.min(hum.Health, d.MaxHealth)
	-- Walk speed is recomputed here from everything that affects it, so no system can erase
	-- another's modifier: held-chunk weight (Destruction) and stun (Combat).
	local holdClass = char:GetAttribute("HoldClass")
	local holdMult = if holdClass then Props.Weights[holdClass].SpeedMult else 1
	local sprintMult = if char:GetAttribute("Sprinting") then Config.Combat.SprintMult else 1
	local weightMult = if d.Overweight then Config.Inventory.OverweightSpeedMult else 1
	char:SetAttribute("Overweight", d.Overweight == true)
	char:SetAttribute("GearWeight", d.WeightScore or 0) -- armour weight 0..6: Q rolls freely only at 0 (client/Movement)
	-- stance, aiming, a guard held by the neck, a body on the shoulder (server/Stealth sets the attributes)
	local SC = Config.Stealth
	local stance = char:GetAttribute("Stance")
	local crouchMult = if stance == "Prone" then SC.Stance.ProneSpeedMult elseif char:GetAttribute("Crouched") then SC.CrouchSpeedMult else 1
	local handsMult = if char:GetAttribute("NeckHold") then SC.Cqc.Hold.SpeedMult elseif char:GetAttribute("Carrying") then SC.Cqc.Carry.SpeedMult
		elseif char:GetAttribute("Aiming") then SC.Aim.SpeedMult else 1
	-- wounds (common/WoundService): a leg out or broken slows you and stops the sprint
	local woundMult = char:GetAttribute("WoundSpeed") or 1
	if char:GetAttribute("WoundNoSprint") then
		sprintMult = 1
	end
	hum.WalkSpeed = if char:GetAttribute("Stunned") then 0 else d.WalkSpeed * holdMult * sprintMult * weightMult * crouchMult * handsMult * woundMult
	if char:GetAttribute("Knocked") then
		hum.WalkSpeed = Config.Kit.Knock.Crawl -- knocked down: a crawl (server/Knock.lua)
	end

	char:SetAttribute("Weapon", PlayerData.Get(player).Equipped)
	HeldWeapons.Attach(char, Weapons.Held(PlayerData.Get(player).Equipped))
	require(script.Parent.Combat).SyncMag(player)
	local worn = {}
	for _, id in PlayerData.Get(player).Armor do
		table.insert(worn, id)
	end
	WornGear.Apply(char, worn) -- armor only: implants are drawn client-side from the Cyber_<slot> attributes
	require(script.Parent.Kit).Apply(player, char) -- the rig and belt, the carried second weapon at its mount
	hum.UseJumpPower = false
	-- no jumping while low or with your hands on someone (Space brings you up a stance instead)
	local grounded = char:GetAttribute("Crouched") or char:GetAttribute("NeckHold") or char:GetAttribute("Carrying") or char:GetAttribute("WoundNoJump") or char:GetAttribute("Knocked")
	hum.JumpHeight = if grounded then 0 else Config.Movement.JumpHeight * (d.JumpMult or 1)
	for _, slot in Cybernetics.Slots do
		char:SetAttribute("Cyber_" .. slot, PlayerData.Get(player).Cyber[slot])
	end
	char:SetAttribute("MaxStamina", d.MaxStamina)
	char:SetAttribute("MaxPosture", d.MaxPosture)
	char:SetAttribute("MaxCharge", S.MaxCharge)
	if fill then
		char:SetAttribute("Stamina", d.MaxStamina)
		char:SetAttribute("Posture", 0)
		char:SetAttribute("Charge", 0)
	end
end

function Stats.XpNeeded(level)
	return 100 * level
end

function Stats.Push(player)
	local data = PlayerData.Get(player)
	if data then
		Remotes.StatsChanged:FireClient(player, {
			Stats = data.Stats,
			FreePoints = data.FreePoints,
			Level = data.Level,
			Xp = data.Xp,
			XpNeeded = Stats.XpNeeded(data.Level),
			Max = S.MaxPerStat,
		})
	end
end

function Stats.AddXp(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.Xp += math.floor(amount)
	while data.Xp >= Stats.XpNeeded(data.Level) do
		data.Xp -= Stats.XpNeeded(data.Level)
		data.Level += 1
		data.FreePoints += S.PointsPerLevel
		Remotes.Announce:FireClient(player, "Level " .. data.Level .. " - allocate your points (J)", "Info")
	end
	Stats.Push(player)
end

function Stats.Allocate(player, statName)
	local data = PlayerData.Get(player)
	if not data or type(statName) ~= "string" or data.Stats[statName] == nil then
		return
	end
	if data.FreePoints <= 0 or data.Stats[statName] >= S.MaxPerStat then
		return
	end
	data.FreePoints -= 1
	data.Stats[statName] += 1
	Gear.Recompute(player) -- fires Gear.Changed -> Apply + Push below
end

function Stats.Init()
	Net.On("Allocate", { rate = 6, burst = 12, args = { "string" } }, Stats.Allocate)
	Gear.Changed.Event:Connect(function(player)
		Stats.Apply(player, false)
		Stats.Push(player)
	end)
end

return Stats
