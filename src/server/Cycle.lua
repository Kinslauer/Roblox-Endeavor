-- The cycle (design/gdd/dematerialization.md): every Config.Cycle.Seconds the Conduit world comes apart
-- and is restored exactly. The conduits read it as proof the world is simulated.
--   Stable -> Warning (T - WarningSeconds: the hum, lights flicker) -> Flicker (T - FlickerSeconds: colour
--   drains) -> Whiteout (T: dematerialize - every enemy, rival crew and unlooted thing on the ground is
--   taken out of the world) -> Stable (T + WhiteoutSeconds: rematerialize - the cycle's draw places the road
--   guards, the rival crews and the contacts; new loot comes from the new bodies).
-- Only four things vary between cycles: player spawns (already a random pad per spawn), enemy spawns, where
-- the contacts stand, and loot. Profiles, the hideout, the war and the range are never touched
-- (Config.Cycle.Exclude). Players stay where they stand. Clients draw the warning from workspace attributes
-- (Cycle_Phase, Cycle_Index; client/WorldFX.lua).
-- Other systems hook in through the signals: Cycle.Warning, Cycle.Dematerialized, Cycle.Rematerialized
-- (destruction's reset will subscribe here).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Contacts = require(script.Parent.Contacts)
local NPCs = require(script.Parent.NPCs)
local Regions = require(script.Parent.Regions)
local Rivals = require(script.Parent.Rivals)
local WorldPhase = require(script.Parent.WorldPhase)

local Cycle = {}

local C = Config.Cycle

local function signal()
	return Instance.new("BindableEvent")
end
Cycle.Warning = signal() -- (secondsLeft)
Cycle.Dematerialized = signal() -- (index)
Cycle.Rematerialized = signal() -- (index, rng)

local state = { Phase = "Off", Index = 0, NextAt = nil, Last = nil }

local function setPhase(phase)
	state.Phase = phase
	workspace:SetAttribute("Cycle_Phase", phase)
end

-- Outside the Conduit world: the hideout room, the war / range, the prologue plots.
function Cycle.Excluded(position)
	local E = C.Exclude
	if position.Y > E.AboveY then
		return true
	end
	local H = Config.Hideout
	local half = H.Size / 2 + E.HideoutMargin
	local d = position - H.Origin
	if math.abs(d.X) <= half and math.abs(d.Z) <= half then
		return true
	end
	local r = position - Config.Range.Origin
	return Vector3.new(r.X, 0, r.Z).Magnitude <= E.RangeRadius
end

local function positionOf(inst)
	if inst:IsA("Model") then
		local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
		return root and root.Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

-- Dematerialize: take out every enemy body (no death, no drops) and every unlooted thing on the ground.
local function clear()
	local removed = { Enemies = 0, Loot = 0 }
	for _, model in CollectionService:GetTagged(NPCs.Tag) do
		local pos = positionOf(model)
		local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
		-- recruits carry a Faction (the war); range targets / dummies sit inside the excluded area
		if not isPlayer and model:GetAttribute("EnemyType") and model:GetAttribute("Faction") == nil and pos and not Cycle.Excluded(pos) then
			NPCs.Remove(model)
			removed.Enemies += 1
		end
	end
	for _, inst in workspace:GetChildren() do
		if inst.Name == "Lootable" and inst:IsA("BasePart") and not Cycle.Excluded(inst.Position) then
			inst:Destroy()
			removed.Loot += 1
		end
	end
	return removed
end

-- Rematerialize: the new cycle's draw places what varies.
local function redraw(rng)
	local placed = {}
	for _, model in Regions.Guards() do
		NPCs.Remove(model)
	end
	placed.Guards = Regions.SpawnGuards(rng, C.GuardJitter)
	Rivals.Reset(rng)
	placed.Contacts = Contacts.Place(rng)
	return placed
end

local function dematerialize()
	setPhase("Whiteout")
	state.Last = { Removed = clear() }
	Cycle.Dematerialized:Fire(state.Index)
end

local function rematerialize()
	state.Index += 1
	local rng = Random.new(C.Seed + state.Index)
	state.Last.Placed = redraw(rng)
	workspace:SetAttribute("Cycle_Index", state.Index)
	setPhase("Stable")
	state.NextAt = os.clock() + C.Seconds
	Cycle.Rematerialized:Fire(state.Index, rng)
end

local function tick(now)
	local nextAt = state.NextAt
	if not nextAt then
		return
	end
	local p = state.Phase
	if p == "Stable" and now >= nextAt - C.WarningSeconds then
		setPhase("Warning")
		Cycle.Warning:Fire(math.max(0, nextAt - now))
		p = "Warning"
	end
	if p == "Warning" and now >= nextAt - C.FlickerSeconds then
		setPhase("Flicker")
		p = "Flicker"
	end
	if p == "Flicker" and now >= nextAt then
		dematerialize()
		p = "Whiteout"
	end
	if p == "Whiteout" and now >= nextAt + C.WhiteoutSeconds then
		rematerialize()
	end
end

-- The clock starts when the world opens (emergence is the first materialization).
function Cycle.Start()
	if state.NextAt then
		return
	end
	state.NextAt = os.clock() + C.Seconds
	workspace:SetAttribute("Cycle_Index", state.Index)
	setPhase("Stable")
end

-- Testing / dev: the next dematerialization happens `seconds` from now (warning and flicker included
-- when there is time for them).
function Cycle.Schedule(seconds)
	if not state.NextAt then
		Cycle.Start()
	end
	if state.Phase == "Whiteout" then
		return
	end
	state.NextAt = os.clock() + math.max(0, seconds)
	setPhase("Stable")
end

function Cycle.State()
	return state
end

function Cycle.Init()
	if WorldPhase.IsOpen() then
		Cycle.Start()
	end
	WorldPhase.Changed.Event:Connect(function(phase)
		if phase == Config.Phases.Open then
			Cycle.Start()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			tick(os.clock())
		end
	end)
end

return Cycle
