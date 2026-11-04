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
