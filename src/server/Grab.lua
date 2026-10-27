-- Grab and throw, story 003 (design/gdd/destruction.md §4.5; Light class first). G picks up a loose chunk
-- of a broken prop (server/Destruction.lua DebrisChunk) within GrabRange; hold G and let go to throw it
-- where you're looking. Everything is decided here: the client only says "grab", "charge" and "throw" with
-- a look direction. The charge is timed on the server, the speed comes from the formula (never from the
-- client), and the flight is flown here, frame by frame, with its own hit detection: the first body it meets
-- past MinFlight takes a normal combat hit (block, parry, dodge and knockback all apply), a prop takes a
-- Thrown hit. Light chunks: one hand, you can still block. Medium and Heavy need cybernetic arms with Lift
-- (one and two; shared/Cybernetics.lua ServoArm).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Destruction = require(script.Parent.Destruction)
local Gear = require(script.Parent.Gear)
local RateLimit = require(script.Parent.RateLimit)

local Grab = {}

local G = Config.Destruction.Grab
local held = {} -- player -> { Chunk, Weld, ChargeAt? }
local flights = {} -- chunk -> { Thrower, Pos, Vel, Start, From, T, Damage, Spec }
local GRAVITY = Vector3.new(0, -(workspace.Gravity or 196.2) * 0.35, 0) -- floatier than a body: thrown things read

local function classOf(chunk)
	return chunk:GetAttribute("Weight") or "Light"
end

local function handOf(char)
	return char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart")
end

function Grab.Holding(player)
	local h = held[player]
	return h and h.Chunk or nil
end

-- G: the nearest loose Light chunk in reach.
function Grab.Grab(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) or held[player] or not Combat.CanAct(char) then
		return false
	end
	local best, bestD
	local arms = Gear.Get(player).Lift or 0
	local function canLift(K)
		return K ~= nil and (K.Grabbable or (K.ArmsNeeded ~= nil and arms >= K.ArmsNeeded))
	end
	for _, c in Destruction.Chunks() do
		local chunk = c[1]
		if chunk.Parent and not chunk:GetAttribute("Held") and not flights[chunk] and canLift(G.Classes[classOf(chunk)]) then
			local d = (chunk.Position - root.Position).Magnitude
			if d <= G.Range and (not bestD or d < bestD) then
				best, bestD = chunk, d
			end
		end
	end
	if not best then
		return false
	end
	best:SetAttribute("Held", player.UserId) -- claimed now: a second grab on the same frame gets nothing
	Combat.SetBusy(char, G.GrabSeconds)
	local token = Combat.State(char).token
	task.delay(G.GrabSeconds, function()
		local hand = handOf(char)
		if Combat.State(char).token ~= token or not hand or hum.Health <= 0 or not best.Parent then
			best:SetAttribute("Held", nil) -- hit while reaching: nothing in hand
			return
		end
		best.Anchored, best.CanCollide, best.Massless = false, false, true
		best.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, best
		weld.Parent = best
		held[player] = { Chunk = best, Weld = weld }
		char:SetAttribute("Holding", classOf(best))
	end)
	return true
end

-- Hold G while holding: the throw winds up (timed here).
function Grab.Charge(player)
	local h = held[player]
	if h and not h.ChargeAt then
		h.ChargeAt = os.clock()
		player.Character:SetAttribute("ThrowCharge", true)
		Combat.FX("ThrowWindup", player.Character, G.MaxCharge)
	end
end

local function aimFrom(root, aim)
	local look = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 0.5 or aim.Magnitude > 1.5 then
		return look
	end
	aim = aim.Unit
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.05 or math.deg(math.acos(math.clamp(flat.Unit:Dot(look), -1, 1))) > Config.Combat.AimCone then
		return look
	end
	return aim
end

local function release(player)
	local h = held[player]
	held[player] = nil
	local char = player.Character
	if char then
		char:SetAttribute("Holding", nil)
		char:SetAttribute("ThrowCharge", nil)
	end
	if h and h.Weld then
		h.Weld:Destroy()
	end
	return h
end

