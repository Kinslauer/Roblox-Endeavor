-- Dismember: limbs that break and limbs that come off (owner, 2026-11-13: "instead of gibbing like the characters do,
-- limbs should specifically fall off, and only when impacted directly by enough of a damaging hit. blunt weapons
-- break more often and dismember less"). No body bursts apart any more (Gore keeps every corpse whole).
--
-- A blow counts for a limb only when its contact point is on an arm or a leg (nearer to it than to the trunk, within
-- Config.Dismember.Direct). One such blow that takes Sever[kind] of the body's max health takes the limb off at the
-- elbow or the knee; one that takes Break[kind] breaks it. Kinds: Cut (blades, spears), Blunt, Bullet, Blast.
-- Enemies are ruled here; players' limbs are ruled by their wounds (common/WoundService: a limb already knocked out
-- can be lost to one more cut or blast), and both come here for what it looks like.
--
-- The look: the one-piece skin cannot be cut, so the lost forearm and hand (or shin and foot) are marked `Severed`
-- and shared/Skin folds their part of the mesh away inside the upper limb; a "Stump" cap closes the end; the piece
-- that falls is the limb's own shape, thrown the way the blow went. Model attributes `Lost_<part>` and
-- `Broken_<part>` (ArmL, ArmR, LegL, LegR) drive the client (client/Limbs: blood, the reaction, the limp arm, the
-- dragged leg). World events: "Sever"(model, part, position, direction), "Break"(model, part, position).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WoundService = require(script.Parent.Common.WoundService)

local D = Config.Dismember
local Dismember = {}

local SIDES = { ArmL = { "LeftUpperArm", "LeftLowerArm", "LeftHand" }, ArmR = { "RightUpperArm", "RightLowerArm", "RightHand" },
	LegL = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }, LegR = { "RightUpperLeg", "RightLowerLeg", "RightFoot" } }
local PART_OF = {}
for part, limbs in SIDES do
	for _, name in limbs do
		PART_OF[name] = part
	end
end
Dismember.Limbs = SIDES

local hurt = setmetatable({}, { __mode = "k" }) -- NPC model -> { hum, speed }

local function folder()
	local f = workspace:FindFirstChild("Gore")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Gore"
		f.Parent = workspace
	end
	return f
end

-- The arm or leg a point is on: part name ("ArmL" ...), or nil when the trunk or head is nearer or nothing is close.
function Dismember.LimbAt(model, position)
	local best, bestD
	for _, limb in model:GetChildren() do
		if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and (PART_OF[limb.Name] or limb.Name == "UpperTorso" or limb.Name == "LowerTorso" or limb.Name == "Head") then
			local p = limb.CFrame:PointToObjectSpace(position)
			local h = limb.Size / 2
			local d = (p - Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))).Magnitude
			if not bestD or d < bestD then
				best, bestD = limb, d
			end
		end
	end
	if best and bestD <= D.Direct then
		return PART_OF[best.Name]
	end
	return nil
end

