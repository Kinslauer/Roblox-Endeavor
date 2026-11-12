-- Stealth rules both sides agree on: which takedown is on offer for a guard, and how lit a point is.
-- The server decides (server/Stealth.lua); the client runs the same functions to draw the prompt and the
-- light meter without waiting for it.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local S = Config.Stealth
local T = S.Takedown

local Stealth = {}

Stealth.Kinds = { "Rear", "Drop", "Panel", "Rail", "Ledge" }

-- The takedown you could do on a guard standing at `guardCF` from `playerCF`, or nil.
--   state: the guard's stealth state ("Patrol" | "Suspicious" | "Search" | "Alert" | "Down")
--   spots: TakedownSpot parts (attribute Takedown = "Panel" | "Rail" | "Ledge"); defaults to every tagged one
-- Returns kind, spot.
function Stealth.TakedownKind(playerCF, guardCF, state, spots)
	if state == "Alert" or state == "Down" then
		return nil
	end
	local offset = playerCF.Position - guardCF.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	-- from above: drop on it
	if offset.Y >= T.DropMin and offset.Y <= T.DropMax and flat.Magnitude <= T.DropReach then
		return "Drop", nil
	end
	if math.abs(offset.Y) > 4 or flat.Magnitude > T.Reach then
		return nil
	end
	-- the room helps: a fuse box, a live rail or a drop beside the guard
	local best, bestD = nil, T.EnvReach
	for _, spot in spots or CollectionService:GetTagged("TakedownSpot") do
		if spot.Parent and not spot:GetAttribute("Used") then
			local d = (spot.Position - guardCF.Position).Magnitude
			if d < bestD then
				best, bestD = spot, d
			end
		end
	end
	if best then
		return best:GetAttribute("Takedown") or "Panel", best
	end
	-- asleep at his post: from any side
	if flat.Magnitude > 0.05 and (state == "Asleep" or guardCF.LookVector:Dot(flat.Unit) < T.BehindDot) then
		return "Rear", nil
	end
	return nil
end

-- Behind the guard (the neck hold needs it whatever the room offers).
function Stealth.Behind(playerCF, guardCF)
	local offset = playerCF.Position - guardCF.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	return math.abs(offset.Y) <= 4 and flat.Magnitude <= T.Reach and flat.Magnitude > 0.05 and guardCF.LookVector:Dot(flat.Unit) < T.BehindDot
end

-- CQC on a guard: what a tap of X and what holding X would do from here. Returns tap, hold (each a word or nil):
--   tap  "Rear" | "Drop" | "Panel" | "Rail" | "Ledge" (the takedowns) | "Throw" (in front of or beside it)
--   hold "Grab" (behind it: the neck hold)
function Stealth.Cqc(playerCF, guardCF, state, spots)
	if state == "Down" or state == "Held" then
		return nil, nil
	end
	local kind = Stealth.TakedownKind(playerCF, guardCF, state, spots)
	local hold = if state ~= "Alert" and Stealth.Behind(playerCF, guardCF) then "Grab" else nil
	if kind then
		return kind, hold
	end
	local offset = playerCF.Position - guardCF.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if math.abs(offset.Y) <= 4 and flat.Magnitude <= S.Cqc.Throw.Reach then
		return "Throw", hold
	end
	return nil, hold
end

-- How much one light adds at `point` (0..1), before walls. `light` is a PointLight / SpotLight / SurfaceLight
-- under a part or attachment.
function Stealth.LightAt(light, origin, look, point)
	if not light.Enabled then
		return 0
	end
	local range = light.Range
	local d = (point - origin).Magnitude
	if d >= range then
		return 0
	end
	if light:IsA("SpotLight") or light:IsA("SurfaceLight") then
		local dir = (point - origin)
		if dir.Magnitude > 0.5 and look:Dot(dir.Unit) < math.cos(math.rad(light.Angle / 2)) then
			return 0
		end
	end
	local f = 1 - d / range
	return math.clamp(light.Brightness, 0, 3) * 1.4 * f * f
end

-- A guard's sight range for a body lit `exposure` (0..1).
function Stealth.SightRange(exposure, crouched, searching, prone)
	local r = S.SightRange * (S.DarkSight + (1 - S.DarkSight) * math.clamp(exposure, 0, 1))
	if prone then
		-- flat on the floor: a small shape, and in the dark close to nothing
		r *= S.Stance.ProneVisibility * (if exposure < S.Stance.ProneDark then S.Stance.ProneDarkVisibility else 1)
	elseif crouched then
		r *= S.CrouchVisibility
	end
	if searching then
		r *= 1.25
	end
	return r
end

return Stealth