-- Let go of G: throw toward the look direction.
function Grab.Throw(player, aim)
	local h = held[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (h and root and h.Chunk.Parent) then
		return false
	end
	local K = G.Classes[classOf(h.Chunk)]
	local charge = math.clamp(((h.ChargeAt and os.clock() - h.ChargeAt) or 0) / G.MaxCharge, 0, 1)
	local stats = Gear.Get(player).Stats or {}
	local stamina = K.Stamina * (1 + charge) * (1 - G.StaminaPerWillpower * (stats.Willpower or 0))
	if not Combat.SpendStamina(char, stamina) then
		release(player) -- too tired to throw: it drops at your feet
		h.Chunk:SetAttribute("Held", nil)
		h.Chunk.CanCollide, h.Chunk.Massless = true, false
		return false
	end
	release(player)
	local speed = K.Speed * (1 + G.ChargeSpeed * charge) * (1 + G.SpeedPerStrength * (stats.Strength or 0))
	local dir = aimFrom(root, aim)
	local chunk = h.Chunk
	chunk.Anchored, chunk.CanCollide = true, false
	local start = chunk.Position
	flights[chunk] = {
		Thrower = char, Pos = start, Vel = dir * speed + Vector3.new(0, K.Lift, 0), Start = start, T = 0,
		Damage = K.Damage * (speed / K.Speed) ^ G.DamageExponent, Posture = K.Posture, Knockback = K.Knockback, Speed = speed,
	}
	Combat.FX("Throw", char, speed)
	return true
end

function Grab.Flights()
	return flights
end

local function land(chunk, at)
	flights[chunk] = nil
	chunk:SetAttribute("Held", nil)
	chunk.CFrame = CFrame.new(at)
	chunk.Anchored, chunk.CanCollide, chunk.Massless = true, true, false
end

local function fly(dt)
	for chunk, f in flights do
		if not chunk.Parent then
			flights[chunk] = nil
			continue
		end
		f.T += dt
		local from = f.Pos
		f.Vel += GRAVITY * dt
		local to = from + f.Vel * dt
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { f.Thrower, chunk }
		local hit = workspace:Raycast(from, to - from, ray)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			local far = (hit.Position - f.Start).Magnitude >= G.MinFlight
			if hum and far then
				Combat.Damage(f.Thrower, model, f.Damage, { Posture = f.Posture, Knockback = f.Knockback, Type = "Physical", Thrown = true })
				land(chunk, hit.Position + Vector3.new(0, 0.5, 0))
				continue
			elseif model and model:GetAttribute("Kind") then
				Destruction.Damage(model, f.Damage, "Thrown", hit.Position)
				land(chunk, hit.Position)
				continue
			elseif not hum then
				land(chunk, hit.Position + hit.Normal * 0.5) -- the ground or a wall
				continue
			end
		end
		f.Pos = to
		local cf = chunk.CFrame
		chunk.CFrame = CFrame.new(to) * (cf - cf.Position) * CFrame.Angles(dt * 9, dt * 5, 0) -- tumbling
		if f.T >= G.FlightSeconds then
			land(chunk, to)
		end
	end
end

local function onRemote(player, action, aim)
	if action == "Grab" then
		Grab.Grab(player)
	elseif action == "Charge" then
		Grab.Charge(player)
	elseif action == "Throw" then
		Grab.Throw(player, aim)
	end
end

-- The cycle: whatever is in your hands dissolves out of them (destruction.md §4.8).
function Grab.DropAll()
	for p in held do
		release(p)
	end
	table.clear(flights)
end

function Grab.Init()
	Remotes.Grab.OnServerEvent:Connect(RateLimit.Wrap("Grab", Config.RateLimit.Grab, onRemote))
	require(script.Parent.Cycle).Dematerialized.Event:Connect(Grab.DropAll)
	RunService.Heartbeat:Connect(fly)
	local function watch(p)
		p.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					local h = release(p)
					if h and h.Chunk.Parent then -- it drops with you
						h.Chunk:SetAttribute("Held", nil)
						h.Chunk.CanCollide, h.Chunk.Massless = true, false
					end
				end)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		local h = release(p)
		if h and h.Chunk.Parent then
			h.Chunk:SetAttribute("Held", nil)
		end
	end)
end

return Grab
