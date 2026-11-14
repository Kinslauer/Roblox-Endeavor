-- Swings: the shape of every melee swing, shared by the server (which traces the blade for hits and clashes)
-- and the clients (which drive the arm along the same arc), so what you see is what hits. Mordhau-style: a
-- swing is only dangerous along its blade, only while it is live (the Active window), and two blades that
-- meet mid-air cancel both swings.
--
-- Space: the attacker's root. Forward = -Z, right = +X, up = +Y. A key is { t, yaw, pitch } in degrees:
-- yaw 0 is straight ahead, positive to the attacker's right; pitch positive is up. The arm (and the weapon
-- in line with it) points along that direction from the right shoulder; the blade runs from the hand
-- (Swings.HandReach) to the tip (the weapon's Range).
local Swings = {}

Swings.Shapes = {
	SlashR = { { 0, 85, 12 }, { 0.5, 0, 2 }, { 1, -75, -12 } }, -- forehand: right to left
	SlashL = { { 0, -70, 6 }, { 0.5, 0, 0 }, { 1, 80, -10 } }, -- backhand: left to right
	Overhead = { { 0, 8, 85 }, { 0.45, 4, 25 }, { 1, 0, -50 } }, -- top down
	Diagonal = { { 0, 70, 70 }, { 0.5, 10, 12 }, { 1, -55, -45 } }, -- high right to low left
	Uppercut = { { 0, 15, -55 }, { 1, 0, 60 } },
	Thrust = { { 0, 0, 0 }, { 1, 0, 0 }, Thrust = true }, -- straight ahead, the blade drives out
	Jab = { { 0, -4, 4 }, { 1, 0, 2 }, Thrust = true, Short = true },
}

-- which shape each weapon family swings, by combo step; the heavy has its own
Swings.Families = {
	Blade = { "SlashR", "SlashL", "SlashR", "Diagonal", Heavy = "Diagonal" },
	Blunt = { "SlashR", "SlashL", "Overhead", Heavy = "Overhead" },
	Baton = { "SlashR", "SlashL", "Overhead", Heavy = "Overhead" },
	Hammer = { "SlashR", "Overhead", Heavy = "Overhead" },
	Spear = { "Thrust", "Thrust", "SlashR", "Thrust", Heavy = "Thrust" },
	Fists = { "Jab", "Jab", "Jab", "Uppercut", Heavy = "Uppercut" },
	Rifle = false,
	Sidearm = false, -- guns are aimed, not swung: no arc (the client's aim-and-recoil pose instead)
}

Swings.HandReach = 2.1 -- shoulder to hand along the arm (studs, at scale 1)
Swings.ShoulderOffset = Vector3.new(1.0, 1.25, 0) -- right shoulder from the root (scale 1)

-- The shape id for a swing: a family's combo step or its heavy.
function Swings.ShapeFor(family, step, heavy)
	local f = Swings.Families[family]
	if f == false then
		return nil
	end
	f = f or Swings.Families.Blade
	if heavy then
		return f.Heavy or f[1]
	end
	return f[((step or 1) - 1) % #f + 1]
end

local function smooth(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function dirOf(yaw, pitch)
	local y, p = math.rad(yaw), math.rad(pitch)
	return Vector3.new(math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))
end

-- Yaw and pitch of a shape at progress u (0..1 of the live window), eased so the blade is fastest mid-swing.
function Swings.Angles(id, u)
	local shape = Swings.Shapes[id] or Swings.Shapes.SlashR
	local e = smooth(u)
	for i = 1, #shape - 1 do
		local a, b = shape[i], shape[i + 1]
		if e <= b[1] then
			local f = (e - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
		end
	end
	local last = shape[#shape]
	return last[2], last[3]
end

-- Direction of the arm/blade in root space at progress u.
function Swings.Dir(id, u)
	return dirOf(Swings.Angles(id, u))
end

-- How far out the blade reaches at progress u (a thrust drives out; everything else holds full reach).
function Swings.ReachAt(id, u, reach)
	local shape = Swings.Shapes[id]
	if shape and shape.Thrust then
		return reach * (0.55 + 0.45 * smooth(u * 1.4))
	end
	return reach
end

-- The blade in world space: base (the hand) and tip, at progress u, for a body at rootCF of size `scale`.
function Swings.Blade(rootCF, id, u, reach, scale)
	scale = scale or 1
	local shoulder = rootCF:PointToWorldSpace(Swings.ShoulderOffset * scale)
	local dir = rootCF:VectorToWorldSpace(Swings.Dir(id, u))
	local hand = Swings.HandReach * scale
	local tip = math.max(Swings.ReachAt(id, u, reach), hand + 1)
	return shoulder + dir * hand, shoulder + dir * tip
end

-- ===== A swing goes where you look, and the way you flick =====
-- (owner, 2026-11-14: the swings "looked canned and non interactive".) The whole arc is tipped up or down with the
-- swinger's look, about the shoulders, live through the swing: look down to cut at a crouched or fallen body, up at
-- one above. The server traces the tipped arc and the clients pose the arms on it, so what you see is what hits.
Swings.LookShare = 0.8 -- how much of the look's pitch the arc takes
Swings.LookMax = 42 -- degrees, either way

-- Degrees to tip a swing for a look direction (unit vector, world space).
function Swings.LookPitch(aim)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
		return 0
	end
	return math.clamp(math.deg(math.asin(math.clamp(aim.Unit.Y, -1, 1))) * Swings.LookShare, -Swings.LookMax, Swings.LookMax)
end

-- The frame a swing is traced in: the body's root, tipped by `pitch` degrees about the shoulder line.
function Swings.Tilt(rootCF, pitch, scale)
	if not pitch or math.abs(pitch) < 0.05 then
		return rootCF
	end
	local y = Swings.ShoulderOffset.Y * (scale or 1)
	return rootCF * CFrame.new(0, y, 0) * CFrame.Angles(math.rad(pitch), 0, 0) * CFrame.new(0, -y, 0)
end

-- A flick of the mouse as the attack is pressed picks the cut: "Left" = the blade travels to the left (a forehand),
-- "Right" a backhand, "Down" an overhead, "Up" a rising cut. Families that only thrust or punch keep their own.
local FLICK = { Left = "SlashR", Right = "SlashL", Down = "Overhead", Up = "Uppercut" }
local NO_FLICK = { Spear = true, Fists = true }
function Swings.FlickShape(family, flick)
	if not FLICK[flick] or NO_FLICK[family] or Swings.Families[family] == false then
		return nil
	end
	return FLICK[flick]
end

-- ===== The guard (F) =====
-- Held across the front, braced by the off hand, turned toward the blade coming in. The server blocks with
-- exactly this shape (Combat: a traced blade is only blocked when it meets the guard before the body) and the
-- clients pose the arms on it, so the guard you see is the guard that blocks. Root space, like the swings.
Swings.GuardTurn = 75 -- degrees the guard turns off your facing toward a blade; past that it comes in around it
Swings.ThreatReach = 2.4 -- studs from a body's axis at which an incoming blade counts as arriving (ThreatPoint)
Swings.GuardRing = 1.6 -- studs from the body's axis the guard is held out at (scale 1)
Swings.GuardHigh = 1.9 -- a blade this high (studs above the root, at scale 1) is met with the guard over the head

-- Where an incoming swing will first reach a body standing at `target` (world space): stepping along the rest of
-- its arc from progress u (0 during the windup), the point of the blade nearest the body at the first step it
-- comes within reach of it. That is where a guard has to be. Without a target, or if the arc never gets there,
-- the blade's middle at mid-arc.
local THREAT_STEPS = 12
function Swings.ThreatPoint(rootCF, id, u, reach, scale, target)
	u = u or 0
	if target then
		local lo, hi = target - Vector3.new(0, 2.5, 0), target + Vector3.new(0, 2.2, 0)
		for i = 0, THREAT_STEPS do
			local uu = u + (1 - u) * i / THREAT_STEPS
			local base, tip = Swings.Blade(rootCF, id, uu, reach, scale)
			local dist, onBlade = Swings.SegmentDistance(base, tip, lo, hi)
			if dist <= Swings.ThreatReach then
				return onBlade
			end
		end
	end
	local base, tip = Swings.Blade(rootCF, id, math.max(u, 0.5), reach, scale)
	return base:Lerp(tip, 0.6)
end

-- The guard pose toward a threat (a point in the guarding body's root space, or nil: nothing coming): the hand
-- that holds it and the direction the weapon runs from that hand (both root space), the turn (degrees, positive
-- to the right) and whether it is held high. The guard is laid across the front, upright on the side a blow comes
-- from, over the head for a high one, and placed so the off hand's brace sits on a ring round the body
-- (Swings.GuardRing) toward where the blade will arrive, at its height.
function Swings.GuardPose(threat, scale)
	scale = scale or 1
	local yaw, high, y = 0, false, 1.45
	if threat then
		yaw = math.clamp(math.deg(math.atan2(threat.X, -threat.Z)), -Swings.GuardTurn, Swings.GuardTurn)
		high = threat.Y > Swings.GuardHigh * scale
		y = math.clamp(threat.Y / scale, 0.6, 2.5)
	end
	local w = math.clamp(math.abs(yaw) / 55, 0, 1)
	local side = if yaw >= 0 then 1 else -1
	local across = Vector3.new(-1, if high then 0.12 else 0.45, -0.05)
	local upright = Vector3.new(0.12 * side, 1, -0.2)
	local blade = (across * (1 - w) + upright * w).Unit
	local r = math.rad(yaw)
	local brace = Vector3.new(math.sin(r) * Swings.GuardRing, y, -math.cos(r) * Swings.GuardRing) * scale
	local hand = brace - blade * (0.9 * scale)
	return Vector3.new(hand.X, math.clamp(hand.Y, 0.5 * scale, 2.4 * scale), hand.Z), blade, yaw, high
end

-- How long a weapon's guard is (studs from the hand along the blade, scale 1) from its reach.
function Swings.GuardLength(range)
	return math.clamp((range or 6) - Swings.HandReach * 1.1, 2.4, 5)
end

-- The guard as a segment in world space, from a pose (GuardPose's hand and blade). Armed: the weapon from
-- just below the grip out to its tip. Unarmed: both forearms, a short bar across the brace point.
function Swings.GuardSegment(rootCF, hand, blade, scale, length, armed, yaw)
	scale = scale or 1
	if armed then
		return rootCF:PointToWorldSpace(hand - blade * (0.5 * scale)), rootCF:PointToWorldSpace(hand + blade * ((length or 3.5) * scale))
	end
	-- forearms: across the guard ring at the brace, square to the way the blow comes in
	local r = math.rad(yaw or 0)
	local centre = hand + blade * (0.9 * scale)
	local across = Vector3.new(math.cos(r), 0, math.sin(r)) * (0.85 * scale)
	return rootCF:PointToWorldSpace(centre - across), rootCF:PointToWorldSpace(centre + across)
end

-- A body's size relative to a standard one, from its humanoid (bigger rigs swing from higher and wider).
function Swings.ScaleOf(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return 1
	end
	return math.clamp((hum.HipHeight + 1.2) / 3.0, 0.8, 1.8)
end

-- Closest points between segments p1-q1 and p2-q2: returns distance, point on the first, point on the second.
function Swings.SegmentDistance(p1, q1, p2, q2)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a <= 1e-8 and e <= 1e-8 then
		return (p1 - p2).Magnitude, p1, p2
	end
	if a <= 1e-8 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-8 then
			t, s = 0, math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom ~= 0 then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t, s = 1, math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local c1, c2 = p1 + d1 * s, p2 + d2 * t
	return (c1 - c2).Magnitude, c1, c2
end

return Swings