local function watch(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and not hurt[model] then
		hurt[model] = { hum = hum, speed = hum.WalkSpeed }
	end
	return hurt[model]
end

local function stump(model, upper)
	if upper:FindFirstChild("Stump") then
		return
	end
	local cap = Instance.new("Part")
	cap.Name = "Stump"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.one * math.max(upper.Size.X, upper.Size.Z) * 0.92
	cap.Color = Color3.fromRGB(96, 14, 16)
	cap.Material = Enum.Material.Slate
	cap.CanCollide, cap.CanQuery, cap.CanTouch, cap.Massless = false, false, false, true
	cap.CFrame = upper.CFrame * CFrame.new(0, -upper.Size.Y / 2 + cap.Size.Y * 0.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = upper, cap
	weld.Parent = cap
	cap.Parent = upper
end

-- The limb comes off at the elbow or knee. `direction`: the way the blow went (the piece is thrown along it).
function Dismember.Sever(model, part, direction, quiet)
	local names = SIDES[part]
	if not names or model:GetAttribute("Severed_" .. part) then
		return false
	end
	local upper, lower, last = model:FindFirstChild(names[1]), model:FindFirstChild(names[2]), model:FindFirstChild(names[3])
	if not (upper and lower and last) then
		return false
	end
	model:SetAttribute("Severed_" .. part, true)
	model:SetAttribute("Lost_" .. part, true)
	-- the piece that falls: the limb's own shapes, joined, capped, thrown
	local piece = Instance.new("Model")
	piece.Name = "SeveredLimb"
	local first
	for _, limb in { lower, last } do
		local c = limb:Clone()
		for _, child in c:GetChildren() do
			child:Destroy()
		end
		c.Name = limb.Name
		c.Transparency = 0
		c.Color = D.Piece.Color
		c.Material = Enum.Material.SmoothPlastic
		c.Anchored, c.CanCollide, c.CanQuery, c.Massless = false, true, false, false
		c:SetAttribute("Proxy", nil)
		c.Parent = piece
		if first then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = first, c
			weld.Parent = c
		else
			first = c
		end
	end
	local cap = Instance.new("Part")
	cap.Name = "Cut"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.one * math.max(lower.Size.X, lower.Size.Z) * 0.95
	cap.Color = Color3.fromRGB(96, 14, 16)
	cap.Material = Enum.Material.Slate
	cap.CanCollide, cap.CanQuery, cap.Massless = false, false, true
	cap.CFrame = lower.CFrame * CFrame.new(0, lower.Size.Y / 2 - cap.Size.Y * 0.2, 0)
	local capWeld = Instance.new("WeldConstraint")
	capWeld.Part0, capWeld.Part1 = first, cap
	capWeld.Parent = cap
	cap.Parent = piece
	piece.PrimaryPart = first
	CollectionService:AddTag(piece, "SeveredLimb")
	piece.Parent = folder()
	local dir = if typeof(direction) == "Vector3" and direction.Magnitude > 0.05 then direction.Unit else upper.CFrame.RightVector
	first.AssemblyLinearVelocity = dir * D.Piece.Speed + Vector3.new(0, D.Piece.Lift, 0)
	first.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * D.Piece.Spin
	pcall(function()
		first:SetNetworkOwner(nil)
	end)
	Debris:AddItem(piece, D.Piece.Life)
	-- what is left on the body: the limbs stay as joints for the animation but are gone to the eye and to blows
	for _, limb in { lower, last } do
		limb:SetAttribute("Severed", true)
		limb.CanQuery, limb.CanTouch = false, false
		for _, d in limb:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1 -- worn gear and scars on the lost part
			end
		end
	end
	stump(model, upper)
	local held = (part == "ArmR") and model:FindFirstChild("HeldWeapon")
	if held and not Players:GetPlayerFromCharacter(model) then
		held:Destroy() -- an enemy's weapon goes with the hand
	end
	-- an enemy's price: a lost arm hits weaker, a lost leg hobbles, and the stump bleeds
	if not Players:GetPlayerFromCharacter(model) then
		local w = watch(model)
		if w then
			if part == "ArmL" or part == "ArmR" then
				model:SetAttribute("LimbDamage", (model:GetAttribute("LimbDamage") or 1) * D.ArmDamage)
			else
				model:SetAttribute("LimbSpeed", (model:GetAttribute("LimbSpeed") or 1) * D.LegSpeed)
			end
			w.bleedUntil = os.clock() + D.Bleed.Seconds
		end
	end
	if not quiet then
		Remotes.World:FireAllClients("Sever", model, part, lower.Position, dir)
	end
	if Dismember.Severed then
		Dismember.Severed(model, part)
	end
	return true
end

function Dismember.Break(model, part, quiet)
	local names = SIDES[part]
	if not names or model:GetAttribute("Broken_" .. part) or model:GetAttribute("Lost_" .. part) then
		return false
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		model:SetAttribute("Broken_" .. part, true) -- a player's comes from the wounds
		local w = watch(model)
		if w then
			if part == "ArmL" or part == "ArmR" then
				model:SetAttribute("LimbDamage", (model:GetAttribute("LimbDamage") or 1) * D.BrokenArm)
			else
				model:SetAttribute("LimbSpeed", (model:GetAttribute("LimbSpeed") or 1) * D.BrokenLeg)
			end
		end
	end
	local limb = model:FindFirstChild(names[2])
	if not quiet then
		Remotes.World:FireAllClients("Break", model, part, limb and limb.Position)
	end
	return true
end

-- One blow on an enemy (from Combat, after the damage). info: { Amount, At, Kind, Direction, Killed }.
function Dismember.Hit(model, info)
	if not info.At or not info.Amount or info.Amount <= 0 or model:GetAttribute("Contact") then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.MaxHealth <= 0 or hum.MaxHealth > D.MaxHealth then
		return nil -- the big ones keep their limbs
	end
	local part = Dismember.LimbAt(model, info.At)
	if not part then
		return nil
	end
	local kind = info.Kind or "Blunt"
	local share = info.Amount / hum.MaxHealth * (if info.Killed then D.KillBonus else 1)
	if share >= (D.Sever[kind] or math.huge) then
		if Dismember.Sever(model, part, info.Direction) then
			return "Sever", part
		end
	elseif share >= (D.Break[kind] or math.huge) then
		if Dismember.Break(model, part) then
			return "Break", part
		end
	end
	return nil
end

-- A corpse keeps what its body had lost (Gore copies the limbs; the attributes come with them).
function Dismember.CopyTo(model, corpse)
	for part, names in SIDES do
		if model:GetAttribute("Severed_" .. part) then
			corpse:SetAttribute("Lost_" .. part, true)
			local upper = corpse:FindFirstChild(names[1])
			if upper then
				local copied = upper:FindFirstChild("Stump") -- cloned with the limb: its weld still points at the living body
				if copied then
					copied:Destroy()
				end
				stump(corpse, upper)
			end
			for i = 2, 3 do
				local limb = corpse:FindFirstChild(names[i])
				if limb then
					limb:SetAttribute("Severed", true)
					limb.Transparency = 1
					limb.CanCollide, limb.CanQuery = false, false
				end
			end
		end
	end
end

function Dismember.Init()
	-- players: the wounds decide (WoundService events), this shows it
	local previous = WoundService.OnEvent
	WoundService.OnEvent = function(char, part, ev, info)
		if previous then
			previous(char, part, ev, info)
		end
		if SIDES[part] then
			local root = char:FindFirstChild("HumanoidRootPart")
			local dir = if root and info and info.At then (root.Position - info.At) * Vector3.new(-1, 0, -1) else nil
			if ev.Lost then
				Dismember.Sever(char, part, dir)
			elseif ev.Broke then
				Dismember.Break(char, part)
			end
		end
	end
	-- enemies with a hurt limb: slower, and a stump bleeds for a while
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for model, w in hurt do
				local hum = w.hum
				if not model.Parent or hum.Health <= 0 then
					hurt[model] = nil
					continue
				end
				local mult = model:GetAttribute("LimbSpeed")
				if mult and hum.WalkSpeed > w.speed * mult + 0.05 then
					hum.WalkSpeed = w.speed * mult
				end
				if w.bleedUntil and now < w.bleedUntil then
					hum:TakeDamage(hum.MaxHealth * D.Bleed.PerSecond * 0.5)
				end
			end
		end
	end)
end

return Dismember
